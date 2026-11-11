import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/widgets/data_list.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/claim.dart';
import '../../data/repositories.dart';
import '../invoices/invoice_flows.dart';
import 'claim_flows.dart';

/// Madai yote ya mizigo (yaliyo wazi kwanza).
class ClaimsPage extends StatefulWidget {
  const ClaimsPage({super.key});

  @override
  State<ClaimsPage> createState() => _ClaimsPageState();
}

class _ClaimsPageState extends State<ClaimsPage> {
  String? _status = 'OPEN';
  List<CargoClaim> _items = const [];
  Map<String, int> _counts = const {};
  LoadStatus _state = LoadStatus.loading;
  String? _error;
  Worker? _changes;

  @override
  void initState() {
    super.initState();
    _changes = ever<int>(AppController.to.changes, (_) => _load());
    _load();
  }

  @override
  void dispose() {
    _changes?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await ClaimRepo.search(status: _status);
      final counts = await ClaimRepo.counts();
      if (!mounted) return;
      setState(() {
        _items = items;
        _counts = counts;
        _state = LoadStatus.ready;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = LoadStatus.error;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      help: 'claims',
      title: 'navClaims'.tr,
      subtitle: 'hintClaims'.tr,
      actions: [IconButton(tooltip: 'refresh'.tr, onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      body: Column(
        children: [
          ListToolbar(
            filters: FilterChips<String?>(
              values: const ['OPEN', 'SETTLED', 'APPROVED', 'REJECTED', null],
              selected: _status,
              label: (s) => s == null ? 'all'.tr : claimStatusLabel(s),
              count: (s) => s == null ? null : _counts[s],
              onSelected: (s) {
                setState(() => _status = s);
                _load();
              },
            ),
          ),
          Expanded(
            child: AsyncBody(
              status: _state,
              error: _error,
              isEmpty: _items.isEmpty,
              onRetry: _load,
              empty: EmptyState(icon: Icons.verified_outlined, title: 'noClaims'.tr),
              builder: () => PageScroll(
                onRefresh: _load,
                children: [
                  for (final c in _items)
                    Card(
                      child: InkWell(
                        onTap: () => InvoiceFlows.open(c.invoiceId),
                        child: Padding(padding: const EdgeInsets.all(14), child: ClaimTile(claim: c)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
