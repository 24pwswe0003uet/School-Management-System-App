import 'package:flutter/material.dart';

import '../../settings/domain/services/settings_service.dart';
import '../../shared/theme/app_theme.dart';
import '../application/fee_service.dart';
import 'collect_payment_screen.dart';
import 'fee_generate_screen.dart';
import 'fee_records_screen.dart';
import 'fee_reports_screen.dart';
import 'fee_structures_screen.dart';

/// Modern Fee Management Hub with intuitive operational tab bars and quick actions.
class FeeScreen extends StatefulWidget {
  const FeeScreen({
    super.key,
    required this.feeService,
    required this.settingsService,
    this.initialTabIndex = 0,
  });

  final FeeService feeService;
  final SettingsService settingsService;
  final int initialTabIndex;

  @override
  State<FeeScreen> createState() => _FeeScreenState();
}

class _FeeScreenState extends State<FeeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Management'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryNavy,
          indicatorColor: AppTheme.primaryNavy,
          tabs: const [
            Tab(icon: Icon(Icons.payments_outlined), text: 'Collect Payment'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Fee Records'),
            Tab(icon: Icon(Icons.auto_awesome_outlined), text: 'Generate Monthly'),
            Tab(icon: Icon(Icons.rule_outlined), text: 'Fee Structures'),
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Fee Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CollectPaymentScreen(
            feeService: widget.feeService,
            settingsService: widget.settingsService,
          ),
          FeeRecordsScreen(
            feeService: widget.feeService,
            settingsService: widget.settingsService,
          ),
          FeeGenerateScreen(feeService: widget.feeService),
          FeeStructuresScreen(feeService: widget.feeService),
          FeeReportsScreen(
            feeService: widget.feeService,
            settingsService: widget.settingsService,
          ),
        ],
      ),
    );
  }
}
