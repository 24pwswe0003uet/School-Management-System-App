import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import '../domain/services/salary_service.dart';
import 'salary_form_screen.dart';
import 'salary_records_screen.dart';

/// Modern Salary Management Hub with integrated tab navigation.
class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key, required this.salaryService, this.initialTabIndex = 0});

  final SalaryService salaryService;
  final int initialTabIndex;

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
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
        title: const Text('Salary Management'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryNavy,
          indicatorColor: AppTheme.primaryNavy,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Salary Records'),
            Tab(icon: Icon(Icons.add_card_outlined), text: 'Record Salary'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SalaryRecordsScreen(salaryService: widget.salaryService),
          SalaryFormScreen(salaryService: widget.salaryService),
        ],
      ),
    );
  }
}
