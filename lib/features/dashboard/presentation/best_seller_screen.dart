import 'package:flutter/material.dart';

import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/gradient_background.dart';
import '../data/dashboard_repository.dart';

class BestSellerScreen extends StatefulWidget {
  const BestSellerScreen({super.key});

  @override
  State<BestSellerScreen> createState() => _BestSellerScreenState();
}

class _BestSellerScreenState extends State<BestSellerScreen> {
  final DashboardRepository _repository = DashboardRepository();
  bool _searchMode = false;
  final TextEditingController _searchController = TextEditingController();

  String _timeFilter = 'THIS_MONTH';
  String _sortFilter = 'QUANTITY';
  DateTimeRange? _customRange;
  bool _loading = true;
  String? _errorMessage;
  List<SoldLineVm> _soldLines = [];
  String _lastBestSellerQuery = '';
  String _lastBestSellerTimeFilter = '';
  String _lastBestSellerSortFilter = '';
  DateTimeRange? _lastBestSellerCustomRange;
  List<SoldLineVm>? _lastBestSellerSource;
  List<_BestSellerRowVm>? _cachedRows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
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
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _errorMessage!,
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
                    final rows = _buildRows(value.text);
                    return _loading
                        ? const Center(child: CircularProgressIndicator())
                        : rows.isEmpty
                        ? const Center(
                            child: Text(
                              'Chưa có dữ liệu bán chạy',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount: rows.length,
                            itemBuilder: (context, index) {
                              return _BestSellerCard(
                                rank: index + 1,
                                row: rows[index],
                                sortFilter: _sortFilter,
                              );
                            },
                          );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
          const Expanded(
            child: Text(
              'Hàng hóa bán chạy',
              style: TextStyle(
                fontSize: 24,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Tìm theo hàng hóa',
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
                _invalidateRowsCache();
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
          _FilterChipButton(label: _timeFilterLabel(), onTap: _pickTimeFilter),
          const SizedBox(width: 12),
          _FilterChipButton(label: _sortFilterLabel(), onTap: _pickSortFilter),
        ],
      ),
    );
  }

  List<_BestSellerRowVm> _buildRows(String queryText) {
    final query = queryText.trim().toLowerCase();
    final canReuse =
        identical(_lastBestSellerSource, _soldLines) &&
        _lastBestSellerQuery == query &&
        _lastBestSellerTimeFilter == _timeFilter &&
        _lastBestSellerSortFilter == _sortFilter &&
        _sameRange(_lastBestSellerCustomRange, _customRange) &&
        _cachedRows != null;
    if (canReuse) {
      return _cachedRows!;
    }

    final source = _soldLines.where((item) => _matchTime(item.soldAt));
    final map = <String, _BestSellerRowVm>{};

    for (final item in source) {
      final exists = map[item.productName];
      if (exists == null) {
        map[item.productName] = _BestSellerRowVm(
          productName: item.productName,
          quantity: item.quantity,
          revenue: item.quantity * item.unitPrice,
        );
      } else {
        exists.quantity += item.quantity;
        exists.revenue += item.quantity * item.unitPrice;
      }
    }

    final rows = map.values
        .where(
          (row) =>
              query.isEmpty || row.productName.toLowerCase().contains(query),
        )
        .toList();

    rows.sort((a, b) {
      if (_sortFilter == 'REVENUE') {
        return b.revenue.compareTo(a.revenue);
      }
      return b.quantity.compareTo(a.quantity);
    });

    _lastBestSellerSource = _soldLines;
    _lastBestSellerQuery = query;
    _lastBestSellerTimeFilter = _timeFilter;
    _lastBestSellerSortFilter = _sortFilter;
    _lastBestSellerCustomRange = _customRange;
    _cachedRows = rows;
    return rows;
  }

  bool _sameRange(DateTimeRange? a, DateTimeRange? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    return a.start == b.start && a.end == b.end;
  }

  void _invalidateRowsCache() {
    _lastBestSellerSource = null;
    _lastBestSellerQuery = '';
    _lastBestSellerTimeFilter = '';
    _lastBestSellerSortFilter = '';
    _lastBestSellerCustomRange = null;
    _cachedRows = null;
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
      case 'ALL':
        return true;
      case 'TODAY':
        return _sameDate(value, now);
      case 'YESTERDAY':
        final y = now.subtract(const Duration(days: 1));
        return _sameDate(value, y);
      case '7DAYS':
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
        return !value.isBefore(start);
      case 'THIS_MONTH':
        return value.year == now.year && value.month == now.month;
      case 'LAST_MONTH':
        final lastMonth = DateTime(now.year, now.month - 1);
        return value.year == lastMonth.year && value.month == lastMonth.month;
      case 'THIS_YEAR':
        return value.year == now.year;
      default:
        return true;
    }
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickSortFilter() async {
    final result = await showAppOptionSheet<String>(
      context: context,
      title: 'Sắp xếp danh sách',
      actions: [
        AppSheetAction(
          label: 'Theo số lượng',
          value: 'QUANTITY',
          selected: _sortFilter == 'QUANTITY',
          icon: Icons.format_list_numbered_rounded,
        ),
        AppSheetAction(
          label: 'Theo doanh thu',
          value: 'REVENUE',
          selected: _sortFilter == 'REVENUE',
          icon: Icons.payments_outlined,
        ),
      ],
    );

    if (result != null) {
      setState(() {
        _sortFilter = result;
        _invalidateRowsCache();
      });
    }
  }

