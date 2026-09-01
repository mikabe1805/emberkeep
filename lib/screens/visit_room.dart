import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../clock.dart';
import '../cloud.dart';
import '../content/creature_skins.dart';
import '../content/room_styles.dart';
import '../content/space_themes.dart';
import '../discovery.dart';
import '../engine.dart';
import '../release_features.dart';
import '../room_photo.dart';
import '../shared_room_media.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/ember_flame_icon.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/home_room.dart';
import '../widgets/spark_picker.dart';
import '../widgets/visitor_shared_room_photo.dart';
import '../widgets/visitor_room_photo_loader.dart';

typedef DiscoverySpaceReporter =
    Future<bool> Function(String code, String category);
typedef SpaceProfileFetcher =
    Future<Map<String, dynamic>?> Function(String code, {bool includeMutual});
typedef SpaceRelationshipSetter =
    Future<bool> Function(String code, {String ownerKey, required bool active});

/// A read-only look at someone else's "Your Space" (round-52, social). Built
/// only from its bounded public room document. The v1 candidate accepts preset
/// appearance and app-generated presence only; user-authored profile cards and
/// journal photos require separately enabled, reviewed release capabilities.
/// Quests, Journal pages, local filenames, and account data never travel.
class VisitRoomScreen extends StatelessWidget {
  const VisitRoomScreen({
    super.key,
    required this.room,
    required this.code,
    this.themeId,
    this.lively = true,
    this.parallax,
    this.localState,
    this.onPersist,
    this.photoUrlLoader,
    this.sparkSender,
    this.discoveryPublicName = '',
    this.discoveryOwnerKey = '',
    this.onReportDiscoverableSpace,
    this.visitorProfile,
    this.spaceProfileFetcher,
    this.relationshipSetter,
    this.visitorPhotoSharingEnabled = kVisitorPhotoSharingEnabled,
    this.visitorProfileSharingEnabled = kVisitorProfileSharingEnabled,
    this.previewOnly = false,
    this.previewRoomPhoto,
    this.roomPhotoBytesLoader,
  });

  final Map<String, dynamic> room;
  final String code;

  /// The LOCAL user's canvas theme — the shared room doc carries no theme, so
  /// the visitor's own backdrop should hold instead of snapping to default.
  final String? themeId;

  /// The LOCAL user's reduce-motion setting — a friend's room should honour it
  /// just like every other surface (the room ambience and optional cat park).
  final bool lively;
  final ValueListenable<Offset>? parallax;

  /// Supplying both values lets a one-off visitor keep this room in their
  /// trusted Circle. Circle-originated visits simply show it as already saved.
  final GameState? localState;
  final VoidCallback? onPersist;
  final VisitorPhotoUrlLoader? photoUrlLoader;
  final bool visitorPhotoSharingEnabled;
  final bool visitorProfileSharingEnabled;

  /// Local owner preview of the public projection. It never opens a network
  /// path or presents visitor actions.
  final bool previewOnly;

  /// An owner preview carries its chosen local image explicitly. It must never
  /// infer it from a singleton or open a remote Storage request.
  final RoomPhotoData? previewRoomPhoto;
  final VisitorRoomPhotoBytesLoader? roomPhotoBytesLoader;
  final String discoveryPublicName;
  final String discoveryOwnerKey;
  final DiscoverySpaceReporter? onReportDiscoverableSpace;
  final Map<String, dynamic>? visitorProfile;
  final SpaceProfileFetcher? spaceProfileFetcher;
  final SpaceRelationshipSetter? relationshipSetter;

  /// Test seam for the leave-a-note action; the real path acquires the
  /// anonymous social session only on the explicit send.
  final SparkSender? sparkSender;

