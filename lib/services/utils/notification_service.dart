import 'package:inspection_app/services/features/chat_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  final ChatService _chatService = ChatService();
  
  Stream<int> get unreadMessagesStream {
    return _chatService.getUserChats().map((chats) {
      int totalUnread = 0;
      for (final chat in chats) {
        totalUnread += chat.unreadCount;
      }
      return totalUnread;
    });
  }
}