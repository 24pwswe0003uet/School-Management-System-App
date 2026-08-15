/// A single row in one of the dashboard's recent-activity lists.
class RecentActivityItem {
  const RecentActivityItem({
    required this.title,
    required this.subtitle,
    this.amount,
    this.dateTime,
  });

  final String title;
  final String subtitle;
  final double? amount;
  final DateTime? dateTime;
}
