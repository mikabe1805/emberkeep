import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../platform/share_stub.dart'
    if (dart.library.js_interop) '../platform/share_web.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/ember_flame_icon.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/pressable.dart';

/// The maker's page: a short, human account of why Room of Days exists, plus
/// feedback and a policy-gated voluntary support link. Support never changes
/// app access, rewards, or progress.
class AboutScreen extends StatelessWidget {
  const AboutScreen({
    super.key,
    this.themeId,
    this.reduceMotion = false,
    this.coffeeUrlOverride,
  });

  final String? themeId;
  final bool reduceMotion;
  final String? coffeeUrlOverride;

  /// The owner can still override this for a separate build. An empty value
  /// hides the whole section rather than rendering a fake control.
  static const String configuredCoffeeUrl = String.fromEnvironment(
    'COFFEE_URL',
    defaultValue: 'https://ko-fi.com/mikabe',
  );

  String get _coffeeUrl => coffeeUrlOverride ?? configuredCoffeeUrl;

  /// Apple requires developer tips inside an iOS app to use In-App Purchase.
  /// Google Play permits a direct creator contribution only when it grants no
  /// digital content or app benefit. The page's copy and behavior preserve
  /// that boundary; iOS remains excluded.
  bool get _coffeeAllowedHere {
    if (_coffeeUrl.isEmpty) return false;
    if (kIsWeb) return true;
    return defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.fuchsia;
  }

  static final Uri _feedbackMail = Uri.parse(
    'mailto:support@roomofdays.com'
    '?subject=${Uri.encodeComponent('Room of Days — feedback')}',
  );

  static const String _shareCopy =
      'Room of Days is a quiet habit app where the little things you keep '
      'warm and grow a room of your own. https://roomofdays.com';

