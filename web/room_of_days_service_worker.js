'use strict';

const cachePrefix = 'room-of-days-shell-';
const buildVersion =
  new URL(self.location.href).searchParams.get('v') || 'development';
const cacheName = `${cachePrefix}${buildVersion.replace(/[^a-zA-Z0-9._-]/g, '-')}`;
const scopeUrl = new URL('./', self.registration.scope);
const offlineManifestUrl = new URL('offline-assets.json', scopeUrl);
// Firebase clean URLs redirects /index.html to /. Cache and return the root
// response itself so an offline navigation never receives a redirected
// Response object that Chromium refuses as a fallback document.
const offlineDocumentUrl = scopeUrl;
let deferredWarmPaused = true;
let deferredWarmPromise = null;

async function releaseManifest() {
  const manifestResponse = await fetch(offlineManifestUrl, {cache: 'no-store'});
  if (!manifestResponse.ok) {
    throw new Error(
      `Offline manifest returned HTTP ${manifestResponse.status}`,
    );
  }

  const manifest = await manifestResponse.json();
  if (
    manifest.schema !== 2 ||
    !Array.isArray(manifest.sharedAssets) ||
    !Array.isArray(manifest.deferredAssets) ||
    !manifest.rendererAssets ||
    !Array.isArray(manifest.rendererAssets.canvaskit) ||
    !Array.isArray(manifest.rendererAssets.skwasm)
  ) {
    throw new Error('Offline manifest is malformed.');
  }
  return manifest;
}

function supportsSkwasm() {
  const agent = self.navigator.userAgent || '';
  const blink =
    (/(?:Chrome|Chromium)\//.test(agent) || /Edg\//.test(agent)) &&
    !/(?:CriOS|EdgiOS|OPiOS)/.test(agent);
  if (!blink) return false;
  try {
    const wasmGcProbe = new Uint8Array([
      0, 97, 115, 109, 1, 0, 0, 0, 1, 5, 1, 95, 1, 120, 0,
    ]);
    return WebAssembly.validate(wasmGcProbe);
  } catch (_) {
    return false;
  }
}

async function cacheUrls(cache, assets, {batchSize = 4} = {}) {
  const urls = assets.map((asset) => new URL(asset, scopeUrl));

  for (let index = 0; index < urls.length; index += batchSize) {
    await Promise.all(
      urls.slice(index, index + batchSize).map(async (url) => {
        if (await cache.match(url, {ignoreSearch: true})) return;
        const response = await fetch(url, {
          cache: 'reload',
          credentials: 'same-origin',
        });
        if (!response.ok) {
          throw new Error(`${url.pathname} returned HTTP ${response.status}`);
        }
        await cache.put(url, response);
      }),
    );
  }
}

async function cacheCore() {
  const manifest = await releaseManifest();
  const renderer = supportsSkwasm() ? 'skwasm' : 'canvaskit';
  const cache = await caches.open(cacheName);
  // Cache only the runtime this browser can execute plus the first room. The
  // old installer downloaded every page, sound, and renderer while the person
  // was trying to use the first screen.
  await cacheUrls(cache, [
    ...manifest.sharedAssets,
    ...manifest.rendererAssets[renderer],
  ]);
}

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function warmDeferredCache() {
  if (deferredWarmPromise) return deferredWarmPromise;
  deferredWarmPromise = (async () => {
    const manifest = await releaseManifest();
    const cache = await caches.open(cacheName);
    for (const asset of manifest.deferredAssets) {
      if (deferredWarmPaused) return;
      const url = new URL(asset, scopeUrl);
      if (!(await cache.match(url, {ignoreSearch: true}))) {
        const response = await fetch(url, {
          cache: 'reload',
          credentials: 'same-origin',
        });
        if (response.ok) await cache.put(url, response);
      }
      // One quiet request at a time leaves input, paint, and audio in front.
      await wait(90);
    }
  })().finally(() => {
    deferredWarmPromise = null;
  });
  return deferredWarmPromise;
}

self.addEventListener('install', (event) => {
  event.waitUntil(cacheCore().then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(
        names
          .filter((name) => name.startsWith(cachePrefix) && name !== cacheName)
          .map((name) => caches.delete(name)),
      );
      await self.clients.claim();
    })(),
  );
});

function cacheKeyFor(request) {
  const url = new URL(request.url);
  url.search = '';
  url.hash = '';
  return url;
}

async function rangedResponse(request, cached) {
  const range = request.headers.get('range');
  if (!range || !cached) return cached;

  const match = /^bytes=(\d+)-(\d*)$/.exec(range);
  if (!match) return new Response(null, {status: 416});

  const bytes = await cached.arrayBuffer();
  const start = Number(match[1]);
  const requestedEnd = match[2] ? Number(match[2]) : bytes.byteLength - 1;
  const end = Math.min(requestedEnd, bytes.byteLength - 1);
  if (start >= bytes.byteLength || start > end) {
    return new Response(null, {
      status: 416,
      headers: {'Content-Range': `bytes */${bytes.byteLength}`},
    });
  }

  const headers = new Headers(cached.headers);
  headers.set('Accept-Ranges', 'bytes');
  headers.set('Content-Length', String(end - start + 1));
  headers.set('Content-Range', `bytes ${start}-${end}/${bytes.byteLength}`);
  return new Response(bytes.slice(start, end + 1), {
    status: 206,
    statusText: 'Partial Content',
    headers,
  });
}

async function cachedAsset(request) {
  const cache = await caches.open(cacheName);
  const key = cacheKeyFor(request);
  const cached = await cache.match(key, {ignoreSearch: true});
  if (cached) return rangedResponse(request, cached);

  const response = await fetch(request);
  if (response.ok && response.type === 'basic') {
    await cache.put(key, response.clone());
  }
  return response;
}

async function navigate(request) {
  const cache = await caches.open(cacheName);
  const fallback = await cache.match(offlineDocumentUrl);
  if (!self.navigator.onLine) return fallback || Response.error();
  try {
    const response = await fetch(request);
    if (response.ok) return response;
  } catch (_) {}
  return fallback || Response.error();
}

function bypassAppShell(url) {
  if (!url.pathname.startsWith(scopeUrl.pathname)) return false;
  const relativePath = url.pathname.slice(scopeUrl.pathname.length);
  return (
    relativePath === 'android' ||
    relativePath === 'android.html' ||
    relativePath === 'introduction' ||
    relativePath === 'introduction.html' ||
    relativePath.startsWith('introduction/')
  );
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== scopeUrl.origin) return;

  // These pages publish independently from the installable Flutter shell.
  // Leave their documents and assets on the network so an older app cache can
  // never replace the introduction or retain a superseded download link.
  if (bypassAppShell(url)) return;

  if (request.mode === 'navigate') {
    event.respondWith(navigate(request));
    return;
  }

  event.respondWith(cachedAsset(request));
});

self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') {
    self.skipWaiting();
  } else if (event.data === 'PAUSE_OFFLINE_CACHE') {
    deferredWarmPaused = true;
  } else if (event.data === 'WARM_OFFLINE_CACHE') {
    deferredWarmPaused = false;
    event.waitUntil(warmDeferredCache());
  }
});
