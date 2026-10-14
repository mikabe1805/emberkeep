import 'dart:math';

import 'package:flutter/foundation.dart';

import 'brawl/weekly_training.dart';
import 'class_credit.dart';
import 'clock.dart';
import 'content/achievements.dart';
import 'content/cosmetics.dart';
import 'content/evidence.dart';
import 'content/messages.dart';
import 'content/room_keepsakes.dart';
import 'content/space_themes.dart';
import 'content/stat_ranks.dart';
import 'content/themes.dart';
import 'content/titles.dart';
import 'discovery.dart';
import 'goal_planner.dart';
import 'models.dart';
import 'release_features.dart';
import 'steward_memory.dart';
import 'tokens.dart';

export 'class_credit.dart';

/// The authored pieces that can be arranged on the owner's My Space page.
///
/// These names are persisted as strings. Keep existing names stable when the
/// presentation copy changes so a saved arrangement survives app updates.
enum SpaceCardKind { about, rightNow, pinnedMoments, thisSeason }

enum SpaceAudience { onlyMe, mutuals, anyone }

const defaultSpaceCardOrder = <SpaceCardKind>[
  SpaceCardKind.about,
  SpaceCardKind.rightNow,
  SpaceCardKind.pinnedMoments,
  SpaceCardKind.thisSeason,
];

/// The game engine. XP = base × difficulty × dread × streak × proof × crit
/// (RESEARCH.md §5). Persisted via toJson/fromJson; period resets happen in
/// [rollover].
class GameState extends ChangeNotifier {
  GameState({Random? rng})
    : _rng = rng ?? debugRandomFactory?.call() ?? Random();

  /// Golden harnesses can supply a repeatable source without changing any
  /// production reward odds or persisting test-only seed state.
  @visibleForTesting
  static Random Function()? debugRandomFactory;

  final Random _rng;

  /// Durable, account-save-scoped memory for the optional Steward encounter.
  /// It intentionally has no progression, stat, or Quest side effects.
  StewardMemory stewardMemory = StewardMemory();

  /// What the player is called (set in onboarding; greetings use it sparingly).
  /// Null = not given.
  String? playerName;

  void setPlayerName(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    final next = cleaned.isEmpty
        ? null
        : String.fromCharCodes(cleaned.runes.take(40));
    if (playerName == next) return;
    playerName = next;
    notifyListeners();
  }

  /// First-run welcome completed?
  bool onboarded = false;

  /// How dense days usually feel — set in onboarding (light/full/packed).
  /// Seeds the starter board; null on legacy saves.
  String? timeShape;

  /// Opt-in "one quest at a time" Focus mode (round-21): collapses the board
  /// to a single suggested quest to fight overwhelm. Default off (full board).
  bool focusMode = false;

  /// Accessibility: when true, particle bursts swap for simple fades and
  /// haptic intensity is reduced (DESIGN.md: "Honor reduce-motion").
  bool reduceMotion = false;

  /// Sound toggle — the owner can mute all event sounds ( DESIGN.md §8).
  bool soundEnabled = true;

  /// Optional room music. It starts off until the keeper explicitly chooses it
  /// and does not follow the event-sound toggle.
  bool musicEnabled = false;

  /// The board's "Add your classes" row was put away with "Not in school".
  /// It stays away for good on this save; Plans keeps its own way in.
  bool addClassesHidden = false;

  /// Accessibility: an in-app text-size multiplier, layered on top of the OS
  /// Text Size setting (main.dart takes the larger of the two, then clamps).
  /// 1.0 = default; presets live in a11y.dart.
  double textScale = 1.0;

  void setReduceMotion(bool v) {
    if (reduceMotion == v) return;
    reduceMotion = v;
    // keep the haptic helper in sync (imported lazily via setter call sites)
    notifyListeners();
  }

  void setTextScale(double v) {
    if (textScale == v) return;
    textScale = v;
    notifyListeners();
  }

  void setFocusMode(bool v) {
    if (focusMode == v) return;
    focusMode = v;
    notifyListeners();
  }

  void setSound(bool v) {
    if (soundEnabled == v) return;
    soundEnabled = v;
    notifyListeners();
  }

  void setMusic(bool v) {
    if (musicEnabled == v) return;
    musicEnabled = v;
    notifyListeners();
  }

  void hideAddClasses() {
    if (addClassesHidden) return;
    addClassesHidden = true;
    notifyListeners();
  }

  /// The shared-space code, if this keep is published. Set through here (not
  /// the field) so the Me-page "Shared · CODE" label repaints when it changes.
  void setRoomCode(String? code) {
    if (roomCode == code &&
        (code != null ||
            (spaceProfilePhotoPath.isEmpty &&
                spaceSeasonPhotoPath.isEmpty &&
                spaceRoomPhotoPath.isEmpty &&
                !roomDiscoverable))) {
      return;
    }
    final previousCode = roomCode;
    final changedRoom = roomCode != code;
    roomCode = code;
    if (code == null) {
      spaceProfilePhotoPath = '';
      spaceSeasonPhotoPath = '';
      spaceRoomPhotoPath = '';
      spaceRoomPhotoFill = false;
      spaceRoomPhotoX = 0;
      spaceRoomPhotoY = 0;
      spaceRoomPhotoWidth = 1;
      spaceRoomPhotoHeight = 1;
      roomDiscoverable = false;
      roomDiscoveryName = '';
      if (previousCode != null) {
        _roomDiscoveryRemovalCodes.remove(previousCode);
      }
    } else if (changedRoom) {
      // A rotated ownership code is a new public listing. Keep the explicit
      // discovery choice, but make the new directory entry anonymous until the
      // keeper deliberately saves a name again.
      roomDiscoveryName = '';
    }
    notifyListeners();
  }

  /// Whether this already-shared room is listed in the opt-in discovery
  /// directory. The setting changes only after the server acknowledges the
  /// corresponding directory create/delete, so the UI never lies offline.
  bool roomDiscoverable = false;

  /// Durable privacy repairs for discovery opt-ins restored into a build where
  /// Discovery is unavailable. Codes survive offline saves and room rotation
  /// until the server confirms each directory deletion.
  final Set<String> _roomDiscoveryRemovalCodes = {};

  bool get roomDiscoveryRemovalPending => _roomDiscoveryRemovalCodes.isNotEmpty;

  Set<String> get roomDiscoveryRemovalCodes =>
      Set<String>.unmodifiable(_roomDiscoveryRemovalCodes);

  /// The optional name deliberately published in Discover. It is wholly
  /// separate from [playerName], blank means anonymous, and it is cleared when
  /// discovery is disabled so it can never silently return on a later opt-in.
  String roomDiscoveryName = '';

  void setRoomDiscoverable(bool value) {
    final next = value && roomCode != null;
    final currentRemovalPending =
        roomCode != null && _roomDiscoveryRemovalCodes.contains(roomCode);
    if (roomDiscoverable == next &&
        !currentRemovalPending &&
        (next || roomDiscoveryName.isEmpty)) {
      return;
    }
    roomDiscoverable = next;
    if (roomCode != null) _roomDiscoveryRemovalCodes.remove(roomCode);
    if (!next) roomDiscoveryName = '';
    notifyListeners();
  }

  void confirmRoomDiscoveryRemoval(String code) {
    if (!_roomDiscoveryRemovalCodes.remove(code)) return;
    notifyListeners();
  }

