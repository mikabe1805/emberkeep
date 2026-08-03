import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'a11y.dart';
import 'audio.dart';
import 'storage.dart';
import 'platform/persist_stub.dart'
    if (dart.library.js_interop) 'platform/persist_web.dart';
import 'screens/shell.dart';
import 'tokens.dart';
import 'widgets/morrow_tapestry_glyph.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // The brand fonts ship IN the app (assets/google_fonts/) — an offline first
  // launch must not fall back to system type. No runtime fetching, ever; and
  // the OFL licenses ride along in the license registry as the OFL requires.
  LicenseRegistry.addLicense(() async* {
    for (final f in const [
      'OFL-Fraunces.txt',
      'OFL-Inter.txt',
      'OFL-JetBrainsMono.txt',
      'OFL-EBGaramond.txt',
    ]) {
      final text = await rootBundle.loadString('assets/google_fonts/$f');
      yield LicenseEntryWithLineBreaks(const ['google_fonts'], text);
    }
  });

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
  // Sync sound setting from saved state — Storage.load() restores GameState
  // before the shell mounts, and the shell reads Sfx.instance.soundEnabled
  // to apply the saved preference. If no save exists yet, the default (true)
  // is fine.
  Storage.load().then((pair) {
    if (pair != null) {
      Sfx.instance.soundEnabled = pair.$1.soundEnabled;
      // restore the saved in-app text size before the first frame settles
      appTextScale.value = pair.$1.textScale;
    }
  });
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
          MorrowTapestryGlyph(
            level: 1,
            lit: true,
            reduceMotion: true,
            size: 34,
          ),
          SizedBox(height: 10),
          Text(
            'A snag — but your progress is safe.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Palette.textHi,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'This corner hit a snag; your progress is saved.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Palette.textLo),
          ),
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
      title: 'Room of Days',
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
      // Accessibility text sizing: honor BOTH the phone's Text Size setting and
      // the in-app control (Me → Settings). The in-app choice is a minimum; the
      // original platform scaler stays intact above it, including nonlinear
      // Android/iOS accessibility behavior.
      builder: (context, child) => ValueListenableBuilder<double>(
        valueListenable: appTextScale,
        builder: (context, inApp, _) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: roomTextScaler(
                MediaQuery.textScalerOf(context),
                inApp,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
      home: const AppShell(),
    );
  }
}
