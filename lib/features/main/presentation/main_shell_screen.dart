import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../dashboard/presentation/overview_screen.dart';
import '../../more/presentation/more_screen.dart';
import '../../orders/presentation/order_list_screen.dart';
import '../../products/presentation/product_list_screen.dart';
import '../../sale/presentation/sale_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;
  bool _isEmployee = false;
  bool _loadingRole = true;
  List<_MainTab> _tabs = const [];

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_selectedIndex >= _tabs.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _bodyIndexFromNavIndex(),
        children: _tabs
            .where((e) => !e.opensSale)
            .map((e) => e.screen!)
            .toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) async {
          final tab = _tabs[index];
          if (tab.opensSale) {
            await _openSaleActivity();
            return;
          }
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: _tabs.map((e) => e.destination).toList(),
      ),
    );
  }

  List<_MainTab> _buildTabs() {
    final tabs = <_MainTab>[];
    if (!_isEmployee) {
      tabs.add(
        const _MainTab(
          destination: NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Tong quan',
          ),
          screen: OverviewScreen(),
        ),
      );
      tabs.add(
        const _MainTab(
          destination: NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'San pham',
          ),
          screen: ProductListScreen(),
        ),
      );
    }
    tabs.add(
      _MainTab(
        destination: NavigationDestination(
          icon: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              size: 24,
              color: Color(0xFF1D4ED8),
            ),
          ),
          selectedIcon: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF1565FF),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x331565FF),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
          label: 'Ban hang',
        ),
        opensSale: true,
      ),
    );
    tabs.add(
      const _MainTab(
        destination: NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Hoa don',
        ),
        screen: OrderListScreen(),
      ),
    );
    tabs.add(
      const _MainTab(
        destination: NavigationDestination(
          icon: Icon(Icons.menu_outlined),
          label: 'Nhieu hon',
        ),
        screen: MoreScreen(),
      ),
    );
    return tabs;
  }

  int _bodyIndexFromNavIndex() {
    var bodyIndex = 0;
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].opensSale) {
        continue;
      }
      if (i == _selectedIndex) {
        return bodyIndex;
      }
      bodyIndex++;
    }
    return 0;
  }

  Future<void> _openSaleActivity() async {
    final saleSaved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (routeContext) => SaleScreen(
          onOrderSaved: () {
            Navigator.of(routeContext).pop(true);
          },
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if ((saleSaved ?? false) == true) {
      setState(() {
        _selectedIndex = _isEmployee ? 1 : 3;
      });
    }
  }

  Future<void> _loadRole() async {
    try {
      if (!SupabaseBootstrap.isInitialized) {
        return;
      }
      final userId = SupabaseBootstrap.client.auth.currentUser?.id;
      if (userId == null) {
        return;
      }
      final row = await SupabaseBootstrap.client
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      _isEmployee = (row?['role'] ?? '').toString().toUpperCase() == 'EMPLOYEE';
    } on PostgrestException {
      _isEmployee = false;
    } finally {
      if (mounted) {
        setState(() {
          _tabs = _buildTabs();
          _loadingRole = false;
        });
      }
    }
  }
}

class _MainTab {
  const _MainTab({
    required this.destination,
    this.screen,
    this.opensSale = false,
  });

  final NavigationDestination destination;
  final Widget? screen;
  final bool opensSale;
}
