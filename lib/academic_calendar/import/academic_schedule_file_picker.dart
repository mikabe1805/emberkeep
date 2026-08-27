import 'dart:convert';

import 'package:file_selector/file_selector.dart';

final class AcademicScheduleImportSource {
  const AcademicScheduleImportSource({
    required this.name,
    required this.contents,
  });

  final String name;
  final String contents;
}

abstract interface class AcademicScheduleFilePicker {
  Future<AcademicScheduleImportSource?> pick();
}

final class PlatformAcademicScheduleFilePicker
    implements AcademicScheduleFilePicker {
  const PlatformAcademicScheduleFilePicker();

  static const maxBytes = 2 * 1024 * 1024;
  static const _calendarFiles = XTypeGroup(
    label: 'Calendar files',
    extensions: <String>['ics'],
    mimeTypes: <String>['text/calendar'],
    uniformTypeIdentifiers: <String>['com.apple.ical.ics'],
  );

  @override
  Future<AcademicScheduleImportSource?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_calendarFiles],
      confirmButtonText: 'Choose schedule',
    );
    if (file == null) return null;

    final normalizedName = file.name.trim();
    if (!normalizedName.toLowerCase().endsWith('.ics')) {
      throw const FormatException('Choose an .ics calendar file.');
    }

    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw const FormatException(
        'That calendar file is too large to review safely.',
      );
    }

    late final String contents;
    try {
      contents = utf8.decode(bytes);
    } on FormatException {
      throw const FormatException('That calendar file is not valid UTF-8.');
    }
    return AcademicScheduleImportSource(
      name: normalizedName.isEmpty ? 'class-schedule.ics' : normalizedName,
      contents: contents.startsWith('\uFEFF')
          ? contents.substring(1)
          : contents,
    );
  }
}
