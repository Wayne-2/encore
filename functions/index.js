'use strict';

/**
 * Sends the Encore email-verification email.
 *
 * Flow: the Flutter app calls this callable after registration →
 * the Firebase Admin SDK generates the verification link →
 * the link is emailed through Brevo's SMTP relay.
 *
 * Secrets (never committed) are bound to the function:
 *   firebase functions:secrets:set BREVO_SMTP_LOGIN
 *   firebase functions:secrets:set BREVO_SMTP_KEY
 *
 * Optional non-secret env (functions/.env):
 *   MAIL_FROM, MAIL_FROM_NAME, APP_CONTINUE_URL
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// --- Brevo (SMTP relay) -----------------------------------------------------
const BREVO_SMTP_LOGIN = defineSecret('BREVO_SMTP_LOGIN');
const BREVO_SMTP_KEY = defineSecret('BREVO_SMTP_KEY');

const BREVO_SMTP_HOST = 'smtp-relay.brevo.com';
const BREVO_SMTP_PORT = 587;

// --- Sender / links ---------------------------------------------------------
const MAIL_FROM = process.env.MAIL_FROM || 'verify@yourdomain.com';
const MAIL_FROM_NAME = process.env.MAIL_FROM_NAME || 'Encore';
const APP_CONTINUE_URL = process.env.APP_CONTINUE_URL || '';

function buildEmail(link, name) {
  const greeting = name ? `Hi ${name},` : 'Hi there,';
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
            <tr>
              <td align="center" style="color:#ffffff;font-size:20px;font-weight:700;letter-spacing:0.3px;">Encore</td>
            </tr>
            <tr>
              <td style="padding-top:20px;color:#ffffff;font-size:15px;">${greeting}</td>
            </tr>
            <tr>
              <td style="padding-top:12px;color:#b3b3b3;font-size:14px;line-height:1.5;">
                Confirm your email address to finish setting up your Encore account.
              </td>
            </tr>
            <tr>
              <td align="center" style="padding-top:28px;">
                <a href="${link}" style="display:inline-block;background:#25A10C;color:#ffffff;text-decoration:none;font-size:14px;font-weight:600;padding:12px 28px;border-radius:4px;">
                  Verify email
                </a>
              </td>
            </tr>
            <tr>
              <td style="padding-top:24px;color:#b3b3b3;font-size:12px;line-height:1.5;">
                If the button doesn't work, copy and paste this link into your browser:<br/>
                <a href="${link}" style="color:#25A10C;word-break:break-all;">${link}</a>
              </td>
            </tr>
            <tr>
              <td style="padding-top:20px;color:#b3b3b3;font-size:12px;">
                If you didn't create an Encore account you can ignore this email.
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;

  return { text, html };
}

exports.sendVerificationEmail = onCall(
  { secrets: [BREVO_SMTP_LOGIN, BREVO_SMTP_KEY], region: 'us-central1' },
  async (request) => {
    const auth = request.auth;
    if (!auth) {
      throw new HttpsError(
        'unauthenticated',
        'Sign in before requesting a verification email.',
      );
    }

    // Trust the token's email first; only fall back to the client payload.
    const email = auth.token.email || (request.data && request.data.email);
    if (!email) {
      throw new HttpsError('invalid-argument', 'No email address available.');
    }

    const actionCodeSettings = APP_CONTINUE_URL
      ? { url: APP_CONTINUE_URL, handleCodeInApp: false }
      : undefined;

    let link;
    try {
      link = await admin
        .auth()
        .generateEmailVerificationLink(email, actionCodeSettings);
    } catch (error) {
      logger.error('generateEmailVerificationLink failed', error);
      if (error.code === 'auth/user-not-found') {
        throw new HttpsError('not-found', 'No account found for that email.');
      }
      throw new HttpsError('internal', 'Could not create a verification link.');
    }

    const transport = nodemailer.createTransport({
      host: BREVO_SMTP_HOST,
      port: BREVO_SMTP_PORT,
      secure: false,
      auth: {
        user: BREVO_SMTP_LOGIN.value(),
        pass: BREVO_SMTP_KEY.value(),
      },
    });

    const { text, html } = buildEmail(link, auth.token.name);

    try {
      await transport.sendMail({
        from: `"${MAIL_FROM_NAME}" <${MAIL_FROM}>`,
        to: email,
        subject: 'Verify your Encore email',
        text,
        html,
      });
    } catch (error) {
      logger.error('Brevo send failed', error);
      throw new HttpsError('internal', 'Could not send the verification email.');
    }

    return { sent: true, email };
  },
);
