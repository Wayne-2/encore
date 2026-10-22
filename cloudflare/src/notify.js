// Push notifications for Encore.
//
// Notifications are delivered from a durable Firestore outbox:
//
//   POST /notify/outbox           { outboxId }  (app, immediate attempt)
//   POST /notify/contact-request  { requestId }  (legacy direct attempt)
//   POST /notify/message          { chatId, messageId }  (legacy direct attempt)
//
// The Worker also runs on a cron trigger and retries pending/failed outbox
// jobs with backoff. Delivery state is written by the Worker's service account.

import { googleAccessToken, verifyIdToken } from './verify.js';

const FIRESTORE_BASE = 'https://firestore.googleapis.com/v1';
const FCM_BASE = 'https://fcm.googleapis.com/v1';
const NOTIFY_SCOPES = [
  'https://www.googleapis.com/auth/datastore',
  'https://www.googleapis.com/auth/firebase.messaging',
].join(' ');

const CHANNEL_ID = 'encore_default';
const ICON = 'ic_notification';
const COLOR = '#25A10C';

const OUTBOX_COLLECTION = 'notificationOutbox';
const MAX_ATTEMPTS = 5;
const CLAIM_TIMEOUT_MS = 5 * 60 * 1000;
const STALE_SENDING_MS = 10 * 60 * 1000;
const CRON_BATCH_SIZE = 25;
const RETRY_DELAYS_MS = [
  60 * 1000,
  5 * 60 * 1000,
  15 * 60 * 1000,
  60 * 60 * 1000,
  6 * 60 * 60 * 1000,
];

let accessTokenCache = { key: '', token: '', expiresAt: 0 };

// --- Firestore REST ---------------------------------------------------------

function decodeValue(value) {
  if (!value || typeof value !== 'object') return null;
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return Number(value.doubleValue);
  if ('timestampValue' in value) return value.timestampValue;
  if ('nullValue' in value) return null;
  if ('arrayValue' in value) {
    return (value.arrayValue.values || []).map(decodeValue);
  }
  if ('mapValue' in value) return decodeFields(value.mapValue.fields);
  return null;
}

function decodeFields(fields) {
  const result = {};
  for (const [key, value] of Object.entries(fields || {})) {
    result[key] = decodeValue(value);
  }
  return result;
}

function encodeValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (value instanceof Date) {
    return { timestampValue: value.toISOString() };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encodeValue) } };
  }
  if (typeof value === 'object') {
    return { mapValue: { fields: encodeFields(value) } };
  }
  return { nullValue: null };
}

function encodeFields(fields) {
  const result = {};
  for (const [key, value] of Object.entries(fields || {})) {
    if (value !== undefined) result[key] = encodeValue(value);
  }
  return result;
}

function documentName(projectId, segments) {
  const path = segments.map((part) => encodeURIComponent(part)).join('/');
  return `projects/${encodeURIComponent(
    projectId,
  )}/databases/(default)/documents/${path}`;
}

function documentUrl(projectId, segments) {
  return `${FIRESTORE_BASE}/${documentName(projectId, segments)}`;
}

function documentsRoot(projectId) {
  return `${FIRESTORE_BASE}/projects/${encodeURIComponent(
    projectId,
  )}/databases/(default)/documents`;
}

async function getDocumentRecord(projectId, accessToken, segments) {
  const response = await fetch(documentUrl(projectId, segments), {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (response.status === 404) return null;
  if (!response.ok) {
    throw new Error(`Firestore read failed (${response.status})`);
  }
  const data = await response.json();
  return {
    id: segments[segments.length - 1],
    name: data.name,
    updateTime: data.updateTime,
    data: decodeFields(data.fields),
  };
}

async function getDocument(projectId, accessToken, segments) {
  const record = await getDocumentRecord(projectId, accessToken, segments);
  return record?.data ?? null;
}

async function deleteDocument(projectId, accessToken, segments) {
  const response = await fetch(documentUrl(projectId, segments), {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!response.ok && response.status !== 404) {
    throw new Error(`Firestore delete failed (${response.status})`);
  }
}

async function commitUpdate(
  projectId,
  accessToken,
  record,
  fields,
  updateTime = null,
) {
  const write = {
    update: { name: record.name, fields: encodeFields(fields) },
    updateMask: { fieldPaths: Object.keys(fields) },
  };
  if (updateTime) write.currentDocument = { updateTime };

  const response = await fetch(`${documentsRoot(projectId)}:commit`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ writes: [write] }),
  });

  if (updateTime && [400, 409, 412].includes(response.status)) {
    // Another Worker invocation claimed the job first.
    return false;
  }
  if (!response.ok) {
    throw new Error(`Firestore update failed (${response.status})`);
  }
  return true;
}

