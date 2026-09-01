import {createHash} from "node:crypto";

import {
  cleanupDeletedSpaceHandler,
  cleanupReplacedPublicRoomPhotoHandler,
  deletedLegacyRoomMediaPaths,
  deletedPublicRoomPhotoPath,
  type SpaceCleanupStore,
  type SpaceCleanupSnapshot,
} from "./space_cleanup";

const ownerKey = (uid: string) => createHash("sha256").update(uid, "utf8").digest("hex");
const roomGeneration = new Date("2026-08-24T12:00:00.000Z");
const publicRoomPhotoPath = (code = "ABC234") =>
  `shared_rooms/${ownerKey("owner")}/${code}/room/ABCDEFGHIJKLMNOPQRSTUV`;
const legacyProfilePath = (code = "ABC234") =>
  `shared_rooms/${ownerKey("owner")}/${code}/profile`;
const legacySeasonPath = (code = "ABC234") =>
  `shared_rooms/${ownerKey("owner")}/${code}/season/ABCDEFGHIJKLMNOPQRSTUV`;

const makeStore = (initial: Record<string, Record<string, unknown>> = {}) => {
  const docs = new Map(Object.entries(initial));
  const key = (path: string, id: string) => `${path}/${id}`;
  const deleted: string[] = [];
  let committed = false;
  const store: SpaceCleanupStore = {
    collection(path) {
      return {doc: (id: string) => ({path: key(path, id)})};
    },
    async runTransaction(fn) {
      const result = await fn({
        async get(reference) {
          const path = (reference as {path: string}).path;
          const value = docs.get(path);
          const snapshot: SpaceCleanupSnapshot = {
            exists: value !== undefined,
            data: () => value,
          };
          return snapshot;
        },
        delete(reference) {
          const path = (reference as {path: string}).path;
          deleted.push(path);
          docs.delete(path);
        },
      });
      committed = true;
      return result;
    },
  };
  return {store, docs, deleted, get committed() { return committed; }};
};

const profile = (ownerUid: string, generation = roomGeneration) => ({
  ownerKey: ownerKey(ownerUid),
  roomUpdatedAt: generation,
});

