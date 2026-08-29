import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../audio.dart';
import '../cloud.dart';
import '../content/creature_skins.dart';
import '../content/links.dart';
import '../content/room_styles.dart';
import '../content/space_themes.dart';
import '../discovery.dart';
import '../engine.dart';
import '../release_features.dart';
import '../social.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/home_room.dart';
import '../widgets/honey_button.dart';
import '../widgets/pressable.dart';
import 'visit_room.dart';

typedef DiscoverableSpacesFetcher =
    Future<List<DiscoverableSpaceSummary>?> Function();
typedef DiscoverableRoomFetcher =
    Future<Map<String, dynamic>?> Function(String code);
typedef DiscoverableSpaceReporter =
    Future<bool> Function(String code, String category);

/// A finite handful of rooms whose keepers explicitly opened the door.
/// Directory cards contain only generated visual identity and level; the
/// existing exact-code room is fetched only after a deliberate tap.
class DiscoverSpacesScreen extends StatefulWidget {
  const DiscoverSpacesScreen({
    super.key,
    required this.state,
    required this.onPersist,
    this.parallax,
    this.fetchSpaces,
    this.fetchRoom,
    this.reportSpace,
    this.onManageOwnListing,
    this.publicDiscoveryNamesEnabled = kPublicDiscoveryNamesEnabled,
  });

  final GameState state;
  final VoidCallback onPersist;
  final ValueListenable<Offset>? parallax;
  final DiscoverableSpacesFetcher? fetchSpaces;
  final DiscoverableRoomFetcher? fetchRoom;
  final DiscoverableSpaceReporter? reportSpace;
  final Future<void> Function()? onManageOwnListing;
  final bool publicDiscoveryNamesEnabled;

  @override
  State<DiscoverSpacesScreen> createState() => _DiscoverSpacesScreenState();
}

