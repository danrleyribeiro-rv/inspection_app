// lib/data/models/user.dart
class User {
  final String id;
  final String email;
  final String? name;
  final String? lastName;
  final String? role;
  final String? profession;
  final String? inspectorId;

  User({
    required this.id,
    required this.email,
    this.name,
    this.lastName,
    this.role = 'user',
    this.profession,
    this.inspectorId,
  });

  String get fullName => name != null && lastName != null 
      ? '$name $lastName' 
      : email;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'lastName': lastName,
      'role': role,
      'profession': profession,
      'inspectorId': inspectorId,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      lastName: json['lastName'],
      role: json['role'],
      profession: json['profession'],
      inspectorId: json['inspectorId'],
    );
  }
}