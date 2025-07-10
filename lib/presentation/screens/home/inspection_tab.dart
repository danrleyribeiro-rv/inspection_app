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

  // Método _completeInspection removido - apenas sincronização manual disponível

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
                  child: Text('Baixando inspeção completa...'),
                ),
              ],
            ),
          ),
        );
      }

      // Download complete inspection for offline use
      await _serviceFactory.syncService.syncInspection(inspectionId);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Download completed successfully
      log('[InspectionsTab _downloadInspectionData] Complete offline download completed successfully for inspection $inspectionId');

      // Clear the cloud updates flag since we just downloaded the latest data
      _inspectionsWithCloudUpdates.remove(inspectionId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspeção baixada! Agora você pode editar.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        // Force UI update to hide download button immediately
        setState(() {});
        // Refresh the list to show updated data
        _loadInspections();
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

      // Use the manual sync service to sync the inspection
      await _serviceFactory.syncService.syncInspection(inspectionId);

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
      // For offline-first mode, we'll check if the inspection has the _local_status indicating modifications
      final inspectionInList = _inspections.firstWhere(
        (inspection) => inspection['id'] == inspectionId,
        orElse: () => <String, dynamic>{},
      );

      final localStatus = inspectionInList['_local_status'] ?? '';
      final hasUnsyncedData =
          localStatus == 'modified' || localStatus == 'in_progress';

      log('[InspectionsTab _hasUnsyncedData] Inspection $inspectionId: local status: $localStatus, has unsynced: $hasUnsyncedData');

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
      // Only check if we're online
      if (!(await _serviceFactory.syncService.isConnected())) {
        return;
      }

      for (final inspection in _inspections) {
        final inspectionId = inspection['id'] as String;

        // Skip if inspection doesn't have local cache
        if (!(await _serviceFactory.dataService.getInspection(inspectionId) !=
            null)) {
          continue;
        }

        // Check if cloud has newer data - simplified check
        try {
          // Verificar se há atualizações na nuvem comparando timestamps
          final localInspection =
              await _serviceFactory.dataService.getInspection(inspectionId);
          if (localInspection != null && localInspection.lastSyncAt != null) {
            // Por simplicidade, assume que não há atualizações para evitar código morto
            _inspectionsWithCloudUpdates.remove(inspectionId);
          }
        } catch (e) {
          debugPrint('Erro ao verificar atualizações na nuvem: $e');
          _inspectionsWithCloudUpdates.remove(inspectionId);
        }
      }

      // Update UI if there are changes
      // hasUpdates is always false for now
      // if (hasUpdates && mounted) {
      //   setState(() {});
      // }
    } catch (e) {
      log('[InspectionsTab _checkForCloudUpdates] Error checking cloud updates: $e');
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

  //region Filter Widgets
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Color(0xFF4A3B6B),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Filtrar por',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildStatusFilter()),
              const SizedBox(width: 12),
              _buildDateFilter(),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedDateFilter != null) _buildSelectedDateChip(),
          const SizedBox(height: 16),
          if (_selectedStatusFilter != null || _selectedDateFilter != null)
            _buildClearFiltersButton(),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<String>(
      value: _selectedStatusFilter,
      onChanged: (value) {
        setState(() {
          _selectedStatusFilter = value == '' ? null : value;
          _applyFilters();
        });
      },
      decoration: InputDecoration(
        labelText: 'Status',
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF312456).withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dropdownColor: const Color(0xFF4A3B6B),
      style: const TextStyle(color: Colors.white),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
      items: const [
        DropdownMenuItem(value: '', child: Text('Todos os status')),
        DropdownMenuItem(value: 'pending', child: Text('Pendente')),
        DropdownMenuItem(value: 'in_progress', child: Text('Em Progresso')),
        DropdownMenuItem(value: 'completed', child: Text('Concluída')),
      ],
    );
  }

  Widget _buildDateFilter() {
    return Tooltip(
      message: 'Selecionar data',
      child: InkWell(
        onTap: _selectDate,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.calendar_today, color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildSelectedDateChip() {
    return Chip(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      label: Text(
        'Data: ${formatDateBR(_selectedDateFilter!)}',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: const Color(0xFF6F4B99),
      deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white70),
      onDeleted: () {
        setState(() {
          _selectedDateFilter = null;
          _applyFilters();
        });
      },
    );
  }

  Future<void> _selectDate() async {
    final DateTime? selectedDate = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        DateTime currentDate = _selectedDateFilter ?? DateTime.now();
        return Dialog(
          backgroundColor: const Color(0xFF312456),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Selecionar Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: Color(0xFF6F4B99),
                      onPrimary: Colors.white,
                      surface: Color(0xFF4A3B6B),
                      onSurface: Colors.white,
                    ),
                    dialogTheme:
                        const DialogTheme(backgroundColor: Color(0xFF4A3B6B)),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
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
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCELAR'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context, currentDate),
                      child: const Text(
                        'OK',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
  }

  Widget _buildClearFiltersButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _clearFilters,
        icon: const Icon(Icons.close, size: 18),
        label: const Text('Limpar Filtros'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.8),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
  //endregion

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
          if (!_isSearching)
            IconButton(
              icon: Icon(
                _showFilters ? Icons.filter_list_off : Icons.filter_list,
                color: Colors.white,
              ),
              tooltip: 'Filtrar Vistorias',
              onPressed: () {
                setState(() {
                  _showFilters = !_showFilters;
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
          if (_showFilters) _buildFilterSection(),
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
