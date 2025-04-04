
// lib/data/repositories/nonconformity_repository_impl.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inspection_app/data/repositories/nonconformity_repository.dart';
import 'package:inspection_app/services/local_database_service.dart';
import 'package:inspection_app/services/connectivity/connectivity_service.dart';

class NonConformityRepositoryImpl implements NonConformityRepository {
  final _supabase = Supabase.instance.client;
  final LocalDatabaseService _localDatabaseService;
  final ConnectivityService _connectivityService;
  
  NonConformityRepositoryImpl({
    required LocalDatabaseService localDatabaseService,
    required ConnectivityService connectivityService,
  })  : _localDatabaseService = localDatabaseService,
        _connectivityService = connectivityService;
  
  @override
  Future<List<Map<String, dynamic>>> getNonConformitiesByInspection(int inspectionId) async {
    try {
      if (_connectivityService.isOffline) {
        // Load from local database
        return await _localDatabaseService.getNonConformitiesByInspection(inspectionId);
      } else {
        // Try to load from Supabase
        try {
          final data = await _supabase
              .from('non_conformities')
              .select(
                  '*, rooms!inner(*), room_items!inner(*), item_details!inner(*)')
              .eq('inspection_id', inspectionId)
              .order('created_at', ascending: false);
              
          return List<Map<String, dynamic>>.from(data);
        } catch (e) {
          // If failed, try to load from local database
          return await _localDatabaseService.getNonConformitiesByInspection(inspectionId);
        }
      }
    } catch (e) {
      print('Error getting non-conformities: $e');
      return [];
    }
  }
  
  @override
  Future<Map<String, dynamic>> addNonConformity(
    int inspectionId,
    int roomId,
    int itemId,
    int detailId,
    String description,
    String severity, {
    String? correctiveAction,
    DateTime? deadline,
  }) async {
    try {
      // Prepare data
      final nonConformityData = {
        'inspection_id': inspectionId,
        'room_id': roomId,
        'item_id': itemId,
        'detail_id': detailId,
        'description': description,
        'severity': severity,
        'corrective_action': correctiveAction,
        'deadline': deadline?.toIso8601String(),
        'status': 'pendente',
        'created_at': DateTime.now().toIso8601String(),
      };
      
      if (_connectivityService.isOffline) {
        // Save to local database only
        final id = -DateTime.now().millisecondsSinceEpoch;
        nonConformityData['id'] = id;
        
        await _localDatabaseService.saveNonConformity(nonConformityData);
        
        return nonConformityData;
      } else {
        // Try to save to Supabase
        try {
          final result = await _supabase
              .from('non_conformities')
              .insert(nonConformityData)
              .select('id')
              .single();
              
          final id = result['id'];
          nonConformityData['id'] = id;
          
          // Also save to local database
          await _localDatabaseService.saveNonConformity(nonConformityData);
          
          return nonConformityData;
        } catch (e) {
          // If failed, save to local database only
          final id = -DateTime.now().millisecondsSinceEpoch;
          nonConformityData['id'] = id;
          
          await _localDatabaseService.saveNonConformity(nonConformityData);
          
          return nonConformityData;
        }
      }
    } catch (e) {
      print('Error adding non-conformity: $e');
      throw Exception('Failed to add non-conformity');
    }
  }
  
  @override
  Future<void> updateNonConformityStatus(int nonConformityId, String newStatus) async {
    try {
      // First update local database
      await _localDatabaseService.updateNonConformityStatus(
        nonConformityId,
        newStatus,
      );
      
      // Then try to update Supabase if online
      if (!_connectivityService.isOffline) {
        try {
          await _supabase.from('non_conformities').update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', nonConformityId);
        } catch (e) {
          print('Error updating status in Supabase: $e');
          // Continue anyway since we updated locally
        }
      }
    } catch (e) {
      print('Error updating non-conformity status: $e');
      throw Exception('Failed to update status');
    }
  }
  
  @override
  Future<List<Map<String, dynamic>>> getMediaByNonConformity(int nonConformityId) async {
    try {
      return await _localDatabaseService.getNonConformityMedia(nonConformityId);
    } catch (e) {
      print('Error getting non-conformity media: $e');
      return [];
    }
  }
  
  @override
  Future<void> addMediaToNonConformity(
    int nonConformityId,
    String mediaPath,
    String mediaType,
  ) async {
    try {
      await _localDatabaseService.saveNonConformityMedia(
        nonConformityId,
        mediaPath,
        mediaType,
      );
      
      // TODO: Implement syncing with Supabase when online
    } catch (e) {
      print('Error adding media to non-conformity: $e');
      throw Exception('Failed to add media');
    }
  }
  
  @override
  Future<void> removeMediaFromNonConformity(
    int nonConformityId,
    String mediaPath,
  ) async {
    try {
      await _localDatabaseService.deleteNonConformityMedia(
        nonConformityId,
        mediaPath,
      );
      
      // TODO: Implement syncing with Supabase when online
    } catch (e) {
      print('Error removing media from non-conformity: $e');
      throw Exception('Failed to remove media');
    }
  }
}