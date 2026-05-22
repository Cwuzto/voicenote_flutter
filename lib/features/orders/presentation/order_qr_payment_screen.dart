import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/payments/viet_qr_service.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../more/data/bank_account_repository.dart';
import 'order_models.dart';
import 'order_store.dart';

class OrderQrPaymentScreen extends StatefulWidget {
  const OrderQrPaymentScreen({super.key, required this.order});

  final OrderVm order;

  @override
  State<OrderQrPaymentScreen> createState() => _OrderQrPaymentScreenState();
}

class _OrderQrPaymentScreenState extends State<OrderQrPaymentScreen> {
  final BankAccountRepository _bankRepository = BankAccountRepository();
  final VietQrService _vietQrService = VietQrService();

  bool _loading = true;
  bool _markingPaid = false;
  String? _errorMessage;
  BankAccountVm? _account;
  VietQrBuildResult? _qrData;

  bool get _isPaid => widget.order.status == OrderStatusVm.paid;

  @override
  void initState() {
    super.initState();
    _loadQr();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                title: 'Thanh toán QR',
                onBack: () => Navigator.pop(context, _isPaid),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _OrderSummaryCard(order: widget.order),
                            const SizedBox(height: 12),
                            if (_errorMessage != null)
                              _ErrorCard(
                                message: _errorMessage!,
                                onRetry: _loadQr,
                              )
                            else if (_qrData != null)
                              _QrReadyCard(
                                qrData: _qrData!,
                                isPaid: _isPaid,
                                markingPaid: _markingPaid,
                                onCopyTransferContent: _copyTransferContent,
                                onCopyAccountNumber: _copyAccountNumber,
                                onMarkPaid: _markPaid,
                              ),
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

  Future<void> _loadQr() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final accounts = await _bankRepository.fetchAccounts();
      if (accounts.isEmpty) {
        throw const VietQrException(
          'Cửa hàng chưa có tài khoản ngân hàng để tạo QR thanh toán.',
        );
      }

      final account = accounts.first;
      final qrData = await _vietQrService.buildOrderPaymentQr(
        bankName: account.bankName,
        accountNumber: account.number,
        accountName: account.holder,
        amount: widget.order.totalAmount,
        orderId: widget.order.id,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _account = account;
        _qrData = qrData;
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

  Future<void> _copyTransferContent() async {
    final qrData = _qrData;
    if (qrData == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: qrData.transferContent));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép nội dung chuyển khoản.')),
    );
  }

  Future<void> _copyAccountNumber() async {
    final account = _account;
    if (account == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: account.number));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã sao chép số tài khoản.')));
  }

  Future<void> _markPaid() async {
    if (_markingPaid || _isPaid) {
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
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật đơn sang trạng thái đã thanh toán.'),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật thanh toán: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _markingPaid = false;
        });
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order});

  final OrderVm order;

  @override
  Widget build(BuildContext context) {
    final paid = order.status == OrderStatusVm.paid;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8E5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: paid
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  paid ? 'Đã thanh toán' : 'Chờ thanh toán',
                  style: TextStyle(
                    color: paid
                        ? const Color(0xFF15803D)
                        : const Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '#${order.id.length <= 8 ? order.id : order.id.substring(0, 8)}',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            order.customerName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tổng thanh toán: ${_formatCurrency(order.totalAmount)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1565FF),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Quét mã để chuyển khoản đúng số tiền của hóa đơn này.',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
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
    return '$buffer VND';
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF5C2C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Không tạo được QR',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF7F1D1D),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1565FF),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

class _QrReadyCard extends StatelessWidget {
  const _QrReadyCard({
    required this.qrData,
    required this.isPaid,
    required this.markingPaid,
    required this.onCopyTransferContent,
    required this.onCopyAccountNumber,
    required this.onMarkPaid,
  });

  final VietQrBuildResult qrData;
  final bool isPaid;
  final bool markingPaid;
  final Future<void> Function() onCopyTransferContent;
  final Future<void> Function() onCopyAccountNumber;
  final Future<void> Function() onMarkPaid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8E5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 280,
              height: 330,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFDCE8FA)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  qrData.imageUri.toString(),
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) {
                      return child;
                    }
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text(
                        'Không tải được ảnh QR.\nHãy thử lại sau.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: 'Ngân hàng',
            value: '${qrData.bank.shortName} (${qrData.bank.bin})',
          ),
          _InfoRow(label: 'Số tài khoản', value: qrData.accountNumber),
          _InfoRow(label: 'Chủ tài khoản', value: qrData.accountName),
          _InfoRow(label: 'Số tiền', value: _formatCurrency(qrData.amount)),
          _InfoRow(label: 'Nội dung CK', value: qrData.transferContent),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onCopyAccountNumber,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy STK'),
              ),
              OutlinedButton.icon(
                onPressed: onCopyTransferContent,
                icon: const Icon(Icons.content_copy_rounded),
                label: const Text('Copy nội dung'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Sau khi khách chuyển khoản thành công, hãy kiểm tra app ngân hàng của bạn rồi bấm "Đã nhận chuyển khoản".',
              style: TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isPaid || markingPaid ? null : onMarkPaid,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1565FF),
              minimumSize: const Size.fromHeight(52),
            ),
            icon: markingPaid
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isPaid
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                  ),
            label: Text(
              isPaid ? 'Đơn đã thanh toán' : 'Đã nhận chuyển khoản',
              style: const TextStyle(fontWeight: FontWeight.w700),
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
    return '$buffer VND';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 94,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
