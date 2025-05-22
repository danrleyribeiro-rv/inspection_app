import 'package:flutter/material.dart';

class ChatTab extends StatelessWidget {
  const ChatTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [],
      ),
      body: const Center(
        child: Text('Chat Content'),
      ),
    );
  }
}