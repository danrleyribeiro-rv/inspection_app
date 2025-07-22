import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/services/storage/sqlite_storage_service.dart'; // Use SQLiteStorageService

class DetailService {
  final SQLiteStorageService _localStorage =
      SQLiteStorageService.instance; // Use SQLiteStorageService

  Future<List<Detail>> getDetails(
      String inspectionId, String topicId, String itemId) async {
    final inspection = await _localStorage.getInspection(inspectionId);
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));
    if (inspection?.topics != null &&
        topicIndex != null &&
        itemIndex != null &&
        topicIndex < inspection!.topics!.length) {
      final topic = inspection.topics![topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      if (itemIndex < items.length) {
        final itemData = items[itemIndex];
        return _extractDetails(inspectionId, topicId, itemId, itemData);
      }
    }

    return [];
  }

  Future<Detail> addDetail(
    String inspectionId,
    String topicId,
    String itemId,
    String detailName, {
    String? type,
    List<String>? options,
    String? detailValue,
    String? observation,
    bool? isDamaged,
  }) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));
    if (topicIndex == null || itemIndex == null) {
      throw Exception('Invalid topic or item ID');
    }

    final existingDetails = await getDetails(inspectionId, topicId, itemId);
    final newPosition = existingDetails.length;

    final newDetailData = {
      'name': detailName,
      'type': type ?? 'text',
      'options': options,
      'value': detailValue,
      'observation': observation,
      'is_damaged': isDamaged ?? false,
      'required': false,
      'media': <Map<String, dynamic>>[],
      'non_conformities': <Map<String, dynamic>>[],
    };

    await _addDetailToItem(inspectionId, topicIndex, itemIndex, newDetailData);

    return Detail(
      id: 'detail_$newPosition',
      inspectionId: inspectionId,
      topicId: topicId,
      itemId: itemId,
      detailName: detailName,
      type: type ?? 'text',
      options: options,
      detailValue: detailValue,
      observation: observation,
      isDamaged: isDamaged ?? false,
      position: newPosition,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> updateDetail(Detail updatedDetail) async {
    final topicIndex =
        int.tryParse(updatedDetail.topicId?.replaceFirst('topic_', '') ?? '');
    final itemIndex =
        int.tryParse(updatedDetail.itemId?.replaceFirst('item_', '') ?? '');
    final detailIndex =
        int.tryParse(updatedDetail.id?.replaceFirst('detail_', '') ?? '');
    if (topicIndex != null && itemIndex != null && detailIndex != null) {
      final inspection =
          await _localStorage.getInspection(updatedDetail.inspectionId);
      if (inspection?.topics != null &&
          topicIndex < inspection!.topics!.length) {
        final topic = inspection.topics![topicIndex];
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          final item = items[itemIndex];
          final details =
              List<Map<String, dynamic>>.from(item['details'] ?? []);
          if (detailIndex < details.length) {
            final currentDetailData =
                Map<String, dynamic>.from(details[detailIndex]);
            currentDetailData['name'] = updatedDetail.detailName;
            currentDetailData['value'] = updatedDetail.detailValue;
            currentDetailData['observation'] = updatedDetail.observation;
            currentDetailData['is_damaged'] = updatedDetail.isDamaged ?? false;

            await _updateDetailAtIndex(updatedDetail.inspectionId, topicIndex,
                itemIndex, detailIndex, currentDetailData);
          }
        }
      }
    }
  }

  List<Detail> _extractDetails(String inspectionId, String topicId,
      String itemId, Map<String, dynamic> itemData) {
    final detailsData = itemData['details'] as List<dynamic>? ?? [];
    List<Detail> details = [];
    for (int i = 0; i < detailsData.length; i++) {
      final detailData = detailsData[i];
      if (detailData is Map<String, dynamic>) {
        List<String>? options;
        if (detailData['options'] is List) {
          options = List<String>.from(detailData['options']);
        }

        details.add(Detail(
          id: 'detail_$i',
          inspectionId: inspectionId,
          topicId: topicId,
          itemId: itemId,
          detailName: detailData['name'] ?? 'Detalhe ${i + 1}',
          type: detailData['type'] ?? 'text',
          options: options,
          detailValue: detailData['value'],
          observation: detailData['observation'],
          isDamaged: detailData['is_damaged'] ?? false,
          position: i,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }
    return details;
  }

  Future<void> _addDetailToItem(String inspectionId, int topicIndex,
      int itemIndex, Map<String, dynamic> newDetail) async {
    final inspection = await _localStorage.getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          final item = Map<String, dynamic>.from(items[itemIndex]);
          final details =
              List<Map<String, dynamic>>.from(item['details'] ?? []);
          details.add(newDetail);
          item['details'] = details;
          items[itemIndex] = item;
          topic['items'] = items;
          topics[topicIndex] = topic;
          final updatedInspection = inspection.copyWith(topics: topics, hasLocalChanges: true);
          // Use SQLiteStorageService to save locally and mark for sync
          await _localStorage.saveInspection(updatedInspection);
        }
      }
    }
  }

  Future<Detail> duplicateDetail(
    String inspectionId,
    String topicId,
    String itemId,
    Detail sourceDetail,
  ) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));
    if (topicIndex == null || itemIndex == null) {
      throw Exception('Invalid topic or item ID');
    }

    final inspection = await _localStorage.getInspection(inspectionId);
    if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
      final topic = inspection.topics![topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      if (itemIndex < items.length) {
        final item = items[itemIndex];
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);

        final duplicateDetailData = {
          'name': '${sourceDetail.detailName} (cópia)',
          'type': sourceDetail.type ?? 'text',
          'options': sourceDetail.options,
          'value': sourceDetail.detailValue,
          'observation': sourceDetail.observation,
          'is_damaged': sourceDetail.isDamaged ?? false,
          'required': false,
          'media': <Map<String, dynamic>>[],
          'non_conformities': <Map<String, dynamic>>[],
        };

        details.add(duplicateDetailData);
        item['details'] = details;
        items[itemIndex] = item;
        topic['items'] = items;

        final topics = List<Map<String, dynamic>>.from(inspection.topics!);
        topics[topicIndex] = topic;

        final updatedInspection = inspection.copyWith(topics: topics, hasLocalChanges: true);
        // Use SQLiteStorageService to save locally and mark for sync
        await _localStorage.saveInspection(updatedInspection);

        return Detail(
          id: 'detail_${details.length - 1}',
          inspectionId: inspectionId,
          topicId: topicId,
          itemId: itemId,
          detailName: '${sourceDetail.detailName} (cópia)',
          type: sourceDetail.type,
          options: sourceDetail.options,
          detailValue: sourceDetail.detailValue,
          observation: sourceDetail.observation,
          isDamaged: sourceDetail.isDamaged,
          position: details.length - 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    }

    throw Exception('Failed to duplicate detail');
  }

  Future<Detail?> isDetailDuplicate(String inspectionId, String topicId,
      String itemId, String detailName) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));
    if (topicIndex == null || itemIndex == null) return null;

    final inspection = await _localStorage.getInspection(inspectionId);
    if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
      final topic = inspection.topics![topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      if (itemIndex < items.length) {
        final item = items[itemIndex];
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);

        for (int i = 0; i < details.length; i++) {
          final detail = details[i];
          if (detail['name'] == detailName) {
            List<String>? options;
            if (detail['options'] is List) {
              options = List<String>.from(detail['options']);
            }

            return Detail(
              id: 'detail_$i',
              inspectionId: inspectionId,
              topicId: topicId,
              itemId: itemId,
              detailName: detail['name'] ?? 'Detalhe ${i + 1}',
              type: detail['type'] ?? 'text',
              options: options,
              detailValue: detail['value'],
              observation: detail['observation'],
              isDamaged: detail['is_damaged'] ?? false,
              position: i,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          }
        }
      }
    }

    return null;
  }

  Future<void> deleteDetail(String inspectionId, String topicId, String itemId,
      String detailId) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));
    final detailIndex = int.tryParse(detailId.replaceFirst('detail_', ''));
    if (topicIndex != null && itemIndex != null && detailIndex != null) {
      await _deleteDetailAtIndex(
          inspectionId, topicIndex, itemIndex, detailIndex);
    }
  }

  Future<void> _deleteDetailAtIndex(String inspectionId, int topicIndex,
      int itemIndex, int detailIndex) async {
    final inspection = await _localStorage.getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          final item = Map<String, dynamic>.from(items[itemIndex]);
          final details =
              List<Map<String, dynamic>>.from(item['details'] ?? []);
          if (detailIndex < details.length) {
            details.removeAt(detailIndex);
            item['details'] = details;
            items[itemIndex] = item;
            topic['items'] = items;
            topics[topicIndex] = topic;
            final updatedInspection = inspection.copyWith(topics: topics, hasLocalChanges: true);
            // Use SQLiteStorageService to save locally and mark for sync
            await _localStorage.saveInspection(updatedInspection);
          }
        }
      }
    }
  }

  Future<void> _updateDetailAtIndex(
      String inspectionId,
      int topicIndex,
      int itemIndex,
      int detailIndex,
      Map<String, dynamic> updatedDetail) async {
    final inspection = await _localStorage.getInspection(inspectionId);
    if (inspection != null && inspection.topics != null) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      if (topicIndex < topics.length) {
        final topic = Map<String, dynamic>.from(topics[topicIndex]);
        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (itemIndex < items.length) {
          final item = Map<String, dynamic>.from(items[itemIndex]);
          final details =
              List<Map<String, dynamic>>.from(item['details'] ?? []);
          if (detailIndex < details.length) {
            details[detailIndex] = updatedDetail;
            item['details'] = details;
            items[itemIndex] = item;
            topic['items'] = items;
            topics[topicIndex] = topic;
            final updatedInspection = inspection.copyWith(topics: topics, hasLocalChanges: true);
            // Use SQLiteStorageService to save locally and mark for sync
            await _localStorage.saveInspection(updatedInspection);
          }
        }
      }
    }
  }

  // NOVO MÉTODO ADICIONADO
  Future<void> reorderDetails(String inspectionId, String topicId,
      String itemId, int oldIndex, int newIndex) async {
    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));
    if (topicIndex == null || itemIndex == null) return;

    final inspection = await _localStorage.getInspection(inspectionId);
    if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      final topic = Map<String, dynamic>.from(topics[topicIndex]);
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);

      if (itemIndex < items.length) {
        final item = Map<String, dynamic>.from(items[itemIndex]);
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);

        if (oldIndex < 0 ||
            oldIndex >= details.length ||
            newIndex < 0 ||
            newIndex > details.length) {
          return; // Índices inválidos
        }

        if (oldIndex < newIndex) {
          newIndex -= 1;
        }

        final detailToMove = details.removeAt(oldIndex);
        details.insert(newIndex, detailToMove);

        item['details'] = details;
        items[itemIndex] = item;
        topic['items'] = items;
        topics[topicIndex] = topic;

        final updatedInspection = inspection.copyWith(topics: topics, hasLocalChanges: true);
        // Use SQLiteStorageService to save locally and mark for sync
        await _localStorage.saveInspection(updatedInspection);
      }
    }
  }
}
