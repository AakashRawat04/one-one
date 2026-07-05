import type { MulticastMessage } from "firebase-admin/messaging";
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
