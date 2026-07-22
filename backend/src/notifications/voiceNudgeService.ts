import { getRealtimeDatabase } from "../firebase/database.js";
import {
  isPermanentMessagingTargetError,
  sendAndroidDataPushes
} from "../firebase/messaging.js";
import {
  getVoiceNudgeBucket,
  createVoiceNudgeSignedReadUrl,
  createVoiceNudgeSignedWriteUrl,
  voiceNudgeUploadContentType
} from "../firebase/storage.js";
import { config } from "../config.js";
import {
  requireActiveGroup,
  requireActiveGroupMember,
  requireActiveUser
} from "../groups/groupService.js";
import { HttpError } from "../http/httpError.js";
import { logger } from "../logger.js";
import { enforceNudgeRateLimits, type NudgeEventType } from "./nudgeRateLimiter.js";
import {
  createDeliveryToken,
  deliveryTokenMatches,
  hashDeliveryToken,
  maxVoiceNudgeBytes,
  validateVoiceNudgeAudio,
  validateVoiceNudgeDuration
} from "./voiceNudgeValidation.js";

type NudgeTarget = {
  targetScope: "single_friend" | "all_friends";
  targetUserId?: string;
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
};

export type CompleteVoiceNudgeUploadInput = {
  groupId: string;
  eventId: string;
  senderUserId: string;
};

export type SendRingNudgeInput = NudgeTarget & {
  groupId: string;
  senderUserId: string;
  durationSeconds: 3 | 5 | 10;
};

type RecipientDevice = {
  userId: string;
  deviceId: string;
  fcmToken: string;
};

type DeliverySecret = {
  userId: string;
  deviceId: string;
  tokenHash: string;
  deliveryState: string;
};

const voiceNudgeMediaTtlSeconds = 10 * 60;
const voiceNudgeUploadUrlTtlSeconds = 5 * 60;
const voiceNudgePushTtlMs = 60 * 1000;
const ringNudgePushTtlMs = 30 * 1000;

/**
 * Preferred path: mint a short-lived V4 write URL so the client uploads
 * audio directly to Cloud Storage (no raw audio through the API).
 */
export async function initiateVoiceNudgeUpload(input: InitiateVoiceNudgeUploadInput) {
  validateVoiceNudgeDuration(input.durationMs);
  const context = await prepareNudge(input, "voice_nudge");
  const db = getRealtimeDatabase();
  const eventRef = db.ref(`notificationEvents/${input.groupId}`).push();
  const eventId = eventRef.key;
  if (!eventId) {
    throw new HttpError(500, "notification_event_id_failed", "Failed to allocate voice nudge id.");
  }

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

  try {
    await db.ref().update({
      [`notificationEvents/${input.groupId}/${eventId}`]: {
        notificationEventId: eventId,
        groupId: input.groupId,
        senderUserId: input.senderUserId,
        eventType: "voice_nudge",
        targetScope: input.targetScope,
        targetUserIds: context.recipientUserIds,
        createdAt: now,
        metadata: {
          durationMs: input.durationMs,
          expiresAt,
          uploadMode: "signed_write_url"
        }
      },
      [`voiceNudges/${eventId}/eventId`]: eventId,
      [`voiceNudges/${eventId}/groupId`]: input.groupId,
      [`voiceNudges/${eventId}/senderUserId`]: input.senderUserId,
      [`voiceNudges/${eventId}/storagePath`]: storagePath,
      [`voiceNudges/${eventId}/expiresAt`]: expiresAt,
      [`voiceNudges/${eventId}/uploadExpiresAt`]: uploadExpiresAt,
      [`voiceNudges/${eventId}/durationMs`]: input.durationMs,
      [`voiceNudges/${eventId}/targetScope`]: input.targetScope,
      [`voiceNudges/${eventId}/targetUserIds`]: context.recipientUserIds,
      [`voiceNudges/${eventId}/senderName`]: context.senderName,
      [`voiceNudges/${eventId}/voiceNudgeState`]: "awaiting_upload",
      [`voiceNudges/${eventId}/createdAt`]: now
    });
  } catch (error) {
    logger.error(
      {
        checkpoint: "VOICE-NUDGE-BE-E2",
        category: "unexpected",
        eventId,
        storagePath,
        error: describeError(error)
      },
      "voice nudge Realtime Database metadata write failed after signed write URL mint"
    );
    throw error;
  }

  logger.info(
    {
      checkpoint: "VOICE-NUDGE-BE-01",
      category: "expected",
      eventId,
      groupId: input.groupId,
      durationMs: input.durationMs,
      uploadMode: "signed_write_url",
      uploadExpiresAt,
      recipientUsers: context.recipientUserIds.length,
      targetDevices: context.recipientDevices.length
    },
    "voice nudge signed write URL issued; client uploads directly to Cloud Storage"
  );

  return {
    notificationEventId: eventId,
    uploadUrl: signedWrite.uploadUrl,
    storagePath,
    contentType: signedWrite.contentType,
    requiredHeaders: signedWrite.requiredHeaders,
    maxBytes: maxVoiceNudgeBytes,
    uploadExpiresAt,
    expiresAt
  };
}

