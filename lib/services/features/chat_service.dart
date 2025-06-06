import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:inspection_app/models/chat.dart';
import 'package:inspection_app/models/chat_message.dart';
import 'package:inspection_app/services/core/firebase_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebase = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Chat>> getUserChats() {
    final userId = _firebase.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firebase.firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Chat.fromFirestore(doc)).toList());
  }

  Stream<List<ChatMessage>> getChatMessages(String chatId) {
    return _firebase.firestore
        .collection('chat_messages')
        .where('chat_id', isEqualTo: chatId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList());
  }

  Future<String> createOrGetChat(String inspectionId) async {
    final userId = _firebase.currentUser?.uid;
    if (userId == null) throw Exception('Usuário não autenticado');

    final existingChats = await _firebase.firestore
        .collection('chats')
        .where('inspection_id', isEqualTo: inspectionId)
        .where('participants', arrayContains: userId)
        .limit(1)
        .get();

    if (existingChats.docs.isNotEmpty) {
      return existingChats.docs.first.id;
    }

    return await _createNewChat(inspectionId, userId);
  }

  Future<void> sendTextMessage(String chatId, String content) async {
    final userId = _firebase.currentUser?.uid;
    if (userId == null) throw Exception('Usuário não autenticado');

    await _firebase.firestore.collection('chat_messages').add({
      'chat_id': chatId,
      'sender_id': userId,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'received_by': [userId],
      'read_by': [userId],
    });

    await _updateLastMessage(chatId, content, userId, 'text');
  }

  Future<void> sendFileMessage(String chatId, File file, String type) async {
    final userId = _firebase.currentUser?.uid;
    if (userId == null) throw Exception('Usuário não autenticado');

    final fileSize = await file.length();
    if (fileSize > 100 * 1024 * 1024) {
      throw Exception('O arquivo excede o limite de 100MB');
    }

    final fileName = path.basename(file.path);
    final storagePath =
        'chats/$chatId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    final storageRef = _firebase.storage.ref().child(storagePath);
    final uploadTask = storageRef.putFile(file);
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    final fileExtension = path.extension(fileName).toLowerCase();
    final fileType = _getFileType(fileExtension);

    await _firebase.firestore.collection('chat_messages').add({
      'chat_id': chatId,
      'sender_id': userId,
      'content': '',
      'timestamp': FieldValue.serverTimestamp(),
      'type': fileType,
      'file_url': downloadUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'received_by': [userId],
      'read_by': [userId],
    });

    final displayText = 'Enviou um ${_getFileTypeDisplay(fileType)}';
    await _updateLastMessage(chatId, displayText, userId, fileType);
  }

  Future<void> markMessagesAsRead(String chatId) async {
    final userId = _firebase.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await _firebase.firestore
        .collection('chat_messages')
        .where('chat_id', isEqualTo: chatId)
        .where('sender_id', isNotEqualTo: userId)
        .get();

    final batch = _firebase.firestore.batch();
    bool hasUnreadMessages = false;

    for (final doc in snapshot.docs) {
      final message = ChatMessage.fromFirestore(doc);
      if (!message.readBy.contains(userId)) {
        hasUnreadMessages = true;
        final updatedReadBy = [...message.readBy, userId];
        batch.update(doc.reference, {'read_by': updatedReadBy});
      }
    }

    if (hasUnreadMessages) {
      await batch.commit();
      await _firebase.firestore
          .collection('chats')
          .doc(chatId)
          .update({'unread_count': 0});
    }
  }

  Future<String> _createNewChat(String inspectionId, String userId) async {
    final inspectionDoc = await _firebase.firestore
        .collection('inspections')
        .doc(inspectionId)
        .get();

    if (!inspectionDoc.exists) {
      throw Exception('Inspeção não encontrada');
    }

    final inspectionData = inspectionDoc.data() as Map<String, dynamic>;

    final inspectorDoc =
        await _firebase.firestore.collection('inspectors').doc(userId).get();

    if (!inspectorDoc.exists) {
      throw Exception('Inspetor não encontrado');
    }

    final inspectorData = inspectorDoc.data() as Map<String, dynamic>;

    final chatRef = await _firebase.firestore.collection('chats').add({
      'inspection_id': inspectionId,
      'inspection': {
        'id': inspectionId,
        'title': inspectionData['title'] ?? 'Inspeção'
      },
      'inspector': {
        'id': userId,
        'name': inspectorData['name'] ?? '',
        'last_name': inspectorData['last_name'] ?? '',
        'profileImageUrl': inspectorData['profileImageUrl']
      },
      'participants': [userId],
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'last_message': {},
      'unread_count': 0,
    });

    return chatRef.id;
  }

  Future<void> _updateLastMessage(
      String chatId, String content, String userId, String type) async {
    await _firebase.firestore.collection('chats').doc(chatId).update({
      'last_message': {
        'text': content,
        'sender_id': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': type
      },
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  String _getFileType(String extension) {
    if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']
        .contains(extension)) {
      return 'image';
    } else if (['.mp4', '.avi', '.mov', '.wmv', '.flv', '.mkv', '.webm']
        .contains(extension)) {
      return 'video';
    } else {
      return 'file';
    }
  }

  String _getFileTypeDisplay(String type) {
    switch (type) {
      case 'image':
        return 'imagem';
      case 'video':
        return 'vídeo';
      case 'file':
        return 'arquivo';
      default:
        return 'arquivo';
    }
  }

  Future<int> getUnreadMessagesCount() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return 0;

    try {
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .get();

      int totalUnread = 0;

      for (final chatDoc in chatsSnapshot.docs) {
        final messagesSnapshot = await _firestore
            .collection('chat_messages')
            .where('chat_id', isEqualTo: chatDoc.id)
            .where('sender_id', isNotEqualTo: userId)
            .get();

        for (final messageDoc in messagesSnapshot.docs) {
          final readBy = List<String>.from(messageDoc.data()['read_by'] ?? []);
          if (!readBy.contains(userId)) {
            totalUnread++;
          }
        }
      }

      return totalUnread;
    } catch (e) {
      debugPrint('Erro ao contar mensagens não lidas: $e');
      return 0;
    }
  }

  Stream<int> getUnreadMessagesCountStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(0);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .asyncMap((chatsSnapshot) async {
      int totalUnread = 0;

      for (final chatDoc in chatsSnapshot.docs) {
        final messagesSnapshot = await _firestore
            .collection('chat_messages')
            .where('chat_id', isEqualTo: chatDoc.id)
            .where('sender_id', isNotEqualTo: userId)
            .get();

        for (final messageDoc in messagesSnapshot.docs) {
          final readBy = List<String>.from(messageDoc.data()['read_by'] ?? []);
          if (!readBy.contains(userId)) {
            totalUnread++;
          }
        }
      }

      return totalUnread;
    });
  }
}
