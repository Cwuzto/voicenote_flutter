import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../sale/presentation/sale_screen.dart';
import 'order_models.dart';
import 'order_store.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.order});

  final OrderVm order;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _showAllItems = false;
  bool _markingPaid = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final totalLines = order.lines.length;
    const previewLimit = 2;
    final hiddenCount = (totalLines - previewLimit) > 0
        ? totalLines - previewLimit
        : 0;
    final visibleLines = _showAllItems || totalLines <= previewLimit
        ? order.lines
        : order.lines.take(previewLimit).toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Dong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1565FF),
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: order.status == OrderStatusVm.paid ? null : _goEdit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Chinh sua',
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _timeFull(order.createdAt),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    order.customerName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 12),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Column(
                      children: visibleLines.map((line) {
                        return Padding(
                          key: ValueKey(
                            'line-${line.name}-${line.unitPrice}-${line.quantity}',
                          ),
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      line.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(line.lineTotal),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${line.quantity} x ${_formatCurrency(line.unitPrice)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              if (line.note != null &&
                                  line.note!.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    line.note!.trim(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF6B7280),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (hiddenCount > 0)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axisAlignment: -1,
                            child: child,
                          ),
                        );
                      },
                      child: GestureDetector(
                        key: ValueKey(_showAllItems),
                        onTap: () {
                          setState(() {
                            _showAllItems = !_showAllItems;
                          });
                        },
                        child: Text(
                          _showAllItems
                              ? 'Thu gon'
                              : 'Xem tat ca ($hiddenCount)',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFF1565FF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tong tien hang',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Text(
                        _formatCurrency(order.totalAmount),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tong cong ($totalLines)',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Text(
                        _formatCurrency(order.totalAmount),
                        style: const TextStyle(
                          fontSize: 22,
                          color: Color(0xFF1565FF),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed:
                          order.status == OrderStatusVm.paid || _markingPaid
                          ? null
                          : _confirmAndMarkPaid,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1565FF),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Nhan du tien'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _createNewOrder,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Tao don moi'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareOrderText,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Chia se'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _printOrder,
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('In'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _createNewOrder() {
    Navigator.push(context, _buildSaleRoute(const SaleScreen()));
  }

  void _shareOrderText() {
    final order = widget.order;
    final buffer = StringBuffer()
      ..writeln('--- HOA DON #${order.id} ---')
      ..writeln('Khach: ${order.customerName}')
      ..writeln('Nhan vien: ${order.sellerName}')
      ..writeln('Thoi gian: ${_timeFull(order.createdAt)}')
      ..writeln('----------------------');
    for (final line in order.lines) {
      buffer.writeln('${line.quantity} x ${line.name} = ${line.lineTotal}');
      if (line.note != null && line.note!.trim().isNotEmpty) {
        buffer.writeln('  Ghi chu: ${line.note!.trim()}');
      }
    }
    buffer.writeln('----------------------');
    buffer.writeln('Tong: ${_formatCurrency(order.totalAmount)}');
    SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }

  Future<void> _printOrder() async {
    final order = widget.order;
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'HOA DON #${order.id}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text('Khach: ${order.customerName}'),
              pw.Text('Nhan vien: ${order.sellerName}'),
              pw.Text('Thoi gian: ${_timeFull(order.createdAt)}'),
              pw.SizedBox(height: 10),
              pw.Divider(),
              ...order.lines.map(
                (line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Text('${line.quantity} x ${line.name}'),
                          ),
                          pw.Text(_formatCurrency(line.lineTotal)),
                        ],
                      ),
                      if (line.note != null && line.note!.trim().isNotEmpty)
                        pw.Text(
                          'Ghi chu: ${line.note!.trim()}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                    ],
                  ),
                ),
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Tong cong',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    _formatCurrency(order.totalAmount),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    try {
      await Printing.layoutPdf(onLayout: (_) async => doc.save());
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Khong the in hoa don: $e')));
    }
  }

  Future<void> _goEdit() async {
    final changed = await Navigator.push<bool>(
      context,
      _buildSaleRoute(SaleScreen(editingOrder: widget.order)),
    );
    if (!mounted) {
      return;
    }
    if (changed == true) {
      OrderStore.instance.notifyChanged();
      setState(() {});
    }
  }

  Future<void> _confirmAndMarkPaid() async {
    final shouldMark = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xac nhan da nhan du tien?'),
          content: const Text(
            'Don hang se duoc chuyen sang trang thai da thanh toan.',
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

    if (shouldMark != true) {
      return;
    }

    setState(() {
      _markingPaid = true;
    });
    try {
      await OrderStore.instance.markPaid(widget.order.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Da cap nhat trang thai da thanh toan.')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Khong the cap nhat: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _markingPaid = false;
        });
      }
    }
  }

  static String _timeFull(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
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

  Route<T> _buildSaleRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, animation, secondaryAnimation) {
        final disableAnimations =
            MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        if (disableAnimations) {
          return page;
        }
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: page,
        );
      },
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final disableAnimations =
            MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        if (disableAnimations) {
          return child;
        }
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        );
      },
    );
  }
}
