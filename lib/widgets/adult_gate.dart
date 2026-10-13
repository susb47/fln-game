import 'dart:math';

import 'package:flutter/material.dart';

import '../bn.dart';

/// A simple grown-ups-only check before teacher or parent screens:
/// a two-digit sum that a 6 to 9 year old is unlikely to solve.
/// Accepts Bangla or English digits.
Future<bool> askAdult(BuildContext context) async {
  final rng = Random();
  final a = 11 + rng.nextInt(9), b = 12 + rng.nextInt(8);
  final controller = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('শুধু শিক্ষক / অভিভাবকের জন্য'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${bn(a)} + ${bn(b)} = ?', style: const TextStyle(fontSize: 28)),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24),
            onSubmitted: (v) => Navigator.pop(c, parseNumber(v) == a + b),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('বাতিল')),
        FilledButton(
          onPressed: () => Navigator.pop(c, parseNumber(controller.text) == a + b),
          child: const Text('ঠিক আছে'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
