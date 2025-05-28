import 'package:flutter/material.dart';
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
  
  void showInAppNotification(BuildContext context, String message, {
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: backgroundColor ?? Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: SnackBarAction(
          label: 'Ver',
          textColor: Colors.white,
          onPressed: () {
            // Navegar para a tela de chats
          },
        ),
      ),
    );
  }
}