import {createHash} from "node:crypto";
import {FieldValue} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

export const SPACE_CODE = /^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$/;
const OWNER_KEY = /^[a-f0-9]{64}$/;
const CARD_KINDS = new Set(["about", "rightNow", "pinnedMoments", "thisSeason"]);
const COARSE_DENYLIST = new Set([
  "fuck", "shit", "bitch", "cunt", "nigger", "faggot", "chink", "kike",
]);

type CallableRequest = {data: unknown; auth?: {uid: string} | null};
type Data = Record<string, unknown>;
type Snapshot = {exists: boolean; data(): Data | undefined};
type DocRef = {get(): Promise<Snapshot>};
type WriteTransaction = {
  get(ref: DocRef): Promise<Snapshot>;
  set(ref: DocRef, data: Data): void;
  delete(ref: DocRef): void;
};
export type SpaceProfileStore = {
  collection(path: string): {doc(id: string): DocRef};
  runTransaction<T>(fn: (transaction: WriteTransaction) => Promise<T>): Promise<T>;
};
export type SpaceProfileDependencies = {store: SpaceProfileStore};

type Profile = {
  displayName: string;
  cardOrder: string[];
  about: string;
  featuredGoals: string[];
  pinnedMoments: {text: string; at: number}[];
  season: string;
};

const invalid = (message: string): never => {
  throw new HttpsError("invalid-argument", message);
};

const record = (value: unknown, label = "request payload"): Data => {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return invalid(`The ${label} must be an object.`);
  }
  return value as Data;
};

const authUid = (request: CallableRequest): string => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Authentication is required.");
  return request.auth.uid;
};

export const ownerKeyForSpaceUid = (uid: string): string =>
  createHash("sha256").update(uid, "utf8").digest("hex");

const code = (value: unknown): string => {
  if (typeof value !== "string" || !SPACE_CODE.test(value)) {
    return invalid("code must be a valid six-character room code.");
  }
  return value;
};

const optionalOwnerKey = (value: unknown): string | undefined => {
  if (value === undefined || value === null || value === "") return undefined;
  if (typeof value !== "string" || !OWNER_KEY.test(value)) {
    return invalid("ownerKey must be a stable owner key when provided.");
  }
  return value;
};

const hasUnsafeText = (value: string): boolean =>
  /https?:\/\//iu.test(value) ||
  /\b(?:www\.|[\w.-]+\.(?:com|net|org|io|me|ly))\b/iu.test(value) ||
  /@|\b(?:discord|telegram|whatsapp|snapchat|instagram|twitter|tiktok)\b/iu.test(value) ||
  value.toLocaleLowerCase().split(/[^\p{L}\p{N}]+/u).some((word) => COARSE_DENYLIST.has(word));

const text = (value: unknown, field: string, maximum: number, {required = false}: {required?: boolean} = {}): string => {
  if (typeof value !== "string") return required ? invalid(`${field} must be a string.`) : "";
  const clean = value.normalize("NFKC").replace(/\r\n?/gu, "\n").trim();
  if ([...clean].length > maximum) return invalid(`${field} is too long.`);
  if (hasUnsafeText(clean)) return invalid(`${field} cannot include contact details, URLs, or disallowed language.`);
  return clean;
};

const exactKeys = (value: Data, keys: string[], label: string): void => {
  const actual = Object.keys(value).sort();
  const expected = [...keys].sort();
  if (actual.length !== expected.length || actual.some((key, index) => key !== expected[index])) {
    invalid(`${label} has unsupported or missing fields.`);
  }
};

