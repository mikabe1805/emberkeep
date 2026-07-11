import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../content/cosmetics.dart';
import '../content/evidence.dart';
import '../engine.dart';
import '../haptics.dart';
import '../models.dart';
import '../tokens.dart';
import 'glass.dart';

/// The "receipt of rewards": a vertical stack of color-coded bubbles popping
/// in one by one near the completed quest — one tap can deliver 2–6 distinct
/// micro-rewards, each with its own color, icon and sound layer
/// (Habitica's best pattern, modernized — DESIGN.md §3).
///
/// The +Stat bubble is tappable when an unread evidence card is waiting
/// (DESIGN.md §5) — tap opens a bite-sized "why this works" card.
class RewardReceipt extends StatefulWidget {
  const RewardReceipt({
    super.key,
    required this.bundle,
    required this.anchor,
    required this.onDone,
    this.state,
  });

  final RewardBundle bundle;

  /// Global position of the completing tap; bubbles rise above it.
  final Offset anchor;
  final VoidCallback onDone;

  /// When set, enables the evidence-card tap on the +Stat bubble.
  final GameState? state;

  @override
  State<RewardReceipt> createState() => _RewardReceiptState();
}

class _Bubble {
  _Bubble(
    this.text,
    this.icon,
    this.color,
    this.sound, {
    this.haptic = false,
    this.wide = false,
    this.hero = false,
    this.evidence = false,
  });
  final String text;
  final IconData icon;
  final Color color;
  final String? sound;
  final bool haptic;
  final bool wide;
  final bool hero;
  final bool evidence;
}

