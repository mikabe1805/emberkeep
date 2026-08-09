'use strict';

const cachePrefix = 'room-of-days-shell-';
const buildVersion =
  new URL(self.location.href).searchParams.get('v') || 'development';
const cacheName = `${cachePrefix}${buildVersion.replace(/[^a-zA-Z0-9._-]/g, '-')}`;
const scopeUrl = new URL('./', self.registration.scope);
const offlineManifestUrl = new URL('offline-assets.json', scopeUrl);
const offlineDocumentUrl = new URL('index.html', scopeUrl);

async function cacheRelease() {
  const manifestResponse = await fetch(offlineManifestUrl, {cache: 'no-store'});
  if (!manifestResponse.ok) {
    throw new Error(
      `Offline manifest returned HTTP ${manifestResponse.status}`,
    );
  }

  const manifest = await manifestResponse.json();
  if (manifest.schema !== 1 || !Array.isArray(manifest.assets)) {
    throw new Error('Offline manifest is malformed.');
  }

  const cache = await caches.open(cacheName);
  const urls = manifest.assets.map((asset) => new URL(asset, scopeUrl));

  // A bounded batch keeps low-memory mobile browsers from fetching the whole
  // illustrated app in one burst while still making install atomic: any failed
  // response rejects installation instead of claiming an incomplete cache.
  for (let index = 0; index < urls.length; index += 8) {
    await Promise.all(
      urls.slice(index, index + 8).map(async (url) => {
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

self.addEventListener('install', (event) => {
  event.waitUntil(cacheRelease().then(() => self.skipWaiting()));
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
  try {
    return await fetch(request);
  } catch (_) {
    const cache = await caches.open(cacheName);
    return (await cache.match(offlineDocumentUrl)) || Response.error();
  }
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== scopeUrl.origin) return;

  if (request.mode === 'navigate') {
    event.respondWith(navigate(request));
    return;
  }

  event.respondWith(cachedAsset(request));
});

self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') self.skipWaiting();
});
