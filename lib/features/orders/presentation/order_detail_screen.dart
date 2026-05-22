import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../sale/presentation/sale_screen.dart';
import 'order_models.dart';
import 'order_qr_payment_screen.dart';
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
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Đóng',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1565FF),
                ),
              ),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Material(
                color: order.status == OrderStatusVm.paid
                    ? const Color(0xFFE2E8F0)
                    : const Color.fromARGB(255, 74, 95, 248),
                shape: const CircleBorder(),
                surfaceTintColor: Colors.transparent,
                child: InkWell(
                  onTap: order.status == OrderStatusVm.paid ? null : _goEdit,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(
                      Icons.edit_outlined,
                      color: order.status == OrderStatusVm.paid
                          ? const Color(0xFF94A3B8)
                          : const Color.fromARGB(255, 255, 255, 255),
                      size: 26,
                    ),
                  ),
                ),
              ),
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
                  const SizedBox(height: 6),
                  Text(
                    'Nhân viên tạo đơn: ${order.sellerName}',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (order.paidByName != null &&
                      order.paidByName!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Người nhận tiền: ${order.paidByName!}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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
                              ? 'Thu gọn'
                              : 'Xem tất cả ($hiddenCount)',
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
                          'Tổng tiền hàng',
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
                          'Tổng cộng ($totalLines)',
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
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openQrPayment,
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Hiển thị QR thanh toán'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _ReceivePaymentButton(
                      enabled:
                          order.status != OrderStatusVm.paid && !_markingPaid,
                      loading: _markingPaid,
                      onPressed: _confirmAndMarkPaid,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 96),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundActionButton(
              onPressed: _printOrder,
              icon: Icons.print_outlined,
              tooltip: 'In hóa đơn',
            ),
            const SizedBox(width: 16),
            _RoundActionButton(
              onPressed: _createNewOrder,
              icon: Icons.add_rounded,
              tooltip: 'Tạo đơn mới',
              filled: true,
            ),
          ],
        ),
      ),
    );
  }

  void _createNewOrder() {
    Navigator.push(context, _buildSaleRoute(const SaleScreen()));
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
              pw.Text('Khách: ${order.customerName}'),
              pw.Text('Nhân viên: ${order.sellerName}'),
              pw.Text('Thời gian: ${_timeFull(order.createdAt)}'),
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
                          'Ghi chú: ${line.note!.trim()}',
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
                    'Tổng cộng',
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
      ).showSnackBar(SnackBar(content: Text('Không thể in hóa đơn: $e')));
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

  Future<void> _openQrPayment() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderQrPaymentScreen(order: widget.order),
      ),
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
          title: const Text('Xác nhận đã nhận đủ tiền?'),
          content: const Text(
            'Đơn hàng sẽ được chuyển sang trạng thái đã thanh toán.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565FF),
              ),
              child: const Text('Xác nhận'),
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
        const SnackBar(content: Text('Đã cập nhật trạng thái đã thanh toán.')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể cập nhật: $e')));
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

class _ReceivePaymentButton extends StatelessWidget {
  const _ReceivePaymentButton({
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = enabled
        ? const Color(0xFF0F6FFF)
        : const Color(0xFFE2E8F0);
    final foregroundColor = enabled ? Colors.white : const Color(0xFF94A3B8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F6FFF).withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: enabled
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: loading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: foregroundColor,
                          ),
                        )
                      : Icon(
                          Icons.check_circle_outline_rounded,
                          color: foregroundColor,
                          size: 20,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                loading ? 'Đang cập nhật...' : 'Nhận đủ tiền',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: foregroundColor,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    this.filled = false,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = filled ? Colors.white : const Color(0xFF0F172A);
    final backgroundColor = filled ? const Color(0xFF1565FF) : Colors.white;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        surfaceTintColor: Colors.transparent,
        elevation: filled ? 2 : 0,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: filled ? null : Border.all(color: const Color(0xFFD6E0F0)),
          ),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 58,
              height: 58,
              child: Icon(icon, color: foregroundColor, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}
