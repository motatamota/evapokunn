import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_fetcher.dart';

/// Debug page (spec §8.4): fetch the notifications HTML and dump it
/// to the screen so we can inspect the DOM structure.
class RawHtmlPage extends ConsumerStatefulWidget {
  const RawHtmlPage({super.key});

  @override
  ConsumerState<RawHtmlPage> createState() => _RawHtmlPageState();
}

class _RawHtmlPageState extends ConsumerState<RawHtmlPage> {
  bool _busy = false;
  int? _status;
  String? _html;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final fetcher = await ref.read(notificationFetcherProvider.future);
      final res = await fetcher.fetch();
      setState(() {
        _status = res.statusCode;
        _html = res.html;
        if (res.needsLogin) _error = 'ログインが必要です (Settings から)';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raw HTML'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          if (_html != null)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _html!));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_status != null) Text('HTTP $_status'),
            if (_error != null) Text('Error: $_error'),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _html ?? '取得していません。右上の更新を押してください。',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
