import 'dart:collection';

import 'package:flutter/foundation.dart' show ChangeNotifier, ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio.dart';
import 'clock.dart';
import 'cloud.dart';
import 'content/creature_skins.dart';
import 'content/links.dart';
import 'engine.dart';
import 'models.dart';
import 'release_features.dart';
import 'platform/share_stub.dart'
    if (dart.library.js_interop) 'platform/share_web.dart';
import 'screens/visit_room.dart';
import 'shared_room_media.dart';
import 'tokens.dart';
import 'widgets/facets.dart';
import 'widgets/glass.dart';
import 'widgets/honey_button.dart';

bool _sharingSpace = false;
final RegExp _roomCodePattern = RegExp(
  r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$',
);

typedef RoomFetcher = Future<Map<String, dynamic>?> Function(String code);

// The single public origin lives in content/links.dart; this alias keeps
// the existing call sites and the SHARE_BASE_URL dart-define working.
const String _defaultRoomInviteBaseUrl = PublicLinks.home;

/// Extracts the bearer code from a shared Room of Days link. Query links are
/// the stable public format; the path form is accepted so a future native
/// universal-link setup will not need a second parser.
String? roomCodeFromUri(Uri uri) {
  final candidates = <String?>[
    uri.queryParameters['space'],
    uri.queryParameters['room'],
    if (uri.pathSegments.length >= 2 &&
        const {'space', 'room'}.contains(uri.pathSegments.first.toLowerCase()))
      uri.pathSegments[1],
  ];
  for (final raw in candidates) {
    final code = raw?.trim().toUpperCase() ?? '';
    if (_roomCodePattern.hasMatch(code)) return code;
  }
  return null;
}

/// Whether a URI names the shared-space surface at all — with or without a
/// valid code. Once native app links claim /space/*, this is what decides
/// that a malformed invite still opens the visit prompt rather than nothing.
bool uriNamesSharedSpace(Uri uri) =>
    uri.queryParameters.containsKey('space') ||
    uri.queryParameters.containsKey('room') ||
    (uri.pathSegments.isNotEmpty &&
        const {'space', 'room'}.contains(uri.pathSegments.first.toLowerCase()));

/// One accepted room-link delivery.
///
/// The sequence makes two taps on the same link distinct events. A friend can
/// send the same room again later and the already-running app should still
/// open it, rather than silently treating the string as unchanged state.
class RoomLinkEvent {
  const RoomLinkEvent({required this.code, required this.sequence});

  final String code;
  final int sequence;
}

/// A small FIFO between Flutter's platform route channel and the loaded app.
///
/// iOS can deliver a universal link shortly after a cold launch, while Android
/// may put it in the initial route. Keeping accepted links here means neither
/// case races cloud startup or onboarding, and a warm link can arrive while a
/// visitor sheet for another room is still open.
class RoomLinkInbox extends ChangeNotifier {
  final Queue<RoomLinkEvent> _pending = Queue<RoomLinkEvent>();
  var _sequence = 0;

  bool get isNotEmpty => _pending.isNotEmpty;

  bool enqueueUri(Uri uri) {
    final code = roomCodeFromUri(uri);
    return code != null && enqueueCode(code);
  }

  bool enqueueCode(String raw) {
    final code = raw.trim().toUpperCase();
    if (!_roomCodePattern.hasMatch(code)) return false;
    _pending.add(RoomLinkEvent(code: code, sequence: ++_sequence));
    notifyListeners();
    return true;
  }

  /// Claims a link that names the space path but carries no usable code — a
  /// bare /space, or a typo'd one. The tap still deserves a destination (the
  /// visit prompt, where the code field explains itself) instead of falling
  /// through to the Navigator as an unknown named route and doing nothing.
  bool enqueuePrompt() {
    _pending.add(RoomLinkEvent(code: '', sequence: ++_sequence));
    notifyListeners();
    return true;
  }

  RoomLinkEvent? takeNext() => _pending.isEmpty ? null : _pending.removeFirst();

  @override
  void dispose() {
    _pending.clear();
    super.dispose();
  }
}

String roomInviteUrl(
  String code, {
  String baseUrl = const String.fromEnvironment(
    'SHARE_BASE_URL',
    defaultValue: _defaultRoomInviteBaseUrl,
  ),
}) {
  final clean = code.trim().toUpperCase();
  final base = Uri.parse(baseUrl);
  final query = Map<String, String>.from(base.queryParameters)
    ..remove('space')
    ..remove('room');
  return base
      .replace(
        pathSegments: [
          ...base.pathSegments.where((segment) => segment.isNotEmpty),
          'space',
          clean,
        ],
        queryParameters: query,
      )
      .toString();
}