class _DiscoverSpacesScreenState extends State<DiscoverSpacesScreen> {
  var _loading = true;
  String? _error;
  String? _openingCode;
  var _managingOwnListing = false;
  List<DiscoverableSpaceSummary> _spaces = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final fetch =
        widget.fetchSpaces ??
        () => CloudSync.instance.fetchDiscoverableSpaces(limit: 8);
    final result = await fetch();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result == null) {
        _error =
            'The open doors couldn’t be reached. Try again when your connection is steady.';
        _spaces = const [];
      } else {
        final ownCode = widget.state.roomCode?.trim().toUpperCase();
        _spaces = [
          for (final space in result)
            if (space.code != ownCode && !_isHidden(space)) space,
        ];
      }
    });
  }

  Future<void> _open(DiscoverableSpaceSummary summary) async {
    if (_openingCode != null) return;
    setState(() => _openingCode = summary.code);
    final fetch = widget.fetchRoom ?? CloudSync.instance.fetchRoom;
    final room = await fetch(summary.code);
    if (!mounted) return;
    setState(() => _openingCode = null);
    if (room == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Palette.card,
            content: Text(
              'That door isn’t open right now. Try another space.',
              style: Type.body.copyWith(color: Palette.textHi),
            ),
          ),
        );
      return;
    }
    final ownerKey = discoveryOwnerKeyFromRoom(room);
    if (ownerKey != summary.ownerKey) {
      setState(
        () => _spaces = [
          for (final space in _spaces)
            if (space.code != summary.code) space,
        ],
      );
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Palette.card,
            content: Text(
              'That door changed before it could open. Try another space.',
              style: Type.body.copyWith(color: Palette.textHi),
            ),
          ),
        );
      return;
    }
    if (_isHidden(summary)) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VisitRoomScreen(
          room: room,
          code: summary.code,
          themeId: widget.state.canvasTheme,
          lively: !widget.state.reduceMotion,
          parallax: widget.parallax,
          localState: widget.state,
          onPersist: widget.onPersist,
          discoveryOwnerKey: summary.ownerKey,
          discoveryPublicName: widget.publicDiscoveryNamesEnabled
              ? summary.publicName
              : '',
          onReportDiscoverableSpace:
              widget.reportSpace ?? CloudSync.instance.reportDiscoverableSpace,
        ),
      ),
    );
    if (mounted && _isHidden(summary)) {
      setState(
        () => _spaces = [
          for (final space in _spaces)
            if (widget.state.blockedDiscoveryOwners.containsKey(
                  summary.ownerKey,
                )
                ? space.ownerKey != summary.ownerKey
                : space.code != summary.code)
              space,
        ],
      );
    }
  }

  bool _isHidden(DiscoverableSpaceSummary space) =>
      widget.state.blockedRoomCodes.contains(space.code) ||
      widget.state.blockedDiscoveryOwners.containsKey(space.ownerKey);

  Future<void> _enterCode() {
    Sfx.instance.playMaterial(MaterialSound.glass);
    return visitSpace(
      context,
      state: widget.state,
      onPersist: widget.onPersist,
      themeId: widget.state.canvasTheme,
      lively: !widget.state.reduceMotion,
      parallax: widget.parallax,
      fetcher: widget.fetchRoom,
    );
  }

  Future<void> _manageOwnListing() async {
    if (_managingOwnListing) return;
    setState(() => _managingOwnListing = true);
    try {
      final injected = widget.onManageOwnListing;
      if (injected != null) {
        await injected();
      } else {
        await shareSpace(
          context,
          widget.state,
          widget.onPersist,
          spaceDiscoveryEnabled: true,
          publicDiscoveryNamesEnabled: widget.publicDiscoveryNamesEnabled,
          discoveryFirst: true,
        );
      }
    } finally {
      if (mounted) setState(() => _managingOwnListing = false);
    }
  }

  Future<void> _manageHidden() async {
    Sfx.instance.playMaterial(MaterialSound.glass);
    final owners = widget.state.blockedDiscoveryOwners.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final ownerCodes = owners.map((entry) => entry.value).toSet();
    final legacyCodes = [
      for (final code in widget.state.blockedRoomCodes)
        if (!ownerCodes.contains(code)) code,
    ]..sort();
    final hidden = <({String id, String label})>[
      for (final owner in owners)
        (
          id: 'owner:${owner.key}',
          label: 'KEEPER · LAST SEEN AT ${owner.value}',
        ),
      for (final code in legacyCodes) (id: 'code:$code', label: 'SPACE $code'),
    ];
    if (hidden.isEmpty) return;
    final unhide = await showDialog<String>(
      context: context,
      barrierColor: Palette.dialogBarrier,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Palette.dialogSurface,
        shape: const FacetedBorder(cut: 12),
        title: Text(
          'Hidden spaces',
          style: Type.display.copyWith(fontSize: 20, color: Palette.textHi),
        ),
        content: SizedBox(
          width: 320,
          height: (hidden.length * 52.0).clamp(52, 312),
          child: ListView.separated(
            itemCount: hidden.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: Palette.glassEdge),
            itemBuilder: (_, index) {
              final entry = hidden[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  entry.label,
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    color: Palette.textMid,
                  ),
                ),
                trailing: TextButton(
                  key: ValueKey('discover-unhide-${entry.id}'),
                  onPressed: () {
                    Sfx.instance.playMaterial(MaterialSound.glass);
                    Navigator.of(dialogContext).pop(entry.id);
                  },
                  child: Text(
                    'UNHIDE',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: Palette.xpLight,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Sfx.instance.playMaterial(MaterialSound.glass);
              Navigator.of(dialogContext).pop();
            },
            child: Text(
              'DONE',
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: Palette.xpLight,
              ),
            ),
          ),
        ],
      ),
    );
    if (unhide == null || !mounted) return;
    var serverUnblocked = true;
    if (unhide.startsWith('owner:')) {
      final ownerKey = unhide.substring('owner:'.length);
      final code = widget.state.blockedDiscoveryOwners[ownerKey] ?? '';
      widget.state.unblockDiscoveryOwner(ownerKey);
      serverUnblocked = await CloudSync.instance.setSpaceBlock(
        code,
        ownerKey: ownerKey,
        blocked: false,
      );
    } else if (unhide.startsWith('code:')) {
      final code = unhide.substring('code:'.length);
      widget.state.unblockRoomCode(code);
      serverUnblocked = await CloudSync.instance.setSpaceBlock(
        code,
        blocked: false,
      );
    }
    widget.onPersist();
    if (!mounted) return;
    if (!serverUnblocked) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Palette.card,
            content: Text(
              'Visible on this device. Reconnect later to finish restoring mutual access.',
              style: Type.body.copyWith(color: Palette.textHi),
            ),
          ),
        );
    }
    await _load();
  }

  Future<void> _openCommunityRules(BuildContext context) async {
    Sfx.instance.playInteraction(InteractionSound.open);
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(PublicLinks.community));
    } catch (_) {
      // A missing browser should not make the directory feel broken.
    }
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        content: Text(
          'Couldn’t open the community rules. Try again when a browser is available.',
          style: Type.body.copyWith(color: Palette.textHi),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownCode = widget.state.roomCode;
    final cleanupPending =
        ownCode != null &&
        widget.state.roomDiscoveryRemovalCodes.contains(ownCode);
    return Scaffold(
      backgroundColor: Palette.parchment,
      body: WarmBackground(
        themeId: widget.state.canvasTheme,
        reduceMotion: widget.state.reduceMotion,
        child: SafeArea(
          child: ListView(
            key: const ValueKey('discover-spaces-list'),
            padding: const EdgeInsets.only(bottom: 36),
            children: [
              DetailHeader(
                title: 'Discover spaces',
                accent: Palette.xp,
                subtitle: 'a few open doors',
                pill: cleanupPending
                    ? 'CLOSING'
                    : widget.state.roomDiscoverable
                    ? 'LISTED'
                    : 'PRIVATE',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PrivacyNote(
                      publicNamesEnabled: widget.publicDiscoveryNamesEnabled,
                    ),
                    const SizedBox(height: 12),
                    _OwnerListingCard(
                      discoverable: widget.state.roomDiscoverable,
                      cleanupPending: cleanupPending,
                      busy: _managingOwnListing,
                      onTap: _manageOwnListing,
                    ),
                    const SizedBox(height: 14),
                    if (_loading)
                      const _LoadingDoors()
                    else if (_error != null)
                      _DirectoryMessage(
                        icon: Icons.cloud_off_outlined,
                        title: 'The doors went quiet',
                        body: _error!,
                        action: 'TRY AGAIN',
                        onAction: _load,
                      )
                    else if (_spaces.isEmpty)
                      _DirectoryMessage(
                        icon: Icons.meeting_room_outlined,
                        title: 'No open doors yet',
                        body:
                            'When other keepers open their spaces, a small handful will appear here. Your own listing controls are just above.',
                        action: 'LOOK AGAIN',
                        onAction: _load,
                      )
                    else ...[
                      for (final space in _spaces) ...[
                        _DiscoverableSpaceCard(
                          summary: space,
                          publicNamesEnabled:
                              widget.publicDiscoveryNamesEnabled,
                          busy: _openingCode == space.code,
                          onTap: () => _open(space),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 2),
                      HoneyButton(
                        key: const ValueKey('discover-refresh'),
                        label: _loading
                            ? 'LOOKING…'
                            : 'SHOW ME DIFFERENT SPACES',
                        icon: Icons.shuffle_rounded,
                        enabled: !_loading && _openingCode == null,
                        expand: true,
                        onTap: _load,
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextButton.icon(
                      key: const ValueKey('discover-enter-code'),
                      onPressed: _openingCode == null ? _enterCode : null,
                      icon: const Icon(Icons.key_outlined, size: 16),
                      label: Text(
                        'I HAVE A CODE',
                        style: Type.label.copyWith(fontSize: 11),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: Palette.xpLight,
                      ),
                    ),
                    if (widget.state.blockedRoomCodes.isNotEmpty ||
                        widget.state.blockedDiscoveryOwners.isNotEmpty)
                      TextButton.icon(
                        key: const ValueKey('discover-manage-hidden'),
                        onPressed: _manageHidden,
                        icon: const Icon(
                          Icons.visibility_off_outlined,
                          size: 15,
                        ),
                        label: Text(
                          'MANAGE HIDDEN SPACES · ${widget.state.blockedRoomCodes.length}',
                          style: Type.label.copyWith(fontSize: Type.minLabel),
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          foregroundColor: Palette.textLo,
                        ),
                      ),
                    TextButton.icon(
                      key: const ValueKey('discover-community-rules'),
                      onPressed: () => _openCommunityRules(context),
                      icon: const Icon(Icons.gavel_outlined, size: 15),
                      label: Text(
                        'COMMUNITY RULES & SAFETY',
                        style: Type.label.copyWith(fontSize: Type.minLabel),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        foregroundColor: Palette.textLo,
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

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.publicNamesEnabled});

  final bool publicNamesEnabled;

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shield_outlined, size: 18, color: Palette.success),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            publicNamesEnabled
                ? 'Only an optional public name, the room’s generated title, room style, and level appear here. Quests, Journal pages, streaks, and account details stay private. A block still works if a keeper changes room codes.'
                : 'Only the room’s generated title, room style, and level appear here. Quests, Journal pages, streaks, and account details stay private. A block still works if a keeper changes room codes.',
            style: Type.body.copyWith(
              fontSize: 12,
              height: 1.42,
              color: Palette.textMid,
            ),
          ),
        ),
      ],
    ),
  );
}

class _OwnerListingCard extends StatelessWidget {
  const _OwnerListingCard({
    required this.discoverable,
    required this.cleanupPending,
    required this.busy,
    required this.onTap,
  });

  final bool discoverable;
  final bool cleanupPending;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final open = discoverable && !cleanupPending;
    final title = cleanupPending
        ? 'YOUR DOOR IS CLOSING'
        : open
        ? 'YOUR SPACE IS IN DISCOVER'
        : 'YOUR SPACE IS PRIVATE';
    final body = cleanupPending
        ? 'Cleanup will finish when the connection returns. Sharing by code still works.'
        : open
        ? 'Choose the public name people see, or close your listing.'
        : 'Open your door to let other keepers find your room without a code.';
    final action = busy
        ? 'OPENING…'
        : open || cleanupPending
        ? 'MANAGE LISTING'
        : 'OPEN TO DISCOVER';
    return Pressable(
      key: const ValueKey('discover-manage-own-listing'),
      enabled: !busy,
      // glass/open is not a shipped material lane; select keeps the declared
      // glass body actually audible instead of silently falling back to wood.
      material: MaterialSound.glass,
      interactionSound: InteractionSound.select,
      semanticLabel: open
          ? 'Manage Discover listing'
          : 'Open my space to Discover',
      semanticHint:
          'Opens the optional public listing and public name controls',
      onTapUp: (_) => onTap(),
      pressDepth: 3,
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        decoration: facetedDecoration(
          cut: 10,
          color: open ? Palette.xp.withValues(alpha: 0.11) : Palette.glassFill,
          borderColor: open
              ? Palette.xp.withValues(alpha: 0.50)
              : Palette.glassEdge,
        ),
        child: Row(
          children: [
            FacetMedallion(
              size: 42,
              accent: open ? Palette.xp : Palette.textLo,
              glow: open,
              child: Icon(
                open ? Icons.door_front_door_outlined : Icons.lock_open_rounded,
                size: 20,
                color: open ? Palette.xpLight : Palette.textMid,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: open ? Palette.xpLight : Palette.textMid,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: Type.body.copyWith(
                      fontSize: 11.5,
                      height: 1.35,
                      color: Palette.textLo,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          action,
                          maxLines: 2,
                          overflow: TextOverflow.fade,
                          style: Type.label.copyWith(
                            fontSize: Type.minLabel,
                            color: Palette.xpLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Palette.xpLight,
                      ),
                    ],
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

class _LoadingDoors extends StatelessWidget {
  const _LoadingDoors();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 220,
    child: Center(
      child: CircularProgressIndicator(color: Palette.xp, strokeWidth: 2.5),
    ),
  );
}

class _DirectoryMessage extends StatelessWidget {
  const _DirectoryMessage({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => GlassPanel(
    child: Column(
      children: [
        Icon(icon, size: 34, color: Palette.textLo),
        const SizedBox(height: 10),
        Text(title, style: Type.display.copyWith(fontSize: 20)),
        const SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: Type.body.copyWith(
            fontSize: 13,
            height: 1.4,
            color: Palette.textMid,
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            Sfx.instance.playInteraction(InteractionSound.open);
            onAction();
          },
          style: TextButton.styleFrom(minimumSize: const Size(120, 48)),
          child: Text(action, style: Type.label.copyWith(fontSize: 11)),
        ),
      ],
    ),
  );
}

class _DiscoverableSpaceCard extends StatelessWidget {
  const _DiscoverableSpaceCard({
    required this.summary,
    required this.publicNamesEnabled,
    required this.busy,
    required this.onTap,
  });

  final DiscoverableSpaceSummary summary;
  final bool publicNamesEnabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = spaceThemeById(summary.wall);
    final roomName =
        theme?.name ?? roomStyleById(summary.wall)?.name ?? 'A keeper’s room';
    final accent = theme?.accent ?? Palette.xpLight;
    final publicName = publicNamesEnabled ? summary.publicName : '';
    final primary = publicName.isNotEmpty ? publicName : summary.buildTitle;
    final secondary = publicName.isNotEmpty
        ? '${summary.buildTitle} · $roomName'
        : roomName;
    return Pressable(
      key: ValueKey('discover-space-${summary.code}'),
      enabled: !busy,
      material: MaterialSound.parchment,
      interactionSound: InteractionSound.open,
      semanticLabel:
          '$primary, ${summary.buildTitle}, level ${summary.level}. Open this space.',
      onTapUp: (_) => onTap(),
      child: GlassPanel(
        blur: true,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  HomeRoom(
                    aspect: 1.7,
                    lively: false,
                    lightweightPreview: true,
                    unlocked: const {},
                    wall: wallColorsById(summary.wall),
                    plateId: summary.wall,
                    floor: floorColorsById(summary.floor),
                    window: summary.window,
                    emberGlow: flameHueById(summary.skin),
                    heirloomFlame: heirloomFlameById(summary.skin),
                    level: summary.level,
                  ),
                  if (busy)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x7A120C08),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Palette.xpLight,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.display.copyWith(
                          fontSize: 17,
                          color: accent,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.body.copyWith(
                          fontSize: 12,
                          color: Palette.textLo,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: facetedDecoration(
                    cut: 6,
                    color: accent.withValues(alpha: 0.13),
                    borderColor: accent.withValues(alpha: 0.42),
                  ),
                  child: Text(
                    'LV ${summary.level}',
                    style: Type.label.copyWith(fontSize: 11, color: accent),
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Palette.textLo,
                  size: 21,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
