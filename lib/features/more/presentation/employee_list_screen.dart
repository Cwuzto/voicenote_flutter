import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/gradient_background.dart';
import '../data/employee_repository.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final EmployeeRepository _repository = EmployeeRepository();
  final List<EmployeeVm> _employees = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadEmployees());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _addEmployee,
        backgroundColor: const Color(0xFF1565FF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                title: 'Quản lý nhân viên',
                onBack: () => Navigator.pop(context),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_employees.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có nhân viên nào',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: _employees.length,
      itemBuilder: (context, index) {
        final item = _employees[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFE5EAF2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(item.name),
                  style: const TextStyle(
                    color: Color(0xFF1565FF),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (!item.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Vô hiệu hóa',
                              style: TextStyle(
                                color: Color(0xFFB91C1C),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      item.email,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (action) => _handleAction(action, item),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(item.isActive ? 'Vô hiệu hóa' : 'Kích hoạt'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                ],
                child: const Icon(Icons.more_vert_rounded),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final data = await _repository.fetchEmployees();
      if (!mounted) {
        return;
      }
      setState(() {
        _employees
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
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleAction(String action, EmployeeVm item) async {
    if (action == 'delete') {
      final ok = await _confirmDelete(item.name);
      if (!ok || !mounted) {
        return;
      }
      try {
        await _repository.deleteEmployee(item.employeeId);
        if (!mounted) {
          return;
        }
        setState(() {
          _employees.removeWhere((e) => e.employeeId == item.employeeId);
        });
        _showMessage('Đã xóa');
      } catch (e) {
        _showMessage(e.toString());
      }
      return;
    }

    if (action == 'toggle') {
      try {
        final updated = await _repository.updateEmployee(
          employee: item,
          fullName: item.name,
          isActive: !item.isActive,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          final index = _employees.indexWhere(
            (e) => e.employeeId == item.employeeId,
          );
          if (index >= 0) {
            _employees[index] = updated;
          }
        });
        _showMessage(updated.isActive ? 'Đã kích hoạt' : 'Đã vô hiệu hóa');
      } catch (e) {
        _showMessage(e.toString());
      }
      return;
    }

    await _editEmployee(item);
  }

  Future<void> _addEmployee() async {
    final payload = await _showEmployeeDialog();
    if (payload == null || !mounted) {
      return;
    }
    try {
      final created = await _repository.addEmployee(
        fullName: payload.name,
        email: payload.email,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _employees.insert(0, created);
      });
      _showMessage('Đã thêm');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _editEmployee(EmployeeVm employee) async {
    final payload = await _showEmployeeDialog(employee: employee);
    if (payload == null || !mounted) {
      return;
    }
    try {
      final updated = await _repository.updateEmployee(
        employee: employee,
        fullName: payload.name,
        isActive: payload.isActive,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final index = _employees.indexWhere(
          (e) => e.employeeId == employee.employeeId,
        );
        if (index >= 0) {
          _employees[index] = updated;
        }
      });
      _showMessage('Đã cập nhật');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<_EmployeeDialogPayload?> _showEmployeeDialog({EmployeeVm? employee}) {
    final isEdit = employee != null;
    final nameController = TextEditingController(text: employee?.name ?? '');
    final emailController = TextEditingController(text: employee?.email ?? '');
    var isActive = employee?.isActive ?? true;

    return showDialog<_EmployeeDialogPayload>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              scrollable: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              title: Text(isEdit ? 'S?a nh?n vi?n' : 'Th?m nh?n vi?n'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'H? t?n',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    enabled: !isEdit,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('K?ch ho?t'),
                        const Spacer(),
                        Switch(
                          value: isActive,
                          onChanged: (value) {
                            setDialogState(() {
                              isActive = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  if (!isEdit)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'L?u ?: Email ph?i t?n t?i s?n trong h? th?ng.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('H?y'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final email = emailController.text.trim();
                    if (name.isEmpty || email.isEmpty || !email.contains('@')) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Vui l?ng nh?p ??y ?? th?ng tin'),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(
                      dialogContext,
                      _EmployeeDialogPayload(
                        name: name,
                        email: email.toLowerCase(),
                        isActive: isActive,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565FF),
                  ),
                  child: const Text('L?u'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDelete(String name) async {
    final result = await showAppConfirmDialog(
      context: context,
      title: 'Xóa nhân viên',
      message: 'Bạn có chắc muốn xóa $name?',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    return result;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EmployeeDialogPayload {
  const _EmployeeDialogPayload({
    required this.name,
    required this.email,
    required this.isActive,
  });

  final String name;
  final String email;
  final bool isActive;
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
