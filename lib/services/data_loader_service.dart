// lib/services/data_loader_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inspection_app/services/local_database_service.dart';

class DataLoaderService {
  final _supabase = Supabase.instance.client;
  
  // Carregar templates de ambientes da base de dados
Future<List<Map<String, dynamic>>> loadRoomTemplates() async {
    try {
      // Verificar conectividade
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult == ConnectivityResult.none;
      
      if (isOffline) {
        // Offline: tentar buscar do cache
        final cachedTemplates = await _getCachedRoomTemplates();
        if (cachedTemplates.isNotEmpty) {
          print('Carregando ${cachedTemplates.length} templates de ambientes do cache');
          return cachedTemplates;
        }
        
        // Se não tem no cache, buscar de dados locais
        return await _loadRoomTemplatesFromLocal();
      } else {
        // Online: carregar diretamente das tabelas
        try {
          print('Buscando templates de ambientes do banco...');
          final data = await _supabase
              .from('rooms')  // Tabela existente
              .select('id, room_name, room_label, observation')
              .order('room_name', ascending: true)
              .limit(50);
          
          // Log dos dados recebidos
          print('Recebidos ${data.length} templates de ambientes');

          // Processar os dados
          final List<Map<String, dynamic>> templates = [];
          final Set<String> uniqueRoomNames = {};
          
          for (var room in data) {
            final roomName = room['room_name'] as String;
            // Apenas registrar uma vez cada nome único
            if (!uniqueRoomNames.contains(roomName)) {
              uniqueRoomNames.add(roomName);
              templates.add({
                'name': roomName,
                'label': room['room_label'],
                'description': room['observation'],
                'id': room['id'],
              });
            }
          }
          
          // Salvar no cache para uso futuro
          await _cacheRoomTemplates(templates);
          
          return templates;
        } catch (e) {
          print('Erro ao carregar templates de ambientes: $e');
          
          // Em caso de erro, tentar do cache
          final cachedTemplates = await _getCachedRoomTemplates();
          if (cachedTemplates.isNotEmpty) {
            return cachedTemplates;
          }
          
          // Ou dos dados locais
          return await _loadRoomTemplatesFromLocal();
        }
      }
    } catch (e) {
      print('Erro ao carregar templates de ambientes: $e');
      return [];
    }
  }

