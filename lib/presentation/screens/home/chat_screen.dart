// lib/presentation/screens/home/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final int conversationId;
  final int? inspectionId;
  final String title;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.inspectionId,
    required this.title,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _messages = [];
  late final Stream<List<Map<String, dynamic>>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _supabase.removeAllChannels();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    if (!mounted) return; // Check if widget is still mounted

    try {
      _supabase
          .channel(
              'public:messages:conversation_id=eq.${widget.conversationId}')
          .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'conversation_id',
                value: widget.conversationId.toString(),
              ),
              callback: (payload) {
                _handleNewMessage(payload.newRecord);
              })
          .subscribe()
          ; // Removed .onError(...)
    } catch (e) {
      print('Error setting up realtime subscription: $e');
    }
  }

  void _handleNewMessage(Map<String, dynamic> newMessage) {
    if (newMessage['conversation_id'] == widget.conversationId) {
      setState(() {
        _messages.insert(0, newMessage);
      });
    }
  }

  Future<void> _loadMessages() async {
    try {
      setState(() => _isLoading = true);

      final data = await _supabase
          .from('messages')
          .select('*, users:user_id(id, name, last_name)')
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading messages: $e'); // Debugging message loading errors
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      final userId = _supabase.auth.currentUser!.id;

      await _supabase.from('messages').insert({
        'conversation_id': widget.conversationId,
        'user_id': userId,
        'content': text,
        'is_read': false,
      });

      _messageController.clear();
    } catch (e) {
      print('Error sending message: $e'); // Debugging message sending errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('No messages yet.'))
                    : ListView.builder(
                        reverse: true,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isSentByCurrentUser = message['user_id'] ==
                              _supabase.auth.currentUser!.id;

                          final user = message['users'] as Map<String, dynamic>?;
                          final senderName =
                              '${user?['name'] ?? 'Unknown'} ${user?['last_name'] ?? ''}'
                                  .trim();

                          return _buildMessageBubble(
                              message, isSentByCurrentUser, senderName);
                        },
                      ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      Map<String, dynamic> message, bool isSentByCurrentUser, String senderName) {
    return Align(
      alignment:
          isSentByCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSentByCurrentUser ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: isSentByCurrentUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isSentByCurrentUser)
              Text(
                senderName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            Text(
              message['content'],
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message['created_at']),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type your message...',
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';

    try {
      final time = DateTime.parse(timeStr).toLocal();
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}