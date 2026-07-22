import { randomUUID } from "node:crypto";
import { sendAndroidDataPushes } from "../firebase/messaging.js";
import {
  getVoiceNudgeBucket,
  createVoiceNudgeSignedReadUrl,
  createVoiceNudgeSignedWriteUrl,
  voiceNudgeUploadContentType
} from "../firebase/storage.js";
import { config } from "../config.js";
import { HttpError } from "../http/httpError.js";
import { logger } from "../logger.js";
import {
  createDeliveryToken,
  createUploadTicket,
  deliveryTokenMatches,
  hashDeliveryToken,
  maxVoiceNudgeBytes,
  validateVoiceNudgeAudio,
  validateVoiceNudgeDuration,
  verifyUploadTicket,
  type UploadTicket
} from "./voiceNudgeValidation.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type NudgeTarget = {
  targetScope: "single_friend" | "all_friends";
  targetUserId?: string;
};

type RecipientDevice = {
  userId: string;
  deviceId: string;
  fcmToken: string;
};

export type CreateVoiceNudgeInput = NudgeTarget & {
  groupId: string;
  senderUserId: string;
  audio: Buffer;
  durationMs: number;
};

export type InitiateVoiceNudgeUploadInput = NudgeTarget & {
  groupId: string;
  senderUserId: string;
  durationMs: number;
  recipientDevices: RecipientDevice[];
  senderName: string;
};

export type CompleteVoiceNudgeUploadInput = {
  uploadTicket: string;
};

export type SendRingNudgeInput = NudgeTarget & {
  groupId: string;
  senderUserId: string;
  durationSeconds: 3 | 5 | 10;
  recipientDevices: RecipientDevice[];
  senderName: string;
};

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const voiceNudgeMediaTtlSeconds = 10 * 60;
const voiceNudgeUploadUrlTtlSeconds = 5 * 60;
const voiceNudgePushTtlMs = 60 * 1000;
const ringNudgePushTtlMs = 30 * 1000;

// ---------------------------------------------------------------------------
// initiateVoiceNudgeUpload — ZERO RTDB calls
// ---------------------------------------------------------------------------

export async function initiateVoiceNudgeUpload(input: InitiateVoiceNudgeUploadInput) {
  validateVoiceNudgeDuration(input.durationMs);

  if (!input.recipientDevices || input.recipientDevices.length === 0) {
    throw new HttpError(400, "no_recipient_devices", "At least one recipient device is required.");
  }

  const eventId = randomUUID().replace(/-/g, "");
  const now = nowSeconds();
  const expiresAt = now + voiceNudgeMediaTtlSeconds;
  const uploadExpiresAt = now + voiceNudgeUploadUrlTtlSeconds;
  const storagePath = `voiceNudges/${eventId}.m4a`;

  let signedWrite: Awaited<ReturnType<typeof createVoiceNudgeSignedWriteUrl>>;
  try {
    signedWrite = await createVoiceNudgeSignedWriteUrl(storagePath, uploadExpiresAt * 1000);
  } catch (error) {
    logger.error(
      {
        checkpoint: "VOICE-NUDGE-BE-E1",
        category: "unexpected",
        eventId,
        storagePath,
        error: describeError(error)
      },
      "voice nudge signed write URL generation failed"
    );
    throw error;
  }

  const recipientUserIds = [
    ...new Set(input.recipientDevices.map((d) => d.userId))
  ].filter((uid) => uid !== input.senderUserId);

  const ticket = createUploadTicket({
    eventId,
    groupId: input.groupId,
    senderUserId: input.senderUserId,
    targetScope: input.targetScope,
    targetUserId: input.targetUserId,
    recipientDevices: input.recipientDevices,
    recipientUserIds,
    senderName: input.senderName,
    durationMs: input.durationMs,
    storagePath,
    expiresAt,
    uploadExpiresAt
  });

  logger.info(
    {
      checkpoint: "VOICE-NUDGE-BE-01",
      category: "expected",
      eventId,
      groupId: input.groupId,
      durationMs: input.durationMs,
      uploadMode: "signed_write_url__rtdb_free",
      uploadExpiresAt,
      recipientUsers: recipientUserIds.length,
      targetDevices: input.recipientDevices.length
    },
    "voice nudge signed write URL issued; all context sealed in upload ticket (zero RTDB)"
  );

  return {
    notificationEventId: eventId,
    uploadUrl: signedWrite.uploadUrl,
    storagePath,
    contentType: signedWrite.contentType,
    requiredHeaders: signedWrite.requiredHeaders,
    maxBytes: maxVoiceNudgeBytes,
    uploadExpiresAt,
    expiresAt,
    uploadTicket: ticket
  };
}

