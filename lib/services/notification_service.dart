// lib/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/services/chat_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  final ChatService _chatService = ChatService();
  
  // Stream para escutar mudanças nas mensagens não lidas
  Stream<int> get unreadMessagesStream {
    return _chatService.getUserChats().map((chats) {
      int totalUnread = 0;
      for (final chat in chats) {
        totalUnread += chat.unreadCount ?? 0;
      }
      return totalUnread;
    });
  }
  
  // Mostrar notificação in-app para nova mensagem
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