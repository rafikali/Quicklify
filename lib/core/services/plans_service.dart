/// Streams the premium plan catalog from Firestore `plans/{id}`.
///
/// Falls back to a hardcoded catalog (Rs 40 / Rs 100 / Rs 500) when Firestore
/// hasn't been seeded yet or the network is unreachable, so the premium screen
/// always renders three plans.
library;

import 'dart:async';
import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/models/plan.dart';

class PlansService {
  PlansService._();
  static final instance = PlansService._();
  static const _tag = 'PlansService';

  static const List<Plan> fallbackPlans = [
    Plan(
      id: '_fallback_monthly',
      name: '1 Month',
      durationDays: 30,
      priceInr: 40,
      sortOrder: 1,
    ),
    Plan(
      id: '_fallback_quarterly',
      name: '3 Months',
      durationDays: 90,
      priceInr: 100,
      sortOrder: 2,
      popular: true,
      tagline: 'Most popular',
    ),
    Plan(
      id: '_fallback_yearly',
      name: '1 Year',
      durationDays: 365,
      priceInr: 500,
      sortOrder: 3,
      tagline: 'Best value',
    ),
  ];

  final _db = FirebaseFirestore.instance;

  List<Plan> _cached = List.unmodifiable(fallbackPlans);
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  final _changes = StreamController<List<Plan>>.broadcast();

  Stream<List<Plan>> get changes => _changes.stream;
  List<Plan> get current => _cached;

  Future<void> initialize() async {
    _sub?.cancel();
    _sub = _db
        .collection('plans')
        .where('active', isEqualTo: true)
        .snapshots()
        .listen(
      (snap) {
        if (snap.docs.isEmpty) {
          // Keep fallback on empty (uninitialized) collection.
          return;
        }
        final list = snap.docs.map(Plan.fromFirestore).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _cached = List.unmodifiable(list);
        _changes.add(_cached);
      },
      onError: (e) {
        dev.log('plans listener error: $e', name: _tag);
      },
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _changes.close();
  }
}
