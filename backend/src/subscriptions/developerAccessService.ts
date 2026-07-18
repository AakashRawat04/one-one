import { createHash, timingSafeEqual } from "node:crypto";
import { getAuth } from "firebase-admin/auth";
import { config } from "../config.js";
import { requireFirebaseAdminApp } from "../firebase/adminApp.js";
import { HttpError } from "../http/httpError.js";

const claimName = "oneOneDeveloper";
const attemptWindowMs = 15 * 60 * 1000;
const maxAttemptsPerWindow = 5;

type AttemptWindow = { count: number; resetAt: number };
const attempts = new Map<string, AttemptWindow>();

export function normalizeDeveloperRedeemCode(code: string) {
  return code.trim().toUpperCase();
}

export function hashDeveloperRedeemCode(code: string) {
  return createHash("sha256")
    .update(normalizeDeveloperRedeemCode(code), "utf8")
    .digest("hex");
}

function configuredHashes() {
  return (config.SUBSCRIPTION_REDEEM_CODE_HASHES ?? "")
    .split(",")
    .map((value) => value.trim().toLowerCase())
    .filter((value) => /^[a-f0-9]{64}$/.test(value));
}

export function isDeveloperRedeemCodeValid(code: string, hashes: string[]) {
  const candidate = Buffer.from(hashDeveloperRedeemCode(code), "hex");
  return hashes.some((hash) => {
    if (!/^[a-f0-9]{64}$/i.test(hash)) return false;
    const configuredHash = Buffer.from(hash, "hex");
    return (
      configuredHash.length === candidate.length &&
      timingSafeEqual(configuredHash, candidate)
    );
  });
}

function enforceRateLimit(key: string) {
  const now = Date.now();
  const current = attempts.get(key);
  if (!current || current.resetAt <= now) {
    attempts.set(key, { count: 1, resetAt: now + attemptWindowMs });
    return;
  }
  if (current.count >= maxAttemptsPerWindow) {
    throw new HttpError(429, "redeem_rate_limited", "Too many redemption attempts. Try again later.");
  }
  current.count += 1;
}

export async function redeemDeveloperAccess(input: {
  userId: string;
  code: string;
  rateLimitKey: string;
}) {
  enforceRateLimit(input.rateLimitKey);
  const hashes = configuredHashes();
  if (hashes.length === 0) {
    throw new HttpError(503, "developer_redeem_unavailable", "Developer redemption is not configured.");
  }

  const valid = isDeveloperRedeemCodeValid(input.code, hashes);
  if (!valid) {
    throw new HttpError(403, "invalid_redeem_code", "The redeem code is invalid.");
  }

  const auth = getAuth(requireFirebaseAdminApp());
  const user = await auth.getUser(input.userId);
  if (user.customClaims?.[claimName] !== true) {
    await auth.setCustomUserClaims(input.userId, {
      ...user.customClaims,
      [claimName]: true
    });
  }

  attempts.delete(input.rateLimitKey);
  return { redeemed: true } as const;
}
