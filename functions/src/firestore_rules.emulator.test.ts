import {readFileSync} from "node:fs";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  where,
} from "firebase/firestore";

const describeWithEmulator = process.env.FIRESTORE_EMULATOR_HOST ?
  describe : describe.skip;

const projection = (bucket: number) => ({
  v: 2,
  title: "KEEPER",
  level: 4,
  wall: "wall_conservatory",
  floor: "floor_oak",
  skin: "ember_amber",
  window: "moon",
  bucket,
  publicName: "",
  updatedAt: Timestamp.now(),
  expiresAt: Timestamp.fromMillis(Date.now() + 30 * 24 * 60 * 60 * 1000),
});

describeWithEmulator("discoverableSpaces Firestore rules", () => {
  let environment: RulesTestEnvironment;

  beforeAll(async () => {
    const [host, rawPort] = process.env.FIRESTORE_EMULATOR_HOST!.split(":");
    environment = await initializeTestEnvironment({
      projectId: process.env.GCLOUD_PROJECT ?? "emberkeep-rules-test",
      firestore: {
        host,
        port: Number(rawPort),
        rules: readFileSync("../firestore.rules", "utf8"),
      },
    });
  });

  beforeEach(async () => {
    await environment.clearFirestore();
    await environment.withSecurityRulesDisabled(async (context) => {
      const database = context.firestore();
      await Promise.all([
        setDoc(doc(database, "discoverableSpaces", "ABC234"), projection(250000)),
        setDoc(doc(database, "discoverableSpaces", "DEF234"), projection(750000)),
        setDoc(doc(database, "discoverableSpaces", "BAD234"), {
          ...projection(900000),
          privateField: "must not pass an exact read",
        }),
        setDoc(doc(database, "discoverableSpaces", "XYZ234"), {
          ...projection(100000),
          expiresAt: Timestamp.fromMillis(Date.now() - 60 * 1000),
        }),
        setDoc(doc(database, "rooms", "XYZ234"), {uid: "owner"}),
      ]);
    });
  });

  afterAll(async () => {
    await environment.cleanup();
  });

  test("allows only the bounded fresh-lease query used by Discover", async () => {
    const database = environment.authenticatedContext("reader").firestore();
    const directory = collection(database, "discoverableSpaces");
    const freshAfter = Timestamp.fromMillis(Date.now() + 5 * 60 * 1000);

    await assertSucceeds(getDocs(query(
      directory,
      where("expiresAt", ">", freshAfter),
      orderBy("expiresAt", "desc"),
      limit(12),
    )));
  });

  test("denies anonymous, unbounded, and oversized directory queries", async () => {
    const anonymous = environment.unauthenticatedContext().firestore();
    const authenticated = environment.authenticatedContext("reader").firestore();

    await assertFails(getDocs(query(
      collection(anonymous, "discoverableSpaces"),
      orderBy("bucket"),
      limit(8),
    )));
    await assertFails(getDocs(query(
      collection(authenticated, "discoverableSpaces"),
      orderBy("bucket"),
      limit(8),
    )));
    await assertFails(getDocs(query(
      collection(authenticated, "discoverableSpaces"),
      where("expiresAt", ">", Timestamp.now()),
      orderBy("expiresAt", "desc"),
    )));
    await assertFails(getDocs(query(
      collection(authenticated, "discoverableSpaces"),
      orderBy("bucket"),
      limit(13),
    )));
  });

  test("keeps strict projection validation on exact reads", async () => {
    const database = environment.authenticatedContext("reader").firestore();
    await assertSucceeds(getDoc(doc(database, "discoverableSpaces", "ABC234")));
    await assertFails(getDoc(doc(database, "discoverableSpaces", "BAD234")));
    await assertFails(getDoc(doc(database, "discoverableSpaces", "XYZ234")));

    const owner = environment.authenticatedContext("owner").firestore();
    await assertSucceeds(getDoc(doc(owner, "discoverableSpaces", "XYZ234")));
    await assertSucceeds(setDoc(doc(owner, "discoverableSpaces", "XYZ234"), {
      ...projection(100000),
      updatedAt: serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + 30 * 24 * 60 * 60 * 1000),
    }));
    await assertSucceeds(getDoc(doc(database, "discoverableSpaces", "XYZ234")));
  });
});
