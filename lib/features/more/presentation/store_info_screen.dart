import 'package:flutter/material.dart';

import '../../../core/widgets/gradient_background.dart';
import '../data/profile_store_repository.dart';

class StoreInfoScreen extends StatefulWidget {
  const StoreInfoScreen({super.key});

  @override
  State<StoreInfoScreen> createState() => _StoreInfoScreenState();
}

class _StoreInfoScreenState extends State<StoreInfoScreen> {
  final _repository = ProfileStoreRepository();
  final _storeName = TextEditingController();
  final _address = TextEditingController();

  String _ownerName = 'Chủ cửa hàng';
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  String? _successMessage;
  String _initialStoreName = '';
  String _initialAddress = '';

  bool get _hasChanges =>
      _storeName.text.trim() != _initialStoreName ||
      _address.text.trim() != _initialAddress;

  @override
  void initState() {
    super.initState();
    _loadStoreInfo();
  }

  @override
  void dispose() {
    _storeName.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                title: 'Thông tin cửa hàng',
                actionLabel: 'Lưu',
                onBack: () => Navigator.pop(context),
                onAction: !_saving && _hasChanges ? _saveStoreInfo : null,
                loading: _saving,
              ),
              if (_successMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: _InlineStatusCard(
                    message: _successMessage!,
                    backgroundColor: const Color(0xFFE8FFF1),
                    foregroundColor: const Color(0xFF166534),
                    icon: Icons.check_circle_rounded,
                  ),
                ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: _InlineStatusCard(
                    message: _errorMessage!,
                    backgroundColor: const Color(0xFFFFECEC),
                    foregroundColor: const Color(0xFFB91C1C),
                    icon: Icons.error_outline_rounded,
                  ),
                ),
              if (!_loading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _hasChanges
                          ? 'Bạn có thay đổi chưa lưu.'
                          : 'Thông tin cửa hàng đang đồng bộ.',
                      style: TextStyle(
                        color: _hasChanges
                            ? const Color(0xFFB45309)
                            : const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Tên cửa hàng'),
                            _field(
                              _storeName,
                              hint: 'Ví dụ: Quán Bún Bò Huế',
                              onChanged: (_) => _handleDraftChanged(),
                            ),
                            _label('Địa chỉ', top: 12),
                            _field(
                              _address,
                              hint: 'Chưa cập nhật',
                              onChanged: (_) => _handleDraftChanged(),
                            ),
                            _label('Chủ cửa hàng', top: 12),
                            _readonlyBox(_ownerName),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadStoreInfo() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final data = await _repository.fetchStoreInfo();
      if (!mounted) {
        return;
      }
      _storeName.text = data.storeName;
      _address.text = data.address;
      _ownerName = data.ownerName;
      _initialStoreName = data.storeName.trim();
      _initialAddress = data.address.trim();
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

  Future<void> _saveStoreInfo() async {
    if (!_hasChanges || _saving) {
      return;
    }
    final name = _storeName.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Tên cửa hàng không được để trống.';
        _successMessage = null;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await _repository.updateStoreInfo(
        storeName: _storeName.text,
        address: _address.text,
      );
      if (!mounted) {
        return;
      }
      _initialStoreName = _storeName.text.trim();
      _initialAddress = _address.text.trim();
      setState(() {
        _successMessage = 'Đã lưu thông tin cửa hàng.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thông tin cửa hàng.')),
      );
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
          _saving = false;
        });
      }
    }
  }

  void _handleDraftChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _successMessage = null;
      _errorMessage = null;
    });
  }

  static Widget _label(String text, {double top = 0}) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 4),
      child: Text(text),
    );
  }

  static Widget _field(
    TextEditingController controller, {
    String? hint,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static Widget _readonlyBox(String text) {
    return Container(
      height: 48,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFF888888))),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.actionLabel,
    required this.onBack,
    required this.onAction,
    required this.loading,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onBack;
  final VoidCallback? onAction;
  final bool loading;

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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565FF),
                minimumSize: const Size(72, 32),
              ),
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      actionLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineStatusCard extends StatelessWidget {
  const _InlineStatusCard({
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: foregroundColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
