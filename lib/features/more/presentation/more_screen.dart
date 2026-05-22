import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/bank_account_repository.dart';
import '../data/profile_store_repository.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/widgets/gradient_background.dart';
import 'bank_account_list_screen.dart';
import 'category_management_screen.dart';
import 'employee_list_screen.dart';
import 'profile_screen.dart';
import 'speaker_settings_screen.dart';
import 'store_info_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final _profileRepository = ProfileStoreRepository();
  final _bankRepository = BankAccountRepository();

  bool _signingOut = false;
  bool _loading = true;
  String _name = 'Tài khoản';
  String _phone = '';
  String _role = 'OWNER';
  bool _hasBankAccount = false;

  bool get _isEmployee => _role == 'EMPLOYEE';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _ProfileHero(name: _name, phone: _phone, loading: _loading),
              const SizedBox(height: 14),
              _MenuSection(
                children: [
                  _MenuRow(
                    icon: Icons.account_circle_outlined,
                    text: 'Thông tin cá nhân',
                    onTap: () => _openScreen(const ProfileScreen()),
                  ),
                  const _DividerLine(),
                  if (!_isEmployee)
                    _MenuRow(
                      icon: Icons.home_outlined,
                      text: 'Thông tin cửa hàng',
                      onTap: () => _openScreen(const StoreInfoScreen()),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_isEmployee)
                _MenuSection(
                  children: [
                    _MenuRow(
                      icon: Icons.volume_up_outlined,
                      text: 'Loa đọc tiền',
                      onTap: () => _openScreen(const SpeakerSettingsScreen()),
                    ),
                    const _DividerLine(),
                    _MenuRow(
                      icon: _hasBankAccount
                          ? Icons.account_balance_wallet_outlined
                          : Icons.qr_code_rounded,
                      text: _hasBankAccount
                          ? 'Tài khoản ngân hàng'
                          : 'Thêm QR để bật loa báo ting ting',
                      onTap: () => _openScreen(const BankAccountListScreen()),
                    ),
                    const _DividerLine(),
                    _MenuRow(
                      icon: Icons.person_add_alt_1_outlined,
                      text: 'Quản lý nhân viên',
                      onTap: () => _openScreen(const EmployeeListScreen()),
                    ),
                    const _DividerLine(),
                    _MenuRow(
                      icon: Icons.category_outlined,
                      text: 'Quản lý danh mục',
                      onTap: () =>
                          _openScreen(const CategoryManagementScreen()),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              _MenuSection(
                children: [
                  _MenuRow(
                    icon: Icons.phone_outlined,
                    text: 'Gọi tổng đài',
                    trailing: const Text(
                      '1900 090807',
                      style: TextStyle(
                        color: Color(0xFF1565FF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: _openHotline,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _signingOut ? null : _signOut,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFF5B8B8)),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFD91C1C),
                  ),
                  child: _signingOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Đăng xuất',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Phiên bản 1.1.1',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (!mounted) {
      return;
    }
    await _loadData();
  }

  Future<void> _signOut() async {
    setState(() {
      _signingOut = true;
    });
    try {
      if (SupabaseBootstrap.isInitialized) {
        await SupabaseBootstrap.client.auth.signOut();
      }
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _signingOut = false;
        });
      }
    }
  }

  Future<void> _loadData() async {
    try {
      final profile = await _profileRepository.fetchProfile();
      final banks = await _bankRepository.fetchAccounts();
      if (!mounted) {
        return;
      }
      setState(() {
        _name = profile.fullName;
        _phone = profile.phone;
        _role = profile.role;
        _hasBankAccount = banks.isNotEmpty;
      });
    } catch (_) {
      // Keep UI fallback when remote data unavailable.
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openHotline() async {
    final uri = Uri.parse('tel:1900090807');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không mở được ứng dụng gọi điện.'),
        ),
      );
    }
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDE8FA)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(children: children),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.phone,
    required this.loading,
  });

  final String name;
  final String phone;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFE3EEFF), Color(0xFFF7FAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFD5E4FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_circle_rounded,
              size: 46,
              color: Color(0xFF1565FF),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phone.isEmpty
                      ? 'Chưa cập nhật số điện thoại'
                      : phone,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.text,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF2563EB)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            if (trailing case final Widget trailingWidget) trailingWidget,
          ],
        ),
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: Color(0xFFEEF2F7)),
    );
  }
}