async function queryOutbox(projectId, accessToken, status) {
  const body = {
    structuredQuery: {
      from: [{ collectionId: OUTBOX_COLLECTION }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'status' },
          op: 'EQUAL',
          value: { stringValue: status },
        },
      },
      limit: CRON_BATCH_SIZE,
    },
  };

  const response = await fetch(`${documentsRoot(projectId)}:runQuery`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`Firestore query failed (${response.status})`);
  }

  const rows = await response.json();
  return rows
    .filter((row) => row.document)
    .map((row) => ({
      id: row.document.name.split('/').pop(),
      name: row.document.name,
      updateTime: row.document.updateTime,
      data: decodeFields(row.document.fields),
    }));
}

// --- Auth / service account -------------------------------------------------

async function requireUser(request, env, json) {
  const header = request.headers.get('Authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) {
    return { response: json({ error: 'missing bearer token' }, 401, env) };
  }
  try {
    const payload = await verifyIdToken(token, env.FIREBASE_PROJECT_ID);
    return { uid: payload.sub };
  } catch (error) {
    return {
      response: json(
        { error: 'unauthorized', detail: String(error.message) },
        401,
        env,
      ),
    };
  }
}

function serviceAccount(env) {
  try {
    return JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
  } catch {
    return null;
  }
}

async function accessToken(env, account) {
  const key = `${account.client_email}:${account.private_key_id || ''}`;
  if (
    accessTokenCache.key === key &&
    accessTokenCache.expiresAt > Date.now()
  ) {
    return accessTokenCache.token;
  }

  const token = await googleAccessToken(account, NOTIFY_SCOPES);
  accessTokenCache = {
    key,
    token,
    expiresAt: Date.now() + 50 * 60 * 1000,
  };
  return token;
}

