import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/company.dart';
import '../company/subscription_page.dart' show subscriptionLook;
import 'platform_api.dart';

/// Mipango yote (kwa fomu za admin panel).
Future<List<Plan>> loadPlans() async {
  final body = await PlatformApi.get('plans');
  if (body is! List) return [];
  return body.whereType<Map>().map((e) => Plan.fromJson(Map<String, dynamic>.from(e))).toList();
}

String money(String currency, num value) => '$currency ${Fmt.number(value)}';

/// Hali ya subscription kama kidonge (TRIAL · siku 5).
class SubscriptionPill extends StatelessWidget {
  final SubscriptionState? state;

  const SubscriptionPill(this.state, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final st = state;
    if (st == null) return const SizedBox.shrink();
    final (Color color, String label) = subscriptionLook(p, st.status);
    final days = st.daysLeft;
    final extra = days == null ? '' : (days >= 0 ? ' · ${'saDaysN'.trParams({'n': '$days'})}' : '');
    return Pill('$label$extra', color: color, dense: true);
  }
}

/// Hali ya kampuni: ACTIVE / PENDING / SUSPENDED / REJECTED.
class CompanyStatusPill extends StatelessWidget {
  final String status;

  const CompanyStatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return switch (status) {
      'PENDING' => Pill('saPending'.tr, color: p.warning, dense: true, icon: Icons.hourglass_top_rounded),
      'SUSPENDED' => Pill('saSuspended'.tr, color: p.danger, dense: true, icon: Icons.block_rounded),
      'REJECTED' => Pill('saRejected'.tr, color: p.danger, dense: true, icon: Icons.cancel_outlined),
      _ => Pill('saActive'.tr, color: p.success, dense: true),
    };
  }
}

/// Ukurasa unaopakia data moja (loading / kosa / data).
class SaLoader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  const SaLoader({super.key, required this.load, required this.builder});

  @override
  State<SaLoader<T>> createState() => _SaLoaderState<T>();
}

class _SaLoaderState<T> extends State<SaLoader<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.load();
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      if (_error != null) return ErrorState(message: _error.toString(), onRetry: _reload);
      return const LoadingList();
    }
    return Stack(
      children: [
        widget.builder(context, data, _reload),
        if (_loading) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
      ],
    );
  }
}

/// Kichwa cha sehemu: kichwa + vitufe (mf. "Sajili kampuni").
class SaHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const SaHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 10,
      spacing: 10,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.text)),
            if (subtitle != null) Text(subtitle!, style: TextStyle(color: p.muted, fontSize: 13)),
          ],
        ),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    );
  }
}
