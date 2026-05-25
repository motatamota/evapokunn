import 'package:intl/intl.dart';

const _jstOffset = Duration(hours: 9);

/// Formats a [when] as JST regardless of the device timezone.
///
/// 42 intra dates are inherently in JST (or arrive tagged as such), but
/// the Android emulator often runs in UTC which makes [.toLocal] return
/// UTC. We avoid the problem entirely by computing the JST wall clock
/// as a UTC-flagged DateTime and letting DateFormat read the raw fields.
String fmtJst(DateTime when, [String pattern = 'yyyy/MM/dd HH:mm']) {
  final wallClock = when.toUtc().add(_jstOffset);
  return DateFormat(pattern, 'ja').format(wallClock);
}
