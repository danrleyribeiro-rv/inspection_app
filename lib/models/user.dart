// lib/models/user.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String email;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? profileImageUrl;

  User({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.profileImageUrl,
  });

  // Create User from Firestore document
  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return User(
      id: doc.id,
      email: data['email'] ?? '',
      role: data['role'] ?? 'user',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profileImageUrl: data['profileImageUrl'],
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'role': role,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'profileImageUrl': profileImageUrl,
    };
  }

  // Create a copy of this User with updated fields
  User copyWith({
    String? email,
    String? role,
    String? profileImageUrl,
  }) {
    return User(
      id: id,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}