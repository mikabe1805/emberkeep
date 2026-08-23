import {createHash} from "node:crypto";
import {FieldValue} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

export const ROOM_CODE = /^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$/;
export const ownerKeyForUid = (uid: string): string => createHash("sha256").update(uid, "utf8").digest("hex");
const MAX_NAME_CODE_POINTS = 32;
const NAME_COOLDOWN_MS = 60_000;
const DAILY_NAME_LIMIT = 10;
const REPORT_COOLDOWN_MS = 60_000;
const DAILY_REPORT_LIMIT = 10;
const REPORT_CATEGORIES = new Set(["inappropriate_name", "impersonation", "other"]);
const COARSE_DENYLIST = new Set([
  "fuck", "shit", "bitch", "cunt", "nigger", "faggot", "chink", "kike",
]);

type CallableRequest = {data: unknown; auth?: {uid: string} | null};
type Snapshot = {exists: boolean; data(): Record<string, unknown> | undefined};
type DocRef = {get(): Promise<Snapshot>; set(data: Record<string, unknown>, options?: {merge?: boolean}): Promise<void>};
export type DiscoveryStore = {
  collection(path: string): {doc(id: string): DocRef};
  runTransaction<T>(fn: (transaction: DiscoveryTransaction) => Promise<T>): Promise<T>;
};
export type DiscoveryTransaction = {
  get(ref: DocRef): Promise<Snapshot>;
  set(ref: DocRef, data: Record<string, unknown>, options?: {merge?: boolean}): void;
};
export type DiscoveryDependencies = {store: DiscoveryStore; now?: () => Date};
export type PublicNameDependencies = DiscoveryDependencies & {
  publicNamesEnabled?: () => boolean;
};

const invalid = (message: string): never => {
  throw new HttpsError("invalid-argument", message);
};

const record = (value: unknown): Record<string, unknown> => {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return invalid("The request payload must be an object.");
  return value as Record<string, unknown>;
};

const authUid = (request: CallableRequest): string => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Authentication is required.");
  return request.auth.uid;
};

const ownerKey = (uid: string): string => ownerKeyForUid(uid);

const code = (value: unknown): string => {
  if (typeof value !== "string" || !ROOM_CODE.test(value)) return invalid("code must be a valid six-character room code.");
  return value;
};

const containsControlCharacter = (value: string): boolean => [...value].some((character) => {
  const point = character.codePointAt(0) ?? 0;
  return point <= 0x1f || (point >= 0x7f && point <= 0x9f) || point === 0x2028 || point === 0x2029;
});

