/// Provider exposing the dynamic plan catalog + the user's currently selected
/// plan. Selection lives in memory (no need to persist — defaults to the
/// `popular` plan or the middle one).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/plans_service.dart';
import '../../data/models/plan.dart';

class PlansProvider extends ChangeNotifier {
  StreamSubscription<List<Plan>>? _sub;
  List<Plan> _plans;
  String? _selectedPlanId;

  PlansProvider() : _plans = PlansService.instance.current {
    _selectedPlanId = _pickDefault(_plans);
    _sub = PlansService.instance.changes.listen((list) {
      _plans = list;
      // If the previously selected plan was removed/deactivated, fall back.
      if (_selectedPlanId == null ||
          !_plans.any((p) => p.id == _selectedPlanId)) {
        _selectedPlanId = _pickDefault(_plans);
      }
      notifyListeners();
    });
  }

  List<Plan> get plans => _plans;

  Plan? get selected {
    if (_selectedPlanId == null) return null;
    for (final p in _plans) {
      if (p.id == _selectedPlanId) return p;
    }
    return null;
  }

  void select(String planId) {
    if (_selectedPlanId == planId) return;
    _selectedPlanId = planId;
    notifyListeners();
  }

  static String? _pickDefault(List<Plan> plans) {
    if (plans.isEmpty) return null;
    for (final p in plans) {
      if (p.popular) return p.id;
    }
    // No popular flag → pick the middle entry.
    return plans[plans.length ~/ 2].id;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
