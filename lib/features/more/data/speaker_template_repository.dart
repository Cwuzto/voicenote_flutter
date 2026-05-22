import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

class SpeakerTemplateVm {
  const SpeakerTemplateVm({
    required this.id,
    required this.title,
    required this.content,
    required this.isDefault,
  });

  final String id;
  final String title;
  final String content;
  final bool isDefault;

  SpeakerTemplateVm copyWith({
    String? title,
    String? content,
    bool? isDefault,
  }) {
    return SpeakerTemplateVm(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class SpeakerTemplateRepository {
  SpeakerTemplateRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseBootstrap.client;

  static final List<SpeakerTemplateVm> _localTemplates = [
    const SpeakerTemplateVm(
      id: 't1',
      title: 'Mẫu 1',
      content: 'Đã nhận {so_tien} đồng',
      isDefault: true,
    ),
    const SpeakerTemplateVm(
      id: 't2',
      title: 'Mẫu 2',
      content: 'Cảm ơn quý khách, đã nhận tiền thành công',
      isDefault: false,
    ),
    const SpeakerTemplateVm(
      id: 't3',
      title: 'Mẫu 3',
      content: 'Tiền vào rồi nhà mình ơi',
      isDefault: false,
    ),
  ];

  Future<List<SpeakerTemplateVm>> fetchTemplates() async {
    if (!SupabaseBootstrap.isInitialized) {
      return List<SpeakerTemplateVm>.from(_localTemplates);
    }

    final storeId = await _resolveStoreId();
    final data = await _supabase
        .from('speaker_templates')
        .select('id, title, content, is_default')
        .eq('store_id', storeId)
        .order('is_default', ascending: false)
        .order('updated_at', ascending: false);

    return List<Map<String, dynamic>>.from(data).map((row) {
      return SpeakerTemplateVm(
        id: row['id'].toString(),
        title: (row['title'] ?? '').toString(),
        content: (row['content'] ?? '').toString(),
        isDefault: row['is_default'] == true,
      );
    }).toList();
  }

  Future<SpeakerTemplateVm> createTemplate({required String content}) async {
    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty) {
      throw const SpeakerTemplateFlowException('Nội dung không được để trống.');
    }

    if (!SupabaseBootstrap.isInitialized) {
      final vm = SpeakerTemplateVm(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: _deriveTitle(normalizedContent),
        content: normalizedContent,
        isDefault: _localTemplates.isEmpty,
      );
      _localTemplates.add(vm);
      return vm;
    }

    final storeId = await _resolveStoreId();
    final inserted = await _supabase
        .from('speaker_templates')
        .insert({
          'store_id': storeId,
          'title': _deriveTitle(normalizedContent),
          'content': normalizedContent,
          'is_default': false,
        })
        .select('id, title, content, is_default')
        .single();

    return SpeakerTemplateVm(
      id: inserted['id'].toString(),
      title: (inserted['title'] ?? '').toString(),
      content: (inserted['content'] ?? '').toString(),
      isDefault: inserted['is_default'] == true,
    );
  }

  Future<SpeakerTemplateVm> updateTemplate({
    required String id,
    required String content,
  }) async {
    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty) {
      throw const SpeakerTemplateFlowException('Nội dung không được để trống.');
    }

    if (!SupabaseBootstrap.isInitialized) {
      final index = _localTemplates.indexWhere((e) => e.id == id);
      if (index < 0) {
        throw const SpeakerTemplateFlowException('Không tìm thấy mẫu câu.');
      }
      final updated = _localTemplates[index].copyWith(
        title: _deriveTitle(normalizedContent),
        content: normalizedContent,
      );
      _localTemplates[index] = updated;
      return updated;
    }

    final updated = await _supabase
        .from('speaker_templates')
        .update({
          'title': _deriveTitle(normalizedContent),
          'content': normalizedContent,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select('id, title, content, is_default')
        .single();

    return SpeakerTemplateVm(
      id: updated['id'].toString(),
      title: (updated['title'] ?? '').toString(),
      content: (updated['content'] ?? '').toString(),
      isDefault: updated['is_default'] == true,
    );
  }

  Future<void> deleteTemplate(String id) async {
    if (!SupabaseBootstrap.isInitialized) {
      _localTemplates.removeWhere((e) => e.id == id);
      return;
    }
    await _supabase.from('speaker_templates').delete().eq('id', id);
  }

  Future<void> selectDefault(String templateId) async {
    if (!SupabaseBootstrap.isInitialized) {
      for (int i = 0; i < _localTemplates.length; i++) {
        _localTemplates[i] = _localTemplates[i].copyWith(
          isDefault: _localTemplates[i].id == templateId,
        );
      }
      return;
    }

    final storeId = await _resolveStoreId();
    await _supabase
        .from('speaker_templates')
        .update({'is_default': false})
        .eq('store_id', storeId);
    await _supabase
        .from('speaker_templates')
        .update({'is_default': true})
        .eq('id', templateId)
        .eq('store_id', storeId);
  }

  String _deriveTitle(String content) {
    final text = content.trim();
    if (text.length <= 24) {
      return text;
    }
    return '${text.substring(0, 24)}...';
  }

  Future<String> _resolveStoreId() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const SpeakerTemplateFlowException(
        'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
      );
    }

    final ownerStore = await _supabase
        .from('stores')
        .select('id')
        .eq('owner_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (ownerStore != null) {
      return ownerStore['id'].toString();
    }

    final employeeRow = await _supabase
        .from('employees')
        .select('store_id')
        .eq('user_id', userId)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();
    if (employeeRow != null) {
      return employeeRow['store_id'].toString();
    }

    throw const SpeakerTemplateFlowException(
      'Chưa tìm thấy cửa hàng cho tài khoản hiện tại.',
    );
  }
}

class SpeakerTemplateFlowException implements Exception {
  const SpeakerTemplateFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}
