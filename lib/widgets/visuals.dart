import 'package:flutter/material.dart';

import '../bn.dart';
import '../logic/question.dart';
import 'anim.dart';

/// Draws a group of objects in rows of five, like a ten-frame, so children
/// can see "five and three" instead of counting a jumble.
///
/// With [animate] on, the objects pop in one by one starting after [delay]
/// (calling [onPop] for each, to play a sound), and then the crossed-out ones
/// are taken away.
class ObjectGroupView extends StatelessWidget {
  final ObjectGroup group;
  final double size;
  final bool numbered;
  final bool animate;
  final Duration delay;
  final VoidCallback? onPop;

  /// Time between two objects popping in.
  static const step = Duration(milliseconds: 90);

  const ObjectGroupView(
    this.group, {
    super.key,
    this.size = 34,
    this.numbered = false,
    this.animate = false,
    this.delay = Duration.zero,
    this.onPop,
  });

  /// How long the whole group takes to appear.
  static Duration showTime(ObjectGroup g, Duration delay) => delay + step * g.count;

  @override
  Widget build(BuildContext context) {
    final cell = size * 1.25;
    final emoji = Text(group.emoji, style: TextStyle(fontSize: size, height: 1.1));
    Widget object(int i) {
      final crossed = i >= group.count - group.crossed;
      if (!animate) {
        return crossed
            ? Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(opacity: 0.35, child: emoji),
                  Icon(Icons.close_rounded, size: size * 1.1, color: Colors.red.shade700),
                ],
              )
            : emoji;
      }
      // Taking away starts once every object is in, one after another.
      final takeAway =
          showTime(group, delay) +
          const Duration(milliseconds: 350) +
          step * 2 * (i - (group.count - group.crossed));
      return PopIn(
        delay: delay + step * i,
        onShow: onPop,
        child: crossed ? CrossOut(size: size, delay: takeAway, child: emoji) : emoji,
      );
    }

    return SizedBox(
      width: cell * (group.count < 5 ? group.count : 5),
      child: Wrap(
        children: [
          for (var i = 0; i < group.count; i++)
            SizedBox(
              width: cell,
              height: numbered ? cell + 16 : cell,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  object(i),
                  if (numbered)
                    Text(
                      bn(i + 1),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The question area: objects, numerals and patterns.
///
/// Give it a new [key] for each question and it plays its entrance again:
/// boxes slide in from the sides, objects pop in one by one, numbers bounce,
/// pattern tiles drop in and the "?" keeps gently pulsing.
class VisualsView extends StatelessWidget {
  final List<Visual> visuals;
  final bool numbered;

  /// Called as each object or tile pops in (the game plays a "pop").
  final VoidCallback? onPop;

  const VisualsView(this.visuals, {super.key, this.numbered = false, this.onPop});

  /// When the entrance is over and the answers should appear.
  static Duration entranceTime(List<Visual> visuals) {
    var t = const Duration(milliseconds: 150);
    for (final v in visuals) {
      t += switch (v) {
        ObjectGroup() => ObjectGroupView.step * v.count + const Duration(milliseconds: 100),
        Sequence(:final items) => const Duration(milliseconds: 120) * items.length,
        BigText() => const Duration(milliseconds: 250),
      };
    }
    return t > const Duration(milliseconds: 1600) ? const Duration(milliseconds: 1600) : t;
  }

  @override
  Widget build(BuildContext context) {
    final groupSize = visuals.whereType<ObjectGroup>().length > 1 ? 28.0 : 38.0;
    var at = const Duration(milliseconds: 150);
    final children = <Widget>[];
    for (var n = 0; n < visuals.length; n++) {
      final v = visuals[n];
      final start = at;
      // First box comes from the left, the last from the right, middles drop in.
      final from = visuals.length == 1
          ? const Offset(0, 0.4)
          : n == 0
          ? const Offset(-0.6, 0)
          : n == visuals.length - 1
          ? const Offset(0.6, 0)
          : const Offset(0, -0.6);
      switch (v) {
        case ObjectGroup():
          children.add(
            PopIn(
              delay: start,
              from: from,
              curve: Curves.easeOutBack,
              duration: const Duration(milliseconds: 450),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ObjectGroupView(
                  v,
                  size: groupSize,
                  numbered: numbered,
                  animate: true,
                  delay: start + const Duration(milliseconds: 150),
                  onPop: onPop,
                ),
              ),
            ),
          );
          at += ObjectGroupView.step * v.count + const Duration(milliseconds: 100);
        case BigText(:final text):
          children.add(
            PopIn(
              delay: start,
              onShow: onPop,
              duration: const Duration(milliseconds: 700),
              child: Text(text, style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold)),
            ),
          );
          at += const Duration(milliseconds: 250);
        case Sequence(:final items):
          children.add(
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < items.length; i++)
                  PopIn(
                    delay: start + const Duration(milliseconds: 120) * i,
                    from: const Offset(0, -0.8),
                    onShow: onPop,
                    child: Pulse(
                      active: items[i] == '?',
                      amount: 0.12,
                      child: Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: items[i] == '?' ? Colors.amber.shade200 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          items[i],
                          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
          at += const Duration(milliseconds: 120) * items.length;
      }
    }
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: children,
    );
  }
}

enum AnswerState { idle, correct, wrong }

/// A big, easy-to-tap answer button.
///
/// It shakes when it turns wrong and does a little hop when it is right.
class AnswerButton extends StatelessWidget {
  final AnswerOption option;
  final AnswerState state;
  final VoidCallback? onTap;

  const AnswerButton({super.key, required this.option, required this.state, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      AnswerState.idle => Colors.white,
      AnswerState.correct => Colors.green.shade300,
      AnswerState.wrong => Colors.grey.shade300,
    };
    return Shake(
      shakes: state == AnswerState.wrong ? 1 : 0,
      child: AnimatedScale(
        scale: state == AnswerState.correct ? 1.15 : 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.elasticOut,
        child: Opacity(
          opacity: state == AnswerState.wrong ? 0.5 : 1,
          child: Material(
            color: color,
            elevation: state == AnswerState.idle ? 3 : 0,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minWidth: 88, minHeight: 88),
                padding: const EdgeInsets.all(12),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: option.group != null
                      ? ObjectGroupView(option.group!, size: 26)
                      : Text(
                          option.label!,
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filled and empty stars, e.g. 2 of 3.
class StarsRow extends StatelessWidget {
  final int stars;
  final double size;
  final Color emptyColor;

  const StarsRow(this.stars, {super.key, this.size = 28, this.emptyColor = Colors.white70});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 3; i++)
        Icon(
          i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < stars ? Colors.amber : emptyColor,
        ),
    ],
  );
}