// ---------------------------------------------------------------------------
// completeVoiceNudgeUpload — ZERO RTDB calls
// ---------------------------------------------------------------------------

export async function completeVoiceNudgeUpload(input: CompleteVoiceNudgeUploadInput) {
  const ticket = verifyUploadTicket(input.uploadTicket);
  const now = nowSeconds();

  if (ticket.uploadExpiresAt < now) {
    throw new HttpError(410, "voice_nudge_upload_expired", "Voice nudge upload has expired.");
  }

  const audioBytes = await verifyClientUploadedVoiceObject(ticket.eventId, ticket.storagePath);

  logger.info(
    {
      checkpoint: "VOICE-NUDGE-BE-02",
      category: "expected",
      eventId: ticket.eventId,
      storagePath: ticket.storagePath,
      audioBytes,
      uploadMode: "signed_write_url__rtdb_free"
    },
    "voice nudge audio verified in Cloud Storage after client direct upload"
  );

  const file = getVoiceNudgeBucket().file(ticket.storagePath);
  let signedAudioUrl: string;
  try {
    signedAudioUrl = await createVoiceNudgeSignedReadUrl(ticket.storagePath, ticket.expiresAt * 1000);
  } catch (error) {
    logger.error(
      {
        checkpoint: "VOICE-NUDGE-BE-E1",
        category: "unexpected",
        eventId: ticket.eventId,
        storagePath: ticket.storagePath,
        error: describeError(error)
      },
      "voice nudge signed read URL generation failed, rolling back Cloud Storage object"
    );
    await file.delete({ ignoreNotFound: true }).catch(() => undefined);
    throw error;
  }

  const deliveryTokens = ticket.recipientDevices.map((device) => ({
    device,
    deliveryId: `${device.userId}_${device.deviceId}`,
    token: createDeliveryToken()
  }));

  if (deliveryTokens.length === 0) {
    logger.warn(
      {
        checkpoint: "VOICE-NUDGE-BE-W1",
        category: "expected",
        eventId: ticket.eventId,
        reason: "no_recipients"
      },
      "voice nudge has no active recipient devices, purging Cloud Storage object immediately"
    );
    await file.delete({ ignoreNotFound: true }).catch(() => undefined);
    return nudgeResult(ticket.eventId, ticket.recipientUserIds.length, 0, 0, 0);
  }

  const pushResult = await sendAndroidDataPushes(
    deliveryTokens.map((delivery) => ({
      token: delivery.device.fcmToken,
      data: {
        type: "voice_nudge",
        eventId: ticket.eventId,
        groupId: ticket.groupId,
        senderUserId: ticket.senderUserId,
        senderName: ticket.senderName,
        durationMs: String(ticket.durationMs),
        expiresAt: String(ticket.expiresAt),
        audioUrl: signedAudioUrl
      }
    })),
    voiceNudgePushTtlMs
  );

  logger.info(
    {
      checkpoint: "VOICE-NUDGE-BE-03",
      category: "expected",
      eventId: ticket.eventId,
      audioBytes,
      targetDevices: ticket.recipientDevices.length,
      sent: pushResult.successCount,
      failed: pushResult.failureCount,
      deliveryMode: "signed_url",
      uploadMode: "signed_write_url__rtdb_free",
      rtdbCalls: 0
    },
    "voice nudge dispatched via FCM (zero RTDB calls)"
  );

  return nudgeResult(
    ticket.eventId,
    ticket.recipientUserIds.length,
    ticket.recipientDevices.length,
    pushResult.successCount,
    pushResult.failureCount
  );
}

// ---------------------------------------------------------------------------
// verifyClientUploadedVoiceObject — GCS only, no RTDB
// ---------------------------------------------------------------------------

async function verifyClientUploadedVoiceObject(eventId: string, storagePath: string) {
  const file = getVoiceNudgeBucket().file(storagePath);

  let metadata: Record<string, unknown>;
  try {
    [metadata] = (await file.getMetadata()) as unknown as [Record<string, unknown>];
  } catch (error) {
    if (isHttpErrorCode(error, 404)) {
      throw new HttpError(
        409,
        "voice_nudge_upload_missing",
        "Voice nudge audio has not been uploaded yet."
      );
    }
    throw error;
  }
  const size = Number((metadata as { size?: number }).size ?? 0);
  if (!Number.isFinite(size) || size <= 0 || size > maxVoiceNudgeBytes) {
    await file.delete({ ignoreNotFound: true }).catch(() => undefined);
    throw new HttpError(
      413,
      "voice_nudge_too_large",
      `Voice nudge audio must not exceed ${maxVoiceNudgeBytes} bytes.`
    );
  }

  const [header] = await file.download({ start: 0, end: Math.min(11, size - 1) });
  if (header.length < 12 || header.subarray(4, 8).toString("ascii") !== "ftyp") {
    await file.delete({ ignoreNotFound: true }).catch(() => undefined);
    throw new HttpError(400, "invalid_voice_nudge_audio", "Voice nudge must be an M4A file.");
  }

  logger.info(
    {
      checkpoint: "VOICE-NUDGE-BE-02A",
      category: "expected",
      eventId,
      storagePath,
      audioBytes: size,
      headerCheckBytes: header.length
    },
    "voice nudge client upload verified (metadata + ftyp header)"
  );

  return size;
}

