import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../domain/notification_item.dart';
import '../domain/sale_event.dart';

/// Parses the 42 intra notifications page.
///
/// DOM shape (confirmed against profile.intra.42.fr/notifications):
/// ```
/// <ul class="vertical-list" id="notification-list">
///   <ul class="pagination">...</ul>
///   <a class="notification-link" href="https://profile.intra.42.fr/events/XX">
///     <li class="notification-item vertical-list-item">
///       <div class="notification-item--body">…text…</div>
///       <div class="notification-item--footer">…time…</div>
///     </li>
///   </a>
///   ...
/// </ul>
/// ```
///
/// Sale phrases (confirmed):
///   start: "Evaluation points sales are now starting for a limited time ! Enjoy !"
///   end:   "Evaluation points sales are now over."
class NotificationParser {
  static const _jstOffset = Duration(hours: 9);

  /// Anchor phrase — both start and end notifications contain this.
  static final _saleAnchor = RegExp(
    r'evaluation\s+points?\s+sales',
    caseSensitive: false,
  );
  static final _saleEnd = RegExp(r'\b(over|ended|finished)\b', caseSensitive: false);
  static final _saleStart = RegExp(
    r'\b(starting|started|start|begin|now\s+on)\b',
    caseSensitive: false,
  );

  List<SaleEvent> parse(String html) {
    final doc = html_parser.parse(html);
    final items = _findItems(doc);
    final events = <SaleEvent>[];
    for (final el in items) {
      final ev = _toSaleEvent(el);
      if (ev != null) events.add(ev);
    }
    return events;
  }

  List<NotificationItem> parseAll(String html) {
    final doc = html_parser.parse(html);
    final items = _findItems(doc);
    final result = <NotificationItem>[];
    for (final el in items) {
      final body = _bodyText(el);
      if (body.isEmpty) continue;
      final isSale = _saleAnchor.hasMatch(body);
      result.add(NotificationItem(
        occurredAt: _extractDateTime(el),
        text: body,
        url: _href(el),
        isSaleRelated: isSale,
      ));
    }
    return result;
  }

  // ─── internals ────────────────────────────────────────────────────────────

  List<Element> _findItems(Document doc) {
    // Each <a class="notification-link"> wraps one <li class="notification-item">.
    final inList = doc.querySelectorAll(
      '#notification-list a.notification-link',
    );
    if (inList.isNotEmpty) return inList;
    return doc.querySelectorAll('a.notification-link');
  }

  String _bodyText(Element a) {
    final body = a.querySelector('.notification-item--body');
    final raw = (body ?? a).text;
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _href(Element a) {
    final h = a.attributes['href'];
    if (h == null || h.isEmpty || h == '#') return null;
    return h;
  }

  SaleEvent? _toSaleEvent(Element a) {
    final body = _bodyText(a);
    if (body.isEmpty) return null;
    if (!_saleAnchor.hasMatch(body)) return null;
    final type = _detectType(body);
    if (type == null) return null;
    final when = _extractDateTime(a) ?? DateTime.now().toUtc();
    return SaleEvent(
      type: type,
      occurredAt: when,
      rawTitle: body,
      sourceUrl: _href(a),
    );
  }

  SaleEventType? _detectType(String text) {
    if (_saleEnd.hasMatch(text)) return SaleEventType.end;
    if (_saleStart.hasMatch(text)) return SaleEventType.start;
    return null;
  }

  DateTime? _extractDateTime(Element a) {
    // 1. <time datetime="..."> anywhere inside the item is the gold standard.
    final timeEl = a.querySelector('time[datetime]');
    final dt = timeEl?.attributes['datetime'];
    if (dt != null) {
      final parsed = DateTime.tryParse(dt);
      if (parsed != null) return parsed.toUtc();
    }
    // 2. data-time / data-datetime / title attributes some sites use.
    for (final el in [a, ...a.children]) {
      for (final attr in ['data-time', 'data-datetime', 'title']) {
        final v = el.attributes[attr];
        if (v == null) continue;
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed.toUtc();
      }
    }
    // 3. Look only inside the footer for a date pattern (avoid matching
    //    numbers in the body like "for 2 days").
    final footer = a.querySelector('.notification-item--footer');
    return _parseFromText((footer ?? a).text);
  }

  /// Public for testing.
  static DateTime? parseDateTimeFromText(String text) => _parseFromText(text);

  static DateTime? _parseFromText(String text) {
    final iso = RegExp(
      r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})[ T](\d{1,2}):(\d{2})',
    ).firstMatch(text);
    if (iso != null) {
      return _buildJst(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
        int.parse(iso.group(4)!),
        int.parse(iso.group(5)!),
      );
    }
    final jp = RegExp(
      r'(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日(?:\([^)]*\))?\s*(\d{1,2})[:：](\d{2})',
    ).firstMatch(text);
    if (jp != null) {
      return _buildJst(
        int.parse(jp.group(1)!),
        int.parse(jp.group(2)!),
        int.parse(jp.group(3)!),
        int.parse(jp.group(4)!),
        int.parse(jp.group(5)!),
      );
    }
    final dateOnly =
        RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(text);
    if (dateOnly != null) {
      return _buildJst(
        int.parse(dateOnly.group(1)!),
        int.parse(dateOnly.group(2)!),
        int.parse(dateOnly.group(3)!),
        0,
        0,
      );
    }
    return null;
  }

  static DateTime _buildJst(int y, int mo, int d, int h, int mi) {
    return DateTime.utc(y, mo, d, h, mi).subtract(_jstOffset);
  }
}