const profile = (value: unknown, label: string): Profile | null => {
  if (value === null || value === undefined) return null;
  const raw = record(value, label);
  exactKeys(raw, ["displayName", "cardOrder", "about", "featuredGoals", "pinnedMoments", "season"], label);
  if (!Array.isArray(raw.cardOrder) || raw.cardOrder.length > 4 || raw.cardOrder.some((kind) => typeof kind !== "string" || !CARD_KINDS.has(kind))) {
    invalid(`${label}.cardOrder is invalid.`);
  }
  const cardOrder = raw.cardOrder as string[];
  if (new Set(cardOrder).size !== cardOrder.length) invalid(`${label}.cardOrder cannot repeat a card.`);
  if (!Array.isArray(raw.featuredGoals) || raw.featuredGoals.length > 3) invalid(`${label}.featuredGoals is invalid.`);
  if (!Array.isArray(raw.pinnedMoments) || raw.pinnedMoments.length > 4) invalid(`${label}.pinnedMoments is invalid.`);
  const featuredGoals = raw.featuredGoals as unknown[];
  const pinnedMoments = raw.pinnedMoments as unknown[];
  const result: Profile = {
    displayName: text(raw.displayName, `${label}.displayName`, 40, {required: true}),
    cardOrder,
    about: text(raw.about, `${label}.about`, 180, {required: true}),
    featuredGoals: featuredGoals.map((goal, index) => text(goal, `${label}.featuredGoals[${index}]`, 100, {required: true})),
    pinnedMoments: pinnedMoments.map((moment, index) => {
      const item = record(moment, `${label}.pinnedMoments[${index}]`);
      exactKeys(item, ["text", "at"], `${label}.pinnedMoments[${index}]`);
      if (typeof item.at !== "number" || !Number.isInteger(item.at) || item.at < 0 || item.at > 9999999999999) {
        invalid(`${label}.pinnedMoments[${index}].at is invalid.`);
      }
      return {text: text(item.text, `${label}.pinnedMoments[${index}].text`, 240, {required: true}), at: item.at as number};
    }),
    season: text(raw.season, `${label}.season`, 180, {required: true}),
  };
  if (!cardOrder.includes("about") && result.about) invalid(`${label}.about requires the About card.`);
  if (!cardOrder.includes("rightNow") && result.featuredGoals.length) invalid(`${label}.featuredGoals requires the Right now card.`);
  if (!cardOrder.includes("pinnedMoments") && result.pinnedMoments.length) invalid(`${label}.pinnedMoments requires its card.`);
  if (!cardOrder.includes("thisSeason") && result.season) invalid(`${label}.season requires the This season card.`);
  // A zero-card audience may retain an intentionally blank projection, but it
  // cannot become an identity directory through the name alone.
  if (cardOrder.length === 0 && result.displayName) {
    invalid(`${label}.displayName requires at least one visible card.`);
  }
  return result;
};

const same = (left: unknown, right: unknown): boolean => JSON.stringify(left) === JSON.stringify(right);

const publicIsContainedInMutual = (publicProfile: Profile | null, mutualProfile: Profile | null): void => {
  if (publicProfile === null) return;
  const mutual: Profile = mutualProfile ?? invalid("mutualProfile must include the public profile identity.");
  // An empty Anyone projection deliberately withholds the keeper's name while
  // still permitting Mutuals to recognize one another. Once a public name is
  // supplied, the two projections must remain the same identity.
  if (publicProfile.displayName && publicProfile.displayName !== mutual.displayName) {
    invalid("mutualProfile must include the public profile identity.");
  }
  for (const card of publicProfile.cardOrder) {
    if (!mutual.cardOrder.includes(card)) invalid("mutualProfile must include every public card.");
    if (card === "about" && publicProfile.about !== mutual.about) invalid("mutualProfile must preserve the public About card.");
    if (card === "rightNow" && !same(publicProfile.featuredGoals, mutual.featuredGoals)) invalid("mutualProfile must preserve public goals.");
    if (card === "pinnedMoments" && !same(publicProfile.pinnedMoments, mutual.pinnedMoments)) invalid("mutualProfile must preserve public pinned moments.");
    if (card === "thisSeason" && publicProfile.season !== mutual.season) invalid("mutualProfile must preserve the public season.");
  }
};

const liveOwnedRoom = async (transaction: WriteTransaction, store: SpaceProfileStore, roomCode: string, uid: string): Promise<unknown> => {
  const room = await transaction.get(store.collection("rooms").doc(roomCode));
  const roomData = room.data();
  if (!room.exists || roomData?.ownerKey !== ownerKeyForSpaceUid(uid) || roomData?.v !== 6 ||
      roomData?.profileVisible !== false || roomData?.updatedAt === undefined) {
    throw new HttpsError("permission-denied", "You do not own a live generated-only room at this code.");
  }
  return roomData.updatedAt;
};

export const publishSpaceProfileHandler = async (
  request: CallableRequest,
  dependencies: SpaceProfileDependencies,
): Promise<{published: true; publicProfile: boolean; mutualProfile: boolean}> => {
  const uid = authUid(request);
  const body = record(request.data);
  exactKeys(body, ["code", "publicProfile", "mutualProfile"], "request payload");
  const roomCode = code(body.code);
  const publicProfile = profile(body.publicProfile, "publicProfile");
  const mutualProfile = profile(body.mutualProfile, "mutualProfile");
  publicIsContainedInMutual(publicProfile, mutualProfile);
  const ownerKey = ownerKeyForSpaceUid(uid);
  await dependencies.store.runTransaction(async (transaction) => {
    const roomUpdatedAt = await liveOwnedRoom(transaction, dependencies.store, roomCode, uid);
    const write = (path: string, value: Profile | null): void => {
      const ref = dependencies.store.collection(path).doc(roomCode);
      if (value === null) transaction.delete(ref);
      else transaction.set(ref, {
        v: 2,
        ownerKey,
        roomUpdatedAt,
        ...value,
        updatedAt: FieldValue.serverTimestamp(),
      });
    };
    write("publicSpaceProfiles", publicProfile);
    write("mutualSpaceProfiles", mutualProfile);
  });
  return {published: true, publicProfile: publicProfile !== null, mutualProfile: mutualProfile !== null};
};

