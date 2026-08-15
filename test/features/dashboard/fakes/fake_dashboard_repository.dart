import 'package:school_office_management/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:school_office_management/features/dashboard/domain/repositories/dashboard_repository.dart';

/// Returns a configurable summary without touching a real database. Used by
/// widget tests that render the dashboard.
class FakeDashboardRepository implements DashboardRepository {
  FakeDashboardRepository({DashboardSummary? summary})
    : summary = summary ?? DashboardSummary.empty;

  DashboardSummary summary;
  Object? error;

  @override
  Future<DashboardSummary> load({required DateTime now}) async {
    final error = this.error;
    if (error != null) throw error;
    return summary;
  }
}
