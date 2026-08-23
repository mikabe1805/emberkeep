import 'package:flutter/material.dart';

import '../audio.dart';
import '../content/release_notes.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/gold_surface.dart';
import '../widgets/pressable.dart';

/// The automatic one-time release card and its replayable Me archive share the
/// exact same content surface. Automatic mode owns a quiet close control;
/// manual mode uses ordinary Navigator back behavior.
class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({
    super.key,
    this.releases = roomOfDaysReleaseNotes,
    this.automatic = false,
    this.onDismiss,
    this.themeId,
    this.reduceMotion = false,
  }) : assert(!automatic || onDismiss != null);

  final List<RoomReleaseNotes> releases;
  final bool automatic;
  final VoidCallback? onDismiss;
  final String? themeId;
  final bool reduceMotion;

  void _dismiss(BuildContext context) {
    final callback = onDismiss;
    if (callback != null) {
      callback();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final shownReleases = automatic ? releases.take(1).toList() : releases;
    return Scaffold(
      backgroundColor: Palette.parchment,
      body: WarmBackground(
        themeId: themeId,
        tint: Palette.xp,
        reduceMotion: reduceMotion,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: "What's New",
          explicitChildNodes: true,
          child: FocusScope(
            autofocus: automatic,
            child: SafeArea(
              child: Column(
                children: [
                  if (automatic)
                    _AutomaticHeader(onClose: () => _dismiss(context))
                  else
                    const DetailHeader(
                      title: "What's New",
                      accent: Palette.xp,
                      subtitle: 'what changed, release by release',
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      key: const ValueKey('whats-new-scroll'),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (automatic) ...[
                            Text(
                              'WHAT\'S NEW',
                              style: Type.label.copyWith(
                                fontSize: 11,
                                letterSpacing: 1.55,
                                color: Palette.xpLight,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'A few new things',
                              style: Type.display.copyWith(
                                fontSize: 32,
                                height: 1.04,
                                color: Palette.textHi,
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                          if (shownReleases.isEmpty)
                            const _EmptyReleaseArchive()
                          else
                            for (final (index, release)
                                in shownReleases.indexed) ...[
                              _ReleaseCard(
                                key: ValueKey(
                                  'whats-new-release-${release.id}',
                                ),
                                release: release,
                                featured: index == 0,
                              ),
                              if (index != shownReleases.length - 1)
                                const SizedBox(height: 16),
                            ],
                          const SizedBox(height: 22),
                          _ExitAction(
                            automatic: automatic,
                            reduceMotion: reduceMotion,
                            onTap: () => _dismiss(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AutomaticHeader extends StatelessWidget {
  const _AutomaticHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
      child: Row(
        children: [
          const Expanded(child: SizedBox()),
          Semantics(
            button: true,
            label: "Close What's New",
            onTap: onClose,
            excludeSemantics: true,
            child: IconButton(
              key: const ValueKey('whats-new-close'),
              tooltip: "Close What's New",
              onPressed: onClose,
              icon: const Icon(
                Icons.close_rounded,
                size: 23,
                color: Palette.textMid,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({
    super.key,
    required this.release,
    required this.featured,
  });

  final RoomReleaseNotes release;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      glow: featured,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const FacetMedallion(
                size: 56,
                accent: Palette.xp,
                glow: true,
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: 27,
                  color: Palette.xpLight,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      release.versionLabel,
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        height: 1.35,
                        color: Palette.xpLight,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      release.dateLabel,
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        letterSpacing: 1.25,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            release.title,
            style: Type.display.copyWith(
              fontSize: 24,
              height: 1.12,
              color: Palette.textHi,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            release.introduction,
            style: Type.body.copyWith(
              fontSize: 13.5,
              height: 1.48,
              color: Palette.textMid,
            ),
          ),
          if (release.highlights.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x00E0A865),
                    Color(0x8AE0A865),
                    Color(0x00E0A865),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final (index, highlight) in release.highlights.indexed) ...[
              _HighlightRow(highlight: highlight),
              if (index != release.highlights.length - 1)
                const SizedBox(height: 15),
            ],
          ],
        ],
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({required this.highlight});

  final ReleaseHighlight highlight;

  IconData get _icon => switch (highlight.kind) {
    ReleaseHighlightKind.academicDaybook => Icons.calendar_month_outlined,
    ReleaseHighlightKind.courseWork => Icons.assignment_outlined,
    ReleaseHighlightKind.calendarViews => Icons.view_week_outlined,
    ReleaseHighlightKind.locationDirections => Icons.directions_outlined,
    ReleaseHighlightKind.flexiblePlans => Icons.event_repeat_rounded,
    ReleaseHighlightKind.streakSafety => Icons.shield_outlined,
    ReleaseHighlightKind.roomGuide => Icons.explore_outlined,
    ReleaseHighlightKind.interactionSound => Icons.graphic_eq_rounded,
    ReleaseHighlightKind.questControl => Icons.edit_note_rounded,
    ReleaseHighlightKind.spaceDiscovery => Icons.travel_explore_rounded,
    ReleaseHighlightKind.ambientLight => Icons.light_mode_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FacetMedallion(
          size: 38,
          accent: Palette.xp,
          child: Icon(_icon, size: 19, color: Palette.xpLight),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                highlight.title,
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  height: 1.3,
                  color: Palette.xpLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                highlight.body,
                style: Type.body.copyWith(
                  fontSize: 12.5,
                  height: 1.43,
                  color: Palette.textMid,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyReleaseArchive extends StatelessWidget {
  const _EmptyReleaseArchive();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Text(
        'No release notes are kept here yet.',
        style: Type.body.copyWith(fontSize: 14, color: Palette.textMid),
      ),
    );
  }
}

class _ExitAction extends StatelessWidget {
  const _ExitAction({
    required this.automatic,
    required this.reduceMotion,
    required this.onTap,
  });

  final bool automatic;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = automatic ? 'KEEP GOING' : 'BACK TO YOUR ROOM';
    return Pressable(
      key: ValueKey(
        automatic ? 'whats-new-keep-going' : 'whats-new-back-to-room',
      ),
      semanticLabel: automatic ? 'Keep going' : 'Back to your room',
      material: MaterialSound.brass,
      onTapUp: (_) => onTap(),
      pressDepth: 3,
      edgeColor: Palette.brassDeep,
      shape: const FacetedBorder(cut: 10),
      child: ExcludeSemantics(
        child: GoldSurface(
          cut: 10,
          reduceMotion: reduceMotion,
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: GoldLabel(
                text: label,
                icon: automatic
                    ? Icons.arrow_forward_rounded
                    : Icons.chevron_left_rounded,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
