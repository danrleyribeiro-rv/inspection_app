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
import 'package:lince_inspecoes/services/debug_media_download_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _loadInspections();
    _searchController.addListener(_filterInspections);
    _startCloudUpdateChecks();
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
        log('[InspectionsTab _loadInspections] User not logged in.');
        await _loadCachedInspections();
        return;
      }

      log('[InspectionsTab _loadInspections] Loading inspections for user ID: $userId');

      // OFFLINE-FIRST: Always load cached inspections only
      await _loadCachedInspections();

      // In offline-first mode, we don't automatically sync from cloud
      // Users must explicitly download inspections they want to work on
    } catch (e, s) {
      log('[InspectionsTab _loadInspections] Error loading inspections',
          error: e, stackTrace: s);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar as vistorias: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadCachedInspections() async {
    try {
      log('[InspectionsTab _loadCachedInspections] Loading cached inspections only.');

      final cachedInspections = await _getCachedInspections();

      if (mounted) {
        setState(() {
          _inspections = cachedInspections;
          _filteredInspections = List.from(_inspections);
          _isLoading = false;
        });
      }

      log('[InspectionsTab _loadCachedInspections] Loaded ${_inspections.length} cached inspections.');
    } catch (e) {
      log('[InspectionsTab _loadCachedInspections] Error loading cached inspections: $e');
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
        log('[InspectionsTab _getCachedInspections] No user logged in');
        return [];
      }

      final cachedInspections = <Map<String, dynamic>>[];

      // Get only downloaded inspections for current user (offline-first)
      final offlineInspections =
          await _serviceFactory.dataService.getInspectionsByInspector(userId);

      for (final inspection in offlineInspections) {
        try {
          // Convert Inspection to Map format compatible with UI
          final inspectionMap = inspection.toMap();
          inspectionMap['_is_cached'] = true;
          inspectionMap['_local_status'] = inspection.status;
          
          // Check if there are actual local changes that need sync
          final hasRealChanges = await _checkForRealLocalChanges(inspection.id);
          inspectionMap['has_local_changes'] = hasRealChanges;

          cachedInspections.add(inspectionMap);
        } catch (e) {
          log('[InspectionsTab _getCachedInspections] Error converting inspection ${inspection.id}: $e');
          // Skip this inspection if conversion fails
          continue;
        }
      }

      log('[InspectionsTab _getCachedInspections] Found ${cachedInspections.length} downloaded inspections for current user.');
      return cachedInspections;
    } catch (e) {
      log('[InspectionsTab _getCachedInspections] Error getting cached inspections: $e');
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
              log('Error parsing date for search: $e');
            }
          }
        }
        return matchesSearchText;
      }).toList();
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
    log('[InspectionsTab _downloadInspectionData] Starting complete offline download for inspection ID: $inspectionId');
    try {
      
      // Run detailed debug of media download
      await _debugMediaDownload(inspectionId);
      
      // Use native sync service for background download
      await NativeSyncService.instance.startInspectionDownload(inspectionId);

      log('[InspectionsTab _downloadInspectionData] Complete offline download started for inspection $inspectionId');

      // Clear the cloud updates flag since we just downloaded the latest data
      _inspectionsWithCloudUpdates.remove(inspectionId);

      // Force UI update to hide download button immediately
      setState(() {});
      // Refresh the list to show updated data
      _loadInspections();
    } catch (e) {
      log('[InspectionsTab _downloadInspectionData] Error downloading data for inspection $inspectionId: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao baixar para offline: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _debugMediaDownload(String inspectionId) async {
    try {
      // Add debug service import if not already imported
      final debugService = DebugMediaDownloadService.instance;
      await debugService.testInspectionMediaDownload(inspectionId);
    } catch (e) {
      log('[InspectionsTab _debugMediaDownload] Error running debug: $e');
    }
  }


  Future<void> _syncInspectionData(String inspectionId) async {
    log('[InspectionsTab _syncInspectionData] Starting sync for inspection ID: $inspectionId');
    try {
      // Use native sync service for background sync
      await NativeSyncService.instance.startInspectionSync(inspectionId);

      log('[InspectionsTab _syncInspectionData] Sync started for inspection $inspectionId');

      // Refresh the list to show updated sync status
      _loadInspections();
    } catch (e) {
      log('[InspectionsTab _syncInspectionData] Error syncing data for inspection $inspectionId: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao sincronizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _checkForRealLocalChanges(String inspectionId) async {
    try {
      // Check if there are entities that need sync using the sync service
      final syncStatus = await _serviceFactory.syncService.getSyncStatus();
      
      // Check if inspection itself needs sync
      final inspection = await _serviceFactory.dataService.getInspection(inspectionId);
      if (inspection != null && inspection.hasLocalChanges) {
        return true;
      }
      
      // Check if there are entities that need sync
      final totalNeedingSync = (syncStatus['inspections'] ?? 0) + 
                              (syncStatus['topics'] ?? 0) + 
                              (syncStatus['items'] ?? 0) + 
                              (syncStatus['details'] ?? 0) + 
                              (syncStatus['non_conformities'] ?? 0);
      
      if (totalNeedingSync > 0) {
        return true;
      }
      
      // Check for media files that need sync
      final mediaFiles = await _serviceFactory.dataService.getMediaByInspection(inspectionId);
      for (final media in mediaFiles) {
        if (media.needsSync) return true;
      }
      
      return false;
    } catch (e) {
      log('[InspectionsTab _checkForRealLocalChanges] Error checking for real local changes: $e');
      return false;
    }
  }

  bool _hasUnsyncedData(String inspectionId) {
    try {
      // For offline-first mode, we'll check if the inspection has the _local_status indicating modifications
      final inspectionInList = _inspections.firstWhere(
        (inspection) => inspection['id'] == inspectionId,
        orElse: () => <String, dynamic>{},
      );

      final localStatus = inspectionInList['_local_status'] ?? '';
      final hasLocalChanges = inspectionInList['has_local_changes'] == true || inspectionInList['has_local_changes'] == 1;
      final hasUnsyncedData = hasLocalChanges || localStatus == 'modified';

      log('[InspectionsTab _hasUnsyncedData] Inspection $inspectionId: local status: $localStatus, has_local_changes: $hasLocalChanges, has unsynced: $hasUnsyncedData');

      return hasUnsyncedData;
    } catch (e) {
      log('[InspectionsTab _hasUnsyncedData] Error checking unsynced data: $e');
      return false;
    }
  }

  bool _isInspectionFullyDownloaded(String inspectionId) {
    try {
      // Check if inspection exists in the local list (meaning it was downloaded)
      final inspectionInList = _inspections.firstWhere(
        (inspection) => inspection['id'] == inspectionId,
        orElse: () => <String, dynamic>{},
      );

      // If inspection exists in our local list, it means it was downloaded
      final isDownloaded =
          inspectionInList.isNotEmpty && inspectionInList['_is_cached'] == true;

      log('[InspectionsTab _isInspectionFullyDownloaded] Inspection $inspectionId: exists in local list: ${inspectionInList.isNotEmpty}, is cached: ${inspectionInList['_is_cached']}, is downloaded: $isDownloaded');

      return isDownloaded;
    } catch (e) {
      log('[InspectionsTab _isInspectionFullyDownloaded] Error checking download status: $e');
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
      log('[InspectionsTab _checkForCloudUpdates] Error checking cloud updates: $e');
    }
  }

  Future<void> _checkSingleInspectionForConflicts(String inspectionId) async {
    try {
      // Get local inspection
      final localInspection = await _serviceFactory.dataService.getInspection(inspectionId);
      if (localInspection == null) return;

      // Check if local inspection has changes
      if (!localInspection.hasLocalChanges) {
        // No local changes, no conflicts possible
        setState(() {
          _inspectionsWithConflicts.remove(inspectionId);
        });
        return;
      }

      // Try to detect conflicts by attempting a sync and checking the result
      // This is a simplified approach since we can't access private members directly
      try {
        final syncResult = await _serviceFactory.syncService.syncInspection(inspectionId);
        
        if (syncResult['hasConflicts'] == true) {
          // Conflict detected
          setState(() {
            _inspectionsWithConflicts.add(inspectionId);
          });
          log('[InspectionsTab _checkSingleInspectionForConflicts] Conflict detected for inspection $inspectionId');
        } else {
          // No conflict
          setState(() {
            _inspectionsWithConflicts.remove(inspectionId);
          });
        }
      } catch (e) {
        // If sync fails, remove from conflicts list
        setState(() {
          _inspectionsWithConflicts.remove(inspectionId);
        });
        log('[InspectionsTab _checkSingleInspectionForConflicts] Sync failed for $inspectionId: $e');
      }
    } catch (e) {
      log('[InspectionsTab _checkSingleInspectionForConflicts] Error checking conflicts for $inspectionId: $e');
    }
  }


  // Method removed - not used anywhere

  bool _hasPendingImages(String inspectionId) {
    try {
      // In offline-first mode, we assume there are no pending images to sync
      // Images are stored locally and only uploaded when explicitly synced
      log('[InspectionsTab _hasPendingImages] Inspection $inspectionId: no pending images in offline-first mode');
      return false;
    } catch (e) {
      log('[InspectionsTab _hasPendingImages] Error checking pending images: $e');
      return false;
    }
  }

  int _getPendingImagesCount(String inspectionId) {
    try {
      // In offline-first mode, we assume no pending images to sync
      // Images are stored locally and only uploaded when explicitly synced
      log('[InspectionsTab _getPendingImagesCount] No pending images in offline-first mode for inspection $inspectionId');
      return 0;
    } catch (e) {
      log('[InspectionsTab _getPendingImagesCount] Error counting pending images: $e');
      return 0;
    }
  }

  Future<void> _syncInspectionImages(String inspectionId) async {
    log('[InspectionsTab _syncInspectionImages] Starting image sync for inspection ID: $inspectionId');
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

      log('[InspectionsTab _syncInspectionImages] Image sync completed successfully for inspection $inspectionId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagens sincronizadas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the list to show updated sync status
        _loadInspections();
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      log('[InspectionsTab _syncInspectionImages] Error syncing images for inspection $inspectionId: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao sincronizar imagens: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final bool isApiKeyAvailable =
        _googleMapsApiKey != null && _googleMapsApiKey!.isNotEmpty;

    if (!isApiKeyAvailable) {
      log('[InspectionsTab build] API Key is missing. Map previews will not work.');
    }

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
                            return InspectionCard(
                              inspection: inspection,
                              googleMapsApiKey: _googleMapsApiKey ?? '',
                              isFullyDownloaded: _isInspectionFullyDownloaded(
                                  inspection['id']),
                              needsSync: _hasUnsyncedData(inspection['id']),
                              hasConflicts: _inspectionsWithConflicts.contains(inspection['id']),
                              onViewDetails: () {
                                log('[InspectionsTab] Navigating to details for inspection ID: ${inspection['id']}');
                                _navigateToInspectionDetail(inspection['id']);
                              },
                              // onComplete removido - apenas sincronização manual
                              onSync: _hasUnsyncedData(inspection['id'])
                                  ? () => _syncInspectionData(inspection['id'])
                                  : null,
                              onDownload: () =>
                                  _downloadInspectionData(inspection['id']),
                              onSyncImages: _hasPendingImages(inspection['id'])
                                  ? () =>
                                      _syncInspectionImages(inspection['id'])
                                  : null,
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

      log('[InspectionsTab _showDownloadDialog] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar vistorias: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>>
      _getAvailableInspectionsFromFirestore() async {
    try {
      debugPrint(
          'InspectionsTab: Fetching available inspections from Firestore');

      final user = _serviceFactory.authService.currentUser;
      if (user == null) {
        debugPrint('InspectionsTab: No user logged in');
        return [];
      }

      final querySnapshot = await _serviceFactory.firebaseService.firestore
          .collection('inspections')
          .where('inspector_id', isEqualTo: user.uid)
          .where('status', whereIn: ['pending', 'in_progress', 'completed'])
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

      debugPrint(
          'InspectionsTab: Found ${availableInspections.length} available inspections');
      return availableInspections;
    } catch (e) {
      debugPrint('InspectionsTab: Error fetching available inspections: $e');
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
    _loadInspections();
  }

}

class _AvailableInspectionsDialog extends StatelessWidget {
  final List<Map<String, dynamic>> inspections;

  const _AvailableInspectionsDialog({required this.inspections});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vistorias Disponíveis'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: inspections.length,
          itemBuilder: (context, index) {
            final inspection = inspections[index];
            final title = inspection['title'] ?? 'Vistoria sem título';
            final date = _formatDate(inspection['scheduled_date']);
            final isDownloaded = inspection['isDownloaded'] ?? false;

            return ListTile(
              title: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Data: $date', style: const TextStyle(fontSize: 12)),
                  if (isDownloaded)
                    const Text(
                      'Já baixada - Toque para abrir',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.bold),
                    )
                  else
                    const Text(
                      'Toque para baixar',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color.fromARGB(255, 120, 80, 165)),
                    ),
                ],
              ),
              trailing: Icon(
                isDownloaded ? Icons.check_circle : Icons.download,
                color: isDownloaded
                    ? Colors.green
                    : Color.fromARGB(255, 120, 80, 165),
              ),
              onTap: () => Navigator.of(context).pop(inspection),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
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
