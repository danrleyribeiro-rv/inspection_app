// lib/presentation/screens/home/inspection_tab.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'dart:developer';
import 'package:inspection_app/presentation/screens/inspection/inspection_detail_screen.dart';
import 'package:inspection_app/presentation/widgets/common/inspection_card.dart';
import 'package:inspection_app/services/service_factory.dart';

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
  final _firestore = FirebaseFirestore.instance;
  String? _googleMapsApiKey;

  // Filtros adicionais
  String? _selectedStatusFilter;
  DateTime? _selectedDateFilter;
  bool _showFilters = false;

  bool _isLoading = true;
  List<Map<String, dynamic>> _inspections = [];
  List<Map<String, dynamic>> _filteredInspections = [];
  bool _isSearching = false;
  final _searchController = TextEditingController();
  
  // Track inspections that have newer data in the cloud
  final Set<String> _inspectionsWithCloudUpdates = <String>{};

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

      // Always load cached inspections first for immediate display
      await _loadCachedInspections();

      // Check connectivity for online updates
      try {
        await _firestore.collection('inspections').limit(1).get(const GetOptions(source: Source.server));
        log('[InspectionsTab _loadInspections] Online - will load updates from Firestore');
      } catch (e) {
        log('[InspectionsTab _loadInspections] Offline - showing cached inspections only');
        return; // Already loaded cache above
      }

      try {
        // Try to load from Firestore first (only when online)
        final inspectorSnapshot = await _firestore
            .collection('inspectors')
            .where('user_id', isEqualTo: userId)
            .limit(1)
            .get(const GetOptions(source: Source.serverAndCache));

        if (inspectorSnapshot.docs.isEmpty) {
          log('[InspectionsTab _loadInspections] No inspector document found for user ID: $userId');
          await _loadCachedInspections();
          return;
        }

        final inspectorId = inspectorSnapshot.docs[0].id;
        log('[InspectionsTab _loadInspections] Found inspector ID: $inspectorId');

        final data = await _firestore
            .collection('inspections')
            .where('inspector_id', isEqualTo: inspectorId)
            .where('deleted_at', isNull: true)
            .orderBy('scheduled_date', descending: false)
            .get(const GetOptions(source: Source.serverAndCache));

        log('[InspectionsTab _loadInspections] Found ${data.docs.length} inspections from Firestore.');

        // Get Firestore inspections
        final firestoreInspections = data.docs
            .map((doc) => {
                  ...doc.data(),
                  'id': doc.id,
                })
            .toList();

        // Cache each Firestore inspection for offline access
        final cacheService = ServiceFactory().cacheService;
        for (final inspection in firestoreInspections) {
          try {
            await cacheService.cacheInspection(inspection['id'] as String, inspection, isFromCloud: true);
            log('[InspectionsTab _loadInspections] Cached inspection ${inspection['id']} for offline access');
          } catch (e) {
            log('[InspectionsTab _loadInspections] Error caching inspection ${inspection['id']}: $e');
          }
        }

        // Get cached inspections to merge
        final cachedInspections = await _getCachedInspections();
        
        // Merge Firestore and cached inspections (prioritize Firestore for duplicates)
        final allInspections = <String, Map<String, dynamic>>{};
        
        // Add cached inspections first
        for (final cached in cachedInspections) {
          allInspections[cached['id'] as String] = cached;
        }
        
        // Add/override with Firestore data
        for (final firestore in firestoreInspections) {
          allInspections[firestore['id'] as String] = firestore;
        }

        if (mounted) {
          setState(() {
            _inspections = allInspections.values.toList();
            _filteredInspections = List.from(_inspections);
            _isLoading = false;
          });
        }
        
        log('[InspectionsTab _loadInspections] Loaded ${_inspections.length} total inspections (Firestore + Cache).');
      } catch (e) {
        log('[InspectionsTab _loadInspections] Error loading from Firestore: $e');
        // Fallback to cached inspections if Firestore fails
        await _loadCachedInspections();
      }
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
      final cacheService = ServiceFactory().cacheService;
      final cachedInspections = <Map<String, dynamic>>[];
      
      // Get all cached inspections
      final allCachedInspections = cacheService.getAllCachedInspections();
      
      for (final cachedInspection in allCachedInspections) {
        // Extract the inspection data from the cached inspection
        final inspectionData = Map<String, dynamic>.from(cachedInspection.data);
        
        // Create a Map format compatible with Firestore format
        final inspectionMap = {
          'id': cachedInspection.id,
          ...inspectionData, // Include all the original inspection data
          // Add cache-specific metadata
          '_cached_at': cachedInspection.lastUpdated.toIso8601String(),
          '_needs_sync': cachedInspection.needsSync,
          '_is_cached': true, // Flag to identify cached inspections
        };
        
        cachedInspections.add(inspectionMap);
      }
      
      log('[InspectionsTab _getCachedInspections] Found ${cachedInspections.length} cached inspections.');
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
        // Filtro de status
        bool matchesStatus = true;
        if (_selectedStatusFilter != null &&
            _selectedStatusFilter!.isNotEmpty) {
          final status = inspection['status']?.toString() ?? '';
          matchesStatus = status == _selectedStatusFilter;
        }
        // Filtro de data
        bool matchesDate = true;
        if (_selectedDateFilter != null) {
          try {
            DateTime? scheduledDate;
            if (inspection['scheduled_date'] is String) {
              scheduledDate = DateTime.parse(inspection['scheduled_date']);
            } else if (inspection['scheduled_date'] is Timestamp) {
              scheduledDate = inspection['scheduled_date'].toDate();
            }
            if (scheduledDate != null) {
              matchesDate = scheduledDate.year == _selectedDateFilter!.year &&
                  scheduledDate.month == _selectedDateFilter!.month &&
                  scheduledDate.day == _selectedDateFilter!.day;
            } else {
              matchesDate = false;
            }
          } catch (e) {
            log('Error comparing date for filter: $e');
            matchesDate = false;
          }
        }
        return matchesSearchText && matchesStatus && matchesDate;
      }).toList();
    });
  }

  void _filterInspections() {
    _applyFilters();
  }

  void _clearFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _selectedDateFilter = null;
      _applyFilters();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _clearFilters();
    });
  }

  Future<void> _completeInspection(String inspectionId) async {
    log('[InspectionsTab _completeInspection] Attempting to complete inspection ID: $inspectionId');
    try {
      await _firestore.collection('inspections').doc(inspectionId).update({
        'status': 'completed',
        'finished_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      log('[InspectionsTab _completeInspection] Inspection $inspectionId completed successfully.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vistoria concluída com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadInspections();
      }
    } catch (e, s) {
      log('[InspectionsTab _completeInspection] Error completing inspection $inspectionId',
          error: e, stackTrace: s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao concluir a vistoria: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadInspectionData(String inspectionId) async {
    log('[InspectionsTab _downloadInspectionData] Starting complete offline download for inspection ID: $inspectionId');
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
                  child: Text('Baixando inspeção completa para uso offline...'),
                ),
              ],
            ),
          ),
        );
      }

      // Download complete inspection for offline use
      final success = await ServiceFactory().offlineService.downloadInspectionForOffline(inspectionId);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (success) {
        log('[InspectionsTab _downloadInspectionData] Complete offline download completed successfully for inspection $inspectionId');

        // Clear the cloud updates flag since we just downloaded the latest data
        _inspectionsWithCloudUpdates.remove(inspectionId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inspeção baixada para uso offline! Agora você pode editar sem internet.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          // Force UI update to hide download button immediately
          setState(() {});
          // Refresh the list to show updated data
          _loadInspections();
        }
      } else {
        throw Exception('Falha no download offline');
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

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

  Future<void> _syncInspectionData(String inspectionId) async {
    log('[InspectionsTab _syncInspectionData] Starting sync for inspection ID: $inspectionId');
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
                const Text('Sincronizando dados...'),
              ],
            ),
          ),
        );
      }

      // Use the offline service to sync the inspection
      final success = await ServiceFactory().offlineService.syncOfflineChanges(inspectionId);
      
      if (!success) {
        throw Exception('Falha na sincronização offline');
      }

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      log('[InspectionsTab _syncInspectionData] Sync completed successfully for inspection $inspectionId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mudanças offline sincronizadas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the list to show updated sync status
        _loadInspections();
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

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

  bool _hasUnsyncedData(String inspectionId) {
    try {
      final offlineService = ServiceFactory().offlineService;
      
      // Check if inspection has unsaved changes
      final hasUnsyncedInspection = offlineService.hasUnsavedChanges(inspectionId);
      
      // Check if there are pending media uploads
      final pendingMediaCount = offlineService.getPendingMediaCount(inspectionId);
      
      final hasUnsyncedData = hasUnsyncedInspection || pendingMediaCount > 0;
      
      log('[InspectionsTab _hasUnsyncedData] Inspection $inspectionId: unsynced inspection: $hasUnsyncedInspection, pending media: $pendingMediaCount, has unsynced: $hasUnsyncedData');
      
      return hasUnsyncedData;
    } catch (e) {
      log('[InspectionsTab _hasUnsyncedData] Error checking unsynced data: $e');
      return false;
    }
  }

  bool _shouldShowDownloadButton(String inspectionId) {
    try {
      final offlineService = ServiceFactory().offlineService;
      
      // Show download button ONLY if:
      // 1. There's no local cache (new inspection to download)
      final hasLocalCache = offlineService.isInspectionAvailableOffline(inspectionId);
      
      log('[InspectionsTab _shouldShowDownloadButton] Inspection $inspectionId: hasLocalCache=$hasLocalCache');
      
      if (!hasLocalCache) {
        log('[InspectionsTab _shouldShowDownloadButton] Showing download button - no local cache for $inspectionId');
        return true; // No local data, so download button should show
      }
      
      // 2. If there's local cache, only show download button if there are confirmed cloud updates
      final hasCloudUpdates = _inspectionsWithCloudUpdates.contains(inspectionId);
      
      log('[InspectionsTab _shouldShowDownloadButton] Inspection $inspectionId: hasCloudUpdates=$hasCloudUpdates');
      
      // Hide download button permanently once cached unless there are newer cloud updates
      return hasCloudUpdates;
    } catch (e) {
      log('[InspectionsTab _shouldShowDownloadButton] Error checking download status: $e');
      return false;
    }
  }

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
      final cacheService = ServiceFactory().cacheService;
      
      // Only check if we're online
      if (!(await _isConnected())) {
        return;
      }
      
      bool hasUpdates = false;
      
      for (final inspection in _inspections) {
        final inspectionId = inspection['id'] as String;
        
        // Skip if inspection doesn't have local cache
        if (!cacheService.isAvailableOffline(inspectionId)) {
          continue;
        }
        
        // Check if cloud has newer data
        final hasNewerData = await cacheService.hasNewerDataInCloud(inspectionId);
        
        if (hasNewerData) {
          _inspectionsWithCloudUpdates.add(inspectionId);
          hasUpdates = true;
        } else {
          _inspectionsWithCloudUpdates.remove(inspectionId);
        }
      }
      
      // Update UI if there are changes
      if (hasUpdates && mounted) {
        setState(() {});
      }
    } catch (e) {
      log('[InspectionsTab _checkForCloudUpdates] Error checking cloud updates: $e');
    }
  }

  Future<bool> _isConnected() async {
    try {
      // Try to access Firestore to check connectivity
      await _firestore.collection('inspections').limit(1).get();
      return true;
    } catch (e) {
      return false;
    }
  }

  bool _hasPendingImages(String inspectionId) {
    try {
      final cacheService = ServiceFactory().cacheService;
      
      // Check if there are pending media uploads for this inspection (only locally created)
      final pendingMedia = cacheService.getPendingOfflineMedia()
          .where((media) => media.inspectionId == inspectionId && media.needsUpload && media.isLocallyCreated)
          .toList();
      
      final hasPendingImages = pendingMedia.isNotEmpty;
      
      log('[InspectionsTab _hasPendingImages] Inspection $inspectionId: pending locally created images: ${pendingMedia.length}');
      
      return hasPendingImages;
    } catch (e) {
      log('[InspectionsTab _hasPendingImages] Error checking pending images: $e');
      return false;
    }
  }

  int _getPendingImagesCount(String inspectionId) {
    try {
      final cacheService = ServiceFactory().cacheService;
      
      // Count only locally created media that needs upload (exclude downloaded from cloud)
      final pendingMedia = cacheService.getPendingOfflineMedia()
          .where((media) => media.inspectionId == inspectionId && media.needsUpload && media.isLocallyCreated)
          .toList();
      
      log('[InspectionsTab _getPendingImagesCount] Found ${pendingMedia.length} locally created pending images for inspection $inspectionId');
      return pendingMedia.length;
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
      await ServiceFactory().mediaService.uploadPendingMediaForInspection(inspectionId);

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
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.white),
              tooltip: 'Filtrar Vistorias',
              onPressed: () {
                setState(() {
                  _showFilters = !_showFilters;
                });
              },
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
          if (_showFilters)
            Container(
              color: const Color(0xFF4A3B6B),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtros',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatusFilter,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          dropdownColor: const Color(0xFF4A3B6B),
                          style: const TextStyle(color: Colors.white),
                          items: const [
                            DropdownMenuItem(
                              value: '',
                              child: Text('Todos',
                                  style: TextStyle(color: Colors.white)),
                            ),
                            DropdownMenuItem(
                              value: 'pending',
                              child: Text('Pendente',
                                  style: TextStyle(color: Colors.white)),
                            ),
                            DropdownMenuItem(
                              value: 'in_progress',
                              child: Text('Em Progresso',
                                  style: TextStyle(color: Colors.white)),
                            ),
                            DropdownMenuItem(
                              value: 'completed',
                              child: Text('Concluída',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedStatusFilter =
                                  value == '' ? null : value;
                              _applyFilters();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Na função que mostra o DatePicker, modifique para:
                      IconButton(
                        icon: const Icon(Icons.calendar_today,
                            color: Colors.white),
                        onPressed: () async {
                          // Use showDialog em vez de showDatePicker
                          final DateTime? selectedDate =
                              await showDialog<DateTime>(
                            context: context,
                            builder: (BuildContext context) {
                              DateTime currentDate =
                                  _selectedDateFilter ?? DateTime.now();
                              return Dialog(
                                backgroundColor: const Color(0xFF4A3B6B),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Selecionar Data',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: MediaQuery.of(context).size.width * 1.12,
                                        child: CalendarDatePicker(
                                          initialDate: currentDate,
                                          firstDate: DateTime(2025),
                                          lastDate: DateTime(2035),
                                          onDateChanged: (date) {
                                            currentDate = date;
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text(
                                              'Cancelar',
                                              style: TextStyle(
                                                  color: Colors.white70),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                                context, currentDate),
                                            child: const Text(
                                              'Confirmar',
                                              style:
                                                  TextStyle(color: Color(0xFF6F4B99)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );

                          if (selectedDate != null) {
                            setState(() {
                              _selectedDateFilter = selectedDate;
                              _applyFilters();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_selectedDateFilter != null)
                        Chip(
                          label: Text(
                            'Data: ${formatDateBR(_selectedDateFilter!)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Color(0xFF6F4B99),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() {
                              _selectedDateFilter = null;
                              _applyFilters();
                            });
                          },
                        ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        label: const Text('Limpar Filtros',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : _filteredInspections.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadInspections,
                        color: Colors.white,
                        backgroundColor: Color(0xFF6F4B99),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredInspections.length,
                          itemBuilder: (context, index) {
                            final inspection = _filteredInspections[index];
                            return InspectionCard(
                              inspection: inspection,
                              googleMapsApiKey: _googleMapsApiKey ?? '',
                              onViewDetails: () {
                                log('[InspectionsTab] Navigating to details for inspection ID: ${inspection['id']}');
                                _navigateToInspectionDetail(inspection['id']);
                              },
                              onComplete: inspection['status'] == 'in_progress'
                                  ? () => _completeInspection(inspection['id'])
                                  : null,
                              onSync: _hasUnsyncedData(inspection['id']) 
                                  ? () => _syncInspectionData(inspection['id'])
                                  : null,
                              onDownload: _shouldShowDownloadButton(inspection['id'])
                                  ? () => _downloadInspectionData(inspection['id'])
                                  : null,
                              onSyncImages: _hasPendingImages(inspection['id'])
                                  ? () => _syncInspectionImages(inspection['id'])
                                  : null,
                              pendingImagesCount: _getPendingImagesCount(inspection['id']),
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
                foregroundColor: Colors.white, backgroundColor: Color(0xFF6F4B99)),
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

  Future<void> _navigateToInspectionDetail(String inspectionId) async {
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
