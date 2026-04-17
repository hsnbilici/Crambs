import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ekranda uçan "+N crumb" sayıları. Home overlay bu listeyi render eder.
class FloatingNumber {
  FloatingNumber({required this.id, required this.amount, required this.dx});
  final int id;
  final double amount;

  /// ±20px yatay jitter — aynı yerde üst üste binmeyi kırar.
  final double dx;
}

class FloatingNumbersNotifier extends Notifier<List<FloatingNumber>> {
  static const int _maxConcurrent = 5;
  int _seq = 0;
  final _rng = Random();

  @override
  List<FloatingNumber> build() => const [];

  void spawn(double amount) {
    final number = FloatingNumber(
      id: ++_seq,
      amount: amount,
      dx: _rng.nextDouble() * 40 - 20,
    );
    final next = [...state, number];
    state = next.length > _maxConcurrent
        ? next.sublist(next.length - _maxConcurrent)
        : next;
  }

  void remove(int id) {
    state = state.where((n) => n.id != id).toList();
  }
}

final floatingNumbersProvider =
    NotifierProvider<FloatingNumbersNotifier, List<FloatingNumber>>(
  FloatingNumbersNotifier.new,
);
