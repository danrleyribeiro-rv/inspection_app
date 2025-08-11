// lib/presentation/screens/home/inspection_tab.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'dart:developer';
import 'package:lince_inspecoes/presentation/screens/inspection/inspection_detail_screen.dart';
import 'package:lince_inspecoes/presentation/widgets/common/inspection_card.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/services/native_sync_service.dart';
import 'package:lince_inspecoes/services/manual_sync_service.dart';
import 'package:lince_inspecoes/models/sync_progress.dart';

// Função auxiliar para formatação de data em pt-BR
String formatDateBR(DateTime date) {
  return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
}

class InspectionsTab extends StatefulWidget {
  const InspectionsTab({super.key});

  @override
  State<InspectionsTab> createState() => _InspectionsTabState();
}

class _InspectionsTabState extends State<InspectionsTab> {
  final _auth = FirebaseAuth.instance;
  // _firestore removido - não utilizado após remoção do botão completar
  final _serviceFactory = EnhancedOfflineServiceFactory.instance;
  String? _googleMapsApiKey;

  // Filtros adicionais

  bool _isLoading = true;
  List<Map<String, dynamic>> _inspections = [];
  List<Map<String, dynamic>> _filteredInspections = [];
  bool _isSearching = false;
  final _searchController = TextEditingController();

  // Track inspections that have newer data in the cloud
  final Set<String> _inspectionsWithCloudUpdates = <String>{};

  // Track inspections with detected conflicts
  final Set<String> _inspectionsWithConflicts = <String>{};

  // Track inspections currently downloading
  final Set<String> _downloadingInspections = <String>{};

  // Track inspections sync status based on history
  final Map<String, bool> _inspectionSyncStatus = <String, bool>{};

