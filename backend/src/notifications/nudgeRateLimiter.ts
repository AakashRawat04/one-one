import { config } from "../config.js";
import { getRealtimeDatabase } from "../firebase/database.js";
import { HttpError } from "../http/httpError.js";
import { logger } from "../logger.js";

export type NudgeEventType = "nudge" | "ring_nudge" | "voice_nudge";

export type EnforceNudgeRateLimitsInput = {
  groupId: string;
  senderUserId: string;
  eventType: NudgeEventType;
  targetUserIds: string[];
};

type NotificationEventRecord = {
  senderUserId: string;
  eventType: string;
  targetUserIds: string[];
  createdAt: number;
};

/**
 * Single source of truth for nudge spam/cooldown rules. Push, ring, and
 * voice nudges all call this before dispatching so the configured limits
 * (backend/src/config.ts) stay consistent across every nudge type instead
 * of being duplicated per send-path.
 */
/**
 * Maximum number of notification event records the rate limiter will
 * download from RTDB. 50 is well above every configured limit
 * (NUDGE_RATE_LIMIT_MAX_PER_GROUP=30, NUDGE_SPAM_MAX_PER_WINDOW=10)
 * so the limiter can enforce all rules without ever pulling unbounded
 * history over the wire.
 */
const rateLimitQueryCap = 50;

export async function enforceNudgeRateLimits(input: EnforceNudgeRateLimitsInput) {
  const now = nowSeconds();
  const snapshot = await getRealtimeDatabase()
    .ref(`notificationEvents/${input.groupId}`)
    .orderByChild("createdAt")
    .limitToLast(rateLimitQueryCap)
    .get();
  if (!snapshot.exists() || !isRecord(snapshot.val())) return;

  const senderEvents = Object.values(snapshot.val() as Record<string, unknown>).filter(
    (value): value is NotificationEventRecord => isSenderNotificationEvent(value, input.senderUserId)
  );

  enforceSpamWindow(senderEvents, now);
  enforceGroupBurstLimit(senderEvents, now);
  enforceTypeCooldown(senderEvents, input.eventType, now);
  enforceRecipientCooldown(senderEvents, input.targetUserIds, now);
}

function enforceSpamWindow(events: NotificationEventRecord[], now: number) {
  const windowSeconds = config.NUDGE_SPAM_WINDOW_SECONDS;
  const withinWindow = events.filter((event) => event.createdAt >= now - windowSeconds);
  if (withinWindow.length < config.NUDGE_SPAM_MAX_PER_WINDOW) return;

  const oldestCreatedAt = Math.min(...withinWindow.map((event) => event.createdAt));
  const retryAfterSeconds = Math.max(1, oldestCreatedAt + windowSeconds - now);
  logger.warn(
    {
      checkpoint: "NUDGE-BE-W4",
      category: "expected",
      reason: "spam_window",
      recentCount: withinWindow.length,
      configuredLimit: config.NUDGE_SPAM_MAX_PER_WINDOW,
      windowSeconds,
      retryAfterSeconds
    },
    "nudge request rate limited before FCM send"
  );
  throw new HttpError(
    429,
    "nudge_rate_limited",
    `You're sending nudges too quickly. Try again in ${retryAfterSeconds} seconds.`
  );
}

function enforceGroupBurstLimit(events: NotificationEventRecord[], now: number) {
  const windowSeconds = config.NUDGE_RATE_LIMIT_WINDOW_SECONDS;
  const withinWindow = events.filter((event) => event.createdAt >= now - windowSeconds);
  if (withinWindow.length < config.NUDGE_RATE_LIMIT_MAX_PER_GROUP) return;

  const oldestCreatedAt = Math.min(...withinWindow.map((event) => event.createdAt));
  const retryAfterSeconds = Math.max(1, oldestCreatedAt + windowSeconds - now);
  logger.warn(
    {
      checkpoint: "NUDGE-BE-W1",
      category: "expected",
      reason: "group_limit",
      recentCount: withinWindow.length,
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

function enforceTypeCooldown(
  events: NotificationEventRecord[],
  eventType: NudgeEventType,
  now: number
) {
  const cooldownSeconds = cooldownSecondsFor(eventType);
  if (cooldownSeconds <= 0) return;

  const lastOfType = events
    .filter((event) => event.eventType === eventType)
    .reduce<number | null>(
      (latest, event) => (latest == null || event.createdAt > latest ? event.createdAt : latest),
      null
    );
  if (lastOfType == null || lastOfType < now - cooldownSeconds) return;

  const retryAfterSeconds = Math.max(1, lastOfType + cooldownSeconds - now);
  logger.warn(
    {
      checkpoint: "NUDGE-BE-W3",
      category: "expected",
      reason: "type_cooldown",
      eventType,
      cooldownSeconds,
      retryAfterSeconds
    },
    "nudge request rate limited before FCM send"
  );
  throw new HttpError(
    429,
    "nudge_rate_limited",
    `Please wait ${retryAfterSeconds} seconds before sending another ${describeEventType(eventType)}.`
  );
}

function enforceRecipientCooldown(
  events: NotificationEventRecord[],
  targetUserIds: string[],
  now: number
) {
  const cooldownSeconds = config.NUDGE_RECIPIENT_COOLDOWN_SECONDS;
  if (cooldownSeconds <= 0 || targetUserIds.length !== 1) return;

  const target = targetUserIds[0];
  const repeated = events.some((event) => {
    if (event.createdAt < now - cooldownSeconds) return false;
    return event.targetUserIds.includes(target);
  });
  if (!repeated) return;

  logger.warn(
    {
      checkpoint: "NUDGE-BE-W2",
      category: "expected",
      reason: "recipient_cooldown",
      retryAfterSeconds: cooldownSeconds
    },
    "nudge request rate limited before FCM send"
  );
  throw new HttpError(
    429,
    "nudge_rate_limited",
    `Please wait ${cooldownSeconds} seconds before nudging this friend again.`
  );
}

function cooldownSecondsFor(eventType: NudgeEventType): number {
  switch (eventType) {
    case "ring_nudge":
      return config.NUDGE_COOLDOWN_RING_SECONDS;
    case "voice_nudge":
      return config.NUDGE_COOLDOWN_VOICE_SECONDS;
    case "nudge":
      return config.NUDGE_COOLDOWN_PUSH_SECONDS;
  }
}

function describeEventType(eventType: NudgeEventType): string {
  switch (eventType) {
    case "ring_nudge":
      return "ring";
    case "voice_nudge":
      return "voice nudge";
    case "nudge":
      return "push notification";
  }
}

function isSenderNotificationEvent(
  value: unknown,
  senderUserId: string
): value is NotificationEventRecord {
  if (!isRecord(value)) return false;
  return (
    value.senderUserId === senderUserId &&
    typeof value.eventType === "string" &&
    ["nudge", "ring_nudge", "voice_nudge"].includes(value.eventType) &&
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