// ---------------------------------------------------------------------------
// sendRingNudge — also RTDB-free (client provides recipient devices)
// ---------------------------------------------------------------------------

export async function sendRingNudge(input: SendRingNudgeInput) {
  const eventId = randomUUID().replace(/-/g, "");

  if (!input.recipientDevices || input.recipientDevices.length === 0) {
    return nudgeResult(eventId, 0, 0, 0, 0);
  }

  const pushResult = await sendAndroidDataPushes(
    input.recipientDevices.map((device) => ({
      token: device.fcmToken,
      data: {
        type: "ring_nudge",
        eventId,
        groupId: input.groupId,
        senderUserId: input.senderUserId,
        senderName: input.senderName,
        durationMs: String(input.durationSeconds * 1000)
      }
    })),
    ringNudgePushTtlMs
  );

  return nudgeResult(
    eventId,
    [...new Set(input.recipientDevices.map((d) => d.userId))].length,
    input.recipientDevices.length,
    pushResult.successCount,
    pushResult.failureCount
  );
}

// ===================================================================
// DEPRECATED — kept only so route imports don't break.
// ===================================================================

/** @deprecated Use initiateVoiceNudgeUpload + completeVoiceNudgeUpload instead. */
export async function createVoiceNudge(input: CreateVoiceNudgeInput) {
  validateVoiceNudgeAudio(input.audio, input.durationMs);
  const eventId = randomUUID().replace(/-/g, "");
  const now = nowSeconds();
  const expiresAt = now + voiceNudgeMediaTtlSeconds;
  const storagePath = `voiceNudges/${eventId}.m4a`;
  const file = getVoiceNudgeBucket().file(storagePath);

  logger.info(
    {
      checkpoint: "VOICE-NUDGE-BE-01",
      category: "expected",
      eventId,
      audioBytes: input.audio.length,
      durationMs: input.durationMs,
      uploadMode: "backend_proxy_deprecated"
    },
    "voice nudge upload via legacy proxy (deprecated)"
  );

  await file.save(input.audio, {
    resumable: false,
    contentType: voiceNudgeUploadContentType,
    metadata: {
      cacheControl: "private, no-store, max-age=0",
      metadata: { eventId, expiresAt: String(expiresAt) }
    }
  });

  const signedUrl = await createVoiceNudgeSignedReadUrl(storagePath, expiresAt * 1000);
  return { notificationEventId: eventId, storagePath, signedUrl, legacy: true };
}

/** @deprecated Audio is delivered via signed URL in the FCM payload directly. */
export async function resolveVoiceNudgeAudioRedirect(_eventId: string, _token: string) {
  throw new HttpError(
    410,
    "voice_nudge_audio_deprecated",
    "Audio redirect endpoint is deprecated. Use the signed URL from the FCM payload."
  );
}

/** @deprecated Delivery tracking is managed client-side via RTDB directly. */
export async function acknowledgeVoiceNudge(
  _eventId: string,
  _token: string,
  _status: "played" | "failed"
) {
  return { eventId: _eventId, status: _status, ack: "client_only" };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function nudgeResult(
  notificationEventId: string,
  recipientUsers: number,
  targetDevices: number,
  sent: number,
  failed: number
) {
  return {
    notificationEventId,
    recipientUsers,
    targetDevices,
    sent,
    failed,
    skipped: recipientUsers === 0 || targetDevices === 0 ? 1 : 0,
    rtdbCalls: 0
  };
}

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

function describeError(error: unknown) {
  if (error instanceof Error) {
    return {
      name: error.name,
      message: error.message,
      code: "code" in error ? String((error as { code: unknown }).code) : undefined
    };
  }
  return { name: typeof error, message: String(error) };
}

function isHttpErrorCode(error: unknown, code: number): boolean {
  if (typeof error !== "object" || error === null) return false;
  return (
    Number((error as { code?: unknown }).code) === code ||
    Number((error as { status?: unknown }).status) === code
  );
}
