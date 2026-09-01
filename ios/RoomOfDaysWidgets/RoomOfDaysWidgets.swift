import SwiftUI
import WidgetKit

private let roomOfDaysAppGroup = "group.com.mikabe.emberkeep"
private let roomOfDaysSnapshotKey = "roomOfDaysWidgetSnapshotV2"

private struct RoomWidgetSnapshot: Decodable {
  let version: Int
  let generatedAt: String
  let upcomingClasses: [ClassGlance]
  let incompleteQuests: [QuestGlance]

  struct ClassGlance: Decodable {
    let courseCode: String
    let courseTitle: String
    let startLocal: String
    let endLocal: String
    let startEpochMillis: Int64
    let endEpochMillis: Int64
    let timeZoneId: String
  }

  struct QuestGlance: Decodable, Identifiable {
    let id: String
    let title: String
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

  var nextClass: RoomWidgetSnapshot.ClassGlance? {
    let nowMillis = Int64(date.timeIntervalSince1970 * 1000)
    return snapshot.upcomingClasses
      .filter { $0.endEpochMillis >= nowMillis }
      .min { $0.startEpochMillis < $1.startEpochMillis }
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
    let futureBoundaries = snapshot.upcomingClasses.compactMap { glance -> Date? in
      let boundary = Date(
        timeIntervalSince1970: Double(glance.endEpochMillis) / 1000 + 1
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
          decoded.version == 2
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
  static let brass = Color(red: 0.55, green: 0.39, blue: 0.22)
}

private struct RoomWidgetBackground: ViewModifier {
  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      content.containerBackground(for: .widget) {
        LinearGradient(
          colors: [RoomWidgetPalette.panel, RoomWidgetPalette.backdrop],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      }
    } else {
      content.background(
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
    .padding(14)
    .modifier(RoomWidgetBackground())
    .privacySensitive()
  }

  private var small: some View {
    VStack(alignment: .leading, spacing: 7) {
      eyebrow("NEXT CLASS")
      if let next = entry.nextClass {
        Text(next.courseCode)
          .font(.system(size: 20, weight: .semibold, design: .serif))
          .foregroundStyle(RoomWidgetPalette.text)
          .lineLimit(1)
        Text(next.courseTitle)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(RoomWidgetPalette.secondary)
          .lineLimit(2)
        Spacer(minLength: 2)
        Text(classTime(next))
          .font(.system(size: 13, weight: .semibold, design: .monospaced))
          .foregroundStyle(RoomWidgetPalette.honey)
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

  private var medium: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 7) {
        eyebrow("NEXT CLASS")
        if let next = entry.nextClass {
          Text(next.courseCode)
            .font(.system(size: 19, weight: .semibold, design: .serif))
            .foregroundStyle(RoomWidgetPalette.text)
            .lineLimit(1)
          Text(next.courseTitle)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(RoomWidgetPalette.secondary)
            .lineLimit(2)
          Spacer(minLength: 2)
          Text(classTime(next))
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(RoomWidgetPalette.honey)
        } else {
          Text("Your day is open")
            .font(.system(size: 18, weight: .semibold, design: .serif))
            .foregroundStyle(RoomWidgetPalette.text)
          Spacer()
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Rectangle()
        .fill(RoomWidgetPalette.brass.opacity(0.5))
        .frame(width: 1)

      VStack(alignment: .leading, spacing: 7) {
        eyebrow("UP NEXT")
        if entry.snapshot.incompleteQuests.isEmpty {
          Text("Nothing waiting")
            .font(.system(size: 14, weight: .semibold, design: .serif))
            .foregroundStyle(RoomWidgetPalette.text)
          Text("The room is yours.")
            .font(.system(size: 11))
            .foregroundStyle(RoomWidgetPalette.secondary)
        } else {
          ForEach(Array(entry.snapshot.incompleteQuests.prefix(3).enumerated()), id: \.element.id) { index, quest in
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

  private func eyebrow(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 9, weight: .bold))
      .tracking(1.2)
      .foregroundStyle(RoomWidgetPalette.honey)
  }

  private var questCountLine: String {
    let count = entry.snapshot.incompleteQuests.count
    return count == 0 ? "Nothing waiting" : "\(count) quest\(count == 1 ? "" : "s") waiting"
  }

  private func classTime(_ next: RoomWidgetSnapshot.ClassGlance) -> String {
    let date = Date(timeIntervalSince1970: Double(next.startEpochMillis) / 1000)
    let time = DateFormatter()
    time.dateFormat = "h:mm a"
    if let zone = TimeZone(identifier: next.timeZoneId) { time.timeZone = zone }
    return time.string(from: date)
  }
}

private struct DayLedgerWidget: Widget {
  let kind = "DayLedgerWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: RoomWidgetProvider()) { entry in
      DayLedgerWidgetView(entry: entry)
    }
    .configurationDisplayName("Day Ledger")
    .description("Your next class and up to three quests, kept private on this device.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct RoomOfDaysWidgets: WidgetBundle {
  var body: some Widget {
    DayLedgerWidget()
  }
}