/// The message a person actually sends a friend, so it has to read like one.
///
/// The previous copy announced itself in the third person ("X is sharing a
/// Room of Days space with you"), which reads as a notification from an app
/// rather than a note from someone you know, and then spent its last and most
/// visible line explaining what to do when the link fails. Leading with an
/// apology for your own link is the fastest way to make it look unsafe to tap.
///
/// What a recipient needs, in order: who this is and why they'd care, the
/// link, and only then the fallback — plus one clause telling them the link
/// costs them nothing, because an unfamiliar host in a text message is the
/// real reason people don't tap.
String roomInviteText(String code, {String? ownerName}) {
  final clean = code.trim().toUpperCase();
  final name = _sharedProfileText(ownerName, 40);
  final opening = name.isEmpty
      ? 'Come see my room. It’s built out of the days I’ve actually been '
            'keeping.'
      : 'Come see my room. I’m $name in there, and it’s built out of the days '
            'I’ve actually been keeping.';
  return '$opening\n\n${roomInviteUrl(clean)}\n\n'
      'It opens in a browser—nothing to install. If you already use Room of '
      'Days, the code is $clean.';
}

/// A local name enters the platform share sheet only under the same explicit
/// visitor-page consent that publishes it with the room. Keeping the visitor
/// page closed must also keep the invite itself anonymous.
String? roomInviteOwnerName(
  GameState state, {
  bool visitorProfileSharingEnabled = kVisitorProfileSharingEnabled,
}) => visitorProfileSharingEnabled && state.shareSpaceProfile
    ? state.playerName
    : null;

String circleAddNoticeText(int count) => count == 1
    ? 'Someone added your space to their Circle.'
    : '$count people added your space to their Circles.';

