import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/store_scope_resolver.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../data/product_repository.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductRepository _repository = ProductRepository();
  final List<ProductVm> _products = [];
  final TextEditingController _searchController = TextEditingController();

  bool _searchMode = false;
  bool _loading = true;
  bool _loadingRequest = false;
  bool _pendingRefresh = false;
  String? _errorMessage;
  RealtimeChannel? _productsChannel;
  Timer? _realtimeDebounce;

  @override
  void initState() {
    super.initState();
    unawaited(_initRealtime());
    unawaited(_loadProducts());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _realtimeDebounce?.cancel();
    final channel = _productsChannel;
    if (channel != null && SupabaseBootstrap.isInitialized) {
      unawaited(SupabaseBootstrap.client.removeChannel(channel));
    }
    super.dispose();
  }

  Future<void> _initRealtime() async {
    if (!SupabaseBootstrap.isInitialized) {
      return;
    }
    try {
      final client = SupabaseBootstrap.client;
      final storeId = await StoreScopeResolver.resolveStoreId(client);
      if (!mounted) {
        return;
      }
      _productsChannel = client
          .channel('realtime:products')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'products',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'store_id',
              value: storeId,
            ),
            callback: (_) => _scheduleRealtimeRefresh(),
          )
          .subscribe();
    } catch (_) {
      // Keep screen usable even when realtime subscription cannot be created.
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterProducts(_products, _searchController.text);
    final grouped = _groupedProducts(filtered);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddOrEditDialog(),
        backgroundColor: const Color(0xFF1565FF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
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
                firstChild: SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Quan ly San pham',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
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
                  ),
                ),
                secondChild: SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Tim san pham',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                              color: Color(0xFF1565FF),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : grouped.isEmpty
                    ? Center(
                        child: _ProductEmptyState(
                          onAdd: () => _openAddOrEditDialog(),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                        itemCount: grouped.length,
                        itemBuilder: (context, index) {
                          final item = grouped[index];
                          if (item is _HeaderItem) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                              child: Text(
                                item.letter,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            );
                          }
                          final product = (item as _ProductItem).product;
                          return _ProductCard(
                            product: product,
                            onTap: () => _openAddOrEditDialog(product: product),
                            onDelete: () => _confirmDelete(product),
                          );
                        },
                      ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _scheduleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_loadProducts(force: true));
    });
  }

  List<Object> _groupedProducts(List<ProductVm> products) {
    final sorted = [...products]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final items = <Object>[];
    String? current;
    for (final product in sorted) {
      final letter = product.name.trim().isEmpty
          ? '#'
          : product.name.trim().characters.first.toUpperCase();
      if (letter != current) {
        current = letter;
        items.add(_HeaderItem(letter));
      }
      items.add(_ProductItem(product));
    }
    return items;
  }

  List<ProductVm> _filterProducts(List<ProductVm> products, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return products;
    return products.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _openAddOrEditDialog({ProductVm? product}) async {
    final nameController = TextEditingController(text: product?.name ?? '');
    final priceController = TextEditingController(
      text: _formatVndRaw(product?.price ?? 0),
    );
    final isEdit = product != null;
    var updatingPriceField = false;

    void normalizePriceInput() {
      if (updatingPriceField) return;
      updatingPriceField = true;
      final raw = priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final value = int.tryParse(raw) ?? 0;
      final formatted = _formatVndRaw(value);
      priceController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      updatingPriceField = false;
    }

    priceController.addListener(normalizePriceInput);

    int parsePrice() {
      final raw = priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(raw) ?? 0;
    }

    void stepPrice(int delta) {
      final next = (parsePrice() + delta).clamp(0, 999999999);
      final text = _formatVndRaw(next);
      priceController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Sua san pham' : 'Them hang hoa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ten hang', style: TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Nhap ten hang'),
              ),
              const SizedBox(height: 12),
              const Text('Gia ban', style: TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 6),
              Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => stepPrice(-1000),
                      child: const Text('-'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(hintText: '0'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => stepPrice(1000),
                      child: const Text('+'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huy'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final price = parsePrice();

                if (name.isEmpty || price < 0) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui long nhap ten va gia hop le'),
                    ),
                  );
                  return;
                }

                final duplicated = _products.any((p) {
                  if (isEdit && p.id == product.id) return false;
                  return p.name.trim().toLowerCase() == name.toLowerCase();
                });
                if (duplicated) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Ten san pham nay da ton tai')),
                  );
                  return;
                }

                try {
                  if (isEdit) {
                    await _repository.updateProduct(
                      id: product.id,
                      name: name,
                      price: price,
                    );
                  } else {
                    await _repository.createProduct(name: name, price: price);
                  }

                  await _loadProducts(force: true);

                  if (!mounted) {
                    return;
                  }
                  Navigator.of(this.context).pop();
                } catch (e) {
                  if (!mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(
                    this.context,
                  ).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565FF),
              ),
              child: Text(isEdit ? 'Luu' : 'Them'),
            ),
          ],
        );
      },
    );
    priceController.removeListener(normalizePriceInput);
  }

  Future<void> _confirmDelete(ProductVm product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xoa san pham'),
          content: Text('Ban co chac muon xoa "${product.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              child: const Text('Xoa'),
            ),
          ],
        );
      },
    );

    if (ok == true) {
      try {
        await _repository.deleteProduct(product.id);
        await _loadProducts(force: true);
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

  Future<void> _loadProducts({bool force = false}) async {
    if (!mounted) {
      return;
    }
    if (_loadingRequest) {
      if (force) {
        _pendingRefresh = true;
      }
      return;
    }

    final shouldShowBlockingLoading = _products.isEmpty;
    _loadingRequest = true;
    setState(() {
      _loading = shouldShowBlockingLoading;
      _errorMessage = null;
    });

    try {
      final data = await _repository.fetchProducts();
      if (!mounted) {
        return;
      }
      setState(() {
        _products
          ..clear()
          ..addAll(data);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      _loadingRequest = false;
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(_loadProducts(force: true));
      }
    }
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onDelete,
  });

  final ProductVm product;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE8FA)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatAmount(product.price),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF1565FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatAmount(int amount) => _formatVndRaw(amount);
}

class _ProductEmptyState extends StatelessWidget {
  const _ProductEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Color(0xFF1565FF),
          ),
          const SizedBox(height: 8),
          const Text(
            'Chua co san pham nao',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Them san pham'),
          ),
        ],
      ),
    );
  }
}

class _HeaderItem {
  const _HeaderItem(this.letter);

  final String letter;
}

class _ProductItem {
  const _ProductItem(this.product);

  final ProductVm product;
}

String _formatVndRaw(int amount) {
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
