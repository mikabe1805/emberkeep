import 'dart:collection';

import 'package:flutter/foundation.dart'
    show ChangeNotifier, ValueListenable, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio.dart';
import 'clock.dart';
import 'cloud.dart';
import 'content/creature_skins.dart';
import 'content/links.dart';
import 'discovery.dart';
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
import 'widgets/glass_switch.dart';
import 'widgets/honey_button.dart';

bool _sharingSpace = false;
final RegExp _roomCodePattern = RegExp(
  r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$',
);

typedef RoomFetcher = Future<Map<String, dynamic>?> Function(String code);
typedef DiscoveryPublicNameSaver =
    Future<DiscoveryPublicNameUpdate> Function(String name);

@visibleForTesting
bool reconcileDiscoveryAfterRoomPublish({
  required GameState state,
  required bool roomCodeChanged,
  required bool directoryRefreshed,
}) {
  if (!roomCodeChanged || !state.roomDiscoverable || directoryRefreshed) {
    return false;
  }
  state.markRoomDiscoveryRemovalPending(state.roomCode ?? '');
  return true;
}

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

/// Builds one bounded authored-page projection for a specific visitor
/// audience. The public projection contains only cards marked [SpaceAudience.anyone];
/// the mutual projection contains those cards plus cards marked
/// [SpaceAudience.mutuals]. Cards marked [SpaceAudience.onlyMe] never enter
/// either map.
///
/// These projections are stored separately from the bearer-readable room
/// document. Firestore authorizes whole documents, not individual fields, so
/// mixing Mutuals and Anyone content into `/rooms/{code}` would make the
/// privacy labels cosmetic rather than enforceable.
Map<String, dynamic> spaceProfileDisplay(
  GameState s, {
  required SpaceAudience audience,
}) {
  if (!s.shareSpaceProfile || audience == SpaceAudience.onlyMe) {
    return const <String, dynamic>{};
  }

  bool visibleToAudience(SpaceCardKind kind) {
    final selected = s.spaceAudienceFor(kind);
    return selected == SpaceAudience.anyone ||
        (audience == SpaceAudience.mutuals &&
            selected == SpaceAudience.mutuals);
  }

  final sharedCards = <SpaceCardKind>[
    for (final kind in s.spaceCardOrder)
      if (visibleToAudience(kind)) kind,
  ];

  final aboutVisible = sharedCards.contains(SpaceCardKind.about);
  final rightNowVisible = sharedCards.contains(SpaceCardKind.rightNow);
  final momentsVisible = sharedCards.contains(SpaceCardKind.pinnedMoments);
  final seasonVisible = sharedCards.contains(SpaceCardKind.thisSeason);
  return <String, dynamic>{
    // An open page with no cards for this audience gets an intentional empty
    // state without leaking the keeper's private Me name as a bare header.
    'displayName': sharedCards.isEmpty
        ? ''
        : _sharedProfileText(s.playerName, 40),
    'cardOrder': [for (final kind in sharedCards) kind.name],
    'about': aboutVisible ? _sharedProfileText(s.spaceIntro, 180) : '',
    'featuredGoals': rightNowVisible
        ? <String>[
            for (final title in s.featuredGoalTitles)
              _sharedProfileText(title, 100),
          ].where((title) => title.isNotEmpty).toSet().take(3).toList()
        : const <String>[],
    'pinnedMoments': momentsVisible
        ? <Map<String, dynamic>>[
            for (final note in s.journal.reversed)
              if (s.memoryPins.contains(note.id) &&
                  _sharedProfileText(note.text, 240).isNotEmpty)
                <String, dynamic>{
                  'text': _sharedProfileText(note.text, 240),
                  'at': note.at.millisecondsSinceEpoch,
                },
          ].take(4).toList()
        : const <Map<String, dynamic>>[],
    'season': seasonVisible ? _sharedProfileText(s.spaceSeasonText, 180) : '',
  };
}

