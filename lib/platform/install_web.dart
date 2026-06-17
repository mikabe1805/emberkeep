import 'package:web/web.dart' as web;

/// Running in a normal browser tab (not an installed/standalone PWA)?
/// Used to show a one-time "Add to Home Screen" hint — the practical way to
/// "download" Emberkeep on iPhone. Modern iOS home-screen PWAs report
/// display-mode: standalone, so matchMedia alone is reliable (and avoids
/// fragile dynamic JS interop in release builds).
bool get isBrowserNotInstalled {
  try {
    final standalone =
        web.window.matchMedia('(display-mode: standalone)').matches;
    return !standalone;
  } catch (_) {
    return false;
  }
}

bool get isIosBrowser {
  try {
    final ua = web.window.navigator.userAgent.toLowerCase();
    final isIos = ua.contains('iphone') ||
        ua.contains('ipad') ||
        // iPadOS 13+ reports as Mac; detect touch
        (ua.contains('macintosh') && web.window.navigator.maxTouchPoints > 1);
    return isIos;
  } catch (_) {
    return false;
  }
}
