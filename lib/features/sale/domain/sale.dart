class Sale {
  final int id;
  final DateTime startAt;
  final DateTime? endAt;
  final String title;
  final DateTime detectedAt;

  const Sale({
    required this.id,
    required this.startAt,
    this.endAt,
    required this.title,
    required this.detectedAt,
  });

  bool get isOngoing => endAt == null;

  Duration? get duration => endAt?.difference(startAt);
}
