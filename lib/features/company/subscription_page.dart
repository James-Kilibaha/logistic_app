import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/branding.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/states.dart';
import '../../data/models/company.dart';
import '../../data/models/json.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../payments/online_pay.dart';

const _methods = ['M-PESA', 'TIGO PESA', 'AIRTEL MONEY', 'HALOPESA', 'BANK', 'CASH'];

/// Rangi na maandishi ya hali ya subscription.
(Color, String) subscriptionLook(AppPalette p, String status) => switch (status) {
      'TRIAL' => (p.info, 'subTrial'.tr),
      'ACTIVE' => (p.success, 'subActive'.tr),
      'GRACE' => (p.warning, 'subGrace'.tr),
      'EXPIRED' => (p.danger, 'subExpired'.tr),
      _ => (p.danger, 'subNone'.tr),
    };

/// Subscription ya kampuni: mpango, muda uliobaki, matumizi, kulipia na historia.
class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  SubscriptionOverview? _data;
  LoadStatus _status = LoadStatus.loading;
  String? _error;

  bool get _canPay => AppController.to.can(AppModule.setting, AppAction.update);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    try {
      final data = await CompanyRepo.subscription();
      BrandingController.to.subscription.value = data.state;
      setState(() {
        _data = data;
        _status = LoadStatus.ready;
      });
    } catch (e) {
      setState(() {
        _status = LoadStatus.error;
        _error = e.toString();
      });
    }
  }

  /// Kulipia: kwa simu sasa hivi (kama mtoa huduma ameweka AzamPay), au kutuma taarifa ya malipo yaliyofanyika.
  Future<void> _pay({Plan? plan}) async {
    final data = _data;
    if (data == null || data.plans.isEmpty) return;
    bool mobile = false;
    try {
      mobile = J.boolean((await OnlinePayRepo.subscriptionInfo())['enabled']);
    } catch (_) {}
    if (!mobile) return _payManual(plan: plan);
    final ctx = Get.overlayContext ?? Get.context;
    if (ctx == null) return;
    final choice = await showModalBottomSheet<String>(
      context: ctx,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.phone_iphone_rounded, color: context.palette.primary),
              title: Text('subPayMobile'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('subPayMobileSub'.tr),
              onTap: () => Navigator.of(context).pop('mobile'),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text('subPayManual'.tr),
              subtitle: Text('subPayManualSub'.tr),
              onTap: () => Navigator.of(context).pop('manual'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == 'manual') return _payManual(plan: plan);
    if (choice == 'mobile') return _payMobile(plan: plan);
  }

  Future<void> _payMobile({Plan? plan}) async {
    final data = _data;
    if (data == null) return;
    final plans = data.plans.where((pl) => pl.currency.toUpperCase() == 'TZS' && pl.price > 0).toList();
    if (plans.isEmpty) return _payManual(plan: plan);
    Plan selected = plan != null && plans.contains(plan) ? plan : (data.state.plan != null && plans.contains(data.state.plan) ? data.state.plan! : plans.first);
    int periods = 1;
    final phone = TextEditingController();
    final coupon = TextEditingController();
    Map<String, dynamic>? priced; // bei baada ya coupon (null = bila coupon)
    String? couponError;
    String? provider;
    String startMode = 'QUEUE';
    Map<String, dynamic>? started;
    final ok = await showFormSheet(
      title: 'subPayMobile'.tr,
      subtitle: 'subPayMobileSub'.tr,
      icon: Icons.phone_iphone_rounded,
      submitLabel: 'paySendRequest'.tr,
      submitIcon: Icons.send_to_mobile_rounded,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDropdown<Plan>(
            label: 'plan'.tr,
            value: selected,
            items: plans,
            itemLabel: (pl) => '${pl.name} - ${pl.currency} ${Fmt.number(pl.price)}',
            onChanged: (v) => setState(() {
              selected = v ?? selected;
              priced = null;
            }),
          ),
          const SizedBox(height: 16),
          AppDropdown<int>(
            label: 'subPeriods'.tr,
            value: periods,
            items: const [1, 2, 3, 6, 12],
            itemLabel: (n) => 'subPeriodN'.trParams({'n': '$n', 'm': '${n * selected.months}'}),
            onChanged: (v) => setState(() {
              periods = v ?? periods;
              priced = null;
            }),
          ),
          const SizedBox(height: 16),
          _CouponField(
            controller: coupon,
            priced: priced,
            error: couponError,
            onApply: () async {
              try {
                final r = await CompanyRepo.checkCoupon(coupon.text, selected.id, periods);
                setState(() {
                  priced = r;
                  couponError = null;
                });
              } catch (e) {
                setState(() {
                  priced = null;
                  couponError = e.toString();
                });
              }
            },
          ),
          const SizedBox(height: 16),
          PhoneField(
            controller: phone,
            label: 'payPhone'.tr,
            required: true,
            onChanged: (v) {
              final g = guessProvider(v);
              if (g != null && g != provider) setState(() => provider = g);
            },
          ),
          const SizedBox(height: 16),
          AppDropdown<String>(
            label: 'payNetwork'.tr,
            value: provider,
            items: [for (final p in mobileProviders) p.$1],
            itemLabel: (v) => mobileProviders.firstWhere((p) => p.$1 == v).$2,
            required: true,
            validator: (v) => v == null ? 'fieldRequired'.tr : null,
            onChanged: (v) => setState(() => provider = v),
          ),
          _PlanChangeBox(
            key: ValueKey('${selected.id}-$periods'),
            planId: selected.id,
            periods: periods,
            mode: startMode,
            onMode: (m) => setState(() => startMode = m),
          ),
          const SizedBox(height: 16),
          InfoRow(
            label: 'payAmount'.tr,
            value: 'TZS ${Fmt.number(priced == null ? selected.price * periods : J.dbl(priced!['amount']))}',
            emphasize: true,
          ),
          const SizedBox(height: 8),
          Text('payHowItWorks'.tr, style: TextStyle(color: context.palette.muted, fontSize: 12.5, height: 1.4)),
        ],
      ),
      onSubmit: () async => started = await OnlinePayRepo.paySubscription(selected.id, periods, phone.text, provider!,
          coupon: coupon.text, startMode: startMode),
    );
    if (!ok || started == null) return;
    final paid = await waitForMobilePayment(started!, OnlinePayRepo.subscriptionStatus);
    if (paid) {
      Toast.success('subPaidMobile'.tr);
      await _load();
    }
  }

  Future<void> _payManual({Plan? plan}) async {
    final data = _data;
    if (data == null || data.plans.isEmpty) return;
    Plan selected = plan ?? data.state.plan ?? data.plans.first;
    if (!data.plans.contains(selected)) selected = data.plans.first;
    int periods = 1;
    String method = _methods.first;
    final amount = TextEditingController(text: Fmt.number(selected.price));
    final reference = TextEditingController();
    final note = TextEditingController();
    final coupon = TextEditingController();
    Map<String, dynamic>? priced;
    String? couponError;
    String startMode = 'QUEUE';

    void recalc() {
      priced = null;
      amount.text = Fmt.number(selected.price * periods);
    }

    final ok = await showFormSheet(
      title: 'subPayTitle'.tr,
      subtitle: 'subPaySub'.tr,
      icon: Icons.payments_outlined,
      submitLabel: 'subSendPayment'.tr,
      builder: (context, setState) {
        final p = context.palette;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.payTo != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('subPayTo'.tr, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                    const SizedBox(height: 4),
                    SelectableText(data.payTo!, style: TextStyle(color: p.text, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            AppDropdown<Plan>(
              label: 'plan'.tr,
              value: selected,
              items: data.plans,
              itemLabel: (pl) => '${pl.name} - ${pl.currency} ${Fmt.number(pl.price)}',
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  selected = v;
                  recalc();
                });
              },
            ),
            const SizedBox(height: 16),
            AppDropdown<int>(
              label: 'subPeriods'.tr,
              value: periods,
              items: const [1, 2, 3, 6, 12],
              itemLabel: (n) => 'subPeriodN'.trParams({'n': '$n', 'm': '${n * selected.months}'}),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  periods = v;
                  recalc();
                });
              },
            ),
            const SizedBox(height: 16),
            _CouponField(
              controller: coupon,
              priced: priced,
              error: couponError,
              onApply: () async {
                try {
                  final r = await CompanyRepo.checkCoupon(coupon.text, selected.id, periods);
                  setState(() {
                    priced = r;
                    couponError = null;
                    amount.text = Fmt.number(J.dbl(r['amount']));
                  });
                } catch (e) {
                  setState(() {
                    priced = null;
                    couponError = e.toString();
                  });
                }
              },
            ),
            _PlanChangeBox(
              key: ValueKey('${selected.id}-$periods'),
              planId: selected.id,
              periods: periods,
              mode: startMode,
              onMode: (m) => setState(() => startMode = m),
            ),
            const SizedBox(height: 16),
            AppField(
              controller: amount,
              label: 'amountPaid'.tr,
              icon: Icons.attach_money_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              required: true,
              validator: Validators.positive,
            ),
            const SizedBox(height: 16),
            AppDropdown<String>(
              label: 'paymentMethod'.tr,
              value: method,
              items: _methods,
              itemLabel: (m) => m,
              onChanged: (v) => setState(() => method = v ?? method),
            ),
            const SizedBox(height: 16),
            AppField(
              controller: reference,
              label: 'transactionRef'.tr,
              hint: 'QWE12RTY34',
              icon: Icons.receipt_outlined,
              required: true,
              validator: Validators.minLength(3),
            ),
            const SizedBox(height: 16),
            AppField(controller: note, label: 'note'.tr, maxLines: 3, minLines: 2),
          ],
        );
      },
      onSubmit: () => CompanyRepo.submitPayment({
        'plan_id': selected.id,
        'periods': periods,
        'amount': Fmt.parse(amount.text) ?? 0,
        'currency': selected.currency,
        'method': method,
        'reference': reference.text.trim(),
        if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
        if (coupon.text.trim().isNotEmpty) 'couponCode': coupon.text.trim(),
        'startMode': startMode,
      }),
    );
    if (ok) {
      Toast.success('subPaymentSentMsg'.tr, title: 'subPaymentSent'.tr);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'subscription'.tr,
      subtitle: BrandingController.to.current.value.platform.name,
      showBack: true,
      actions: [
        IconButton(tooltip: 'refresh'.tr, onPressed: _status == LoadStatus.loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded)),
      ],
      mainAction: _canPay && _data != null && _data!.plans.isNotEmpty
          ? PageAction(icon: Icons.payments_outlined, label: 'subPayNow'.tr, onPressed: () => _pay())
          : null,
      body: _data == null
          ? (_status == LoadStatus.error
              ? ErrorState(message: _error ?? 'errUnknown'.tr, onRetry: _load)
              : const LoadingList())
          : _content(context, _data!),
    );
  }

  Widget _content(BuildContext context, SubscriptionOverview d) {
    final p = context.palette;
    final st = d.state;
    final (Color color, String label) = subscriptionLook(p, st.status);
    final plan = st.plan;

    final pending = d.payments.where((x) => x.status == 'PENDING').toList();

    return PageScroll(
      onRefresh: _load,
      children: [
        // ------------------------------------------------------------ hali
        SectionCard(
          title: plan?.name ?? 'subNoPlan'.tr,
          subtitle: 'subCurrentPlan'.tr,
          icon: Icons.workspace_premium_outlined,
          trailing: Pill(label, color: color),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (st.endsAt != null)
                InfoRow(
                  label: st.status == 'EXPIRED' || st.status == 'GRACE' ? 'subEndedOn'.tr : 'subEndsOn'.tr,
                  value: Fmt.date(st.endsAt),
                  icon: Icons.event_outlined,
                ),
              if (st.daysLeft != null && st.daysLeft! >= 0)
                InfoRow(label: 'subDaysLeft'.tr, value: '${st.daysLeft}', icon: Icons.hourglass_bottom_rounded,
                    emphasize: st.daysLeft! <= 7),
              if (plan != null)
                InfoRow(label: 'price'.tr, value: '${plan.currency} ${Fmt.number(plan.price)} / '
                    '${plan.months == 1 ? 'monthWord'.tr : 'monthsN'.trParams({'n': '${plan.months}'})}',
                    icon: Icons.sell_outlined),
              if (st.readOnly) ...[
                const SizedBox(height: 10),
                _notice(context, p.danger, Icons.lock_clock_outlined, 'subReadOnlyMsg'.tr),
              ] else if (st.status == 'GRACE' && st.graceEndsAt != null) ...[
                const SizedBox(height: 10),
                _notice(context, p.warning, Icons.warning_amber_rounded,
                    'subGraceMsg'.trParams({'date': Fmt.date(st.graceEndsAt)})),
              ],
              if (st.upcomingPlan != null && st.upcomingStartsAt != null) ...[
                const SizedBox(height: 10),
                _notice(context, p.info, Icons.schedule_rounded,
                    'subUpcoming'.trParams({'plan': st.upcomingPlan!, 'date': Fmt.date(st.upcomingStartsAt)})),
              ],
              if (pending.isNotEmpty) ...[
                const SizedBox(height: 10),
                _notice(context, p.info, Icons.hourglass_top_rounded,
                    'subPendingMsg'.trParams({'n': '${pending.length}'})),
              ],
              if (_canPay && d.plans.isNotEmpty) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _pay(),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: Text(st.isTrial || st.readOnly ? 'subPayNow'.tr : 'subRenew'.tr),
                ),
              ],
            ],
          ),
        ),
        // -------------------------------------------------------- matumizi
        SectionCard(
          title: 'subUsage'.tr,
          subtitle: 'subUsageSub'.tr,
          icon: Icons.data_usage_rounded,
          child: Column(
            children: [
              _UsageBar(label: 'users'.tr, used: d.usage.users, limit: plan?.maxUsers),
              _UsageBar(label: 'offices'.tr, used: d.usage.offices, limit: plan?.maxOffices),
              _UsageBar(label: 'subInvoicesMonth'.tr, used: d.usage.invoicesThisMonth, limit: plan?.maxInvoicesPerMonth),
            ],
          ),
        ),
        // ---------------------------------------------------------- mipango
        if (d.plans.isNotEmpty)
          SectionCard(
            title: 'subPlans'.tr,
            subtitle: 'subPlansSub'.tr,
            icon: Icons.layers_outlined,
            child: ResponsiveGrid(
              minItemWidth: 240,
              children: [
                for (final pl in d.plans)
                  _PlanCard(
                    plan: pl,
                    current: plan?.id == pl.id,
                    onChoose: _canPay ? () => _pay(plan: pl) : null,
                  ),
              ],
            ),
          ),
        // ---------------------------------------------------------- malipo
        SectionCard(
          title: 'subPayments'.tr,
          icon: Icons.receipt_long_outlined,
          child: d.payments.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('subNoPayments'.tr, style: TextStyle(color: p.muted)),
                )
              : Column(
                  children: [
                    for (final pay in d.payments)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          switch (pay.status) {
                            'CONFIRMED' => Icons.check_circle_rounded,
                            'REJECTED' => Icons.cancel_rounded,
                            _ => Icons.hourglass_top_rounded,
                          },
                          color: switch (pay.status) {
                            'CONFIRMED' => p.success,
                            'REJECTED' => p.danger,
                            _ => p.warning,
                          },
                        ),
                        title: Text('${pay.currency} ${Fmt.number(pay.amount)} · ${pay.planName}'),
                        subtitle: Text([
                          Fmt.dateTime(pay.createdAt),
                          if (pay.method != null) pay.method!,
                          if (pay.reference != null) pay.reference!,
                          if (pay.status == 'REJECTED' && pay.note != null) pay.note!,
                        ].join(' · ')),
                        trailing: pay.status == 'CONFIRMED'
                            ? TextButton.icon(
                                onPressed: () => openPdfFrom(
                                  () => CompanyRepo.subscriptionReceipt(pay.id),
                                  title: 'subReceipt'.tr,
                                  fileName: 'risiti_${pay.reference ?? pay.id.substring(0, 8)}',
                                ),
                                icon: const Icon(Icons.receipt_rounded, size: 18),
                                label: Text('subReceipt'.tr),
                              )
                            : Text(
                                pay.status == 'REJECTED' ? 'subRejected'.tr : 'subPending'.tr,
                                style: TextStyle(color: p.muted, fontSize: 12.5),
                              ),
                      ),
                  ],
                ),
        ),
        // --------------------------------------------------------- vipindi
        if (d.history.isNotEmpty)
          SectionCard(
            title: 'subHistory'.tr,
            icon: Icons.history_rounded,
            child: Column(
              children: [
                for (final h in d.history)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.date_range_outlined, color: p.muted),
                    title: Text('${h.planName} · ${subscriptionLook(p, h.status).$2}'),
                    subtitle: Text('${Fmt.date(h.startsAt)} → ${Fmt.date(h.endsAt)}'
                        '${h.note == null ? '' : ' · ${h.note}'}'),
                  ),
              ],
            ),
          ),
        if (d.supportPhone != null || d.supportEmail != null)
          Center(
            child: Text(
              'subSupport'.trParams({
                'contact': [if (d.supportPhone != null) d.supportPhone!, if (d.supportEmail != null) d.supportEmail!]
                    .join(' · ')
              }),
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 12.5),
            ),
          ),
      ],
    );
  }

  Widget _notice(BuildContext context, Color color, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, height: 1.35))),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final String label;
  final int used;
  final int? limit;

  const _UsageBar({required this.label, required this.used, this.limit});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final double ratio = limit == null || limit == 0 ? 0 : (used / limit!).clamp(0, 1).toDouble();
    final Color color = ratio >= 1 ? p.danger : (ratio >= .8 ? p.warning : p.primary);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(color: p.text, fontWeight: FontWeight.w600))),
              Text(limit == null ? '$used · ${'unlimited'.tr}' : '$used / $limit',
                  style: TextStyle(color: p.muted, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: limit == null ? 0 : ratio,
              minHeight: 8,
              backgroundColor: p.surfaceAlt,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;
  final bool current;
  final VoidCallback? onChoose;

  const _PlanCard({required this.plan, required this.current, this.onChoose});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    String limit(int? n, String one, String none) => n == null ? none.tr : one.trParams({'n': '$n'});
    final features = <String>[
      limit(plan.maxUsers, 'nUsers', 'unlimitedUsers'),
      limit(plan.maxOffices, 'nOffices', 'unlimitedOffices'),
      limit(plan.maxInvoicesPerMonth, 'nInvoicesMonth', 'unlimitedInvoices'),
      if (plan.modules == null)
        'allFeatures'.tr
      else
        for (final m in plan.modules!) 'module_$m'.tr,
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: current ? p.primarySoft : p.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: current ? p.primary : p.border, width: current ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(plan.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.text))),
              if (current) Pill('subCurrent'.tr, color: p.primary, dense: true),
            ],
          ),
          const SizedBox(height: 6),
          Text('${plan.currency} ${Fmt.number(plan.price)}',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: p.primary)),
          Text(plan.months == 1 ? 'perMonth'.tr : 'perMonths'.trParams({'n': '${plan.months}'}),
              style: TextStyle(color: p.muted, fontSize: 12.5)),
          if (plan.description != null) ...[
            const SizedBox(height: 8),
            Text(plan.description!, style: TextStyle(color: p.muted, fontSize: 13)),
          ],
          const SizedBox(height: 10),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.check_rounded, size: 16, color: p.success),
                  const SizedBox(width: 6),
                  Expanded(child: Text(f, style: TextStyle(color: p.text, fontSize: 13))),
                ],
              ),
            ),
          if (onChoose != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: onChoose, child: Text(current ? 'subRenew'.tr : 'subChoose'.tr)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sehemu ya coupon: code + "Tumia" + matokeo (punguzo au kosa).
class _CouponField extends StatelessWidget {
  final TextEditingController controller;
  final Map<String, dynamic>? priced;
  final String? error;
  final Future<void> Function() onApply;

  const _CouponField({required this.controller, required this.priced, required this.error, required this.onApply});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppField(
                controller: controller,
                label: 'subCoupon'.tr,
                hint: 'KARIBU20',
                icon: Icons.local_offer_outlined,
                capitalization: TextCapitalization.characters,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) onApply();
                },
                child: Text('subCouponApply'.tr),
              ),
            ),
          ],
        ),
        if (priced != null && J.dbl(priced!['discount']) > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'subCouponOk'.trParams({
                'discount': Fmt.number(J.dbl(priced!['discount'])),
                'amount': Fmt.number(J.dbl(priced!['amount'])),
              }),
              style: TextStyle(color: p.success, fontWeight: FontWeight.w600),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(error!, style: TextStyle(color: p.danger, fontSize: 12.5)),
          ),
      ],
    );
  }
}