  // Carregar templates de ambientes a partir dos dados locais salvos no Hive
  Future<List<Map<String, dynamic>>> _loadRoomTemplatesFromLocal() async {
    try {
      print('Carregando ambientes de dados locais');
      
      // Buscar todos os ambientes cadastrados localmente
      final localRooms = await LocalDatabaseService.getAllLocalRooms();
      print('Encontrados ${localRooms.length} ambientes locais');
      
      // Agrupar por nome para evitar duplicatas
      final List<Map<String, dynamic>> templates = [];
      final Set<String> uniqueRoomNames = {};
      
      for (var room in localRooms) {
        final roomName = room.roomName;
        if (!uniqueRoomNames.contains(roomName)) {
          uniqueRoomNames.add(roomName);
          templates.add({
            'name': roomName,
            'label': room.roomLabel,
            'description': room.observation,
            'id': room.id,
            'isFromLocal': true,
          });
        }
      }
      
      return templates;
    } catch (e) {
      print('Erro ao carregar ambientes locais: $e');
      return [];
    }
  }
  
Future<List<Map<String, dynamic>>> loadItemTemplates(String roomName) async {
    try {
      print('Buscando templates de itens para ambiente: $roomName');
      
      // Verificar conectividade
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult == ConnectivityResult.none;
      
      if (isOffline) {
        // Offline: tentar buscar do cache
        final cachedTemplates = await _getCachedItemTemplates(roomName);
        if (cachedTemplates.isNotEmpty) {
          print('Carregando ${cachedTemplates.length} templates de itens do cache');
          return cachedTemplates;
        }
        
        // Se não tem no cache, buscar de dados locais
        return await _loadItemTemplatesFromLocal(roomName);
      } else {
        // Online: tentar buscar diretamente da API
        try {
          // Primeiro buscar IDs de ambientes com nome similar (não só exato)
          final roomsData = await _supabase
              .from('rooms')
              .select('id, room_name')
              .ilike('room_name', '%$roomName%')  // Usando ILIKE para busca por similaridade
              .limit(100);
          
          print('Encontrados ${roomsData.length} ambientes com nome similar a "$roomName"');
          
          if (roomsData.isEmpty) {
            print('Nenhum ambiente encontrado, buscando todos os itens como fallback');
            // Fallback: buscar todos os itens se não encontrar ambientes
            final allItemsData = await _supabase
                .from('room_items')
                .select('id, item_name, item_label, observation')
                .order('item_name', ascending: true)
                .limit(50);
                
            // Processar itens
            final List<Map<String, dynamic>> templates = [];
            final Set<String> uniqueItemNames = {};
            
            for (var item in allItemsData) {
              final itemName = item['item_name'] as String;
              if (!uniqueItemNames.contains(itemName)) {
                uniqueItemNames.add(itemName);
                templates.add({
                  'name': itemName,
                  'label': item['item_label'],
                  'description': item['observation'],
                  'id': item['id'],
                });
              }
            }
            
            // Salvar no cache
            await _cacheItemTemplates(roomName, templates);
            
            return templates;
          }
          
          // Lista de IDs de ambientes com esse nome
          final List<int> roomIds = [];
          for (var room in roomsData) {
            if (room['id'] != null) {
              roomIds.add(room['id'] as int);
            }
          }
          
          // Buscar itens associados a esses ambientes
          print('Buscando itens para ${roomIds.length} room IDs');
          final List<Map<String, dynamic>> allItemsData = [];
          
          for (final roomId in roomIds) {
            try {
              final itemsData = await _supabase
                  .from('room_items')
                  .select('id, item_name, item_label, observation')
                  .eq('room_id', roomId)
                  .order('item_name', ascending: true)
                  .limit(50);
              
              print('Encontrados ${itemsData.length} itens para room_id=$roomId');
              allItemsData.addAll(List<Map<String, dynamic>>.from(itemsData));
            } catch (e) {
              print('Erro ao buscar itens para room_id=$roomId: $e');
            }
          }
          
          // Se não encontrou itens nas relações, buscar todos
          if (allItemsData.isEmpty) {
            print('Nenhum item encontrado pelas relações, buscando todos');
            final itemsData = await _supabase
                .from('room_items')
                .select('id, item_name, item_label, observation')
                .order('item_name', ascending: true)
                .limit(50);
                
            allItemsData.addAll(List<Map<String, dynamic>>.from(itemsData));
            print('Encontrados ${itemsData.length} itens no total');
          }
          
          // Agrupar itens por nome
          final List<Map<String, dynamic>> templates = [];
          final Set<String> uniqueItemNames = {};
          
          for (var item in allItemsData) {
            if (item['item_name'] != null) {
              final itemName = item['item_name'] as String;
              if (!uniqueItemNames.contains(itemName)) {
                uniqueItemNames.add(itemName);
                templates.add({
                  'name': itemName,
                  'label': item['item_label'],
                  'description': item['observation'],
                  'id': item['id'],
                });
              }
            }
          }
          
          // Salvar no cache
          await _cacheItemTemplates(roomName, templates);
          
          print('Retornando ${templates.length} templates de itens');
          return templates;
        } catch (e) {
          print('Erro ao carregar templates de itens: $e');
          
          // Em caso de erro, tentar do cache
          final cachedTemplates = await _getCachedItemTemplates(roomName);
          if (cachedTemplates.isNotEmpty) {
            return cachedTemplates;
          }
          
          // Ou dos dados locais
          return await _loadItemTemplatesFromLocal(roomName);
        }
      }
    } catch (e) {
      print('Erro ao carregar templates de itens: $e');
      return [];
    }
  }
  
  // Carregar templates de itens a partir dos dados locais
  Future<List<Map<String, dynamic>>> _loadItemTemplatesFromLocal(String roomName) async {
    try {
      // Buscar todos os itens salvos localmente
      final localItems = await LocalDatabaseService.getAllLocalItems();
      
      // Filtrar itens que pertencem a ambientes com o nome especificado
      // e agrupar por nome para evitar duplicatas
      final List<Map<String, dynamic>> templates = [];
      final Set<String> uniqueItemNames = {};
      
      for (var item in localItems) {
        // Verificar se este item pertence a um ambiente com o nome desejado
        final room = await LocalDatabaseService.getRoomById(item.roomId ?? 0);
        if (room != null && room.roomName == roomName) {
          final itemName = item.itemName;
          if (!uniqueItemNames.contains(itemName)) {
            uniqueItemNames.add(itemName);
            templates.add({
              'name': itemName,
              'label': item.itemLabel,
              'description': item.observation,
              'id': item.id,
              'isFromLocal': true,
            });
          }
        }
      }
      
      return templates;
    } catch (e) {
      print('Erro ao carregar itens locais: $e');
      return [];
    }
  }
  
