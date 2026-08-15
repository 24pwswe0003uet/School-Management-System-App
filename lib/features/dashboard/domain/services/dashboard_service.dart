import 'package:flutter/foundation.dart';

import '../entities/dashboard_summary.dart';
import '../repositories/dashboard_repository.dart';

/// Holds the currently displayed dashboard summary and reloads it from the
/// repository. Mirrors the AuthService ChangeNotifier pattern used elsewhere.
class DashboardService extends ChangeNotifier {
  DashboardService(this._repository);

  final DashboardRepository _repository;

  DashboardSummary? _summary;
  bool _loading = false;
  Object? _error;

  DashboardSummary? get summary => _summary;
  bool get isLoading => _loading;
  Object? get error => _error;

  /// Loads the summary, optionally pinning the "as of" time for tests.
  Future<void> load({DateTime? now}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final summary = await _repository.load(now: now ?? DateTime.now());
      _summary = summary;
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
