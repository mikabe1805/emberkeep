import SwiftUI
import WidgetKit

private let roomOfDaysAppGroup = "group.com.mikabe.emberkeep"
private let roomOfDaysSnapshotKey = "roomOfDaysWidgetSnapshotV2"
private let roomOfDaysOpenClassDayURL = URL(string: "roomofdays://class-day")

// The view logic below is mirrored line for line in Dart
// (test/home_widgets/day_ledger_mirror.dart), where it is tested and
// rendered. Change both together.

private struct RoomWidgetSnapshot: Decodable {
  let version: Int
  let generatedAt: String
  let upcomingClasses: [ClassGlance]
  let incompleteQuests: [QuestGlance]
  // Version 3. Optional, so a version 2 snapshot still decodes.
  var questsDayEndsEpochMillis: Int64? = nil
  var nextDayQuests: [QuestGlance]? = nil
  var nextDayEndsEpochMillis: Int64? = nil
  var classDays: [ClassDay]? = nil
  var boundaries: [Int64]? = nil

  struct ClassGlance: Decodable {
    let courseCode: String
    let courseTitle: String
    let startLocal: String
    let endLocal: String
    let startEpochMillis: Int64
    let endEpochMillis: Int64
    let timeZoneId: String
    var dayKey: String? = nil
    var dayLabel: String? = nil
    var shortTitle: String? = nil
  }

  struct QuestGlance: Decodable, Identifiable {
    let id: String
    let title: String
  }

  struct ClassDay: Decodable {
    let dayKey: String
    let weekday: String
    let startsEpochMillis: Int64
    let eveningStartsEpochMillis: Int64
    let nightEndsEpochMillis: Int64
    let lastClassEndEpochMillis: Int64
    let classXp: Int
    let allKept: Bool
    var attendedShort: String? = nil
    let classes: [DayClass]
  }

  struct DayClass: Decodable, Identifiable {
    let occurrenceKey: String
    let shortTitle: String
    let place: String
    let startLabel: String
    let endLabel: String
    let startEpochMillis: Int64
    let endEpochMillis: Int64
    let kept: Bool
    let keptXp: Int
    let markUrl: String

    var id: String { occurrenceKey }
    var markURL: URL? { URL(string: markUrl) }
  }

  static let empty = RoomWidgetSnapshot(
    version: 2,
    generatedAt: "",
    upcomingClasses: [],
    incompleteQuests: []
  )
}

private struct RoomWidgetEntry: TimelineEntry {
  let date: Date
  let snapshot: RoomWidgetSnapshot

  enum Mode {
    case today
    case classes
    case allKept
  }

  private var nowMillis: Int64 { Int64(date.timeIntervalSince1970 * 1000) }

  /// The first class not yet ended (the everyday look).
  var nextClass: RoomWidgetSnapshot.ClassGlance? {
    return snapshot.upcomingClasses
      .filter { $0.endEpochMillis >= nowMillis }
      .min { $0.startEpochMillis < $1.startEpochMillis }
  }

  /// The first class that has not started.
  var upcomingClass: RoomWidgetSnapshot.ClassGlance? {
    return snapshot.upcomingClasses
      .filter { $0.startEpochMillis > nowMillis }
      .min { $0.startEpochMillis < $1.startEpochMillis }
  }

  /// The quests for the day this entry reads. Nil once neither published
  /// list is current, so yesterday's three never linger.
  var quests: [RoomWidgetSnapshot.QuestGlance]? {
    guard let dayEnds = snapshot.questsDayEndsEpochMillis, nowMillis >= dayEnds else {
      return snapshot.incompleteQuests
    }
    if let nextEnds = snapshot.nextDayEndsEpochMillis, nowMillis < nextEnds {
      return snapshot.nextDayQuests ?? []
    }
    return nil
  }

  var classDay: RoomWidgetSnapshot.ClassDay? {
    return snapshot.classDays?.first(where: {
      $0.startsEpochMillis <= nowMillis && nowMillis < $0.nightEndsEpochMillis
    })
  }

  /// The class day while it owns the widget: from its first class's start
  /// (or once every class is kept) until the evening.
  var activeClassDay: RoomWidgetSnapshot.ClassDay? {
    guard let day = classDay, nowMillis < day.eveningStartsEpochMillis else { return nil }
    if day.allKept { return day }
    guard let first = day.classes.first, nowMillis >= first.startEpochMillis else {
      return nil
    }
    return day
  }