  // Carregar templates de detalhes para um tipo de item
  Future<List<Map<String, dynamic>>> loadDetailTemplates(String itemName) async {
    try {
      print('Buscando templates de detalhes para item: $itemName');
      
      // Verificar conectividade
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult == ConnectivityResult.none;
      
      if (isOffline) {
        // Offline: tentar buscar do cache
        final cachedTemplates = await _getCachedDetailTemplates(itemName);
        if (cachedTemplates.isNotEmpty) {
          print('Carregando ${cachedTemplates.length} templates de detalhes do cache');
          return cachedTemplates;
        }
        
        // Se não tem no cache, buscar de dados locais
        return await _loadDetailTemplatesFromLocal(itemName);
      } else {
        // Online: tentar buscar diretamente da API
        try {
          // Buscar IDs de itens com nome similar
          final itemsData = await _supabase
              .from('room_items')
              .select('id, item_name')
              .ilike('item_name', '%$itemName%')  // Usando ILIKE para busca por similaridade
              .limit(100);
          
          print('Encontrados ${itemsData.length} itens com nome similar a "$itemName"');
          
          if (itemsData.isEmpty) {
            print('Nenhum item encontrado, buscando todos os detalhes como fallback');
            // Fallback: buscar todos os detalhes
            final allDetailsData = await _supabase
                .from('item_details')
                .select('id, detail_name, detail_value, observation')
                .order('detail_name', ascending: true)
                .limit(50);
                
            // Processar detalhes
            final List<Map<String, dynamic>> templates = [];
            final Set<String> uniqueDetailNames = {};
            
            for (var detail in allDetailsData) {
              final detailName = detail['detail_name'] as String;
              if (!uniqueDetailNames.contains(detailName)) {
                uniqueDetailNames.add(detailName);
                templates.add({
                  'name': detailName,
                  'value': detail['detail_value'],
                  'observation': detail['observation'],
                  'id': detail['id'],
                });
              }
            }
            
            // Salvar no cache
            await _cacheDetailTemplates(itemName, templates);
            
            return templates;
          }
          
          // Lista de IDs de itens com nome similar
          final List<int> itemIds = [];
          for (var item in itemsData) {
            if (item['id'] != null) {
              itemIds.add(item['id'] as int);
            }
          }
          
          // Buscar detalhes associados a esses itens
          print('Buscando detalhes para ${itemIds.length} item IDs');
          final List<Map<String, dynamic>> allDetailsData = [];
          
          for (final itemId in itemIds) {
            try {
              final detailsData = await _supabase
                  .from('item_details')
                  .select('id, detail_name, detail_value, observation')
                  .eq('room_item_id', itemId)
                  .order('detail_name', ascending: true)
                  .limit(50);
              
              print('Encontrados ${detailsData.length} detalhes para room_item_id=$itemId');
              allDetailsData.addAll(List<Map<String, dynamic>>.from(detailsData));
            } catch (e) {
              print('Erro ao buscar detalhes para item_id=$itemId: $e');
            }
          }
          
          // Se não encontrou detalhes nas relações, buscar todos
          if (allDetailsData.isEmpty) {
            print('Nenhum detalhe encontrado pelas relações, buscando todos');
            final detailsData = await _supabase
                .from('item_details')
                .select('id, detail_name, detail_value, observation')
                .order('detail_name', ascending: true)
                .limit(50);
                
            allDetailsData.addAll(List<Map<String, dynamic>>.from(detailsData));
            print('Encontrados ${detailsData.length} detalhes no total');
          }
          
          // Agrupar detalhes por nome
          final List<Map<String, dynamic>> templates = [];
          final Set<String> uniqueDetailNames = {};
          
          for (var detail in allDetailsData) {
            if (detail['detail_name'] != null) {
              final detailName = detail['detail_name'] as String;
              if (!uniqueDetailNames.contains(detailName)) {
                uniqueDetailNames.add(detailName);
                templates.add({
                  'name': detailName,
                  'value': detail['detail_value'],
                  'observation': detail['observation'],
                  'id': detail['id'],
                });
              }
            }
          }
          
          // Salvar no cache
          await _cacheDetailTemplates(itemName, templates);
          
          print('Retornando ${templates.length} templates de detalhes');
          return templates;
        } catch (e) {
          print('Erro ao carregar templates de detalhes: $e');
          
          // Em caso de erro, tentar do cache
          final cachedTemplates = await _getCachedDetailTemplates(itemName);
          if (cachedTemplates.isNotEmpty) {
            return cachedTemplates;
          }
          
          // Ou dos dados locais
          return await _loadDetailTemplatesFromLocal(itemName);
        }
      }
    } catch (e) {
      print('Erro ao carregar templates de detalhes: $e');
      return [];
    }
  }
  
