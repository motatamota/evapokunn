import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sale/presentation/home_page.dart';
import 'auth_service.dart';
import 'auth_status.dart';
import 'web_login_page.dart';

/// Decides what to show on app launch:
///   - while the cookie-based auth probe is in flight → splash
///   - not authenticated → push [WebLoginPage] immediately, then home
///   - authenticated → home
///
/// Only triggers the WebView **once** per app session. If the user
/// dismisses the login WebView without authenticating, they still land
/// on the home page (Settings is reachable from there).
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _scheduled = false;
  bool _dismissed = false;

  Future<void> _showLoginAndContinue() async {
    _scheduled = true;
    final http = await ref.read(httpClientProvider.future);
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WebLoginPage(httpClient: http)),
    );
    if (!mounted) return;
    _dismissed = true;
    ref.invalidate(authStatusProvider);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const HomePage();
    final auth = ref.watch(authStatusProvider);
    return auth.when(
      loading: () => const _Splash(),
      error: (_, __) => const HomePage(),
      data: (ok) {
        if (ok) return const HomePage();
        if (!_scheduled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showLoginAndContinue();
          });
        }
        return const _Splash();
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('えばぽ君.exe'),
          ],
        ),
      ),
    );
  }
}
