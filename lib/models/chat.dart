// lib/models/chat.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final String inspectionId;
  final Map<String, dynamic> inspection;
  final Map<String, dynamic> inspector;
  final List<String> participants;
  final Map<String, dynamic> lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String>? mutedBy;
  final int unreadCount;

  Chat({
    required this.id,
    required this.inspectionId,
    required this.inspection,
    required this.inspector,
    required this.participants,
    required this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
    this.mutedBy,
    this.unreadCount = 0,
  });

  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Chat(
      id: doc.id,
      inspectionId: data['inspection_id'] ?? '',
      inspection: data['inspection'] ?? {},
      inspector: data['inspector'] ?? {},
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['last_message'] ?? {},
      createdAt: _parseTimestamp(data['created_at']),
      updatedAt: _parseTimestamp(data['updated_at']),
      mutedBy: data['muted_by'] != null ? List<String>.from(data['muted_by']) : null,
      unreadCount: data['unread_count'] ?? 0,
    );
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String) return DateTime.parse(timestamp);
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'inspection_id': inspectionId,
      'inspection': inspection,
      'inspector': inspector,
      'participants': participants,
      'last_message': lastMessage,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'muted_by': mutedBy,
      'unread_count': unreadCount,
    };
  }
}