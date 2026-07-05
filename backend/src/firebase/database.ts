import { getDatabase } from "firebase-admin/database";
import { requireFirebaseAdminApp } from "./adminApp.js";

export function getRealtimeDatabase() {
  return getDatabase(requireFirebaseAdminApp());
}
