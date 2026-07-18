import { getRealtimeDatabase } from "../firebase/database.js";
import { sendPushToTokens } from "../firebase/messaging.js";
import {
  requireActiveGroup,
  requireActiveGroupMember,
  requireActiveUser,
  requireActiveUserDevice
} from "../groups/groupService.js";
import { HttpError } from "../http/httpError.js";

export type FriendLiveInput = {
  groupId: string;
  senderUserId: string;
  deviceId: string;
  serviceSessionId: string;
  livekitSessionId: string;
};

export type NudgeInput = {
  groupId: string;
  senderUserId: string;
  targetScope: "single_friend" | "all_friends";
  targetUserId?: string;
};

type RecipientDevice = {
  userId: string;
  deviceId: string;
  fcmToken: string;
};

const friendLiveDedupeSeconds = 60;
const sameRecipientNudgeSeconds = 60;
const senderGroupNudgeLimitSeconds = 10 * 60;
const senderGroupNudgeLimit = 5;

export async function sendFriendLiveNotification(input: FriendLiveInput) {
  const db = getRealtimeDatabase();
  await requireActiveUser(input.senderUserId);
  await requireActiveGroup(input.groupId);
  await requireActiveGroupMember(input.groupId, input.senderUserId);
  await requireActiveUserDevice(input.senderUserId, input.deviceId);

  const availabilitySnapshot = await db
    .ref(`memberAvailability/${input.groupId}/${input.senderUserId}`)
    .get();

  if (!availabilitySnapshot.exists()) {
    throw new HttpError(409, "availability_missing", "Sender availability is missing.");
  }

  if (
    availabilitySnapshot.child("desiredState").val() !== "online" ||
    availabilitySnapshot.child("effectiveState").val() !== "live" ||
    availabilitySnapshot.child("canReceiveLiveAudio").val() !== true
  ) {
    throw new HttpError(
      409,
      "sender_not_live",
      "Friend-live notification can only be sent after the sender is effectively live."
    );
  }

  const now = nowSeconds();
  const dedupedEvent = await findRecentNotificationEvent({
    groupId: input.groupId,
    senderUserId: input.senderUserId,
    eventType: "friend_live",
    since: now - friendLiveDedupeSeconds
  });

  if (dedupedEvent) {
    return {
      notificationEventId: dedupedEvent.notificationEventId,
      eventType: "friend_live",
      deduped: true,
      recipientUsers: dedupedEvent.targetUserIds.length,
      targetDevices: 0,
      sent: 0,
      failed: 0,
      skipped: 0
    };
  }

  const senderName = await readDisplayName(input.senderUserId);
  const recipientUserIds = await activeRecipientUserIds(input.groupId, input.senderUserId);
  const recipientDevices = await collectRecipientDevices(recipientUserIds);
  const notificationEventId = await createNotificationEvent({
    groupId: input.groupId,
    senderUserId: input.senderUserId,
    eventType: "friend_live",
    targetScope: "all_friends",
    targetUserIds: recipientUserIds,
    createdAt: now,
    metadata: {
      serviceSessionId: input.serviceSessionId,
      livekitSessionId: input.livekitSessionId
    }
  });

  const pushResult = await sendPushToTokens({
    tokens: recipientDevices.map((device) => device.fcmToken),
    title: `${senderName} is live`,
    body: "Tap to open One One",
    data: {
      type: "friend_live",
      groupId: input.groupId,
      senderUserId: input.senderUserId,
      deepLink: `walkie://group/${input.groupId}`
    }
  });

  await writeDeliveries(notificationEventId, recipientDevices, pushResult);
  await writeStatusEvent(input.groupId, input.senderUserId, "friend_live_notification_sent", {
    notificationEventId
  });

  return {
    notificationEventId,
    eventType: "friend_live",
    deduped: false,
    recipientUsers: recipientUserIds.length,
    targetDevices: recipientDevices.length,
    sent: pushResult.successCount,
    failed: pushResult.failureCount,
    skipped: recipientUserIds.length === 0 ? 1 : 0
  };
}

export async function sendNudgeNotification(input: NudgeInput) {
  const db = getRealtimeDatabase();
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
  await enforceNudgeRateLimits(input, now);

  const senderName = await readDisplayName(input.senderUserId);
  const recipientUserIds =
    input.targetScope === "single_friend"
      ? [input.targetUserId!].filter((userId) => userId !== input.senderUserId)
      : await activeRecipientUserIds(input.groupId, input.senderUserId);
  const recipientDevices = await collectRecipientDevices(recipientUserIds);
  const notificationEventId = await createNotificationEvent({
    groupId: input.groupId,
    senderUserId: input.senderUserId,
    eventType: "nudge",
    targetScope: input.targetScope,
    targetUserIds: recipientUserIds,
    createdAt: now,
    metadata: {}
  });

  const pushResult = await sendPushToTokens({
    tokens: recipientDevices.map((device) => device.fcmToken),
    title: `${senderName} nudged you`,
    body: "Come online on One One",
    data: {
      type: "nudge",
      groupId: input.groupId,
      senderUserId: input.senderUserId,
      deepLink: `walkie://group/${input.groupId}`
    }
  });

  await writeDeliveries(notificationEventId, recipientDevices, pushResult);
  await writeStatusEvent(input.groupId, input.senderUserId, "nudge_sent", {
    notificationEventId,
    targetScope: input.targetScope
  });

  return {
    notificationEventId,
    eventType: "nudge",
    rateLimited: false,
    recipientUsers: recipientUserIds.length,
    targetDevices: recipientDevices.length,
    sent: pushResult.successCount,
    failed: pushResult.failureCount,
    skipped: recipientUserIds.length === 0 ? 1 : 0
  };
}

