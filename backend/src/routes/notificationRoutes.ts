import express, { Router } from "express";
import { z } from "zod";
import { requireFirebaseAuth, type AuthenticatedRequest } from "../firebase/auth.js";
import { asyncHandler } from "../http/asyncHandler.js";
import { logger } from "../logger.js";
import {
  sendFriendLiveNotification,
  sendNudgeNotification
} from "../notifications/notificationService.js";
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

const voiceNudgeUploadSchema = z.discriminatedUnion("targetScope", [
  z.object({
    targetScope: z.literal("single_friend"),
    targetUserId: z.string().min(1),
    durationMs: z.number().int().positive()
  }),
  z.object({
    targetScope: z.literal("all_friends"),
    durationMs: z.number().int().positive()
  })
]);

const ringNudgeSchema = z.object({
  targetScope: z.enum(["single_friend", "all_friends"]),
  targetUserId: z.string().min(1).optional(),
  durationSeconds: z.union([z.literal(3), z.literal(5), z.literal(10)])
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
      const result = await sendRingNudge({
        groupId,
        senderUserId: authRequest.auth.uid,
        targetScope: body.targetScope,
        targetUserId: body.targetUserId,
        durationSeconds: body.durationSeconds
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
      const result = await initiateVoiceNudgeUpload({
        groupId,
        senderUserId: authRequest.auth.uid,
        targetScope: body.targetScope,
        targetUserId: "targetUserId" in body ? body.targetUserId : undefined,
        durationMs: body.durationMs
      });
      response.status(201).json(result);
    })
  );

  router.post(
    "/v1/groups/:groupId/voice-nudges/:eventId/complete",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      const groupId = z.string().min(1).parse(request.params.groupId);
      const eventId = z.string().min(1).parse(request.params.eventId);
      const result = await completeVoiceNudgeUpload({
        groupId,
        eventId,
        senderUserId: authRequest.auth.uid
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

  router.get(
    "/v1/voice-nudges/:eventId/audio",
    asyncHandler(async (request, response) => {
      const eventId = z.string().min(1).parse(request.params.eventId);
      const token = request.header("x-one-one-delivery-token") ?? "";
      // Compatibility path for older clients: validate the delivery token,
      // then 302 to a Cloud Storage signed URL so audio bytes never leave
      // Storage through the API process.
      const { signedUrl, deliveryId } = await resolveVoiceNudgeAudioRedirect(eventId, token);
      logger.info(
        {
          checkpoint: "VOICE-NUDGE-BE-05",
          category: "expected",
          eventId,
          deliveryId,
          egress: "signed_url_redirect"
        },
        "voice nudge audio redirect issued to recipient device"
      );
      response
        .status(302)
        .set({
          location: signedUrl,
          "cache-control": "private, no-store, max-age=0"
        })
        .end();
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
