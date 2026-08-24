import {HttpsError} from "firebase-functions/v2/https";

import {
  ownerKeyForUid,
  reportDiscoverableSpaceHandler,
  setDiscoveryPublicNameHandler,
  type DiscoveryStore,
} from "./discovery";

type AnyDoc = Record<string, unknown>;
const makeStore = (initial: Record<string, AnyDoc> = {}) => {
  const docs = new Map(Object.entries(initial));
  for (const [path, room] of [...docs.entries()]) {
    if (!path.startsWith("rooms/") || typeof room.uid !== "string") continue;
    docs.set(`roomOwners/${path.slice("rooms/".length)}`, {
      uid: room.uid,
      ownerKey: room.ownerKey,
      updatedAt: room.updatedAt,
    });
  }
  const key = (path: string, id: string) => `${path}/${id}`;
  const store: DiscoveryStore = {
    collection(path) {
      return {doc: (id: string) => ({
        async get() {
          const value = docs.get(key(path, id));
          return {exists: value !== undefined, data: () => value};
        },
        async set(data: AnyDoc, options?: {merge?: boolean}) {
          const previous = docs.get(key(path, id));
          docs.set(key(path, id), options?.merge ? {...previous, ...data} : data);
        },
      })};
    },
    async runTransaction(fn) {
      return fn({
        async get(ref) { return ref.get(); },
        set(ref, data, options) { void ref.set(data, options); },
      });
    },
  };
  return {store, docs};
};

const request = (data: unknown, uid = "owner") => ({data, auth: {uid}});
const publicNamesOn = {publicNamesEnabled: () => true};
const owned = {
  "rooms/ABC234": {
    uid: "owner",
    ownerKey: ownerKeyForUid("owner"),
    v: 6,
    profileVisible: false,
    updatedAt: new Date("2026-08-24T12:00:00.000Z"),
    secret: "preserve",
  },
  "discoverableSpaces/ABC234": {publicName: "old name", ownerKey: ownerKeyForUid("owner"), theme: "walnut"},
};
const liveRoom = (uid: string, ownerKey = ownerKeyForUid(uid)) => ({
  uid,
  ownerKey,
  v: 6,
  profileVisible: false,
  updatedAt: new Date("2026-08-24T12:00:00.000Z"),
});
const liveProfile = (ownerKey: string, generation = new Date("2026-08-24T12:00:00.000Z")) => ({
  v: 2,
  ownerKey,
  displayName: "Mika",
  cardOrder: [],
  about: "",
  featuredGoals: [],
  pinnedMoments: [],
  season: "",
  roomUpdatedAt: generation,
});