String _sharedProfileText(String? value, int maxCharacters) {
  final collapsed = (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return String.fromCharCodes(collapsed.runes.take(maxCharacters));
}

/// Returns the two device-local files the keeper separately chose to place on
/// their visitor page. These names are used only at the upload boundary and
/// never enter the public room document.
Map<SharedRoomMediaSlot, String> selectedSharedRoomPhotoFiles(
  GameState s, {
  bool visitorPhotoSharingEnabled = kVisitorPhotoSharingEnabled,
  bool visitorProfileSharingEnabled = kVisitorProfileSharingEnabled,
}) {
  if (!visitorPhotoSharingEnabled ||
      !visitorProfileSharingEnabled ||
      !s.shareSpaceProfile) {
    return const {};
  }
  final selected = <SharedRoomMediaSlot, String>{};
  final profile = s.spaceProfilePhotoNote;
  if (s.shareSpaceProfilePhoto && profile != null) {
    selected[SharedRoomMediaSlot.profile] = profile.images.first;
  }
  final season = s.spaceSeasonPhotoNote;
  if (s.shareSpaceSeasonPhoto &&
      s.visitorSpaceCards.contains(SpaceCardKind.thisSeason) &&
      season != null) {
    selected[SharedRoomMediaSlot.season] = season.images.first;
  }
  return Map.unmodifiable(selected);
}

String _sharedPhotoPath({
  required Map<SharedRoomMediaSlot, String> selected,
  required Map<SharedRoomMediaSlot, String> objectPaths,
  required SharedRoomMediaSlot slot,
  required String? ownerUid,
  required String? roomCode,
}) {
  if (!selected.containsKey(slot)) return '';
  final objectPath = objectPaths[slot];
  if (objectPath == null || objectPath.isEmpty) return '';
  try {
    final location = SharedRoomMediaLocation.fromObjectPath(objectPath);
    if (location.slot != slot ||
        (ownerUid != null && location.ownerUid != ownerUid) ||
        (roomCode != null &&
            location.roomCode != roomCode.trim().toUpperCase())) {
      return '';
    }
    return location.objectPath;
  } on SharedRoomMediaException {
    return '';
  }
}

Map<SharedRoomMediaSlot, String> _stateSharedRoomPhotoPaths(GameState state) =>
    {
      if (state.spaceProfilePhotoPath.isNotEmpty)
        SharedRoomMediaSlot.profile: state.spaceProfilePhotoPath,
      if (state.spaceSeasonPhotoPath.isNotEmpty)
        SharedRoomMediaSlot.season: state.spaceSeasonPhotoPath,
    };

/// The bounded payload published for a shared space. Account data, quest
/// history, and unselected Journal pages stay out. A photo contributes only a
/// exact, versioned Storage object path after separate consent; local
/// filenames, download URLs, and bytes never enter this map.
Map<String, dynamic> roomDisplay(
  GameState s, {
  String? mediaOwnerUid,
  String? mediaRoomCode,
  Map<SharedRoomMediaSlot, String>? mediaObjectPaths,
  bool visitorPhotoSharingEnabled = kVisitorPhotoSharingEnabled,
  bool visitorProfileSharingEnabled = kVisitorProfileSharingEnabled,
}) {
  final milestoneGoals = s.goals
      .where((g) => g.complete || g.progress >= 25)
      .length;
  final hearthMemories = [
    5,
    10,
    16,
    24,
    34,
  ].where((level) => s.level >= level).length;
  final memories =
      s.memoryPins.length +
      s.unlockedAchievements.length +
      milestoneGoals +
      hearthMemories;
  final profileVisible = visitorProfileSharingEnabled && s.shareSpaceProfile;
  // Energy weather is a private daily capacity lens (engine.dart). It leaves
  // the device only through the same door as the rest of the person: the
  // explicit visitor-profile opt-in. Code bearers without that opt-in see
  // 'unknown', same as an unset day.
  final weather = profileVisible && s.energyWeatherDay == Days.key(Clock.now())
      ? s.energyWeather.name
      : 'unknown';
  final sharedCards = profileVisible
      ? <SpaceCardKind>[
          for (final kind in s.spaceCardOrder)
            if (s.visitorSpaceCards.contains(kind)) kind,
        ]
      : const <SpaceCardKind>[];
  final aboutVisible = sharedCards.contains(SpaceCardKind.about);
  final rightNowVisible = sharedCards.contains(SpaceCardKind.rightNow);
  final momentsVisible = sharedCards.contains(SpaceCardKind.pinnedMoments);
  final seasonVisible = sharedCards.contains(SpaceCardKind.thisSeason);
  final displayName = profileVisible
      ? _sharedProfileText(s.playerName, 40)
      : '';
  final about = profileVisible && aboutVisible
      ? _sharedProfileText(s.spaceIntro, 180)
      : '';
  final featuredGoals = profileVisible && rightNowVisible
      ? <String>[
          for (final title in s.featuredGoalTitles)
            _sharedProfileText(title, 100),
        ].where((title) => title.isNotEmpty).toSet().take(3).toList()
      : const <String>[];
  final pinnedMoments = momentsVisible
      ? <Map<String, dynamic>>[
          for (final note in s.journal.reversed)
            if (s.memoryPins.contains(note.id) &&
                _sharedProfileText(note.text, 240).isNotEmpty)
              {
                'text': _sharedProfileText(note.text, 240),
                'at': note.at.millisecondsSinceEpoch,
              },
        ].take(4).toList()
      : const <Map<String, dynamic>>[];
  final season = seasonVisible
      ? _sharedProfileText(s.spaceSeasonText, 180)
      : '';
  final selectedPhotos = selectedSharedRoomPhotoFiles(
    s,
    visitorPhotoSharingEnabled: visitorPhotoSharingEnabled,
    visitorProfileSharingEnabled: visitorProfileSharingEnabled,
  );
  final publishedPhotoPaths = mediaObjectPaths ?? _stateSharedRoomPhotoPaths(s);
  return {
    // The legacy fixed field remains for older clients; bounded, deliberately
    // selected profile writing lives only in the explicit v4 fields below.
    'name': 'Fellow keeper',
    'title': s.buildTitle,
    'level': s.level,
    'furniture': s.ownedFurniture.toList(),
    'wall': s.wallStyle,
    'floor': s.floorStyle,
    'skin': flameSkinIdFor(s),
    'window': s.windowScene,
    'awake': s.streakDays > 0,
    'memories': memories.clamp(0, 9999),
    'weather': weather,
    'todayLit': (s.history[Days.key(Clock.now())] ?? 0) > 0,
    'focusKind': s.quietCompanyActive ? s.quietCompanyKind : 'none',
    'focusUntil': s.quietCompanyActive ? s.quietCompanyUntil : 0,
    'profileVisible': profileVisible,
    'displayName': displayName,
    'cardOrder': [for (final kind in sharedCards) kind.name],
    'about': about,
    'featuredGoals': featuredGoals,
    'pinnedMoments': pinnedMoments,
    'season': season,
    'profilePhotoPath': _sharedPhotoPath(
      selected: selectedPhotos,
      objectPaths: publishedPhotoPaths,
      slot: SharedRoomMediaSlot.profile,
      ownerUid: mediaOwnerUid,
      roomCode: mediaRoomCode,
    ),
    'seasonPhotoPath': _sharedPhotoPath(
      selected: selectedPhotos,
      objectPaths: publishedPhotoPaths,
      slot: SharedRoomMediaSlot.season,
      ownerUid: mediaOwnerUid,
      roomCode: mediaRoomCode,
    ),
    'v': 5,
  };
}

/// Narrow, injectable boundary for the acknowledged visitor-page transaction.
/// Production delegates to [CloudSync]; tests can prove ordering without a
/// Firebase app or a second private CloudSync constructor.
class RoomPublicationClient {
  const RoomPublicationClient({
    required this.ensureAvailable,
    required this.ensureSocialSession,
    required this.ownerUid,
    required this.fetchRoom,
    required this.publishRoom,
    required this.unshareRoom,
  });

  factory RoomPublicationClient.cloud(CloudSync cloud) => RoomPublicationClient(
    ensureAvailable: cloud.ensureAvailable,
    ensureSocialSession: cloud.ensureSocialSession,
    ownerUid: () => cloud.socialUid,
    fetchRoom: cloud.fetchRoom,
    publishRoom: (display, {code}) => cloud.publishRoom(display, code: code),
    unshareRoom: cloud.unshareRoom,
  );

  final Future<bool> Function() ensureAvailable;
  final Future<bool> Function() ensureSocialSession;
  final String? Function() ownerUid;
  final Future<Map<String, dynamic>?> Function(String code) fetchRoom;
  final Future<RoomPublishResult> Function(
    Map<String, dynamic> display, {
    String? code,
  })
  publishRoom;
  final Future<bool> Function(String code) unshareRoom;
}

Map<SharedRoomMediaSlot, String> _publishedRoomPhotoPaths(
  Map<String, dynamic>? room, {
  required String ownerUid,
  required String roomCode,
}) {
  if (room?['uid'] != ownerUid) return const {};
  final paths = <SharedRoomMediaSlot, String>{};
  for (final entry in const {
    SharedRoomMediaSlot.profile: 'profilePhotoPath',
    SharedRoomMediaSlot.season: 'seasonPhotoPath',
  }.entries) {
    final raw = room?[entry.value];
    if (raw is! String || raw.isEmpty) continue;
    try {
      final location = SharedRoomMediaLocation.fromObjectPath(raw);
      if (location.ownerUid == ownerUid &&
          location.roomCode == roomCode &&
          location.slot == entry.key) {
        paths[entry.key] = location.objectPath;
      }
    } on SharedRoomMediaException {
      // A malformed restored/public value is never copied into a new write.
    }
  }
  return Map.unmodifiable(paths);
}

/// Publishes one exact visitor-page state while coordinating its two optional
/// Storage objects. The current public state is refreshed first so a failed
/// photo operation cannot accidentally publish an uncommitted text edit.
Future<RoomPublishResult> publishSpaceRoomState(
  GameState target, {
  required GameState current,
  required String? code,
  CloudSync? cloudSync,
  SharedRoomMediaService? mediaService,
  RoomPublicationClient? publicationClient,
  bool visitorPhotoSharingEnabled = kVisitorPhotoSharingEnabled,
  bool visitorProfileSharingEnabled = kVisitorProfileSharingEnabled,
}) async {
  final cloud = cloudSync ?? CloudSync.instance;
  final publication = publicationClient ?? RoomPublicationClient.cloud(cloud);
  if (!await publication.ensureAvailable() ||
      !await publication.ensureSocialSession()) {
    return const RoomPublishResult.failed(RoomPublishFailure.unavailable);
  }
  final ownerUid = publication.ownerUid();
  if (ownerUid == null) {
    return const RoomPublishResult.failed(RoomPublishFailure.unavailable);
  }

  // The v1 store candidate takes this route. It writes a complete v5 room with
  // no user-authored profile or photo handles in one acknowledged Firestore
  // operation and never constructs a Firebase Storage client. A successful
  // write also forgets stale pre-release consent so a later opt-in build cannot
  // revive it without a new deliberate choice.
  if (!visitorProfileSharingEnabled || !visitorPhotoSharingEnabled) {
    final display = roomDisplay(
      target,
      mediaOwnerUid: ownerUid,
      mediaRoomCode: code,
      visitorPhotoSharingEnabled: visitorPhotoSharingEnabled,
      visitorProfileSharingEnabled: visitorProfileSharingEnabled,
    );
    final published = await publication.publishRoom(display, code: code);
    if (published.ok) {
      if (!visitorProfileSharingEnabled) {
        target.disableVisitorProfileSharing();
      } else if (!visitorPhotoSharingEnabled) {
        target.disableVisitorPhotoSharing();
      }
    }
    return published;
  }

  final normalizedInputCode = code?.trim().toUpperCase();
  final existingRoom =
      normalizedInputCode != null &&
          _roomCodePattern.hasMatch(normalizedInputCode)
      ? await publication.fetchRoom(normalizedInputCode)
      : null;
  final pathSource =
      existingRoom ??
      {
        'uid': ownerUid,
        'profilePhotoPath': current.spaceProfilePhotoPath,
        'seasonPhotoPath': current.spaceSeasonPhotoPath,
      };
  var previousPaths = normalizedInputCode == null
      ? const <SharedRoomMediaSlot, String>{}
      : _publishedRoomPhotoPaths(
          pathSource,
          ownerUid: ownerUid,
          roomCode: normalizedInputCode,
        );
  final currentDisplay = roomDisplay(
    current,
    mediaOwnerUid: ownerUid,
    mediaRoomCode: normalizedInputCode,
    mediaObjectPaths: previousPaths,
    visitorPhotoSharingEnabled: true,
    visitorProfileSharingEnabled: true,
  );
  final reserved = await publication.publishRoom(currentDisplay, code: code);
  final finalCode = reserved.code;
  if (finalCode == null) return reserved;

  final createdNew =
      normalizedInputCode == null || normalizedInputCode != finalCode;
  if (createdNew) previousPaths = const {};
  final previousFiles = createdNew
      ? const <SharedRoomMediaSlot, String>{}
      : selectedSharedRoomPhotoFiles(
          current,
          visitorPhotoSharingEnabled: true,
          visitorProfileSharingEnabled: true,
        );
  final selected = selectedSharedRoomPhotoFiles(
    target,
    visitorPhotoSharingEnabled: true,
    visitorProfileSharingEnabled: true,
  );
  final changed = <SharedRoomMediaSlot, String>{
    for (final entry in selected.entries)
      if (createdNew ||
          previousFiles[entry.key] != entry.value ||
          !previousPaths.containsKey(entry.key))
        entry.key: entry.value,
  };
  final media = mediaService ?? SharedRoomMediaService.instance;
  var uploaded = const <SharedRoomMediaSlot, String>{};

  Future<void> abandonNewRoom() async {
    if (createdNew) await publication.unshareRoom(finalCode);
  }

  Future<void> removeUploaded() async {
    if (uploaded.isEmpty) return;
    try {
      await media.deleteObjectPaths(uploaded.values);
    } on SharedRoomMediaException {
      // The paths are unreferenced and unguessable. Preserve the primary
      // failure; a future owner cleanup can remove any rare orphan.
    }
  }

  try {
    if (changed.isNotEmpty) {
      uploaded = await media.syncSelected(
        ownerUid: ownerUid,
        roomCode: finalCode,
        selectedLocalFilenames: changed,
      );
    }
    // Remove replaced/revoked public bytes before the room document changes.
    // If the final publish fails, the previous card can show a missing image,
    // but it can never expose the uncommitted replacement.
    final supersededPaths = <String>{
      for (final entry in previousPaths.entries)
        if (!selected.containsKey(entry.key) || changed.containsKey(entry.key))
          entry.value,
    };
    if (supersededPaths.isNotEmpty) {
      await media.deleteObjectPaths(supersededPaths);
    }
  } on SharedRoomMediaException {
    await removeUploaded();
    await abandonNewRoom();
    return const RoomPublishResult.failed(RoomPublishFailure.media);
  }

  final finalPaths = <SharedRoomMediaSlot, String>{};
  for (final slot in selected.keys) {
    final path = uploaded[slot] ?? previousPaths[slot];
    if (path != null) finalPaths[slot] = path;
  }
  final display = roomDisplay(
    target,
    mediaOwnerUid: ownerUid,
    mediaRoomCode: finalCode,
    mediaObjectPaths: finalPaths,
    visitorPhotoSharingEnabled: true,
    visitorProfileSharingEnabled: true,
  );
  final published = await publication.publishRoom(display, code: finalCode);
  if (!published.ok) {
    await removeUploaded();
    await abandonNewRoom();
    return published;
  }
  target.setSharedRoomPhotoPaths(
    profilePath: finalPaths[SharedRoomMediaSlot.profile] ?? '',
    seasonPath: finalPaths[SharedRoomMediaSlot.season] ?? '',
  );
  return RoomPublishResult.success(
    published.code!,
    rotatedStaleCode: reserved.rotatedStaleCode || published.rotatedStaleCode,
  );
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Palette.textHi)),
        backgroundColor: Palette.card,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// Publish (or refresh) your space and show its share code.