  // Track inspections currently syncing
  final Map<String, bool> _syncingStatus = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _loadInspections();
    _searchController.addListener(_filterInspections);
    _startCloudUpdateChecks();
    _setupSyncProgressListener();
    _listenToDataModifications();
  }

  void _setupSyncProgressListener() {
    NativeSyncService.instance.syncProgressStream.listen((progress) {
      debugPrint('InspectionTab: Sync progress received - ID: ${progress.inspectionId}, Phase: ${progress.phase}');
      if (mounted) {
        setState(() {
          if (progress.phase == SyncPhase.completed) {
            debugPrint('InspectionTab: Processing sync completion for ${progress.inspectionId}');
            // Download/Upload completed, remove from downloading set
            _downloadingInspections.remove(progress.inspectionId);
            
            // Remove syncing status
            _syncingStatus[progress.inspectionId] = false;

            // Update sync status - mark as synced when completed
            // This will hide the sync button after successful upload
            _inspectionSyncStatus[progress.inspectionId] = true;
            debugPrint('InspectionTab: Set _inspectionSyncStatus[${progress.inspectionId}] = true');
            // Remove from conflicts if it was resolved
            _inspectionsWithConflicts.remove(progress.inspectionId);

            // Clear local changes flag for this inspection immediately
            _markInspectionAsSynced(progress.inspectionId).catchError((e) {
              debugPrint('Error during async marking as synced: $e');
            });

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Inspeção ${progress.inspectionId} sincronizada com sucesso!'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }

            // Add delay to allow database operations to complete before refreshing UI
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) {
                _loadInspections();
              }
            });
          } else if (progress.phase == SyncPhase.error) {
            // Download/Upload failed, remove from downloading set
            _downloadingInspections.remove(progress.inspectionId);
            
            // Remove syncing status on error
            _syncingStatus[progress.inspectionId] = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterInspections);
    _searchController.dispose();
    super.dispose();
  }

  void _loadApiKey() {
    _googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) {
      log('ERRO CRÍTICO: GOOGLE_MAPS_API_KEY não encontrada no arquivo .env!',
          level: 1000);
    } else {
      log('[InspectionsTab] Google Maps API Key loaded successfully.');
    }
  }

  Future<void> _loadInspections() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        // User not logged in
        await _loadCachedInspections();
        return;
      }

      // Loading inspections for user

      // OFFLINE-FIRST: Always load cached inspections only
      await _loadCachedInspections();

      // Atualizar status de sincronização baseado no histórico
      await _updateSyncStatusForAllInspections();

      // In offline-first mode, we don't automatically sync from cloud
      // Users must explicitly download inspections they want to work on
    } catch (e) {
      debugPrint('Error loading inspections: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar as vistorias: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _updateSyncStatusForAllInspections() async {
    try {
      // Updating sync status for all inspections

      final inspectionIds =
          _inspections.map((inspection) => inspection['id'] as String).toList();

      for (final inspectionId in inspectionIds) {
        final isSynced = await _isInspectionSyncedWithHistory(inspectionId);
        final hasConflicts = await _hasConflictsWithHistory(inspectionId);

        if (mounted) {
          setState(() {
            // CORREÇÃO: Verificar se há mudanças locais que invalidam o status de sincronização
            final currentStatus = _inspectionSyncStatus[inspectionId];
            
            // Verificar se há novas mudanças na inspeção atual
            final inspectionData = _inspections.firstWhere(
              (insp) => insp['id'] == inspectionId,
              orElse: () => <String, dynamic>{},
            );
            final hasNewChanges = inspectionData['has_local_changes'] == true ||
                inspectionData['_local_status'] == 'modified';
            
            if (hasNewChanges) {
              // Há mudanças locais, sempre marcar como não sincronizado
              _inspectionSyncStatus[inspectionId] = false;
              debugPrint('InspectionTab: Detected changes for $inspectionId - setting sync status to false');
            } else if (currentStatus != true) {
              // Se não há mudanças e não estava marcado como sincronizado, usar valor do histórico
              _inspectionSyncStatus[inspectionId] = isSynced;
              debugPrint('InspectionTab: Updated sync status from history for $inspectionId: $isSynced');
            } else {
              // Se estava marcado como sincronizado e não há mudanças, manter como sincronizado
              debugPrint('InspectionTab: No new changes for $inspectionId - keeping sync status true');
            }
            
            if (hasConflicts) {
              _inspectionsWithConflicts.add(inspectionId);
            } else {
              _inspectionsWithConflicts.remove(inspectionId);
            }
          });
        }
      }

      // Updated sync status for all inspections
    } catch (e) {
      debugPrint('Error updating sync status: $e');
    }
  }

  Future<void> _loadCachedInspections() async {
    try {
      // Loading cached inspections only

      final cachedInspections = await _getCachedInspections();

      if (mounted) {
        // Ordenar por data de última modificação (updated_at) em ordem decrescente
        cachedInspections.sort((a, b) {
          try {
            final aUpdatedAt = a['updated_at'];
            final bUpdatedAt = b['updated_at'];
            
            // Se ambos têm updated_at, comparar
            if (aUpdatedAt != null && bUpdatedAt != null) {
              DateTime aDate;
              DateTime bDate;
              
              if (aUpdatedAt is String) {
                aDate = DateTime.parse(aUpdatedAt);
              } else {
                aDate = DateTime.now(); // fallback
              }
              
              if (bUpdatedAt is String) {
                bDate = DateTime.parse(bUpdatedAt);
              } else {
                bDate = DateTime.now(); // fallback
              }
              
              return bDate.compareTo(aDate); // Ordem decrescente (mais recente primeiro)
            }
            
            // Se apenas um tem updated_at, priorizar o que tem
            if (aUpdatedAt != null) return -1;
            if (bUpdatedAt != null) return 1;
            
            // Se nenhum tem updated_at, manter ordem original
            return 0;
          } catch (e) {
            debugPrint('Error sorting inspections by updated_at: $e');
            return 0;
          }
        });
        
        setState(() {
          _inspections = cachedInspections;
          _filteredInspections = List.from(_inspections);
          _isLoading = false;
          
          // Clean up any orphaned syncing status from inspections that no longer exist
          final currentInspectionIds = cachedInspections.map((i) => i['id'] as String).toSet();
          _syncingStatus.removeWhere((key, value) => !currentInspectionIds.contains(key));
          
          // Reset any syncing status that might be stuck
          for (final inspectionId in currentInspectionIds) {
            if (_syncingStatus[inspectionId] == true) {
              debugPrint('InspectionTab: Resetting stuck syncing status for $inspectionId');
              _syncingStatus[inspectionId] = false;
            }
          }
        });
      }

      // Loaded cached inspections successfully
    } catch (e) {
      debugPrint('Error loading cached inspections: $e');
      if (mounted) {
        setState(() {
          _inspections = [];
          _filteredInspections = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getCachedInspections() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return [];
      }

      // Get all inspections from local database
      final allInspections =
          await _serviceFactory.dataService.getAllInspections();

      // Filter by user ID and deleted_at is null (not deleted)
      // Accept inspections where inspectorId is either the current user or null/empty
      // (since downloaded inspections might have missing inspectorId)
      final userInspections = allInspections
          .where((inspection) =>
              (inspection.inspectorId == userId || 
               inspection.inspectorId == null || 
               inspection.inspectorId!.isEmpty) && 
              inspection.deletedAt == null)
          .toList();

      final cachedInspections = <Map<String, dynamic>>[];

      for (final inspection in userInspections) {
        try {
          // Convert Inspection to Map format compatible with UI
          final inspectionMap = inspection.toMap();
          inspectionMap['_is_cached'] = true;
          inspectionMap['_local_status'] = inspection.status;
          
          // Debug: Log status para troubleshooting
          if (inspection.id == 'ggamoZ2ezDpuAo4xmH9H') {
            debugPrint('InspectionTab: Loading inspection ${inspection.id} with status: "${inspection.status}"');
            debugPrint('InspectionTab: _local_status set to: "${inspectionMap['_local_status']}"');
          }

          // Check if there are actual local changes that need sync
          final hasRealChanges = await _checkForRealLocalChanges(inspection.id);
          inspectionMap['has_local_changes'] = hasRealChanges;
          
          // Log para debug
          if (inspection.id == 'PgepInIdfFdw47YnRqO3') {
            debugPrint('InspectionTab: Loading inspection ${inspection.id}:');
            debugPrint('  - inspection.hasLocalChanges: ${inspection.hasLocalChanges}');
            debugPrint('  - hasRealChanges (calculated): $hasRealChanges');
            debugPrint('  - inspection.status: ${inspection.status}');
          }

          cachedInspections.add(inspectionMap);
        } catch (e) {
          debugPrint('Error converting inspection ${inspection.id}: $e');
          continue;
        }
      }

      return cachedInspections;
    } catch (e) {
      debugPrint('Error getting cached inspections: $e');
      return [];
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredInspections = _inspections.where((inspection) {
        // Aplicar filtro de texto
        bool matchesSearchText = true;
        final query = _searchController.text.toLowerCase();
        if (query.isNotEmpty) {
          matchesSearchText = false;
          final title = inspection['title']?.toString().toLowerCase() ?? '';
          if (title.contains(query)) matchesSearchText = true;
          final address =
              inspection['address_string']?.toString().toLowerCase() ?? '';
          if (address.contains(query)) matchesSearchText = true;
          final status = inspection['status']?.toString().toLowerCase() ?? '';
          if (status.contains(query)) matchesSearchText = true;
          final projectId =
              inspection['project_id']?.toString().toLowerCase() ?? '';
          if (projectId.contains(query)) matchesSearchText = true;
          final observation =
              inspection['observation']?.toString().toLowerCase() ?? '';
          if (observation.contains(query)) matchesSearchText = true;
          if (inspection['scheduled_date'] != null) {
            try {
              DateTime? scheduledDate;
              if (inspection['scheduled_date'] is String) {
                scheduledDate = DateTime.parse(inspection['scheduled_date']);
              } else if (inspection['scheduled_date'] is Timestamp) {
                scheduledDate = inspection['scheduled_date'].toDate();
              }
              if (scheduledDate != null) {
                final formattedDate =
                    "${scheduledDate.day.toString().padLeft(2, '0')}/"
                    "${scheduledDate.month.toString().padLeft(2, '0')}/"
                    "${scheduledDate.year}";
                if (formattedDate.contains(query)) matchesSearchText = true;
              }
            } catch (e) {
              // Error parsing date for search
            }
          }
        }
        return matchesSearchText;
      }).toList();
      
      // Manter a mesma ordenação por updated_at na lista filtrada
      _filteredInspections.sort((a, b) {
        try {
          final aUpdatedAt = a['updated_at'];
          final bUpdatedAt = b['updated_at'];
          
          if (aUpdatedAt != null && bUpdatedAt != null) {
            DateTime aDate;
            DateTime bDate;
            
            if (aUpdatedAt is String) {
              aDate = DateTime.parse(aUpdatedAt);
            } else {
              aDate = DateTime.now();
            }
            
            if (bUpdatedAt is String) {
              bDate = DateTime.parse(bUpdatedAt);
            } else {
              bDate = DateTime.now();
            }
            
            return bDate.compareTo(aDate); // Ordem decrescente
          }
          
          if (aUpdatedAt != null) return -1;
          if (bUpdatedAt != null) return 1;
          return 0;
        } catch (e) {
          return 0;
        }
      });
    });
  }

  void _filterInspections() {
    _applyFilters();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _applyFilters();
    });
  }

  // Método _completeInspection removido - apenas sincronização manual disponível

  Future<void> _downloadInspectionData(String inspectionId) async {
    try {
      // Add to downloading set and update UI immediately
      setState(() {
        _downloadingInspections.add(inspectionId);
      });

      // Show notification immediately BEFORE starting download
      await NativeSyncService.instance.initialize();

      // Use native sync service for background download
      await NativeSyncService.instance.startInspectionDownload(inspectionId);

      // Clear the cloud updates flag since we just downloaded the latest data
      _inspectionsWithCloudUpdates.remove(inspectionId);

      // Note: UI refresh will happen via sync progress listener
    } catch (e) {
      debugPrint('Error downloading inspection data: $e');

      // Remove from downloading set on error
      setState(() {
        _downloadingInspections.remove(inspectionId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao baixar para offline: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _syncInspectionData(String inspectionId) async {
    try {
      // Set syncing status to true immediately
      setState(() {
        _syncingStatus[inspectionId] = true;
      });

      // Check for conflicts before syncing
      final hasConflicts = await _hasConflictsWithHistory(inspectionId);

      if (hasConflicts) {
        // Show conflict alert dialog
        if (!mounted) return;
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Conflito Detectado'),
            content: const Text(
                'A inspeção foi modificada na nuvem desde o último download. '
                'Suas alterações podem sobrescrever as alterações feitas por outros usuários.\n\n'
                'Deseja continuar com a sincronização?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Continuar'),
              ),
            ],
          ),
        );

        if (shouldProceed != true) {
          // User cancelled, remove syncing status
          setState(() {
            _syncingStatus[inspectionId] = false;
          });
          return;
        }
      }

      // Use native sync service for background sync
      await NativeSyncService.instance.startInspectionSync(inspectionId);

      // DON'T update sync status immediately - wait for actual sync completion
      // The sync status will be updated when we receive the sync result

      // Refresh the list to show updated sync status
      _loadInspections();
    } catch (e) {
      debugPrint('Error syncing inspection data: $e');

      // Remove syncing status on error
      setState(() {
        _syncingStatus[inspectionId] = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao sincronizar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<bool> _checkForRealLocalChanges(String inspectionId) async {
    try {
      // Check ONLY if this specific inspection and its related entities need sync
      final inspection = await _serviceFactory.dataService.getInspection(inspectionId);
      if (inspection == null) return false;

      // Check if inspection itself needs sync
      if (inspection.hasLocalChanges) {
        debugPrint('InspectionTab: Inspection $inspectionId has local changes: true');
        return true;
      }

      // Check if any topics/items/details for this specific inspection need sync
      final hasRelatedChanges = await _checkInspectionRelatedEntitiesNeedSync(inspectionId);
      debugPrint('InspectionTab: Inspection $inspectionId related entities need sync: $hasRelatedChanges');
      
      return hasRelatedChanges;
    } catch (e) {
      debugPrint('Error checking for real local changes: $e');
      return false;
    }
  }

  Future<bool> _checkInspectionRelatedEntitiesNeedSync(String inspectionId) async {
    try {
      // Use the ManualSyncService to check if this specific inspection has pending changes
      final manualSyncService = ManualSyncService();
      final pendingInspections = await manualSyncService.getPendingInspectionIds();
      
      return pendingInspections.contains(inspectionId);
    } catch (e) {
      debugPrint('Error checking related entities for $inspectionId: $e');
      return false;
    }
  }


  // Novo método que usa o sistema de histórico para verificar sincronização
  Future<bool> _isInspectionSyncedWithHistory(String inspectionId) async {
    try {
      final isSynced =
          await _serviceFactory.dataService.isInspectionSynced(inspectionId);
      return isSynced;
    } catch (e) {
      debugPrint('Error checking sync status: $e');
      return false;
    }
  }

  // Detecta conflitos baseado no histórico
  Future<bool> _hasConflictsWithHistory(String inspectionId) async {
    try {
      final hasConflicts = await _serviceFactory.dataService
          .hasUnresolvedConflicts(inspectionId);
      return hasConflicts;
    } catch (e) {
      debugPrint('Error checking conflicts: $e');
      return false;
    }
  }

  // Marca a inspeção como sincronizada, removendo flags de mudanças locais
  Future<void> _markInspectionAsSynced(String inspectionId) async {
    try {
      // PRIMEIRO: Definir o status de sincronização na memória
      _inspectionSyncStatus[inspectionId] = true;
      debugPrint('InspectionTab: Set _inspectionSyncStatus[$inspectionId] = true');
      
      // Encontrar a inspeção na lista e limpar flags locais
      final inspectionIndex = _inspections.indexWhere(
        (inspection) => inspection['id'] == inspectionId,
      );
      
      if (inspectionIndex >= 0) {
        _inspections[inspectionIndex]['has_local_changes'] = false;
        _inspections[inspectionIndex]['_local_status'] = null;
        debugPrint('InspectionTab: Marked inspection $inspectionId as synced - local flags cleared in memory');
      }

      // IMPORTANTE: Também limpar no banco de dados para persistir o estado
      try {
        final inspection = await _serviceFactory.dataService.getInspection(inspectionId);
        if (inspection != null) {
          // Usar o método do serviço para marcar como sincronizado no banco
          await _serviceFactory.dataService.markInspectionSynced(inspectionId);
          debugPrint('InspectionTab: Marked inspection $inspectionId as synced in database');
        }
      } catch (dbError) {
        debugPrint('Error marking inspection as synced in database: $dbError');
      }

      // Força atualização da lista após marcar como sincronizado
      if (mounted) {
        setState(() {
          // Força rebuild da UI com os novos valores
        });
        // Recarrega a lista do banco para garantir consistência
        await _loadCachedInspections();
        debugPrint('InspectionTab: Reloaded inspections after marking $inspectionId as synced');
      }
    } catch (e) {
      debugPrint('Error marking inspection as synced: $e');
    }
  }

  // Método para detectar quando uma inspeção foi modificada e deve mostrar botão de sync
  void markInspectionAsModified(String inspectionId) {
    setState(() {
      // Remove da lista de sincronizados para mostrar botão novamente
      _inspectionSyncStatus[inspectionId] = false;
      
      // IMPORTANTE: Reset syncing status to prevent loading state
      _syncingStatus[inspectionId] = false;
      
      // Atualizar updated_at da inspeção na lista local para reordenação
      final inspectionIndex = _inspections.indexWhere(
        (inspection) => inspection['id'] == inspectionId,
      );
      
      if (inspectionIndex >= 0) {
        _inspections[inspectionIndex]['updated_at'] = DateTime.now().toIso8601String();
        debugPrint('InspectionTab: Updated updated_at for $inspectionId to move it to top of list');
      }
    });
    
    // Reordenar a lista para mover a inspeção modificada para o topo
    _applyFilters();
    
    debugPrint('InspectionTab: Set _inspectionSyncStatus[$inspectionId] = false and _syncingStatus[$inspectionId] = false - sync button will appear in normal state');
  }

  Future<void> _removeInspection(String inspectionId) async {
    try {
      // Remove from local database
      await _serviceFactory.dataService.deleteInspection(inspectionId);
      
      // Remove from local state
      setState(() {
        _inspections.removeWhere((inspection) => inspection['id'] == inspectionId);
        _filteredInspections.removeWhere((inspection) => inspection['id'] == inspectionId);
        _downloadingInspections.remove(inspectionId);
        _inspectionSyncStatus.remove(inspectionId);
        _syncingStatus.remove(inspectionId);
        _inspectionsWithConflicts.remove(inspectionId);
        _inspectionsWithCloudUpdates.remove(inspectionId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspeção removida com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error removing inspection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover inspeção: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Escuta modificações em dados da inspeção
  void _listenToDataModifications() {
    // OFFLINE-FIRST: Disabled automatic sync check timer
    // Changes are stored locally only and sync only when the sync button is manually clicked
    // Timer.periodic(const Duration(seconds: 2), (timer) async {
    //   if (!mounted) {
    //     timer.cancel();
    //     return;
    //   }
    //   await _checkForDataModifications();
    // });
  }

  // OFFLINE-FIRST: This method is no longer used since automatic sync checks are disabled
  // Future<void> _checkForDataModifications() async {
  //   try {
  //     for (final inspection in _inspections) {
  //       final inspectionId = inspection['id'] as String;
  //       
  //       // Se esta inspeção foi marcada como recentemente sincronizada, verifica se houve modificação
  //       if (_inspectionSyncStatus[inspectionId] == true) {
  //         // Verifica se há entidades não sincronizadas para esta inspeção
  //         final hasUnsyncedData = await _hasRealUnsyncedData(inspectionId);
  //         if (hasUnsyncedData) {
  //           debugPrint('InspectionTab: Detected modification for $inspectionId - clearing recent sync status');
  //           setState(() {
  //             _inspectionSyncStatus[inspectionId] = false;
  //           });
  //         }
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint('InspectionTab: Error checking data modifications: $e');
  //   }
  // }

  // OFFLINE-FIRST: This method is no longer used since automatic sync checks are disabled
  // Future<bool> _hasRealUnsyncedData(String inspectionId) async {
  //   try {
  //     // PRIMEIRO: Verificar se a própria inspeção tem mudanças locais
  //     final inspection = await _serviceFactory.dataService.getInspection(inspectionId);
  //     if (inspection != null && inspection.hasLocalChanges) {
  //       debugPrint('InspectionTab: Inspection $inspectionId has hasLocalChanges=true');
  //       return true;
  //     }

  //     // Verificar se há entidades que precisam ser sincronizadas
  //     final topicsNeedingSync = await _serviceFactory.dataService.getTopicsNeedingSync();
  //     final inspectionTopics = topicsNeedingSync.where((t) => t.inspectionId == inspectionId).toList();
  //     if (inspectionTopics.isNotEmpty) {
  //       debugPrint('InspectionTab: Found ${inspectionTopics.length} topics needing sync for $inspectionId');
  //       return true;
  //     }

  //     final itemsNeedingSync = await _serviceFactory.dataService.getItemsNeedingSync();
  //     final inspectionItems = itemsNeedingSync.where((i) => i.inspectionId == inspectionId).toList();
  //     if (inspectionItems.isNotEmpty) {
  //       debugPrint('InspectionTab: Found ${inspectionItems.length} items needing sync for $inspectionId');
  //       return true;
  //     }

  //     final detailsNeedingSync = await _serviceFactory.dataService.getDetailsNeedingSync();
  //     final inspectionDetails = detailsNeedingSync.where((d) => d.inspectionId == inspectionId).toList();
  //     if (inspectionDetails.isNotEmpty) {
  //       debugPrint('InspectionTab: Found ${inspectionDetails.length} details needing sync for $inspectionId');
  //       return true;
  //     }

  //     // Verificar mídias que precisam ser sincronizadas
  //     final mediaNeedingSync = await _serviceFactory.dataService.getMediaNeedingSync();
  //     final inspectionMedia = mediaNeedingSync.where((m) => m.inspectionId == inspectionId).toList();
  //     if (inspectionMedia.isNotEmpty) {
  //       debugPrint('InspectionTab: Found ${inspectionMedia.length} media files needing sync for $inspectionId');
  //       return true;
  //     }

  //     return false;
  //   } catch (e) {
  //     debugPrint('InspectionTab: Error checking real unsynced data: $e');
  //     return false;
  //   }
  // }


  bool _isInspectionFullyDownloaded(String inspectionId) {
    try {
      // If inspection is currently downloading, don't show it as downloaded
      if (_downloadingInspections.contains(inspectionId)) {
        return false;
      }

      // Check if inspection exists in the local list (meaning it was downloaded)
      final inspectionInList = _inspections.firstWhere(
        (inspection) => inspection['id'] == inspectionId,
        orElse: () => <String, dynamic>{},
      );

      // If inspection exists in our local list, it means it was downloaded
      final isDownloaded =
          inspectionInList.isNotEmpty && inspectionInList['_is_cached'] == true;

      return isDownloaded;
    } catch (e) {
      debugPrint('Error checking download status: $e');
      return false;
    }
  }

  // Method removed - not used anywhere

  // Method removed - not used anywhere

  void _startCloudUpdateChecks() {
    // Check for cloud updates every 15 seconds when online
    Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      // Only check if we're not loading and have inspections
      if (!_isLoading && _inspections.isNotEmpty) {
        _checkForCloudUpdates();
      }
    });
  }

  Future<void> _checkForCloudUpdates() async {
    try {
      // Check if we have internet connectivity
      if (!await _serviceFactory.syncService.isConnected()) {
        return;
      }

      // Check each downloaded inspection for cloud conflicts
      for (final inspection in _inspections) {
        final inspectionId = inspection['id'] as String;

        // Only check fully downloaded inspections
        if (_isInspectionFullyDownloaded(inspectionId)) {
          await _checkSingleInspectionForConflicts(inspectionId);
        }
      }
    } catch (e) {
      debugPrint('Error checking cloud updates: $e');
    }
  }

  Future<void> _checkSingleInspectionForConflicts(String inspectionId) async {
    try {
      // Get local inspection
      final localInspection =
          await _serviceFactory.dataService.getInspection(inspectionId);
      if (localInspection == null) return;

      // Check if local inspection has changes
      if (!localInspection.hasLocalChanges) {
        // No local changes, no conflicts possible
        setState(() {
          _inspectionsWithConflicts.remove(inspectionId);
        });
        return;
      }

      // OFFLINE-FIRST: Don't sync automatically to check conflicts
      // Instead, just mark that there are local changes that need manual sync
      debugPrint('InspectionTab: Inspection $inspectionId has local changes - manual sync required');
      
      // Remove from conflicts list since we're not checking cloud conflicts automatically
      setState(() {
        _inspectionsWithConflicts.remove(inspectionId);
      });
    } catch (e) {
      debugPrint('Error checking conflicts for $inspectionId: $e');
    }
  }

  // Method removed - not used anywhere

  bool _hasPendingImages(String inspectionId) {
    try {
      // In offline-first mode, we assume there are no pending images to sync
      // Images are stored locally and only uploaded when explicitly synced
      return false;
    } catch (e) {
      debugPrint('Error checking pending images: $e');
      return false;
    }
  }

  int _getPendingImagesCount(String inspectionId) {
    try {
      // In offline-first mode, we assume no pending images to sync
      // Images are stored locally and only uploaded when explicitly synced
      return 0;
    } catch (e) {
      debugPrint('Error counting pending images: $e');
      return 0;
    }
  }

  Future<void> _syncInspectionImages(String inspectionId) async {
    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text('Sincronizando imagens...'),
                ),
              ],
            ),
          ),
        );
      }

      // Upload pending media for this specific inspection
      // Upload manual seria implementado aqui no futuro
      debugPrint('Manual upload would be implemented here');

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Image sync completed successfully

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagens sincronizadas com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Refresh the list to show updated sync status
        _loadInspections();
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      debugPrint('Error syncing images: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao sincronizar imagens: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // API key validation happens silently

    return Scaffold(
      backgroundColor: const Color(0xFF312456),
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Pesquisar...',
                  hintStyle: const TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    onPressed: _clearSearch,
                  ),
                ),
              )
            : const Text('Inspeções'),
        backgroundColor: const Color(0xFF312456),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Search Icon
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              tooltip: 'Pesquisar',
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          // Download Button
          IconButton(
            icon: const Icon(Icons.cloud_download, color: Colors.white),
            tooltip: 'Baixar Vistorias',
            onPressed: _isLoading ? null : _showDownloadDialog,
          ),
          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Atualizar Vistorias',
            onPressed: _isLoading ? null : _loadInspections,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : _filteredInspections.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadInspections,
                        color: Colors.white,
                        backgroundColor: const Color(0xFF312456),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredInspections.length,
                          itemBuilder: (context, index) {
                            final inspection = _filteredInspections[index];
                            final inspectionId = inspection['id'] as String;
                            
                            // Verificar mudanças locais reais diretamente no banco
                            final inspectionInList = _inspections.firstWhere(
                              (insp) => insp['id'] == inspectionId,
                              orElse: () => <String, dynamic>{},
                            );
                            
                            final localStatus = inspectionInList['_local_status'] ?? '';
                            final hasLocalChanges = inspectionInList['has_local_changes'] == true ||
                                inspectionInList['has_local_changes'] == 1;
                            final isSyncedByHistory = _inspectionSyncStatus[inspectionId] ?? false;
                            
                            // CORREÇÃO: Sempre mostrar botão de sync se há mudanças locais, independente do histórico
                            // Isso garante que mudanças recentes sempre mostrem o botão
                            final needsSync = hasLocalChanges || localStatus == 'modified';
                                
                            // Debug info for sync state
                            debugPrint('InspectionTab: Inspection $inspectionId sync state:');
                            debugPrint('  - localStatus: $localStatus');
                            debugPrint('  - hasLocalChanges: $hasLocalChanges');
                            debugPrint('  - isSyncedByHistory: $isSyncedByHistory');
                            debugPrint('  - hasLocalChanges || localStatus==modified: ${hasLocalChanges || localStatus == 'modified'}');
                            debugPrint('  - needsSync: $needsSync');
                            debugPrint('  - Sync button visible: ${needsSync ? "YES" : "NO"}');

                            return InspectionCard(
                              inspection: inspection,
                              googleMapsApiKey: _googleMapsApiKey ?? '',
                              isFullyDownloaded:
                                  _isInspectionFullyDownloaded(inspectionId),
                              needsSync: needsSync,
                              hasConflicts: _inspectionsWithConflicts
                                  .contains(inspectionId),
                              isSyncing: _syncingStatus[inspectionId] ?? false,
                              onViewDetails: () {
                                _navigateToInspectionDetail(inspectionId);
                              },
                              // onComplete removido - apenas sincronização manual
                              onSync: needsSync
                                  ? () => _syncInspectionData(inspectionId)
                                  : null,
                              onDownload: () =>
                                  _downloadInspectionData(inspection['id']),
                              onSyncImages: _hasPendingImages(inspection['id'])
                                  ? () =>
                                      _syncInspectionImages(inspection['id'])
                                  : null,
                              onRemove: () => _removeInspection(inspectionId),
                              pendingImagesCount:
                                  _getPendingImagesCount(inspection['id']),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    // Determine which empty state to show based on search or no inspections
    final bool isEmptySearch =
        _searchController.text.isNotEmpty && _filteredInspections.isEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isEmptySearch ? Icons.search_off : Icons.list_alt_outlined,
            size: 64,
            color: Colors.blueGrey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            isEmptySearch
                ? 'Nenhuma vistoria encontrada para "${_searchController.text}"'
                : 'Nenhuma vistoria encontrada',
            style: const TextStyle(fontSize: 10, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isEmptySearch
                ? 'Tente outro termo de pesquisa'
                : 'Novas vistorias aparecerão aqui.',
            style: const TextStyle(fontSize: 10, color: Colors.white60),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF6F4B99)),
            onPressed: isEmptySearch
                ? _clearSearch
                : (_isLoading ? null : _loadInspections),
            icon: Icon(isEmptySearch ? Icons.clear : Icons.refresh),
            label: Text(isEmptySearch ? 'Limpar Pesquisa' : 'Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDownloadDialog() async {
    try {
      // Show loading while fetching available inspections
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(
                child: Text('Carregando vistorias disponíveis...'),
              ),
            ],
          ),
        ),
      );

      // Buscar inspeções disponíveis do Firestore
      final availableInspections =
          await _getAvailableInspectionsFromFirestore();

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (availableInspections.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhuma vistoria disponível para download.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Show available inspections dialog
      if (mounted) {
        final selectedInspection = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => _AvailableInspectionsDialog(
            inspections: availableInspections,
          ),
        );

        if (selectedInspection != null) {
          final isDownloaded = selectedInspection['isDownloaded'] ?? false;
          if (isDownloaded) {
            // Navigate to already downloaded inspection
            await _navigateToInspectionDetail(selectedInspection['id']);
          } else {
            // Download the inspection
            await _downloadInspectionData(selectedInspection['id']);
          }
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      debugPrint('Error loading inspections: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar vistorias: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>>
      _getAvailableInspectionsFromFirestore() async {
    try {
      // Fetching available inspections from Firestore

      final user = _serviceFactory.authService.currentUser;
      if (user == null) {
        // No user logged in
        return [];
      }

      final querySnapshot = await _serviceFactory.firebaseService.firestore
          .collection('inspections')
          .where('inspector_id', isEqualTo: user.uid)
          .where('deleted_at', isNull: true)
          .orderBy('scheduled_date', descending: true)
          .get();

      final availableInspections = <Map<String, dynamic>>[];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        // Verificar se já está baixada localmente
        final localInspection =
            await _serviceFactory.dataService.getInspection(doc.id);
        data['isDownloaded'] = localInspection != null;

        availableInspections.add(data);
      }

      return availableInspections;
    } catch (e) {
      debugPrint('Error fetching available inspections: $e');
      return [];
    }
  }

  Future<void> _navigateToInspectionDetail(String inspectionId) async {
    if (!mounted) return;

    // Update status from "pending" to "in_progress" when starting an inspection
    try {
      final inspection =
          await _serviceFactory.dataService.getInspection(inspectionId);

      if (inspection != null && inspection.status == 'pending') {
        await _serviceFactory.dataService
            .updateInspectionStatus(inspectionId, 'in_progress');
        log('[InspectionsTab] Updated inspection $inspectionId status from pending to in_progress');
      } else {
        log('[InspectionsTab] Inspection $inspectionId is already ${inspection?.status}, not changing to in_progress');
      }
    } catch (e) {
      log('[InspectionsTab] Error updating inspection status: $e');
    }

    if (!mounted) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => InspectionDetailScreen(
          inspectionId: inspectionId,
        ),
      ),
    );

    log('[InspectionsTab] Returned from Detail Screen for $inspectionId. Result: $result');
    
    // Always mark as potentially modified when returning from details
    // This ensures the sync button appears if there were any changes
    markInspectionAsModified(inspectionId);
    debugPrint('InspectionTab: Marked $inspectionId as potentially modified after returning from details');
    
    // Add a small delay to ensure database changes are committed
    await Future.delayed(const Duration(milliseconds: 500));
    
    _loadInspections();
  }
}

