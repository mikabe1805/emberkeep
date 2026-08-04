import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../audio.dart';
import '../cloud.dart';
import '../haptics.dart';
import '../journal_media.dart' as journal_media;
import '../platform/share_stub.dart'
    if (dart.library.js_interop) '../platform/share_web.dart';
import '../content/achievements.dart';
import '../content/cosmetics.dart';
import '../content/creature_skins.dart';
import '../content/links.dart';
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

typedef SpaceRoomPublisher =
    Future<RoomPublishResult> Function(
      GameState target, {
      required String code,
    });

Future<void> _changePlayerName(
  BuildContext context,
  GameState state,
  VoidCallback onPersist,
  SpaceRoomPublisher onPublishRoom,
) async {
  var editedName = state.playerName ?? '';
  final next = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'What should we call you?',
        style: Type.display.copyWith(fontSize: 20, color: Palette.textHi),
      ),
      content: TextFormField(
        key: const ValueKey('space-name-field'),
        initialValue: editedName,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        style: Type.body.copyWith(color: Palette.textHi),
        decoration: const InputDecoration(
          labelText: 'Your name',
          hintText: 'Name or nickname',
        ),
        onChanged: (value) => editedName = value,
        onFieldSubmitted: (value) => Navigator.of(dialogContext).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(editedName),
          child: const Text('Save name'),
        ),
      ],
    ),
  );
  if (next == null || !context.mounted) return;

  final draft = GameState.fromJson(state.toJson())..setPlayerName(next);
  final code = state.roomCode;
  RoomPublishResult? published;
  if (code != null &&
      jsonEncode(roomDisplay(state)) != jsonEncode(roomDisplay(draft))) {
    final progress = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Palette.card,
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  'Updating visitor page\u2026',
                  key: const ValueKey('space-name-publish-busy'),
                  style: Type.body.copyWith(color: Palette.textHi),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    try {
      published = await onPublishRoom(draft, code: code);
    } catch (_) {
      published = const RoomPublishResult.failed(RoomPublishFailure.unknown);
    }
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    await progress;
    if (!context.mounted) return;
    if (!published.ok) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Palette.card,
            content: Text(
              'Couldn\u2019t update the live visitor page. Its previous version '
              'may still show your old name. Reconnect and try again.',
              key: const ValueKey('space-name-publish-error'),
              style: Type.body.copyWith(color: Palette.textHi),
            ),
          ),
        );
      return;
    }
  }

  state.setPlayerName(next);
  final publishedCode = published?.code;
  if (publishedCode != null && publishedCode != state.roomCode) {
    state.setRoomCode(publishedCode);
  }
  onPersist();
}

Future<void> _personalizeSpace(
  BuildContext context,
  GameState state,
  VoidCallback onPersist,
  SpaceRoomPublisher onPublishRoom,
) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _SpacePageArranger(
        state: state,
        onPersist: onPersist,
        onPublishRoom: onPublishRoom,
      ),
    ),
  );
}

String _spaceCardTitle(SpaceCardKind kind) => switch (kind) {
  SpaceCardKind.about => 'About',
  SpaceCardKind.rightNow => 'Right now',
  SpaceCardKind.pinnedMoments => 'Pinned moments',
  SpaceCardKind.thisSeason => 'This season',
};

IconData _spaceCardIcon(SpaceCardKind kind) => switch (kind) {
  SpaceCardKind.about => Icons.auto_stories_outlined,
  SpaceCardKind.rightNow => Icons.flag_outlined,
  SpaceCardKind.pinnedMoments => Icons.push_pin_outlined,
  SpaceCardKind.thisSeason => Icons.filter_vintage_outlined,
};

Color _spaceCardAccent(SpaceCardKind kind) => switch (kind) {
  SpaceCardKind.about => Palette.xp,
  SpaceCardKind.rightNow => Palette.success,
  SpaceCardKind.pinnedMoments => const Color(0xFFD29B78),
  SpaceCardKind.thisSeason => Palette.unlock,
};

/// A full-page workbench for My Space. The room itself stays the page hero;
/// this route only arranges the authored cards that sit beneath it.
class _SpacePageArranger extends StatefulWidget {
  const _SpacePageArranger({
    required this.state,
    required this.onPersist,
    required this.onPublishRoom,
  });

  final GameState state;
  final VoidCallback onPersist;
  final SpaceRoomPublisher onPublishRoom;

  @override
  State<_SpacePageArranger> createState() => _SpacePageArrangerState();
}

