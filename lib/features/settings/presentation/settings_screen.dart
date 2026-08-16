import 'package:flutter/material.dart';

import '../../fee/application/fee_service.dart';
import '../domain/services/settings_service.dart';
import 'widgets/academic_tab.dart';
import 'widgets/fee_tab.dart';
import 'widgets/profile_tab.dart';
import 'widgets/receipt_tab.dart';

/// Module 12: School Settings.
///
/// Tabs: Profile (name/address/contact/logo), Academic (canonical class and
/// section lists), Fee (read-only view of fee structures + link to the Fee
/// module editor) and Receipt (footer line). Data-entry users see everything
/// read-only with an explanatory banner; only the school admin can edit.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settingsService,
    required this.feeService,
  });

  final SettingsService settingsService;
  final FeeService feeService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _readOnlyBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    widget.settingsService.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settingsService,
      builder: (context, _) {
        final service = widget.settingsService;
        if (service.isLoading && !service.isLoaded) {
          return Scaffold(
            appBar: AppBar(title: const Text('School Settings')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('School Settings'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Profile'),
                  Tab(text: 'Academic'),
                  Tab(text: 'Fee'),
                  Tab(text: 'Receipt'),
                ],
              ),
            ),
            body: Column(
              children: [
                if (!service.isAdmin && !_readOnlyBannerDismissed)
                  MaterialBanner(
                    leading: const Icon(Icons.visibility_outlined),
                    content: const Text(
                      'You are viewing settings in read-only mode. Only the '
                      'school administrator can make changes.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          setState(() => _readOnlyBannerDismissed = true);
                        },
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ProfileTab(settingsService: service),
                      AcademicTab(settingsService: service),
                      FeeTab(settingsService: service, feeService: widget.feeService),
                      ReceiptTab(settingsService: service),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
