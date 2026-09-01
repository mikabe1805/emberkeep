export type SpaceCleanupStore = {
  collection(path: string): {doc(id: string): unknown};
  runTransaction<T>(fn: (transaction: SpaceCleanupTransaction) => Promise<T>): Promise<T>;
};

export type SpaceCleanupSnapshot = {
  exists: boolean;
  data(): Record<string, unknown> | undefined;
};

export type SpaceCleanupTransaction = {
  get(reference: unknown): Promise<SpaceCleanupSnapshot>;
  delete(reference: unknown): void;
};

export type DeletedRoomAnchor = {
  v?: unknown;
  ownerKey?: unknown;
  updatedAt?: unknown;
  profilePhotoPath?: unknown;
  seasonPhotoPath?: unknown;
  roomPhotoPath?: unknown;
};

export type PublicRoomPhotoStorage = {
  deleteObject(path: string): Promise<void>;
};

const ROOM_CODE = /^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$/;
const OWNER_KEY = /^[a-f0-9]{64}$/;
const GENERATION = /^[A-Za-z0-9_-]{22}$/;

/// Returns only the deleted v8 room's own opaque Storage path. A malformed
/// snapshot must never turn a deletion trigger into authority over an
/// arbitrary Storage object.
export const deletedPublicRoomPhotoPath = (
  code: string,
  deletedRoom: DeletedRoomAnchor,
): string | null => {
  const ownerKey = deletedRoom.ownerKey;
  const path = deletedRoom.roomPhotoPath;
  if (!ROOM_CODE.test(code) || typeof ownerKey !== "string" || !OWNER_KEY.test(ownerKey)) {
    return null;
  }
  if (path === "") return null;
  if (typeof path !== "string") return null;
  const parts = path.split("/");
  if (parts.length !== 5 || parts[0] !== "shared_rooms" ||
      parts[1] !== ownerKey || parts[2] !== code || parts[3] !== "room" ||
      !GENERATION.test(parts[4] ?? "")) {
    return null;
  }
  return path;
};

/// Legacy generated rooms could expose selected profile/season media through
/// their bearer room document. Their paths use the same opaque owner key that
/// the room snapshot carries, so the deletion trigger can validate exact
/// snapshot-owned objects after the parent has been removed. Never derive a
/// delete from a v8 document: those fields are required to be empty.
export const deletedLegacyRoomMediaPaths = (
  code: string,
  deletedRoom: DeletedRoomAnchor,
): string[] => {
  if ((deletedRoom.v !== 6 && deletedRoom.v !== 7) ||
      !ROOM_CODE.test(code) ||
      typeof deletedRoom.ownerKey !== "string" ||
      !OWNER_KEY.test(deletedRoom.ownerKey)) {
    return [];
  }
  const paths: string[] = [];
  for (const [key, slot] of [
    ["profilePhotoPath", "profile"],
    ["seasonPhotoPath", "season"],
  ] as const) {
    const path = deletedRoom[key];
    if (typeof path !== "string" || path === "") continue;
    const parts = path.split("/");
    const deterministic = parts.length === 4;
    const revisioned = parts.length === 5 && GENERATION.test(parts[4] ?? "");
    if ((deterministic || revisioned) &&
        parts[0] === "shared_rooms" &&
        parts[1] === deletedRoom.ownerKey &&
        parts[2] === code &&
        parts[3] === slot) {
      paths.push(path);
    }
  }
  return paths;
};

const sameMoment = (left: unknown, right: unknown): boolean => {
  const millis = (value: unknown): number | undefined => {
    if (value instanceof Date) return value.getTime();
    if (typeof value === "number" && Number.isFinite(value)) return value;
    if (typeof value === "object" && value !== null &&
        "toMillis" in value && typeof value.toMillis === "function") {
      return value.toMillis();
    }
    return undefined;
  };
  const leftMillis = millis(left);
  const rightMillis = millis(right);
  return leftMillis !== undefined && rightMillis !== undefined &&
    leftMillis === rightMillis;
};

// Retries and out-of-order events can make an older immutable revision live
// again. Admin cleanup must defer to the room document that is live now.
const liveRoomStillReferencesSharedMedia = async (
  code: string,
  store: SpaceCleanupStore,
  path: string,
): Promise<boolean> => {
  const roomRef = store.collection("rooms").doc(code);
  const currentRoom = await store.runTransaction(
    async (transaction) => transaction.get(roomRef),
  );
  const current = currentRoom.data();
  if (!currentRoom.exists || current === undefined) return false;
  return (current.v === 8 && deletedPublicRoomPhotoPath(code, current) === path) ||
    deletedLegacyRoomMediaPaths(code, current).includes(path);
};

/**
 * Removes projections only when they still belong to the deleted room
 * generation. If a short code has already been reused, the current room is
 * the generation fence: old projections are never allowed to delete the new
 * owner's data.
 */
