const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');

initializeApp();

const db = getFirestore();
const PUBLIC_PRODUCT_PREFIX = 'product_images/';
const CONTACT_WINDOW_MS = 60 * 60 * 1000;
const CONTACT_MAX_PER_WINDOW = 5;

async function verifyStaffMediaAccess(req) {
  const authHeader = req.headers.authorization || '';
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) return false;

  try {
    const decoded = await getAuth().verifyIdToken(match[1]);
    const claimRole = decoded.role || '';
    if (claimRole === 'admin' || claimRole === 'employee') return true;

    const userSnap = await db.collection('users').doc(decoded.uid).get();
    if (!userSnap.exists) return false;
    const firestoreRole = userSnap.data().role || 'client';
    return firestoreRole === 'admin' || firestoreRole === 'employee';
  } catch (_) {
    return false;
  }
}

// Firestore (default) is eur3 — deploy this trigger in europe-west1, not us-central1.
exports.syncUserRoleToClaims = onDocumentWritten(
  {
    document: 'users/{userId}',
    region: 'europe-west1',
  },
  async (event) => {
    const userId = event.params.userId;
    const after = event.data?.after;

    if (!after?.exists) {
      return null;
    }

    const role = after.data().role || 'client';
    await getAuth().setCustomUserClaims(userId, { role });
    return null;
  },
);

// Callable backfill when JWT custom claims are missing (e.g. user doc predates the trigger).
exports.syncMyRoleClaims = onCall({ region: 'europe-west1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const uid = request.auth.uid;
  const userSnap = await db.collection('users').doc(uid).get();

  if (!userSnap.exists) {
    throw new HttpsError('not-found', 'User profile not found.');
  }

  const role = userSnap.data().role || 'client';
  await getAuth().setCustomUserClaims(uid, { role });
  return { role };
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

/// Same-origin product photos for web — avoids Chrome profiles/extensions blocking googleapis.com.
exports.productMedia = onRequest({ region: 'europe-west1' }, async (req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.status(405).end();
    return;
  }

  let objectPath = req.path.startsWith('/media/') ? req.path.slice('/media/'.length) : req.path;
  try {
    objectPath = decodeURIComponent(objectPath);
  } catch (_) {
    res.status(400).end();
    return;
  }

  if (!objectPath.startsWith(PUBLIC_PRODUCT_PREFIX)) {
    res.status(404).end();
    return;
  }

  const fileName = objectPath.split('/').pop() || '';
  const isBarcode = fileName === 'barcode.jpg';

  if (isBarcode) {
    const allowed = await verifyStaffMediaAccess(req);
    if (!allowed) {
      res.status(403).end();
      return;
    }
  }

  try {
    const file = getStorage().bucket().file(objectPath);
    const [exists] = await file.exists();
    if (!exists) {
      res.status(404).end();
      return;
    }

    res.set('Cache-Control', isBarcode ? 'private, max-age=3600' : 'public, max-age=86400');
    res.set('Content-Type', 'image/jpeg');

    if (req.method === 'HEAD') {
      res.status(200).end();
      return;
    }

    file.createReadStream().on('error', () => {
      if (!res.headersSent) res.status(404).end();
    }).pipe(res);
  } catch (_) {
    if (!res.headersSent) res.status(500).end();
  }
});