async function readJson(request) {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

function requireConfig(env) {
  return Boolean(env.FIREBASE_PROJECT_ID && env.FIREBASE_SERVICE_ACCOUNT);
}

function notifyError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

// --- FCM --------------------------------------------------------------------

function displayName(value, fallback = 'Someone') {
  const name = typeof value === 'string' ? value.trim() : '';
  return name || fallback;
}

function truncate(value, max = 140) {
  const text = typeof value === 'string' ? value.trim() : '';
  if (text.length <= max) return text;
  return `${text.slice(0, max - 1).trimEnd()}…`;
}

function messagePreview(message) {
  if (message.type === 'image') return 'Sent you a photo';
  if (message.type === 'sticker') return 'Sent you a sticker';
  if (message.type === 'voice') return 'Sent you a voice note';
  if (message.type === 'library') return 'Sent you a document';
  return truncate(message.text) || 'Sent you a message';
}

function retryDelay(attempts) {
  const index = Math.max(
    0,
    Math.min(attempts - 1, RETRY_DELAYS_MS.length - 1),
  );
  return RETRY_DELAYS_MS[index];
}

async function sendFcm(env, token, fid, payload) {
  const body = {
    message: {
      token: fid,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: Object.fromEntries(
        Object.entries(payload.data || {}).map(([key, value]) => [
          key,
          String(value),
        ]),
      ),
      android: {
        priority: 'high',
        collapse_key: payload.collapseKey,
        notification: {
          channel_id: CHANNEL_ID,
          icon: ICON,
          color: COLOR,
          tag: payload.tag,
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'alert',
        },
        payload: {
          aps: {
            sound: 'default',
            'thread-id': payload.threadId,
          },
        },
      },
    },
  };

  const response = await fetch(
    `${FCM_BASE}/projects/${encodeURIComponent(
      env.FIREBASE_PROJECT_ID,
    )}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    },
  );

  if (!response.ok) {
    console.error('FCM send failed', response.status, await response.text());
    return false;
  }
  return true;
}

async function recipientToken(env, token, uid) {
  const user = await getDocument(env.FIREBASE_PROJECT_ID, token, ['users', uid]);
  const fid = user?.fcmToken;
  return typeof fid === 'string' && fid.trim() ? fid.trim() : null;
}

// --- Delivery ---------------------------------------------------------------

async function deliverContactRequest(env, token, actorUid, requestId) {
  const contactRequest = await getDocument(
    env.FIREBASE_PROJECT_ID,
    token,
    ['contactRequests', requestId],
  );

  if (!contactRequest) {
    return { sent: 0, reason: 'request not found' };
  }
  if (contactRequest.fromUid !== actorUid) {
    throw notifyError(403, 'not your request');
  }
  if (contactRequest.status !== 'pending') {
    return { sent: 0, reason: 'request is not pending' };
  }

  const fid = await recipientToken(env, token, contactRequest.toUid);
  if (!fid) return { sent: 0, reason: 'recipient has no device' };

  const fromUser = contactRequest.fromUser || {};
  const name = displayName(fromUser.fullName || fromUser.username);
  const sent = await sendFcm(env, token, fid, {
    title: 'New DM request',
    body: `${name} wants to start a chat with you.`,
    data: {
      type: 'contact_request',
      requestId,
      fromUid: actorUid,
    },
    collapseKey: `contact_request_${requestId}`,
    tag: `contact_request_${requestId}`,
    threadId: 'contact_requests',
  });
  if (!sent) throw new Error('FCM send failed');

  return { sent: 1 };
}

async function deliverMessage(env, token, actorUid, chatId, messageId) {
  const chat = await getDocument(env.FIREBASE_PROJECT_ID, token, [
    'chats',
    chatId,
  ]);
  const members = Array.isArray(chat?.members) ? chat.members : [];
  if (!members.includes(actorUid)) {
    throw notifyError(403, 'not a chat member');
  }

  const message = await getDocument(env.FIREBASE_PROJECT_ID, token, [
    'chats',
    chatId,
    'messages',
    messageId,
  ]);
  if (!message) return { sent: 0, reason: 'message not found' };
  if (message.senderId !== actorUid) {
    throw notifyError(403, 'not your message');
  }
  if (message.deleted === true) {
    return { sent: 0, reason: 'message deleted' };
  }

  const recipients = [
    ...new Set(
      members.filter(
        (uid) => typeof uid === 'string' && uid && uid !== actorUid,
      ),
    ),
  ];
  const messageMillis = Date.parse(message.createdAt) || Date.now();
  const clearedAt = chat.clearedAt || {};
  const senderName = displayName(message.senderName);
  const anonymous = message.anonymous === true;

  let sentCount = 0;
  let failures = 0;
  await Promise.all(
    recipients.map(async (uid) => {
      const cleared = Date.parse(clearedAt[uid]);
      if (Number.isFinite(cleared) && cleared >= messageMillis) return;

      const fid = await recipientToken(env, token, uid);
      if (!fid) return;

      const sent = await sendFcm(env, token, fid, {
        title: senderName,
        body: messagePreview(message),
        data: {
          type: 'chat_message',
          chatId,
          messageId,
          ...(anonymous ? {} : { senderId: actorUid }),
        },
        collapseKey: chatId,
        tag: chatId,
        threadId: chatId,
      });
      if (sent) sentCount += 1;
      else failures += 1;
    }),
  );

  // Retry only when at least one FCM request failed. Successful recipients
  // reuse the same collapse key, so a retry updates rather than duplicates.
  if (failures > 0) {
    throw new Error(`${failures} FCM send(s) failed`);
  }
  return { sent: sentCount };
}

async function deliverOutbox(env, token, record) {
  const data = record.data;
  if (data.type === 'contact_request') {
    return deliverContactRequest(env, token, data.actorId, data.requestId);
  }
  if (data.type === 'chat_message') {
    return deliverMessage(
      env,
      token,
      data.actorId,
      data.chatId,
      data.messageId,
    );
  }
  throw new Error('unknown notification type');
}

// --- Outbox -----------------------------------------------------------------

async function claimOutbox(env, token, record) {
  const attempts = Number(record.data.attempts) || 0;
  if (attempts >= MAX_ATTEMPTS) return null;

  const now = Date.now();
  const data = record.data;
  if (data.status === 'sending') {
    const updatedAt = Date.parse(data.updatedAt);
    if (Number.isFinite(updatedAt) && now - updatedAt < STALE_SENDING_MS) {
      return null;
    }
  }

  const claimed = {
    ...data,
    status: 'sending',
    attempts: attempts + 1,
    updatedAt: new Date(now).toISOString(),
    nextAttemptAt: new Date(now + CLAIM_TIMEOUT_MS).toISOString(),
  };
  const ok = await commitUpdate(
    env.FIREBASE_PROJECT_ID,
    token,
    record,
    {
      status: claimed.status,
      attempts: claimed.attempts,
      updatedAt: claimed.updatedAt,
      nextAttemptAt: claimed.nextAttemptAt,
    },
    record.updateTime,
  );
  return ok ? claimed : null;
}

async function completeOutbox(env, token, record, sentCount) {
  const now = new Date().toISOString();
  await commitUpdate(env.FIREBASE_PROJECT_ID, token, record, {
    status: 'sent',
    sentCount,
    sentAt: now,
    updatedAt: now,
    lastError: '',
  });
}

async function failOutbox(env, token, record, attempts, error) {
  const now = Date.now();
  const finalAttempt = attempts >= MAX_ATTEMPTS;
  await commitUpdate(env.FIREBASE_PROJECT_ID, token, record, {
    status: finalAttempt ? 'dead' : 'failed',
    lastError: truncate(error?.message || String(error), 500),
    updatedAt: new Date(now).toISOString(),
    nextAttemptAt: new Date(
      now + (finalAttempt ? 24 * 60 * 60 * 1000 : retryDelay(attempts)),
    ).toISOString(),
    ...(finalAttempt ? { failedAt: new Date(now).toISOString() } : {}),
  });
}

async function processOutboxRecord(env, token, record) {
  const claimed = await claimOutbox(env, token, record);
  if (!claimed) return { processed: false, sentCount: 0 };

  try {
    const result = await deliverOutbox(env, token, {
      ...record,
      data: claimed,
    });
    const sentCount = Number(result.sent) || 0;
    await completeOutbox(env, token, record, sentCount);
    try {
      await deleteDocument(env.FIREBASE_PROJECT_ID, token, [
        OUTBOX_COLLECTION,
        record.id,
      ]);
    } catch (error) {
      // A completed job is harmless if cleanup is delayed.
      console.error('Outbox cleanup failed', record.id, error);
    }
    return { processed: true, sentCount };
  } catch (error) {
    console.error('Outbox delivery failed', record.id, error);
    await failOutbox(env, token, record, claimed.attempts, error);
    return { processed: false, sentCount: 0 };
  }
}

function isOutboxDue(record, now) {
  const data = record.data;
  const attempts = Number(data.attempts) || 0;
  if (attempts >= MAX_ATTEMPTS) return false;

  if (data.status === 'sending') {
    const updatedAt = Date.parse(data.updatedAt);
    return !Number.isFinite(updatedAt) || now - updatedAt >= STALE_SENDING_MS;
  }

  const nextAttemptAt = Date.parse(data.nextAttemptAt);
  return !Number.isFinite(nextAttemptAt) || nextAttemptAt <= now;
}

export async function processNotificationOutbox(env) {
  if (!requireConfig(env)) return { processed: 0, skipped: 0 };

  const account = serviceAccount(env);
  if (!account) return { processed: 0, skipped: 0 };

  try {
    const token = await accessToken(env, account);
    const [pending, failed, sending] = await Promise.all([
      queryOutbox(env.FIREBASE_PROJECT_ID, token, 'pending'),
      queryOutbox(env.FIREBASE_PROJECT_ID, token, 'failed'),
      queryOutbox(env.FIREBASE_PROJECT_ID, token, 'sending'),
    ]);

    const now = Date.now();
    const candidates = [...pending, ...failed, ...sending]
      .filter((record) => isOutboxDue(record, now))
      .sort((a, b) => {
        const aAt = Date.parse(a.data.createdAt) || 0;
        const bAt = Date.parse(b.data.createdAt) || 0;
        return aAt - bAt;
      })
      .slice(0, CRON_BATCH_SIZE);

    let processed = 0;
    for (const record of candidates) {
      const result = await processOutboxRecord(env, token, record);
      if (result.processed) processed += 1;
    }
    return { processed, skipped: candidates.length - processed };
  } catch (error) {
    console.error('Outbox cron failed', error);
    return { processed: 0, error: String(error.message || error) };
  }
}

// --- Routes -----------------------------------------------------------------

export async function handleNotifyOutbox(request, env, json) {
  if (!requireConfig(env)) {
    return json({ error: 'notifications are not configured' }, 500, env);
  }

  const auth = await requireUser(request, env, json);
  if (auth.response) return auth.response;

  const body = await readJson(request);
  const outboxId =
    typeof body?.outboxId === 'string' ? body.outboxId.trim() : '';
  if (!outboxId) {
    return json({ error: 'outboxId is required' }, 400, env);
  }

  const account = serviceAccount(env);
  if (!account) {
    return json({ error: 'invalid service account secret' }, 500, env);
  }

  try {
    const token = await accessToken(env, account);
    const record = await getDocumentRecord(env.FIREBASE_PROJECT_ID, token, [
      OUTBOX_COLLECTION,
      outboxId,
    ]);
    if (!record) {
      return json({ sent: 0, reason: 'outbox not found' }, 404, env);
    }
    if (record.data.actorId !== auth.uid) {
      return json({ error: 'not your notification' }, 403, env);
    }
    if (record.data.status === 'sent') {
      return json({ sent: 0, reason: 'already sent' }, 200, env);
    }

    const result = await processOutboxRecord(env, token, record);
    return json(
      {
        sent: result.sentCount,
        queued: !result.processed,
      },
      200,
      env,
    );
  } catch (error) {
    console.error('Outbox notification failed', error);
    return json({ error: 'notification failed' }, 502, env);
  }
}

export async function handleNotifyContactRequest(request, env, json) {
  if (!requireConfig(env)) {
    return json({ error: 'notifications are not configured' }, 500, env);
  }

  const auth = await requireUser(request, env, json);
  if (auth.response) return auth.response;

  const body = await readJson(request);
  const requestId =
    typeof body?.requestId === 'string' ? body.requestId.trim() : '';
  if (!requestId) {
    return json({ error: 'requestId is required' }, 400, env);
  }

  const account = serviceAccount(env);
  if (!account) {
    return json({ error: 'invalid service account secret' }, 500, env);
  }

  try {
    const token = await accessToken(env, account);
    const result = await deliverContactRequest(
      env,
      token,
      auth.uid,
      requestId,
    );
    return json({ sent: result.sent > 0, reason: result.reason }, 200, env);
  } catch (error) {
    console.error('Contact request notification failed', error);
    return json(
      { error: error.status ? error.message : 'notification failed' },
      error.status || 502,
      env,
    );
  }
}

export async function handleNotifyMessage(request, env, json) {
  if (!requireConfig(env)) {
    return json({ error: 'notifications are not configured' }, 500, env);
  }

  const auth = await requireUser(request, env, json);
  if (auth.response) return auth.response;

  const body = await readJson(request);
  const chatId = typeof body?.chatId === 'string' ? body.chatId.trim() : '';
  const messageId =
    typeof body?.messageId === 'string' ? body.messageId.trim() : '';
  if (!chatId || !messageId) {
    return json({ error: 'chatId and messageId are required' }, 400, env);
  }

  const account = serviceAccount(env);
  if (!account) {
    return json({ error: 'invalid service account secret' }, 500, env);
  }

  try {
    const token = await accessToken(env, account);
    const result = await deliverMessage(
      env,
      token,
      auth.uid,
      chatId,
      messageId,
    );
    return json({ sent: result.sent, reason: result.reason }, 200, env);
  } catch (error) {
    console.error('Chat notification failed', error);
    return json(
      { error: error.status ? error.message : 'notification failed' },
      error.status || 502,
      env,
    );
  }
}
