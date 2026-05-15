import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/chat_service.dart';

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

const Color _primaryColor = Color(0xFF2563EB);
const Color _accentColor = Color(0xFF10B981);
const Color _surfaceColor = Color(0xFFF8FAFC);
const Color _cardColor = Color(0xFFFFFFFF);
const Color _textPrimary = Color(0xFF1E293B);

void _micLog(String message) {
  debugPrint('[MIC] $message');
}

class ChatScreen extends StatefulWidget {
  final String? roomName;

  const ChatScreen({super.key, this.roomName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late stt.SpeechToText _speechToText;
  late AudioPlayer _audioPlayer;
  
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  
  bool _isListening = false;
  bool _isLoading = false;
  bool _isPlaying = false;
  /// Mic tự bật lại sau mỗi lượt (trừ khi người dùng bấm Dừng).
  bool _userPausedContinuousMic = false;
  /// Tránh gọi listen() chồng lấn (double-tap / resume đồng thời).
  bool _micSessionActive = false;
  /// Đã chạy initialize ít nhất một lần (gợi ý giao diện / hỗ trợ truy cập).
  bool _speechInitAttempted = false;
  /// true chỉ khi initialize thành công và engine báo isAvailable.
  bool _speechEngineReady = false;
  /// Đã hiện hướng dẫn dài lần đầu khi lỗi recognizerNotAvailable.
  bool _printedRecognizerHelp = false;
  String? _lastAIResponse;

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _audioPlayer = AudioPlayer();
    _prepareChatMedia();
    
    // Add welcome message
    _messages.add(
      ChatMessage(
        role: 'assistant',
        content: 'Xin chào! Tôi là AI Assistant. Bạn có thể nói hoặc nhập câu hỏi để được hỗ trợ.',
        isError: false,
      ),
    );
  }

  @override
  void dispose() {
    _micLog('dispose — tắt STT');
    try {
      _speechToText.stop();
    } catch (_) {}
    _audioPlayer.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// Android: audio focus + loa ngoài; web/iOS giữ mặc định.
  Future<void> _configureAudioForAndroid() async {
    if (!_isAndroid) return;
    try {
      await _audioPlayer.setAudioContext(
        const AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Audio context Android: $e');
    }
  }

  Future<void> _prepareChatMedia() async {
    await _configureAudioForAndroid();
    await _initializeSpeech();
    if (mounted &&
        _speechEngineReady &&
        !_userPausedContinuousMic) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resumeContinuousMicAfterIdle('mở_màn_chat');
      });
    }
  }

