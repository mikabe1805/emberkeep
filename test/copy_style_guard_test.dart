import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

/// Holds the 2026-10 copy sweep: Mika named the em dash as an AI tell, so no
/// string literal under lib/ may carry one. Raw strings (regex character
/// classes) and comments are not copy and are ignored.
///
/// A few files belong to other work in flight and still hold em dashes. Each
/// keeps a ceiling that may only go down; when a file reaches zero, delete its
/// line here.
const _pendingCeilings = <String, int>{
  'lib/screens/quests.dart': 20,
  'lib/screens/shell.dart': 6,
  'lib/engine.dart': 4,
  'lib/storage.dart': 3,
  'lib/widgets/routine_flows.dart': 4,
  'lib/screens/calendar.dart': 1,
  'lib/academic_calendar/import/academic_schedule_ics_import.dart': 1,
  'lib/academic_calendar/widgets/academic_schedule_import_dialog.dart': 2,
  // The ladder lookup key matches the seed quest title in shell.dart; both
  // change together.
  'lib/content/ladders.dart': 1,
};

void main() {
  test('no em dash in a lib/ string literal', () {
    final offenders = <String>[];
    final overCeiling = <String>[];
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty);
    for (final file in files) {
      final path = file.path.replaceAll(r'\', '/');
      final hits = <String>[
        for (final literal in dartStringLiterals(file.readAsStringSync()))
          if (!literal.raw && literal.text.contains('—'))
            '$path:${literal.line}  ${literal.text.trim()}',
      ];
      if (hits.isEmpty) continue;
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
