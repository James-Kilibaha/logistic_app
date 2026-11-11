import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';
import 'layout.dart';

/// Safu ya jedwali (kompyuta).
class ColumnSpec {
  final String label;
  final int flex;
  final TextAlign align;

  const ColumnSpec(this.label, {this.flex = 2, this.align = TextAlign.start});
}

/// Orodha inayojipanga: jedwali kwenye skrini pana, kadi kwenye simu.
/// Inatumia `ListView.builder` (inajenga mistari inayoonekana tu) - haraka hata kwa data nyingi.
///
/// Kwenye kompyuta (desktop) na web, orodha inagawanywa kwa kurasa (pagination): idadi kwa ukurasa inachaguliwa
/// (10 / 25 / 50 / 100) na inakumbukwa. Kwenye simu orodha inabaki ya kusogeza (scroll) kama kawaida.
class DataList<T> extends StatefulWidget {
  final List<T> items;
  final List<ColumnSpec> columns;
  final List<Widget> Function(BuildContext context, T item) cells;
  final Widget Function(BuildContext context, T item) card;
  final void Function(T item)? onTap;
  final Widget Function(BuildContext context, T item)? actions;
  final Future<void> Function()? onRefresh;
  final double tableMinWidth;
  final Widget? header;

  /// Mwisho wa orodha (mf. kitufe cha "Pakia zaidi") - kwenye pagination unaonekana ukurasa wa mwisho.
  final Widget? footer;

  /// `null` = kurasa zinatumika kwenye desktop na web tu; `false` = kamwe; `true` = daima.
  final bool? paginate;

  const DataList({
    super.key,
    required this.items,
    required this.columns,
    required this.cells,
    required this.card,
    this.onTap,
    this.actions,
    this.onRefresh,
    this.tableMinWidth = 820,
    this.header,
    this.footer,
    this.paginate,
  });

  @override
  State<DataList<T>> createState() => _DataListState<T>();
}

/// Idadi ya mistari kwa ukurasa (inakumbukwa kwa orodha zote hadi app ifungwe).
int _pageSize = 25;
const List<int> _pageSizes = [10, 25, 50, 100];

bool get _desktopOrWeb =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux ||
    defaultTargetPlatform == TargetPlatform.macOS;

class _DataListState<T> extends State<DataList<T>> {
  int _page = 0;
  final ScrollController _scroll = ScrollController();

  bool get _paged => widget.paginate ?? _desktopOrWeb;

  int get _pages => widget.items.isEmpty ? 1 : (widget.items.length / _pageSize).ceil();

