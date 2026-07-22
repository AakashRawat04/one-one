import { getStorage } from "firebase-admin/storage";
import { requireFirebaseAdminApp } from "./adminApp.js";
import { maxVoiceNudgeBytes } from "../notifications/voiceNudgeValidation.js";

export const voiceNudgeUploadContentType = "audio/mp4";

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

/**
 * Short-lived V4 write URL so the sender uploads audio directly to Cloud
 * Storage. Bound content-type and byte range into the signature so the
 * backend never receives raw audio bytes.
 */
export async function createVoiceNudgeSignedWriteUrl(
  storagePath: string,
  expiresAtMs: number,
  maxBytes = maxVoiceNudgeBytes
) {
  const contentLengthRange = `1,${maxBytes}`;
  const file = getVoiceNudgeBucket().file(storagePath);
  const [url] = await file.getSignedUrl({
    version: "v4",
    action: "write",
    expires: expiresAtMs,
    contentType: voiceNudgeUploadContentType,
    extensionHeaders: {
      "x-goog-content-length-range": contentLengthRange
    }
  });
  return {
    uploadUrl: url,
    contentType: voiceNudgeUploadContentType,
    requiredHeaders: {
      "content-type": voiceNudgeUploadContentType,
      "x-goog-content-length-range": contentLengthRange
    }
  };
}
