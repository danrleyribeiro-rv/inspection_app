// lib/presentation/screens/chat/chats_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inspection_app/models/chat.dart';
import 'package:inspection_app/services/features/chat_service.dart';
import 'package:inspection_app/presentation/screens/chat/chat_detail_screen.dart';
import 'package:inspection_app/presentation/widgets/media/avatar_widget.dart';
import 'package:intl/intl.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final ChatService _chatService = ChatService();
  String _searchQuery = '';
  List<Chat> _allChats = [];
  List<Chat> _filteredChats = [];
  bool _showUnreadOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        title: const Text('Conversas'),
        backgroundColor: const Color(0xFF1E293B),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        elevation: 0,
        actions: [
          IconButton(
            icon:
                Icon(_showUnreadOnly ? Icons.visibility : Icons.visibility_off),
            tooltip: _showUnreadOnly ? 'Mostrar todas' : 'Mostrar não lidas',
            onPressed: () {
              setState(() {
                _showUnreadOnly = !_showUnreadOnly;
                _filterChats();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Pesquisar conversas...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[800],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filterChats();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Chat>>(
              stream: _chatService.getUserChats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erro: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white)),
                  );
                }

                _allChats = snapshot.data ?? [];
                _filterChats();

                if (_filteredChats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(
                          _allChats.isEmpty
                              ? 'Nenhuma conversa disponível'
                              : 'Nenhuma conversa encontrada',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: _filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = _filteredChats[index];
                    return ChatListItem(
                      chat: chat,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatDetailScreen(chat: chat),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _filterChats() {
    if (_searchQuery.isEmpty && !_showUnreadOnly) {
      _filteredChats = _allChats;
      return;
    }

    _filteredChats = _allChats.where((chat) {
      if (_showUnreadOnly && chat.unreadCount == 0) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final inspectionCod = chat.inspection['cod'] ?? '';
        final inspectorName = chat.inspector['name'] ?? '';
        final inspectorLastName = chat.inspector['last_name'] ?? '';
        final managerName = chat.manager['name'] ?? '';
        final managerLastName = chat.manager['last_name'] ?? '';

        final searchLower = _searchQuery.toLowerCase();
        return inspectionCod.toLowerCase().contains(searchLower) ||
            inspectorName.toLowerCase().contains(searchLower) ||
            inspectorLastName.toLowerCase().contains(searchLower) ||
            managerName.toLowerCase().contains(searchLower) ||
            managerLastName.toLowerCase().contains(searchLower);
      }

      return true;
    }).toList();
  }
}

class ChatListItem extends StatelessWidget {
  final Chat chat;
  final VoidCallback onTap;

  const ChatListItem({
    super.key,
    required this.chat,
    required this.onTap,
  });

  void _showReadOptionsDialog(BuildContext context, int unreadCount) {
    final chatService = ChatService();
    
    showModalBottomSheet(
      context: context,
      elevation: 10,
      useSafeArea: false,
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Opções do Chat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[300],
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  unreadCount > 0 ? Icons.mark_chat_read : Icons.mark_chat_unread,
                  color: unreadCount > 0 ? Colors.green : Colors.orange,
                ),
                title: Text(unreadCount > 0 ? 'Marcar como Lida' : 'Marcar como Não Lida'),
                onTap: () async {
                  Navigator.of(context).pop();
                  try {
                    if (unreadCount > 0) {
                      await chatService.markChatAsRead(chat.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chat marcado como lido')),
                        );
                      }
                    } else {
                      await chatService.markChatAsUnread(chat.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chat marcado como não lido')),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro: $e')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.grey),
                title: const Text('Cancelar'),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final inspectorName = chat.inspector['name'] ?? '';
    final inspectorLastName = chat.inspector['last_name'] ?? '';
    final inspectorFullName = '$inspectorName $inspectorLastName';
    
    // Use manager data for avatar if available, otherwise fallback to inspector
    final managerName = chat.manager['name'] ?? '';
    final managerLastName = chat.manager['last_name'] ?? '';
    final managerFullName = '$managerName $managerLastName';
    final profileImageUrl = chat.manager['profileImageUrl'] ?? chat.inspector['profileImageUrl'];
    final displayName = managerFullName.trim().isNotEmpty ? managerFullName : inspectorFullName;

    // Verificar se a última mensagem é do usuário atual
    final isCurrentUserSender =
        chat.lastMessage.isNotEmpty && chat.lastMessage['sender_id'] == userId;

    String timeText = '';
    if (chat.lastMessage.isNotEmpty && chat.lastMessage['timestamp'] != null) {
      DateTime timestamp;
      final timestampData = chat.lastMessage['timestamp'];

      if (timestampData is String) {
        timestamp = DateTime.parse(timestampData);
      } else {
        timestamp = timestampData.toDate();
      }

      final now = DateTime.now();
      final difference = now.difference(timestamp);

      if (difference.inDays == 0) {
        timeText = DateFormat.Hm().format(timestamp);
      } else if (difference.inDays < 7) {
        timeText = DateFormat.E().format(timestamp);
      } else {
        timeText = DateFormat.yMd().format(timestamp);
      }
    }

    String lastMessageText = '';
    if (chat.lastMessage.isNotEmpty) {
      if (chat.lastMessage['type'] == 'text') {
        lastMessageText = chat.lastMessage['text'] ?? '';
      } else {
        lastMessageText = chat.lastMessage['text'] ?? 'Arquivo enviado';
      }

      if (isCurrentUserSender) {
        lastMessageText = 'Você: $lastMessageText';
      }
    }

    // StreamBuilder para contagem em tempo real de mensagens não lidas deste chat
    return StreamBuilder<int>(
      stream: FirebaseFirestore.instance
          .collection('chat_messages')
          .where('chat_id', isEqualTo: chat.id)
          .where('sender_id', isNotEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        int unreadCount = 0;
        for (var doc in snapshot.docs) {
          final readBy = List<String>.from(doc.data()['read_by'] ?? []);
          if (!readBy.contains(userId)) {
            unreadCount++;
          }
        }
        return unreadCount;
      }),
      builder: (context, unreadSnapshot) {
        final unreadCount = unreadSnapshot.data ?? 0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: Colors.grey[850],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: onTap,
            onLongPress: () => _showReadOptionsDialog(context, unreadCount),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  AvatarWidget(
                    imageUrl: profileImageUrl,
                    name: displayName,
                    size: 50,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              displayName.isEmpty
                                  ? 'Chat da Inspeção'
                                  : displayName,
                              style: TextStyle(
                                fontWeight: unreadCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              timeText,
                              style: TextStyle(
                                color:
                                    unreadCount > 0 ? Colors.blue : Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          chat.inspection['cod'] ?? 'Inspeção',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastMessageText.isEmpty
                                    ? 'Iniciar conversa'
                                    : lastMessageText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: unreadCount > 0
                                      ? Colors.white
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
