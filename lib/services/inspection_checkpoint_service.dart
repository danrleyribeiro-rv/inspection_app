// lib/services/inspection_checkpoint_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Esta classe representa um checkpoint da inspeção
class InspectionCheckpoint {
  final String id;
  final String inspectionId;
  final String createdBy;
  final DateTime createdAt;
  final String? message;
  final Map<String, dynamic>? data; // Dados completos para restauração

  InspectionCheckpoint({
    required this.id,
    required this.inspectionId,
    required this.createdBy,
    required this.createdAt,
    this.message,
    this.data,
  });

  String get formattedDate => DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
}

class InspectionCheckpointService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Método para criar um checkpoint da inspeção
  Future<void> createCheckpoint({
    required String inspectionId,
    String? message,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('Usuário não autenticado');

    // Obter todas as salas, itens e detalhes para criar um snapshot completo
    final checkpointData = await _createInspectionSnapshot(inspectionId);

    // Salvar o checkpoint
    await _firestore.collection('inspection_checkpoints').add({
      'inspection_id': inspectionId,
      'created_by': userId,
      'created_at': FieldValue.serverTimestamp(),
      'message': message,
      'snapshot_data': checkpointData, // Dados completos da inspeção
    });
    
    // Atualizar a inspeção com a informação do último checkpoint
    await _firestore.collection('inspections').doc(inspectionId).update({
      'last_checkpoint_at': FieldValue.serverTimestamp(),
      'last_checkpoint_message': message,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
  
  // Método para obter os checkpoints de uma inspeção
  Future<List<InspectionCheckpoint>> getCheckpoints(String inspectionId) async {
    final snapshot = await _firestore
        .collection('inspection_checkpoints')
        .where('inspection_id', isEqualTo: inspectionId)
        .orderBy('created_at', descending: true)
        .get();
        
    return snapshot.docs.map((doc) {
      final data = doc.data();
      
      DateTime createdAt;
      if (data['created_at'] is Timestamp) {
        createdAt = (data['created_at'] as Timestamp).toDate();
      } else {
        createdAt = DateTime.now(); // Fallback
      }
      
      return InspectionCheckpoint(
        id: doc.id,
        inspectionId: data['inspection_id'],
        createdBy: data['created_by'],
        createdAt: createdAt,
        message: data['message'],
        data: data['snapshot_data'],
      );
    }).toList();
  }

  // Obtém um checkpoint específico pelo ID
  Future<InspectionCheckpoint?> getCheckpointById(String checkpointId) async {
    try {
      final doc = await _firestore.collection('inspection_checkpoints').doc(checkpointId).get();
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      
      DateTime createdAt;
      if (data['created_at'] is Timestamp) {
        createdAt = (data['created_at'] as Timestamp).toDate();
      } else {
        createdAt = DateTime.now(); // Fallback
      }
      
      return InspectionCheckpoint(
        id: doc.id,
        inspectionId: data['inspection_id'],
        createdBy: data['created_by'],
        createdAt: createdAt,
        message: data['message'],
        data: data['snapshot_data'],
      );
    } catch (e) {
      print('Erro ao buscar checkpoint: $e');
      return null;
    }
  }

  // Método para restaurar uma inspeção a partir de um checkpoint
  Future<bool> restoreFromCheckpoint(InspectionCheckpoint checkpoint) async {
    if (checkpoint.data == null) {
      throw Exception('Dados do checkpoint são nulos ou incompletos');
    }
    
    final inspectionId = checkpoint.inspectionId;
    final batch = _firestore.batch();
    final snapshot = checkpoint.data!;
    
    try {
      // 1. Limpar dados existentes
      await _clearInspectionData(inspectionId);
      
      // 2. Restaurar salas, itens e detalhes
      if (snapshot['rooms'] != null) {
        for (final roomData in snapshot['rooms']) {
          final roomId = roomData['id'];
          final roomRef = _firestore.collection('rooms').doc(roomId);
          
          // Remover campos que não devem ser restaurados
          final Map<String, dynamic> cleanRoomData = {...roomData};
          cleanRoomData.remove('id');
          cleanRoomData.remove('items');
          
          // Adicionar campos de registro da restauração
          cleanRoomData['restored_from_checkpoint'] = checkpoint.id;
          cleanRoomData['restored_at'] = FieldValue.serverTimestamp();
          
          batch.set(roomRef, cleanRoomData);
          
          // Restaurar itens desta sala
          if (roomData['items'] != null) {
            for (final itemData in roomData['items']) {
              final itemId = itemData['id'];
              final itemRef = _firestore.collection('room_items').doc(itemId);
              
              // Remover campos que não devem ser restaurados
              final Map<String, dynamic> cleanItemData = {...itemData};
              cleanItemData.remove('id');
              cleanItemData.remove('details');
              
              // Adicionar campos de registro da restauração
              cleanItemData['restored_from_checkpoint'] = checkpoint.id;
              cleanItemData['restored_at'] = FieldValue.serverTimestamp();
              
              batch.set(itemRef, cleanItemData);
              
              // Restaurar detalhes deste item
              if (itemData['details'] != null) {
                for (final detailData in itemData['details']) {
                  final detailId = detailData['id'];
                  final detailRef = _firestore.collection('item_details').doc(detailId);
                  
                  // Remover apenas o ID e manter todos os outros campos
                  final Map<String, dynamic> cleanDetailData = {...detailData};
                  cleanDetailData.remove('id');
                  
                  // Adicionar campos de registro da restauração
                  cleanDetailData['restored_from_checkpoint'] = checkpoint.id;
                  cleanDetailData['restored_at'] = FieldValue.serverTimestamp();
                  
                  batch.set(detailRef, cleanDetailData);
                }
              }
            }
          }
        }
      }
      
      // 3. Restaurar não conformidades
      if (snapshot['non_conformities'] != null) {
        for (final ncData in snapshot['non_conformities']) {
          final ncId = ncData['id'];
          final ncRef = _firestore.collection('non_conformities').doc(ncId);
          
          // Remover campos que não devem ser restaurados
          final Map<String, dynamic> cleanNcData = {...ncData};
          cleanNcData.remove('id');
          
          // Adicionar campos de registro da restauração
          cleanNcData['restored_from_checkpoint'] = checkpoint.id;
          cleanNcData['restored_at'] = FieldValue.serverTimestamp();
          
          batch.set(ncRef, cleanNcData);
        }
      }
      
      // 4. Restaurar mídia (apenas metadados, não os arquivos físicos)
      if (snapshot['media'] != null) {
        for (final mediaData in snapshot['media']) {
          final mediaId = mediaData['id'];
          final mediaRef = _firestore.collection('media').doc(mediaId);
          
          // Remover campos que não devem ser restaurados
          final Map<String, dynamic> cleanMediaData = {...mediaData};
          cleanMediaData.remove('id');
          
          // Adicionar campos de registro da restauração
          cleanMediaData['restored_from_checkpoint'] = checkpoint.id;
          cleanMediaData['restored_at'] = FieldValue.serverTimestamp();
          
          batch.set(mediaRef, cleanMediaData);
        }
      }
      
      // 5. Atualizar o documento da inspeção
      final inspectionRef = _firestore.collection('inspections').doc(inspectionId);
      batch.update(inspectionRef, {
        'restored_from_checkpoint': checkpoint.id,
        'restored_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      // Executar o batch
      await batch.commit();
      
      return true;
    } catch (e) {
      print('Erro ao restaurar checkpoint: $e');
      return false;
    }
  }
  
  // Método para limpar os dados existentes da inspeção antes da restauração
  Future<void> _clearInspectionData(String inspectionId) async {
    // Buscar e remover detalhes
    final detailsSnapshot = await _firestore
        .collection('item_details')
        .where('inspection_id', isEqualTo: inspectionId)
        .get();
        
    for (final doc in detailsSnapshot.docs) {
      await doc.reference.delete();
    }
    
    // Buscar e remover itens
    final itemsSnapshot = await _firestore
        .collection('room_items')
        .where('inspection_id', isEqualTo: inspectionId)
        .get();
        
    for (final doc in itemsSnapshot.docs) {
      await doc.reference.delete();
    }
    
    // Buscar e remover salas
    final roomsSnapshot = await _firestore
        .collection('rooms')
        .where('inspection_id', isEqualTo: inspectionId)
        .get();
        
    for (final doc in roomsSnapshot.docs) {
      await doc.reference.delete();
    }
    
    // Buscar e remover não conformidades
    final nonConformitiesSnapshot = await _firestore
        .collection('non_conformities')
        .where('inspection_id', isEqualTo: inspectionId)
        .get();
        
    for (final doc in nonConformitiesSnapshot.docs) {
      await doc.reference.delete();
    }
    
    // Não removemos as mídias físicas, apenas os metadados
    final mediaSnapshot = await _firestore
        .collection('media')
        .where('inspection_id', isEqualTo: inspectionId)
        .get();
        
    for (final doc in mediaSnapshot.docs) {
      await doc.reference.delete();
    }
  }
  
  // Método privado para criar um snapshot completo da inspeção
// lib/services/inspection_checkpoint_service.dart
// No método _createInspectionSnapshot, modifique:

Future<Map<String, dynamic>> _createInspectionSnapshot(String inspectionId) async {
  // Buscar inspeção
  final inspectionDoc = await _firestore.collection('inspections').doc(inspectionId).get();
  if (!inspectionDoc.exists) throw Exception('Inspeção não encontrada');
  
  // Buscar salas
  final roomsSnapshot = await _firestore
      .collection('rooms')
      .where('inspection_id', isEqualTo: inspectionId)
      .get();
      
  final rooms = <Map<String, dynamic>>[];
  
  // Contadores para verificação
  int totalItems = 0;
  int totalDetails = 0;
  
  for (final roomDoc in roomsSnapshot.docs) {
    final roomData = roomDoc.data();
    final roomId = roomDoc.id;
    
    // Buscar itens desta sala
    final itemsSnapshot = await _firestore
        .collection('room_items')
        .where('room_id', isEqualTo: roomId)
        .get();
        
    final items = <Map<String, dynamic>>[];
    
    for (final itemDoc in itemsSnapshot.docs) {
      final itemData = itemDoc.data();
      final itemId = itemDoc.id;
      totalItems++;
      
      // Buscar detalhes deste item
      final detailsSnapshot = await _firestore
          .collection('item_details')
          .where('item_id', isEqualTo: itemId)
          .get();
          
      final details = <Map<String, dynamic>>[];
      
      for (final detailDoc in detailsSnapshot.docs) {
        totalDetails++;
        final detailData = detailDoc.data();
        
        // Incluir todos os campos do detalhe, sem filtro
        details.add({
          'id': detailDoc.id,
          ...detailData,
        });
      }
      
      items.add({
        'id': itemId,
        ...itemData,
        'details': details,
      });
    }
    
    rooms.add({
      'id': roomId,
      ...roomData,
      'items': items,
    });
  }
  
  // Adicione logs para verificação
  print('Checkpoint snapshot: Total de salas: ${rooms.length}');
  print('Checkpoint snapshot: Total de itens: $totalItems');
  print('Checkpoint snapshot: Total de detalhes: $totalDetails');
  
  // Buscar não conformidades
  final nonConformitiesSnapshot = await _firestore
      .collection('non_conformities')
      .where('inspection_id', isEqualTo: inspectionId)
      .get();
      
  final nonConformities = nonConformitiesSnapshot.docs.map((doc) {
    return {
      'id': doc.id,
      ...doc.data(),
    };
  }).toList();
  
  // Buscar mídia
  final mediaSnapshot = await _firestore
      .collection('media')
      .where('inspection_id', isEqualTo: inspectionId)
      .get();
      
  final media = mediaSnapshot.docs.map((doc) {
    return {
      'id': doc.id,
      ...doc.data(),
    };
  }).toList();
  
  return {
    'inspection': {
      'id': inspectionId,
      ...inspectionDoc.data() ?? {},
    },
    'rooms': rooms,
    'non_conformities': nonConformities,
    'media': media,
  };
}  
  // Exclui um checkpoint
  Future<bool> deleteCheckpoint(String checkpointId) async {
    try {
      await _firestore.collection('inspection_checkpoints').doc(checkpointId).delete();
      return true;
    } catch (e) {
      print('Erro ao excluir checkpoint: $e');
      return false;
    }
  }
  
  // Obtém o último checkpoint de uma inspeção
  Future<InspectionCheckpoint?> getLastCheckpoint(String inspectionId) async {
    try {
      final snapshot = await _firestore
          .collection('inspection_checkpoints')
          .where('inspection_id', isEqualTo: inspectionId)
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();
          
      if (snapshot.docs.isEmpty) return null;
      
      final doc = snapshot.docs.first;
      final data = doc.data();
      
      DateTime createdAt;
      if (data['created_at'] is Timestamp) {
        createdAt = (data['created_at'] as Timestamp).toDate();
      } else {
        createdAt = DateTime.now(); // Fallback
      }
      
      return InspectionCheckpoint(
        id: doc.id,
        inspectionId: data['inspection_id'],
        createdBy: data['created_by'],
        createdAt: createdAt,
        message: data['message'],
        data: data['snapshot_data'],
      );
    } catch (e) {
      print('Erro ao buscar último checkpoint: $e');
      return null;
    }
  }
  
  // Compara o estado atual com um checkpoint para verificar diferenças
  Future<Map<String, dynamic>> compareWithCheckpoint(String inspectionId, String checkpointId) async {
    try {
      // Obter o checkpoint
      final checkpoint = await getCheckpointById(checkpointId);
      if (checkpoint == null || checkpoint.data == null) {
        throw Exception('Checkpoint não encontrado ou dados incompletos');
      }
      
      // Obter snapshot atual
      final currentSnapshot = await _createInspectionSnapshot(inspectionId);
      
      // Comparar número de salas
      final checkpointRooms = checkpoint.data!['rooms'] as List<dynamic>? ?? [];
      final currentRooms = currentSnapshot['rooms'] as List<dynamic>? ?? [];
      
      // Comparar número de itens e detalhes
      int checkpointItemsCount = 0;
      int currentItemsCount = 0;
      int checkpointDetailsCount = 0;
      int currentDetailsCount = 0;
      
      for (final room in checkpointRooms) {
        final items = room['items'] as List<dynamic>? ?? [];
        checkpointItemsCount += items.length;
        
        for (final item in items) {
          final details = item['details'] as List<dynamic>? ?? [];
          checkpointDetailsCount += details.length;
        }
      }
      
      for (final room in currentRooms) {
        final items = room['items'] as List<dynamic>? ?? [];
        currentItemsCount += items.length;
        
        for (final item in items) {
          final details = item['details'] as List<dynamic>? ?? [];
          currentDetailsCount += details.length;
        }
      }
      
      // Comparar não conformidades
      final checkpointNCs = checkpoint.data!['non_conformities'] as List<dynamic>? ?? [];
      final currentNCs = currentSnapshot['non_conformities'] as List<dynamic>? ?? [];
      
      // Comparar mídia
      final checkpointMedia = checkpoint.data!['media'] as List<dynamic>? ?? [];
      final currentMedia = currentSnapshot['media'] as List<dynamic>? ?? [];
      
      return {
        'checkpoint_date': checkpoint.createdAt,
        'checkpoint_message': checkpoint.message,
        'rooms_diff': currentRooms.length - checkpointRooms.length,
        'items_diff': currentItemsCount - checkpointItemsCount,
        'details_diff': currentDetailsCount - checkpointDetailsCount,
        'non_conformities_diff': currentNCs.length - checkpointNCs.length,
        'media_diff': currentMedia.length - checkpointMedia.length,
      };
    } catch (e) {
      print('Erro ao comparar com checkpoint: $e');
      return {
        'error': e.toString(),
      };
    }
  }
}