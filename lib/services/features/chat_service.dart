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
      final chatDoc = existingChats.docs.first;
      final chatData = chatDoc.data() as Map<String, dynamic>;
      
      // Verificar se precisa atualizar o chat com dados faltantes
      bool needsUpdate = false;
      Map<String, dynamic> updateData = {};
      
      // Verificar se tem o cod da inspeção
      if (chatData['inspection'] != null && 
          chatData['inspection']['cod'] == null) {
        needsUpdate = true;
        
        // Buscar dados atualizados da inspeção
        final inspectionDoc = await _firebase.firestore
            .collection('inspections')
            .doc(inspectionId)
            .get();
            
        if (inspectionDoc.exists) {
          final inspectionData = inspectionDoc.data() as Map<String, dynamic>;
          updateData['inspection.cod'] = inspectionData['cod'] ?? 'COD-000';
        }
      }
      
      // Verificar se tem dados do gerente
      if (chatData['manager'] == null) {
        needsUpdate = true;
        
        // Buscar dados do gerente através do projeto
        final inspectionDoc = await _firebase.firestore
            .collection('inspections')
            .doc(inspectionId)
            .get();
            
        if (inspectionDoc.exists) {
          final inspectionData = inspectionDoc.data() as Map<String, dynamic>;
          final projectId = inspectionData['project_id'];
          
          if (projectId != null) {
            // Buscar o projeto para pegar o manager_id
            final projectDoc = await _firebase.firestore
                .collection('projects')
                .doc(projectId)
                .get();
                
            if (projectDoc.exists) {
              final projectData = projectDoc.data() as Map<String, dynamic>;
              final managerId = projectData['manager_id'];
              
              if (managerId != null) {
                final managerDoc = await _firebase.firestore
                    .collection('managers')
                    .doc(managerId)
                    .get();
                    
                if (managerDoc.exists) {
                  final manager = managerDoc.data() as Map<String, dynamic>;
                  updateData['manager'] = {
                    'id': managerId,
                    'name': manager['name'] ?? '',
                    'last_name': manager['last_name'] ?? '',
                    'profileImageUrl': manager['profileImageUrl']
                  };
                }
              }
            }
          }
        }
      }
      
      // Atualizar o chat se necessário
      if (needsUpdate) {
        await _firebase.firestore
            .collection('chats')
            .doc(chatDoc.id)
            .update(updateData);
      }
      
      return chatDoc.id;
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
      'is_deleted': false,
      'is_edited': false,
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
      'is_deleted': false,
      'is_edited': false,
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

  Future<void> markChatAsUnread(String chatId) async {
    final userId = _firebase.currentUser?.uid;
    if (userId == null) return;

    // Pegar a última mensagem que não foi enviada pelo usuário atual
    final snapshot = await _firebase.firestore
        .collection('chat_messages')
        .where('chat_id', isEqualTo: chatId)
        .where('sender_id', isNotEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final lastMessageDoc = snapshot.docs.first;
      final message = ChatMessage.fromFirestore(lastMessageDoc);
      
      // Remover o usuário da lista de lidos da última mensagem
      final updatedReadBy = message.readBy.where((id) => id != userId).toList();
      
      await _firebase.firestore
          .collection('chat_messages')
          .doc(lastMessageDoc.id)
          .update({'read_by': updatedReadBy});

      // Atualizar o contador de não lidas no chat
      await _firebase.firestore
          .collection('chats')
          .doc(chatId)
          .update({'unread_count': 1});
    }
  }

  Future<void> markChatAsRead(String chatId) async {
    await markMessagesAsRead(chatId);
  }

  Future<void> deleteMessage(String messageId, String chatId) async {
    final userId = _firebase.currentUser?.uid;
    if (userId == null) throw Exception('Usuário não autenticado');

    // Verificar se a mensagem pertence ao usuário
    final messageDoc = await _firebase.firestore
        .collection('chat_messages')
        .doc(messageId)
        .get();

    if (!messageDoc.exists) {
      throw Exception('Mensagem não encontrada');
    }

    final messageData = messageDoc.data() as Map<String, dynamic>;
    if (messageData['sender_id'] != userId) {
      throw Exception('Você só pode apagar suas próprias mensagens');
    }

    // Marcar como deletada em vez de apagar completamente
    await _firebase.firestore
        .collection('chat_messages')
        .doc(messageId)
        .update({
      'content': '',
      'deleted_at': FieldValue.serverTimestamp(),
      'is_deleted': true,
    });

    // Atualizar última mensagem se for a mensagem mais recente
    await _updateLastMessageIfNeeded(chatId);
  }

  Future<void> editMessage(String messageId, String newContent) async {
    final userId = _firebase.currentUser?.uid;
    if (userId == null) throw Exception('Usuário não autenticado');

    // Verificar se a mensagem pertence ao usuário
    final messageDoc = await _firebase.firestore
        .collection('chat_messages')
        .doc(messageId)
        .get();

    if (!messageDoc.exists) {
      throw Exception('Mensagem não encontrada');
    }

    final messageData = messageDoc.data() as Map<String, dynamic>;
    if (messageData['sender_id'] != userId) {
      throw Exception('Você só pode editar suas próprias mensagens');
    }

    if (messageData['type'] != 'text') {
      throw Exception('Só é possível editar mensagens de texto');
    }

    // Atualizar o conteúdo da mensagem
    await _firebase.firestore
        .collection('chat_messages')
        .doc(messageId)
        .update({
      'content': newContent,
      'edited_at': FieldValue.serverTimestamp(),
      'is_edited': true,
    });

    // Atualizar última mensagem se for a mensagem mais recente
    await _updateLastMessageIfNeeded(messageData['chat_id']);
  }

  Future<void> _updateLastMessageIfNeeded(String chatId) async {
    // Buscar a última mensagem não deletada
    final lastMessageSnapshot = await _firebase.firestore
        .collection('chat_messages')
        .where('chat_id', isEqualTo: chatId)
        .where('is_deleted', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (lastMessageSnapshot.docs.isNotEmpty) {
      final lastMessage = lastMessageSnapshot.docs.first.data();
      await _firebase.firestore.collection('chats').doc(chatId).update({
        'last_message': {
          'text': lastMessage['content'],
          'sender_id': lastMessage['sender_id'],
          'timestamp': lastMessage['timestamp'],
          'type': lastMessage['type']
        },
        'updated_at': FieldValue.serverTimestamp(),
      });
    } else {
      // Não há mensagens, limpar última mensagem
      await _firebase.firestore.collection('chats').doc(chatId).update({
        'last_message': {},
        'updated_at': FieldValue.serverTimestamp(),
      });
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

    // Buscar dados do gerente através do projeto
    Map<String, dynamic> managerData = {};
    final projectId = inspectionData['project_id'];
    if (projectId != null) {
      final projectDoc = await _firebase.firestore
          .collection('projects')
          .doc(projectId)
          .get();
          
      if (projectDoc.exists) {
        final projectData = projectDoc.data() as Map<String, dynamic>;
        final managerId = projectData['manager_id'];
        
        if (managerId != null) {
          final managerDoc = await _firebase.firestore
              .collection('managers')
              .doc(managerId)
              .get();
          
          if (managerDoc.exists) {
            final manager = managerDoc.data() as Map<String, dynamic>;
            managerData = {
              'id': managerId,
              'name': manager['name'] ?? '',
              'last_name': manager['last_name'] ?? '',
              'profileImageUrl': manager['profileImageUrl']
            };
          }
        }
      }
    }

    final chatRef = await _firebase.firestore.collection('chats').add({
      'inspection_id': inspectionId,
      'inspection': {
        'id': inspectionId,
        'title': inspectionData['title'] ?? 'Inspeção',
        'cod': inspectionData['cod'] ?? 'COD-000'
      },
      'inspector': {
        'id': userId,
        'name': inspectorData['name'] ?? '',
        'last_name': inspectorData['last_name'] ?? '',
        'profileImageUrl': inspectorData['profileImageUrl']
      },
      'manager': managerData,
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
