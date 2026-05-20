import 'package:flutter/material.dart';

import '../data/profile_store_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repository = ProfileStoreRepository();
  final _fullName = TextEditingController();
    final _phone = TextEditingController();
  final _email = TextEditingController();
  final _oldPass = TextEditingController();
  final _newPass = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullName.dispose();
        _phone.dispose();
    _email.dispose();
    _oldPass.dispose();
    _newPass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              _TopBar(
                title: 'Thong tin ca nhan',
                actionLabel: 'Luu',
                onBack: () => Navigator.pop(context),
                onAction: _saving ? null : _saveProfile,
                loading: _saving,
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE5EAF2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.account_circle_rounded,
                                  size: 60,
                                  color: Color(0xFF1565FF),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _label('Ten cua ban'),
                            _field(_fullName),                            _label('So dien thoai', top: 12),
                            _field(_phone),
                            _label('Email', top: 12),
                            _field(_email, enabled: false),
                            const SizedBox(height: 6),
                            const Text(
                              'Doi mat khau',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            _label('Mat khau cu', top: 8),
                            _field(
                              _oldPass,
                              hint: 'Nhap mat khau cu de doi mat khau',
                              obscure: true,
                            ),
                            _label('Mat khau moi', top: 12),
                            _field(
                              _newPass,
                              hint: 'Nhap mat khau moi (it nhat 6 ky tu)',
                              obscure: true,
                            ),
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

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final data = await _repository.fetchProfile();
      if (!mounted) {
        return;
      }
      _fullName.text = data.fullName;      _phone.text = data.phone;
      _email.text = data.email;
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

  Future<void> _saveProfile() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await _repository.updateProfile(
        fullName: _fullName.text,
        phone: _phone.text,
        newPassword: _newPass.text,
        oldPassword: _oldPass.text,
      );
      if (!mounted) {
        return;
      }
      _oldPass.clear();
      _newPass.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Da luu thong tin ca nhan.')),
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

  static Widget _label(String text, {double top = 0}) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 4),
      child: Text(text),
    );
  }

  static Widget _field(
    TextEditingController controller, {
    String? hint,
    bool enabled = true,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF1F5F9),
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

