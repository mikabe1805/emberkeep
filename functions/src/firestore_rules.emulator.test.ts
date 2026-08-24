import {readFileSync} from "node:fs";
import {createHash} from "node:crypto";
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
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  where,
  writeBatch,
} from "firebase/firestore";

const describeWithEmulator = process.env.FIRESTORE_EMULATOR_HOST ?
  describe : describe.skip;

const stableOwnerKey = (uid: string) => createHash("sha256").update(uid, "utf8").digest("hex");
const ownerKey = stableOwnerKey("owner");
const readerKey = stableOwnerKey("reader");
const roomGeneration = Timestamp.fromMillis(1724500800000);

const room = (key = ownerKey, generation = roomGeneration) => ({
  ownerKey: key,
  v: 6,
  profileVisible: false,
  updatedAt: generation,
});

const roomOwner = (uid = "owner", key = ownerKey, generation = roomGeneration) => ({
  uid,
  ownerKey: key,
  updatedAt: generation,
});

const generatedRoomWrite = (key: string, version = 6) => ({
  ownerKey: key,
  name: "Fellow keeper",
  title: "KEEPER",
  level: 1,
  furniture: [],
  wall: "wall_walnut",
  floor: "floor_oak",
  skin: "ember_amber",
  window: "moon",
  awake: false,
  memories: 0,
  weather: "unknown",
  todayLit: false,
  focusKind: "none",
  focusUntil: 0,
  profileVisible: false,
  displayName: "",
  about: "",
  featuredGoals: [],
  cardOrder: [],
  pinnedMoments: [],
  season: "",
  v: version,
  profilePhotoPath: "",
  seasonPhotoPath: "",
  updatedAt: serverTimestamp(),
});

const projection = (bucket: number, key = ownerKey) => ({
  v: 3,
  title: "KEEPER",
  level: 4,
  wall: "wall_conservatory",
  floor: "floor_oak",
  skin: "ember_amber",
  window: "moon",
  bucket,
  publicName: "",
  ownerKey: key,
  updatedAt: Timestamp.now(),
  expiresAt: Timestamp.fromMillis(Date.now() + 30 * 24 * 60 * 60 * 1000),
});

