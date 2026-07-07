import { config, liveKitConfigured } from "../config.js";
import { isFirebaseAdminConfigured } from "../firebase/adminApp.js";

export function getReadiness() {
  return {
    ok: true,
    service: "one-one-token-api",
    firebaseAdminConfigured: isFirebaseAdminConfigured(),
    firebaseDatabaseConfigured: Boolean(config.FIREBASE_DATABASE_URL),
    firebaseProjectId: config.FIREBASE_PROJECT_ID ?? null,
    firebaseDatabaseHost: readHost(config.FIREBASE_DATABASE_URL),
    liveKitConfigured
  };
}

function readHost(url: string | undefined) {
  if (!url) return null;

  try {
    return new URL(url).host;
  } catch {
    return null;
  }
}
