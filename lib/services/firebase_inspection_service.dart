// lib/services/firebase_inspection_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class FirebaseInspectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final FirebaseInspectionService _instance = FirebaseInspectionService._internal();

  factory FirebaseInspectionService() {
    return _instance;
  }

  FirebaseInspectionService._internal() {
    // Habilitar persistência offline do Firestore
    _enableOfflinePersistence();
  }

  Future<void> _enableOfflinePersistence() async {
    try {
      await _firestore.enablePersistence(const PersistenceSettings(
        synchronizeTabs: true,
      ));
      print('Persistência offline habilitada com sucesso');
    } catch (e) {
      print('Erro ao habilitar persistência offline: $e');
      // O erro pode ocorrer se a persistência já estiver habilitada ou em ambientes não suportados
    }
  }

  // SEÇÃO: GERENCIAMENTO DE CONECTIVIDADE
  // ===================================
  
  // Verificar conectividade
  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // SEÇÃO: OPERAÇÕES DE INSPEÇÃO
  // ===========================

  // Obter inspeção
  Future<Inspection?> getInspection(String inspectionId) async {
    try {
      final docSnapshot = await _firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();

      if (!docSnapshot.exists) {
        print('Inspeção não encontrada: $inspectionId');
        return null;
      }

      final data = docSnapshot.data();
      if (data == null) return null;
      
      // Adicionar o ID no mapa de dados para ser incluído na conversão
      final inspectionData = {
        ...data,
        'id': inspectionId,
      };
      
      return Inspection.fromJson(inspectionData);
    } catch (e) {
      print('Erro ao obter inspeção: $e');
      rethrow;
    }
  }

  // Salvar inspeção
  Future<void> saveInspection(Inspection inspection) async {
    try {
      await _firestore
          .collection('inspections')
          .doc(inspection.id)
          .set(inspection.toJson(), SetOptions(merge: true));
      
      print('Inspeção ${inspection.id} salva com sucesso');
    } catch (e) {
      print('Erro ao salvar inspeção: $e');
      rethrow;
    }
  }

  // SEÇÃO: OPERAÇÕES DE SALAS
  // ========================

  // Obter salas de uma inspeção
  Future<List<Room>> getRooms(String inspectionId) async {
    try {
      final querySnapshot = await _firestore
          .collection('rooms')
          .where('inspection_id', isEqualTo: inspectionId)
          .orderBy('position', descending: false)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Room.fromJson({
          ...data,
          'id': doc.id,  // Usa ID como string
        });
      }).toList();
    } catch (e) {
      print('Erro ao obter salas: $e');
      return [];
    }
  }

  // Adicionar sala
  Future<Room> addRoom(String inspectionId, String name, {String? label, int? position}) async {
    try {
      final roomRef = _firestore.collection('rooms').doc();
      
      final roomData = {
        'inspection_id': inspectionId,
        'room_name': name,
        'room_label': label,
        'position': position ?? 0,
        'is_damaged': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      await roomRef.set(roomData);
      
      return Room(
        id: roomRef.id,
        inspectionId: inspectionId,
        position: position ?? 0,
        roomName: name,
        roomLabel: label,
        isDamaged: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('Erro ao adicionar sala: $e');
      rethrow;
    }
  }

  // Atualizar sala
  Future<void> updateRoom(Room room) async {
    try {
      if (room.id == null) {
        throw Exception('Room ID não pode ser nulo');
      }
      
      await _firestore
          .collection('rooms')
          .doc(room.id.toString())
          .update(room.toJson());
      
      print('Sala ${room.id} atualizada com sucesso');
    } catch (e) {
      print('Erro ao atualizar sala: $e');
      rethrow;
    }
  }

  // Excluir sala
  Future<void> deleteRoom(String inspectionId, dynamic roomId) async {
    try {
      // Excluir sala
      await _firestore
          .collection('rooms')
          .doc(roomId.toString())
          .delete();
      
      // Excluir itens associados
      final itemsSnapshot = await _firestore
          .collection('room_items')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: roomId)
          .get();
      
      for (var doc in itemsSnapshot.docs) {
        await doc.reference.delete();
        
        // Excluir detalhes do item
        final detailsSnapshot = await _firestore
            .collection('item_details')
            .where('inspection_id', isEqualTo: inspectionId)
            .where('room_id', isEqualTo: roomId)
            .where('room_item_id', isEqualTo: doc.id)
            .get();
        
        for (var detailDoc in detailsSnapshot.docs) {
          await detailDoc.reference.delete();
        }
      }
      
      print('Sala $roomId e todos seus itens e detalhes excluídos com sucesso');
    } catch (e) {
      print('Erro ao excluir sala: $e');
      rethrow;
    }
  }

  // SEÇÃO: OPERAÇÕES DE ITENS
  // ========================

  // Obter itens de uma sala
  Future<List<Item>> getItems(String inspectionId, dynamic roomId) async {
    try {
      final querySnapshot = await _firestore
          .collection('room_items')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: roomId)
          .orderBy('position', descending: false)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Item.fromJson({
          ...data,
          'id': doc.id,  // Usa ID como string
        });
      }).toList();
    } catch (e) {
      print('Erro ao obter itens: $e');
      return [];
    }
  }

  // Adicionar item
  Future<Item> addItem(String inspectionId, dynamic roomId, String name, {String? label, int? position}) async {
    try {
      final itemRef = _firestore.collection('room_items').doc();
      
      final itemData = {
        'inspection_id': inspectionId,
        'room_id': roomId,
        'item_name': name,
        'item_label': label,
        'position': position ?? 0,
        'is_damaged': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      await itemRef.set(itemData);
      
      return Item(
        id: itemRef.id,
        inspectionId: inspectionId,
        roomId: roomId,
        position: position ?? 0,
        itemName: name,
        itemLabel: label,
        isDamaged: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('Erro ao adicionar item: $e');
      rethrow;
    }
  }

  // Atualizar item
  Future<void> updateItem(Item item) async {
    try {
      if (item.id == null) {
        throw Exception('Item ID não pode ser nulo');
      }
      
      await _firestore
          .collection('room_items')
          .doc(item.id.toString())
          .update(item.toJson());
      
      print('Item ${item.id} atualizado com sucesso');
    } catch (e) {
      print('Erro ao atualizar item: $e');
      rethrow;
    }
  }

  // Excluir item
  Future<void> deleteItem(String inspectionId, dynamic roomId, dynamic itemId) async {
    try {
      // Excluir item
      await _firestore
          .collection('room_items')
          .doc(itemId.toString())
          .delete();
      
      // Excluir detalhes do item
      final detailsSnapshot = await _firestore
          .collection('item_details')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: roomId)
          .where('room_item_id', isEqualTo: itemId)
          .get();
      
      for (var doc in detailsSnapshot.docs) {
        await doc.reference.delete();
      }
      
      print('Item $itemId e todos seus detalhes excluídos com sucesso');
    } catch (e) {
      print('Erro ao excluir item: $e');
      rethrow;
    }
  }

  // SEÇÃO: OPERAÇÕES DE DETALHES
  // ===========================

  // Obter detalhes de um item
  Future<List<Detail>> getDetails(String inspectionId, dynamic roomId, dynamic itemId) async {
    try {
      final querySnapshot = await _firestore
          .collection('item_details')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: roomId)
          .where('room_item_id', isEqualTo: itemId)
          .orderBy('position', descending: false)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Detail.fromJson({
          ...data,
          'id': doc.id,  // Usa ID como string
        });
      }).toList();
    } catch (e) {
      print('Erro ao obter detalhes: $e');
      return [];
    }
  }

  // Adicionar detalhe
  Future<Detail> addDetail(String inspectionId, dynamic roomId, dynamic itemId, String name, {String? value, int? position}) async {
    try {
      final detailRef = _firestore.collection('item_details').doc();
      
      final detailData = {
        'inspection_id': inspectionId,
        'room_id': roomId,
        'room_item_id': itemId,
        'detail_name': name,
        'detail_value': value,
        'position': position ?? 0,
        'is_damaged': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      await detailRef.set(detailData);
      
      return Detail(
        id: detailRef.id,
        inspectionId: inspectionId,
        roomId: roomId,
        itemId: itemId,
        position: position,
        detailName: name,
        detailValue: value,
        isDamaged: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('Erro ao adicionar detalhe: $e');
      rethrow;
    }
  }

  // Atualizar detalhe
  Future<void> updateDetail(Detail detail) async {
    try {
      if (detail.id == null) {
        throw Exception('Detail ID não pode ser nulo');
      }
      
      await _firestore
          .collection('item_details')
          .doc(detail.id.toString())
          .update(detail.toJson());
      
      print('Detalhe ${detail.id} atualizado com sucesso');
    } catch (e) {
      print('Erro ao atualizar detalhe: $e');
      rethrow;
    }
  }

  // Excluir detalhe
  Future<void> deleteDetail(String inspectionId, dynamic roomId, dynamic itemId, dynamic detailId) async {
    try {
      await _firestore
          .collection('item_details')
          .doc(detailId.toString())
          .delete();
      
      print('Detalhe $detailId excluído com sucesso');
    } catch (e) {
      print('Erro ao excluir detalhe: $e');
      rethrow;
    }
  }

  // SEÇÃO: OPERAÇÕES DE TEMPLATE
  // ===========================

  // Aplicar template a uma inspeção - MÉTODO MELHORADO
  Future<bool> applyTemplateToInspection(String inspectionId, String templateId) async {
    try {
      print('Iniciando aplicação do template $templateId para a inspeção $inspectionId');
      
      // Verificar se a inspeção já tem template aplicado
      final inspectionDoc = await _firestore.collection('inspections').doc(inspectionId).get();
      final inspectionData = inspectionDoc.data();
      
      if (inspectionData != null && inspectionData['is_templated'] == true) {
        print('Esta inspeção já tem um template aplicado.');
        return true; // Já está aplicado, retorna sucesso
      }
      
      // Obter dados do template
      final templateDoc = await _firestore.collection('templates').doc(templateId).get();
      if (!templateDoc.exists) {
        print('Template não encontrado: $templateId');
        return false;
      }

      final templateData = templateDoc.data();
      if (templateData == null) {
        print('Dados do template são nulos');
        return false;
      }

      print('Template encontrado: ${templateData['title']}');

      // Processar as salas do template
      final roomsData = templateData['rooms'];
      if (roomsData == null || roomsData is! List) {
        print('Template não contém salas válidas');
        return false;
      }

      print('Processando ${roomsData.length} salas do template');
      
      // Variável para rastrear se pelo menos uma sala foi criada
      bool successfulCreation = false;
      
      // Processamento das salas do template
      for (var roomData in roomsData) {
        // Extrair nome da sala com tratamento adequado para diferentes formatos
        String roomName = _extractStringValueFromTemplate(roomData, 'name', defaultValue: 'Sala sem nome');
        String? roomDescription = _extractStringValueFromTemplate(roomData, 'description');
        
        print('Criando sala: $roomName');
        
        try {
          // Criar sala
          final roomDoc = await _firestore.collection('rooms').add({
            'inspection_id': inspectionId,
            'room_name': roomName,
            'room_label': roomDescription,
            'position': 0,
            'is_damaged': false,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
          
          final roomId = roomDoc.id;
          print('Sala criada com ID: $roomId');
          successfulCreation = true;
          
          // Processar itens da sala
          List<dynamic> items = _extractArrayFromTemplate(roomData, 'items');
          print('Processando ${items.length} itens para a sala $roomName');
          
          int itemPosition = 0;
          for (var itemData in items) {
            var fields = _extractFieldsFromTemplate(itemData);
            if (fields == null) continue;
            
            // Extrair nome e descrição do item
            String itemName = _extractStringValueFromTemplate(fields, 'name', defaultValue: 'Item sem nome');
            String? itemDescription = _extractStringValueFromTemplate(fields, 'description');
            
            print('Criando item: $itemName');
            
            try {
              // Criar item
              final itemDoc = await _firestore.collection('room_items').add({
                'inspection_id': inspectionId,
                'room_id': roomId,
                'item_name': itemName,
                'item_label': itemDescription ?? '',
                'position': itemPosition++,
                'is_damaged': false,
                'created_at': FieldValue.serverTimestamp(),
                'updated_at': FieldValue.serverTimestamp(),
              });
              
              final itemId = itemDoc.id;
              print('Item criado com ID: $itemId');
              
              // Processar detalhes do item
              List<dynamic> details = _extractArrayFromTemplate(fields, 'details');
              print('Processando ${details.length} detalhes para o item $itemName');
              
              int detailPosition = 0;
              for (var detailData in details) {
                var detailFields = _extractFieldsFromTemplate(detailData);
                if (detailFields == null) continue;
                
                // Extrair nome do detalhe
                String detailName = _extractStringValueFromTemplate(detailFields, 'name', defaultValue: 'Detalhe sem nome');
                
                // Extrair opções do detalhe se existirem
                List<String> options = [];
                var optionsArray = _extractArrayFromTemplate(detailFields, 'options');
                
                for (var option in optionsArray) {
                  if (option is Map && option.containsKey('stringValue')) {
                    options.add(option['stringValue']);
                  } else if (option is String) {
                    options.add(option);
                  }
                }
                
                // Usar a primeira opção como valor inicial, se disponível
                String? initialValue = options.isNotEmpty ? options[0] : null;
                
                print('Criando detalhe: $detailName');
                
                try {
                  await _firestore.collection('item_details').add({
                    'inspection_id': inspectionId,
                    'room_id': roomId,
                    'room_item_id': itemId,
                    'detail_name': detailName,
                    'detail_value': initialValue,
                    'position': detailPosition++,
                    'is_damaged': false,
                    'created_at': FieldValue.serverTimestamp(),
                    'updated_at': FieldValue.serverTimestamp(),
                  });
                } catch (e) {
                  print('Erro ao criar detalhe $detailName: $e');
                }
              }
            } catch (e) {
              print('Erro ao criar item $itemName: $e');
            }
          }
        } catch (e) {
          print('Erro ao criar sala $roomName: $e');
        }
      }
      
      // Marcar inspeção como templated apenas se pelo menos uma sala foi criada
      if (successfulCreation) {
        await _firestore.collection('inspections').doc(inspectionId).update({
          'is_templated': true,
          'status': 'in_progress',
          'updated_at': FieldValue.serverTimestamp(),
        });
        
        print('Inspeção marcada como templated com sucesso');
        return true;
      } else {
        print('Nenhuma sala foi criada. Template não aplicado.');
        return false;
      }
    } catch (e) {
      print('Erro ao aplicar template à inspeção: $e');
      return false;
    }
  }

  // Métodos auxiliares para extração de dados do template
  
  String _extractStringValueFromTemplate(dynamic data, String key, {String defaultValue = ''}) {
    if (data == null) return defaultValue;
    
    // Caso 1: Direto como string
    if (data[key] is String) {
      return data[key];
    }
    
    // Caso 2: Formato Firestore (stringValue)
    if (data[key] is Map && data[key].containsKey('stringValue')) {
      return data[key]['stringValue'];
    }
    
    // Caso 3: Valor não encontrado
    return defaultValue;
  }
  
  List<dynamic> _extractArrayFromTemplate(dynamic data, String key) {
    if (data == null) return [];
    
    // Caso 1: Já é uma lista
    if (data[key] is List) {
      return data[key];
    }
    
    // Caso 2: Formato Firestore (arrayValue)
    if (data[key] is Map && 
        data[key].containsKey('arrayValue') && 
        data[key]['arrayValue'] is Map &&
        data[key]['arrayValue'].containsKey('values')) {
      return data[key]['arrayValue']['values'] ?? [];
    }
    
    // Caso 3: Valor não encontrado
    return [];
  }
  
Map<String, dynamic>? _extractFieldsFromTemplate(dynamic data) {
  if (data == null) return null;
  
  // Caso 1: Já é um mapa de campos
  if (data is Map && data.containsKey('fields')) {
    return Map<String, dynamic>.from(data['fields']);
  }
  
  // Caso 2: Formato Firestore complexo
  if (data is Map && 
      data.containsKey('mapValue') && 
      data['mapValue'] is Map &&
      data['mapValue'].containsKey('fields')) {
    return Map<String, dynamic>.from(data['mapValue']['fields']);
  }
  
  // Caso 3: É um mapa simples
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  
  // Caso 4: Valor não é um mapa válido
  return null;
}

  // SEÇÃO: OPERAÇÕES DE NÃO CONFORMIDADES
  // ====================================

  // Obter não conformidades de uma inspeção
  Future<List<Map<String, dynamic>>> getNonConformitiesByInspection(String inspectionId) async {
    try {
      final querySnapshot = await _firestore
          .collection('non_conformities')
          .where('inspection_id', isEqualTo: inspectionId)
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();
    } catch (e) {
      print('Erro ao obter não conformidades: $e');
      return [];
    }
  }

  // Salvar não conformidade
  Future<void> saveNonConformity(Map<String, dynamic> nonConformity) async {
    try {
      if (nonConformity.containsKey('id') && nonConformity['id'] != null) {
        // Atualizar existente
        await _firestore
            .collection('non_conformities')
            .doc(nonConformity['id'])
            .update(nonConformity);
      } else {
        // Adicionar nova
        final docRef = await _firestore
            .collection('non_conformities')
            .add(nonConformity);
        
        nonConformity['id'] = docRef.id;
      }
      
      print('Não conformidade salva com sucesso');
    } catch (e) {
      print('Erro ao salvar não conformidade: $e');
      rethrow;
    }
  }

  // Atualizar status de não conformidade
  Future<void> updateNonConformityStatus(String nonConformityId, String newStatus) async {
    try {
      await _firestore
          .collection('non_conformities')
          .doc(nonConformityId)
          .update({
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      print('Status da não conformidade atualizado para: $newStatus');
    } catch (e) {
      print('Erro ao atualizar status de não conformidade: $e');
      rethrow;
    }
  }

  // SEÇÃO: OPERAÇÕES DE DUPLICAÇÃO E VERIFICAÇÃO
  // =========================================

  // Verificar se já existe uma sala com este nome na inspeção
  Future<bool> isRoomDuplicate(String inspectionId, String roomName) async {
    try {
      final querySnapshot = await _firestore
          .collection('rooms')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_name', isEqualTo: roomName)
          .limit(1)
          .get();
      
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Erro ao verificar sala duplicada: $e');
      return false; // Em caso de erro, assumimos que não é duplicado
    }
  }

  // Verificar se já existe um item com este nome nesta sala
  Future<bool> isItemDuplicate(String inspectionId, dynamic roomId, String itemName) async {
    try {
      final querySnapshot = await _firestore
          .collection('room_items')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: roomId)
          .where('item_name', isEqualTo: itemName)
          .limit(1)
          .get();
      
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Erro ao verificar item duplicado: $e');
      return false; // Em caso de erro, assumimos que não é duplicado
    }
  }

  // Verificar se já existe um detalhe com este nome neste item
  Future<Detail?> isDetailDuplicate(String inspectionId, dynamic roomId, dynamic itemId, String detailName) async {
    try {
      final querySnapshot = await _firestore
          .collection('item_details')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: roomId)
          .where('room_item_id', isEqualTo: itemId)
          .where('detail_name', isEqualTo: detailName)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        // Se encontrou um detalhe existente, criar uma cópia
        final position = await _getNextDetailPosition(inspectionId, roomId, itemId);
        final newDetailName = "$detailName (cópia)";
        
        final detail = await addDetail(
          inspectionId,
          roomId,
          itemId,
          newDetailName,
          position: position,
        );
        
        return detail;
      }
      
      return null;
    } catch (e) {
      print('Erro ao verificar detalhe duplicado: $e');
      return null;
    }
  }
  
  // Obter a próxima posição para um detalhe
  Future<int> _getNextDetailPosition(String inspectionId, dynamic roomId, dynamic itemId) async {
    try {
      final querySnapshot = await _firestore
          .collection('item_details')
          .where('inspection_id', isEqualTo: inspectionId)
          .where('room_id', isEqualTo: roomId)
          .where('room_item_id', isEqualTo: itemId)
          .orderBy('position', descending: true)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return 0;
      }
      
      final lastPosition = querySnapshot.docs.first.data()['position'] ?? 0;
      return lastPosition + 1;
    } catch (e) {
      print('Erro ao obter próxima posição: $e');
      return 0;
    }
  }

  // SEÇÃO: CÁLCULOS E MÉTRICAS
  // =========================

  // Calcular percentual de conclusão de uma inspeção
  Future<double> calculateCompletionPercentage(String inspectionId) async {
    try {
      // Obter todas as salas
      final rooms = await getRooms(inspectionId);
      
      int totalDetails = 0;
      int filledDetails = 0;
      
      for (var room in rooms) {
        if (room.id == null) continue;
        
        // Obter todos os itens para esta sala
        final items = await getItems(inspectionId, room.id);
        
        for (var item in items) {
          if (item.id == null) continue;
          
          // Obter todos os detalhes para este item
          final details = await getDetails(inspectionId, room.id, item.id);
          
          totalDetails += details.length;
          
          // Contar detalhes preenchidos
          for (var detail in details) {
            if (detail.detailValue != null && detail.detailValue!.isNotEmpty) {
              filledDetails++;
            }
          }
        }
      }
      
      // Evitar divisão por zero
      if (totalDetails == 0) return 0.0;
      
      return filledDetails / totalDetails;
    } catch (e) {
      print('Erro ao calcular percentual de conclusão: $e');
      return 0.0;
    }
  }
}