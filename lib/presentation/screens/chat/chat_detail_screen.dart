// lib/presentation/screens/chat/chat_detail_screen.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:inspection_app/models/chat.dart';
import 'package:inspection_app/models/chat_message.dart';
import 'package:inspection_app/services/features/chat_service.dart';
import 'package:inspection_app/presentation/widgets/media/avatar_widget.dart';
import 'package:inspection_app/presentation/widgets/common/chat_message_item.dart';
import 'package:intl/intl.dart';

class ChatDetailScreen extends StatefulWidget {
  final Chat chat;

  const ChatDetailScreen({
    super.key,
    required this.chat,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

// REMOVED `with WidgetsBindingObserver` as we will handle this differently
class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String _currentUserId = '';
  List<ChatMessage> _messages = [];
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  bool _isFirstLoad = true;
  // bool _keyboardVisible = false; // This state is no longer needed

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid ?? '';
    _markMessagesAsRead();

    _messageController.addListener(() {
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupMessagesStream();
    });
  }

  // REMOVED `didChangeMetrics()` - we'll handle this in the build method.

  void _setupMessagesStream() {
    _messagesSubscription =
        _chatService.getChatMessages(widget.chat.id).listen((messages) {
      if (mounted) {
        setState(() {
          _messages = messages;
        });

        if (_isFirstLoad || _shouldScrollToBottom()) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom(animate: !_isFirstLoad);
            _isFirstLoad = false;
          });
        }
      }
    });
  }

  bool _shouldScrollToBottom() {
    if (!_scrollController.hasClients) return true;

    final isNearBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100;

    return isNearBottom;
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _markMessagesAsRead() async {
    try {
      await _chatService.markMessagesAsRead(widget.chat.id);
    } catch (e) {
      debugPrint('Erro ao marcar mensagens como lidas: $e');
    }
  }

  void _scrollToBottom({bool animate = true}) {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(maxScroll);
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      await _chatService.sendTextMessage(widget.chat.id, message);
      _messageController.clear();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar mensagem: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        if (!mounted) return;
        setState(() => _isLoading = true);

        final file = File(image.path);
        await _chatService.sendFileMessage(widget.chat.id, file, 'image');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    } catch (e) {
      // THE FIX: Add a mounted check before using context.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar imagem: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        if (!mounted) return;
        setState(() => _isLoading = true);

        final file = File(result.files.single.path!);
        await _chatService.sendFileMessage(widget.chat.id, file, 'file');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    } catch (e) {
      // THE FIX: Add a mounted check before using context.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar arquivo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ... (rest of the methods like _showMessageOptions, etc., remain the same)
  void _showMessageOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      elevation: 10,
      useSafeArea: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.grey),
                title: const Text('Detalhes',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showMessageDetails(message);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateSeparator(DateTime messageDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay =
        DateTime(messageDate.year, messageDate.month, messageDate.day);

    if (messageDay == today) {
      return 'Hoje';
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      return 'Ontem';
    } else {
      return DateFormat('dd/MM/yyyy').format(messageDate);
    }
  }

  void _showMessageDetails(ChatMessage message) {
    final readBy =
        message.readBy.where((id) => id != message.senderId).toList();
    final sentTime = DateFormat('dd/MM/yyyy HH:mm').format(message.timestamp);
    String readTime = '';

    if (message.readByTimestamp != null) {
      readTime =
          DateFormat('dd/MM/yyyy HH:mm').format(message.readByTimestamp!);
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Detalhes da mensagem',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enviada: $sentTime',
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              if (readBy.isNotEmpty && readTime.isNotEmpty) ...[
                Text('Lida em: $readTime',
                    style: const TextStyle(color: Colors.green)),
              ] else ...[
                const Text('Status: Não lida',
                    style: TextStyle(color: Colors.grey)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // THE FIX for `window` deprecation: Get insets from MediaQuery
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    // Scroll to bottom when keyboard appears
    if (keyboardVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animate: true);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            AvatarWidget(
              imageUrl: widget.chat.manager['profileImageUrl'] ?? widget.chat.inspector['profileImageUrl'],
              name: widget.chat.manager.isNotEmpty 
                  ? '${widget.chat.manager['name']} ${widget.chat.manager['last_name']}'
                  : '${widget.chat.inspector['name']} ${widget.chat.inspector['last_name']}',
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chat.manager.isNotEmpty 
                        ? '${widget.chat.manager['name']} ${widget.chat.manager['last_name']}'
                        : '${widget.chat.inspector['name']} ${widget.chat.inspector['last_name']}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.chat.inspection['cod'] ?? widget.chat.inspection['title'] ?? 'Inspeção',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // Use Expanded instead of Flexible for more predictable behavior
              child: _messages.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhuma mensagem ainda. Comece a conversar!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isCurrentUser =
                            message.senderId == _currentUserId;
                        final previousIsSameSender = index > 0 &&
                            _messages[index - 1].senderId == message.senderId;

                        bool showDateSeparator = false;
                        if (index == 0) {
                          showDateSeparator = true;
                        } else {
                          final currentDate = DateTime(message.timestamp.year,
                              message.timestamp.month, message.timestamp.day);
                          final previousDate = DateTime(
                              _messages[index - 1].timestamp.year,
                              _messages[index - 1].timestamp.month,
                              _messages[index - 1].timestamp.day);
                          showDateSeparator =
                              !currentDate.isAtSameMomentAs(previousDate);
                        }

                        return Column(
                          children: [
                            if (showDateSeparator)
                              Center(
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text(
                                      _formatDateSeparator(message.timestamp),
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 10)),
                                ),
                              ),
                            ChatMessageItem(
                              message: message,
                              isCurrentUser: isCurrentUser,
                              onLongPress: () => _showMessageOptions(message),
                              previousIsSameSender: previousIsSameSender,
                              onEdit: _editMessage,
                              onDelete: _deleteMessage,
                            ),
                          ],
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.1).round()),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey),
                    onPressed: _isLoading ? null : _showAttachmentOptions,
                  ),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 100),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Digite uma mensagem...',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none),
                          filled: true,
                          fillColor: Colors.grey[800],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        style: const TextStyle(color: Colors.white),
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !_isLoading,
                        onSubmitted: (_) => _sendMessage(),
                        onTap: () {
                          Future.delayed(const Duration(milliseconds: 300),
                              () => _scrollToBottom(animate: true));
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isLoading
                      ? Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(12),
                          child:
                              const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.blue),
                          onPressed:
                              _messageController.text.trim().isNotEmpty &&
                                      !_isLoading
                                  ? _sendMessage
                                  : null,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      elevation: 10,
      useSafeArea: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blue),
                title:
                    const Text('Imagem', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file, color: Colors.orange),
                title: const Text('Arquivo',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _editMessage(String messageId, String currentContent) {
    final TextEditingController editController = TextEditingController(text: currentContent);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Mensagem'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: 'Digite a nova mensagem...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final newContent = editController.text.trim();
              if (newContent.isNotEmpty && newContent != currentContent) {
                Navigator.pop(context);
                try {
                  await _chatService.editMessage(messageId, newContent);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mensagem editada')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao editar: $e')),
                    );
                  }
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(String messageId) async {
    try {
      await _chatService.deleteMessage(messageId, widget.chat.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mensagem apagada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao apagar: $e')),
        );
      }
    }
  }
}
