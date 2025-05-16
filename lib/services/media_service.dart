// lib/services/media_service.dart (novo arquivo)
import 'package:cloud_firestore/cloud_firestore.dart';

class MediaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Busca todas as mídias da inspeção navegando pelas subcoleções
  Future<List<Map<String, dynamic>>> getAllMedia(String inspectionId) async {
    List<Map<String, dynamic>> allMedia = [];

    try {
      // Buscar todos os tópicos
      final topicsSnapshot = await _firestore
          .collection('inspections')
          .doc(inspectionId)
          .collection('topics')
          .get();

      // Para cada tópico
      for (var topicDoc in topicsSnapshot.docs) {
        final topicId = topicDoc.id;
        final topicData = topicDoc.data();
        final topicName = topicData['topic_name'] ?? '';

        // Buscar todos os itens
        final itemsSnapshot = await _firestore
            .collection('inspections')
            .doc(inspectionId)
            .collection('topics')
            .doc(topicId)
            .collection('topic_items')
            .get();

        // Para cada item
        for (var itemDoc in itemsSnapshot.docs) {
          final itemId = itemDoc.id;
          final itemData = itemDoc.data();
          final itemName = itemData['item_name'] ?? '';

          // Buscar todos os detalhes
          final detailsSnapshot = await _firestore
              .collection('inspections')
              .doc(inspectionId)
              .collection('topics')
              .doc(topicId)
              .collection('topic_items')
              .doc(itemId)
              .collection('item_details')
              .get();

          // Para cada detalhe
          for (var detailDoc in detailsSnapshot.docs) {
            final detailId = detailDoc.id;
            final detailData = detailDoc.data();
            final detailName = detailData['detail_name'] ?? '';
            final isDamaged = detailData['is_damaged'] ?? false;

            // Buscar todas as mídias regulares
            final mediaSnapshot = await _firestore
              .collection('inspections')
              .doc(inspectionId)
              .collection('topics')
              .doc(topicId)
              .collection('topic_items')
              .doc(itemId)
              .collection('item_details')
              .doc(detailId)
              .collection('media')
              .get();

            // Processar cada mídia regular
            for (var mediaDoc in mediaSnapshot.docs) {
              final mediaId = mediaDoc.id;
              final mediaData = mediaDoc.data();
              
              allMedia.add({
                'id': mediaId,
                'inspection_id': inspectionId,
                'topic_id': topicId,
                'topic_item_id': itemId,
                'detail_id': detailId,
                'topic_name': topicName,
                'item_name': itemName,
                'detail_name': detailName,
                'is_damaged': isDamaged,
                ...mediaData,
              });
            }

            // Buscar não-conformidades e suas mídias
            final nonConformitiesSnapshot = await _firestore
              .collection('inspections')
              .doc(inspectionId)
              .collection('topics')
              .doc(topicId)
              .collection('topic_items')
              .doc(itemId)
              .collection('item_details')
              .doc(detailId)
              .collection('non_conformities')
              .get();

            // Para cada não-conformidade
            for (var ncDoc in nonConformitiesSnapshot.docs) {
              final ncId = ncDoc.id;
              final ncData = ncDoc.data();
              
              // Buscar mídias da não-conformidade
              final ncMediaSnapshot = await _firestore
                .collection('inspections')
                .doc(inspectionId)
                .collection('topics')
                .doc(topicId)
                .collection('topic_items')
                .doc(itemId)
                .collection('item_details')
                .doc(detailId)
                .collection('non_conformities')
                .doc(ncId)
                .collection('nc_media')
                .get();

              // Processar cada mídia de não-conformidade
              for (var ncMediaDoc in ncMediaSnapshot.docs) {
                final ncMediaId = ncMediaDoc.id;
                final ncMediaData = ncMediaDoc.data();
                
                // Construir um ID composto para a não-conformidade
                final nonConformityId = '$inspectionId-$topicId-$itemId-$detailId-$ncId';
                
                allMedia.add({
                  'id': ncMediaId,
                  'inspection_id': inspectionId,
                  'topic_id': topicId,
                  'topic_item_id': itemId,
                  'detail_id': detailId,
                  'non_conformity_id': nonConformityId,
                  'topic_name': topicName,
                  'item_name': itemName,
                  'detail_name': detailName,
                  'is_non_conformity': true,
                  ...ncMediaData,
                });
              }
            }
          }
        }
      }

      return allMedia;
    } catch (e) {
      print('Erro ao buscar mídias: $e');
      return [];
    }
  }

  // Filtra mídias por tópico, item, detalhe e outros critérios
  List<Map<String, dynamic>> filterMedia({
    required List<Map<String, dynamic>> allMedia,
    String? topicId,
    String? itemId,
    String? detailId,
    bool? isNonConformityOnly,
    String? mediaType,
  }) {
    return allMedia.where((media) {
      // Filtrar por tópico
      if (topicId != null && media['topic_id'] != topicId) {
        return false;
      }

      // Filtrar por item
      if (itemId != null && media['topic_item_id'] != itemId) {
        return false;
      }

      // Filtrar por detalhe
      if (detailId != null && media['detail_id'] != detailId) {
        return false;
      }

      // Filtrar apenas não-conformidades
      if (isNonConformityOnly == true && !(media['is_non_conformity'] == true)) {
        return false;
      }

      // Filtrar por tipo de mídia (imagem ou vídeo)
      if (mediaType != null && media['type'] != mediaType) {
        return false;
      }

      return true;
    }).toList();
  }

  // Deleta uma mídia específica conforme sua localização
  Future<void> deleteMedia(Map<String, dynamic> mediaItem) async {
    try {
      final inspectionId = mediaItem['inspection_id'];
      final topicId = mediaItem['topic_id'];
      final itemId = mediaItem['topic_item_id'];
      final detailId = mediaItem['detail_id'];
      final mediaId = mediaItem['id'];
      
      // Verificar se é uma mídia de não-conformidade
      if (mediaItem['is_non_conformity'] == true && mediaItem['non_conformity_id'] != null) {
        final parts = mediaItem['non_conformity_id'].toString().split('-');
        if (parts.length >= 5) {
          final ncId = parts[4];
          
          // Delete mídia de não-conformidade
          await _firestore
            .collection('inspections')
            .doc(inspectionId)
            .collection('topics')
            .doc(topicId)
            .collection('topic_items')
            .doc(itemId)
            .collection('item_details')
            .doc(detailId)
            .collection('non_conformities')
            .doc(ncId)
            .collection('nc_media')
            .doc(mediaId)
            .delete();
            
          return;
        }
      }
      
      // Delete mídia regular
      await _firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .collection('topic_items')
        .doc(itemId)
        .collection('item_details')
        .doc(detailId)
        .collection('media')
        .doc(mediaId)
        .delete();
    } catch (e) {
      print('Erro ao excluir mídia: $e');
      throw Exception('Não foi possível excluir a mídia: $e');
    }
  }

  // Atualiza uma mídia específica conforme sua localização
  Future<void> updateMedia(Map<String, dynamic> mediaItem, Map<String, dynamic> updates) async {
    try {
      final inspectionId = mediaItem['inspection_id'];
      final topicId = mediaItem['topic_id'];
      final itemId = mediaItem['topic_item_id'];
      final detailId = mediaItem['detail_id'];
      final mediaId = mediaItem['id'];
      
      // Prepara os dados da atualização
      final updateData = {
        ...updates,
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      // Remove campos que não devem ser atualizados
      updateData.remove('id');
      updateData.remove('inspection_id');
      updateData.remove('topic_id');
      updateData.remove('topic_item_id');
      updateData.remove('detail_id');
      
      // Verificar se é uma mídia de não-conformidade
      if (mediaItem['is_non_conformity'] == true && mediaItem['non_conformity_id'] != null) {
        final parts = mediaItem['non_conformity_id'].toString().split('-');
        if (parts.length >= 5) {
          final ncId = parts[4];
          
          // Atualiza mídia de não-conformidade
          await _firestore
            .collection('inspections')
            .doc(inspectionId)
            .collection('topics')
            .doc(topicId)
            .collection('topic_items')
            .doc(itemId)
            .collection('item_details')
            .doc(detailId)
            .collection('non_conformities')
            .doc(ncId)
            .collection('nc_media')
            .doc(mediaId)
            .update(updateData);
            
          return;
        }
      }
      
      // Atualiza mídia regular
      await _firestore
        .collection('inspections')
        .doc(inspectionId)
        .collection('topics')
        .doc(topicId)
        .collection('topic_items')
        .doc(itemId)
        .collection('item_details')
        .doc(detailId)
        .collection('media')
        .doc(mediaId)
        .update(updateData);
        
      // Atualiza o status de non-conformity no detalhe se necessário
      if (updates.containsKey('is_non_conformity')) {
        bool isNonConformity = updates['is_non_conformity'] == true;
        
        if (isNonConformity) {
          await _firestore
            .collection('inspections')
            .doc(inspectionId)
            .collection('topics')
            .doc(topicId)
            .collection('topic_items')
            .doc(itemId)
            .collection('item_details')
            .doc(detailId)
            .update({'is_damaged': true});
        }
      }
    } catch (e) {
      print('Erro ao atualizar mídia: $e');
      throw Exception('Não foi possível atualizar a mídia: $e');
    }
  }
}