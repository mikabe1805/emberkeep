#!/usr/bin/env node

"use strict";

const {applicationDefault, initializeApp} = require("firebase-admin/app");
const {
  FieldPath,
  FieldValue,
  getFirestore,
} = require("firebase-admin/firestore");

const PROJECT_ID = "emberkeep-5b33b";
const OWNER_KEY = /^[a-f0-9]{64}$/;
const ROOM_CODE = /^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$/;

const args = process.argv.slice(2);
const projectFlag = args.shift();
if (projectFlag !== `--project=${PROJECT_ID}`) {
  fail(`Refusing to run. First argument must be --project=${PROJECT_ID}.`);
}
const command = args.shift();
if (!command) usage();

initializeApp({credential: applicationDefault(), projectId: PROJECT_ID});
const store = getFirestore();

function fail(message) {
  console.error(message);
  process.exit(64);
}

function usage() {
  fail([
    "Usage:",
    `  node scripts/discovery-moderation.cjs --project=${PROJECT_ID} list`,
    `  node scripts/discovery-moderation.cjs --project=${PROJECT_ID} dismiss CODE REPORTER_UID`,
    `  node scripts/discovery-moderation.cjs --project=${PROJECT_ID} clear-name CODE REPORTER_UID`,
    `  node scripts/discovery-moderation.cjs --project=${PROJECT_ID} ban OWNER_KEY CODE REPORTER_UID REASON_CODE`,
    `  node scripts/discovery-moderation.cjs --project=${PROJECT_ID} unban OWNER_KEY`,
    `  node scripts/discovery-moderation.cjs --project=${PROJECT_ID} pause-names`,
  ].join("\n"));
}

function code(value) {
  if (!ROOM_CODE.test(value ?? "")) fail("CODE must be a valid Room of Days room code.");
  return value;
}

function ownerKey(value) {
  if (!OWNER_KEY.test(value ?? "")) fail("OWNER_KEY must be 64 lowercase hex characters.");
  return value;
}

function reporter(value) {
  if (!value || value.includes("/") || value.length > 256) fail("REPORTER_UID is invalid.");
  return value;
}

function reportRef(roomCode, reporterUid) {
  return store.doc(`discoveryReports/${code(roomCode)}/reporters/${reporter(reporterUid)}`);
}

async function list() {
  const snapshot = await store.collectionGroup("reporters")
    .where("state", "==", "pending")
    .limit(100)
    .get();
  if (snapshot.empty) {
    console.log("No pending discovery reports.");
    return;
  }
  const pending = [...snapshot.docs].sort((first, second) => {
    const firstTime = first.data().clientReportedAt?.toMillis?.() ?? 0;
    const secondTime = second.data().clientReportedAt?.toMillis?.() ?? 0;
    return firstTime - secondTime;
  });
  for (const document of pending) {
    const data = document.data();
    const roomCode = document.ref.parent.parent?.id ?? "UNKNOWN";
    console.log(JSON.stringify({
      path: document.ref.path,
      roomCode,
      category: data.category,
      publicName: data.publicName,
      ownerKey: data.ownerKey,
      reportedAt: data.clientReportedAt?.toDate?.().toISOString?.() ?? null,
    }));
  }
}

async function resolve(roomCode, reporterUid, resolution) {
  await reportRef(roomCode, reporterUid).update({
    state: "resolved",
    resolution,
    resolvedAt: FieldValue.serverTimestamp(),
  });
  console.log(`Resolved ${roomCode}/${reporterUid}: ${resolution}.`);
}

async function clearName(roomCode, reporterUid) {
  const batch = store.batch();
  batch.update(store.doc(`discoverableSpaces/${code(roomCode)}`), {
    publicName: "",
  });
  batch.update(reportRef(roomCode, reporterUid), {
    state: "resolved",
    resolution: "public_name_cleared",
    resolvedAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  console.log(`Cleared the public name and resolved ${roomCode}/${reporterUid}.`);
}

async function ban(key, roomCode, reporterUid, reasonCode) {
  ownerKey(key);
  code(roomCode);
  reporter(reporterUid);
  if (!/^[a-z0-9_]{3,40}$/.test(reasonCode ?? "")) {
    fail("REASON_CODE must use 3-40 lowercase letters, digits, or underscores.");
  }
  const batch = store.batch();
  batch.set(store.doc(`discoveryBans/${key}`), {
    state: "active",
    reasonCode,
    createdAt: FieldValue.serverTimestamp(),
  });
  batch.delete(store.doc(`discoverableSpaces/${roomCode}`));
  batch.update(reportRef(roomCode, reporterUid), {
    state: "resolved",
    resolution: "keeper_banned",
    reasonCode,
    resolvedAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  console.log(`Banned ${key}, removed ${roomCode}, and resolved the report.`);
}

async function unban(key) {
  await store.doc(`discoveryBans/${ownerKey(key)}`).delete();
  console.log(`Unbanned ${key}. No room was relisted automatically.`);
}

async function pauseNames() {
  let changed = 0;
  let cursor;
  for (;;) {
    let query = store.collection("discoverableSpaces")
      .orderBy(FieldPath.documentId())
      .limit(400);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) break;
    const batch = store.batch();
    let writes = 0;
    for (const document of snapshot.docs) {
      if (document.data().publicName) {
        batch.update(document.ref, {publicName: ""});
        changed += 1;
        writes += 1;
      }
    }
    if (writes > 0) await batch.commit();
    cursor = snapshot.docs.at(-1);
    if (snapshot.size < 400) break;
  }
  console.log(`Cleared ${changed} public names. Also set DISCOVERY_PUBLIC_NAMES_ENABLED=false and redeploy setDiscoveryPublicName before leaving moderation unattended.`);
}

(async () => {
  switch (command) {
    case "list":
      if (args.length) usage();
      await list();
      break;
    case "dismiss":
      if (args.length !== 2) usage();
      await resolve(args[0], args[1], "no_violation");
      break;
    case "clear-name":
      if (args.length !== 2) usage();
      await clearName(args[0], args[1]);
      break;
    case "ban":
      if (args.length !== 4) usage();
      await ban(args[0], args[1], args[2], args[3]);
      break;
    case "unban":
      if (args.length !== 1) usage();
      await unban(args[0]);
      break;
    case "pause-names":
      if (args.length) usage();
      await pauseNames();
      break;
    default:
      usage();
  }
})().catch((error) => {
  console.error(error?.stack ?? error);
  process.exitCode = 1;
});
