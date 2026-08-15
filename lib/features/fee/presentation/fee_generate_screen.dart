import 'package:flutter/material.dart';

import '../application/fee_service.dart';
import '../domain/entities/fee_generation_result.dart';
import '../domain/entities/fee_period.dart';
import 'widgets/month_period_picker.dart';

/// Generates the monthly fee charges for all active students.
class FeeGenerateScreen extends StatefulWidget {
  const FeeGenerateScreen({super.key, required this.feeService});

  final FeeService feeService;

  @override
  State<FeeGenerateScreen> createState() => _FeeGenerateScreenState();
}

class _FeeGenerateScreenState extends State<FeeGenerateScreen> {
  FeePeriod _period = FeePeriod.current();

  Future<void> _generate() async {
    try {
      await widget.feeService.generate(year: _period.year, month: _period.month);
      final result = widget.feeService.lastGeneration;
      if (!mounted) return;
      if (result != null && result.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Nothing to do — no active students found.'),
            ),
          );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              widget.feeService.errorMessage ?? 'Generation failed.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Monthly Fee')),
      body: ListenableBuilder(
        listenable: widget.feeService,
        builder: (context, _) {
          final service = widget.feeService;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: MonthPeriodPicker(
                  period: _period,
                  onChanged: service.running
                      ? (_) {}
                      : (period) => setState(() => _period = period),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'One charge is created for every active student for '
                        '${_period.label}. The amount comes from the '
                        'student\'s class fee rule, or the default rule when '
                        'no class rule exists.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('generate_button'),
                          onPressed: service.running ? null : _generate,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: Text('Generate for ${_period.label}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (service.running) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generating… ${service.processed} of ${service.total}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          key: const Key('generate_progress'),
                          value: service.total == 0
                              ? null
                              : service.processed / service.total,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (service.lastGeneration != null) ...[
                const SizedBox(height: 16),
                _ResultCard(result: service.lastGeneration!),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final FeeGenerationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Done',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _line(theme, Icons.check_circle, Colors.green,
                '${result.created} fee records created'),
            _line(theme, Icons.info, Colors.orange,
                '${result.alreadyExists} already charged — skipped'),
            _line(theme, Icons.warning_amber, Colors.red,
                '${result.noRule} students have no fee rule'),
          ],
        ),
      ),
    );
  }

  Widget _line(ThemeData theme, IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
