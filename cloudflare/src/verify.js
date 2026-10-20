// Email verification for Encore.
//
// POST /verify/send  (Authorization: Bearer <Firebase ID token>)
//   1. Verifies the caller's Firebase ID token (RS256 via Google's JWKS).
//   2. Mints a verification link with the Firebase Admin REST API
//      (`accounts:sendOobCode` + `returnOobLink`), authenticated with the
//      project's service-account key.
//   3. Sends the link through Brevo's transactional email HTTP API.
//
// Secrets (set with `npx wrangler secret put <NAME>`):
//   FIREBASE_SERVICE_ACCOUNT  — the service-account JSON, stringified
//   BREVO_API_KEY             — Brevo transactional API key (xkeysib-…)
//
// Vars (wrangler.toml):
//   FIREBASE_PROJECT_ID, MAIL_FROM, MAIL_FROM_NAME, APP_CONTINUE_URL

const JWKS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const IDENTITY_TOOLKIT_URL =
  'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode';
const BREVO_API_URL = 'https://api.brevo.com/v3/smtp/email';

const IDENTITYTOOLKIT_SCOPE =
  'https://www.googleapis.com/auth/identitytoolkit';

let jwksCache = { keys: null, expiresAt: 0 };

// --- base64url helpers ------------------------------------------------------

function base64UrlToBytes(value) {
  const base64 = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, '=');
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function base64UrlEncode(bytes) {
  let binary = '';
  const view = new Uint8Array(bytes);
  for (let i = 0; i < view.length; i += 1) {
    binary += String.fromCharCode(view[i]);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function decodeJwtPart(part) {
  return JSON.parse(new TextDecoder().decode(base64UrlToBytes(part)));
}

function pemToBytes(pem) {
  const base64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

// --- Firebase ID token verification ----------------------------------------

async function getSigningKeys() {
  const now = Date.now();
  if (jwksCache.keys && jwksCache.expiresAt > now) {
    return jwksCache.keys;
  }
  const response = await fetch(JWKS_URL);
  if (!response.ok) {
    throw new Error('Could not fetch Firebase signing keys');
  }
  const data = await response.json();
  jwksCache = { keys: data.keys, expiresAt: now + 60 * 60 * 1000 };
  return data.keys;
}

export async function verifyIdToken(token, projectId) {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new Error('malformed token');
  }
  const [headerPart, payloadPart, signaturePart] = parts;
  const header = decodeJwtPart(headerPart);
  const payload = decodeJwtPart(payloadPart);

  if (header.alg !== 'RS256') {
    throw new Error('unexpected signing algorithm');
  }

  const keys = await getSigningKeys();
  const jwk = keys.find((key) => key.kid === header.kid);
  if (!jwk) {
    throw new Error('unknown signing key');
  }

  const key = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );

  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    base64UrlToBytes(signaturePart),
    new TextEncoder().encode(`${headerPart}.${payloadPart}`),
  );
  if (!valid) {
    throw new Error('bad signature');
  }

  const now = Math.floor(Date.now() / 1000);
  if (payload.exp <= now) {
    throw new Error('token expired');
  }
  if (payload.aud !== projectId) {
    throw new Error('bad audience');
  }
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
    throw new Error('bad issuer');
  }
  if (!payload.sub) {
    throw new Error('missing subject');
  }
  return payload;
}

// --- Link generation (Admin REST) -------------------------------------------

