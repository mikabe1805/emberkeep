import 'dart:math';

import 'package:flutter/foundation.dart';

import 'clock.dart';
import 'content/achievements.dart';
import 'content/cosmetics.dart';
import 'content/evidence.dart';
import 'content/messages.dart';
import 'content/space_themes.dart';
import 'content/stat_ranks.dart';
import 'content/titles.dart';
import 'models.dart';
import 'tokens.dart';

/// The authored pieces that can be arranged on the owner's My Space page.
///
/// These names are persisted as strings. Keep existing names stable when the
/// presentation copy changes so a saved arrangement survives app updates.
enum SpaceCardKind { about, rightNow, pinnedMoments, thisSeason }

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
  GameState({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;

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

  /// The shared-space code, if this keep is published. Set through here (not
  /// the field) so the Me-page "Shared · CODE" label repaints when it changes.
  void setRoomCode(String? code) {
    if (roomCode == code) return;
    roomCode = code;
    notifyListeners();
  }

  /// Trusted keeps remembered locally. Codes expose only the same fixed,
  /// appearance-only public room payload as a one-off visit; no names, tasks,
  /// notes, account details, or free-text profile fields are introduced.
  final List<String> hearthCircleCodes = [];

  bool addCircleCode(String raw) {
    final code = raw.trim().toUpperCase();
    if (!RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code) ||
        code == roomCode ||
        hearthCircleCodes.contains(code) ||
        hearthCircleCodes.length >= 5) {
      return false;
    }
    hearthCircleCodes.add(code);
    notifyListeners();
    return true;
  }

  void removeCircleCode(String code) {
    if (hearthCircleCodes.remove(code)) notifyListeners();
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
  /// The note text remains private and local/cloud-save-only; public rooms
  /// receive only a total artifact count.
  final Set<String> memoryPins = {};

  /// A small, authored profile for the owner's room. It stays private unless
  /// [shareSpaceProfile] is explicitly enabled; callers that publish a room
  /// must honor that consent bit rather than inferring consent from content.
  String spaceIntro = '';
  final List<String> featuredGoalTitles = [];
  bool shareSpaceProfile = false;

  /// The private arrangement of the My Space deck. The first three entries
  /// reproduce the page that existed before cards became arrangeable; the
  /// empty This season card is omitted by the UI until the owner writes it.
  final List<SpaceCardKind> spaceCardOrder = [...defaultSpaceCardOrder];
  final Set<SpaceCardKind> hiddenSpaceCards = {};
  String spaceSeasonText = '';
  String? spaceSeasonPhotoNoteId;

  /// The Journal page supplying This season's optional photo. A cloud-restored
  /// note can legitimately have no local media, and a selected note can later
  /// be deleted, so both cases quietly fall back to the text-only card.
  Note? get spaceSeasonPhotoNote {
    final id = spaceSeasonPhotoNoteId;
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
    required String intro,
    required Iterable<String> featuredGoalTitles,
    required String seasonText,
    required String? seasonPhotoNoteId,
    required bool shareProfile,
  }) {
    final cleanOrder = _cleanSpaceCardOrder(order);
    final cleanHidden = hidden.toSet();
    final cleanFeatured = featuredGoalTitles.toList(growable: false);
    spaceCardOrder
      ..clear()
      ..addAll(cleanOrder);
    hiddenSpaceCards
      ..clear()
      ..addAll(cleanHidden);
    spaceIntro = _cleanSpaceIntro(intro);
    spaceSeasonText = _cleanSpaceSeasonText(seasonText);
    spaceSeasonPhotoNoteId = _cleanSpaceSeasonPhotoNoteId(seasonPhotoNoteId);
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
      intro: intro,
      featuredGoalTitles: goals,
      seasonText: spaceSeasonText,
      seasonPhotoNoteId: spaceSeasonPhotoNoteId,
      shareProfile: shared ?? shareSpaceProfile,
    );
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
    const freeWall = 'wall_walnut', freeFloor = 'floor_oak';
    if (kind == RoomStyleKind.wall) {
      if (id != freeWall && !ownedStyles.contains(id)) return;
      wallStyle = id;
    } else {
      if (id != freeFloor && !ownedStyles.contains(id)) return;
      floorStyle = id;
    }
    notifyListeners();
  }

  /// Creature skins (round-47) — the colour of the ember itself, chosen in the
  /// shop. Exclusive like room styles (own many, wear one). The free default
  /// 'ember_amber' is implicitly owned. Distinct from [equippedSkin], which is
  /// an earned cosmetic that only tints the aura/badge.
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
  JournalTrace todayJournalTrace(List<Quest> quests) => _journalTrace(
    quests,
    day: Days.key(Clock.now()),
    xp: todayXp,
    statGains: todayStats,
    questTitles: todayQuestTitles,
    energy: energyWeatherDay == Days.key(Clock.now()) ? energyWeather : null,
  );

  String get activeNightDayKey => Days.nightKey(Clock.now());

  bool get _nightUsesSnapshot => previousDayKey == activeNightDayKey;

  int get nightXp => _nightUsesSnapshot ? previousDayXp : todayXp;

  Map<Stat, int> get nightStatGains =>
      _nightUsesSnapshot ? previousDayStats : todayStats;

  List<String> get nightQuestTitles =>
      _nightUsesSnapshot ? previousDayQuestTitles : todayQuestTitles;

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
      goalTitles: goalTitles.toList(growable: false),
      statGains: {
        for (final entry in statGains.entries)
          if (entry.value > 0) entry.key: entry.value,
      },
      energy: energy,
    );
  }

  /// Recent gains, newest first — the Me page's attribution ledger.
  final List<LedgerEntry> ledger = [];

  // ── streak (real now: consecutive days with ≥1 completion) ──────
  int streakDays = 0;
  int bestStreak = 0;
  String? lastCompletionDay;

  /// Streak shields — the Lv-6 unlock, finally real. Each one quietly bridges
  /// a single missed day so a long streak survives one bad day (never-punish;
  /// RESEARCH-momentum.md §7). Granted at the unlock and earned on perfect days.
  int streakShields = 0;
  bool shieldUnlockGranted = false;
  static const maxShields = 5;

  // ── achievement counters ─────────────────────────────────────────
  int totalCompletions = 0;
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
  /// default dominant-stat look. Recolors the portrait aura + completion
  /// sparks (see content/cosmetics.dart). Toggle with [equipSkin].
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
    if (canvasTheme == id) return;
    canvasTheme = id;
    notifyListeners();
  }

  /// The wall-style id whose material language dresses the Quests HUD.
  ///
  /// This is deliberately independent from [wallStyle]: a player can keep a
  /// walnut room and still carry an owned Midnight look to their Quest Desk.
  /// The UI validates ownership before applying a look. Older saves simply
  /// fall back to the free Walnut Desk.
  String questDeskStyle = 'wall_walnut';

  void setQuestDeskStyle(String id) {
    if (questDeskStyle == id) return;
    questDeskStyle = id;
    notifyListeners();
  }

  /// dateKey → completions that day (calendar history dots).
  final Map<String, int> history = {};

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
  int todayXp = 0;
  final Map<Stat, int> todayStats = {};
  final List<String> todayQuestTitles = [];

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

  /// Closing the night arms tomorrow morning's briefing.
  void closeNight() {
    final now = Clock.now();
    nightDoneDay = Days.nightKey(now);
    nightDoneAt = now.millisecondsSinceEpoch;
    morningArmed = true;
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
    6: 'STREAK SHIELDS',
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
  /// last active day, how many days were missed, and can shields bridge it?
  /// Read identically by [roll] (for messaging) and [commit] (to apply) —
  /// both run before lastCompletionDay is bumped, so they agree.
  ({bool gap, int missed, bool covered}) _streakSituation() {
    final last = lastCompletionDay;
    final now = Clock.now();
    if (last == null || last == Days.key(now)) {
      return (gap: false, missed: 0, covered: false);
    }
    final d = Days.parse(last);
    final missed = Days.between(d, now) - 1;
    if (missed <= 0) return (gap: false, missed: 0, covered: false);
    return (gap: true, missed: missed, covered: streakShields >= missed);
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
  RewardBundle roll(Quest q, {bool verified = false}) {
    final now = Clock.now();
    final nowKey = Days.key(now);
    // How a gap (if any) resolves: a shield bridges it silently, otherwise
    // it's a true lapse and the return earns a warm comeback bonus. Read
    // before we stamp anything (mirrors [commit]'s decision).
    final sit = _streakSituation();
    final shieldHeld = sit.gap && sit.covered;
    final isComeback = sit.gap && !sit.covered;
    // the FIRST completion of the day (no completion committed yet today)
    final firstOfDay = lastCompletionDay != nowKey;

    final priorSame = todayTitleCounts[q.title] ?? 0;
    final neglect = _neglectMult(q, nowKey);
    final dayOne = _dayOneDamp(q, nowKey);

    q.lastDoneDay = nowKey;
    if (q.rising) q.risingStreak++;

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

    return RewardBundle(
      xp: earned.round(),
      // embers track XP (~a third, min 1) — the one source for both the
      // receipt bubble and what commit() banks
      embers: max(1, earned.round() ~/ 3),
      stat: q.stat,
      statGain: max(1, gain.round() + (q.dread ? 3 : 0)),
      questTitle: q.displayTitle,
      message: RewardMessages.pick(
        q.stat,
        _rng,
        hour: now.hour,
        dread: q.dread,
        countToday: (history[nowKey] ?? 0) + 1,
        comeback: isComeback,
      ),
      difficulty: q.difficulty,
      dread: q.dread,
      custom: q.custom,
      isEvent: q.isEvent,
      goalTitle: q.goalTitle,
      critMult: crit,
      // report the multiplier actually applied (post-reset on a comeback)
      streakMult: isComeback
          ? effStreakMult
          : (streakDays > 0 ? streakMult : null),
      verifiedMult: verified ? verifiedBonus : null,
      comebackMult: isComeback ? comebackBonus : null,
      shieldHeld: shieldHeld,
      firstOfDay: firstOfDay,
      loot: loot,
      hasEvidence:
          evidenceForStat(q.stat) != null &&
          !seenEvidence.contains(evidenceForStat(q.stat)!.title),
      questKey: q.title,
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
    final effMult = (sit.gap && !sit.covered) ? streakMultFor(1) : streakMult;
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

    // streak: consecutive days with at least one completion — a shield
    // bridges a missed day so a long run survives one bad day (never-punish)
    final now = Clock.now();
    final today = Days.key(now);
    if (lastCompletionDay != today) {
      final sit = _streakSituation();
      if (!sit.gap) {
        streakDays += 1; // first ever, or yesterday → continues
      } else if (sit.covered) {
        streakShields -= sit.missed; // shield(s) hold the line
        streakDays += 1;
      } else {
        comebacks++; // a real lapse — reset, but the return is celebrated
        streakDays = 1;
      }
      lastCompletionDay = today;

      // streak milestone — a 7/30/100 day CROSSING queues a chest. This lives
      // INSIDE the day-change block on purpose: a milestone can only be
      // crossed when the streak increments, so the second+ completion of a
      // milestone day must NOT re-pay the chest (day 30 × 6 quests once paid
      // 1,200 embers and staged the takeover six times — the exact currency
      // inflation the shop economy can't take).
      if (streakMilestones.containsKey(streakDays)) {
        _streakMilestoneQ.add(streakDays);
        embers += streakMilestones[streakDays]!;
      }
    }
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
    final titleKey = b.questKey ?? b.questTitle;
    todayTitleCounts[titleKey] = (todayTitleCounts[titleKey] ?? 0) + 1;

    // VIT perk: high Vitality occasionally forges an extra shield on the
    // day's first ember (never above the cap; only once shields unlock).
    if (b.firstOfDay &&
        shieldUnlockGranted &&
        streakShields < maxShields &&
        stats[Stat.vit]! >= 40 &&
        _rng.nextDouble() < 0.08) {
      streakShields++;
    }

    // today's haul (night recap)
    todayXp += b.xp;
    todayStats[b.stat] = (todayStats[b.stat] ?? 0) + b.statGain;
    todayQuestTitles.add(b.questTitle);

    // goal progress: linked completions inch the bar toward full
    if (b.goalTitle != null) {
      for (final g in goals) {
        if (g.title == b.goalTitle && !g.complete) {
          g.progress++;
          if (g.progress >= g.target) {
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
    // the STREAK SHIELDS unlock (Lv 6) actually hands you shields now
    if (level >= 6 && !shieldUnlockGranted) {
      shieldUnlockGranted = true;
      streakShields = (streakShields + 2).clamp(0, maxShields);
    }
    // the GILDED SKIN unlock (Lv 15) grants the gilded skin for free
    if (level >= 15 && !ownedSkins.contains('gilded')) {
      ownedSkins.add('gilded');
    }
    return LevelResult(leveledTo: reached, unlock: unlocks[reached]);
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
    // once shields are unlocked, a perfect day forges one (capped) — a
    // reason to clear the whole board, and a buffer for the day you can't
    if (shieldUnlockGranted && streakShields < maxShields) streakShields++;
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
    'hearthCircleCodes': hearthCircleCodes,
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
    'spaceSeasonText': spaceSeasonText,
    if (spaceSeasonPhotoNoteId != null)
      'spaceSeasonPhotoNoteId': spaceSeasonPhotoNoteId,
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
    'streakShields': streakShields,
    'shieldUnlockGranted': shieldUnlockGranted,
    'lastCompletionDay': lastCompletionDay,
    'lastActiveDay': lastActiveDay,
    'totalCompletions': totalCompletions,
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
    'goals': [for (final g in goals) g.toJson()],
    'todayXp': todayXp,
    'todayStats': [for (final s in Stat.values) todayStats[s] ?? 0],
    'todayQuestTitles': todayQuestTitles,
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
    if (nightDraftNoteId != null) 'nightDraftNoteId': nightDraftNoteId,
    if (pendingMorningNoteId != null)
      'pendingMorningNoteId': pendingMorningNoteId,
    'sparkSeenDay': sparkSeenDay,
    'weekRecapSeenWeek': weekRecapSeenWeek,
    'emberSeenDay': emberSeenDay,
  };

  static GameState fromJson(Map<String, dynamic> j) {
    final s = GameState();
    s.playerName = j['playerName'] as String?;
    s.onboarded = j['onboarded'] as bool? ?? true; // pre-existing saves skip
    s.timeShape = j['timeShape'] as String?;
    s.focusMode = j['focusMode'] as bool? ?? false;
    s.reduceMotion = j['reduceMotion'] as bool? ?? false;
    s.soundEnabled = j['soundEnabled'] as bool? ?? true;
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
    for (final raw in (j['hearthCircleCodes'] as List?) ?? const []) {
      final code = raw is String ? raw.trim().toUpperCase() : '';
      if (RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code) &&
          !s.hearthCircleCodes.contains(code) &&
          s.hearthCircleCodes.length < 5) {
        s.hearthCircleCodes.add(code);
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
    s.spaceSeasonText = _cleanSpaceSeasonText(
      j['spaceSeasonText'] is String ? j['spaceSeasonText'] as String : '',
    );
    s.spaceSeasonPhotoNoteId = _cleanSpaceSeasonPhotoNoteId(
      j['spaceSeasonPhotoNoteId'] is String
          ? j['spaceSeasonPhotoNoteId'] as String
          : null,
    );
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
    s.streakShields = j['streakShields'] as int? ?? 0;
    s.shieldUnlockGranted = j['shieldUnlockGranted'] as bool? ?? false;
    s.lastCompletionDay = Days.validKey(j['lastCompletionDay']);
    s.lastActiveDay = Days.validKey(j['lastActiveDay']);
    s.totalCompletions = j['totalCompletions'] as int? ?? 0;
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
    s.canvasTheme = j['canvasTheme'] as String? ?? 'walnut';
    final savedDesk = j['questDeskStyle'] as String? ?? 'wall_walnut';
    s.questDeskStyle = switch (savedDesk) {
      'wall_sage' => 'wall_conservatory',
      'wall_plum' || 'wall_indigo' || 'wall_berry' => 'wall_archive',
      _ when isSpaceThemeId(savedDesk) => savedDesk,
      _ => 'wall_walnut',
    };
    if (s.questDeskStyle != 'wall_walnut' &&
        !s.ownedStyles.contains(s.questDeskStyle)) {
      s.questDeskStyle = 'wall_walnut';
    }
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
    s.sparkSeenDay = Days.validKey(j['sparkSeenDay']);
    s.weekRecapSeenWeek = Days.validKey(j['weekRecapSeenWeek']);
    s.emberSeenDay = Days.validKey(j['emberSeenDay']);
    // Self-heal saves created by builds where achievements were only checked
    // from the quest screen. All counters/goals/routines are loaded now, so
    // this pass safely restores every trophy the player already earned.
    s.checkAchievements();
    return s;
  }
}