const targetRoom = async (transaction: WriteTransaction, store: SpaceProfileStore, roomCode: string, uid: string, requestedOwnerKey: string | undefined): Promise<{ownerKey: string}> => {
  const room = await transaction.get(store.collection("rooms").doc(roomCode));
  const ownerKey = room.data()?.ownerKey;
  if (!room.exists || typeof ownerKey !== "string" || !OWNER_KEY.test(ownerKey) || room.data()?.v !== 6 || room.data()?.profileVisible !== false) {
    throw new HttpsError("not-found", "That shared space is unavailable.");
  }
  if (ownerKey === ownerKeyForSpaceUid(uid)) throw new HttpsError("failed-precondition", "You cannot create a relationship with your own space.");
  if (requestedOwnerKey !== undefined && requestedOwnerKey !== ownerKey) {
    throw new HttpsError("failed-precondition", "That space changed before the relationship could be updated.");
  }
  return {ownerKey};
};

export const setCircleRelationshipHandler = async (
  request: CallableRequest,
  dependencies: SpaceProfileDependencies,
): Promise<{active: boolean; ownerKey: string}> => {
  const uid = authUid(request);
  const body = record(request.data);
  if (Object.keys(body).some((key) => !["code", "ownerKey", "active"].includes(key))) invalid("The request contains an unsupported field.");
  const roomCode = code(body.code);
  if (typeof body.active !== "boolean") invalid("active must be a boolean.");
  const active = body.active as boolean;
  const requestedOwnerKey = optionalOwnerKey(body.ownerKey);
  return dependencies.store.runTransaction(async (transaction) => {
    // Removal is intentionally keyed by the stable owner key supplied by the
    // caller. A room code can disappear or be reissued between a visitor
    // adding someone and later revoking that choice; resolving that stale code
    // would otherwise strand the private relationship document forever.
    if (!active && requestedOwnerKey !== undefined) {
      transaction.delete(
        dependencies.store.collection(`circleRelationships/${ownerKeyForSpaceUid(uid)}/outgoing`).doc(requestedOwnerKey),
      );
      return {active, ownerKey: requestedOwnerKey};
    }
    const target = await targetRoom(transaction, dependencies.store, roomCode, uid, requestedOwnerKey);
    const edge = dependencies.store.collection(`circleRelationships/${ownerKeyForSpaceUid(uid)}/outgoing`).doc(target.ownerKey);
    if (active) transaction.set(edge, {ownerKey: target.ownerKey, updatedAt: FieldValue.serverTimestamp()});
    else transaction.delete(edge);
    return {active, ownerKey: target.ownerKey};
  });
};

export const setSpaceBlockHandler = async (
  request: CallableRequest,
  dependencies: SpaceProfileDependencies,
): Promise<{blocked: boolean; ownerKey: string}> => {
  const uid = authUid(request);
  const body = record(request.data);
  if (Object.keys(body).some((key) => !["code", "ownerKey", "blocked"].includes(key))) invalid("The request contains an unsupported field.");
  const roomCode = code(body.code);
  if (typeof body.blocked !== "boolean") invalid("blocked must be a boolean.");
  const blocked = body.blocked as boolean;
  const requestedOwnerKey = optionalOwnerKey(body.ownerKey);
  return dependencies.store.runTransaction(async (transaction) => {
    // See the equivalent Circle removal above. Unblocking is a revocation of
    // the caller's own opaque block document, never a permission grant.
    if (!blocked && requestedOwnerKey !== undefined) {
      transaction.delete(
        dependencies.store.collection(`spaceBlocks/${ownerKeyForSpaceUid(uid)}/blocked`).doc(requestedOwnerKey),
      );
      return {blocked, ownerKey: requestedOwnerKey};
    }
    const target = await targetRoom(transaction, dependencies.store, roomCode, uid, requestedOwnerKey);
    const selfKey = ownerKeyForSpaceUid(uid);
    const block = dependencies.store.collection(`spaceBlocks/${selfKey}/blocked`).doc(target.ownerKey);
    const edge = dependencies.store.collection(`circleRelationships/${selfKey}/outgoing`).doc(target.ownerKey);
    if (blocked) transaction.set(block, {ownerKey: target.ownerKey, updatedAt: FieldValue.serverTimestamp()});
    else transaction.delete(block);
    // Blocking must immediately collapse a relationship; unblocking never
    // restores it, so renewed access always requires a fresh Circle choice.
    if (blocked) transaction.delete(edge);
    return {blocked, ownerKey: target.ownerKey};
  });
};
