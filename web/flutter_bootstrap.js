{{flutter_js}}
{{flutter_build_config}}

const roomOfDaysServiceWorkerVersion = {{flutter_service_worker_version}};
let roomOfDaysWarmResumeTimer;

function messageRoomOfDaysWorker(message) {
  navigator.serviceWorker.ready
    .then((registration) => {
      registration.active?.postMessage(message);
    })
    .catch(() => {});
}

function warmRoomOfDaysOfflineCache() {
  messageRoomOfDaysWorker('WARM_OFFLINE_CACHE');
}

function pauseRoomOfDaysOfflineCache() {
  messageRoomOfDaysWorker('PAUSE_OFFLINE_CACHE');
  clearTimeout(roomOfDaysWarmResumeTimer);
  roomOfDaysWarmResumeTimer = setTimeout(warmRoomOfDaysOfflineCache, 8000);
}

function scheduleRoomOfDaysOfflineWarmup() {
  for (const eventName of ['pointerdown', 'touchstart', 'wheel', 'keydown']) {
    window.addEventListener(eventName, pauseRoomOfDaysOfflineCache, {
      passive: true,
    });
  }
  // The first room and this browser's renderer are installed atomically. The
  // rest of the illustrated app warms only after the first-use window and an
  // idle turn; any interaction pauses it again.
  setTimeout(() => {
    if ('requestIdleCallback' in window) {
      window.requestIdleCallback(warmRoomOfDaysOfflineCache, {timeout: 30000});
    } else {
      setTimeout(warmRoomOfDaysOfflineCache, 4000);
    }
  }, 20000);
}

function registerRoomOfDaysServiceWorker() {
  if (!('serviceWorker' in navigator)) return;

  const root = new URL('./', document.baseURI);
  const worker = new URL('room_of_days_service_worker.js', root);
  worker.searchParams.set(
    'v',
    roomOfDaysServiceWorkerVersion ?? 'development',
  );

  navigator.serviceWorker
    .register(worker, {scope: root.pathname})
    .then(scheduleRoomOfDaysOfflineWarmup)
    .catch((error) => {
      console.warn('Room of Days offline cache could not start:', error);
    });
}

if (document.readyState === 'complete') {
  registerRoomOfDaysServiceWorker();
} else {
  window.addEventListener('load', registerRoomOfDaysServiceWorker, {once: true});
}

_flutter.loader.load({
  // Keep the rendering engine on the app's own origin so a completed cache can
  // reopen without depending on a third-party CDN.
  config: {canvasKitBaseUrl: 'canvaskit/'},
});