  void markRoomDiscoveryRemovalPending(String rawCode) {
    final code = rawCode.trim().toUpperCase();
    if (!RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code)) {
      return;
    }
    final changed =
        roomDiscoverable ||
        roomDiscoveryName.isNotEmpty ||
        !_roomDiscoveryRemovalCodes.contains(code);
    roomDiscoverable = false;
    roomDiscoveryName = '';
    _roomDiscoveryRemovalCodes.add(code);
    if (changed) notifyListeners();
  }

  void setRoomDiscoveryName(String value) {
    final next = roomDiscoverable ? sanitizeDiscoveryPublicName(value) : '';
    if (roomDiscoveryName == next) return;
    roomDiscoveryName = next;
    notifyListeners();
  }

  /// Trusted keeps remembered locally. In the first store release, a code
  /// exposes only generated room appearance and broad presence fields. The
  /// dormant visitor-profile capability must remain disabled until its UGC
  /// safety operation exists.
  final List<String> hearthCircleCodes = [];
  final Map<String, String> hearthCircleNames = {};
  final Map<String, String> hearthCircleOwnerKeys = {};
  final Set<String> blockedRoomCodes = {};
  final Map<String, String> blockedDiscoveryOwners = {};

  bool addCircleCode(
    String raw, {
    String publicName = '',
    String ownerKey = '',
  }) {
    final code = raw.trim().toUpperCase();
    final cleanOwnerKey = isValidDiscoveryOwnerKey(ownerKey) ? ownerKey : '';
    if (!RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code) ||
        code == roomCode ||
        blockedRoomCodes.contains(code) ||
        (cleanOwnerKey.isNotEmpty &&
            blockedDiscoveryOwners.containsKey(cleanOwnerKey)) ||
        hearthCircleCodes.contains(code)) {
      return false;
    }
    hearthCircleCodes.add(code);
    final cleanName = sanitizeDiscoveryPublicName(publicName);
    if (cleanName.isNotEmpty) hearthCircleNames[code] = cleanName;
    if (cleanOwnerKey.isNotEmpty) hearthCircleOwnerKeys[code] = cleanOwnerKey;
    notifyListeners();
    return true;
  }

  void removeCircleCode(String raw) {
    final code = raw.trim().toUpperCase();
    final removed = hearthCircleCodes.remove(code);
    final forgotName = hearthCircleNames.remove(code) != null;
    final forgotOwner = hearthCircleOwnerKeys.remove(code) != null;
    if (removed || forgotName || forgotOwner) notifyListeners();
  }

  /// Learns the stable owner identity after a trusted Circle code is fetched.
  /// Older saved keeps have no owner key until their next successful refresh.
  bool rememberCircleOwnerKey(String raw, String ownerKey) {
    final code = raw.trim().toUpperCase();
    if (!hearthCircleCodes.contains(code) ||
        !isValidDiscoveryOwnerKey(ownerKey) ||
        blockedDiscoveryOwners.containsKey(ownerKey) ||
        hearthCircleOwnerKeys[code] == ownerKey) {
      return false;
    }
    hearthCircleOwnerKeys[code] = ownerKey;
    notifyListeners();
    return true;
  }

  bool blockRoomCode(String raw) {
    final code = raw.trim().toUpperCase();
    if (!RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code) ||
        code == roomCode) {
      return false;
    }
    final changed = blockedRoomCodes.add(code);
    final removed = hearthCircleCodes.remove(code);
    final forgotName = hearthCircleNames.remove(code) != null;
    final forgotOwner = hearthCircleOwnerKeys.remove(code) != null;
    if (changed || removed || forgotName || forgotOwner) notifyListeners();
    return changed || removed || forgotName || forgotOwner;
  }

  void unblockRoomCode(String raw) {
    final code = raw.trim().toUpperCase();
    if (blockedRoomCodes.remove(code)) notifyListeners();
  }

  bool blockDiscoveryOwner(String ownerKey, String rawCode) {
    if (!isValidDiscoveryOwnerKey(ownerKey)) return blockRoomCode(rawCode);
    final code = rawCode.trim().toUpperCase();
    if (!RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code) ||
        code == roomCode) {
      return false;
    }
    var changed = blockedDiscoveryOwners[ownerKey] != code;
    blockedDiscoveryOwners[ownerKey] = code;
    changed = blockedRoomCodes.add(code) || changed;
    final matchingCodes = [
      for (final entry in hearthCircleOwnerKeys.entries)
        if (entry.value == ownerKey) entry.key,
    ];
    for (final matchingCode in matchingCodes) {
      changed = hearthCircleCodes.remove(matchingCode) || changed;
      changed = hearthCircleNames.remove(matchingCode) != null || changed;
      changed = hearthCircleOwnerKeys.remove(matchingCode) != null || changed;
    }
    changed = hearthCircleCodes.remove(code) || changed;
    changed = hearthCircleNames.remove(code) != null || changed;
    changed = hearthCircleOwnerKeys.remove(code) != null || changed;
    if (changed) notifyListeners();
    return changed;
  }

  void unblockDiscoveryOwner(String ownerKey) {
    final code = blockedDiscoveryOwners.remove(ownerKey);
    if (code == null) return;
    blockedRoomCodes.remove(code);
    notifyListeners();
  }

  /// A private daily capacity lens. It never changes rewards, streaks, or
  /// difficulty; it only changes suggestions and the order Room of Days offers
  /// help. Stamped by day so yesterday's weather is never assumed today.
  EnergyWeather energyWeather = EnergyWeather.steady;
  String? energyWeatherDay;
  final Map<String, EnergyWeather> energyHistory = {};

  /// Stable choices for today's Gentle Mode shelter. Keeping the titles fixed
  /// prevents a fourth quest from sliding in the moment one of the chosen
  /// three is completed—the promise is a smaller day, not an endless queue.
  final List<String> lowFlameQuestTitles = [];

  bool get energyWeatherDue => energyWeatherDay != Days.key(Clock.now());
  bool get lowFlameActive =>
      energyWeatherDay == Days.key(Clock.now()) &&
      energyWeather == EnergyWeather.low;

  void setEnergyWeather(EnergyWeather weather) {
    energyWeather = weather;
    energyWeatherDay = Days.key(Clock.now());
    energyHistory[energyWeatherDay!] = weather;
    if (weather != EnergyWeather.low) lowFlameQuestTitles.clear();
    if (energyHistory.length > 180) {
      final keys = energyHistory.keys.toList()..sort();
      while (energyHistory.length > 180 && keys.isNotEmpty) {
        energyHistory.remove(keys.removeAt(0));
      }
    }
    notifyListeners();
  }

  void setLowFlameQuests(Iterable<String> titles) {
    lowFlameQuestTitles
      ..clear()
      ..addAll(titles.where((t) => t.trim().isNotEmpty).toSet().take(3));
    notifyListeners();
  }

  /// Journal-note ids the keeper deliberately placed in their Memory Cabinet.
  /// They contribute to the public artifact count. Up to four bounded texts may
  /// also be published only when the keeper explicitly shares Pinned moments;
  /// note ids, rich data, and every photo remain private.
  final Set<String> memoryPins = {};

  /// A small, authored profile for the owner's room. It stays private unless
  /// [shareSpaceProfile] is explicitly enabled; callers that publish a room
  /// must honor that consent bit rather than inferring consent from content.
  String spaceIntro = '';
  final List<String> featuredGoalTitles = [];
  bool shareSpaceProfile = false;

  /// Cards the keeper has deliberately selected for their visitor page.
  ///
  /// This is separate from [hiddenSpaceCards]: a card can be tucked away on
  /// the owner's page while remaining part of the page they made for friends,
  /// or kept locally visible while private to them. The legacy default
  /// preserves the two cards older builds could share; the visitor-page master
  /// switch still defaults off.
  /// Audience per card. Missing entries are always private.
  final Map<SpaceCardKind, SpaceAudience> spaceCardAudiences = {
    for (final kind in SpaceCardKind.values) kind: SpaceAudience.onlyMe,
  };

  /// Deprecated compatibility bridge for older callers. New saves serialize
  /// the audience map; this set is only a temporary caller-side adapter.
  final Set<SpaceCardKind> visitorSpaceCards = {};

  SpaceAudience spaceAudienceFor(SpaceCardKind kind) {
    final audience = spaceCardAudiences[kind] ?? SpaceAudience.onlyMe;
    // A few internal/test callers from the dormant pre-release implementation
    // still mutate the legacy set directly. Honor that as Anyone until every
    // caller has moved to the audience map; new persisted saves never use it
    // as authority.
    if (audience == SpaceAudience.onlyMe && visitorSpaceCards.contains(kind)) {
      return SpaceAudience.anyone;
    }
    return audience;
  }

  /// The private arrangement of the My Space deck. The first three entries
  /// reproduce the page that existed before cards became arrangeable; the
  /// empty This season card is omitted by the UI until the owner writes it.
  final List<SpaceCardKind> spaceCardOrder = [...defaultSpaceCardOrder];
  final Set<SpaceCardKind> hiddenSpaceCards = {};
  String spaceSeasonText = '';
  String? spaceProfilePhotoNoteId;
  String? spaceSeasonPhotoNoteId;
  bool shareSpaceProfilePhoto = false;
  bool shareSpaceSeasonPhoto = false;

  /// Exact public Storage revisions acknowledged by the current room document.
  /// These are opaque object handles, never local filenames or download URLs.
  String spaceProfilePhotoPath = '';
  String spaceSeasonPhotoPath = '';

  /// An explicit opt-in to place the private room photograph in the shared
  /// visitor room. The source bytes remain outside GameState; this state holds
  /// only the consent and a server-acknowledged public projection.
  bool shareRoomPhoto = false;

  /// Exact public Storage revision acknowledged by the current room document.
  /// It is never a local gallery path or download URL.
  String spaceRoomPhotoPath = '';
  bool spaceRoomPhotoFill = false;
  double spaceRoomPhotoX = 0;
  double spaceRoomPhotoY = 0;
  int spaceRoomPhotoWidth = 1;
  int spaceRoomPhotoHeight = 1;

  /// The Journal pages supplying the two deliberately selectable visitor
  /// photos. Selecting a local source and sharing it are separate choices;
  /// neither photo is public unless its own consent bit is also on.
  Note? get spaceProfilePhotoNote => _spacePhotoNote(spaceProfilePhotoNoteId);

  /// The Journal page supplying This season's optional photo. A cloud-restored
  /// note can legitimately have no local media, and a selected note can later
  /// be deleted, so both cases quietly fall back to the text-only card.
  Note? get spaceSeasonPhotoNote => _spacePhotoNote(spaceSeasonPhotoNoteId);

  Note? _spacePhotoNote(String? id) {
    if (id == null) return null;
    for (final note in journal) {
      if (note.id == id) return note.images.isEmpty ? null : note;
    }
    return null;
  }

  static String _cleanSpaceIntro(String intro) {
    final lines = intro
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trim().replaceAll(RegExp(r'\s+'), ' '))
        .toList();
    while (lines.isNotEmpty && lines.first.isEmpty) {
      lines.removeAt(0);
    }
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return String.fromCharCodes(lines.join('\n').runes.take(180));
  }

  static String _cleanSpaceSeasonText(String text) => _cleanSpaceIntro(text);

  static String? _cleanSpaceSeasonPhotoNoteId(String? noteId) {
    final clean = noteId?.trim() ?? '';
    if (clean.isEmpty) return null;
    return String.fromCharCodes(clean.runes.take(120));
  }

  static List<SpaceCardKind> _cleanSpaceCardOrder(
    Iterable<SpaceCardKind> order,
  ) {
    final seen = <SpaceCardKind>{};
    return [
      for (final kind in order)
        if (seen.add(kind)) kind,
      for (final kind in defaultSpaceCardOrder)
        if (seen.add(kind)) kind,
    ];
  }

  static Iterable<SpaceCardKind> _spaceCardKindsFromJson(Object? raw) sync* {
    if (raw is! List) return;
    for (final value in raw) {
      if (value is! String) continue;
      for (final kind in SpaceCardKind.values) {
        if (kind.name == value) {
          yield kind;
          break;
        }
      }
    }
  }

  /// Applies the entire My Space editor draft in one coherent state change.
  /// Unknown save values are filtered by the decoder; duplicates are removed
  /// and newly introduced card kinds are appended so they cannot disappear.
  void setSpacePage({
    required Iterable<SpaceCardKind> order,
    required Iterable<SpaceCardKind> hidden,
    Iterable<SpaceCardKind>? visitorVisible,
    Map<SpaceCardKind, SpaceAudience>? audiences,
    required String intro,
    required Iterable<String> featuredGoalTitles,
    required String seasonText,
    required String? profilePhotoNoteId,
    required String? seasonPhotoNoteId,
    required bool shareProfilePhoto,
    required bool shareSeasonPhoto,
    required bool shareProfile,
  }) {
    final cleanOrder = _cleanSpaceCardOrder(order);
    final cleanHidden = hidden.toSet();
    final cleanVisitor = visitorVisible
        ?.where(SpaceCardKind.values.contains)
        .toSet();
    final cleanFeatured = featuredGoalTitles.toList(growable: false);
    spaceCardOrder
      ..clear()
      ..addAll(cleanOrder);
    hiddenSpaceCards
      ..clear()
      ..addAll(cleanHidden);
    if (cleanVisitor != null) {
      visitorSpaceCards
        ..clear()
        ..addAll(cleanVisitor);
    }
    final cleanAudiences = <SpaceCardKind, SpaceAudience>{
      for (final kind in SpaceCardKind.values)
        kind:
            audiences?[kind] ??
            (cleanVisitor?.contains(kind) == true
                ? SpaceAudience.anyone
                : SpaceAudience.onlyMe),
    };
    spaceCardAudiences
      ..clear()
      ..addAll(cleanAudiences);
    visitorSpaceCards
      ..clear()
      ..addAll(
        cleanAudiences.entries
            .where((entry) => entry.value != SpaceAudience.onlyMe)
            .map((entry) => entry.key),
      );
    spaceIntro = _cleanSpaceIntro(intro);
    spaceSeasonText = _cleanSpaceSeasonText(seasonText);
    spaceProfilePhotoNoteId = _cleanSpaceSeasonPhotoNoteId(profilePhotoNoteId);
    spaceSeasonPhotoNoteId = _cleanSpaceSeasonPhotoNoteId(seasonPhotoNoteId);
    shareSpaceProfilePhoto = shareProfilePhoto;
    shareSpaceSeasonPhoto = shareSeasonPhoto;
    shareSpaceProfile = shareProfile;

    final valid = goals.map((goal) => goal.title).toSet();
    this.featuredGoalTitles
      ..clear()
      ..addAll(
        cleanFeatured
            .map((title) => title.trim())
            .where((title) => title.isNotEmpty && valid.contains(title))
            .toSet()
            .take(3),
      );
    notifyListeners();
  }

  void setSpaceProfile({
    required String intro,
    required Iterable<String> goals,
    bool? shared,
  }) {
    setSpacePage(
      order: spaceCardOrder,
      hidden: hiddenSpaceCards,
      visitorVisible: visitorSpaceCards,
      audiences: spaceCardAudiences,
      intro: intro,
      featuredGoalTitles: goals,
      seasonText: spaceSeasonText,
      profilePhotoNoteId: spaceProfilePhotoNoteId,
      seasonPhotoNoteId: spaceSeasonPhotoNoteId,
      shareProfilePhoto: shareSpaceProfilePhoto,
      shareSeasonPhoto: shareSpaceSeasonPhoto,
      shareProfile: shared ?? shareSpaceProfile,
    );
  }

  void setSharedRoomPhotoPaths({
    required String profilePath,
    required String seasonPath,
  }) {
    final cleanProfile = _cleanSharedRoomPhotoPath(profilePath);
    final cleanSeason = _cleanSharedRoomPhotoPath(seasonPath);
    if (spaceProfilePhotoPath == cleanProfile &&
        spaceSeasonPhotoPath == cleanSeason) {
      return;
    }
    spaceProfilePhotoPath = cleanProfile;
    spaceSeasonPhotoPath = cleanSeason;
    notifyListeners();
  }

  /// For a candidate that does not offer remote visitor photos, forget any
  /// older consent bits and acknowledged public handles while preserving the
  /// locally selected My Space photos themselves.
  bool disableVisitorPhotoSharing() {
    if (!shareSpaceProfilePhoto &&
        !shareSpaceSeasonPhoto &&
        spaceProfilePhotoPath.isEmpty &&
        spaceSeasonPhotoPath.isEmpty) {
      return false;
    }
    shareSpaceProfilePhoto = false;
    shareSpaceSeasonPhoto = false;
    spaceProfilePhotoPath = '';
    spaceSeasonPhotoPath = '';
    notifyListeners();
    return true;
  }

  /// For a candidate without UGC moderation, forget every public writing/name
  /// consent bit while preserving the private My Space page itself. Photo
  /// consent and public handles are part of the same visitor surface.
  bool disableVisitorProfileSharing() {
    final changed =
        shareSpaceProfile ||
        visitorSpaceCards.isNotEmpty ||
        spaceCardAudiences.values.any((a) => a != SpaceAudience.onlyMe) ||
        shareSpaceProfilePhoto ||
        shareSpaceSeasonPhoto ||
        spaceProfilePhotoPath.isNotEmpty ||
        spaceSeasonPhotoPath.isNotEmpty;
    if (!changed) return false;
    shareSpaceProfile = false;
    visitorSpaceCards.clear();
    for (final kind in SpaceCardKind.values) {
      spaceCardAudiences[kind] = SpaceAudience.onlyMe;
    }
    shareSpaceProfilePhoto = false;
    shareSpaceSeasonPhoto = false;
    spaceProfilePhotoPath = '';
    spaceSeasonPhotoPath = '';
    notifyListeners();
    return true;
  }

  static String _cleanSharedRoomPhotoPath(Object? value) {
    if (value is! String) return '';
    final clean = value.trim();
    return clean.length <= 192 ? clean : '';
  }

  static String _cleanPublicRoomPhotoPath(Object? value) {
    if (value is! String) return '';
    final clean = value.trim();
    return RegExp(
          r'^shared_rooms/[a-f0-9]{64}/[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}/room/[A-Za-z0-9_-]{22}$',
        ).hasMatch(clean)
        ? clean
        : '';
  }

  static double _cleanRoomPhotoAlignment(Object? value) {
    if (value is! num) return 0;
    final clean = value.toDouble();
    return clean.isFinite && clean >= -1 && clean <= 1 ? clean : 0;
  }

  static int _cleanRoomPhotoDimension(Object? value) {
    if (value is! int || value < 1 || value > 1200) return 1;
    return value;
  }

  /// Commits the deliberate share choice while retaining the last
  /// acknowledged projection until an external unpublish has completed.
  void setRoomPhotoSharing(bool enabled) {
    if (shareRoomPhoto == enabled) return;
    shareRoomPhoto = enabled;
    notifyListeners();
  }

  /// Records only a projection that the public room document has acknowledged.
  /// An empty or invalid path always discards its display metadata too.
  void setSharedRoomPhotoProjection({
    required String path,
    required bool fillFrame,
    required double alignmentX,
    required double alignmentY,
    required int pixelWidth,
    required int pixelHeight,
  }) {
    final cleanPath = _cleanPublicRoomPhotoPath(path);
    final cleanFill = cleanPath.isNotEmpty && fillFrame;
    final cleanX = cleanPath.isEmpty
        ? 0.0
        : _cleanRoomPhotoAlignment(alignmentX);
    final cleanY = cleanPath.isEmpty
        ? 0.0
        : _cleanRoomPhotoAlignment(alignmentY);
    final cleanWidth = cleanPath.isEmpty
        ? 1
        : _cleanRoomPhotoDimension(pixelWidth);
    final cleanHeight = cleanPath.isEmpty
        ? 1
        : _cleanRoomPhotoDimension(pixelHeight);
    if (spaceRoomPhotoPath == cleanPath &&
        spaceRoomPhotoFill == cleanFill &&
        spaceRoomPhotoX == cleanX &&
        spaceRoomPhotoY == cleanY &&
        spaceRoomPhotoWidth == cleanWidth &&
        spaceRoomPhotoHeight == cleanHeight) {
      return;
    }
    spaceRoomPhotoPath = cleanPath;
    spaceRoomPhotoFill = cleanFill;
    spaceRoomPhotoX = cleanX;
    spaceRoomPhotoY = cleanY;
    spaceRoomPhotoWidth = cleanWidth;
    spaceRoomPhotoHeight = cleanHeight;
    notifyListeners();
  }

  /// Drops the acknowledged public handle. Set [disableSharing] after a
  /// confirmed unpublish or reset; the source bytes remain device-local.
  void clearSharedRoomPhotoProjection({bool disableSharing = false}) {
    final changed =
        (disableSharing && shareRoomPhoto) ||
        spaceRoomPhotoPath.isNotEmpty ||
        spaceRoomPhotoFill ||
        spaceRoomPhotoX != 0 ||
        spaceRoomPhotoY != 0 ||
        spaceRoomPhotoWidth != 1 ||
        spaceRoomPhotoHeight != 1;
    if (!changed) return;
    if (disableSharing) shareRoomPhoto = false;
    spaceRoomPhotoPath = '';
    spaceRoomPhotoFill = false;
    spaceRoomPhotoX = 0;
    spaceRoomPhotoY = 0;
    spaceRoomPhotoWidth = 1;
    spaceRoomPhotoHeight = 1;
    notifyListeners();
  }

  void setMemoryPinned(String noteId, bool pinned) {
    final changed = pinned ? memoryPins.add(noteId) : memoryPins.remove(noteId);
    if (changed) notifyListeners();
  }

  /// A quiet-company session publishes only a fixed activity kind and expiry
  /// in the existing appearance-only room card. The actual task stays private.
  String quietCompanyKind = 'none';
  int quietCompanyUntil = 0;

  bool get quietCompanyActive =>
      quietCompanyKind != 'none' &&
      quietCompanyUntil > Clock.now().millisecondsSinceEpoch;

  void startQuietCompany(String kind, Duration duration) {
    const allowed = {'study', 'making', 'reset', 'quiet'};
    quietCompanyKind = allowed.contains(kind) ? kind : 'quiet';
    quietCompanyUntil = Clock.now().add(duration).millisecondsSinceEpoch;
    notifyListeners();
  }

  void stopQuietCompany() {
    quietCompanyKind = 'none';
    quietCompanyUntil = 0;
    notifyListeners();
  }

  /// Local-reminder prefs (round-22). Native-only — the scheduling no-ops on
  /// web (see notifications.dart). Default off; default nudge at 9:00am.
  bool notifyEnabled = false;
  int notifyHour = 9;
  int notifyMinute = 0;

  /// A separate, opt-in reminder for the daily closing ledger. The existing
  /// morning quest nudge stays on when notifications are enabled; this one is
  /// deliberately off until the person asks for it.
  bool nightReminderEnabled = false;
  int nightReminderHour = 21;
  int nightReminderMinute = 0;

  void setNotify({bool? enabled, int? hour, int? minute}) {
    if (enabled != null) notifyEnabled = enabled;
    if (hour != null) notifyHour = hour;
    if (minute != null) notifyMinute = minute;
    notifyListeners();
  }

  void setNightReminder({bool? enabled, int? hour, int? minute}) {
    if (enabled != null) nightReminderEnabled = enabled;
    if (hour != null) nightReminderHour = hour.clamp(0, 23);
    if (minute != null) nightReminderMinute = minute.clamp(0, 59);
    notifyListeners();
  }

  /// Keeps the in-app reminder switches honest when the operating-system
  /// permission has been revoked (or a backup restores an enabled switch onto
  /// a device that never granted it). This never requests permission.
  void disableRemindersWithoutPermission() {
    if (!notifyEnabled && !nightReminderEnabled) return;
    notifyEnabled = false;
    nightReminderEnabled = false;
    notifyListeners();
  }

  /// Wall-clock ms of the last save — the "newness" signal cloud sync uses
  /// to decide which copy wins (a stale device must never clobber a newer
  /// cloud save). Stamped by the shell on every persist.
  int lastModified = 0;

  int level = 1;
  int xp = 0;
  int totalXp = 0;
  final Map<Stat, int> stats = {for (final s in Stat.values) s: 0};

  /// Glimmers — the earn-by-play currency. They unlock a small number of
  /// complete room identities and are never bought with money. Earned on every
  /// completion alongside XP.
  int embers = 0;

  /// Legacy additive-furniture ownership retained for old saves and shared
  /// room payloads. Current complete room identities do not render this set.
  final Set<String> ownedFurniture = {};

  /// Inert legacy wire values retained for schema-28 save compatibility.
  /// They are bounded catalog ids only and have no visible product effect.
  final List<String> roomKeepsakes = [];

  /// Preserves the historical bounded field. Unknown, duplicate, and excess
  /// ids are discarded; the result is never rendered or narrated.
  void setRoomKeepsakes(Iterable<String> value) {
    final next = sanitizeRoomKeepsakes(value.toList());
    if (listEquals(roomKeepsakes, next)) return;
    roomKeepsakes
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  /// Buy a piece if affordable and allowed (the caller resolves any
  /// achievement gate). Returns true on success.
  bool buyFurniture(String id, int price, {bool allowed = true}) {
    if (!allowed || embers < price || ownedFurniture.contains(id)) return false;
    embers -= price;
    ownedFurniture.add(id);
    notifyListeners();
    return true;
  }

  /// Whole-room identity ownership plus legacy floor-style compatibility. Own
  /// many complete rooms, display one; Writer’s Hearth is implicitly owned.
  final Set<String> ownedStyles = {};
  String wallStyle = 'wall_walnut';
  String floorStyle = 'floor_oak';

  /// Buy a style (affordable + allowed + not already owned) and put it on.
  bool buyStyle(
    String id,
    int price,
    RoomStyleKind kind, {
    bool allowed = true,
  }) {
    if (!allowed || embers < price || ownedStyles.contains(id)) return false;
    embers -= price;
    ownedStyles.add(id);
    applyStyle(id, kind);
    return true;
  }

  /// Put an already-owned style on the wall or floor. Ignores an unowned id
  /// (defence-in-depth: only the shop cards gate this today, so a stray call
  /// — deep link, sync merge, a future UI slip — can't equip paid content for
  /// free). The free defaults are always allowed.
  void applyStyle(String id, RoomStyleKind kind) {
    const freeFloor = 'floor_oak';
    if (kind == RoomStyleKind.wall) {
      final theme = spaceThemeById(id);
      if (theme?.price != 0 && !ownedStyles.contains(id)) return;
      wallStyle = id;
      questDeskStyle = id;
    } else {
      if (id != freeFloor && !ownedStyles.contains(id)) return;
      floorStyle = id;
    }
    notifyListeners();
  }

  /// Creature skins (round-47) — the colour of the ember itself, chosen in the
  /// shop. Exclusive like room styles (own many, wear one). The free default
  /// 'ember_amber' is implicitly owned. Distinct from [equippedSkin], which is
  /// an earned override: taking it off reveals this underlying shop choice.
  final Set<String> ownedSkins = {};
  String creatureSkin = 'ember_amber';

  bool buySkin(String id, int price, {bool allowed = true}) {
    if (!allowed || embers < price || ownedSkins.contains(id)) return false;
    embers -= price;
    ownedSkins.add(id);
    creatureSkin = id;
    notifyListeners();
    return true;
  }

  void applySkin(String id) {
    if (id != 'ember_amber' && !ownedSkins.contains(id)) return;
    creatureSkin = id;
    notifyListeners();
  }

  /// Window views (round-49) — the landscape outside your room's window, the
  /// owner's "landscape behind avatar." Exclusive (one view at a time); the
  /// free default 'moon' is implicitly owned.
  final Set<String> ownedWindows = {};
  String windowScene = 'moon';

  bool buyWindow(String id, int price, {bool allowed = true}) {
    if (!allowed || embers < price || ownedWindows.contains(id)) return false;
    embers -= price;
    ownedWindows.add(id);
    windowScene = id;
    notifyListeners();
    return true;
  }

  void applyWindow(String id) {
    if (id != 'moon' && !ownedWindows.contains(id)) return;
    windowScene = id;
    notifyListeners();
  }

  /// Painted stages (round-60) — the scene the creature stands in at its hero
  /// moments (skin try-on, the share card). Exclusive; the free default
  /// 'hearthside' is implicitly owned.
  final Set<String> ownedScenes = {};
  String stageScene = 'hearthside';

  bool buyScene(String id, int price, {bool allowed = true}) {
    if (!allowed || embers < price || ownedScenes.contains(id)) return false;
    embers -= price;
    ownedScenes.add(id);
    stageScene = id;
    notifyListeners();
    return true;
  }

  void applyScene(String id) {
    if (id != 'hearthside' && !ownedScenes.contains(id)) return;
    stageScene = id;
    notifyListeners();
  }

  /// Share code for "Your Space" once published (round-52, social) — null until
  /// you first share. Stable so re-sharing updates the same public room doc.
  String? roomCode;

  /// Per-domain journal — notes the user keeps on a whole life domain (their
  /// "base" for Home, Care, Craft…). Sparse: only domains with entries appear.
  /// Lists are replaced wholesale (see [NoteList]) so callers never mutate in
  /// place. The keystone of notes-with-consequence (round-24): a domain page
  /// gathers its notes + the quests serving it + its growth in one place.
  final Map<Stat, List<Note>> domainNotes = {};

  List<Note> notesFor(Stat s) => domainNotes[s] ?? const [];
  void setDomainNotes(Stat s, List<Note> notes) {
    if (notes.isEmpty) {
      domainNotes.remove(s);
    } else {
      domainNotes[s] = notes;
    }
    notifyListeners();
  }

  /// The free-form journal (round-45) — notes not tied to any one quest, goal
  /// or domain. The standalone "maybe even a journal" the owner asked for, and
  /// the writing home of the Journal hub that finally makes notes discoverable.
  List<Note> journal = const [];
  void setJournal(List<Note> notes) {
    journal = notes;
    final byId = {for (final note in notes) note.id: note};
    if (byId[nightDraftNoteId]?.night == null) nightDraftNoteId = null;
    final pendingMessage = byId[pendingMorningNoteId]?.night?.tomorrowMessage
        ?.trim();
    if (pendingMessage == null || pendingMessage.isEmpty) {
      pendingMorningNoteId = null;
    }
    notifyListeners();
  }

  Note? _journalNote(String? id) {
    if (id == null) return null;
    for (final note in journal) {
      if (note.id == id) return note;
    }
    return null;
  }

  Note? get nightDraftNote {
    final note = _journalNote(nightDraftNoteId);
    if (note?.night == null || note?.trace?.day != Days.nightKey(Clock.now())) {
      return null;
    }
    return note;
  }

  String? get morningSelfMessage {
    final message = _journalNote(
      pendingMorningNoteId,
    )?.night?.tomorrowMessage?.trim();
    return message == null || message.isEmpty ? null : message;
  }

  /// Creates or replaces tonight's one composite Journal page. Blank drafts
  /// are ignored, and repeated saves keep the same note identity.
  Note? saveNightJournal(NightJournalData data, JournalTrace trace) {
    final existing = nightDraftNote;
    if (data.isEmpty) {
      if (existing != null) {
        journal = journal.without(existing);
        if (pendingMorningNoteId == existing.id) pendingMorningNoteId = null;
      }
      nightDraftNoteId = null;
      notifyListeners();
      return null;
    }

    final note = existing == null
        ? Note(
            at: Clock.now(),
            text: data.plainText,
            context: buildTitle,
            trace: trace,
            night: data,
          )
        : existing.withNight(data, updatedTrace: trace);
    journal = existing == null ? [...journal, note] : journal.replacing(note);
    nightDraftNoteId = note.id;
    notifyListeners();
    return note;
  }

  /// Updates a structured night page from Journal or Calendar without turning
  /// an old page into tonight's draft. An empty edit removes the page and any
  /// delivery pointer that referenced it.
  Note? updateNightJournalEntry(Note entry, NightJournalData data) {
    final existing = _journalNote(entry.id);
    if (existing == null || existing.night == null) return null;
    if (data.isEmpty) {
      journal = journal.without(existing);
      if (nightDraftNoteId == existing.id) nightDraftNoteId = null;
      if (pendingMorningNoteId == existing.id) pendingMorningNoteId = null;
      notifyListeners();
      return null;
    }
    final updated = existing.withNight(data, updatedTrace: existing.trace);
    journal = journal.replacing(updated);
    if (pendingMorningNoteId == existing.id &&
        (updated.night?.tomorrowMessage?.trim().isEmpty ?? true)) {
      pendingMorningNoteId = null;
    }
    notifyListeners();
    return updated;
  }

  /// Seals the current draft into this night and arms its tomorrow-message,
  /// if one was written. Repeated calls do not duplicate the Journal entry.
  void finalizeNightJournal(JournalTrace trace) {
    final draft = nightDraftNote;
    if (draft == null || draft.night == null) {
      // A genuinely new close with no message supersedes an older, unviewed
      // message. A duplicate finalize after this same night closed is a no-op.
      if (nightDoneDay != activeNightDayKey && pendingMorningNoteId != null) {
        pendingMorningNoteId = null;
        notifyListeners();
      }
      return;
    }
    final finalNote = draft.withNight(draft.night!, updatedTrace: trace);
    journal = journal.replacing(finalNote);
    final message = finalNote.night?.tomorrowMessage?.trim() ?? '';
    pendingMorningNoteId = message.isEmpty ? null : finalNote.id;
    nightDraftNoteId = null;
    notifyListeners();
  }

  /// Freezes the part of today that a generic notes page cannot know: the
  /// quests that happened, the goals they served, the build they moved, and
  /// the energy the person brought. Quick reflections, full journal pages,
  /// and the night ledger all use this one source so an old entry never
  /// quietly changes when today's state changes.
  JournalTrace todayJournalTrace(List<Quest> quests) {
    final today = Days.key(Clock.now());
    return _journalTrace(
      quests,
      day: today,
      xp: _dayXp(today),
      statGains: _dayStats(today),
      questTitles: _dayQuestTitles(today),
      energy: energyWeatherDay == today ? energyWeather : null,
    );
  }

  String get activeNightDayKey => Days.nightKey(Clock.now());

  bool get _nightUsesSnapshot => previousDayKey == activeNightDayKey;

  /// Everything the night-owned day carried: its Quest bucket plus the day's
  /// own records (kept classes, the full-day bonus and Extra Credit).
  int get nightXp => _dayXp(activeNightDayKey);

  Map<Stat, int> get nightStatGains => _dayStats(activeNightDayKey);

  List<String> get nightQuestTitles => _dayQuestTitles(activeNightDayKey);

  int get nightCompletionCount =>
      history[activeNightDayKey] ?? nightQuestTitles.length;

  JournalTrace nightJournalTrace(List<Quest> quests) => _journalTrace(
    quests,
    day: activeNightDayKey,
    xp: nightXp,
    statGains: nightStatGains,
    questTitles: nightQuestTitles,
    energy: _nightUsesSnapshot
        ? previousDayEnergy
        : energyWeatherDay == activeNightDayKey
        ? energyWeather
        : null,
  );

  /// The trace for [dayKey]: the night-owned day's own when it is that day
  /// (a class-day evening's page after midnight still belongs to it),
  /// otherwise what that day carried.
  JournalTrace journalTraceFor(List<Quest> quests, String dayKey) {
    if (dayKey == activeNightDayKey) return nightJournalTrace(quests);
    return _journalTrace(
      quests,
      day: dayKey,
      xp: _dayXp(dayKey),
      statGains: _dayStats(dayKey),
      questTitles: _dayQuestTitles(dayKey),
      energy: energyWeatherDay == dayKey
          ? energyWeather
          : previousDayKey == dayKey
          ? previousDayEnergy
          : null,
    );
  }

  JournalTrace _journalTrace(
    List<Quest> quests, {
    required String day,
    required int xp,
    required Map<Stat, int> statGains,
    required List<String> questTitles,
    required EnergyWeather? energy,
  }) {
    final titles = questTitles.toSet().toList(growable: false);
    final goalTitles = <String>{};
    for (final quest in quests) {
      if (!titles.contains(quest.displayTitle) &&
          !titles.contains(quest.title)) {
        continue;
      }
      final goal = quest.goalTitle?.trim();
      if (goal != null && goal.isNotEmpty) goalTitles.add(goal);
    }
    return JournalTrace(
      day: day,
      level: level,
      totalXp: totalXp,
      todayXp: xp,
      streakDays: streakDays,
      questTitles: titles,
      extraCreditTitles: extraCreditTitlesForDay(day),
      // One label per kept class, so a course that met twice counts twice
      // on the page's line (`3 classes · ...`) while its name shows once.
      classTitles: [for (final kept in classesKeptOn(day)) kept.label],
      goalTitles: goalTitles.toList(growable: false),
      statGains: {
        for (final entry in statGains.entries)
          if (entry.value > 0) entry.key: entry.value,
      },
      energy: energy,
    );
  }

  /// The Quest bucket for [dayKey]. Quest XP keeps using the live
  /// today/previous rollover buckets; a day's own records are added only when
  /// reading it, which keeps a 1am credit out of today's stat bucket and
  /// keeps class XP out of the Quest soft cap.
  int _questDayXp(String dayKey) {
    final calendarDay = Days.key(Clock.now());
    if (_nightUsesSnapshot && dayKey == previousDayKey) return previousDayXp;
    // An app that remains open through midnight has not rolled its live
    // Quest bucket yet. It still belongs to [lastActiveDay], not the new
    // calendar date, until rollover snapshots it.
    if (lastActiveDay == dayKey) return todayXp;
    if (lastActiveDay != null && lastActiveDay != calendarDay) return 0;
    return dayKey == calendarDay ? todayXp : 0;
  }

  int _dayXp(String dayKey) =>
      _questDayXp(dayKey) + (dayRecordFor(dayKey)?.xp ?? 0);

  Map<Stat, int> _dayStats(String dayKey) {
    final Map<Stat, int> questStats;
    if (_nightUsesSnapshot && dayKey == previousDayKey) {
      questStats = previousDayStats;
    } else if (lastActiveDay == dayKey ||
        (lastActiveDay == null && dayKey == Days.key(Clock.now()))) {
      questStats = todayStats;
    } else {
      questStats = const {};
    }
    final classes = dayRecordFor(dayKey)?.classes ?? const <KeptClass>[];
    if (classes.isEmpty) return questStats;
    final merged = Map<Stat, int>.of(questStats);
    for (final kept in classes) {
      merged[kept.stat] = (merged[kept.stat] ?? 0) + kept.statGain;
    }
    return merged;
  }

  List<String> _dayQuestTitles(String dayKey) {
    if (_nightUsesSnapshot && dayKey == previousDayKey) {
      return previousDayQuestTitles;
    }
    if (lastActiveDay == dayKey ||
        (lastActiveDay == null && dayKey == Days.key(Clock.now()))) {
      return todayQuestTitles;
    }
    return const [];
  }

  /// Recent gains, newest first — the Me page's attribution ledger.
  final List<LedgerEntry> ledger = [];

  // ── streak (real now: consecutive days with ≥1 completion) ──────
  int streakDays = 0;
  int bestStreak = 0;

  /// The last day a Quest was completed. Quest-only, always.
  String? lastCompletionDay;

  /// The last day the streak advanced. Quest days always advance it; with
  /// [ClassDayRules.classDayLightsStreak], a kept-class day does too. It never
  /// trails [lastCompletionDay], so older saves (and tests that set only the
  /// Quest day) read exactly as before.
  String? get lastStreakDay {
    final quest = lastCompletionDay;
    final other = _lastStreakDay;
    if (quest == null) return other;
    if (other == null) return quest;
    return other.compareTo(quest) > 0 ? other : quest;
  }

  String? _lastStreakDay;

  /// A class keep restarted the streak after a gap the reserve could not
  /// hold. The next Quest, while no later day has lit the streak, still gets
  /// the welcome-back bonus it would have had if it had come first.
  String? comebackPendingDay;

  bool get _comebackPending =>
      comebackPendingDay != null && comebackPendingDay == lastStreakDay;

  /// Answers "was this a rest day?" for [ClassDayRules.restDaysPause]. The
  /// shell sets it from the timetable (a term day with no classes). The
  /// timetable is device-wide and not in the save, so this hook is too: it
  /// survives undo, restore and cloud adoption of a new [GameState].
  static bool Function(String dayKey)? restDayResolver;

  /// Streak freezes are available from the beginning. Each one quietly holds
  /// one day away, but is spent only when the whole gap can be covered. The
  /// serialized names remain the old `streakShields` names for save and cloud
  /// compatibility; public copy consistently calls these freezes.
  static const starterStreakFreezes = 3;
  static const maxStreakFreezes = 7;
  static const _baseFreezeCapacity = 5;
  static const _streakFreezeVersion = 1;
  int streakFreezes = starterStreakFreezes;
  int streakFreezeProgress = 0;
  int streakFreezeVersion = _streakFreezeVersion;
  bool freezeLevelBonusGranted = false;
  final Set<String> frozenStreakDays = {};

  /// Level 6 opens enough room to hold a full week; freezes still work before
  /// then, so the app never withholds its safety net from a new keeper.
  int get streakFreezeCapacity =>
      level >= 6 ? maxStreakFreezes : _baseFreezeCapacity;

  /// Ordinary active days replenish the reserve. Vitality bends this loop in a
  /// deterministic, legible way instead of hiding a random reward chance.
  int get activeDaysPerFreeze => (stats[Stat.vit] ?? 0) >= 40 ? 2 : 3;

  /// A small public preview for UI. Nothing is spent until a quest is actually
  /// completed, and an under-covered gap never wastes the reserve.
  ({int days, bool covered}) get pendingStreakGap {
    final situation = _streakSituation();
    return (days: situation.days.length, covered: situation.covered);
  }

  // ── achievement counters ─────────────────────────────────────────
  int totalCompletions = 0;

  /// [totalCompletions] when the last level was reached, so a level-up can
  /// say what earned it. Null for older saves until their next level.
  int? completionsAtLastLevel = 0;
  int verifiedCompletions = 0;
  int dreadCompletions = 0;
  int epicCompletions = 0;
  int eventCompletions = 0;
  int customCompletions = 0;
  int comebacks = 0; // returns after a missed day
  int dawnCompletions = 0; // before 8am
  int duskCompletions = 0; // 9pm or later
  int perfectDays = 0; // days every due quest was cleared
  String? lastPerfectDay;
  final Set<String> unlockedAchievements = {};

  /// Default starter quests the user deliberately removed — refresh must not
  /// resurrect these (lowercased titles).
  final Set<String> removedDefaults = {};

  /// Cosmetic fragments found in the embers (loot drops). Honest now: a drop
  /// is actually kept and shown on the Me page, not announced-then-vanished.
  final Set<String> collectedLoot = {};

  /// The currently-worn cosmetic (a name from [collectedLoot]); null = the
  /// default dominant-stat look. Recolors the hearth flame, portrait aura,
  /// and completion sparks (see content/cosmetics.dart). Toggle with
  /// [equipSkin].
  String? equippedSkin;

  /// Equip a found cosmetic, or unequip it if it's already worn. notify
  /// triggers the shell's persist listener.
  void equipSkin(String name) {
    if (!collectedLoot.contains(name)) return;
    equippedSkin = equippedSkin == name ? null : name;
    notifyListeners();
  }

  /// Evidence cards the reader has already seen surfaced as relevant — so the
  /// Sparks feed can flag a genuinely NEW card the first time it matters
  /// (after a relevant rank-up). Persisted.
  final Set<String> seenEvidence = {};

  void markEvidenceSeen(Iterable<String> titles) {
    final before = seenEvidence.length;
    seenEvidence.addAll(titles);
    if (seenEvidence.length != before) notifyListeners();
  }

  /// The chosen candlelit canvas theme (id from content/themes.dart); the
  /// non-default ones open at the Lv-5 THEMES unlock. Persisted.
  String canvasTheme = 'walnut';

  void setTheme(String id) {
    if (!isCanvasThemeId(id)) return;
    final choice = canvasThemeById(id);
    if (choice.locked && level < 5) return;
    if (canvasTheme == id) return;
    canvasTheme = id;
    notifyListeners();
  }

  /// The wall-style id whose material language dresses the Quests HUD.
  ///
  /// Retained for old backup compatibility. Current rendering follows
  /// [wallStyle], so the room and its board materials stay together.
  String questDeskStyle = 'wall_walnut';

  void setQuestDeskStyle(String id) {
    if (questDeskStyle == id) return;
    questDeskStyle = id;
    notifyListeners();
  }

  /// dateKey → completions that day (calendar history dots).
  final Map<String, int> history = {};

  // ── this week's training (the weekend brawl reads it) ──────────────
  /// One small mark for every Quest finished in the last two weeks: when, for
  /// which stat, and what it counts for (1, or 1.5 when the timer proved it).
  /// The week's training points are read from these ([weeklyTraining]). Kept
  /// in the save, so the whole-save undo of a Quest takes its mark back with
  /// it. Kept classes are not here: their records already live in the day
  /// records, and [trainingMarks] reads them from there.
  final List<TrainingMark> trainingLog = [];

  /// The marks kept: this week's and the week before's (a "last week" line
  /// may want it), and never more than this many.
  static const _trainingLogMax = 400;

  /// Remembers one finished Quest for the week's training. [at] is the moment
  /// it was finished (defaults to [Clock.now]); [weight] is 1, or
  /// [timerProvenWeight] when the countdown proved it.
  void markTraining(Stat stat, {DateTime? at, double weight = 1}) {
    final now = Clock.now();
    trainingLog.add(TrainingMark(at: at ?? now, stat: stat, weight: weight));
    final keepFrom = trainingWeekStart(now).subtract(const Duration(days: 7));
    trainingLog.removeWhere((mark) => mark.at.isBefore(keepFrom));
    if (trainingLog.length > _trainingLogMax) {
      trainingLog.removeRange(0, trainingLog.length - _trainingLogMax);
    }
  }

  /// Everything that trained a stat recently: the Quests in [trainingLog] and
  /// the classes he kept (each one counts 1 for the stat its kind feeds).
  List<TrainingMark> get trainingMarks => [
    ...trainingLog,
    for (final record in _dayRecords)
      for (final kept in record.classes)
        TrainingMark(at: kept.keptAt, stat: kept.stat),
  ];

  /// The training points per stat this week (Monday 04:00 to [now], which is
  /// [Clock.now] unless given): the number of Quests finished for each stat,
  /// the timer-proven ones counting 1.5, and the classes kept.
  WeeklyTraining weeklyTraining([DateTime? now]) =>
      WeeklyTraining.from(trainingMarks, now ?? Clock.now());

  String? lastActiveDay;

  // ── user goals (quests feed them via goalTitle) ─────────────────
  final List<Goal> goals = [];

  // Celebration queues (FIFO). Each commit may produce a goal-achieved, a
  // milestone, and/or a rank-up; the UI consumes them later, asynchronously,
  // once per completion's overlay chain. These are QUEUES (not single slots)
  // so a rapid second completion can't overwrite or drop the first's pending
  // celebration — each chain pops the oldest in arrival order (bug-hunt §12/§15).

  /// ACHIEVE goals that just crossed the finish line, awaiting their takeover.
  final List<Goal> _achievedQ = [];
  Goal? takeJustAchieved() =>
      _achievedQ.isEmpty ? null : _achievedQ.removeAt(0);

  /// BECOME-goal milestones reached (carries the milestone value).
  final List<(Goal, int)> _milestonedQ = [];
  (Goal, int)? takeJustMilestoned() =>
      _milestonedQ.isEmpty ? null : _milestonedQ.removeAt(0);

  /// Stat rank-tier crossings, awaiting the "WHY THIS WORKS" evidence beat.
  final List<(Stat, StatRank)> _rankedUpQ = [];
  (Stat, StatRank)? takeJustRankedUp() =>
      _rankedUpQ.isEmpty ? null : _rankedUpQ.removeAt(0);

  /// Streak milestones reached (7/30/100 days), awaiting their full-screen
  /// chest celebration. Carries the milestone day-count.
  final List<int> _streakMilestoneQ = [];
  int? takeJustStreakMilestone() =>
      _streakMilestoneQ.isEmpty ? null : _streakMilestoneQ.removeAt(0);

  /// Ember chest payouts for each streak milestone (DESIGN.md §7).
  static const streakMilestones = <int, int>{
    7: 50, // a week — a warm chest
    30: 200, // a month — a proper haul
    100: 800, // a season — legendary
  };

  // ── today's haul (the night recap's raw material; reset on rollover) ──
  /// Quest-only XP for the live calendar-day bucket. Read helpers add the
  /// day's own records for night and Journal attribution; class XP never
  /// enters this bucket, so it never pushes evening Quests into the soft cap.
  int todayXp = 0;
  final Map<Stat, int> todayStats = {};
  final List<String> todayQuestTitles = [];

  // ── the day's own records (schema 29): kept classes and Extra Credit ──
  /// How many of the newest day records the save keeps (the same horizon as
  /// [history]). The active night (and a record just written for it or a
  /// recent night) is never trimmed: when a backward clock leaves it older
  /// than these, it is kept in addition to them.
  static const dayRecordHorizon = 180;

  /// A queued mark (widget or notification) may land up to this many nights
  /// after its class's day.
  static const classKeepRecentNights = 2;

  /// A class can be marked from this long before it starts.
  static const classKeepLead = Duration(minutes: 15);

  final List<DayRecord> _dayRecords = [];

  /// Every day record, oldest day first.
  List<DayRecord> get dayRecords => List.unmodifiable(_dayRecords);

  DayRecord? dayRecordFor(String dayKey) {
    for (final record in _dayRecords) {
      if (record.dayKey == dayKey) return record;
    }
    return null;
  }

  /// Every class ever kept. Survives the record trim, so it only grows.
  int totalClassesKept = 0;

  /// [totalClassesKept] when the last level was reached.
  int classesAtLastLevel = 0;

  final Map<String, int> _keptClassCounts = {};

  /// Kept classes per course code. Survives the record trim, so "your Nth
  /// lecture of this course" only grows.
  Map<String, int> get keptClassCounts => Map.unmodifiable(_keptClassCounts);

  int keptCountForCourse(String courseCode) =>
      _keptClassCounts[KeptClass.cleanCode(courseCode)] ?? 0;

  static const _maxCourseCounters = 500;

  List<KeptClass> classesKeptOn(String dayKey) =>
      dayRecordFor(dayKey)?.classes ?? const [];

  /// The stored keep for this class, if it was kept.
  KeptClass? keptClassFor(ClassFacts facts) =>
      dayRecordFor(facts.dayKey)?.keptMatching(
        occurrenceKey: facts.occurrenceKey,
        courseCode: facts.keptCode ?? facts.courseCode.trim(),
        startMinute: facts.startMinute,
      );

  /// Class XP for a day, including its full-day bonus.
  int classXpForDay(String dayKey) => dayRecordFor(dayKey)?.classXp ?? 0;

  List<String> classTitlesForDay(String dayKey) => [
    ...{for (final kept in classesKeptOn(dayKey)) kept.label},
  ];

  // ── "Couldn't make it" ────────────────────────────────────────────
  //
  // A dismissed class is neither kept nor held against anyone. It pays no XP,
  // no stat and no Glimmers, counts toward no streak and no tally, and drops
  // out of that day's class set everywhere the set is read (the card, the
  // full-day and tier plans, the evening, the board's close-the-day rule, the
  // night ledger, the Day Ledger widget). The schedule is device-local, so
  // the surfaces that hold it apply [isClassDismissed] when they project a
  // day (`projectClassDay(isDismissed:)`), and the shell's rest-day resolver
  // reads it too (`restDayFor(isDismissed:)`).

  /// The classes he could not make on [dayKey]. Only this engine and the
  /// schedule-holding surfaces read it; no screen shows a count of it.
  List<DismissedClass> classesDismissedOn(String dayKey) =>
      dayRecordFor(dayKey)?.dismissed ?? const [];

  /// Whether this class was dismissed.
  bool isClassDismissed(ClassFacts facts) =>
      dayRecordFor(facts.dayKey)?.dismissedMatching(
        occurrenceKey: facts.occurrenceKey,
        courseCode: facts.keptCode ?? facts.courseCode.trim(),
        startMinute: facts.startMinute,
      ) !=
      null;

  /// Whether [facts] can be set aside now: a real class that is neither
  /// kept nor already dismissed, inside its own night (so a class can be
  /// folded away before it starts, while it runs, or after it ends, until its
  /// night is over).
  bool canDismissClass(ClassFacts facts) {
    if (isClassDismissed(facts)) return false;
    final check = checkClassKeep(facts);
    return check == ClassKeepCheck.open ||
        check == ClassKeepCheck.notStartedYet;
  }

  /// Says he could not make this class. Pays nothing and changes no counter,
  /// stat or streak. Returns false (and writes nothing) when [canDismissClass]
  /// is false: already kept, already dismissed, outside its night, not a class
  /// or a day already holding the most dismissals a save keeps.
  ///
  /// Bumps [rewardSerial] although it pays nothing: a whole-save undo taken
  /// before it would otherwise put the class back without a word.
  bool dismissClass(ClassFacts facts) {
    if (!canDismissClass(facts)) return false;
    final before =
        dayRecordFor(facts.dayKey) ?? DayRecord(dayKey: facts.dayKey);
    if (before.dismissed.length >= DayRecord.maxClassesPerDay) return false;
    _putDayRecord(
      before.copyWith(
        dismissed: [
          ...before.dismissed,
          DismissedClass(
            occurrenceKey: facts.occurrenceKey,
            courseCode: facts.keptCode!,
            startMinute: facts.startMinute,
            dismissedAt: Clock.now().toUtc(),
            optional: !ClassPay.countsTowardDay(
              KeptClass.cleanKind(facts.kind),
            ),
          ),
        ],
      ),
    );
    _rewardSerial++;
    notifyListeners();
    return true;
  }

  /// Takes a dismissal back: the class is on its day again, exactly as it was
  /// (a day record that held nothing else goes away entirely). Returns false
  /// when the class was not dismissed.
  bool undoDismiss(ClassFacts facts) {
    final record = dayRecordFor(facts.dayKey);
    if (record == null) return false;
    final left = [
      for (final item in record.dismissed)
        if (!item.sameClassAs(
          occurrenceKey: facts.occurrenceKey,
          courseCode: facts.keptCode ?? facts.courseCode.trim(),
          startMinute: facts.startMinute,
        ))
          item,
    ];
    if (left.length == record.dismissed.length) return false;
    _replaceDayRecord(record.copyWith(dismissed: left));
    _rewardSerial++;
    notifyListeners();
    return true;
  }

  /// Bumps on every reward (Quest commit, class keep, Extra Credit) and on an
  /// Extra Credit wording edit, which a whole-save restore would otherwise
  /// quietly put back (engine map 5.3.4). Not saved: it exists so a
  /// [RewardUndoSlot] can tell that something newer has landed since its
  /// snapshot.
  int get rewardSerial => _rewardSerial;
  int _rewardSerial = 0;

  /// When [facts]'s own night ends (04:00 the morning after its day, in its
  /// timetable's zone), as a UTC instant. [ClassFacts.nightEndsAt] when given;
  /// else worked out from [ClassFacts.startsAt] and the local start minute,
  /// which together carry the timetable zone's offset at the start. Null when
  /// neither is known or they disagree beyond any real zone offset.
  static DateTime? classNightEnd(ClassFacts facts) {
    final given = facts.nightEndsAt;
    if (given != null) return given.toUtc();
    final startsAt = facts.startsAt;
    final day = Days.tryParse(facts.dayKey);
    if (startsAt == null || day == null) return null;
    final wall = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).add(Duration(minutes: facts.startMinute));
    final offset = wall.difference(startsAt.toUtc()).inMinutes;
    if (offset < -12 * 60 || offset > 14 * 60 || offset % 15 != 0) return null;
    return DateTime.utc(
      day.year,
      day.month,
      day.day + 1,
      4,
    ).subtract(Duration(minutes: offset));
  }

  /// Whether [facts] can be kept now (or, for a queued mark, at [at]).
  ///
  /// The window is the class's own night: its civil day from 04:00 until
  /// 04:00 the next morning, in the timetable's zone. When the facts carry
  /// instants ([ClassFacts.nightEndsAt] or [ClassFacts.startsAt]) the window
  /// is judged by instants, so a phone in another zone keeps exactly what
  /// its timetable shows; without them, by the device's own night
  /// ([Days.nightKey]). A queued widget or notification mark carries [at],
  /// the moment it was made: it counts when it was made inside the window
  /// and that night ended at most [classKeepRecentNights] nights ago.
  /// Nothing earlier, nothing in the future.
  ClassKeepCheck checkClassKeep(ClassFacts facts, {DateTime? at}) {
    final day = Days.tryParse(facts.dayKey);
    if (day == null ||
        facts.keptCode == null ||
        facts.startMinute < 0 ||
        facts.startMinute >= 24 * 60 ||
        (facts.occurrenceKey != null &&
            (facts.occurrenceKey!.isEmpty ||
                facts.occurrenceKey!.length > 200))) {
      return ClassKeepCheck.invalid;
    }
    if (keptClassFor(facts) != null) return ClassKeepCheck.alreadyKept;
    // The decoder keeps at most this many per day; one more could be paid
    // now and dropped on the next load, taking its proof with it.
    if (classesKeptOn(facts.dayKey).length >= DayRecord.maxClassesPerDay) {
      return ClassKeepCheck.dayFull;
    }
    final now = Clock.now();
    if (at != null &&
        at.toUtc().isAfter(now.toUtc().add(const Duration(minutes: 1)))) {
      return ClassKeepCheck.outsideWindow;
    }
    final nightEnd = classNightEnd(facts);
    if (nightEnd != null) {
      // Twenty-four hours back; on a daylight-saving change day this start
      // sits an hour off, around 4:00 AM, when no class meets.
      final nightStart = nightEnd.subtract(const Duration(days: 1));
      final moment = (at ?? now).toUtc();
      if (moment.isBefore(nightStart) || !moment.isBefore(nightEnd)) {
        return ClassKeepCheck.outsideWindow;
      }
      if (at != null &&
          !now.toUtc().isBefore(
            nightEnd.add(const Duration(days: classKeepRecentNights)),
          )) {
        return ClassKeepCheck.outsideWindow;
      }
    } else {
      final currentNight = Days.nightKey(now);
      if (at == null) {
        if (facts.dayKey != currentNight) return ClassKeepCheck.outsideWindow;
      } else {
        // Read the mark's night on the same clock face as now.
        final markedAt = now.isUtc ? at.toUtc() : at.toLocal();
        if (Days.nightKey(markedAt) != facts.dayKey) {
          return ClassKeepCheck.outsideWindow;
        }
        final nightsBack = Days.between(day, Days.parse(currentNight));
        if (nightsBack < 0 || nightsBack > classKeepRecentNights) {
          return ClassKeepCheck.outsideWindow;
        }
      }
    }
    final startsAt = facts.startsAt;
    if (startsAt != null &&
        (at ?? now).toUtc().isBefore(
          startsAt.toUtc().subtract(classKeepLead),
        )) {
      return ClassKeepCheck.notStartedYet;
    }
    return ClassKeepCheck.open;
  }

  /// Keeps one class: the person says they went. A separate apply path that
  /// never runs [commit]: it is not a Quest and touches no Quest counters
  /// (completions, history, today's Quest bucket, the Quest-only day marker,
  /// goals, mastery, loot or perfect days).
  ///
  /// Feeds XP, total XP, Glimmers, the kind's stat (with a rank-tier crossing
  /// into the usual rank-up beat), a Me ledger line with the class label, and
  /// achievements. Pass [dayClassKeys] (every real class that day, as
  /// identities) to pay the full-day bonus on the keep that completes the
  /// day. Returns null whenever [checkClassKeep] is not open: already kept,
  /// outside its window, not started, a full day, or not a class. A course
  /// code longer than [KeptClass.maxCodeLength] is stored shortened
  /// ([ClassFacts.keptCode]). Level-ups are left to the caller's usual chain.
  ClassCredit? keepClass(
    ClassFacts facts, {
    List<String> dayClassKeys = const [],
    DateTime? at,
  }) {
    if (checkClassKeep(facts, at: at) != ClassKeepCheck.open) return null;
    final now = Clock.now();
    final code = facts.keptCode!;
    final kind = KeptClass.cleanKind(facts.kind);
    final pay = ClassPay.forKind(kind);
    final kept = KeptClass(
      occurrenceKey: facts.occurrenceKey,
      courseCode: code,
      label: facts.label,
      kind: kind,
      startMinute: facts.startMinute,
      xp: pay.xp,
      stat: pay.stat,
      statGain: pay.statGain,
      keptAt: (at ?? now).toUtc(),
    );
    final before =
        dayRecordFor(facts.dayKey) ?? DayRecord(dayKey: facts.dayKey);
    final classes = [...before.classes, kept];
    // Pressing "I was there" on a class that was set aside is his own word
    // that he went after all: the dismissal is lifted, the class counts again,
    // and it is judged with its day (the caller's keys came from a day that
    // had folded it away).
    final wasDismissed =
        before.dismissedMatching(
          occurrenceKey: facts.occurrenceKey,
          courseCode: code,
          startMinute: facts.startMinute,
        ) !=
        null;
    final keys = {
      for (final key in dayClassKeys)
        if (key.trim().isNotEmpty) key.trim(),
      if (wasDismissed && ClassPay.countsTowardDay(kind)) facts.identity,
    };
    bool covers(List<KeptClass> list) =>
        keys.isNotEmpty &&
        keys.every((key) => list.any((item) => item.answersTo(key)));
    final dayComplete = covers(classes);
    // The dismissals that stand once this keep is in: a keep on a set-aside
    // class lifts that one.
    final standing = wasDismissed
        ? [
            for (final item in before.dismissed)
              if (!item.sameClassAs(
                occurrenceKey: facts.occurrenceKey,
                courseCode: code,
                startMinute: facts.startMinute,
              ))
                item,
          ]
        : before.dismissed;
    // The full-day bonus is for a day of every counting class kept. A day on
    // which any counting class was set aside has no such day, whatever order
    // the keeps and the dismissals came in; an optional meeting set aside
    // (office hours) never matters to it.
    final setAsideCounting = standing.any((item) => !item.optional);
    final bonus =
        dayComplete &&
            !setAsideCounting &&
            !covers(before.classes) &&
            before.fullDayBonusXp == 0
        ? ClassPay.fullDayBonusXp
        : 0;
    _putDayRecord(
      before.copyWith(
        classes: classes,
        fullDayBonusXp: before.fullDayBonusXp + bonus,
        dismissed: wasDismissed ? standing : null,
      ),
    );

    final award = pay.xp + bonus;
    final glimmers = ClassPay.glimmersFor(award);
    final xpBefore = xp;
    xp += award;
    totalXp += award;
    embers += glimmers;
    final beforeRank = rankFor(pay.stat, stats[pay.stat] ?? 0);
    stats[pay.stat] = (stats[pay.stat] ?? 0) + pay.statGain;
    final afterRank = rankFor(pay.stat, stats[pay.stat]!);
    StatRank? rankedUpTo;
    if (afterRank.tier > beforeRank.tier) {
      _rankedUpQ.add((pay.stat, afterRank));
      rankedUpTo = afterRank;
    }
    ledger.insert(
      0,
      LedgerEntry(stat: pay.stat, amount: pay.statGain, title: kept.label),
    );
    if (ledger.length > 8) ledger.removeLast();
    totalClassesKept++;
    if (_keptClassCounts.containsKey(code) ||
        _keptClassCounts.length < _maxCourseCounters) {
      _keptClassCounts[code] = (_keptClassCounts[code] ?? 0) + 1;
    }

    var streak = ClassStreakEffect.none;
    if (ClassDayRules.current.classDayLightsStreak) {
      streak = _lightStreakForClass(facts.dayKey);
    }
    _rewardSerial++;

    var projected = level;
    var remaining = xp;
    while (remaining >= xpNeeded(projected + 1)) {
      remaining -= xpNeeded(projected + 1);
      projected++;
    }
    final unlocked = checkAchievements();
    notifyListeners();
    return ClassCredit(
      kept: kept,
      dayKey: facts.dayKey,
      xp: award,
      classXp: pay.xp,
      fullDayBonus: bonus,
      stat: pay.stat,
      statGain: pay.statGain,
      rankedUpTo: rankedUpTo,
      glimmers: glimmers,
      courseCount: keptCountForCourse(code),
      totalClassesKept: totalClassesKept,
      dayComplete: dayComplete,
      keptToday: classes.length,
      dayClassCount: keys.length,
      level: ClassLevelProjection(
        level: level,
        xpBefore: xpBefore,
        xpAfter: xp,
        xpForNextLevel: xpNeeded(level + 1),
        projectedLevel: projected,
      ),
      streak: streak,
      achievements: unlocked,
    );
  }

  /// Rule A: a kept class lights its day. A mark for a day older than the
  /// last streak day recounts the days after it ([_relightEarlierDay]).
  ClassStreakEffect _lightStreakForClass(String dayKey) {
    final last = lastStreakDay;
    if (last != null && dayKey.compareTo(last) < 0) {
      return _relightEarlierDay(dayKey);
    }
    final step = _advanceStreakDay(dayKey, fromClass: true);
    if (!step.advanced) return ClassStreakEffect.none;
    if (step.restarted) comebackPendingDay = dayKey;
    final milestone = step.milestone;
    return ClassStreakEffect(
      lit: true,
      streakDays: streakDays,
      freezesUsed: step.freezesUsed,
      restDaysPassed: step.restDaysPassed,
      restarted: step.restarted,
      freezeEarned: step.freezeEarned,
      milestone: milestone,
      milestoneGlimmers: milestone == null ? 0 : streakMilestones[milestone]!,
    );
  }

  /// Rule A, a late mark: [dayKey] is older than the last streak day (a
  /// Quest after midnight lit the next calendar day first, or a queued mark
  /// was replayed after a later day lit). The remembered advances after it
  /// run again in day order from the streak just before the first of them,
  /// as if the mark had come on time, so the order of a Quest and a class
  /// mark does not change the streak.
  ///
  /// The recount is kept only when it leaves the streak longer, or as long
  /// with at least as many freezes: a mark never takes a streak day or a
  /// freeze away. Otherwise (and when the remembered days cannot place this
  /// one) the live streak stands, and a freeze that held the day comes back.
  ClassStreakEffect _relightEarlierDay(String dayKey) {
    final steps = _streakSteps;
    final from = steps.indexWhere((step) => step.dayKey.compareTo(dayKey) >= 0);
    if (from < 0 || steps.last.dayKey != lastStreakDay) {
      return _returnHeldFreeze(dayKey);
    }
    final first = steps[from];
    final before = first.lastBefore;
    if (first.dayKey == dayKey || before == dayKey) {
      return ClassStreakEffect.none; // already a streak day
    }
    if (before != null && before.compareTo(dayKey) > 0) {
      return _returnHeldFreeze(dayKey);
    }
    final replaced = steps.sublist(from);
    final wasHeld = frozenStreakDays.contains(dayKey);
    final live = (
      streak: streakDays,
      freezes: streakFreezes,
      progress: streakFreezeProgress,
      held: {...frozenStreakDays},
    );

    // Rewind to just before the first advance after this day.
    streakDays = first.streakBefore;
    streakFreezes = first.freezesBefore;
    streakFreezeProgress = first.progressBefore;
    for (final step in replaced) {
      frozenStreakDays.removeAll(step.held);
    }
    final rerun = _StreakRerun(before);
    var best = 0;
    var restarts = 0;
    final lateStep = _advanceStreakDay(dayKey, fromClass: true, rerun: rerun);
    if (lateStep.restarted) restarts++;
    best = max(best, streakDays);
    for (var i = 0; i < replaced.length; i++) {
      final original = replaced[i];
      if (i > 0) {
        // Freezes that arrived from elsewhere between the two advances (the
        // level-6 gift, a returned freeze) stay where they arrived.
        streakFreezes =
            (streakFreezes +
                    original.freezesBefore -
                    replaced[i - 1].freezesAfter)
                .clamp(0, streakFreezeCapacity);
      }
      final step = _advanceStreakDay(
        original.dayKey,
        fromClass: !original.quest,
        rerun: rerun,
      );
      if (step.restarted) restarts++;
      best = max(best, streakDays);
    }
    streakFreezes = (streakFreezes + live.freezes - replaced.last.freezesAfter)
        .clamp(0, streakFreezeCapacity);

    final better =
        streakDays > live.streak ||
        (streakDays == live.streak && streakFreezes >= live.freezes);
    if (!better) {
      streakDays = live.streak;
      streakFreezes = live.freezes;
      streakFreezeProgress = live.progress;
      frozenStreakDays
        ..clear()
        ..addAll(live.held);
      return _returnHeldFreeze(dayKey);
    }

    _lastStreakDay = rerun.last;
    if (best > bestStreak) bestStreak = best;
    final restartsBefore = replaced.where((step) => step.restarted).length;
    comebacks = max(0, comebacks - restartsBefore + restarts);
    // A chest the original order already paid is never paid twice.
    final paid = {for (final step in replaced) ?step.milestone};
    int? milestone;
    var chests = 0;
    for (final step in rerun.steps) {
      final crossed = step.milestone;
      if (crossed != null && paid.add(crossed)) {
        _streakMilestoneQ.add(crossed);
        embers += streakMilestones[crossed]!;
        chests += streakMilestones[crossed]!;
        milestone ??= crossed;
      }
    }
    // A welcome-back waits only on a class day that still began the streak
    // again; one the original order left was either used or never owed.
    final newest = rerun.steps.last;
    if (newest.quest || !newest.restarted) {
      comebackPendingDay = null;
    } else if (!replaced.last.restarted) {
      comebackPendingDay = newest.dayKey;
    }
    steps
      ..removeRange(from, steps.length)
      ..addAll(rerun.steps);
    return ClassStreakEffect(
      lit: true,
      relit: true,
      streakDays: streakDays,
      freezesUsed: max(0, live.freezes - streakFreezes),
      restDaysPassed: lateStep.restDaysPassed,
      freezeEarned: streakFreezes > live.freezes + (wasHeld ? 1 : 0),
      freezeReturned: wasHeld,
      milestone: milestone,
      milestoneGlimmers: chests,
    );
  }

  /// The fallback for a late mark the remembered days cannot recount: a day
  /// a freeze held turned out to be lived, so that freeze comes back.
  ClassStreakEffect _returnHeldFreeze(String dayKey) {
    if (!frozenStreakDays.remove(dayKey)) return ClassStreakEffect.none;
    streakFreezes = min(streakFreezeCapacity, streakFreezes + 1);
    return ClassStreakEffect(streakDays: streakDays, freezeReturned: true);
  }

  /// Keeps the last few advances, enough for a queued mark from
  /// [classKeepRecentNights] nights back (with a day to spare for a phone
  /// in another zone than its timetable).
  void _rememberStreakStep(_StreakStep step) {
    _streakSteps.add(step);
    final night = Days.nightDate(Clock.now());
    final oldest = Days.key(
      DateTime(night.year, night.month, night.day - classKeepRecentNights - 2),
    );
    _streakSteps.removeWhere((kept) => kept.dayKey.compareTo(oldest) < 0);
    if (_streakSteps.length > _maxStreakSteps) {
      _streakSteps.removeRange(0, _streakSteps.length - _maxStreakSteps);
    }
  }

  static const _maxStreakSteps = 8;

  /// The last few streak advances, oldest first (see [_StreakStep]).
  final List<_StreakStep> _streakSteps = [];

  /// One optional acknowledgement for real effort that was not planned as a
  /// Quest. It is separate so it cannot fabricate Quest-only progression.
  static const int extraCreditXp = ExtraCreditEntry.awardXp;

  List<ExtraCreditEntry> get extraCreditEntries => [
    for (final record in _dayRecords) ?record.extraCredit,
  ];

  ExtraCreditEntry? extraCreditForDay(String dayKey) =>
      dayRecordFor(dayKey)?.extraCredit;

  List<String> extraCreditTitlesForDay(String dayKey) => [
    ?dayRecordFor(dayKey)?.extraCredit?.title,
  ];

  int extraCreditXpForDay(String dayKey) =>
      dayRecordFor(dayKey)?.extraCredit?.xp ?? 0;

  /// The captured day key must still be the active night-owned day. A stale
  /// editor therefore expires instead of silently crediting tomorrow.
  ExtraCreditEntry? addExtraCredit(String title, {required String dayKey}) {
    final cleaned = ExtraCreditEntry.cleanTitle(title);
    if (cleaned == null || dayKey != Days.nightKey(Clock.now())) return null;
    if (extraCreditForDay(dayKey) != null) return null;
    final entry = ExtraCreditEntry(
      dayKey: dayKey,
      title: cleaned,
      xp: extraCreditXp,
      createdAt: Clock.now().toUtc(),
    );
    final record = dayRecordFor(dayKey) ?? DayRecord(dayKey: dayKey);
    _putDayRecord(record.copyWith(extraCredit: entry));
    // Intentionally only XP: no stats, Glimmers, streak, history, perfect
    // day, Quest, goal, loot, mastery, or level-up mutation belongs here.
    xp += entry.xp;
    totalXp += entry.xp;
    _rewardSerial++;
    notifyListeners();
    return entry;
  }

  /// Editing preserves the original award and day; it can never award twice.
  /// A real change of wording bumps [rewardSerial], so an armed whole-save
  /// undo settles instead of quietly putting the old words back.
  bool updateExtraCredit(String dayKey, String title) {
    final cleaned = ExtraCreditEntry.cleanTitle(title);
    if (cleaned == null || dayKey != Days.nightKey(Clock.now())) {
      return false;
    }
    final record = dayRecordFor(dayKey);
    final entry = record?.extraCredit;
    if (record == null || entry == null) return false;
    if (entry.title == cleaned) return true;
    _putDayRecord(record.copyWith(extraCredit: entry.copyWith(title: cleaned)));
    _rewardSerial++;
    notifyListeners();
    return true;
  }

  /// Replaces (or adds) the record for its day, keeps day order, and trims to
  /// the horizon without ever evicting the active night or this record.
  /// Puts [record] back for its day, or removes the day's record when nothing
  /// is left in it, so taking back the only thing a day held leaves the save
  /// exactly as it was before.
  void _replaceDayRecord(DayRecord record) {
    if (record.isEmpty) {
      _dayRecords.removeWhere((r) => r.dayKey == record.dayKey);
    } else {
      _putDayRecord(record);
    }
  }

  void _putDayRecord(DayRecord record) {
    final index = _dayRecords.indexWhere((r) => r.dayKey == record.dayKey);
    if (index >= 0) {
      _dayRecords[index] = record;
    } else {
      _dayRecords
        ..add(record)
        ..sort((a, b) => a.dayKey.compareTo(b.dayKey));
    }
    _trimDayRecords(retain: {Days.nightKey(Clock.now()), record.dayKey});
  }

  /// Trim by day key: keep the newest [dayRecordHorizon] days, plus any
  /// retained day (the active night, the record just written) older than
  /// those. [_dayRecords] is kept in day order.
  void _trimDayRecords({required Set<String> retain}) {
    if (_dayRecords.length <= dayRecordHorizon) return;
    final newest = {
      for (final record in _dayRecords.skip(
        _dayRecords.length - dayRecordHorizon,
      ))
        record.dayKey,
    };
    _dayRecords.removeWhere(
      (record) =>
          !newest.contains(record.dayKey) && !retain.contains(record.dayKey),
    );
  }

  /// One rollover-deep snapshot keeps a just-finished day available to the
  /// 00:00–03:59 wind-down. Without it, midnight erased the very haul the
  /// closing ledger was meant to reflect.
  String? previousDayKey;
  int previousDayXp = 0;
  final Map<Stat, int> previousDayStats = {};
  final List<String> previousDayQuestTitles = [];
  EnergyWeather? previousDayEnergy;

  // ── routine day-stamps ──────────────────────────────────────────
  String? nightDoneDay;
  String? morningDoneDay;

  /// A morning briefing is "armed" the moment you close out a night, and
  /// disarmed once you've seen it — sleep-cycle based, not calendar based, so
  /// a 3am wind-down still earns a morning a few hours later (user report).
  bool morningArmed = false;

  /// Wall-clock ms the night routine was closed (drives the wake-up gap).
  int nightDoneAt = 0;

  /// IDs point into [journal]; the writing itself has one source of truth.
  String? nightDraftNoteId;
  String? pendingMorningNoteId;

  /// Minimum gap before the morning AUTO-shows — long enough that closing the
  /// night at 3am doesn't instantly re-pop, but short enough to greet you when
  /// you wake a few hours later the same calendar day.
  static const _morningGapMs = 4 * 60 * 60 * 1000;

  /// Night-key the person chose to reopen after closing the day — "I'm not
  /// done yet". Null, or a different night, means a closed night rests.
  String? restLiftedNight;

  /// Closing the night arms tomorrow morning's briefing.
  void closeNight() {
    final now = Clock.now();
    nightDoneDay = Days.nightKey(now);
    nightDoneAt = now.millisecondsSinceEpoch;
    morningArmed = true;
    // Closing the day again (after an "I'm not done yet" reopen) rests the
    // board again — the ritual owns the state, not the exception.
    restLiftedNight = null;
    // Rest Earned is caused here, not on the quest board. Check immediately
    // so the trophy and any gated reward do not wait for another completion.
    if (checkAchievements().isEmpty) notifyListeners();
  }

  /// Seeing the morning briefing disarms it.
  void closeMorning() {
    morningDoneDay = Days.key(Clock.now());
    morningArmed = false;
    pendingMorningNoteId = null;
    notifyListeners();
  }

  /// The board rests once tonight's ledger is written: the night you closed
  /// is the night you're still inside, the morning hasn't opened a new day,
  /// and you haven't chosen to reopen. Crossing 4am ends the night, so the
  /// rest lifts on its own even before the morning greeting.
  bool get dayRestingNow =>
      morningArmed &&
      nightDoneDay == Days.nightKey(Clock.now()) &&
      restLiftedNight != nightDoneDay;

  /// "I'm not done yet" — reopen tonight's board without disturbing the
  /// armed morning briefing. Closing the night again rests it again.
  void liftRest() {
    restLiftedNight = nightDoneDay;
    notifyListeners();
  }

  /// Day-key the "Today's Spark" greeting was dismissed — so the cold-open
  /// delight shows once per day, never nags (RESEARCH §3 / scout pick #1).
  String? sparkSeenDay;

  /// Monday-key of the week whose "last week" recap has been seen — the weekly
  /// temporal-landmark card shows once per new week, never nags (round-37).
  String? weekRecapSeenWeek;

  int _weekTotal(int weeksAgo) {
    final start = Days.weekStart(
      Clock.now(),
    ).subtract(Duration(days: 7 * weeksAgo));
    var total = 0;
    for (var i = 0; i < 7; i++) {
      total += history[Days.key(start.add(Duration(days: i)))] ?? 0;
    }
    return total;
  }

  int _weekLitDays(int weeksAgo) {
    final start = Days.weekStart(
      Clock.now(),
    ).subtract(Duration(days: 7 * weeksAgo));
    var lit = 0;
    for (var i = 0; i < 7; i++) {
      if ((history[Days.key(start.add(Duration(days: i)))] ?? 0) > 0) lit++;
    }
    return lit;
  }

  /// True on the first open of a new week, once last week had any activity to
  /// look back on (and it hasn't been dismissed yet).
  bool get weekRecapDue {
    final wk = Days.key(Days.weekStart(Clock.now()));
    return weekRecapSeenWeek != wk && _weekTotal(1) > 0;
  }

  /// Last week's shape: active days (of 7), total completions, and the change vs
  /// the week before.
  ({int litDays, int total, int delta}) weeklyRecap() => (
    litDays: _weekLitDays(1),
    total: _weekTotal(1),
    delta: _weekTotal(1) - _weekTotal(2),
  );

  void dismissWeekRecap() {
    weekRecapSeenWeek = Days.key(Days.weekStart(Clock.now()));
    notifyListeners();
  }

  /// Day-key the "Today's Bonus" offer was acted on/dismissed — so the daily
  /// bonus shows once per day, never nags.
  String? emberSeenDay;
  bool get emberDue => emberSeenDay != Days.key(Clock.now());
  void dismissEmber() {
    emberSeenDay = Days.key(Clock.now());
    notifyListeners();
  }

  /// Morning briefing AUTO-shows once a night is armed AND enough time has
  /// passed since you wound down that you've plausibly slept — so a 3am night
  /// still earns a morning when you wake, and closing the night at 3am doesn't
  /// instantly re-pop it. (nightDoneAt == 0 → an older save, gap assumed met.)
  bool get morningPending =>
      morningArmed &&
      (nightDoneAt == 0 ||
          Clock.now().millisecondsSinceEpoch - nightDoneAt >= _morningGapMs);

  /// The briefing is REACHABLE (a visible button/prompt) the whole time it's
  /// armed — so even before the gap, or after a missed auto-show, there's a
  /// way in.
  bool get morningAvailable => morningArmed;

  /// Your strongest trained stat — colors the portrait's aura. Null until
  /// something is trained.
  Stat? get dominantStat {
    Stat? best;
    var bestV = 0;
    for (final e in stats.entries) {
      if (e.value > bestV) {
        bestV = e.value;
        best = e.key;
      }
    }
    return best;
  }

  /// Your build's name — top two stats, silly but earnest; gains a rank
  /// epithet as your top stat climbs (scout pick #5).
  String get buildTitle => BuildTitles.epithetOf(stats);

  /// The dominant stat IF it's reached a real rank (tier ≥ 3) — drives the
  /// portrait's build-trait flourish. Null otherwise (room to grow, no flair).
  Stat? get portraitTrait {
    final s = dominantStat;
    if (s == null) return null;
    return rankFor(s, stats[s] ?? 0).tier >= 3 ? s : null;
  }

  /// Unlock ladder: level → unlock name. Every level-up reveals the next
  /// system or cosmetic tier, so there's always a visible "next thing"
  /// (RESEARCH-momentum.md §7). Levels 2-6 are core systems; 8-15 are
  /// cosmetic and quality-of-life expansions that keep the ladder alive
  /// past the initial onboarding burst.
  static const unlocks = <int, String>{
    2: 'STAT DETAILS',
    3: 'CHARACTER SHEET',
    4: 'EVIDENCE ARCHIVE',
    5: 'THEMES',
    6: 'WEEK-LONG FREEZE RESERVE',
    8: 'TODAY’S BONUS',
    12: 'WINDOW VIEWS',
    14: 'ROOM STYLES+',
    15: 'GILDED SKIN',
  };

  /// Rising XP-per-level curve; level 2 lands in the first session.
  int xpNeeded(int forLevel) => 60 + (forLevel - 1) * 45;

  String? nextUnlockLabel() {
    final next = unlocks.keys
        .where((l) => l > level)
        .fold<int?>(null, (a, b) => a == null || b < a ? b : a);
    return next == null ? null : 'Lv $next · ${unlocks[next]}';
  }

  /// Always-present forward carrot for the HUD: the next feature unlock while
  /// any remain, otherwise the nearest stat rank-up — so there's never a
  /// "nothing left to chase" gap past level 6 (RESEARCH-momentum.md §7).
  String? nextChaseLabel() {
    final unlock = nextUnlockLabel();
    if (unlock != null) return unlock;
    // nearest stat rank-up across all six stats
    String? best;
    var bestGap = 1 << 30;
    for (final s in Stat.values) {
      final v = stats[s] ?? 0;
      final gap = toNextTier(v);
      if (gap != null && gap < bestGap) {
        bestGap = gap;
        best = '+$gap ${s.abbr} → ${rankFor(s, v + gap).label}';
      }
    }
    return best;
  }

  /// Streak multiplier for an arbitrary day count — ramps 1.0 → 1.5 over 7
  /// days, caps at 2.0 (day 30).
  double streakMultFor(int days) {
    if (days <= 0) return 1.0;
    if (days <= 7) return 1.0 + 0.5 * days / 7;
    return min(2.0, 1.5 + 0.5 * (days - 7) / 23);
  }

  double get streakMult => streakMultFor(streakDays);

  /// How this completion sits against the streak: is there a gap since the
  /// last active day, which quiet dates sit inside it, and can freezes bridge
  /// every one? Partial coverage is deliberately refused so no freeze is ever
  /// spent without preserving the streak.
  /// Read identically by [roll] (for messaging) and [commit] (to apply) —
  /// both run before lastCompletionDay is bumped, so they agree.
  ({bool gap, List<String> days, bool covered}) _streakSituation() {
    final sit = _streakSituationFor(Days.key(Clock.now()));
    return (gap: sit.gap, days: sit.days, covered: sit.covered);
  }

  /// The gap between the last streak day and [dayKey]. With
  /// [ClassDayRules.restDaysPause], rest days inside it are passed over: they
  /// neither count as quiet days nor need a freeze.
  ({bool gap, List<String> days, List<String> restDays, bool covered})
  _streakSituationFor(String dayKey, {({String? day})? from}) {
    const none = (
      gap: false,
      days: <String>[],
      restDays: <String>[],
      covered: false,
    );
    final last = from == null ? lastStreakDay : from.day;
    if (last == null || last == dayKey) return none;
    final d = Days.tryParse(last);
    final target = Days.tryParse(dayKey);
    if (d == null || target == null) return none;
    final quietDays = Days.between(d, target) - 1;
    if (quietDays <= 0) return none;
    final resolver = ClassDayRules.current.restDaysPause
        ? restDayResolver
        : null;
    final days = <String>[];
    final restDays = <String>[];
    for (var i = 1; i <= quietDays; i++) {
      final key = Days.key(DateTime(d.year, d.month, d.day + i));
      if (resolver != null && _isRestDay(resolver, key)) {
        restDays.add(key);
      } else {
        days.add(key);
      }
    }
    if (days.isEmpty) {
      return (gap: false, days: days, restDays: restDays, covered: false);
    }
    return (
      gap: true,
      days: days,
      restDays: restDays,
      covered: streakFreezes >= days.length,
    );
  }

  static bool _isRestDay(bool Function(String) resolver, String dayKey) {
    try {
      return resolver(dayKey);
    } catch (_) {
      return false;
    }
  }

  /// Advances the streak for [dayKey], once. Quest commits and (with
  /// [ClassDayRules.classDayLightsStreak]) class keeps share this one block,
  /// so milestone chests and freeze cadence follow streak days whichever
  /// lit them. A Quest passes the freeze numbers its receipt already showed.
  ///
  /// Every advance is remembered for a few nights ([_streakSteps]). With
  /// [rerun], this is one advance of a late mark's recount: it reads and
  /// moves the recount's own last day, records into it, and leaves chests,
  /// comebacks and the best streak to [_relightEarlierDay].
  ({
    bool advanced,
    int freezesUsed,
    int restDaysPassed,
    bool restarted,
    bool freezeEarned,
    int? milestone,
  })
  _advanceStreakDay(
    String dayKey, {
    bool fromClass = false,
    int? freezeBalanceAfter,
    int? freezeProgressAfter,
    int? freezeCadenceAfter,
    _StreakRerun? rerun,
  }) {
    final last = rerun == null ? lastStreakDay : rerun.last;
    // A Quest advances on any new calendar day (unchanged behavior, even on a
    // backward clock). A class mark may arrive for a recent past day, so it
    // advances only a day after the last streak day.
    final advances = fromClass
        ? last == null || dayKey.compareTo(last) > 0
        : last != dayKey;
    if (!advances) {
      return (
        advanced: false,
        freezesUsed: 0,
        restDaysPassed: 0,
        restarted: false,
        freezeEarned: false,
        milestone: null,
      );
    }
    // A Quest on a backward clock: the remembered day order no longer holds,
    // so no late mark may recount across it.
    if (rerun == null && last != null && dayKey.compareTo(last) < 0) {
      _streakSteps.clear();
    }
    final sit = _streakSituationFor(dayKey, from: (day: last));
    final streakBefore = streakDays;
    final freezesBefore = streakFreezes;
    final progressBefore = streakFreezeProgress;
    var freezesUsed = 0;
    var restarted = false;
    if (!sit.gap) {
      streakDays += 1; // first ever, yesterday, or only rest days between
    } else if (sit.covered) {
      streakFreezes -= sit.days.length;
      frozenStreakDays.addAll(sit.days);
      freezesUsed = sit.days.length;
      streakDays += 1;
    } else {
      // a real lapse — reset, but the return is celebrated
      if (rerun == null) comebacks++;
      streakDays = 1;
      restarted = true;
    }
    if (rerun == null) {
      _lastStreakDay = dayKey;
    } else {
      rerun.last = dayKey;
    }
    // Showing up replenishes freezes without asking for a perfect board.
    // Progress can sit one day from ready while the reserve is full; if a
    // later completion spends a freeze, that same active day may refill it.
    bool freezeEarned;
    if (freezeBalanceAfter != null) {
      freezeEarned = freezeBalanceAfter > streakFreezes;
      streakFreezes = freezeBalanceAfter;
      final cadence = freezeCadenceAfter ?? activeDaysPerFreeze;
      streakFreezeProgress = min(
        cadence - 1,
        freezeProgressAfter ?? streakFreezeProgress,
      );
    } else {
      final cadence = activeDaysPerFreeze;
      freezeEarned =
          streakFreezes < streakFreezeCapacity &&
          streakFreezeProgress + 1 >= cadence;
      streakFreezes = min(
        streakFreezeCapacity,
        streakFreezes + (freezeEarned ? 1 : 0),
      );
      streakFreezeProgress = freezeEarned
          ? 0
          : min(cadence - 1, streakFreezeProgress + 1);
    }
    // streak milestone — a 7/30/100 day CROSSING queues a chest. This lives
    // INSIDE the once-per-day advance on purpose: a milestone can only be
    // crossed when the streak increments, so the second+ completion of a
    // milestone day must NOT re-pay the chest (day 30 × 6 quests once paid
    // 1,200 embers and staged the takeover six times — the exact currency
    // inflation the shop economy can't take).
    int? milestone;
    if (streakMilestones.containsKey(streakDays)) {
      milestone = streakDays;
      if (rerun == null) {
        _streakMilestoneQ.add(streakDays);
        embers += streakMilestones[streakDays]!;
      }
    }
    final step = _StreakStep(
      dayKey: dayKey,
      quest: !fromClass,
      lastBefore: last,
      streakBefore: streakBefore,
      freezesBefore: freezesBefore,
      progressBefore: progressBefore,
      freezesAfter: streakFreezes,
      held: freezesUsed > 0 ? List.unmodifiable(sit.days) : const [],
      restarted: restarted,
      milestone: milestone,
    );
    if (rerun == null) {
      if (streakDays > bestStreak) bestStreak = streakDays;
      _rememberStreakStep(step);
    } else {
      rerun.steps.add(step);
    }
    return (
      advanced: true,
      freezesUsed: freezesUsed,
      restDaysPassed: sit.restDays.length,
      restarted: restarted,
      freezeEarned: freezeEarned,
      milestone: milestone,
    );
  }

  /// Verified completions (timer proof) pay ×1.2 — proof multiplies,
  /// never gates (RESEARCH.md §5).
  static const verifiedBonus = 1.2;

  /// Custom (user-forged) quests pay ×0.85 — anti-abuse damping; honesty
  /// keeps the magic (DESIGN.md round-3).
  static const customDamp = 0.85;

  /// First completion back after a gap pays ×1.5 — the fragile
  /// re-engagement moment is rewarded, never scolded (RESEARCH-momentum.md §4).
  static const comebackBonus = 1.5;

  /// Soft daily XP ceilings (ROADMAP Phase 1 anti-grind). Past the first
  /// threshold further XP is halved; past the second, quartered. Effort is
  /// never discarded — just gently soft-capped.
  static const dailyXpSoft = 250;
  static const dailyXpHard = 400;

  /// Same-task same-day repeat decay: 100% → 50% → 25% → 10% (ROADMAP §1).
  static double sameDayDecay(int priorSameTitleToday) =>
      switch (priorSameTitleToday) {
        0 => 1.0,
        1 => 0.5,
        2 => 0.25,
        _ => 0.1,
      };

  /// Per-stat daily soft-cap: after this much of one stat today, further
  /// gains to that stat are halved (anti-farm; still never zeroed).
  static const dailyStatSoft = 40;

  /// Base crit chance; STR bends this upward (DESIGN.md §4).
  double get critChance =>
      (0.03 + (stats[Stat.str]! / 200) * 0.05).clamp(0.03, 0.10);

  /// INT bends XP rate — up to +15% at high Intellect.
  double get intXpMult =>
      (1.0 + (stats[Stat.intl]! / 200) * 0.15).clamp(1.0, 1.15);

  /// FOC bends loot drop chance — up to +8% absolute.
  double get focLootBonus => ((stats[Stat.foc]! / 200) * 0.08).clamp(0.0, 0.08);

  /// FOC also raises the daily drop cap (base 5).
  int get dailyLootCap => 5 + ((stats[Stat.foc]! / 50).floor().clamp(0, 3));

  /// DIS amplifies neglect bonus (dreaded / long-idle tasks pay more).
  double get disNeglectMult =>
      (1.0 + (stats[Stat.dis]! / 200) * 0.25).clamp(1.0, 1.25);

  /// How many days since this quest was last cleared (0 if never / today).
  int _neglectDays(Quest q, String nowKey) {
    final last = q.lastDoneDay;
    if (last == null || last == nowKey) return 0;
    final d = Days.parse(last);
    final now = Days.parse(nowKey);
    return Days.between(d, now).clamp(0, 30);
  }

  /// Neglect payout: up to +50% after ~10 idle days, scaled by DIS.
  double _neglectMult(Quest q, String nowKey) {
    final days = _neglectDays(q, nowKey);
    if (days <= 0) return 1.0;
    final raw = 1.0 + min(0.5, days * 0.05);
    return 1.0 + (raw - 1.0) * disNeglectMult;
  }

  /// Today's soft-cap multiplier given XP already banked today.
  double _dailyXpMult() {
    if (todayXp >= dailyXpHard) return 0.25;
    if (todayXp >= dailyXpSoft) return 0.5;
    return 1.0;
  }

  /// Day-one damp for a custom quest forged today (can't farm a fresh
  /// self-entered task for full XP on day one).
  double _dayOneDamp(Quest q, String nowKey) {
    if (!q.custom) return 1.0;
    final created = q.createdDay;
    if (created == null || created != nowKey) return 1.0;
    // first completion of a brand-new custom quest today
    if (q.lastDoneDay != null) return 1.0;
    return 0.5;
  }

  /// Loot drops earned today (for the daily cap). Cleared on rollover.
  int todayLootDrops = 0;

  /// Same-title completion counts today (anti-grind decay). Cleared on rollover.
  final Map<String, int> todayTitleCounts = {};

  /// Pure roll: computes the reward and marks the quest done for its
  /// period, but does NOT mutate xp/stats — [commit] does that later so the
  /// bar fill and chip pulses can be staged after the reward receipt.
  RewardBundle roll(Quest q, {bool verified = false, Quest? progressionQuest}) {
    final now = Clock.now();
    final nowKey = Days.key(now);
    // A threshold completion pays for and names the prescription the person
    // actually finished. Its authored ladder may rise only after that truth is
    // captured for the receipt and ledger.
    final completedTitle = q.displayTitle;
    final completedDifficulty = q.difficulty;
    // How a gap (if any) resolves: freezes bridge it quietly, otherwise
    // it's a true lapse and the return earns a warm comeback bonus. Read
    // before we stamp anything (mirrors [commit]'s decision).
    final sit = _streakSituation();
    final shieldHeld = sit.gap && sit.covered;
    // A class keep that already restarted the streak leaves the welcome-back
    // for this Quest, so the order of a comeback day never changes its pay.
    final isComeback =
        (sit.gap && !sit.covered) || (!sit.gap && _comebackPending);
    // the FIRST streak advance of the day (nothing has lit today yet)
    final firstOfDay = lastStreakDay != nowKey;
    final freezesUsed = shieldHeld ? sit.days.length : 0;
    final reserveAfterHeldDays = streakFreezes - freezesUsed;

    final priorSame = todayTitleCounts[q.title] ?? 0;
    final neglect = _neglectMult(q, nowKey);
    final dayOne = _dayOneDamp(q, nowKey);

    q.lastDoneDay = nowKey;

    // A comeback resets the streak to 1 in commit — pay this completion at the
    // POST-reset multiplier, not the stale lapsed streak (else a broken 30-day
    // streak pays ×2.0 stacked with the comeback bonus; bug-hunt §10).
    final effStreakMult = isComeback ? streakMultFor(1) : streakMult;
    // Base scales with continuous difficulty: d1 ≈ 0.6×, d10 ≈ 3×.
    final base = 10 * (0.5 + q.difficulty * 0.25);
    var earned = base * effStreakMult;
    if (q.dread) earned *= 1.35;
    if (q.custom) earned *= customDamp;
    if (verified) earned *= verifiedBonus;
    if (isComeback) earned *= comebackBonus;
    earned *= neglect;
    earned *= dayOne;
    earned *= sameDayDecay(priorSame);
    earned *= intXpMult;
    earned *= _dailyXpMult();

    // Critical hit: STR-bent chance, ×1.5–×3, always announced with the roll.
    double? crit;
    if (_rng.nextDouble() < critChance) {
      crit = 1.5 + _rng.nextDouble() * 1.5;
      earned *= crit;
    }

    // Loot: FOC-bent chance, daily cap, never re-drop owned skins.
    // Guaranteed first drop on the player's 2nd-ever completion (DESIGN §3).
    String? loot;
    final available = [
      for (final name in droppableLoot)
        if (!collectedLoot.contains(name)) name,
    ];
    final underCap = todayLootDrops < dailyLootCap;
    final guaranteeSecond = totalCompletions == 1 && available.isNotEmpty;
    if (underCap && available.isNotEmpty) {
      final chance = 0.18 + focLootBonus;
      if (guaranteeSecond || _rng.nextDouble() < chance) {
        loot = available[_rng.nextInt(available.length)];
      }
    }

    // anti-abuse damp covers stats too — they drive the aura/title/radar.
    // Per-stat daily soft-cap halves further gains past the threshold.
    var gain = q.difficulty * 1.5;
    if (q.custom) gain *= customDamp;
    gain *= dayOne;
    gain *= sameDayDecay(priorSame);
    if ((todayStats[q.stat] ?? 0) >= dailyStatSoft) gain *= 0.5;
    final projectedVit =
        stats[Stat.vit]! +
        (q.stat == Stat.vit ? max(1, gain.round() + (q.dread ? 3 : 0)) : 0);
    final freezeCadenceAfter = projectedVit >= 40 ? 2 : 3;
    final freezeEarnedAfterCommit =
        firstOfDay &&
        reserveAfterHeldDays < streakFreezeCapacity &&
        streakFreezeProgress + 1 >= freezeCadenceAfter;
    final finalFreezeBalance = min(
      streakFreezeCapacity,
      reserveAfterHeldDays + (freezeEarnedAfterCommit ? 1 : 0),
    );
    final freezeProgressAfter = freezeEarnedAfterCommit
        ? 0
        : min(freezeCadenceAfter - 1, streakFreezeProgress + 1);
    // Guided sessions reward a temporary routine Quest but build permanent
    // mastery on the launcher the person chose. Ordinary completions use q.
    final progress = (progressionQuest ?? q).recordCompletionProgress();

    return RewardBundle(
      xp: earned.round(),
      // embers track XP (~a third, min 1) — the one source for both the
      // receipt bubble and what commit() banks
      embers: max(1, earned.round() ~/ 3),
      stat: q.stat,
      statGain: max(1, gain.round() + (q.dread ? 3 : 0)),
      questTitle: completedTitle,
      message: RewardMessages.pick(
        q.stat,
        _rng,
        hour: now.hour,
        dread: q.dread,
        countToday: (history[nowKey] ?? 0) + 1,
        comeback: isComeback,
      ),
      difficulty: completedDifficulty,
      dread: q.dread,
      custom: q.custom,
      isEvent: q.isEvent,
      goalTitle: q.goalTitle,
      goalPlanStepId: q.goalPlanStepId,
      goalPlanRevision: q.goalPlanRevision,
      critMult: crit,
      // report the multiplier actually applied (post-reset on a comeback)
      streakMult: isComeback
          ? effStreakMult
          : (streakDays > 0 ? streakMult : null),
      verifiedMult: verified ? verifiedBonus : null,
      comebackMult: isComeback ? comebackBonus : null,
      freezesUsed: freezesUsed,
      freezeEarned: freezeEarnedAfterCommit,
      freezeBalanceAfter: finalFreezeBalance,
      freezeProgressAfter: freezeProgressAfter,
      freezeCadenceAfter: freezeCadenceAfter,
      firstOfDay: firstOfDay,
      loot: loot,
      hasEvidence:
          evidenceForStat(q.stat) != null &&
          !seenEvidence.contains(evidenceForStat(q.stat)!.title),
      questKey: q.title,
      masteryCompletionsAfter: progress.completionsAfter,
      masteryTierReached: progress.tierReached,
      risenToTitle: progress.risenToTitle,
    );
  }

  /// XP a quest will pay (sans crit luck) — shown on the card so the reward
  /// IS the difficulty signal (DESIGN.md §11.4). Advertises the BASE
  /// (honor) payout — the ×1.2 is the timer's upside, not a promise.
  int xpPreview(Quest q) {
    // mirror roll(): on a comeback day streakDays still holds the stale lapsed
    // value until the first commit resets it, so preview at the multiplier
    // roll() will ACTUALLY pay (post-reset) — never over-promise ×2.0 on the
    // exact fragile re-engagement day the card is trying to win back.
    final nowKey = Days.key(Clock.now());
    final sit = _streakSituation();
    final effMult = (sit.gap && !sit.covered) || (!sit.gap && _comebackPending)
        ? streakMultFor(1)
        : streakMult;
    final priorSame = todayTitleCounts[q.title] ?? 0;
    var earned = 10 * (0.5 + q.difficulty * 0.25) * effMult;
    if (q.dread) earned *= 1.35;
    if (q.custom) earned *= customDamp;
    earned *= _neglectMult(q, nowKey);
    earned *= _dayOneDamp(q, nowKey);
    earned *= sameDayDecay(priorSame);
    earned *= intXpMult;
    earned *= _dailyXpMult();
    return earned.round();
  }

  /// Applies a rolled bundle to xp/stats/streak/counters — the moment the
  /// bar fills and the stat chip pulses.
  void commit(RewardBundle b) {
    xp += b.xp;
    totalXp += b.xp;
    // bank the embers the roll computed (shown in the receipt) — the shop
    // currency for "Your Space"; every win nudges the balance up.
    embers += b.embers;
    // stat gain, watching for a rank-tier crossing (fires the evidence beat)
    final beforeRank = rankFor(b.stat, stats[b.stat]!);
    stats[b.stat] = stats[b.stat]! + b.statGain;
    final afterRank = rankFor(b.stat, stats[b.stat]!);
    if (afterRank.tier > beforeRank.tier) {
      _rankedUpQ.add((b.stat, afterRank));
    }
    ledger.insert(
      0,
      LedgerEntry(stat: b.stat, amount: b.statGain, title: b.questTitle),
    );
    if (ledger.length > 8) ledger.removeLast();

    // Streak: active days count upward; freezes hold calendar days away without
    // pretending those days were active. Full-save undo restores this whole
    // transaction, including reserve, progress, and the exact frozen dates.
    final now = Clock.now();
    final today = Days.key(now);
    // Once per streak day; a class keep may already have lit today.
    _advanceStreakDay(
      today,
      freezeBalanceAfter: b.freezeBalanceAfter,
      freezeProgressAfter: b.freezeProgressAfter,
      freezeCadenceAfter: b.freezeCadenceAfter,
    );
    // The Quest-only day marker moves after the shared streak advance.
    lastCompletionDay = today;
    // A Quest consumes a class-started welcome-back (or outlives it).
    comebackPendingDay = null;
    if (streakDays > bestStreak) bestStreak = streakDays;

    // time-of-day flair
    if (now.hour < 8) dawnCompletions++;
    if (now.hour >= 21) duskCompletions++;

    // a found cosmetic fragment is actually kept now (honest loot)
    if (b.loot != null) {
      collectedLoot.add(b.loot!);
      todayLootDrops++;
    }

    // counters + calendar history
    totalCompletions++;
    if (b.verifiedMult != null) verifiedCompletions++;
    if (b.dread) dreadCompletions++;
    if (b.difficulty >= 7) epicCompletions++;
    if (b.isEvent) eventCompletions++;
    if (b.custom) customCompletions++;
    history[today] = (history[today] ?? 0) + 1;
    // The week's training: one mark for the stat this Quest fed, counting 1.5
    // when the timer proved it (the same flag that pays the verified bonus).
    markTraining(
      b.stat,
      at: now,
      weight: b.verifiedMult != null ? timerProvenWeight : 1,
    );
    final titleKey = b.questKey ?? b.questTitle;
    todayTitleCounts[titleKey] = (todayTitleCounts[titleKey] ?? 0) + 1;

    // today's haul (night recap)
    todayXp += b.xp;
    todayStats[b.stat] = (todayStats[b.stat] ?? 0) + b.statGain;
    todayQuestTitles.add(b.questTitle);

    // goal progress: linked completions inch the bar toward full
    if (b.goalTitle != null) {
      for (final g in goals) {
        if (g.title.trim().toLowerCase() == b.goalTitle!.trim().toLowerCase() &&
            !g.complete) {
          // A goal's first proof is earned only by a real linked completion.
          // Creation, scheduling, reflections, and a later unlinked receipt
          // never get to claim this moment on the person's behalf.
          if (g.firstProofTitle == null || g.firstProofDay == null) {
            g.firstProofTitle = b.questTitle;
            g.firstProofDay = today;
          }
          final plan = g.plan;
          final stepId = b.goalPlanStepId;
          var routeAdvanced = false;
          var routeFinished = false;
          if (plan == null) {
            g.progress++;
          } else if (stepId != null && b.goalPlanRevision == plan.revision) {
            final stepIndex = plan.steps.indexWhere(
              (step) => step.id == stepId,
            );
            // Completing an action from later in the route is still honest
            // evidence, but it cannot silently skip the owned route order.
            if (stepIndex == plan.currentStepIndex &&
                !plan.steps[stepIndex].complete) {
              final step = plan.steps[stepIndex];
              final completions = step.completions + 1;
              final completed = completions >= step.requiredCompletions;
              final masteryCompletions =
                  b.masteryCompletionsAfter > step.masteryCompletions
                  ? b.masteryCompletionsAfter
                  : step.masteryCompletions;
              final updatedSteps = [...plan.steps];
              final routeMarker = step.resumeAfterRecovery;
              updatedSteps[stepIndex] = routeMarker != null && !completed
                  ? routeMarker.copyWith(
                      completions: completions,
                      masteryCompletions: masteryCompletions,
                      clearCompletedDay: true,
                      clearResumeAfterRecovery: true,
                    )
                  : step.copyWith(
                      completions: completions,
                      masteryCompletions: masteryCompletions,
                      completedDay: completed ? today : null,
                      clearResumeAfterRecovery: true,
                    );
              var updatedPlan = plan.copyWith(
                steps: updatedSteps,
                lastSignal: GoalPlanSignal.completed,
              );
              routeAdvanced = true;
              routeFinished = updatedPlan.complete;
              g.progress++;
              if (routeFinished && updatedPlan.type == GoalRouteType.routine) {
                updatedPlan = GoalPlanner.continueRoutine(updatedPlan);
                routeFinished = false;
              }
              g.plan = updatedPlan;
            }
          }
          if (plan != null &&
              routeAdvanced &&
              routeFinished &&
              plan.type != GoalRouteType.routine) {
            g.achievedDay = today;
            _achievedQ.add(g);
          } else if (plan == null && g.progress >= g.target) {
            if (g.kind == GoalKind.achieve) {
              // finish line crossed — celebrate, then it rests in honor
              g.achievedDay = today;
              _achievedQ.add(g);
            } else {
              // ongoing practice: milestone reached, the path continues
              _milestonedQ.add((g, g.target));
              g.target *= 2;
              g.milestones++;
            }
          }
          break;
        }
      }
    }
    // trim history to 180 days — never evict TODAY's just-written entry (guards
    // a backward clock / future-dated restore from deleting it; bug-hunt §14).
    // A while-loop, not a single removal: an oversized imported/legacy save
    // must drain to the cap in one commit, not one day per completion.
    if (history.length > 180) {
      final keys = (history.keys.toList()..sort())
          .where((k) => k != today)
          .toList();
      var i = 0;
      while (history.length > 180 && i < keys.length) {
        history.remove(keys[i++]);
      }
    }

    _rewardSerial++;
    notifyListeners();
  }

  /// Evaluates achievement conditions; returns the newly unlocked ones.
  /// Idempotent — call after commits and after level-ups.
  List<Achievement> checkAchievements() {
    final newly = <Achievement>[];
    for (final a in achievements) {
      if (!unlockedAchievements.contains(a.id) && a.test(this)) {
        unlockedAchievements.add(a.id);
        // a signature achievement hands you its exclusive legendary skin
        if (a.cosmetic != null) collectedLoot.add(a.cosmetic!);
        newly.add(a);
      }
    }
    if (newly.isNotEmpty) notifyListeners();
    return newly;
  }

  /// Consume XP into level-ups. Overflow always carries (no wasted
  /// progress). Returns the highest level reached this application, if any.
  /// Deliberately does NOT notify — the UI reveals the pour on its own
  /// schedule (DESIGN.md §6).
  LevelResult applyLevelUps() {
    int? reached;
    final from = level;
    while (xp >= xpNeeded(level + 1)) {
      xp -= xpNeeded(level + 1);
      level++;
      reached = level;
    }
    // Keep the old starter-piece flags for backup/share compatibility. The
    // current room system is complete from level one and does not render them.
    if (level >= 2) ownedFurniture.add('rug');
    if (level >= 3) ownedFurniture.add('plant');
    if (level >= 4) ownedFurniture.add('cushion');
    // Lv 6 widens the reserve to a full week and places two freezes inside it.
    if (level >= 6 && !freezeLevelBonusGranted) {
      freezeLevelBonusGranted = true;
      streakFreezes = (streakFreezes + 2).clamp(0, streakFreezeCapacity);
    }
    // the GILDED SKIN unlock (Lv 15) grants the gilded skin for free
    if (level >= 15 && !ownedSkins.contains('gilded')) {
      ownedSkins.add('gilded');
    }
    if (reached == null) {
      return LevelResult(leveledTo: null, unlock: null);
    }
    final since = completionsAtLastLevel == null
        ? null
        : totalCompletions - completionsAtLastLevel!;
    completionsAtLastLevel = totalCompletions;
    final classesSince = totalClassesKept - classesAtLastLevel;
    classesAtLastLevel = totalClassesKept;
    return LevelResult(
      leveledTo: reached,
      unlock: unlocks[reached],
      previousLevel: from,
      questsSince: since == null || since < 0 ? null : since,
      classesSince: classesSince < 0 ? 0 : classesSince,
    );
  }

  /// Day rollover: drops completed one-time quests from past days and
  /// stamps the active day. Recurring quests reset implicitly — their
  /// doneFor() recomputes against the new period. Returns true if the
  /// active day changed.
  bool rollover(List<Quest> quests) {
    final now = Clock.now();
    final today = Days.key(now);
    final changed = lastActiveDay != today;
    final startOfToday = DateTime(now.year, now.month, now.day);
    quests.removeWhere(
      (q) =>
          q.schedule == QuestSchedule.once &&
          q.lastDoneDay != null &&
          q.lastDoneDay != today,
    );
    // momentum bonuses are a today-only gift — an unfinished one quietly
    // expires at dawn rather than lingering as an "overdue" obligation.
    quests.removeWhere(
      (q) => q.bonus && q.dueDate != null && q.dueDate!.isBefore(startOfToday),
    );
    if (changed) {
      if (lastActiveDay != null) {
        previousDayKey = lastActiveDay;
        previousDayXp = todayXp;
        previousDayStats
          ..clear()
          ..addAll(todayStats);
        previousDayQuestTitles
          ..clear()
          ..addAll(todayQuestTitles);
        previousDayEnergy = energyWeatherDay == lastActiveDay
            ? energyWeather
            : null;
      }
      todayXp = 0;
      todayStats.clear();
      todayQuestTitles.clear();
      todayLootDrops = 0;
      todayTitleCounts.clear();
    }
    lastActiveDay = today;
    return changed;
  }

  /// A warm one-line recap of the day just cleared — which life domains you
  /// tended, reflected back so the peak-end is personal (round-32). Ranked by
  /// how much each domain got today.
  String todaysShape() {
    final worked = Stat.values.where((s) => (todayStats[s] ?? 0) > 0).toList()
      ..sort((a, b) => (todayStats[b] ?? 0).compareTo(todayStats[a] ?? 0));
    final n = todayQuestTitles.length;
    final plural = n == 1 ? 'quest' : 'quests';
    if (worked.isEmpty) return 'A day cleared — every small step counts.';
    if (worked.length == 1) {
      return 'You poured today into ${worked.first.label} — '
          '$n $plural, all in one direction.';
    }
    if (worked.length == 2) {
      return 'You tended ${worked[0].label} and ${worked[1].label} today — '
          '$n $plural, a balanced day.';
    }
    return 'You moved across ${worked.length} parts of your life today — '
        '$n $plural, a full and varied day.';
  }

  /// Adds a goal; refuses duplicate titles.
  bool addGoal(Goal g) {
    final key = g.title.trim().toLowerCase();
    if (goals.any((e) => e.title.trim().toLowerCase() == key)) return false;
    g.startedDay ??= Days.key(Clock.now()); // for "days on the journey"
    goals.add(g);
    // Pathmaker is earned by adding the third goal. Previously all achievement
    // checks lived on the quest screen, so this could look permanently broken.
    if (checkAchievements().isEmpty) notifyListeners();
    return true;
  }

  /// Updates the optional, user-authored support around a goal. These fields
  /// are deliberately editable and clearable: a reason or hard-day plan is a
  /// tool the person owns, never a pledge the app locks them into.
  void updateGoalSupport(
    Goal goal, {
    required String? why,
    required String? fallbackCue,
    required String? fallbackAction,
  }) {
    if (!goals.contains(goal)) return;
    goal.why = why;
    goal.fallbackCue = fallbackCue;
    goal.fallbackAction = fallbackAction;
    notifyListeners();
  }

  /// Replaces an owned route after creation or a no-guilt recalibration.
  /// Historical goal progress and proof stay untouched.
  void updateGoalPlan(Goal goal, GoalPlan plan) {
    if (!goals.contains(goal)) return;
    final previousPlan = goal.plan;
    final previousRouteProgress =
        previousPlan?.steps.fold<int>(
          0,
          (total, step) =>
              total + step.completions.clamp(0, step.requiredCompletions),
        ) ??
        0;
    final historicalProgress = (goal.progress - previousRouteProgress).clamp(
      0,
      goal.progress,
    );
    goal.plan = plan;
    goal.fallbackCue = plan.obstacleCue;
    goal.fallbackAction = plan.fallbackAction;
    if (plan.type != GoalRouteType.routine) {
      final routeTarget = plan.steps.fold(
        0,
        (total, step) => total + step.requiredCompletions,
      );
      final routeProgress = plan.steps.fold(
        0,
        (total, step) =>
            total + step.completions.clamp(0, step.requiredCompletions),
      );
      goal.target = historicalProgress + routeTarget;
      goal.progress = historicalProgress + routeProgress;
    }
    notifyListeners();
  }

  /// Completes the one-time opening only after the person accepts its exact
  /// first move. Leaving the opening early keeps it resumable.
  void completeGoalOpening(Goal goal) {
    if (!goals.contains(goal) || goal.openingSeen) return;
    goal.openingSeen = true;
    notifyListeners();
  }

  /// Abandons a goal. Caller also removes its linked quests.
  void removeGoal(Goal g) {
    goals.remove(g);
    notifyListeners();
  }

  /// Records a perfect day — every due quest cleared — at most once per day,
  /// and only if at least one quest was actually completed today.
  void recordPerfectDay() {
    final today = Days.key(Clock.now());
    if (lastPerfectDay == today || (history[today] ?? 0) < 1) return;
    lastPerfectDay = today;
    perfectDays++;
    notifyListeners();
  }

  // ── persistence ──────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'playerName': playerName,
    'onboarded': onboarded,
    'timeShape': timeShape,
    'focusMode': focusMode,
    'reduceMotion': reduceMotion,
    'soundEnabled': soundEnabled,
    'musicEnabled': musicEnabled,
    if (addClassesHidden) 'addClassesHidden': true,
    'textScale': textScale,
    'notifyEnabled': notifyEnabled,
    'notifyHour': notifyHour,
    'notifyMinute': notifyMinute,
    'nightReminderEnabled': nightReminderEnabled,
    'nightReminderHour': nightReminderHour,
    'nightReminderMinute': nightReminderMinute,
    'lastModified': lastModified,
    'level': level,
    'xp': xp,
    'totalXp': totalXp,
    'embers': embers,
    'ownedFurniture': ownedFurniture.toList(),
    'roomKeepsakes': roomKeepsakes.toList(),
    'ownedStyles': ownedStyles.toList(),
    'wallStyle': wallStyle,
    'floorStyle': floorStyle,
    'ownedSkins': ownedSkins.toList(),
    'creatureSkin': creatureSkin,
    'ownedWindows': ownedWindows.toList(),
    'windowScene': windowScene,
    'ownedScenes': ownedScenes.toList(),
    'stageScene': stageScene,
    'roomCode': roomCode,
    'roomDiscoverable': roomDiscoverable,
    'roomDiscoveryName': roomDiscoverable ? roomDiscoveryName : '',
    'roomDiscoveryRemovalCodes': _roomDiscoveryRemovalCodes.toList()..sort(),
    'hearthCircleCodes': hearthCircleCodes,
    'hearthCircleNames': {
      for (final code in hearthCircleCodes)
        if (hearthCircleNames[code]?.isNotEmpty == true)
          code: hearthCircleNames[code],
    },
    'hearthCircleOwnerKeys': {
      for (final code in hearthCircleCodes)
        if (isValidDiscoveryOwnerKey(hearthCircleOwnerKeys[code]))
          code: hearthCircleOwnerKeys[code],
    },
    'blockedRoomCodes': blockedRoomCodes.toList(),
    'blockedDiscoveryOwners': blockedDiscoveryOwners,
    'energyWeather': energyWeather.name,
    'energyWeatherDay': energyWeatherDay,
    'energyHistory': {
      for (final entry in energyHistory.entries) entry.key: entry.value.name,
    },
    'lowFlameQuestTitles': lowFlameQuestTitles,
    'memoryPins': memoryPins.toList(),
    'spaceIntro': spaceIntro,
    'featuredGoalTitles': featuredGoalTitles,
    'shareSpaceProfile': shareSpaceProfile,
    'spaceCardOrder': [for (final kind in spaceCardOrder) kind.name],
    'hiddenSpaceCards': [
      for (final kind in SpaceCardKind.values)
        if (hiddenSpaceCards.contains(kind)) kind.name,
    ],
    'spaceCardAudiences': {
      for (final kind in SpaceCardKind.values)
        kind.name: spaceAudienceFor(kind).name,
    },
    'spaceSeasonText': spaceSeasonText,
    if (spaceProfilePhotoNoteId != null)
      'spaceProfilePhotoNoteId': spaceProfilePhotoNoteId,
    if (spaceSeasonPhotoNoteId != null)
      'spaceSeasonPhotoNoteId': spaceSeasonPhotoNoteId,
    'shareSpaceProfilePhoto': shareSpaceProfilePhoto,
    'shareSpaceSeasonPhoto': shareSpaceSeasonPhoto,
    if (spaceProfilePhotoPath.isNotEmpty)
      'spaceProfilePhotoPath': spaceProfilePhotoPath,
    if (spaceSeasonPhotoPath.isNotEmpty)
      'spaceSeasonPhotoPath': spaceSeasonPhotoPath,
    'shareRoomPhoto': shareRoomPhoto,
    if (spaceRoomPhotoPath.isNotEmpty) ...{
      'spaceRoomPhotoPath': spaceRoomPhotoPath,
      'spaceRoomPhotoFill': spaceRoomPhotoFill,
      'spaceRoomPhotoX': spaceRoomPhotoX,
      'spaceRoomPhotoY': spaceRoomPhotoY,
      'spaceRoomPhotoWidth': spaceRoomPhotoWidth,
      'spaceRoomPhotoHeight': spaceRoomPhotoHeight,
    },
    'quietCompanyKind': quietCompanyKind,
    'quietCompanyUntil': quietCompanyUntil,
    'stats': [for (final s in Stat.values) stats[s] ?? 0],
    // per-domain notes, by Stat order (parallel to 'stats'); empty lists
    // for domains with nothing kept, so a restore maps cleanly by index.
    'domainNotes': [
      for (final s in Stat.values)
        [for (final n in domainNotes[s] ?? const []) n.toJson()],
    ],
    'journal': [for (final n in journal) n.toJson()],
    'ledger': [for (final e in ledger) e.toJson()],
    'streakDays': streakDays,
    'bestStreak': bestStreak,
    // Keep legacy keys stable so an existing cloud/local save keeps merging.
    'streakShields': streakFreezes,
    'shieldUnlockGranted': freezeLevelBonusGranted,
    'streakFreezeProgress': streakFreezeProgress,
    'streakFreezeVersion': streakFreezeVersion,
    'frozenStreakDays': frozenStreakDays.toList()..sort(),
    'lastCompletionDay': lastCompletionDay,
    if (lastStreakDay != null) 'lastStreakDay': lastStreakDay,
    if (comebackPendingDay != null) 'comebackPendingDay': comebackPendingDay,
    // The last few streak advances, so a late class mark can recount them.
    if (_streakSteps.isNotEmpty)
      'streakSteps': [for (final step in _streakSteps) step.toJson()],
    'lastActiveDay': lastActiveDay,
    'totalCompletions': totalCompletions,
    'completionsAtLastLevel': completionsAtLastLevel,
    'verifiedCompletions': verifiedCompletions,
    'dreadCompletions': dreadCompletions,
    'epicCompletions': epicCompletions,
    'eventCompletions': eventCompletions,
    'customCompletions': customCompletions,
    'comebacks': comebacks,
    'dawnCompletions': dawnCompletions,
    'duskCompletions': duskCompletions,
    'perfectDays': perfectDays,
    'lastPerfectDay': lastPerfectDay,
    'removedDefaults': removedDefaults.toList(),
    'collectedLoot': collectedLoot.toList(),
    'equippedSkin': equippedSkin,
    'seenEvidence': seenEvidence.toList(),
    'canvasTheme': canvasTheme,
    'questDeskStyle': questDeskStyle,
    'unlockedAchievements': unlockedAchievements.toList(),
    'history': history,
    if (trainingLog.isNotEmpty)
      'trainingLog': [for (final mark in trainingLog) mark.toJson()],
    'goals': [for (final g in goals) g.toJson()],
    'todayXp': todayXp,
    'todayStats': [for (final s in Stat.values) todayStats[s] ?? 0],
    'todayQuestTitles': todayQuestTitles,
    // Schema 29: one list for the day's own records. Reward-bearing, so the
    // schema bump makes an older build hold instead of dropping the proof.
    'dayRecords': [for (final record in _dayRecords) record.toJson()],
    'totalClassesKept': totalClassesKept,
    'classesAtLastLevel': classesAtLastLevel,
    'keptClassCounts': {
      for (final code in _keptClassCounts.keys.toList()..sort())
        code: _keptClassCounts[code],
    },
    if (previousDayKey != null) 'previousDayKey': previousDayKey,
    'previousDayXp': previousDayXp,
    'previousDayStats': [for (final s in Stat.values) previousDayStats[s] ?? 0],
    'previousDayQuestTitles': previousDayQuestTitles,
    if (previousDayEnergy != null) 'previousDayEnergy': previousDayEnergy!.name,
    'todayLootDrops': todayLootDrops,
    'todayTitleCounts': todayTitleCounts,
    'nightDoneDay': nightDoneDay,
    'morningDoneDay': morningDoneDay,
    'morningArmed': morningArmed,
    'nightDoneAt': nightDoneAt,
    if (restLiftedNight != null) 'restLiftedNight': restLiftedNight,
    if (nightDraftNoteId != null) 'nightDraftNoteId': nightDraftNoteId,
    if (pendingMorningNoteId != null)
      'pendingMorningNoteId': pendingMorningNoteId,
    'sparkSeenDay': sparkSeenDay,
    'weekRecapSeenWeek': weekRecapSeenWeek,
    'emberSeenDay': emberSeenDay,
    'stewardMemory': stewardMemory.toJson(),
  };

  static GameState fromJson(Map<String, dynamic> j) {
    final s = GameState();
    s.stewardMemory = StewardMemory.fromJson(j['stewardMemory']);
    s.playerName = j['playerName'] as String?;
    s.onboarded = j['onboarded'] as bool? ?? true; // pre-existing saves skip
    s.timeShape = j['timeShape'] as String?;
    s.focusMode = j['focusMode'] as bool? ?? false;
    s.reduceMotion = j['reduceMotion'] as bool? ?? false;
    s.soundEnabled = j['soundEnabled'] as bool? ?? true;
    s.musicEnabled = j['musicEnabled'] as bool? ?? false;
    s.addClassesHidden = j['addClassesHidden'] == true;
    s.textScale = (j['textScale'] as num?)?.toDouble() ?? 1.0;
    s.notifyEnabled = j['notifyEnabled'] as bool? ?? false;
    s.notifyHour = j['notifyHour'] as int? ?? 9;
    s.notifyMinute = j['notifyMinute'] as int? ?? 0;
    s.nightReminderEnabled = j['nightReminderEnabled'] as bool? ?? false;
    s.nightReminderHour = (j['nightReminderHour'] as int? ?? 21).clamp(0, 23);
    s.nightReminderMinute = (j['nightReminderMinute'] as int? ?? 0).clamp(
      0,
      59,
    );
    s.lastModified = j['lastModified'] as int? ?? 0;
    s.level = j['level'] as int? ?? 1;
    s.xp = j['xp'] as int? ?? 0;
    s.totalXp = j['totalXp'] as int? ?? 0;
    s.embers = j['embers'] as int? ?? 0;
    s.ownedFurniture.addAll(
      ((j['ownedFurniture'] as List?) ?? const []).cast(),
    );
    s.roomKeepsakes.addAll(sanitizeRoomKeepsakes(j['roomKeepsakes']));
    // Preserve legacy starter-piece flags for existing TestFlight backups.
    if (s.level >= 2) s.ownedFurniture.add('rug');
    if (s.level >= 3) s.ownedFurniture.add('plant');
    if (s.level >= 4) s.ownedFurniture.add('cushion');
    s.ownedStyles.addAll(((j['ownedStyles'] as List?) ?? const []).cast());
    final savedWall = j['wallStyle'] as String? ?? 'wall_walnut';
    // Grandfather old wall-paint purchases into the nearest complete room.
    // Nobody who spent Glimmers before this model changed should have to buy
    // their way back into an equivalent atmosphere.
    // Rose Clay (180) and Amber Limewash (200) are warm earth tones and the
    // only warm room is the free one, so there was no hue-true landing spot and
    // they fell through every branch below — their owners lost the purchase
    // outright, which is exactly what the comment above says must not happen.
    // Conservatory is the cheaper paid room and worth more than either cost.
    if (s.ownedStyles.any(
      const {'wall_sage', 'wall_clay', 'wall_amber'}.contains,
    )) {
      s.ownedStyles.add('wall_conservatory');
    }
    if (s.ownedStyles.any(
      const {'wall_plum', 'wall_indigo', 'wall_berry'}.contains,
    )) {
      s.ownedStyles.add('wall_archive');
    }
    if (isSpaceThemeId(savedWall)) {
      s.wallStyle = savedWall;
    } else if (const {
      'wall_sage',
      'wall_clay',
      'wall_amber',
    }.contains(savedWall)) {
      s.wallStyle = 'wall_conservatory';
      s.ownedStyles.add('wall_conservatory');
    } else if (const {
      'wall_plum',
      'wall_indigo',
      'wall_berry',
    }.contains(savedWall)) {
      s.wallStyle = 'wall_archive';
      s.ownedStyles.add('wall_archive');
    } else {
      s.wallStyle = 'wall_walnut';
    }
    s.floorStyle = j['floorStyle'] as String? ?? 'floor_oak';
    s.ownedSkins.addAll(((j['ownedSkins'] as List?) ?? const []).cast());
    s.creatureSkin = j['creatureSkin'] as String? ?? 'ember_amber';
    s.ownedWindows.addAll(((j['ownedWindows'] as List?) ?? const []).cast());
    s.windowScene = j['windowScene'] as String? ?? 'moon';
    s.ownedScenes.addAll(((j['ownedScenes'] as List?) ?? const []).cast());
    s.stageScene = j['stageScene'] as String? ?? 'hearthside';
    s.roomCode = j['roomCode'] as String?;
    final storedDiscoverable =
        s.roomCode != null && j['roomDiscoverable'] == true;
    final rawRemovalCodes = j['roomDiscoveryRemovalCodes'];
    if (rawRemovalCodes is List) {
      for (final raw in rawRemovalCodes.take(16)) {
        final code = raw is String ? raw.trim().toUpperCase() : '';
        if (RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code)) {
          s._roomDiscoveryRemovalCodes.add(code);
        }
      }
    }
    if (s.roomCode != null &&
        (j['roomDiscoveryRemovalPending'] == true ||
            (!kSpaceDiscoveryEnabled && storedDiscoverable))) {
      s._roomDiscoveryRemovalCodes.add(s.roomCode!);
    }
    s.roomDiscoverable =
        kSpaceDiscoveryEnabled &&
        storedDiscoverable &&
        !s._roomDiscoveryRemovalCodes.contains(s.roomCode);
    s.roomDiscoveryName = s.roomDiscoverable
        ? sanitizeDiscoveryPublicName(j['roomDiscoveryName'])
        : '';
    final rawBlockedCodes = j['blockedRoomCodes'];
    if (rawBlockedCodes is List) {
      for (final raw in rawBlockedCodes) {
        final code = raw is String ? raw.trim().toUpperCase() : '';
        if (RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code) &&
            code != s.roomCode) {
          s.blockedRoomCodes.add(code);
        }
      }
    }
    final rawBlockedOwners = j['blockedDiscoveryOwners'];
    if (rawBlockedOwners is Map) {
      for (final entry in rawBlockedOwners.entries.take(100)) {
        final ownerKey = entry.key;
        final code = entry.value is String
            ? (entry.value as String).trim().toUpperCase()
            : '';
        if (isValidDiscoveryOwnerKey(ownerKey) &&
            RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code) &&
            code != s.roomCode) {
          s.blockedDiscoveryOwners[ownerKey as String] = code;
          s.blockedRoomCodes.add(code);
        }
      }
    }
    final rawCircleOwnerKeys = j['hearthCircleOwnerKeys'];
    final rawCircleCodes = j['hearthCircleCodes'];
    if (rawCircleCodes is List) {
      for (final raw in rawCircleCodes) {
        final code = raw is String ? raw.trim().toUpperCase() : '';
        final ownerKey = rawCircleOwnerKeys is Map
            ? rawCircleOwnerKeys[code]
            : null;
        if (RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code) &&
            !s.blockedRoomCodes.contains(code) &&
            (!isValidDiscoveryOwnerKey(ownerKey) ||
                !s.blockedDiscoveryOwners.containsKey(ownerKey)) &&
            code != s.roomCode &&
            !s.hearthCircleCodes.contains(code)) {
          s.hearthCircleCodes.add(code);
          if (isValidDiscoveryOwnerKey(ownerKey)) {
            s.hearthCircleOwnerKeys[code] = ownerKey as String;
          }
        }
      }
    }
    final rawCircleNames = j['hearthCircleNames'];
    if (rawCircleNames is Map) {
      for (final code in s.hearthCircleCodes) {
        final name = sanitizeDiscoveryPublicName(rawCircleNames[code]);
        if (name.isNotEmpty) s.hearthCircleNames[code] = name;
      }
    }
    s.energyWeather = EnergyWeather.values.firstWhere(
      (e) => e.name == j['energyWeather'],
      orElse: () => EnergyWeather.steady,
    );
    s.energyWeatherDay = Days.validKey(j['energyWeatherDay']);
    for (final entry
        in (((j['energyHistory'] as Map?) ?? const {}).cast<String, dynamic>())
            .entries) {
      if (Days.tryParse(entry.key) == null) continue;
      final weather = EnergyWeather.values.where((e) => e.name == entry.value);
      if (weather.isNotEmpty) s.energyHistory[entry.key] = weather.first;
    }
    s.lowFlameQuestTitles.addAll(
      ((j['lowFlameQuestTitles'] as List?) ?? const [])
          .whereType<String>()
          .where((title) => title.trim().isNotEmpty)
          .toSet()
          .take(3),
    );
    s.memoryPins.addAll(
      ((j['memoryPins'] as List?) ?? const []).cast<String>(),
    );
    s.spaceIntro = _cleanSpaceIntro(j['spaceIntro'] as String? ?? '');
    final savedFeatured = ((j['featuredGoalTitles'] as List?) ?? const [])
        .whereType<String>()
        .map((title) => title.trim())
        .where((title) => title.isNotEmpty)
        .toSet()
        .take(3);
    s.featuredGoalTitles.addAll(savedFeatured);
    s.shareSpaceProfile = j['shareSpaceProfile'] as bool? ?? false;
    s.spaceCardOrder
      ..clear()
      ..addAll(
        _cleanSpaceCardOrder(_spaceCardKindsFromJson(j['spaceCardOrder'])),
      );
    s.hiddenSpaceCards.addAll(_spaceCardKindsFromJson(j['hiddenSpaceCards']));
    final savedAudiences = j['spaceCardAudiences'];
    s.spaceCardAudiences
      ..clear()
      ..addAll({
        for (final kind in SpaceCardKind.values) kind: SpaceAudience.onlyMe,
      });
    if (savedAudiences is Map) {
      for (final kind in SpaceCardKind.values) {
        final value = savedAudiences[kind.name];
        for (final audience in SpaceAudience.values) {
          if (audience.name == value) s.spaceCardAudiences[kind] = audience;
        }
      }
    }
    s.visitorSpaceCards.clear();
    s.spaceSeasonText = _cleanSpaceSeasonText(
      j['spaceSeasonText'] is String ? j['spaceSeasonText'] as String : '',
    );
    s.spaceProfilePhotoNoteId = _cleanSpaceSeasonPhotoNoteId(
      j['spaceProfilePhotoNoteId'] is String
          ? j['spaceProfilePhotoNoteId'] as String
          : null,
    );
    s.spaceSeasonPhotoNoteId = _cleanSpaceSeasonPhotoNoteId(
      j['spaceSeasonPhotoNoteId'] is String
          ? j['spaceSeasonPhotoNoteId'] as String
          : null,
    );
    s.shareSpaceProfilePhoto = j['shareSpaceProfilePhoto'] as bool? ?? false;
    s.shareSpaceSeasonPhoto = j['shareSpaceSeasonPhoto'] as bool? ?? false;
    s.spaceProfilePhotoPath = _cleanSharedRoomPhotoPath(
      j['spaceProfilePhotoPath'],
    );
    s.spaceSeasonPhotoPath = _cleanSharedRoomPhotoPath(
      j['spaceSeasonPhotoPath'],
    );
    s.shareRoomPhoto = j['shareRoomPhoto'] == true;
    final roomPhotoPath = _cleanPublicRoomPhotoPath(j['spaceRoomPhotoPath']);
    s.spaceRoomPhotoPath = roomPhotoPath;
    if (roomPhotoPath.isNotEmpty) {
      s.spaceRoomPhotoFill = j['spaceRoomPhotoFill'] == true;
      s.spaceRoomPhotoX = _cleanRoomPhotoAlignment(j['spaceRoomPhotoX']);
      s.spaceRoomPhotoY = _cleanRoomPhotoAlignment(j['spaceRoomPhotoY']);
      s.spaceRoomPhotoWidth = _cleanRoomPhotoDimension(
        j['spaceRoomPhotoWidth'],
      );
      s.spaceRoomPhotoHeight = _cleanRoomPhotoDimension(
        j['spaceRoomPhotoHeight'],
      );
    }
    final quietKind = j['quietCompanyKind'] as String? ?? 'none';
    s.quietCompanyKind =
        const {'none', 'study', 'making', 'reset', 'quiet'}.contains(quietKind)
        ? quietKind
        : 'none';
    s.quietCompanyUntil = j['quietCompanyUntil'] as int? ?? 0;
    final st = (j['stats'] as List?)?.cast<int>() ?? const [];
    for (var i = 0; i < Stat.values.length && i < st.length; i++) {
      s.stats[Stat.values[i]] = st[i];
    }
    final dn = (j['domainNotes'] as List?) ?? const [];
    for (var i = 0; i < Stat.values.length && i < dn.length; i++) {
      final list = [
        for (final e in (dn[i] as List?) ?? const [])
          Note.fromJson((e as Map).cast<String, dynamic>()),
      ];
      if (list.isNotEmpty) s.domainNotes[Stat.values[i]] = list;
    }
    s.journal = [
      for (final e in (j['journal'] as List?) ?? const [])
        Note.fromJson((e as Map).cast<String, dynamic>()),
    ];
    for (final e in (j['ledger'] as List?) ?? const []) {
      s.ledger.add(LedgerEntry.fromJson((e as Map).cast<String, dynamic>()));
    }
    s.streakDays = j['streakDays'] as int? ?? 0;
    s.bestStreak = j['bestStreak'] as int? ?? s.streakDays;
    final encodedFreezeVersion = j['streakFreezeVersion'] as int? ?? 0;
    final encodedFreezes = j['streakShields'] as int? ?? 0;
    // Every pre-freeze-system save receives the starter reserve exactly once;
    // any old shields already earned are preserved if that is more generous.
    s.streakFreezes =
        (encodedFreezeVersion >= _streakFreezeVersion
                ? encodedFreezes
                : max(encodedFreezes, starterStreakFreezes))
            .clamp(0, s.streakFreezeCapacity);
    s.streakFreezeVersion = _streakFreezeVersion;
    s.freezeLevelBonusGranted = j['shieldUnlockGranted'] as bool? ?? false;
    s.streakFreezeProgress = (j['streakFreezeProgress'] as int? ?? 0).clamp(
      0,
      s.activeDaysPerFreeze - 1,
    );
    for (final day in (j['frozenStreakDays'] as List?) ?? const []) {
      final key = Days.validKey(day);
      if (key != null) s.frozenStreakDays.add(key);
    }
    s.lastCompletionDay = Days.validKey(j['lastCompletionDay']);
    s._lastStreakDay = Days.validKey(j['lastStreakDay']);
    s.comebackPendingDay = Days.validKey(j['comebackPendingDay']);
    s._decodeStreakSteps(j['streakSteps']);
    s.lastActiveDay = Days.validKey(j['lastActiveDay']);
    s.totalCompletions = j['totalCompletions'] as int? ?? 0;
    s.completionsAtLastLevel = j['completionsAtLastLevel'] as int?;
    s.verifiedCompletions = j['verifiedCompletions'] as int? ?? 0;
    s.dreadCompletions = j['dreadCompletions'] as int? ?? 0;
    s.epicCompletions = j['epicCompletions'] as int? ?? 0;
    s.eventCompletions = j['eventCompletions'] as int? ?? 0;
    s.customCompletions = j['customCompletions'] as int? ?? 0;
    s.comebacks = j['comebacks'] as int? ?? 0;
    s.dawnCompletions = j['dawnCompletions'] as int? ?? 0;
    s.duskCompletions = j['duskCompletions'] as int? ?? 0;
    s.perfectDays = j['perfectDays'] as int? ?? 0;
    s.lastPerfectDay = Days.validKey(j['lastPerfectDay']);
    s.removedDefaults.addAll(
      ((j['removedDefaults'] as List?) ?? const []).cast(),
    );
    s.collectedLoot.addAll(((j['collectedLoot'] as List?) ?? const []).cast());
    s.equippedSkin = j['equippedSkin'] as String?;
    s.seenEvidence.addAll(((j['seenEvidence'] as List?) ?? const []).cast());
    final savedCanvasTheme = j['canvasTheme'] as String?;
    final savedCanvasChoice = canvasThemeById(savedCanvasTheme);
    s.canvasTheme =
        isCanvasThemeId(savedCanvasTheme) &&
            (!savedCanvasChoice.locked || s.level >= 5)
        ? savedCanvasTheme!
        : 'walnut';
    // Complete room themes are the single appearance authority. Older saves
    // may carry a separate desk id, but it must never split Me and Quests or
    // grant a paid room that is not owned.
    final activeTheme = spaceThemeById(s.wallStyle);
    if (activeTheme == null ||
        (activeTheme.price > 0 && !s.ownedStyles.contains(s.wallStyle))) {
      s.wallStyle = 'wall_walnut';
    }
    s.questDeskStyle = s.wallStyle;
    s.unlockedAchievements.addAll(
      ((j['unlockedAchievements'] as List?) ?? const []).cast(),
    );
    for (final e
        in (((j['history'] as Map?) ?? const {}).cast<String, dynamic>())
            .entries) {
      if (Days.tryParse(e.key) != null && e.value is num) {
        s.history[e.key] = (e.value as num).toInt();
      }
    }
    for (final raw in (j['trainingLog'] as List?) ?? const []) {
      final mark = TrainingMark.tryFromJson(raw);
      if (mark != null) s.trainingLog.add(mark);
    }
    for (final g in (j['goals'] as List?) ?? const []) {
      s.goals.add(Goal.fromJson((g as Map).cast<String, dynamic>()));
    }
    s.todayXp = j['todayXp'] as int? ?? 0;
    final ts = (j['todayStats'] as List?)?.cast<int>() ?? const [];
    for (var i = 0; i < Stat.values.length && i < ts.length; i++) {
      if (ts[i] > 0) s.todayStats[Stat.values[i]] = ts[i];
    }
    s.todayQuestTitles.addAll(
      ((j['todayQuestTitles'] as List?) ?? const []).cast(),
    );
    s._decodeDayRecords(j);
    s.previousDayKey = Days.validKey(j['previousDayKey']);
    s.previousDayXp = j['previousDayXp'] as int? ?? 0;
    final previousStats =
        (j['previousDayStats'] as List?)?.cast<int>() ?? const [];
    for (var i = 0; i < Stat.values.length && i < previousStats.length; i++) {
      if (previousStats[i] > 0) {
        s.previousDayStats[Stat.values[i]] = previousStats[i];
      }
    }
    s.previousDayQuestTitles.addAll(
      ((j['previousDayQuestTitles'] as List?) ?? const []).whereType<String>(),
    );
    final previousEnergy = j['previousDayEnergy'] as String?;
    if (previousEnergy != null) {
      for (final value in EnergyWeather.values) {
        if (value.name == previousEnergy) s.previousDayEnergy = value;
      }
    }
    s.todayLootDrops = j['todayLootDrops'] as int? ?? 0;
    for (final e
        in (((j['todayTitleCounts'] as Map?) ?? const {})
                .cast<String, dynamic>())
            .entries) {
      s.todayTitleCounts[e.key] = (e.value as num).toInt();
    }
    s.nightDoneDay = Days.validKey(j['nightDoneDay']);
    s.morningDoneDay = Days.validKey(j['morningDoneDay']);
    s.nightDoneAt = j['nightDoneAt'] as int? ?? 0;
    final draftId = j['nightDraftNoteId'] as String?;
    final pendingId = j['pendingMorningNoteId'] as String?;
    final draft = s._journalNote(draftId);
    final pending = s._journalNote(pendingId);
    s.nightDraftNoteId =
        draft?.night != null && draft?.trace?.day == Days.nightKey(Clock.now())
        ? draftId
        : null;
    final pendingMessage = pending?.night?.tomorrowMessage?.trim();
    s.pendingMorningNoteId = pendingMessage != null && pendingMessage.isNotEmpty
        ? pendingId
        : null;
    // Bridge older saves (no morningArmed key): if a night was closed and you
    // haven't been greeted today, arm the morning so it surfaces after this
    // update (e.g. a 3am wind-down before the field existed) — user report.
    s.morningArmed =
        j['morningArmed'] as bool? ??
        (j['nightDoneDay'] != null &&
            j['morningDoneDay'] != Days.key(Clock.now()));
    s.restLiftedNight = Days.validKey(j['restLiftedNight']);
    s.sparkSeenDay = Days.validKey(j['sparkSeenDay']);
    s.weekRecapSeenWeek = Days.validKey(j['weekRecapSeenWeek']);
    s.emberSeenDay = Days.validKey(j['emberSeenDay']);
    // Self-heal saves created by builds where achievements were only checked
    // from the quest screen. All counters/goals/routines are loaded now, so
    // this pass safely restores every trophy the player already earned.
    s.checkAchievements();
    return s;
  }

  /// The remembered streak advances. All or nothing: a malformed entry, a
  /// broken day chain, or a log that does not end on the last streak day is
  /// dropped whole, and a late mark then falls back to returning a held
  /// freeze. Never reads the clock.
  void _decodeStreakSteps(Object? raw) {
    if (raw is! List) return;
    final recent = raw.length > _maxStreakSteps
        ? raw.sublist(raw.length - _maxStreakSteps)
        : raw;
    final steps = <_StreakStep>[];
    for (final item in recent) {
      final step = _StreakStep.fromJson(item);
      if (step == null) return;
      if (steps.isNotEmpty &&
          (step.dayKey.compareTo(steps.last.dayKey) <= 0 ||
              step.lastBefore != steps.last.dayKey)) {
        return;
      }
      steps.add(step);
    }
    if (steps.isEmpty || steps.last.dayKey != lastStreakDay) return;
    _streakSteps.addAll(steps);
  }

  /// Tolerant decode of the day's own records. Never throws: a bad record is
  /// dropped, a repeated day folds into one (newest wins, nothing re-awards),
  /// and only an oversized list consults the clock, to protect the active
  /// night while trimming. Counters are repaired upward, never down.
  void _decodeDayRecords(Map<String, dynamic> j) {
    final byDay = <String, DayRecord>{};
    final rawRecords = j['dayRecords'];
    if (rawRecords is List) {
      for (final raw in rawRecords.take(dayRecordHorizon * 4)) {
        final record = DayRecord.fromJson(raw);
        if (record == null) continue;
        final existing = byDay[record.dayKey];
        byDay[record.dayKey] = existing == null
            ? record
            : DayRecord.merge(existing, record);
      }
    }
    // A schema-29 preview build kept Extra Credit under its own key. Read it
    // so such a save keeps its proof: one entry per day, newest wording.
    final legacy = j['extraCredit'];
    if (legacy is List) {
      final entries = <ExtraCreditEntry>[
        for (final raw in legacy.take(dayRecordHorizon * 4))
          ?ExtraCreditEntry.fromJson(raw),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      for (final entry in entries) {
        final record = byDay[entry.dayKey];
        if (record?.extraCredit != null) continue;
        byDay[entry.dayKey] = (record ?? DayRecord(dayKey: entry.dayKey))
            .copyWith(extraCredit: entry);
      }
    }
    _dayRecords
      ..addAll(byDay.values)
      ..sort((a, b) => a.dayKey.compareTo(b.dayKey));
    if (_dayRecords.length > dayRecordHorizon) {
      _trimDayRecords(retain: {Days.nightKey(Clock.now())});
    }

    final rawCounts = j['keptClassCounts'];
    if (rawCounts is Map) {
      for (final entry in rawCounts.entries.take(_maxCourseCounters)) {
        final code = entry.key;
        final count = entry.value;
        if (code is String &&
            code.trim().isNotEmpty &&
            code.trim().length <= KeptClass.maxCodeLength &&
            count is int &&
            count > 0) {
          _keptClassCounts[code.trim()] = count;
        }
      }
    }
    final counted = <String, int>{};
    for (final record in _dayRecords) {
      for (final kept in record.classes) {
        counted[kept.courseCode] = (counted[kept.courseCode] ?? 0) + 1;
      }
    }
    for (final entry in counted.entries) {
      if ((_keptClassCounts[entry.key] ?? 0) < entry.value &&
          (_keptClassCounts.containsKey(entry.key) ||
              _keptClassCounts.length < _maxCourseCounters)) {
        _keptClassCounts[entry.key] = entry.value;
      }
    }
    final countedTotal = _keptClassCounts.values.fold(0, (a, b) => a + b);
    final storedTotal = j['totalClassesKept'];
    totalClassesKept = max(
      storedTotal is int && storedTotal > 0 ? storedTotal : 0,
      countedTotal,
    );
    final storedAtLevel = j['classesAtLastLevel'];
    classesAtLastLevel = storedAtLevel is int
        ? storedAtLevel.clamp(0, totalClassesKept)
        : 0;
  }
}

