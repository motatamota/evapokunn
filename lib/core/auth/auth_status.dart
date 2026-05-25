import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';

final authStatusProvider = FutureProvider<bool>((ref) async {
  final auth = await ref.watch(authServiceProvider.future);
  return auth.ensureAuthenticated();
});

/// Returns the logged-in user's login name (e.g. "ahirayam") or null
/// if we're not authenticated. Cached for the app session; invalidate
/// after login/logout.
final usernameProvider = FutureProvider<String?>((ref) async {
  final authed = await ref.watch(authStatusProvider.future);
  if (!authed) return null;
  final auth = await ref.watch(authServiceProvider.future);
  return auth.fetchUsername();
});

/// True once this app session has already prompted the user to log in
/// via WebView. Prevents re-opening the WebView on every rebuild after
/// the user dismisses it without logging in.
final loginPromptShownProvider = StateProvider<bool>((_) => false);