class _SpacePageArrangerState extends State<_SpacePageArranger> {
  late final TextEditingController _intro;
  late final TextEditingController _season;
  late final List<SpaceCardKind> _order;
  late final Set<SpaceCardKind> _hidden;
  late final Set<SpaceCardKind> _visitorVisible;
  late final Set<String> _featuredGoals;
  late final Set<String> _pinnedMoments;
  final Set<SpaceCardKind> _expanded = {SpaceCardKind.about};
  String? _profilePhotoNoteId;
  String? _seasonPhotoNoteId;
  late bool _shareProfilePhoto;
  late bool _shareSeasonPhoto;
  late bool _shared;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _intro = TextEditingController(text: widget.state.spaceIntro);
    _season = TextEditingController(text: widget.state.spaceSeasonText);
    _order = widget.state.spaceCardOrder.toList();
    for (final kind in defaultSpaceCardOrder) {
      if (!_order.contains(kind)) _order.add(kind);
    }
    _hidden = widget.state.hiddenSpaceCards.toSet();
    _visitorVisible = widget.state.visitorSpaceCards.toSet();
    _featuredGoals = widget.state.featuredGoalTitles.toSet();
    _pinnedMoments = widget.state.memoryPins.toSet();
    _profilePhotoNoteId = widget.state.spaceProfilePhotoNoteId;
    _seasonPhotoNoteId = widget.state.spaceSeasonPhotoNoteId;
    _shareProfilePhoto = widget.state.shareSpaceProfilePhoto;
    _shareSeasonPhoto = widget.state.shareSpaceSeasonPhoto;
    _shared = widget.state.shareSpaceProfile;
  }

  @override
  void dispose() {
    _intro.dispose();
    _season.dispose();
    super.dispose();
  }

  void _applyDraft(GameState target) {
    for (final note in target.journal) {
      final pinned = _pinnedMoments.contains(note.id);
      if (target.memoryPins.contains(note.id) != pinned) {
        target.setMemoryPinned(note.id, pinned);
      }
    }
    target.setSpacePage(
      order: _order,
      hidden: _hidden,
      visitorVisible: _visitorVisible,
      intro: _intro.text,
      featuredGoalTitles: _featuredGoals,
      seasonText: _season.text,
      profilePhotoNoteId: _profilePhotoNoteId,
      seasonPhotoNoteId: _seasonPhotoNoteId,
      shareProfilePhoto: _shareProfilePhoto,
      shareSeasonPhoto: _shareSeasonPhoto,
      shareProfile: _shared,
    );
  }

  void _commitDraft(GameState draft) {
    for (final note in widget.state.journal) {
      final pinned = draft.memoryPins.contains(note.id);
      if (widget.state.memoryPins.contains(note.id) != pinned) {
        widget.state.setMemoryPinned(note.id, pinned);
      }
    }
    widget.state.setSpacePage(
      order: draft.spaceCardOrder,
      hidden: draft.hiddenSpaceCards,
      visitorVisible: draft.visitorSpaceCards,
      intro: draft.spaceIntro,
      featuredGoalTitles: draft.featuredGoalTitles,
      seasonText: draft.spaceSeasonText,
      profilePhotoNoteId: draft.spaceProfilePhotoNoteId,
      seasonPhotoNoteId: draft.spaceSeasonPhotoNoteId,
      shareProfilePhoto: draft.shareSpaceProfilePhoto,
      shareSeasonPhoto: draft.shareSpaceSeasonPhoto,
      shareProfile: draft.shareSpaceProfile,
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    // Build the candidate on a listener-free clone. Mutating the live state
    // would immediately trigger AppShell's ordinary persistence listener and
    // its best-effort room debounce before the server acknowledged a privacy
    // reduction.
    final draft = GameState.fromJson(widget.state.toJson());
    _applyDraft(draft);
    final currentDisplay = roomDisplay(widget.state);
    final nextDisplay = roomDisplay(draft);
    String photoIntent(GameState state) => jsonEncode({
      for (final entry in selectedSharedRoomPhotoFiles(state).entries)
        entry.key.name: entry.value,
    });
    final code = widget.state.roomCode;
    RoomPublishResult? published;

    if (code != null &&
        (jsonEncode(currentDisplay) != jsonEncode(nextDisplay) ||
            photoIntent(widget.state) != photoIntent(draft))) {
      setState(() {
        _saving = true;
        _saveError = null;
      });
      try {
        published = await widget.onPublishRoom(draft, code: code);
      } catch (_) {
        published = const RoomPublishResult.failed(RoomPublishFailure.unknown);
      }
      if (!mounted) return;
      if (!published.ok) {
        setState(() {
          _saving = false;
          _saveError = published?.failure == RoomPublishFailure.media
              ? 'Couldn\u2019t share that photo. Choose another JPEG, PNG, or '
                    'WebP under 3 MB, then try again.'
              : 'Couldn\u2019t update the live visitor page. Its previous version '
                    'may still be visible. Reconnect and try again.';
        });
        return;
      }
    }

    _commitDraft(draft);
    final publishedCode = published?.code;
    if (publishedCode != null && publishedCode != widget.state.roomCode) {
      widget.state.setRoomCode(publishedCode);
    }
    widget.onPersist();
    Sfx.instance.play('levelup');
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.of(context).pop();
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final moved = _order.removeAt(oldIndex);
      _order.insert(newIndex, moved);
    });
    HapticFeedback.selectionClick();
  }

  void _togglePinned(String noteId) {
    setState(() {
      if (_pinnedMoments.remove(noteId)) return;
      if (_pinnedMoments.length >= 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Palette.card,
            content: Text('Choose up to four moments for this card.'),
          ),
        );
        return;
      }
      _pinnedMoments.add(noteId);
    });
  }

  List<Note> get _momentChoices {
    final newest = widget.state.journal.reversed.toList();
    final pinned = [
      for (final note in newest)
        if (_pinnedMoments.contains(note.id)) note,
    ];
    final recent = [
      for (final note in newest)
        if (!_pinnedMoments.contains(note.id)) note,
    ].take(8);
    return [...pinned, ...recent];
  }

  List<Note> get _seasonPhotoChoices => [
    for (final note in widget.state.journal.reversed)
      if (note.images.isNotEmpty) note,
  ].take(12).toList();

  Widget _editorFor(SpaceCardKind kind) => switch (kind) {
    SpaceCardKind.about => _AboutSpaceEditor(
      controller: _intro,
      notes: _seasonPhotoChoices,
      selectedNoteId: _profilePhotoNoteId,
      sharePhoto: _shareProfilePhoto,
      visitorPageEnabled: _shared,
      onPhotoChanged: (id) => setState(() {
        _profilePhotoNoteId = id;
        _shareProfilePhoto = false;
      }),
      onSharePhotoChanged: (value) =>
          setState(() => _shareProfilePhoto = value),
    ),
    SpaceCardKind.rightNow => _RightNowSpaceEditor(
      goals: widget.state.goals,
      selected: _featuredGoals,
      onChanged: (title, selected) {
        setState(() {
          if (!selected) {
            _featuredGoals.remove(title);
          } else if (_featuredGoals.length < 3) {
            _featuredGoals.add(title);
          }
        });
      },
    ),
    SpaceCardKind.pinnedMoments => _PinnedMomentsEditor(
      notes: _momentChoices,
      selected: _pinnedMoments,
      onToggle: _togglePinned,
    ),
    SpaceCardKind.thisSeason => _SeasonSpaceEditor(
      controller: _season,
      notes: _seasonPhotoChoices,
      selectedNoteId: _seasonPhotoNoteId,
      sharePhoto: _shareSeasonPhoto,
      visitorPageEnabled: _shared,
      visitorCardSelected: _visitorVisible.contains(SpaceCardKind.thisSeason),
      onPhotoChanged: (id) => setState(() {
        _seasonPhotoNoteId = id;
        _shareSeasonPhoto = false;
      }),
      onSharePhotoChanged: (value) => setState(() => _shareSeasonPhoto = value),
    ),
  };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        key: const ValueKey('space-arranger'),
        backgroundColor: Palette.parchment,
        body: SafeArea(
          child: Column(
            children: [
              _SpaceArrangerHeading(
                onClose: _saving ? null : () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: _saving,
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                    header: _SpaceSharingPanel(
                      shared: _shared,
                      onChanged: (value) => setState(() => _shared = value),
                    ),
                    itemCount: _order.length,
                    onReorderItem: _reorder,
                    proxyDecorator: (child, _, animation) => AnimatedBuilder(
                      animation: animation,
                      builder: (_, child) => Transform.scale(
                        scale: 1 + animation.value * 0.018,
                        child: Material(
                          color: Colors.transparent,
                          elevation: animation.value * 12,
                          shadowColor: Palette.warmShadow,
                          child: child,
                        ),
                      ),
                      child: child,
                    ),
                    itemBuilder: (context, index) {
                      final kind = _order[index];
                      return _SpaceArrangerCard(
                        key: ValueKey('space-card-${kind.name}'),
                        kind: kind,
                        index: index,
                        hidden: _hidden.contains(kind),
                        visitorVisible: _visitorVisible.contains(kind),
                        visitorPageEnabled: _shared,
                        expanded: _expanded.contains(kind),
                        onExpand: () => setState(() {
                          if (!_expanded.remove(kind)) _expanded.add(kind);
                        }),
                        onVisibilityChanged: () => setState(() {
                          if (!_hidden.remove(kind)) _hidden.add(kind);
                        }),
                        onVisitorVisibilityChanged: () => setState(() {
                          if (!_visitorVisible.remove(kind)) {
                            _visitorVisible.add(kind);
                          }
                        }),
                        child: _editorFor(kind),
                      );
                    },
                  ),
                ),
              ),
              _SpaceArrangerActions(
                busy: _saving,
                error: _saveError,
                onCancel: _saving ? null : () => Navigator.of(context).pop(),
                onSave: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpaceArrangerHeading extends StatelessWidget {
  const _SpaceArrangerHeading({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Palette.glassEdge)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF251A15), Color(0xFF191210)],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close without saving',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Palette.textMid),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MY SPACE',
                  style: Type.label.copyWith(
                    fontSize: 9.5,
                    letterSpacing: 1.7,
                    color: Palette.xpLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Personalize your space',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Type.display.copyWith(
                    fontSize: 21,
                    height: 1.05,
                    color: Palette.textHi,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpaceSharingPanel extends StatelessWidget {
  const _SpaceSharingPanel({required this.shared, required this.onChanged});

  final bool shared;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: facetedDecoration(
              cut: 10,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: shared
                    ? const [Color(0xFF342B1E), Color(0xFF1E2018)]
                    : const [Color(0xFF2A211D), Color(0xFF201814)],
              ),
              borderColor: shared
                  ? Palette.xp.withValues(alpha: 0.48)
                  : Palette.glassEdge,
            ),
            child: SwitchListTile.adaptive(
              key: const ValueKey('space-profile-share-toggle'),
              contentPadding: const EdgeInsets.fromLTRB(13, 6, 8, 6),
              minTileHeight: 64,
              value: shared,
              activeTrackColor: Palette.xp.withValues(alpha: 0.72),
              title: Text(
                'Open my visitor page',
                style: Type.body.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Palette.textHi,
                ),
              ),
              subtitle: Text(
                shared
                    ? 'Your name and only the cards marked for visitors appear when someone opens your room.'
                    : 'Your room can still be shared; every profile card stays private.',
                style: Type.body.copyWith(
                  fontSize: 11.5,
                  height: 1.35,
                  color: Palette.textLo,
                ),
              ),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Choose each card’s audience below. A profile or This season photo is separate: select it, then explicitly let visitors see it. Drag the brass grips to set the order.',
              style: Type.body.copyWith(
                fontSize: 11.5,
                height: 1.35,
                color: Palette.textLo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpaceArrangerCard extends StatelessWidget {
  const _SpaceArrangerCard({
    super.key,
    required this.kind,
    required this.index,
    required this.hidden,
    required this.visitorVisible,
    required this.visitorPageEnabled,
    required this.expanded,
    required this.onExpand,
    required this.onVisibilityChanged,
    required this.onVisitorVisibilityChanged,
    required this.child,
  });

  final SpaceCardKind kind;
  final int index;
  final bool hidden;
  final bool visitorVisible;
  final bool visitorPageEnabled;
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onVisibilityChanged;
  final VoidCallback onVisitorVisibilityChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final accent = _spaceCardAccent(kind);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: hidden ? 0.58 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(Palette.card, accent, 0.075)!,
              const Color(0xFF1B1411),
            ],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.34)),
          boxShadow: const [
            BoxShadow(
              color: Palette.warmShadow,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 10),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.12),
                      border: Border.all(color: accent.withValues(alpha: 0.42)),
                    ),
                    child: Icon(_spaceCardIcon(kind), size: 19, color: accent),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: onExpand,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 64),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 8,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _spaceCardTitle(kind),
                                style: Type.body.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Palette.textHi,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hidden
                                    ? 'HIDDEN FROM YOUR PAGE'
                                    : 'ON YOUR PAGE',
                                style: Type.label.copyWith(
                                  fontSize: 8.5,
                                  letterSpacing: 0.9,
                                  color: hidden ? Palette.textLo : accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('space-card-toggle-${kind.name}'),
                    tooltip: hidden ? 'Show this card' : 'Hide this card',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: onVisibilityChanged,
                    icon: Icon(
                      hidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: hidden ? Palette.textLo : accent,
                    ),
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: Semantics(
                      label: 'Move ${_spaceCardTitle(kind)} card',
                      button: true,
                      child: const SizedBox(
                        width: 48,
                        height: 56,
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: Palette.brassLit,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _VisitorScopeControl(
                kind: kind,
                selected: visitorVisible,
                visitorPageEnabled: visitorPageEnabled,
                accent: accent,
                onChanged: onVisitorVisibilityChanged,
              ),
              if (expanded)
                Container(
                  key: ValueKey('space-card-editor-${kind.name}'),
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: accent.withValues(alpha: 0.20)),
                    ),
                  ),
                  child: child,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitorScopeControl extends StatelessWidget {
  const _VisitorScopeControl({
    required this.kind,
    required this.selected,
    required this.visitorPageEnabled,
    required this.accent,
    required this.onChanged,
  });

  final SpaceCardKind kind;
  final bool selected;
  final bool visitorPageEnabled;
  final Color accent;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final active = selected && visitorPageEnabled;
    final status = active
        ? 'VISITORS CAN SEE THIS CARD'
        : selected
        ? 'SELECTED · VISITOR PAGE CLOSED'
        : 'ONLY YOU CAN SEE THIS CARD';
    return InkWell(
      key: ValueKey('space-card-share-${kind.name}'),
      onTap: onChanged,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: visitorPageEnabled ? 0.09 : 0.04)
              : Palette.glassFill,
          border: Border(
            top: BorderSide(color: accent.withValues(alpha: 0.16)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              active
                  ? Icons.door_front_door_outlined
                  : Icons.lock_outline_rounded,
              size: 16,
              color: active ? accent : Palette.textLo,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Type.label.copyWith(
                  fontSize: 8.5,
                  letterSpacing: 0.75,
                  color: active ? accent : Palette.textLo,
                ),
              ),
            ),
            Switch.adaptive(
              value: selected,
              activeTrackColor: accent.withValues(alpha: 0.72),
              onChanged: (_) => onChanged(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSpaceEditor extends StatelessWidget {
  const _AboutSpaceEditor({
    required this.controller,
    required this.notes,
    required this.selectedNoteId,
    required this.sharePhoto,
    required this.visitorPageEnabled,
    required this.onPhotoChanged,
    required this.onSharePhotoChanged,
  });

  final TextEditingController controller;
  final List<Note> notes;
  final String? selectedNoteId;
  final bool sharePhoto;
  final bool visitorPageEnabled;
  final ValueChanged<String?> onPhotoChanged;
  final ValueChanged<bool> onSharePhotoChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLength: 180,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          style: Type.body.copyWith(fontSize: 14, color: Palette.textHi),
          decoration: InputDecoration(
            labelText: 'A little about you',
            hintText: 'What are you making room for right now?',
            alignLabelWithHint: true,
            filled: true,
            fillColor: Palette.glassFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
          ),
        ),
        const SizedBox(height: 4),
        _SpacePhotoPicker(
          slot: 'profile',
          heading: 'PROFILE PHOTO FROM YOUR JOURNAL',
          emptyLabel: 'No profile photo',
          emptyCopy: 'Add a photo to a Journal page and it can live here.',
          notes: notes,
          selectedNoteId: selectedNoteId,
          onChanged: onPhotoChanged,
        ),
        const SizedBox(height: 9),
        _SharedPhotoAudienceControl(
          slot: 'profile',
          selected: sharePhoto,
          hasPhoto: selectedNoteId != null,
          visitorPageEnabled: visitorPageEnabled,
          visitorCardSelected: true,
          activeCopy: 'Visible in your visitor-page header.',
          onChanged: onSharePhotoChanged,
        ),
      ],
    );
  }
}

