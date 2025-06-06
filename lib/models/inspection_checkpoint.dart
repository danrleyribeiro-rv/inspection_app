// lib/models/checkpoint/inspection_checkpoint.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class InspectionCheckpoint {
  final String id;
  final String inspectionId;
  final String createdBy;
  final DateTime createdAt;
  final String? message;
  final Map<String, dynamic>? data;

  InspectionCheckpoint({
    required this.id,
    required this.inspectionId,
    required this.createdBy,
    required this.createdAt,
    this.message,
    this.data,
  });

  String get formattedDate {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year;
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    
    return '$day/$month/$year $hour:$minute';
  }

  factory InspectionCheckpoint.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    DateTime createdAt;
    if (data['created_at'] is Timestamp) {
      createdAt = (data['created_at'] as Timestamp).toDate();
    } else {
      createdAt = DateTime.now();
    }
    
    return InspectionCheckpoint(
      id: doc.id,
      inspectionId: data['inspection_id'],
      createdBy: data['created_by'],
      createdAt: createdAt,
      message: data['message'],
      data: data['data'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'inspection_id': inspectionId,
      'created_by': createdBy,
      'created_at': Timestamp.fromDate(createdAt),
      'message': message,
      'data': data,
    };
  }
}