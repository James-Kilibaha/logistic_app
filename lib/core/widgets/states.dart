import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/invoice.dart';
import '../theme/app_theme.dart';
import 'layout.dart';

enum LoadStatus { loading, ready, error }

/// Inaonyesha loading / kosa / tupu / data kufuatana na hali ya controller.
class AsyncBody extends StatelessWidget {
  final LoadStatus status;
  final String? error;
  final bool isEmpty;
  final VoidCallback onRetry;
  final Widget empty;
  final Widget Function() builder;

  const AsyncBody({
    super.key,
    required this.status,
    required this.isEmpty,
    required this.onRetry,
    required this.empty,
    required this.builder,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (status == LoadStatus.loading && isEmpty) return const LoadingList();
    if (status == LoadStatus.error && isEmpty) {
      return ErrorState(message: error ?? 'errUnknown'.tr, onRetry: onRetry);
    }
    if (isEmpty) return empty;
    return builder();
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(color: p.primarySoft, shape: BoxShape.circle),
                child: Icon(icon, size: 34, color: p.primary),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text),
              ),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(message!, textAlign: TextAlign.center, style: TextStyle(color: p.muted, height: 1.4)),
              ],
              if (action != null) ...[const SizedBox(height: 18), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(color: p.danger.withValues(alpha: .1), shape: BoxShape.circle),
                child: Icon(Icons.cloud_off_rounded, size: 34, color: p.danger),
              ),
              const SizedBox(height: 18),
              Text(
                'loadFailed'.tr,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text),
              ),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center, style: TextStyle(color: p.muted, height: 1.4)),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text('tryAgain'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Mifupa" ya orodha wakati data inapakiwa.
class LoadingList extends StatefulWidget {
  final int rows;

  const LoadingList({super.key, this.rows = 6});

  @override
  State<LoadingList> createState() => _LoadingListState();
}

class _LoadingListState extends State<LoadingList> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ContentBox(
      child: FadeTransition(
        opacity: Tween<double>(begin: .45, end: 1).animate(_c),
        child: Column(
          children: [
            for (int i = 0; i < widget.rows; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: p.surfaceAlt, shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _bar(p, 160),
                          const SizedBox(height: 8),
                          _bar(p, 100),
                        ],
                      ),
                    ),
                    _bar(p, 60),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bar(AppPalette p, double width) => Container(
        width: width,
        height: 11,
        decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(6)),
      );
}

/// Kiashiria kidogo cha loading ndani ya kitufe.
class ButtonSpinner extends StatelessWidget {
  final Color? color;

  const ButtonSpinner({super.key, this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: color ?? Colors.white),
      );
}

/// Kadi ya takwimu (dashboard).
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? hint;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.hint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 13)),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: p.text, letterSpacing: -.2),
                      ),
                    ),
                    if (hint != null)
                      Text(hint!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12)),
                  ],
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right_rounded, color: p.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rangi, ikoni na jina la kila hatua ya mzigo.
class StatusStyle {
  final Color color;
  final IconData icon;
  final String label;

  const StatusStyle(this.color, this.icon, this.label);

  static StatusStyle of(InvoiceStatus status) => switch (status) {
        InvoiceStatus.open => StatusStyle(const Color(0xFF4F46E5), Icons.inventory_2_outlined, 'stOpen'.tr),
        InvoiceStatus.parking => StatusStyle(const Color(0xFFD97706), Icons.move_to_inbox_outlined, 'stParking'.tr),
        InvoiceStatus.shipping => StatusStyle(const Color(0xFF0284C7), Icons.local_shipping_outlined, 'stShipping'.tr),
        InvoiceStatus.store => StatusStyle(const Color(0xFF7C3AED), Icons.warehouse_outlined, 'stStore'.tr),
        InvoiceStatus.delivered => StatusStyle(const Color(0xFFB45309), Icons.handshake_outlined, 'stDelivered'.tr),
        InvoiceStatus.completed => StatusStyle(const Color(0xFF15803D), Icons.task_alt_rounded, 'stCompleted'.tr),
        InvoiceStatus.blocked => StatusStyle(const Color(0xFFDC2626), Icons.block_rounded, 'stBlocked'.tr),
        InvoiceStatus.other => StatusStyle(const Color(0xFF64748B), Icons.help_outline_rounded, 'stOther'.tr),
      };
}

class StatusChip extends StatelessWidget {
  final InvoiceStatus status;
  final bool dense;

  const StatusChip(this.status, {super.key, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final s = StatusStyle.of(status);
    return Pill(s.label, color: s.color, icon: dense ? null : s.icon, dense: dense);
  }
}