/**
 * After the client PUTs audio to the signed write URL, verify the object
 * and dispatch FCM with a signed read URL.
 */
export async function completeVoiceNudgeUpload(input: CompleteVoiceNudgeUploadInput) {
  const db = getRealtimeDatabase();
  const snapshot = await db.ref(`voiceNudges/${input.eventId}`).get();
  if (!snapshot.exists() || !isRecord(snapshot.val())) {
    throw new HttpError(404, "voice_nudge_not_found", "Voice nudge does not exist.");
  }

  const value = snapshot.val() as Record<string, unknown>;
  if (String(value.groupId ?? "") !== input.groupId) {
    throw new HttpError(404, "voice_nudge_not_found", "Voice nudge does not exist.");
  }
  if (String(value.senderUserId ?? "") !== input.senderUserId) {
    throw new HttpError(403, "voice_nudge_forbidden", "Only the sender can complete this upload.");
  }

  const state = String(value.voiceNudgeState ?? "");
  if (state !== "awaiting_upload") {
    if (state === "pending" || state === "sent" || state === "completed") {
      return idempotentCompleteResult(input.eventId, value);
    }
    throw new HttpError(
      409,
      "voice_nudge_not_awaiting_upload",
      "Voice nudge is not waiting for an upload."
    );
  }

  const now = nowSeconds();
  const uploadExpiresAt = readNumber(value.uploadExpiresAt);
  if (uploadExpiresAt > 0 && uploadExpiresAt < now) {
    await purgeVoiceNudge(input.eventId, "upload_expired");
    throw new HttpError(410, "voice_nudge_upload_expired", "Voice nudge upload URL has expired.");
  }

  const storagePath = String(value.storagePath ?? "");
  if (!storagePath) {
    throw new HttpError(500, "voice_nudge_storage_missing", "Voice nudge storage path is missing.");
  }

  const audioBytes = await verifyClientUploadedVoiceObject(input.eventId, storagePath);
  const durationMs = readNumber(value.durationMs);
  validateVoiceNudgeDuration(durationMs);

  const expiresAt = readNumber(value.expiresAt) || now + voiceNudgeMediaTtlSeconds;
  const recipientUserIds = Array.isArray(value.targetUserIds)
    ? value.targetUserIds.map(String)
    : [];
  const senderName = String(value.senderName ?? "Someone");
  const recipientDevices = await collectAndroidRecipientDevices(recipientUserIds);

  logger.info(
    {
      checkpoint: "VOICE-NUDGE-BE-02",
      category: "expected",
      eventId: input.eventId,
      storagePath,
      audioBytes,
      uploadMode: "signed_write_url"
    },
    "voice nudge audio verified in Cloud Storage after client direct upload"
  );

  return dispatchVoiceNudge({
    eventId: input.eventId,
    groupId: input.groupId,
    senderUserId: input.senderUserId,
    senderName,
    durationMs,
    expiresAt,
    storagePath,
    audioBytes,
    recipientUserIds,
    recipientDevices,
    uploadMode: "signed_write_url",
    writeNotificationEvent: false
  });
}