  @override
  void didUpdateWidget(covariant DataList<T> old) {
    super.didUpdateWidget(old);
    // Kutafuta / kuchuja (idadi imebadilika) -> ukurasa wa kwanza. Kusasisha (idadi ile ile) au "Pakia zaidi"
    // (orodha imeongezeka mwishoni) -> ukurasa unabaki.
    final grew = widget.items.length > old.items.length &&
        old.items.isNotEmpty &&
        identical(old.items.first, widget.items.first);
    if (widget.items.length != old.items.length && !grew) _page = 0;
    if (_page >= _pages) _page = _pages - 1;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int page) {
    setState(() => _page = page.clamp(0, _pages - 1));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  List<T> get _visible {
    if (!_paged) return widget.items;
    final start = (_page * _pageSize).clamp(0, widget.items.length);
    final end = (start + _pageSize).clamp(0, widget.items.length);
    return widget.items.sublist(start, end);
  }

  /// "Pakia zaidi" inaonekana ukurasa wa mwisho tu.
  Widget? get _footer => !_paged || _page >= _pages - 1 ? widget.footer : null;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final bool table = c.maxWidth >= widget.tableMinWidth;
      final Widget list = table ? _table(context) : _cards(context);
      if (widget.onRefresh == null) return list;
      return RefreshIndicator(onRefresh: widget.onRefresh!, child: list);
    });
  }

  Widget? _pager() {
    if (!_paged || widget.items.length <= _pageSizes.first) return null;
    return _Pager(
      page: _page,
      pages: _pages,
      total: widget.items.length,
      pageSize: _pageSize,
      onPage: _go,
      onPageSize: (n) => setState(() {
        final first = _page * _pageSize;
        _pageSize = n;
        _page = (first ~/ n).clamp(0, _pages - 1);
      }),
    );
  }

  Widget _cards(BuildContext context) {
    final items = _visible;
    final footer = _footer;
    final pager = _pager();
    final list = ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 4, 16, pager == null ? 96 : 16),
      itemCount: items.length + (widget.header == null ? 0 : 1) + (footer == null ? 0 : 1),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (widget.header != null) {
          if (i == 0) return widget.header!;
          i -= 1;
        }
        if (i >= items.length) return footer!;
        final item = items[i];
        return Card(
          child: InkWell(
            onTap: widget.onTap == null ? null : () => widget.onTap!(item),
            child: widget.card(context, item),
          ),
        );
      },
    );
    if (pager == null) return list;
    return Column(
      children: [
        Expanded(child: list),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: pager),
      ],
    );
  }

  Widget _table(BuildContext context) {
    final p = context.palette;
    final double h = context.isMediumUp ? 28 : 16;
    final columns = widget.columns;
    final actions = widget.actions;
    final items = _visible;
    final footer = _footer;
    final pager = _pager();
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(h, 4, h, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.header != null) ...[widget.header!, const SizedBox(height: 14)],
              Expanded(
                child: Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: p.surfaceAlt,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        child: Row(
                          children: [
                            for (final col in columns)
                              Expanded(
                                flex: col.flex,
                                child: Text(
                                  col.label.toUpperCase(),
                                  textAlign: col.align,
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .7,
                                  ),
                                ),
                              ),
                            if (actions != null) const SizedBox(width: 48),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: p.border),
                      Expanded(
                        child: ListView.separated(
                          controller: _scroll,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: items.length + (footer == null ? 0 : 1),
                          separatorBuilder: (_, __) => Divider(height: 1, color: p.border),
                          itemBuilder: (context, i) {
                            if (i >= items.length) return footer!;
                            final item = items[i];
                            final cellWidgets = widget.cells(context, item);
                            return InkWell(
                              onTap: widget.onTap == null ? null : () => widget.onTap!(item),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(18, 10, actions == null ? 18 : 6, 10),
                                child: Row(
                                  children: [
                                    for (int k = 0; k < columns.length; k++)
                                      Expanded(
                                        flex: columns[k].flex,
                                        child: Align(
                                          alignment: switch (columns[k].align) {
                                            TextAlign.end || TextAlign.right => Alignment.centerRight,
                                            TextAlign.center => Alignment.center,
                                            _ => Alignment.centerLeft,
                                          },
                                          child: k < cellWidgets.length ? cellWidgets[k] : const SizedBox.shrink(),
                                        ),
                                      ),
                                    if (actions != null) SizedBox(width: 48, child: actions(context, item)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (pager != null) ...[
                        Divider(height: 1, color: p.border),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: pager),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kipande cha kurasa: "1–25 kati ya 340", idadi kwa ukurasa, na vitufe vya kurasa.
class _Pager extends StatelessWidget {
  final int page;
  final int pages;
  final int total;
  final int pageSize;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onPageSize;

  const _Pager({
    required this.page,
    required this.pages,
    required this.total,
    required this.pageSize,
    required this.onPage,
    required this.onPageSize,
  });

  /// Namba za kurasa za kuonyesha: ya kwanza, ya mwisho na zilizo karibu na ukurasa wa sasa (null = "…").
  List<int?> _numbers() {
    final wanted = <int>{0, pages - 1, page - 1, page, page + 1}.where((n) => n >= 0 && n < pages).toList()..sort();
    final out = <int?>[];
    for (final n in wanted) {
      if (out.isNotEmpty && out.last != null && n - out.last! > 1) out.add(null);
      out.add(n);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final from = total == 0 ? 0 : page * pageSize + 1;
    final to = ((page + 1) * pageSize).clamp(0, total);
    final muted = TextStyle(color: p.muted, fontSize: 13);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 6,
      spacing: 16,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('pageRange'.trParams({'from': '$from', 'to': '$to', 'total': '$total'}), style: muted),
            const SizedBox(width: 16),
            Text('perPage'.tr, style: muted),
            const SizedBox(width: 6),
            DropdownButton<int>(
              value: pageSize,
              underline: const SizedBox.shrink(),
              isDense: true,
              items: [for (final n in _pageSizes) DropdownMenuItem(value: n, child: Text('$n'))],
              onChanged: (n) {
                if (n != null) onPageSize(n);
              },
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'firstPage'.tr,
              visualDensity: VisualDensity.compact,
              onPressed: page > 0 ? () => onPage(0) : null,
              icon: const Icon(Icons.first_page_rounded),
            ),
            IconButton(
              tooltip: 'previousPage'.tr,
              visualDensity: VisualDensity.compact,
              onPressed: page > 0 ? () => onPage(page - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            for (final n in _numbers())
              n == null
                  ? Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('…', style: muted))
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: n == page
                          ? FilledButton(
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size(36, 34), padding: const EdgeInsets.symmetric(horizontal: 8)),
                              onPressed: null,
                              child: Text('${n + 1}'),
                            )
                          : TextButton(
                              style: TextButton.styleFrom(
                                  minimumSize: const Size(36, 34), padding: const EdgeInsets.symmetric(horizontal: 8)),
                              onPressed: () => onPage(n),
                              child: Text('${n + 1}'),
                            ),
                    ),
            IconButton(
              tooltip: 'nextPage'.tr,
              visualDensity: VisualDensity.compact,
              onPressed: page < pages - 1 ? () => onPage(page + 1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            IconButton(
              tooltip: 'lastPage'.tr,
              visualDensity: VisualDensity.compact,
              onPressed: page < pages - 1 ? () => onPage(pages - 1) : null,
              icon: const Icon(Icons.last_page_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

/// Maandishi ya seli: mstari mkuu + mstari mdogo (si lazima).
class CellText extends StatelessWidget {
  final String text;
  final String? sub;
  final bool bold;
  final TextAlign align;
  final Color? color;

  const CellText(this.text, {super.key, this.sub, this.bold = false, this.align = TextAlign.start, this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: align == TextAlign.end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? p.text,
            fontSize: 14,
          ),
        ),
        if (sub != null && sub!.isNotEmpty)
          Text(
            sub!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
            style: TextStyle(color: p.muted, fontSize: 12.5),
          ),
      ],
    );
  }
}

/// Kichwa cha orodha: kutafuta + vichujio + idadi.
class ListToolbar extends StatelessWidget {
  final Widget? search;
  final Widget? filters;
  final List<Widget> trailing;

  const ListToolbar({super.key, this.search, this.filters, this.trailing = const []});

  @override
  Widget build(BuildContext context) {
    final double h = context.isMediumUp ? 28 : 16;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(h, 16, h, 12),
          child: LayoutBuilder(builder: (context, c) {
            final bool row = c.maxWidth >= 760;
            if (row) {
              return Row(
                children: [
                  if (search != null) SizedBox(width: 340, child: search),
                  if (filters != null) ...[const SizedBox(width: 12), Expanded(child: filters!)] else const Spacer(),
                  ...trailing,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (search != null)
                  Row(children: [Expanded(child: search!), ...trailing])
                else if (trailing.isNotEmpty)
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: trailing),
                if (filters != null) ...[const SizedBox(height: 10), filters!],
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Vichujio vya "chip" vinavyosogezwa pembeni.
class FilterChips<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final int? Function(T value)? count;
  final ValueChanged<T> onSelected;

  const FilterChips({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final v in values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: v == selected,
                onSelected: (_) => onSelected(v),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label(v),
                      style: TextStyle(
                        color: v == selected ? p.primary : p.text,
                        fontWeight: v == selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (count != null && count!(v) != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: v == selected ? p.primary : p.surfaceAlt,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${count!(v)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: v == selected ? context.cs.onPrimary : p.muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
