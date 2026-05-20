import 'package:flutter/material.dart';

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
    final rows = _buildRows();

    return Scaffold(
      body: Container(
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
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : rows.isEmpty
                    ? const Center(
                        child: Text(
                          'Chua co du lieu ban chay',
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
              'Hang hoa ban chay',
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
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tim theo hang hoa',
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
          _FilterChipButton(label: _timeFilterLabel(), onTap: _pickTimeFilter),
          const SizedBox(width: 12),
          _FilterChipButton(label: _sortFilterLabel(), onTap: _pickSortFilter),
        ],
      ),
    );
  }

  List<_BestSellerRowVm> _buildRows() {
    final query = _searchController.text.trim().toLowerCase();
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

    return rows;
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
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetTile(
                label: 'Theo so luong',
                onTap: () => Navigator.pop(context, 'QUANTITY'),
              ),
              _SheetTile(
                label: 'Theo doanh thu',
                onTap: () => Navigator.pop(context, 'REVENUE'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _sortFilter = result;
      });
    }
  }

  Future<void> _pickTimeFilter() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetTile(
                label: 'Toan thoi gian',
                onTap: () => Navigator.pop(context, 'ALL'),
              ),
              _SheetTile(
                label: 'Hom nay',
                onTap: () => Navigator.pop(context, 'TODAY'),
              ),
              _SheetTile(
                label: 'Hom qua',
                onTap: () => Navigator.pop(context, 'YESTERDAY'),
              ),
              _SheetTile(
                label: '7 ngay qua',
                onTap: () => Navigator.pop(context, '7DAYS'),
              ),
              _SheetTile(
                label: 'Thang nay',
                onTap: () => Navigator.pop(context, 'THIS_MONTH'),
              ),
              _SheetTile(
                label: 'Thang truoc',
                onTap: () => Navigator.pop(context, 'LAST_MONTH'),
              ),
              _SheetTile(
                label: 'Nam nay',
                onTap: () => Navigator.pop(context, 'THIS_YEAR'),
              ),
              _SheetTile(
                label: 'Tuy chinh',
                onTap: () => Navigator.pop(context, 'CUSTOM'),
              ),
            ],
          ),
        );
      },
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
      });
      return;
    }

    setState(() {
      _customRange = null;
      _timeFilter = result;
    });
  }

  String _timeFilterLabel() {
    if (_customRange != null) {
      return '${_ddmm(_customRange!.start)} - ${_ddmm(_customRange!.end)}';
    }

    switch (_timeFilter) {
      case 'ALL':
        return 'Toan thoi gian';
      case 'TODAY':
        return 'Hom nay';
      case 'YESTERDAY':
        return 'Hom qua';
      case '7DAYS':
        return '7 ngay qua';
      case 'THIS_MONTH':
        return 'Thang nay';
      case 'LAST_MONTH':
        return 'Thang truoc';
      case 'THIS_YEAR':
        return 'Nam nay';
      default:
        return 'Thang nay';
    }
  }

  String _sortFilterLabel() {
    return _sortFilter == 'REVENUE' ? 'Theo doanh thu' : 'Theo so luong';
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

class _SheetTile extends StatelessWidget {
  const _SheetTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(label), onTap: onTap);
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
