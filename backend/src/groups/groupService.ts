import { randomBytes, createHash } from "node:crypto";
import { getRealtimeDatabase } from "../firebase/database.js";
import { HttpError } from "../http/httpError.js";

const maxMembers = 4;
const defaultMaxTalkMs = 60_000;

export type CreateGroupInput = {
  ownerUserId: string;
  name: string;
};

export type CreateInviteInput = {
  groupId: string;
  userId: string;
  maxUses: number;
  expiresInHours: number;
};

export type JoinInviteInput = {
  userId: string;
  inviteCode: string;
};

export async function createGroup(input: CreateGroupInput) {
  const db = getRealtimeDatabase();
  await requireActiveUser(input.ownerUserId);

  const groupRef = db.ref("groups").push();
  const groupId = groupRef.key;

  if (!groupId) {
    throw new HttpError(500, "group_id_failed", "Failed to allocate group id.");
  }

  const now = nowSeconds();
  const livekitRoomName = `group_${groupId}`;

  await db.ref().update({
    [`groups/${groupId}`]: {
      name: input.name,
      ownerUserId: input.ownerUserId,
      livekitRoomName,
      singleSpeaker: true,
      maxTalkMs: defaultMaxTalkMs,
      maxMembers,
      createdAt: now,
      archivedAt: null,
      groupState: "active"
    },
    [`groupMembers/${groupId}/${input.ownerUserId}`]: {
      role: "owner",
      memberState: "active",
      mutedBySelf: false,
      joinedAt: now,
      leftAt: null
    },
    [`livekitRooms/${groupId}`]: {
      groupId,
      roomName: livekitRoomName,
      serverUrlKey: "default",
      roomStrategy: "one_room_per_group",
      createdAt: now,
      roomState: "active"
    },
    [`memberAvailability/${groupId}/${input.ownerUserId}`]: defaultAvailability(now)
  });

  return {
    groupId,
    livekitRoomName
  };
}

export async function createInvite(input: CreateInviteInput) {
  const db = getRealtimeDatabase();
  await requireActiveUser(input.userId);
  await requireActiveGroupMember(input.groupId, input.userId);
  const group = await requireActiveGroup(input.groupId);

  const inviteRef = db.ref("groupInvites").push();
  const inviteId = inviteRef.key;

  if (!inviteId) {
    throw new HttpError(500, "invite_id_failed", "Failed to allocate invite id.");
  }

  const now = nowSeconds();
  const inviteCode = generateInviteCode();
  const expiresAt = now + input.expiresInHours * 60 * 60;

  await inviteRef.set({
    inviteId,
    groupId: input.groupId,
    inviteCodeHash: hashInviteCode(inviteCode),
    createdByUserId: input.userId,
    maxUses: Math.min(input.maxUses, Math.max(group.maxMembers - 1, 1)),
    usedCount: 0,
    expiresAt,
    revokedAt: null,
    createdAt: now
  });

  return {
    inviteId,
    groupId: input.groupId,
    inviteCode,
    expiresAt
  };
}

export async function joinInvite(input: JoinInviteInput) {
  const db = getRealtimeDatabase();
  await requireActiveUser(input.userId);

  const invite = await findActiveInvite(input.inviteCode);
  const group = await requireActiveGroup(invite.groupId);
  const existingMember = await db
    .ref(`groupMembers/${invite.groupId}/${input.userId}`)
    .get();

  if (
    existingMember.exists() &&
    (existingMember.child("memberState").val() ?? "active") === "active"
  ) {
    return {
      groupId: invite.groupId,
      alreadyMember: true
    };
  }

  const now = nowSeconds();
  const memberRef = db.ref(`groupMembers/${invite.groupId}`);
  const membership = await memberRef.transaction((current) => {
    const members = isRecord(current) ? current : {};
    const activeCount = Object.values(members).filter((member) => {
      return isRecord(member) && member.memberState === "active";
    }).length;

    if (activeCount >= group.maxMembers) {
      return;
    }

    return {
      ...members,
      [input.userId]: {
        role: "member",
        memberState: "active",
        mutedBySelf: false,
        joinedAt: now,
        leftAt: null
      }
    };
  });

  if (!membership.committed) {
    throw new HttpError(409, "group_full", "Group already has the maximum number of members.");
  }

  const inviteUpdate = await db.ref(`groupInvites/${invite.inviteId}`).transaction((current) => {
    if (!isRecord(current)) {
      return;
    }

    const usedCount = readNumber(current.usedCount, 0);
    const maxUsesValue = readNumber(current.maxUses, invite.maxUses);
    const expiresAt = readNumber(current.expiresAt, 0);
    const revokedAt = current.revokedAt;

    if (revokedAt != null || expiresAt <= now || usedCount >= maxUsesValue) {
      return;
    }

    return {
      ...current,
      usedCount: usedCount + 1
    };
  });

  if (!inviteUpdate.committed) {
    await db.ref(`groupMembers/${invite.groupId}/${input.userId}`).remove();
    throw new HttpError(409, "invite_unavailable", "Invite is expired or fully used.");
  }

  await db.ref(`memberAvailability/${invite.groupId}/${input.userId}`).set(defaultAvailability(now));

  return {
    groupId: invite.groupId,
    alreadyMember: false
  };
}