  var mode: Mode {
    guard let day = activeClassDay else { return .today }
    return day.allKept ? .allKept : .classes
  }

  /// The newest class that has started and is not kept.
  var focusClass: RoomWidgetSnapshot.DayClass? {
    guard let day = activeClassDay, !day.allKept else { return nil }
    return day.classes.last(where: { $0.startEpochMillis <= nowMillis && !$0.kept })
  }

  func isInSession(_ entry: RoomWidgetSnapshot.DayClass) -> Bool {
    return entry.startEpochMillis <= nowMillis && nowMillis < entry.endEpochMillis
  }

  var classesDone: Bool {
    guard let day = activeClassDay else { return false }
    return nowMillis >= day.lastClassEndEpochMillis
  }

  /// After the last class: at most three rows in time order, the newest
  /// waiting classes first in line for a place, then the newest kept.
  var doneRows: [RoomWidgetSnapshot.DayClass] {
    guard let day = activeClassDay else { return [] }
    if day.classes.count <= 3 { return day.classes }
    let waiting = day.classes.filter { !$0.kept }
    let kept = day.classes.filter { $0.kept }
    let fromWaiting = Array(waiting.suffix(3))
    let fromKept = Array(kept.suffix(max(0, 3 - fromWaiting.count)))
    return (fromWaiting + fromKept).sorted { $0.startEpochMillis < $1.startEpochMillis }
  }

  var lastKept: RoomWidgetSnapshot.DayClass? {
    return activeClassDay?.classes.last(where: { $0.kept })
  }

  /// What comes next: the day's next class, else the first class after it.
  var nextAfter: (title: String, time: String)? {
    if let day = activeClassDay,
       let next = day.classes.first(where: { $0.startEpochMillis > nowMillis }) {
      return (title: next.shortTitle, time: next.startLabel)
    }
    guard let glance = upcomingClass else { return nil }
    return (title: glance.shortTitle ?? glance.courseTitle, time: classTime(glance))
  }

  /// `8:30 AM`, or `WED 8:30 AM` when the class is not on this entry's own
  /// date in the class's zone.
  func classTime(_ glance: RoomWidgetSnapshot.ClassGlance) -> String {
    let start = Date(timeIntervalSince1970: Double(glance.startEpochMillis) / 1000)
    let zone = TimeZone(identifier: glance.timeZoneId)
    let time = DateFormatter()
    time.locale = Locale(identifier: "en_US_POSIX")
    time.dateFormat = "h:mm a"
    if let zone = zone { time.timeZone = zone }
    let clock = time.string(from: start)
    guard let dayKey = glance.dayKey, let dayLabel = glance.dayLabel else { return clock }
    let day = DateFormatter()
    day.locale = Locale(identifier: "en_US_POSIX")
    day.dateFormat = "yyyy-MM-dd"
    if let zone = zone { day.timeZone = zone }
    return day.string(from: date) == dayKey ? clock : "\(dayLabel) \(clock)"
  }

  /// The small widget is one tap: the class to mark, else the class day.
  var smallURL: URL? {
    if let focus = focusClass { return focus.markURL }
    return activeClassDay == nil ? nil : roomOfDaysOpenClassDayURL
  }

  /// The medium widget's background tap; its rows carry their own links.
  var mediumURL: URL? {
    return activeClassDay == nil ? nil : roomOfDaysOpenClassDayURL
  }
}

