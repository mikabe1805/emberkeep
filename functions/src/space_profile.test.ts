import {HttpsError} from "firebase-functions/v2/https";

import {
  ownerKeyForSpaceUid,
  publishSpaceProfileHandler,
  setCircleRelationshipHandler,
  setSpaceBlockHandler,
  type SpaceProfileStore,
} from "./space_profile";

type Doc = Record<string, unknown>;

const makeStore = (initial: Record<string, Doc> = {}) => {
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
  const store: SpaceProfileStore = {
    collection(path) {
      return {doc: (id: string) => ({
        async get() {
          const value = docs.get(key(path, id));
          return {exists: value !== undefined, data: () => value};
        },
      })};
    },
    async runTransaction(fn) {
      return fn({
        async get(ref) { return ref.get(); },
        set(ref, data) {
          const target = ref as unknown as {path?: string};
          // The test reference keeps its identity in the closure below; store
          // writes are intercepted by the transaction adapter instead.
          void target;
          const match = [...refs.entries()].find(([, candidate]) => candidate === ref);
          if (match !== undefined) docs.set(match[0], data);
        },
        delete(ref) {
          const match = [...refs.entries()].find(([, candidate]) => candidate === ref);
          if (match !== undefined) docs.delete(match[0]);
        },
      });
    },
  };
  const refs = new Map<string, object>();
  const original = store.collection.bind(store);
  store.collection = (path) => ({doc: (id: string) => {
    const document = original(path).doc(id);
    refs.set(key(path, id), document);
    return document;
  }});
  return {store, docs};
};

const ownerRoom = {
  uid: "owner",
  ownerKey: ownerKeyForSpaceUid("owner"),
  v: 6,
  profileVisible: false,
  updatedAt: new Date("2026-08-24T12:00:00.000Z"),
};
const visitorRoom = {
  uid: "visitor",
  ownerKey: ownerKeyForSpaceUid("visitor"),
  v: 6,
  profileVisible: false,
  updatedAt: new Date("2026-08-24T12:00:00.000Z"),
};
const profile = (overrides: Record<string, unknown> = {}) => ({
  displayName: "Mika",
  cardOrder: ["about", "rightNow"],
  about: "Building a life with more room in it.",
  featuredGoals: ["Finish my lab report"],
  pinnedMoments: [],
  season: "",
  ...overrides,
});
const request = (data: unknown, uid = "owner") => ({data, auth: {uid}});