export const cleanupDeletedSpaceHandler = async (
  code: string,
  store: SpaceCleanupStore,
  deletedRoom: DeletedRoomAnchor,
  publicRoomPhotoStorage?: PublicRoomPhotoStorage,
): Promise<void> => {
  const deletedOwnerKey = typeof deletedRoom.ownerKey === "string" ? deletedRoom.ownerKey : undefined;
  const deletedGeneration = deletedRoom.updatedAt;
  await store.runTransaction(async (transaction) => {
    const roomRef = store.collection("rooms").doc(code);
    const publicRef = store.collection("publicSpaceProfiles").doc(code);
    const mutualRef = store.collection("mutualSpaceProfiles").doc(code);
    const directoryRef = store.collection("discoverableSpaces").doc(code);
    const ownerRef = store.collection("roomOwners").doc(code);
    const [currentRoom, publicProfile, mutualProfile, directory, owner] = await Promise.all([
      transaction.get(roomRef),
      transaction.get(publicRef),
      transaction.get(mutualRef),
      transaction.get(directoryRef),
      transaction.get(ownerRef),
    ]);

    const codeWasReused = currentRoom.exists;
    const profileBelongsToDeletedGeneration = (snapshot: SpaceCleanupSnapshot): boolean => {
      const data = snapshot.data();
      if (!snapshot.exists || deletedOwnerKey === undefined || data?.ownerKey !== deletedOwnerKey) {
        return false;
      }
      // New projections carry the room generation. Legacy projections can be
      // removed only when the room is absent; with a live replacement room,
      // leaving them in place is safer than deleting replacement data.
      return !codeWasReused || sameMoment(data.roomUpdatedAt, deletedGeneration);
    };
    const directoryBelongsToDeletedGeneration = (): boolean => {
      const data = directory.data();
      if (!directory.exists || deletedOwnerKey === undefined ||
          data?.ownerKey !== deletedOwnerKey) return false;
      return !codeWasReused || sameMoment(data.roomUpdatedAt, deletedGeneration);
    };
    const ownerRegistryBelongsToDeletedGeneration = (): boolean => {
      const data = owner.data();
      if (!owner.exists || deletedOwnerKey === undefined ||
          data?.ownerKey !== deletedOwnerKey) return false;
      // The registry is the deletion-flow's ownership anchor. Once a new room
      // exists, retain the registry even if the owner key is unchanged: the
      // delete event cannot safely distinguish a stale same-owner generation
      // from the live room's only ownership record.
      return !codeWasReused;
    };

    // A reused code must never be deleted wholesale. Only generation-tagged
    // projections from the deleted room may be removed in that case.
    if (profileBelongsToDeletedGeneration(publicProfile)) transaction.delete(publicRef);
    if (profileBelongsToDeletedGeneration(mutualProfile)) transaction.delete(mutualRef);
    if (directoryBelongsToDeletedGeneration()) transaction.delete(directoryRef);
    if (ownerRegistryBelongsToDeletedGeneration()) transaction.delete(ownerRef);

  });

  // The Firestore pointer has already been deleted before this trigger runs.
  // Delete only exact snapshot-owned media after public availability is gone.
  // Let a Storage failure retry the event; silently retaining public bytes
  // would defeat account/unshare cleanup.
  const mediaPaths = [
    ...deletedLegacyRoomMediaPaths(code, deletedRoom),
    ...[deletedPublicRoomPhotoPath(code, deletedRoom)].filter(
      (path): path is string => path !== null,
    ),
  ];
  if (publicRoomPhotoStorage !== undefined) {
    for (const path of new Set(mediaPaths)) {
      if (await liveRoomStillReferencesSharedMedia(code, store, path)) continue;
      await publicRoomPhotoStorage.deleteObject(path);
    }
  }
};

/// Clears an obsolete public room-photo revision after a successful room
/// update has changed or removed its pointer. The current document is already
/// authoritative when this runs, so preserving its exact path prevents a
/// delayed retry from deleting the new revision.
export const cleanupReplacedPublicRoomPhotoHandler = async (
  code: string,
  store: SpaceCleanupStore,
  previousRoom: DeletedRoomAnchor,
  currentRoom: DeletedRoomAnchor,
  publicRoomPhotoStorage: PublicRoomPhotoStorage,
): Promise<void> => {
  if (previousRoom.v !== 8) return;
  const previousPath = deletedPublicRoomPhotoPath(code, previousRoom);
  if (previousPath === null || currentRoom.roomPhotoPath === previousPath) {
    return;
  }
  if (await liveRoomStillReferencesSharedMedia(code, store, previousPath)) return;
  await publicRoomPhotoStorage.deleteObject(previousPath);
};
