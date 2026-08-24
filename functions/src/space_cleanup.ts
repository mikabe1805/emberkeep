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
  ownerKey?: unknown;
  updatedAt?: unknown;
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
};
