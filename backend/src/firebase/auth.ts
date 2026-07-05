import type { NextFunction, Request, Response } from "express";
import type { DecodedIdToken } from "firebase-admin/auth";
import { getAuth } from "firebase-admin/auth";
import { HttpError } from "../http/httpError.js";
import { requireFirebaseAdminApp } from "./adminApp.js";

export type AuthenticatedRequest = Request & {
  auth: DecodedIdToken;
};

function parseBearerToken(headerValue: string | undefined) {
  if (!headerValue) return null;

  const [scheme, token] = headerValue.split(" ");
  if (scheme?.toLowerCase() !== "bearer" || !token) {
    return null;
  }

  return token;
}

export async function verifyFirebaseIdToken(idToken: string) {
  const app = requireFirebaseAdminApp();
  return getAuth(app).verifyIdToken(idToken);
}

export async function requireFirebaseAuth(request: Request, _response: Response, next: NextFunction) {
  try {
    const idToken = parseBearerToken(request.header("authorization"));

    if (!idToken) {
      throw new HttpError(401, "missing_auth_token", "Authorization Bearer token is required.");
    }

    (request as AuthenticatedRequest).auth = await verifyFirebaseIdToken(idToken);
    next();
  } catch (error) {
    next(error);
  }
}
