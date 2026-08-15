import 'package:flutter/material.dart';

import '../../domain/entities/family_list_item.dart';

/// A tappable family row in the search results. Shows enough detail to
/// distinguish similar families (ID, guardian, mother, phone, student count).
class FamilyCard extends StatelessWidget {
  const FamilyCard({super.key, required this.item, required this.onTap});

  final FamilyListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final family = item.family;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  family.familyId,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            family.guardianName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (family.isArchived)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.outlineVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Archived',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (family.motherName != null &&
                        family.motherName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Mother: ${family.motherName}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (family.primaryPhone != null &&
                        family.primaryPhone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Phone: ${family.primaryPhone}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (family.address != null &&
                        family.address!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        family.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${item.studentCount} '
                      '${item.studentCount == 1 ? 'child' : 'children'}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
