import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

/// Holds the 2026-10 copy sweep: Mika named the em dash as an AI tell, so no
/// string literal under lib/ may carry one. Raw strings (regex character
/// classes) and comments are not copy and are ignored.
///
/// A few files belong to other work in flight and still hold em dashes. Each
/// keeps a ceiling: the guard fails when a file passes it. Those files are
/// owned by sibling branches that do not carry this test, so a ceiling above
/// the real count (or a file that moved or reached zero) is printed as a note
/// instead of failing; lower or delete the line here when the note appears,
/// in the same commit that merges the branch.
const _pendingCeilings = <String, int>{
  'lib/screens/quests.dart': 20,
  'lib/screens/shell.dart': 6,
  'lib/engine.dart': 4,
  'lib/storage.dart': 3,
  'lib/widgets/routine_flows.dart': 4,
  'lib/screens/calendar.dart': 1,
  'lib/academic_calendar/import/academic_schedule_ics_import.dart': 1,
  'lib/academic_calendar/widgets/academic_schedule_import_dialog.dart': 2,
  // The workout rungs are saved, not only shown: Quest.ladder keeps them, and
  // a goal plan step keeps its template's displayTitle as actionTitle and
  // questTemplate. GoalAdjustment matches the live quest against that text,
  // so renaming them needs a decode migration in models.dart first (all four
  // rungs together in Quest.ladder, GoalPlanStep.actionTitle and
  // questTemplate.ladder). The lookup key matches the seed quest title in
  // shell.dart and changes with them.
  'lib/content/ladders.dart': 5,
};

/// Every non-raw string literal under lib/ that holds an em dash, by path.
Map<String, List<String>> _emDashLiterals() {
  final files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  expect(files, isNotEmpty);
  final byPath = <String, List<String>>{};
  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    final hits = <String>[
      for (final literal in dartStringLiterals(file.readAsStringSync()))
        if (!literal.raw && literal.text.contains('—'))
          '$path:${literal.line}  ${literal.text.trim()}',
    ];
    if (hits.isNotEmpty) byPath[path] = hits;
  }
  return byPath;
}