class _RightNowSpaceEditor extends StatelessWidget {
  const _RightNowSpaceEditor({
    required this.goals,
    required this.selected,
    required this.onChanged,
  });

  final List<Goal> goals;
  final Set<String> selected;
  final void Function(String title, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return Text(
        'Create a goal first, then you can place it here.',
        style: Type.body.copyWith(fontSize: 12.5, color: Palette.textLo),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose up to three goals to keep in view.',
          style: Type.body.copyWith(fontSize: 12.5, color: Palette.textMid),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final goal in goals)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: FilterChip(
                  selected: selected.contains(goal.title),
                  label: Text(goal.title),
                  onSelected: (value) => onChanged(goal.title, value),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PinnedMomentsEditor extends StatelessWidget {
  const _PinnedMomentsEditor({
    required this.notes,
    required this.selected,
    required this.onToggle,
  });

  final List<Note> notes;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return Text(
        'Your Journal is empty for now. A page you write can become a pinned moment later.',
        style: Type.body.copyWith(
          fontSize: 12.5,
          height: 1.4,
          color: Palette.textLo,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose up to four Journal entries. Visitors receive only the writing in this card; its attached photos stay private.',
          style: Type.body.copyWith(
            fontSize: 12.5,
            height: 1.4,
            color: Palette.textMid,
          ),
        ),
        const SizedBox(height: 8),
        for (final note in notes)
          _JournalMomentChoice(
            note: note,
            selected: selected.contains(note.id),
            onTap: () => onToggle(note.id),
          ),
      ],
    );
  }
}

class _JournalMomentChoice extends StatelessWidget {
  const _JournalMomentChoice({
    required this.note,
    required this.selected,
    required this.onTap,
  });

