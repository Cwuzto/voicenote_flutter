import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
  String _ttsModeLabel = 'Dang khoi tao TTS...';
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
                        'Loa doc tien',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1565FF),
                        ),
                        child: const Text(
                          'Xong',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Tuy chinh thong bao de moi lan nhan tien them y nghia',
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
                    'Dang nghe thu...',
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
          'Chua co mau cau nao',
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
                  PopupMenuItem(value: 'edit', child: Text('Sua')),
                  PopupMenuItem(value: 'delete', child: Text('Xoa')),
                  PopupMenuItem(value: 'test', child: Text('Nghe thu')),
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
    final content = await _showEditorDialog(title: 'Them mau cau');
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
      _showMessage('Da them');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _edit(SpeakerTemplateVm item) async {
    final content = await _showEditorDialog(
      title: 'Sua mau cau',
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
      _showMessage('Da cap nhat');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _delete(SpeakerTemplateVm item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xoa mau cau'),
          content: const Text('Ban co chac muon xoa mau cau nay?'),
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
      _showMessage('Da xoa');
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
      _showMessage('Da chon mac dinh');
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
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Noi dung mau cau'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Huy'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Noi dung khong duoc de trong'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, text);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565FF),
              ),
              child: const Text('Luu'),
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
          ? 'TTS san sang (vi-VN).'
          : 'TTS san sang voi fallback locale (en-US).';

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
          _errorMessage = 'TTS error: $msg';
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
        _ttsModeLabel = 'Khong khoi tao duoc TTS tren thiet bi nay.';
      });
    }
  }

  Future<void> _testSound(String template) async {
    if (!_ttsReady) {
      _showMessage('TTS chua san sang. Kiem tra thiet bi/voice engine.');
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
      _showMessage('Dang phat thu noi dung...');
    } catch (e) {
      _showMessage('Khong the phat thu: $e');
    }
  }
}
