// lib/presentation/widgets/chat_notification_badge.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/services/notification_service.dart';

class ChatNotificationBadge extends StatelessWidget {
  final Widget child;
  
  const ChatNotificationBadge({
    Key? key,
    required this.child,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService().unreadMessagesStream,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        
        return Stack(
          children: [
            child,
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}