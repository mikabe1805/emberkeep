import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio.dart';
import 'platform/persist_stub.dart'
    if (dart.library.js_interop) 'platform/persist_web.dart';
import 'screens/shell.dart';
import 'tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Crash safety: a widget build error shows a warm panel, never a raw red
  // box or a white screen — and one bad frame never takes the app down.
  ErrorWidget.builder = (details) => const _FriendlyError();
  // Uncaught async/platform errors: surface loudly in debug (so bugs aren't
  // hidden from the developer), swallow in release (so the app stays alive).
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
    return !kDebugMode;
  };

  // Phone-first: this is a vertical, candlelit experience — keep it upright.
  // (No-op on web; honored on native iOS/Android.)
  SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);

  // Fire-and-forget: the app never waits on (or requires) audio.
  Sfx.instance.init();
  // Ask the browser to make storage durable (exempts an installed PWA from
  // iOS's storage eviction — the save's first line of defense).
  requestPersistentStorage();
  runApp(const LifeRpgApp());
}

/// Replaces Flutter's default error box. Keeps the candlelit look and never
/// leaks a stack trace to the user; the data underneath is untouched.
/// Deliberately uses ONLY built-in styles (no GoogleFonts) so the fallback
/// itself can never throw and start an error loop.
class _FriendlyError extends StatelessWidget {
  const _FriendlyError();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.parchment,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, color: Palette.streak, size: 32),
          SizedBox(height: 10),
          Text('A flicker — but your fire is safe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Palette.textHi)),
          SizedBox(height: 4),
          Text('This corner hit a snag; your progress is saved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Palette.textLo)),
        ],
      ),
    );
  }
}

class LifeRpgApp extends StatelessWidget {
  const LifeRpgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emberkeep',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Palette.parchment,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.xp,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // Honor the phone's Text Size accessibility setting (the app ignored it
      // before), but clamp the upper end so the dense candlelit cards don't
      // shatter. A low-vision user finally gets larger type; layouts stay sane.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.3,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AppShell(),
    );
  }
}
