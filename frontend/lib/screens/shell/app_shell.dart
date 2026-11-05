import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/category_provider.dart';
import '../../providers/global_refresh_controller.dart';
import '../../providers/health_provider.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _items = <_NavItem>[
    _NavItem(
      label: 'Tổng quan',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      route: '/',
      subtitle: 'Tình hình tồn kho và hoạt động gần đây',
    ),
    _NavItem(
      label: 'Sản phẩm',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      route: '/products',
      subtitle: 'Danh mục sản phẩm và thông tin tồn kho',
    ),
    _NavItem(
      label: 'Kho hàng',
      icon: Icons.swap_vert_rounded,
      selectedIcon: Icons.swap_vert_rounded,
      route: '/inventory',
      subtitle: 'Nhập xuất kho và lịch sử giao dịch',
    ),
    _NavItem(
      label: 'Danh mục',
      icon: Icons.category_outlined,
      selectedIcon: Icons.category_rounded,
      route: '/categories',
      subtitle: 'Nhóm sản phẩm đang hoạt động',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HealthProvider>().check();
      context.read<CategoryProvider>().load();
    });
  }

  int get _selectedIndex {
    final path = widget.location;
    if (path == '/') return 0;
    if (path.startsWith('/products')) return 1;
    if (path.startsWith('/inventory')) return 2;
    if (path.startsWith('/categories')) return 3;
    return 0;
  }

  String get _title {
    if (widget.location.startsWith('/products/')) return 'Chi tiết sản phẩm';
    return _items[_selectedIndex].label;
  }

  String get _subtitle {
    if (widget.location.startsWith('/products/')) {
      return 'Thông tin sản phẩm và lịch sử giao dịch kho';
    }
    return _items[_selectedIndex].subtitle;
  }

  void _navigate(int index) {
    final route = _items[index].route;
    if (widget.location != route) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= 1024) return _buildDesktop();
        if (width >= 600) return _buildTablet();
        return _buildMobile();
      },
    );
  }

  Widget _buildDesktop() {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            items: _items,
            selectedIndex: _selectedIndex,
            onSelect: _navigate,
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: _title, subtitle: _subtitle),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTablet() {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _navigate,
            labelType: NavigationRailLabelType.all,
            groupAlignment: -0.85,
            leading: const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 16),
              child: _BrandIcon(size: 40),
            ),
            destinations: [
              for (final item in _items)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: _title, subtitle: _subtitle, compact: true),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: const [
          _ConnectionChip(compact: true),
          SizedBox(width: 4),
          _RefreshButton(),
          SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        width: 286,
        child: SafeArea(
          child: Column(
            children: [
              const _Brand(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  children: [
                    const _NavSectionLabel(),
                    for (var index = 0; index < _items.length; index++)
                      _SidebarItem(
                        item: _items[index],
                        selected: index == _selectedIndex,
                        onTap: () {
                          Navigator.of(context).pop();
                          _navigate(index);
                        },
                      ),
                  ],
                ),
              ),
              const _SidebarFooter(),
            ],
          ),
        ),
      ),
      body: widget.child,
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
    required this.subtitle,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  final String subtitle;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const _Brand(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                children: [
                  const _NavSectionLabel(),
                  for (var index = 0; index < items.length; index++)
                    _SidebarItem(
                      item: items[index],
                      selected: index == selectedIndex,
                      onTap: () => onSelect(index),
                    ),
                ],
              ),
            ),
            const _SidebarFooter(),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Row(
        children: [
          const _BrandIcon(size: 44),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kho Thông Minh',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Quản lý kho hàng',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandIcon extends StatelessWidget {
  const _BrandIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(
        Icons.inventory_2_rounded,
        color: Colors.white,
        size: size * 0.52,
      ),
    );
  }
}

class _NavSectionLabel extends StatelessWidget {
  const _NavSectionLabel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Text(
        'ĐIỀU HƯỚNG',
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 21,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
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

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage_rounded, size: 14, color: AppColors.primary),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Dữ liệu trực tiếp',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              'PostgreSQL • REST API',
              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontSize: 19),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _ConnectionChip(),
          const SizedBox(width: 4),
          const _RefreshButton(),
        ],
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Làm mới dữ liệu',
      onPressed: () => context.read<GlobalRefreshController>().refresh(),
      icon: const Icon(Icons.refresh_rounded, size: 20),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Consumer<HealthProvider>(
      builder: (context, health, _) {
        final online = health.online;
        final color = health.checking
            ? AppColors.textMuted
            : online == true
            ? AppColors.success
            : online == false
            ? AppColors.danger
            : AppColors.textMuted;
        final label = health.checking
            ? 'Đang kiểm tra'
            : online == true
            ? 'API trực tuyến'
            : online == false
            ? 'Mất kết nối'
            : 'Chưa kiểm tra';
        final shortLabel = health.checking
            ? '...'
            : online == true
            ? 'API'
            : online == false
            ? 'Lỗi'
            : 'API';

        return Tooltip(
          message: 'Nhấn để kiểm tra lại kết nối API',
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: health.checking ? null : health.check,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    compact ? shortLabel : label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
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
}
