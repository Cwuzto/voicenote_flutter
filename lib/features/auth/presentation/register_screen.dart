import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/widgets/gradient_background.dart';
import '../data/auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Tạo tài khoản',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text('Tên của bạn'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _fullNameController,
                      decoration: _inputDecoration('Ví dụ: Nguyễn Văn A'),
                    ),
                    const SizedBox(height: 14),
                    const Text('Email'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: _inputDecoration('Ví dụ: ban@domain.com'),
                    ),
                    const SizedBox(height: 14),
                    const Text('Mật khẩu'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: _inputDecoration('Tạo mật khẩu'),
                    ),
                    const SizedBox(height: 14),
                    const Text('Xác nhận mật khẩu'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: _inputDecoration('Nhập lại mật khẩu'),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _submitting ? null : _register,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: const Color(0xFF1565FF),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Đăng ký',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đã có tài khoản? Đăng nhập'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Vui lòng nhập đầy đủ thông tin');
      return;
    }
    if (!email.contains('@')) {
      _showMessage('Email không hợp lệ');
      return;
    }
    if (!SupabaseBootstrap.isConfigured) {
      _showMessage('Chưa cấu hình SUPABASE_URL và SUPABASE_ANON_KEY');
      return;
    }
    if (password != confirmPassword) {
      _showMessage('Mật khẩu xác nhận không khớp');
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final repository = AuthRepository();
      await repository.signUpOwner(
        fullName: fullName,
        email: email,
        password: password,
      );

      if (!mounted) {
        return;
      }
      Navigator.pushReplacementNamed(context, '/create-store');
    } on AuthException catch (e) {
      _showMessage(e.message);
    } on AuthFlowException catch (e) {
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
