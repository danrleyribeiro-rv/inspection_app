// lib/presentation/screens/home/inspection_tab.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/presentation/screens/inspection/inspection_detail_screen.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class InspectionsTab extends StatefulWidget {
  const InspectionsTab({super.key});

  @override
  State<InspectionsTab> createState() => _InspectionsTabState();
}

class _InspectionsTabState extends State<InspectionsTab> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _inspectionService = FirebaseInspectionService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _inspections = [];
  bool _isOnline = true;
  double progress = 0.0;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadInspections();
    
    // Monitorar mudanças de conectividade
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
    });
  }
  
  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivityResult != ConnectivityResult.none;
    });
  }

  Future<void> _loadInspections() async {
    try {
      setState(() => _isLoading = true);

      // Get the inspector ID associated with the current user
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get inspector ID from Firestore
      final inspectorSnapshot = await _firestore
          .collection('inspectors')
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();

      if (inspectorSnapshot.docs.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final inspectorId = inspectorSnapshot.docs[0].id;

      // Get inspections assigned to this inspector
      final data = await _firestore
          .collection('inspections')
          .where('inspector_id', isEqualTo: inspectorId)
          .where('deleted_at', isNull: true)
          .orderBy('scheduled_date', descending: false)
          .get();

      setState(() {
        _inspections = data.docs
            .map((doc) => {
                  ...doc.data(),
                  'id': doc.id,
                })
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar as vistorias: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Slate background color
      appBar: AppBar(
        title: const Text('Vistorias'),
        backgroundColor: const Color(0xFF1E293B), // Slate app bar color
        actions: [
          // Indicador de status online/offline
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isOnline ? 'Online' : 'Offline',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInspections,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _inspections.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No inspections found',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadInspections,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadInspections,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _inspections.length,
                    itemBuilder: (context, index) {
                      final inspection = _inspections[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        color: Colors.grey[850],
                        elevation: 2,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        InspectionDetailScreen(
                                      inspectionId: inspection['id'],
                                    ),
                                  ),
                                )
                                .then((_) =>
                                    _loadInspections()); // Reload on return
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        inspection['title'] ?? 'Sem título',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    _buildStatusChip(inspection['status']),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Address: ${_formatAddress(inspection)}', // Address
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.white70),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Date: ${_formatDate(inspection['scheduled_date'])}', // Date
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.white70),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),
                                const Text(
                                  'Progress:',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.white70),
                                ),
                                const SizedBox(height: 4),
                                FutureBuilder<double>(
                                  future: _inspectionService.calculateCompletionPercentage(inspection['id']),
                                  builder: (context, snapshot) {
                                    final percentage = snapshot.data ?? 0.0;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        LinearProgressIndicator(
                                          value: percentage,
                                          backgroundColor: Colors.grey[300],
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Theme.of(context).primaryColor,
                                          ),
                                          minHeight: 8,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${(percentage * 100).toInt()}%',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (inspection['status'] == 'pending' ||
                                        inspection['status'] == 'in_progress')
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => InspectionDetailScreen(
                                                inspectionId: inspection['id'],
                                              ),
                                            ),
                                          ).then((_) => _loadInspections());
                                        },
                                        child: Text(
                                          inspection['status'] == 'pending'
                                              ? 'Iniciar'
                                              : 'Continuar',
                                        ),
                                      ),
                                    if (inspection['status'] == 'in_progress')
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            // Complete the inspection
                                            try {
                                              await _firestore
                                                  .collection('inspections')
                                                  .doc(inspection['id'])
                                                  .update({
                                                'status': 'completed',
                                                'finished_at': FieldValue
                                                    .serverTimestamp(),
                                                'updated_at': FieldValue
                                                    .serverTimestamp(),
                                              });

                                              if (mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(const SnackBar(
                                                        content: Text(
                                                            'Vistoria concluída com sucesso!')));
                                                _loadInspections();
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                        content: Text(
                                                            'Erro ao concluir a vistoria: $e')));
                                              }
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                          ),
                                          child: const Text(
                                              'Completar'), // Complete
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  // Format the address
  String _formatAddress(Map<String, dynamic> inspection) {
    final street = inspection['street'] ?? '';
    final number = inspection['number'] ?? '';
    final neighborhood = inspection['neighborhood'] ?? '';
    final city = inspection['city'] ?? '';
    final state = inspection['state'] ?? '';

    return '$street, $number - $neighborhood, $city - $state';
  }

  // Format the date
  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Date not set';

    try {
      DateTime date;
      if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else {
        return 'Invalid date';
      }

      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Build the status chip
  Widget _buildStatusChip(String? status) {
    String label;
    Color color;

    switch (status) {
      case 'pending':
        label = 'Pendente';
        color = Colors.orange;
        break;
      case 'in_progress':
        label = 'Em Progresso';
        color = Colors.blue;
        break;
      case 'completed':
        label = 'Concluído';
        color = Colors.green;
        break;
      case 'cancelled':
        label = 'Cancelado';
        color = Colors.red;
        break;
      default:
        label = 'Unknown';
        color = Colors.grey;
    }

    return Chip(
      backgroundColor: color.withOpacity(0.2),
      side: BorderSide(color: color),
      label: Text(
        label,
        style: TextStyle(color: color),
      ),
    );
  }
}