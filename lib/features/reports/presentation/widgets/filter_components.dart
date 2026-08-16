import 'package:flutter/material.dart';
import 'package:school_office_management/shared/utils/formatters.dart';

import '../../domain/entities/report_filter_option.dart';
import '../../domain/entities/report_filter.dart';

/// Filter type identifiers matching [ReportFilter.type].
enum FilterType {
  date('date'),
  dateRange('date-range'),
  month('month'),
  year('year'),
  status('status'),
  category('category'),
  entity('entity'),
  classSection('class-section');

  final String label;
  const FilterType(this.label);
}

/// Inline date picker field — shows a material date picker dialog.
class DatePickerField extends StatefulWidget {
  const DatePickerField({
    super.key,
    required this.label,
    required this.initialDate,
    required this.onSelected,
  });

  final String label;
  final DateTime initialDate;
  final ValueChanged<DateTime> onSelected;

  @override
  State<DatePickerField> createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<DatePickerField> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = Formatters.date(_selectedDate);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.calendar_today),
      ),
      child: Row(
        children: [
          Text(formatted, style: theme.textTheme.bodyMedium),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

/// Date range picker field — shows two date pickers for start and end.
class DateRangePickerField extends StatefulWidget {
  const DateRangePickerField({
    super.key,
    required this.label,
    required this.initialStart,
    required this.initialEnd,
    required this.onSelected,
  });

  final String label;
  final DateTime initialStart;
  final DateTime initialEnd;
  final ValueChanged<(DateTime, DateTime)> onSelected;

  @override
  State<DateRangePickerField> createState() => _DateRangePickerFieldState();
}

class _DateRangePickerFieldState extends State<DateRangePickerField> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStart;
    _endDate = widget.initialEnd;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startFormatted = Formatters.date(_startDate);
    final endFormatted = Formatters.date(_endDate);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.date_range),
      ),
      child: Row(
        children: [
          Expanded(child: Text(startFormatted, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward),
          const SizedBox(width: 8),
          Expanded(child: Text(endFormatted, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Month picker field — uses a dropdown with month labels.
/// Uses Formatters for display; no dependency on FeePeriod.
class MonthPickerField extends StatefulWidget {
  const MonthPickerField({
    super.key,
    required this.label,
    required this.initialMonth,
    required this.onSelected,
  });

  final String label;
  final int initialMonth; // 1-12
  final ValueChanged<int> onSelected;

  @override
  State<MonthPickerField> createState() => _MonthPickerFieldState();
}

class _MonthPickerFieldState extends State<MonthPickerField> {
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.calendar_today),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedMonth,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          onChanged: (int? newMonth) {
            if (newMonth != null && newMonth != _selectedMonth) {
              setState(() => _selectedMonth = newMonth);
              widget.onSelected(newMonth);
            }
          },
          items: List<int>.generate(12, (i) => i + 1)
              .map<DropdownMenuItem<int>>(
                (int month) => DropdownMenuItem<int>(
                  value: month,
                  child: Text(
                    Formatters.monthYear(DateTime(2000, month, 1)),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

/// Year picker field — simple dropdown of years.
class YearPickerField extends StatefulWidget {
  const YearPickerField({
    super.key,
    required this.label,
    required this.initialYear,
    required this.onSelected,
  });

  final String label;
  final int initialYear;
  final ValueChanged<int> onSelected;

  @override
  State<YearPickerField> createState() => _YearPickerFieldState();
}

class _YearPickerFieldState extends State<YearPickerField> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.date_range),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedYear,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          onChanged: (int? newYear) {
            if (newYear != null) {
              setState(() => _selectedYear = newYear);
              widget.onSelected(newYear);
            }
          },
          items: List<int>.generate(11, (i) => 2020 + i)
              .map<DropdownMenuItem<int>>(
                (int year) => DropdownMenuItem<int>(
                  value: year,
                  child: Text('$year'),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

/// Dropdown filter field — for status, category, etc. with predefined options.
class DropdownFilterField extends StatefulWidget {
  const DropdownFilterField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.options,
    this.isRequired = false,
  });

  final String label;
  final String value;
  final ValueChanged<String?> onChanged;
  final List<ReportFilterOption> options;
  final bool isRequired;

  @override
  State<DropdownFilterField> createState() => _DropdownFilterFieldState();
}

class _DropdownFilterFieldState extends State<DropdownFilterField> {
  late String _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.tune),
        errorText: _selectedValue.isEmpty && widget.isRequired
            ? 'Required'
            : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedValue,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          onChanged: (String? newValue) {
            setState(() => _selectedValue = newValue ?? '');
            widget.onChanged(newValue);
          },
          items: widget.options
              .map<DropdownMenuItem<String>>(
                (ReportFilterOption option) => DropdownMenuItem<String>(
                  value: option.value,
                  child: Text(option.label),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

/// Entity picker field — shows a dialog with searchable list from repository.
class EntityPickerField extends StatefulWidget {
  const EntityPickerField({
    super.key,
    required this.label,
    required this.repository,
    required this.searchText,
    required this.onSelected,
    this.isRequired = false,
  });

  final String label;
  final Object? repository; // actual repository instance
  final String searchText;
  final ValueChanged<Object?> onSelected;
  final bool isRequired;

  @override
  State<EntityPickerField> createState() => _EntityPickerFieldState();
}

class _EntityPickerFieldState extends State<EntityPickerField> {
  late TextEditingController _searchController;
  late List<String> _items;
  late String _selectedValue;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _items = _buildInitialItems();
    _selectedValue = widget.isRequired ? _items.first : '';
  }

  List<String> _buildInitialItems() {
    // In a real implementation, this would query the repository
    // For now, return placeholder items
    return ['Item 1', 'Item 2', 'Item 3'];
  }

  void _filterSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _isSearching = query.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () {
            _showEntityDialog(context);
          },
          icon: const Icon(Icons.person_search),
          label: Text(_selectedValue.isNotEmpty
              ? _selectedValue
              : widget.isRequired
                  ? 'Select $widget.label'
                  : ''),
        ),
        if (_isSearching) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _filterSearch(),
          ),
        ],
      ],
    );
  }

  Future<void> _showEntityDialog(BuildContext context) async {
    final result = await showDialog<Object?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(widget.label),
        content: const Text('Entity picker not fully implemented'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('selected'),
            child: const Text('Select'),
          ),
        ],
      ),
    );
    if (result != null) {
      widget.onSelected(result);
      setState(() => _selectedValue = result.toString());
    }
  }
}

