import { Router } from "express";
import { z } from "zod";
import { requireFirebaseAuth, type AuthenticatedRequest } from "../firebase/auth.js";
import { asyncHandler } from "../http/asyncHandler.js";
import { createGroup, createInvite, joinInvite } from "../groups/groupService.js";
import { config } from "../config.js";

const createGroupSchema = z.object({
  name: z.string().trim().min(1).max(48)
});

const createInviteSchema = z.object({
  maxUses: z.coerce.number().int().min(1).max(3).default(3),
  expiresInHours: z.coerce.number().int().min(1).max(168).default(72)
});

const joinInviteSchema = z.object({
  inviteCode: z.string().trim().min(4).max(64)
});

export function createGroupRoutes() {
  const router = Router();

  // HTTPS invite links are Android App Links when domain verification is
  // configured. The redirect remains a fallback for devices that have not
  // verified the domain yet but do have One One installed.
  router.get("/invite/:inviteCode", (request, response) => {
    const inviteCode = joinInviteSchema.shape.inviteCode.parse(
      request.params.inviteCode
    );
    response.setHeader("Cache-Control", "no-store");
    response.redirect(302, `oneone://invite/${encodeURIComponent(inviteCode)}`);
  });

  router.get("/.well-known/assetlinks.json", (_request, response) => {
    const fingerprints = (config.ANDROID_APP_LINK_SHA256_CERT_FINGERPRINTS ?? "")
      .split(",")
      .map((value) => value.trim().toUpperCase())
      .filter(Boolean);
    response.setHeader("Cache-Control", "public, max-age=300");
    response.json(
      fingerprints.length === 0
        ? []
        : [
            {
              relation: ["delegate_permission/common.handle_all_urls"],
              target: {
                namespace: "android_app",
                package_name: "app.oneone.one_one_app",
                sha256_cert_fingerprints: fingerprints
              }
            }
          ]
    );
  });

  router.post(
    "/v1/groups",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      const body = createGroupSchema.parse(request.body);
      const result = await createGroup({
        ownerUserId: authRequest.auth.uid,
        name: body.name
      });

      response.status(201).json(result);
    })
  );

  router.post(
    "/v1/groups/:groupId/invites",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      const groupId = z.string().min(1).parse(request.params.groupId);
      const body = createInviteSchema.parse(request.body);
      const result = await createInvite({
        groupId,
        userId: authRequest.auth.uid,
        maxUses: body.maxUses,
        expiresInHours: body.expiresInHours
      });

      response.status(201).json(result);
    })
  );

  router.post(
    "/v1/invites/join",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      const body = joinInviteSchema.parse(request.body);
      const result = await joinInvite({
        userId: authRequest.auth.uid,
        inviteCode: body.inviteCode
      });

      response.status(200).json(result);
    })
  );

  return router;
}