/// Ndani ya fomu ya malipo: mpango uliochaguliwa ni mkubwa/mdogo kuliko uliolipiwa?
/// - Mkubwa: unaanza sasa + siku zilizobaki zinaongezwa.
/// - Mdogo: chaguo - kusubiri wa sasa uishe (chaguo-msingi), au kuanza sasa na siku zilizobaki kufutwa (inaulizwa).
class _PlanChangeBox extends StatefulWidget {
  final String planId;
  final int periods;
  final String mode;
  final ValueChanged<String> onMode;

  const _PlanChangeBox({super.key, required this.planId, required this.periods, required this.mode,
      required this.onMode});

  @override
  State<_PlanChangeBox> createState() => _PlanChangeBoxState();
}

class _PlanChangeBoxState extends State<_PlanChangeBox> {
  Map<String, dynamic>? _d;

  @override
  void initState() {
    super.initState();
    CompanyRepo.planChange(widget.planId, widget.periods).then((d) {
      if (mounted) setState(() => _d = d);
    }).catchError((_) {});
    // mpango ukibadilika chaguo linarudi kwenye "subiri" (baada ya fremu - si wakati wa kujenga)
    if (widget.mode != 'QUEUE') WidgetsBinding.instance.addPostFrameCallback((_) => widget.onMode('QUEUE'));
  }

