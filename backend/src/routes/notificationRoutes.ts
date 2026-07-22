import express, { Router } from "express";
import { z } from "zod";
import { getRealtimeDatabase } from "../firebase/database.js";
import { requireFirebaseAuth, type AuthenticatedRequest } from "../firebase/auth.js";
import { asyncHandler } from "../http/asyncHandler.js";
import {
  acknowledgeVoiceNudge,
  completeVoiceNudgeUpload,
  createVoiceNudge,
  initiateVoiceNudgeUpload,
  resolveVoiceNudgeAudioRedirect,
  sendRingNudge
} from "../notifications/voiceNudgeService.js";
import { maxVoiceNudgeBytes } from "../notifications/voiceNudgeValidation.js";
import { respondToNudge } from "../notifications/nudgeResponseService.js";
import {
  sendFriendLiveNotification,
  sendNudgeNotification
} from "../notifications/notificationService.js";

const friendLiveSchema = z.object({
  deviceId: z.string().min(1),
  serviceSessionId: z.string().min(1),
  livekitSessionId: z.string().min(1)
});

const nudgeSchema = z.discriminatedUnion("targetScope", [
  z.object({
    targetScope: z.literal("single_friend"),
    targetUserId: z.string().min(1)
  }),
  z.object({
    targetScope: z.literal("all_friends")
  })
]);

const voiceNudgeQuerySchema = z.object({
  targetScope: z.enum(["single_friend", "all_friends"]),
  targetUserId: z.string().min(1).optional()
});

const recipientDeviceSchema = z.object({
  userId: z.string().min(1),
  deviceId: z.string().min(1),
  fcmToken: z.string().min(1)
});

const voiceNudgeUploadSchema = z.discriminatedUnion("targetScope", [
  z.object({
    targetScope: z.literal("single_friend"),
    targetUserId: z.string().min(1),
    durationMs: z.number().int().positive(),
    // New fields — client provides these when reading RTDB directly.
    // Optional during migration; backend falls back to RTDB reads if missing.
    recipientDevices: z.array(recipientDeviceSchema).min(1).optional(),
    senderName: z.string().min(1).optional()
  }),
  z.object({
    targetScope: z.literal("all_friends"),
    durationMs: z.number().int().positive(),
    recipientDevices: z.array(recipientDeviceSchema).min(1).optional(),
    senderName: z.string().min(1).optional()
  })
]);

const voiceNudgeCompleteSchema = z.object({
  uploadTicket: z.string().min(1)
});

const ringNudgeSchema = z.object({
  targetScope: z.enum(["single_friend", "all_friends"]),
  targetUserId: z.string().min(1).optional(),
  durationSeconds: z.union([z.literal(3), z.literal(5), z.literal(10)]),
  // Optional during migration; backend falls back to RTDB reads if missing.
  recipientDevices: z.array(recipientDeviceSchema).min(1).optional(),
  senderName: z.string().min(1).optional()
});

const voiceNudgeAckSchema = z.object({
  status: z.enum(["played", "failed"])
});

const nudgeResponseSchema = z.discriminatedUnion("action", [
  z.object({ action: z.literal("accept") }),
  z.object({ action: z.literal("decline") }),
  z.object({
    action: z.literal("snooze"),
    // Preserve compatibility with installed builds that sent a bare snooze.
    snoozeMinutes: z.union([z.literal(5), z.literal(15)]).default(5)
  })
]);