export async function requireActiveUser(userId: string) {
  const snapshot = await getRealtimeDatabase().ref(`users/${userId}`).get();
  if (!snapshot.exists()) {
    throw new HttpError(403, "user_not_found", "User profile does not exist.");
  }

  if ((snapshot.child("accountState").val() ?? "active") !== "active") {
    throw new HttpError(403, "user_not_active", "User is not active.");
  }
}

export async function requireActiveGroup(groupId: string) {
  const snapshot = await getRealtimeDatabase().ref(`groups/${groupId}`).get();
  if (!snapshot.exists()) {
    throw new HttpError(404, "group_not_found", "Group does not exist.");
  }

  if ((snapshot.child("groupState").val() ?? "active") !== "active") {
    throw new HttpError(409, "group_not_active", "Group is not active.");
  }

  return {
    groupId,
    maxMembers: readNumber(snapshot.child("maxMembers").val(), maxMembers),
    livekitRoomName: snapshot.child("livekitRoomName").val()?.toString() ?? `group_${groupId}`
  };
}

export async function requireActiveGroupMember(groupId: string, userId: string) {
  const snapshot = await getRealtimeDatabase().ref(`groupMembers/${groupId}/${userId}`).get();

  if (!snapshot.exists() || (snapshot.child("memberState").val() ?? "active") !== "active") {
    throw new HttpError(403, "not_group_member", "User is not an active group member.");
  }

  return {
    role: snapshot.child("role").val()?.toString() ?? "member"
  };
}

export async function requireActiveUserDevice(userId: string, deviceId: string) {
  const snapshot = await getRealtimeDatabase().ref(`userDevices/${userId}/${deviceId}`).get();

  if (!snapshot.exists() || (snapshot.child("deviceState").val() ?? "active") !== "active") {
    throw new HttpError(403, "device_not_active", "Device is not active for this user.");
  }
}

async function findActiveInvite(inviteCode: string) {
  const now = nowSeconds();
  const hash = hashInviteCode(inviteCode);
  const snapshot = await getRealtimeDatabase()
    .ref("groupInvites")
    .orderByChild("inviteCodeHash")
    .equalTo(hash)
    .get();

  if (!snapshot.exists() || !isRecord(snapshot.val())) {
    throw new HttpError(404, "invite_not_found", "Invite code is invalid.");
  }

  for (const [inviteId, value] of Object.entries(snapshot.val() as Record<string, unknown>)) {
    if (!isRecord(value)) continue;

    const expiresAt = readNumber(value.expiresAt, 0);
    const maxUsesValue = readNumber(value.maxUses, 0);
    const usedCount = readNumber(value.usedCount, 0);

    if (value.revokedAt != null || expiresAt <= now || usedCount >= maxUsesValue) {
      continue;
    }

    return {
      inviteId,
      groupId: value.groupId?.toString() ?? "",
      maxUses: maxUsesValue
    };
  }

  throw new HttpError(409, "invite_unavailable", "Invite is expired or fully used.");
}

function defaultAvailability(now: number) {
  return {
    activeDeviceId: null,
    activeServiceSessionId: null,
    activeLivekitSessionId: null,
    desiredState: "away",
    effectiveState: "away",
    serviceState: "stopped",
    livekitConnectionState: "disconnected",
    canReceiveLiveAudio: false,
    lastHeartbeatAt: now,
    staleAfterAt: now,
    updatedAt: now
  };
}

function generateInviteCode() {
  return randomBytes(5).toString("base64url").toUpperCase();
}

function hashInviteCode(inviteCode: string) {
  return createHash("sha256").update(inviteCode.trim().toUpperCase()).digest("hex");
}

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readNumber(value: unknown, fallback: number) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}
