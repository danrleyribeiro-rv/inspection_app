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
      if (mounted) {
        setState(() {
          if (progress.phase == SyncPhase.completed) {
            // Download/Upload completed, remove from downloading set
            _downloadingInspections.remove(progress.inspectionId);

            // Remove syncing status
            _syncingStatus[progress.inspectionId] = false;

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
                  content: Text(
                      'Inspeção ${progress.inspectionId} sincronizada com sucesso!'),
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

  Future<void> _loadCachedInspections() async {
    try {
      // Loading cached inspections only

      final cachedInspections = await _getCachedInspections();

      if (mounted) {
        // Ordenar por data de última sincronização (last_sync_at) em ordem decrescente
        cachedInspections.sort((a, b) {
          try {
            final aLastSyncAt = a['last_sync_at'];
            final bLastSyncAt = b['last_sync_at'];

            // Se ambos têm last_sync_at, comparar
            if (aLastSyncAt != null && bLastSyncAt != null) {
              DateTime aDate;
              DateTime bDate;

              if (aLastSyncAt is String) {
                aDate = DateTime.parse(aLastSyncAt);
              } else {
                aDate = DateTime.now(); // fallback
              }

              if (bLastSyncAt is String) {
                bDate = DateTime.parse(bLastSyncAt);
              } else {
                bDate = DateTime.now(); // fallback
              }

              return bDate.compareTo(
                  aDate); // Ordem decrescente (mais recente primeiro)
            }

            // Se apenas um tem last_sync_at, priorizar o que tem
            if (aLastSyncAt != null) return -1;
            if (bLastSyncAt != null) return 1;

            // Fallback: ordenar por updated_at se não houver last_sync_at
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

              return bDate.compareTo(aDate);
            }

            return 0;
          } catch (e) {
            debugPrint('Error sorting inspections by last_sync_at: $e');
            return 0;
          }
        });

        setState(() {
          _inspections = cachedInspections;
          _filteredInspections = List.from(_inspections);
          _isLoading = false;

          // Clean up any orphaned syncing status from inspections that no longer exist
          final currentInspectionIds =
              cachedInspections.map((i) => i['id'] as String).toSet();
          _syncingStatus
              .removeWhere((key, value) => !currentInspectionIds.contains(key));

          // Reset any syncing status that might be stuck
          for (final inspectionId in currentInspectionIds) {
            if (_syncingStatus[inspectionId] == true) {
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

          // Check if there are actual local changes that need sync
          final hasRealChanges = await _checkForRealLocalChanges(inspection.id);
          inspectionMap['has_local_changes'] = hasRealChanges;

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

      // Use native sync service for background sync
      await NativeSyncService.instance.startInspectionSync(inspectionId);
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

  Future<void> _cancelSync(String inspectionId) async {
    try {
      // Cancel the sync operation
      await _serviceFactory.syncService.cancelSync(inspectionId);

      // Update syncing status
      if (mounted) {
        setState(() {
          _syncingStatus[inspectionId] = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronização cancelada'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );

        // Refresh the list
        _loadInspections();
      }
    } catch (e) {
      debugPrint('Error cancelling sync: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cancelar: $e'),
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
      final inspection =
          await _serviceFactory.dataService.getInspection(inspectionId);
      if (inspection == null) return false;

      // Since we removed markSynced system, always return true to enable sync
      return true;
    } catch (e) {
      debugPrint('Error checking for real local changes: $e');
      return false;
    }
  }

  // Marca a inspeção como sincronizada, removendo flags de mudanças locais
  Future<void> _markInspectionAsSynced(String inspectionId) async {
    try {

      // Encontrar a inspeção na lista e limpar flags locais
      final inspectionIndex = _inspections.indexWhere(
        (inspection) => inspection['id'] == inspectionId,
      );

      if (inspectionIndex >= 0) {
        _inspections[inspectionIndex]['has_local_changes'] = false;
        _inspections[inspectionIndex]['_local_status'] = null;
      }

      // Força atualização da lista
      if (mounted) {
        setState(() {
          // Força rebuild da UI
        });
        await _loadCachedInspections();
      }
    } catch (e) {
      debugPrint('InspectionTab: Error in _markInspectionSynced: $e');
    }
  }

  Future<void> _removeInspection(String inspectionId) async {
    try {
      // Remove from local database
      await _serviceFactory.dataService.deleteInspection(inspectionId);

      // Remove from local state
      setState(() {
        _inspections
            .removeWhere((inspection) => inspection['id'] == inspectionId);
        _filteredInspections
            .removeWhere((inspection) => inspection['id'] == inspectionId);
        _downloadingInspections.remove(inspectionId);
        _syncingStatus.remove(inspectionId);
        _inspectionsWithConflicts.remove(inspectionId);
        _inspectionsWithCloudUpdates.remove(inspectionId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspeção removida com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 800),
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

  void _listenToDataModifications() {
    // No-op: Changes are stored locally and synced only when sync button is manually clicked
  }

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

      // Always assume no conflicts since we sync all data on demand
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
    final theme = Theme.of(context);


    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: theme.appBarTheme.titleTextStyle,
                decoration: InputDecoration(
                  hintText: 'Pesquisar...',
                  hintStyle: theme.appBarTheme.titleTextStyle
                      ?.copyWith(color: Colors.white70),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: Icon(Icons.clear,
                        color: theme.appBarTheme.iconTheme?.color),
                    onPressed: _clearSearch,
                  ),
                ),
              )
            : const Text('Inspeções'),
        elevation: 0,
        actions: [
          // Search Icon
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Pesquisar',
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          // Download Button
          IconButton(
            icon: const Icon(Icons.cloud_download),
            tooltip: 'Baixar Vistorias',
            onPressed: _isLoading ? null : _showDownloadDialog,
          ),
          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar Vistorias',
            onPressed: _isLoading ? null : _loadInspections,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInspections.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadInspections,
                        color: theme.colorScheme.primary,
                        backgroundColor: theme.scaffoldBackgroundColor,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredInspections.length,
                          itemBuilder: (context, index) {
                            final inspection = _filteredInspections[index];
                            final inspectionId = inspection['id'] as String;

                            // Get last sync date from inspection data
                            DateTime? lastSyncDate;
                            try {
                              final lastSyncStr =
                                  inspection['last_sync_at'] as String?;
                              if (lastSyncStr != null &&
                                  lastSyncStr.isNotEmpty) {
                                lastSyncDate = DateTime.parse(lastSyncStr);
                              }
                            } catch (e) {
                              debugPrint('Error parsing lastSyncAt: $e');
                            }

                            return InspectionCard(
                              inspection: inspection,
                              googleMapsApiKey: _googleMapsApiKey ?? '',
                              isFullyDownloaded:
                                  _isInspectionFullyDownloaded(inspectionId),
                              hasConflicts: _inspectionsWithConflicts
                                  .contains(inspectionId),
                              isSyncing: _syncingStatus[inspectionId] ?? false,
                              lastSyncDate: lastSyncDate,
                              onViewDetails: () {
                                _navigateToInspectionDetail(inspectionId);
                              },
                              // onComplete removido - apenas sincronização manual
                              onSync: () => _syncInspectionData(
                                  inspectionId), // Always allow sync
                              onDownload: () =>
                                  _downloadInspectionData(inspection['id']),
                              onSyncImages: _hasPendingImages(inspection['id'])
                                  ? () =>
                                      _syncInspectionImages(inspection['id'])
                                  : null,
                              onRemove: () => _removeInspection(inspectionId),
                              onCancelSync: () => _cancelSync(inspectionId),
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
    final theme = Theme.of(context);
    final bool isEmptySearch =
        _searchController.text.isNotEmpty && _filteredInspections.isEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isEmptySearch ? Icons.search_off : Icons.list_alt_outlined,
            size: 64,
            color: theme.textTheme.bodySmall?.color
                ?.withAlpha((0.5 * 255).round()),
          ),
          const SizedBox(height: 16),
          Text(
            isEmptySearch
                ? 'Nenhuma vistoria encontrada para "${_searchController.text}"'
                : 'Nenhuma vistoria encontrada',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isEmptySearch
                ? 'Tente outro termo de pesquisa'
                : 'Novas vistorias aparecerão aqui.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                foregroundColor: theme.colorScheme.onPrimary,
                backgroundColor: theme.colorScheme.primary),
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
    final theme = Theme.of(context);
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
                      style: theme.textTheme.titleMedium?.copyWith(
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
                      Icon(Icons.qr_code,
                          size: 11, color: theme.textTheme.bodySmall?.color),
                      const SizedBox(width: 4),
                      Text(
                        cod,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

              // Data programada
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 11, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Text(
                    'Data: $date',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Endereço
              Row(
                children: [
                  Icon(Icons.location_on,
                      size: 11, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      style: theme.textTheme.bodySmall,
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
                            ? Colors.green.withAlpha((0.1 * 255).round())
                            : theme.colorScheme.surface
                                .withAlpha((0.1 * 255).round()),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDownloaded
                              ? Colors.green.withAlpha((0.3 * 255).round())
                              : theme.colorScheme.surface
                                  .withAlpha((0.3 * 255).round()),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isDownloaded
                                ? Icons.check_circle
                                : Icons.cloud_download,
                            size: 16,
                            color: isDownloaded
                                ? Colors.green
                                : theme.colorScheme.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isDownloaded
                                  ? 'Já baixada - Toque para abrir'
                                  : 'Toque para baixar',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
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
    final theme = Theme.of(context);
    final filteredInspections = _filteredInspections;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        color: theme.cardColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.cloud_download,
                    color: theme.colorScheme.onSurface, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Vistorias Disponíveis',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: 'BricolageGrotesque',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: theme.iconTheme.color),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Barra de busca
            TextField(
              controller: _searchController,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Buscar por título, endereço ou código...',
                hintStyle: theme.inputDecorationTheme.hintStyle
                    ?.copyWith(fontSize: 12),
                prefixIcon: Icon(Icons.search,
                    color: theme.inputDecorationTheme.hintStyle?.color),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: Icon(Icons.clear,
                            color: theme.inputDecorationTheme.hintStyle?.color),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color:
                          theme.disabledColor.withAlpha((0.3 * 255).round())),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
                filled: true,
                fillColor: theme.inputDecorationTheme.fillColor,
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
                            activeColor: theme.colorScheme.primary,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Ocultar já baixadas',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                // Counter on the right
                Text(
                  '${filteredInspections.length} de ${widget.inspections.length} vistorias',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withAlpha((0.6 * 255).round()),
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
                              color: theme.textTheme.bodySmall?.color
                                  ?.withAlpha((0.4 * 255).round()),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _hideDownloaded
                                  ? 'Todas as vistorias\njá foram baixadas'
                                  : _searchQuery.isNotEmpty
                                      ? 'Nenhuma vistoria encontrada\npara "$_searchQuery"'
                                      : 'Nenhuma vistoria disponível',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.textTheme.bodyLarge?.color
                                    ?.withAlpha((0.6 * 255).round()),
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
