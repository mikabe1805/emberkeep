import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../audio.dart';
import '../cloud.dart';
import '../haptics.dart';
import '../platform/share_stub.dart'
    if (dart.library.js_interop) '../platform/share_web.dart';
import '../content/achievements.dart';
import '../content/cosmetics.dart';
import '../content/creature_skins.dart';
import '../content/memories.dart';
import '../content/room_styles.dart';
import '../content/stat_ranks.dart';
import '../content/themes.dart';
import '../engine.dart';
import '../notifications.dart';
import '../storage.dart';
import '../tokens.dart';
import '../a11y.dart';
import '../widgets/count_up.dart';
import '../widgets/domain_hint.dart';
import '../widgets/ember_flame_icon.dart';
import '../widgets/facets.dart';
import '../models.dart';
import '../widgets/glass.dart';
import '../widgets/glass_switch.dart';
import '../widgets/home_room.dart';
import '../widgets/honey_button.dart';
import '../widgets/luxe_depth.dart';
import '../widgets/morrow_tapestry_glyph.dart';
import '../widgets/radar.dart';
import '../widgets/stat_chips.dart';
import '../social.dart';
import 'domain_detail.dart';
import 'hearth_circle.dart';
import 'shop.dart';

/// The "Me" page: your space + your build. The stats radar, the attribution
/// ledger, and the share card (a build this earnest deserves showing off).
class MePage extends StatelessWidget {
  const MePage({
    super.key,
    required this.state,
    required this.quests,
    required this.onPersist,
    required this.onAddQuest,
    required this.onExport,
    required this.onImport,
    required this.onReset,
    required this.onNotifyChanged,
    required this.onEnableCloud,
    required this.onLinkAccount,
    required this.onSignIn,
    required this.onSignOut,
    required this.onDeleteAccount,
    this.parallax = const AlwaysStoppedAnimation(Offset.zero),
  });

  final GameState state;

  /// The live board quests — threaded to a domain's base page (quests serving it).
  final List<Quest> quests;

  /// Persists the save after a domain journal edit.
  final VoidCallback onPersist;

  /// Adds a quest — used by a domain journal's "make this a quest".
  final bool Function(Quest quest) onAddQuest;

  /// Copies the raw save to the clipboard; returns false if none exists.
  final Future<bool> Function() onExport;

  /// Restores a pasted backup; returns false on invalid data.
  final Future<bool> Function(String raw) onImport;

  /// Erases everything and starts a fresh keep (guarded by a dialog).
  final VoidCallback onReset;

  /// Re-applies local reminders after a settings change (native-only).
  final Future<void> Function() onNotifyChanged;

  /// Explicitly enables optional anonymous cloud backup.
  final Future<String?> Function() onEnableCloud;

  /// Links an email/password to the current data; null = success.
  final Future<String?> Function(String email, String pw) onLinkAccount;

  /// Signs in to an existing account (adopts its save); null = success.
  final Future<String?> Function(String email, String pw) onSignIn;

  /// Signs out → back to anonymous.
  final Future<void> Function() onSignOut;

  /// Permanently deletes the linked cloud account; null = success.
  final Future<String?> Function(String password) onDeleteAccount;

  /// Shared room perspective. Text and controls stay anchored while the
  /// authored plate and light respond beneath them.
  final ValueListenable<Offset> parallax;

  static final _privacyUrl = Uri.parse(
    'https://emberkeep-5b33b.web.app/privacy.html',
  );
  static final _deletionUrl = Uri.parse(
    'https://emberkeep-5b33b.web.app/delete-account.html',
  );

