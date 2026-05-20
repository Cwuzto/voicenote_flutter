import 'package:flutter/material.dart';

import '../domain/dashboard_time_filter.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/presentation/order_models.dart';
import '../../sale/presentation/sale_screen.dart';
import 'best_seller_screen.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  final OrderRepository _orderRepository = OrderRepository();

  bool _loading = true;
  String? _errorMessage;
  List<OrderVm> _paidOrders = [];

  DashboardRangeKey _revenueRangeKey = DashboardRangeKey.thisMonth;
  DateTimeRange? _revenueCustomRange;
  DashboardRangeKey _chartRangeKey = DashboardRangeKey.thisMonth;
  DateTimeRange? _chartCustomRange;
  DashboardRangeKey _bestRangeKey = DashboardRangeKey.thisMonth;
  DateTimeRange? _bestCustomRange;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  @override
  Widget build(BuildContext context) {
    final revenueRange = DashboardTimeFilter.resolveRange(
      _revenueRangeKey,
      custom: _revenueCustomRange,
    );
    final chartRange = DashboardTimeFilter.resolveRange(
      _chartRangeKey,
      custom: _chartCustomRange,
    );
    final bestRange = DashboardTimeFilter.resolveRange(
      _bestRangeKey,
      custom: _bestCustomRange,
    );

    final revenueOrders = _ordersInRange(_paidOrders, revenueRange);
    final chartOrders = _ordersInRange(_paidOrders, chartRange);
    final bestOrders = _ordersInRange(_paidOrders, bestRange);
    final hasAnyPaidData = _paidOrders.isNotEmpty;

    final revenueAmount = revenueOrders.fold<int>(
      0,
      (sum, order) => sum + order.totalAmount,
    );
    final orderCount = revenueOrders.length;
    final chartData = _buildChartData(chartOrders, chartRange, _chartRangeKey);
    final bestRows = _aggregateBestSellers(bestOrders);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.storefront_rounded, size: 34, color: Color(0xFF1565FF)),
                SizedBox(width: 10),
                Text(
                  'voicenote',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.trending_up_rounded,
                    value: _formatCurrency(revenueAmount),
                    label: 'Doanh thu ${_rangeLabel(_revenueRangeKey).toLowerCase()}',
                    onTap: () => _pickRange(_FilterSection.revenue),
                    showFilterArrow: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.receipt_long_rounded,
                    value: '$orderCount',
                    label: 'Don ${_rangeLabel(_revenueRangeKey).toLowerCase()}',
                  ),
                ),
              ],
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Doanh thu',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _TimeChip(
                        label: _rangeLabel(
                          _chartRangeKey,
                          custom: _chartCustomRange,
                        ),
                        onTap: () => _pickRange(_FilterSection.chart),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loading) ...[
                    const SizedBox(
                      height: 190,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ] else if (!hasAnyPaidData) ...[
                    _EmptyState(
                      icon: Icons.trending_up_rounded,
                      message: 'Ban chua co don nao, tao thu don de xem thong ke.',
                      actionText: 'Tao thu don',
                      onAction: _openSale,
                    ),
                  ] else if (chartData.points.isEmpty) ...[
                    const _EmptyState(
                      icon: Icons.trending_up_rounded,
                      message: 'Chua co du lieu trong khoang thoi gian nay.',
                    ),
                  ] else ...[
                    SizedBox(
                      height: 220,
                      child: _MiniLineChart(data: chartData),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Hang hoa ban chay',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _TimeChip(
                        label: _rangeLabel(
                          _bestRangeKey,
                          custom: _bestCustomRange,
                        ),
                        onTap: () => _pickRange(_FilterSection.best),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loading) ...[
                    const Center(child: CircularProgressIndicator()),
                  ] else if (!hasAnyPaidData) ...[
                    const _EmptyState(
                      icon: Icons.receipt_long_rounded,
                      message: 'Chua co du lieu ban chay',
                    ),
                  ] else if (bestRows.isEmpty) ...[
                    const _EmptyState(
                      icon: Icons.receipt_long_rounded,
                      message: 'Khong co mat hang nao trong khoang nay',
                    ),
                  ] else ...[
                    ...bestRows.take(3).toList().asMap().entries.map(
                      (entry) => _BestSellerRow(
                        data: _BestSellerData(
                          rank: entry.key + 1,
                          productName: entry.value.productName,
                          quantity: entry.value.quantity,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BestSellerScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Xem tat ca',
                          style: TextStyle(
                            color: Color(0xFF1565FF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _loadOverview() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final orders = await _orderRepository.fetchOrders();
      if (!mounted) return;
      setState(() {
        _paidOrders = orders.where((o) => o.status == OrderStatusVm.paid).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openSale() async {
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const SaleScreen()),
    );
    if (!mounted) return;
    await _loadOverview();
  }

  List<OrderVm> _ordersInRange(
    List<OrderVm> orders,
    DashboardResolvedRange range,
  ) {
    return orders.where((o) {
      return DashboardTimeFilter.contains(o.createdAt, range);
    }).toList();
  }

  _ChartRenderData _buildChartData(
    List<OrderVm> orders,
    DashboardResolvedRange range,
    DashboardRangeKey rangeKey,
  ) {
    final isSingleDay = rangeKey == DashboardRangeKey.today ||
        rangeKey == DashboardRangeKey.yesterday;
    final bucket = <int, double>{};

    for (final order in orders) {
      final dt = order.createdAt;
      final key = isSingleDay
          ? DateTime(dt.year, dt.month, dt.day, dt.hour).millisecondsSinceEpoch
          : DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch;
      bucket.update(key, (value) => value + order.totalAmount, ifAbsent: () => order.totalAmount.toDouble());
    }

    final points = bucket.entries
        .map((e) => _ChartPointVm(xMillis: e.key.toDouble(), y: e.value))
        .toList()
      ..sort((a, b) => a.xMillis.compareTo(b.xMillis));

    final startX = range.start.millisecondsSinceEpoch.toDouble();
    final endX = range.end.millisecondsSinceEpoch.toDouble();
    if (points.length == 1) {
      final only = points.first;
      if (only.xMillis != startX) {
        points.insert(0, _ChartPointVm(xMillis: startX, y: 0));
      }
      if (only.xMillis < endX) {
        points.add(_ChartPointVm(xMillis: endX, y: 0));
      }
    }

    if (points.isEmpty) {
      return _ChartRenderData(
        points: const [],
        isSingleDay: isSingleDay,
        minY: 0,
        maxY: 0,
        startX: startX,
        endX: endX,
      );
    }

    var minY = points.first.y;
    var maxY = points.first.y;
    for (final p in points) {
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    return _ChartRenderData(
      points: points,
      isSingleDay: isSingleDay,
      minY: minY,
      maxY: maxY,
      startX: startX,
      endX: endX,
    );
  }

  List<_BestSellerRowVm> _aggregateBestSellers(List<OrderVm> orders) {
    final map = <String, _BestSellerRowVm>{};
    for (final order in orders) {
      for (final line in order.lines) {
        final current = map[line.name];
        if (current == null) {
          map[line.name] = _BestSellerRowVm(
            productName: line.name,
            quantity: line.quantity,
            revenue: line.lineTotal,
          );
        } else {
          current.quantity += line.quantity;
          current.revenue += line.lineTotal;
        }
      }
    }
    final rows = map.values.toList();
    rows.sort((a, b) => b.quantity.compareTo(a.quantity));
    return rows;
  }

  Future<void> _pickRange(_FilterSection section) async {
    final selected = await showModalBottomSheet<DashboardRangeKey>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: DashboardRangeKey.values
                .map(
                  (k) => ListTile(
                    title: Text(_rangeLabel(k)),
                    onTap: () => Navigator.pop(context, k),
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;

    if (selected == DashboardRangeKey.custom) {
      final custom = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (!mounted || custom == null) return;
      setState(() {
        switch (section) {
          case _FilterSection.revenue:
            _revenueRangeKey = DashboardRangeKey.custom;
            _revenueCustomRange = custom;
            break;
          case _FilterSection.chart:
            _chartRangeKey = DashboardRangeKey.custom;
            _chartCustomRange = custom;
            break;
          case _FilterSection.best:
            _bestRangeKey = DashboardRangeKey.custom;
            _bestCustomRange = custom;
            break;
        }
      });
      return;
    }

    setState(() {
      switch (section) {
        case _FilterSection.revenue:
          _revenueRangeKey = selected;
          _revenueCustomRange = null;
          break;
        case _FilterSection.chart:
          _chartRangeKey = selected;
          _chartCustomRange = null;
          break;
        case _FilterSection.best:
          _bestRangeKey = selected;
          _bestCustomRange = null;
          break;
      }
    });
  }

  String _rangeLabel(DashboardRangeKey key, {DateTimeRange? custom}) {
    if (key == DashboardRangeKey.custom && custom != null) {
      return '${_ddmm(custom.start)} - ${_ddmm(custom.end)}';
    }
    switch (key) {
      case DashboardRangeKey.today:
        return 'Hom nay';
      case DashboardRangeKey.yesterday:
        return 'Hom qua';
      case DashboardRangeKey.sevenDays:
        return '7 ngay qua';
      case DashboardRangeKey.thisMonth:
        return 'Thang nay';
      case DashboardRangeKey.lastMonth:
        return 'Thang truoc';
      case DashboardRangeKey.thisYear:
        return 'Nam nay';
      case DashboardRangeKey.custom:
        return 'Tuy chinh';
    }
  }

  String _ddmm(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m';
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
}

enum _FilterSection { revenue, chart, best }

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
    this.showFilterArrow = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;
  final bool showFilterArrow;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 112,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: const Color(0xFF1565FF)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showFilterArrow)
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.actionText,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(icon, size: 64, color: const Color(0xFF1565FF)),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 10),
              OutlinedButton(onPressed: onAction, child: Text(actionText!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _BestSellerData {
  const _BestSellerData({
    required this.rank,
    required this.productName,
    required this.quantity,
  });

  final int rank;
  final String productName;
  final int quantity;
}

class _BestSellerRow extends StatelessWidget {
  const _BestSellerRow({required this.data});

  final _BestSellerData data;

  static const List<Color> _rankColors = [
    Color(0xFFF59E0B),
    Color(0xFF6B7280),
    Color(0xFF8D6E63),
  ];

  @override
  Widget build(BuildContext context) {
    final color = data.rank <= 3 ? _rankColors[data.rank - 1] : const Color(0xFF64748B);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              data.rank.toString(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.star_rounded, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              data.productName,
              style: const TextStyle(fontSize: 16, color: Color(0xFF0F172A)),
            ),
          ),
          Text(
            'x${data.quantity}',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _BestSellerRowVm {
  _BestSellerRowVm({
    required this.productName,
    required this.quantity,
    required this.revenue,
  });

  final String productName;
  int quantity;
  int revenue;
}

class _ChartPointVm {
  const _ChartPointVm({required this.xMillis, required this.y});

  final double xMillis;
  final double y;
}

class _ChartRenderData {
  const _ChartRenderData({
    required this.points,
    required this.isSingleDay,
    required this.minY,
    required this.maxY,
    required this.startX,
    required this.endX,
  });

  final List<_ChartPointVm> points;
  final bool isSingleDay;
  final double minY;
  final double maxY;
  final double startX;
  final double endX;
}

class _MiniLineChart extends StatefulWidget {
  const _MiniLineChart({required this.data});

  final _ChartRenderData data;

  @override
  State<_MiniLineChart> createState() => _MiniLineChartState();
}

class _MiniLineChartState extends State<_MiniLineChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final points = widget.data.points;
    final selected = _selectedIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 20,
          child: selected != null && selected >= 0 && selected < points.length
              ? Text(
                  '${_OverviewScreenState._formatCurrency(points[selected].y.round())}d',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _selectNearest(details.localPosition.dx),
            onHorizontalDragUpdate: (details) =>
                _selectNearest(details.localPosition.dx),
            onTapCancel: () => setState(() => _selectedIndex = null),
            onHorizontalDragEnd: (_) => setState(() => _selectedIndex = null),
            child: CustomPaint(
              painter: _MiniLineChartPainter(
                data: widget.data,
                selectedIndex: _selectedIndex,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _ChartAxisLabels(data: widget.data),
      ],
    );
  }

  void _selectNearest(double localX) {
    final points = widget.data.points;
    if (points.isEmpty) return;
    final width = context.size?.width ?? 0;
    if (width <= 0) return;
    const leftPad = 8.0;
    const rightPad = 8.0;
    final usableWidth = width - leftPad - rightPad;
    if (usableWidth <= 0) return;
    final startX = widget.data.startX;
    final endX = widget.data.endX;
    final x = (localX - leftPad).clamp(0.0, usableWidth);
    final millis = startX + (x / usableWidth) * (endX - startX);
    var nearestIdx = 0;
    var nearestDistance = double.infinity;
    for (int i = 0; i < points.length; i++) {
      final d = (points[i].xMillis - millis).abs();
      if (d < nearestDistance) {
        nearestDistance = d;
        nearestIdx = i;
      }
    }
    if (_selectedIndex != nearestIdx) {
      setState(() {
        _selectedIndex = nearestIdx;
      });
    }
  }
}

class _ChartAxisLabels extends StatelessWidget {
  const _ChartAxisLabels({required this.data});

  final _ChartRenderData data;

  @override
  Widget build(BuildContext context) {
    final ticks = List<double>.generate(
      4,
      (i) => data.startX + ((data.endX - data.startX) * i / 3),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: ticks.map((x) {
        final dt = DateTime.fromMillisecondsSinceEpoch(x.round());
        final label = data.isSingleDay
            ? '${dt.hour.toString().padLeft(2, '0')}h'
            : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
        return Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        );
      }).toList(),
    );
  }
}

class _MiniLineChartPainter extends CustomPainter {
  _MiniLineChartPainter({required this.data, required this.selectedIndex});

  final _ChartRenderData data;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final points = data.points;
    if (points.isEmpty) return;
    const leftPad = 8.0;
    const rightPad = 8.0;
    const topPad = 10.0;
    const bottomPad = 20.0;

    final width = size.width - leftPad - rightPad;
    final height = size.height - topPad - bottomPad;
    final xRange = (data.endX - data.startX).abs() < 1 ? 1.0 : data.endX - data.startX;
    final yRange = (data.maxY - data.minY).abs() < 1 ? 1.0 : data.maxY - data.minY;

    Offset mapPoint(_ChartPointVm p) {
      final dx = leftPad + ((p.xMillis - data.startX) / xRange) * width;
      final dy = topPad + (1 - ((p.y - data.minY) / yRange)) * height;
      return Offset(dx, dy);
    }

    final plotPoints = points.map(mapPoint).toList();

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 0; i < 3; i++) {
      final y = topPad + (height * i / 2);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);
    }

    if (plotPoints.length > 1) {
      final smoothPath = Path()..moveTo(plotPoints.first.dx, plotPoints.first.dy);
      for (int i = 1; i < plotPoints.length; i++) {
        final prev = plotPoints[i - 1];
        final cur = plotPoints[i];
        final midX = (prev.dx + cur.dx) / 2;
        smoothPath.cubicTo(midX, prev.dy, midX, cur.dy, cur.dx, cur.dy);
      }

      final fillPath = Path.from(smoothPath)
        ..lineTo(plotPoints.last.dx, size.height - bottomPad)
        ..lineTo(plotPoints.first.dx, size.height - bottomPad)
        ..close();

      final fillPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x661565FF), Color(0x001565FF)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      final linePaint = Paint()
        ..color = const Color(0xFF1565FF)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawPath(smoothPath, linePaint);
    }

    final dotPaint = Paint()..color = const Color(0xFF1565FF);
    for (int i = 0; i < plotPoints.length; i++) {
      final p = plotPoints[i];
      canvas.drawCircle(p, selectedIndex == i ? 4.8 : 3.2, dotPaint);
      if (selectedIndex == i) {
        final ring = Paint()
          ..color = const Color(0x661565FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5;
        canvas.drawCircle(p, 8, ring);
      }
    }

    final minValue = data.minY;
    final maxValue = data.maxY;
    final textStyle = const TextStyle(
      color: Color(0xFF6B7280),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    final paintedMax = <double>{};
    for (int i = 0; i < points.length; i++) {
      final y = points[i].y;
      if ((y - minValue).abs() < 0.001 || (y - maxValue).abs() < 0.001) {
        if (paintedMax.contains(y)) continue;
        paintedMax.add(y);
        final tp = TextPainter(
          text: TextSpan(
            text: '${_OverviewScreenState._formatCurrency(y.round())}d',
            style: textStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final p = plotPoints[i];
        tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height - 6));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniLineChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.selectedIndex != selectedIndex;
  }
}
