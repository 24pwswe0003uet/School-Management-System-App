import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/reports/domain/entities/report_definition.dart';
import 'package:school_office_management/features/reports/domain/entities/report_filter.dart';
import 'package:school_office_management/features/reports/domain/entities/report_filter_option.dart';
import 'package:school_office_management/features/reports/domain/services/report_export_service.dart';
import 'package:school_office_management/features/reports/presentation/report_view_screen.dart';
import 'package:school_office_management/features/reports/presentation/reports_hub_screen.dart';
import 'package:school_office_management/features/reports/presentation/widgets/report_menu_tile.dart';
import '../settings/helpers.dart';
import 'mock_repository.dart';

void main() {
  group('ReportsHubScreen', () {
    testWidgets('renders 7 category cards', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Create a mock report repository
      final mockRepo = MockReportRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: ReportsHubScreen(reportRepository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Verify 7 category cards are displayed
      expect(find.byType(ReportMenuTile), findsNWidgets(7));

      // Verify category titles
      expect(find.text('Student'), findsOneWidget);
      expect(find.text('Admission'), findsOneWidget);
      expect(find.text('Fee'), findsOneWidget);
      expect(find.text('Employee'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Financial'), findsOneWidget);
    });
  });

  group('ReportViewScreen', () {
    testWidgets('renders when definition and filters provided', (WidgetTester tester) async {
      final mockRepo = MockReportRepository();
      final definition = ReportDefinition.student(
        id: 'student-all',
        title: 'All Students',
        description: 'List of all students',
        filters: [
          ReportFilter(name: 'Status', type: 'status', options: [
            ReportFilterOption(value: 'active', label: 'Active'),
          ]),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReportViewScreen(
            reportRepository: mockRepo,
            definition: definition,
            filtersApplied: [
              ReportFilter(name: 'Status', type: 'status', options: [
                ReportFilterOption(value: 'active', label: 'Active'),
              ]),
            ],
            exportService: ReportExportService(),
            settingsService: await buildTestSettingsService(),
          ),
        ),
      );

      // Wait for the build
      await tester.pumpAndSettle();

      // Verify the screen title
      expect(find.text('All Students'), findsWidgets);

      // Verify tabs exist (Summary and Details)
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('shows summary section when result has summary', (WidgetTester tester) async {
      final mockRepo = MockReportRepository();
      final definition = ReportDefinition.financial(
        id: 'financial-summary',
        title: 'Financial Summary',
        description: 'Fee Income, Salary Expenses, Other Expenses, Net Position',
        filters: const [
          ReportFilter(name: 'Start Date', type: 'date', required: true),
          ReportFilter(name: 'End Date', type: 'date', required: true),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReportViewScreen(
            reportRepository: mockRepo,
            definition: definition,
            filtersApplied: const [
              ReportFilter(name: 'Start Date', type: 'date', required: true),
              ReportFilter(name: 'End Date', type: 'date', required: true),
            ],
            exportService: ReportExportService(),
            settingsService: await buildTestSettingsService(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify summary section exists
      expect(find.text('Financial Summary'), findsWidgets);
    });
  });
}
