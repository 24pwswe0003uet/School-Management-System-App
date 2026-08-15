import '../entities/dashboard_summary.dart';

/// Reads the figures shown on the dashboard from SQLite.
///
/// [load] receives [now] so date bucketing ("today", "current month") is
/// deterministic and testable instead of relying on the wall clock.
abstract interface class DashboardRepository {
  Future<DashboardSummary> load({required DateTime now});
}
