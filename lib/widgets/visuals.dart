import 'package:flutter/material.dart';

import '../bn.dart';
import '../logic/question.dart';

/// Draws a group of objects in rows of five, like a ten-frame, so children
/// can see "five and three" instead of counting a jumble.
class ObjectGroupView extends StatelessWidget {
  final ObjectGroup group;
  final double size;
  final bool numbered;

  const ObjectGroupView(this.group, {super.key, this.size = 34, this.numbered = false});

  @override
  Widget build(BuildContext context) {
    final cell = size * 1.25;
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
                  if (i >= group.count - group.crossed)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: 0.35,
                          child: Text(group.emoji, style: TextStyle(fontSize: size, height: 1.1)),
                        ),
                        Icon(Icons.close_rounded, size: size * 1.1, color: Colors.red.shade700),
                      ],
                    )
                  else
                    Text(group.emoji, style: TextStyle(fontSize: size, height: 1.1)),
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
class VisualsView extends StatelessWidget {
  final List<Visual> visuals;
  final bool numbered;

  const VisualsView(this.visuals, {super.key, this.numbered = false});

  @override
  Widget build(BuildContext context) {
    final groupSize = visuals.whereType<ObjectGroup>().length > 1 ? 28.0 : 38.0;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        for (final v in visuals)
          switch (v) {
            ObjectGroup() => Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ObjectGroupView(v, size: groupSize, numbered: numbered),
            ),
            BigText(:final text) => Text(
              text,
              style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold),
            ),
            Sequence(:final items) => Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final item in items)
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: item == '?' ? Colors.amber.shade200 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          },
      ],
    );
  }
}

enum AnswerState { idle, correct, wrong }

/// A big, easy-to-tap answer button.
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
    return AnimatedScale(
      scale: state == AnswerState.correct ? 1.1 : 1,
      duration: const Duration(milliseconds: 200),
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
