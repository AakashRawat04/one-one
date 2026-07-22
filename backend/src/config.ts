import "dotenv/config";
import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().min(1).max(65535).default(8080),
  LOG_LEVEL: z.enum(["fatal", "error", "warn", "info", "debug", "trace", "silent"]).default("info"),
  LIVEKIT_URL: z.string().url().optional(),
  LIVEKIT_API_KEY: z.string().min(1).optional(),
  LIVEKIT_API_SECRET: z.string().min(1).optional(),
  FIREBASE_PROJECT_ID: z.string().min(1).optional(),
  FIREBASE_CLIENT_EMAIL: z.string().email().optional(),
  FIREBASE_PRIVATE_KEY: z.string().min(1).optional(),
  FIREBASE_DATABASE_URL: z.string().url().optional(),
  FIREBASE_STORAGE_BUCKET: z.string().min(1).optional(),
  PUBLIC_API_BASE_URL: z
    .string()
    .url()
    .default("https://one-one-xw00.onrender.com"),
  PUBLIC_INVITE_BASE_URL: z.string().url().optional(),
  ANDROID_APP_LINK_SHA256_CERT_FINGERPRINTS: z.string().optional(),
  NUDGE_RATE_LIMIT_WINDOW_SECONDS: z.coerce.number().int().min(10).max(3600).default(600),
  NUDGE_RATE_LIMIT_MAX_PER_GROUP: z.coerce.number().int().min(1).max(300).default(30),
  NUDGE_RECIPIENT_COOLDOWN_SECONDS: z.coerce.number().int().min(0).max(300).default(5),
  // Per-type cooldowns: how long a sender must wait before sending *another*
  // nudge of the same type (regardless of recipient). Independent from the
  // recipient-specific and group-wide limiters above so each nudge type can
  // be tuned without affecting the others.
  NUDGE_COOLDOWN_RING_SECONDS: z.coerce.number().int().min(0).max(600).default(20),
  NUDGE_COOLDOWN_VOICE_SECONDS: z.coerce.number().int().min(0).max(600).default(60),
  NUDGE_COOLDOWN_PUSH_SECONDS: z.coerce.number().int().min(0).max(600).default(10),
  // Anti-spam guard: caps the total number of nudges (any type) a single
  // sender can fire within a short rolling window, independent of the
  // longer-lived NUDGE_RATE_LIMIT_WINDOW_SECONDS burst guard above.
  NUDGE_SPAM_WINDOW_SECONDS: z.coerce.number().int().min(10).max(3600).default(300),
  NUDGE_SPAM_MAX_PER_WINDOW: z.coerce.number().int().min(1).max(300).default(10),
  SUBSCRIPTION_REDEEM_CODE_HASHES: z.string().optional(),
  CORS_ORIGINS: z.string().optional()
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error("Invalid environment configuration", parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const config = parsed.data;

export const liveKitConfigured = Boolean(
  config.LIVEKIT_URL && config.LIVEKIT_API_KEY && config.LIVEKIT_API_SECRET
);

export const firebaseServiceAccountConfigured = Boolean(
  config.FIREBASE_PROJECT_ID && config.FIREBASE_CLIENT_EMAIL && config.FIREBASE_PRIVATE_KEY
);
