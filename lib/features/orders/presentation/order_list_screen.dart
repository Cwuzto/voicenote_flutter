import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import 'order_detail_screen.dart';
import 'order_models.dart';
import 'order_store.dart';

enum OrderStatusFilter { all, paid, unpaid }

enum OrderTimeFilter { all, today, yesterday, last7Days, thisMonth, lastMonth, custom }

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
  String? _highlightOrderId;
  String? _handledLastAddedOrderId;

  late final VoidCallback _storeListener;

  @override
  void initState() {
    super.initState();
    if (SupabaseBootstrap.isInitialized) {
      unawaited(OrderStore.instance.startRealtime());
      unawaited(OrderStore.instance.loadOrders(force: true));
    } else {
      OrderStore.instance.ensureSeeded(_buildSeedOrders());
    }
    _storeListener = () {
      final lastAddedOrderId = OrderStore.instance.lastAddedOrderId;
      if (lastAddedOrderId != null &&
          lastAddedOrderId != _handledLastAddedOrderId) {
        _handledLastAddedOrderId = lastAddedOrderId;
        _highlightOrderId = lastAddedOrderId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) {
            return;
          }
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
          );
        });
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (!mounted || _highlightOrderId != lastAddedOrderId) {
            return;
          }
          setState(() {
            _highlightOrderId = null;
          });
        });
      }
      if (mounted) {
        setState(() {});
      }
    };
    OrderStore.instance.addListener(_storeListener);
  }

  List<OrderVm> _buildSeedOrders() {
    final now = DateTime.now();
    return [
      OrderVm(
        id: '1',
        customerName: 'Khach le',
        sellerName: 'Long Hoang',
        createdAt: now.subtract(const Duration(hours: 2)),
        status: OrderStatusVm.unpaid,
        lines: const [
          OrderLineVm(
            name: 'Kim chi',
            quantity: 3,
            unitPrice: 25000,
            note: 'Khong hanh',
          ),
          OrderLineVm(name: 'Bun bo', quantity: 1, unitPrice: 50000),
        ],
      ),
      OrderVm(
        id: '2',
        customerName: 'Ban so 5',
        sellerName: 'Ngoc Anh',
        createdAt: now.subtract(const Duration(hours: 6)),
        status: OrderStatusVm.paid,
        lines: const [
          OrderLineVm(name: 'Pho bo', quantity: 2, unitPrice: 45000),
          OrderLineVm(
            name: 'Tra dao',
            quantity: 2,
            unitPrice: 30000,
            note: 'It da',
          ),
          OrderLineVm(name: 'Ca phe sua', quantity: 1, unitPrice: 25000),
        ],
      ),
      OrderVm(
        id: '3',
        customerName: 'Cong ty ABC',
        sellerName: 'Long Hoang',
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
        status: OrderStatusVm.unpaid,
        lines: const [
          OrderLineVm(name: 'Com ga', quantity: 4, unitPrice: 55000),
        ],
      ),
      OrderVm(
        id: '4',
        customerName: 'Anh Nam',
        sellerName: 'Ngoc Anh',
        createdAt: now.subtract(const Duration(days: 4, hours: 1)),
        status: OrderStatusVm.paid,
        lines: const [
          OrderLineVm(
            name: 'Banh mi',
            quantity: 5,
            unitPrice: 18000,
            note: 'Khong ot',
          ),
          OrderLineVm(name: 'Tra dao', quantity: 3, unitPrice: 30000),
          OrderLineVm(name: 'Pho bo', quantity: 1, unitPrice: 45000),
          OrderLineVm(name: 'Bun cha', quantity: 1, unitPrice: 50000),
          OrderLineVm(name: 'Ca phe sua', quantity: 2, unitPrice: 25000),
          OrderLineVm(name: 'Com ga', quantity: 1, unitPrice: 55000),
        ],
      ),
    ];
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
    final filtered = _applyFilters(store.orders);
    final grouped = _groupByDate(filtered);
    final loading = store.loading && grouped.isEmpty;
    final errorMessage = store.errorMessage;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC), Color(0xFFE0ECFF)],
        ),
      ),
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
              child: RefreshIndicator(
                onRefresh: () => OrderStore.instance.loadOrders(force: true),
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : grouped.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: [
                          _OrdersEmptyState(
                            hasError:
                                errorMessage != null && errorMessage.isNotEmpty,
                            onRetry: () async {
                              await OrderStore.instance.loadOrders(force: true);
                            },
                          ),
                        ],
                      )
                    : CustomScrollView(
                        controller: _scrollController,
                        slivers: _buildStickyGroupedSlivers(grouped),
                      ),
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
              'Hoa don',
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
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tim theo hang hoa, khach hang',
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
              });
              FocusScope.of(context).unfocus();
            },
            child: const Text(
              'Huy',
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
    final query = _searchController.text.trim().toLowerCase();

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

      if (query.isEmpty) return true;

      final inCustomer = order.customerName.toLowerCase().contains(query);
      final inItems = order.lines.any(
        (line) => line.name.toLowerCase().contains(query),
      );
      return inCustomer || inItems;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyDateHeaderDelegate(
            group: group,
            dateLabelBuilder: _dateHeader,
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final order = group.orders[index];
              return _OrderCard(
                order: order,
                highlight: _highlightOrderId == order.id,
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
      );
    }
    slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 16)));
    return slivers;
  }
  Future<void> _pickStatusFilter() async {
    final result = await showModalBottomSheet<OrderStatusFilter>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetTile(
                label: _statusFilterText(context, OrderStatusFilter.all),
                selected: _statusFilter == OrderStatusFilter.all,
                onTap: () => Navigator.pop(context, OrderStatusFilter.all),
              ),
              _SheetTile(
                label: _statusFilterText(context, OrderStatusFilter.paid),
                selected: _statusFilter == OrderStatusFilter.paid,
                onTap: () => Navigator.pop(context, OrderStatusFilter.paid),
              ),
              _SheetTile(
                label: _statusFilterText(context, OrderStatusFilter.unpaid),
                selected: _statusFilter == OrderStatusFilter.unpaid,
                onTap: () => Navigator.pop(context, OrderStatusFilter.unpaid),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _statusFilter = result;
      });
    }
  }

  Future<void> _pickTimeFilter() async {
    final result = await showModalBottomSheet<OrderTimeFilter>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetTile(
                label: _timeFilterText(context, OrderTimeFilter.all),
                selected:
                    _timeFilter == OrderTimeFilter.all && _customRange == null,
                onTap: () => Navigator.pop(context, OrderTimeFilter.all),
              ),
              _SheetTile(
                label: _timeFilterText(context, OrderTimeFilter.today),
                selected: _timeFilter == OrderTimeFilter.today,
                onTap: () => Navigator.pop(context, OrderTimeFilter.today),
              ),
              _SheetTile(
                label: _timeFilterText(context, OrderTimeFilter.yesterday),
                selected: _timeFilter == OrderTimeFilter.yesterday,
                onTap: () => Navigator.pop(context, OrderTimeFilter.yesterday),
              ),
              _SheetTile(
                label: _timeFilterText(context, OrderTimeFilter.last7Days),
                selected: _timeFilter == OrderTimeFilter.last7Days,
                onTap: () => Navigator.pop(context, OrderTimeFilter.last7Days),
              ),
              _SheetTile(
                label: _timeFilterText(context, OrderTimeFilter.thisMonth),
                selected: _timeFilter == OrderTimeFilter.thisMonth,
                onTap: () => Navigator.pop(context, OrderTimeFilter.thisMonth),
              ),
              _SheetTile(
                label: _timeFilterText(context, OrderTimeFilter.lastMonth),
                selected: _timeFilter == OrderTimeFilter.lastMonth,
                onTap: () => Navigator.pop(context, OrderTimeFilter.lastMonth),
              ),
              _SheetTile(
                label: _timeFilterText(context, OrderTimeFilter.custom),
                selected:
                    _timeFilter == OrderTimeFilter.custom &&
                    _customRange != null,
                onTap: () => Navigator.pop(context, OrderTimeFilter.custom),
              ),
            ],
          ),
        );
      },
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
        });
      }
      return;
    }

    setState(() {
      _customRange = null;
      _timeFilter = result;
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

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xac nhan thanh toan'),
          content: const Text(
            'Ban co chac chan muon danh dau don nay la DA NHAN TIEN?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565FF),
              ),
              child: const Text('Xac nhan'),
            ),
          ],
        );
      },
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
    final isVi = _isVietnameseLocale(context);
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      final todayLabel = isVi ? 'Hom nay' : 'Today';
      return '$todayLabel, ${localizations.formatShortDate(date)}';
    }
    final weekday = _weekdayLabel(date.weekday, isVi: isVi);
    return '$weekday, ${localizations.formatShortDate(date)}';
  }

  bool _isVietnameseLocale(BuildContext context) {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'vi';
  }

  String _timeFilterText(BuildContext context, OrderTimeFilter key) {
    final isVi = _isVietnameseLocale(context);
    switch (key) {
      case OrderTimeFilter.today:
        return isVi ? 'Hom nay' : 'Today';
      case OrderTimeFilter.yesterday:
        return isVi ? 'Hom qua' : 'Yesterday';
      case OrderTimeFilter.last7Days:
        return isVi ? '7 ngay qua' : 'Last 7 days';
      case OrderTimeFilter.thisMonth:
        return isVi ? 'Thang nay' : 'This month';
      case OrderTimeFilter.lastMonth:
        return isVi ? 'Thang truoc' : 'Last month';
      case OrderTimeFilter.custom:
        return isVi ? 'Tuy chinh' : 'Custom';
      case OrderTimeFilter.all:
        return isVi ? 'Toan thoi gian' : 'All time';
    }
  }

  String _statusFilterText(BuildContext context, OrderStatusFilter key) {
    final isVi = _isVietnameseLocale(context);
    switch (key) {
      case OrderStatusFilter.paid:
        return isVi ? 'Da nhan tien' : 'Paid';
      case OrderStatusFilter.unpaid:
        return isVi ? 'Chua thanh toan' : 'Unpaid';
      case OrderStatusFilter.all:
        return isVi ? 'Tat ca don' : 'All orders';
    }
  }

  static String _weekdayLabel(int weekday, {required bool isVi}) {
    if (isVi) {
      const weekdaysVi = [
        'Thu Hai',
        'Thu Ba',
        'Thu Tu',
        'Thu Nam',
        'Thu Sau',
        'Thu Bay',
        'Chu Nhat',
      ];
      return weekdaysVi[weekday - 1];
    }
    const weekdaysEn = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return weekdaysEn[weekday - 1];
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

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? const Color(0xFF1565FF) : const Color(0xFF111827),
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: Color(0xFF1565FF))
          : null,
      onTap: onTap,
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
                ? 'Chua tai duoc danh sach hoa don.'
                : 'Danh sach don hang dang trong.\nBam Ban hang de tao don.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
          if (hasError) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thu tai lai'),
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
      child: ColoredBox(
        color: const Color(0xFFF8FAFC),
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
    required this.highlight,
    required this.onPaidTap,
    required this.onTap,
  });

  final OrderVm order;
  final bool highlight;
  final ValueChanged<OrderVm> onPaidTap;
  final ValueChanged<OrderVm> onTap;

  @override
  Widget build(BuildContext context) {
    final lineSummary = _buildLinesSummary(order.lines);
    final noteSummary = _buildNotesSummary(order.lines);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFFFF7CC) : Colors.white,
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
                            'Nhan vien: ${order.sellerName}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
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
                              'Da nhan tien',
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
    if (lines.isEmpty) return 'Don hang trong';

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
          buffer.write(' + $remain hang khac');
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

