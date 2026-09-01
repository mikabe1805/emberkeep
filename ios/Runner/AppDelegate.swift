import Flutter
import UIKit
import UserNotifications
import WidgetKit

/// Retains valid .ics payloads until Flutter explicitly takes them. This
/// covers both a cold open from Files and a warm Share/Open In delivery.
final class AcademicScheduleFileBridge: NSObject, FlutterSceneLifeCycleDelegate {
  static let shared = AcademicScheduleFileBridge()

  private let maxBytes = 2 * 1024 * 1024
  private let maxPendingCount = 4
  private var pending: [[String: String]] = []
  private var channel: FlutterMethodChannel?

  private override init() {}

  func configure(registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "room_of_days/academic_schedule_files",
      binaryMessenger: registrar.messenger()
    )
    self.channel = channel
    registrar.addSceneDelegate(self)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "takeInitialAcademicSchedule" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self, !self.pending.isEmpty else {
        result(nil)
        return
      }
      result(self.pending.removeFirst())
    }
    if !pending.isEmpty {
      channel.invokeMethod("academicScheduleAvailable", arguments: nil)
    }
  }

  @discardableResult
  func receive(url: URL) -> Bool {
    guard url.isFileURL, url.pathExtension.lowercased() == "ics" else {
      return false
    }
    let scoped = url.startAccessingSecurityScopedResource()
    defer {
      if scoped { url.stopAccessingSecurityScopedResource() }
    }
    do {
      let values = try url.resourceValues(forKeys: [.fileSizeKey])
      if let size = values.fileSize, size > maxBytes { return false }
      let data = try Data(contentsOf: url, options: [.mappedIfSafe])
      guard data.count <= maxBytes,
            var contents = String(data: data, encoding: .utf8)
      else { return false }
      if contents.hasPrefix("\u{FEFF}") { contents.removeFirst() }
      if pending.count >= maxPendingCount {
        pending.removeFirst()
      }
      pending.append([
        "name": url.lastPathComponent.isEmpty
          ? "class-schedule.ics"
          : url.lastPathComponent,
        "contents": contents,
      ])
      channel?.invokeMethod("academicScheduleAvailable", arguments: nil)
      return true
    } catch {
      return false
    }
  }

  /// The Flutter scene lifecycle delegate preserves Flutter's own engine and
  /// plugin forwarding while letting this narrow file handler claim only .ics
  /// URLs. It covers both cold launch connection options and warm Open In.
  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let connectionOptions else { return false }
    var handled = false
    for context in connectionOptions.urlContexts {
      handled = receive(url: context.url) || handled
    }
    return handled
  }

  func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) -> Bool {
    var handled = false
    for context in URLContexts {
      handled = receive(url: context.url) || handled
    }
    return handled
  }
}

final class RoomOfDaysWidgetBridge {
  static let shared = RoomOfDaysWidgetBridge()
  static let appGroup = "group.com.mikabe.emberkeep"
  static let snapshotKey = "roomOfDaysWidgetSnapshotV2"

  private init() {}

  func configure(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "room_of_days/home_widget",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "writeSnapshot",
            let arguments = call.arguments as? [String: Any],
            let json = arguments["json"] as? String,
            let defaults = UserDefaults(suiteName: Self.appGroup)
      else {
        result(false)
        return
      }
      defaults.set(json, forKey: Self.snapshotKey)
      WidgetCenter.shared.reloadAllTimelines()
      result(true)
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate =
        self as? UNUserNotificationCenterDelegate
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "AcademicScheduleFileBridge"
    ) {
      AcademicScheduleFileBridge.shared.configure(registrar: registrar)
    }
    let messenger = engineBridge.applicationRegistrar.messenger()
    RoomOfDaysWidgetBridge.shared.configure(messenger: messenger)
  }
}
