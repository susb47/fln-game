// Writes the voice recording script: every sentence, word group and number
// the characters can say, one row per clip, with the file name to save it as.
//
// Run:  flutter test tool/voice_script_test.dart
// Out:  docs/voice_script.csv  (open in Excel or Google Sheets)
//
// Rows already in the CSV keep their file names, so re-running after adding
// levels or dialogue only appends new rows. See docs/VOICES.md.
import 'dart:io';
import 'dart:math';

import 'package:fln_game/audio/voice_pack.dart';
import 'package:fln_game/bn.dart';
import 'package:fln_game/data/cast.dart';
import 'package:fln_game/logic/puzzle_factory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers.dart';

const out = 'docs/voice_script.csv';

/// Questions sampled per level. Enough to meet every number a level can use.
const samples = 400;

void main() {
  test('write the voice recording script', () {
    final content = loadContent();
    final cast = Cast.parse(
      charactersJson: File(charactersFile).readAsStringSync(),
      dialogueJson: File(dialogueFile).readAsStringSync(),
    );

    // voice -> text -> where it is used. A voice is a trainer voice group
    // ("boy", "girl") or a character id.
    final need = <String, Map<String, Set<String>>>{};
    void add(String speaker, String text, String where) {
      final voices = speaker == Cast.trainerSpeaker
          ? {for (final t in cast.trainers) t.voiceKey}
          : {cast.characters[speaker]?.voiceKey ?? speaker};
      for (final v in voices) {
        for (final p in VoicePack.allPieces(text)) {
          need.putIfAbsent(v, () => {}).putIfAbsent(p, () => {}).add(where);
        }
      }
    }

    String who(String event) => cast.events[event]?.speaker ?? Cast.trainerSpeaker;

    // Questions and hints, from every level.
    final hints = <String>{};
    final factory = PuzzleFactory(Random(2026));
    for (final level in content.allLevels) {
      for (var i = 0; i < samples; i++) {
        final q = factory.forLevel(level);
        add(who('question'), q.spoken, 'question');
        hints.add(q.hint);
      }
    }

    // Dialogue, with placeholders filled in every way the game can.
    final fills = <String, List<String>>{
      'hint': hints.toList(),
      'stars': [for (var s = 1; s <= 3; s++) bn(s)],
      'title': [for (final a in content.achievements) a.title],
      'name': [''],
    };
    for (final MapEntry(key: event, value: e) in cast.events.entries) {
      for (final line in e.lines) {
        var texts = [line];
        for (final MapEntry(:key, :value) in fills.entries) {
          if (!line.contains('{$key}')) continue;
          texts = [
            for (final t in texts)
              for (final v in value) t.replaceAll('{$key}', v),
          ];
        }
        for (final t in texts) {
          add(e.speaker, t, event);
        }
      }
    }

    // Every number up to 200, and tens up to 1000, for each speaker that says
    // numbers, so new levels rarely need new recordings.
    for (final s in need.keys.toList()) {
      if (!need[s]!.keys.any((t) => RegExp(r'^[০-৯]').hasMatch(t))) continue;
      for (var n = 0; n <= 1000; n += n < 200 ? 1 : 10) {
        need[s]!.putIfAbsent(bn(n), () => {'spare'});
      }
    }

    // Keep file names from the last run; number new rows after them.
    final rows = <String, List<String>>{}; // "speaker|text" -> row
    final next = <String, int>{};
    final old = File(out);
    if (old.existsSync()) {
      for (final r in _readCsv(old.readAsStringSync()).skip(1)) {
        if (r.length < 3) continue;
        rows['${r[1]}|${r[2]}'] = r;
        final n = int.tryParse(RegExp(r'(\d+)').firstMatch(r[0])?.group(1) ?? '') ?? 0;
        next[r[1]] = max(next[r[1]] ?? 0, n);
      }
    }
    final speakers = need.keys.toList()..sort();
    var added = 0;
    for (final s in speakers) {
      final texts = need[s]!.keys.toList()..sort(_byKind);
      for (final t in texts) {
        final key = '$s|$t';
        final used = (need[s]![t]!.toList()..sort()).join(' ');
        if (rows.containsKey(key)) {
          rows[key]![4] = used;
          continue;
        }
        final n = next[s] = (next[s] ?? 0) + 1;
        final kind = RegExp(r'^[০-৯0-9]').hasMatch(t) ? 'number' : 'speech';
        rows[key] = ['$s/${n.toString().padLeft(4, '0')}.mp3', s, t, kind, used];
        added++;
      }
    }

    // Lines nobody says any more drop out; their numbers are not reused.
    rows.removeWhere((key, r) => need[r[1]]?.containsKey(r[2]) != true);
    final buf = StringBuffer('﻿file,speaker,text,kind,used_in\n');
    for (final r in rows.values) {
      buf.writeln(r.map(_csv).join(','));
    }
    old.writeAsStringSync(buf.toString());
    final per = {for (final s in speakers) s: rows.values.where((r) => r[1] == s).length};
    // ignore: avoid_print
    print('$out: ${rows.length} clips ($added new). Per speaker: $per');
  });
}

/// Numbers first, in number order, then everything else.
int _byKind(String a, String b) {
  final na = parseNumber(RegExp(r'^[০-৯]+').stringMatch(a) ?? '');
  final nb = parseNumber(RegExp(r'^[০-৯]+').stringMatch(b) ?? '');
  if (na != null && nb != null) return na != nb ? na - nb : a.compareTo(b);
  if (na != null) return -1;
  if (nb != null) return 1;
  return a.compareTo(b);
}

String _csv(String s) => s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;

List<List<String>> _readCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  final t = text.startsWith('﻿') ? text.substring(1) : text;
  for (var i = 0; i < t.length; i++) {
    final c = t[i];
    if (quoted) {
      if (c == '"' && i + 1 < t.length && t[i + 1] == '"') {
        cell.write('"');
        i++;
      } else if (c == '"') {
        quoted = false;
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\n') {
      row.add(cell.toString().replaceAll('\r', ''));
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) rows.add(row..add(cell.toString()));
  return rows;
}
