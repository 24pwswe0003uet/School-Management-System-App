import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_empty_state.dart';

/// Highly customizable paginated, searchable, responsive data table.
class AppDataTable<T> extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.isLoading = false,
    this.emptyMessage = 'No records found',
    this.emptyIcon = Icons.folder_open_outlined,
    this.searchQuery,
    this.onSearchChanged,
    this.searchPlaceholder = 'Search records...',
    this.headerActions,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final bool isLoading;
  final String emptyMessage;
  final IconData emptyIcon;
  final String? searchQuery;
  final ValueChanged<String>? onSearchChanged;
  final String searchPlaceholder;
  final List<Widget>? headerActions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter & search header
          if (onSearchChanged != null || (headerActions != null && headerActions!.isNotEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (onSearchChanged != null)
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          onChanged: onSearchChanged,
                          decoration: InputDecoration(
                            hintText: searchPlaceholder,
                            prefixIcon: const Icon(Icons.search, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              borderSide: const BorderSide(color: AppTheme.lightBorder),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (headerActions != null) ...[
                    const SizedBox(width: 12),
                    ...headerActions!,
                  ],
                ],
              ),
            ),
          const Divider(height: 1),

          // Content body
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: AppEmptyState(
                title: emptyMessage,
                icon: emptyIcon,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 64),
                child: DataTable(
                  columns: columns,
                  rows: rows,
                  headingRowHeight: 44,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 64,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
