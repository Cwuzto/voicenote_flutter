import 'dart:collection';

import 'package:flutter/foundation.dart';

enum SaleBottomPanelMode { none, grid, listening }

class SaleQuickProduct {
  SaleQuickProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.selected,
  });

  final String id;
  final String name;
  final int price;
  int selected;

  String get initial {
    final tokens = name.trim().split(RegExp(r'\s+'));
    if (tokens.isEmpty) return '?';
    if (tokens.length == 1) return tokens.first.substring(0, 1).toUpperCase();
    return (tokens.first.substring(0, 1) + tokens.last.substring(0, 1))
        .toUpperCase();
  }
}

class SaleOrderLine {
  SaleOrderLine({
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  String productName;
  int unitPrice;
  int quantity;
  String note = '';
}

class SaleStateController extends ChangeNotifier {
  String _customer = 'Khach hang, phong ban...';
  bool _loadingProducts = false;
  SaleBottomPanelMode _panelMode = SaleBottomPanelMode.none;

  final List<SaleQuickProduct> _quickProducts = [];
  final List<SaleOrderLine> _cart = [];

  String get customer => _customer;
  bool get loadingProducts => _loadingProducts;
  SaleBottomPanelMode get panelMode => _panelMode;
  UnmodifiableListView<SaleQuickProduct> get quickProducts =>
      UnmodifiableListView(_quickProducts);
  UnmodifiableListView<SaleOrderLine> get cart => UnmodifiableListView(_cart);
  bool get hasItems => _cart.isNotEmpty;
  int get total =>
      _cart.fold<int>(0, (sum, item) => sum + item.unitPrice * item.quantity);

  void setLoadingProducts(bool value) {
    if (_loadingProducts == value) return;
    _loadingProducts = value;
    notifyListeners();
  }

  void setCustomer(String value) {
    _customer = value.trim().isEmpty ? 'Khach hang, phong ban...' : value.trim();
    notifyListeners();
  }

  void setPanelMode(SaleBottomPanelMode mode) {
    if (_panelMode == mode) return;
    _panelMode = mode;
    notifyListeners();
  }

  void toggleGridPanel() {
    _panelMode = _panelMode == SaleBottomPanelMode.grid
        ? SaleBottomPanelMode.none
        : SaleBottomPanelMode.grid;
    notifyListeners();
  }

  void setQuickProducts(List<SaleQuickProduct> products) {
    _quickProducts
      ..clear()
      ..addAll(products);
    _syncQuickSelectionsFromCart();
    notifyListeners();
  }

  void loadDraftOrder({
    required String customerName,
    required List<SaleOrderLine> lines,
  }) {
    _customer = customerName.trim().isEmpty ? 'Khach le' : customerName.trim();
    _cart
      ..clear()
      ..addAll(lines);
    _syncQuickSelectionsFromCart();
    notifyListeners();
  }

  void addQuickProductLocal(String name, int price) {
    _quickProducts.insert(
      0,
      SaleQuickProduct(
        id: 'local_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        price: price,
        selected: 0,
      ),
    );
    notifyListeners();
  }

  void removeQuickProduct(String productId) {
    final idx = _quickProducts.indexWhere((p) => p.id == productId);
    if (idx < 0) return;
    _quickProducts.removeAt(idx);
    notifyListeners();
  }

  void addToCart(String name, int qty, int price) {
    final index = _cart.indexWhere(
      (item) =>
          item.productName.toLowerCase() == name.toLowerCase() &&
          item.unitPrice == price,
    );
    if (index >= 0) {
      _cart[index].quantity += qty;
      final quick = _findQuickProduct(name, price);
      if (quick != null) quick.selected = _cart[index].quantity;
    } else {
      _cart.add(SaleOrderLine(productName: name, unitPrice: price, quantity: qty));
      final quick = _findQuickProduct(name, price);
      if (quick != null) quick.selected = qty;
    }
    notifyListeners();
  }

  void addQuickProductToCart(SaleQuickProduct product) {
    addToCart(product.name, 1, product.price);
  }

  void updateNote(int index, String note) {
    if (index < 0 || index >= _cart.length) return;
    _cart[index].note = note;
    notifyListeners();
  }

  void changeQty(int index, int delta) {
    if (index < 0 || index >= _cart.length) return;
    final item = _cart[index];
    item.quantity += delta;
    if (item.quantity <= 0) {
      _removeProductSelection(item);
      _cart.removeAt(index);
      notifyListeners();
      return;
    }
    final quick = _findQuickProduct(item.productName, item.unitPrice);
    if (quick != null) quick.selected = item.quantity;
    notifyListeners();
  }

  void removeLine(int index) {
    if (index < 0 || index >= _cart.length) return;
    final item = _cart.removeAt(index);
    _removeProductSelection(item);
    notifyListeners();
  }

  void setLineQuantity(int index, int quantity) {
    if (index < 0 || index >= _cart.length) return;
    final item = _cart[index];
    if (quantity <= 0) {
      _removeProductSelection(item);
      _cart.removeAt(index);
      notifyListeners();
      return;
    }
    item.quantity = quantity;
    final quick = _findQuickProduct(item.productName, item.unitPrice);
    if (quick != null) quick.selected = quantity;
    notifyListeners();
  }

  void replaceLine({
    required int index,
    required String productName,
    required int unitPrice,
    required int quantity,
    required String note,
  }) {
    if (index < 0 || index >= _cart.length) return;
    final normalizedName = productName.trim();
    if (normalizedName.isEmpty || quantity <= 0 || unitPrice < 0) return;

    final old = _cart[index];
    final oldQuick = _findQuickProduct(old.productName, old.unitPrice);
    if (oldQuick != null) {
      oldQuick.selected = (oldQuick.selected - old.quantity).clamp(0, 1 << 20);
    }

    int mergeTarget = -1;
    for (int i = 0; i < _cart.length; i++) {
      if (i == index) continue;
      final item = _cart[i];
      if (item.productName.toLowerCase() == normalizedName.toLowerCase() &&
          item.unitPrice == unitPrice) {
        mergeTarget = i;
        break;
      }
    }

    if (mergeTarget >= 0) {
      final target = _cart[mergeTarget];
      target.quantity += quantity;
      if (note.trim().isNotEmpty) {
        target.note = note.trim();
      }
      _cart.removeAt(index);
      final quick = _findQuickProduct(normalizedName, unitPrice);
      if (quick != null) {
        quick.selected = target.quantity;
      }
      notifyListeners();
      return;
    }

    old.productName = normalizedName;
    old.unitPrice = unitPrice;
    old.quantity = quantity;
    old.note = note.trim();

    final quick = _findQuickProduct(normalizedName, unitPrice);
    if (quick != null) {
      quick.selected = quantity;
    }
    notifyListeners();
  }

  int? findProductPrice(String name) {
    for (final p in _quickProducts) {
      if (p.name.toLowerCase() == name.toLowerCase()) return p.price;
    }
    return null;
  }

  void clearAfterSave() {
    for (final p in _quickProducts) {
      p.selected = 0;
    }
    _cart.clear();
    _panelMode = SaleBottomPanelMode.none;
    notifyListeners();
  }

  String resolvedCustomerName() {
    if (_customer == 'Khach hang, phong ban...' || _customer.trim().isEmpty) {
      return 'Khach le';
    }
    return _customer.trim();
  }

  SaleQuickProduct? _findQuickProduct(String name, int price) {
    for (final p in _quickProducts) {
      if (p.name.toLowerCase() == name.toLowerCase() && p.price == price) {
        return p;
      }
    }
    return null;
  }

  void _removeProductSelection(SaleOrderLine item) {
    final quick = _findQuickProduct(item.productName, item.unitPrice);
    if (quick != null) quick.selected = 0;
  }

  void _syncQuickSelectionsFromCart() {
    for (final p in _quickProducts) {
      p.selected = 0;
    }
    for (final item in _cart) {
      final quick = _findQuickProduct(item.productName, item.unitPrice);
      if (quick != null) {
        quick.selected = item.quantity;
      }
    }
  }
}
