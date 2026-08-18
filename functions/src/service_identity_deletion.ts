import type {Firestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

const TOMBSTONE_TTL_MS = 35 * 24 * 60 * 60 * 1_000;

type CallableRequest = {
  auth?: {
    uid: string;
    token?: {firebase?: {sign_in_provider?: string}};
  } | null;
};

export interface ServiceIdentityDeletionTombstoneStore {
  begin(uid: string): Promise<void>;
}

export type ServiceIdentityDeletionTombstone = {
  uid: string;
  state: "deleting";
  updatedAt: Date;
  expiresAt: Date;
};

export const buildServiceIdentityDeletionTombstone = (
  uid: string,
  now: Date,
): ServiceIdentityDeletionTombstone => ({
  uid,
  state: "deleting",
  updatedAt: now,
  expiresAt: new Date(now.getTime() + TOMBSTONE_TTL_MS),
});

export class FirestoreServiceIdentityDeletionTombstoneStore
implements ServiceIdentityDeletionTombstoneStore {
  constructor(
    private readonly db: Firestore,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async begin(uid: string): Promise<void> {
    const ref = this.db
      .collection("serviceIdentityDeletionTombstones")
      .doc(uid);
    await this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const instant = this.now();
      const tombstone = buildServiceIdentityDeletionTombstone(uid, instant);
      transaction.set(ref, {
        ...tombstone,
        createdAt: snapshot.exists ? snapshot.get("createdAt") : instant,
      });
    });
  }
}

export const beginServiceIdentityDeletionHandler = async (
  request: CallableRequest,
  dependencies: {store: ServiceIdentityDeletionTombstoneStore},
): Promise<{state: "deleting"}> => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  if (request.auth?.token?.firebase?.sign_in_provider !== "anonymous") {
    throw new HttpsError(
      "failed-precondition",
      "Only a private anonymous service identity can be removed here.",
    );
  }
  try {
    await dependencies.store.begin(uid);
  } catch {
    throw new HttpsError(
      "unavailable",
      "Secure identity removal could not be started.",
    );
  }
  return {state: "deleting"};
};
