import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
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
