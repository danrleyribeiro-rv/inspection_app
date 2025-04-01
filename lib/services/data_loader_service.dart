// lib/services/data_loader_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DataLoaderService {
  final _supabase = Supabase.instance.client;
  
  // Carregar templates de ambientes disponíveis no sistema
  Future<List<Map<String, dynamic>>> loadRoomTemplates() async {
    try {
      // Primeiro tenta buscar do cache
      final cachedTemplates = await _getCachedRoomTemplates();
      if (cachedTemplates.isNotEmpty) {
        return cachedTemplates;
      }
      
      // Tenta buscar do servidor se estiver online
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        final data = await _supabase
            .from('rooms')
            .select('id, room_name, room_label, observation')
            .order('room_name', ascending: true)
            .limit(100); // limitar para evitar excesso de dados
        
        // Agrupar ambientes por tipo
        final List<Map<String, dynamic>> templates = [];
        final Set<String> uniqueRoomNames = {};
        
        for (var room in data) {
          final roomName = room['room_name'] as String;
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
        
        // Salvar no cache
        await _cacheRoomTemplates(templates);
        
        return templates;
      }
      
      return [];
    } catch (e) {
      print('Erro ao carregar templates de ambientes: $e');
      return [];
    }
  }
  
  // Carregar templates de itens disponíveis para um tipo de ambiente
  Future<List<Map<String, dynamic>>> loadItemTemplates(String roomName) async {
    try {
      // Primeiro tenta buscar do cache
      final cachedTemplates = await _getCachedItemTemplates(roomName);
      if (cachedTemplates.isNotEmpty) {
        return cachedTemplates;
      }
      
      // Tenta buscar do servidor se estiver online
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        // Primeiro buscar IDs de ambientes com esse nome
        final roomsData = await _supabase
            .from('rooms')
            .select('id')
            .eq('room_name', roomName)
            .limit(100);
        
        if (roomsData.isEmpty) return [];
        
        // Lista de IDs de ambientes com esse nome
        final List<int> roomIds = roomsData.map<int>((r) => r['id'] as int).toList();
        
        // Buscar itens associados a esses ambientes
        // Usamos uma lista de consultas separadas para cada roomId
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
      
      return [];
    } catch (e) {
      print('Erro ao carregar templates de itens: $e');
      return [];
    }
  }
  
  // Carregar templates de detalhes disponíveis para um tipo de item
  Future<List<Map<String, dynamic>>> loadDetailTemplates(String itemName) async {
    try {
      // Primeiro tenta buscar do cache
      final cachedTemplates = await _getCachedDetailTemplates(itemName);
      if (cachedTemplates.isNotEmpty) {
        return cachedTemplates;
      }
      
      // Tenta buscar do servidor se estiver online
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        // Primeiro buscar IDs de itens com esse nome
        final itemsData = await _supabase
            .from('room_items')
            .select('id')
            .eq('item_name', itemName)
            .limit(100);
        
        if (itemsData.isEmpty) return [];
        
        // Lista de IDs de itens com esse nome
        final List<int> itemIds = itemsData.map<int>((i) => i['id'] as int).toList();
        
        // Buscar detalhes associados a esses itens
        // Usamos uma lista de consultas separadas para cada itemId
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
      
      return [];
    } catch (e) {
      print('Erro ao carregar templates de detalhes: $e');
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