  Future<void> _pickTimeFilter() async {
    final result = await showAppOptionSheet<String>(
      context: context,
      title: 'Chọn thời gian',
      actions: [
        AppSheetAction(
          label: 'Toàn thời gian',
          value: 'ALL',
          selected: _timeFilter == 'ALL' && _customRange == null,
          icon: Icons.all_inclusive_rounded,
        ),
        AppSheetAction(
          label: 'Hôm nay',
          value: 'TODAY',
          selected: _timeFilter == 'TODAY',
          icon: Icons.today_rounded,
        ),
        AppSheetAction(
          label: 'Hôm qua',
          value: 'YESTERDAY',
          selected: _timeFilter == 'YESTERDAY',
          icon: Icons.history_toggle_off_rounded,
        ),
        AppSheetAction(
          label: '7 ngày qua',
          value: '7DAYS',
          selected: _timeFilter == '7DAYS',
          icon: Icons.date_range_rounded,
        ),
        AppSheetAction(
          label: 'Tháng nay',
          value: 'THIS_MONTH',
          selected: _timeFilter == 'THIS_MONTH',
          icon: Icons.calendar_month_rounded,
        ),
        AppSheetAction(
          label: 'Tháng trước',
          value: 'LAST_MONTH',
          selected: _timeFilter == 'LAST_MONTH',
          icon: Icons.event_repeat_rounded,
        ),
        AppSheetAction(
          label: 'Năm nay',
          value: 'THIS_YEAR',
          selected: _timeFilter == 'THIS_YEAR',
          icon: Icons.event_note_rounded,
        ),
        AppSheetAction(
          label: 'Tùy chỉnh',
          value: 'CUSTOM',
          selected: _timeFilter == 'CUSTOM' && _customRange != null,
          icon: Icons.tune_rounded,
        ),
      ],
    );

    if (!mounted || result == null) {
      return;
    }

    if (result == 'CUSTOM') {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (!mounted || range == null) {
        return;
      }
      setState(() {
        _customRange = range;
        _timeFilter = 'CUSTOM';
        _invalidateRowsCache();
      });
      return;
    }

    setState(() {
      _customRange = null;
      _timeFilter = result;
      _invalidateRowsCache();
    });
  }

  String _timeFilterLabel() {
    if (_customRange != null) {
      return '${_ddmm(_customRange!.start)} - ${_ddmm(_customRange!.end)}';
    }

    switch (_timeFilter) {
      case 'ALL':
        return 'Toàn thời gian';
      case 'TODAY':
        return 'Hôm nay';
      case 'YESTERDAY':
        return 'Hôm qua';
      case '7DAYS':
        return '7 ngày qua';
      case 'THIS_MONTH':
        return 'Tháng nay';
      case 'LAST_MONTH':
        return 'Tháng trước';
      case 'THIS_YEAR':
        return 'Năm nay';
      default:
        return 'Tháng nay';
    }
  }

  String _sortFilterLabel() {
    return _sortFilter == 'REVENUE' ? 'Theo doanh thu' : 'Theo số lượng';
  }

  String _ddmm(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final soldLines = await _repository.fetchSoldLines();
      if (!mounted) {
        return;
      }
      setState(() {
        _soldLines = soldLines;
        _invalidateRowsCache();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
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

class _BestSellerCard extends StatelessWidget {
  const _BestSellerCard({
    required this.rank,
    required this.row,
    required this.sortFilter,
  });

  final int rank;
  final _BestSellerRowVm row;
  final String sortFilter;

  static const List<Color> _rankColors = [
    Color(0xFFF59E0B),
    Color(0xFF6B7280),
    Color(0xFF8D6E63),
  ];

  static const List<Color> _rankIconColors = [
    Color(0xFFFDE68A),
    Color(0xFFD1D5DB),
    Color(0xFFA1887F),
  ];

  @override
  Widget build(BuildContext context) {
    final rankColor = rank <= 3
        ? _rankColors[rank - 1]
        : const Color(0xFF6B7280);
    final starColor = rank <= 3
        ? _rankIconColors[rank - 1]
        : const Color(0xFFD1D5DB);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rankColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              rank.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (rank <= 3)
            Icon(Icons.star_rounded, size: 20, color: starColor)
          else
            const SizedBox(width: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.productName,
              style: const TextStyle(fontSize: 16, color: Color(0xFF0F172A)),
            ),
          ),
          Text(
            sortFilter == 'REVENUE'
                ? '${_formatCurrency(row.revenue)}d'
                : 'x${row.quantity}',
            style: TextStyle(
              color: sortFilter == 'REVENUE'
                  ? const Color(0xFF1565FF)
                  : const Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
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
