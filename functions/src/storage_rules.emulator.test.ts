import {createHash} from "node:crypto";
import {readFileSync} from "node:fs";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {doc, setDoc} from "firebase/firestore";

const describeWithEmulator = process.env.FIREBASE_STORAGE_EMULATOR_HOST &&
    process.env.FIRESTORE_EMULATOR_HOST ? describe : describe.skip;

const roomCode = "ABC234";
const ownerUid = "owner";
const otherUid = "other";
const ownerKey = createHash("sha256").update(ownerUid, "utf8").digest("hex");
const oldGeneration = "AAAAAAAAAAAAAAAAAAAAAA";
const newGeneration = "BBBBBBBBBBBBBBBBBBBBBB";
const failedGeneration = "CCCCCCCCCCCCCCCCCCCCCC";

const objectPath = (generation: string, key = ownerKey, code = roomCode) =>
  `shared_rooms/${key}/${code}/room/${generation}`;
const png = new Uint8Array([137, 80, 78, 71]);
const pngMetadata = {contentType: "image/png"};

describeWithEmulator("public room-photo Storage rules", () => {
  let environment: RulesTestEnvironment;

  const reference = (uid: string | null, path: string) =>
    (uid === null ? environment.unauthenticatedContext() :
      environment.authenticatedContext(uid)).storage().ref(path);

  const seedPublicRoom = async (path = "") => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      await Promise.all([
        setDoc(doc(firestore, "roomOwners", roomCode), {
          uid: ownerUid,
          ownerKey,
        }),
        setDoc(doc(firestore, "rooms", roomCode), {
          v: 8,
          ownerKey,
          roomPhotoPath: path,
        }),
      ]);
    });
  };

  beforeAll(async () => {
    const [storageHost, storagePort] =
        process.env.FIREBASE_STORAGE_EMULATOR_HOST!.split(":");
    const [firestoreHost, firestorePort] =
        process.env.FIRESTORE_EMULATOR_HOST!.split(":");
    environment = await initializeTestEnvironment({
      projectId: process.env.GCLOUD_PROJECT ?? "emberkeep-storage-rules-test",
      firestore: {
        host: firestoreHost,
        port: Number(firestorePort),
        rules: readFileSync("../firestore.rules", "utf8"),
      },
      storage: {
        host: storageHost,
        port: Number(storagePort),
        rules: readFileSync("../storage.rules", "utf8"),
      },
    });
  });

  beforeEach(async () => {
    await Promise.all([environment.clearFirestore(), environment.clearStorage()]);
    await seedPublicRoom();
  });

  afterAll(async () => {
    await environment.cleanup();
  });

  test("allows the registered owner to create, read, replace, and delete an exact room revision", async () => {
    const oldPath = objectPath(oldGeneration);
    const newPath = objectPath(newGeneration);

    await assertSucceeds(reference(ownerUid, oldPath).put(png, pngMetadata));
    await seedPublicRoom(oldPath);
    await assertSucceeds(reference(ownerUid, oldPath).getMetadata());

    await assertSucceeds(reference(ownerUid, newPath).put(png, pngMetadata));
    await seedPublicRoom(newPath);
    await assertSucceeds(reference(ownerUid, newPath).getMetadata());
    await assertSucceeds(reference(ownerUid, oldPath).delete());
  });

  test("exposes an exact public room photo only while its live room points to that revision", async () => {
    const livePath = objectPath(oldGeneration);
    const unreferencedPath = objectPath(newGeneration);
    await assertSucceeds(reference(ownerUid, livePath).put(png, pngMetadata));
    await assertSucceeds(reference(ownerUid, unreferencedPath).put(png, pngMetadata));

    await assertFails(reference(otherUid, livePath).getMetadata());
    await seedPublicRoom(livePath);
    await assertSucceeds(reference(null, livePath).getMetadata());
    await assertFails(reference(null, unreferencedPath).getMetadata());
  });

  test("keeps the old public revision live through a retry and lets the owner discard the failed replacement", async () => {
    const livePath = objectPath(oldGeneration);
    const retryPath = objectPath(failedGeneration);
    await assertSucceeds(reference(ownerUid, livePath).put(png, pngMetadata));
    await seedPublicRoom(livePath);

    await assertSucceeds(reference(ownerUid, retryPath).put(png, pngMetadata));
    await assertSucceeds(reference(null, livePath).getMetadata());
    await assertFails(reference(null, retryPath).getMetadata());
    await assertSucceeds(reference(ownerUid, retryPath).delete());
    await assertSucceeds(reference(null, livePath).getMetadata());
  });

  test("denies unauthenticated, cross-owner, malformed, oversized, and non-PNG writes", async () => {
    const validPath = objectPath(oldGeneration);
    await assertFails(reference(null, validPath).put(png, pngMetadata));
    await assertFails(reference(otherUid, validPath).put(png, pngMetadata));
    await assertFails(reference(otherUid, validPath).delete());
    await assertFails(reference(ownerUid, objectPath(oldGeneration, "not-an-owner-key")).put(png, pngMetadata));
    await assertFails(reference(ownerUid, objectPath(oldGeneration, ownerKey, "BAD")).put(png, pngMetadata));
    await assertFails(reference(ownerUid, "shared_rooms/" +
      `${ownerKey}/${roomCode}/room/short`).put(png, pngMetadata));
    await assertFails(reference(ownerUid, validPath).put(png, {contentType: "image/jpeg"}));
    await assertFails(reference(ownerUid, validPath).put(
      new Uint8Array(800 * 1024 + 1),
      pngMetadata,
    ));
  });
});