/// Class/Section picker field — class dropdown with conditional section.
class ClassSectionPickerField extends StatefulWidget {
  const ClassSectionPickerField({
    super.key,
    required this.label,
    required this.initialClass,
    required this.onClassChanged,
    required this.onSectionChanged,
    this.isRequired = false,
  });

  final String label;
  final String? initialClass;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String?> onSectionChanged;
  final bool isRequired;

  @override
  State<ClassSectionPickerField> createState() =>
      _ClassSectionPickerFieldState();
}

class _ClassSectionPickerFieldState extends State<ClassSectionPickerField> {
  late String _selectedClass;
  late String? _selectedSection;
  final List<String> _classes = [
    'Play Group',
    'Nursery',
    'KG',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
  ];
  final Map<String, List<String>> _sectionMap = {
    '1': ['A', 'B'],
    '2': ['A', 'B'],
    '3': ['A', 'B', 'C'],
    '4': ['A', 'B', 'C'],
    '5': ['A', 'B', 'C'],
    '6': ['A', 'B', 'C'],
    '7': ['A', 'B', 'C'],
    '8': ['A', 'B', 'C'],
    '9': ['A', 'B', 'C'],
    '10': ['A', 'B', 'C'],
    '11': ['A', 'B'],
    '12': ['A', 'B'],
  };

  @override
  void initState() {
    super.initState();
    _selectedClass = widget.initialClass ?? _classes.first;
    _selectedSection = _sectionMap[_selectedClass]?.first;
    widget.onClassChanged(_selectedClass);
    widget.onSectionChanged(_selectedSection);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedClass,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.numbers),
          ),
          onChanged: (String? newValue) {
            setState(() {
              _selectedClass = newValue ?? '';
              _selectedSection = _sectionMap[_selectedClass]?.first;
            });
            widget.onClassChanged(_selectedClass);
            widget.onSectionChanged(_selectedSection);
          },
          items: _classes.map<DropdownMenuItem<String>>(
            (String value) => DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            ),
          ).toList(),
        ),
        if (_selectedClass.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedSection,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Section',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.format_list_numbered),
            ),
            onChanged: (String? newValue) {
              setState(() => _selectedSection = newValue);
              widget.onSectionChanged(_selectedSection);
            },
            items: (_sectionMap[_selectedClass] ?? [])
                .map<DropdownMenuItem<String>>(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}