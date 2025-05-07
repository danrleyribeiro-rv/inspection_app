// lib/services/inspection_checkpoint_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class InspectionCheckpoint {
  final String id;
  final String inspectionId;
  final String createdBy;
  final DateTime createdAt;
  final String? message;
  final int completedItems;
  final int totalItems;
  final double completionPercentage;

  InspectionCheckpoint({
    required this.id,
    required this.inspectionId,
    required this.createdBy,
    required this.createdAt,
    this.message,
    required this.completedItems,
    required this.totalItems,
    required this.completionPercentage,
  });

  Map<String, dynamic> toJson() {
    return {
      'inspection_id': inspectionId,
      'created_by': createdBy,
      'created_at': createdAt,
      'message': message,
      'completed_items': completedItems,
      'total_items': totalItems,
      'completion_percentage': completionPercentage,
    };
  }

  factory InspectionCheckpoint.fromJson(String id, Map<String, dynamic> json) {
    DateTime createdAt;
    if (json['created_at'] is Timestamp) {
      createdAt = (json['created_at'] as Timestamp).toDate();
    } else if (json['created_at'] is String) {
      createdAt = DateTime.parse(json['created_at']);
    } else {
      createdAt = DateTime.now();
    }

    return InspectionCheckpoint(
      id: id,
      inspectionId: json['inspection_id'] ?? '',
      createdBy: json['created_by'] ?? '',
      createdAt: createdAt,
      message: json['message'],
      completedItems: json['completed_items'] ?? 0,
      totalItems: json['total_items'] ?? 0,
      completionPercentage: (json['completion_percentage'] ?? 0.0).toDouble(),
    );
  }

  String get formattedDate {
    return DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
  }
}

class InspectionCheckpointService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  InspectionCheckpointService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Cria um checkpoint para uma inspeção
  /// 
  /// [inspectionId] - ID da inspeção
  /// [message] - Mensagem opcional para o checkpoint
  /// [completedItems] - Número de itens completados (detalhes preenchidos)
  /// [totalItems] - Número total de itens na inspeção
  /// [completionPercentage] - Porcentagem de conclusão da inspeção (0-100)
  Future<InspectionCheckpoint?> createCheckpoint({
    required String inspectionId,
    String? message,
    required int completedItems,
    required int totalItems,
    required double completionPercentage,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      final checkpointData = {
        'inspection_id': inspectionId,
        'created_by': user.uid,
        'created_at': FieldValue.serverTimestamp(),
        'message': message,
        'completed_items': completedItems,
        'total_items': totalItems,
        'completion_percentage': completionPercentage,
      };

      // Salva no Firestore
      final docRef = await _firestore
          .collection('inspection_checkpoints')
          .add(checkpointData);

      // Atualiza também a informação do último checkpoint na coleção de inspeções
      await _firestore.collection('inspections').doc(inspectionId).update({
        'last_checkpoint_at': FieldValue.serverTimestamp(),
        'last_checkpoint_by': user.uid,
        'last_checkpoint_message': message,
        'last_checkpoint_completion': completionPercentage,
      });

      // Recupera o documento com o timestamp gerado pelo servidor
      final doc = await docRef.get();
      if (doc.exists) {
        return InspectionCheckpoint.fromJson(
          doc.id,
          doc.data() as Map<String, dynamic>,
        );
      }

      return null;
    } catch (e) {
      print('Erro ao criar checkpoint: $e');
      rethrow;
    }
  }

  /// Recupera todos os checkpoints de uma inspeção ordenados por data de criação
  Future<List<InspectionCheckpoint>> getCheckpoints(String inspectionId) async {
    try {
      final snapshots = await _firestore
          .collection('inspection_checkpoints')
          .where('inspection_id', isEqualTo: inspectionId)
          .orderBy('created_at', descending: true)
          .get();

      return snapshots.docs
          .map((doc) => InspectionCheckpoint.fromJson(
                doc.id,
                doc.data(),
              ))
          .toList();
    } catch (e) {
      print('Erro ao recuperar checkpoints: $e');
      return [];
    }
  }

