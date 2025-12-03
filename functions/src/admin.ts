// admin.ts - Firebase Admin SDK initialization

import * as admin from "firebase-admin";

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

export { admin };