export async function googleAccessToken(
  serviceAccount,
  scope = IDENTITYTOOLKIT_SCOPE,
) {
  const now = Math.floor(Date.now() / 1000);
  const encoder = new TextEncoder();
  const unsigned = `${base64UrlEncode(
    encoder.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })),
  )}.${base64UrlEncode(
    encoder.encode(
      JSON.stringify({
        iss: serviceAccount.client_email,
        scope,
        aud: GOOGLE_TOKEN_URL,
        iat: now,
        exp: now + 3600,
      }),
    ),
  )}`;

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBytes(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    encoder.encode(unsigned),
  );

  const response = await fetch(GOOGLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${base64UrlEncode(signature)}`,
    }),
  });
  if (!response.ok) {
    throw new Error(`Google token exchange failed (${response.status})`);
  }
  const data = await response.json();
  return data.access_token;
}

async function generateVerificationLink(serviceAccount, email, continueUrl) {
  const accessToken = await googleAccessToken(serviceAccount);
  const body = { requestType: 'VERIFY_EMAIL', email, returnOobLink: true };
  if (continueUrl) {
    body.continueUrl = continueUrl;
  }

  const response = await fetch(IDENTITY_TOOLKIT_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok || !data.oobLink) {
    throw new Error(
      `sendOobCode failed (${response.status}): ${data.error?.message ?? 'no link'}`,
    );
  }
  return data.oobLink;
}

// --- Brevo ------------------------------------------------------------------

function buildEmail(link, name, env) {
  const greeting = name ? `Hi ${name},` : 'Hi there,';
  const appName = env.MAIL_FROM_NAME || 'Encore';
  const text = [
    greeting,
    '',
    'Confirm your email address to finish setting up your Encore account.',
    '',
    link,
    '',
    "If you didn't create an Encore account you can ignore this email.",
  ].join('\n');

  const html = `<!doctype html>
<html>
  <body style="margin:0;padding:0;background:#121212;font-family:Helvetica,Arial,sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#121212;padding:32px 0;">
      <tr>
        <td align="center">
          <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="background:#181818;border:1px solid rgba(255,255,255,0.1);border-radius:14px;padding:32px;">
            <tr><td align="center" style="color:#ffffff;font-size:20px;font-weight:700;">${appName}</td></tr>
            <tr><td style="padding-top:20px;color:#ffffff;font-size:15px;">${greeting}</td></tr>
            <tr><td style="padding-top:12px;color:#b3b3b3;font-size:14px;line-height:1.5;">Confirm your email address to finish setting up your Encore account.</td></tr>
            <tr><td align="center" style="padding-top:28px;">
              <a href="${link}" style="display:inline-block;background:#25A10C;color:#ffffff;text-decoration:none;font-size:14px;font-weight:600;padding:12px 28px;border-radius:4px;">Verify email</a>
            </td></tr>
            <tr><td style="padding-top:24px;color:#b3b3b3;font-size:12px;line-height:1.5;">
              If the button doesn't work, copy and paste this link into your browser:<br/>
              <a href="${link}" style="color:#25A10C;word-break:break-all;">${link}</a>
            </td></tr>
            <tr><td style="padding-top:20px;color:#b3b3b3;font-size:12px;">If you didn't create an Encore account you can ignore this email.</td></tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;

  return { text, html };
}

async function sendViaBrevo(env, email, link, name) {
  const { text, html } = buildEmail(link, name, env);
  const response = await fetch(BREVO_API_URL, {
    method: 'POST',
    headers: {
      'api-key': env.BREVO_API_KEY,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      sender: {
        name: env.MAIL_FROM_NAME || 'Encore',
        email: env.MAIL_FROM || 'verify@yourdomain.com',
      },
      to: [{ email }],
      subject: 'Verify your Encore email',
      htmlContent: html,
      textContent: text,
    }),
  });
  if (!response.ok) {
    throw new Error(`Brevo send failed (${response.status})`);
  }
}

// --- Route handler ----------------------------------------------------------

export async function handleVerifySend(request, env, json) {
  const auth = request.headers.get('Authorization') || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  if (!token) {
    return json({ error: 'missing bearer token' }, 401, env);
  }
  if (!env.FIREBASE_PROJECT_ID || !env.FIREBASE_SERVICE_ACCOUNT) {
    return json({ error: 'verification is not configured' }, 500, env);
  }

  let payload;
  try {
    payload = await verifyIdToken(token, env.FIREBASE_PROJECT_ID);
  } catch (error) {
    return json({ error: 'unauthorized', detail: String(error.message) }, 401, env);
  }

  const email = payload.email;
  if (!email) {
    return json({ error: 'no email on token' }, 400, env);
  }

  let serviceAccount;
  try {
    serviceAccount = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
  } catch {
    return json({ error: 'invalid service account secret' }, 500, env);
  }

  let link;
  try {
    link = await generateVerificationLink(
      serviceAccount,
      email,
      env.APP_CONTINUE_URL,
    );
  } catch (error) {
    return json({ error: 'link_failed', detail: String(error.message) }, 502, env);
  }

  try {
    await sendViaBrevo(env, email, link, payload.name);
  } catch (error) {
    return json({ error: 'send_failed', detail: String(error.message) }, 502, env);
  }

  return json({ sent: true, email }, 200, env);
}