/// One streak advance, remembered for a few nights: the day it lit, whether
/// a Quest lit it, the streak just before it, and what it held and paid. A
/// late class mark for an earlier day runs the advances after that day again
/// from here, in day order (rule A). Saved, so a reload between a Quest and a
/// late mark changes nothing.
final class _StreakStep {
  const _StreakStep({
    required this.dayKey,
    required this.quest,
    required this.lastBefore,
    required this.streakBefore,
    required this.freezesBefore,
    required this.progressBefore,
    required this.freezesAfter,
    this.held = const [],
    this.restarted = false,
    this.milestone,
  });

  final String dayKey;
  final bool quest;

  /// The last streak day before this advance.
  final String? lastBefore;
  final int streakBefore;
  final int freezesBefore;
  final int progressBefore;
  final int freezesAfter;

  /// The quiet days this advance held with freezes.
  final List<String> held;
  final bool restarted;

  /// The 7/30/100 chest this advance paid.
  final int? milestone;

  Map<String, dynamic> toJson() => {
    'day': dayKey,
    if (quest) 'quest': true,
    if (lastBefore != null) 'last': lastBefore,
    'streak': streakBefore,
    'freezes': freezesBefore,
    'progress': progressBefore,
    'freezesAfter': freezesAfter,
    if (held.isNotEmpty) 'held': held,
    if (restarted) 'restarted': true,
    if (milestone != null) 'milestone': milestone,
  };

