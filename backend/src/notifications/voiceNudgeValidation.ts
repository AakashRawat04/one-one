import { createHash, createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import { HttpError } from "../http/httpError.js";

export const maxVoiceNudgeBytes = 96 * 1024;
export const maxVoiceNudgeDurationMs = 6_000;
export const minVoiceNudgeDurationMs = 250;

export function validateVoiceNudgeDuration(durationMs: number) {
  if (
    !Number.isFinite(durationMs) ||
    durationMs < minVoiceNudgeDurationMs ||
    durationMs > maxVoiceNudgeDurationMs
  ) {
    throw new HttpError(
      400,
      "invalid_voice_nudge_duration",
      `Voice nudges must be between ${minVoiceNudgeDurationMs}ms and ${maxVoiceNudgeDurationMs}ms.`
    );
  }
}

export function validateVoiceNudgeAudioBytes(audio: Buffer) {
  if (audio.length === 0 || audio.length > maxVoiceNudgeBytes) {
    throw new HttpError(
      413,
      "voice_nudge_too_large",
      `Voice nudge audio must not exceed ${maxVoiceNudgeBytes} bytes.`
    );
  }

  // An M4A/MP4 file starts with a box length followed by the `ftyp` marker.
  if (audio.length < 12 || audio.subarray(4, 8).toString("ascii") !== "ftyp") {
    throw new HttpError(400, "invalid_voice_nudge_audio", "Voice nudge must be an M4A file.");
  }
}

export function validateVoiceNudgeAudio(audio: Buffer, durationMs: number) {
  validateVoiceNudgeDuration(durationMs);
  validateVoiceNudgeAudioBytes(audio);
}

export function createDeliveryToken() {
  return randomBytes(32).toString("base64url");
}

export function hashDeliveryToken(token: string) {
  return createHash("sha256").update(token, "utf8").digest("hex");
}

export function deliveryTokenMatches(token: string, expectedHash: string) {
  const actual = Buffer.from(hashDeliveryToken(token), "hex");
  const expected = Buffer.from(expectedHash, "hex");
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

// ---------------------------------------------------------------------------
// Upload ticket: replaces all RTDB state for the voice-nudge upload flow.
// The client reads group members, FCM tokens and display names from RTDB
// directly (frontend-only), then sends them to the backend.  The backend
// seals everything into an HMAC-signed ticket that the client echoes back
// in the /complete call.  No RTDB read or write ever touches the server.
// ---------------------------------------------------------------------------

const uploadTicketSecret = (() => {
  // In production set VOICE_UPLOAD_TICKET_SECRET; fallback is acceptable in
  // single-process environments but will break across restarts/workers.
  if (process.env.VOICE_UPLOAD_TICKET_SECRET) {
    return Buffer.from(process.env.VOICE_UPLOAD_TICKET_SECRET, "base64url");
  }
  // Ephemeral secret – tickets won't survive a restart.  Fine for dev.
  return randomBytes(32);
})();

export type UploadTicket = {
  eventId: string;
  groupId: string;
  senderUserId: string;
  targetScope: "single_friend" | "all_friends";
  targetUserId?: string;
  recipientDevices: Array<{ userId: string; deviceId: string; fcmToken: string }>;
  recipientUserIds: string[];
  senderName: string;
  durationMs: number;
  storagePath: string;
  expiresAt: number;
  uploadExpiresAt: number;
  iat: number; // issued-at – prevents replay after expiry
};

export function createUploadTicket(payload: Omit<UploadTicket, "iat">): string {
  const full: UploadTicket = { ...payload, iat: nowSeconds() };
  const json = JSON.stringify(full);
  const encoded = Buffer.from(json, "utf8").toString("base64url");
  const sig = createHmac("sha256", uploadTicketSecret).update(encoded).digest("base64url");
  return `${encoded}.${sig}`;
}

export function verifyUploadTicket(ticket: string): UploadTicket {
  const dot = ticket.lastIndexOf(".");
  if (dot < 0) {
    throw new HttpError(403, "invalid_upload_ticket", "Upload ticket is malformed.");
  }
  const encoded = ticket.slice(0, dot);
  const sig = ticket.slice(dot + 1);

  const expected = createHmac("sha256", uploadTicketSecret).update(encoded).digest("base64url");
  const sigBuf = Buffer.from(sig, "base64url");
  const expBuf = Buffer.from(expected, "base64url");
  if (sigBuf.length !== expBuf.length || !timingSafeEqual(sigBuf, expBuf)) {
    throw new HttpError(403, "invalid_upload_ticket", "Upload ticket signature is invalid.");
  }

  let raw: unknown;
  try {
    raw = JSON.parse(Buffer.from(encoded, "base64url").toString("utf8"));
  } catch {
    throw new HttpError(403, "invalid_upload_ticket", "Upload ticket payload is corrupt.");
  }

  if (!isUploadTicket(raw)) {
    throw new HttpError(403, "invalid_upload_ticket", "Upload ticket payload is invalid.");
  }

  return raw;
}

function isUploadTicket(value: unknown): value is UploadTicket {
  if (!isRecord(value)) return false;
  return (
    typeof value.eventId === "string" &&
    typeof value.groupId === "string" &&
    typeof value.senderUserId === "string" &&
    (value.targetScope === "single_friend" || value.targetScope === "all_friends") &&
    Array.isArray(value.recipientDevices) &&
    value.recipientDevices.every(
      (d: unknown) =>
        isRecord(d) &&
        typeof (d as Record<string, unknown>).userId === "string" &&
        typeof (d as Record<string, unknown>).deviceId === "string" &&
        typeof (d as Record<string, unknown>).fcmToken === "string"
    ) &&
    Array.isArray(value.recipientUserIds) &&
    value.recipientUserIds.every((id: unknown) => typeof id === "string") &&
    typeof value.senderName === "string" &&
    typeof value.durationMs === "number" &&
    typeof value.storagePath === "string" &&
    typeof value.expiresAt === "number" &&
    typeof value.uploadExpiresAt === "number" &&
    typeof value.iat === "number"
  );
}

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