Future<void> shareSpace(
  BuildContext context,
  GameState state,
  VoidCallback onPersist,
) async {
  final cloud = CloudSync.instance;
  if (_sharingSpace) {
    _toast(context, 'Your share is already opening.');
    return;
  }
  _sharingSpace = true;
  try {
    if (!await cloud.ensureAvailable()) {
      if (context.mounted) {
        _toast(context, 'Sharing needs a connection — try again in a moment.');
      }
      return;
    }
    if (!await cloud.ensureSocialSession()) {
      if (context.mounted) {
        _toast(context, 'Couldn’t connect sharing — try again.');
      }
      return;
    }
    Sfx.instance.playMaterial(MaterialSound.brass);
    final published = await publishSpaceRoomState(
      state,
      current: state,
      code: state.roomCode,
      cloudSync: cloud,
    );
    if (!context.mounted) return;
    final code = published.code;
    if (code == null) {
      final message = switch (published.failure) {
        RoomPublishFailure.permissionDenied =>
          'Sharing is updating on our side. Please try again shortly.',
        RoomPublishFailure.timedOut || RoomPublishFailure.network =>
          'The connection went quiet. Your space is safe — try again.',
        RoomPublishFailure.media =>
          'That photo could not be shared. Try another JPEG, PNG, or WebP under 3 MB.',
        RoomPublishFailure.exhaustedCodes =>
          'Couldn’t reserve a share code. Please try once more.',
        _ => 'Couldn’t share right now — try again.',
      };
      _toast(context, message);
      return;
    }
    if (state.roomCode != code) {
      state.setRoomCode(code);
      onPersist();
    }
    final sharedRoom = roomDisplay(
      state,
      mediaOwnerUid: cloud.socialUid,
      mediaRoomCode: code,
    );
    Sfx.instance.play('loot');
    await showShareSpaceDialog(
      context,
      code: code,
      ownerName: roomInviteOwnerName(state),
      rotatedCode: published.rotatedStaleCode,
      onPreview: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => VisitRoomScreen(
            room: sharedRoom,
            code: code,
            themeId: state.canvasTheme,
            lively: !state.reduceMotion,
          ),
        ),
      ),
      onStop: () async {
        final stopped = await cloud.unshareRoom(code);
        if (!stopped) return false;
        state.setRoomCode(null);
        onPersist();
        return true;
      },
    );
  } finally {
    _sharingSpace = false;
  }
}

