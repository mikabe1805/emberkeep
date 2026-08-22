import {HttpsError} from "firebase-functions/v2/https";

import {
  reportDiscoverableSpaceHandler,
  setDiscoveryPublicNameHandler,
  type DiscoveryStore,
} from "./discovery";

type AnyDoc = Record<string, unknown>;
const makeStore = (initial: Record<string, AnyDoc> = {}) => {
  const docs = new Map(Object.entries(initial));
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
  "rooms/ABC234": {uid: "owner", secret: "preserve"},
  "discoverableSpaces/ABC234": {publicName: "old name", theme: "walnut"},
};

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
    const missing = makeStore({"rooms/ABC234": {uid: "owner"}}).store;
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
    expect(docs.get("discoveryReports/ABC234/reporters/reporter")).toMatchObject({category: "impersonation", publicName: "old name", state: "pending"});
    expect(docs.get("discoveryReports/ABC234/reporters/reporter")).not.toHaveProperty("narrative");
  });

  test("rejects self-reports before writing a private report", async () => {
    const {store, docs} = makeStore(owned);
    await expect(reportDiscoverableSpaceHandler(request({code: "ABC234", category: "other"}, "owner"), {store})).rejects.toMatchObject({code: "failed-precondition"});
    expect(docs.has("discoveryReports/ABC234/reporters/owner")).toBe(false);
  });

  test("rate limits reports per account and caps the day", async () => {
    const now = new Date("2026-08-22T12:00:00Z");
    const {store} = makeStore(owned);
    await reportDiscoverableSpaceHandler(request({code: "ABC234", category: "other"}, "reporter"), {store, now: () => now});
    await expect(reportDiscoverableSpaceHandler(request({code: "ABC234", category: "impersonation"}, "reporter"), {store, now: () => new Date(now.getTime() + 10_000)})).rejects.toMatchObject({code: "resource-exhausted"});

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
});