class _RewardReceiptState extends State<RewardReceipt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Bubble> _bubbles;
  bool _heldForEvidence = false;

  @override
  void initState() {
    super.initState();
    final b = widget.bundle;
    _bubbles = [
      if (b.firstOfDay)
        _Bubble(
          'FIRST EMBER OF THE DAY 🔥',
          Icons.local_fire_department,
          Palette.streak,
          'streak',
        ),
      _Bubble('+${b.xp} XP', Icons.bolt, Palette.xp, null, hero: true),
      // per-stat pitched blip (§8: pitch varies by stat) — tappable when
      // an unread evidence card waits behind it (DESIGN §5)
      _Bubble(
        '+${b.statGain} ${b.stat.abbr}${b.hasEvidence ? ' ⓘ' : ''}',
        Icons.trending_up,
        b.stat.color,
        'stat_${b.stat.index}',
        evidence: b.hasEvidence,
      ),
      // embers earned — makes the shop currency felt every completion (r48)
      if (b.embers > 0)
        _Bubble('+${b.embers} ✦', Icons.auto_awesome, Palette.xpLight, null),
      if (b.verifiedMult != null)
        _Bubble(
          'VERIFIED ×${b.verifiedMult!.toStringAsFixed(1)}',
          Icons.verified,
          Palette.verify,
          null,
        ),
      if (b.streakMult != null)
        _Bubble(
          'STREAK ×${b.streakMult!.toStringAsFixed(1)}',
          Icons.local_fire_department,
          Palette.streak,
          'streak',
        ),
      if (b.comebackMult != null)
        _Bubble(
          'WELCOME BACK ×${b.comebackMult!.toStringAsFixed(1)}',
          Icons.local_fire_department,
          Palette.streak,
          'streak',
        ),
      if (b.shieldHeld)
        _Bubble('STREAK SAFE 🛡️', Icons.shield, Palette.verify, 'streak'),
      if (b.critMult != null)
        _Bubble(
          'CRITICAL! ×${b.critMult!.toStringAsFixed(1)}',
          Icons.flash_on,
          Palette.unlock,
          'crit',
          haptic: true,
          hero: true,
        ),
      if (b.loot != null)
        _Bubble(
          '${(cosmeticFor(b.loot)?.rarity ?? Rarity.common) == Rarity.rare ? "RARE" : "LOOT"} · ${b.loot}',
          Icons.card_giftcard,
          rarityColor(cosmeticFor(b.loot)?.rarity ?? Rarity.common),
          'loot',
          hero: true,
        ),
      // the personal voice — last, wider, no sound (DESIGN.md §11.2)
      _Bubble(b.message, Icons.favorite, b.stat.color, null, wide: true),
    ];

    final total = Motion.bubbleLife + Motion.bubbleStagger * _bubbles.length;
    _c = AnimationController(vsync: this, duration: total)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && !_heldForEvidence) {
          widget.onDone();
        }
      })
      ..forward();

    // sound/haptic layers fire on each bubble's entrance beat
    for (var i = 0; i < _bubbles.length; i++) {
      final bubble = _bubbles[i];
      if (bubble.sound == null && !bubble.haptic) continue;
      Future.delayed(Motion.bubbleStagger * i, () {
        if (!mounted) return;
        if (bubble.sound != null) Sfx.instance.play(bubble.sound!);
        if (bubble.haptic) {
          if (Haptics.reduceMotion) {
            HapticFeedback.mediumImpact();
          } else {
            HapticFeedback.heavyImpact();
            Future.delayed(const Duration(milliseconds: 90), () {
              if (mounted) HapticFeedback.mediumImpact();
            });
          }
        }
      });
    }
  }

  void _openEvidence() {
    final card = evidenceForStat(widget.bundle.stat);
    final s = widget.state;
    if (card == null || s == null) return;
    _heldForEvidence = true;
    s.markEvidenceSeen([card.title]);
    Sfx.instance.play('tick');
    Haptics.tap();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GlassPanel(
            tint: const Color(0xF22A211D),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHY THIS WORKS',
                  style: Type.label.copyWith(fontSize: 11, color: Palette.info),
                ),
                const SizedBox(height: 8),
                Text(
                  card.title,
                  style: Type.display.copyWith(
                    fontSize: 20,
                    color: Palette.textHi,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  card.text,
                  style: Type.body.copyWith(
                    fontSize: 14,
                    height: 1.45,
                    color: Palette.textMid,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  card.source,
                  style: Type.label.copyWith(
                    fontSize: 10,
                    color: Palette.textLo,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'GOT IT',
                      style: Type.label.copyWith(color: Palette.xp),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      if (!mounted) return;
      _heldForEvidence = false;
      if (_c.status == AnimationStatus.completed) {
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final totalMs = _c.duration!.inMilliseconds.toDouble();
    final staggerMs = Motion.bubbleStagger.inMilliseconds.toDouble();

    // Keep the whole bubble stack on screen: estimate its height and clamp the
    // top so the bottom never runs off the bottom edge (stack can be ~10 tall).
    final stackH = 60.0 * _bubbles.length;
    final top = (widget.anchor.dy - stackH).clamp(
      8.0,
      (screen.height - stackH - 16).clamp(8.0, screen.height),
    );

    return Positioned(
      left: (widget.anchor.dx - 110).clamp(8.0, screen.width - 228),
      top: top,
      child: OverlaySurface(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final elapsed = _c.value * totalMs;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: screen.height - 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _bubbles.length; i++)
                    _bubbleView(_bubbles[i], elapsed - i * staggerMs, totalMs),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _bubbleView(_Bubble b, double localMs, double totalMs) {
    // entrance: 220ms pop (ease-out-back); exit: shared fade at the end
    final enter = (localMs / 220).clamp(0.0, 1.0);
    if (enter <= 0) return const SizedBox(height: 44);
    final scale = Curves.easeOutBack.transform(enter);
    final fadeStart = totalMs - 350;
    final exit = _heldForEvidence
        ? 0.0
        : ((_c.value * totalMs - fadeStart) / 350).clamp(0.0, 1.0);

    final pill = Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(horizontal: 13, vertical: b.hero ? 10 : 8),
      constraints: BoxConstraints(maxWidth: b.wide ? 230 : 220),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              b.color.withValues(alpha: b.hero || b.evidence ? 0.30 : 0.20),
              Palette.card,
            ),
            Color.alphaBlend(b.color.withValues(alpha: 0.10), Palette.card),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: b.color.withValues(alpha: b.hero || b.evidence ? 0.85 : 0.6),
          width: b.hero || b.evidence ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: b.color.withValues(
              alpha: b.hero || b.evidence ? 0.40 : 0.22,
            ),
            blurRadius: b.hero || b.evidence ? 18 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: b.wide
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Icon(
            b.icon,
            size: b.wide
                ? 13
                : b.hero
                ? 19
                : 16,
            color: b.color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: b.wide
                ? Text(
                    b.text,
                    style: Type.body.copyWith(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Palette.textMid,
                    ),
                  )
                : Text(
                    b.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Type.numerals.copyWith(
                      fontSize: b.hero ? 18 : 13,
                      color: b.color,
                    ),
                  ),
          ),
        ],
      ),
    );

    return Opacity(
      opacity: (enter * (1 - exit)).clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - scale) * 14 - 18 * exit),
        child: Transform.scale(
          scale: 0.6 + 0.4 * scale,
          alignment: Alignment.centerLeft,
          child: b.evidence
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openEvidence,
                  child: pill,
                )
              : IgnorePointer(child: pill),
        ),
      ),
    );
  }
}
