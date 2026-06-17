import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/install_stub.dart'
    if (dart.library.js_interop) '../platform/install_web.dart';
import '../tokens.dart';
import 'glass.dart';

/// A one-time, dismissible nudge to install Emberkeep to the home screen —
/// the practical "download" on iPhone. Only appears in a mobile browser
/// tab, never in the installed PWA or native builds. Dismissal is persisted
/// so it never nags twice (and a rare false-positive stays gone once shut).
class InstallHint extends StatefulWidget {
  const InstallHint({super.key});

  @override
  State<InstallHint> createState() => _InstallHintState();
}

class _InstallHintState extends State<InstallHint> {
  static const _prefKey = 'install_hint_dismissed';
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted && (p.getBool(_prefKey) ?? false)) {
        setState(() => _dismissed = true);
      }
    });
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    try {
      (await SharedPreferences.getInstance()).setBool(_prefKey, true);
    } catch (_) {/* best effort */}
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !isBrowserNotInstalled) return const SizedBox.shrink();
    final ios = isIosBrowser;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GlassPanel(
        glow: true,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.ios_share, size: 18, color: Palette.xpLight),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ios
                    ? 'Keep the ember close — add Emberkeep to your Home Screen. Tap Share, then “Add to Home Screen.”'
                    : 'Keep the ember close — add Emberkeep to your Home Screen from your browser menu: “Add to Home Screen.”',
                style: Type.body.copyWith(fontSize: 12, color: Palette.textMid),
              ),
            ),
            GestureDetector(
              onTap: _dismiss,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.close, size: 16, color: Palette.textLo),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
