import {ownerKeyForUid} from "./discovery";
import {
  cleanupDeletedIdentityRelationshipsHandler,
  type IdentityRelationshipCleanupStore,
  type RelationshipSubcollection,
} from "./identity_relationship_cleanup";

describe("deleted identity relationship cleanup", () => {
  const deletedKey = ownerKeyForUid("deleted-user");

  test("deletes outgoing and incoming Circle/block docs for the deleted identity", async () => {
    const calls: {owned: string[]; incoming: string[]; deleted: readonly string[] | undefined} = {
      owned: [],
      incoming: [],
      deleted: undefined,
    };
    const store: IdentityRelationshipCleanupStore = {
      async listOwned(path) {
        calls.owned.push(path);
        return path.includes("circleRelationships")
          ? [`${path}/incoming-peer`]
          : [`${path}/blocking-peer`];
      },
      async listIncoming(subcollection, targetOwnerKey) {
        calls.incoming.push(`${subcollection}:${targetOwnerKey}`);
        return subcollection === "outgoing"
          ? [`circleRelationships/peer-a/outgoing/${targetOwnerKey}`]
          : [`spaceBlocks/peer-b/blocked/${targetOwnerKey}`];
      },
      async delete(paths) {
        calls.deleted = paths;
      },
    };

    await cleanupDeletedIdentityRelationshipsHandler("deleted-user", store);

    expect(calls.owned).toEqual([
      `circleRelationships/${deletedKey}/outgoing`,
      `spaceBlocks/${deletedKey}/blocked`,
    ]);
    expect(calls.incoming).toEqual([
      `outgoing:${deletedKey}`,
      `blocked:${deletedKey}`,
    ]);
    expect(calls.deleted).toEqual([
      `circleRelationships/${deletedKey}/outgoing/incoming-peer`,
      `circleRelationships/peer-a/outgoing/${deletedKey}`,
      `spaceBlocks/${deletedKey}/blocked/blocking-peer`,
      `spaceBlocks/peer-b/blocked/${deletedKey}`,
    ]);
  });

  test("deduplicates a pathological self-edge and does not write when empty", async () => {
    const deleted: readonly string[][] = [];
    const store: IdentityRelationshipCleanupStore = {
      async listOwned(path) {
        return [`${path}/same`];
      },
      async listIncoming(subcollection, targetOwnerKey) {
        return [subcollection === "outgoing"
          ? `circleRelationships/${targetOwnerKey}/outgoing/same`
          : `spaceBlocks/${targetOwnerKey}/blocked/same`];
      },
      async delete(paths) {
        deleted.push(paths);
      },
    };

    await cleanupDeletedIdentityRelationshipsHandler("deleted-user", store);

    expect(deleted).toEqual([[
      `circleRelationships/${deletedKey}/outgoing/same`,
      `spaceBlocks/${deletedKey}/blocked/same`,
    ]]);
  });

  test("propagates a relationship query failure without partial deletion", async () => {
    let deleteCalled = false;
    const store: IdentityRelationshipCleanupStore = {
      async listOwned() {
        return [];
      },
      async listIncoming(subcollection: RelationshipSubcollection) {
        if (subcollection === "blocked") throw new Error("query failed");
        return [];
      },
      async delete() {
        deleteCalled = true;
      },
    };

    await expect(cleanupDeletedIdentityRelationshipsHandler("deleted-user", store))
      .rejects.toThrow("query failed");
    expect(deleteCalled).toBe(false);
  });
});