  final Note note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clean = note.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? Palette.xp.withValues(alpha: 0.10)
            : Palette.glassFill,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
              child: Row(
                children: [
                  if (note.images.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: journal_media.image(
                          note.images.first,
                          maxHeight: 46,
                        ),
                      ),
                    )
                  else
                    const SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(Icons.notes_rounded, color: Palette.textLo),
                    ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clean.isEmpty ? 'Journal moment' : clean,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Type.body.copyWith(
                            fontSize: 12.5,
                            height: 1.3,
                            color: Palette.textHi,
                          ),
                        ),
                        Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(note.at),
                          style: Type.label.copyWith(
                            fontSize: 8.5,
                            color: Palette.textLo,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Checkbox(value: selected, onChanged: (_) => onTap()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeasonSpaceEditor extends StatelessWidget {
  const _SeasonSpaceEditor({
    required this.controller,
    required this.notes,
    required this.selectedNoteId,
    required this.sharePhoto,
    required this.visitorPageEnabled,
    required this.visitorCardSelected,
    required this.onPhotoChanged,
    required this.onSharePhotoChanged,
  });

  final TextEditingController controller;
  final List<Note> notes;
  final String? selectedNoteId;
  final bool sharePhoto;
  final bool visitorPageEnabled;
  final bool visitorCardSelected;
  final ValueChanged<String?> onPhotoChanged;
  final ValueChanged<bool> onSharePhotoChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLength: 180,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          style: Type.body.copyWith(fontSize: 14, color: Palette.textHi),
          decoration: InputDecoration(
            labelText: 'What does this season hold?',
            hintText: 'Finals, a new routine, the garden coming back...',
            alignLabelWithHint: true,
            filled: true,
            fillColor: Palette.glassFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
          ),
        ),
        const SizedBox(height: 2),
        _SpacePhotoPicker(
          slot: 'season',
          heading: 'ONE PHOTO FROM YOUR JOURNAL',
          emptyLabel: 'No season photo',
          emptyCopy: 'Add a photo to a Journal page and it can live here.',
          notes: notes,
          selectedNoteId: selectedNoteId,
          onChanged: onPhotoChanged,
        ),
        const SizedBox(height: 9),
        _SharedPhotoAudienceControl(
          slot: 'season',
          selected: sharePhoto,
          hasPhoto: selectedNoteId != null,
          visitorPageEnabled: visitorPageEnabled,
          visitorCardSelected: visitorCardSelected,
          activeCopy: 'Visible inside your shared This season card.',
          onChanged: onSharePhotoChanged,
        ),
      ],
    );
  }
}

class _SpacePhotoPicker extends StatelessWidget {
  const _SpacePhotoPicker({
    required this.slot,
    required this.heading,
    required this.emptyLabel,
    required this.emptyCopy,
    required this.notes,
    required this.selectedNoteId,
    required this.onChanged,
  });

