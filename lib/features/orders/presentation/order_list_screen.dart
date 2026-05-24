import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/gradient_background.dart';
import 'order_detail_screen.dart';
import 'order_models.dart';
import 'order_store.dart';

enum OrderStatusFilter { all, paid, unpaid }

enum OrderTimeFilter {
  all,
  today,
  yesterday,
  last7Days,
  thisMonth,
  lastMonth,
  custom,
}

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  bool _searchMode = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  OrderStatusFilter _statusFilter = OrderStatusFilter.all;
  OrderTimeFilter _timeFilter = OrderTimeFilter.all;
  DateTimeRange? _customRange;
  List<OrderVm>? _lastFilteredOrdersSource;
  int _lastFilteredOrdersCount = -1;
  String _lastFilterQuery = '';
  OrderStatusFilter? _lastStatusFilter;
  OrderTimeFilter? _lastTimeFilter;
  DateTimeRange? _lastCustomRange;
  _VisibleOrdersData? _cachedVisibleOrders;

  late final VoidCallback _storeListener;

  @override
  void initState() {
    super.initState();
    if (SupabaseBootstrap.isInitialized) {
      unawaited(OrderStore.instance.startRealtime());
      unawaited(OrderStore.instance.loadOrders(force: true));
    }
    _storeListener = () {
      if (mounted) {
        _invalidateVisibleOrdersCache();
        setState(() {});
      }
    };
    OrderStore.instance.addListener(_storeListener);
  }

  @override
  void dispose() {
    if (SupabaseBootstrap.isInitialized) {
      unawaited(OrderStore.instance.stopRealtime());
    }
    OrderStore.instance.removeListener(_storeListener);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = OrderStore.instance;
    final errorMessage = store.errorMessage;

    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: _searchMode
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: _buildHeader(),
              secondChild: _buildSearchBar(),
            ),
            _buildFilterRow(),
            if (errorMessage != null && errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    errorMessage,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, _) {
                  final visible = _resolveVisibleOrders(
                    store.orders,
                    value.text.trim().toLowerCase(),
                  );
                  final grouped = visible.groups;
                  final loading = store.loading && grouped.isEmpty;
                  return RefreshIndicator(
                    onRefresh: () =>
                        OrderStore.instance.loadOrders(force: true),
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : grouped.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            children: [
                              _OrdersEmptyState(
                                hasError:
                                    errorMessage != null &&
                                    errorMessage.isNotEmpty,
                                onRetry: () async {
                                  await OrderStore.instance.loadOrders(
                                    force: true,
                                  );
                                },
                              ),
                            ],
                          )
                        : CustomScrollView(
                            controller: _scrollController,
                            slivers: _buildStickyGroupedSlivers(grouped),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Hóa đơn',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {
              setState(() {
                _searchMode = true;
                _invalidateVisibleOrdersCache();
              });
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFE5EAF2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Tìm theo hàng hóa, khách hàng',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _searchMode = false;
                _searchController.clear();
                _invalidateVisibleOrdersCache();
              });
              FocusScope.of(context).unfocus();
            },
            child: const Text(
              'Hủy',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1565FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Row(
        children: [
          _FilterChipButton(
            label: _timeFilterLabel(context),
            onTap: _pickTimeFilter,
          ),
          const SizedBox(width: 12),
          _FilterChipButton(
            label: _statusFilterLabel(context),
            onTap: _pickStatusFilter,
          ),
        ],
      ),
    );
  }

  List<OrderVm> _applyFilters(List<OrderVm> source) {
    return source.where((order) {
      if (_statusFilter == OrderStatusFilter.paid &&
          order.status != OrderStatusVm.paid) {
        return false;
      }
      if (_statusFilter == OrderStatusFilter.unpaid &&
          order.status != OrderStatusVm.unpaid) {
        return false;
      }

      if (!_matchTime(order.createdAt)) return false;

      if (_lastFilterQuery.isEmpty) return true;

      final inCustomer = order.customerName.toLowerCase().contains(
        _lastFilterQuery,
      );
      final inItems = order.lines.any(
        (line) => line.name.toLowerCase().contains(_lastFilterQuery),
      );
      return inCustomer || inItems;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  _VisibleOrdersData _resolveVisibleOrders(List<OrderVm> source, String query) {
    final customRange = _customRange;
    final canReuse =
        identical(_lastFilteredOrdersSource, source) &&
        _lastFilteredOrdersCount == source.length &&
        _lastFilterQuery == query &&
        _lastStatusFilter == _statusFilter &&
        _lastTimeFilter == _timeFilter &&
        _sameRange(_lastCustomRange, customRange) &&
        _cachedVisibleOrders != null;
    if (canReuse) {
      return _cachedVisibleOrders!;
    }

    _lastFilteredOrdersSource = source;
    _lastFilteredOrdersCount = source.length;
    _lastFilterQuery = query;
    _lastStatusFilter = _statusFilter;
    _lastTimeFilter = _timeFilter;
    _lastCustomRange = customRange;

    final filtered = _applyFilters(source);
    final grouped = _groupByDate(filtered);
    final visible = _VisibleOrdersData(filtered: filtered, groups: grouped);
    _cachedVisibleOrders = visible;
    return visible;
  }

  bool _matchTime(DateTime value) {
    final now = DateTime.now();

    if (_customRange != null) {
      final start = DateTime(
        _customRange!.start.year,
        _customRange!.start.month,
        _customRange!.start.day,
      );
      final end = DateTime(
        _customRange!.end.year,
        _customRange!.end.month,
        _customRange!.end.day,
        23,
        59,
        59,
      );
      return !value.isBefore(start) && !value.isAfter(end);
    }

    switch (_timeFilter) {
      case OrderTimeFilter.today:
        return _sameDate(value, now);
      case OrderTimeFilter.yesterday:
        final y = now.subtract(const Duration(days: 1));
        return _sameDate(value, y);
      case OrderTimeFilter.last7Days:
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
        return !value.isBefore(start);
      case OrderTimeFilter.thisMonth:
        return value.year == now.year && value.month == now.month;
      case OrderTimeFilter.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1);
        return value.year == lastMonth.year && value.month == lastMonth.month;
      case OrderTimeFilter.custom:
      case OrderTimeFilter.all:
        return true;
    }
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _sameRange(DateTimeRange? a, DateTimeRange? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    return a.start == b.start && a.end == b.end;
  }

  void _invalidateVisibleOrdersCache() {
    _lastFilteredOrdersSource = null;
    _lastFilteredOrdersCount = -1;
    _cachedVisibleOrders = null;
  }

  List<_DateGroup> _groupByDate(List<OrderVm> list) {
    final map = <String, List<OrderVm>>{};
    final dateMap = <String, DateTime>{};

    for (final order in list) {
      final key =
          '${order.createdAt.year}-${order.createdAt.month}-${order.createdAt.day}';
      map.putIfAbsent(key, () => []).add(order);
      dateMap[key] = DateTime(
        order.createdAt.year,
        order.createdAt.month,
        order.createdAt.day,
      );
    }

    final groups = <_DateGroup>[];
    for (final e in map.entries) {
      final date = dateMap[e.key]!;
      final dayTotal = e.value.fold<int>(0, (sum, o) => sum + o.totalAmount);
      groups.add(_DateGroup(date: date, orders: e.value, dayTotal: dayTotal));
    }

    groups.sort((a, b) => b.date.compareTo(a.date));
    return groups;
  }

  List<Widget> _buildStickyGroupedSlivers(List<_DateGroup> groups) {
    final slivers = <Widget>[
      const SliverPadding(padding: EdgeInsets.only(top: 2)),
    ];
    for (final group in groups) {
      slivers.add(
        SliverMainAxisGroup(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyDateHeaderDelegate(
                group: group,
                dateLabelBuilder: _dateHeader,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final order = group.orders[index];
                  return _OrderCard(
                    order: order,
                    onPaidTap: (value) => _confirmPaid(value),
                    onTap: (value) async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderDetailScreen(order: value),
                        ),
                      );
                      if (!context.mounted) {
                        return;
                      }
                      if (SupabaseBootstrap.isInitialized) {
                        await OrderStore.instance.loadOrders(force: true);
                      } else {
                        OrderStore.instance.notifyChanged();
                      }
                    },
                  );
                }, childCount: group.orders.length),
              ),
            ),
          ],
        ),
      );
    }
    slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 16)));
    return slivers;
  }

  Future<void> _pickStatusFilter() async {
    final result = await showAppOptionSheet<OrderStatusFilter>(
      context: context,
      title: 'Lọc theo trạng thái',
      actions: [
        AppSheetAction(
          label: _statusFilterText(context, OrderStatusFilter.all),
          value: OrderStatusFilter.all,
          selected: _statusFilter == OrderStatusFilter.all,
          icon: Icons.layers_clear_rounded,
        ),
        AppSheetAction(
          label: _statusFilterText(context, OrderStatusFilter.paid),
          value: OrderStatusFilter.paid,
          selected: _statusFilter == OrderStatusFilter.paid,
          icon: Icons.check_circle_outline_rounded,
        ),
        AppSheetAction(
          label: _statusFilterText(context, OrderStatusFilter.unpaid),
          value: OrderStatusFilter.unpaid,
          selected: _statusFilter == OrderStatusFilter.unpaid,
          icon: Icons.pending_actions_rounded,
        ),
      ],
    );

    if (result != null) {
      setState(() {
        _statusFilter = result;
        _invalidateVisibleOrdersCache();
      });
    }
  }

  Future<void> _pickTimeFilter() async {
    final result = await showAppOptionSheet<OrderTimeFilter>(
      context: context,
      title: 'Lọc theo thời gian',
      description: 'Chọn một khoảng để lọc danh sách hóa đơn.',
      actions: [
        AppSheetAction(
          label: _timeFilterText(context, OrderTimeFilter.all),
          value: OrderTimeFilter.all,
          selected: _timeFilter == OrderTimeFilter.all && _customRange == null,
          icon: Icons.all_inclusive_rounded,
        ),
        AppSheetAction(
          label: _timeFilterText(context, OrderTimeFilter.today),
          value: OrderTimeFilter.today,
          selected: _timeFilter == OrderTimeFilter.today,
          icon: Icons.today_rounded,
        ),
        AppSheetAction(
          label: _timeFilterText(context, OrderTimeFilter.yesterday),
          value: OrderTimeFilter.yesterday,
          selected: _timeFilter == OrderTimeFilter.yesterday,
          icon: Icons.history_toggle_off_rounded,
        ),
        AppSheetAction(
          label: _timeFilterText(context, OrderTimeFilter.last7Days),
          value: OrderTimeFilter.last7Days,
          selected: _timeFilter == OrderTimeFilter.last7Days,
          icon: Icons.date_range_rounded,
        ),
        AppSheetAction(
          label: _timeFilterText(context, OrderTimeFilter.thisMonth),
          value: OrderTimeFilter.thisMonth,
          selected: _timeFilter == OrderTimeFilter.thisMonth,
          icon: Icons.calendar_month_rounded,
        ),
        AppSheetAction(
          label: _timeFilterText(context, OrderTimeFilter.lastMonth),
          value: OrderTimeFilter.lastMonth,
          selected: _timeFilter == OrderTimeFilter.lastMonth,
          icon: Icons.event_repeat_rounded,
        ),
        AppSheetAction(
          label: _timeFilterText(context, OrderTimeFilter.custom),
          value: OrderTimeFilter.custom,
          selected:
              _timeFilter == OrderTimeFilter.custom && _customRange != null,
          icon: Icons.tune_rounded,
        ),
      ],
    );

    if (!mounted) {
      return;
    }
    if (result == null) return;

    if (result == OrderTimeFilter.custom) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (!mounted) {
        return;
      }
      if (range != null) {
        setState(() {
          _customRange = range;
          _timeFilter = OrderTimeFilter.custom;
          _invalidateVisibleOrdersCache();
        });
      }
      return;
    }

    setState(() {
      _customRange = null;
      _timeFilter = result;
      _invalidateVisibleOrdersCache();
    });
  }

  String _timeFilterLabel(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    if (_customRange != null) {
      return '${localizations.formatShortDate(_customRange!.start)} - ${localizations.formatShortDate(_customRange!.end)}';
    }
    return _timeFilterText(context, _timeFilter);
  }

  String _statusFilterLabel(BuildContext context) {
    return _statusFilterText(context, _statusFilter);
  }

  Future<void> _confirmPaid(OrderVm order) async {
    if (order.status == OrderStatusVm.paid) return;

    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Xác nhận thanh toán',
      message: 'Bạn có chắc chắn muốn đánh dấu đơn này là đã nhận tiền?',
      confirmLabel: 'Xác nhận',
      icon: Icons.payments_outlined,
    );

    if (ok == true) {
      try {
        await OrderStore.instance.markPaid(order.id);
      } catch (e) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  static String _formatCurrency(int amount) {
    final text = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final indexFromEnd = text.length - i;
      buffer.write(text[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  static String _timeHm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _dateHeader(BuildContext context, DateTime date) {
    final localizations = MaterialLocalizations.of(context);
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      const todayLabel = 'Hôm nay';
      return '$todayLabel, ${localizations.formatShortDate(date)}';
    }
    final weekday = _weekdayLabel(date.weekday);
    return '$weekday, ${localizations.formatShortDate(date)}';
  }

  String _timeFilterText(BuildContext context, OrderTimeFilter key) {
    switch (key) {
      case OrderTimeFilter.today:
        return 'Hôm nay';
      case OrderTimeFilter.yesterday:
        return 'Hôm qua';
      case OrderTimeFilter.last7Days:
        return '7 ngày qua';
      case OrderTimeFilter.thisMonth:
        return 'Tháng nay';
      case OrderTimeFilter.lastMonth:
        return 'Tháng trước';
      case OrderTimeFilter.custom:
        return 'Tùy chỉnh';
      case OrderTimeFilter.all:
        return 'Tất cả thời gian';
    }
  }

  String _statusFilterText(BuildContext context, OrderStatusFilter key) {
    switch (key) {
      case OrderStatusFilter.paid:
        return 'Đã nhận tiền';
      case OrderStatusFilter.unpaid:
        return 'Chưa thanh toán';
      case OrderStatusFilter.all:
        return 'Tất cả đơn';
    }
  }

  static String _weekdayLabel(int weekday) {
    const weekdaysVi = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    return weekdaysVi[weekday - 1];
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 36,
        padding: const EdgeInsets.only(left: 14, right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFDDE3EE)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _OrdersEmptyState extends StatelessWidget {
  const _OrdersEmptyState({required this.hasError, required this.onRetry});

  final bool hasError;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(
            hasError ? Icons.wifi_off_rounded : Icons.receipt_long_rounded,
            size: 56,
            color: const Color(0xFF64748B),
          ),
          const SizedBox(height: 8),
          Text(
            hasError
                ? 'Chưa tải được danh sách hóa đơn.'
                : 'Danh sách đơn hàng đang trống.\nBấm Bán hàng để tạo đơn.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
          if (hasError) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử tải lại'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateGroup {
  const _DateGroup({
    required this.date,
    required this.orders,
    required this.dayTotal,
  });

  final DateTime date;
  final List<OrderVm> orders;
  final int dayTotal;
}

class _VisibleOrdersData {
  const _VisibleOrdersData({required this.filtered, required this.groups});

  final List<OrderVm> filtered;
  final List<_DateGroup> groups;
}

class _StickyDateHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StickyDateHeaderDelegate({
    required this.group,
    required this.dateLabelBuilder,
  });

  final _DateGroup group;
  final String Function(BuildContext context, DateTime date) dateLabelBuilder;

  @override
  double get minExtent => 46;

  @override
  double get maxExtent => 46;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          boxShadow: overlapsContent
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dateLabelBuilder(context, group.date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              Text(
                _OrderListScreenState._formatCurrency(group.dayTotal),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1565FF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyDateHeaderDelegate oldDelegate) {
    return oldDelegate.group.date != group.date ||
        oldDelegate.group.dayTotal != group.dayTotal ||
        oldDelegate.dateLabelBuilder != dateLabelBuilder;
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onPaidTap,
    required this.onTap,
  });

  final OrderVm order;
  final ValueChanged<OrderVm> onPaidTap;
  final ValueChanged<OrderVm> onTap;

  @override
  Widget build(BuildContext context) {
    final lineSummary = _buildLinesSummary(order.lines);
    final noteSummary = _buildNotesSummary(order.lines);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onTap(order),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Nhân viên: ${order.sellerName}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          if (order.paidByName != null &&
                              order.paidByName!.trim().isNotEmpty)
                            Text(
                              'Nhận tiền: ${order.paidByName!}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      _OrderListScreenState._timeHm(order.createdAt),
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 10),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lineSummary,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF374151),
                              height: 1.35,
                            ),
                          ),
                          if (noteSummary.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                noteSummary,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                  fontStyle: FontStyle.italic,
                                  height: 1.25,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _OrderListScreenState._formatCurrency(order.totalAmount),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Spacer(),
                    InkWell(
                      onTap: order.status == OrderStatusVm.paid
                          ? null
                          : () => onPaidTap(order),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFD1D5DB)),
                          color: order.status == OrderStatusVm.paid
                              ? const Color(0xFFF1F5F9)
                              : Colors.white,
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: order.status == OrderStatusVm.paid,
                              onChanged: order.status == OrderStatusVm.paid
                                  ? null
                                  : (_) => onPaidTap(order),
                            ),
                            const Text(
                              'Đã nhận tiền',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _buildLinesSummary(List<OrderLineVm> lines) {
    if (lines.isEmpty) return 'Đơn hàng trống';

    final maxLines = 5;
    final buffer = StringBuffer();

    for (int i = 0; i < lines.length; i++) {
      if (i < maxLines) {
        if (i > 0) {
          buffer.writeln();
        }
        buffer.write('${lines[i].quantity} x ${lines[i].name}');
      } else if (i == maxLines) {
        final remain = lines.length - maxLines;
        if (remain > 0) {
          buffer.write(' + $remain hàng khác');
        }
      }
    }
    return buffer.toString();
  }

  static String _buildNotesSummary(List<OrderLineVm> lines) {
    final notes = lines
        .where((l) => l.note != null && l.note!.trim().isNotEmpty)
        .map((l) => l.note!.trim())
        .toList();
    return notes.join('\n');
  }
}
