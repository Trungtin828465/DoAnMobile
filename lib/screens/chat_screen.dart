import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';

import '../services/chat_service.dart';

const Color _primaryColor = Color(0xFF2563EB);
const Color _accentColor = Color(0xFF10B981);
const Color _surfaceColor = Color(0xFFF8FAFC);
const Color _cardColor = Color(0xFFFFFFFF);
const Color _textPrimary = Color(0xFF1E293B);
const Color _textSecondary = Color(0xFF64748B);

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
  String? _lastAIResponse;

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _audioPlayer = AudioPlayer();
    _initializeSpeech();
    
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
    _speechToText.stop();
    _audioPlayer.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _initializeSpeech() async {
    await _speechToText.initialize(
      onError: (error) {
        debugPrint('Lỗi STT: $error');
        _showSnackBar('Lỗi: $error');
      },
      onStatus: (status) {
        debugPrint('Status: $status');
      },
    );
  }

  void _startListening() async {
    if (!_isListening && _speechToText.isAvailable) {
      setState(() => _isListening = true);
      
      try {
        await _speechToText.listen(
          onResult: (result) {
            setState(() {
              _messageController.text = result.recognizedWords;
            });
            
            if (result.finalResult) {
              setState(() => _isListening = false);
              // Auto send khi hết nói
              if (result.recognizedWords.isNotEmpty) {
                _sendMessage(result.recognizedWords);
              }
            }
          },
          localeId: 'vi_VN',
        );
      } catch (e) {
        debugPrint('Lỗi: $e');
        setState(() => _isListening = false);
      }
    }
  }

  void _stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
    }
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _messageController.clear();
      _isLoading = true;
    });

    // Get AI response
    final response = await ChatService.sendMessage(text);
    
    setState(() {
      _messages.add(ChatMessage(role: 'assistant', content: response));
      _isLoading = false;
    });

    // Lưu response để phát lại sau
    _lastAIResponse = response;
    
    // Auto play TTS
    await _playTTS(response);
  }

  Future<void> _playTTS(String text) async {
    try {
      setState(() => _isPlaying = true);
      
      // Tách text thành các câu (cách bằng dấu chấm)
      final sentences = ChatService.splitTextForTTS(text);
      debugPrint('🔊 Phát ${sentences.length} câu');
      
      // Phát từng câu liên tiếp
      for (int i = 0; i < sentences.length; i++) {
        final sentence = sentences[i];
        final audioUrl = ChatService.getTTSUrlForText(sentence);
        
        debugPrint('🔊 Phát câu ${i + 1}/${sentences.length}: "$sentence"');
        
        try {
          // Phát audio
          await _audioPlayer.play(UrlSource(audioUrl));
          
          // Đợi audio phát xong (tính theo độ dài của câu)
          // Ước tính: 100ms cơ bản + 50ms per ký tự
          final delayMs = 500 + (sentence.length * 50);
          await Future.delayed(Duration(milliseconds: delayMs));
        } catch (e) {
          debugPrint('❌ Lỗi phát câu $i: $e');
          if (mounted) {
            _showSnackBar('Lỗi phát câu ${i + 1}');
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _isPlaying = false;
          // Xóa text cũ sau khi phát xong
          _lastAIResponse = null;
        });
      }
    } catch (e) {
      debugPrint('Lỗi TTS: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _lastAIResponse = null;
        });
        _showSnackBar('Lỗi phát âm thanh: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
                                    onPressed: () {
                                      if (_isPlaying) {
                                        _audioPlayer.pause();
                                        setState(() => _isPlaying = false);
                                      } else {
                                        _playTTS(_lastAIResponse!);
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
                          onTap: _stopListening,
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
                          hintText: 'Nhập hoặc nói...',
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
                    // Mic button
                    Container(
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
                            : (_isListening ? _stopListening : _startListening),
                        tooltip: _isListening ? 'Dừng' : 'Nói',
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