const profile = (key = ownerKey, generation = roomGeneration) => ({
  v: 2,
  ownerKey: key,
  displayName: "Mika",
  cardOrder: ["about"],
  about: "A quiet room made from lived days.",
  featuredGoals: [],
  pinnedMoments: [],
  season: "",
  roomUpdatedAt: generation,
  updatedAt: Timestamp.now(),
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
        setDoc(doc(database, "rooms", "ABC234"), room()),
        setDoc(doc(database, "roomOwners", "ABC234"), roomOwner()),
        setDoc(doc(database, "rooms", "DEF234"), room()),
        setDoc(doc(database, "roomOwners", "DEF234"), roomOwner()),
        setDoc(doc(database, "rooms", "XYZ234"), room()),
        setDoc(doc(database, "roomOwners", "XYZ234"), roomOwner()),
        setDoc(doc(database, "publicSpaceProfiles", "ABC234"), profile()),
        setDoc(doc(database, "mutualSpaceProfiles", "ABC234"), profile()),
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

  test("makes a stale directory record unreadable without its live room anchor", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const database = context.firestore();
      await setDoc(doc(database, "discoverableSpaces", "NOANCH"), projection(500000));
      await setDoc(doc(database, "discoverableSpaces", "MISMAT"), projection(500001));
      await setDoc(doc(database, "rooms", "MISMAT"), room(readerKey));
      await setDoc(doc(database, "roomOwners", "MISMAT"), roomOwner("reader", readerKey));
    });

    const reader = environment.authenticatedContext("reader").firestore();
    await assertFails(getDoc(doc(reader, "discoverableSpaces", "NOANCH")));
    await assertFails(getDoc(doc(reader, "discoverableSpaces", "MISMAT")));
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

  test("lets only the owner read the absent directory entry needed for first opt-in", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const database = context.firestore();
      await Promise.all([
        setDoc(doc(database, "rooms", "NEW234"), room()),
        setDoc(doc(database, "roomOwners", "NEW234"), roomOwner()),
      ]);
    });

    const reader = environment.authenticatedContext("reader").firestore();
    await assertFails(getDoc(doc(reader, "discoverableSpaces", "NEW234")));

    const owner = environment.authenticatedContext("owner").firestore();
    const directoryEntry = doc(owner, "discoverableSpaces", "NEW234");
    await assertSucceeds(runTransaction(owner, async (transaction) => {
      const existing = await transaction.get(directoryEntry);
      expect(existing.exists()).toBe(false);
      transaction.set(directoryEntry, {
        ...projection(375000),
        updatedAt: serverTimestamp(),
      });
    }));
    await assertSucceeds(getDoc(directoryEntry));
  });

  test("rejects an owner create or refresh while its stable owner key is banned", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const database = context.firestore();
      await setDoc(doc(database, "rooms", "NEW234"), room());
      await setDoc(doc(database, "roomOwners", "NEW234"), roomOwner());
      await setDoc(doc(database, "discoveryBans", "4c1029697ee358715d3a14a2add817c4b01651440de808371f78165ac90dc581"), {state: "active"});
    });
    const owner = environment.authenticatedContext("owner").firestore();
    await assertFails(getDoc(doc(owner, "discoverableSpaces", "NEW234")));
    await assertFails(setDoc(doc(owner, "discoverableSpaces", "NEW234"), projection(250000)));
    await assertFails(setDoc(doc(owner, "discoverableSpaces", "XYZ234"), {
      ...projection(100000),
      updatedAt: serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + 30 * 24 * 60 * 60 * 1000),
    }));
  });

  test("an owner can atomically create a strict v6 room and private registry", async () => {
    const owner = environment.authenticatedContext("owner").firestore();
    const batch = writeBatch(owner);
    batch.set(doc(owner, "rooms", "NEW234"), generatedRoomWrite(ownerKey));
    batch.set(doc(owner, "roomOwners", "NEW234"), {
      uid: "owner",
      ownerKey,
      updatedAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());
  });

  test("only the Build 31 owner can migrate v5 to v6 without rotating its code", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const legacyRoom: Record<string, unknown> = {
        ...generatedRoomWrite(ownerKey, 5),
        uid: "owner",
        updatedAt: roomGeneration,
      };
      delete legacyRoom.ownerKey;
      await setDoc(doc(context.firestore(), "rooms", "BEG234"), legacyRoom);
    });

    const anonymous = environment.unauthenticatedContext().firestore();
    const reader = environment.authenticatedContext("reader").firestore();
    const owner = environment.authenticatedContext("owner").firestore();
    await assertFails(getDoc(doc(anonymous, "rooms", "BEG234")));
    await assertFails(getDoc(doc(reader, "rooms", "BEG234")));
    await assertSucceeds(getDoc(doc(owner, "rooms", "BEG234")));

    const batch = writeBatch(owner);
    batch.set(doc(owner, "rooms", "BEG234"), generatedRoomWrite(ownerKey));
    batch.set(doc(owner, "roomOwners", "BEG234"), {
      uid: "owner",
      ownerKey,
      updatedAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());

    await assertSucceeds(getDoc(doc(reader, "rooms", "BEG234")));
    await assertFails(getDoc(doc(reader, "roomOwners", "BEG234")));
    await assertSucceeds(getDoc(doc(owner, "roomOwners", "BEG234")));
  });

  test("public profiles are exact-read only and must match a live generated room", async () => {
    const anonymous = environment.unauthenticatedContext().firestore();
    const reader = environment.authenticatedContext("reader").firestore();
    await assertSucceeds(getDoc(doc(anonymous, "publicSpaceProfiles", "ABC234")));
    await assertFails(getDocs(collection(reader, "publicSpaceProfiles")));
    await assertFails(setDoc(doc(reader, "publicSpaceProfiles", "ABC234"), profile()));
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "publicSpaceProfiles", "BAD234"), {
        ...profile(), ownerKey: stableOwnerKey("not-the-room-owner"),
      });
      await setDoc(doc(context.firestore(), "rooms", "BAD234"), {
        ...room(),
      });
      await setDoc(doc(context.firestore(), "roomOwners", "BAD234"), roomOwner());
    });
    await assertFails(getDoc(doc(reader, "publicSpaceProfiles", "BAD234")));
  });

  test("profile reads reject stale rooms, owner-key mismatches, and malformed schemas", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const database = context.firestore();
      const cases = [
        ["MISSING", undefined, profile()],
        ["LEGACY", {...room(), v: 5}, profile()],
        ["VISIBLE", {...room(), profileVisible: true}, profile()],
        ["CHANGED", room(stableOwnerKey("other-owner")), profile()],
        ["BADKEY", room(), {
          ...profile(), ownerKey: "0".repeat(64),
        }],
        ["DUPLICATE", room(), {
          ...profile(), cardOrder: ["about", "about"],
        }],
        ["BADPIN", room(), {
          ...profile(), pinnedMoments: [{text: "not valid", at: "now"}],
        }],
        ["BADSTAMP", room(), {
          ...profile(), updatedAt: "not a timestamp",
        }],
        ["EXTRA", room(), {
          ...profile(), privateField: "must not pass",
        }],
      ] as const;
      for (const [code, room, value] of cases) {
        if (room !== undefined) {
          await setDoc(doc(database, "rooms", code), room);
          const key = typeof room.ownerKey === "string" ? room.ownerKey : ownerKey;
          await setDoc(doc(database, "roomOwners", code), roomOwner("owner", key));
        }
        await setDoc(doc(database, "publicSpaceProfiles", code), value);
        await setDoc(doc(database, "mutualSpaceProfiles", code), value);
      }
    });

    const anonymous = environment.unauthenticatedContext().firestore();
    const reader = environment.authenticatedContext("reader").firestore();
    for (const code of [
      "MISSING", "LEGACY", "VISIBLE", "CHANGED", "BADKEY", "DUPLICATE",
      "BADPIN", "BADSTAMP", "EXTRA",
    ]) {
      await assertFails(getDoc(doc(anonymous, "publicSpaceProfiles", code)));
      await assertFails(getDoc(doc(reader, "mutualSpaceProfiles", code)));
    }
  });

  test("mutual profiles require reciprocal Circle edges and no block", async () => {
    const reader = environment.authenticatedContext("reader").firestore();
    const owner = environment.authenticatedContext("owner").firestore();
    const anonymous = environment.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anonymous, "mutualSpaceProfiles", "ABC234")));
    await assertSucceeds(getDoc(doc(owner, "mutualSpaceProfiles", "ABC234")));
    await assertFails(getDoc(doc(reader, "mutualSpaceProfiles", "ABC234")));
    await environment.withSecurityRulesDisabled(async (context) => {
      const database = context.firestore();
      await setDoc(doc(database, "circleRelationships", readerKey, "outgoing", ownerKey), {edge: true});
      await setDoc(doc(database, "circleRelationships", ownerKey, "outgoing", readerKey), {edge: true});
    });
    await assertSucceeds(getDoc(doc(reader, "mutualSpaceProfiles", "ABC234")));
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "spaceBlocks", ownerKey, "blocked", readerKey), {blocked: true});
    });
    await assertFails(getDoc(doc(reader, "mutualSpaceProfiles", "ABC234")));
    await assertFails(getDocs(collection(reader, "mutualSpaceProfiles")));
  });

  test("clients cannot enumerate or forge relationship and block documents", async () => {
    const reader = environment.authenticatedContext("reader").firestore();
    await assertFails(getDocs(collection(reader, "circleRelationships", readerKey, "outgoing")));
    await assertFails(setDoc(
      doc(reader, "circleRelationships", readerKey, "outgoing", ownerKey),
      {edge: true},
    ));
    await assertFails(getDoc(doc(reader, "spaceBlocks", readerKey, "blocked", ownerKey)));
    await assertFails(setDoc(
      doc(reader, "spaceBlocks", readerKey, "blocked", ownerKey),
      {blocked: true},
    ));
  });
});
