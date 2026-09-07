import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const helper = readFileSync(
  new URL('../preview/refresh-working-preview-20260906.html', import.meta.url),
  'utf8',
);
const script = /<script>\s*([\s\S]*?)<\/script>/.exec(helper)?.[1];
assert.ok(script, 'preview refresh helper must contain an inline script');

function registration({scope = 'http://127.0.0.1:8393/', scriptURL, unregister = true}) {
  let calls = 0;
  return {
    scope,
    active: scriptURL ? {scriptURL} : null,
    waiting: null,
    installing: null,
    async unregister() {
      calls += 1;
      return unregister;
    },
    get calls() {
      return calls;
    },
  };
}

async function run({
  hostname = '127.0.0.1',
  port = '8393',
  registrations = [],
  cacheNames = [],
  deleteCache = () => true,
} = {}) {
  const deletedCaches = [];
  let registrationsRead = 0;
  let redirect;
  const heading = {textContent: 'Opening the updated Goals…'};
  const status = {textContent: 'Refreshing this local preview.'};
  const origin = `http://${hostname}${port ? `:${port}` : ''}`;
  const caches = {
    async keys() {
      return [...cacheNames];
    },
    async delete(name) {
      deletedCaches.push(name);
      return deleteCache(name);
    },
  };
  const location = {
    hostname,
    port,
    origin,
    replace(path) {
      redirect = path;
    },
  };
  const navigator = {
    serviceWorker: {
      async getRegistrations() {
        registrationsRead += 1;
        return registrations;
      },
    },
  };
  const context = vm.createContext({
    URL,
    Promise,
    Error,
    location,
    navigator,
    caches,
    window: {caches},
    document: {
      getElementById(id) {
        return id === 'heading' ? heading : status;
      },
    },
  });
  await vm.runInContext(script, context, {
    filename: 'refresh-working-preview-20260906.html',
  });
  return {deletedCaches, heading, redirect, registrationsRead, status};
}

test('does nothing outside the exact local preview origin', async () => {
  const target = registration({
    scriptURL: 'http://localhost:8393/room_of_days_service_worker.js',
  });
  const result = await run({hostname: 'localhost', registrations: [target]});

  assert.equal(result.registrationsRead, 0);
  assert.equal(target.calls, 0);
  assert.deepEqual(result.deletedCaches, []);
  assert.equal(result.redirect, undefined);
  assert.equal(result.heading.textContent, 'This link is for the local preview');
});

test('only removes the preview worker and its named cache before redirecting', async () => {
  const previewWorker = registration({
    scriptURL: 'http://127.0.0.1:8393/room_of_days_service_worker.js?v=42',
  });
  const unrelatedWorker = registration({
    scriptURL: 'http://127.0.0.1:8393/unrelated-worker.js',
  });
  const nestedPreviewWorker = registration({
    scope: 'http://127.0.0.1:8393/nested/',
    scriptURL: 'http://127.0.0.1:8393/room_of_days_service_worker.js',
  });
  const result = await run({
    registrations: [previewWorker, unrelatedWorker, nestedPreviewWorker],
    cacheNames: ['room-of-days-shell-42', 'unrelated-cache'],
  });

  assert.equal(previewWorker.calls, 1);
  assert.equal(unrelatedWorker.calls, 0);
  assert.equal(nestedPreviewWorker.calls, 0);
  assert.deepEqual(result.deletedCaches, ['room-of-days-shell-42']);
  assert.equal(result.redirect, '/?page=goals&preview=working-room-20260906');
});

test('does not redirect when preview worker cleanup reports failure', async () => {
  const previewWorker = registration({
    scriptURL: 'http://127.0.0.1:8393/room_of_days_service_worker.js',
    unregister: false,
  });
  const result = await run({
    registrations: [previewWorker],
    cacheNames: ['room-of-days-shell-42'],
  });

  assert.equal(previewWorker.calls, 1);
  assert.deepEqual(result.deletedCaches, []);
  assert.equal(result.redirect, undefined);
  assert.equal(result.heading.textContent, 'The preview could not refresh');
  assert.equal(
    result.status.textContent,
    'Your saved progress is unchanged. Reload this page to try again.',
  );
});
