{{flutter_js}}
{{flutter_build_config}}

const roomOfDaysServiceWorkerVersion = {{flutter_service_worker_version}};

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
