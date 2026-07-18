import { applicationDefault, cert, getApp, getApps, initializeApp, type App } from "firebase-admin/app";
import { config, firebaseServiceAccountConfigured } from "../config.js";
import { HttpError } from "../http/httpError.js";

function normalizePrivateKey(privateKey: string) {
  return privateKey.replace(/\\n/g, "\n");
}

export function isFirebaseAdminConfigured() {
  return firebaseServiceAccountConfigured || Boolean(process.env.GOOGLE_APPLICATION_CREDENTIALS);
}

export function getFirebaseAdminApp(): App | null {
  if (!isFirebaseAdminConfigured()) {
    return null;
  }

  if (getApps().length > 0) {
    return getApp();
  }

  const options = {
    databaseURL: config.FIREBASE_DATABASE_URL,
    storageBucket:
      config.FIREBASE_STORAGE_BUCKET ??
      (config.FIREBASE_PROJECT_ID
        ? `${config.FIREBASE_PROJECT_ID}.firebasestorage.app`
        : undefined)
  };

  if (firebaseServiceAccountConfigured) {
    return initializeApp({
      ...options,
      credential: cert({
        projectId: config.FIREBASE_PROJECT_ID!,
        clientEmail: config.FIREBASE_CLIENT_EMAIL!,
        privateKey: normalizePrivateKey(config.FIREBASE_PRIVATE_KEY!)
      })
    });
  }

  return initializeApp({
    ...options,
    credential: applicationDefault()
  });
}

export function requireFirebaseAdminApp() {
  const app = getFirebaseAdminApp();

  if (!app) {
    throw new HttpError(
      503,
      "firebase_not_configured",
      "Firebase Admin is not configured. Set GOOGLE_APPLICATION_CREDENTIALS or Firebase service-account env vars."
    );
  }

  return app;
}