  // Carregar templates de detalhes a partir dos dados locais
  Future<List<Map<String, dynamic>>> _loadDetailTemplatesFromLocal(String itemName) async {
    try {
      // Buscar todos os detalhes salvos localmente
      final localDetails = await LocalDatabaseService.getAllLocalDetails();
      
      // Filtrar detalhes que pertencem a itens com o nome especificado
      // e agrupar por nome para evitar duplicatas
      final List<Map<String, dynamic>> templates = [];
      final Set<String> uniqueDetailNames = {};
      
      for (var detail in localDetails) {
        // Verificar se este detalhe pertence a um item com o nome desejado
        final item = await LocalDatabaseService.getItemById(detail.itemId ?? 0);
        if (item != null && item.itemName == itemName) {
          final detailName = detail.detailName;
          if (!uniqueDetailNames.contains(detailName)) {
            uniqueDetailNames.add(detailName);
            templates.add({
              'name': detailName,
              'value': detail.detailValue,
              'observation': detail.observation,
              'id': detail.id,
              'isFromLocal': true,
            });
          }
        }
      }
      
      return templates;
    } catch (e) {
      print('Erro ao carregar detalhes locais: $e');
      return [];
    }
  }
  
  // Funções para cache
  Future<void> _cacheRoomTemplates(List<Map<String, dynamic>> templates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_templates', jsonEncode(templates));
      await prefs.setString('room_templates_timestamp', DateTime.now().toIso8601String());
    } catch (e) {
      print('Erro ao salvar cache de templates de ambientes: $e');
    }
  }
  
  Future<List<Map<String, dynamic>>> _getCachedRoomTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templatesString = prefs.getString('room_templates');
      final timestamp = prefs.getString('room_templates_timestamp');
      
      if (templatesString == null || timestamp == null) return [];
      
      // Verificar se o cache é recente (menos de 24 horas)
      final cacheTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      if (now.difference(cacheTime).inHours > 24) return [];
      
      final List<dynamic> decodedList = jsonDecode(templatesString);
      return decodedList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Erro ao ler cache de templates de ambientes: $e');
      return [];
    }
  }
  
  Future<void> _cacheItemTemplates(String roomName, List<Map<String, dynamic>> templates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('item_templates_$roomName', jsonEncode(templates));
      await prefs.setString('item_templates_${roomName}_timestamp', DateTime.now().toIso8601String());
    } catch (e) {
      print('Erro ao salvar cache de templates de itens: $e');
    }
  }
  
  Future<List<Map<String, dynamic>>> _getCachedItemTemplates(String roomName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templatesString = prefs.getString('item_templates_$roomName');
      final timestamp = prefs.getString('item_templates_${roomName}_timestamp');
      
      if (templatesString == null || timestamp == null) return [];
      
      // Verificar se o cache é recente (menos de 24 horas)
      final cacheTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      if (now.difference(cacheTime).inHours > 24) return [];
      
      final List<dynamic> decodedList = jsonDecode(templatesString);
      return decodedList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Erro ao ler cache de templates de itens: $e');
      return [];
    }
  }
  
  Future<void> _cacheDetailTemplates(String itemName, List<Map<String, dynamic>> templates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('detail_templates_$itemName', jsonEncode(templates));
      await prefs.setString('detail_templates_${itemName}_timestamp', DateTime.now().toIso8601String());
    } catch (e) {
      print('Erro ao salvar cache de templates de detalhes: $e');
    }
  }
  
  Future<List<Map<String, dynamic>>> _getCachedDetailTemplates(String itemName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templatesString = prefs.getString('detail_templates_$itemName');
      final timestamp = prefs.getString('detail_templates_${itemName}_timestamp');
      
      if (templatesString == null || timestamp == null) return [];
      
      // Verificar se o cache é recente (menos de 24 horas)
      final cacheTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      if (now.difference(cacheTime).inHours > 24) return [];
      
      final List<dynamic> decodedList = jsonDecode(templatesString);
      return decodedList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Erro ao ler cache de templates de detalhes: $e');
      return [];
    }
  }
}