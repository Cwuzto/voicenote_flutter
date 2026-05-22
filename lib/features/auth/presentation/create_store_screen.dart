import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/widgets/gradient_background.dart';
import '../data/store_repository.dart';

class CreateStoreScreen extends StatefulWidget {
  const CreateStoreScreen({super.key});

  @override
  State<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends State<CreateStoreScreen> {
  final _storeNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _storeNameFocus = FocusNode();
  bool _submitting = false;

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _storeNameFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final storeName = _storeNameController.text.trim();
    if (storeName.isEmpty) {
      _showMessage('Tên cửa hàng không được trống');
      _storeNameFocus.requestFocus();
      return;
    }
    if (!SupabaseBootstrap.isConfigured) {
      _showMessage('Chưa cấu hình SUPABASE_URL và SUPABASE_ANON_KEY');
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final repository = StoreRepository();
      await repository.createOwnerStore(
        name: storeName,
        address: _storeAddressController.text,
      );

      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
    } on AuthException catch (e) {
      _showMessage(e.message);
    } on PostgrestException catch (e) {
      _showMessage(e.message);
    } on StoreFlowException catch (e) {
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
                      'Tạo cửa hàng đầu tiên',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Thông tin này sẽ dùng để quản lý bán hàng',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 28),
                    const Text('Tên cửa hàng'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _storeNameController,
                      focusNode: _storeNameFocus,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration('Ví dụ: Quán Bún Bò Huế'),
                    ),
                    const SizedBox(height: 14),
                    const Text('Địa chỉ (Không bắt buộc)'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _storeAddressController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: _inputDecoration(
                        'Ví dụ: Số 1 đường Trần Văn Ơn',
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
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
                              'Tạo cửa hàng',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    if (!SupabaseBootstrap.isConfigured) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Cần cấu hình Supabase bằng --dart-define để lưu cửa hàng.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ],
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
