import SwiftUI
import WidgetKit

private let roomOfDaysAppGroup = "group.com.mikabe.emberkeep"
private let roomOfDaysSnapshotKey = "roomOfDaysWidgetSnapshotV2"
private let roomOfDaysOpenClassDayURL = URL(string: "roomofdays://class-day")

// The view logic below is mirrored line for line in Dart
// (test/home_widgets/day_ledger_mirror.dart), where it is tested and
// rendered (test/design_renders/day_ledger_widget_mock.dart). Change all
// three together.

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
    // Present only while the app's board keeps classes from links.
    var markAllUrl: String? = nil
    var recordLine: String? = nil
    let classes: [DayClass]

    var markAllURL: URL? { markAllUrl.flatMap { URL(string: $0) } }
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
    // Present only while the app's board keeps classes from links.
    var markUrl: String? = nil
    // Absent (true) for a class; false for an optional meeting (office hours).
    var countsTowardDay: Bool? = nil

    var id: String { occurrenceKey }
    var markURL: URL? { markUrl.flatMap { URL(string: $0) } }
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

  /// The one quiet line the evening adds under the everyday look.
  enum EveningLine {
    case markAll
    case waiting
    case record
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

  /// The newest class of any kind that has started and is not kept. A day
  /// whose counted classes are all kept still offers a started office hour.
  var focusClass: RoomWidgetSnapshot.DayClass? {
    guard let day = activeClassDay else { return nil }
    return day.classes.last(where: { $0.startEpochMillis <= nowMillis && !$0.kept })
  }

  var mode: Mode {
    guard let day = activeClassDay else { return .today }
    return day.allKept && focusClass == nil ? .allKept : .classes
  }

  func isInSession(_ entry: RoomWidgetSnapshot.DayClass) -> Bool {
    return entry.startEpochMillis <= nowMillis && nowMillis < entry.endEpochMillis
  }

  var classesDone: Bool {
    guard let day = activeClassDay else { return false }
    return nowMillis >= day.lastClassEndEpochMillis
  }

  /// Classes of the active day that have ended and are not kept.
  var waitingClasses: [RoomWidgetSnapshot.DayClass] {
    guard let day = activeClassDay else { return [] }
    return day.classes.filter { $0.endEpochMillis <= nowMillis && !$0.kept }
  }

  /// After the last class, with two or more waiting: one control for all.
  var markAllURL: URL? {
    guard classesDone, waitingClasses.count >= 2 else { return nil }
    return activeClassDay?.markAllURL
  }

  var markAllLabel: String {
    return RoomWidgetEntry.markAllLabel(day: activeClassDay, waiting: waitingClasses.count)
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

  /// The NEXT line gives way when three rows and the mark-all control fill
  /// the medium widget.
  var showsNextAfterRows: Bool {
    return markAllURL == nil || doneRows.count < 3
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

  /// The class day's evening, until its night ends at 04:00: the everyday
  /// look, with the day's record or a class still to mark in one quiet line.
  var eveningDay: RoomWidgetSnapshot.ClassDay? {
    guard let day = classDay, nowMillis >= day.eveningStartsEpochMillis else { return nil }
    return day
  }

  /// The evening's counted classes that ended and are not kept, oldest
  /// first. An optional meeting (office hours) is left to the board, so it
  /// never crowds out the day's record.
  var eveningWaiting: [RoomWidgetSnapshot.DayClass] {
    guard let day = eveningDay else { return [] }
    return day.classes.filter {
      $0.endEpochMillis <= nowMillis && !$0.kept && ($0.countsTowardDay ?? true)
    }
  }

  var eveningLine: EveningLine? {
    guard let day = eveningDay else { return nil }
    let waiting = eveningWaiting
    if waiting.count >= 2 && day.markAllURL != nil { return .markAll }
    // A control with nothing to press is not drawn: without a mark link the
    // line gives way to the record.
    if let newest = waiting.last, newest.markURL != nil { return .waiting }
    if day.recordLine != nil { return .record }
    return nil
  }

  var eveningMarkAllLabel: String {
    return RoomWidgetEntry.markAllLabel(day: eveningDay, waiting: eveningWaiting.count)
  }

  /// `I WENT TO BOTH` only for a day of exactly two classes, both waiting;
  /// otherwise `I WENT TO ALL`: never a count of what waits.
  private static func markAllLabel(day: RoomWidgetSnapshot.ClassDay?, waiting: Int) -> String {
    if let day = day, day.classes.count == 2, waiting == 2 { return "I WENT TO BOTH" }
    return "I WENT TO ALL"
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

  /// The small widget is one tap: the newest class to mark, else the class
  /// day while it has something to show. Mark-all lives on the medium widget
  /// and the board, as a quiet row under the newest class.
  var smallURL: URL? {
    if let focus = focusClass, let url = focus.markURL { return url }
    return openURL
  }

  /// The medium widget's background tap; only its control marks.
  var mediumURL: URL? {
    return openURL
  }

  /// The class day while it owns the widget, and in its evening while there
  /// is a record or a class still to mark; otherwise the plain app.
  private var openURL: URL? {
    if activeClassDay != nil { return roomOfDaysOpenClassDayURL }
    return eveningLine == nil ? nil : roomOfDaysOpenClassDayURL
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
  // The board's brass plate and check ring, muted for the home screen.
  static let brassLight = Color(red: 0.859, green: 0.741, blue: 0.533)
  static let brassFace = Color(red: 0.773, green: 0.635, blue: 0.447)
  static let brassEdge = Color(red: 0.475, green: 0.314, blue: 0.169)
  static let brassDeep = Color(red: 0.298, green: 0.184, blue: 0.075)
  static let brassWireDark = Color(red: 0.478, green: 0.298, blue: 0.141)
  static let brassWireMid = Color(red: 0.584, green: 0.376, blue: 0.180)
  static let brassWireLight = Color(red: 0.890, green: 0.745, blue: 0.486)
  static let brassWireHot = Color(red: 0.941, green: 0.839, blue: 0.612)
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

/// The board's check ring at widget size, in brass wire, never a filled disc.
/// Kept: the bright ring with its edge and tick. Waiting: the same circle,
/// thin and empty, still to be filled. It is drawn only beside a control that can
/// check it; with nothing to press the row uses a plain dim dot instead.
private struct ClassRing: View {
  let kept: Bool
  let size: CGFloat

  private var wire: AngularGradient {
    AngularGradient(
      gradient: Gradient(colors: [
        RoomWidgetPalette.brassWireDark,
        RoomWidgetPalette.brassWireLight,
        RoomWidgetPalette.brassWireMid,
        RoomWidgetPalette.brassWireHot,
        RoomWidgetPalette.brassWireDark,
      ]),
      center: .center
    )
  }

  var body: some View {
    let line = max(1.2, size * 0.075)
    return ZStack {
      if kept {
        Circle()
          .stroke(RoomWidgetPalette.brassEdge, lineWidth: line * 1.6)
          .padding(size * 0.11)
        Circle()
          .stroke(wire, lineWidth: line)
          .padding(size * 0.11)
        ClassRingTick()
          .stroke(
            RoomWidgetPalette.brassLight,
            style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round)
          )
      } else {
        // The same circle, whole and thin, with no tick: an empty place the
        // control beside it will fill. No gap and no clasp, so it can never
        // read as a reload arrow, and no tick, so it can never read as kept.
        Circle()
          .stroke(wire, lineWidth: line * 0.9)
          .opacity(0.8)
          .padding(size * 0.11)
      }
    }
    .frame(width: size, height: size)
  }
}

private struct ClassRingTick: Shape {
  func path(in rect: CGRect) -> Path {
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      return CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
    }
    var path = Path()
    path.move(to: point(0.29, 0.51))
    path.addLine(to: point(0.44, 0.65))
    path.addLine(to: point(0.72, 0.35))
    return path
  }
}

/// A plate with its four corners cut, as the board's brass plate is.
private struct ChamferedPlate: InsettableShape {
  var cut: CGFloat = 4.5
  var insetAmount: CGFloat = 0

  func path(in rect: CGRect) -> Path {
    let box = rect.insetBy(dx: insetAmount, dy: insetAmount)
    let corner = min(cut, box.height / 2, box.width / 2)
    var path = Path()
    path.move(to: CGPoint(x: box.minX + corner, y: box.minY))
    path.addLine(to: CGPoint(x: box.maxX - corner, y: box.minY))
    path.addLine(to: CGPoint(x: box.maxX, y: box.minY + corner))
    path.addLine(to: CGPoint(x: box.maxX, y: box.maxY - corner))
    path.addLine(to: CGPoint(x: box.maxX - corner, y: box.maxY))
    path.addLine(to: CGPoint(x: box.minX + corner, y: box.maxY))
    path.addLine(to: CGPoint(x: box.minX, y: box.maxY - corner))
    path.addLine(to: CGPoint(x: box.minX, y: box.minY + corner))
    path.closeSubpath()
    return path
  }

  func inset(by amount: CGFloat) -> ChamferedPlate {
    var plate = self
    plate.insetAmount += amount
    return plate
  }
}

private struct DayLedgerWidgetView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.dynamicTypeSize) private var typeSize
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

  /// Small text follows the reader's text size a little, up to a quarter
  /// larger; titles keep their size so the ledger still fits.
  private var typeScale: CGFloat {
    switch typeSize {
    case .xSmall, .small, .medium, .large:
      return 1
    case .xLarge:
      return 1.06
    case .xxLarge:
      return 1.12
    case .xxxLarge:
      return 1.18
    default:
      return 1.24
    }
  }

  private func scaled(_ size: CGFloat) -> CGFloat {
    return size * typeScale
  }

  /// The everyday look's eyebrows and numerals are honey; on a class day
  /// (any time its night has not ended) they go quiet, so the one lit thing
  /// is the next class's time or the control, never six honey items at once.
  private var calmTint: Color {
    return entry.classDay != nil ? RoomWidgetPalette.secondary : RoomWidgetPalette.honey
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
      eyebrow("NEXT CLASS", color: calmTint)
      if let next = entry.nextClass {
        nextClassName(next, compact: false)
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
        eyebrow(
          entry.classesDone ? "\(classNoun(day)) DONE" : day.weekday.uppercased(),
          color: RoomWidgetPalette.secondary
        )
        if let focus = entry.focusClass {
          // The small widget gives the title its full width (the word that
          // tells a lab from its lecture is often the last one); its whole
          // surface is the control, so it needs no ring to point at it.
          Text(focus.shortTitle)
            .font(.system(size: 16, weight: .semibold, design: .serif))
            .foregroundStyle(RoomWidgetPalette.text)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.top, 5)
          Text(focusLine(focus, withPlace: false))
            .font(.system(size: scaled(11), weight: .medium))
            .foregroundStyle(RoomWidgetPalette.secondary)
            .lineLimit(1)
            .padding(.top, 3)
          Spacer(minLength: 4)
          if focus.markURL != nil {
            markCapsule(markLabel(focus), fullWidth: true)
          } else if let next = entry.nextAfter {
            nextTime(next.time)
          }
        } else if let kept = entry.lastKept {
          Text(kept.shortTitle)
            .font(.system(size: 16, weight: .semibold, design: .serif))
            .foregroundStyle(RoomWidgetPalette.text)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.top, 5)
          HStack(spacing: 5) {
            ClassRing(kept: true, size: 14)
            Text("+\(kept.keptXp) XP")
              .font(.system(size: scaled(11), weight: .semibold, design: .monospaced))
              .foregroundStyle(RoomWidgetPalette.honey)
              .lineLimit(1)
          }
          .padding(.top, 4)
          Spacer(minLength: 4)
          if let next = entry.nextAfter {
            nextTime(next.time)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var smallAllKept: some View {
    if let day = entry.activeClassDay {
      VStack(alignment: .leading, spacing: 0) {
        eyebrow(day.weekday.uppercased(), color: RoomWidgetPalette.secondary)
        Text(day.attendedShort ?? "Attended")
          .font(.system(size: 18, weight: .semibold, design: .serif))
          .foregroundStyle(RoomWidgetPalette.text)
          .lineLimit(2)
          .padding(.top, 5)
        HStack(spacing: 5) {
          ClassRing(kept: true, size: 15)
          Text("+\(day.classXp) XP")
            .font(.system(size: scaled(14), weight: .semibold, design: .monospaced))
            .foregroundStyle(RoomWidgetPalette.honey)
            .lineLimit(1)
        }
        .padding(.top, 4)
        Spacer(minLength: 4)
        if let next = entry.nextAfter {
          nextTime(next.time)
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
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 14) {
        VStack(alignment: .leading, spacing: 7) {
          eyebrow("NEXT CLASS", color: calmTint)
          if let next = entry.nextClass {
            nextClassName(next, compact: entry.eveningLine != nil)
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
            eyebrow("UP NEXT", color: calmTint)
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
                    .foregroundStyle(calmTint)
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
      if let line = entry.eveningLine, let day = entry.eveningDay {
        eveningFooter(line, day: day)
      }
    }
  }

  /// Between classes, or in one: the class to mark with its ring and its
  /// control directly under it, then what comes next as one quiet line.
  @ViewBuilder
  private var mediumBetween: some View {
    if let day = entry.activeClassDay {
      VStack(alignment: .leading, spacing: 0) {
        eyebrow("\(day.weekday.uppercased()) · \(classNoun(day))", color: RoomWidgetPalette.secondary)
        Spacer(minLength: 6)
        if let focus = entry.focusClass {
          HStack(alignment: .center, spacing: 10) {
            // The ring only beside a control that can check it.
            if focus.markURL != nil {
              ClassRing(kept: false, size: 26)
            } else {
              Circle()
                .fill(RoomWidgetPalette.secondary.opacity(0.45))
                .frame(width: 6, height: 6)
                .frame(width: 26, height: 26)
            }
            VStack(alignment: .leading, spacing: 3) {
              Text(focus.shortTitle)
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(RoomWidgetPalette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
              Text(focusLine(focus, withPlace: true))
                .font(.system(size: scaled(11), weight: .medium))
                .foregroundStyle(RoomWidgetPalette.secondary)
                .lineLimit(1)
            }
          }
          if let url = focus.markURL {
            Link(destination: url) {
              markCapsule(markLabel(focus), fullWidth: false)
            }
            .padding(.leading, 36)
            .padding(.top, 8)
          }
        } else if let kept = entry.lastKept {
          HStack(alignment: .center, spacing: 10) {
            ClassRing(kept: true, size: 26)
            VStack(alignment: .leading, spacing: 3) {
              Text(kept.shortTitle)
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(RoomWidgetPalette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
              HStack(spacing: 6) {
                Text("Attended")
                  .font(.system(size: scaled(11), weight: .medium))
                  .foregroundStyle(RoomWidgetPalette.secondary)
                Text("+\(kept.keptXp) XP")
                  .font(.system(size: scaled(11), weight: .semibold, design: .monospaced))
                  .foregroundStyle(RoomWidgetPalette.honey)
              }
              .lineLimit(1)
            }
          }
        }
        Spacer(minLength: 6)
        nextLine
      }
    }
  }

  /// After the last class: the day's classes as ledger rows. Only the one
  /// brass control marks; every other tap just opens the class day.
  @ViewBuilder
  private var mediumDone: some View {
    if let day = entry.activeClassDay {
      VStack(alignment: .leading, spacing: 0) {
        eyebrow("\(day.weekday.uppercased()) · \(classNoun(day)) DONE", color: RoomWidgetPalette.secondary)
        Spacer(minLength: tightRows ? 3 : 6)
        VStack(alignment: .leading, spacing: rowSpacing) {
          ForEach(entry.doneRows) { row in
            doneRow(row)
          }
        }
        if let url = entry.markAllURL {
          HStack(spacing: 0) {
            Spacer(minLength: 0)
            Link(destination: url) {
              quietControl(entry.markAllLabel)
            }
          }
          .padding(.top, tightRows ? 4 : 6)
        }
        Spacer(minLength: tightRows ? 3 : 6)
        if entry.showsNextAfterRows {
          nextLine
        }
      }
    }
  }

  @ViewBuilder
  private var mediumAllKept: some View {
    if let day = entry.activeClassDay {
      VStack(alignment: .leading, spacing: 0) {
        eyebrow("\(day.weekday.uppercased()) · \(classNoun(day))", color: RoomWidgetPalette.secondary)
        Spacer(minLength: 6)
        HStack(alignment: .center, spacing: 10) {
          ClassRing(kept: true, size: 26)
          VStack(alignment: .leading, spacing: 3) {
            Text(day.attendedShort ?? "Attended")
              .font(.system(size: 20, weight: .semibold, design: .serif))
              .foregroundStyle(RoomWidgetPalette.text)
              .lineLimit(1)
            Text("+\(day.classXp) XP")
              .font(.system(size: scaled(13), weight: .semibold, design: .monospaced))
              .foregroundStyle(RoomWidgetPalette.honey)
          }
        }
        Spacer(minLength: 6)
        nextLine
      }
    }
  }

  // MARK: Pieces

  /// The everyday look leads with the class's name; the course code is left
  /// to the board (a colon-laden code above a time reads as a second time).
  private func nextClassName(_ next: RoomWidgetSnapshot.ClassGlance, compact: Bool) -> some View {
    Text(next.shortTitle ?? next.courseTitle)
      .font(.system(size: 16, weight: .semibold, design: .serif))
      .foregroundStyle(RoomWidgetPalette.text)
      .lineLimit(compact ? 2 : 4)
  }

  /// One quiet line: `NEXT 2:00 PM  Discrete Structures II`.
  @ViewBuilder
  private var nextLine: some View {
    if let next = entry.nextAfter {
      HStack(spacing: 8) {
        // At a larger text size the word NEXT goes (the time and the day
        // already say it) so the title keeps the word that tells a lab from
        // its lecture.
        Text(typeScale > 1 ? next.time : "NEXT \(next.time)")
          .font(.system(size: scaled(10.5), weight: .semibold, design: .monospaced))
          .foregroundStyle(RoomWidgetPalette.secondary)
          .lineLimit(1)
          .layoutPriority(1)
        Text(next.title)
          .font(.system(size: scaled(11.5), weight: .medium))
          .foregroundStyle(RoomWidgetPalette.secondary)
          .lineLimit(1)
      }
    }
  }

  private func nextTime(_ time: String) -> some View {
    Text(typeScale > 1 ? time : "NEXT \(time)")
      .font(.system(size: scaled(10.5), weight: .semibold, design: .monospaced))
      .foregroundStyle(RoomWidgetPalette.secondary)
      .lineLimit(1)
  }

  /// One ledger row the way the board draws its quiet rows: the mark at
  /// the leading edge (closed ring when kept, the open ring on the one row
  /// the control marks, a quiet dim dot otherwise), the title, then its XP,
  /// its control or its start time.
  private func doneRow(_ row: RoomWidgetSnapshot.DayClass) -> some View {
    HStack(spacing: 0) {
      rowMark(row)
        .frame(width: 16, height: 16)
        .padding(.trailing, 8)
      Text(row.shortTitle)
        .font(.system(size: 14, weight: .semibold, design: .serif))
        .foregroundStyle(
          row.kept || isControlRow(row)
            ? RoomWidgetPalette.text
            : RoomWidgetPalette.text.opacity(0.82)
        )
        .lineLimit(1)
        .minimumScaleFactor(0.9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 6)
      rowTrailing(row)
    }
    .frame(height: rowHeight)
  }

  /// The row whose class the one luminous I WAS THERE marks: the newest.
  private func isControlRow(_ row: RoomWidgetSnapshot.DayClass) -> Bool {
    return row.markURL != nil
      && row.occurrenceKey == entry.focusClass?.occurrenceKey
  }

  @ViewBuilder
  private func rowMark(_ row: RoomWidgetSnapshot.DayClass) -> some View {
    if row.kept {
      ClassRing(kept: true, size: 15)
    } else if isControlRow(row) {
      ClassRing(kept: false, size: 15)
    } else {
      // A quiet dim dot: waiting, never a hollow socket.
      Circle()
        .fill(RoomWidgetPalette.secondary.opacity(0.45))
        .frame(width: 6, height: 6)
    }
  }

  @ViewBuilder
  private func rowTrailing(_ row: RoomWidgetSnapshot.DayClass) -> some View {
    if row.kept {
      Text("+\(row.keptXp) XP")
        .font(.system(size: scaled(10.5), weight: .semibold, design: .monospaced))
        .foregroundStyle(RoomWidgetPalette.secondary)
        .lineLimit(1)
    } else if isControlRow(row), let url = row.markURL {
      Link(destination: url) {
        markCapsule("I WAS THERE", fullWidth: false, compact: true)
      }
    } else {
      Text(row.startLabel)
        .font(.system(size: scaled(10.5), weight: .medium, design: .monospaced))
        .foregroundStyle(RoomWidgetPalette.secondary)
        .lineLimit(1)
    }
  }

  /// The evening's one quiet line under the everyday look: the day's
  /// record, or a class still to mark with a quiet outlined control.
  private func eveningFooter(
    _ line: RoomWidgetEntry.EveningLine,
    day: RoomWidgetSnapshot.ClassDay
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Rectangle()
        .fill(RoomWidgetPalette.brass.opacity(0.35))
        .frame(height: 0.5)
      HStack(spacing: 7) {
        switch line {
        case .record:
          ClassRing(kept: true, size: 13)
          Text(day.recordLine ?? "")
            .font(.system(size: scaled(11), weight: .medium))
            .foregroundStyle(RoomWidgetPalette.secondary)
            .lineLimit(1)
          Spacer(minLength: 4)
          Text("+\(day.classXp) XP")
            .font(.system(size: scaled(10.5), weight: .semibold, design: .monospaced))
            .foregroundStyle(RoomWidgetPalette.secondary)
            .lineLimit(1)
        case .markAll:
          ClassRing(kept: false, size: 13)
          Text("\(day.weekday)\u{2019}s classes")
            .font(.system(size: scaled(11), weight: .medium))
            .foregroundStyle(RoomWidgetPalette.text)
            .lineLimit(1)
          Spacer(minLength: 4)
          if let url = day.markAllURL {
            Link(destination: url) {
              quietControl(entry.eveningMarkAllLabel)
            }
          }
        case .waiting:
          if let waiting = entry.eveningWaiting.last {
            ClassRing(kept: false, size: 13)
            Text(waiting.shortTitle)
              .font(.system(size: scaled(11), weight: .medium))
              .foregroundStyle(RoomWidgetPalette.text)
              .lineLimit(1)
            Spacer(minLength: 4)
            if let url = waiting.markURL {
              Link(destination: url) {
                quietControl("I WAS THERE")
              }
            }
          }
        }
      }
    }
    .padding(.top, 8)
  }

  /// A control that marks without owning the evening: outlined, not lit.
  private func quietControl(_ label: String) -> some View {
    Text(label)
      .font(.system(size: scaled(10), weight: .bold, design: .monospaced))
      .tracking(0.6)
      .foregroundStyle(RoomWidgetPalette.brassLight)
      .lineLimit(1)
      .fixedSize()
      .padding(.horizontal, 9)
      .padding(.vertical, 4)
      .overlay(ChamferedPlate().strokeBorder(RoomWidgetPalette.brass, lineWidth: 1))
  }

  /// The one luminous control: the board's brushed brass, muted, with a
  /// darker rim and an under-lip. No glow.
  private func markCapsule(_ label: String, fullWidth: Bool, compact: Bool = false) -> some View {
    let size: CGFloat = scaled(compact ? 11 : 11.5)
    let tracking: CGFloat = compact ? 0.4 : 0.9
    // A full-width plate centres its label; it needs no side room of its own.
    let horizontal: CGFloat = compact ? 9 : (fullWidth ? 8 : 13)
    let vertical: CGFloat = compact ? 5 : 7
    let maxWidth: CGFloat? = fullWidth ? CGFloat.infinity : nil
    return Text(label)
      .font(.system(size: size, weight: .bold, design: .monospaced))
      .tracking(tracking)
      .foregroundStyle(RoomWidgetPalette.ink)
      .lineLimit(1)
      .minimumScaleFactor(0.85)
      .padding(.horizontal, horizontal)
      .padding(.vertical, vertical)
      .frame(maxWidth: maxWidth)
      .background(
        ZStack {
          ChamferedPlate()
            .fill(RoomWidgetPalette.brassDeep)
            .offset(y: 1)
          ChamferedPlate()
            .fill(
              LinearGradient(
                colors: [RoomWidgetPalette.brassLight, RoomWidgetPalette.brassFace],
                startPoint: .top,
                endPoint: .bottom
              )
            )
          ChamferedPlate()
            .fill(
              LinearGradient(
                gradient: Gradient(stops: [
                  .init(color: Color.white.opacity(0), location: 0.1),
                  .init(color: Color.white.opacity(0.14), location: 0.3),
                  .init(color: Color.white.opacity(0), location: 0.52),
                ]),
                startPoint: .leading,
                endPoint: .trailing
              )
            )
          ChamferedPlate()
            .strokeBorder(RoomWidgetPalette.brassEdge, lineWidth: 0.75)
        }
      )
  }

  /// Three rows and the mark-all control share the medium widget's height.
  private var tightRows: Bool {
    return entry.markAllURL != nil && entry.doneRows.count > 2
  }

  private var rowHeight: CGFloat {
    return tightRows ? 21 : 24
  }

  private var rowSpacing: CGFloat {
    if tightRows { return 2 }
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

  private func eyebrow(_ text: String, color: Color) -> some View {
    Text(text)
      .font(.system(size: scaled(10), weight: .bold))
      .tracking(1.2)
      .foregroundStyle(color)
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