  void _resumeContinuousMicAfterIdle(String reason) {
    if (!_speechEngineReady) {
      _micLog('Không resume ($reason): không có engine nhận dạng giọng trên máy');
      return;
    }
    Future<void>(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted || _userPausedContinuousMic) {
        _micLog('Không resume ($reason): userPaused=$_userPausedContinuousMic');
        return;
      }
      await _startListening();
    });
  }

  void _announceForAccessibility(String message) {
    final dir = Directionality.maybeOf(context) ?? TextDirection.ltr;
    // ignore: deprecated_member_use
    SemanticsService.announce(message, dir);
    _micLog('A11y announce: $message');
  }

  void _showSpeechUnavailableHelp() {
    const full =
        'Thiết bị chưa có dịch vụ nhận dạng giọng của Google. '
        'Hãy cài hoặc cập nhật ứng dụng Google từ CH Play, mở app Google một lần. '
        'Vào Cài đặt hệ thống, tìm Ngôn ngữ hoặc Ý đầu vào bằng giọng nói, chọn dịch vụ Google.';

    const short =
        'Nhận dạng giọng vẫn chưa sẵn sàng. Kiểm tra ứng dụng Google và cài đặt giọng nói của Google.';

    if (!_printedRecognizerHelp) {
      _printedRecognizerHelp = true;
      _showSnackBar(full, duration: const Duration(seconds: 20));
      _announceForAccessibility(full);
    } else {
      _showSnackBar(short, duration: const Duration(seconds: 10));
      _announceForAccessibility(short);
    }
  }

  Future<bool> _initializeSpeech() async {
    try {
      final ok = await _speechToText.initialize(
        onError: (error) {
          _micLog('STT lỗi: $error');
          if (mounted) {
            _showSnackBar('Lỗi nhận dạng giọng: $error');
          }
        },
        onStatus: (status) {
          switch (status) {
            case 'listening':
              _micLog('STT đang CHẠY — đang nghe microphone');
              if (mounted) setState(() => _isListening = true);
              break;
            case 'notListening':
              _micLog('STT dừng — notListening');
              if (mounted) setState(() => _isListening = false);
              break;
            default:
              _micLog('STT status=$status');
          }
        },
      );
      if (!mounted) return false;
      final ready = ok && _speechToText.isAvailable;
      _speechEngineReady = ready;
      if (!ready) {
        _micLog(
          'STT không khả dụng (initialize=$ok, isAvailable=${_speechToText.isAvailable})',
        );
      } else {
        _micLog('STT sẵn sàng — mic có thể luôn bật cho người dùng');
      }
      return ready;
    } on PlatformException catch (e) {
      _speechEngineReady = false;
      _micLog(
        'initialize PlatformException: code=${e.code} message=${e.message}',
      );
      if (e.code == 'recognizerNotAvailable') {
        if (mounted) _showSpeechUnavailableHelp();
      } else if (mounted) {
        _showSnackBar(
          'Không khởi tạo được nhận dạng giọng: ${e.message}',
        );
      }
      return false;
    } catch (e, st) {
      _speechEngineReady = false;
      _micLog('initialize lỗi: $e\n$st');
      if (mounted) {
        _showSnackBar('Lỗi khởi tạo mic: $e');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _speechInitAttempted = true);
      }
    }
  }

  Future<bool> _ensureAndroidMicPermission() async {
    if (!_isAndroid) return true;
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    if (status.isGranted) return true;
    if (mounted) {
      final msg = status.isPermanentlyDenied
          ? 'Micro bị từ chối. Vào Cài đặt → Ứng dụng → AI SP → Quyền → Bật Micro.'
          : 'Cần quyền micro để nói.';
      _showSnackBar(msg);
    }
    return false;
  }

  /// Ưu tiên tiếng Việt; nếu máy không có gói vi_VN thì fallback locale hệ thống (bàn phím vẫn
  /// nhận diện được vì IME dùng pipeline khác).
  Future<String?> _preferredSpeechLocaleId() async {
    try {
      final locales = await _speechToText.locales();
      final ids = locales.map((l) => l.localeId).toList();
      _micLog(
        'locales (${ids.length}): ${ids.take(15).join(", ")}${ids.length > 15 ? "…" : ""}',
      );

      const preferred = ['vi_VN', 'vi-VN', 'vi'];
      for (final p in preferred) {
        if (ids.contains(p)) return p;
      }
      for (final l in locales) {
        if (l.localeId.toLowerCase().startsWith('vi')) {
          return l.localeId;
        }
      }
      if (locales.isNotEmpty) {
        final fallback = locales.first.localeId;
        _micLog('Không thấy tiếng Việt trong danh sách STT — dùng $fallback');
        return fallback;
      }
    } catch (e) {
      _micLog('locales() lỗi: $e');
    }
    return null;
  }

  Future<void> _stopMicEngineOnly() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
      _micLog('Đã gọi speech.stop() (tạm tắt, không đổi chế độ người dùng)');
    }
    if (mounted && _isListening) {
      setState(() => _isListening = false);
    }
  }

  Future<void> _userStopContinuousMic() async {
    _userPausedContinuousMic = true;
    _micLog('Người dùng TẮT mic liên tục — không tự nghe lại cho đến khi bấm icon mic');
    await _stopMicEngineOnly();
  }

  Future<void> _startListening({bool triggeredByMicButton = false}) async {
    if (triggeredByMicButton) {
      _userPausedContinuousMic = false;
      _micLog('Bật lại mic (người dùng bấm icon mic)');
    }

    if (_isLoading || _isPlaying) {
      _micLog(
        'startListening bỏ qua: loading=$_isLoading playing=$_isPlaying',
      );
      return;
    }

    if (_micSessionActive) {
      _micLog('startListening bỏ qua: đang có phiên listen đang chạy');
      return;
    }

    // Hết kẹt: UI đỏ nhưng engine không listen (rất hay gặp sau lỗi/race).
    if (_isListening && !_speechToText.isListening) {
      _micLog('Phục hồi: UI báo đang nghe nhưng engine không active');
      if (mounted) setState(() => _isListening = false);
    }

    if (_speechToText.isListening) {
      _micLog('Engine đã đang listen — không gọi listen() lần nữa');
      return;
    }

    if (!await _ensureAndroidMicPermission()) return;

    if (!_speechToText.isAvailable) {
      await _initializeSpeech();
    }
    if (!_speechToText.isAvailable) {
      if (mounted) {
        _showSnackBar(
          'Nhận dạng giọng không khả dụng. Cài Google / dịch vụ Google Play, hoặc bật "Nhận dạng giọng nói của Google" trong Cài đặt.',
        );
      }
      return;
    }

    final localeId = await _preferredSpeechLocaleId();
    _micLog(
      'Gọi listen() localeId=${localeId ?? "mặc định hệ thống"} — chờ status=listening',
    );

    _micSessionActive = true;
    try {
      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            _messageController.text = result.recognizedWords;
          });

          if (result.finalResult) {
            _micLog('Có kết quả cuối (${result.recognizedWords.length} ký tự)');
            if (result.recognizedWords.isNotEmpty) {
              _sendMessage(result.recognizedWords);
            } else {
              _micLog('Kết quả rỗng — không gửi');
              if (!_userPausedContinuousMic && mounted) {
                _resumeContinuousMicAfterIdle('final_rỗng');
              }
            }
          }
        },
        localeId: localeId,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 60),
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (e) {
      _micLog('Lỗi listen: $e');
      if (mounted) {
        setState(() => _isListening = false);
        _showSnackBar('Không bắt đầu được micro: $e');
      }
    } finally {
      _micSessionActive = false;
      if (mounted &&
          _speechEngineReady &&
          !_speechToText.isListening &&
          !_userPausedContinuousMic &&
          !_isLoading &&
          !_isPlaying) {
        _resumeContinuousMicAfterIdle('sau_kết_thúc_phiên_listen');
      }
    }
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _messageController.clear();
      _isLoading = true;
    });
    _micLog('Gửi tin nhắn — loading=true trước khi tắt mic (tránh resume sớm)');

    await _stopMicEngineOnly();
    _micLog('Mic đã tắt — chờ AI + TTS');

    try {
      final response = await ChatService.sendMessage(text);

      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: response));
        _isLoading = false;
      });

      _lastAIResponse = response;
      await _playTTS(response);
    } finally {
      if (mounted && _speechEngineReady && !_userPausedContinuousMic) {
        _micLog('Kết thúc vòng hỏi–đáp — sẽ bật lại mic liên tục');
        _resumeContinuousMicAfterIdle('sau_TTS');
      }
    }
  }

  Future<void> _playTTS(String text) async {
    await _stopMicEngineOnly();

    try {
      setState(() => _isPlaying = true);
      _micLog('TTS bắt đầu (mic tắt để tránh thu tiếng loa)');

      final sentences = ChatService.splitTextForTTS(text);
      final n = sentences.length;
      _micLog('TTS: $n đoạn (tối đa ${ChatService.ttsMaxChunkChars} ký tự/đoạn)');

      for (var i = 0; i < n; i++) {
        final sentence = sentences[i];
        final audioUrl = ChatService.getTTSUrlForText(sentence);
        _micLog(
          'TTS đoạn ${i + 1}/$n (${sentence.length} ký tự): ${sentence.length > 80 ? '${sentence.substring(0, 80)}…' : sentence}',
        );

        final completer = Completer<void>();
        late final StreamSubscription<void> sub;
        sub = _audioPlayer.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });

        try {
          await _audioPlayer.stop();
          await _audioPlayer.play(UrlSource(audioUrl));
          final cap = Duration(
            seconds: (4 + sentence.length / 14).ceil().clamp(6, 90),
          );
          await completer.future.timeout(cap);
        } on TimeoutException {
          _micLog('TTS đoạn ${i + 1}/$n — hết thời gian chờ, chuyển đoạn sau');
        } catch (e) {
          _micLog('TTS đoạn ${i + 1}/$n lỗi: $e');
          if (mounted) {
            _showSnackBar('Lỗi phát đoạn ${i + 1}');
          }
        } finally {
          await sub.cancel();
        }
      }

      if (mounted) {
        setState(() => _isPlaying = false);
        _lastAIResponse = text;
      }
      _micLog('TTS xong');
    } catch (e) {
      _micLog('TTS lỗi tổng: $e');
      if (mounted) {
        setState(() => _isPlaying = false);
        _lastAIResponse = text;
        _showSnackBar('Lỗi phát âm thanh: $e');
      }
    }
  }

  void _showSnackBar(String message, {Duration duration = const Duration(seconds: 5)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: duration),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        title: Text(widget.roomName ?? 'AI Chat Assistant'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Không có tin nhắn'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg.role == 'user';
                      
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isUser ? _primaryColor : _cardColor,
                            border: isUser
                                ? null
                                : Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.content,
                                style: TextStyle(
                                  color: isUser ? Colors.white : _textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              if (!isUser && _lastAIResponse == msg.content && _lastAIResponse != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: ElevatedButton.icon(
                                    icon: Icon(
                                      _isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      size: 16,
                                    ),
                                    label: Text(
                                      _isPlaying ? 'Tạm dừng' : 'Phát lại',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () async {
                                      if (_isPlaying) {
                                        await _audioPlayer.pause();
                                        if (mounted) {
                                          setState(() => _isPlaying = false);
                                        }
                                      } else {
                                        await _playTTS(_lastAIResponse!);
                                        if (mounted &&
                                            _speechEngineReady &&
                                            !_userPausedContinuousMic) {
                                          _resumeContinuousMicAfterIdle(
                                            'phát_lại_TTS',
                                          );
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      backgroundColor: _accentColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              children: [
                if (_isListening)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.mic, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Đang lắng nghe...',
                          style: TextStyle(color: Colors.red),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _userStopContinuousMic,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red),
                            ),
                            child: const Text(
                              'Dừng',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: !_speechEngineReady && _speechInitAttempted
                              ? 'Nhập chữ. Mic cần Google / Dịch vụ nhận dạng giọng — bấm nút mic để nghe hướng dẫn.'
                              : _userPausedContinuousMic
                                  ? 'Nhập hoặc bấm mic để nghe...'
                                  : 'Nhập hoặc đang nghe liên tục...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: _primaryColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          suffixIcon: _isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        onSubmitted: (text) {
                          if (!_isLoading) _sendMessage(text);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Mic button (Semantics cho TalkBack / người khiếm thị)
                    Semantics(
                      button: true,
                      enabled: !_isLoading,
                      label: _speechEngineReady
                          ? (_isListening
                              ? 'Đang nghe microphone. Nhấn để tắt mic.'
                              : 'Bật microphone để nói liên tục.')
                          : 'Nhận dạng giọng chưa bật trên máy. Nhấn để thử lại và nghe hướng dẫn cài Google.',
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isListening ? Colors.red : _primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isListening ? Icons.stop : Icons.mic,
                            color: Colors.white,
                          ),
                          onPressed: _isLoading
                              ? null
                              : (_isListening
                                  ? _userStopContinuousMic
                                  : () => _startListening(
                                        triggeredByMicButton: true,
                                      )),
                          tooltip: _isListening
                              ? 'Dừng mic'
                              : (_speechEngineReady
                                  ? 'Bật mic (nghe liên tục)'
                                  : 'Mic — thử lại / xem hướng dẫn'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send button
                    Container(
                      decoration: BoxDecoration(
                        color: _accentColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _isLoading
                            ? null
                            : () => _sendMessage(_messageController.text),
                        tooltip: 'Gửi',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final bool isError;

  ChatMessage({
    required this.role,
    required this.content,
    this.isError = false,
  });
}