export function createNotificationRoutes() {
  const router = Router();

  router.post(
    "/v1/groups/:groupId/notifications/friend-live",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      const groupId = z.string().min(1).parse(request.params.groupId);
      const body = friendLiveSchema.parse(request.body);
      const result = await sendFriendLiveNotification({
        groupId,
        senderUserId: authRequest.auth.uid,
        deviceId: body.deviceId,
        serviceSessionId: body.serviceSessionId,
        livekitSessionId: body.livekitSessionId
      });

      response.status(200).json(result);
    })
  );

  router.post(
    "/v1/groups/:groupId/nudges",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      const groupId = z.string().min(1).parse(request.params.groupId);
      const body = nudgeSchema.parse(request.body);
      const result = await sendNudgeNotification({
        groupId,
        senderUserId: authRequest.auth.uid,
        targetScope: body.targetScope,
        targetUserId: "targetUserId" in body ? body.targetUserId : undefined
      });

      response.status(200).json(result);
    })
  );

  router.post(
    "/v1/groups/:groupId/nudges/:eventId/respond",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      const groupId = z.string().min(1).parse(request.params.groupId);
      const eventId = z.string().min(1).parse(request.params.eventId);
      const body = nudgeResponseSchema.parse(request.body);
      response.status(200).json(
        await respondToNudge({
          groupId,
          eventId,
          responderUserId: authRequest.auth.uid,
          action: body.action,
          snoozeMinutes: body.action === "snooze" ? body.snoozeMinutes : undefined
        })
      );
    })
  );

  router.post(
    "/v1/groups/:groupId/ring-nudges",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      const groupId = z.string().min(1).parse(request.params.groupId);
      const body = ringNudgeSchema.parse(request.body);

      // Backward compat: old clients don't send recipientDevices/senderName.
      let recipientDevices = body.recipientDevices;
      let senderName = body.senderName;

      if (!recipientDevices || !senderName) {
        const db = getRealtimeDatabase();

        const targetUserId = body.targetUserId;
        let recipientUserIds: string[];
        if (body.targetScope === "single_friend" && targetUserId) {
          recipientUserIds = targetUserId !== authRequest.auth.uid
            ? [targetUserId] : [];
        } else {
          const snap = await db.ref(`groupMembers/${groupId}`).get();
          recipientUserIds = [];
          if (snap.exists()) {
            const members = snap.val() as Record<string, unknown>;
            for (const [uid, val] of Object.entries(members)) {
              if (
                uid !== authRequest.auth.uid &&
                typeof val === "object" && val !== null &&
                (val as Record<string, unknown>).memberState === "active"
              ) {
                recipientUserIds.push(uid);
              }
            }
          }
        }

        const devices: Array<{ userId: string; deviceId: string; fcmToken: string }> = [];
        for (const uid of recipientUserIds) {
          const devSnap = await db.ref(`userDevices/${uid}`).get();
          if (!devSnap.exists()) continue;
          const devs = devSnap.val() as Record<string, unknown>;
          for (const [devId, dv] of Object.entries(devs)) {
            if (
              typeof dv === "object" && dv !== null &&
              (dv as Record<string, unknown>).deviceState === "active" &&
              (dv as Record<string, unknown>).platform === "android"
            ) {
              const tok = (dv as Record<string, unknown>).fcmToken;
              if (typeof tok === "string" && tok) {
                devices.push({ userId: uid, deviceId: devId, fcmToken: tok });
              }
            }
          }
        }
        recipientDevices = devices;

        const nameSnap = await db.ref(`users/${authRequest.auth.uid}/displayName`).get();
        senderName = nameSnap.val()?.toString() || "Someone";
      }

      const result = await sendRingNudge({
        groupId,
        senderUserId: authRequest.auth.uid,
        targetScope: body.targetScope,
        targetUserId: body.targetUserId,
        durationSeconds: body.durationSeconds,
        recipientDevices: recipientDevices!,
        senderName: senderName!
      });
      response.status(200).json(result);
    })
  );

  router.post(
    "/v1/groups/:groupId/voice-nudges/uploads",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      const groupId = z.string().min(1).parse(request.params.groupId);
      const body = voiceNudgeUploadSchema.parse(request.body);

      // Backward compat: old clients don't send recipientDevices/senderName.
      // Fall back to RTDB reads until all clients are updated.
      let recipientDevices = body.recipientDevices;
      let senderName = body.senderName;

      if (!recipientDevices || !senderName) {
        const db = getRealtimeDatabase();

        // Resolve recipients
        const targetUserId =
          "targetUserId" in body ? body.targetUserId : undefined;
        let recipientUserIds: string[];
        if (targetUserId) {
          recipientUserIds = targetUserId !== authRequest.auth.uid
            ? [targetUserId]
            : [];
        } else {
          const memberSnap = await db.ref(`groupMembers/${groupId}`).get();
          recipientUserIds = [];
          if (memberSnap.exists()) {
            const members = memberSnap.val() as Record<string, unknown>;
            for (const [uid, val] of Object.entries(members)) {
              if (
                uid !== authRequest.auth.uid &&
                typeof val === "object" && val !== null &&
                (val as Record<string, unknown>).memberState === "active"
              ) {
                recipientUserIds.push(uid);
              }
            }
          }
        }

        // Read recipient devices (FCM tokens) from RTDB
        const devices: Array<{ userId: string; deviceId: string; fcmToken: string }> = [];
        for (const uid of recipientUserIds) {
          const devSnap = await db.ref(`userDevices/${uid}`).get();
          if (!devSnap.exists()) continue;
          const devs = devSnap.val() as Record<string, unknown>;
          for (const [devId, dv] of Object.entries(devs)) {
            if (
              typeof dv === "object" && dv !== null &&
              (dv as Record<string, unknown>).deviceState === "active" &&
              (dv as Record<string, unknown>).platform === "android"
            ) {
              const tok = (dv as Record<string, unknown>).fcmToken;
              if (typeof tok === "string" && tok) {
                devices.push({ userId: uid, deviceId: devId, fcmToken: tok });
              }
            }
          }
        }
        recipientDevices = devices;

        // Read display name from RTDB
        const nameSnap = await db.ref(`users/${authRequest.auth.uid}/displayName`).get();
        senderName = nameSnap.val()?.toString() || "Someone";
      }

      const result = await initiateVoiceNudgeUpload({
        groupId,
        senderUserId: authRequest.auth.uid,
        targetScope: body.targetScope,
        targetUserId: "targetUserId" in body ? body.targetUserId : undefined,
        durationMs: body.durationMs,
        recipientDevices: recipientDevices!,
        senderName: senderName!
      });
      response.status(201).json(result);
    })
  );

  router.post(
    "/v1/groups/:groupId/voice-nudges/:eventId/complete",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const body = voiceNudgeCompleteSchema.parse(request.body);
      const result = await completeVoiceNudgeUpload({
        uploadTicket: body.uploadTicket
      });
      response.status(200).json(result);
    })
  );

  // Legacy: raw audio through the API. Prefer /voice-nudges/uploads + /complete.
  router.post(
    "/v1/groups/:groupId/voice-nudges",
    requireFirebaseAuth,
    express.raw({ type: ["audio/mp4", "application/octet-stream"], limit: maxVoiceNudgeBytes }),
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      const groupId = z.string().min(1).parse(request.params.groupId);
      const query = voiceNudgeQuerySchema.parse(request.query);
      const durationMs = z.coerce
        .number()
        .int()
        .positive()
        .parse(request.header("x-voice-duration-ms"));
      if (!Buffer.isBuffer(request.body)) {
        response.status(415).json({
          error: "unsupported_media_type",
          message: "Voice nudge body must use audio/mp4."
        });
        return;
      }

      const result = await createVoiceNudge({
        groupId,
        senderUserId: authRequest.auth.uid,
        targetScope: query.targetScope,
        targetUserId: query.targetUserId,
        durationMs,
        audio: request.body
      });
      response.status(201).json(result);
    })
  );

  // Deprecated — audio is delivered via signed URL in the FCM payload.
  // Kept for backward compatibility; throws 410 for any caller.
  router.get(
    "/v1/voice-nudges/:eventId/audio",
    asyncHandler(async (request, response) => {
      const eventId = z.string().min(1).parse(request.params.eventId);
      const token = request.header("x-one-one-delivery-token") ?? "";
      // resolveVoiceNudgeAudioRedirect now throws HttpError(410) — audio
      // must be fetched via the signed URL in the FCM data payload.
      await resolveVoiceNudgeAudioRedirect(eventId, token);
    })
  );

  router.post(
    "/v1/voice-nudges/:eventId/ack",
    asyncHandler(async (request, response) => {
      const eventId = z.string().min(1).parse(request.params.eventId);
      const token = request.header("x-one-one-delivery-token") ?? "";
      const body = voiceNudgeAckSchema.parse(request.body);
      response.status(200).json(await acknowledgeVoiceNudge(eventId, token, body.status));
    })
  );

  return router;
}
