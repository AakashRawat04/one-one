import { Router } from "express";
import { z } from "zod";
import { requireFirebaseAuth, type AuthenticatedRequest } from "../firebase/auth.js";
import { asyncHandler } from "../http/asyncHandler.js";
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

  return router;
}
