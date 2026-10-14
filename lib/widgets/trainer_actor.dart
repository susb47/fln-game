import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/audio_manager.dart';
import '../audio/coach.dart';
import '../data/cast.dart';
import '../game_scope.dart';
import 'sound_widgets.dart';

/// The player's trainer, alive on screen.
///
/// They breathe and sway while idle, bob while talking, and act out what the
/// coach asks: wave hello, hop for a new question, jump and cheer for a right
/// answer, tilt their head and think after a mistake, nod to encourage.
/// Tapping them makes them jump.
///
/// The picture is one flat cut-out, so the whole body moves (with a waving
/// hand drawn on top); real arm and leg movement needs art split into parts.
class TrainerActor extends StatefulWidget {
  final double height;

  /// What happens on tap. Defaults to a jump.
  final VoidCallback? onTap;

  /// The character to show. Defaults to the current player's trainer.
  final CharacterDef? character;

  const TrainerActor({super.key, this.height = 110, this.onTap, this.character});

  /// Off in tests that wait for every animation to finish.
  static bool idleMotion = true;

  @override
  State<TrainerActor> createState() => _TrainerActorState();
}

class _TrainerActorState extends State<TrainerActor> with TickerProviderStateMixin {
  late final _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  late final _move = AnimationController(vsync: this);
  TrainerMove? _current;
  ValueNotifier<TrainerCue?>? _cue;
  int _seen = 0;

