// lib/models/chat_message.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final String type;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final List<String> readBy;
  final List<String> receivedBy;
  final DateTime? readByTimestamp;
  final bool isDeleted;
  final bool isEdited;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.type,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    List<String>? readBy,
    List<String>? receivedBy,
    this.readByTimestamp,
    this.isDeleted = false,
    this.isEdited = false,
    this.editedAt,
    this.deletedAt,
  })  : readBy = readBy ?? [],
        receivedBy = receivedBy ?? [];

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ChatMessage(
      id: doc.id,
      chatId: data['chat_id'] ?? '',
      senderId: data['sender_id'] ?? '',
      content: data['content'] ?? '',
      timestamp: _parseTimestamp(data['timestamp']) ?? DateTime.now(),
      type: data['type'] ?? 'text',
      fileUrl: data['file_url'],
      fileName: data['file_name'],
      fileSize: data['file_size'],
      readBy: data['read_by'] != null ? List<String>.from(data['read_by']) : [],
      receivedBy: data['received_by'] != null
          ? List<String>.from(data['received_by'])
          : [],
      readByTimestamp: _parseTimestamp(data['read_by_timestamp']),
      isDeleted: data['is_deleted'] ?? false,
      isEdited: data['is_edited'] ?? false,
      editedAt: _parseTimestamp(data['edited_at']),
      deletedAt: _parseTimestamp(data['deleted_at']),
    );
  }

  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is String) {
      return DateTime.parse(timestamp);
    } else if (timestamp is Map<String, dynamic>) {
      try {
        int seconds;
        int nanoseconds;

        // Handle new Firestore Timestamp format
        if (timestamp.containsKey('seconds') &&
            timestamp.containsKey('nanoseconds')) {
          seconds = timestamp['seconds'] as int;
          nanoseconds = timestamp['nanoseconds'] as int;
        }
        // Handle legacy format
        else if (timestamp.containsKey('_seconds') &&
            timestamp.containsKey('_nanoseconds')) {
          seconds = timestamp['_seconds'] as int;
          nanoseconds = timestamp['_nanoseconds'] as int;
        } else {
          return null;
        }

        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + (nanoseconds / 1000000).round(),
        );
      } catch (e) {
        debugPrint('Error parsing Firestore timestamp map: $e');
        return null;
      }
    } else if (timestamp.runtimeType.toString().contains('Timestamp')) {
      try {
        final toDateMethod = (timestamp as dynamic).toDate;
        return toDateMethod?.call();
      } catch (e) {
        debugPrint('Error parsing Timestamp object: $e');
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      'file_url': fileUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'read_by': readBy,
      'received_by': receivedBy,
      'is_deleted': isDeleted,
      'is_edited': isEdited,
      'edited_at': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'deleted_at': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  String getFormattedFileSize() {
    if (fileSize == null) return '';

    if (fileSize! < 1024) {
      return '$fileSize B';
    } else if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