  Future<void> _open(BuildContext context, Uri uri) async {
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      // A missing mail client or browser must not read as a crash.
    }
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        content: Text(
          uri.scheme == 'mailto'
              ? 'Couldn’t open your mail app — you can write to support@roomofdays.com directly.'
              : 'Couldn’t open that page. Try again when a browser is available.',
          style: Type.body.copyWith(color: Palette.textHi),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, Offset origin) async {
    final result = await shareText(
      _shareCopy,
      origin: Rect.fromCenter(center: origin, width: 1, height: 1),
    );
    if (!context.mounted || result != ShareTextResult.unavailable) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        content: Text(
          'Couldn’t open sharing on this device. You can send roomofdays.com directly.',
          style: Type.body.copyWith(color: Palette.textHi),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showCoffee = _coffeeAllowedHere;
    return Scaffold(
      backgroundColor: Palette.parchment,
      body: WarmBackground(
        themeId: themeId,
        tint: Palette.xp,
        reduceMotion: reduceMotion,
        child: SafeArea(
          child: Column(
            children: [
              const DetailHeader(
                title: 'Room of Days',
                accent: Palette.xp,
                subtitle: 'made by Mika',
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                      sliver: SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _MakerCard(),
                            const SizedBox(height: 14),
                            _ContactCard(
                              onFeedback: (_) => _open(context, _feedbackMail),
                            ),
                            const SizedBox(height: 14),
                            _SupportCard(
                              showCoffee: showCoffee,
                              onCoffee: (_) =>
                                  _open(context, Uri.parse(_coffeeUrl)),
                              onShare: (origin) => _share(context, origin),
                            ),
                            const Spacer(),
                            const SizedBox(height: 18),
                            Text(
                              'FREE TO USE  ·  NO PAID PROGRESS',
                              textAlign: TextAlign.center,
                              style: Type.label.copyWith(
                                fontSize: Type.minLabel,
                                letterSpacing: 1.15,
                                color: Palette.textLo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MakerCard extends StatelessWidget {
  const _MakerCard();

  @override
  Widget build(BuildContext context) => GlassPanel(
    glow: true,
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const FacetMedallion(
              size: 68,
              accent: Palette.xp,
              glow: true,
              child: EmberFlameIcon(size: 34),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ONE-PERSON PROJECT',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 1.35,
                      color: Palette.xpLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Made by Mika',
                    style: Type.display.copyWith(
                      fontSize: 23,
                      color: Palette.textHi,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Room of Days is my passion project. I built it because the hard '
          'little things in a day deserve to feel like they count.',
          style: Type.body.copyWith(
            fontSize: 14,
            height: 1.48,
            color: Palette.textHi,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
          decoration: facetedDecoration(
            cut: 8,
            color: Palette.xp.withValues(alpha: 0.09),
            borderColor: Palette.xp.withValues(alpha: 0.28),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.lock_open_rounded,
                  size: 17,
                  color: Palette.xpLight,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Everything in the room stays open to everyone. There are '
                  'no paid shortcuts, and support never changes your progress.',
                  style: Type.body.copyWith(
                    fontSize: 12.5,
                    height: 1.42,
                    color: Palette.textMid,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.onFeedback});

  final ValueChanged<Offset> onFeedback;

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KEEP IN TOUCH',
          style: Type.label.copyWith(
            fontSize: Type.minLabel,
            letterSpacing: 1.35,
            color: Palette.xpLight,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'If something felt good, felt off, or should exist, tell me. Every '
          'note reaches me directly.',
          style: Type.body.copyWith(
            fontSize: 12.8,
            height: 1.42,
            color: Palette.textMid,
          ),
        ),
        const SizedBox(height: 12),
        _AboutAction(
          key: const ValueKey('about-send-feedback'),
          label: 'SEND FEEDBACK',
          icon: Icons.mail_outline_rounded,
          gold: true,
          onTap: onFeedback,
        ),
      ],
    ),
  );
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.showCoffee,
    required this.onCoffee,
    required this.onShare,
  });

  final bool showCoffee;
  final ValueChanged<Offset> onCoffee;
  final ValueChanged<Offset> onShare;

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SUPPORT THE PROJECT',
          style: Type.label.copyWith(
            fontSize: Type.minLabel,
            letterSpacing: 1.35,
            color: Palette.streak,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          showCoffee
              ? 'If the room has earned a place in your days, you can leave '
                    'a tip on Ko-fi. It helps me keep building; nothing '
                    'unlocks in the app.'
              : 'The best way to help right now is to share Room of Days '
                    'with someone who might need a gentler way to keep going.',
          style: Type.body.copyWith(
            fontSize: 12.5,
            height: 1.42,
            color: Palette.textMid,
          ),
        ),
        const SizedBox(height: 12),
        if (showCoffee) ...[
          _AboutAction(
            key: const ValueKey('about-send-coffee'),
            label: 'VISIT KO-FI',
            icon: Icons.local_cafe_outlined,
            gold: true,
            onTap: onCoffee,
          ),
          const SizedBox(height: 10),
        ],
        _AboutAction(
          key: const ValueKey('about-share-app'),
          label: 'SHARE ROOM OF DAYS',
          icon: Icons.ios_share_rounded,
          gold: !showCoffee,
          onTap: onShare,
        ),
      ],
    ),
  );
}

class _AboutAction extends StatelessWidget {
  const _AboutAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.gold = false,
  });

  final String label;
  final IconData icon;
  final ValueChanged<Offset> onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final ink = gold ? Palette.onHoney : Palette.textHi;
    return Pressable(
      semanticLabel: label,
      onTapUp: onTap,
      pressDepth: 3,
      edgeColor: gold ? const Color(0xFF5B3215) : const Color(0xFF0F0905),
      shape: const FacetedBorder(cut: 9),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: facetedDecoration(
          cut: 9,
          gradient: gold ? Palette.honeyGradient : null,
          color: gold ? null : Palette.glassFill,
          borderColor: gold ? Colors.transparent : Palette.glassEdge,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: ink),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: Type.label.copyWith(fontSize: 11, color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
