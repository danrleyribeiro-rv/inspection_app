// lib/presentation/screens/chat/chat_detail_screen.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:inspection_app/models/chat.dart';
import 'package:inspection_app/models/chat_message.dart';
import 'package:inspection_app/services/chat_service.dart';
import 'package:inspection_app/presentation/widgets/avatar_widget.dart';
import 'package:inspection_app/presentation/widgets/chat_message_item.dart';
import 'package:intl/intl.dart';

class ChatDetailScreen extends StatefulWidget {
  final Chat chat;

  const ChatDetailScreen({
    Key? key,
    required this.chat,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String _currentUserId = '';
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid ?? '';
    _markMessagesAsRead();
    
    _messageController.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
    _forceScrollToBottom();
  });
}

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _markMessagesAsRead() async {
    try {
      await _chatService.markMessagesAsRead(widget.chat.id);
    } catch (e) {
      print('Erro ao marcar mensagens como lidas: $e');
    }
  }
  
  void _scrollToBottom({bool animate = true}) {
    if (_scrollController.hasClients) {
      if (animate) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  void _forceScrollToBottom() {
  if (_scrollController.hasClients) {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }
}
  
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _chatService.sendTextMessage(widget.chat.id, message);
      _messageController.clear();
      
      // Scroll para baixo após enviar mensagem
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
        setState(() {
          _isLoading = false;
        });
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
      setState(() => _isLoading = true);
      
      final file = File(image.path);
      await _chatService.sendFileMessage(widget.chat.id, file, 'image');
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao enviar imagem: $e')),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}

Future<void> _pickAndSendFile() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    
    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);
      
      final file = File(result.files.single.path!);
      await _chatService.sendFileMessage(widget.chat.id, file, 'file');
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao enviar arquivo: $e')),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}

void _showMessageOptions(ChatMessage message) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey[900],
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
              title: const Text('Detalhes', style: TextStyle(color: Colors.white)),
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

void _showMessageDetails(ChatMessage message) {
  final readBy = message.readBy.where((id) => id != message.senderId).toList();
  final sentTime = DateFormat('dd/MM/yyyy HH:mm').format(message.timestamp);
  String readTime = '';
  
  if (message.readByTimestamp != null) {
    readTime = DateFormat('dd/MM/yyyy HH:mm').format(message.readByTimestamp!);
  }
  
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Detalhes da mensagem', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enviada: $sentTime', style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            
            if (readBy.isNotEmpty && readTime.isNotEmpty) ...[
              Text('Lida em: $readTime', style: const TextStyle(color: Colors.green)),
            ] else ...[
              const Text('Status: Não lida', style: TextStyle(color: Colors.grey)),
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
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            AvatarWidget(
              imageUrl: widget.chat.inspector['profileImageUrl'],
              name: '${widget.chat.inspector['name']} ${widget.chat.inspector['last_name']}',
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.chat.inspector['name']} ${widget.chat.inspector['last_name']}',
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.chat.inspection['title'] ?? 'Inspeção',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Lista de mensagens
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getChatMessages(widget.chat.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erro: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
                  );
                }
                
                final messages = snapshot.data ?? [];
                _messages = messages; // Armazenar mensagens
                
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhuma mensagem ainda. Comece a conversar!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                
                // Scroll para o final quando novas mensagens chegarem
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    // Verificar se estamos perto do final antes de fazer scroll automático
                    final isAtBottom = _scrollController.position.pixels >= 
                        _scrollController.position.maxScrollExtent - 100;
                    
                    if (isAtBottom || messages.length == 1) {
                      _scrollToBottom(animate: false);
                    }
                  }
                });
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isCurrentUser = message.senderId == _currentUserId;
                    final previousIsSameSender = index > 0 && 
                        messages[index - 1].senderId == message.senderId;
                    
                    // Mostrar data se for uma nova data
                    bool showDateSeparator = false;
                    if (index == 0) {
                      showDateSeparator = true;
                    } else {
                      final currentDate = DateTime(
                        message.timestamp.year,
                        message.timestamp.month,
                        message.timestamp.day,
                      );
                      final previousDate = DateTime(
                        messages[index - 1].timestamp.year,
                        messages[index - 1].timestamp.month,
                        messages[index - 1].timestamp.day,
                      );
                      showDateSeparator = !currentDate.isAtSameMomentAs(previousDate);
                    }
                    
                    return Column(
                      children: [
                        if (showDateSeparator)
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                DateFormat('dd/MM/yyyy').format(message.timestamp),
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ),
                          ),
                        
                        ChatMessageItem(
                          message: message,
                          isCurrentUser: isCurrentUser,
                          onLongPress: () => _showMessageOptions(message),
                          previousIsSameSender: previousIsSameSender,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          
          // Campo de entrada de mensagem
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Botão de anexo
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey),
                    onPressed: _isLoading ? null : _showAttachmentOptions,
                  ),
                  
                  // Campo de texto
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Digite uma mensagem...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      style: const TextStyle(color: Colors.white),
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !_isLoading,
                      onSubmitted: (_) => _sendMessage(), // Adicionar para enviar com Enter
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Botão de enviar
                  _isLoading
                      ? Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(12),
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.blue),
                          onPressed: _messageController.text.trim().isNotEmpty && !_isLoading 
                              ? _sendMessage 
                              : null,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
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
}
