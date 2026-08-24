import type {Firestore} from "firebase-admin/firestore";
import {ownerKeyForUid} from "./discovery";

export type RelationshipCollection = "circleRelationships" | "spaceBlocks";
export type RelationshipSubcollection = "outgoing" | "blocked";

/**
 * The opaque owner-key graph is deliberately inaccessible to clients. This
 * narrow store keeps the account-deletion cleanup testable without exposing
 * an Admin Firestore dependency to the handler itself.
 */
export type IdentityRelationshipCleanupStore = {
  listOwned(path: string): Promise<readonly string[]>;
  listIncoming(
    subcollection: RelationshipSubcollection,
    targetOwnerKey: string,
  ): Promise<readonly string[]>;
  delete(paths: readonly string[]): Promise<void>;
};

const DELETE_BATCH_SIZE = 450;

/** Admin adapter used only by the Auth-deletion cleanup. */
export const firestoreIdentityRelationshipCleanupStore = (
  db: Firestore,
): IdentityRelationshipCleanupStore => ({
  async listOwned(path) {
    const snapshot = await db.collection(path).get();
    return snapshot.docs.map((document) => document.ref.path);
  },
  async listIncoming(subcollection, targetOwnerKey) {
    const snapshot = await db.collectionGroup(subcollection)
      .where("ownerKey", "==", targetOwnerKey)
      .get();
    return snapshot.docs.map((document) => document.ref.path);
  },
  async delete(paths) {
    for (let offset = 0; offset < paths.length; offset += DELETE_BATCH_SIZE) {
      const batch = db.batch();
      for (const path of paths.slice(offset, offset + DELETE_BATCH_SIZE)) {
        batch.delete(db.doc(path));
      }
      await batch.commit();
    }
  },
});

const subcollectionFor = (collection: RelationshipCollection): RelationshipSubcollection =>
  collection === "circleRelationships" ? "outgoing" : "blocked";

/**
 * Removes both directions of the deleted identity's relationship edges.
 *
 * Room deletion intentionally does not call this: stopping sharing or
 * rotating a room code must not erase somebody's Circle or block choices.
 * Auth deletion is the irreversible identity-level event that authorizes this
 * cleanup, whether the identity was anonymous, linked, or reset locally.
 */
export const cleanupDeletedIdentityRelationshipsHandler = async (
  uid: string,
  store: IdentityRelationshipCleanupStore,
): Promise<void> => {
  const deletedOwnerKey = ownerKeyForUid(uid);
  const collections: readonly RelationshipCollection[] = [
    "circleRelationships",
    "spaceBlocks",
  ];
  const paths = await Promise.all(collections.flatMap((collection) => {
    const subcollection = subcollectionFor(collection);
    return [
      store.listOwned(`${collection}/${deletedOwnerKey}/${subcollection}`),
      store.listIncoming(subcollection, deletedOwnerKey),
    ];
  }));
  const uniquePaths = [...new Set(paths.flat())];
  if (uniquePaths.length > 0) await store.delete(uniquePaths);
};