/// The bounded generated-room payload published for a shared space. Account
/// data, authored profile cards, quest history, Journal pages, and visitor
/// photos stay out; authored text is published only through the separate
/// audience-specific profile projections below.
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
  return {
    // The fixed generated-room name remains for older clients; deliberately
    // selected profile writing lives only in the audience projections.
    'name': 'Fellow keeper',
    // A visitor can receive this stable opaque key for blocking and Circle;
    // Firebase ownership stays in the unreadable roomOwners registry.
    if (mediaOwnerUid != null) 'ownerKey': discoveryOwnerKey(mediaOwnerUid),
    'title': s.buildTitle,
    'level': s.level,
    'furniture': s.ownedFurniture.toList(),
    'wall': s.wallStyle,
    'floor': s.floorStyle,
    'skin': flameSkinIdFor(s),
    'window': s.windowScene,
    'awake': s.streakDays > 0,
    'memories': memories.clamp(0, 9999),
    'weather': 'unknown',
    'todayLit': (s.history[Days.key(Clock.now())] ?? 0) > 0,
    'focusKind': s.quietCompanyActive ? s.quietCompanyKind : 'none',
    'focusUntil': s.quietCompanyActive ? s.quietCompanyUntil : 0,
    // Authored page content is published to audience-specific documents. Keep
    // this v6 room generated-only so its code remains a bounded bearer key and
    // older visitors never receive Mutuals content by accident.
    'profileVisible': false,
    'displayName': '',
    'cardOrder': const <String>[],
    'about': '',
    'featuredGoals': const <String>[],
    'pinnedMoments': const <Map<String, dynamic>>[],
    'season': '',
    'profilePhotoPath': '',
    'seasonPhotoPath': '',
    'v': 6,
  };
}

/// Narrow, injectable boundary for the acknowledged visitor-page transaction.
/// Production delegates to [CloudSync]; tests can prove ordering without a
/// Firebase app or a second private CloudSync constructor.
typedef RoomAndSpaceProfilePublisher =
    Future<RoomPublishResult> Function(
      Map<String, dynamic> display, {
      String? code,
      required Map<String, dynamic>? publicProfile,
      required Map<String, dynamic>? mutualProfile,
    });

class RoomPublicationClient {
  const RoomPublicationClient({
    required this.ensureAvailable,
    required this.ensureSocialSession,
    required this.ownerUid,
    required this.fetchRoom,
    required this.publishRoom,
    required this.unshareRoom,
    this.publishRoomWithSpaceProfile,
  });