/**
 * Legacy path: client POSTs raw audio through the API, which writes to GCS.
 * Prefer initiateVoiceNudgeUpload + completeVoiceNudgeUpload for new clients.
 */
export async function createVoiceNudge(input: CreateVoiceNudgeInput) {
  validateVoiceNudgeAudio(input.audio, input.durationMs);
  const context = await prepareNudge(input, "voice_nudge");
  const db = getRealtimeDatabase();
  const eventRef = db.ref(`notificationEvents/${input.groupId}`).push();
  const eventId = eventRef.key;
  if (!eventId) {
    throw new HttpError(500, "notification_event_id_failed", "Failed to allocate voice nudge id.");
  }

  logger.info(
    {
      checkpoint: "VOICE-NUDGE-BE-01",
      category: "expected",
      eventId,
      groupId: input.groupId,
      audioBytes: input.audio.length,
      durationMs: input.durationMs,
      uploadMode: "backend_proxy"
    },
    "voice nudge upload accepted, writing to Cloud Storage via backend (legacy)"
  );

  const now = nowSeconds();
  const expiresAt = now + voiceNudgeMediaTtlSeconds;
  const storagePath = `voiceNudges/${eventId}.m4a`;
  const file = getVoiceNudgeBucket().file(storagePath);
  try {
    await file.save(input.audio, {
      resumable: false,
      contentType: voiceNudgeUploadContentType,
      metadata: {
        cacheControl: "private, no-store, max-age=0",
        metadata: {
          eventId,
          expiresAt: String(expiresAt)
        }
      }
    });
  } catch (error) {
    logger.error(
      {
        checkpoint: "VOICE-NUDGE-BE-E1",
        category: "unexpected",
        eventId,
        storagePath,
        audioBytes: input.audio.length,
        error: describeError(error)
      },
      "voice nudge Cloud Storage write failed"
    );
    throw error;
  }
  logger.info(
    {
      checkpoint: "VOICE-NUDGE-BE-02",
      category: "expected",
      eventId,
      storagePath,
      audioBytes: input.audio.length,
      uploadMode: "backend_proxy"
    },
    "voice nudge audio stored in Cloud Storage"
  );

  return dispatchVoiceNudge({
    eventId,
    groupId: input.groupId,
    senderUserId: input.senderUserId,
    senderName: context.senderName,
    durationMs: input.durationMs,
    expiresAt,
    storagePath,
    audioBytes: input.audio.length,
    recipientUserIds: context.recipientUserIds,
    recipientDevices: context.recipientDevices,
    uploadMode: "backend_proxy",
    writeNotificationEvent: true,
    targetScope: input.targetScope
  });
}