void main() {
  test('no em dash in a lib/ string literal', () {
    final offenders = <String>[];
    final overCeiling = <String>[];
    for (final MapEntry(key: path, value: hits) in _emDashLiterals().entries) {
      final ceiling = _pendingCeilings[path];
      if (ceiling == null) {
        offenders.addAll(hits);
      } else if (hits.length > ceiling) {
        overCeiling.add('$path has ${hits.length} (ceiling $ceiling)');
        offenders.addAll(hits);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Rewrite these sentences without an em dash (a period, a comma, '
          'a colon or a middle dot, whichever reads naturally). '
          '${overCeiling.join('; ')}',
    );
  });

  test('ceilings above the real count are reported as a note', () {
    final counts = {
      for (final MapEntry(key: path, value: hits) in _emDashLiterals().entries)
        path: hits.length,
    };
    final slack = <String>[
      for (final MapEntry(key: path, value: ceiling)
          in _pendingCeilings.entries)
        if (!File(path).existsSync())
          '$path no longer exists: delete its ceiling'
        else if ((counts[path] ?? 0) == 0)
          '$path has no em dash left: delete its ceiling'
        else if (counts[path]! < ceiling)
          '$path has ${counts[path]}: lower its ceiling to ${counts[path]}',
    ];
    // A note, not a failure: sibling branches shrink these files without
    // this test, and their merge should not turn CI red for that alone.
    for (final line in slack) {
      // ignore: avoid_print
      print('copy_style_guard note: $line');
    }
    expect(_pendingCeilings.values.every((ceiling) => ceiling > 0), isTrue);
  });

  test('the daily nudge reads as an open door, with no deadline', () {
    // The 9:00 nudge is the one line the app sends unasked. It once read
    // "Your quests are waiting" and "One small win before the day gets away
    // from you."; it stays an invitation. The scan reads every literal in the
    // file, so it holds for LF and CRLF checkouts alike.
    final source = File(
      'lib/platform/notifications_native.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    final copy = [
      for (final literal in dartStringLiterals(source))
        if (!literal.raw) literal.text,
    ];
    final title = copy.indexOf('Your room is open');
    expect(title, isNot(-1));
    expect(
      copy[title + 1],
      'Today’s quests are on the board, ready whenever you are.',
    );
    expect(copy, isNot(contains('Your quests are waiting')));
    expect(
      copy,
      isNot(contains('One small win before the day gets away from you.')),
    );
    final pressure = RegExp(
      r'\b(fail\w*|missed|lost|lose|broke|skipped|waiting|gets away|hurry|'
      r'last chance|before it.s too late)\b',
      caseSensitive: false,
    );
    for (final line in copy) {
      expect(pressure.hasMatch(line), isFalse, reason: line);
    }
  });

  test('the literal scanner sees copy and skips comments and raw strings', () {
    const source = '''
// a comment — not copy
final a = 'one — two';
final b = r"[–—-]";
/* block — comment */
final c = "it's \${x ? 'y — z' : 'w'} fine";
final d = \'\'\'
three — four\'\'\';
''';
    final literals = dartStringLiterals(source);
    final dashed = literals
        .where((l) => !l.raw && l.text.contains('—'))
        .map((l) => l.line)
        .toList();
    expect(dashed, [2, 5, 6]);
    expect(literals.where((l) => l.raw).single.line, 3);
  });
}

class DartStringLiteral {
  const DartStringLiteral(this.line, this.text, {required this.raw});
  final int line;
  final String text;
  final bool raw;
}

/// A small lexer that is good enough for this repository's sources: it skips
/// comments, keeps raw strings marked, and reports interpolated nested
/// literals on their own.
List<DartStringLiteral> dartStringLiterals(String src) {
  final out = <DartStringLiteral>[];
  var line = 1;
  var i = 0;
  final n = src.length;

  bool isIdent(int at) {
    if (at < 0) return false;
    final c = src.codeUnitAt(at);
    return (c >= 48 && c <= 57) ||
        (c >= 65 && c <= 90) ||
        (c >= 97 && c <= 122) ||
        c == 95 ||
        c == 36;
  }

  // Reads one string starting at the quote at [start]. Returns the index after
  // the closing quote.
  int readString(int start, {required bool raw}) {
    final quote = src[start];
    final triple =
        start + 2 < n && src[start + 1] == quote && src[start + 2] == quote;
    final open = triple ? 3 : 1;
    final startLine = line;
    final buffer = StringBuffer();
    var j = start + open;
    while (j < n) {
      final ch = src[j];
      if (triple ? src.startsWith(quote * 3, j) : ch == quote || ch == '\n') {
        break;
      }
      if (ch == '\n') line++;
      if (!raw && ch == r'\') {
        buffer.write(src.substring(j, math.min(j + 2, n)));
        j += 2;
        continue;
      }
      if (!raw && ch == r'$' && j + 1 < n && src[j + 1] == '{') {
        var depth = 1;
        j += 2;
        while (j < n && depth > 0) {
          final c = src[j];
          if (c == '{') {
            depth++;
          } else if (c == '}') {
            depth--;
          } else if (c == "'" || c == '"') {
            j = readString(j, raw: false);
            continue;
          } else if (c == '\n') {
            line++;
          }
          j++;
        }
        buffer.write(r'${}');
        continue;
      }
      buffer.write(ch);
      j++;
    }
    out.add(DartStringLiteral(startLine, buffer.toString(), raw: raw));
    return math.min(j + (triple ? 3 : 1), n);
  }

  while (i < n) {
    final c = src[i];
    if (c == '\n') {
      line++;
      i++;
    } else if (src.startsWith('//', i)) {
      final end = src.indexOf('\n', i);
      i = end < 0 ? n : end;
    } else if (src.startsWith('/*', i)) {
      final end = src.indexOf('*/', i + 2);
      final stop = end < 0 ? n : end + 2;
      line += '\n'.allMatches(src.substring(i, stop)).length;
      i = stop;
    } else if (c == 'r' &&
        i + 1 < n &&
        (src[i + 1] == "'" || src[i + 1] == '"') &&
        !isIdent(i - 1)) {
      i = readString(i + 1, raw: true);
    } else if (c == "'" || c == '"') {
      i = readString(i, raw: false);
    } else {
      i++;
    }
  }
  return out;
}
