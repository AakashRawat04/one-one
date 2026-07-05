import { config, liveKitConfigured } from "../config.js";
import { isFirebaseAdminConfigured } from "../firebase/adminApp.js";

export function getReadiness() {
  return {
    ok: true,
    service: "one-one-token-api",
    firebaseAdminConfigured: isFirebaseAdminConfigured(),
    firebaseDatabaseConfigured: Boolean(config.FIREBASE_DATABASE_URL),
    liveKitConfigured
  };
}
