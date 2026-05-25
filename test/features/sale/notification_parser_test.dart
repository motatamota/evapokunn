import 'package:flutter_test/flutter_test.dart';
import 'package:sale_tracker/features/sale/data/notification_parser.dart';
import 'package:sale_tracker/features/sale/domain/sale_event.dart';

String _page({required String items}) => '''
<html><body>
  <div class="page-content">
    <ul class="vertical-list" id="notification-list">
      <ul class="pagination"></ul>
      $items
    </ul>
  </div>
</body></html>
''';

String _item({
  required String body,
  String href = '#',
  String? datetime,
}) {
  final footer = datetime == null
      ? '<div class="notification-item--footer">just now</div>'
      : '<div class="notification-item--footer">'
          '<time datetime="$datetime">x</time></div>';
  return '''
<a class="notification-link" href="$href">
  <li class="notification-item vertical-list-item">
    <div class="notification-item--body">$body</div>
    $footer
  </li>
</a>
''';
}

void main() {
  final parser = NotificationParser();

  group('NotificationParser', () {
    test('extracts a start event from the real intra phrase', () {
      final html = _page(items: _item(
        body: 'Evaluation points sales are now starting for a limited time ! Enjoy !',
        href: 'https://profile.intra.42.fr/events/41239',
        datetime: '2026-05-20T10:00:00+09:00',
      ));
      final events = parser.parse(html);
      expect(events, hasLength(1));
      expect(events.first.type, SaleEventType.start);
      expect(events.first.sourceUrl, 'https://profile.intra.42.fr/events/41239');
      expect(events.first.occurredAt, DateTime.utc(2026, 5, 20, 1, 0));
    });

    test('extracts an end event from the real intra phrase', () {
      final html = _page(items: _item(
        body: 'Evaluation points sales are now over.',
        datetime: '2026-05-22T18:00:00+09:00',
      ));
      final events = parser.parse(html);
      expect(events, hasLength(1));
      expect(events.first.type, SaleEventType.end);
    });

    test('extracts both events on the same page in order', () {
      final html = _page(items: '''
${_item(
        body: 'Evaluation points sales are now starting for a limited time ! Enjoy !',
        datetime: '2026-05-20T10:00:00+09:00',
      )}
${_item(
        body: 'Evaluation points sales are now over.',
        datetime: '2026-05-22T18:00:00+09:00',
      )}
''');
      final events = parser.parse(html);
      expect(events.map((e) => e.type), [SaleEventType.start, SaleEventType.end]);
    });

    test('ignores the "sales will start in two days" announcement', () {
      // Real intra wording (category prefix + body) for the
      // "pool is full" pre-announcement. It contains
      // "Evaluation points sales" AND "start" but is NOT a real start
      // event.
      final html = _page(items: _item(
        body: "Evaluation points sales "
            "Cursus 42cursus's evaluation points pool is full. "
            "Sales will start in two days, (20/05/2026 13:10).",
        datetime: '2026-05-18T13:10:00+09:00',
      ));
      expect(parser.parse(html), isEmpty);
      // Still flagged as sale-related in the all-notifications view.
      final all = parser.parseAll(html);
      expect(all, hasLength(1));
      expect(all.first.isSaleRelated, isTrue);
    });

    test('strips repeated category prefix from body text', () {
      final html = _page(items: _item(
        body:
            'Evaluation points sales Evaluation points sales are now over.',
        datetime: '2026-05-20T18:25:00+09:00',
      ));
      final ev = parser.parse(html).single;
      expect(ev.type, SaleEventType.end);
      expect(ev.rawTitle, 'Evaluation points sales are now over.');
    });

    test('ignores non-sale notifications', () {
      final html = _page(items: '''
${_item(body: 'You have been invited to evaluate someone')}
${_item(body: 'Your project corrected: ft_printf')}
${_item(body: 'A new event has been added: Sushi night')}
''');
      expect(parser.parse(html), isEmpty);
    });

    test('parseAll keeps every notification with sale flag', () {
      final html = _page(items: '''
${_item(body: 'Evaluation points sales are now over.', datetime: '2026-05-22T18:00:00+09:00')}
${_item(body: 'You have a new correction', datetime: '2026-05-15T09:00:00+09:00')}
''');
      final items = parser.parseAll(html);
      expect(items, hasLength(2));
      expect(items[0].isSaleRelated, isTrue);
      expect(items[1].isSaleRelated, isFalse);
    });

    test('handles href="#" (no source url)', () {
      final html = _page(items: _item(
        body: 'Evaluation points sales are now starting for a limited time ! Enjoy !',
        href: '#',
        datetime: '2026-05-20T10:00:00+09:00',
      ));
      final events = parser.parse(html);
      expect(events, hasLength(1));
      expect(events.first.sourceUrl, isNull);
    });

    test('parses ISO timestamp from <time datetime>', () {
      final dt = NotificationParser.parseDateTimeFromText(
        'event at 2026-05-25T13:00 JST',
      );
      expect(dt, DateTime.utc(2026, 5, 25, 4, 0));
    });

    test('falls back to "now" when no time info is present', () {
      final html = _page(items: _item(
        body: 'Evaluation points sales are now starting for a limited time ! Enjoy !',
        datetime: null,
      ));
      final ev = parser.parse(html).single;
      expect(
        ev.occurredAt.difference(DateTime.now().toUtc()).inSeconds.abs(),
        lessThan(5),
      );
    });
  });
}
