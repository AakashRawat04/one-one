import { Router } from "express";
import { z } from "zod";
import { requireFirebaseAuth, type AuthenticatedRequest } from "../firebase/auth.js";
import { asyncHandler } from "../http/asyncHandler.js";
import { redeemDeveloperAccess } from "../subscriptions/developerAccessService.js";

const redeemSchema = z.object({
  code: z.string().trim().min(8).max(128)
});

export function createSubscriptionRoutes() {
  const router = Router();

  router.post(
    "/v1/subscriptions/redeem",
    requireFirebaseAuth,
    asyncHandler(async (request, response) => {
      const authRequest = request as AuthenticatedRequest;
      const body = redeemSchema.parse(request.body);
      const result = await redeemDeveloperAccess({
        userId: authRequest.auth.uid,
        code: body.code,
        rateLimitKey: `${authRequest.auth.uid}:${request.ip ?? "unknown"}`
      });
      response.status(200).json(result);
    })
  );

  return router;
}
