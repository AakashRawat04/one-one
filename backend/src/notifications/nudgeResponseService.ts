import { config } from "../config.js";
import { getRealtimeDatabase } from "../firebase/database.js";
import { sendAndroidDataPushes } from "../firebase/messaging.js";
import { requireActiveGroup, requireActiveGroupMember } from "../groups/groupService.js";
import { HttpError } from "../http/httpError.js";
import { logger } from "../logger.js";

export type NudgeResponseAction = "accept" | "decline" | "snooze";

type RecipientDevice = {
  fcmToken: string;
};

export async function respondToNudge(input: {
  groupId: string;
  eventId: string;
  responderUserId: string;
  action: NudgeResponseAction;
}) {
  await requireActiveGroup(input.groupId);
  await requireActiveGroupMember(input.groupId, input.responderUserId);

  const db = getRealtimeDatabase();
  const eventSnapshot = await db
    .ref(`notificationEvents/${input.groupId}/${input.eventId}`)
    .get();
  if (!eventSnapshot.exists() || !isRecord(eventSnapshot.val())) {
    throw new HttpError(404, "nudge_not_found", "This nudge is no longer available.");
  }

  const event = eventSnapshot.val() as Record<string, unknown>;
  const eventType = String(event.eventType ?? "");
  if (!["nudge", "ring_nudge", "voice_nudge"].includes(eventType)) {
    throw new HttpError(409, "nudge_not_actionable", "This notification cannot be answered.");
  }

  const targetUserIds = Array.isArray(event.targetUserIds)
    ? event.targetUserIds.map(String)
    : [];
  if (!targetUserIds.includes(input.responderUserId)) {
    throw new HttpError(403, "nudge_response_forbidden", "You are not a recipient of this nudge.");
  }

  const senderUserId = String(event.senderUserId ?? "");
  if (!senderUserId) {
    throw new HttpError(409, "nudge_sender_missing", "This nudge has no sender.");
  }

  const responseRef = db.ref(
    `nudgeResponses/${input.eventId}/${input.responderUserId}`
  );
  const previous = await responseRef.get();
  if (previous.child("action").val() === input.action) {
    return {
      eventId: input.eventId,
      action: input.action,
      deduped: true
    };
  }

  const now = nowSeconds();
  const snoozedUntil = input.action === "snooze" ? now + 5 * 60 : null;
  await db.ref().update({
    [`nudgeResponses/${input.eventId}/${input.responderUserId}`]: {
      eventId: input.eventId,
      groupId: input.groupId,
      responderUserId: input.responderUserId,
      senderUserId,
      action: input.action,
      respondedAt: now,
      snoozedUntil
    },
    [`statusEvents/${input.groupId}/${input.eventId}_${input.responderUserId}`]: {
      eventId: `${input.eventId}_${input.responderUserId}`,
      groupId: input.groupId,
      userId: input.responderUserId,
      eventType: `nudge_${input.action}`,
      metadata: {
        notificationEventId: input.eventId,
        senderUserId,
        snoozedUntil
      },
      createdAt: now
    }
  });

  const responderName = await readDisplayName(input.responderUserId);
  const devices = await collectAndroidDevices(senderUserId);
  const baseUrl = config.PUBLIC_API_BASE_URL.replace(/\/$/, "");
  const pushResult = await sendAndroidDataPushes(
    devices.map((device) => ({
      token: device.fcmToken,
      data: {
        type: "nudge_response",
        eventId: input.eventId,
        groupId: input.groupId,
        responderUserId: input.responderUserId,
        responderName,
        responseAction: input.action,
        snoozedUntil: snoozedUntil == null ? "" : String(snoozedUntil),
        responseUrl: `${baseUrl}/v1/groups/${input.groupId}/nudges/${input.eventId}/respond`
      }
    })),
    10 * 60 * 1000
  );

  logger.info(
    {
      checkpoint: "NUDGE-RESPONSE-BE-01",
      eventId: input.eventId,
      action: input.action,
      targetDevices: devices.length,
      sent: pushResult.successCount,
      failed: pushResult.failureCount
    },
    "nudge response stored and sender notified"
  );

  return {
    eventId: input.eventId,
    action: input.action,
    snoozedUntil,
    deduped: false,
    senderDevices: devices.length,
    sent: pushResult.successCount
  };
}

async function collectAndroidDevices(userId: string) {
  const snapshot = await getRealtimeDatabase().ref(`userDevices/${userId}`).get();
  if (!snapshot.exists() || !isRecord(snapshot.val())) return [];
  const devices: RecipientDevice[] = [];
  for (const value of Object.values(snapshot.val() as Record<string, unknown>)) {
    if (!isRecord(value) || value.deviceState !== "active" || value.platform !== "android") {
      continue;
    }
    const fcmToken = value.fcmToken?.toString().trim();
    if (fcmToken) devices.push({ fcmToken });
  }
  return devices;
}

async function readDisplayName(userId: string) {
  const snapshot = await getRealtimeDatabase().ref(`users/${userId}/displayName`).get();
  return snapshot.val()?.toString() || "Your friend";
}

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
