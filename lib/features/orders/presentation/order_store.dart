import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../../../core/supabase/store_scope_resolver.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../data/order_repository.dart';
import 'order_models.dart';

class OrderStore extends ChangeNotifier {
  OrderStore._({OrderRepository? repository}) : _repository = repository;

  static final OrderStore instance = OrderStore._();

  OrderRepository? _repository;
  final List<OrderVm> _orders = [];
  bool _seeded = false;
  String? _lastAddedOrderId;
  bool _loading = false;
  bool _pendingReload = false;
  String? _errorMessage;
  bool _loadedFromRemote = false;
  RealtimeChannel? _ordersChannel;
  Timer? _realtimeDebounce;

  List<OrderVm> get orders => _orders;
  String? get lastAddedOrderId => _lastAddedOrderId;
  bool get loading => _loading;
  String? get errorMessage => _errorMessage;
  bool get loadedFromRemote => _loadedFromRemote;

  OrderRepository get _repo => _repository ??= OrderRepository();

  void ensureSeeded(List<OrderVm> seed) {
    if (_seeded) {
      return;
    }
    _orders
      ..clear()
      ..addAll(seed);
    _seeded = true;
    notifyListeners();
  }

  Future<void> startRealtime() async {
    if (!SupabaseBootstrap.isInitialized || _ordersChannel != null) {
      return;
    }

    final client = SupabaseBootstrap.client;
    final storeId = await StoreScopeResolver.resolveStoreId(client);
    _ordersChannel = client
        .channel('realtime:orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'store_id',
            value: storeId,
          ),
          callback: (_) => _scheduleRealtimeReload(),
        )
        .subscribe();
  }

  Future<void> stopRealtime() async {
    final channel = _ordersChannel;
    if (channel == null || !SupabaseBootstrap.isInitialized) {
      return;
    }
    _realtimeDebounce?.cancel();
    _realtimeDebounce = null;
    _ordersChannel = null;
    await SupabaseBootstrap.client.removeChannel(channel);
  }

  Future<void> loadOrders({bool force = false}) async {
    if (_loading) {
      if (force) {
        _pendingReload = true;
      }
      return;
    }
    if (_loadedFromRemote && !force) {
      return;
    }
    if (!SupabaseBootstrap.isInitialized) {
      return;
    }

    final shouldShowBlockingLoading = _orders.isEmpty && !_loadedFromRemote;
    _loading = true;
    _errorMessage = null;
    if (shouldShowBlockingLoading) {
      notifyListeners();
    }

    try {
      final remoteOrders = await _repo.fetchOrders();
      _orders
        ..clear()
        ..addAll(remoteOrders);
      _loadedFromRemote = true;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
      if (_pendingReload) {
        _pendingReload = false;
        await loadOrders(force: true);
      }
    }
  }

  Future<OrderVm> createOrder({
    required String customerName,
    required String sellerName,
    required List<OrderLineVm> lines,
  }) async {
    if (!SupabaseBootstrap.isInitialized) {
      final localOrder = OrderVm(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        customerName: customerName,
        sellerName: sellerName,
        createdAt: DateTime.now(),
        status: OrderStatusVm.unpaid,
        lines: lines,
      );
      _orders.insert(0, localOrder);
      _lastAddedOrderId = localOrder.id;
      notifyListeners();
      return localOrder;
    }

    final created = await _repo.createOrder(
      customerName: customerName,
      sellerName: sellerName,
      lines: lines,
    );
    _orders.insert(0, created);
    _lastAddedOrderId = created.id;
    notifyListeners();
    return created;
  }

  Future<void> markPaid(String orderId) async {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx < 0) {
      return;
    }

    String? paidByName;
    if (SupabaseBootstrap.isInitialized) {
      paidByName = await _repo.getCurrentUserName();
      await _repo.markPaid(orderId);
    } else {
      paidByName = 'Nhân viên bán hàng';
    }

    _orders[idx].status = OrderStatusVm.paid;
    _orders[idx].paidByName = paidByName;
    notifyListeners();
  }

  Future<void> updateOrder({
    required String orderId,
    required String customerName,
    required List<OrderLineVm> lines,
  }) async {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx < 0) {
      return;
    }
    if (SupabaseBootstrap.isInitialized) {
      await _repo.updateOrder(
        orderId: orderId,
        customerName: customerName,
        lines: lines,
      );
    }

    _orders[idx].customerName = customerName;
    _orders[idx].lines = lines;
    notifyListeners();
  }

  void notifyChanged() {
    notifyListeners();
  }

  void _scheduleRealtimeReload() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 250), () {
      loadOrders(force: true);
    });
  }
}
