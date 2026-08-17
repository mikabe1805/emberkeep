#!/usr/bin/env node
// Builds the Room of Days marketing page and overlays it into build/web so a
// normal `firebase deploy` carries /introduction with it.
//
// Before this existed, /introduction was applied by cloning the live Hosting
// version and overlaying 25 files by hand. Any plain deploy from app/ published
// a fresh version built only from build/web and silently erased the page — and
// because firebase.json rewrites "**" to /index.html, the dead route answered
// HTTP 200 with the Flutter shell instead of 404ing. It is a build output now
// so it cannot drift out of a release again.
//
// Runs LAST in the firebase.json predeploy chain, after prepare_web_offline.dart,
// so these files never enter the app's offline manifest. prepare_web_offline.dart
// also excludes them defensively.

import { execFileSync } from "node:child_process";
import { cpSync, existsSync, mkdirSync, copyFileSync, rmSync, readdirSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const siteRoot = path.resolve(appRoot, "..", "marketing_site");
const buildWeb = path.join(appRoot, "build", "web");
const built = path.join(siteRoot, "dist", "client");
const target = path.join(buildWeb, "introduction");

const skip = process.argv.includes("--skip-build");

function fail(message) {
  console.error(`\noverlay_introduction: ${message}\n`);
  process.exit(1);
}

if (!existsSync(siteRoot)) fail(`marketing_site not found at ${siteRoot}`);
if (!existsSync(buildWeb)) fail(`${buildWeb} is missing — run the Flutter web build first.`);

if (skip) {
  console.log("overlay_introduction: --skip-build, reusing marketing_site/dist/client");
} else {
  if (!existsSync(path.join(siteRoot, "node_modules"))) {
    fail(
      `marketing_site/node_modules is missing. Run "npm install" in marketing_site,\n` +
      `  or re-run with --skip-build to reuse the existing dist/client.`,
    );
  }
  console.log("overlay_introduction: building marketing_site (base=/introduction/)...");
  // Runs marketing_site's "build:introduction" script, which is
  // `vite build --base=/introduction/ && node scripts/prepare-sites-build.mjs`.
  // Keep invoking it by name so the build flags stay defined in one place.
  //
  // shell:true is required on Windows: since the CVE-2024-27980 fix, Node
  // refuses to spawn npm.cmd without a shell and fails with EINVAL. The
  // arguments are constant, so there is nothing for a shell to interpolate.
  execFileSync("npm", ["run", "build:introduction"], {
    cwd: siteRoot,
    stdio: "inherit",
    windowsHide: true,
    shell: true,
  });
}

const indexHtml = path.join(built, "index.html");
if (!existsSync(indexHtml)) fail(`expected ${indexHtml} after the build; it is missing.`);

// The page is only correct when Vite emitted it with the /introduction/ base.
// A stray `npm run build` (base "/") would produce a page whose asset URLs
// resolve against the Flutter root and 200 back the app shell — the exact
// silent failure this script exists to prevent.
const { readFileSync } = await import("node:fs");
const html = readFileSync(indexHtml, "utf8");
if (!html.includes('"/introduction/assets/') && !html.includes("'/introduction/assets/")) {
  fail(
    `marketing_site/dist/client/index.html does not reference /introduction/assets/.\n` +
    `  It was built with the wrong --base. Use "npm run build:introduction".`,
  );
}

rmSync(target, { recursive: true, force: true });
mkdirSync(target, { recursive: true });
cpSync(built, target, { recursive: true });

// Serve the clean /introduction URL too. firebase.json sets cleanUrls, so
// /introduction resolves to /introduction.html and /introduction/ resolves to
// /introduction/index.html; ship both so either form works.
copyFileSync(indexHtml, path.join(buildWeb, "introduction.html"));

let count = 0;
let bytes = 0;
const walk = (dir) => {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const absolute = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(absolute);
    else if (entry.isFile()) {
      count += 1;
      bytes += statSync(absolute).size;
    }
  }
};
walk(target);

console.log(
  `overlay_introduction: staged ${count + 1} files ` +
  `(${(bytes / (1024 * 1024)).toFixed(2)} MiB) into build/web/introduction + introduction.html`,
);