class _AvailableInspectionsDialog extends StatefulWidget {
  final List<Map<String, dynamic>> inspections;

  const _AvailableInspectionsDialog({required this.inspections});

  @override
  State<_AvailableInspectionsDialog> createState() =>
      _AvailableInspectionsDialogState();
}

class _AvailableInspectionsDialogState
    extends State<_AvailableInspectionsDialog> {
  bool _hideDownloaded = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> get _filteredInspections {
    var filtered = widget.inspections;

    // Filtro de busca
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((inspection) {
        final title = (inspection['title'] ?? '').toString().toLowerCase();
        final address =
            (inspection['address_string'] ?? '').toString().toLowerCase();
        final cod = (inspection['cod'] ?? '').toString().toLowerCase();
        return title.contains(_searchQuery.toLowerCase()) ||
            address.contains(_searchQuery.toLowerCase()) ||
            cod.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filtro de vistorias baixadas
    if (_hideDownloaded) {
      filtered = filtered
          .where((inspection) => !(inspection['isDownloaded'] ?? false))
          .toList();
    }

    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildInspectionCard(Map<String, dynamic> inspection) {
    final title = inspection['title'] ?? 'Vistoria sem título';
    final cod = inspection['cod'] ?? '';
    final date = _formatDate(inspection['scheduled_date']);
    final address = inspection['address_string'] ?? 'Endereço não informado';
    final isDownloaded = inspection['isDownloaded'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).pop(inspection),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header com título e status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'BricolageGrotesque',
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Remover badge de status completamente
                ],
              ),

              const SizedBox(height: 8),

              // Código da vistoria
              if (cod.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code, size: 11, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        cod,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

              // Data programada
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 11, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Data: $date',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Endereço
              Row(
                children: [
                  const Icon(Icons.location_on, size: 11, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Status de download
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDownloaded
                            ? Colors.green.withValues(alpha: 0.1)
                            : const Color(0xFF312456).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDownloaded
                              ? Colors.green.withValues(alpha: 0.3)
                              : const Color(0xFF312456).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isDownloaded
                                ? Icons.check_circle
                                : Icons.cloud_download,
                            size: 16,
                            color: isDownloaded ? Colors.green : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isDownloaded
                                  ? 'Já baixada - Toque para abrir'
                                  : 'Toque para baixar',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredInspections = _filteredInspections;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.cloud_download,
                    color: Color(0xFFFFFFFF), size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Vistorias Disponíveis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'BricolageGrotesque',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Barra de busca
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por título, endereço ou código...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.clear, color: Colors.grey),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF312456)),
                ),
                filled: true,
                fillColor: Colors.grey.withValues(alpha: 0.05),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),

            const SizedBox(height: 8),

            // Filtros
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () =>
                      setState(() => _hideDownloaded = !_hideDownloaded),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: Checkbox(
                            value: _hideDownloaded,
                            onChanged: (value) => setState(
                                () => _hideDownloaded = value ?? false),
                            activeColor: Colors.blue,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Ocultar já baixadas',
                          style: TextStyle(fontSize: 11, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                // Counter on the right
                Text(
                  '${filteredInspections.length} de ${widget.inspections.length} vistorias',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Lista de vistorias
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: filteredInspections.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _hideDownloaded
                                  ? Icons.visibility_off
                                  : Icons.search_off,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _hideDownloaded
                                  ? 'Todas as vistorias\njá foram baixadas'
                                  : _searchQuery.isNotEmpty
                                      ? 'Nenhuma vistoria encontrada\npara "$_searchQuery"'
                                      : 'Nenhuma vistoria disponível',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: const Text(
                                  'Limpar busca',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 12),
                        itemCount: filteredInspections.length,
                        itemBuilder: (context, index) =>
                            _buildInspectionCard(filteredInspections[index]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Data não definida';

    try {
      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue.runtimeType.toString().contains('Timestamp')) {
        date = (dateValue as dynamic).toDate();
      } else {
        return 'Data inválida';
      }

      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return 'Data inválida';
    }
  }
}
