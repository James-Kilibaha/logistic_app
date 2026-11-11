import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/api/api_client.dart';
import '../../core/branding.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/states.dart';

/// Kuandika "code ya kampuni" (mf. ymg) - app ya simu, au web iliyofunguliwa kwenye domain ya mfumo.
/// Inarudisha `true` kampuni ikipatikana.
Future<bool> showCompanyDialog({bool dismissible = true}) async {
  final ctx = Get.overlayContext ?? Get.context;
  if (ctx == null) return false;
  final ok = await showDialog<bool>(
    context: ctx,
    barrierDismissible: dismissible,
    builder: (_) => _CompanyDialog(dismissible: dismissible),
  );
  return ok == true;
}

class _CompanyDialog extends StatefulWidget {
  final bool dismissible;

  const _CompanyDialog({required this.dismissible});

  @override
  State<_CompanyDialog> createState() => _CompanyDialogState();
}

class _CompanyDialogState extends State<_CompanyDialog> {
  final _code = TextEditingController(text: BrandingController.to.current.value.slug);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim().toLowerCase();
    if (code.length < 3) {
      setState(() => _error = 'companyCodeInvalid'.tr);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await BrandingController.to.useCompany(code);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'companyNotFound'.tr);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.apartment_rounded, color: p.primary),
          const SizedBox(width: 10),
          Expanded(child: Text('companyCode'.tr)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('companyCodeHelp'.tr, style: TextStyle(color: p.muted, height: 1.4)),
            const SizedBox(height: 16),
            FieldLabel('companyCode'.tr, required: true),
            TextField(
              controller: _code,
              autofocus: true,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'companyCodeHint'.tr,
                prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.dismissible)
          TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: Text('cancel'.tr)),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const ButtonSpinner() : Text('continue'.tr),
        ),
      ],
    );
  }
}
