import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../orders/presentation/order_models.dart';
import '../../orders/presentation/order_store.dart';
import '../../products/data/product_repository.dart';
import 'sale_order_input_parser.dart';
import 'sale_state_controller.dart';
import 'sale_voice_controller.dart';

class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key, this.onOrderSaved, this.editingOrder});

  final VoidCallback? onOrderSaved;
  final OrderVm? editingOrder;

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final TextEditingController _lineController = TextEditingController();
  final FocusNode _lineFocusNode = FocusNode();
  final ProductRepository _productRepository = ProductRepository();
  final SaleOrderInputParser _orderInputParser = const SaleOrderInputParser();
  final SaleVoiceController _voiceController = SaleVoiceController();
  final SaleStateController _state = SaleStateController();

  bool _savingOrder = false;
  bool _voiceBusy = false;
  bool _voiceCancelled = false;
  bool _searchExpanded = false;
  String? _voiceHint;
  double _soundLevel = 0;
  bool get _listening => _voiceController.isListening;
  bool get _isEditMode => widget.editingOrder != null;

  @override
  void initState() {
    super.initState();
    _lineFocusNode.addListener(_onLineFocusChanged);
    _loadEditingDraftIfNeeded();
    unawaited(_loadQuickProducts());
    unawaited(_initSpeech());
  }

  @override
  void dispose() {
    unawaited(_voiceController.dispose());
    _state.dispose();
    _lineFocusNode
      ..removeListener(_onLineFocusChanged)
      ..dispose();
    _lineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _state,
      builder: (context, _) {
        final canDone = _state.hasItems && !_savingOrder;
        final total = _state.total;
        final mediaQuery = MediaQuery.of(context);
        final screenHeight = mediaQuery.size.height;
        final keyboardVisible = mediaQuery.viewInsets.bottom > 0;
        final panelHeight = keyboardVisible
            ? 180.0
            : (screenHeight < 700 ? 190.0 : 220.0);
        const quickBarFootprint = 82.0;
        final panelVisible = _state.panelMode != SaleBottomPanelMode.none;
        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEFF6FF),
                  Color(0xFFF8FAFC),
                  Color(0xFFE0ECFF),
                ],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      _buildHeader(canDone, total),
                      _buildCustomerRow(),
                      if (_voiceHint != null) _buildVoiceHint(),
                      Flexible(
                        fit: FlexFit.tight,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.04),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _state.cart.isEmpty
                              ? const SizedBox(
                                  key: ValueKey('sale-guide'),
                                  child: Center(child: _SaleGuide()),
                                )
                              : KeyedSubtree(
                                  key: const ValueKey('sale-cart'),
                                  child: _buildCart(total),
                                ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.06),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _state.panelMode == SaleBottomPanelMode.grid
                            ? _buildQuickGrid(height: panelHeight)
                            : _state.panelMode == SaleBottomPanelMode.listening
                            ? _buildListeningPanel(height: panelHeight)
                            : const SizedBox.shrink(),
                      ),
                      _buildQuickBar(),
                    ],
                  ),
                  if (panelVisible)
                    Positioned.fill(
                      bottom: panelHeight + quickBarFootprint,
                      child: IgnorePointer(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 4 * value,
                                sigmaY: 4 * value,
                              ),
                              child: Container(
                                color: const Color(
                                  0xFF0F172A,
                                ).withValues(alpha: 0.04 * value),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  if (panelVisible)
                    Positioned.fill(
                      bottom: panelHeight + quickBarFootprint,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          _state.setPanelMode(SaleBottomPanelMode.none);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool canDone, int total) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8FA)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _handleClose,
          ),
          Expanded(
            child: Text(
              _isEditMode ? 'Sua hoa don' : 'Ban hang',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          FilledButton(
            onPressed: canDone ? () => _saveOrder(total) : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1565FF),
              disabledBackgroundColor: const Color(0xFFBFC8D8),
              minimumSize: const Size(84, 36),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            ),
            child: _savingOrder
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _isEditMode ? 'Cap nhat' : 'Xong',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickCustomerName,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            _state.customer,
            style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _voiceHint!,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCart(int total) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            itemCount: _state.cart.length,
            itemBuilder: (context, index) {
              final item = _state.cart[index];
              return TweenAnimationBuilder<double>(
                key: ValueKey(
                  'line-anim-${item.productName}-${item.unitPrice}-${item.quantity}',
                ),
                tween: Tween(begin: 0, end: 1),
                duration: Duration(
                  milliseconds: 180 + (index * 45).clamp(0, 180),
                ),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 16),
                      child: child,
                    ),
                  );
                },
                child: _OrderLineCard(
                  key: ValueKey('${item.productName}-${item.unitPrice}'),
                  item: item,
                  onTap: () => _openEditLineDialog(index),
                  onPlus: () => _state.changeQty(index, 1),
                  onMinus: () => _state.changeQty(index, -1),
                  onDelete: () => _state.removeLine(index),
                  onEdit: () => _openEditLineDialog(index),
                  onNoteChanged: (value) => _state.updateNote(index, value),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Tong cong',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                _formatVnd(total),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickGrid({required double height}) {
    final items = <Widget>[
      _AddQuickItem(onTap: _showAddQuickProductDialog),
      ..._state.quickProducts.map(
        (p) => _QuickChipItem(
          product: p,
          onTap: () => _state.addQuickProductToCart(p),
          onLongPress: () => _confirmRemoveQuickProduct(p),
        ),
      ),
    ];

    return Container(
      key: const ValueKey('quick-grid'),
      height: height,
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: _state.loadingProducts
          ? const Center(child: CircularProgressIndicator())
          : GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.84,
              children: items,
            ),
    );
  }

  Widget _buildListeningPanel({required double height}) {
    final compact = height < 200;
    return Container(
      key: const ValueKey('listening-panel'),
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _listening ? Icons.mic_rounded : Icons.hearing_rounded,
                    size: compact ? 34 : 40,
                    color: const Color(0xFF1565FF),
                  ),
                  SizedBox(height: compact ? 4 : 8),
                  _ListeningWave(active: _listening, level: _soundLevel),
                  SizedBox(height: compact ? 6 : 10),
                  Text(
                    _listening ? 'Dang nghe...' : 'Dang xu ly...',
                    style: TextStyle(
                      fontSize: compact ? 14 : 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: compact ? 4 : 8),
                  Text(
                    _lineController.text.trim().isEmpty
                        ? 'Hay noi ten mon, so luong, gia. Vi du: 2 coca 10k'
                        : _lineController.text.trim(),
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  SizedBox(height: compact ? 10 : 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _voiceBusy ? null : _cancelVoice,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Huy'),
                      ),
                      FilledButton.icon(
                        onPressed: _voiceBusy ? null : _acceptVoice,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1565FF),
                        ),
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Them'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickBar() {
    final hasText = _lineController.text.trim().isNotEmpty;
    final showExpandedSearch =
        _searchExpanded || hasText || _lineFocusNode.hasFocus;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      height: 70,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8FA)),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {
              FocusScope.of(context).unfocus();
              _state.toggleGridPanel();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFE5EAF2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.grid_view_rounded),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axis: Axis.horizontal,
                    axisAlignment: -1,
                    child: child,
                  ),
                );
              },
              child: showExpandedSearch
                  ? AnimatedContainer(
                      key: const ValueKey('search-expanded'),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _lineFocusNode.hasFocus
                              ? const Color(0xFF1565FF).withValues(alpha: 0.35)
                              : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: _lineFocusNode.hasFocus
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF1565FF,
                                  ).withValues(alpha: 0.14),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: TextField(
                        controller: _lineController,
                        focusNode: _lineFocusNode,
                        onTap: () {
                          if (_state.panelMode != SaleBottomPanelMode.none) {
                            _state.setPanelMode(SaleBottomPanelMode.none);
                          }
                        },
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _addFromInput(),
                        decoration: InputDecoration(
                          hintText: 'Nhap ten hang + gia',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
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
                    )
                  : InkWell(
                      key: const ValueKey('search-collapsed'),
                      borderRadius: BorderRadius.circular(999),
                      onTap: _expandSearchInput,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Nhap ten hang + gia',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: _voiceBusy
                ? null
                : (hasText ? _addFromInput : _handleVoiceTap),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: hasText
                    ? const Color(0xFF1565FF)
                    : const Color(0xFFE5EAF2),
                shape: BoxShape.circle,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  key: ValueKey('${hasText}_${_listening}_$_voiceBusy'),
                  hasText
                      ? Icons.send_rounded
                      : (_listening
                            ? Icons.stop_circle_outlined
                            : (_voiceBusy
                                  ? Icons.hourglass_top_rounded
                                  : Icons.mic_rounded)),
                  color: hasText ? Colors.white : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleClose() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(false);
      return;
    }
    _lineController.clear();
    _state.setPanelMode(SaleBottomPanelMode.none);
  }

  void _addFromInput() {
    final parsed = _orderInputParser.parse(
      _lineController.text,
      findProductPrice: _findProductPrice,
    );
    if (parsed == null) {
      if (_lineController.text.trim().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui long nhap ten san pham.')),
        );
      }
      return;
    }
    _lineController.clear();
    FocusScope.of(context).unfocus();
    _searchExpanded = false;
    _state.setPanelMode(SaleBottomPanelMode.none);
    _state.addToCart(parsed.name, parsed.quantity, parsed.price);
  }

  void _expandSearchInput() {
    setState(() {
      _searchExpanded = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _lineFocusNode.requestFocus();
      if (_state.panelMode != SaleBottomPanelMode.none) {
        _state.setPanelMode(SaleBottomPanelMode.none);
      }
    });
  }

  void _onLineFocusChanged() {
    if (!_lineFocusNode.hasFocus && _lineController.text.trim().isEmpty) {
      setState(() {
        _searchExpanded = false;
      });
      return;
    }
    if (_lineFocusNode.hasFocus && !_searchExpanded) {
      setState(() {
        _searchExpanded = true;
      });
    }
  }

  int? _findProductPrice(String name) {
    return _state.findProductPrice(name);
  }

  Future<void> _pickCustomerName() async {
    final controller = TextEditingController(
      text: _state.customer == 'Khach hang, phong ban...'
          ? ''
          : _state.customer,
    );
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nhap ten khach hang'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Vi du: Ban so 5 / Anh Nam',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huy'),
            ),
            FilledButton(
              onPressed: () {
                _state.setCustomer(controller.text.trim());
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565FF),
              ),
              child: const Text('Luu'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddQuickProductDialog() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Them hang nhanh'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Ten san pham'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Gia ban'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huy'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final price = int.tryParse(priceController.text.trim());
                if (name.isEmpty || price == null || price < 0) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Ten/gia khong hop le')),
                  );
                  return;
                }
                _state.addQuickProductLocal(name, price);
                Navigator.pop(context);
                unawaited(_persistQuickProduct(name, price));
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565FF),
              ),
              child: const Text('Them'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveOrder(int total) async {
    final customerName = _state.resolvedCustomerName();

    final lines = _state.cart
        .map(
          (e) => OrderLineVm(
            name: e.productName,
            quantity: e.quantity,
            unitPrice: e.unitPrice,
            note: e.note.trim().isEmpty ? null : e.note.trim(),
          ),
        )
        .toList();

    setState(() {
      _savingOrder = true;
    });

    try {
      if (_isEditMode) {
        await OrderStore.instance.updateOrder(
          orderId: widget.editingOrder!.id,
          customerName: customerName,
          lines: lines,
        );
      } else {
        await OrderStore.instance.createOrder(
          customerName: customerName,
          sellerName: 'Nhan vien ban hang',
          lines: lines,
        );
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Da cap nhat don - Tong: ${_formatVnd(total)}'
                : 'Da luu don - Tong: ${_formatVnd(total)}',
          ),
        ),
      );
      if (_isEditMode) {
        Navigator.of(context).pop(true);
      } else {
        _state.clearAfterSave();
        _lineController.clear();
        widget.onOrderSaved?.call();
      }
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
          _savingOrder = false;
        });
      }
    }
  }

  static String _formatVnd(int amount) {
    final text = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final indexFromEnd = text.length - i;
      buffer.write(text[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return '$buffer';
  }

  Future<void> _loadQuickProducts() async {
    _state.setLoadingProducts(true);
    try {
      final products = await _productRepository.fetchProducts();
      if (!mounted) {
        return;
      }
      _state.setQuickProducts(
        products
            .map(
              (p) => SaleQuickProduct(
                id: p.id,
                name: p.name,
                price: p.price,
                selected: 0,
              ),
            )
            .toList(),
      );
    } catch (_) {
      // Keep empty list silently; user can still add manual quick items.
    } finally {
      if (mounted) _state.setLoadingProducts(false);
    }
  }

  Future<void> _persistQuickProduct(String name, int price) async {
    if (!SupabaseBootstrap.isInitialized) {
      return;
    }
    try {
      await _productRepository.createProduct(name: name, price: price);
      await _loadQuickProducts();
    } catch (_) {
      // Keep local item if remote persist fails.
    }
  }

  Future<void> _confirmRemoveQuickProduct(SaleQuickProduct product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xoa mon nhanh'),
          content: Text('Ban co chac chan muon xoa "${product.name}"?'),
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
    if (ok != true) return;
    _state.removeQuickProduct(product.id);
    if (!SupabaseBootstrap.isInitialized) return;
    if (!product.id.startsWith('local_')) {
      try {
        await _productRepository.deleteProduct(product.id);
      } catch (_) {
        // Keep local removal for UX even if remote delete fails.
      }
    }
  }

  Future<void> _initSpeech() async {
    final result = await _voiceController.initialize(
      onStatus: (status) {
        if (!mounted) {
          return;
        }
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _voiceBusy = false;
            if (_state.panelMode == SaleBottomPanelMode.listening) {
              _voiceHint = 'Da nhan xong, ban co the bam Them.';
            }
          });
        }
      },
      onError: (errorMessage) {
        if (!mounted) {
          return;
        }
        if (_voiceCancelled) {
          _voiceCancelled = false;
          return;
        }
        _setPanelModeSafely(SaleBottomPanelMode.none);
        setState(() {
          _voiceBusy = false;
          _voiceHint = errorMessage;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
        if (errorMessage.toLowerCase().contains('quyen micro')) {
          unawaited(_showMicPermissionHelpDialog());
        }
      },
    );

    if (!mounted) return;
    setState(() {
      _voiceHint = result.hint;
    });
  }

  Future<void> _handleVoiceTap() async {
    if (_voiceBusy) {
      return;
    }

    if (_listening) {
      await _stopListening();
      return;
    }

    if (!_voiceController.isEnabled) {
      setState(() {
        _voiceBusy = true;
      });
      await _initSpeech();
      if (!mounted) {
        return;
      }
      setState(() {
        _voiceBusy = false;
      });
    }
    if (!_voiceController.isEnabled) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Khong mo duoc microphone. Kiem tra quyen truy cap.'),
        ),
      );
      return;
    }

    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    FocusScope.of(context).unfocus();
    if (keyboardVisible) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) {
        return;
      }
    }
    _setPanelModeSafely(SaleBottomPanelMode.listening);
    setState(() {
      _voiceBusy = true;
      _voiceHint = 'Dang bat dau nghe...';
    });

    try {
      await _voiceController.startListening(
        onResult: (recognizedWords, finalResult) {
          if (!mounted) {
            return;
          }
          _lineController.text = _normalizeSpeechText(recognizedWords);
          _lineController.selection = TextSelection.fromPosition(
            TextPosition(offset: _lineController.text.length),
          );
          setState(() {
            _voiceHint = finalResult
                ? 'Da nhan xong, bam Them de them vao gio.'
                : 'Dang nghe...';
          });
        },
        onSoundLevel: (level) {
          if (!mounted) return;
          final normalized = ((level + 2) / 12).clamp(0.0, 1.0);
          setState(() {
            _soundLevel = (_soundLevel * 0.7) + (normalized * 0.3);
          });
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _voiceBusy = false;
        _soundLevel = 0;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      _setPanelModeSafely(SaleBottomPanelMode.none);
      setState(() {
        _voiceBusy = false;
        _soundLevel = 0;
        _voiceHint = 'Khong bat dau nghe duoc. Thu lai sau.';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _stopListening() async {
    setState(() {
      _voiceBusy = true;
    });
    await _voiceController.stopListening();
    if (!mounted) {
      return;
    }
    setState(() {
      _voiceBusy = false;
      if (!_listening) {
        _soundLevel = 0;
      }
    });
  }

  Future<void> _cancelVoice() async {
    _voiceCancelled = true;
    await _stopListening();
    if (!mounted) {
      return;
    }
    _lineController.clear();
    _setPanelModeSafely(SaleBottomPanelMode.none);
    setState(() {
      _voiceHint = 'Da huy nhap giong noi.';
      _soundLevel = 0;
    });
  }

  Future<void> _acceptVoice() async {
    await _stopListening();
    if (!mounted) {
      return;
    }
    _addFromInput();
  }

  String _normalizeSpeechText(String value) {
    var text = value;
    const mappings = {
      'mot': '1',
      'hai': '2',
      'ba': '3',
      'bon': '4',
      'tu': '4',
      'nam': '5',
      'sau': '6',
      'bay': '7',
      'tam': '8',
      'chin': '9',
      'muoi': '10',
    };

    mappings.forEach((word, number) {
      text = text.replaceAll(
        RegExp('\\b$word\\b', caseSensitive: false),
        number,
      );
    });

    return text;
  }

  Future<void> _openEditLineDialog(int index) async {
    if (index < 0 || index >= _state.cart.length) return;
    final item = _state.cart[index];
    final nameController = TextEditingController(text: item.productName);
    final priceController = TextEditingController(
      text: _formatVnd(item.unitPrice),
    );
    var qty = item.quantity;
    final noteController = TextEditingController(text: item.note);
    String? inlineError;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final previewPrice = _parsePriceInput(priceController.text) ?? 0;
            final lineTotal = previewPrice * qty;
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF1FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Sua mon trong gio',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Ten mon',
                          hintText: 'Nhap ten mon...',
                          prefixIcon: Icon(Icons.fastfood_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setLocalState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Don gia',
                          hintText: 'VD: 25000 hoac 25k',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDCE8FA)),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'So luong',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            _QtyAdjustButton(
                              icon: Icons.remove_rounded,
                              onTap: qty > 1
                                  ? () => setLocalState(() => qty -= 1)
                                  : null,
                            ),
                            Container(
                              width: 46,
                              alignment: Alignment.center,
                              child: Text(
                                '$qty',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ),
                            _QtyAdjustButton(
                              icon: Icons.add_rounded,
                              onTap: () => setLocalState(() => qty += 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chu',
                          hintText: 'Them ghi chu cho mon...',
                          prefixIcon: Icon(Icons.sticky_note_2_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Tam tinh: ${_formatVnd(lineTotal)}',
                          style: const TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (inlineError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          inlineError!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Huy'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                final name = nameController.text.trim();
                                final price = _parsePriceInput(
                                  priceController.text,
                                );
                                if (name.isEmpty) {
                                  setLocalState(() {
                                    inlineError =
                                        'Ten mon khong duoc de trong.';
                                  });
                                  return;
                                }
                                if (price == null || price < 0) {
                                  setLocalState(() {
                                    inlineError = 'Don gia khong hop le.';
                                  });
                                  return;
                                }
                                _state.replaceLine(
                                  index: index,
                                  productName: name,
                                  unitPrice: price,
                                  quantity: qty,
                                  note: noteController.text,
                                );
                                Navigator.pop(context);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1565FF),
                              ),
                              child: const Text('Luu thay doi'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _setPanelModeSafely(SaleBottomPanelMode mode) {
    if (_state.panelMode != mode) {
      _state.setPanelMode(mode);
    }
  }

  int? _parsePriceInput(String raw) {
    var text = raw.trim().toLowerCase();
    if (text.isEmpty) return null;
    text = text
        .replaceAll('vnd', '')
        .replaceAll('vnđ', '')
        .replaceAll('d', '')
        .replaceAll('đ', '')
        .trim();
    if (text.endsWith('k')) {
      final base = double.tryParse(text.substring(0, text.length - 1));
      if (base == null) return null;
      return (base * 1000).round();
    }
    final normalized = text.replaceAll('.', '').replaceAll(',', '');
    return int.tryParse(normalized);
  }

  Future<void> _showMicPermissionHelpDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Can cap quyen microphone'),
          content: const Text(
            'Ung dung can quyen micro de nhan dang giong noi. '
            'Ban co muon mo Cai dat ung dung ngay bay gio khong?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('De sau'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _openAppSettings();
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565FF),
              ),
              child: const Text('Mo Cai dat'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openAppSettings() async {
    final settingsUri = Uri.parse('app-settings:');
    if (await canLaunchUrl(settingsUri)) {
      await launchUrl(settingsUri);
    }
  }

  void _loadEditingDraftIfNeeded() {
    final order = widget.editingOrder;
    if (order == null) {
      return;
    }
    final lines = order.lines
        .map(
          (line) => SaleOrderLine(
            productName: line.name,
            unitPrice: line.unitPrice,
            quantity: line.quantity,
          )..note = line.note ?? '',
        )
        .toList();
    _state.loadDraftOrder(customerName: order.customerName, lines: lines);
  }
}

class _QtyAdjustButton extends StatefulWidget {
  const _QtyAdjustButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_QtyAdjustButton> createState() => _QtyAdjustButtonState();
}

class _QtyAdjustButtonState extends State<_QtyAdjustButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _pressed ? 0.92 : 1,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: disabled
                  ? const Color(0xFFF1F5F9)
                  : const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: disabled
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF1E3A8A),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddQuickItem extends StatelessWidget {
  const _AddQuickItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE5EEFF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                '+',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Them hang',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ListeningWave extends StatefulWidget {
  const _ListeningWave({required this.active, required this.level});

  final bool active;
  final double level;

  @override
  State<_ListeningWave> createState() => _ListeningWaveState();
}

class _SaleGuide extends StatelessWidget {
  const _SaleGuide();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.96, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value.clamp(0, 1),
            child: Transform.scale(scale: value, child: child),
          );
        },
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Don nay ban ban hang gi?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF212B36),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Nhap ten hang hoac doc ten hang de them nhanh vao gio.',
              style: TextStyle(color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ListeningWaveState extends State<_ListeningWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = widget.active ? _controller.value : 0.15;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(12, (i) {
              final phase = (i % 4) * 0.18;
              final animated = (0.25 + (t + phase) % 1 * 0.75).clamp(0.2, 1.0);
              final scale = widget.active
                  ? (animated * 0.45) + (widget.level.clamp(0.0, 1.0) * 0.55)
                  : 0.2;
              final h = widget.active ? 6.0 + scale * 16.0 : 6.0;
              return Container(
                width: 4,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 1.6),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF1565FF,
                  ).withValues(alpha: widget.active ? 0.85 : 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _QuickChipItem extends StatelessWidget {
  const _QuickChipItem({
    required this.product,
    required this.onTap,
    required this.onLongPress,
  });

  final SaleQuickProduct product;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(product.name);
    final bg = _backgroundColor(product.name);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  product.initial,
                  style: TextStyle(fontWeight: FontWeight.w800, color: accent),
                ),
              ),
              if (product.selected > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1565FF),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${product.selected}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: accent.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Color _accentColor(String seed) {
    const accents = <Color>[
      Color(0xFF0F766E),
      Color(0xFF1D4ED8),
      Color(0xFF7C3AED),
      Color(0xFFB45309),
      Color(0xFFBE123C),
      Color(0xFF0E7490),
      Color(0xFF4D7C0F),
    ];
    return accents[seed.hashCode.abs() % accents.length];
  }

  static Color _backgroundColor(String seed) {
    const bg = <Color>[
      Color(0xFFE6FFFA),
      Color(0xFFEFF6FF),
      Color(0xFFF5F3FF),
      Color(0xFFFFF7ED),
      Color(0xFFFFF1F2),
      Color(0xFFECFEFF),
      Color(0xFFF7FEE7),
    ];
    return bg[seed.hashCode.abs() % bg.length];
  }
}

class _OrderLineCard extends StatelessWidget {
  const _OrderLineCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onPlus,
    required this.onMinus,
    required this.onDelete,
    required this.onEdit,
    required this.onNoteChanged,
  });

  final SaleOrderLine item;
  final VoidCallback onTap;
  final VoidCallback onPlus;
  final VoidCallback onMinus;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final ValueChanged<String> onNoteChanged;

  @override
  Widget build(BuildContext context) {
    final lineTotal = item.unitPrice * item.quantity;
    final unitPriceText = _SaleScreenState._formatVnd(item.unitPrice);

    return Slidable(
      key: ValueKey('line-${item.productName}-${item.unitPrice}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.46,
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: const Color(0xFF1565FF),
            foregroundColor: Colors.white,
            icon: Icons.edit_outlined,
            label: 'Sua',
            borderRadius: BorderRadius.circular(12),
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Xoa',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF8FBFF)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDCE8FA)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF1FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.productName.trim().isEmpty
                            ? '?'
                            : item.productName
                                  .trim()
                                  .substring(0, 1)
                                  .toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF1E40AF),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$unitPriceText / mon',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF1D4ED8),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.2),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          _SaleScreenState._formatVnd(lineTotal),
                          key: ValueKey('lineTotal-$lineTotal'),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1E3A8A),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _CircleButton(icon: Icons.remove_rounded, onTap: onMinus),
                    Container(
                      width: 50,
                      height: 36,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                        color: const Color(0xFFF8FAFF),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 140),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: child,
                          );
                        },
                        child: Text(
                          '${item.quantity}',
                          key: ValueKey('qty-${item.quantity}'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ),
                    _CircleButton(icon: Icons.add_rounded, onTap: onPlus),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: onEdit,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1565FF),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const Text(
                        'Sua',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextFormField(
                    initialValue: item.note,
                    onChanged: onNoteChanged,
                    decoration: const InputDecoration(
                      hintText: 'Ghi chu cho mon...',
                      hintStyle: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatefulWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_CircleButton> createState() => _CircleButtonState();
}

class _CircleButtonState extends State<_CircleButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        scale: _pressed ? 0.9 : 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: widget.onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFE5EAF2),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon),
          ),
        ),
      ),
    );
  }
}
