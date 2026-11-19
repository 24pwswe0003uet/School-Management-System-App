import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config/app_config.dart';

/// Form input specifically tailored for monetary amounts formatted with AppConfig.currencySymbol (Rs).
class AppMoneyField extends StatelessWidget {
  const AppMoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText = '0',
    this.validator,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final String? Function(String?)? validator;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixText: '${AppConfig.currencySymbol} ',
        prefixStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }
}