  @override
  Widget build(BuildContext context) {
    String safeString(String key, [String fallback = '', int max = 80]) {
      final value = room[key];
      if (value is! String) return fallback;
      return String.fromCharCodes(value.trim().runes.take(max));
    }

    // A local public preview must use the explicitly injected Anyone
    // projection, never fields embedded in a room map from a legacy caller.
    final profileVisible =
        !previewOnly &&
        visitorProfileSharingEnabled &&
        room['profileVisible'] == true;
    final legacyName = safeString('name', '', 40);
    final displayName = profileVisible ? safeString('displayName', '', 40) : '';
    final directoryName = sanitizeDiscoveryPublicName(discoveryPublicName);
    final name = directoryName.isNotEmpty
        ? directoryName
        : displayName.isNotEmpty
        ? displayName
        : legacyName;
    final title = safeString('title', '', 64);
    final about = profileVisible ? safeString('about', '', 180) : '';
    final featuredGoals = <String>[];
    if (profileVisible && room['featuredGoals'] is List) {
      for (final raw in room['featuredGoals'] as List) {
        if (raw is! String) continue;
        final goal = String.fromCharCodes(raw.trim().runes.take(80));
        if (goal.isEmpty || featuredGoals.contains(goal)) continue;
        featuredGoals.add(goal);
        if (featuredGoals.length == 3) break;
      }
    }
    final cardOrder = <SpaceCardKind>[];
    if (profileVisible && room['cardOrder'] is List) {
      for (final raw in room['cardOrder'] as List) {
        if (raw is! String) continue;
        final matches = SpaceCardKind.values.where((kind) => kind.name == raw);
        if (matches.isEmpty || cardOrder.contains(matches.first)) continue;
        cardOrder.add(matches.first);
        if (cardOrder.length == 4) break;
      }
    } else if (profileVisible) {
      // v3 rooms had two fixed profile fields rather than a card deck.
      if (about.isNotEmpty) cardOrder.add(SpaceCardKind.about);
      if (featuredGoals.isNotEmpty) cardOrder.add(SpaceCardKind.rightNow);
    }
    String safePhotoPath(String key, SharedRoomMediaSlot expectedSlot) {
      if (!visitorPhotoSharingEnabled || !profileVisible) return '';
      final path = safeString(key, '', 160);
      final ownerUid = safeString('uid', '', 128);
      if (path.isEmpty || ownerUid.isEmpty) return '';
      try {
        final location = SharedRoomMediaLocation.fromObjectPath(path);
        if (location.ownerUid != ownerUid ||
            location.roomCode != code.trim().toUpperCase() ||
            location.slot != expectedSlot) {
          return '';
        }
        return location.objectPath;
      } on SharedRoomMediaException {
        return '';
      }
    }

    final profilePhotoPath = safePhotoPath(
      'profilePhotoPath',
      SharedRoomMediaSlot.profile,
    );
    final seasonPhotoPath = cardOrder.contains(SpaceCardKind.thisSeason)
        ? safePhotoPath('seasonPhotoPath', SharedRoomMediaSlot.season)
        : '';

    ({String path, bool fill, Alignment alignment, int width, int height})?
    safeRoomPhoto() {
      if (previewOnly) return null;
      final path = safeString('roomPhotoPath', '', 240);
      final ownerKey = safeString('ownerKey', '', 160);
      final rawWidth = room['roomPhotoWidth'];
      final rawHeight = room['roomPhotoHeight'];
      final rawX = room['roomPhotoX'];
      final rawY = room['roomPhotoY'];
      if (path.isEmpty ||
          ownerKey.isEmpty ||
          rawWidth is! num ||
          rawHeight is! num ||
          rawX is! num ||
          rawY is! num) {
        return null;
      }
      final width = rawWidth.toInt();
      final height = rawHeight.toInt();
      final x = rawX.toDouble();
      final y = rawY.toDouble();
      if (width < 1 ||
          width > RoomPhotoStore.maxDimension ||
          height < 1 ||
          height > RoomPhotoStore.maxDimension ||
          x < -1 ||
          x > 1 ||
          y < -1 ||
          y > 1) {
        return null;
      }
      try {
        final location = SharedRoomMediaLocation.fromObjectPath(path);
        if (location.generation == null ||
            location.ownerKey != ownerKey ||
            location.roomCode != code.trim().toUpperCase() ||
            location.slot != SharedRoomMediaSlot.room) {
          return null;
        }
        return (
          path: location.objectPath,
          fill: room['roomPhotoFill'] == true,
          alignment: Alignment(x, y),
          width: width,
          height: height,
        );
      } on SharedRoomMediaException {
        return null;
      }
    }

    final remoteRoomPhoto = safeRoomPhoto();
    final pinnedMoments = <({String text, DateTime at})>[];
    if (profileVisible && room['pinnedMoments'] is List) {
      for (final raw in room['pinnedMoments'] as List) {
        if (raw is! Map) continue;
        final map = raw.cast<dynamic, dynamic>();
        final text = map['text'] is String
            ? String.fromCharCodes(
                (map['text'] as String).trim().runes.take(240),
              )
            : '';
        final at = map['at'] is num ? (map['at'] as num).toInt() : 0;
        if (text.isEmpty || at < 0) continue;
        pinnedMoments.add((
          text: text,
          at: DateTime.fromMillisecondsSinceEpoch(at),
        ));
        if (pinnedMoments.length == 4) break;
      }
    }
    final season = profileVisible ? safeString('season', '', 180) : '';
    final rawLevel = room['level'];
    final level = rawLevel is num ? rawLevel.toInt().clamp(1, 9999) : 1;
    final rawFurniture = room['furniture'];
    final furniture = rawFurniture is List
        ? rawFurniture.whereType<String>().take(64).toSet()
        : <String>{};
    final rawMemories = room['memories'];
    final memories = rawMemories is num
        ? rawMemories.toInt().clamp(0, 9999)
        : 0;
    final focusUntil = room['focusUntil'] is num
        ? (room['focusUntil'] as num).toInt()
        : 0;
    final focusActive = focusUntil > Clock.now().millisecondsSinceEpoch;
    final focusKind = safeString('focusKind', 'none');
    final weather = safeString('weather', 'unknown');
    final savedWall = safeString('wall');
    final migratedWall = switch (savedWall) {
      'wall_sage' || 'wall_clay' || 'wall_amber' => 'wall_conservatory',
      'wall_plum' || 'wall_indigo' || 'wall_berry' => 'wall_archive',
      _ => savedWall,
    };
    final sharedTheme = spaceThemeById(migratedWall) ?? spaceThemes.first;
    Widget buildRoom(RoomPhotoData? photo) => HomeRoom(
      aspect: 1.5,
      lively: lively,
      unlocked: furniture,
      wall: wallColorsById(sharedTheme.id),
      plateId: sharedTheme.id,
      floor: floorColorsById(safeString('floor')),
      window: safeString('window', 'moon'),
      level: level,
      petAwake: room['awake'] == true,
      emberGlow: flameHueById(safeString('skin')),
      heirloomFlame: heirloomFlameById(safeString('skin')),
      memoryArtifacts: memories,
      parallax: lively ? parallax : null,
      roomPhoto: photo,
    );
    final roomView = previewOnly
        ? buildRoom(previewRoomPhoto)
        : remoteRoomPhoto == null
        ? buildRoom(null)
        : VisitorRoomPhotoLoader(
            key: ValueKey(remoteRoomPhoto.path),
            objectPath: remoteRoomPhoto.path,
            fillFrame: remoteRoomPhoto.fill,
            alignment: remoteRoomPhoto.alignment,
            pixelWidth: remoteRoomPhoto.width,
            pixelHeight: remoteRoomPhoto.height,
            bytesLoader: roomPhotoBytesLoader,
            builder: (_, photo) => buildRoom(photo),
          );

    return Scaffold(
      backgroundColor: Palette.parchment,
      body: WarmBackground(
        themeId: themeId,
        reduceMotion: !lively,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 36),
            children: [
              DetailHeader(
                title: previewOnly
                    ? 'Public preview'
                    : name.isNotEmpty
                    ? '$name’s space'
                    : 'a space',
                accent: Palette.xp,
                subtitle: previewOnly ? 'local preview' : 'visiting · $code',
                pill: 'LV $level',
              ),
              if (previewOnly)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: GlassPanel(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Only Anyone cards appear here. Nothing is published.',
                      textAlign: TextAlign.center,
                      style: Type.body.copyWith(
                        fontSize: 12,
                        color: Palette.textLo,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassPanel(
                  blur: true,
                  child: Column(
                    children: [
                      roomView,
                      const SizedBox(height: 14),
                      if (title.isNotEmpty)
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Type.display.copyWith(
                            fontSize: 20,
                            color: Palette.xpLight,
                            letterSpacing: 1.5,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        sharedTheme.name,
                        style: Type.body.copyWith(
                          fontSize: 12,
                          color: Palette.textLo,
                        ),
                      ),
                      if (memories > 0)
                        Text(
                          '$memories memories held',
                          style: Type.body.copyWith(
                            fontSize: 11.5,
                            color: Palette.textLo,
                          ),
                        ),
                      if (room['todayLit'] == true ||
                          weather != 'unknown' ||
                          focusActive) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            if (room['todayLit'] == true)
                              _StatusChip(
                                icon: Icons.auto_awesome,
                                label: 'LIT TODAY',
                                color: Palette.streak,
                              ),
                            if (weather != 'unknown')
                              _StatusChip(
                                icon: weather == 'low'
                                    ? Icons.nightlight_outlined
                                    : weather == 'bright'
                                    ? Icons.wb_sunny_outlined
                                    : Icons.horizontal_rule,
                                label: '${weather.toUpperCase()} WEATHER',
                                color: weather == 'low'
                                    ? Stat.vit.color
                                    : weather == 'bright'
                                    ? Palette.streak
                                    : Palette.xpLight,
                              ),
                            if (focusActive)
                              _StatusChip(
                                icon: Icons.hourglass_top,
                                label: '${focusKind.toUpperCase()} COMPANY',
                                color: Palette.unlock,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (profileVisible) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _VisitorProfileDeck(
                    displayName: displayName,
                    cardOrder: cardOrder,
                    about: about,
                    featuredGoals: featuredGoals,
                    pinnedMoments: pinnedMoments,
                    season: season,
                    profilePhotoPath: profilePhotoPath,
                    seasonPhotoPath: seasonPhotoPath,
                    photoUrlLoader: photoUrlLoader,
                  ),
                ),
              ],
              if (!profileVisible &&
                  visitorProfileSharingEnabled &&
                  (!previewOnly || visitorProfile != null))
                _VisitorProfileLoader(
                  code: code,
                  initialProfile: visitorProfile,
                  includeMutual:
                      localState?.hearthCircleCodes.contains(
                        code.trim().toUpperCase(),
                      ) ==
                      true,
                  fetcher:
                      spaceProfileFetcher ??
                      CloudSync.instance.fetchSpaceProfile,
                  relationshipSetter:
                      relationshipSetter ??
                      (spaceProfileFetcher == null
                          ? CloudSync.instance.setCircleRelationship
                          : null),
                  ownerKey: discoveryOwnerKey,
                  photoUrlLoader: photoUrlLoader,
                ),
              // The visit ends with something to give, not just something to
              // keep — the same fixed, text-free note the Circle sends.
              if (!previewOnly &&
                  localState?.roomCode != code.trim().toUpperCase()) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _LeaveNoteAction(code: code, sparkSender: sparkSender),
                ),
              ],
              if (!previewOnly && localState != null && onPersist != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _KeepInCircleAction(
                    code: code,
                    publicName: directoryName,
                    ownerKey: discoveryOwnerKey,
                    state: localState!,
                    onPersist: onPersist!,
                  ),
                ),
              ],
              if (!previewOnly &&
                  localState != null &&
                  onPersist != null &&
                  localState!.roomCode != code.trim().toUpperCase()) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ReportOrHideAction(
                    code: code,
                    ownerKey: discoveryOwnerKey,
                    state: localState!,
                    onPersist: onPersist!,
                    onReport: onReportDiscoverableSpace,
                  ),
                ),
              ],
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitorProfileLoader extends StatefulWidget {
  const _VisitorProfileLoader({
    required this.code,
    required this.initialProfile,
    required this.includeMutual,
    required this.fetcher,
    required this.relationshipSetter,
    required this.ownerKey,
    required this.photoUrlLoader,
  });

  final String code;
  final Map<String, dynamic>? initialProfile;
  final bool includeMutual;
  final SpaceProfileFetcher fetcher;
  final SpaceRelationshipSetter? relationshipSetter;
  final String ownerKey;
  final VisitorPhotoUrlLoader? photoUrlLoader;

  @override
  State<_VisitorProfileLoader> createState() => _VisitorProfileLoaderState();
}

class _VisitorProfileLoaderState extends State<_VisitorProfileLoader> {
  Future<Map<String, dynamic>?>? _profile;

  @override
  void initState() {
    super.initState();
    if (widget.initialProfile == null) _profile = _fetch();
  }

  @override
  void didUpdateWidget(covariant _VisitorProfileLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialProfile != oldWidget.initialProfile ||
        widget.code != oldWidget.code ||
        widget.includeMutual != oldWidget.includeMutual ||
        widget.fetcher != oldWidget.fetcher ||
        widget.relationshipSetter != oldWidget.relationshipSetter ||
        widget.ownerKey != oldWidget.ownerKey) {
      _profile = widget.initialProfile == null ? _fetch() : null;
    }
  }

  Future<Map<String, dynamic>?> _fetch() async {
    final relationshipSetter = widget.relationshipSetter;
    if (widget.includeMutual && relationshipSetter != null) {
      await relationshipSetter(
        widget.code,
        ownerKey: widget.ownerKey,
        active: true,
      );
    }
    return widget.fetcher(widget.code, includeMutual: widget.includeMutual);
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialProfile;
    if (initial != null) return _buildProfile(context, initial);
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _VisitorProfileStatus(
            key: ValueKey('visitor-profile-loading'),
            message: 'Opening their page…',
          );
        }
        final profile = snapshot.data;
        return profile == null
            ? const _VisitorProfileStatus(
                key: ValueKey('visitor-profile-absent'),
                message: 'This keeper has not opened a visitor page.',
              )
            : _buildProfile(context, profile);
      },
    );
  }

  Widget _buildProfile(BuildContext context, Map<String, dynamic> profile) {
    String safeString(String key, [int maximum = 180]) {
      final value = profile[key];
      if (value is! String) return '';
      return String.fromCharCodes(value.trim().runes.take(maximum));
    }

    final cardOrder = <SpaceCardKind>[];
    final rawOrder = profile['cardOrder'];
    if (rawOrder is List) {
      for (final raw in rawOrder) {
        if (raw is! String) continue;
        final match = SpaceCardKind.values.where((kind) => kind.name == raw);
        if (match.isEmpty || cardOrder.contains(match.first)) continue;
        cardOrder.add(match.first);
        if (cardOrder.length == SpaceCardKind.values.length) break;
      }
    }
    if (cardOrder.isEmpty) {
      return const _VisitorProfileStatus(
        key: ValueKey('visitor-profile-empty'),
        message:
            'Their page is open, but they have not placed anything here yet.',
      );
    }

    final featuredGoals = <String>[];
    final rawGoals = profile['featuredGoals'];
    if (rawGoals is List) {
      for (final raw in rawGoals) {
        if (raw is! String) continue;
        final value = String.fromCharCodes(raw.trim().runes.take(100));
        if (value.isEmpty || featuredGoals.contains(value)) continue;
        featuredGoals.add(value);
        if (featuredGoals.length == 3) break;
      }
    }

    final pinnedMoments = <({String text, DateTime at})>[];
    final rawMoments = profile['pinnedMoments'];
    if (rawMoments is List) {
      for (final raw in rawMoments) {
        if (raw is! Map) continue;
        final textValue = raw['text'];
        final atValue = raw['at'];
        if (textValue is! String || atValue is! num) continue;
        final text = String.fromCharCodes(textValue.trim().runes.take(240));
        final at = atValue.toInt();
        if (text.isEmpty || at < 0 || at > 9999999999999) continue;
        pinnedMoments.add((
          text: text,
          at: DateTime.fromMillisecondsSinceEpoch(at),
        ));
        if (pinnedMoments.length == 4) break;
      }
    }

    return Padding(
      key: const ValueKey('visitor-external-profile'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: _VisitorProfileDeck(
        displayName: safeString('displayName', 40),
        cardOrder: cardOrder,
        about: safeString('about'),
        featuredGoals: featuredGoals,
        pinnedMoments: pinnedMoments,
        season: safeString('season'),
        profilePhotoPath: '',
        seasonPhotoPath: '',
        photoUrlLoader: widget.photoUrlLoader,
      ),
    );
  }
}