  static Future<void> _openPolicyPage(BuildContext context, Uri page) async {
    var opened = false;
    try {
      opened = await launchUrl(page);
    } catch (_) {
      // A missing browser should never break the data controls around this link.
    }
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        content: Text(
          'Couldn’t open that page. Try again when a browser is available.',
          style: Type.body.copyWith(color: Palette.textHi),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => LuxeCustomPageList(
        hero: HomeRoom(
          aspect: 1.5,
          lively: !state.reduceMotion,
          unlocked: const {},
          wall: wallColorsFor(state),
          plateId: state.wallStyle,
          floor: floorColorsFor(state),
          window: state.windowScene,
          petAwake: state.streakDays > 0,
          emberGlow: flameHueFor(state),
          heirloomFlame: state.creatureSkin == 'gilded',
          level: state.level,
          memoryArtifacts: memoryArtifactCount(state, quests),
          parallax: state.reduceMotion ? null : parallax,
        ),
        title: 'Me',
        subtitle: 'your space, already yours',
        icon: Icons.emoji_emotions_outlined,
        reduceMotion: state.reduceMotion,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: facetedDecoration(
            cut: 8,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Palette.xp.withValues(alpha: 0.20),
                Palette.xp.withValues(alpha: 0.06),
              ],
            ),
            borderColor: Palette.xp.withValues(alpha: 0.52),
          ),
          child: RollingNumber(
            state.totalXp,
            prefix: 'LV ${state.level} · ',
            suffix: ' XP',
            maxLines: 1,
            style: Type.label.copyWith(fontSize: 10, color: Palette.xpLight),
          ),
        ),
        children: [
          // ── the room's own rail: what you have to spend, and the way in ──
          // Glimmers/room choice, sharing and the circle used to live *inside* the
          // identity plate, which turned the one page element that should read
          // as a nameplate into a grab bag of unrelated controls.
          _SpaceRail(
            embers: state.embers,
            onChangeSpace: () {
              Sfx.instance.play('tick');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ShopScreen(state: state, onPersist: onPersist),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SpaceLink(
                icon: Icons.ios_share,
                label: state.roomCode == null
                    ? 'Share my space'
                    : 'Shared · ${state.roomCode}',
                onTap: () => shareSpace(context, state, onPersist),
              ),
              Container(
                width: 1,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: Palette.textLo.withValues(alpha: 0.3),
              ),
              _SpaceLink(
                icon: Icons.travel_explore,
                label: 'Visit a space',
                onTap: () => visitSpace(
                  context,
                  themeId: state.canvasTheme,
                  lively: !state.reduceMotion,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── the nameplate ────────────────────────────────────────
          GlassPanel(
            blur: true,
            child: Column(
              children: [
                const _PlateOrnament(),
                const SizedBox(height: 12),
                Text(
                  (state.playerName ?? 'You').toUpperCase(),
                  style: Type.display.copyWith(
                    fontSize: 29,
                    color: Palette.textHi,
                    letterSpacing: 3.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.buildTitle.toUpperCase(),
                  style: Type.body.copyWith(
                    fontSize: 14,
                    letterSpacing: 2.2,
                    color: state.dominantStat?.color ?? Palette.xpLight,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${state.totalCompletions} QUESTS DONE  ·  ${state.streakDays} DAY STREAK',
                  style: Type.label.copyWith(
                    fontSize: 10.5,
                    color: Palette.textLo,
                  ),
                ),
                if (state.equippedSkin != null) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (_) {
                      final tint =
                          cosmeticFor(state.equippedSkin)?.aura ??
                          Palette.unlock;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 13, color: tint),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'WEARING ${state.equippedSkin!.toUpperCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Type.label.copyWith(
                                fontSize: 11,
                                color: tint,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                // Milestones remain a compact record inside the nameplate.
                // Complete-room identities now live in Change your space, so
                // this row no longer implies the room begins unfinished.
                _InsetSection(
                  label: 'MILESTONES',
                  child: Row(
                    children: [
                      for (final f in progressMilestones.take(3)) ...[
                        if (f != progressMilestones.take(3).first)
                          const SizedBox(width: 7),
                        Expanded(
                          child: _LockedSlot(
                            // The name always; the padlock says "not yet" and
                            // the sheet behind the tap gives the exact level.
                            // "FIRST FIVE · LV 5" in a third of a row shrank
                            // below the readable floor.
                            label: f.name.toUpperCase(),
                            unlocked: state.level >= f.level,
                            onTap: () => _showRoomMilestoneInfo(
                              context,
                              currentLevel: state.level,
                              targetLevel: f.level,
                              name: f.name,
                              description: f.description,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _HearthCircleLink(
                  count: state.hearthCircleCodes.length,
                  active: state.quietCompanyActive,
                  onTap: () {
                    Sfx.instance.play('tick');
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HearthCircleScreen(
                          state: state,
                          onPersist: onPersist,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── the build shape ──────────────────────────────────────
          GlassPanel(
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'YOUR BUILD',
                      style: Type.label.copyWith(fontSize: 11),
                    ),
                    const Spacer(),
                    const DomainLegendButton(),
                  ],
                ),
                const SizedBox(height: 8),
                // The engraved six-domain measure leads, exactly as it does on
                // Quests and in the approved target. The radar follows as the
                // shape of the same numbers — before this the panel opened on a
                // diagram with three unlabelled colour blocks floating round it.
                _InsetSection(
                  child: StatChips(
                    values: state.stats,
                    reduceMotion: state.reduceMotion,
                  ),
                ),
                const SizedBox(height: 12),
                Center(child: StatRadar(values: state.stats)),
                const SizedBox(height: 10),
                for (final s in Stat.values)
                  _StatRow(
                    stat: s,
                    value: state.stats[s] ?? 0,
                    noteCount: state.notesFor(s).length,
                    onOpen: () {
                      Sfx.instance.play('tick');
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DomainDetailScreen(
                            stat: s,
                            state: state,
                            quests: quests,
                            onPersist: onPersist,
                            onAddQuest: onAddQuest,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ShareButton(state: state, quests: quests),
          const SizedBox(height: 14),

          // ── recent gains (near the build — both are your progress) ──
          _ledgerPanel(),
          const SizedBox(height: 14),

          // ── trophy case ──────────────────────────────────────────
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'TROPHY CASE',
                      style: Type.label.copyWith(fontSize: 11),
                    ),
                    const Spacer(),
                    Text(
                      '${state.unlockedAchievements.length} / ${achievements.length}',
                      style: Type.numerals.copyWith(
                        fontSize: 12,
                        color: Palette.xp,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final a in achievements)
                      _TrophyTile(
                        achievement: a,
                        unlocked: state.unlockedAchievements.contains(a.id),
                        closest: a.id == _closestTrophyId(state),
                        progress: state.unlockedAchievements.contains(a.id)
                            ? null
                            : a.progress?.call(state),
                        flameHue: flameHueFor(state),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── wardrobe: owned skins + locked silhouettes (DESIGN §7)
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('WARDROBE', style: Type.label.copyWith(fontSize: 11)),
                    const Spacer(),
                    Text(
                      '${state.collectedLoot.length}/${cosmetics.length}',
                      style: Type.numerals.copyWith(
                        fontSize: 12,
                        color: Palette.xp,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  state.collectedLoot.isEmpty
                      ? 'empty slots wait for drops and trophies — keep earning Glimmers'
                      : 'skins you’ve found — tap to try on; silhouettes wait for the rest',
                  style: Type.body.copyWith(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final loot
                        in state.collectedLoot.toList()..sort(
                          (a, b) => (cosmeticFor(b)?.rarity.index ?? 0)
                              .compareTo(cosmeticFor(a)?.rarity.index ?? 0),
                        ))
                      Builder(
                        builder: (_) {
                          final worn = state.equippedSkin == loot;
                          final cos = cosmeticFor(loot);
                          final tint = cos?.aura ?? Palette.unlock;
                          final rarity = cos?.rarity ?? Rarity.common;
                          final legendary = rarity == Rarity.legendary;
                          return GestureDetector(
                            onTap: () => _showSkinPreview(context, state, loot),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 300),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: facetedDecoration(
                                  cut: 6,
                                  color: tint.withValues(
                                    alpha: worn ? 0.28 : 0.10,
                                  ),
                                  borderColor: worn
                                      ? tint.withValues(alpha: 0.9)
                                      : rarityColor(
                                          rarity,
                                        ).withValues(alpha: 0.55),
                                  borderWidth: worn ? 1.4 : 1,
                                  shadows: legendary
                                      ? const [
                                          BoxShadow(
                                            color: Palette.honeyGlow,
                                            blurRadius: 10,
                                          ),
                                        ]
                                      : const [],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Transform.rotate(
                                      angle: 0.785,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        color: tint,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        loot,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Type.body.copyWith(
                                          fontSize: 13,
                                          color: Palette.textMid,
                                        ),
                                      ),
                                    ),
                                    if (worn) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        'WORN',
                                        style: Type.label.copyWith(
                                          fontSize: 11,
                                          color: tint,
                                        ),
                                      ),
                                    ] else if (legendary) ...[
                                      const SizedBox(width: 5),
                                      const Icon(
                                        Icons.auto_awesome,
                                        size: 13,
                                        color: Palette.xpLight,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    for (final entry in cosmetics.entries)
                      if (!state.collectedLoot.contains(entry.key))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: facetedDecoration(
                            cut: 6,
                            color: Palette.glassFill,
                            borderColor: Palette.glassEdge.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.rotate(
                                angle: 0.785,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  color: Palette.textLo.withValues(alpha: 0.35),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '???',
                                style: Type.body.copyWith(
                                  fontSize: 13,
                                  color: Palette.textLo.withValues(alpha: 0.55),
                                ),
                              ),
                              if (entry.value.rarity != Rarity.common) ...[
                                const SizedBox(width: 4),
                                Text(
                                  entry.value.rarity == Rarity.legendary
                                      ? 'LEGEND'
                                      : 'RARE',
                                  style: Type.label.copyWith(
                                    fontSize: 9,
                                    color: rarityColor(
                                      entry.value.rarity,
                                    ).withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── settings (demoted below the identity content) ────────
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6, bottom: 8),
            child: Text(
              'SETTINGS',
              style: Type.label.copyWith(fontSize: 11, color: Palette.textLo),
            ),
          ),
          _themesPanel(),
          const SizedBox(height: 14),
          _soundPanel(),
          const SizedBox(height: 14),
          _remindersPanel(context),
          const SizedBox(height: 14),

          // ── account (sync across devices) ─────────────────────────
          _AccountPanel(
            onEnableCloud: onEnableCloud,
            onLink: onLinkAccount,
            onSignIn: onSignIn,
            onSignOut: onSignOut,
            onDeleteAccount: onDeleteAccount,
          ),
          const SizedBox(height: 14),

          // ── your data is yours ───────────────────────────────────
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR SAVE IS YOURS',
                  style: Type.label.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your save stays under your control. For a copy nothing can '
                  'touch — even cloud backup — stash a manual one too.',
                  style: Type.body.copyWith(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DataButton(
                      label: 'STASH A COPY',
                      icon: Icons.upload_outlined,
                      onTap: () async {
                        final ok = await onExport();
                        if (!context.mounted) return;
                        Sfx.instance.play(ok ? 'streak' : 'boing');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Palette.card,
                            content: Text(
                              ok
                                  ? 'Copied — stash it somewhere safe.'
                                  : 'Nothing to stash yet — go earn some XP.',
                              style: Type.body.copyWith(color: Palette.textHi),
                            ),
                          ),
                        );
                      },
                    ),
                    _DataButton(
                      label: 'RESTORE',
                      icon: Icons.download_outlined,
                      onTap: () {
                        Sfx.instance.play('tick');
                        showDialog(
                          context: context,
                          barrierColor: const Color(0xCC140C06),
                          builder: (_) => _RestoreDialog(onImport: onImport),
                        );
                      },
                    ),
                    // round-21: the on-device usage log, for the owner to hand
                    // to Claude for improvement ideas. Stored locally only,
                    // never uploaded — copied out only when you choose to.
                    _DataButton(
                      label: 'USAGE LOG',
                      icon: Icons.insights_outlined,
                      onTap: () async {
                        final raw = await Storage.usageExport();
                        if (!context.mounted) return;
                        final ok = raw != null && raw.isNotEmpty;
                        if (ok) {
                          await Clipboard.setData(ClipboardData(text: raw));
                        }
                        if (!context.mounted) return;
                        Sfx.instance.play(ok ? 'streak' : 'boing');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Palette.card,
                            content: Text(
                              ok
                                  ? 'Usage log copied to your clipboard — it never leaves your device.'
                                  : 'No usage logged yet — check back after a few days.',
                              style: Type.body.copyWith(color: Palette.textHi),
                            ),
                          ),
                        );
                      },
                    ),
                    _DataButton(
                      label: 'PRIVACY',
                      icon: Icons.privacy_tip_outlined,
                      onTap: () => _openPolicyPage(context, _privacyUrl),
                    ),
                    _DataButton(
                      label: 'DELETE HELP',
                      icon: Icons.person_remove_outlined,
                      onTap: () => _openPolicyPage(context, _deletionUrl),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListenableBuilder(
                  listenable: CloudSync.instance,
                  builder: (_, _) {
                    final cloud = CloudSync.instance;
                    return Row(
                      children: [
                        Icon(
                          cloud.ready
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off_outlined,
                          size: 13,
                          color: cloud.ready ? Palette.success : Palette.textLo,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            cloud.ready
                                ? 'cloud backup · ${cloud.status}'
                                : cloud.available
                                ? 'device-only · optional backup is off'
                                : 'device-only · cloud unavailable',
                            style: Type.body.copyWith(
                              fontSize: 11,
                              color: Palette.textLo,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const _CorruptRecovery(),
                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onTap: () => _confirmReset(context),
                    child: Text(
                      'start over',
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: const Color(0xFFE89090).withValues(alpha: 0.7),
                      ),
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

  /// One tap must never erase a life. Reset asks twice — in words.
  // ── recent gains (kept near the build — both are your progress) ──
  Widget _ledgerPanel() {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RECENT GAINS', style: Type.label.copyWith(fontSize: 11)),
          const SizedBox(height: 10),
          if (state.ledger.isEmpty)
            Text(
              'Complete a quest and your story starts here.',
              style: Type.body.copyWith(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            )
          else
            for (final e in state.ledger)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      '+${e.amount} ${e.stat.abbr}',
                      style: Type.numerals.copyWith(
                        fontSize: 13,
                        color: e.stat.color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.title,
                        overflow: TextOverflow.ellipsis,
                        style: Type.body.copyWith(
                          fontSize: 13,
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

  // ── settings panels (grouped at the bottom; the page leads with identity) ──
  Widget _themesPanel() {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('THEMES', style: Type.label.copyWith(fontSize: 11)),
              const Spacer(),
              if (state.level < 5)
                Row(
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 12,
                      color: Palette.textLo,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'LV 5',
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            state.level < 5
                ? 'pick your candlelit canvas — opens at level 5'
                : 'pick the night you build by',
            style: Type.body.copyWith(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Palette.textLo,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in canvasThemes)
                _ThemeSwatch(
                  theme: t,
                  selected: state.canvasTheme == t.id,
                  locked: t.locked && state.level < 5,
                  onTap: () {
                    if (t.locked && state.level < 5) {
                      Sfx.instance.play('boing');
                      return;
                    }
                    Sfx.instance.play('tick');
                    HapticFeedback.selectionClick();
                    state.setTheme(t.id);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _soundPanel() {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SOUND · MOTION · TEXT',
                style: Type.label.copyWith(fontSize: 11),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          _toggleRow(
            icon: Icons.volume_up_outlined,
            label: 'Sound effects',
            value: state.soundEnabled,
            onChanged: (v) {
              state.setSound(v);
              Sfx.instance.soundEnabled = v;
              if (v) Sfx.instance.play('tick');
              onPersist();
            },
          ),
          const SizedBox(height: 6),
          _toggleRow(
            icon: Icons.reduce_capacity_outlined,
            label: 'Reduce motion',
            subtitle: 'swap particles for fades',
            value: state.reduceMotion,
            onChanged: (v) {
              state.setReduceMotion(v);
              Haptics.reduceMotion = v;
              onPersist();
            },
          ),
          const SizedBox(height: 12),
          _textSizeRow(),
        ],
      ),
    );
  }

  /// Accessibility text sizing — an in-app control (on top of the phone's own
  /// Text Size setting) so larger type is discoverable without leaving the app.
  Widget _textSizeRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.format_size, size: 16, color: Palette.textLo),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Text size',
                style: Type.label.copyWith(fontSize: 12, color: Palette.textHi),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // the control itself never scales — the 'A' sizes are literal previews
        MediaQuery.withNoTextScaling(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final p in textScalePresets)
                _textSizeChip(
                  p.$1,
                  p.$2,
                  selected: (state.textScale - p.$2).abs() < 0.001,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _textSizeChip(String label, double value, {required bool selected}) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Text size $label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          state.setTextScale(value);
          appTextScale.value = value;
          Haptics.tap();
          onPersist();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 40,
              alignment: Alignment.center,
              decoration: facetedDecoration(
                cut: 8,
                color: selected
                    ? Palette.xp.withValues(alpha: 0.16)
                    : Palette.glassFill,
                borderColor: selected
                    ? Palette.xp.withValues(alpha: 0.6)
                    : Palette.glassEdge,
              ),
              child: Text(
                'A',
                style: Type.numerals.copyWith(
                  // 12 → ~20pt so each chip previews its own scale
                  fontSize: 12 + (value - 1.0) * 16,
                  color: selected ? Palette.xp : Palette.textMid,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Type.label.copyWith(
                fontSize: 9,
                color: selected ? Palette.xp : Palette.textLo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Palette.textLo),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Type.label.copyWith(fontSize: 12, color: Palette.textHi),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: Type.body.copyWith(
                    fontSize: 10,
                    color: Palette.textLo,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        GlassSwitch(value: value, onChanged: onChanged, semanticLabel: label),
      ],
    );
  }

  Widget _remindersPanel(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('REMINDERS', style: Type.label.copyWith(fontSize: 11)),
              const Spacer(),
              if (kIsWeb)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: facetedDecoration(
                    cut: 6,
                    color: Palette.glassFill,
                    borderColor: Palette.glassEdge,
                  ),
                  child: Text(
                    'NATIVE APP',
                    style: Type.label.copyWith(fontSize: 11),
                  ),
                )
              else
                GlassSwitch(
                  value: state.notifyEnabled,
                  semanticLabel: 'Reminders',
                  onChanged: (v) async {
                    if (v) {
                      final granted = await Notifications.requestPermission();
                      if (!context.mounted) return;
                      if (!granted) {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                            const SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Palette.card,
                              content: Text(
                                'Reminders stayed off — allow notifications '
                                'in system settings when you’re ready.',
                              ),
                            ),
                          );
                        return;
                      }
                    }
                    state.setNotify(enabled: v);
                    await onNotifyChanged();
                  },
                ),
            ],
          ),
          Text(
            kIsWeb
                ? 'Daily nudges and plan reminders are available in the iOS and Android apps.'
                : 'a daily nudge for your first quest, plus reminders for dated plans',
            style: Type.body.copyWith(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Palette.textLo,
            ),
          ),
          if (state.notifyEnabled) ...[
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: state.notifyHour,
                    minute: state.notifyMinute,
                  ),
                );
                if (picked == null) return;
                state.setNotify(hour: picked.hour, minute: picked.minute);
                await onNotifyChanged();
              },
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Palette.xpLight),
                  const SizedBox(width: 8),
                  Text(
                    'Daily nudge at',
                    style: Type.body.copyWith(
                      fontSize: 13,
                      color: Palette.textMid,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: facetedDecoration(
                      cut: 7,
                      color: Colors.transparent,
                      borderColor: Palette.glassEdge,
                    ),
                    child: Text(
                      _fmtTime(state.notifyHour, state.notifyMinute),
                      style: Type.numerals.copyWith(
                        fontSize: 14,
                        color: Palette.xp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    Sfx.instance.play('tick');
    showDialog(
      context: context,
      barrierColor: const Color(0xCC140C06),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassPanel(
          tint: const Color(0xF22A211D),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 26,
                color: Palette.streak,
              ),
              const SizedBox(height: 10),
              Text(
                'Start completely over?',
                style: Type.display.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                'Level ${state.level}, ${state.totalXp} XP, every goal and '
                'trophy — gone for good. Your cloud save and shared space go '
                'too. Guest profiles are deleted; a linked sign-in stays '
                'until you use Delete account. Copy a backup first if unsure.',
                textAlign: TextAlign.center,
                style: Type.body.copyWith(
                  fontSize: 13.5,
                  color: Palette.textMid,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: facetedDecoration(
                        cut: 8,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFF6D9A2),
                            Color(0xFFEFC074),
                            Color(0xFFC08B4F),
                          ],
                        ),
                      ),
                      child: Text(
                        'KEEP MY PROGRESS',
                        style: Type.label.copyWith(
                          fontSize: 11,
                          color: const Color(0xFF3A2510),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Sfx.instance.play('boing');
                      onReset();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: facetedDecoration(
                        cut: 8,
                        color: Colors.transparent,
                        borderColor: const Color(
                          0xFFE89090,
                        ).withValues(alpha: 0.6),
                      ),
                      child: Text(
                        'ERASE EVERYTHING',
                        style: Type.label.copyWith(
                          fontSize: 11,
                          color: const Color(0xFFE89090),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "why this works" popup (RESEARCH-momentum.md §7) — the signature
/// stats-grow-with-evidence principle, reachable right from a stat row.
/// 24h hour/minute → a friendly 12-hour clock label ("9:00 AM").
String _fmtTime(int hour, int minute) {
  final ampm = hour < 12 ? 'AM' : 'PM';
  var h = hour % 12;
  if (h == 0) h = 12;
  return '$h:${minute.toString().padLeft(2, '0')} $ampm';
}

/// Room milestones used to look like controls but were inert. They now explain
/// the earned landmark and the exact progress remaining.
void _showRoomMilestoneInfo(
  BuildContext context, {
  required int currentLevel,
  required int targetLevel,
  required String name,
  required String description,
}) {
  final unlocked = currentLevel >= targetLevel;
  final remaining = (targetLevel - currentLevel).clamp(0, targetLevel);
  final progress = (currentLevel / targetLevel).clamp(0.0, 1.0);
  Sfx.instance.play('tick');
  showDialog(
    context: context,
    barrierColor: const Color(0xCC140C06),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: GlassPanel(
        tint: const Color(0xF22A211D),
        glow: unlocked,
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FacetMedallion(
              size: 64,
              accent: unlocked ? Palette.xpLight : Palette.streak,
              glow: unlocked,
              child: unlocked
                  ? MorrowTapestryGlyph(
                      level: currentLevel,
                      lit: true,
                      reduceMotion: true,
                      size: 42,
                    )
                  : const Icon(
                      Icons.lock_outline,
                      size: 30,
                      color: Palette.streak,
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              name.toUpperCase(),
              textAlign: TextAlign.center,
              style: Type.display.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Type.body.copyWith(fontSize: 14, color: Palette.textMid),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: Palette.textLo.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation(
                  unlocked ? Palette.success : Palette.streak,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              unlocked
                  ? 'UNLOCKED AT LEVEL $targetLevel ✓'
                  : 'LEVEL $currentLevel / $targetLevel · '
                        '$remaining ${remaining == 1 ? 'LEVEL' : 'LEVELS'} TO GO',
              textAlign: TextAlign.center,
              style: Type.label.copyWith(
                fontSize: 11,
                color: unlocked ? Palette.success : Palette.streak,
              ),
            ),
            if (!unlocked) ...[
              const SizedBox(height: 9),
              Text(
                'Complete quests, earn XP, and reach level $targetLevel.',
                textAlign: TextAlign.center,
                style: Type.body.copyWith(fontSize: 12, color: Palette.textLo),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Tap a trophy to learn what it is, how to earn it, and what it grants.
void _showAchievementInfo(
  BuildContext context,
  Achievement a,
  bool unlocked,
  (int, int)? progress,
  Color flameHue,
) {
  Sfx.instance.play('tick');
  showDialog(
    context: context,
    barrierColor: const Color(0xCC140C06),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: GlassPanel(
        tint: const Color(0xF22A211D),
        glow: unlocked,
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FacetMedallion(
              size: 64,
              accent: unlocked ? Palette.xpLight : Palette.textLo,
              glow: unlocked,
              child: emberkeepIcon(
                unlocked ? a.icon : Icons.lock_outline,
                size: 30,
                color: unlocked ? Palette.xpLight : Palette.textLo,
                flameHue: flameHue,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              a.title,
              textAlign: TextAlign.center,
              style: Type.display.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              a.desc,
              textAlign: TextAlign.center,
              style: Type.body.copyWith(fontSize: 14, color: Palette.textMid),
            ),
            const SizedBox(height: 14),
            Text(
              unlocked
                  ? 'UNLOCKED ✓'
                  : progress != null
                  ? '${progress.$1} / ${progress.$2}'
                  : 'LOCKED',
              style: Type.label.copyWith(
                fontSize: 12,
                color: unlocked ? Palette.success : Palette.textLo,
              ),
            ),
            if (a.cosmetic != null) ...[
              const SizedBox(height: 12),
              Text(
                'EARNS THE ${a.cosmetic!.toUpperCase()} SKIN',
                textAlign: TextAlign.center,
                style: Type.label.copyWith(fontSize: 11, color: Palette.unlock),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Try-on a skin before wearing it: a big portrait shows the aura live, with
/// the rarity + flavor and a wear/take-off toggle (customization you can see).
void _showSkinPreview(BuildContext context, GameState state, String loot) {
  final cos = cosmeticFor(loot);
  final tint = cos?.aura ?? Palette.unlock;
  final rarity = cos?.rarity ?? Rarity.common;
  Sfx.instance.play('tick');
  showDialog(
    context: context,
    barrierColor: const Color(0xCC140C06),
    builder: (dialogCtx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: ListenableBuilder(
        listenable: state,
        builder: (_, _) {
          final worn = state.equippedSkin == loot;
          return GlassPanel(
            tint: const Color(0xF22A211D),
            glow: true,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // the find, glowing in your space
                SizedBox(
                  height: 150,
                  child: HomeRoom(
                    lively: !state.reduceMotion,
                    unlocked: state.ownedFurniture,
                    wall: wallColorsFor(state),
                    plateId: state.wallStyle,
                    floor: floorColorsFor(state),
                    window: state.windowScene,
                    petAwake: true,
                    emberGlow: tint,
                    level: state.level,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  loot,
                  textAlign: TextAlign.center,
                  style: Type.display.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  rarity.name.toUpperCase(),
                  style: Type.label.copyWith(
                    fontSize: 11,
                    color: rarityColor(rarity),
                  ),
                ),
                if (cos?.blurb != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    cos!.blurb!,
                    textAlign: TextAlign.center,
                    style: Type.body.copyWith(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Palette.textMid,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Sfx.instance.play(worn ? 'tick' : 'streak');
                    HapticFeedback.selectionClick();
                    state.equipSkin(loot);
                    Navigator.of(dialogCtx).pop();
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 11,
                    ),
                    decoration: facetedDecoration(
                      cut: 9,
                      gradient: worn
                          ? null
                          : LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                tint.withValues(alpha: 0.92),
                                tint.withValues(alpha: 0.6),
                              ],
                            ),
                      borderColor: worn
                          ? Palette.glassEdge
                          : Colors.transparent,
                      shadows: worn
                          ? const []
                          : [
                              BoxShadow(
                                color: tint.withValues(alpha: 0.4),
                                blurRadius: 16,
                              ),
                            ],
                    ),
                    child: Text(
                      worn ? 'TAKE IT OFF' : 'WEAR THIS',
                      style: Type.label.copyWith(
                        fontSize: 12,
                        color: worn ? Palette.textLo : const Color(0xFF2A211D),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// One stat as a row: dot, name, rank title, value, and a thin bar toward
/// the next tier — makes each attribute feel like its own little ladder.
/// A small icon+label text link for the Share / Visit space actions.
class _SpaceLink extends StatelessWidget {
  const _SpaceLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Palette.xpLight),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Type.label.copyWith(fontSize: 11, color: Palette.xpLight),
            ),
          ),
        ],
      ),
    );
  }
}

class _HearthCircleLink extends StatelessWidget {
  const _HearthCircleLink({
    required this.count,
    required this.active,
    required this.onTap,
  });
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: facetedDecoration(
        cut: 8,
        color: active
            ? Palette.unlock.withValues(alpha: 0.12)
            : Palette.glassFill,
        borderColor: active
            ? Palette.unlock.withValues(alpha: 0.48)
            : Palette.glassEdge,
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.hourglass_top : Icons.people_outline,
            size: 16,
            color: active ? Palette.unlock : Palette.xpLight,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              active
                  ? 'QUIET COMPANY IS HERE'
                  : count == 0
                  ? 'BEGIN A CIRCLE'
                  : 'CIRCLE · $count ${count == 1 ? 'SPACE' : 'SPACES'}',
              style: Type.label.copyWith(
                fontSize: 10,
                color: active ? Palette.unlock : Palette.xpLight,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, size: 17, color: Palette.textLo),
        ],
      ),
    ),
  );
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.stat,
    required this.value,
    required this.noteCount,
    required this.onOpen,
  });
  final Stat stat;
  final int value;

  /// How many journal entries this domain holds — a small ✎ count appears when
  /// >0, so people discover the base page and feel their writing accumulate.
  final int noteCount;

  /// Opens this domain's "base" page (growth + journal + quests + evidence).
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final rank = rankFor(stat, value);
    final toNext = toNextTier(value);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          children: [
            // shares its tag with the domain base header, so the dot flies in
            // when you open the page — a spatial "this row → that room" cue
            Hero(
              tag: 'domainDot-${stat.index}',
              child: Transform.rotate(
                angle: 0.785,
                child: Container(width: 8, height: 8, color: stat.color),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  stat.abbr,
                  maxLines: 1,
                  style: Type.label.copyWith(fontSize: 11, color: stat.color),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          rank.label,
                          overflow: TextOverflow.ellipsis,
                          style: Type.body.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Palette.textHi,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$value',
                        style: Type.numerals.copyWith(
                          fontSize: 12,
                          color: stat.color,
                        ),
                      ),
                      if (toNext != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '· +$toNext',
                          style: Type.label.copyWith(fontSize: 11),
                        ),
                      ],
                      // a small ✎ count when this domain holds journal entries —
                      // the writing made visible, and a nudge to open the base
                      if (noteCount > 0) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.auto_stories_outlined,
                          size: 12,
                          color: stat.color.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$noteCount',
                          style: Type.label.copyWith(
                            fontSize: 11,
                            color: stat.color,
                          ),
                        ),
                      ],
                      // opens the domain's "base" — growth, journal, quests,
                      // and the "why this matters" evidence in one place
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Palette.textLo,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  FacetedMeter(
                    value: rankProgress(value),
                    height: 4,
                    background: Palette.railTrack,
                    color: stat.color,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.state, required this.quests});
  final GameState state;
  final List<Quest> quests;

  String _buildSummary() {
    final stats = Stat.values
        .where((s) => (state.stats[s] ?? 0) > 0)
        .map((s) => '${s.abbr} ${state.stats[s]}')
        .join(' · ');
    return '⚔️ ${state.buildTitle} — Level ${state.level}\n'
        '${stats.isEmpty ? "a brand-new adventurer" : stats}\n'
        '${state.totalXp} XP of real life, and counting. — Morrowloom';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.instance.play('tick');
        HapticFeedback.selectionClick();
        showDialog(
          context: context,
          barrierColor: const Color(0xCC140C06),
          builder: (_) => _ShareCardDialog(
            state: state,
            summary: _buildSummary(),
            memoryArtifacts: memoryArtifactCount(state, quests),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        decoration: facetedDecoration(
          cut: 9,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6D9A2), Color(0xFFEFC074), Color(0xFFC08B4F)],
          ),
          shadows: const [
            BoxShadow(
              color: Palette.honeyGlow,
              blurRadius: 18,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.ios_share, size: 15, color: Color(0xFF3A2510)),
            const SizedBox(width: 7),
            Text(
              'SHARE MY BUILD',
              style: Type.label.copyWith(
                fontSize: 11,
                color: const Color(0xFF3A2510),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The share card — pretty enough to screenshot, and now exportable: SHARE
/// IMAGE captures the card to a PNG and hands it to the native share sheet
/// (or downloads it), COPY AS TEXT copies the summary line.
class _ShareCardDialog extends StatefulWidget {
  const _ShareCardDialog({
    required this.state,
    required this.summary,
    required this.memoryArtifacts,
  });
  final GameState state;
  final String summary;
  final int memoryArtifacts;

  @override
  State<_ShareCardDialog> createState() => _ShareCardDialogState();
}

class _ShareCardDialogState extends State<_ShareCardDialog> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  Future<void> _shareImage() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final ok =
          data != null &&
          await sharePng(
            data.buffer.asUint8List(),
            'morrowloom-build.png',
            widget.summary,
          );
      if (!mounted) return;
      Sfx.instance.play(ok ? 'streak' : 'boing');
      if (ok) {
        Navigator.of(context).pop();
        return;
      }
      // nothing could share/download (native build) → fall back to text
      setState(() => _busy = false);
      _copyText();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _copyText();
    }
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: widget.summary));
    Sfx.instance.play('streak');
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        content: Text(
          'Build copied — go show it off.',
          style: Type.body.copyWith(color: Palette.textHi),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // captured to PNG — keep the whole card inside the boundary
          RepaintBoundary(
            key: _cardKey,
            child: GlassPanel(
              tint: const Color(0xF22A211D),
              glow: true,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The shared card's hero shot: the space and permanent
                  // tapestry progress the player has built.
                  ClipPath(
                    clipper: const FacetedClipper(cut: 14),
                    child: SizedBox(
                      height: 140,
                      child: HomeRoom(
                        lively: !state.reduceMotion,
                        unlocked: state.ownedFurniture,
                        wall: wallColorsFor(state),
                        plateId: state.wallStyle,
                        floor: floorColorsFor(state),
                        window: state.windowScene,
                        petAwake: true,
                        emberGlow: flameHueFor(state),
                        heirloomFlame: state.creatureSkin == 'gilded',
                        level: state.level,
                        memoryArtifacts: widget.memoryArtifacts,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.buildTitle,
                    style: Type.display.copyWith(
                      fontSize: 24,
                      color: state.dominantStat?.color ?? Palette.xpLight,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'LEVEL ${state.level}',
                    style: Type.label.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  StatRadar(values: state.stats, size: 170),
                  const SizedBox(height: 6),
                  Text(
                    '${state.totalXp} XP of real life',
                    style: Type.body.copyWith(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Palette.textLo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MorrowTapestryGlyph(
                        level: state.level,
                        lit: state.streakDays > 0,
                        reduceMotion: true,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'MORROWLOOM',
                        style: Type.label.copyWith(
                          fontSize: 11,
                          color: Palette.textLo,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _shareImage,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: facetedDecoration(
                    cut: 9,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFF6D9A2),
                        Color(0xFFEFC074),
                        Color(0xFFC08B4F),
                      ],
                    ),
                    shadows: const [
                      BoxShadow(
                        color: Palette.honeyGlow,
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.ios_share,
                        size: 13,
                        color: Color(0xFF3A2510),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _busy ? 'SAVING…' : 'SHARE IMAGE',
                        style: Type.label.copyWith(
                          fontSize: 11,
                          color: const Color(0xFF3A2510),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _copyText,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: facetedDecoration(
                    cut: 9,
                    color: Palette.glassFill,
                    borderColor: Palette.glassEdge,
                  ),
                  child: Text(
                    'COPY TEXT',
                    style: Type.label.copyWith(
                      fontSize: 11,
                      color: Palette.textHi,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The locked trophy closest to earning (highest progress fraction among
/// those with a threshold) — gets a gentle "so close" highlight.
String? _closestTrophyId(GameState s) {
  String? best;
  var bestFrac = 0.0;
  for (final a in achievements) {
    if (s.unlockedAchievements.contains(a.id) || a.progress == null) continue;
    final (cur, target) = a.progress!(s);
    if (target <= 0) continue;
    final frac = cur / target;
    if (frac > bestFrac && frac < 1.0) {
      bestFrac = frac;
      best = a.id;
    }
  }
  // only highlight when genuinely close (≥40% there)
  return bestFrac >= 0.4 ? best : null;
}

class _TrophyTile extends StatelessWidget {
  const _TrophyTile({
    required this.achievement,
    required this.unlocked,
    required this.flameHue,
    this.closest = false,
    this.progress,
  });
  final Achievement achievement;
  final bool unlocked;
  final Color flameHue;
  final bool closest;
  final (int, int)? progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final showProgress = !unlocked && p != null && p.$1 > 0 && p.$1 < p.$2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showAchievementInfo(
        context,
        achievement,
        unlocked,
        progress,
        flameHue,
      ),
      child: Tooltip(
        message: achievement.desc,
        textStyle: Type.body.copyWith(fontSize: 11, color: Palette.textHi),
        decoration: facetedDecoration(color: Palette.card, cut: 8),
        child: SizedBox(
          width: 78,
          child: Column(
            children: [
              FacetMedallion(
                size: 46,
                accent: unlocked
                    ? Palette.xpLight
                    : closest
                    ? Palette.streak
                    : Palette.textLo,
                glow: unlocked,
                child: emberkeepIcon(
                  unlocked ? achievement.icon : Icons.lock_outline,
                  size: 20,
                  color: unlocked
                      ? Palette.xpLight
                      : closest
                      ? Palette.streak
                      : Palette.textLo.withValues(alpha: 0.6),
                  flameHue: flameHue,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                achievement.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Type.label.copyWith(
                  fontSize: 11,
                  color: unlocked
                      ? Palette.textMid
                      : Palette.textLo.withValues(alpha: 0.7),
                ),
              ),
              if (showProgress) ...[
                const SizedBox(height: 2),
                Text(
                  '${p.$1}/${p.$2}',
                  style: Type.numerals.copyWith(
                    fontSize: 11,
                    color: closest
                        ? Palette.streak
                        : Palette.textLo.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A candlelit theme swatch — its canvas gradient under a glow dot, ringed
/// when worn, dimmed-with-lock until the Lv-5 unlock.
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.locked,
    required this.onTap,
  });
  final CanvasTheme theme;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 78,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 44,
              decoration: facetedDecoration(
                cut: 8,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [theme.top, theme.bottom],
                ),
                borderColor: selected
                    ? Palette.xpLight.withValues(alpha: 0.9)
                    : Palette.glassEdge,
                borderWidth: selected ? 1.8 : 1,
                shadows: selected
                    ? const [
                        BoxShadow(color: Palette.honeyGlow, blurRadius: 12),
                      ]
                    : const [],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            theme.glows[0].withValues(alpha: 1),
                            theme.glows[0].withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (locked)
                    const Center(
                      child: Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: Palette.textLo,
                      ),
                    ),
                  if (selected)
                    const Positioned(
                      right: 4,
                      bottom: 4,
                      child: Icon(
                        Icons.check_circle,
                        size: 13,
                        color: Palette.xpLight,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              theme.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Type.label.copyWith(
                fontSize: 11,
                color: selected ? Palette.xpLight : Palette.textLo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glimmers and the way into the complete-room chooser, on their own brass rail above the
/// nameplate — the arrangement the approved Me target uses.
class _SpaceRail extends StatelessWidget {
  const _SpaceRail({required this.embers, required this.onChangeSpace});
  final int embers;
  final VoidCallback onChangeSpace;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open room chooser. $embers Glimmers available.',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChangeSpace,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        // A pane is darker than the lit art behind it (DESIGN-BIBLE), so this is
        // opaque warm glass, not a film — a translucent rail let the room's own
        // light and anything beneath it read straight through.
        decoration: facetedDecoration(
          cut: 10,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xF02A211B), Color(0xF61A130F)],
          ),
          borderColor: Palette.brass.withValues(alpha: 0.52),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Palette.xp, size: 17),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '$embers GLIMMERS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Type.label.copyWith(
                  fontSize: 11.5,
                  letterSpacing: 1.5,
                  color: Palette.textMid,
                ),
              ),
            ),
            const SizedBox(width: 10),
            HoneyButton(
              label: 'CHANGE SPACE',
              icon: Icons.meeting_room_outlined,
              fontSize: 10.5,
              glow: false,
              onTap: onChangeSpace,
            ),
          ],
        ),
      ),
    ),
  );
}

/// The engraved flourish at the head of the nameplate: a hairline rule out to
/// each side of a small brass star. It is what turns a stack of centred text
/// into something struck onto a plate.
class _PlateOrnament extends StatelessWidget {
  const _PlateOrnament();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: _OrnamentRule(flip: false)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: const Icon(
          Icons.auto_awesome_rounded,
          color: Palette.xp,
          size: 15,
        ),
      ),
      const Expanded(child: _OrnamentRule(flip: true)),
    ],
  );
}

class _OrnamentRule extends StatelessWidget {
  const _OrnamentRule({required this.flip});
  final bool flip;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: flip ? Alignment.centerRight : Alignment.centerLeft,
        end: flip ? Alignment.centerLeft : Alignment.centerRight,
        colors: [
          Palette.brass.withValues(alpha: 0),
          Palette.brass.withValues(alpha: 0.75),
        ],
      ),
    ),
  );
}

/// A shallow well cut into a panel, for a measure or a row of seals. It gives
/// the nested content its own edge so a long page reads as one composed plate
/// instead of a column of same-weight modules.
class _InsetSection extends StatelessWidget {
  const _InsetSection({required this.child, this.label});
  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(11, label == null ? 6 : 9, 11, 9),
    decoration: facetedDecoration(
      cut: 9,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x2E1A120D), Color(0x4D110C09)],
      ),
      borderColor: Palette.brass.withValues(alpha: 0.30),
      borderWidth: 0.9,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: Type.label.copyWith(fontSize: 10.5, color: Palette.textLo),
          ),
          const SizedBox(height: 9),
        ],
        child,
      ],
    ),
  );
}

class _LockedSlot extends StatelessWidget {
  const _LockedSlot({required this.label, this.unlocked = false, this.onTap});
  final String label;
  final bool unlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      height: 30,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: facetedDecoration(
        cut: 6,
        color: unlocked ? Palette.xp.withValues(alpha: 0.10) : null,
        borderColor: unlocked
            ? Palette.brass.withValues(alpha: 0.9)
            : Palette.textLo.withValues(alpha: 0.32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            unlocked ? Icons.check_circle_outline : Icons.lock_outline,
            size: 13,
            color: unlocked
                ? Palette.xpLight
                : Palette.textLo.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: Type.label.copyWith(
                  fontSize: 11,
                  letterSpacing: 0.7,
                  color: unlocked
                      ? Palette.xpLight
                      : Palette.textLo.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return tile;
    return Semantics(
      button: true,
      label: label,
      hint: unlocked
          ? 'Room milestone unlocked. Tap for details.'
          : 'Tap to hear what this room milestone unlocks.',
      child: Tooltip(
        message: unlocked ? 'Milestone unlocked' : 'Tap for progress',
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: tile,
          ),
        ),
      ),
    );
  }
}

/// If a corrupt save was quarantined on load, offer to recover its raw bytes
/// (copy out) or dismiss it — so the safety net is reachable, not write-only.
class _CorruptRecovery extends StatefulWidget {
  const _CorruptRecovery();

  @override
  State<_CorruptRecovery> createState() => _CorruptRecoveryState();
}

class _CorruptRecoveryState extends State<_CorruptRecovery> {
  Future<String?>? _backup;

  @override
  void initState() {
    super.initState();
    _backup = Storage.corruptBackup();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _backup,
      builder: (context, snap) {
        final raw = snap.data;
        if (raw == null || raw.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: facetedDecoration(
              cut: 8,
              borderColor: Palette.streak.withValues(alpha: 0.5),
              color: Palette.streak.withValues(alpha: 0.08),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.healing, size: 13, color: Palette.streak),
                    const SizedBox(width: 6),
                    Text(
                      'WE CAUGHT A FALLING SAVE',
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: Palette.streak,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'An older save wouldn’t open, so we set it aside — safe and '
                  'whole. Copy it out to keep, then dismiss.',
                  style: Type.body.copyWith(
                    fontSize: 11,
                    color: Palette.textMid,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DataButton(
                      label: 'COPY IT',
                      icon: Icons.content_copy,
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: raw));
                        if (!context.mounted) return;
                        Sfx.instance.play('streak');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Palette.card,
                            content: Text(
                              'Recovered save copied',
                              style: Type.body.copyWith(color: Palette.textHi),
                            ),
                          ),
                        );
                      },
                    ),
                    _DataButton(
                      label: 'DISMISS',
                      icon: Icons.close,
                      onTap: () async {
                        await Storage.clearCorruptBackup();
                        if (mounted) {
                          setState(() => _backup = Future.value(null));
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DataButton extends StatelessWidget {
  const _DataButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Off → the button reads plainly disabled (dimmed, no tap) instead of
  /// looking live but doing nothing (the offline account buttons did that).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ink = enabled ? Palette.textMid : Palette.textLo;
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: facetedDecoration(
            cut: 8,
            borderColor: Palette.glassEdge,
            color: Palette.glassFill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: ink),
              const SizedBox(width: 6),
              Text(label, style: Type.label.copyWith(fontSize: 11, color: ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog({required this.onImport});
  final Future<bool> Function(String raw) onImport;

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  final _raw = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _raw.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await widget.onImport(_raw.text.trim());
    if (!mounted) return;
    if (!ok) {
      Sfx.instance.play('boing');
      setState(() {
        _busy = false;
        _error = 'that doesn’t look like a Morrowloom backup';
      });
      return;
    }
    Sfx.instance.play('levelup');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: GlassPanel(
        tint: const Color(0xF22A211D),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RESTORE A BACKUP', style: Type.label.copyWith(fontSize: 11)),
            const SizedBox(height: 6),
            Text(
              'this replaces what’s on this device',
              style: Type.body.copyWith(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _raw,
              maxLines: 4,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              style: Type.body.copyWith(fontSize: 11, color: Palette.textHi),
              decoration: InputDecoration(
                hintText: 'paste your backup here…',
                hintStyle: Type.body.copyWith(
                  fontSize: 13,
                  color: Palette.textLo,
                ),
                errorText: _error,
                errorStyle: Type.body.copyWith(
                  fontSize: 11,
                  color: const Color(0xFFE89090),
                ),
                filled: true,
                fillColor: Palette.glassFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Palette.glassEdge),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: _restore,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 10,
                  ),
                  decoration: facetedDecoration(
                    cut: 8,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFF6D9A2),
                        Color(0xFFEFC074),
                        Color(0xFFC08B4F),
                      ],
                    ),
                  ),
                  child: Text(
                    _busy ? 'RESTORING…' : 'RESTORE',
                    style: Type.label.copyWith(
                      fontSize: 11,
                      color: const Color(0xFF3A2510),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The account section: anonymous users see "sync across devices" with
/// create/sign-in; signed-in users see their email and a sign-out.
class _AccountPanel extends StatelessWidget {
  const _AccountPanel({
    required this.onEnableCloud,
    required this.onLink,
    required this.onSignIn,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final Future<String?> Function() onEnableCloud;
  final Future<String?> Function(String, String) onLink;
  final Future<String?> Function(String, String) onSignIn;
  final Future<void> Function() onSignOut;
  final Future<String?> Function(String) onDeleteAccount;

  Future<void> _enableBackup(BuildContext context) async {
    Sfx.instance.play('tick');
    final error = await onEnableCloud();
    if (!context.mounted) return;
    Sfx.instance.play(error == null ? 'levelup' : 'boing');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        content: Text(
          error ?? 'Cloud backup is on — your story has a second home.',
          style: Type.body.copyWith(color: Palette.textHi),
        ),
      ),
    );
  }

  void _openForm(BuildContext context, {required bool signIn}) {
    Sfx.instance.play('tick');
    showDialog(
      context: context,
      barrierColor: const Color(0xCC140C06),
      builder: (_) =>
          _AccountDialog(signIn: signIn, action: signIn ? onSignIn : onLink),
    );
  }

  void _confirmSignOut(BuildContext context) {
    Sfx.instance.play('tick');
    showDialog(
      context: context,
      barrierColor: const Color(0xCC140C06),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassPanel(
          tint: const Color(0xF22A211D),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sign out?', style: Type.display.copyWith(fontSize: 18)),
              const SizedBox(height: 6),
              Text(
                'Your space and progress stay on this device — you’ll just stop '
                'syncing to your account until you sign in again. Your '
                'account’s cloud save is kept safe.',
                textAlign: TextAlign.center,
                style: Type.body.copyWith(
                  fontSize: 13.5,
                  color: Palette.textMid,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: facetedDecoration(
                        cut: 8,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFF6D9A2),
                            Color(0xFFEFC074),
                            Color(0xFFC08B4F),
                          ],
                        ),
                      ),
                      child: Text(
                        'KEEP MY PROGRESS',
                        style: Type.label.copyWith(
                          fontSize: 11,
                          color: const Color(0xFF3A2510),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      Sfx.instance.play('boing');
                      await onSignOut();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: facetedDecoration(
                        cut: 8,
                        color: Colors.transparent,
                        borderColor: Palette.textLo.withValues(alpha: 0.5),
                      ),
                      child: Text(
                        'SIGN OUT',
                        style: Type.label.copyWith(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    Sfx.instance.play('tick');
    showDialog<void>(
      context: context,
      barrierColor: Palette.dialogBarrier,
      builder: (_) => _DeleteAccountDialog(action: onDeleteAccount),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CloudSync.instance,
      builder: (context, _) {
        final email = CloudSync.instance.accountEmail;
        final signedIn = email != null;
        final cloudReady = CloudSync.instance.ready;
        final cloudAvailable = CloudSync.instance.available;
        return GlassPanel(
          glow: !signedIn && CloudSync.instance.ready,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    signedIn
                        ? Icons.verified_user
                        : cloudReady
                        ? Icons.devices
                        : Icons.phonelink_lock_outlined,
                    size: 14,
                    color: Palette.xpLight,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    signedIn
                        ? 'YOUR ACCOUNT'
                        : cloudReady
                        ? 'YOUR STORY, EVERYWHERE'
                        : 'DEVICE-ONLY BY DEFAULT',
                    style: Type.label.copyWith(fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (signedIn) ...[
                Text(
                  email,
                  style: Type.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Palette.textHi,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your story follows you to any device you sign in on.',
                  style: Type.body.copyWith(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _confirmSignOut(context),
                  child: Text(
                    'sign out',
                    style: Type.label.copyWith(
                      fontSize: 11,
                      color: Palette.textLo.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _confirmDelete(context),
                  child: Text(
                    'delete account',
                    style: Type.label.copyWith(
                      fontSize: 11,
                      color: Palette.danger.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  cloudReady
                      ? 'Cloud backup is on. Create a free account so your '
                            'space can follow you to another device.'
                      : cloudAvailable
                      ? 'Your space is only on this device. Turn on optional '
                            'backup, or sign in to an existing space.'
                      : 'Your space is safe on this device. Cloud features are '
                            'out of reach right now.',
                  style: Type.body.copyWith(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (cloudReady)
                      _DataButton(
                        label: 'CREATE ACCOUNT',
                        icon: Icons.person_add_alt,
                        enabled: true,
                        onTap: () => _openForm(context, signIn: false),
                      )
                    else if (cloudAvailable)
                      _DataButton(
                        label: 'TURN ON BACKUP',
                        icon: Icons.cloud_upload_outlined,
                        enabled: true,
                        onTap: () => _enableBackup(context),
                      ),
                    _DataButton(
                      label: 'SIGN IN',
                      icon: Icons.login,
                      enabled: cloudAvailable,
                      onTap: () => _openForm(context, signIn: true),
                    ),
                  ],
                ),
                if (!cloudAvailable) ...[
                  const SizedBox(height: 6),
                  Text(
                    '(the cloud’s out of reach — try again once you’re back online)',
                    style: Type.label.copyWith(fontSize: 11),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.action});

  final Future<String?> Function(String password) action;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy) return;
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.action(_password.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        content: Text('Account and Morrowloom data deleted.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: GlassPanel(
        tint: Palette.dialogSurface,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete account?', style: Type.display.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              'This permanently removes your sign-in, cloud backup, and shared '
              'space, plus progress and journal media on this device. Export a '
              'backup first if you want to keep a copy.',
              style: Type.body.copyWith(fontSize: 13, color: Palette.textMid),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _delete(),
              decoration: InputDecoration(
                hintText: 'password',
                errorText: _error,
                filled: true,
                fillColor: Palette.glassFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Keep account'),
                ),
                const Spacer(),
                HoneyButton(
                  label: _busy ? 'DELETING…' : 'DELETE ACCOUNT',
                  enabled: !_busy,
                  glow: false,
                  onTap: _delete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.signIn, required this.action});
  final bool signIn;
  final Future<String?> Function(String, String) action;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final pw = _pw.text;
    if (email.isEmpty || pw.isEmpty) {
      setState(() => _error = 'need both — your email and a password');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.action(email, pw);
    if (!mounted) return;
    if (err != null) {
      Sfx.instance.play('boing');
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    Sfx.instance.play('levelup');
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        content: Text(
          widget.signIn
              ? 'Signed in — welcome back.'
              : 'Account created — your story’s safe now.',
          style: Type.body.copyWith(color: Palette.textHi),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: GlassPanel(
        tint: const Color(0xF22A211D),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.signIn ? 'SIGN IN' : 'CREATE ACCOUNT',
              style: Type.label.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              widget.signIn
                  ? 'Loads your account’s space and progress onto this device, '
                        'replacing what’s here now.'
                  : 'Keeps your current progress and syncs it everywhere.',
              style: Type.body.copyWith(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              style: Type.body.copyWith(fontSize: 14, color: Palette.textHi),
              decoration: _dec('email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pw,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              style: Type.body.copyWith(fontSize: 14, color: Palette.textHi),
              decoration: _dec('password (6+ characters)', error: _error),
            ),
            const SizedBox(height: 14),
            Center(
              child: GestureDetector(
                onTap: _submit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 11,
                  ),
                  decoration: facetedDecoration(
                    cut: 9,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFF6D9A2),
                        Color(0xFFEFC074),
                        Color(0xFFC08B4F),
                      ],
                    ),
                    shadows: const [
                      BoxShadow(
                        color: Palette.honeyGlow,
                        blurRadius: 16,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    _busy
                        ? '…'
                        : widget.signIn
                        ? 'SIGN IN'
                        : 'CREATE ACCOUNT',
                    style: Type.label.copyWith(
                      fontSize: 11,
                      color: const Color(0xFF3A2510),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String hint, {String? error}) => InputDecoration(
    hintText: hint,
    hintStyle: Type.body.copyWith(fontSize: 14, color: Palette.textLo),
    errorText: error,
    errorStyle: Type.body.copyWith(
      fontSize: 11,
      color: const Color(0xFFE89090),
    ),
    filled: true,
    fillColor: Palette.glassFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Palette.glassEdge),
    ),
  );
}