describe("discovery callables", () => {
  test("normalizes Unicode names and preserves directory data", async () => {
    const {store, docs} = makeStore(owned);
    const result = await setDiscoveryPublicNameHandler(request({code: "ABC234", publicName: "  José\u00a0  O’Neil  ",}), {store, now: () => new Date("2026-08-22T12:00:00Z"), ...publicNamesOn});
    expect(result).toEqual({publicName: "José O’Neil"});
    expect(docs.get("discoverableSpaces/ABC234")).toMatchObject({publicName: "José O’Neil", theme: "walnut"});
  });

  test.each([
    "https://example.com", "@mika", "mika@example.com", "discord mika", "fuck", "a\nname", "🙂🙂",
  ])("rejects unsafe or non-name input: %s", async (publicName) => {
    const {store} = makeStore(owned);
    await expect(setDiscoveryPublicNameHandler(request({code: "ABC234", publicName}), {store, ...publicNamesOn})).rejects.toBeInstanceOf(HttpsError);
  });

  test("allows blank name to become anonymous and enforces ownership/discoverability", async () => {
    const {store, docs} = makeStore(owned);
    await setDiscoveryPublicNameHandler(request({code: "ABC234", publicName: "   "}), {store, ...publicNamesOn});
    expect(docs.get("discoverableSpaces/ABC234")?.publicName).toBe("");
    await expect(setDiscoveryPublicNameHandler(request({code: "ABC234", publicName: "x"}, "intruder"), {store, ...publicNamesOn})).rejects.toBeInstanceOf(HttpsError);
    const missing = makeStore({"rooms/ABC234": liveRoom("owner")}).store;
    await expect(setDiscoveryPublicNameHandler(request({code: "ABC234", publicName: "x"}), {store: missing, ...publicNamesOn})).rejects.toBeInstanceOf(HttpsError);
  });

  test("rate limits repeated changes and caps the day", async () => {
    const {store} = makeStore(owned);
    const now = new Date("2026-08-22T12:00:00Z");
    await setDiscoveryPublicNameHandler(request({code: "ABC234", publicName: "first"}), {store, now: () => now, ...publicNamesOn});
    await expect(setDiscoveryPublicNameHandler(request({code: "ABC234", publicName: "second"}), {store, now: () => new Date(now.getTime() + 10_000), ...publicNamesOn})).rejects.toBeInstanceOf(HttpsError);

    const prior = new Date("2026-08-22T10:00:00Z");
    const capped = makeStore({
      ...owned,
      "discoveryNameChanges/owner": {
        dayBucket: "2026-08-22",
        dayCount: 10,
        lastChangedAt: prior,
      },
    }).store;
    await expect(setDiscoveryPublicNameHandler(
      request({code: "ABC234", publicName: "later"}),
      {store: capped, now: () => now, ...publicNamesOn},
    )).rejects.toMatchObject({code: "resource-exhausted"});
  });

  test("denies public-name writes unless the server gate is enabled", async () => {
    const {store, docs} = makeStore(owned);
    await expect(setDiscoveryPublicNameHandler(
      request({code: "ABC234", publicName: "new name"}),
      {store},
    )).rejects.toMatchObject({code: "failed-precondition"});
    expect(docs.get("discoverableSpaces/ABC234")?.publicName).toBe("old name");
  });

  test("upserts private report with a public-name snapshot and no narrative", async () => {
    const {store, docs} = makeStore(owned);
    const result = await reportDiscoverableSpaceHandler(request({code: "ABC234", category: "impersonation"}, "reporter"), {store, now: () => new Date("2026-08-22T12:00:00Z")});
    expect(result).toEqual({reported: true});
    expect(docs.get("discoveryReports/ABC234/reporters/reporter")).toMatchObject({category: "impersonation", publicName: "old name", state: "pending", ownerKey: ownerKeyForUid("owner")});
    expect(docs.get("discoveryReports/ABC234/reporters/reporter")).not.toHaveProperty("narrative");
    await expect(reportDiscoverableSpaceHandler(request({code: "ABC234", category: "other"}, "reporter"), {store})).rejects.toMatchObject({code: "already-exists"});
  });

  test("allows a code-only report for a live public profile", async () => {
    const {store, docs} = makeStore({
      "rooms/ABC234": liveRoom("owner"),
      "publicSpaceProfiles/ABC234": liveProfile(ownerKeyForUid("owner")),
    });

    await expect(reportDiscoverableSpaceHandler(
      request({code: "ABC234", category: "other"}, "reporter"),
      {store},
    )).resolves.toEqual({reported: true});
    expect(docs.get("discoveryReports/ABC234/reporters/reporter")).toMatchObject({
      category: "other",
      publicName: null,
      ownerKey: ownerKeyForUid("owner"),
    });
  });

  test("permits a Mutuals-only report only for reciprocal, unblocked Circle choices", async () => {
    const base = {
      "rooms/ABC234": liveRoom("owner"),
      "mutualSpaceProfiles/ABC234": liveProfile(ownerKeyForUid("owner")),
      [`circleRelationships/${ownerKeyForUid("reporter")}/outgoing/${ownerKeyForUid("owner")}`]: {edge: true},
      [`circleRelationships/${ownerKeyForUid("owner")}/outgoing/${ownerKeyForUid("reporter")}`]: {edge: true},
    };
    const {store, docs} = makeStore(base);
    await expect(reportDiscoverableSpaceHandler(
      request({code: "ABC234", category: "other"}, "reporter"),
      {store},
    )).resolves.toEqual({reported: true});
    expect(docs.has("discoveryReports/ABC234/reporters/reporter")).toBe(true);

    const missingReciprocity = makeStore({...base});
    missingReciprocity.docs.delete(`circleRelationships/${ownerKeyForUid("owner")}/outgoing/${ownerKeyForUid("reporter")}`);
    await expect(reportDiscoverableSpaceHandler(
      request({code: "ABC234", category: "other"}, "reporter"),
      {store: missingReciprocity.store},
    )).rejects.toMatchObject({code: "not-found"});

    const blocked = makeStore({
      ...base,
      [`spaceBlocks/${ownerKeyForUid("owner")}/blocked/${ownerKeyForUid("reporter")}`]: {blocked: true},
    });
    await expect(reportDiscoverableSpaceHandler(
      request({code: "ABC234", category: "other"}, "reporter"),
      {store: blocked.store},
    )).rejects.toMatchObject({code: "not-found"});
  });

  test("does not accept a stale profile whose owner disagrees with its room", async () => {
    const {store, docs} = makeStore({
      "rooms/ABC234": liveRoom("owner"),
      "publicSpaceProfiles/ABC234": liveProfile(ownerKeyForUid("someone-else")),
    });
    await expect(reportDiscoverableSpaceHandler(
      request({code: "ABC234", category: "other"}, "reporter"),
      {store},
    )).rejects.toMatchObject({code: "not-found"});
    expect(docs.has("discoveryReports/ABC234/reporters/reporter")).toBe(false);
  });

  test("does not attach a stale directory name to a profile-only report", async () => {
    const {store, docs} = makeStore({
      "rooms/ABC234": liveRoom("owner"),
      "publicSpaceProfiles/ABC234": liveProfile(ownerKeyForUid("owner")),
      "discoverableSpaces/ABC234": {
        ownerKey: ownerKeyForUid("someone-else"),
        publicName: "Stale name",
      },
    });
    await reportDiscoverableSpaceHandler(
      request({code: "ABC234", category: "other"}, "reporter"),
      {store},
    );
    expect(docs.get("discoveryReports/ABC234/reporters/reporter")?.publicName).toBeNull();
  });

  test("rejects self-reports before writing a private report", async () => {
    const {store, docs} = makeStore(owned);
    await expect(reportDiscoverableSpaceHandler(request({code: "ABC234", category: "other"}, "owner"), {store})).rejects.toMatchObject({code: "failed-precondition"});
    expect(docs.has("discoveryReports/ABC234/reporters/owner")).toBe(false);
  });

  test("rejects public-name changes for banned owners", async () => {
    const {store, docs} = makeStore({
      ...owned,
      [`discoveryBans/${ownerKeyForUid("owner")}`]: {state: "active"},
    });
    await expect(setDiscoveryPublicNameHandler(request({code: "ABC234", publicName: "new name"}), {store, ...publicNamesOn})).rejects.toMatchObject({code: "permission-denied"});
    expect(docs.get("discoverableSpaces/ABC234")?.publicName).toBe("old name");
  });

  test("rate limits reports per account and caps the day", async () => {
    const now = new Date("2026-08-22T12:00:00Z");
    const {store} = makeStore({
      ...owned,
      "rooms/DEF234": liveRoom("other-owner"),
      "discoverableSpaces/DEF234": {publicName: "other", ownerKey: ownerKeyForUid("other-owner")},
    });
    await reportDiscoverableSpaceHandler(request({code: "ABC234", category: "other"}, "reporter"), {store, now: () => now});
    await expect(reportDiscoverableSpaceHandler(request({code: "DEF234", category: "impersonation"}, "reporter"), {store, now: () => new Date(now.getTime() + 10_000)})).rejects.toMatchObject({code: "resource-exhausted"});

    const capped = makeStore({
      ...owned,
      "discoveryReportLimits/reporter": {
        dayBucket: "2026-08-22",
        dayCount: 10,
        lastReportedAt: new Date("2026-08-22T10:00:00Z"),
      },
    }).store;
    await expect(reportDiscoverableSpaceHandler(request({code: "ABC234", category: "other"}, "reporter"), {store: capped, now: () => now})).rejects.toMatchObject({code: "resource-exhausted"});
  });

  test("requires auth, validates category/code, and does not report unknown rooms", async () => {
    const {store} = makeStore(owned);
    await expect(reportDiscoverableSpaceHandler({data: {code: "ABC234", category: "other"}}, {store})).rejects.toBeInstanceOf(HttpsError);
    await expect(reportDiscoverableSpaceHandler(request({code: "ABC234", category: "spam"}), {store})).rejects.toBeInstanceOf(HttpsError);
    await expect(reportDiscoverableSpaceHandler(request({code: "ABC234", category: "other"}, "reporter"), {store: makeStore().store})).rejects.toBeInstanceOf(HttpsError);
  });

  test.each([
    {uid: "owner", ownerKey: ownerKeyForUid("owner"), v: 5, profileVisible: false},
    {uid: "owner", ownerKey: ownerKeyForUid("owner"), v: 6, profileVisible: true},
  ])("does not report a legacy or profile-visible room anchor", async (room) => {
    const {store, docs} = makeStore({
      "rooms/ABC234": room,
      "discoverableSpaces/ABC234": {publicName: "old name", ownerKey: ownerKeyForUid("owner")},
      "publicSpaceProfiles/ABC234": liveProfile(ownerKeyForUid("owner")),
    });
    await expect(reportDiscoverableSpaceHandler(
      request({code: "ABC234", category: "other"}, "reporter"),
      {store},
    )).rejects.toMatchObject({code: "not-found"});
    expect(docs.has("discoveryReports/ABC234/reporters/reporter")).toBe(false);
  });
});