class _VisitorProfileDeck extends StatelessWidget {
  const _VisitorProfileDeck({
    required this.displayName,
    required this.cardOrder,
    required this.about,
    required this.featuredGoals,
    required this.pinnedMoments,
    required this.season,
    required this.profilePhotoPath,
    required this.seasonPhotoPath,
    required this.photoUrlLoader,
  });

  final String displayName;
  final List<SpaceCardKind> cardOrder;
  final String about;
  final List<String> featuredGoals;
  final List<({String text, DateTime at})> pinnedMoments;
  final String season;
  final String profilePhotoPath;
  final String seasonPhotoPath;
  final VisitorPhotoUrlLoader? photoUrlLoader;

  @override
  Widget build(BuildContext context) {
    final visibleCards = [
      for (final kind in cardOrder)
        if (kind == SpaceCardKind.about && about.isNotEmpty ||
            kind == SpaceCardKind.rightNow && featuredGoals.isNotEmpty ||
            kind == SpaceCardKind.pinnedMoments && pinnedMoments.isNotEmpty ||
            kind == SpaceCardKind.thisSeason &&
                (season.isNotEmpty || seasonPhotoPath.isNotEmpty))
          kind,
    ];
    if (visibleCards.isEmpty) {
      return const _VisitorProfileStatus(
        key: ValueKey('visitor-profile-empty'),
        message:
            'Their page is open, but they have not placed anything here yet.',
      );
    }
    return Column(
      key: const ValueKey('visitor-profile-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanel(
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final identity = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THEIR PAGE',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 1.5,
                      color: Palette.xpLight,
                    ),
                  ),
                  if (displayName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      displayName,
                      style: Type.display.copyWith(
                        fontSize: 20,
                        color: Palette.textHi,
                      ),
                    ),
                  ],
                ],
              );
              final badge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: facetedDecoration(
                  cut: 5,
                  color: Palette.xp.withValues(alpha: 0.08),
                  borderColor: Palette.xp.withValues(alpha: 0.30),
                ),
                child: Text(
                  'SHARED BY CHOICE',
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    letterSpacing: 0.8,
                    color: Palette.textLo,
                  ),
                ),
              );
              final compact =
                  MediaQuery.textScalerOf(context).scale(1) > 1.15 ||
                  constraints.maxWidth < 300;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (profilePhotoPath.isNotEmpty) ...[
                      SizedBox(
                        width: 76,
                        child: VisitorSharedRoomPhoto(
                          key: const ValueKey('visitor-profile-photo'),
                          objectPath: profilePhotoPath,
                          semanticLabel: 'Shared profile photo',
                          height: 76,
                          borderRadius: 17,
                          urlLoader: photoUrlLoader,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    identity,
                    const SizedBox(height: 8),
                    badge,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (profilePhotoPath.isNotEmpty) ...[
                    SizedBox(
                      width: 76,
                      child: VisitorSharedRoomPhoto(
                        key: const ValueKey('visitor-profile-photo'),
                        objectPath: profilePhotoPath,
                        semanticLabel: 'Shared profile photo',
                        height: 76,
                        borderRadius: 17,
                        urlLoader: photoUrlLoader,
                      ),
                    ),
                    const SizedBox(width: 11),
                  ],
                  Expanded(child: identity),
                  const SizedBox(width: 10),
                  badge,
                ],
              );
            },
          ),
        ),
        for (final kind in visibleCards) ...[
          const SizedBox(height: 10),
          switch (kind) {
            SpaceCardKind.about => _VisitorSharedCard(
              icon: Icons.auto_stories_outlined,
              title: 'ABOUT',
              accent: Palette.xpLight,
              child: Text(
                about,
                style: Type.body.copyWith(
                  fontSize: 14,
                  height: 1.45,
                  color: Palette.textHi,
                ),
              ),
            ),
            SpaceCardKind.rightNow => _VisitorSharedCard(
              icon: Icons.flag_outlined,
              title: 'RIGHT NOW',
              accent: Palette.success,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < featuredGoals.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.arrow_right_rounded,
                          size: 18,
                          color: Palette.success,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            featuredGoals[i],
                            style: Type.body.copyWith(
                              fontSize: 13,
                              color: Palette.textHi,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            SpaceCardKind.pinnedMoments => _VisitorSharedCard(
              icon: Icons.push_pin_outlined,
              title: 'PINNED MOMENTS',
              accent: const Color(0xFFDDB296),
              child: Column(
                children: [
                  for (var i = 0; i < pinnedMoments.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 17, color: Palette.glassEdge),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        pinnedMoments[i].text,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: Type.body.copyWith(
                          fontSize: 13,
                          height: 1.4,
                          color: Palette.textHi,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(pinnedMoments[i].at),
                        style: Type.label.copyWith(
                          fontSize: Type.minLabel,
                          color: Palette.textLo,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SpaceCardKind.thisSeason => _VisitorSharedCard(
              icon: Icons.filter_vintage_outlined,
              title: 'THIS SEASON',
              accent: Palette.unlock,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (seasonPhotoPath.isNotEmpty) ...[
                    VisitorSharedRoomPhoto(
                      key: const ValueKey('visitor-season-photo'),
                      objectPath: seasonPhotoPath,
                      semanticLabel: 'Shared This season photo',
                      height: 190,
                      borderRadius: 13,
                      urlLoader: photoUrlLoader,
                    ),
                    const SizedBox(height: 11),
                  ],
                  if (season.isNotEmpty)
                    Text(
                      season,
                      style: Type.body.copyWith(
                        fontSize: 14,
                        height: 1.45,
                        color: Palette.textHi,
                      ),
                    ),
                ],
              ),
            ),
          },
        ],
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Only the cards they chose for your audience appear here. Every other Journal page, photo, quest, streak, and account detail stays private.',
            textAlign: TextAlign.center,
            style: Type.body.copyWith(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Palette.textLo,
            ),
          ),
        ),
      ],
    );
  }
}

