// lib/presentation/widgets/chat_tag_widget.dart
import 'package:flutter/material.dart';

class ChatTagWidget extends StatelessWidget {
  final String tag;
  final bool isSelected;
  final VoidCallback onTap;
  
  const ChatTagWidget({
    Key? key,
    required this.tag,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[600]!,
          ),
        ),
        child: Text(
          tag,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[300],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}