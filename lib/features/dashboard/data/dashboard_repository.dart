import '../../orders/data/order_repository.dart';
import '../../orders/presentation/order_models.dart';

class DashboardOverviewVm {
  const DashboardOverviewVm({
    required this.revenueThisMonth,
    required this.ordersThisMonth,
    required this.dailyRevenuePoints,
    required this.topProducts,
  });

  final int revenueThisMonth;
  final int ordersThisMonth;
  final List<double> dailyRevenuePoints;
  final List<BestSellerVm> topProducts;
}

class SoldLineVm {
  const SoldLineVm({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.soldAt,
  });

  final String productName;
  final int quantity;
  final int unitPrice;
  final DateTime soldAt;
}

class BestSellerVm {
  const BestSellerVm({
    required this.productName,
    required this.quantity,
    required this.revenue,
  });

  final String productName;
  final int quantity;
  final int revenue;
}

class DashboardRepository {
  DashboardRepository({OrderRepository? orderRepository})
    : _orderRepository = orderRepository ?? OrderRepository();

  final OrderRepository _orderRepository;

  Future<DashboardOverviewVm> fetchOverview() async {
    final orders = await _orderRepository.fetchOrders();
    final paidOrders = orders.where((o) => o.status == OrderStatusVm.paid).toList();
    final now = DateTime.now();
    final monthly = paidOrders.where(
      (o) => o.createdAt.year == now.year && o.createdAt.month == now.month,
    );
    final revenueThisMonth = monthly.fold<int>(0, (sum, o) => sum + o.totalAmount);
    final ordersThisMonth = monthly.length;

    final dailyRevenue = List<int>.filled(7, 0);
    final start = DateTime(now.year, now.month, now.day).subtract(
      const Duration(days: 6),
    );
    for (final order in paidOrders) {
      final day = DateTime(
        order.createdAt.year,
        order.createdAt.month,
        order.createdAt.day,
      );
      if (day.isBefore(start)) {
        continue;
      }
      final idx = day.difference(start).inDays;
      if (idx >= 0 && idx < dailyRevenue.length) {
        dailyRevenue[idx] += order.totalAmount;
      }
    }

    final soldLines = _buildSoldLines(paidOrders);
    final top = _aggregateBestSellers(soldLines).take(3).toList();

    return DashboardOverviewVm(
      revenueThisMonth: revenueThisMonth,
      ordersThisMonth: ordersThisMonth,
      dailyRevenuePoints: dailyRevenue.map((e) => e.toDouble()).toList(),
      topProducts: top,
    );
  }

  Future<List<SoldLineVm>> fetchSoldLines() async {
    final orders = await _orderRepository.fetchOrders();
    final paidOrders = orders.where((o) => o.status == OrderStatusVm.paid).toList();
    return _buildSoldLines(paidOrders);
  }

  List<SoldLineVm> _buildSoldLines(List<OrderVm> orders) {
    final out = <SoldLineVm>[];
    for (final order in orders) {
      for (final line in order.lines) {
        out.add(
          SoldLineVm(
            productName: line.name,
            quantity: line.quantity,
            unitPrice: line.unitPrice,
            soldAt: order.createdAt,
          ),
        );
      }
    }
    return out;
  }

  List<BestSellerVm> _aggregateBestSellers(List<SoldLineVm> lines) {
    final map = <String, BestSellerVm>{};
    for (final line in lines) {
      final current = map[line.productName];
      if (current == null) {
        map[line.productName] = BestSellerVm(
          productName: line.productName,
          quantity: line.quantity,
          revenue: line.quantity * line.unitPrice,
        );
      } else {
        map[line.productName] = BestSellerVm(
          productName: current.productName,
          quantity: current.quantity + line.quantity,
          revenue: current.revenue + line.quantity * line.unitPrice,
        );
      }
    }

    final rows = map.values.toList();
    rows.sort((a, b) => b.quantity.compareTo(a.quantity));
    return rows;
  }
}
