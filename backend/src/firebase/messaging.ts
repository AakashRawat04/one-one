import type { Message, MulticastMessage } from "firebase-admin/messaging";
import { getMessaging } from "firebase-admin/messaging";
import { requireFirebaseAdminApp } from "./adminApp.js";

export type PushPayload = {
  tokens: string[];
  title: string;
  body: string;
  data?: Record<string, string>;
};

export async function sendPushToTokens(payload: PushPayload) {
  if (payload.tokens.length === 0) {
    return {
      successCount: 0,
      failureCount: 0,
      responses: []
    };
  }

  const message: MulticastMessage = {
    tokens: payload.tokens,
    notification: {
      title: payload.title,
      body: payload.body
    },
    data: payload.data,
    android: {
      priority: "high",
      notification: {
        channelId: "walkie_alerts"
      }
    }
  };

  return getMessaging(requireFirebaseAdminApp()).sendEachForMulticast(message);
}

export type AndroidDataPush = {
  token: string;
  data: Record<string, string>;
};

export async function sendAndroidDataPushes(pushes: AndroidDataPush[], ttlMs: number) {
  if (pushes.length === 0) {
    return {
      successCount: 0,
      failureCount: 0,
      responses: []
    };
  }

  const messages: Message[] = pushes.map((push) => ({
    token: push.token,
    data: push.data,
    android: {
      priority: "high",
      ttl: ttlMs
    }
  }));

  return getMessaging(requireFirebaseAdminApp()).sendEach(messages);
}
