/// The seam for the next import slice: reading classes that already sit in
/// this phone's own calendars (iOS EventKit), so a student with an iCloud,
/// Google or Exchange account on the phone never has to find a file or link.
///
/// Not built in this slice. When it is, a small native channel (like the
/// existing file bridge in ios/Runner/AppDelegate.swift) asks for calendar
/// access only after the student taps that way in, reads the chosen
/// calendars for the current term on the device, and hands them over as
/// iCalendar text: one VEVENT per meeting is enough, because the class
/// finder already gathers single meetings into weekly series. The text then
/// goes through the same review as a file or a link. Nothing leaves the
/// phone. iOS 17 needs `requestFullAccessToEvents` and an
/// `NSCalendarsFullAccessUsageDescription` line in Info.plist.
library;

import 'academic_schedule_file_picker.dart';

abstract interface class DeviceCalendarReader {
  /// Reads the phone's calendars as one iCalendar text, asking for access
  /// first if needed. Returns null when the student declines or picks
  /// nothing. Throws [FormatException] with a showable message otherwise.
  Future<AcademicScheduleImportSource?> read();
}