Future<void> showShareSpaceDialog(
  BuildContext context, {
  required String code,
  required Future<bool> Function() onStop,
  String? ownerName,
  bool rotatedCode = false,
  VoidCallback? onPreview,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Palette.dialogBarrier,
    builder: (_) => _ShareDialog(
      code: code,
      ownerName: ownerName,
      rotatedCode: rotatedCode,
      onPreview: onPreview,
      onStop: onStop,
    ),
  );
}

/// Prompt for a room code and keep the dialog open while the shared room is
/// validated and fetched. Circle and one-off visits share this exact handoff.
Future<SharedRoomVisit?> promptForSharedRoom(
  BuildContext context, {
  RoomFetcher? fetcher,
  String? initialCode,
  bool autoSubmit = false,
}) async {
  if (fetcher == null) {
    final cloud = CloudSync.instance;
    if (!await cloud.ensureAvailable()) {
      if (context.mounted) {
        _toast(context, 'Visiting needs a connection — try again in a moment.');
      }
      return null;
    }
    if (!context.mounted) return null;
    // Exact-code room reads are public bearer-key reads. Visiting should not
    // create an anonymous identity; one is acquired later only if the visitor
    // chooses a social write such as keeping the room in their Circle.
  }
  return showDialog<SharedRoomVisit>(
    context: context,
    builder: (_) => _VisitPrompt(
      fetcher: fetcher ?? CloudSync.instance.fetchRoom,
      initialCode: initialCode,
      autoSubmit: autoSubmit,
    ),
  );
}

