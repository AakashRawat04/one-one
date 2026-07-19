import { getStorage } from "firebase-admin/storage";
import { requireFirebaseAdminApp } from "./adminApp.js";

export function getVoiceNudgeBucket() {
  return getStorage(requireFirebaseAdminApp()).bucket();
}
