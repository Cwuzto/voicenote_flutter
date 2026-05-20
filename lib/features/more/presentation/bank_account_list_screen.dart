import 'dart:async';

import 'package:flutter/material.dart';

import '../data/bank_account_repository.dart';

class BankAccountListScreen extends StatefulWidget {
  const BankAccountListScreen({super.key});

  @override
  State<BankAccountListScreen> createState() => _BankAccountListScreenState();
}

class _BankAccountListScreenState extends State<BankAccountListScreen> {
  final BankAccountRepository _repository = BankAccountRepository();

  final List<BankAccountVm> _accounts = [];
  bool _loading = true;
  String? _errorMessage;
  String? _defaultAccountId;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAccounts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addAccount,
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
              _Header(
                title: 'Tai khoan ngan hang',
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
    if (_accounts.isEmpty) {
      return const Center(
        child: Text(
          'Chua co tai khoan ngan hang',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: _accounts.length,
      itemBuilder: (context, index) {
        final item = _accounts[index];
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _editAccount(item),
          onLongPress: () => _showAccountActions(item),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.bankName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (_defaultAccountId == item.id)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Mac dinh',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.number,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.holder,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final data = await _repository.fetchAccounts();
      if (!mounted) {
        return;
      }
      setState(() {
        _accounts
          ..clear()
          ..addAll(data);
        if (_defaultAccountId == null && _accounts.isNotEmpty) {
          _defaultAccountId = _accounts.first.id;
        }
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

  Future<void> _addAccount() async {
    final payload = await _showAddEditDialog();
    if (payload == null || !mounted) {
      return;
    }

    try {
      final created = await _repository.createAccount(
        bankName: payload.bankName,
        number: payload.number,
        holder: payload.holder,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _accounts.insert(0, created);
        _defaultAccountId ??= created.id;
      });
      _showMessage('Da them');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _editAccount(BankAccountVm account) async {
    final payload = await _showAddEditDialog(account: account);
    if (payload == null || !mounted) {
      return;
    }

    try {
      final updated = await _repository.updateAccount(
        id: account.id,
        bankName: payload.bankName,
        number: payload.number,
        holder: payload.holder,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final index = _accounts.indexWhere((a) => a.id == account.id);
        if (index >= 0) {
          _accounts[index] = updated;
        }
      });
      _showMessage('Da cap nhat');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _showAccountActions(BankAccountVm account) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Sua tai khoan'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                title: const Text('Dat mac dinh'),
                onTap: () => Navigator.pop(context, 'default'),
              ),
              ListTile(
                title: const Text('Xoa tai khoan'),
                textColor: const Color(0xFFDC2626),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }
    if (action == 'edit') {
      await _editAccount(account);
      return;
    }
    if (action == 'default') {
      setState(() {
        _defaultAccountId = account.id;
      });
      return;
    }

    final ok = await _confirmDelete(account.bankName);
    if (!ok || !mounted) {
      return;
    }

    try {
      await _repository.deleteAccount(account.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _accounts.removeWhere((a) => a.id == account.id);
        if (_defaultAccountId == account.id) {
          _defaultAccountId = _accounts.isEmpty ? null : _accounts.first.id;
        }
      });
      _showMessage('Da xoa');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<bool> _confirmDelete(String bankName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xoa tai khoan'),
          content: Text('Ban co chac muon xoa "$bankName"?'),
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
    return result == true;
  }

  Future<_BankAccountFormPayload?> _showAddEditDialog({
    BankAccountVm? account,
  }) async {
    final bankController = TextEditingController(text: account?.bankName ?? '');
    final numberController = TextEditingController(text: account?.number ?? '');
    final holderController = TextEditingController(text: account?.holder ?? '');
    final isEdit = account != null;

    final payload = await showDialog<_BankAccountFormPayload>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEdit ? 'Sua tai khoan' : 'Them tai khoan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bankController,
                decoration: const InputDecoration(labelText: 'Ngan hang'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: numberController,
                decoration: const InputDecoration(labelText: 'So tai khoan'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: holderController,
                decoration: const InputDecoration(labelText: 'Chu tai khoan'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Huy'),
            ),
            FilledButton(
              onPressed: () {
                final bankName = bankController.text.trim();
                final number = numberController.text.trim();
                final holder = holderController.text.trim();
                if (bankName.isEmpty || number.isEmpty || holder.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Vui long nhap day du thong tin'),
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _BankAccountFormPayload(
                    bankName: bankName,
                    number: number,
                    holder: holder,
                  ),
                );
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

    bankController.dispose();
    numberController.dispose();
    holderController.dispose();
    return payload;
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

class _BankAccountFormPayload {
  const _BankAccountFormPayload({
    required this.bankName,
    required this.number,
    required this.holder,
  });

  final String bankName;
  final String number;
  final String holder;
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
