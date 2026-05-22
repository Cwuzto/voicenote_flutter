import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/gradient_background.dart';
import '../data/category_repository.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final CategoryRepository _repository = CategoryRepository();
  final List<CategoryVm> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        backgroundColor: const Color(0xFF1565FF),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                title: 'Quản lý danh mục',
                onBack: () => Navigator.pop(context),
              ),
              if (_error != null) _buildError(),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _error!,
          style: const TextStyle(
            color: Color(0xFFB91C1C),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_categories.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có danh mục nào',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final item = _categories[index];
          final isProtected = item.name.trim().toLowerCase() == 'khác';
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _rename(item),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5EAF2),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.category_outlined,
                      color: Color(0xFF1565FF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (isProtected)
                          const Text(
                            'Danh mục mặc định',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ),

                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: isProtected
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFFDC2626),
                    ),
                    onPressed: isProtected ? null : () => _delete(item),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repository.fetchCategories();
      if (!mounted) return;
      setState(() {
        _categories
          ..clear()
          ..addAll(data);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _create() async {
    final controller = TextEditingController();
    final name = await _askName(
      title: 'Thêm danh mục',
      controller: controller,
      confirmLabel: 'Thêm',
    );
    if (name == null) return;
    try {
      await _repository.createCategory(name);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _rename(CategoryVm item) async {
    final controller = TextEditingController(text: item.name);
    final name = await _askName(
      title: 'Sửa danh mục',
      controller: controller,
      confirmLabel: 'Lưu',
    );
    if (name == null) return;
    try {
      await _repository.renameCategory(category: item, newName: name);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _delete(CategoryVm item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa danh mục'),
        content: Text(
          'Xóa "${item.name}"? Các món trong danh mục này sẽ chuyển sang "Khác".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repository.deleteCategory(item);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<String?> _askName({
    required String title,
    required TextEditingController controller,
    required String confirmLabel,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nhập tên danh mục'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
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
          IconButton(onPressed: onBack, icon: const Icon(Icons.close_rounded)),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