async function enforceNudgeRateLimits(input: NudgeInput, now: number) {
  const snapshot = await getRealtimeDatabase().ref(`notificationEvents/${input.groupId}`).get();
  const recentGroupNudges = !snapshot.exists() || !isRecord(snapshot.val())
    ? []
    : Object.values(snapshot.val() as Record<string, unknown>)
        .filter(isNotificationEvent)
        .filter((event) => {
          return (
            event.senderUserId === input.senderUserId &&
            ["nudge", "ring_nudge", "voice_nudge"].includes(event.eventType) &&
            event.createdAt >= now - senderGroupNudgeLimitSeconds
          );
        });

  if (recentGroupNudges.length >= senderGroupNudgeLimit) {
    throw new HttpError(429, "nudge_rate_limited", "Too many nudges sent in this group.");
  }

  if (input.targetScope === "single_friend" && input.targetUserId) {
    const recentSameRecipient = recentGroupNudges.some((event) => {
      return (
        event.createdAt >= now - sameRecipientNudgeSeconds &&
        event.targetUserIds.includes(input.targetUserId!)
      );
    });

    if (recentSameRecipient) {
      throw new HttpError(429, "nudge_rate_limited", "This friend was nudged too recently.");
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

async function collectRecipientDevices(userIds: string[]) {
  const db = getRealtimeDatabase();
  const devices: RecipientDevice[] = [];

  for (const userId of userIds) {
    const snapshot = await db.ref(`userDevices/${userId}`).get();
    if (!snapshot.exists() || !isRecord(snapshot.val())) continue;

    for (const [deviceId, value] of Object.entries(snapshot.val() as Record<string, unknown>)) {
      if (!isRecord(value)) continue;
      if (value.deviceState !== "active") continue;
      const fcmToken = value.fcmToken?.toString();
      if (!fcmToken) continue;

      devices.push({
        userId,
        deviceId,
        fcmToken
      });
    }
  }

  return devices;
}

async function createNotificationEvent(input: {
  groupId: string;
  senderUserId: string;
  eventType: string;
  targetScope: string;
  targetUserIds: string[];
  createdAt: number;
  metadata: Record<string, unknown>;
}) {
  const ref = getRealtimeDatabase().ref(`notificationEvents/${input.groupId}`).push();
  const notificationEventId = ref.key;
  if (!notificationEventId) {
    throw new HttpError(500, "notification_event_id_failed", "Failed to allocate notification event id.");
  }

  await ref.set({
    notificationEventId,
    groupId: input.groupId,
    senderUserId: input.senderUserId,
    eventType: input.eventType,
    targetScope: input.targetScope,
    targetUserIds: input.targetUserIds,
    createdAt: input.createdAt,
    metadata: input.metadata
  });

  return notificationEventId;
}

async function writeDeliveries(
  notificationEventId: string,
  recipientDevices: RecipientDevice[],
  pushResult: {
    successCount: number;
    failureCount: number;
    responses: Array<{ success: boolean; messageId?: string; error?: unknown }>;
  }
) {
  const updates: Record<string, unknown> = {};
  const now = nowSeconds();

  recipientDevices.forEach((device, index) => {
    const response = pushResult.responses[index];
    const deliveryId = `${device.userId}_${device.deviceId}`;
    updates[`notificationDeliveries/${notificationEventId}/${deliveryId}`] = {
      notificationEventId,
      userId: device.userId,
      deviceId: device.deviceId,
      fcmTokenTail: device.fcmToken.slice(-8),
      deliveryState: response?.success ? "sent" : "failed",
      fcmMessageId: response?.messageId ?? null,
      errorCode: response?.error ? String(response.error) : null,
      attemptedAt: now
    };
  });

  if (Object.keys(updates).length > 0) {
    await getRealtimeDatabase().ref().update(updates);
  }
}

async function writeStatusEvent(
  groupId: string,
  userId: string,
  eventType: string,
  metadata: Record<string, unknown>
) {
  const ref = getRealtimeDatabase().ref(`statusEvents/${groupId}`).push();
  const eventId = ref.key;
  if (!eventId) return;

  await ref.set({
    eventId,
    groupId,
    userId,
    eventType,
    metadata,
    createdAt: nowSeconds()
  });
}

async function readDisplayName(userId: string) {
  const snapshot = await getRealtimeDatabase().ref(`users/${userId}/displayName`).get();
  return snapshot.val()?.toString() || "Someone";
}

async function findRecentNotificationEvent(input: {
  groupId: string;
  senderUserId: string;
  eventType: string;
  since: number;
}) {
  const events = await listRecentNotificationEvents(input);
  return events[0] ?? null;
}

async function listRecentNotificationEvents(input: {
  groupId: string;
  senderUserId: string;
  eventType: string;
  since: number;
}) {
  const snapshot = await getRealtimeDatabase().ref(`notificationEvents/${input.groupId}`).get();
  if (!snapshot.exists() || !isRecord(snapshot.val())) return [];

  return Object.values(snapshot.val() as Record<string, unknown>)
    .filter(isNotificationEvent)
    .filter((event) => {
      return (
        event.senderUserId === input.senderUserId &&
        event.eventType === input.eventType &&
        event.createdAt >= input.since
      );
    })
    .sort((a, b) => b.createdAt - a.createdAt);
}

type NotificationEventRecord = {
  notificationEventId: string;
  senderUserId: string;
  eventType: string;
  targetUserIds: string[];
  createdAt: number;
};

function isNotificationEvent(value: unknown): value is NotificationEventRecord {
  if (!isRecord(value)) return false;

  return (
    typeof value.notificationEventId === "string" &&
    typeof value.senderUserId === "string" &&
    typeof value.eventType === "string" &&
    typeof value.createdAt === "number" &&
    Array.isArray(value.targetUserIds)
  );
}

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
