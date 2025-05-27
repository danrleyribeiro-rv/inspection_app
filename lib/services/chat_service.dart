// lib/services/chat_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:inspection_app/models/chat.dart';
import 'package:inspection_app/models/chat_message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Chat>> getUserChats() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => Chat.fromFirestore(doc)).toList());
  }
  
  Stream<List<ChatMessage>> getChatMessages(String chatId) {
    return _firestore
        .collection('chat_messages')
        .where('chat_id', isEqualTo: chatId)
        .orderBy('timestamp', descending: false) // Manter ascendente para ordem cronológica
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList());
  }
  
  Future<String> createOrGetChat(String inspectionId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('Usuário não autenticado');

    try {
      // Verificar se já existe um chat para esta inspeção
      final existingChats = await _firestore
          .collection('chats')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('participants', arrayContains: userId)
          .limit(1)
          .get();

      if (existingChats.docs.isNotEmpty) {
        return existingChats.docs.first.id;
      }

      // Buscar dados da inspeção
      final inspectionDoc = await _firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();
      
      if (!inspectionDoc.exists) {
        throw Exception('Inspeção não encontrada');
      }
      
      final inspectionData = inspectionDoc.data() as Map<String, dynamic>;

      // Buscar dados do inspetor
      final inspectorDoc = await _firestore
          .collection('inspectors')
          .doc(userId)
          .get();
      
      if (!inspectorDoc.exists) {
        throw Exception('Inspetor não encontrado');
      }

      final inspectorData = inspectorDoc.data() as Map<String, dynamic>;

      // Criar novo chat
      final chatRef = await _firestore.collection('chats').add({
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
        'participants': [userId], // Apenas o inspetor por enquanto
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'last_message': {},
        'unread_count': 0,
      });
      
      return chatRef.id;
    } catch (e) {
      throw Exception('Erro ao criar/obter chat: $e');
    }
  }
  
  Future<void> sendTextMessage(String chatId, String content) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('Usuário não autenticado');
    
    try {
      // Buscar participantes do chat
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
      
      await _firestore.collection('chat_messages').add({
        'chat_id': chatId,
        'sender_id': userId,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'received_by': [userId],
        'read_by': [userId],
      });
      
      // Calcular mensagens não lidas para outros participantes
      int unreadCount = 0;
      for (String participantId in participants) {
        if (participantId != userId) {
          final unreadMessages = await _firestore
              .collection('chat_messages')
              .where('chat_id', isEqualTo: chatId)
              .where('sender_id', isNotEqualTo: participantId)
              .get();
          
          int count = 0;
          for (var doc in unreadMessages.docs) {
            final readBy = List<String>.from(doc.data()['read_by'] ?? []);
            if (!readBy.contains(participantId)) {
              count++;
            }
          }
          unreadCount = count + 1;
          break;
        }
      }
      
      await _firestore.collection('chats').doc(chatId).update({
        'last_message': {
          'text': content,
          'sender_id': userId,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'text'
        },
        'updated_at': FieldValue.serverTimestamp(),
        'unread_count': unreadCount,
      });
    } catch (e) {
      throw Exception('Erro ao enviar mensagem: $e');
    }
  }
  
  Future<void> sendFileMessage(String chatId, File file, String type) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('Usuário não autenticado');
    
    final fileSize = await file.length();
    if (fileSize > 100 * 1024 * 1024) {
      throw Exception('O arquivo excede o limite de 100MB');
    }
    
    try {
      final fileName = path.basename(file.path);
      final uniqueId = const Uuid().v4();
      final storagePath = 'chats/$chatId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      final storageRef = _storage.ref().child(storagePath);
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      final fileExtension = path.extension(fileName).toLowerCase();
      final fileType = _getFileType(fileExtension);
      final displayText = 'Enviou um ${_getFileTypeDisplay(fileType)}';
      
      await _firestore.collection('chat_messages').add({
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
      
      await _firestore.collection('chats').doc(chatId).update({
        'last_message': {
          'text': displayText,
          'sender_id': userId,
          'timestamp': FieldValue.serverTimestamp(),
          'type': fileType
        },
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Erro ao enviar arquivo: $e');
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
      print('Erro ao contar mensagens não lidas: $e');
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

  Future<void> markMessagesAsRead(String chatId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    try {
      final snapshot = await _firestore
          .collection('chat_messages')
          .where('chat_id', isEqualTo: chatId)
          .where('sender_id', isNotEqualTo: userId)
          .get();
      
      final batch = _firestore.batch();
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
        
        await _firestore.collection('chats').doc(chatId).update({
          'unread_count': 0
        });
      }
    } catch (e) {
      throw Exception('Erro ao marcar mensagens como lidas: $e');
    }
  }

  String _getFileType(String extension) {
    if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(extension)) {
      return 'image';
    } else if (['.mp4', '.avi', '.mov', '.wmv', '.flv', '.mkv', '.webm'].contains(extension)) {
      return 'video';
    } else {
      return 'file';
    }
  }

  String _getFileTypeDisplay(String type) {
    switch (type) {
      case 'image': return 'imagem';
      case 'video': return 'vídeo';
      case 'file': return 'arquivo';
      default: return 'arquivo';
    }
  }
}