  /// Total: anything malformed returns null (and drops the whole log).
  static _StreakStep? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final day = Days.validKey(raw['day']);
    final rawLast = raw['last'];
    final last = Days.validKey(rawLast);
    final streak = raw['streak'];
    final freezes = raw['freezes'];
    final progress = raw['progress'];
    final after = raw['freezesAfter'];
    final quest = raw['quest'] ?? false;
    final restarted = raw['restarted'] ?? false;
    final milestone = raw['milestone'];
    final rawHeld = raw['held'] ?? const <Object?>[];
    bool count(Object? value, int most) =>
        value is int && value >= 0 && value <= most;
    if (day == null ||
        (rawLast != null && last == null) ||
        !count(streak, 1 << 20) ||
        !count(freezes, GameState.maxStreakFreezes) ||
        !count(progress, 8) ||
        !count(after, GameState.maxStreakFreezes) ||
        quest is! bool ||
        restarted is! bool ||
        (milestone != null &&
            !GameState.streakMilestones.containsKey(milestone)) ||
        rawHeld is! List ||
        rawHeld.length > 60) {
      return null;
    }
    final held = <String>[];
    for (final item in rawHeld) {
      final key = Days.validKey(item);
      if (key == null) return null;
      held.add(key);
    }
    return _StreakStep(
      dayKey: day,
      quest: quest,
      lastBefore: last,
      streakBefore: streak as int,
      freezesBefore: freezes as int,
      progressBefore: progress as int,
      freezesAfter: after as int,
      held: List.unmodifiable(held),
      restarted: restarted,
      milestone: milestone as int?,
    );
  }
}