async function dispatchVoiceNudge(input: {
  eventId: string;
  groupId: string;
  senderUserId: string;
  senderName: string;
  durationMs: number;
  expiresAt: number;
  storagePath: string;
  audioBytes: number;
  recipientUserIds: string[];
  recipientDevices: RecipientDevice[];
  uploadMode: "signed_write_url" | "backend_proxy";
  writeNotificationEvent: boolean;
  targetScope?: "single_friend" | "all_friends";
}) {
  const db = getRealtimeDatabase();
  const now = nowSeconds();
  const file = getVoiceNudgeBucket().file(input.storagePath);

  let signedAudioUrl: string;
  try {
    signedAudioUrl = await createVoiceNudgeSignedReadUrl(input.storagePath, input.expiresAt * 1000);
  } catch (error) {
    logger.error(
      {
        checkpoint: "VOICE-NUDGE-BE-E1",
        category: "unexpected",
        eventId: input.eventId,
        storagePath: input.storagePath,
        error: describeError(error)
      },
      "voice nudge signed read URL generation failed, rolling back Cloud Storage object"
    );
    await file.delete({ ignoreNotFound: true }).catch(() => undefined);
    throw error;
  }

  const deliveryTokens = input.recipientDevices.map((device) => ({
    device,
    deliveryId: deliveryIdFor(device),
    token: createDeliveryToken()
  }));
  const updates: Record<string, unknown> = {
    [`voiceNudges/${input.eventId}/voiceNudgeState`]: "pending",
    [`voiceNudges/${input.eventId}/audioBytes`]: input.audioBytes,
    [`voiceNudges/${input.eventId}/uploadedAt`]: now
  };

  if (input.writeNotificationEvent) {
    updates[`notificationEvents/${input.groupId}/${input.eventId}`] = {
      notificationEventId: input.eventId,
      groupId: input.groupId,
      senderUserId: input.senderUserId,
      eventType: "voice_nudge",
      targetScope: input.targetScope,
      targetUserIds: input.recipientUserIds,
      createdAt: now,
      metadata: {
        durationMs: input.durationMs,
        expiresAt: input.expiresAt,
        uploadMode: input.uploadMode
      }
    };
    updates[`voiceNudges/${input.eventId}/eventId`] = input.eventId;
    updates[`voiceNudges/${input.eventId}/groupId`] = input.groupId;
    updates[`voiceNudges/${input.eventId}/senderUserId`] = input.senderUserId;
    updates[`voiceNudges/${input.eventId}/storagePath`] = input.storagePath;
    updates[`voiceNudges/${input.eventId}/expiresAt`] = input.expiresAt;
    updates[`voiceNudges/${input.eventId}/createdAt`] = now;
  }

  for (const delivery of deliveryTokens) {
    updates[`voiceNudges/${input.eventId}/deliveries/${delivery.deliveryId}`] = {
      userId: delivery.device.userId,
      deviceId: delivery.device.deviceId,
      tokenHash: hashDeliveryToken(delivery.token),
      deliveryState: "pending",
      createdAt: now
    };
    updates[`notificationDeliveries/${input.eventId}/${delivery.deliveryId}`] = {
      notificationEventId: input.eventId,
      userId: delivery.device.userId,
      deviceId: delivery.device.deviceId,
      fcmTokenTail: delivery.device.fcmToken.slice(-8),
      deliveryState: "pending",
      attemptedAt: now
    };
  }

  try {
    await db.ref().update(updates);
  } catch (error) {
    logger.error(
      {
        checkpoint: "VOICE-NUDGE-BE-E2",
        category: "unexpected",
        eventId: input.eventId,
        storagePath: input.storagePath,
        error: describeError(error)
      },
      "voice nudge Realtime Database metadata write failed, rolling back Cloud Storage object"
    );
    await file.delete({ ignoreNotFound: true }).catch(() => undefined);
    throw error;
  }

  if (deliveryTokens.length === 0) {
    logger.info(
      {
        checkpoint: "VOICE-NUDGE-BE-W1",
        category: "expected",
        eventId: input.eventId,
        reason: "no_recipients"
      },
      "voice nudge has no active recipient devices, purging Cloud Storage object immediately"
    );
    await purgeVoiceNudge(input.eventId, "no_recipients");
    return nudgeResult(input.eventId, input.recipientUserIds.length, 0, 0, 0);
  }

  const baseUrl = config.PUBLIC_API_BASE_URL.replace(/\/$/, "");
  const pushResult = await sendAndroidDataPushes(
    deliveryTokens.map((delivery) => ({
      token: delivery.device.fcmToken,
      data: {
        type: "voice_nudge",
        eventId: input.eventId,
        groupId: input.groupId,
        senderUserId: input.senderUserId,
        senderName: input.senderName,
        durationMs: String(input.durationMs),
        expiresAt: String(input.expiresAt),
        // Direct Cloud Storage download — eliminates backend audio proxy egress.
        audioUrl: signedAudioUrl,
        ackUrl: `${baseUrl}/v1/voice-nudges/${input.eventId}/ack`,
        responseUrl: `${baseUrl}/v1/groups/${input.groupId}/nudges/${input.eventId}/respond`,
        deliveryToken: delivery.token
      }
    })),
    voiceNudgePushTtlMs
  );

  const deliveryUpdates: Record<string, unknown> = {};
  deliveryTokens.forEach((delivery, index) => {
    const response = pushResult.responses[index];
    const pushState = response?.success ? "sent" : "failed";
    deliveryUpdates[`voiceNudges/${input.eventId}/deliveries/${delivery.deliveryId}/deliveryState`] =
      pushState;
    deliveryUpdates[`notificationDeliveries/${input.eventId}/${delivery.deliveryId}/deliveryState`] =
      pushState;
    deliveryUpdates[`notificationDeliveries/${input.eventId}/${delivery.deliveryId}/fcmMessageId`] =
      response?.messageId ?? null;
    deliveryUpdates[`notificationDeliveries/${input.eventId}/${delivery.deliveryId}/errorCode`] =
      response?.error ? String(response.error) : null;
    if (isPermanentMessagingTargetError(response?.error)) {
      deliveryUpdates[
        `userDevices/${delivery.device.userId}/${delivery.device.deviceId}/fcmToken`
      ] = null;
      deliveryUpdates[
        `userDevices/${delivery.device.userId}/${delivery.device.deviceId}/registrationInvalidatedAt`
      ] = now;
    }
  });
  await db.ref().update(deliveryUpdates);

  logger.info(
    {
      checkpoint: "VOICE-NUDGE-BE-03",
      category: "expected",
      eventId: input.eventId,
      audioBytes: input.audioBytes,
      targetDevices: input.recipientDevices.length,
      sent: pushResult.successCount,
      failed: pushResult.failureCount,
      deliveryMode: "signed_url",
      uploadMode: input.uploadMode,
      expectedDownloadFanout: pushResult.successCount
    },
    "voice nudge dispatched via FCM with Cloud Storage signed URL"
  );

  return nudgeResult(
    input.eventId,
    input.recipientUserIds.length,
    input.recipientDevices.length,
    pushResult.successCount,
    pushResult.failureCount
  );
}

