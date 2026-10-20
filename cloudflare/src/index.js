import { AwsClient } from 'aws4fetch';

import {
  handleNotifyContactRequest,
  handleNotifyMessage,
  handleNotifyOutbox,
  processNotificationOutbox,
} from './notify.js';
import { handleVerifySend } from './verify.js';

// Signed-URL lifetime, in seconds.
const EXPIRES = 900;

// Path prefix under which the Worker serves stored objects.
const MEDIA_PATH = '/media/';

function cors(env) {
  return {
    'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
}

function json(data, status, env) {
  return Response.json(data, { status, headers: cors(env) });
}

// - GET  /health      -> { ok: true }
// - GET  /media/<key> -> streams the object from the R2 bucket
// - POST /upload      -> stores the request body in R2 and returns { publicUrl }
// - POST /sign        -> { key, uploadUrl, publicUrl, expiresIn } (legacy)
// - POST /verify/send -> mints a Firebase verification link and emails it
// - POST /notify/outbox          -> processes one queued notification
// - POST /notify/contact-request -> pushes a new DM request (legacy)
// - POST /notify/message         -> pushes a new chat message (legacy)
//
// The scheduled handler retries pending/failed notification outbox jobs.
//
// The app uploads through /upload, which writes to the bucket via the R2
// binding. No S3 credentials are involved for uploads.
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const { pathname } = url;

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors(env) });
    }

    if (request.method === 'GET' && pathname === '/health') {
      return json({ ok: true }, 200, env);
    }

    if (request.method === 'POST' && pathname === '/verify/send') {
      return handleVerifySend(request, env, json);
    }

    if (request.method === 'POST' && pathname === '/notify/outbox') {
      return handleNotifyOutbox(request, env, json);
    }

    if (request.method === 'POST' && pathname === '/notify/contact-request') {
      return handleNotifyContactRequest(request, env, json);
    }

    if (request.method === 'POST' && pathname === '/notify/message') {
      return handleNotifyMessage(request, env, json);
    }

    if (request.method === 'POST' && pathname === '/upload') {
      const filename = url.searchParams.get('filename');
      if (!filename) {
        return json({ error: 'filename is required' }, 400, env);
      }

      const length = Number(request.headers.get('Content-Length') || 0);
      if (length > 20 * 1024 * 1024) {
        return json({ error: 'file is too large' }, 413, env);
      }

      const prefix = env.UPLOAD_PREFIX || 'uploads';
      const safeName =
        filename.replace(/[^a-zA-Z0-9._-]/g, '_').slice(-120) || 'upload';
      const key = `${prefix}/${crypto.randomUUID()}-${safeName}`;
      const contentType =
        request.headers.get('Content-Type') || 'application/octet-stream';

      await env.BUCKET.put(key, await request.arrayBuffer(), {
        httpMetadata: {
          contentType,
          cacheControl: 'public, max-age=31536000, immutable',
        },
      });

      return json(
        {
          key,
          publicUrl: `${url.origin}${MEDIA_PATH}${key}`,
        },
        200,
        env,
      );
    }

    if (request.method === 'GET' && pathname.startsWith(MEDIA_PATH)) {
      const key = decodeURIComponent(pathname.slice(MEDIA_PATH.length));
      if (!key) {
        return new Response('Not found', { status: 404, headers: cors(env) });
      }

      const object = await env.BUCKET.get(key);
      if (object === null) {
        return new Response('Not found', { status: 404, headers: cors(env) });
      }

      const headers = new Headers(cors(env));
      object.writeHttpMetadata(headers);
      headers.set('etag', object.httpEtag);
      headers.set('Cache-Control', 'public, max-age=31536000, immutable');
      return new Response(object.body, { headers });
    }

    if (request.method === 'POST' && pathname === '/sign') {
      let body;
      try {
        body = await request.json();
      } catch {
        return json({ error: 'invalid JSON body' }, 400, env);
      }

      const { filename, contentType } = body ?? {};
      if (!filename) {
        return json({ error: 'filename is required' }, 400, env);
      }

      const prefix = env.UPLOAD_PREFIX || 'uploads';
      const key = `${prefix}/${crypto.randomUUID()}-${filename}`;

      const aws = new AwsClient({
        accessKeyId: env.R2_ACCESS_KEY_ID,
        secretAccessKey: env.R2_SECRET_ACCESS_KEY,
        service: 's3',
        region: 'auto',
      });

      const objectUrl =
        `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com/` +
        `${env.R2_BUCKET}/${key}`;

      // The expiry must live in the query string before signing, otherwise
      // aws4fetch adds it to SignedHeaders and the PUT fails signature checks.
      const signUrl = new URL(objectUrl);
      signUrl.searchParams.set('X-Amz-Expires', String(EXPIRES));

      const signed = await aws.sign(
        new Request(signUrl, {
          method: 'PUT',
          headers: contentType ? { 'Content-Type': contentType } : {},
        }),
        { aws: { signQuery: true } },
      );

      return json(
        {
          key,
          uploadUrl: signed.url,
          publicUrl: `${url.origin}${MEDIA_PATH}${key}`,
          expiresIn: EXPIRES,
        },
        200,
        env,
      );
    }

    return json({ error: 'not found' }, 404, env);
  },

  async scheduled(_controller, env, ctx) {
    ctx.waitUntil(processNotificationOutbox(env));
  },
};
