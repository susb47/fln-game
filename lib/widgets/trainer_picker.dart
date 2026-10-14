import 'package:flutter/material.dart';

import '../audio/audio_manager.dart';
import '../data/cast.dart';
import '../game_scope.dart';
import 'sound_widgets.dart';
import 'trainer_actor.dart';

/// The nine children: tap one to make them your trainer. They say hello.
class TrainerPicker extends StatelessWidget {
  final String? selected;
  final ValueChanged<CharacterDef> onPick;
  const TrainerPicker({super.key, required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final trainers = scope.cast.trainers;
    final current = scope.cast.trainer(selected).id;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final t in trainers)
          _TrainerCard(
            key: ValueKey('trainer_${t.id}'),
            trainer: t,
            selected: t.id == current,
            onTap: () {
              scope.audio.sfx(Sfx.tap);
              scope.audio.say([Line(t, 'আমি ${t.name}। ${t.signature}')]);
              onPick(t);
            },
          ),
      ],
    );
  }
}

class _TrainerCard extends StatelessWidget {
  final CharacterDef trainer;
  final bool selected;
  final VoidCallback onTap;
  const _TrainerCard({
    super.key,
    required this.trainer,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: selected ? 1.06 : 1,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOutBack,
    child: Material(
      color: selected
          ? Color.alphaBlend(trainer.color.withValues(alpha: 0.18), Colors.white)
          : Colors.white,
      elevation: selected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? trainer.color : Colors.black12, width: selected ? 3 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          width: 104,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
            child: Column(
              children: [
                CharacterFigure(trainer, height: 120),
                const SizedBox(height: 4),
                Text(
                  trainer.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: selected ? trainer.color : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// A sheet for changing the current player's trainer.
Future<void> showTrainerPicker(BuildContext context) {
  final scope = GameScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    builder: (context) => ListenableBuilder(
      listenable: scope.store,
      builder: (context, _) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'তোমার ট্রেনার বেছে নাও',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TrainerPicker(
                selected: scope.store.current?.trainer,
                onPick: (t) => scope.store.setTrainer(t.id),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The player's trainer on the map: tap to change.
class TrainerButton extends StatelessWidget {
  const TrainerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    return ListenableBuilder(
      listenable: scope.store,
      builder: (context, _) {
        final t = scope.coach.trainer;
        return IconButton(
          key: const ValueKey('trainer_button'),
          tooltip: 'ট্রেনার: ${t.name}',
          onPressed: () => showTrainerPicker(context),
          icon: CharacterFace(t, size: 38),
        );
      },
    );
  }
}

/// The trainer, moving, next to what they last said. Tap the trainer to make them jump.
class TrainerStrip extends StatelessWidget {
  final double height;
  const TrainerStrip({super.key, this.height = 110});

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    return ListenableBuilder(
      listenable: scope.store,
      builder: (context, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TrainerActor(key: const ValueKey('trainer_strip'), height: height),
          const SizedBox(width: 8),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: CaptionBubble(showFace: false),
            ),
          ),
        ],
      ),
    );
  }
}