class _VisitorProfileStatus extends StatelessWidget {
  const _VisitorProfileStatus({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: GlassPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_stories_outlined,
            size: 18,
            color: Palette.textLo,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: Type.body.copyWith(
                fontSize: 12.5,
                height: 1.35,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _VisitorSharedCard extends StatelessWidget {
  const _VisitorSharedCard({
    required this.icon,
    required this.title,
    required this.accent,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(Palette.card, accent, 0.07)!,
          const Color(0xFF1B1411),
        ],
      ),
      border: Border.all(color: accent.withValues(alpha: 0.34)),
      boxShadow: const [
        BoxShadow(
          color: Palette.warmShadow,
          blurRadius: 16,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: accent),
            const SizedBox(width: 7),
            // Flexible so floor-size card titles wrap at accessibility text
            // scales on narrow phones instead of running out of the card.
            Flexible(
              child: Text(
                title,
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  letterSpacing: 1.35,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

/// "Leave a note by their fire" — the reciprocity half of a visit. Reuses the
/// Circle's fixed spark vocabulary; the anonymous session is acquired only on
/// the explicit send, and the rules keep it to one pending note per sender.
class _LeaveNoteAction extends StatefulWidget {
  const _LeaveNoteAction({required this.code, this.sparkSender});

  final String code;
  final SparkSender? sparkSender;

  @override
  State<_LeaveNoteAction> createState() => _LeaveNoteActionState();
}

class _LeaveNoteActionState extends State<_LeaveNoteAction> {
  bool _busy = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.card,
          content: Text(
            message,
            style: Type.body.copyWith(color: Palette.textHi),
          ),
        ),
      );
  }

  Future<void> _leaveNote() async {
    Sfx.instance.playMaterial(MaterialSound.glass);
    final kind = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Palette.dialogBarrier,
      builder: (_) => const SparkPickerSheet(),
    );
    if (kind == null || !mounted) return;
    setState(() => _busy = true);
    final sender = widget.sparkSender;
    final safeKind = normalizedSparkKind(kind);
    SparkSendResult result;
    if (sender != null) {
      result = await sender(widget.code, safeKind)
          ? SparkSendResult.sent
          : SparkSendResult.failed;
    } else if (!await CloudSync.instance.ensureSocialSession()) {
      result = SparkSendResult.failed;
    } else {
      result = await CloudSync.instance.sendSpark(widget.code, kind: safeKind);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case SparkSendResult.sent:
        Sfx.instance.play('streak');
        HapticFeedback.mediumImpact();
        _toast(
          '${sparkSupportReceiptLabel(safeKind)} is waiting by their fire.',
        );
      case SparkSendResult.alreadyWaiting:
        _toast('A note from you is already waiting by their fire.');
      case SparkSendResult.failed:
        _toast('The connection went quiet — try again in a bit.');
    }
  }

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          enabled: !_busy,
          label: 'Leave a note by their fire',
          child: GestureDetector(
            key: const ValueKey('visit-room-note-action'),
            behavior: HitTestBehavior.opaque,
            onTap: _busy ? null : _leaveNote,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: facetedDecoration(
                  cut: 9,
                  color: Palette.streak.withValues(alpha: 0.10),
                  borderColor: Palette.streak.withValues(alpha: 0.40),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    EmberFlameIcon(
                      size: 18,
                      color: _busy ? Palette.textLo : Palette.streak,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _busy ? 'LEAVING IT…' : 'LEAVE A NOTE BY THEIR FIRE',
                        textAlign: TextAlign.center,
                        style: Type.label.copyWith(
                          fontSize: Type.minLabel,
                          letterSpacing: 1.1,
                          color: _busy ? Palette.textLo : Palette.streak,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'One fixed note, no message attached. They collect it at their own hearth.',
          style: Type.body.copyWith(
            fontSize: 11.5,
            height: 1.35,
            color: Palette.textLo,
          ),
        ),
      ],
    ),
  );
}

class _KeepInCircleAction extends StatelessWidget {
  const _KeepInCircleAction({
    required this.code,
    required this.publicName,
    required this.ownerKey,
    required this.state,
    required this.onPersist,
  });

  final String code;
  final String publicName;
  final String ownerKey;
  final GameState state;
  final VoidCallback onPersist;

  Future<bool> _notifyOwner(String normalized) async {
    final cloud = CloudSync.instance;
    if (!await cloud.ensureAvailable() || !await cloud.ensureSocialSession()) {
      return false;
    }
    final related = await cloud.setCircleRelationship(
      normalized,
      ownerKey: ownerKey,
      active: true,
    );
    if (related) unawaited(cloud.sendCircleAdd(normalized));
    return related;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final normalized = code.trim().toUpperCase();
        final own = normalized == state.roomCode;
        final saved = state.hearthCircleCodes.contains(normalized);
        final enabled = !own && !saved;
        final label = own
            ? 'THIS IS YOUR SPACE'
            : saved
            ? 'IN YOUR CIRCLE'
            : 'KEEP IN MY CIRCLE';
        final detail = own
            ? 'You are visiting the room attached to your own share code.'
            : saved
            ? 'Saved with your trusted spaces.'
            : 'Save this space so it is easy to visit again.';
        final icon = own
            ? Icons.home_outlined
            : saved
            ? Icons.bookmark_added_outlined
            : Icons.bookmark_add_outlined;
        final accent = enabled ? Palette.xpLight : Palette.textLo;

        Future<void> add() async {
          if (!enabled ||
              !state.addCircleCode(
                normalized,
                publicName: publicName,
                ownerKey: ownerKey,
              )) {
            return;
          }
          onPersist();
          final synced = await _notifyOwner(normalized);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  synced
                      ? 'Kept in your Circle. Mutual cards unlock when they keep you too.'
                      : 'Kept on this device. Reconnect later to enable mutual cards.',
                  style: Type.body.copyWith(color: Palette.textHi),
                ),
                backgroundColor: Palette.card,
                behavior: SnackBarBehavior.floating,
              ),
            );
        }

        return GlassPanel(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                enabled: enabled,
                label: label,
                child: GestureDetector(
                  key: const ValueKey('visit-room-circle-action'),
                  behavior: HitTestBehavior.opaque,
                  onTap: enabled ? add : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: facetedDecoration(
                        cut: 9,
                        color: enabled
                            ? Palette.xp.withValues(alpha: 0.12)
                            : Palette.glassFill,
                        borderColor: enabled
                            ? Palette.xp.withValues(alpha: 0.44)
                            : Palette.glassEdge,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 18, color: accent),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: Type.label.copyWith(
                                fontSize: Type.minLabel,
                                letterSpacing: 1.1,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                detail,
                style: Type.body.copyWith(
                  fontSize: 11.5,
                  height: 1.35,
                  color: Palette.textLo,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportOrHideAction extends StatelessWidget {
  const _ReportOrHideAction({
    required this.code,
    required this.ownerKey,
    required this.state,
    required this.onPersist,
    required this.onReport,
  });

  final String code;
  final String ownerKey;
  final GameState state;
  final VoidCallback onPersist;
  final DiscoverySpaceReporter? onReport;

  Future<void> _open(BuildContext context) async {
    final choice = await showDialog<String>(
      context: context,
      barrierColor: Palette.dialogBarrier,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        backgroundColor: Palette.dialogSurface,
        shape: const FacetedBorder(cut: 12),
        title: Text(
          'Block or report this keeper?',
          style: Type.display.copyWith(fontSize: 20, color: Palette.textHi),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Blocking hides this room and any future public room from the same keeper on this device. Reports are private and never tell them who sent one.',
              style: Type.body.copyWith(
                fontSize: 13,
                height: 1.4,
                color: Palette.textMid,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Palette.glassEdge),
            const SizedBox(height: 6),
            _DiscoverySafetyChoice(
              key: const ValueKey('discover-hide-space'),
              icon: Icons.visibility_off_outlined,
              label: 'BLOCK THIS KEEPER',
              color: Palette.xpLight,
              onTap: () => Navigator.of(dialogContext).pop('hide'),
            ),
            if (onReport != null) ...[
              _DiscoverySafetyChoice(
                key: const ValueKey('discover-report-name'),
                icon: Icons.flag_outlined,
                label: 'REPORT THIS NAME',
                color: Palette.danger,
                onTap: () =>
                    Navigator.of(dialogContext).pop('inappropriate_name'),
              ),
              _DiscoverySafetyChoice(
                key: const ValueKey('discover-report-impersonation'),
                icon: Icons.badge_outlined,
                label: 'REPORT IMPERSONATION',
                color: Palette.danger,
                onTap: () => Navigator.of(dialogContext).pop('impersonation'),
              ),
              _DiscoverySafetyChoice(
                key: const ValueKey('discover-report-other'),
                icon: Icons.report_outlined,
                label: 'REPORT THIS PAGE',
                color: Palette.danger,
                onTap: () => Navigator.of(dialogContext).pop('other'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'CANCEL',
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: Palette.textLo,
              ),
            ),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;

    final normalized = code.trim().toUpperCase();
    state.blockDiscoveryOwner(ownerKey, normalized);
    onPersist();
    final serverBlocked = await CloudSync.instance.setSpaceBlock(
      normalized,
      ownerKey: ownerKey,
      blocked: true,
    );
    final reported = choice == 'hide' || onReport == null
        ? null
        : await onReport!(normalized, choice);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.card,
          content: Text(
            choice == 'hide'
                ? serverBlocked
                      ? 'This keeper is blocked. Mutual access was removed.'
                      : 'This keeper is hidden on this device. Reconnect to finish blocking mutual access.'
                : reported == true
                ? serverBlocked
                      ? 'Blocked. Your private report was sent.'
                      : 'Hidden here and reported. Reconnect to finish blocking mutual access.'
                : 'Hidden on this device. The report or mutual-access block could not be sent yet.',
            style: Type.body.copyWith(color: Palette.textHi),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const ValueKey('discover-report-or-hide'),
    onPressed: () => _open(context),
    icon: const Icon(Icons.visibility_off_outlined, size: 15),
    label: Text(
      onReport == null ? 'BLOCK THIS KEEPER' : 'BLOCK OR REPORT THIS KEEPER',
      style: Type.label.copyWith(fontSize: Type.minLabel),
    ),
    style: TextButton.styleFrom(
      minimumSize: const Size.fromHeight(44),
      foregroundColor: Palette.textLo,
    ),
  );
}

class _DiscoverySafetyChoice extends StatelessWidget {
  const _DiscoverySafetyChoice({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 17),
    label: Text(
      label,
      style: Type.label.copyWith(fontSize: Type.minLabel, color: color),
    ),
    style: TextButton.styleFrom(
      alignment: Alignment.centerLeft,
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      minimumSize: const Size.fromHeight(44),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      border: Border.all(color: color.withValues(alpha: 0.34)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        // Flexible so a floor-size label at accessibility text scales wraps
        // inside the chip instead of pushing past the Wrap's width.
        Flexible(
          child: Text(
            label,
            style: Type.label.copyWith(fontSize: Type.minLabel, color: color),
          ),
        ),
      ],
    ),
  );
}