/// A late mark's recount in progress: its own last day and the advances it
/// has made so far.
final class _StreakRerun {
  _StreakRerun(this.last);

  String? last;
  final List<_StreakStep> steps = [];
}

enum RewardUndoKind { quest, keptClass }

/// The one whole-save undo slot (engine map §5.3).
///
/// A Quest completion and a class keep share it: the newest reward replaces
/// the slot, and [canRestore] refuses once any later reward (Quest, class or
/// Extra Credit) or Extra Credit wording edit has landed, so an undo never
/// erases a newer reward or puts older words back. The restore is the whole
/// snapshot: day records are reward-bearing and are never merged back from
/// the live save, because the snapshot already pairs every record with the
/// XP it paid.
final class RewardUndoSlot {
  RewardUndoSlot._(
    this._state,
    this._serialBefore, {
    required this.kind,
    required this.label,
    required this.snapshot,
    this.classIdentity,
    this.dayKey,
    this.rewards = 1,
  });

  /// Capture just before the reward is applied. [snapshot] is the shell's
  /// whole-save JSON (`onSnapshot`).
  factory RewardUndoSlot.before(
    GameState state, {
    required RewardUndoKind kind,
    required String label,
    required String snapshot,
    String? classIdentity,
    String? dayKey,
  }) => RewardUndoSlot._(
    state,
    state.rewardSerial,
    kind: kind,
    label: label,
    snapshot: snapshot,
    classIdentity: classIdentity,
    dayKey: dayKey,
  );