  final String slot;
  final String heading;
  final String emptyLabel;
  final String emptyCopy;
  final List<Note> notes;
  final String? selectedNoteId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: Type.label.copyWith(fontSize: 9, color: Palette.textLo),
        ),
        const SizedBox(height: 7),
        OutlinedButton.icon(
          key: ValueKey('space-$slot-photo-none'),
          onPressed: () => onChanged(null),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: selectedNoteId == null
                ? Palette.xpLight
                : Palette.textMid,
          ),
          icon: Icon(
            selectedNoteId == null
                ? Icons.check_circle_outline
                : Icons.hide_image_outlined,
          ),
          label: Text(emptyLabel),
        ),
        if (notes.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            emptyCopy,
            style: Type.body.copyWith(fontSize: 12.5, color: Palette.textLo),
          ),
        ] else ...[
          const SizedBox(height: 9),
          SizedBox(
            height: 138,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: notes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final note = notes[index];
                return _SeasonPhotoChoice(
                  slot: slot,
                  note: note,
                  selected: selectedNoteId == note.id,
                  onTap: () => onChanged(note.id),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _SharedPhotoAudienceControl extends StatelessWidget {
  const _SharedPhotoAudienceControl({
    required this.slot,
    required this.selected,
    required this.hasPhoto,
    required this.visitorPageEnabled,
    required this.visitorCardSelected,
    required this.activeCopy,
    required this.onChanged,
  });

  final String slot;
  final bool selected;
  final bool hasPhoto;
  final bool visitorPageEnabled;
  final bool visitorCardSelected;
  final String activeCopy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final active =
        selected && hasPhoto && visitorPageEnabled && visitorCardSelected;
    final subtitle = !hasPhoto
        ? 'Choose a Journal photo first.'
        : !selected
        ? 'Only you can see this photo.'
        : !visitorPageEnabled
        ? 'Selected · your visitor page is closed.'
        : !visitorCardSelected
        ? 'Selected · share the This season card too.'
        : activeCopy;
    return Container(
      decoration: facetedDecoration(
        cut: 8,
        color: active ? Palette.xp.withValues(alpha: 0.09) : Palette.glassFill,
        borderColor: active
            ? Palette.xp.withValues(alpha: 0.38)
            : Palette.glassEdge,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SwitchListTile.adaptive(
          key: ValueKey('space-$slot-photo-share-toggle'),
          contentPadding: const EdgeInsets.fromLTRB(12, 3, 7, 3),
          minTileHeight: 60,
          value: selected && hasPhoto,
          activeTrackColor: Palette.xp.withValues(alpha: 0.72),
          onChanged: hasPhoto ? onChanged : null,
          title: Text(
            'Let visitors see this photo',
            style: Type.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: hasPhoto ? Palette.textHi : Palette.textLo,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: Type.body.copyWith(
              fontSize: 11.2,
              height: 1.3,
              color: active ? Palette.textMid : Palette.textLo,
            ),
          ),
        ),
      ),
    );
  }
}

class _SeasonPhotoChoice extends StatelessWidget {
  const _SeasonPhotoChoice({
    required this.slot,
    required this.note,
    required this.selected,
    required this.onTap,
  });

  final String slot;
  final Note note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${slot == 'profile' ? 'Profile' : 'Season'} photo from ${MaterialLocalizations.of(context).formatMediumDate(note.at)}',
      child: InkWell(
        key: ValueKey('space-$slot-photo-${note.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 116,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? Palette.unlock.withValues(alpha: 0.14)
                : Palette.glassFill,
            border: Border.all(
              color: selected ? Palette.unlock : Palette.glassEdge,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: double.infinity,
                    child: journal_media.image(
                      note.images.first,
                      maxHeight: 90,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                MaterialLocalizations.of(context).formatMediumDate(note.at),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Type.label.copyWith(
                  fontSize: 8.5,
                  color: selected ? Palette.textHi : Palette.textLo,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpaceArrangerActions extends StatelessWidget {
  const _SpaceArrangerActions({
    required this.busy,
    required this.error,
    required this.onCancel,
    required this.onSave,
  });

  final bool busy;
  final String? error;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xF21B1411),
        border: Border(top: BorderSide(color: Palette.glassEdge)),
        boxShadow: [
          BoxShadow(
            color: Palette.warmShadow,
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                error!,
                key: const ValueKey('space-arranger-save-error'),
                textAlign: TextAlign.center,
                style: Type.body.copyWith(
                  fontSize: 12,
                  height: 1.35,
                  color: Palette.danger,
                ),
              ),
            ),
            const SizedBox(height: 7),
          ],
          Row(
            children: [
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  minimumSize: const Size(72, 52),
                  foregroundColor: Palette.textMid,
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('space-arranger-save'),
                  onPressed: onSave,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: Palette.xp,
                    foregroundColor: Palette.onHoney,
                  ),
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Palette.onHoney,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    busy ? 'Updating visitor page\u2026' : 'Save page',
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

/// The "Me" page: your space + your build. The stats radar, the attribution
/// ledger, and the share card (a build this earnest deserves showing off).
class MePage extends StatelessWidget {
  const MePage({
    super.key,
    required this.state,
    required this.quests,
    required this.onPersist,
    required this.onPublishRoom,
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

  /// Publishes a changed live visitor page and resolves only after the server
  /// has acknowledged it. Private/layout-only changes never call this.
  final SpaceRoomPublisher onPublishRoom;

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

  static final _privacyUrl = Uri.parse(PublicLinks.privacy);
  static final _deletionUrl = Uri.parse(PublicLinks.deleteAccount);

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
    final compactHeading =
        MediaQuery.sizeOf(context).width < 360 &&
        MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    Widget levelSummary() => Container(
      key: const ValueKey('me-level-summary'),
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
    );
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
          heirloomFlame: heirloomFlameFor(state),
          level: state.level,
          memoryArtifacts: memoryArtifactCount(state, quests),
          parallax: state.reduceMotion ? null : parallax,
        ),
        title: 'Me',
        subtitle: 'your space, already yours',
        icon: Icons.emoji_emotions_outlined,
        reduceMotion: state.reduceMotion,
        trailing: compactHeading ? null : levelSummary(),
        children: [
          if (compactHeading) ...[
            Align(alignment: Alignment.centerLeft, child: levelSummary()),
            const SizedBox(height: 10),
          ],
          // ── the room's own rail: what you have to spend, and the way in ──
          // Glimmers/room choice, sharing and the circle used to live *inside* the
          // identity plate, which turned the one page element that should read
          // as a nameplate into a grab bag of unrelated controls.
          _SpaceRail(
            embers: state.embers,
            light: state.reduceMotion ? null : parallax,
            onChangeSpace: () {
              Sfx.instance.play('tick');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ShopScreen(
                    state: state,
                    onPersist: onPersist,
                    parallax: parallax,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _SpaceLink(
                icon: Icons.ios_share,
                label: state.roomCode == null
                    ? 'Share my space'
                    : 'Shared · ${state.roomCode}',
                onTap: () => shareSpace(context, state, onPersist),
              ),
              _SpaceLink(
                icon: Icons.travel_explore,
                label: 'Visit a space',
                onTap: () => visitSpace(
                  context,
                  state: state,
                  onPersist: onPersist,
                  themeId: state.canvasTheme,
                  lively: !state.reduceMotion,
                  parallax: parallax,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        (state.playerName ?? 'You').toUpperCase(),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.fade,
                        style: Type.display.copyWith(
                          fontSize: 29,
                          color: Palette.textHi,
                          letterSpacing: 3.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Change your name',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Palette.textMid,
                      ),
                      onPressed: () => _changePlayerName(
                        context,
                        state,
                        onPersist,
                        onPublishRoom,
                      ),
                    ),
                  ],
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
                          parallax: parallax,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          _PersonalSpacePanel(
            state: state,
            onEdit: () =>
                _personalizeSpace(context, state, onPersist, onPublishRoom),
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
                            key: ValueKey('wardrobe-skin-$loot'),
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
              'Completed quests and stat gains will appear here.',
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
    Future<bool> permissionIfNeeded(bool turningOn) async {
      if (!turningOn) return true;
      final granted = await Notifications.requestPermission();
      if (!context.mounted) return false;
      if (!granted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Palette.card,
              content: Text(
                'Reminders stayed off — allow notifications in system settings when you’re ready.',
              ),
            ),
          );
      }
      return granted;
    }

    Widget reminderToggle({
      required String label,
      required String detail,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) => Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Type.body.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Palette.textHi,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: Type.body.copyWith(
                  fontSize: 11,
                  height: 1.25,
                  color: Palette.textLo,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GlassSwitch(value: value, semanticLabel: label, onChanged: onChanged),
      ],
    );

    Widget timeRow({
      required String label,
      required int hour,
      required int minute,
      required Future<void> Function(TimeOfDay picked) onPicked,
    }) => Semantics(
      button: true,
      label: '$label ${_fmtTime(hour, minute)}',
      child: InkWell(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: hour, minute: minute),
          );
          if (picked != null) await onPicked(picked);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: Palette.xpLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Type.body.copyWith(
                    fontSize: 13,
                    color: Palette.textMid,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                  _fmtTime(hour, minute),
                  style: Type.numerals.copyWith(
                    fontSize: 14,
                    color: Palette.xp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final supported = Notifications.isSupported;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('REMINDERS', style: Type.label.copyWith(fontSize: 11)),
              const Spacer(),
              if (!supported)
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
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            supported
                ? 'Only the reminders you choose. No missed-day warnings.'
                : 'Quest and night-routine reminders are available in the iOS and Android apps.',
            style: Type.body.copyWith(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Palette.textLo,
            ),
          ),
          if (supported) ...[
            const SizedBox(height: 16),
            reminderToggle(
              label: 'Quest & plan reminders',
              detail: 'Your first quest and anything due that day.',
              value: state.notifyEnabled,
              onChanged: (value) async {
                if (!await permissionIfNeeded(value)) return;
                state.setNotify(enabled: value);
                await onNotifyChanged();
              },
            ),
            if (state.notifyEnabled) ...[
              const SizedBox(height: 10),
              timeRow(
                label: 'Quest nudge at',
                hour: state.notifyHour,
                minute: state.notifyMinute,
                onPicked: (picked) async {
                  state.setNotify(hour: picked.hour, minute: picked.minute);
                  await onNotifyChanged();
                },
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: Palette.glassEdge),
            ),
            reminderToggle(
              label: 'Night routine reminder',
              detail: 'A quiet cue to review today and set up tomorrow.',
              value: state.nightReminderEnabled,
              onChanged: (value) async {
                if (!await permissionIfNeeded(value)) return;
                state.setNightReminder(enabled: value);
                await onNotifyChanged();
              },
            ),
            if (state.nightReminderEnabled) ...[
              const SizedBox(height: 10),
              timeRow(
                label: 'Close the day at',
                hour: state.nightReminderHour,
                minute: state.nightReminderMinute,
                onPicked: (picked) async {
                  state.setNightReminder(
                    hour: picked.hour,
                    minute: picked.minute,
                  );
                  await onNotifyChanged();
                },
              ),
            ],
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
                'too when Room of Days can confirm the server. Guest profiles are deleted; a linked sign-in stays '
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

/// Try on a found skin before wearing it: the room shows its actual hearth hue,
/// with the rarity + flavor and a wear/take-off toggle.
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
                    key: ValueKey('skin-preview-room-$loot'),
                    lively: !state.reduceMotion,
                    unlocked: state.ownedFurniture,
                    wall: wallColorsFor(state),
                    plateId: state.wallStyle,
                    floor: floorColorsFor(state),
                    window: state.windowScene,
                    petAwake: true,
                    // Preview the same effective fire colour that WEAR THIS
                    // applies everywhere else, not only the button/aura tint.
                    emberGlow: flameHueById(loot),
                    heirloomFlame: heirloomFlameById(loot),
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

class _PersonalSpacePanel extends StatelessWidget {
  const _PersonalSpacePanel({required this.state, required this.onEdit});

  final GameState state;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final order = state.spaceCardOrder.toList();
    for (final kind in defaultSpaceCardOrder) {
      if (!order.contains(kind)) order.add(kind);
    }
    final goals = [
      for (final goal in state.goals)
        if (state.featuredGoalTitles.contains(goal.title)) goal,
    ];
    final moments = [
      for (final note in state.journal)
        if (state.memoryPins.contains(note.id)) note,
    ].reversed.take(4).toList();
    final profilePhoto = state.spaceProfilePhotoNote;
    Note? seasonPhoto;
    final selectedSeasonPhoto = state.spaceSeasonPhotoNoteId;
    if (selectedSeasonPhoto != null) {
      for (final note in state.journal) {
        if (note.id == selectedSeasonPhoto && note.images.isNotEmpty) {
          seasonPhoto = note;
          break;
        }
      }
    }
    final visibleOrder = [
      for (final kind in order)
        if (!state.hiddenSpaceCards.contains(kind) &&
            (kind != SpaceCardKind.thisSeason ||
                state.spaceSeasonText.trim().isNotEmpty ||
                seasonPhoto != null))
          kind,
    ];
    bool shared(SpaceCardKind kind) =>
        state.shareSpaceProfile && state.visitorSpaceCards.contains(kind);
    final sharedCount = state.shareSpaceProfile
        ? state.visitorSpaceCards.length
        : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SpaceDeckHeading(
          sharedCount: sharedCount,
          visitorPageOpen: state.shareSpaceProfile,
          onEdit: onEdit,
        ),
        const SizedBox(height: 10),
        if (visibleOrder.isEmpty)
          _EmptySpaceDeck(onEdit: onEdit)
        else
          for (var index = 0; index < visibleOrder.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            switch (visibleOrder[index]) {
              SpaceCardKind.about => _AboutSpaceCard(
                intro: state.spaceIntro,
                shared: shared(SpaceCardKind.about),
                photo: profilePhoto,
                photoShared:
                    state.shareSpaceProfile && state.shareSpaceProfilePhoto,
              ),
              SpaceCardKind.rightNow => _RightNowSpaceCard(
                goals: goals,
                shared: shared(SpaceCardKind.rightNow),
              ),
              SpaceCardKind.pinnedMoments => _PinnedMomentsSpaceCard(
                moments: moments,
                shared: shared(SpaceCardKind.pinnedMoments),
              ),
              SpaceCardKind.thisSeason => _ThisSeasonSpaceCard(
                text: state.spaceSeasonText,
                photo: seasonPhoto,
                shared: shared(SpaceCardKind.thisSeason),
                photoShared:
                    shared(SpaceCardKind.thisSeason) &&
                    state.shareSpaceSeasonPhoto,
              ),
            },
          ],
      ],
    );
  }
}

class _SpaceDeckHeading extends StatelessWidget {
  const _SpaceDeckHeading({
    required this.sharedCount,
    required this.visitorPageOpen,
    required this.onEdit,
  });

  final int sharedCount;
  final bool visitorPageOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            MediaQuery.textScalerOf(context).scale(1) > 1.15 ||
            constraints.maxWidth < 330;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MY SPACE',
              style: Type.label.copyWith(
                fontSize: 11,
                letterSpacing: 1.7,
                color: Palette.xpLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'a page made from your days',
              style: Type.body.copyWith(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
          ],
        );
        final status = Container(
          key: const ValueKey('space-profile-visibility-status'),
          constraints: BoxConstraints(
            minHeight: 48,
            maxWidth: compact ? constraints.maxWidth : 220,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: facetedDecoration(
            cut: 7,
            color: visitorPageOpen
                ? Palette.xp.withValues(alpha: 0.11)
                : Palette.glassFill,
            borderColor: visitorPageOpen
                ? Palette.xp.withValues(alpha: 0.40)
                : Palette.glassEdge,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                visitorPageOpen
                    ? Icons.visibility_outlined
                    : Icons.lock_outline_rounded,
                size: 14,
                color: visitorPageOpen ? Palette.xpLight : Palette.textLo,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  visitorPageOpen ? '$sharedCount SHARED' : 'PRIVATE PAGE',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Type.label.copyWith(
                    fontSize: 8.5,
                    letterSpacing: 0.8,
                    color: visitorPageOpen ? Palette.xpLight : Palette.textLo,
                  ),
                ),
              ),
            ],
          ),
        );
        final edit = TextButton.icon(
          key: const ValueKey('space-page-open-arranger'),
          onPressed: onEdit,
          icon: const Icon(Icons.tune_rounded, size: 17),
          style: TextButton.styleFrom(
            foregroundColor: Palette.xpLight,
            minimumSize: const Size(48, 48),
          ),
          label: Text(
            'EDIT SPACE',
            style: Type.label.copyWith(
              fontSize: 9.5,
              letterSpacing: 1.1,
              color: Palette.xpLight,
            ),
          ),
        );
        final actions = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 2,
          children: [status, edit],
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 5), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: title),
            actions,
          ],
        );
      },
    );
  }
}

class _EmptySpaceDeck extends StatelessWidget {
  const _EmptySpaceDeck({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: facetedDecoration(
        cut: 12,
        gradient: const LinearGradient(
          colors: [Color(0xFF2B211A), Color(0xFF1D1612)],
        ),
        borderColor: Palette.glassEdge,
      ),
      child: Row(
        children: [
          const Icon(Icons.chair_outlined, color: Palette.xpLight),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'The room can stand on its own. Add a card whenever you want more of yourself here.',
              style: Type.body.copyWith(
                fontSize: 13,
                height: 1.4,
                color: Palette.textMid,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Choose cards',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onEdit,
            icon: const Icon(Icons.add_rounded, color: Palette.xpLight),
          ),
        ],
      ),
    );
  }
}

class _SpaceCardPrivacyMark extends StatelessWidget {
  const _SpaceCardPrivacyMark({required this.visitorEligible});

  final bool visitorEligible;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: largeText ? 180 : 160),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            visitorEligible
                ? Icons.door_front_door_outlined
                : Icons.lock_outline,
            size: 12,
            color: Palette.textMid,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              visitorEligible
                  ? (largeText ? 'VISITORS CAN SEE' : 'SHARED WITH VISITORS')
                  : 'ONLY YOU',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Type.label.copyWith(
                fontSize: 8.5,
                letterSpacing: 0.8,
                color: Palette.textMid,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpaceDeckCardHeader extends StatelessWidget {
  const _SpaceDeckCardHeader({
    required this.icon,
    required this.title,
    required this.accent,
    required this.visitorEligible,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final bool visitorEligible;

  @override
  Widget build(BuildContext context) {
    final identity = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: accent),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Type.label.copyWith(
              fontSize: 10,
              letterSpacing: 1.4,
              color: accent,
            ),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            MediaQuery.textScalerOf(context).scale(1) >= 1.5 ||
            constraints.maxWidth < 260;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              identity,
              const SizedBox(height: 6),
              _SpaceCardPrivacyMark(visitorEligible: visitorEligible),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: identity),
            const SizedBox(width: 8),
            _SpaceCardPrivacyMark(visitorEligible: visitorEligible),
          ],
        );
      },
    );
  }
}

