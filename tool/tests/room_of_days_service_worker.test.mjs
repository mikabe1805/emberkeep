import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const scope = 'https://preview.example/';
const workerSource = readFileSync(
  new URL('../../web/room_of_days_service_worker.js', import.meta.url),
  'utf8',
);

// Node's constructed Response has type "default". Service-worker fetches for
// same-origin files expose type "basic", which is the worker's cacheability
// condition, so model that browser response explicitly.
function basicResponse(body, {status = 200, headers = {}} = {}) {
  const responseHeaders = new Headers(headers);
  return {
    ok: status >= 200 && status < 300,
    status,
    statusText: '',
    type: 'basic',
    headers: responseHeaders,
    clone() {
      return basicResponse(body, {status, headers: responseHeaders});
    },
    async text() {
      return body;
    },
    async arrayBuffer() {
      return new TextEncoder().encode(body).buffer;
    },
  };
}

function cacheKey(value) {
  const url = new URL(value instanceof Request ? value.url : value);
  return `${url.origin}${url.pathname}`;
}

function makeWorker() {
  const handlers = new Map();
  const stores = new Map();
  const requests = [];
  let cachePut = async () => {};
  let network = async (request) =>
    basicResponse(`network:${new URL(request.url).pathname}`);

  const caches = {
    async open(name) {
      let entries = stores.get(name);
      if (!entries) {
        entries = new Map();
        stores.set(name, entries);
      }
      return {
        async match(request) {
          const response = entries.get(cacheKey(request));
          return response?.clone();
        },
        async put(request, response) {
          await cachePut(request, response);
          entries.set(cacheKey(request), response.clone());
        },
      };
    },
    async keys() {
      return [...stores.keys()];
    },
    async delete(name) {
      return stores.delete(name);
    },
  };

  const self = {
    location: {href: `${scope}room_of_days_service_worker.js?v=test`},
    registration: {scope},
    navigator: {onLine: true, userAgent: 'Node'},
    clients: {claim: async () => {}},
    skipWaiting: async () => {},
    addEventListener(name, callback) {
      handlers.set(name, callback);
    },
  };
  const context = vm.createContext({
    URL,
    Request,
    Response,
    Headers,
    Promise,
    RegExp,
    Uint8Array,
    WebAssembly,
    setTimeout,
    clearTimeout,
    caches,
    self,
    fetch: async (request, options) => {
      requests.push({url: request.url, options});
      return network(request, options);
    },
  });
  vm.runInContext(workerSource, context, {
    filename: 'room_of_days_service_worker.js',
  });

  async function seed(path, body, options) {
    const cache = await caches.open('room-of-days-shell-test');
    await cache.put(
      new Request(`${scope}${path}`),
      basicResponse(body, options),
    );
  }

  async function cached(path) {
    const cache = await caches.open('room-of-days-shell-test');
    const response = await cache.match(new Request(`${scope}${path}`));
    return response?.text();
  }

  async function dispatch(path, options) {
    let response;
    handlers.get('fetch')({
      request: new Request(`${scope}${path}`, options),
      respondWith(value) {
        response = Promise.resolve(value);
      },
    });
    assert.ok(response, `fetch handler did not claim ${path}`);
    return response;
  }

  return {
    cached,
    dispatch,
    requests,
    seed,
    setNetwork(handler) {
      network = handler;
    },
    setCachePut(handler) {
      cachePut = handler;
    },
  };
}

test('refreshes a cached bootstrap online and preserves it for offline fallback', async () => {
  const worker = makeWorker();
  await worker.seed('flutter_bootstrap.js', 'old bootstrap');
  worker.setNetwork(async () => basicResponse('current bootstrap'));

  const online = await worker.dispatch('flutter_bootstrap.js?release=next');
  assert.equal(await online.text(), 'current bootstrap');
  assert.equal(worker.requests.length, 1);
  assert.equal(
    worker.requests[0].url,
    `${scope}flutter_bootstrap.js?release=next`,
  );
  assert.equal(worker.requests[0].options.cache, 'no-store');
  assert.equal(await worker.cached('flutter_bootstrap.js'), 'current bootstrap');

  worker.setNetwork(async () => {
    throw new Error('offline');
  });
  const offline = await worker.dispatch('flutter_bootstrap.js');
  assert.equal(await offline.text(), 'current bootstrap');
});

