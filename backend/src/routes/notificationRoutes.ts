import express, { Router } from "express";
import { z } from "zod";
import { requireFirebaseAuth, type AuthenticatedRequest } from "../firebase/auth.js";
import { asyncHandler } from "../http/asyncHandler.js";
import {
  sendFriendLiveNotification,
  sendNudgeNotification
} from "../notifications/notificationService.js";
import {
  acknowledgeVoiceNudge,
  createVoiceNudge,
  downloadVoiceNudge,
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

const ringNudgeSchema = z.object({
  targetScope: z.enum(["single_friend", "all_friends"]),
  targetUserId: z.string().min(1).optional(),
  durationSeconds: z.union([z.literal(3), z.literal(5), z.literal(10)])
});

const voiceNudgeAckSchema = z.object({
  status: z.enum(["played", "failed"])
});

const nudgeResponseSchema = z.object({
  action: z.enum(["accept", "decline", "snooze"])
});

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
          action: body.action
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
      const audio = await downloadVoiceNudge(eventId, token);
      response
        .status(200)
        .set({
          "content-type": "audio/mp4",
          "cache-control": "private, no-store, max-age=0",
          "content-length": String(audio.length)
        })
        .send(audio);
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
