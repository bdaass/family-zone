const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

initializeApp();

const db = getFirestore();

const CONTACT_WINDOW_MS = 60 * 60 * 1000;
const CONTACT_MAX_PER_WINDOW = 5;

exports.syncUserRoleToClaims = onDocumentWritten('users/{userId}', async (event) => {
  const userId = event.params.userId;
  const after = event.data?.after;

  if (!after?.exists) {
    return null;
  }

  const role = after.data().role || 'client';
  await getAuth().setCustomUserClaims(userId, { role });
  return null;
});

exports.submitContactMessage = onCall(async (request) => {
  const data = request.data ?? {};
  const message = typeof data.message === 'string' ? data.message.trim() : '';
  const anonymous = data.anonymous === true;

  if (!message || message.length > 2000) {
    throw new HttpsError('invalid-argument', 'Message must be between 1 and 2000 characters.');
  }

  const uid = request.auth?.uid ?? null;
  const clientKey = uid ?? `ip:${request.rawRequest?.ip ?? 'unknown'}`;
  const rateRef = db.collection('_rate_limits').doc(`contact_${clientKey}`);
  const now = Date.now();

  await db.runTransaction(async (tx) => {
    const rateSnap = await tx.get(rateRef);
    let count = 0;
    let windowStart = now;

    if (rateSnap.exists) {
      const rateData = rateSnap.data();
      windowStart = rateData.windowStart ?? now;
      count = rateData.count ?? 0;

      if (now - windowStart < CONTACT_WINDOW_MS) {
        if (count >= CONTACT_MAX_PER_WINDOW) {
          throw new HttpsError(
            'resource-exhausted',
            'Too many messages. Please try again later.',
          );
        }
        count += 1;
      } else {
        windowStart = now;
        count = 1;
      }
    } else {
      count = 1;
    }

    tx.set(rateRef, { windowStart, count, updatedAt: FieldValue.serverTimestamp() });

    const doc = {
      message,
      anonymous,
      createdAt: FieldValue.serverTimestamp(),
    };

    if (anonymous) {
      doc.name = null;
      doc.email = null;
      doc.phone = null;
      doc.userId = null;
    } else {
      const name = typeof data.name === 'string' ? data.name.trim() : '';
      const email = typeof data.email === 'string' ? data.email.trim() : '';
      const phone = typeof data.phone === 'string' ? data.phone.trim() : '';

      if (!name) {
        throw new HttpsError('invalid-argument', 'Name is required.');
      }
      if (!email) {
        throw new HttpsError('invalid-argument', 'Email is required.');
      }

      doc.name = name;
      doc.email = email;
      doc.phone = phone || null;
      doc.userId = uid;
    }

    const messageRef = db.collection('contact_messages').doc();
    tx.set(messageRef, doc);
  });

  return { ok: true };
});
