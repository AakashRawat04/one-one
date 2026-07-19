import { getRealtimeDatabase } from "../firebase/database.js";
import {
  isPermanentMessagingTargetError,
  sendAndroidDataPushes
} from "../firebase/messaging.js";
import { getVoiceNudgeBucket } from "../firebase/storage.js";
import { config } from "../config.js";
import {
  requireActiveGroup,
  requireActiveGroupMember,
  requireActiveUser
} from "../groups/groupService.js";
import { HttpError } from "../http/httpError.js";
import { logger } from "../logger.js";
import {
  createDeliveryToken,
  deliveryTokenMatches,
  hashDeliveryToken,
  validateVoiceNudgeAudio
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
const voiceNudgePushTtlMs = 60 * 1000;
const ringNudgePushTtlMs = 30 * 1000;

export async function createVoiceNudge(input: CreateVoiceNudgeInput) {
  validateVoiceNudgeAudio(input.audio, input.durationMs);
  const context = await prepareNudge(input);
  const db = getRealtimeDatabase();
  const eventRef = db.ref(`notificationEvents/${input.groupId}`).push();
  const eventId = eventRef.key;
  if (!eventId) {
    throw new HttpError(500, "notification_event_id_failed", "Failed to allocate voice nudge id.");
  }

  const now = nowSeconds();
  const expiresAt = now + voiceNudgeMediaTtlSeconds;
  const storagePath = `voiceNudges/${eventId}.m4a`;
  const file = getVoiceNudgeBucket().file(storagePath);
  await file.save(input.audio, {
    resumable: false,
    contentType: "audio/mp4",
    metadata: {
      cacheControl: "private, no-store, max-age=0",
      metadata: {
        eventId,
        expiresAt: String(expiresAt)
      }
    }
  });

  const deliveryTokens = context.recipientDevices.map((device) => ({
    device,
    deliveryId: deliveryIdFor(device),
    token: createDeliveryToken()
  }));
  const updates: Record<string, unknown> = {
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
        expiresAt
      }
    },
    [`voiceNudges/${eventId}/eventId`]: eventId,
    [`voiceNudges/${eventId}/groupId`]: input.groupId,
    [`voiceNudges/${eventId}/senderUserId`]: input.senderUserId,
    [`voiceNudges/${eventId}/storagePath`]: storagePath,
    [`voiceNudges/${eventId}/expiresAt`]: expiresAt,
    [`voiceNudges/${eventId}/voiceNudgeState`]: "pending",
    [`voiceNudges/${eventId}/createdAt`]: now
  };

  for (const delivery of deliveryTokens) {
    updates[`voiceNudges/${eventId}/deliveries/${delivery.deliveryId}`] = {
      userId: delivery.device.userId,
      deviceId: delivery.device.deviceId,
      tokenHash: hashDeliveryToken(delivery.token),
      deliveryState: "pending",
      createdAt: now
    };
    updates[`notificationDeliveries/${eventId}/${delivery.deliveryId}`] = {
      notificationEventId: eventId,
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
    await file.delete({ ignoreNotFound: true }).catch(() => undefined);
    throw error;
  }

  if (deliveryTokens.length === 0) {
    await purgeVoiceNudge(eventId, "no_recipients");
    return nudgeResult(eventId, context.recipientUserIds.length, 0, 0, 0);
  }

  const baseUrl = config.PUBLIC_API_BASE_URL.replace(/\/$/, "");
  const pushResult = await sendAndroidDataPushes(
    deliveryTokens.map((delivery) => ({
      token: delivery.device.fcmToken,
      data: {
        type: "voice_nudge",
        eventId,
        groupId: input.groupId,
        senderUserId: input.senderUserId,
        senderName: context.senderName,
        durationMs: String(input.durationMs),
        expiresAt: String(expiresAt),
        audioUrl: `${baseUrl}/v1/voice-nudges/${eventId}/audio`,
        ackUrl: `${baseUrl}/v1/voice-nudges/${eventId}/ack`,
        deliveryToken: delivery.token
      }
    })),
    voiceNudgePushTtlMs
  );

  const deliveryUpdates: Record<string, unknown> = {};
  deliveryTokens.forEach((delivery, index) => {
    const response = pushResult.responses[index];
    const state = response?.success ? "sent" : "failed";
    deliveryUpdates[`voiceNudges/${eventId}/deliveries/${delivery.deliveryId}/deliveryState`] = state;
    deliveryUpdates[`notificationDeliveries/${eventId}/${delivery.deliveryId}/deliveryState`] = state;
    deliveryUpdates[`notificationDeliveries/${eventId}/${delivery.deliveryId}/fcmMessageId`] =
      response?.messageId ?? null;
    deliveryUpdates[`notificationDeliveries/${eventId}/${delivery.deliveryId}/errorCode`] =
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

  return nudgeResult(
    eventId,
    context.recipientUserIds.length,
    context.recipientDevices.length,
    pushResult.successCount,
    pushResult.failureCount
  );
}

export async function sendRingNudge(input: SendRingNudgeInput) {
  const context = await prepareNudge(input);
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
        durationMs: String(input.durationSeconds * 1000)
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

export async function downloadVoiceNudge(eventId: string, token: string) {
  const access = await requireDeliveryAccess(eventId, token);
  const now = nowSeconds();
  if (access.expiresAt <= now) {
    await purgeVoiceNudge(eventId, "expired");
    throw new HttpError(410, "voice_nudge_expired", "Voice nudge has expired.");
  }

  const [audio] = await getVoiceNudgeBucket().file(access.storagePath).download();
  await getRealtimeDatabase().ref().update({
    [`voiceNudges/${eventId}/deliveries/${access.deliveryId}/deliveryState`]: "downloaded",
    [`voiceNudges/${eventId}/deliveries/${access.deliveryId}/downloadedAt`]: now,
    [`notificationDeliveries/${eventId}/${access.deliveryId}/deliveryState`]: "downloaded",
    [`notificationDeliveries/${eventId}/${access.deliveryId}/downloadedAt`]: now
  });
  return audio;
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

  if (status === "played") {
    await deleteWhenEveryRecipientPlayed(eventId, access.storagePath);
  }

  return { eventId, status };
}

async function prepareNudge(input: NudgeTarget & { groupId: string; senderUserId: string }) {
  await requireActiveUser(input.senderUserId);
  await requireActiveGroup(input.groupId);
  await requireActiveGroupMember(input.groupId, input.senderUserId);

  if (input.targetScope === "single_friend") {
    if (!input.targetUserId) {
      throw new HttpError(400, "target_user_required", "targetUserId is required.");
    }
    await requireActiveGroupMember(input.groupId, input.targetUserId);
  }

  const now = nowSeconds();
  const recipientUserIds =
    input.targetScope === "single_friend"
      ? [input.targetUserId!].filter((userId) => userId !== input.senderUserId)
      : await activeRecipientUserIds(input.groupId, input.senderUserId);
  await enforceNudgeRateLimits(input.groupId, input.senderUserId, recipientUserIds, now);

  return {
    senderName: await readDisplayName(input.senderUserId),
    recipientUserIds,
    recipientDevices: await collectAndroidRecipientDevices(recipientUserIds)
  };
}

async function enforceNudgeRateLimits(
  groupId: string,
  senderUserId: string,
  targetUserIds: string[],
  now: number
) {
  const snapshot = await getRealtimeDatabase().ref(`notificationEvents/${groupId}`).get();
  if (!snapshot.exists() || !isRecord(snapshot.val())) return;

  const recent = Object.values(snapshot.val() as Record<string, unknown>).filter((value) => {
    if (!isRecord(value)) return false;
    return (
      value.senderUserId === senderUserId &&
      ["nudge", "ring_nudge", "voice_nudge"].includes(String(value.eventType)) &&
      readNumber(value.createdAt) >= now - config.NUDGE_RATE_LIMIT_WINDOW_SECONDS
    );
  });

  if (recent.length >= config.NUDGE_RATE_LIMIT_MAX_PER_GROUP) {
    const oldestCreatedAt = Math.min(
      ...recent.map((value) => (isRecord(value) ? readNumber(value.createdAt) : now))
    );
    const retryAfterSeconds = Math.max(
      1,
      oldestCreatedAt + config.NUDGE_RATE_LIMIT_WINDOW_SECONDS - now
    );
    logger.warn(
      {
        checkpoint: "NUDGE-BE-W1",
        reason: "group_limit",
        recentCount: recent.length,
        configuredLimit: config.NUDGE_RATE_LIMIT_MAX_PER_GROUP,
        retryAfterSeconds
      },
      "nudge request rate limited before FCM send"
    );
    throw new HttpError(
      429,
      "nudge_rate_limited",
      `Nudge limit reached. Try again in ${retryAfterSeconds} seconds.`
    );
  }

  if (config.NUDGE_RECIPIENT_COOLDOWN_SECONDS > 0 && targetUserIds.length === 1) {
    const target = targetUserIds[0];
    const repeated = recent.some((value) => {
      if (
        !isRecord(value) ||
        readNumber(value.createdAt) < now - config.NUDGE_RECIPIENT_COOLDOWN_SECONDS
      ) {
        return false;
      }
      return Array.isArray(value.targetUserIds) && value.targetUserIds.includes(target);
    });
    if (repeated) {
      logger.warn(
        {
          checkpoint: "NUDGE-BE-W2",
          reason: "recipient_cooldown",
          retryAfterSeconds: config.NUDGE_RECIPIENT_COOLDOWN_SECONDS
        },
        "nudge request rate limited before FCM send"
      );
      throw new HttpError(
        429,
        "nudge_rate_limited",
        `Please wait ${config.NUDGE_RECIPIENT_COOLDOWN_SECONDS} seconds before nudging this friend again.`
      );
    }
  }
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
    throw new HttpError(401, "missing_delivery_token", "Voice nudge delivery token is required.");
  }
  const snapshot = await getRealtimeDatabase().ref(`voiceNudges/${eventId}`).get();
  if (!snapshot.exists() || !isRecord(snapshot.val())) {
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
