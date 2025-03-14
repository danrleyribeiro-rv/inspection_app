// lib/presentation/screens/home/chat_tab.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inspection_app/presentation/screens/home/chat_screen.dart'; // Import ChatScreen

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];
  String? _inspectorId;

  @override
  void initState() {
    super.initState();
    _getInspectorId().then((_) {
      _loadConversations();
      _setupRealtimeSubscription(); // Set up Realtime after loading
    });
  }

  @override
  void dispose() {
    _supabase.removeAllChannels();
    super.dispose();
  }

  Future<void> _getInspectorId() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final inspectorData = await _supabase
          .from('inspectors')
          .select('id')
          .eq('user_id', userId)
          .single();

      _inspectorId = inspectorData['id'];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao obter dados do inspetor: $e')),
        );
      }
    }
  }

  void _setupRealtimeSubscription() {
    _supabase
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            // Check if the new message is relevant to the current inspector
            _handleNewMessage(payload.newRecord);
          },
        )
        .subscribe();
  }

  void _handleNewMessage(Map<String, dynamic> newMessage) async {
    // Check if the conversation is in the current list
    final existingConversationIndex = _conversations.indexWhere(
      (conv) => conv['conversation_id'] == newMessage['conversation_id'],
    );

    if (existingConversationIndex != -1) {
      // Update existing conversation
      setState(() {
        // Update last message and timestamp
        _conversations[existingConversationIndex]['last_message'] =
            newMessage['content'];
        _conversations[existingConversationIndex]['updated_at'] =
            newMessage['created_at'];

        // Increment unread count if not on the chat screen
        // if (!_isChatScreenActive || _activeConversationId != newMessage['conversation_id']) {
        //   _conversations[existingConversationIndex]['unread_count'] =
        //       (_conversations[existingConversationIndex]['unread_count'] ?? 0) + 1;
        // }

        // Move the conversation to the top
        final updatedConversation =
            _conversations.removeAt(existingConversationIndex);
        _conversations.insert(0, updatedConversation);
      });
    } else {
      // New conversation, fetch details and add to the list
      _loadConversations();
    }
  }

  Future<void> _loadConversations() async {
    if (_inspectorId == null) return;

    try {
      setState(() => _isLoading = true);

      // 1. Buscar TODAS as conversas do inspetor (incluindo gerais)
      final allConversations = await _supabase
          .from('conversations')
          .select('''
          id,
          title,
          inspection_id,
          updated_at,
          messages(content),
          conversation_participants(user_id)
        ''')
          .eq('conversation_participants.user_id',
              _supabase.auth.currentUser!.id)
          .order('updated_at', ascending: false);

      // 2. Separar as conversas em inspeção e gerais
      List<Map<String, dynamic>> inspectionConversations = [];
      List<Map<String, dynamic>> generalConversations = [];

      for (final conv in allConversations) {
        final inspectionId = conv['inspection_id'];

        String lastMessage = 'Clique para ver a conversa.';
        if (conv['messages'] != null && (conv['messages'] as List).isNotEmpty) {
          lastMessage = conv['messages'][0]['content'] ??
              'Clique para ver a conversa.';
        }

        final conversationData = {
          'id': conv['id'],
          'title': conv['title'] ?? 'Conversa',
          'last_message': lastMessage,
          'updated_at': conv['updated_at'] ?? DateTime.now().toIso8601String(),
          'unread_count': 0, // TODO: Calculate unread
          'inspection_id': inspectionId,
          'conversation_id': conv['id'],
          'project_id': null, // We'll fetch this below
        };

        if (inspectionId != null) {
          // Busca o título da inspeção, se existir
          final inspection = await _supabase
              .from('inspections')
              .select('title, project_id')
              .eq('id', inspectionId)
              .maybeSingle();

          if (inspection != null) {
            conversationData['title'] = 'Vistoria: ${inspection['title']}';
            conversationData['project_id'] =
                inspection['project_id']; // Now we have project_id
          }
          inspectionConversations.add(conversationData);
        } else {
          generalConversations.add(conversationData);
        }
      }
      //Junção das conversas de vistoria e geral
      setState(() {
        _conversations = [...inspectionConversations, ...generalConversations];
        _conversations.sort((a, b) => DateTime.parse(b['updated_at']!)
            .compareTo(DateTime.parse(a['updated_at']!)));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar conversas: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensagens'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConversations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nenhuma conversa disponível',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'As conversas relacionadas às suas vistorias e conversas gerais aparecerão aqui',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadConversations,
                        child: const Text('Atualizar'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = _conversations[index];
                    return Card(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: const Icon(Icons.chat, color: Colors.white),
                        ),
                        title: Text(
                          conversation['title'] ?? 'Sem título',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          conversation['last_message'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: conversation['unread_count'] > 0
                            ? Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  conversation['unread_count'].toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : Text(
                                _formatTime(conversation['updated_at']),
                                style: const TextStyle(color: Colors.grey),
                              ),
                        onTap: () {
                          // Navegar para a tela de chat individual
                          _navigateToChat(conversation);
                        },
                      ),
                    );
                  },
                ),
    );
  }

  void _navigateToChat(Map<String, dynamic> conversation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversation['conversation_id'],
          inspectionId: conversation['inspection_id'],
          title: conversation['title'],
        ),
      ),
    );
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';

    try {
      final time = DateTime.parse(timeStr).toLocal();
      final now = DateTime.now();

      if (now.difference(time).inDays > 0) {
        // Se for mais de um dia, exibe a data
        return '${time.day}/${time.month}';
      } else {
        // Senão exibe a hora
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }
}

