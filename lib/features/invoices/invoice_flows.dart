import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../data/models/customer.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../customers/customer_flows.dart';
import 'invoice_detail_page.dart';

/// Vitendo vya invoice vinavyoitwa kutoka sehemu mbalimbali za app.
class InvoiceFlows {
  InvoiceFlows._();

  static Future<void> open(String invoiceId) async {
    await Get.to(() => InvoiceDetailPage(invoiceId: invoiceId), preventDuplicates: false);
  }

  /// Kufungua invoice mpya: chagua mteja (au sajili mpya), kisha nenda kwenye invoice.
  static Future<void> newInvoice({Customer? customer}) async {
    final selected = customer ?? await pickCustomer();
    if (selected == null) return;
    try {
      final invoice = await InvoiceRepo.create(selected.id);
      AppController.to.notifyChanged();
      Toast.success('invoiceCreatedMsg'.trParams({'n': invoice.invoiceNumber}), title: 'invoiceCreated'.tr);
      await open(invoice.id);
    } catch (e) {
      Toast.error(e);
    }
  }

  /// Dirisha la kuchagua mteja (lina kutafuta na kusajili mteja mpya).
  static Future<Customer?> pickCustomer() async {
    final ctx = Get.overlayContext ?? Get.context;
    if (ctx == null) return null;
    return showDialog<Customer>(context: ctx, builder: (_) => const _CustomerPicker());
  }
}

class _CustomerPicker extends StatefulWidget {
  const _CustomerPicker();

  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  final _search = TextEditingController();
  List<Customer> _all = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Wateja wanatafutwa kwenye server (hai tu, 40 wa kwanza wanaolingana).
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _all = await CustomerRepo.search(query: _search.text, active: 1, limit: 40);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _createNew() async {
    final created = await CustomerFlows.edit(initialName: _search.text.trim());
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final list = _all;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: MediaQuery.sizeOf(context).height * .8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text('chooseCustomer'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text)),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'searchCustomerHint'.tr,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                ),
              ),
            ),
            if (AppController.to.can(AppModule.customer, AppAction.insert))
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: p.primarySoft, shape: BoxShape.circle),
                  child: Icon(Icons.person_add_alt_1_rounded, color: p.primary, size: 20),
                ),
                title: Text('newCustomer'.tr, style: TextStyle(color: p.primary, fontWeight: FontWeight.w700)),
                subtitle: Text('registerAndContinue'.tr),
                onTap: _createNew,
              ),
            Divider(color: p.border, height: 1),
            Flexible(
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: p.danger)),
                              TextButton(onPressed: _load, child: Text('tryAgain'.tr)),
                            ],
                          ),
                        )
                      : list.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text('noMatch'.tr, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: list.length,
                              itemBuilder: (context, i) {
                                final c = list[i];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                  leading: Initials(c.initials, size: 40),
                                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(Fmt.phone(c.phoneNumber)),
                                  trailing: const Icon(Icons.chevron_right_rounded),
                                  onTap: () => Navigator.of(context).pop(c),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
