import 'package:flutter/widgets.dart';

import 'audio/audio_manager.dart';
import 'audio/coach.dart';
import 'data/cast.dart';
import 'data/content.dart';
import 'logic/profile.dart';
import 'logic/profile_store.dart';
import 'logic/progression.dart';

/// Gives every screen the loaded content, the profile store, the characters and the sound.
class GameScope extends InheritedWidget {
  final Content content;
  final ProfileStore store;
  final Cast cast;
  final AudioManager audio;
  final Coach coach;

  const GameScope._({
    super.key,
    required this.content,
    required this.store,
    required this.cast,
    required this.audio,
    required this.coach,
    required super.child,
  });

  /// [cast] and [audio] default to a silent stand-in, which is what tests use.
  factory GameScope({
    Key? key,
    required Content content,
    required ProfileStore store,
    Cast? cast,
    AudioManager? audio,
    required Widget child,
  }) {
    final c = cast ?? Cast.fallback;
    final a = audio ?? AudioManager.silent();
    return GameScope._(
      key: key,
      content: content,
      store: store,
      cast: c,
      audio: a,
      coach: Coach(c, a),
      child: child,
    );
  }

  static GameScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameScope>()!;

  Profile get player => store.current!;
  Progression get progression => Progression(content, player);
  Progression progressionFor(Profile p) => Progression(content, p);

  @override
  bool updateShouldNotify(GameScope old) =>
      content != old.content || store != old.store || audio != old.audio || cast != old.cast;
}
