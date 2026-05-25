enum SaleEventType { start, end }

class SaleEvent {
  final SaleEventType type;
  final DateTime occurredAt;
  final String rawTitle;
  final String? sourceUrl;

  const SaleEvent({
    required this.type,
    required this.occurredAt,
    required this.rawTitle,
    this.sourceUrl,
  });

  @override
  String toString() =>
      'SaleEvent(${type.name}, $occurredAt, "$rawTitle")';
}
