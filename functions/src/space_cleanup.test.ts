import {createHash} from "node:crypto";

import {
  cleanupDeletedSpaceHandler,
  type SpaceCleanupStore,
  type SpaceCleanupSnapshot,
} from "./space_cleanup";

const ownerKey = (uid: string) => createHash("sha256").update(uid, "utf8").digest("hex");
const roomGeneration = new Date("2026-08-24T12:00:00.000Z");

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
      await fn({
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
});
