/// A single raw notification scraped from the notifications page.
class NotificationItem {
  final DateTime? occurredAt;
  final String text;
  final String? url;
  final bool isSaleRelated;

  const NotificationItem({
    required this.occurredAt,
    required this.text,
    this.url,
    this.isSaleRelated = false,
  });
}