test('refreshes the wasm app entry but leaves ordinary assets cache-first', async () => {
  const worker = makeWorker();
  await worker.seed('main.dart.wasm', 'old wasm');
  await worker.seed('assets/pages/room.webp', 'cached illustration');
  worker.setNetwork(async (request) =>
    basicResponse(`current:${new URL(request.url).pathname}`),
  );

  const wasm = await worker.dispatch('main.dart.wasm');
  assert.equal(await wasm.text(), 'current:/main.dart.wasm');
  assert.equal(await worker.cached('main.dart.wasm'), 'current:/main.dart.wasm');

  const illustration = await worker.dispatch('assets/pages/room.webp');
  assert.equal(await illustration.text(), 'cached illustration');
  assert.equal(worker.requests.length, 1);
});

test('returns a fresh entrypoint when updating its offline cache fails', async () => {
  const worker = makeWorker();
  await worker.seed('flutter_bootstrap.js', 'old bootstrap');
  worker.setNetwork(async () => basicResponse('current bootstrap'));
  worker.setCachePut(async () => {
    throw new Error('quota exceeded');
  });

  const response = await worker.dispatch('flutter_bootstrap.js');
  assert.equal(await response.text(), 'current bootstrap');
  assert.equal(await worker.cached('flutter_bootstrap.js'), 'old bootstrap');
});

test('returns a complete cached audio response to a no-cors Range request', async () => {
  const worker = makeWorker();
  await worker.seed('assets/sfx/room/ordinary/navigate/1.wav', 'abcdef', {
    headers: {
      'Content-Length': '6',
      'Content-Type': 'audio/wav',
    },
  });

  const response = await worker.dispatch(
    'assets/sfx/room/ordinary/navigate/1.wav',
    {
      mode: 'no-cors',
      headers: {Range: 'bytes=1-3'},
    },
  );

  assert.equal(response.type, 'basic');
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Content-Range'), null);
  assert.equal(await response.text(), 'abcdef');
  assert.equal(worker.requests.length, 0);
});

test('returns a synthesized partial response to a cached same-origin Range request', async () => {
  const worker = makeWorker();
  await worker.seed('assets/sfx/room/ordinary/navigate/1.wav', 'abcdef', {
    headers: {'Content-Type': 'audio/wav'},
  });

  const response = await worker.dispatch(
    'assets/sfx/room/ordinary/navigate/1.wav',
    {headers: {Range: 'bytes=1-3'}},
  );

  assert.equal(response.status, 206);
  assert.equal(response.headers.get('Accept-Ranges'), 'bytes');
  assert.equal(response.headers.get('Content-Length'), '3');
  assert.equal(response.headers.get('Content-Range'), 'bytes 1-3/6');
  assert.equal(await response.text(), 'bcd');
  assert.equal(worker.requests.length, 0);
});

test('passes through a cold network Range response without caching its partial body', async () => {
  const worker = makeWorker();
  worker.setNetwork(async () =>
    basicResponse('bcd', {
      status: 206,
      headers: {
        'Content-Length': '3',
        'Content-Range': 'bytes 1-3/6',
        'Content-Type': 'audio/wav',
      },
    }),
  );

  const path = 'assets/sfx/room/ordinary/navigate/1.wav';
  const response = await worker.dispatch(path, {
    headers: {Range: 'bytes=1-3'},
  });

  assert.equal(response.status, 206);
  assert.equal(await response.text(), 'bcd');
  assert.equal(worker.requests.length, 1);
  assert.equal(await worker.cached(path), undefined);
});
