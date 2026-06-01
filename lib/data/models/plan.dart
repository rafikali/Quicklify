import 'package:cloud_firestore/cloud_firestore.dart';

/// A premium plan offered to users. Sourced from Firestore `plans/{id}`
/// (admin-managed) with a hardcoded fallback baked into the app so the screen
/// always shows something even if Firestore is unreachable.
class Plan {
  final String id;
  final String name;
  final int durationDays;
  final int priceInr;
  final String currency;
  final int sortOrder;
  final bool active;
  final bool popular;
  final String? tagline;

  const Plan({
    required this.id,
    required this.name,
    required this.durationDays,
    required this.priceInr,
    this.currency = 'Rs',
    this.sortOrder = 0,
    this.active = true,
    this.popular = false,
    this.tagline,
  });

  factory Plan.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data() ?? const {};
    return Plan(
      id: snap.id,
      name: (d['name'] as String?) ?? snap.id,
      durationDays: (d['durationDays'] as num?)?.toInt() ?? 30,
      priceInr: (d['priceInr'] as num?)?.toInt() ?? 0,
      currency: (d['currency'] as String?) ?? 'Rs',
      sortOrder: (d['sortOrder'] as num?)?.toInt() ?? 0,
      active: (d['active'] as bool?) ?? true,
      popular: (d['popular'] as bool?) ?? false,
      tagline: d['tagline'] as String?,
    );
  }

  /// Per-month price for display ("Rs 33/mo equivalent").
  /// Returns null for plans shorter than 30 days.
  double? get perMonthInr {
    if (durationDays < 30) return null;
    return priceInr * 30 / durationDays;
  }

  String get priceLabel => '$currency $priceInr';

  String get durationLabel {
    if (durationDays % 365 == 0) {
      final y = durationDays ~/ 365;
      return y == 1 ? '1 year' : '$y years';
    }
    if (durationDays % 30 == 0) {
      final m = durationDays ~/ 30;
      return m == 1 ? '1 month' : '$m months';
    }
    return '$durationDays days';
  }
}