private struct RoomWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> RoomWidgetEntry {
    RoomWidgetEntry(
      date: Date(),
      snapshot: RoomWidgetSnapshot(
        version: 2,
        generatedAt: "",
        upcomingClasses: [
          .init(
            courseCode: "ECE 202",
            courseTitle: "Signals and Systems",
            startLocal: "2026-09-02T10:00:00-04:00",
            endLocal: "2026-09-02T11:15:00-04:00",
            startEpochMillis: 1_788_357_600_000,
            endEpochMillis: 1_788_362_100_000,
            timeZoneId: "America/New_York"
          )
        ],
        incompleteQuests: [
          .init(id: "one", title: "Review the next lecture"),
          .init(id: "two", title: "25-minute focus session"),
          .init(id: "three", title: "Pack tomorrow's bag"),
        ]
      )
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (RoomWidgetEntry) -> Void) {
    completion(RoomWidgetEntry(date: Date(), snapshot: loadSnapshot()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<RoomWidgetEntry>) -> Void) {
    let now = Date()
    let snapshot = loadSnapshot()
    // Version 3 lists every instant the picture changes at (class starts
    // and ends, the evening, midnight, the night's end); version 2 had
    // only class ends.
    let boundaryMillis = snapshot.boundaries
      ?? snapshot.upcomingClasses.map { $0.endEpochMillis }
    let futureBoundaries = boundaryMillis.compactMap { millis -> Date? in
      let boundary = Date(
        timeIntervalSince1970: Double(millis) / 1000 + 1
      )
      return boundary > now ? boundary : nil
    }
    let entryDates = Array(Set([now] + futureBoundaries)).sorted()
    let entries = entryDates.map {
      RoomWidgetEntry(date: $0, snapshot: snapshot)
    }
    let lastBoundary = entryDates.last ?? now
    let refresh = Calendar.current.date(
      byAdding: .minute,
      value: 15,
      to: lastBoundary
    ) ?? lastBoundary.addingTimeInterval(15 * 60)
    completion(Timeline(entries: entries, policy: .after(refresh)))
  }

  private func loadSnapshot() -> RoomWidgetSnapshot {
    guard let defaults = UserDefaults(suiteName: roomOfDaysAppGroup),
          let json = defaults.string(forKey: roomOfDaysSnapshotKey),
          let data = json.data(using: .utf8),
          let decoded = try? JSONDecoder().decode(RoomWidgetSnapshot.self, from: data),
          (2...3).contains(decoded.version)
    else { return .empty }
    return decoded
  }
}

private enum RoomWidgetPalette {
  static let backdrop = Color(red: 0.075, green: 0.052, blue: 0.043)
  static let panel = Color(red: 0.12, green: 0.082, blue: 0.065)
  static let text = Color(red: 0.95, green: 0.86, blue: 0.71)
  static let secondary = Color(red: 0.68, green: 0.58, blue: 0.48)
  static let honey = Color(red: 0.91, green: 0.65, blue: 0.24)
  static let honeyLight = Color(red: 0.97, green: 0.80, blue: 0.46)
  static let brass = Color(red: 0.55, green: 0.39, blue: 0.22)
  static let ink = Color(red: 0.16, green: 0.10, blue: 0.06)
}

private struct RoomWidgetBackground: ViewModifier {
  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      // iOS 17 applies the system's own content margins; padding on top of
      // them would inset the ledger twice.
      content.containerBackground(for: .widget) {
        LinearGradient(
          colors: [RoomWidgetPalette.panel, RoomWidgetPalette.backdrop],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      }
    } else {
      content
        .padding(16)
        .background(
          LinearGradient(
            colors: [RoomWidgetPalette.panel, RoomWidgetPalette.backdrop],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    }
  }
}

private struct DayLedgerWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: RoomWidgetEntry