describe("space profile callables", () => {
  test("publishes isolated public and full mutual projections atomically", async () => {
    const {store, docs} = makeStore({"rooms/ABC234": ownerRoom});
    const publicProfile = profile({cardOrder: ["about"], featuredGoals: []});
    const mutualProfile = profile({
      cardOrder: ["about", "rightNow", "pinnedMoments"],
      pinnedMoments: [{text: "I made it through a hard week.", at: 1724000000000}],
    });

    await expect(publishSpaceProfileHandler(request({code: "ABC234", publicProfile, mutualProfile}), {store}))
      .resolves.toEqual({published: true, publicProfile: true, mutualProfile: true});
    expect(docs.get("publicSpaceProfiles/ABC234")).toMatchObject({
      v: 2, ownerKey: ownerKeyForSpaceUid("owner"),
      roomUpdatedAt: ownerRoom.updatedAt, ...publicProfile,
    });
    expect(docs.get("mutualSpaceProfiles/ABC234")).toMatchObject({
      v: 2, ownerKey: ownerKeyForSpaceUid("owner"),
      roomUpdatedAt: ownerRoom.updatedAt, ...mutualProfile,
    });
  });

  test("deleting both profiles leaves Only me content nowhere in Firestore", async () => {
    const {store, docs} = makeStore({
      "rooms/ABC234": ownerRoom,
      "publicSpaceProfiles/ABC234": {old: true},
      "mutualSpaceProfiles/ABC234": {old: true},
    });
    await expect(publishSpaceProfileHandler(request({code: "ABC234", publicProfile: null, mutualProfile: null}), {store}))
      .resolves.toEqual({published: true, publicProfile: false, mutualProfile: false});
    expect(docs.has("publicSpaceProfiles/ABC234")).toBe(false);
    expect(docs.has("mutualSpaceProfiles/ABC234")).toBe(false);
  });

  test.each([
    profile({about: "Find me at https://example.com"}),
    profile({featuredGoals: ["message me on discord"]}),
    profile({about: "this is shit"}),
    profile({cardOrder: ["about", "about"]}),
    profile({cardOrder: [], about: "Should not be present"}),
    profile({cardOrder: [], about: "", featuredGoals: [], displayName: "Bare identity"}),
    {...profile(), untrustedField: "no"},
  ])("rejects unsafe or malformed authored content", async (unsafe) => {
    const {store} = makeStore({"rooms/ABC234": ownerRoom});
    await expect(publishSpaceProfileHandler(request({code: "ABC234", publicProfile: null, mutualProfile: unsafe}), {store}))
      .rejects.toBeInstanceOf(HttpsError);
  });

  test("requires mutual projection to retain every public card unchanged", async () => {
    const {store} = makeStore({"rooms/ABC234": ownerRoom});
    await expect(publishSpaceProfileHandler(request({
      code: "ABC234",
      publicProfile: profile({cardOrder: ["about"], featuredGoals: []}),
      mutualProfile: profile({cardOrder: ["about"], featuredGoals: [], about: "Different"}),
    }), {store})).rejects.toBeInstanceOf(HttpsError);
  });

  test("allows an anonymous Anyone projection to keep a Mutuals-only name", async () => {
    const {store, docs} = makeStore({"rooms/ABC234": ownerRoom});
    const publicProfile = profile({displayName: "", cardOrder: [], about: "", featuredGoals: []});
    const mutualProfile = profile();

    await expect(publishSpaceProfileHandler(request({code: "ABC234", publicProfile, mutualProfile}), {store}))
      .resolves.toEqual({published: true, publicProfile: true, mutualProfile: true});
    expect(docs.get("publicSpaceProfiles/ABC234")?.displayName).toBe("");
    expect(docs.get("mutualSpaceProfiles/ABC234")?.displayName).toBe("Mika");
  });

  test("rejects profile publishing from another person or a non-v5 room", async () => {
    const intruder = makeStore({"rooms/ABC234": ownerRoom});
    await expect(publishSpaceProfileHandler(request({code: "ABC234", publicProfile: null, mutualProfile: profile()}, "intruder"), {store: intruder.store}))
      .rejects.toMatchObject({code: "permission-denied"});
    const legacy = makeStore({"rooms/ABC234": {uid: "owner", v: 4, profileVisible: true}});
    await expect(publishSpaceProfileHandler(request({code: "ABC234", publicProfile: null, mutualProfile: profile()}), {store: legacy.store}))
      .rejects.toMatchObject({code: "permission-denied"});
  });

  test("records only a caller-owned directed Circle edge and verifies supplied owner key", async () => {
    const {store, docs} = makeStore({"rooms/ABC234": visitorRoom});
    const key = ownerKeyForSpaceUid("visitor");
    await expect(setCircleRelationshipHandler(request({code: "ABC234", ownerKey: key, active: true}), {store}))
      .resolves.toEqual({active: true, ownerKey: key});
    expect(docs.get(`circleRelationships/${ownerKeyForSpaceUid("owner")}/outgoing/${key}`)).toMatchObject({ownerKey: key});
    await expect(setCircleRelationshipHandler(request({code: "ABC234", ownerKey: ownerKeyForSpaceUid("wrong"), active: true}), {store}))
      .rejects.toMatchObject({code: "failed-precondition"});
    await setCircleRelationshipHandler(request({code: "ABC234", active: false}), {store});
    expect(docs.has(`circleRelationships/${ownerKeyForSpaceUid("owner")}/outgoing/${key}`)).toBe(false);
  });

  test("revokes a Circle choice by supplied owner key after a room disappears", async () => {
    const key = ownerKeyForSpaceUid("visitor");
    const {store, docs} = makeStore({
      [`circleRelationships/${ownerKeyForSpaceUid("owner")}/outgoing/${key}`]: {ownerKey: key},
    });

    await expect(setCircleRelationshipHandler(
      request({code: "ABC234", ownerKey: key, active: false}),
      {store},
    )).resolves.toEqual({active: false, ownerKey: key});
    expect(docs.has(`circleRelationships/${ownerKeyForSpaceUid("owner")}/outgoing/${key}`)).toBe(false);
    await expect(setCircleRelationshipHandler(
      request({code: "ABC234", ownerKey: key, active: true}),
      {store},
    )).rejects.toMatchObject({code: "not-found"});
  });

  test("blocking deletes the caller's edge and unblocking does not restore it", async () => {
    const {store, docs} = makeStore({
      "rooms/ABC234": visitorRoom,
      [`circleRelationships/${ownerKeyForSpaceUid("owner")}/outgoing/${ownerKeyForSpaceUid("visitor")}`]: {ownerKey: ownerKeyForSpaceUid("visitor")},
    });
    const key = ownerKeyForSpaceUid("visitor");
    await expect(setSpaceBlockHandler(
      request({code: "ABC234", ownerKey: ownerKeyForSpaceUid("wrong"), blocked: true}),
      {store},
    )).rejects.toMatchObject({code: "failed-precondition"});
    await expect(setSpaceBlockHandler(request({code: "ABC234", ownerKey: key, blocked: true}), {store}))
      .resolves.toEqual({blocked: true, ownerKey: key});
    expect(docs.has(`circleRelationships/${ownerKeyForSpaceUid("owner")}/outgoing/${key}`)).toBe(false);
    expect(docs.get(`spaceBlocks/${ownerKeyForSpaceUid("owner")}/blocked/${key}`)).toMatchObject({ownerKey: key});
    await setSpaceBlockHandler(request({code: "ABC234", blocked: false}), {store});
    expect(docs.has(`spaceBlocks/${ownerKeyForSpaceUid("owner")}/blocked/${key}`)).toBe(false);
    expect(docs.has(`circleRelationships/owner/outgoing/${key}`)).toBe(false);
  });

  test("revokes a block by supplied owner key after a room disappears", async () => {
    const key = ownerKeyForSpaceUid("visitor");
    const {store, docs} = makeStore({
      [`spaceBlocks/${ownerKeyForSpaceUid("owner")}/blocked/${key}`]: {ownerKey: key},
    });

    await expect(setSpaceBlockHandler(
      request({code: "ABC234", ownerKey: key, blocked: false}),
      {store},
    )).resolves.toEqual({blocked: false, ownerKey: key});
    expect(docs.has(`spaceBlocks/${ownerKeyForSpaceUid("owner")}/blocked/${key}`)).toBe(false);
    await expect(setSpaceBlockHandler(
      request({code: "ABC234", ownerKey: key, blocked: true}),
      {store},
    )).rejects.toMatchObject({code: "not-found"});
  });
});
