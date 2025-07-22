import 'package:lince_inspecoes/services/storage/sqlite_storage_service.dart'; // Use SQLiteStorageService
import 'package:uuid/uuid.dart';

class NonConformityService {
  final SQLiteStorageService _localStorage =
      SQLiteStorageService.instance; // Use SQLiteStorageService
  final Uuid _uuid = Uuid();

  Future<List<Map<String, dynamic>>> getNonConformitiesByInspection(
      String inspectionId) async {
    final inspection =
        await _localStorage.getInspection(inspectionId); // Get from SQLite
    if (inspection?.topics == null) return [];

    List<Map<String, dynamic>> nonConformities = [];

    for (int topicIndex = 0;
        topicIndex < inspection!.topics!.length;
        topicIndex++) {
      final topic = inspection.topics![topicIndex];
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);

      for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
        final item = items[itemIndex];
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);

        for (int detailIndex = 0; detailIndex < details.length; detailIndex++) {
          final detail = details[detailIndex];
          final ncList =
              List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);

          for (int ncIndex = 0; ncIndex < ncList.length; ncIndex++) {
            final nc = ncList[ncIndex];

            nonConformities.add({
              ...nc,
              'id': 'nc_$ncIndex',
              'inspection_id': inspectionId,
              'topic_id': 'topic_$topicIndex',
              'item_id': 'item_$itemIndex',
              'detail_id': 'detail_$detailIndex',
              'topics': {
                'topic_name': topic['name'],
                'id': 'topic_$topicIndex',
              },
              'topic_items': {
                'item_name': item['name'],
                'id': 'item_$itemIndex',
              },
              'item_details': {
                'detail_name': detail['name'],
                'id': 'detail_$detailIndex',
              },
            });
          }
        }
      }
    }

    return nonConformities;
  }

  Future<void> saveNonConformity(Map<String, dynamic> nonConformityData) async {
    final inspectionId = nonConformityData['inspection_id'];
    final topicId = nonConformityData['topic_id'];
    final itemId = nonConformityData['item_id'];
    final detailId = nonConformityData['detail_id'];

    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));
    final detailIndex = int.tryParse(detailId.replaceFirst('detail_', ''));

    if (topicIndex == null || itemIndex == null || detailIndex == null) {
      throw Exception('Invalid topic, item, or detail ID');
    }

    final nonConformityToSave = {
      'id': _uuid.v4(),
      'description': nonConformityData['description'],
      'severity': nonConformityData['severity'] ?? 'Média',
      'corrective_action': nonConformityData['corrective_action'],
      'status': nonConformityData['status'] ?? 'pendente',
      'media': <Map<String, dynamic>>[],
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _addNonConformityToDetail(
        inspectionId, topicIndex, itemIndex, detailIndex, nonConformityToSave);
  }

  Future<void> updateNonConformityStatus(
      String nonConformityId, String newStatus) async {
    final parts = nonConformityId.split('-');
    if (parts.length < 5) {
      throw Exception('Invalid non-conformity ID format');
    }

    final inspectionId = parts[0];
    final topicIndex = int.tryParse(parts[1].replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(parts[2].replaceFirst('item_', ''));
    final detailIndex = int.tryParse(parts[3].replaceFirst('detail_', ''));
    final ncIndex = int.tryParse(parts[4].replaceFirst('nc_', ''));

    if (topicIndex == null ||
        itemIndex == null ||
        detailIndex == null ||
        ncIndex == null) {
      throw Exception('Invalid non-conformity ID indices');
    }

    final inspection =
        await _localStorage.getInspection(inspectionId); // Get from SQLite
    if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      final topic = Map<String, dynamic>.from(topics[topicIndex]);
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);

      if (itemIndex < items.length) {
        final item = Map<String, dynamic>.from(items[itemIndex]);
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);

        if (detailIndex < details.length) {
          final detail = Map<String, dynamic>.from(details[detailIndex]);
          final nonConformities =
              List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);

          if (ncIndex < nonConformities.length) {
            final nc = Map<String, dynamic>.from(nonConformities[ncIndex]);
            nc['status'] = newStatus;
            nc['updated_at'] = DateTime.now().toIso8601String();

            nonConformities[ncIndex] = nc;
            detail['non_conformities'] = nonConformities;
            details[detailIndex] = detail;
            item['details'] = details;
            items[itemIndex] = item;
            topic['items'] = items;
            topics[topicIndex] = topic;

            await _localStorage.saveInspection(
                inspection.copyWith(topics: topics, hasLocalChanges: true)); // Save to SQLite
          }
        }
      }
    }
  }

  Future<void> updateNonConformity(
      String nonConformityId, Map<String, dynamic> updatedData) async {
    final parts = nonConformityId.split('-');
    if (parts.length < 5) {
      throw Exception('Invalid non-conformity ID format');
    }

    final inspectionId = parts[0];
    final topicIndex = int.tryParse(parts[1].replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(parts[2].replaceFirst('item_', ''));
    final detailIndex = int.tryParse(parts[3].replaceFirst('detail_', ''));
    final ncIndex = int.tryParse(parts[4].replaceFirst('nc_', ''));

    if (topicIndex == null ||
        itemIndex == null ||
        detailIndex == null ||
        ncIndex == null) {
      throw Exception('Invalid non-conformity ID indices');
    }

    final inspection =
        await _localStorage.getInspection(inspectionId); // Get from SQLite
    if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      final topic = Map<String, dynamic>.from(topics[topicIndex]);
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);

      if (itemIndex < items.length) {
        final item = items[itemIndex];
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);

        if (detailIndex < details.length) {
          final detail = Map<String, dynamic>.from(details[detailIndex]);
          final nonConformities =
              List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);

          if (ncIndex < nonConformities.length) {
            final nc = Map<String, dynamic>.from(nonConformities[ncIndex]);

            if (updatedData.containsKey('description')) {
              nc['description'] = updatedData['description'];
            }
            if (updatedData.containsKey('severity')) {
              nc['severity'] = updatedData['severity'];
            }
            if (updatedData.containsKey('corrective_action')) {
              nc['corrective_action'] = updatedData['corrective_action'];
            }
            if (updatedData.containsKey('status')) {
              nc['status'] = updatedData['status'];
            }
            nc['updated_at'] = DateTime.now().toIso8601String();

            nonConformities[ncIndex] = nc;
            detail['non_conformities'] = nonConformities;
            details[detailIndex] = detail;
            item['details'] = details;
            items[itemIndex] = item;
            topic['items'] = items;
            topics[topicIndex] = topic;

            await _localStorage.saveInspection(
                inspection.copyWith(topics: topics, hasLocalChanges: true)); // Save to SQLite
          }
        }
      }
    }
  }

  // Adicionar não conformidade a nível de tópico
  Future<String> addNonConformityToTopic(
      String inspectionId, String topicId, Map<String, dynamic> ncData) async {
    final inspection =
        await _localStorage.getInspection(inspectionId); // Get from SQLite
    if (inspection?.topics == null) throw Exception('Inspection not found');

    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    if (topicIndex == null || topicIndex >= inspection!.topics!.length) {
      throw Exception('Invalid topic ID');
    }

    final topics = List<Map<String, dynamic>>.from(inspection.topics!);
    final topic = Map<String, dynamic>.from(topics[topicIndex]);

    // Criar lista de não conformidades do tópico se não existir
    final topicNCs =
        List<Map<String, dynamic>>.from(topic['non_conformities'] ?? []);

    final newNC = {
      'id': _uuid.v4(),
      'description': ncData['description'] ?? '',
      'severity': ncData['severity'] ?? 'Média',
      'status': 'Pendente',
      'corrective_action': ncData['corrective_action'],
      'is_resolved': false,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'level': 'topic', // Identificar nível
      ...ncData,
    };

    topicNCs.add(newNC);
    topic['non_conformities'] = topicNCs;
    topics[topicIndex] = topic;

    await _localStorage
        .saveInspection(inspection.copyWith(topics: topics, hasLocalChanges: true)); // Save to SQLite

    return '$inspectionId-topic_$topicIndex-nc_${topicNCs.length - 1}';
  }

  // Adicionar não conformidade a nível de item
  Future<String> addNonConformityToItem(String inspectionId, String topicId,
      String itemId, Map<String, dynamic> ncData) async {
    final inspection =
        await _localStorage.getInspection(inspectionId); // Get from SQLite
    if (inspection?.topics == null) throw Exception('Inspection not found');

    final topicIndex = int.tryParse(topicId.replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(itemId.replaceFirst('item_', ''));

    if (topicIndex == null || itemIndex == null) throw Exception('Invalid IDs');
    if (topicIndex >= inspection!.topics!.length) {
      throw Exception('Invalid topic');
    }

    final topics = List<Map<String, dynamic>>.from(inspection.topics!);
    final topic = topics[topicIndex];
    final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);

    if (itemIndex >= items.length) throw Exception('Invalid item');

    final item = Map<String, dynamic>.from(items[itemIndex]);
    final itemNCs =
        List<Map<String, dynamic>>.from(item['non_conformities'] ?? []);

    final newNC = {
      'id': _uuid.v4(),
      'description': ncData['description'] ?? '',
      'severity': ncData['severity'] ?? 'Média',
      'status': 'Pendente',
      'corrective_action': ncData['corrective_action'],
      'is_resolved': false,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'level': 'item', // Identificar nível
      ...ncData,
    };

    itemNCs.add(newNC);
    item['non_conformities'] = itemNCs;
    items[itemIndex] = item;
    topic['items'] = items;
    topics[topicIndex] = topic;

    await _localStorage
        .saveInspection(inspection.copyWith(topics: topics, hasLocalChanges: true)); // Save to SQLite

    return '$inspectionId-topic_$topicIndex-item_$itemIndex-nc_${itemNCs.length - 1}';
  }

  Future<void> deleteNonConformity(
      String nonConformityId, String inspectionId) async {
    final parts = nonConformityId.split('-');
    if (parts.length < 5) {
      throw Exception('Invalid non-conformity ID format');
    }

    final topicIndex = int.tryParse(parts[1].replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(parts[2].replaceFirst('item_', ''));
    final detailIndex = int.tryParse(parts[3].replaceFirst('detail_', ''));
    final ncIndex = int.tryParse(parts[4].replaceFirst('nc_', ''));

    if (topicIndex == null ||
        itemIndex == null ||
        detailIndex == null ||
        ncIndex == null) {
      throw Exception('Invalid non-conformity ID indices');
    }

    final inspection =
        await _localStorage.getInspection(inspectionId); // Get from SQLite
    if (inspection?.topics != null && topicIndex < inspection!.topics!.length) {
      final topics = List<Map<String, dynamic>>.from(inspection.topics!);
      final topic = Map<String, dynamic>.from(topics[topicIndex]);
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);

      if (itemIndex < items.length) {
        final item = items[itemIndex];
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);

        if (detailIndex < details.length) {
          final detail = Map<String, dynamic>.from(details[detailIndex]);
          final nonConformities =
              List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);

          if (ncIndex < nonConformities.length) {
            nonConformities.removeAt(ncIndex);
            detail['non_conformities'] = nonConformities;
            detail['is_damaged'] = nonConformities.isNotEmpty;

            details[detailIndex] = detail;
            item['details'] = details;
            items[itemIndex] = item;
            topic['items'] = items;
            topics[topicIndex] = topic;

            await _localStorage.saveInspection(
                inspection.copyWith(topics: topics, hasLocalChanges: true)); // Save to SQLite
          }
        }
      }
    }
  }

  Future<void> _addNonConformityToDetail(
      String inspectionId,
      int topicIndex,
      int itemIndex,
      int detailIndex,
      Map<String, dynamic> nonConformity) async {
    final inspection =
        await _localStorage.getInspection(inspectionId); // Get from SQLite
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
            final detail = Map<String, dynamic>.from(details[detailIndex]);
            final ncList = List<Map<String, dynamic>>.from(
                detail['non_conformities'] ?? []);
            ncList.add(nonConformity);
            detail['non_conformities'] = ncList;
            detail['is_damaged'] = true;
            details[detailIndex] = detail;
            item['details'] = details;
            items[itemIndex] = item;
            topic['items'] = items;
            topics[topicIndex] = topic;

            await _localStorage.saveInspection(
                inspection.copyWith(topics: topics, hasLocalChanges: true)); // Save to SQLite
          }
        }
      }
    }
  }
}
