const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

initializeApp();

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
