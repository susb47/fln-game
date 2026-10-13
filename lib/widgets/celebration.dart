import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/audio_manager.dart';
import 'sound_widgets.dart';

/// Confetti that bursts from the middle and falls. Plays once when shown.
class ConfettiBurst extends StatefulWidget {
  final int pieces;
  final Duration duration;
  const ConfettiBurst({
    super.key,
    this.pieces = 36,
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration)..forward();
  late final List<_Piece> _pieces = List.generate(widget.pieces, (i) => _Piece(Random(i * 7 + 3)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) =>
          CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_pieces, _c.value)),
    ),
  );
}

class _Piece {
  static const colors = [
    Color(0xFFFFB703),
    Color(0xFFFB8500),
    Color(0xFF219EBC),
    Color(0xFF8ECAE6),
    Color(0xFFE76F51),
    Color(0xFF2A9D8F),
    Color(0xFF9C6ADE),
  ];
  final double angle, speed, spin, size;
  final Color color;
  final bool round;
  _Piece(Random r)
    : angle = -pi / 2 + (r.nextDouble() - 0.5) * pi * 1.3,
      speed = 0.6 + r.nextDouble() * 0.7,
      spin = (r.nextDouble() - 0.5) * 14,
      size = 7 + r.nextDouble() * 8,
      color = colors[r.nextInt(colors.length)],
      round = r.nextBool();
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.4);
    final reach = size.shortestSide * 0.9;
    final fade = t < 0.75 ? 1.0 : (1 - t) / 0.25;
    for (final p in pieces) {
      // Thrown outwards, then pulled down.
      final d = reach * p.speed * Curves.easeOut.transform(t);
      final pos = origin + Offset(cos(p.angle) * d, sin(p.angle) * d + size.height * 0.35 * t * t);
      final paint = Paint()..color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// After a right answer: confetti, and the character pops up with what they say.
///
/// [line] is the same sentence the character speaks, so words and voice match.
class Celebration extends StatefulWidget {
  final Line line;

  /// The child needed more than one try: a calmer "you kept going" card.
  final bool afterRetry;
  const Celebration({super.key, required this.line, this.afterRetry = false});

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
    ..forward();

  late final _pop = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.45, curve: Curves.elasticOut),
  );
  late final _out = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.82, 1, curve: Curves.easeIn),
  );
  late final _bob = CurvedAnimation(parent: _c, curve: const Interval(0.2, 0.8));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speaker = widget.line.speaker;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) => Opacity(
                opacity: 1 - _out.value,
                child: Transform.translate(
                  offset: Offset(0, -10 * sin(_bob.value * pi * 3)),
                  child: Transform.scale(scale: 0.3 + 0.7 * _pop.value, child: child),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: speaker.color, width: 4),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CharacterFace(speaker, size: 96),
                    const SizedBox(height: 8),
                    Text(
                      widget.line.text,
                      key: const ValueKey('praise'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('⭐ ⭐ ⭐', style: TextStyle(fontSize: 22)),
                  ],
                ),
              ),
            ),
          ),
          ConfettiBurst(pieces: widget.afterRetry ? 24 : 48),
        ],
      ),
    );
  }
}