  /// A class keep's slot, labelled and keyed for the row that shows undo.
  factory RewardUndoSlot.beforeClass(
    GameState state,
    ClassFacts facts, {
    required String snapshot,
  }) => RewardUndoSlot.before(
    state,
    kind: RewardUndoKind.keptClass,
    label: facts.label,
    snapshot: snapshot,
    classIdentity: facts.identity,
    dayKey: facts.dayKey,
  );

  final GameState _state;
  final int _serialBefore;
  final RewardUndoKind kind;
  final String label;
  final String snapshot;
  final String? classIdentity;
  final String? dayKey;

  /// How many rewards the one gesture landed after the snapshot (the class
  /// shortcut keeps several classes at once). The restore takes them all.
  final int rewards;

  /// The same slot for a gesture that landed [count] rewards in a row, named
  /// for the last of them ([last]'s class, when given).
  RewardUndoSlot spanning(int count, {ClassFacts? last}) => RewardUndoSlot._(
    _state,
    _serialBefore,
    kind: kind,
    label: last?.label ?? label,
    snapshot: snapshot,
    classIdentity: last?.identity ?? classIdentity,
    dayKey: last?.dayKey ?? dayKey,
    rewards: count,
  );

  /// True only while the rewards this slot was taken for are the latest ones
  /// on the same live state.
  bool canRestore(GameState live) =>
      rewards > 0 &&
      identical(live, _state) &&
      live.rewardSerial == _serialBefore + rewards;
}
