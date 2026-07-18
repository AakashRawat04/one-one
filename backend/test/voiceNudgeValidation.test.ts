import assert from "node:assert/strict";
import test from "node:test";
import { HttpError } from "../src/http/httpError.js";
import {
  createDeliveryToken,
  deliveryTokenMatches,
  hashDeliveryToken,
  maxVoiceNudgeBytes,
  validateVoiceNudgeAudio
} from "../src/notifications/voiceNudgeValidation.js";

function m4aFixture(size = 32) {
  const audio = Buffer.alloc(size);
  audio.writeUInt32BE(size, 0);
  audio.write("ftyp", 4, "ascii");
  return audio;
}

test("voice nudge validation accepts a bounded M4A recording", () => {
  assert.doesNotThrow(() => validateVoiceNudgeAudio(m4aFixture(), 5_900));
});

test("voice nudge validation rejects oversized, long, and non-M4A bodies", () => {
  for (const action of [
    () => validateVoiceNudgeAudio(m4aFixture(maxVoiceNudgeBytes + 1), 1_000),
    () => validateVoiceNudgeAudio(m4aFixture(), 6_001),
    () => validateVoiceNudgeAudio(Buffer.from("not audio"), 1_000)
  ]) {
    assert.throws(action, (error) => error instanceof HttpError);
  }
});

test("delivery tokens are high entropy and compared against their hash", () => {
  const token = createDeliveryToken();
  assert.ok(token.length >= 40);
  const hash = hashDeliveryToken(token);
  assert.equal(deliveryTokenMatches(token, hash), true);
  assert.equal(deliveryTokenMatches(`${token}x`, hash), false);
});