/// Prompt for a code and open that shared space.
Future<void> visitSpace(
  BuildContext context, {
  String? themeId,
  bool lively = true,
  ValueListenable<Offset>? parallax,
  GameState? state,
  VoidCallback? onPersist,
  RoomFetcher? fetcher,
  String? initialCode,
  bool autoSubmit = false,
}) async {
  final result = await promptForSharedRoom(
    context,
    fetcher: fetcher,
    initialCode: initialCode,
    autoSubmit: autoSubmit,
  );
  if (result == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => VisitRoomScreen(
        room: result.room,
        code: result.code,
        themeId: themeId,
        lively: lively,
        parallax: parallax,
        localState: state,
        onPersist: onPersist,
      ),
    ),
  );
}

class SharedRoomVisit {
  const SharedRoomVisit({required this.code, required this.room});

  final String code;
  final Map<String, dynamic> room;
}

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({
    required this.code,
    required this.onStop,
    this.ownerName,
    this.rotatedCode = false,
    this.onPreview,
  });
  final String code;
  final Future<bool> Function() onStop;
  final String? ownerName;
  final bool rotatedCode;
  final VoidCallback? onPreview;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  bool _inviting = false;
  bool _stopping = false;

  String get _invite =>
      roomInviteText(widget.code, ownerName: widget.ownerName);

  String get _inviteUrl => roomInviteUrl(widget.code);

  Future<void> _invitePeople() async {
    if (_inviting) return;
    setState(() => _inviting = true);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final result = await shareText(_invite, origin: origin);
    if (!mounted) return;
    setState(() => _inviting = false);
    if (result == ShareTextResult.unavailable) {
      await Clipboard.setData(ClipboardData(text: _invite));
      if (mounted) {
        _toast(context, 'Sharing isn’t available here — invite copied');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: GlassPanel(
            blur: true,
            radius: 24,
            tint: Palette.dialogSurface,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHARE YOUR SPACE',
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    letterSpacing: 2.1,
                    color: Palette.textLo,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Your space is live',
                  style: Type.display.copyWith(
                    fontSize: 22,
                    color: Palette.textHi,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.rotatedCode
                      ? 'Your old code belonged to another sign-in, so this fresh one keeps both spaces safe.'
                      : 'This code is the key to your space.',
                  style: Type.body.copyWith(
                    fontSize: 13,
                    height: 1.4,
                    color: Palette.textMid,
                  ),
                ),
                const SizedBox(height: 15),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    decoration: facetedDecoration(
                      cut: 10,
                      color: Palette.xp.withValues(alpha: 0.12),
                      borderColor: Palette.xp.withValues(alpha: 0.52),
                      shadows: const [
                        BoxShadow(
                          color: Palette.honeyGlow,
                          blurRadius: 18,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Semantics(
                      label: 'Share code ${widget.code.split('').join(' ')}',
                      child: Text(
                        widget.code,
                        style: Type.display.copyWith(
                          fontSize: 30,
                          color: Palette.xpLight,
                          letterSpacing: 6,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                HoneyButton(
                  key: const Key('share-space-invite'),
                  label: _inviting ? 'OPENING SHARE SHEET…' : 'INVITE PEOPLE',
                  icon: Icons.send_outlined,
                  enabled: !_inviting && !_stopping,
                  expand: true,
                  onTap: _invitePeople,
                ),
                const SizedBox(height: 7),
                Text(
                  'Choose Messages, Mail, WhatsApp, or another app. The invite opens this room in a browser.',
                  style: Type.body.copyWith(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Palette.textLo,
                  ),
                ),
                const SizedBox(height: 11),
                if (widget.onPreview != null) ...[
                  _ShareUtilityAction(
                    key: const Key('share-space-preview'),
                    icon: Icons.visibility_outlined,
                    label: 'PREVIEW WHAT VISITORS SEE',
                    onTap: widget.onPreview!,
                    expand: true,
                  ),
                  const SizedBox(height: 8),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        constraints.maxWidth < 290 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.3;
                    final width = stacked
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: width,
                          child: _ShareUtilityAction(
                            key: const Key('share-space-copy-link'),
                            icon: Icons.link_rounded,
                            label: 'COPY LINK',
                            onTap: () async {
                              await Clipboard.setData(
                                ClipboardData(text: _inviteUrl),
                              );
                              Sfx.instance.playMaterial(MaterialSound.glass);
                              if (context.mounted) {
                                _toast(context, 'Invite link copied');
                              }
                            },
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _ShareUtilityAction(
                            key: const Key('share-space-copy-code'),
                            icon: Icons.copy_rounded,
                            label: 'COPY CODE',
                            onTap: () async {
                              await Clipboard.setData(
                                ClipboardData(text: widget.code),
                              );
                              Sfx.instance.playMaterial(MaterialSound.glass);
                              if (context.mounted) {
                                _toast(context, 'Code copied');
                              }
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: facetedDecoration(
                    cut: 8,
                    color: Palette.glassFill,
                    borderColor: Palette.glassEdge,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: Palette.success,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Anyone with this link can visit until you stop sharing. They see the room you built and a few small signs of presence, like whether its fire is lit today or a quiet-company timer is running. Your name, writing, photos, quests, Journal pages, and account details stay private.',
                          style: Type.body.copyWith(
                            fontSize: 11,
                            height: 1.42,
                            color: Palette.textMid,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      TextButton(
                        key: const Key('share-space-stop'),
                        onPressed: _stopping ? null : _stopSharing,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: Palette.textLo,
                        ),
                        child: Text(
                          _stopping ? 'STOPPING…' : 'STOP SHARING',
                          style: Type.label.copyWith(
                            fontSize: Type.minLabel,
                            color: Palette.textLo,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('share-space-done'),
                        onPressed: _stopping
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: Palette.xpLight,
                        ),
                        child: Text(
                          'DONE',
                          style: Type.label.copyWith(
                            fontSize: 11.5,
                            color: Palette.xpLight,
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
      ),
    );
  }

  Future<void> _stopSharing() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Palette.dialogBarrier,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Palette.dialogSurface,
        shape: const FacetedBorder(cut: 12),
        title: Text(
          'Stop sharing this space?',
          style: Type.display.copyWith(fontSize: 20, color: Palette.textHi),
        ),
        content: Text(
          'This invite and code will stop working. Friends who kept it in their Circle will see that the space is unavailable.',
          style: Type.body.copyWith(
            fontSize: 13,
            height: 1.4,
            color: Palette.textMid,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'KEEP SHARING',
              style: Type.label.copyWith(fontSize: Type.minLabel),
            ),
          ),
          TextButton(
            key: const Key('share-space-confirm-stop'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'STOP SHARING',
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: Palette.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _stopping = true);
    final stopped = await widget.onStop();
    if (!mounted) return;
    if (stopped) {
      Navigator.of(context).pop();
    } else {
      setState(() => _stopping = false);
      _toast(
        context,
        'Couldn’t stop sharing yet — your code is still safe here.',
      );
    }
  }
}

class _ShareUtilityAction extends StatelessWidget {
  const _ShareUtilityAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.expand = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const FacetedBorder(cut: 8),
        onTap: onTap,
        child: Ink(
          decoration: facetedDecoration(
            cut: 8,
            color: Palette.glassFill,
            borderColor: Palette.glassEdge,
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: Palette.xpLight),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: Palette.xpLight,
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

class _VisitPrompt extends StatefulWidget {
  const _VisitPrompt({
    required this.fetcher,
    this.initialCode,
    this.autoSubmit = false,
  });

  final RoomFetcher fetcher;
  final String? initialCode;
  final bool autoSubmit;

  @override
  State<_VisitPrompt> createState() => _VisitPromptState();
}

class _VisitPromptState extends State<_VisitPrompt> {
  late final TextEditingController _c;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initialCode?.toUpperCase() ?? '');
    if (widget.autoSubmit && _roomCodePattern.hasMatch(_c.text)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _visit());
    }
  }

  Future<void> _visit() async {
    if (_loading) return;
    final code = _c.text.trim().toUpperCase();
    if (!_roomCodePattern.hasMatch(code)) {
      setState(() {
        _error = 'Enter the full six-character code. Codes skip I, O, 0 and 1.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final room = await widget.fetcher(code);
      if (!mounted) return;
      if (room == null) {
        setState(() {
          _loading = false;
          _error =
              'No shared space found with that code. Check it and try again.';
        });
        return;
      }
      Navigator.of(context).pop(SharedRoomVisit(code: code, room: room));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Couldn’t reach that space. Check your connection and try again.';
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      backgroundColor: Palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Visit a space',
        style: Type.display.copyWith(fontSize: 20, color: Palette.textHi),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter a friend’s share code:',
            style: Type.body.copyWith(fontSize: 13, color: Palette.textMid),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('visit-space-code'),
            controller: _c,
            autofocus: !widget.autoSubmit,
            enabled: !_loading,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[A-HJ-NP-Za-hj-np-z2-9]'),
              ),
              LengthLimitingTextInputFormatter(6),
            ],
            style: Type.display.copyWith(
              fontSize: 24,
              color: Palette.xpLight,
              letterSpacing: 6,
            ),
            textAlign: TextAlign.center,
            cursorColor: Palette.xp,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'ABC123',
              hintStyle: Type.display.copyWith(
                fontSize: 24,
                color: Palette.textLo,
                letterSpacing: 6,
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Palette.glassRim),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Palette.xp),
              ),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _visit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              key: const Key('visit-space-error'),
              style: Type.body.copyWith(fontSize: 12, color: Palette.danger),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: Type.label.copyWith(fontSize: 12, color: Palette.textLo),
          ),
        ),
        TextButton(
          key: const Key('visit-space-submit'),
          onPressed: _loading ? null : _visit,
          child: _loading
              ? const SizedBox.square(
                  key: Key('visit-space-loading'),
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'Visit',
                  style: Type.label.copyWith(
                    fontSize: 13,
                    color: Palette.xpLight,
                  ),
                ),
        ),
      ],
    );
  }
}
