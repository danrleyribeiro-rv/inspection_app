// lib/services/template_cache_manager.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TemplateCacheManager {
  static final TemplateCacheManager _instance = TemplateCacheManager._internal();
  final _supabase = Supabase.instance.client;

  factory TemplateCacheManager() {
    return _instance;
  }

  TemplateCacheManager._internal();

  // Cache de templates básicos para utilização offline
  Future<void> cacheBasicTemplates() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print('Offline: ignorando cache de templates básicos');
      return;
    }

    try {
      // Buscar templates de ambientes
      final roomTemplates = await _supabase
          .from('rooms')
          .select('id, room_name, room_label, observation')
          .order('room_name', ascending: true)
          .limit(100);
      
      // Agrupar ambientes por nome para evitar duplicatas
      final List<Map<String, dynamic>> rooms = [];
      final Set<String> uniqueRoomNames = {};
      
      for (var room in roomTemplates) {
        final roomName = room['room_name'] as String;
        if (!uniqueRoomNames.contains(roomName)) {
          uniqueRoomNames.add(roomName);
          rooms.add({
            'name': roomName,
            'label': room['room_label'],
            'description': room['observation'],
            'id': room['id'],
          });
        }
      }
      
      // Salvar cache de ambientes
      await _cacheTemplates('room_templates', rooms);
      
      // Para cada ambiente, buscar items associados
      for (var room in rooms) {
        final roomName = room['name'];
        
        // Buscar IDs de ambientes com esse nome
        final roomsData = await _supabase
            .from('rooms')
            .select('id')
            .eq('room_name', roomName)
            .limit(100);
        
        if (roomsData.isNotEmpty) {
          // Lista de IDs de ambientes com esse nome
          final List<int> roomIds = roomsData.map<int>((r) => r['id'] as int).toList();
          
          // Buscar itens associados a esses ambientes
          final List<Map<String, dynamic>> allItemsData = [];
          
          for (final roomId in roomIds) {
            final itemsData = await _supabase
                .from('room_items')
                .select('id, item_name, item_label, observation')
                .eq('room_id', roomId)
                .order('item_name', ascending: true)
                .limit(50);
            
            allItemsData.addAll(List<Map<String, dynamic>>.from(itemsData));
          }
          
          // Agrupar itens por nome
          final List<Map<String, dynamic>> items = [];
          final Set<String> uniqueItemNames = {};
          
          for (var item in allItemsData) {
            final itemName = item['item_name'] as String;
            if (!uniqueItemNames.contains(itemName)) {
              uniqueItemNames.add(itemName);
              items.add({
                'name': itemName,
                'label': item['item_label'],
                'description': item['observation'],
                'id': item['id'],
              });
            }
          }
          
          // Salvar cache de itens para este ambiente
          await _cacheTemplates('item_templates_$roomName', items);
          
          // Para cada item, buscar detalhes associados
          for (var item in items) {
            final itemName = item['name'];
            
            // Buscar IDs de itens com esse nome
            final itemsData = await _supabase
                .from('room_items')
                .select('id')
                .eq('item_name', itemName)
                .limit(100);
            
            if (itemsData.isNotEmpty) {
              // Lista de IDs de itens com esse nome
              final List<int> itemIds = itemsData.map<int>((i) => i['id'] as int).toList();
              
              // Buscar detalhes associados a esses itens
              final List<Map<String, dynamic>> allDetailsData = [];
              
              for (final itemId in itemIds) {
                final detailsData = await _supabase
                    .from('item_details')
                    .select('id, detail_name, detail_value, observation')
                    .eq('room_item_id', itemId)
                    .order('detail_name', ascending: true)
                    .limit(50);
                
                allDetailsData.addAll(List<Map<String, dynamic>>.from(detailsData));
              }
              
              // Agrupar detalhes por nome
              final List<Map<String, dynamic>> details = [];
              final Set<String> uniqueDetailNames = {};
              
              for (var detail in allDetailsData) {
                final detailName = detail['detail_name'] as String;
                if (!uniqueDetailNames.contains(detailName)) {
                  uniqueDetailNames.add(detailName);
                  details.add({
                    'name': detailName,
                    'value': detail['detail_value'],
                    'observation': detail['observation'],
                    'id': detail['id'],
                  });
                }
              }
              
              // Salvar cache de detalhes para este item
              await _cacheTemplates('detail_templates_$itemName', details);
            }
          }
        }
      }
      
      // Salvar timestamp de última atualização do cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('templates_cache_timestamp', DateTime.now().toIso8601String());
      
      print('Cache de templates atualizado com sucesso');
    } catch (e) {
      print('Erro ao atualizar cache de templates: $e');
    }
  }

  // Verifica se o cache de templates precisa ser atualizado (mais de 24h)
  Future<bool> needsCacheUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getString('templates_cache_timestamp');
      
      if (lastUpdate == null) return true;
      
      final lastUpdateTime = DateTime.parse(lastUpdate);
      final now = DateTime.now();
      
      // Se o cache for mais antigo que 24 horas, precisa atualizar
      return now.difference(lastUpdateTime).inHours > 24;
    } catch (e) {
      print('Erro ao verificar cache: $e');
      return true;
    }
  }

  // Função interna para salvar templates no cache
  Future<void> _cacheTemplates(String key, List<Map<String, dynamic>> templates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(templates));
    } catch (e) {
      print('Erro ao salvar templates no cache ($key): $e');
    }
  }

  // Obter templates de ambientes do cache
  Future<List<Map<String, dynamic>>> getRoomTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templatesString = prefs.getString('room_templates');
      
      if (templatesString == null) return [];
      
      final List<dynamic> decodedList = jsonDecode(templatesString);
      return decodedList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Erro ao ler templates de ambientes do cache: $e');
      return [];
    }
  }

  // Obter templates de itens do cache para um tipo de ambiente
  Future<List<Map<String, dynamic>>> getItemTemplates(String roomName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templatesString = prefs.getString('item_templates_$roomName');
      
      if (templatesString == null) return [];
      
      final List<dynamic> decodedList = jsonDecode(templatesString);
      return decodedList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Erro ao ler templates de itens do cache para $roomName: $e');
      return [];
    }
  }

  // Obter templates de detalhes do cache para um tipo de item
  Future<List<Map<String, dynamic>>> getDetailTemplates(String itemName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templatesString = prefs.getString('detail_templates_$itemName');
      
      if (templatesString == null) return [];
      
      final List<dynamic> decodedList = jsonDecode(templatesString);
      return decodedList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Erro ao ler templates de detalhes do cache para $itemName: $e');
      return [];
    }
  }
}