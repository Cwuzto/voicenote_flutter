import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/gradient_background.dart';
import '../data/speaker_template_repository.dart';

class SpeakerSettingsScreen extends StatefulWidget {
  const SpeakerSettingsScreen({super.key});

  @override
  State<SpeakerSettingsScreen> createState() => _SpeakerSettingsScreenState();
}

class _SpeakerSettingsScreenState extends State<SpeakerSettingsScreen> {
  final SpeakerTemplateRepository _repository = SpeakerTemplateRepository();
  final FlutterTts _tts = FlutterTts();
  final List<SpeakerTemplateVm> _templates = [];

  bool _loading = true;
  bool _speaking = false;
  bool _ttsReady = false;
  String _ttsModeLabel = 'Đang khởi tạo TTS...';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_initTts());
    unawaited(_loadTemplates());
  }

  @override
  void dispose() {
    unawaited(_tts.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Expanded(
                      child: Text(
                        'Loa đọc tiền',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        height: 40,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1565FF),
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Xong',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Tùy chỉnh thông báo để mỗi lần nhận tiền thêm ý nghĩa',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _ttsModeLabel,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (_speaking)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Đang nghe thử...',
                    style: TextStyle(
                      color: Color(0xFF1565FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
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
              const SizedBox(height: 4),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: const Color(0xFF1565FF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_templates.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có mẫu câu nào',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        final item = _templates[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _selectDefault(item),
                icon: Icon(
                  item.isDefault
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: item.isDefault
                      ? const Color(0xFF1565FF)
                      : const Color(0xFF94A3B8),
                ),
              ),
              Expanded(
                child: Text(
                  item.content,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    await _edit(item);
                  } else if (value == 'delete') {
                    await _delete(item);
                  } else if (value == 'test') {
                    await _testSound(item.content);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Sửa')),
                  PopupMenuItem(value: 'delete', child: Text('Xóa')),
                  PopupMenuItem(value: 'test', child: Text('Nghe thử')),
                ],
                child: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final data = await _repository.fetchTemplates();
      if (!mounted) {
        return;
      }
      setState(() {
        _templates
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

  Future<void> _add() async {
    final content = await _showEditorDialog(title: 'Thêm mẫu câu');
    if (content == null || !mounted) {
      return;
    }
    try {
      final created = await _repository.createTemplate(content: content);
      if (!mounted) {
        return;
      }
      setState(() {
        _templates.insert(0, created);
      });
      _showMessage('Đã thêm');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _edit(SpeakerTemplateVm item) async {
    final content = await _showEditorDialog(
      title: 'Sửa mẫu câu',
      initialContent: item.content,
    );
    if (content == null || !mounted) {
      return;
    }
    try {
      final updated = await _repository.updateTemplate(
        id: item.id,
        content: content,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final index = _templates.indexWhere((e) => e.id == item.id);
        if (index >= 0) {
          _templates[index] = updated;
        }
      });
      _showMessage('Đã cập nhật');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _delete(SpeakerTemplateVm item) async {
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Xóa mẫu câu',
      message: 'Bạn có chắc muốn xóa mẫu câu này?',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (ok != true || !mounted) {
      return;
    }

    try {
      await _repository.deleteTemplate(item.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _templates.removeWhere((e) => e.id == item.id);
      });
      _showMessage('Đã xóa');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _selectDefault(SpeakerTemplateVm item) async {
    if (item.isDefault) {
      return;
    }
    try {
      await _repository.selectDefault(item.id);
      if (!mounted) {
        return;
      }
      setState(() {
        for (int i = 0; i < _templates.length; i++) {
          _templates[i] = _templates[i].copyWith(
            isDefault: _templates[i].id == item.id,
          );
        }
      });
      _showMessage('Đã chọn mặc định');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<String?> _showEditorDialog({
    required String title,
    String initialContent = '',
  }) {
    final controller = TextEditingController(text: initialContent);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Nội dung mẫu câu'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Nội dung không được để trống'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, text);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565FF),
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _initTts() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      bool viReady = false;
      try {
        final result = await _tts.setLanguage('vi-VN');
        viReady = result == 1 || result == true || result == '1';
      } catch (_) {
        viReady = false;
      }

      if (!viReady) {
        await _tts.setLanguage('en-US');
      }

      _ttsReady = true;
      _ttsModeLabel = viReady
          ? 'TTS sẵn sàng (vi-VN).'
          : 'TTS sẵn sàng với locale dự phòng (en-US).';

      _tts.setStartHandler(() {
        if (!mounted) {
          return;
        }
        setState(() {
          _speaking = true;
        });
      });
      _tts.setCompletionHandler(() {
        if (!mounted) {
          return;
        }
        setState(() {
          _speaking = false;
        });
      });
      _tts.setCancelHandler(() {
        if (!mounted) {
          return;
        }
        setState(() {
          _speaking = false;
        });
      });
      _tts.setErrorHandler((msg) {
        if (!mounted) {
          return;
        }
        setState(() {
          _speaking = false;
          _errorMessage = 'TTS lỗi: $msg';
        });
      });

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _ttsReady = false;
        _ttsModeLabel = 'Không khởi tạo được TTS trên thiết bị này.';
      });
    }
  }

  Future<void> _testSound(String template) async {
    if (!_ttsReady) {
      _showMessage('TTS chưa sẵn sàng. Kiểm tra thiết bị/voice engine.');
      return;
    }

    final sample = template
        .replaceAll('{so_tien}', '125 nghin')
        .replaceAll('{So tien}', '125 nghin');

    try {
      if (_speaking) {
        await _tts.stop();
      }
      await _tts.speak(sample);
      _showMessage('Đang phát thử nội dung...');
    } catch (e) {
      _showMessage('Không thể phát thử: $e');
    }
  }
}
