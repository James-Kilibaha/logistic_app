import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/api/api_client.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';

/// Kubadilisha anwani ya server (bila kujenga app upya).
Future<void> showServerDialog() async {
  final ctx = Get.overlayContext ?? Get.context;
  if (ctx == null) return;
  await showDialog<void>(context: ctx, builder: (_) => const _ServerDialog());
}

class _ServerDialog extends StatefulWidget {
  const _ServerDialog();

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

enum _Check { none, checking, ok, failed }

class _ServerDialogState extends State<_ServerDialog> {
  late final TextEditingController _url =
      TextEditingController(text: Session.server.replaceFirst(RegExp(r'^http://'), ''));
  _Check _check = _Check.none;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() => _check = _Check.checking);
    final ok = await Api.ping(_url.text);
    if (mounted) setState(() => _check = ok ? _Check.ok : _Check.failed);
  }

  Future<void> _save() async {
    await Session.saveServer(_url.text);
    if (!mounted) return;
    Navigator.of(context).pop();
    Toast.success(Session.server, title: 'serverSaved'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (Color color, IconData icon, String text) = switch (_check) {
      _Check.ok => (p.success, Icons.check_circle_rounded, 'serverOk'.tr),
      _Check.failed => (p.danger, Icons.error_rounded, 'serverFailed'.tr),
      _ => (p.muted, Icons.info_outline_rounded, 'serverHelp'.tr),
    };

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.dns_outlined, color: p.primary),
          const SizedBox(width: 10),
          Text('server'.tr),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel('serverAddress'.tr),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              onChanged: (_) {
                if (_check != _Check.none) setState(() => _check = _Check.none);
              },
              decoration: const InputDecoration(
                hintText: '192.168.1.200:8000',
                prefixIcon: Icon(Icons.link_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_check == _Check.checking)
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.primary))
                else
                  Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _check == _Check.checking ? 'checking'.tr : text,
                    style: TextStyle(color: color, fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _check == _Check.checking ? null : _test, child: Text('testConnection'.tr)),
        FilledButton(onPressed: _save, child: Text('save'.tr)),
      ],
    );
  }
}