/// Considera:
/// 1. Detalhes preenchidos (com valor ou marcados como danificados)
/// 2. Presença de mídia (fotos/vídeos) para cada item
/// 3. Observações preenchidas
/// 
/// Retorna o número de itens completados, o total de itens e a porcentagem de conclusão
Future<Map<String, dynamic>> getInspectionProgress(String inspectionId) async {
  try {
    // Contadores para o progresso
    int completedDetails = 0;
    int totalDetails = 0;
    int itemsWithMedia = 0;
    int totalItems = 0;
    
    // Peso para cada componente do progresso (ajuste conforme necessário)
    const double DETAIL_VALUE_WEIGHT = 0.6; // 60% do progresso vem de detalhes preenchidos
    const double MEDIA_WEIGHT = 0.4; // 40% do progresso vem de mídia

    // Recupera todas as salas da inspeção
    final roomsSnapshot = await _firestore
        .collection('rooms')
        .where('inspection_id', isEqualTo: inspectionId)
        .get();

    // Para cada sala, recupera seus itens
    for (var roomDoc in roomsSnapshot.docs) {
      final roomId = roomDoc.id;
      
      final itemsSnapshot = await _firestore
          .collection('room_items')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: roomId)
          .get();
      
      totalItems += itemsSnapshot.docs.length;

      // Para cada item, verifica mídia e detalhes
      for (var itemDoc in itemsSnapshot.docs) {
        final itemId = itemDoc.id;
        // 1. Verificar se o item tem mídia associada
        final mediaSnapshot = await _firestore
            .collection('media')
            .where('inspection_id', isEqualTo: inspectionId)
            .where('room_id', isEqualTo: roomId)
            .where('room_item_id', isEqualTo: itemId)
            .limit(1) // Precisamos apenas saber se existe pelo menos um
            .get();
        
        if (mediaSnapshot.docs.isNotEmpty) {
          itemsWithMedia++;
        }
        
        // 2. Verificar detalhes do item
        final detailsSnapshot = await _firestore
            .collection('item_details')
            .where('inspection_id', isEqualTo: inspectionId)
            .where('room_id', isEqualTo: roomId)
            .where('item_id', isEqualTo: itemId)
            .get();

        final detailsCount = detailsSnapshot.docs.length;
        totalDetails += detailsCount;
        
        // Contar detalhes completados
        for (var detailDoc in detailsSnapshot.docs) {
          final detail = detailDoc.data();
          
          // Um detalhe é considerado completado se:
          // 1. Tem valor preenchido, OU
          // 2. Está marcado como danificado, OU
          // 3. Tem observação preenchida
          if ((detail['detail_value'] != null && detail['detail_value'].toString().isNotEmpty) ||
              detail['is_damaged'] == true ||
              (detail['observation'] != null && detail['observation'].toString().isNotEmpty)) {
            completedDetails++;
          }
        }
      }
    }

    // Calcular as pontuações parciais
    double detailsScore = 0;
    if (totalDetails > 0) {
      detailsScore = (completedDetails / totalDetails) * DETAIL_VALUE_WEIGHT;
    }
    
    double mediaScore = 0;
    if (totalItems > 0) {
      mediaScore = (itemsWithMedia / totalItems) * MEDIA_WEIGHT;
    }
    
    // Calcular pontuação total (porcentagem de conclusão)
    final completionPercentage = (detailsScore + mediaScore) * 100;
    
    // Logs para depuração (opcional)
    print('Progresso da inspeção $inspectionId:');
    print('  Detalhes completados: $completedDetails / $totalDetails');
    print('  Itens com mídia: $itemsWithMedia / $totalItems');
    print('  Pontuação detalhes: ${detailsScore * 100}%');
    print('  Pontuação mídia: ${mediaScore * 100}%');
    print('  Progresso total: ${completionPercentage.toStringAsFixed(1)}%');

    return {
      'completed_items': completedDetails,
      'total_items': totalDetails,
      'items_with_media': itemsWithMedia,
      'total_items_for_media': totalItems,
      'completion_percentage': double.parse(completionPercentage.toStringAsFixed(1)),
      'details_score': detailsScore,
      'media_score': mediaScore,
    };
  } catch (e) {
    print('Erro ao calcular progresso da inspeção: $e');
    return {
      'completed_items': 0,
      'total_items': 0,
      'items_with_media': 0,
      'total_items_for_media': 0,
      'completion_percentage': 0.0,
      'details_score': 0.0,
      'media_score': 0.0,
    };
  }
}

  /// Exclui um checkpoint
  Future<bool> deleteCheckpoint(String checkpointId) async {
    try {
      await _firestore
          .collection('inspection_checkpoints')
          .doc(checkpointId)
          .delete();
      return true;
    } catch (e) {
      print('Erro ao excluir checkpoint: $e');
      return false;
    }
  }
}