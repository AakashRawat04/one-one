import { getStorage } from "firebase-admin/storage";
import { requireFirebaseAdminApp } from "./adminApp.js";

export function getVoiceNudgeBucket() {
  return getStorage(requireFirebaseAdminApp()).bucket();
}

/**
 * Short-lived V4 read URL so recipients download voice nudge audio
 * directly from Cloud Storage (no backend audio proxy / double egress).
 * Storage security rules stay closed; signed URLs bypass them.
 */
export async function createVoiceNudgeSignedReadUrl(
  storagePath: string,
  expiresAtMs: number
) {
  const file = getVoiceNudgeBucket().file(storagePath);
  const [url] = await file.getSignedUrl({
    version: "v4",
    action: "read",
    expires: expiresAtMs,
    responseType: "audio/mp4",
    responseDisposition: "inline"
  });
  return url;
}
