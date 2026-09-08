import { Router } from "express";
import { z } from "zod";
import { requireFirebaseAuth, type AuthenticatedRequest } from "../firebase/auth.js";
import { asyncHandler } from "../http/asyncHandler.js";
import {
  createGroup,
  createInvite,
  deleteGroup,
  joinInvite,
  leaveGroup,
  listGroupMembers,
  listGroupsForUser,
  purgeUserAccount,
  removeGroupMember
} from "../groups/groupService.js";
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

const databaseKeySchema = z
  .string()
  .min(1)
  .max(128)
  .regex(/^[^.#$\[\]\/]+$/);

export function createGroupRoutes() {
  const router = Router();

  // HTTPS invite links are Android App Links when domain verification is
  // configured. For devices with the app installed, the OS intercepts this URL
  // before the browser opens it. If the browser does open this URL:
  //   • Android (no app): redirect to Play Store with the invite code as the
  //     Play Install Referrer so the app auto-joins after install.
  //   • iOS: redirect to the App Store listing.
  //   • Desktop / other: fall back to the custom-scheme deep link.
  router.get("/invite/:inviteCode", (request, response) => {
    const inviteCode = joinInviteSchema.shape.inviteCode.parse(
      request.params.inviteCode
    );
    response.setHeader("Cache-Control", "no-store");

    const ua = (request.headers["user-agent"] ?? "").toLowerCase();
    const isAndroid = ua.includes("android");

    if (isAndroid) {
      // Pass the invite code as the Play Install Referrer so
      // InstallReferrerReader.kt can recover it on first launch.
      const referrer = encodeURIComponent(`inviteCode=${inviteCode}`);
      response.redirect(
        302,
        `https://play.google.com/store/apps/details?id=app.oneone.one_one_app&referrer=${referrer}`
      );
    } else {
      // Non-Android (or unknown UA) — fall back to the custom scheme.
      response.redirect(302, `oneone://invite/${encodeURIComponent(inviteCode)}`);
    }
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

  router.get(
    "/v1/groups",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      response.status(200).json(await listGroupsForUser(authRequest.auth.uid));
    })
  );

  router.post(
    "/v1/groups/:groupId/invites",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      const groupId = databaseKeySchema.parse(request.params.groupId);
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

  router.get(
    "/v1/groups/:groupId/members",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      const groupId = databaseKeySchema.parse(request.params.groupId);
      response.status(200).json(
        await listGroupMembers({ groupId, userId: authRequest.auth.uid })
      );
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

  router.delete(
    "/v1/account",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      response.status(200).json(await purgeUserAccount(authRequest.auth.uid));
    })
  );

  router.delete(
    "/v1/groups/:groupId/members/:memberUserId",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      const groupId = databaseKeySchema.parse(request.params.groupId);
      const memberUserId = databaseKeySchema.parse(request.params.memberUserId);
      response.status(200).json(
        await removeGroupMember({
          groupId,
          userId: authRequest.auth.uid,
          memberUserId
        })
      );
    })
  );

  router.post(
    "/v1/groups/:groupId/leave",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      const groupId = databaseKeySchema.parse(request.params.groupId);
      response.status(200).json(
        await leaveGroup({ groupId, userId: authRequest.auth.uid })
      );
    })
  );

  router.delete(
    "/v1/groups/:groupId",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      const groupId = databaseKeySchema.parse(request.params.groupId);
      response.status(200).json(
        await deleteGroup({ groupId, userId: authRequest.auth.uid })
      );
    })
  );

  return router;
}
