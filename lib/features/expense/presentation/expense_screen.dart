import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import '../domain/services/expense_service.dart';
import 'expense_form_screen.dart';
import 'expense_list_screen.dart';
import 'expense_reports_screen.dart';

/// Modern Expense Management Hub with integrated tab navigation.
class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key, required this.expenseService, this.initialTabIndex = 0});

  final ExpenseService expenseService;
  final int initialTabIndex;

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
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
        title: const Text('Expense Management'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryNavy,
          indicatorColor: AppTheme.primaryNavy,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Expense List'),
            Tab(icon: Icon(Icons.add_card_outlined), text: 'Add Expense'),
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ExpenseListScreen(expenseService: widget.expenseService),
          ExpenseFormScreen(expenseService: widget.expenseService),
          ExpenseReportsScreen(expenseService: widget.expenseService),
        ],
      ),
    );
  }
}