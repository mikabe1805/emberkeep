import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../audio.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/ember_flame_icon.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';

/// About Room of Days — who makes it, the promise it keeps, and the two ways
/// to help: honest feedback, and in separately reviewed builds a voluntary
/// coffee. Nothing here sells anything; progress is the only currency the app
/// recognises, and this page says so in writing.
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

  /// Store builds default to no external payment link. A separately reviewed
  /// web/desktop build can opt in with --dart-define=COFFEE_URL=...; an empty
  /// value hides the whole section rather than rendering a fake control.
  static const String configuredCoffeeUrl = String.fromEnvironment(
    'COFFEE_URL',
    defaultValue: '',
  );

  String get _coffeeUrl => coffeeUrlOverride ?? configuredCoffeeUrl;

  /// Apple requires digital developer tips inside an iOS app to go through
  /// In-App Purchase (guideline 3.1.1), so the external coffee link stays off
  /// iOS builds entirely rather than risking the whole release on a review
  /// gamble. Android, web, and desktop may link out freely.
  bool get _coffeeAllowedHere =>
      _coffeeUrl.isNotEmpty && defaultTargetPlatform != TargetPlatform.iOS;

  static final Uri _feedbackMail = Uri.parse(
    'mailto:support@roomofdays.com'
    '?subject=${Uri.encodeComponent('Room of Days — feedback')}',
  );

  Future<void> _open(BuildContext context, Uri uri) async {
    Sfx.instance.play('tick');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.parchment,
      body: WarmBackground(
        themeId: themeId,
        reduceMotion: reduceMotion,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 36),
            children: [
              const DetailHeader(
                title: 'About Room of Days',
                accent: Palette.xp,
                subtitle: 'one keeper, one fire',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const EmberFlameIcon(size: 22),
                              const SizedBox(width: 9),
                              Flexible(
                                child: Text(
                                  'THE PROMISE',
                                  style: Type.label.copyWith(
                                    fontSize: Type.minLabel,
                                    color: Palette.xpLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Room of Days is for the little things — the '
                            'chores and small actions that are hard to feel. '
                            'Every one you keep pays into a room that warms '
                            'and grows, so consistency shows up somewhere '
                            'you can actually see. And when a day goes thin, '
                            'nothing scolds and nothing is taken from you: '
                            'streaks rest, the fire waits.\n\n'
                            'It’s made by one person and meant for everyone '
                            '— which is why all of it is free, and nothing '
                            'you could buy moves your progress. There are no '
                            'shortcuts, on purpose.',
                            style: Type.body.copyWith(
                              fontSize: 14,
                              height: 1.5,
                              color: Palette.textHi,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SAY SOMETHING',
                            style: Type.label.copyWith(
                              fontSize: Type.minLabel,
                              color: Palette.xpLight,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Feedback lands directly with the person who '
                            'builds this — what felt good, what felt off, '
                            'what you wish the room could hold.',
                            style: Type.body.copyWith(
                              fontSize: 13,
                              height: 1.45,
                              color: Palette.textMid,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _AboutAction(
                            key: const ValueKey('about-send-feedback'),
                            label: 'SEND FEEDBACK',
                            icon: Icons.mail_outline,
                            onTap: () => _open(context, _feedbackMail),
                          ),
                        ],
                      ),
                    ),
                    if (_coffeeAllowedHere) ...[
                      const SizedBox(height: 14),
                      GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KEEP THE FIRE FED',
                              style: Type.label.copyWith(
                                fontSize: Type.minLabel,
                                color: Palette.streak,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'If Room of Days has earned a place in your '
                              'days, you can send a coffee. It changes '
                              'nothing in the app — your room never knows. '
                              'It just helps one person keep building it.',
                              style: Type.body.copyWith(
                                fontSize: 13,
                                height: 1.45,
                                color: Palette.textMid,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _AboutAction(
                              key: const ValueKey('about-send-coffee'),
                              label: 'SEND A COFFEE',
                              icon: Icons.local_cafe_outlined,
                              gold: true,
                              onTap: () =>
                                  _open(context, Uri.parse(_coffeeUrl)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      'Thank you for keeping days here.',
                      textAlign: TextAlign.center,
                      style: Type.body.copyWith(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: Palette.textLo,
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
  final VoidCallback onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final ink = gold ? Palette.onHoney : Palette.textMid;
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
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
      ),
    );
  }
}
