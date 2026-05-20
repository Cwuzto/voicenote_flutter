import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/widgets/gradient_background.dart';
import '../data/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFDCE8FF)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A1D4ED8),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE0ECFF), Color(0xFFF2F7FF)],
                          ),
                          border: Border.all(color: const Color(0xFFD9E6FF)),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          size: 48,
                          color: Color(0xFF1565FF),
                        ),
                      ),
                      const Text(
                        'Dang nhap',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Quan ly cua hang nhanh hon cung voicenote',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 24),
                      const Text('Email'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: _inputDecoration('Nhap email'),
                      ),
                      const SizedBox(height: 14),
                      const Text('Mat khau'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: _inputDecoration('Nhap mat khau'),
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _submitting ? null : _login,
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Dang nhap'),
                      ),
                      if (!SupabaseBootstrap.isConfigured) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Chua cau hinh Supabase. Chay app voi --dart-define de dang nhap.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Chua co tai khoan? '),
                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/register'),
                            child: const Text('Dang ky ngay'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Vui long nhap email va mat khau');
      return;
    }
    if (!email.contains('@')) {
      _showMessage('Email khong hop le');
      return;
    }
    if (!SupabaseBootstrap.isConfigured) {
      _showMessage('Chua cau hinh SUPABASE_URL va SUPABASE_ANON_KEY');
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final repository = AuthRepository();
      await repository.signIn(email: email, password: password);
      final route = await repository.resolvePostLoginRoute();

      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        route == PostLoginRoute.createStore ? '/create-store' : '/main',
        (route) => false,
      );
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
