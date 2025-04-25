// lib/services/user_registration_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserRegistrationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Registrar um usuário e atribuir o papel de inspector
  Future<UserCredential> registerUser({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Criar o usuário no Firebase Authentication
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // 2. Atribuir a role "inspector" na tabela users
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'role': 'inspector',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      return userCredential;
    } catch (e) {
      print('Erro ao registrar usuário: $e');
      rethrow;
    }
  }
  
  // Registrar os dados do inspetor
  Future<void> registerInspector({
    required String userId,
    required String name,
    required String lastName,
    required String email,
    String? profession,
    String? document,
    String? phoneNumber,
    String? cep,
    String? street,
    String? neighborhood,
    String? city,
    String? state,
  }) async {
    try {
      // Criar o inspetor na coleção inspectors
      await _firestore.collection('inspectors').doc(userId).set({
        'user_id': userId,
        'name': name,
        'last_name': lastName,
        'email': email,
        'profession': profession,
        'document': document,
        'phonenumber': phoneNumber,
        'cep': cep,
        'street': street,
        'neighborhood': neighborhood,
        'city': city,
        'state': state,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'deleted_at': null,
      });
    } catch (e) {
      print('Erro ao registrar inspetor: $e');
      rethrow;
    }
  }
  
  // Função completa para registrar usuário e inspetor em uma única chamada
  Future<UserCredential> registerInspectorWithUserAccount({
    required String email,
    required String password,
    required String name,
    required String lastName,
    String? profession,
    String? document,
    String? phoneNumber,
    String? cep,
    String? street,
    String? neighborhood,
    String? city,
    String? state,
  }) async {
    try {
      // 1. Registrar o usuário com papel de inspetor
      final userCredential = await registerUser(
        email: email,
        password: password,
      );
      
      // 2. Registrar os dados do inspetor
      await registerInspector(
        userId: userCredential.user!.uid,
        name: name,
        lastName: lastName,
        email: email,
        profession: profession,
        document: document,
        phoneNumber: phoneNumber,
        cep: cep,
        street: street,
        neighborhood: neighborhood,
        city: city,
        state: state,
      );
      
      // 3. Registrar no user_roles para controle adicional
      await _firestore.collection('user_roles').doc(userCredential.user!.uid).set({
        'user_id': userCredential.user!.uid,
        'roles': ['inspector'],
        'created_at': FieldValue.serverTimestamp(),
      });
      
      return userCredential;
    } catch (e) {
      print('Erro ao registrar inspetor com conta de usuário: $e');
      rethrow;
    }
  }
  
  // Verificar se um email já está em uso
  Future<bool> isEmailInUse(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      print('Erro ao verificar email: $e');
      return false;
    }
  }
}