const normalizeName = (value: unknown): string => {
  if (value === undefined || value === null) return "";
  if (typeof value !== "string") return invalid("publicName must be a string when provided.");
  if (containsControlCharacter(value)) return invalid("publicName contains unsupported control characters.");
  const normalized = value.normalize("NFKC").replace(/\s+/gu, " ").trim();
  if ([...normalized].length > MAX_NAME_CODE_POINTS) return invalid("publicName must be at most 32 characters.");
  if (containsControlCharacter(normalized)) return invalid("publicName contains unsupported control characters.");
  if (!normalized) return "";
  if (!/[\p{L}\p{M}\p{N}]/u.test(normalized)) return invalid("publicName must contain a human-readable name.");
  if (/https?:\/\//iu.test(normalized) || /\b(?:www\.|[\w.-]+\.(?:com|net|org|io|me|ly))\b/iu.test(normalized)) return invalid("publicName cannot contain a URL.");
  if (/@|\b(?:discord|telegram|whatsapp|snapchat|instagram|twitter|tiktok)\b/iu.test(normalized)) return invalid("publicName cannot contain a contact handle.");
  if (!/^[\p{L}\p{M}\p{N} .'’‘‐‑–—-]+$/u.test(normalized)) return invalid("publicName contains unsupported characters.");
  const words = normalized.toLocaleLowerCase().split(/[ .'’‘‐‑–—-]+/u).filter(Boolean);
  if (words.some((word) => COARSE_DENYLIST.has(word))) return invalid("publicName is not allowed.");
  return normalized;
};

const readMillis = (value: unknown): number | undefined => {
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "object" && value !== null && "toMillis" in value && typeof value.toMillis === "function") return value.toMillis();
  return undefined;
};

export const setDiscoveryPublicNameHandler = async (
  request: CallableRequest,
  dependencies: PublicNameDependencies,
): Promise<{publicName: string}> => {
  if (!(dependencies.publicNamesEnabled?.() ?? false)) {
    throw new HttpsError(
      "failed-precondition",
      "Public discovery names are not enabled.",
    );
  }
  const uid = authUid(request);
  const body = record(request.data);
  if (Object.keys(body).some((key) => key !== "code" && key !== "publicName")) return invalid("The request contains an unsupported field.");
  const roomCode = code(body.code);
  const publicName = normalizeName(body.publicName);
  const now = (dependencies.now ?? (() => new Date()))();
  const roomRef = dependencies.store.collection("rooms").doc(roomCode);
  const directoryRef = dependencies.store.collection("discoverableSpaces").doc(roomCode);
  const limitRef = dependencies.store.collection("discoveryNameChanges").doc(uid);
  await dependencies.store.runTransaction(async (transaction) => {
    const [room, directory, ban, limit] = await Promise.all([
      transaction.get(roomRef), transaction.get(directoryRef),
      transaction.get(dependencies.store.collection("discoveryBans").doc(ownerKey(uid))),
      transaction.get(limitRef),
    ]);
    if (!room.exists || room.data()?.uid !== uid) throw new HttpsError("permission-denied", "You do not own this room.");
    if (!directory.exists) throw new HttpsError("failed-precondition", "This room is not discoverable.");
    if (directory.data()?.ownerKey !== ownerKey(uid)) throw new HttpsError("failed-precondition", "This room's discovery record is stale.");
    if (ban.exists) throw new HttpsError("permission-denied", "This room is not eligible for public names.");
    const prior = limit.data();
    const last = readMillis(prior?.lastChangedAt);
    const day = now.toISOString().slice(0, 10);
    const count = prior?.dayBucket === day && typeof prior.dayCount === "number" ? prior.dayCount : 0;
    if (last !== undefined && now.getTime() - last < NAME_COOLDOWN_MS) throw new HttpsError("resource-exhausted", "Please wait before changing your public name again.");
    if (count >= DAILY_NAME_LIMIT) throw new HttpsError("resource-exhausted", "The daily public-name change limit has been reached.");
    // Keep the field present even for anonymous rooms: directory reads and
    // client refreshes share one strict v3 schema.
    transaction.set(directoryRef, {publicName}, {merge: true});
    transaction.set(limitRef, {dayBucket: day, dayCount: count + 1, lastChangedAt: now}, {merge: true});
  });
  return {publicName};
};

export const reportDiscoverableSpaceHandler = async (
  request: CallableRequest,
  dependencies: DiscoveryDependencies,
): Promise<{reported: true}> => {
  const uid = authUid(request);
  const body = record(request.data);
  if (Object.keys(body).some((key) => key !== "code" && key !== "category")) return invalid("The request contains an unsupported field.");
  const roomCode = code(body.code);
  if (typeof body.category !== "string" || !REPORT_CATEGORIES.has(body.category)) return invalid("category is invalid.");
  const now = (dependencies.now ?? (() => new Date()))();
  const roomRef = dependencies.store.collection("rooms").doc(roomCode);
  const directoryRef = dependencies.store.collection("discoverableSpaces").doc(roomCode);
  const reportRef = dependencies.store.collection(`discoveryReports/${roomCode}/reporters`).doc(uid);
  const limitRef = dependencies.store.collection("discoveryReportLimits").doc(uid);
  await dependencies.store.runTransaction(async (transaction) => {
    const [room, directory, existing, limit] = await Promise.all([
      transaction.get(roomRef),
      transaction.get(directoryRef),
      transaction.get(reportRef),
      transaction.get(limitRef),
    ]);
    if (!room.exists || !directory.exists) throw new HttpsError("not-found", "This room is not discoverable.");
    const roomOwnerUid = room.data()?.uid;
    if (typeof roomOwnerUid !== "string") throw new HttpsError("not-found", "This room is not discoverable.");
    const roomOwnerKey = ownerKey(roomOwnerUid);
    if (directory.data()?.ownerKey !== roomOwnerKey) throw new HttpsError("failed-precondition", "This room's discovery record is stale.");
    if (roomOwnerUid === uid) throw new HttpsError("failed-precondition", "You cannot report your own room.");
    if (existing.exists) throw new HttpsError("already-exists", "You have already reported this room.");
    const prior = limit.data();
    const last = readMillis(prior?.lastReportedAt);
    const day = now.toISOString().slice(0, 10);
    const count = prior?.dayBucket === day && typeof prior.dayCount === "number" ? prior.dayCount : 0;
    if (last !== undefined && now.getTime() - last < REPORT_COOLDOWN_MS) {
      throw new HttpsError("resource-exhausted", "Please wait before submitting another report.");
    }
    if (count >= DAILY_REPORT_LIMIT) {
      throw new HttpsError("resource-exhausted", "The daily report limit has been reached.");
    }
    const publicName = directory.data()?.publicName;
    transaction.set(reportRef, {
      category: body.category,
      publicName: typeof publicName === "string" ? publicName : null,
      ownerKey: roomOwnerKey,
      ownerUid: roomOwnerUid,
      state: "pending",
      updatedAt: FieldValue.serverTimestamp(),
      ...(existing.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      clientReportedAt: now,
    }, {merge: true});
    transaction.set(limitRef, {
      dayBucket: day,
      dayCount: count + 1,
      lastReportedAt: now,
    }, {merge: true});
  });
  return {reported: true};
};
