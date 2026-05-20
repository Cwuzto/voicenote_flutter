import 'package:flutter/material.dart';

import '../../products/data/product_repository.dart';
import 'order_models.dart';
import 'order_store.dart';

class OrderEditScreen extends StatefulWidget {
  const OrderEditScreen({super.key, required this.order});

  final OrderVm order;

  @override
  State<OrderEditScreen> createState() => _OrderEditScreenState();
}

class _OrderEditScreenState extends State<OrderEditScreen> {
  late final TextEditingController _customerController;
  final ProductRepository _productRepository = ProductRepository();
  late List<OrderLineVm> _lines;
  List<ProductVm> _products = const [];
  bool _saving = false;
  bool _loadingProducts = false;

  @override
  void initState() {
    super.initState();
    _customerController = TextEditingController(
      text: widget.order.customerName,
    );
    _lines = widget.order.lines.map((e) => e.copyWith()).toList();
    _loadProducts();
  }

  @override
  void dispose() {
    _customerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _lines.fold<int>(0, (sum, item) => sum + item.lineTotal);

    return Scaffold(
      appBar: AppBar(title: const Text('Sua hoa don')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loadingProducts ? null : _openAddItemPicker,
                icon: _loadingProducts
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_shopping_cart_rounded),
                label: Text(
                  _loadingProducts ? 'Dang tai danh sach mon...' : 'Them mon',
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _customerController,
              decoration: InputDecoration(
                labelText: 'Ten khach hang',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: _lines.length,
              itemBuilder: (context, index) {
                final item = _lines[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _CircleAction(
                            icon: Icons.remove_rounded,
                            onTap: () => _changeQty(index, -1),
                          ),
                          Container(
                            width: 42,
                            height: 36,
                            alignment: Alignment.center,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFD1D5DB),
                              ),
                            ),
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _CircleAction(
                            icon: Icons.add_rounded,
                            onTap: () => _changeQty(index, 1),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _removeLine(index),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFDC2626),
                            ),
                            tooltip: 'Xoa mon',
                          ),
                          const Spacer(),
                          Text(
                            _formatCurrency(item.lineTotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: item.note ?? '',
                        onChanged: (value) {
                          _lines[index] = item.copyWith(
                            note: value.trim().isEmpty ? null : value.trim(),
                          );
                        },
                        decoration: const InputDecoration(
                          hintText: 'Ghi chu...',
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tong cong',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  _formatCurrency(total),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1565FF),
        onPressed: _saving ? null : _save,
        label: _saving ? const Text('Dang luu...') : const Text('Luu'),
        icon: _saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_outlined),
      ),
    );
  }

  void _changeQty(int index, int delta) {
    setState(() {
      final item = _lines[index];
      final next = item.quantity + delta;
      if (next <= 0) {
        _lines.removeAt(index);
      } else {
        _lines[index] = item.copyWith(quantity: next);
      }
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
    });
  }

  Future<void> _save() async {
    final customerName = _customerController.text.trim().isEmpty
        ? 'Khach le'
        : _customerController.text.trim();

    setState(() {
      _saving = true;
    });
    try {
      await OrderStore.instance.updateOrder(
        orderId: widget.order.id,
        customerName: customerName,
        lines: _lines,
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
    });
    try {
      final products = await _productRepository.fetchProducts();
      if (!mounted) {
        return;
      }
      setState(() {
        _products = products;
      });
    } catch (_) {
      // Keep editing existing lines even if product list cannot be loaded.
    } finally {
      if (mounted) {
        setState(() {
          _loadingProducts = false;
        });
      }
    }
  }

  Future<void> _openAddItemPicker() async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chua co san pham de them.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<ProductVm>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final filtered = _products
                .where(
                  (p) => p.name.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Tim san pham...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) {
                        setLocalState(() {
                          query = value.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return ListTile(
                            title: Text(item.name),
                            subtitle: Text(_formatCurrency(item.price)),
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null) {
      return;
    }
    setState(() {
      final existingIndex = _lines.indexWhere(
        (line) =>
            line.name.toLowerCase() == selected.name.toLowerCase() &&
            line.unitPrice == selected.price,
      );
      if (existingIndex >= 0) {
        final line = _lines[existingIndex];
        _lines[existingIndex] = line.copyWith(quantity: line.quantity + 1);
      } else {
        _lines.add(
          OrderLineVm(name: selected.name, quantity: 1, unitPrice: selected.price),
        );
      }
    });
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

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0xFFE5EAF2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
