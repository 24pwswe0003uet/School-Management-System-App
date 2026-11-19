import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Form input with calendar picker for standardized date capture.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.label,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
  });

  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final String label;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final displayText = selectedDate != null
        ? DateFormat('dd MMM yyyy').format(selectedDate!)
        : 'Select date';

    return InkWell(
      onTap: enabled
          ? () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? DateTime.now(),
                firstDate: firstDate ?? DateTime(2000),
                lastDate: lastDate ?? DateTime(2100),
              );
              if (picked != null) {
                onDateSelected(picked);
              }
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
          enabled: enabled,
        ),
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: 14,
            color: selectedDate != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
