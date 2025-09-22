import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Gerenciador de tokens para Firebase Storage
/// Implementa lógica similar ao update-cloudurl-unified.js
class FirebaseTokenManager {
  static const String _projectId = 'inspection-app-2025';

  /// Extrai informações de uma URL do Firebase Storage
  static Map<String, dynamic>? extractStorageInfo(String firebaseUrl) {
    try {
      final uri = Uri.parse(firebaseUrl);

      if (!uri.host.contains('firebasestorage.googleapis.com')) {
        return null;
      }

      final pathParts = uri.pathSegments;
      if (pathParts.length < 6) return null;

      String bucket = pathParts[2];
      final objectPath = Uri.decodeComponent(pathParts[4]);

      // Corrigir bucket "undefined"
      if (bucket.contains('undefined') || bucket == 'undefined.firebasestorage.app') {
        bucket = '$_projectId.firebasestorage.app';
      }

      final currentToken = uri.queryParameters['token'];

      return {
        'bucket': bucket,
        'objectPath': objectPath,
        'currentToken': currentToken,
        'baseUrl': 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(objectPath)}?alt=media',
        'needsCorrection': bucket != pathParts[2],
      };
    } catch (e) {
      debugPrint('FirebaseTokenManager: Erro ao extrair informações da URL: $e');
      return null;
    }
  }

  /// Verifica se uma URL do Firebase Storage é válida
  static Future<bool> verifyStorageUrl(String cloudUrl) async {
    try {
      final response = await http.head(Uri.parse(cloudUrl));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('FirebaseTokenManager: Erro ao verificar URL: $e');
      return false;
    }
  }

  /// Gera um novo token de acesso para um arquivo
  static Future<String?> generateNewToken(String bucket, String objectPath) async {
    try {
      final storage = FirebaseStorage.instance;
      final ref = storage.refFromURL('gs://$bucket/$objectPath');

      // Verificar se o arquivo existe
      try {
        await ref.getMetadata();
      } catch (e) {
        debugPrint('FirebaseTokenManager: Arquivo não encontrado: $objectPath');
        return null;
      }

      // Gerar novo token de download
      final downloadUrl = await ref.getDownloadURL();
      final uri = Uri.parse(downloadUrl);
      return uri.queryParameters['token'];
    } catch (e) {
      debugPrint('FirebaseTokenManager: Erro ao gerar novo token: $e');
      return null;
    }
  }

  /// Obtém um token válido para um arquivo
  static Future<String?> getValidToken(String bucket, String objectPath) async {
    try {
      final storage = FirebaseStorage.instance;
      final ref = storage.refFromURL('gs://$bucket/$objectPath');

      // Obter metadata do arquivo
      final metadata = await ref.getMetadata();

      // Verificar se já tem token nos metadados customizados
      final existingToken = metadata.customMetadata?['firebaseStorageDownloadTokens'];
      if (existingToken != null && existingToken.isNotEmpty) {
        final tokens = existingToken.split(',');
        return tokens.first;
      }

      // Se não tem token, gerar um novo
      return await generateNewToken(bucket, objectPath);
    } catch (e) {
      // Arquivo não existe ou erro de acesso - retorna null silenciosamente
      return null;
    }
  }

  /// Constrói uma nova URL com token correto
  static String buildNewUrl(String baseUrl, String token) {
    return '$baseUrl&token=$token';
  }

  /// Verifica e corrige uma URL do Firebase Storage se necessário
  static Future<String?> validateAndFixStorageUrl(String cloudUrl) async {
    try {
      // Extrair informações da URL
      final urlInfo = extractStorageInfo(cloudUrl);
      if (urlInfo == null) {
        return null;
      }

      final bucket = urlInfo['bucket'] as String;
      final objectPath = urlInfo['objectPath'] as String;
      final currentToken = urlInfo['currentToken'] as String?;
      final baseUrl = urlInfo['baseUrl'] as String;
      final needsCorrection = urlInfo['needsCorrection'] as bool;

      // Se precisa corrigir o bucket ou não tem token, tenta corrigir
      if (needsCorrection || currentToken == null || currentToken.isEmpty) {
        final validToken = await getValidToken(bucket, objectPath);
        if (validToken != null) {
          final newUrl = buildNewUrl(baseUrl, validToken);
          return newUrl;
        }
      } else {
        // Se tem token, assume que está válida (evita verificações HTTP desnecessárias)
        return cloudUrl;
      }

      return null;
    } catch (e) {
      // Retorna a URL original em caso de erro (evita quebrar upload)
      return cloudUrl;
    }
  }

  /// Gera uma URL de download para um caminho específico
  static Future<String?> generateDownloadUrl(String inspectionId, String filename, String type) async {
    try {
      final storagePath = 'inspections/$inspectionId/media/$type/$filename';
      final storage = FirebaseStorage.instance;
      final ref = storage.ref().child(storagePath);

      // Verificar se o arquivo existe (sem log de erro para arquivos inexistentes)
      try {
        await ref.getMetadata();
      } catch (e) {
        // Arquivo não existe - retorna null silenciosamente
        return null;
      }

      // Gerar URL de download
      final downloadUrl = await ref.getDownloadURL();
      debugPrint('FirebaseTokenManager: URL gerada para $filename: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('FirebaseTokenManager: Erro ao gerar URL de download: $e');
      return null;
    }
  }
}