  static const _durations = {
    TrainerMove.wave: Duration(milliseconds: 1700),
    TrainerMove.hop: Duration(milliseconds: 550),
    TrainerMove.jump: Duration(milliseconds: 800),
    TrainerMove.cheer: Duration(milliseconds: 1500),
    TrainerMove.think: Duration(milliseconds: 1600),
    TrainerMove.nod: Duration(milliseconds: 1100),
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cue = GameScope.of(context).coach.cue;
    if (cue != _cue) {
      _cue?.removeListener(_onCue);
      _cue = cue..addListener(_onCue);
      // A move asked for just before this screen appeared still plays.
      final c = cue.value;
      if (c != null && c.count != _seen) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _onCue());
      }
    }
  }

  void _onCue() {
    final c = _cue?.value;
    if (!mounted || c == null || c.count == _seen) return;
    _seen = c.count;
    play(c.move);
  }

  void play(TrainerMove m) {
    setState(() => _current = m);
    _move
      ..duration = _durations[m]
      ..forward(from: 0).whenComplete(() {
        if (mounted && _move.value == 1) setState(() => _current = null);
      });
  }

  @override
  void dispose() {
    _cue?.removeListener(_onCue);
    _idle.dispose();
    _move.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final character = widget.character ?? scope.coach.trainer;
    final h = widget.height;
    final alive = TrainerActor.idleMotion && character.image != null;
    if (alive && !_idle.isAnimating) _idle.repeat();
    if (!alive && _idle.isAnimating) _idle.stop();
    return GestureDetector(
      key: const ValueKey('trainer_actor'),
      onTap:
          widget.onTap ??
          () {
            scope.audio.sfx(Sfx.pop);
            play(TrainerMove.jump);
          },
      child: ListenableBuilder(
        listenable: Listenable.merge([_idle, _move, scope.audio]),
        builder: (context, _) {
          final pose = _pose(_current, _move.value, _idle.value, scope.audio.speaking, h);
          // Jumps rise out of this box (nothing clips them), so the strip
          // stays short enough for small phones.
          return SizedBox(
            width: h * 0.62,
            height: h * 1.08,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Shadow on the ground: smaller the higher they jump.
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: h * 0.4 * pose.shadow,
                    height: h * 0.05,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.13 * pose.shadow),
                      borderRadius: BorderRadius.circular(h),
                    ),
                  ),
                ),
                Positioned(
                  bottom: h * 0.02,
                  child: Transform.translate(
                    offset: Offset(pose.dx, -pose.lift),
                    child: Transform.rotate(
                      angle: pose.tilt,
                      alignment: Alignment.bottomCenter,
                      child: Transform(
                        alignment: Alignment.bottomCenter,
                        transform: Matrix4.diagonal3Values(pose.sx, pose.sy, 1),
                        child: CharacterFigure(character, height: h),
                      ),
                    ),
                  ),
                ),
                if (pose.extra != null)
                  Positioned(
                    top: -h * 0.02 - pose.lift,
                    right: -h * 0.12,
                    child: Transform.rotate(
                      angle: pose.extraTilt,
                      alignment: Alignment.bottomLeft,
                      child: Transform.scale(
                        scale: pose.extraScale,
                        child: Text(pose.extra!, style: TextStyle(fontSize: h * 0.22)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Where the body is at one moment of a move.
class _Pose {
  double lift = 0, tilt = 0, sx = 1, sy = 1, dx = 0, shadow = 1;
  String? extra;
  double extraTilt = 0, extraScale = 1;
}

/// A jump arc: 0 on the ground, 1 at the top. [t] runs 0..1.
double _arc(double t) => sin(pi * t.clamp(0.0, 1.0));

/// Squash before take-off and on landing, stretch in the air.
void _jump(_Pose p, double t, double height, double h) {
  const crouch = 0.18, land = 0.85;
  if (t < crouch) {
    final k = sin(pi * t / crouch);
    p.sy = 1 - 0.1 * k;
    p.sx = 1 + 0.07 * k;
  } else if (t < land) {
    final a = (t - crouch) / (land - crouch);
    p.lift = height * h * _arc(a);
    p.sy = 1 + 0.06 * (1 - a);
    p.sx = 1 - 0.04 * (1 - a);
    p.shadow = 1 - 0.5 * _arc(a);
  } else {
    final k = sin(pi * (t - land) / (1 - land));
    p.sy = 1 - 0.08 * k;
    p.sx = 1 + 0.06 * k;
  }
}

_Pose _pose(TrainerMove? move, double t, double idle, bool talking, double h) {
  final p = _Pose();
  final ease = 1 - Curves.easeIn.transform(t);
  switch (move) {
    case null:
      // Breathing and a slow sway; a quicker bob while talking.
      p.sy = 1 + 0.015 * sin(2 * pi * idle);
      p.tilt = 0.025 * sin(2 * pi * idle + 1);
      if (talking) p.lift = h * 0.015 * (1 + sin(2 * pi * idle * 8)) / 2;
    case TrainerMove.wave:
      // Rocks side to side with a hand waving above their shoulder.
      final fade = t < 0.85 ? 1.0 : (1 - t) / 0.15;
      p.tilt = 0.07 * sin(2 * pi * 3 * t) * fade;
      p.lift = h * 0.03 * _arc(t);
      p.extra = '👋';
      p.extraTilt = 0.6 * sin(2 * pi * 4 * t);
      p.extraScale = Curves.elasticOut.transform((t * 3).clamp(0.0, 1.0)) * fade;
    case TrainerMove.hop:
      _jump(p, t, 0.08, h);
    case TrainerMove.jump:
      _jump(p, t, 0.28, h);
      p.extra = '⭐';
      p.extraScale = _arc(t);
      p.extraTilt = t * 2;
    case TrainerMove.cheer:
      // Two jumps with a little spin of joy and sparkles.
      final half = t < 0.5 ? t * 2 : (t - 0.5) * 2;
      _jump(p, half, t < 0.5 ? 0.3 : 0.2, h);
      p.tilt = t < 0.5 ? 0 : 0.12 * sin(2 * pi * half);
      p.extra = '✨';
      p.extraScale = 0.6 + 0.6 * _arc(half);
      p.extraTilt = 0.4 * sin(2 * pi * 2 * t);
    case TrainerMove.think:
      // Tilts their head, scratches it with a little side-to-side, "?" appears.
      final inOut = t < 0.2 ? t / 0.2 : (t > 0.8 ? (1 - t) / 0.2 : 1.0);
      p.tilt = -0.1 * Curves.easeInOut.transform(inOut.clamp(0.0, 1.0));
      p.dx = h * 0.02 * sin(2 * pi * 2 * t) * inOut;
      p.extra = '❓';
      p.extraScale = Curves.elasticOut.transform((t * 2.5).clamp(0.0, 1.0)) * inOut;
      p.extraTilt = 0.15 * sin(2 * pi * t);
    case TrainerMove.nod:
      // Encouraging nods: small dips forward, a thumbs-up.
      p.sy = 1 - 0.035 * _arc((t * 3) % 1) * ease;
      p.tilt = 0.04 * _arc((t * 3) % 1) * ease;
      p.extra = '👍';
      p.extraScale =
          Curves.elasticOut.transform((t * 2).clamp(0.0, 1.0)) * (t < 0.85 ? 1 : (1 - t) / 0.15);
  }
  return p;
}