/**
 * Confirm the object exists, is within size limits, and looks like M4A.
 * Only reads the first 12 bytes from Storage (header check), not the full file.
 */
async function verifyClientUploadedVoiceObject(eventId: string, storagePath: string) {
  const file = getVoiceNudgeBucket().file(storagePath);
  const [exists] = await file.exists();
  if (!exists) {
    throw new HttpError(
      409,
      "voice_nudge_upload_missing",
      "Voice nudge audio has not been uploaded yet."
    );
  }

  const [metadata] = await file.getMetadata();
  const size = Number(metadata.size ?? 0);
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

function idempotentCompleteResult(eventId: string, value: Record<string, unknown>) {
  const recipientUsers = Array.isArray(value.targetUserIds) ? value.targetUserIds.length : 0;
  const deliveries = isRecord(value.deliveries) ? Object.values(value.deliveries) : [];
  const targetDevices = deliveries.length;
  let sent = 0;
  let failed = 0;
  for (const delivery of deliveries) {
    if (!isRecord(delivery)) continue;
    const deliveryState = String(delivery.deliveryState ?? "");
    if (deliveryState === "failed") failed += 1;
    else if (deliveryState !== "pending") sent += 1;
  }
  return nudgeResult(eventId, recipientUsers, targetDevices, sent, failed);
}

export async function sendRingNudge(input: SendRingNudgeInput) {
  const context = await prepareNudge(input, "ring_nudge");
  const db = getRealtimeDatabase();
  const eventRef = db.ref(`notificationEvents/${input.groupId}`).push();
  const eventId = eventRef.key;
  if (!eventId) {
    throw new HttpError(500, "notification_event_id_failed", "Failed to allocate ring nudge id.");
  }

  const now = nowSeconds();
  await eventRef.set({
    notificationEventId: eventId,
    groupId: input.groupId,
    senderUserId: input.senderUserId,
    eventType: "ring_nudge",
    targetScope: input.targetScope,
    targetUserIds: context.recipientUserIds,
    createdAt: now,
    metadata: { durationSeconds: input.durationSeconds }
  });

  const pushResult = await sendAndroidDataPushes(
    context.recipientDevices.map((device) => ({
      token: device.fcmToken,
      data: {
        type: "ring_nudge",
        eventId,
        groupId: input.groupId,
        senderUserId: input.senderUserId,
        senderName: context.senderName,
        durationMs: String(input.durationSeconds * 1000),
        responseUrl: `${config.PUBLIC_API_BASE_URL.replace(/\/$/, "")}/v1/groups/${input.groupId}/nudges/${eventId}/respond`
      }
    })),
    ringNudgePushTtlMs
  );
  await writePublicDeliveries(eventId, context.recipientDevices, pushResult);

  return nudgeResult(
    eventId,
    context.recipientUserIds.length,
    context.recipientDevices.length,
    pushResult.successCount,
    pushResult.failureCount
  );
}

/**
 * Issues a short-lived Cloud Storage signed URL and marks the delivery
 * downloaded. Used by GET /audio as a compatibility redirect for older
 * clients that still hit the backend instead of using the FCM signed URL.
 * Does not proxy audio bytes through the backend.
 */
export async function resolveVoiceNudgeAudioRedirect(eventId: string, token: string) {
  const access = await requireDeliveryAccess(eventId, token);
  const now = nowSeconds();
  if (access.expiresAt <= now) {
    logger.warn(
      {
        checkpoint: "VOICE-NUDGE-BE-W2",
        category: "expected",
        eventId,
        deliveryId: access.deliveryId,
        reason: "expired"
      },
      "voice nudge audio requested after expiry, purging Cloud Storage object"
    );
    await purgeVoiceNudge(eventId, "expired");
    throw new HttpError(410, "voice_nudge_expired", "Voice nudge has expired.");
  }

  let signedUrl: string;
  try {
    signedUrl = await createVoiceNudgeSignedReadUrl(access.storagePath, access.expiresAt * 1000);
  } catch (error) {
    logger.error(
      {
        checkpoint: "VOICE-NUDGE-BE-E3",
        category: "unexpected",
        eventId,
        deliveryId: access.deliveryId,
        storagePath: access.storagePath,
        error: describeError(error)
      },
      "voice nudge signed URL generation failed for audio redirect"
    );
    throw error;
  }

  logger.info(
    {
      checkpoint: "VOICE-NUDGE-BE-04",
      category: "expected",
      eventId,
      deliveryId: access.deliveryId,
      storagePath: access.storagePath,
      egress: "signed_url_redirect"
    },
    "voice nudge audio redirecting client to Cloud Storage signed URL"
  );

  await getRealtimeDatabase().ref().update({
    [`voiceNudges/${eventId}/deliveries/${access.deliveryId}/deliveryState`]: "downloaded",
    [`voiceNudges/${eventId}/deliveries/${access.deliveryId}/downloadedAt`]: now,
    [`notificationDeliveries/${eventId}/${access.deliveryId}/deliveryState`]: "downloaded",
    [`notificationDeliveries/${eventId}/${access.deliveryId}/downloadedAt`]: now
  });

  return { signedUrl, deliveryId: access.deliveryId };
}

export async function acknowledgeVoiceNudge(
  eventId: string,
  token: string,
  status: "played" | "failed"
) {
  const access = await requireDeliveryAccess(eventId, token);
  const now = nowSeconds();
  await getRealtimeDatabase().ref().update({
    [`voiceNudges/${eventId}/deliveries/${access.deliveryId}/deliveryState`]: status,
    [`voiceNudges/${eventId}/deliveries/${access.deliveryId}/acknowledgedAt`]: now,
    [`notificationDeliveries/${eventId}/${access.deliveryId}/deliveryState`]: status,
    [`notificationDeliveries/${eventId}/${access.deliveryId}/acknowledgedAt`]: now
  });

  const log = status === "played" ? logger.info.bind(logger) : logger.warn.bind(logger);
  log(
    {
      checkpoint: "VOICE-NUDGE-BE-06",
      category: status === "played" ? "expected" : "unexpected",
      eventId,
      deliveryId: access.deliveryId,
      status
    },
    "voice nudge playback acknowledgement received"
  );

  if (status === "played") {
    await deleteWhenEveryRecipientPlayed(eventId, access.storagePath);
  }

  return { eventId, status };
}

async function prepareNudge(
  input: NudgeTarget & { groupId: string; senderUserId: string },
  eventType: NudgeEventType
) {
  await requireActiveUser(input.senderUserId);
  await requireActiveGroup(input.groupId);
  await requireActiveGroupMember(input.groupId, input.senderUserId);

  if (input.targetScope === "single_friend") {
    if (!input.targetUserId) {
      throw new HttpError(400, "target_user_required", "targetUserId is required.");
    }
    await requireActiveGroupMember(input.groupId, input.targetUserId);
  }

  const recipientUserIds =
    input.targetScope === "single_friend"
      ? [input.targetUserId!].filter((userId) => userId !== input.senderUserId)
      : await activeRecipientUserIds(input.groupId, input.senderUserId);
  await enforceNudgeRateLimits({
    groupId: input.groupId,
    senderUserId: input.senderUserId,
    eventType,
    targetUserIds: recipientUserIds
  });

  return {
    senderName: await readDisplayName(input.senderUserId),
    recipientUserIds,
    recipientDevices: await collectAndroidRecipientDevices(recipientUserIds)
  };
}

async function activeRecipientUserIds(groupId: string, senderUserId: string) {
  const snapshot = await getRealtimeDatabase().ref(`groupMembers/${groupId}`).get();
  if (!snapshot.exists() || !isRecord(snapshot.val())) return [];
  return Object.entries(snapshot.val() as Record<string, unknown>)
    .filter(([userId, value]) => {
      return userId !== senderUserId && isRecord(value) && value.memberState === "active";
    })
    .map(([userId]) => userId);
}

async function collectAndroidRecipientDevices(userIds: string[]) {
  const devices: RecipientDevice[] = [];
  for (const userId of userIds) {
    const snapshot = await getRealtimeDatabase().ref(`userDevices/${userId}`).get();
    if (!snapshot.exists() || !isRecord(snapshot.val())) continue;
    for (const [deviceId, value] of Object.entries(snapshot.val() as Record<string, unknown>)) {
      if (!isRecord(value) || value.deviceState !== "active" || value.platform !== "android") continue;
      const fcmToken = value.fcmToken?.toString();
      if (fcmToken) devices.push({ userId, deviceId, fcmToken });
    }
  }
  return devices;
}

async function requireDeliveryAccess(eventId: string, token: string) {
  if (!token) {
    logger.warn(
      {
        checkpoint: "VOICE-NUDGE-BE-W3",
        category: "unexpected",
        eventId,
        reason: "missing_delivery_token"
      },
      "voice nudge audio/ack request missing delivery token"
    );
    throw new HttpError(401, "missing_delivery_token", "Voice nudge delivery token is required.");
  }
  const snapshot = await getRealtimeDatabase().ref(`voiceNudges/${eventId}`).get();
  if (!snapshot.exists() || !isRecord(snapshot.val())) {
    logger.warn(
      {
        checkpoint: "VOICE-NUDGE-BE-W3",
        category: "unexpected",
        eventId,
        reason: "voice_nudge_not_found"
      },
      "voice nudge audio/ack request referenced an unknown eventId"
    );
    throw new HttpError(404, "voice_nudge_not_found", "Voice nudge does not exist.");
  }
  const value = snapshot.val() as Record<string, unknown>;
  const deliveries = isRecord(value.deliveries) ? value.deliveries : {};
  for (const [deliveryId, raw] of Object.entries(deliveries)) {
    if (!isDeliverySecret(raw)) continue;
    if (deliveryTokenMatches(token, raw.tokenHash)) {
      return {
        deliveryId,
        storagePath: String(value.storagePath ?? ""),
        expiresAt: readNumber(value.expiresAt)
      };
    }
  }
  logger.warn(
    {
      checkpoint: "VOICE-NUDGE-BE-W3",
      category: "unexpected",
      eventId,
      reason: "invalid_delivery_token"
    },
    "voice nudge audio/ack request presented a token that matched no delivery"
  );
  throw new HttpError(403, "invalid_delivery_token", "Voice nudge delivery token is invalid.");
}

async function deleteWhenEveryRecipientPlayed(eventId: string, storagePath: string) {
  const snapshot = await getRealtimeDatabase().ref(`voiceNudges/${eventId}/deliveries`).get();
  if (!snapshot.exists() || !isRecord(snapshot.val())) return;
  const deliveries = Object.values(snapshot.val() as Record<string, unknown>).filter(isDeliverySecret);
  const recipientUserIds = [...new Set(deliveries.map((delivery) => delivery.userId))];
  const everyRecipientPlayed = recipientUserIds.every((userId) =>
    deliveries.some(
      (delivery) => delivery.userId === userId && delivery.deliveryState === "played"
    )
  );
  if (!everyRecipientPlayed) return;

  await getVoiceNudgeBucket().file(storagePath).delete({ ignoreNotFound: true });
  await getRealtimeDatabase().ref(`voiceNudges/${eventId}`).update({
    voiceNudgeState: "completed",
    storageDeletedAt: nowSeconds()
  });
  logger.info(
    {
      checkpoint: "VOICE-NUDGE-BE-07",
      category: "expected",
      eventId,
      storagePath,
      reason: "all_recipients_played"
    },
    "voice nudge Cloud Storage object deleted after every recipient played it"
  );
}

async function purgeVoiceNudge(eventId: string, reason: string) {
  const ref = getRealtimeDatabase().ref(`voiceNudges/${eventId}`);
  const snapshot = await ref.get();
  if (!snapshot.exists()) return;
  const storagePath = snapshot.child("storagePath").val()?.toString();
  if (storagePath) {
    await getVoiceNudgeBucket().file(storagePath).delete({ ignoreNotFound: true });
  }
  await ref.update({
    voiceNudgeState: reason,
    storageDeletedAt: nowSeconds()
  });
  logger.info(
    {
      checkpoint: "VOICE-NUDGE-BE-08",
      category: "expected",
      eventId,
      storagePath: storagePath ?? null,
      reason
    },
    "voice nudge Cloud Storage object purged"
  );
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

async function writePublicDeliveries(
  eventId: string,
  devices: RecipientDevice[],
  pushResult: {
    responses: Array<{ success: boolean; messageId?: string; error?: unknown }>;
  }
) {
  const updates: Record<string, unknown> = {};
  devices.forEach((device, index) => {
    const response = pushResult.responses[index];
    updates[`notificationDeliveries/${eventId}/${deliveryIdFor(device)}`] = {
      notificationEventId: eventId,
      userId: device.userId,
      deviceId: device.deviceId,
      fcmTokenTail: device.fcmToken.slice(-8),
      deliveryState: response?.success ? "sent" : "failed",
      fcmMessageId: response?.messageId ?? null,
      errorCode: response?.error ? String(response.error) : null,
      attemptedAt: nowSeconds()
    };
    if (isPermanentMessagingTargetError(response?.error)) {
      updates[`userDevices/${device.userId}/${device.deviceId}/fcmToken`] = null;
      updates[`userDevices/${device.userId}/${device.deviceId}/registrationInvalidatedAt`] =
        nowSeconds();
    }
  });
  if (Object.keys(updates).length > 0) await getRealtimeDatabase().ref().update(updates);
}

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
    skipped: recipientUsers === 0 || targetDevices === 0 ? 1 : 0
  };
}

function deliveryIdFor(device: Pick<RecipientDevice, "userId" | "deviceId">) {
  return `${device.userId}_${device.deviceId}`;
}

async function readDisplayName(userId: string) {
  const snapshot = await getRealtimeDatabase().ref(`users/${userId}/displayName`).get();
  return snapshot.val()?.toString() || "Someone";
}

function isDeliverySecret(value: unknown): value is DeliverySecret {
  return (
    isRecord(value) &&
    typeof value.userId === "string" &&
    typeof value.deviceId === "string" &&
    typeof value.tokenHash === "string" &&
    typeof value.deliveryState === "string"
  );
}

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

function readNumber(value: unknown) {
  if (typeof value === "number") return value;
  return Number(value) || 0;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
