import { AwsClient } from 'aws4fetch';

// Signed-URL lifetime, in seconds.
const EXPIRES = 900;

// Path prefix under which the Worker serves stored objects.
const MEDIA_PATH = '/media/';

function cors(env) {
  return {
    'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}

function json(data, status, env) {
  return Response.json(data, { status, headers: cors(env) });
}

// - GET  /health      -> { ok: true }
// - GET  /media/<key> -> streams the object from the R2 bucket
// - POST /sign        -> { key, uploadUrl, publicUrl, expiresIn }
//
// Uploads never pass through the Worker: the app gets a short-lived presigned
// PUT URL, uploads straight to R2, and reads back through /media. The R2
// credentials never leave the Worker.
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
};
