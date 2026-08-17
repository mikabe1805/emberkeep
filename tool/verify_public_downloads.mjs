#!/usr/bin/env node

import {createHash} from "node:crypto";
import {createReadStream} from "node:fs";
import {readFile, stat} from "node:fs/promises";
import path from "node:path";
import {fileURLToPath} from "node:url";

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const marketingRoot = path.resolve(appRoot, "..", "marketing_site");
const expectedAndroidRoute = "https://roomofdays.com/android";

function fail(message) {
  throw new Error(`Public download verification failed: ${message}`);
}

async function sha256(file) {
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(file)) hash.update(chunk);
  return hash.digest("hex");
}

async function checkedFetch(url, options = {}) {
  const response = await fetch(url, {
    redirect: "follow",
    signal: AbortSignal.timeout(20_000),
    ...options,
  });
  if (!response.ok) fail(`${url} returned HTTP ${response.status}`);
  return response;
}

function releaseParts(downloadUrl) {
  const parsed = new URL(downloadUrl);
  const match = /^\/([^/]+)\/([^/]+)\/releases\/download\/([^/]+)\/([^/]+)$/.exec(
    parsed.pathname,
  );
  if (parsed.hostname !== "github.com" || !match) {
    fail(`Android href is not a direct GitHub release asset: ${downloadUrl}`);
  }
  return {
    owner: decodeURIComponent(match[1]),
    repo: decodeURIComponent(match[2]),
    tag: decodeURIComponent(match[3]),
    assetName: decodeURIComponent(match[4]),
  };
}

const candidate = JSON.parse(
  await readFile(path.join(appRoot, "release-candidate.json"), "utf8"),
);
const androidPage = await readFile(path.join(appRoot, "web", "android.html"), "utf8");
const marketingSource = await readFile(
  path.join(marketingRoot, "src", "App.jsx"),
  "utf8",
);

const androidLinks = [
  ...new Set(
    [...androidPage.matchAll(/href="(https:\/\/github\.com\/[^"\s]+\.apk)"/g)].map(
      (match) => match[1],
    ),
  ),
];
if (androidLinks.length !== 1) {
  fail(`expected one Android release href, found ${androidLinks.length}`);
}
if (!marketingSource.includes(`const ANDROID_URL = "${expectedAndroidRoute}";`)) {
  fail(`introduction must link Android downloads through ${expectedAndroidRoute}`);
}

const downloadUrl = androidLinks[0];
const {owner, repo, tag, assetName} = releaseParts(downloadUrl);
const localApk = path.resolve(appRoot, candidate.apk.path);
const expectedDigest = String(candidate.apk.sha256).toLowerCase();
const expectedSize = Number(candidate.apk.size);
if (!Number.isSafeInteger(expectedSize) || expectedSize <= 0) {
  fail("release-candidate.json is missing the APK byte length");
}
try {
  const localStat = await stat(localApk);
  if (localStat.size !== expectedSize) fail("local APK has the wrong byte length");
  const localDigest = await sha256(localApk);
  if (localDigest !== expectedDigest) {
    fail("local APK does not match release-candidate.json");
  }
} catch (error) {
  // A hosting checkout does not need to carry the 79 MB signed artifact. The
  // public GitHub size and digest below remain mandatory either way.
  if (error?.code !== "ENOENT") throw error;
}

const githubHeaders = {
  Accept: "application/vnd.github+json",
  "User-Agent": "room-of-days-release-verifier",
  "X-GitHub-Api-Version": "2022-11-28",
};
if (process.env.GITHUB_TOKEN) {
  githubHeaders.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
}
const release = await (
  await checkedFetch(
    `https://api.github.com/repos/${owner}/${repo}/releases/tags/${encodeURIComponent(tag)}`,
    {headers: githubHeaders},
  )
).json();
const asset = release.assets?.find((entry) => entry.name === assetName);
if (!asset) fail(`${tag} does not contain ${assetName}`);
if (asset.state !== "uploaded") fail(`${assetName} is not fully uploaded`);
if (Number(asset.size) !== expectedSize) fail(`${assetName} has the wrong byte length`);
if (String(asset.digest).toLowerCase() !== `sha256:${expectedDigest}`) {
  fail(`${assetName} has the wrong GitHub digest`);
}
const direct = await checkedFetch(downloadUrl, {method: "HEAD"});
const publicLength = Number(direct.headers.get("content-length"));
if (publicLength && publicLength !== expectedSize) {
  fail(`${assetName} serves the wrong byte length`);
}

const testFlightMatch = /const TESTFLIGHT_URL = "([^"]+)";/.exec(marketingSource);
const iosUrl = process.env.VITE_APP_STORE_URL?.trim() || testFlightMatch?.[1];
if (!iosUrl) fail("no iOS App Store or TestFlight URL is configured");
await checkedFetch(iosUrl, {method: "HEAD"});

console.log(`PASS: Android ${candidate.versionName}+${candidate.versionCode} is public and exact.`);
console.log(`PASS: ${expectedAndroidRoute} is the introduction's Android route.`);
console.log(`PASS: iOS download route is available at ${iosUrl}.`);
