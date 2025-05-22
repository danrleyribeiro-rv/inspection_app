// lib/presentation/screens/home/inspection_tab.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer';
import 'package:inspection_app/presentation/screens/inspection/inspection_detail_screen.dart';
import 'package:inspection_app/presentation/widgets/inspection_card.dart';

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

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _loadInspections();
    _searchController.addListener(_filterInspections);
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
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      log('[InspectionsTab _loadInspections] Loading inspections for user ID: $userId');

      final inspectorSnapshot = await _firestore
          .collection('inspectors')
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache));

      if (inspectorSnapshot.docs.isEmpty) {
        log('[InspectionsTab _loadInspections] No inspector document found for user ID: $userId');
        if (mounted) setState(() => _isLoading = false);
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

      log('[InspectionsTab _loadInspections] Found ${data.docs.length} inspections.');

      if (mounted) {
        setState(() {
          _inspections = data.docs
              .map((doc) => {
                    ...doc.data(),
                    'id': doc.id,
                  })
              .toList();
          _filteredInspections = List.from(_inspections);
          _isLoading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    final bool isApiKeyAvailable =
        _googleMapsApiKey != null && _googleMapsApiKey!.isNotEmpty;

    if (!isApiKeyAvailable) {
      log('[InspectionsTab build] API Key is missing. Map previews will not work.');
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
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
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
              color: const Color(0xFF2A3749),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtros',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
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
                            labelStyle: TextStyle(color: Colors.white70),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          dropdownColor: const Color(0xFF2A3749),
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
                                backgroundColor: const Color(0xFF2A3749),
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
                                      CalendarDatePicker(
                                        initialDate: currentDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                        onDateChanged: (date) {
                                          currentDate = date;
                                        },
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
                                                  TextStyle(color: Colors.blue),
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
                          backgroundColor: Colors.blue,
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
                            style: TextStyle(color: Colors.white70)),
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
                        backgroundColor: Colors.blue,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredInspections.length,
                          itemBuilder: (context, index) {
                            final inspection = _filteredInspections[index];
                            return InspectionCard(
                              inspection: inspection,
                              googleMapsApiKey: _googleMapsApiKey ?? '',
                              onViewDetails: () {
                                log('[InspectionsTab] Navigating to details for inspection ID: \\${inspection['id']}');
                                _navigateToInspectionDetail(inspection['id']);
                              },
                              onComplete: inspection['status'] == 'in_progress'
                                  ? () => _completeInspection(inspection['id'])
                                  : null,
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
            style: const TextStyle(fontSize: 16, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isEmptySearch
                ? 'Tente outro termo de pesquisa'
                : 'Novas vistorias aparecerão aqui.',
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white, backgroundColor: Colors.blue),
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
