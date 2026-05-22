import 'package:speech_to_text/speech_to_text.dart' as stt;

class SaleVoiceInitResult {
  const SaleVoiceInitResult({
    required this.enabled,
    required this.localeId,
    required this.hint,
  });

  final bool enabled;
  final String? localeId;
  final String hint;
}

class SaleVoiceController {
  SaleVoiceController({stt.SpeechToText? speechToText})
    : _speechToText = speechToText ?? stt.SpeechToText();

  final stt.SpeechToText _speechToText;
  bool _enabled = false;
  String? _localeId;

  bool get isListening => _speechToText.isListening;
  bool get isEnabled => _enabled;
  String? get localeId => _localeId;

  Future<SaleVoiceInitResult> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    try {
      _enabled = await _speechToText.initialize(
        onStatus: onStatus,
        onError: (error) => onError(_mapSpeechError(error.errorMsg)),
      );

      if (_enabled) {
        _localeId = await _resolvePreferredLocaleId();
      }

      return SaleVoiceInitResult(
        enabled: _enabled,
        localeId: _localeId,
        hint: _enabled
            ? 'Nhấn mic để nói. ${_localeId == 'vi_VN' ? 'Đang dùng vi-VN.' : 'Đang dùng locale mặc định.'}'
            : 'Không mở được microphone. Kiểm tra quyền truy cập.',
      );
    } catch (_) {
      _enabled = false;
      return const SaleVoiceInitResult(
        enabled: false,
        localeId: null,
        hint: 'Không thể khởi tạo voice trên thiết bị này.',
      );
    }
  }

  Future<void> startListening({
    required void Function(String text, bool finalResult) onResult,
    void Function(double level)? onSoundLevel,
  }) async {
    await _speechToText.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      onSoundLevelChange: onSoundLevel,
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      ),
      localeId: _localeId,
    );
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
  }

  Future<void> dispose() async {
    await _speechToText.stop();
  }

  Future<String?> _resolvePreferredLocaleId() async {
    try {
      final locales = await _speechToText.locales();
      for (final locale in locales) {
        final id = locale.localeId;
        if (id.toLowerCase() == 'vi_vn') return locale.localeId;
      }
      if (locales.isNotEmpty) return locales.first.localeId;
    } catch (_) {
      // Ignore and let plugin use default locale.
    }
    return null;
  }

  String _mapSpeechError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('permission') || msg.contains('notallowed')) {
      return 'Microphone bị từ chối. Hãy cấp quyền micro trong cài đặt.';
    }
    if (msg.contains('network')) {
      return 'Kết nối mạng không ổn định để nhận dạng giọng nói.';
    }
    if (msg.contains('no match') || msg.contains('error_no_match')) {
      return 'Không nghe rõ nội dung. Thử nói chậm và rõ hơn.';
    }
    return 'Voice gặp lỗi: $raw';
  }
}
