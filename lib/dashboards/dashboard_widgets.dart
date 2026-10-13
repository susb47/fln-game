import 'package:flutter/material.dart';

import '../bn.dart';

/// Ink colours for dashboard text. Data colours never colour text.
const inkPrimary = Color(0xFF1B1F24);
const inkSecondary = Color(0xFF5B6470);
const surface = Colors.white;
const track = Color(0xFFE6E9EE);

/// A single headline number with a label.
class StatTile extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;

  const StatTile({super.key, required this.emoji, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: inkPrimary),
        ),
        Text(label, style: const TextStyle(fontSize: 14, color: inkSecondary)),
      ],
    ),
  );
}

/// A titled white panel.
class Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const Panel({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: inkPrimary),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

/// One labelled horizontal bar, e.g. levels done on an island.
class BarRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String trailing;

  const BarRow({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 15, color: inkPrimary)),
        ),
        Expanded(
          child: Tooltip(
            message: '$label: $trailing',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value.clamp(0, 1).toDouble(),
                minHeight: 14,
                color: color,
                backgroundColor: track,
              ),
            ),
          ),
        ),
        SizedBox(
          width: 96,
          child: Text(
            trailing,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, color: inkSecondary),
          ),
        ),
      ],
    ),
  );
}

/// Column chart of one value per day (single series, so no legend).
class DayBars extends StatelessWidget {
  /// (day label, value) oldest first.
  final List<(String, int)> days;
  final Color color;
  final String unit;

  const DayBars({super.key, required this.days, required this.color, required this.unit});

  @override
  Widget build(BuildContext context) {
    final top = days.fold(0, (m, d) => d.$2 > m ? d.$2 : m);
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (label, v) in days)
            Expanded(
              child: Tooltip(
                message: '$label: ${bn(v)} $unit',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (v > 0)
                      Text(bn(v), style: const TextStyle(fontSize: 12, color: inkSecondary)),
                    Container(
                      height: top == 0 ? 2 : 2 + 96 * v / top,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: v == 0 ? track : color,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(label, style: const TextStyle(fontSize: 12, color: inkSecondary)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