  factory RoomPublicationClient.cloud(CloudSync cloud) => RoomPublicationClient(
    ensureAvailable: cloud.ensureAvailable,
    ensureSocialSession: cloud.ensureSocialSession,
    ownerUid: () => cloud.socialUid,
    fetchRoom: cloud.fetchRoom,
    publishRoom: (display, {code}) => cloud.publishRoom(display, code: code),
    publishRoomWithSpaceProfile: cloud.publishRoomWithSpaceProfile,
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
  final RoomAndSpaceProfilePublisher? publishRoomWithSpaceProfile;
  final Future<bool> Function(String code) unshareRoom;
}

/// Publishes one exact visitor-page state. Build 32 keeps visitor photos
/// dormant, so this path coordinates only the generated room and the two
/// audience-specific text projections.
Future<RoomPublishResult> publishSpaceRoomState(
  GameState target, {
  required GameState current,
  required String? code,
  CloudSync? cloudSync,
  SharedRoomMediaService? mediaService,
  RoomPublicationClient? publicationClient,
  Future<SpaceProfilePublishResult> Function(
    String code, {
    required Map<String, dynamic>? publicProfile,
    required Map<String, dynamic>? mutualProfile,
  })?
  profilePublisher,
  bool visitorPhotoSharingEnabled = kVisitorPhotoSharingEnabled,
  bool visitorProfileSharingEnabled = kVisitorProfileSharingEnabled,
}) async {
  final cloud = cloudSync ?? CloudSync.instance;
  final publication = publicationClient ?? RoomPublicationClient.cloud(cloud);
  if (publicationClient == null) {
    // This is an acknowledged, user-intended state. Fence off a five-second
    // background snapshot before it can revive an older audience selection.
    cloud.invalidatePendingRoomRefreshes();
  }
  if (!await publication.ensureAvailable() ||
      !await publication.ensureSocialSession()) {
    return const RoomPublishResult.failed(RoomPublishFailure.unavailable);
  }
  final ownerUid = publication.ownerUid();
  if (ownerUid == null) {
    return const RoomPublishResult.failed(RoomPublishFailure.unavailable);
  }

  final publishProfile =
      profilePublisher ??
      (publicationClient == null
          ? cloud.publishSpaceProfile
          : (
              String _, {
              required Map<String, dynamic>? publicProfile,
              required Map<String, dynamic>? mutualProfile,
            }) async => SpaceProfilePublishResult.saved);

  Future<RoomPublishResult?> publishAuthoredPage(String publishedCode) async {
    if (!visitorProfileSharingEnabled) return null;
    final publicProfile = spaceProfileDisplay(
      target,
      audience: SpaceAudience.anyone,
    );
    final mutualProfile = spaceProfileDisplay(
      target,
      audience: SpaceAudience.mutuals,
    );
    final result = await publishProfile(
      publishedCode,
      publicProfile: publicProfile.isEmpty ? null : publicProfile,
      mutualProfile: mutualProfile.isEmpty ? null : mutualProfile,
    );
    return switch (result) {
      SpaceProfilePublishResult.saved => null,
      SpaceProfilePublishResult.rejected => const RoomPublishResult.failed(
        RoomPublishFailure.profileRejected,
      ),
      SpaceProfilePublishResult.permissionDenied =>
        const RoomPublishResult.failed(RoomPublishFailure.permissionDenied),
      SpaceProfilePublishResult.timedOut => const RoomPublishResult.failed(
        RoomPublishFailure.timedOut,
      ),
      SpaceProfilePublishResult.unavailable => const RoomPublishResult.failed(
        RoomPublishFailure.unavailable,
      ),
    };
  }

  Future<RoomPublishResult> publishRoomAndAuthoredPage(
    Map<String, dynamic> display, {
    required String? requestedCode,
  }) async {
    final combinedPublisher = publication.publishRoomWithSpaceProfile;
    if (visitorProfileSharingEnabled &&
        profilePublisher == null &&
        combinedPublisher != null) {
      final publicProfile = spaceProfileDisplay(
        target,
        audience: SpaceAudience.anyone,
      );
      final mutualProfile = spaceProfileDisplay(
        target,
        audience: SpaceAudience.mutuals,
      );
      return combinedPublisher(
        display,
        code: requestedCode,
        publicProfile: publicProfile.isEmpty ? null : publicProfile,
        mutualProfile: mutualProfile.isEmpty ? null : mutualProfile,
      );
    }

    final published = await publication.publishRoom(
      display,
      code: requestedCode,
    );
    if (!published.ok) return published;
    final profileFailure = await publishAuthoredPage(published.code!);
    if (profileFailure == null) return published;
    if (requestedCode == null ||
        requestedCode.trim().toUpperCase() != published.code) {
      await publication.unshareRoom(published.code!);
    }
    return profileFailure;
  }

  // The generated v6 room/profile split intentionally has no visitor-readable
  // storage-path projection. Keep image publication dormant until its opaque
  // storage ownership model is implemented. This path never constructs a
  // Firebase Storage client, and only clears stale consent after the room
  // publish is acknowledged so a failed publish cannot discard a local choice.
  final display = roomDisplay(
    target,
    mediaOwnerUid: ownerUid,
    mediaRoomCode: code,
    visitorPhotoSharingEnabled: false,
    visitorProfileSharingEnabled: visitorProfileSharingEnabled,
  );
  final published = await publishRoomAndAuthoredPage(
    display,
    requestedCode: code,
  );
  if (published.ok) {
    if (!visitorProfileSharingEnabled) {
      target.disableVisitorProfileSharing();
    } else {
      target.disableVisitorPhotoSharing();
    }
  }
  return published;
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
  VoidCallback onPersist, {
  bool spaceDiscoveryEnabled = kSpaceDiscoveryEnabled,
  bool publicDiscoveryNamesEnabled = kPublicDiscoveryNamesEnabled,
  bool discoveryFirst = false,
}) async {
  final cloud = CloudSync.instance;
  if (_sharingSpace) {
    _toast(context, 'Your share is already opening.');
    return;
  }
  _sharingSpace = true;
  try {
    final previousRoomCode = state.roomCode;
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
        RoomPublishFailure.profileRejected =>
          'One of your shared cards contains a link, contact detail, or wording that cannot be published. Your private page is unchanged.',
        RoomPublishFailure.exhaustedCodes =>
          'Couldn’t reserve a share code. Please try once more.',
        _ => 'Couldn’t share right now — try again.',
      };
      _toast(context, message);
      return;
    }
    final roomCodeChanged = previousRoomCode != code;
    if (roomCodeChanged) {
      state.setRoomCode(code);
      onPersist();
    }
    final sharedRoom = roomDisplay(
      state,
      mediaOwnerUid: cloud.socialUid,
      mediaRoomCode: code,
    );
    if (spaceDiscoveryEnabled && state.roomDiscoverable) {
      final directoryRefreshed = await cloud.setRoomDiscoverable(
        code,
        sharedRoom,
        discoverable: true,
      );
      final discoveryDisabled = reconcileDiscoveryAfterRoomPublish(
        state: state,
        roomCodeChanged: roomCodeChanged,
        directoryRefreshed: directoryRefreshed,
      );
      if (discoveryDisabled) {
        onPersist();
        if (context.mounted) {
          _toast(
            context,
            'Discover could not confirm the new room, so cleanup will retry. Sharing by code still works.',
          );
        }
      }
      if (!context.mounted) return;
    }
    Sfx.instance.play('loot');
    await showShareSpaceDialog(
      context,
      code: code,
      ownerName: roomInviteOwnerName(state),
      rotatedCode: published.rotatedStaleCode,
      discoverable: state.roomDiscoverable,
      discoveryCleanupPending:
          state.roomCode != null &&
          state.roomDiscoveryRemovalCodes.contains(state.roomCode),
      publicDiscoveryName: state.roomDiscoveryName,
      visitorPagePublished:
          kVisitorProfileSharingEnabled && state.shareSpaceProfile,
      discoveryFirst: discoveryFirst,
      onDiscoverableChanged: spaceDiscoveryEnabled
          ? (next) async {
              final changed = await cloud.setRoomDiscoverable(
                code,
                sharedRoom,
                discoverable: next,
              );
              if (!changed) return false;
              state.setRoomDiscoverable(next);
              onPersist();
              return true;
            }
          : null,
      onPublicDiscoveryNameChanged:
          spaceDiscoveryEnabled && publicDiscoveryNamesEnabled
          ? (name) async {
              final result = await cloud.setDiscoveryPublicName(code, name);
              if (result == DiscoveryPublicNameUpdate.saved) {
                state.setRoomDiscoveryName(name);
                onPersist();
              }
              return result;
            }
          : null,
      onPreview: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => VisitRoomScreen(
            room: sharedRoom,
            code: code,
            themeId: state.canvasTheme,
            lively: !state.reduceMotion,
            visitorProfile: kVisitorProfileSharingEnabled
                ? spaceProfileDisplay(state, audience: SpaceAudience.anyone)
                : null,
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
  bool discoverable = false,
  bool discoveryCleanupPending = false,
  String publicDiscoveryName = '',
  bool discoveryFirst = false,
  bool visitorPagePublished = false,
  Future<bool> Function(bool discoverable)? onDiscoverableChanged,
  DiscoveryPublicNameSaver? onPublicDiscoveryNameChanged,
  VoidCallback? onPreview,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Palette.dialogBarrier,
    builder: (_) => _ShareDialog(
      code: code,
      ownerName: ownerName,
      rotatedCode: rotatedCode,
      discoverable: discoverable,
      discoveryCleanupPending: discoveryCleanupPending,
      publicDiscoveryName: publicDiscoveryName,
      discoveryFirst: discoveryFirst,
      visitorPagePublished: visitorPagePublished,
      onDiscoverableChanged: onDiscoverableChanged,
      onPublicDiscoveryNameChanged: onPublicDiscoveryNameChanged,
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
  final ownerKey = discoveryOwnerKeyFromRoom(result.room);
  if (state != null &&
      ownerKey != null &&
      state.blockedDiscoveryOwners.containsKey(ownerKey)) {
    _toast(context, 'That keeper is hidden on this device.');
    return;
  }
  if (state != null &&
      ownerKey != null &&
      state.hearthCircleCodes.contains(result.code) &&
      state.rememberCircleOwnerKey(result.code, ownerKey)) {
    onPersist?.call();
  }
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
        discoveryOwnerKey: ownerKey ?? '',
        onReportDiscoverableSpace: CloudSync.instance.reportDiscoverableSpace,
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
    this.discoverable = false,
    this.discoveryCleanupPending = false,
    this.publicDiscoveryName = '',
    this.discoveryFirst = false,
    this.visitorPagePublished = false,
    this.onDiscoverableChanged,
    this.onPublicDiscoveryNameChanged,
    this.onPreview,
  });
  final String code;
  final Future<bool> Function() onStop;
  final String? ownerName;
  final bool rotatedCode;
  final bool discoverable;
  final bool discoveryCleanupPending;
  final String publicDiscoveryName;
  final bool discoveryFirst;
  final bool visitorPagePublished;
  final Future<bool> Function(bool discoverable)? onDiscoverableChanged;
  final DiscoveryPublicNameSaver? onPublicDiscoveryNameChanged;
  final VoidCallback? onPreview;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  bool _inviting = false;
  bool _stopping = false;
  bool _changingDiscovery = false;
  bool _savingPublicName = false;
  late bool _discoverable;
  late String _savedPublicName;
  late final TextEditingController _publicNameController;
  final GlobalKey _discoverySettingFocusKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _discoverable = widget.discoverable;
    _savedPublicName = sanitizeDiscoveryPublicName(widget.publicDiscoveryName);
    _publicNameController = TextEditingController(text: _savedPublicName);
    if (widget.discoveryFirst && widget.onDiscoverableChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final discoveryContext = _discoverySettingFocusKey.currentContext;
        if (discoveryContext == null) return;
        Scrollable.ensureVisible(
          discoveryContext,
          alignment: 0.04,
          duration: Duration.zero,
        );
      });
    }
  }

  @override
  void dispose() {
    _publicNameController.dispose();
    super.dispose();
  }

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
                    // This preview deliberately uses the Anyone projection.
                    // Mutuals can receive additional cards, so naming it a
                    // generic visitor preview would over-promise parity.
                    label: 'PREVIEW PUBLIC VIEW',
                    onTap: widget.onPreview!,
                    expand: true,
                  ),
                  const SizedBox(height: 8),
                ],
                if (widget.onDiscoverableChanged != null) ...[
                  KeyedSubtree(
                    key: _discoverySettingFocusKey,
                    child: Container(
                      key: const ValueKey('share-space-discovery-setting'),
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 11, 10, 12),
                      decoration: facetedDecoration(
                        cut: 8,
                        color: _discoverable
                            ? Palette.xp.withValues(alpha: 0.10)
                            : Palette.glassFill,
                        borderColor: _discoverable
                            ? Palette.xp.withValues(alpha: 0.45)
                            : Palette.glassEdge,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Make my space discoverable',
                                      style: Type.display.copyWith(
                                        fontSize: 15,
                                        color: Palette.textHi,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _changingDiscovery
                                          ? (_discoverable
                                                ? 'Opening your door…'
                                                : 'Closing your door…')
                                          : _discoverable
                                          ? widget.onPublicDiscoveryNameChanged !=
                                                    null
                                                ? 'People can find this room, keep it in their Circle, and return. Only the public name you choose, its generated title, room style, and level appear.'
                                                : 'People can find this room, keep it in their Circle, and return. Only its generated title, room style, and level appear.'
                                          : widget.discoveryCleanupPending
                                          ? 'Discover could not confirm this room. Cleanup will retry when you reconnect; sharing by code still works.'
                                          : 'People with your code can still visit. Turn this on to also appear in Discover.',
                                      style: Type.body.copyWith(
                                        fontSize: 11.5,
                                        height: 1.4,
                                        color: Palette.textMid,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IgnorePointer(
                                ignoring: _changingDiscovery,
                                child: Opacity(
                                  opacity: _changingDiscovery ? 0.65 : 1,
                                  child: GlassSwitch(
                                    key: const ValueKey(
                                      'share-space-discovery-switch',
                                    ),
                                    value: _discoverable,
                                    semanticLabel: 'Make my space discoverable',
                                    onChanged: _changeDiscovery,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_discoverable &&
                              widget.onPublicDiscoveryNameChanged != null) ...[
                            const SizedBox(height: 12),
                            Container(height: 1, color: Palette.glassEdge),
                            const SizedBox(height: 10),
                            Text(
                              'NAME SHOWN IN DISCOVER · OPTIONAL',
                              style: Type.label.copyWith(
                                fontSize: Type.minLabel,
                                color: Palette.textLo,
                              ),
                            ),
                            const SizedBox(height: 5),
                            TextField(
                              key: const ValueKey(
                                'share-space-public-discovery-name',
                              ),
                              controller: _publicNameController,
                              enabled: !_savingPublicName,
                              maxLength: discoveryPublicNameMaxLength,
                              maxLines: 1,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.done,
                              style: Type.body.copyWith(
                                fontSize: 14,
                                color: Palette.textHi,
                              ),
                              cursorColor: Palette.xp,
                              decoration: InputDecoration(
                                isDense: true,
                                counterText: '',
                                hintText: 'Stay anonymous',
                                hintStyle: Type.body.copyWith(
                                  fontSize: 14,
                                  color: Palette.textLo,
                                ),
                                enabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Palette.glassRim,
                                  ),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Palette.xp),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _savePublicName(),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Separate from your private Me name. Blank stays anonymous.',
                                    style: Type.body.copyWith(
                                      fontSize: 10.5,
                                      height: 1.3,
                                      color: Palette.textLo,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  key: const ValueKey(
                                    'share-space-save-public-name',
                                  ),
                                  onPressed:
                                      !_savingPublicName &&
                                          sanitizeDiscoveryPublicName(
                                                _publicNameController.text,
                                              ) !=
                                              _savedPublicName
                                      ? _savePublicName
                                      : null,
                                  child: Text(
                                    _savingPublicName
                                        ? 'SAVING…'
                                        : sanitizeDiscoveryPublicName(
                                                _publicNameController.text,
                                              ).isEmpty &&
                                              _savedPublicName.isNotEmpty
                                        ? 'CLEAR NAME'
                                        : 'SAVE NAME',
                                    style: Type.label.copyWith(
                                      fontSize: Type.minLabel,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 11),
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
                          widget.visitorPagePublished
                              ? 'Anyone with this link can visit until you stop sharing. Your visitor page follows the audience on each card: Anyone cards open by code or Discover, while Mutuals cards need both keepers to choose each other in Circle. Photos, unpinned Journal pages, quests, streak details, and account information stay private.'
                              : 'Anyone with this link can visit until you stop sharing. They see the room you built and a few small signs of presence, like whether its fire is lit today or a quiet-company timer is running. Your Me name, writing, photos, quests, Journal pages, and account details stay private.',
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

  Future<void> _changeDiscovery(bool next) async {
    final change = widget.onDiscoverableChanged;
    if (change == null || _changingDiscovery || next == _discoverable) return;
    final previous = _discoverable;
    setState(() {
      _discoverable = next;
      _changingDiscovery = true;
    });
    final changed = await change(next);
    if (!mounted) return;
    setState(() {
      _changingDiscovery = false;
      if (!changed) {
        _discoverable = previous;
      } else if (!next) {
        _savedPublicName = '';
        _publicNameController.clear();
      }
    });
    if (!changed) {
      _toast(
        context,
        next
            ? 'Couldn’t open your door yet — your space is still private.'
            : 'Couldn’t close your door yet — discovery is still on.',
      );
    }
  }

  Future<void> _savePublicName() async {
    final save = widget.onPublicDiscoveryNameChanged;
    if (save == null || !_discoverable || _savingPublicName) return;
    final clean = sanitizeDiscoveryPublicName(_publicNameController.text);
    if (clean == _savedPublicName) return;
    setState(() => _savingPublicName = true);
    final result = await save(clean);
    if (!mounted) return;
    setState(() {
      _savingPublicName = false;
      if (result == DiscoveryPublicNameUpdate.saved) {
        _savedPublicName = clean;
        _publicNameController.value = TextEditingValue(
          text: clean,
          selection: TextSelection.collapsed(offset: clean.length),
        );
      }
    });
    final message = switch (result) {
      DiscoveryPublicNameUpdate.saved =>
        clean.isEmpty
            ? 'Your space is anonymous in Discover.'
            : 'Your public name is saved.',
      DiscoveryPublicNameUpdate.rejected =>
        'That name can’t be used in Discover. Try a simple name without links or contact details.',
      DiscoveryPublicNameUpdate.rateLimited =>
        'That changed a little too quickly. Try again in a minute.',
      DiscoveryPublicNameUpdate.unavailable =>
        'Couldn’t save the public name yet. The name already shown is unchanged.',
    };
    _toast(context, message);
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
        _error = 'Enter 6 characters. No I, O, 0, or 1.';
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
