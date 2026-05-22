import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  PageController? _pageController;
  late final ValueNotifier<bool> _navVisibleNotifier;
  int _selectedIndex = 0;
  bool _isEmployee = false;
  bool _loadingRole = true;
  bool _navVisible = true;
  List<_MainTab> _tabs = const [];

  PageController get _resolvedPageController =>
      _pageController ??= PageController();

  @override
  void initState() {
    super.initState();
    _navVisibleNotifier = ValueNotifier<bool>(true);
    _loadRole();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _navVisibleNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_selectedIndex >= _tabs.length) {
      _selectedIndex = 0;
    }
    final bodyTabs = _bodyTabs();

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<UserScrollNotification>(
              onNotification: _handleUserScrollNotification,
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: ClipRect(
                  child: PageView(
                    controller: _resolvedPageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: _handleBodyPageChanged,
                    children: bodyTabs
                        .map((e) => RepaintBoundary(child: e.screen!))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildNavigationBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar() {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: IgnorePointer(
        ignoring: !_navVisible,
        child: AnimatedSlide(
          duration: duration,
          curve: Curves.easeOutCubic,
          offset: _navVisible ? Offset.zero : const Offset(0, 1.2),
          child: AnimatedOpacity(
            duration: duration,
            curve: Curves.easeOutCubic,
            opacity: _navVisible ? 1 : 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFFFF), Color(0xFFF6FAFF)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD7E6FF)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.07),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: const Color(0xFF1565FF).withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _tabs
                    .asMap()
                    .entries
                    .map((entry) => _buildNavItem(entry.key, entry.value))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, _MainTab tab) {
    if (tab.opensSale) {
      return Expanded(
        flex: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _SaleNavButton(
            icon: tab.selectedIcon,
            label: tab.label,
            onTap: _openSaleActivity,
          ),
        ),
      );
    }

    return Expanded(
      child: _NavTabButton(
        icon: tab.icon,
        selectedIcon: tab.selectedIcon,
        label: tab.label,
        selected: _selectedIndex == index,
        onTap: () => _selectTab(index),
      ),
    );
  }

  List<_MainTab> _buildTabs() {
    final tabs = <_MainTab>[];
    if (!_isEmployee) {
      tabs.add(
        _MainTab(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: 'Tổng quan',
          screen: OverviewScreen(),
        ),
      );
      tabs.add(
        _MainTab(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2_rounded,
          label: 'Sản phẩm',
          screen: ProductListScreen(navVisibleListenable: _navVisibleNotifier),
        ),
      );
    }
    tabs.add(
      _MainTab(
        icon: Icons.storefront_outlined,
        selectedIcon: Icons.storefront_rounded,
        label: 'Bán hàng',
        opensSale: true,
      ),
    );
    tabs.add(
      _MainTab(
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: 'Hóa đơn',
        screen: OrderListScreen(),
      ),
    );
    tabs.add(
      _MainTab(
        icon: Icons.menu_outlined,
        selectedIcon: Icons.menu_rounded,
        label: 'Nhiều hơn',
        screen: MoreScreen(),
      ),
    );
    return tabs;
  }

  List<_MainTab> _bodyTabs() {
    return _tabs.where((e) => !e.opensSale).toList();
  }

  int _bodyIndexFromNavIndex([int? navIndex]) {
    final targetNavIndex = navIndex ?? _selectedIndex;
    var bodyIndex = 0;
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].opensSale) {
        continue;
      }
      if (i == targetNavIndex) {
        return bodyIndex;
      }
      bodyIndex++;
    }
    return 0;
  }

  int _navIndexFromBodyIndex(int bodyIndex) {
    var currentBodyIndex = 0;
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].opensSale) {
        continue;
      }
      if (currentBodyIndex == bodyIndex) {
        return i;
      }
      currentBodyIndex++;
    }
    return 0;
  }

  void _selectTab(int navIndex) {
    if (navIndex == _selectedIndex) {
      return;
    }
    _setNavVisible(true);
    final bodyIndex = _bodyIndexFromNavIndex(navIndex);
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    setState(() {
      _selectedIndex = navIndex;
    });
    final controller = _pageController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    if (disableAnimations) {
      controller.jumpToPage(bodyIndex);
      return;
    }
    controller.animateToPage(
      bodyIndex,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutQuart,
    );
  }

  void _handleBodyPageChanged(int bodyIndex) {
    final navIndex = _navIndexFromBodyIndex(bodyIndex);
    if (navIndex == _selectedIndex) {
      return;
    }
    setState(() {
      _selectedIndex = navIndex;
    });
  }

  bool _handleUserScrollNotification(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    switch (notification.direction) {
      case ScrollDirection.reverse:
        _setNavVisible(false);
        break;
      case ScrollDirection.forward:
        _setNavVisible(true);
        break;
      case ScrollDirection.idle:
        break;
    }
    return false;
  }

  void _setNavVisible(bool visible) {
    if (_navVisible == visible || !mounted) {
      return;
    }
    setState(() {
      _navVisible = visible;
    });
    _navVisibleNotifier.value = visible;
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
      _selectTab(_isEmployee ? 1 : 3);
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
        final nextTabs = _buildTabs();
        final nextSelectedIndex = _selectedIndex >= nextTabs.length ? 0 : _selectedIndex;
        setState(() {
          _tabs = nextTabs;
          _selectedIndex = nextSelectedIndex;
          _loadingRole = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final controller = _pageController;
          if (!mounted || controller == null || !controller.hasClients) {
            return;
          }
          controller.jumpToPage(_bodyIndexFromNavIndex(nextSelectedIndex));
        });
      }
    }
  }
}

class _MainTab {
  const _MainTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.screen,
    this.opensSale = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget? screen;
  final bool opensSale;
}

class _NavTabButton extends StatelessWidget {
  const _NavTabButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF1565FF);
    final inactiveColor = const Color(0xFF64748B);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFEAF2FF)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white
                    : const Color(0xFFF3F7FD),
                borderRadius: BorderRadius.circular(12),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.16),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                selected ? selectedIcon : icon,
                color: selected ? activeColor : inactiveColor,
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? const Color(0xFF0F172A) : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleNavButton extends StatelessWidget {
  const _SaleNavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD6E6FF)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: const Color(0xFFD6E6FF),
                    ),
                  ),
                  child: Icon(icon, color: const Color(0xFF1565FF), size: 21),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
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