class _AboutSpaceCard extends StatelessWidget {
  const _AboutSpaceCard({
    required this.intro,
    required this.shared,
    required this.photo,
    required this.photoShared,
  });

  final String intro;
  final bool shared;
  final Note? photo;
  final bool photoShared;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A2C21), Color(0xFF241A16)],
        ),
        border: Border.all(color: const Color(0x668E6134)),
        boxShadow: const [
          BoxShadow(
            color: Palette.warmShadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -2,
            top: -18,
            child: IgnorePointer(
              child: Text(
                '“',
                style: Type.display.copyWith(
                  fontSize: 82,
                  color: Palette.xp.withValues(alpha: 0.10),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SpaceDeckCardHeader(
                icon: Icons.auto_stories_outlined,
                title: 'ABOUT',
                accent: Palette.xpLight,
                visitorEligible: shared,
              ),
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 1,
                color: Palette.xp.withValues(alpha: 0.66),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photo case final note?) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox.square(
                        dimension: 82,
                        child: journal_media.image(
                          note.images.first,
                          maxHeight: 82,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      intro.isEmpty
                          ? 'A few honest lines about you can live here.'
                          : intro,
                      style: Type.body.copyWith(
                        fontSize: 14,
                        height: 1.5,
                        fontStyle: intro.isEmpty ? FontStyle.italic : null,
                        color: intro.isEmpty ? Palette.textMid : Palette.textHi,
                      ),
                    ),
                  ),
                ],
              ),
              if (photo != null) ...[
                const SizedBox(height: 9),
                _SpacePhotoVisibilityMark(shared: photoShared),
              ],
              if (shared) ...[
                const SizedBox(height: 10),
                Text(
                  'shown when this card is visible to visitors',
                  style: Type.body.copyWith(
                    fontSize: 10.5,
                    color: Palette.textMid,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RightNowSpaceCard extends StatelessWidget {
  const _RightNowSpaceCard({required this.goals, required this.shared});

  final List<Goal> goals;
  final bool shared;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF273025), Color(0xFF191D17)],
        ),
        border: Border.all(color: const Color(0x5C9CBC88)),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFBED2A8), Color(0xFF657653)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(21, 14, 15, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SpaceDeckCardHeader(
                  icon: Icons.flag_outlined,
                  title: 'RIGHT NOW',
                  accent: Palette.success,
                  visitorEligible: shared,
                ),
                const SizedBox(height: 9),
                if (goals.isEmpty)
                  Text(
                    'The goals you choose to keep close will sit here.',
                    style: Type.body.copyWith(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Palette.textMid,
                    ),
                  )
                else
                  for (var index = 0; index < goals.length; index++) ...[
                    if (index > 0)
                      Divider(
                        height: 13,
                        color: Palette.success.withValues(alpha: 0.16),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 23,
                          height: 23,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: goals[index].stat.color.withValues(
                              alpha: 0.12,
                            ),
                            border: Border.all(
                              color: goals[index].stat.color.withValues(
                                alpha: 0.42,
                              ),
                            ),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: Type.numerals.copyWith(
                              fontSize: 10,
                              color: goals[index].stat.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            goals[index].title,
                            style: Type.body.copyWith(
                              fontSize: 13,
                              height: 1.35,
                              color: Palette.textHi,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                if (shared) ...[
                  const SizedBox(height: 9),
                  Text(
                    'shown when this card is visible to visitors',
                    style: Type.body.copyWith(
                      fontSize: 10.5,
                      color: Palette.textMid,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedMomentsSpaceCard extends StatelessWidget {
  const _PinnedMomentsSpaceCard({required this.moments, required this.shared});

  final List<Note> moments;
  final bool shared;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A241B), Color(0xFF241711)],
        ),
        border: Border.all(color: const Color(0x597E4E35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SpaceDeckCardHeader(
            icon: Icons.push_pin_outlined,
            title: 'PINNED MOMENTS',
            accent: Color(0xFFDDB296),
            visitorEligible: shared,
          ),
          const SizedBox(height: 10),
          if (moments.isEmpty)
            Text(
              'Keep a few pages from your Journal on this quiet shelf.',
              style: Type.body.copyWith(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Palette.textMid,
              ),
            )
          else
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: moments.length,
                separatorBuilder: (_, _) => const SizedBox(width: 9),
                itemBuilder: (context, index) =>
                    _PinnedMomentTile(note: moments[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _PinnedMomentTile extends StatelessWidget {
  const _PinnedMomentTile({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    if (note.images.isNotEmpty) {
      return Container(
        width: 104,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xFFB49472),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFF4E2F20), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x72140C06),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: journal_media.image(note.images.first, maxHeight: 100),
        ),
      );
    }
    final clean = note.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return Container(
      width: 158,
      padding: const EdgeInsets.fromLTRB(11, 12, 11, 9),
      decoration: BoxDecoration(
        color: const Color(0xFF322821),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0x557C5A43)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x56140C06),
            blurRadius: 7,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              clean.isEmpty ? 'Journal moment' : clean,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Type.body.copyWith(
                fontSize: 11.5,
                height: 1.3,
                color: Palette.textMid,
              ),
            ),
          ),
          Text(
            MaterialLocalizations.of(context).formatMediumDate(note.at),
            style: Type.label.copyWith(fontSize: 8, color: Palette.textLo),
          ),
        ],
      ),
    );
  }
}

class _ThisSeasonSpaceCard extends StatelessWidget {
  const _ThisSeasonSpaceCard({
    required this.text,
    required this.photo,
    required this.shared,
    required this.photoShared,
  });

  final String text;
  final Note? photo;
  final bool shared;
  final bool photoShared;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF35283C), Color(0xFF201923)],
        ),
        border: Border.all(color: const Color(0x5FC9A3DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photo case final note?)
            SizedBox(
              height: 168,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  journal_media.image(note.images.first, maxHeight: 168),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0xB0160F17)],
                        stops: [0.46, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 9,
                    child: _SpacePhotoVisibilityMark(shared: photoShared),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 0),
            child: _SpaceDeckCardHeader(
              icon: Icons.filter_vintage_outlined,
              title: 'THIS SEASON',
              accent: Palette.unlock,
              visitorEligible: shared,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 17),
            child: Text(
              text.trim().isEmpty
                  ? 'Name the chapter you are in, or leave the space quiet.'
                  : text.trim(),
              style: Type.body.copyWith(
                fontSize: 14,
                height: 1.45,
                fontStyle: text.trim().isEmpty ? FontStyle.italic : null,
                color: text.trim().isEmpty ? Palette.textMid : Palette.textHi,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpacePhotoVisibilityMark extends StatelessWidget {
  const _SpacePhotoVisibilityMark({required this.shared});

  final bool shared;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: facetedDecoration(
      cut: 5,
      color: const Color(0xD9261C17),
      borderColor: shared
          ? Palette.xp.withValues(alpha: 0.48)
          : Palette.glassEdge,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          shared ? Icons.public_rounded : Icons.lock_outline_rounded,
          size: 12,
          color: shared ? Palette.xpLight : Palette.textLo,
        ),
        const SizedBox(width: 5),
        Text(
          shared ? 'PHOTO · VISITORS' : 'PHOTO · ONLY YOU',
          style: Type.label.copyWith(
            fontSize: 7.5,
            letterSpacing: 0.65,
            color: shared ? Palette.xpLight : Palette.textLo,
          ),
        ),
      ],
    ),
  );
}

/// A clear icon+label button for the Share / Visit space actions.
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
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: Palette.card.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.glassRim),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Palette.xpLight),
              const SizedBox(width: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: Type.label.copyWith(
                    fontSize: 11,
                    color: Palette.xpLight,
                  ),
                ),
              ),
            ],
          ),
        ),
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
        '${state.totalXp} XP of real life, and counting. — Room of Days';
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
            'room-of-days-build.png',
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
                        heirloomFlame: heirloomFlameFor(state),
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
                        'ROOM OF DAYS',
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
  const _SpaceRail({
    required this.embers,
    required this.onChangeSpace,
    this.light,
  });
  final int embers;
  final VoidCallback onChangeSpace;
  final ValueListenable<Offset>? light;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    final balance = Row(
      children: [
        const Icon(Icons.auto_awesome_rounded, color: Palette.xp, size: 17),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            '$embers GLIMMERS',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Type.label.copyWith(
              fontSize: 11.5,
              letterSpacing: 1.5,
              color: Palette.textMid,
            ),
          ),
        ),
      ],
    );
    final chooser = HoneyButton(
      label: 'CHANGE SPACE',
      icon: Icons.meeting_room_outlined,
      fontSize: 10.5,
      glow: false,
      light: light,
      onTap: onChangeSpace,
    );
    return Semantics(
      button: true,
      label: 'Open room chooser. $embers Glimmers available.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChangeSpace,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
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
          child: largeText
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [balance, const SizedBox(height: 8), chooser],
                )
              : Row(
                  children: [
                    Expanded(child: balance),
                    const SizedBox(width: 10),
                    chooser,
                  ],
                ),
        ),
      ),
    );
  }
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
      constraints: const BoxConstraints(minHeight: 42),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
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
            child: Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: Type.label.copyWith(
                fontSize: 10.5,
                letterSpacing: 0.5,
                color: unlocked
                    ? Palette.xpLight
                    : Palette.textLo.withValues(alpha: 0.8),
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
        _error = 'that doesn’t look like a Room of Days backup';
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
          error ?? 'Cloud backup is on for this save.',
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
                        ? 'BACKUP ON'
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
                  'Your data is backed up and available when you sign in on another device.',
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
        content: Text('Account and Room of Days data deleted.'),
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
              : 'Account created. Your save is backed up.',
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
