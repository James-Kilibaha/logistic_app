import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../api/api_client.dart';
import '../theme/app_theme.dart';
import 'help.dart';
import 'states.dart';

typedef FormBuilderFn = Widget Function(BuildContext context, StateSetter setState);

/// Fomu moja kwa app nzima.
///
/// - Kompyuta / tablet: dirisha (dialog) katikati.
/// - Simu: "bottom sheet" inayopanda kutoka chini (inaacha nafasi ya kibodi).
///
/// Kosa kutoka kwa server linaonyeshwa ndani ya fomu (haifungwi), ili mtumiaji arekebishe.
/// Inarudisha `true` kama [onSubmit] imefanikiwa.
Future<bool> showFormSheet({
  required String title,
  String? subtitle,
  IconData icon = Icons.edit_note_rounded,
  required FormBuilderFn builder,
  required Future<void> Function() onSubmit,
  String? submitLabel,
  IconData? submitIcon,
  bool danger = false,
  double maxWidth = 540,
  String? help,
}) async {
  final ctx = Get.overlayContext ?? Get.context;
  if (ctx == null) return false;
  final bool wide = MediaQuery.sizeOf(ctx).width >= Breakpoints.medium;

  Widget sheet(bool asDialog) => FormSheet(
        title: title,
        subtitle: subtitle,
        icon: icon,
        builder: builder,
        onSubmit: onSubmit,
        submitLabel: submitLabel,
        submitIcon: submitIcon,
        danger: danger,
        asDialog: asDialog,
        help: help,
      );

  final bool? result;
  if (wide) {
    result = await showDialog<bool>(
      context: ctx,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: MediaQuery.sizeOf(context).height * .9),
          child: sheet(true),
        ),
      ),
    );
  } else {
    result = await showModalBottomSheet<bool>(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(top: false, child: sheet(false)),
      ),
    );
  }
  return result == true;
}

class FormSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final FormBuilderFn builder;
  final Future<void> Function() onSubmit;
  final String? submitLabel;
  final IconData? submitIcon;
  final bool danger;
  final bool asDialog;

  /// Mada ya msaada ya fomu (kitufe cha "?" kwenye kichwa).
  final String? help;

  const FormSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.builder,
    required this.onSubmit,
    this.submitLabel,
    this.submitIcon,
    this.danger = false,
    this.asDialog = true,
    this.help,
  });

  @override
  State<FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<FormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ApiException ? e.message : e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget _submitButton(AppPalette p) => FilledButton.icon(
        style: widget.danger ? FilledButton.styleFrom(backgroundColor: p.danger) : null,
        onPressed: _busy ? null : _submit,
        icon: _busy ? const ButtonSpinner() : Icon(widget.submitIcon ?? Icons.check_rounded, size: 20),
        label: Text(widget.submitLabel ?? 'save'.tr),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color accent = widget.danger ? p.danger : p.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---------------------------------------------------------- kichwa
        Padding(
          padding: EdgeInsets.fromLTRB(20, widget.asDialog ? 18 : 0, widget.asDialog ? 10 : 20, 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)),
                child: Icon(widget.icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text)),
                    if (widget.subtitle != null)
                      Text(widget.subtitle!, style: TextStyle(fontSize: 13, color: p.muted)),
                  ],
                ),
              ),
              if (widget.help != null) HelpButton(topic: widget.help!),
              if (widget.asDialog)
                IconButton(
                  tooltip: 'close'.tr,
                  onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: p.border),
        // ----------------------------------------------------------- fomu
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.danger.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: p.danger.withValues(alpha: .3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline_rounded, color: p.danger, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_error!, style: TextStyle(color: p.danger, height: 1.35))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  AbsorbPointer(absorbing: _busy, child: widget.builder(context, setState)),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, color: p.border),
        // -------------------------------------------------------- vitufe
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: widget.asDialog
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: Text('cancel'.tr)),
                    const SizedBox(width: 10),
                    _submitButton(p),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                        child: Text('cancel'.tr),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: _submitButton(p)),
                  ],
                ),
        ),
      ],
    );
  }
}
