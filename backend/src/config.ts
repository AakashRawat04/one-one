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
  NUDGE_RATE_LIMIT_WINDOW_SECONDS: z.coerce.number().int().min(10).max(3600).default(600),
  NUDGE_RATE_LIMIT_MAX_PER_GROUP: z.coerce.number().int().min(1).max(300).default(30),
  NUDGE_RECIPIENT_COOLDOWN_SECONDS: z.coerce.number().int().min(0).max(300).default(5),
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
