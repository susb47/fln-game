import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Pops its child in after [delay]: grows from small with a springy bounce,
/// optionally sliding in from [from] (a fraction of its own size).
class PopIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset from;
  final Curve curve;

  /// Called the moment the child starts to appear (e.g. to play a "pop").
  final VoidCallback? onShow;

  const PopIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 550),
    this.from = Offset.zero,
    this.curve = Curves.elasticOut,
    this.onShow,
  });

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration);
  late final _grow = CurvedAnimation(parent: _c, curve: widget.curve);
  late final _move = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _start();
    } else {
      _timer = Timer(widget.delay, _start);
    }
  }

  void _start() {
    if (!mounted) return;
    widget.onShow?.call();
    _c.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _c.value.clamp(0.0, 1.0) < 0.15 ? _c.value / 0.15 : 1,
      child: FractionalTranslation(
        translation: widget.from * (1 - _move.value),
        child: Transform.scale(scale: 0.2 + 0.8 * _grow.value, child: child),
      ),
    ),
  );
}

/// Shakes its child sideways each time [shakes] goes up (a wrong answer).
class Shake extends StatefulWidget {
  final int shakes;
  final Widget child;
  const Shake({super.key, required this.shakes, required this.child});

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (widget.shakes > old.shakes) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) => Transform.translate(
      offset: Offset(sin(_c.value * pi * 6) * 10 * (1 - _c.value), 0),
      child: child,
    ),
  );
}

/// Gently grows and shrinks to draw the eye (the "?" in a pattern), for about
/// ten seconds, then rests. With [active] false it sits still.
class Pulse extends StatefulWidget {
  final Widget child;
  final bool active;
  final double amount;
  final Duration period;
  const Pulse({
    super.key,
    required this.child,
    this.active = true,
    this.amount = 0.08,
    this.period = const Duration(milliseconds: 900),
  });

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(Pulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active && !_c.isAnimating) {
      _c.repeat(reverse: true, count: 12);
    } else if (!widget.active && _c.isAnimating) {
      _c.animateTo(0, duration: const Duration(milliseconds: 150));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) => Transform.scale(
      scale: 1 + widget.amount * Curves.easeInOut.transform(_c.value),
      child: child,
    ),
  );
}

/// An object that is taken away: it shows normally, then a red cross pops
/// onto it and it fades and drops a little.
class CrossOut extends StatefulWidget {
  final Widget child;
  final double size;
  final Duration delay;
  const CrossOut({super.key, required this.child, required this.size, this.delay = Duration.zero});

  @override
  State<CrossOut> createState() => _CrossOutState();
}

class _CrossOutState extends State<CrossOut> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final t = Curves.easeOut.transform(_c.value);
      final cross = Curves.elasticOut.transform(_c.value);
      return Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 1 - 0.65 * t,
            child: Transform.translate(
              offset: Offset(0, 6 * t),
              child: Transform.rotate(angle: 0.25 * t, child: widget.child),
            ),
          ),
          Transform.scale(
            scale: cross,
            child: Icon(Icons.close_rounded, size: widget.size * 1.1, color: Colors.red.shade700),
          ),
        ],
      );
    },
  );
}
