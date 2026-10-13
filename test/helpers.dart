import 'dart:io';

import 'package:fln_game/data/content.dart';

/// Loads the real content files from disk, exactly as the app does.
Content loadContent() {
  final dir = Directory('assets/levels');
  final files = {
    for (final f
        in dir.listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path)))
      if (f.path.endsWith('.json') && !f.uri.pathSegments.last.startsWith('_'))
        f.path: f.readAsStringSync(),
  };
  return Content.parse(
    islandsJson: File('assets/config/islands.json').readAsStringSync(),
    achievementsJson: File('assets/config/achievements.json').readAsStringSync(),
    levelFiles: files,
  );
}