  Future<void> _chooseNow(Map<String, dynamic> d) async {
    final ok = await confirmAction(
      title: 'subDowngradeConfirmTitle'.tr,
      message: 'subDowngradeConfirmMsg'.trParams({
        'days': '${J.integer(d['remainingDays'])}',
        'current': J.str(J.map(d['currentPlan'])?['name']),
        'plan': J.str(J.map(d['plan'])?['name']),
      }),
      icon: Icons.delete_sweep_outlined,
      danger: true,
    );
    if (ok) widget.onMode('NOW');
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) return const SizedBox.shrink();
    final p = context.palette;
    final kind = J.str(d['kind']);
    final plan = J.str(J.map(d['plan'])?['name']);
    final current = J.str(J.map(d['currentPlan'])?['name']);
    final days = '${J.integer(d['remainingDays'])}';

    Widget box(Color color, IconData icon, List<Widget> children) => Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            border: Border.all(color: color.withValues(alpha: .35)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
            ],
          ),
        );
    final text = TextStyle(color: p.text, height: 1.4);

    switch (kind) {
      case 'UPGRADE':
        return box(p.success, Icons.trending_up_rounded, [
          Text('subUpgradeInfo'.trParams({
            'plan': plan,
            'current': current,
            'days': days,
            'end': Fmt.date(J.date(d['endsAt'])),
          }), style: text),
        ]);
      case 'DOWNGRADE':
        final queue = J.map(d['queue']) ?? const {};
        final now = widget.mode == 'NOW';
        return box(p.warning, Icons.trending_down_rounded, [
          Text('subDowngradeInfo'.trParams({'plan': plan, 'current': current, 'days': days}),
              style: text.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _Choice(
            selected: !now,
            title: 'subDowngradeQueue'.trParams({'current': current, 'plan': plan,
                'date': Fmt.date(J.date(queue['startsAt']))}),
            onTap: () => widget.onMode('QUEUE'),
          ),
          _Choice(
            selected: now,
            title: 'subDowngradeNow'.trParams({'days': days, 'current': current}),
            danger: true,
            onTap: now ? null : () => _chooseNow(d),
          ),
        ]);
      default:
        final start = J.date(d['startsAt']);
        if (start == null || !start.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
          return const SizedBox.shrink();
        }
        return box(p.info, Icons.event_available_outlined, [
          Text('subNextPeriodInfo'.trParams({'start': Fmt.date(start), 'end': Fmt.date(J.date(d['endsAt']))}),
              style: text),
        ]);
    }
  }
}

class _Choice extends StatelessWidget {
  final bool selected;
  final String title;
  final bool danger;
  final VoidCallback? onTap;

  const _Choice({required this.selected, required this.title, this.danger = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = danger ? p.danger : p.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                size: 20, color: selected ? color : p.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: TextStyle(color: p.text, fontWeight: selected ? FontWeight.w700 : FontWeight.w400, height: 1.35)),
            ),
          ],
        ),
      ),
    );
  }
}