  var body: some View {
    Group {
      if family == .systemMedium {
        medium
      } else {
        small
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .modifier(RoomWidgetBackground())
    .widgetURL(family == .systemMedium ? entry.mediumURL : entry.smallURL)
    .privacySensitive()
  }

  // MARK: Small

  @ViewBuilder
  private var small: some View {
    switch entry.mode {
    case .today:
      smallToday
    case .classes:
      smallClasses
    case .allKept:
      smallAllKept
    }
  }

  private var smallToday: some View {
    VStack(alignment: .leading, spacing: 7) {
      eyebrow("NEXT CLASS")
      if let next = entry.nextClass {
        nextClassName(next)
        Spacer(minLength: 2)
        Text(entry.classTime(next))
          .font(.system(size: 13, weight: .semibold, design: .monospaced))
          .foregroundStyle(RoomWidgetPalette.honey)
          .lineLimit(1)
      } else {
        Text("Your day is open")
          .font(.system(size: 19, weight: .semibold, design: .serif))
          .foregroundStyle(RoomWidgetPalette.text)
          .lineLimit(2)
        Spacer()
        Text(questCountLine)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(RoomWidgetPalette.secondary)
      }
    }
  }

  @ViewBuilder
  private var smallClasses: some View {
    if let day = entry.activeClassDay {
      VStack(alignment: .leading, spacing: 0) {
        eyebrow(entry.classesDone ? "\(classNoun(day)) DONE" : day.weekday.uppercased())
        if let focus = entry.focusClass {
          Text(focus.shortTitle)
            .font(.system(size: 16, weight: .semibold, design: .serif))
            .foregroundStyle(RoomWidgetPalette.text)
            .lineLimit(3)
            .padding(.top, 5)
          Text(focusLine(focus, withPlace: false))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(RoomWidgetPalette.secondary)
            .lineLimit(1)
            .padding(.top, 3)
          Spacer(minLength: 4)
          markCapsule(markLabel(focus), fullWidth: true)
        } else if let kept = entry.lastKept {
          Text(kept.shortTitle)
            .font(.system(size: 16, weight: .semibold, design: .serif))
            .foregroundStyle(RoomWidgetPalette.text)
            .lineLimit(3)
            .padding(.top, 5)
          keptMark(xp: kept.keptXp, size: 11, label: nil)
            .padding(.top, 4)
          Spacer(minLength: 4)
          if let next = entry.nextAfter {
            Text("NEXT \(next.time)")
              .font(.system(size: 10, weight: .semibold, design: .monospaced))
              .foregroundStyle(RoomWidgetPalette.secondary)
              .lineLimit(1)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var smallAllKept: some View {
    if let day = entry.activeClassDay {
      VStack(alignment: .leading, spacing: 0) {
        eyebrow(day.weekday.uppercased())
        Text(day.attendedShort ?? "Attended")
          .font(.system(size: 18, weight: .semibold, design: .serif))
          .foregroundStyle(RoomWidgetPalette.text)
          .lineLimit(2)
          .padding(.top, 5)
        Text("+\(day.classXp) XP")
          .font(.system(size: 14, weight: .semibold, design: .monospaced))
          .foregroundStyle(RoomWidgetPalette.honey)
          .padding(.top, 4)
        Spacer(minLength: 4)
        if let next = entry.nextAfter {
          Text("NEXT \(next.time)")
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(RoomWidgetPalette.secondary)
            .lineLimit(1)
        }
      }
    }
  }

  // MARK: Medium

  @ViewBuilder
  private var medium: some View {
    switch entry.mode {
    case .today:
      mediumToday
    case .classes:
      if entry.classesDone {
        mediumDone
      } else {
        mediumBetween
      }
    case .allKept:
      mediumAllKept
    }
  }

  private var mediumToday: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 7) {
        eyebrow("NEXT CLASS")
        if let next = entry.nextClass {
          nextClassName(next)
          Spacer(minLength: 2)
          Text(entry.classTime(next))
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(RoomWidgetPalette.honey)
            .lineLimit(1)
        } else {
          Text("Your day is open")
            .font(.system(size: 18, weight: .semibold, design: .serif))
            .foregroundStyle(RoomWidgetPalette.text)
          Spacer()
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if let quests = entry.quests {
        Rectangle()
          .fill(RoomWidgetPalette.brass.opacity(0.5))
          .frame(width: 1)

        VStack(alignment: .leading, spacing: 7) {
          eyebrow("UP NEXT")
          if quests.isEmpty {
            Text("Nothing waiting")
              .font(.system(size: 14, weight: .semibold, design: .serif))
              .foregroundStyle(RoomWidgetPalette.text)
            Text("The room is yours.")
              .font(.system(size: 11))
              .foregroundStyle(RoomWidgetPalette.secondary)
          } else {
            ForEach(Array(quests.prefix(3).enumerated()), id: \.element.id) { index, quest in
              HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(index + 1)")
                  .font(.system(size: 10, weight: .bold, design: .monospaced))
                  .foregroundStyle(RoomWidgetPalette.honey)
                Text(quest.title)
                  .font(.system(size: 11, weight: .medium))
                  .foregroundStyle(RoomWidgetPalette.text)
                  .lineLimit(1)
              }
            }
          }
          Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  /// Between classes, or in one: the class to mark, and what comes next.
  @ViewBuilder
  private var mediumBetween: some View {
    if let day = entry.activeClassDay {
      VStack(alignment: .leading, spacing: 0) {
        eyebrow("\(day.weekday.uppercased()) · \(classNoun(day))")
        Spacer(minLength: 6)
        if let focus = entry.focusClass {
          Text(focus.shortTitle)
            .font(.system(size: 20, weight: .semibold, design: .serif))
            .foregroundStyle(RoomWidgetPalette.text)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
          Text(focusLine(focus, withPlace: true))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(RoomWidgetPalette.secondary)
            .lineLimit(1)
            .padding(.top, 3)
        } else if let kept = entry.lastKept {
          Text(kept.shortTitle)
            .font(.system(size: 20, weight: .semibold, design: .serif))
            .foregroundStyle(RoomWidgetPalette.text)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
          keptMark(xp: kept.keptXp, size: 11, label: "Attended")
            .padding(.top, 3)
        }
        Spacer(minLength: 6)
        HStack(alignment: .bottom, spacing: 10) {
          nextBlock
          Spacer(minLength: 0)
          if let focus = entry.focusClass, let url = focus.markURL {
            Link(destination: url) {
              markCapsule(markLabel(focus), fullWidth: false)
            }
          }
        }
      }
    }
  }

  /// After the last class: the day's classes as ledger rows. Every waiting
  /// row is its own mark link; the newest carries the one bright control.
  @ViewBuilder
  private var mediumDone: some View {
    if let day = entry.activeClassDay {
      VStack(alignment: .leading, spacing: 0) {
        eyebrow("\(day.weekday.uppercased()) · \(classNoun(day)) DONE")
        Spacer(minLength: 6)
        VStack(alignment: .leading, spacing: rowSpacing) {
          ForEach(entry.doneRows) { row in
            doneRow(row)
          }
        }
        Spacer(minLength: 6)
        if let next = entry.nextAfter {
          HStack(spacing: 8) {
            Text("NEXT \(next.time)")
              .font(.system(size: 10, weight: .semibold, design: .monospaced))
              .foregroundStyle(RoomWidgetPalette.secondary)
              .lineLimit(1)
              .layoutPriority(1)
            Text(next.title)
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(RoomWidgetPalette.text)
              .lineLimit(1)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var mediumAllKept: some View {
    if let day = entry.activeClassDay {
      VStack(alignment: .leading, spacing: 0) {
        eyebrow("\(day.weekday.uppercased()) · \(classNoun(day))")
        Spacer(minLength: 6)
        Text(day.attendedShort ?? "Attended")
          .font(.system(size: 20, weight: .semibold, design: .serif))
          .foregroundStyle(RoomWidgetPalette.text)
          .lineLimit(1)
        Text("+\(day.classXp) XP")
          .font(.system(size: 13, weight: .semibold, design: .monospaced))
          .foregroundStyle(RoomWidgetPalette.honey)
          .padding(.top, 3)
        Spacer(minLength: 6)
        nextBlock
      }
    }
  }

  // MARK: Pieces

  /// The everyday look leads with the class's name, its code beneath.
  private func nextClassName(_ next: RoomWidgetSnapshot.ClassGlance) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(next.shortTitle ?? next.courseTitle)
        .font(.system(size: 16, weight: .semibold, design: .serif))
        .foregroundStyle(RoomWidgetPalette.text)
        .lineLimit(3)
      Text(next.courseCode)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(RoomWidgetPalette.secondary)
        .lineLimit(1)
    }
  }

  @ViewBuilder
  private var nextBlock: some View {
    if let next = entry.nextAfter {
      VStack(alignment: .leading, spacing: 2) {
        Text("NEXT \(next.time)")
          .font(.system(size: 10, weight: .semibold, design: .monospaced))
          .foregroundStyle(RoomWidgetPalette.secondary)
          .lineLimit(1)
        Text(next.title)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(RoomWidgetPalette.text)
          .lineLimit(1)
      }
    }
  }

  @ViewBuilder
  private func doneRow(_ row: RoomWidgetSnapshot.DayClass) -> some View {
    if !row.kept, let url = row.markURL {
      Link(destination: url) {
        doneRowContent(row)
      }
    } else {
      doneRowContent(row)
    }
  }

  private func doneRowContent(_ row: RoomWidgetSnapshot.DayClass) -> some View {
    HStack(spacing: 0) {
      Text(row.startLabel)
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(RoomWidgetPalette.secondary)
        .lineLimit(1)
        .frame(width: 50, alignment: .leading)
        .padding(.trailing, 8)
      Text(row.shortTitle)
        .font(.system(size: 14, weight: .semibold, design: .serif))
        .foregroundStyle(RoomWidgetPalette.text)
        .lineLimit(1)
        .minimumScaleFactor(0.9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 6)
      rowTrailing(row)
    }
    .frame(height: 24)
  }

  @ViewBuilder
  private func rowTrailing(_ row: RoomWidgetSnapshot.DayClass) -> some View {
    if row.kept {
      keptMark(xp: row.keptXp, size: 10, label: nil)
    } else if row.occurrenceKey == entry.focusClass?.occurrenceKey {
      markCapsule("I WAS THERE", fullWidth: false, compact: true)
    } else {
      // A quiet dim dot: waiting, never a hollow socket.
      Circle()
        .fill(RoomWidgetPalette.secondary.opacity(0.45))
        .frame(width: 6, height: 6)
        .padding(.trailing, 4)
    }
  }

  private func keptMark(xp: Int, size: CGFloat, label: String?) -> some View {
    HStack(spacing: 4) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: size + 1))
        .foregroundStyle(RoomWidgetPalette.honey)
      if let label = label {
        Text(label)
          .font(.system(size: size, weight: .medium))
          .foregroundStyle(RoomWidgetPalette.secondary)
          .padding(.trailing, 2)
      }
      Text("+\(xp) XP")
        .font(.system(size: size, weight: .semibold, design: .monospaced))
        .foregroundStyle(RoomWidgetPalette.honey)
    }
  }

  private func markCapsule(_ label: String, fullWidth: Bool, compact: Bool = false) -> some View {
    let size: CGFloat = compact ? 9.5 : 10.5
    let tracking: CGFloat = compact ? 0.6 : 1
    let horizontal: CGFloat = compact ? 9 : 12
    let vertical: CGFloat = compact ? 5 : 7
    let maxWidth: CGFloat? = fullWidth ? CGFloat.infinity : nil
    return Text(label)
      .font(.system(size: size, weight: .bold, design: .monospaced))
      .tracking(tracking)
      .foregroundStyle(RoomWidgetPalette.ink)
      .lineLimit(1)
      .padding(.horizontal, horizontal)
      .padding(.vertical, vertical)
      .frame(maxWidth: maxWidth)
      .background(
        Capsule().fill(
          LinearGradient(
            colors: [RoomWidgetPalette.honeyLight, RoomWidgetPalette.honey],
            startPoint: .top,
            endPoint: .bottom
          )
        )
      )
      .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
      .shadow(color: RoomWidgetPalette.honey.opacity(0.35), radius: 6)
  }

  private var rowSpacing: CGFloat {
    return entry.doneRows.count > 2 ? 4 : 8
  }

  private func classNoun(_ day: RoomWidgetSnapshot.ClassDay) -> String {
    return day.classes.count == 1 ? "CLASS" : "CLASSES"
  }

  private func markLabel(_ focus: RoomWidgetSnapshot.DayClass) -> String {
    return entry.isInSession(focus) ? "I'M HERE" : "I WAS THERE"
  }

  private func focusLine(_ focus: RoomWidgetSnapshot.DayClass, withPlace: Bool) -> String {
    let when = entry.isInSession(focus) ? "Until \(focus.endLabel)" : "Ended \(focus.endLabel)"
    return withPlace && !focus.place.isEmpty ? "\(when) · \(focus.place)" : when
  }

  private func eyebrow(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 9, weight: .bold))
      .tracking(1.2)
      .foregroundStyle(RoomWidgetPalette.honey)
      .lineLimit(1)
  }

  private var questCountLine: String {
    guard let quests = entry.quests else { return "" }
    let count = quests.count
    return count == 0 ? "Nothing waiting" : "\(count) quest\(count == 1 ? "" : "s") waiting"
  }
}

private struct DayLedgerWidget: Widget {
  let kind = "DayLedgerWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: RoomWidgetProvider()) { entry in
      DayLedgerWidgetView(entry: entry)
    }
    .configurationDisplayName("Day Ledger")
    .description("Your classes, the next one and up to three quests, kept private on this device.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct RoomOfDaysWidgets: WidgetBundle {
  var body: some Widget {
    DayLedgerWidget()
  }
}