describe("deleted-space projection cleanup", () => {
  test("deletes matching projections when the room is truly gone", async () => {
    const result = makeStore({
      "publicSpaceProfiles/ABC234": profile("owner"),
      "mutualSpaceProfiles/ABC234": profile("owner"),
      "discoverableSpaces/ABC234": {
        ownerKey: ownerKey("owner"),
        roomUpdatedAt: roomGeneration,
      },
      "roomOwners/ABC234": {
        ownerKey: ownerKey("owner"),
        updatedAt: roomGeneration,
      },
    });
    const {store, deleted} = result;

    await cleanupDeletedSpaceHandler(
      "ABC234", store, {ownerKey: ownerKey("owner"), updatedAt: roomGeneration},
    );

    expect(deleted).toEqual([
      "publicSpaceProfiles/ABC234",
      "mutualSpaceProfiles/ABC234",
      "discoverableSpaces/ABC234",
      "roomOwners/ABC234",
    ]);
    expect(result.committed).toBe(true);
  });

  test("does not delete replacement projections when a code is reused", async () => {
    const replacementGeneration = new Date("2026-08-24T12:05:00.000Z");
    const {store, deleted, docs} = makeStore({
      "rooms/ABC234": {uid: "new-owner", updatedAt: replacementGeneration},
      "publicSpaceProfiles/ABC234": profile("new-owner", replacementGeneration),
      "mutualSpaceProfiles/ABC234": profile("new-owner", replacementGeneration),
      "discoverableSpaces/ABC234": {
        ownerKey: ownerKey("new-owner"),
        roomUpdatedAt: replacementGeneration,
      },
      "roomOwners/ABC234": {
        ownerKey: ownerKey("new-owner"),
        updatedAt: replacementGeneration,
      },
    });

    await cleanupDeletedSpaceHandler(
      "ABC234", store, {ownerKey: ownerKey("owner"), updatedAt: roomGeneration},
    );

    expect(deleted).toEqual([]);
    expect(docs.has("publicSpaceProfiles/ABC234")).toBe(true);
    expect(docs.has("mutualSpaceProfiles/ABC234")).toBe(true);
    expect(docs.has("discoverableSpaces/ABC234")).toBe(true);
  });

  test("removes only the deleted generation beside a same-owner replacement", async () => {
    const replacementGeneration = new Date("2026-08-24T12:05:00.000Z");
    const {store, deleted, docs} = makeStore({
      "rooms/ABC234": {uid: "owner", updatedAt: replacementGeneration},
      "publicSpaceProfiles/ABC234": profile("owner", roomGeneration),
      "mutualSpaceProfiles/ABC234": profile("owner", roomGeneration),
      "discoverableSpaces/ABC234": {
        ownerKey: ownerKey("owner"),
        roomUpdatedAt: roomGeneration,
      },
      "roomOwners/ABC234": {
        ownerKey: ownerKey("owner"),
        updatedAt: replacementGeneration,
      },
    });

    await cleanupDeletedSpaceHandler(
      "ABC234", store, {ownerKey: ownerKey("owner"), updatedAt: roomGeneration},
    );

    expect(deleted).toEqual([
      "publicSpaceProfiles/ABC234",
      "mutualSpaceProfiles/ABC234",
      "discoverableSpaces/ABC234",
    ]);
    expect(docs.has("publicSpaceProfiles/ABC234")).toBe(false);
    expect(docs.has("mutualSpaceProfiles/ABC234")).toBe(false);
    expect(docs.has("discoverableSpaces/ABC234")).toBe(false);
    expect(docs.has("roomOwners/ABC234")).toBe(true);
  });

  test("does not delete untagged legacy projections beside a replacement room", async () => {
    const {store, deleted, docs} = makeStore({
      "rooms/ABC234": {uid: "owner", updatedAt: new Date("2026-08-24T12:05:00.000Z")},
      "publicSpaceProfiles/ABC234": {ownerKey: ownerKey("owner")},
      "mutualSpaceProfiles/ABC234": {ownerKey: ownerKey("owner")},
      "discoverableSpaces/ABC234": {ownerKey: ownerKey("owner")},
      "roomOwners/ABC234": {ownerKey: ownerKey("owner")},
    });

    await cleanupDeletedSpaceHandler(
      "ABC234", store, {ownerKey: ownerKey("owner"), updatedAt: roomGeneration},
    );

    expect(deleted).toEqual([]);
    expect(docs.has("publicSpaceProfiles/ABC234")).toBe(true);
    expect(docs.has("mutualSpaceProfiles/ABC234")).toBe(true);
    expect(docs.has("discoverableSpaces/ABC234")).toBe(true);
    expect(docs.has("roomOwners/ABC234")).toBe(true);
  });

  test("propagates transaction failures", async () => {
    const store: SpaceCleanupStore = {
      collection: (path) => ({doc: (id) => ({path: `${path}/${id}`})}),
      runTransaction: async () => {
        throw new Error("transient firestore failure");
      },
    };

    await expect(cleanupDeletedSpaceHandler(
      "ABC234", store, {ownerKey: ownerKey("owner"), updatedAt: roomGeneration},
    )).rejects.toThrow("transient firestore failure");
  });

  test("deletes only the exact opaque room-photo revision after its pointer is gone", async () => {
    const result = makeStore();
    const deletedObjects: string[] = [];
    await cleanupDeletedSpaceHandler(
      "ABC234",
      result.store,
      {
        ownerKey: ownerKey("owner"),
        updatedAt: roomGeneration,
        roomPhotoPath: publicRoomPhotoPath(),
      },
      {deleteObject: async (path) => { deletedObjects.push(path); }},
    );
    expect(result.committed).toBe(true);
    expect(deletedObjects).toEqual([publicRoomPhotoPath()]);
  });

  test("preserves a deleted room photo when same-owner code reuse makes it live again", async () => {
    const path = publicRoomPhotoPath();
    const deletedObjects: string[] = [];
    const result = makeStore({
      "rooms/ABC234": {v: 8, ownerKey: ownerKey("owner"), roomPhotoPath: path},
    });

    await cleanupDeletedSpaceHandler(
      "ABC234",
      result.store,
      {v: 8, ownerKey: ownerKey("owner"), updatedAt: roomGeneration, roomPhotoPath: path},
      {deleteObject: async (objectPath) => { deletedObjects.push(objectPath); }},
    );

    expect(deletedObjects).toEqual([]);
  });

  test("deletes validated v6/v7 profile and season paths after room removal", async () => {
    const deletedObjects: string[] = [];
    await cleanupDeletedSpaceHandler(
      "ABC234",
      makeStore().store,
      {
        v: 7,
        ownerKey: ownerKey("owner"),
        profilePhotoPath: legacyProfilePath(),
        seasonPhotoPath: legacySeasonPath(),
      },
      {deleteObject: async (path) => { deletedObjects.push(path); }},
    );

    expect(deletedObjects).toEqual([legacyProfilePath(), legacySeasonPath()]);
  });

  test("preserves a legacy profile path when same-owner code reuse makes it live again", async () => {
    const path = legacyProfilePath();
    const deletedObjects: string[] = [];
    const result = makeStore({
      "rooms/ABC234": {
        v: 7,
        ownerKey: ownerKey("owner"),
        profilePhotoPath: path,
        seasonPhotoPath: "",
      },
    });

    await cleanupDeletedSpaceHandler(
      "ABC234",
      result.store,
      {
        v: 7,
        ownerKey: ownerKey("owner"),
        updatedAt: roomGeneration,
        profilePhotoPath: path,
      },
      {deleteObject: async (objectPath) => { deletedObjects.push(objectPath); }},
    );

    expect(deletedObjects).toEqual([]);
  });

  test("never derives legacy media cleanup from a cross-owner or malformed path", () => {
    const anchor = {
      v: 7,
      ownerKey: ownerKey("owner"),
      profilePhotoPath: legacyProfilePath(),
      seasonPhotoPath: legacySeasonPath(),
    };
    expect(deletedLegacyRoomMediaPaths("ABC234", anchor)).toEqual([
      legacyProfilePath(),
      legacySeasonPath(),
    ]);
    expect(deletedLegacyRoomMediaPaths("ABC234", {
      ...anchor,
      profilePhotoPath: `shared_rooms/${ownerKey("other")}/ABC234/profile`,
      seasonPhotoPath: "shared_rooms/bad",
    })).toEqual([]);
  });

  test("never derives a Storage delete from malformed or cross-owner room data", () => {
    const anchor = {ownerKey: ownerKey("owner"), roomPhotoPath: publicRoomPhotoPath()};
    expect(deletedPublicRoomPhotoPath("ABC234", anchor)).toBe(publicRoomPhotoPath());
    expect(deletedPublicRoomPhotoPath("ABC234", {...anchor, roomPhotoPath: "shared_rooms/owner/ABC234/room/ABCDEFGHIJKLMNOPQRSTUV"})).toBeNull();
    expect(deletedPublicRoomPhotoPath("ABC234", {...anchor, roomPhotoPath: `shared_rooms/${ownerKey("other")}/ABC234/room/ABCDEFGHIJKLMNOPQRSTUV`})).toBeNull();
    expect(deletedPublicRoomPhotoPath("ABC234", {...anchor, roomPhotoPath: ""})).toBeNull();
  });

  test("propagates a Storage deletion failure so the trigger can retry", async () => {
    await expect(cleanupDeletedSpaceHandler(
      "ABC234",
      makeStore().store,
      {
        ownerKey: ownerKey("owner"),
        updatedAt: roomGeneration,
        roomPhotoPath: publicRoomPhotoPath(),
      },
      {deleteObject: async () => { throw new Error("storage unavailable"); }},
    )).rejects.toThrow("storage unavailable");
  });

  test("deletes the prior v8 room photo only after a replacement pointer commits", async () => {
    const deletedObjects: string[] = [];
    const nextPath = `shared_rooms/${ownerKey("owner")}/ABC234/room/ZYXWVUTSRQPONMLKJIHGFE`;
    await cleanupReplacedPublicRoomPhotoHandler(
      "ABC234",
      makeStore().store,
      {v: 8, ownerKey: ownerKey("owner"), roomPhotoPath: publicRoomPhotoPath()},
      {v: 8, ownerKey: ownerKey("owner"), roomPhotoPath: nextPath},
      {deleteObject: async (path) => { deletedObjects.push(path); }},
    );
    expect(deletedObjects).toEqual([publicRoomPhotoPath()]);
  });

  test("clears the prior v8 room photo after an opt-out but preserves the current path", async () => {
    const deletedObjects: string[] = [];
    const previous = {v: 8, ownerKey: ownerKey("owner"), roomPhotoPath: publicRoomPhotoPath()};
    const storage = {deleteObject: async (path: string) => { deletedObjects.push(path); }};
    await cleanupReplacedPublicRoomPhotoHandler("ABC234", makeStore().store, previous, {...previous}, storage);
    await cleanupReplacedPublicRoomPhotoHandler(
      "ABC234", makeStore().store, previous, {...previous, roomPhotoPath: ""}, storage,
    );
    expect(deletedObjects).toEqual([publicRoomPhotoPath()]);
  });

  test("does not delete malformed or legacy prior fields and retries a real Storage failure", async () => {
    const storage = {deleteObject: async () => { throw new Error("storage unavailable"); }};
    await expect(cleanupReplacedPublicRoomPhotoHandler(
      "ABC234",
      makeStore().store,
      {v: 7, ownerKey: ownerKey("owner"), roomPhotoPath: publicRoomPhotoPath()},
      {roomPhotoPath: ""},
      storage,
    )).resolves.toBeUndefined();
    await expect(cleanupReplacedPublicRoomPhotoHandler(
      "ABC234",
      makeStore().store,
      {v: 8, ownerKey: ownerKey("owner"), roomPhotoPath: "shared_rooms/bad"},
      {roomPhotoPath: ""},
      storage,
    )).resolves.toBeUndefined();
    await expect(cleanupReplacedPublicRoomPhotoHandler(
      "ABC234",
      makeStore().store,
      {v: 8, ownerKey: ownerKey("owner"), roomPhotoPath: publicRoomPhotoPath()},
      {roomPhotoPath: ""},
      storage,
    )).rejects.toThrow("storage unavailable");
  });

  test("preserves a reactivated previous revision on a delayed replacement retry", async () => {
    const path = publicRoomPhotoPath();
    const deletedObjects: string[] = [];
    const result = makeStore({
      "rooms/ABC234": {v: 8, ownerKey: ownerKey("owner"), roomPhotoPath: path},
    });

    await cleanupReplacedPublicRoomPhotoHandler(
      "ABC234",
      result.store,
      {v: 8, ownerKey: ownerKey("owner"), roomPhotoPath: path},
      {
        v: 8,
        ownerKey: ownerKey("owner"),
        roomPhotoPath: `shared_rooms/${ownerKey("owner")}/ABC234/room/ZYXWVUTSRQPONMLKJIHGFE`,
      },
      {deleteObject: async (objectPath) => { deletedObjects.push(objectPath); }},
    );

    expect(deletedObjects).toEqual([]);
  });
});
