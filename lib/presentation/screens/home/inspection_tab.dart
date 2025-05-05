// lib/presentation/screens/home/inspection_tab.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'dart:developer'; // Import log
import 'package:inspection_app/presentation/screens/inspection/inspection_detail_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/presentation/widgets/inspection_card.dart';

class InspectionsTab extends StatefulWidget {
  const InspectionsTab({super.key});

  @override
  State<InspectionsTab> createState() => _InspectionsTabState();
}

class _InspectionsTabState extends State<InspectionsTab> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _inspections = [];
  bool _isOnline = false;
  final Connectivity _connectivity = Connectivity();
  String? _googleMapsApiKey; // Store the API key

  @override
  void initState() {
    super.initState();
    _loadApiKey(); // Load API key first
    _initConnectivity();
    _loadInspections();
  }

  // --- Load API Key ---
  void _loadApiKey() {
    _googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) {
      log('ERRO CRÍTICO: GOOGLE_MAPS_API_KEY não encontrada no arquivo .env!', level: 1000);
      // Consider showing a persistent warning or disabling map features
      // For now, we just log the error. MapLocationCard will show its own error placeholder.
    } else {
       log('[InspectionsTab] Google Maps API Key loaded successfully.');
    }
  }
  // --- End Load API Key ---


  Future<void> _initConnectivity() async {
    // ... (implementation unchanged) ...
    try {
       final connectivityResult = await _connectivity.checkConnectivity();
        if (mounted) {
          setState(() {
            _isOnline = connectivityResult.any((result) => result != ConnectivityResult.none);
          });
        }
    } catch (e) {
       log("Couldn't check connectivity status", error: e);
       if (mounted) {
         setState(() => _isOnline = false); // Assume offline on error
       }
    }
  }

  Future<void> _loadInspections() async {
    // ... (implementation largely unchanged) ...
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
          .get(const GetOptions(source: Source.serverAndCache)); // Try cache first

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
          // .orderBy('status') // Example: Could order by status then date
          .orderBy('scheduled_date', descending: false)
          .get(const GetOptions(source: Source.serverAndCache)); // Try cache first

      log('[InspectionsTab _loadInspections] Found ${data.docs.length} inspections.');

      if (mounted) {
         setState(() {
            _inspections = data.docs
                .map((doc) => {
                      ...doc.data(),
                      'id': doc.id, // Ensure ID is added
                    })
                .toList();
            _isLoading = false;
          });
      }
    } catch (e, s) {
      log('[InspectionsTab _loadInspections] Error loading inspections', error: e, stackTrace: s);
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

  Future<void> _completeInspection(String inspectionId) async {
    // ... (implementation unchanged) ...
     log('[InspectionsTab _completeInspection] Attempting to complete inspection ID: $inspectionId');
     try {
       await _firestore
           .collection('inspections')
           .doc(inspectionId)
           .update({
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
         _loadInspections(); // Refresh the list
       }
     } catch (e, s) {
       log('[InspectionsTab _completeInspection] Error completing inspection $inspectionId', error: e, stackTrace: s);
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
    // --- API Key Check ---
    // Although loaded in initState, we check here before rendering the list
    // to potentially show a different UI if the key is missing.
    final bool isApiKeyAvailable = _googleMapsApiKey != null && _googleMapsApiKey!.isNotEmpty;

     if (!isApiKeyAvailable) {
        // Optionally, show a persistent warning bar or modify the UI
        log('[InspectionsTab build] API Key is missing. Map previews will not work.');
        // You could return a Scaffold with a warning message here,
        // or just allow the list to build and let MapLocationCard show placeholders.
        // For simplicity, we'll proceed, and MapLocationCard will handle the missing key.
     }
    // --- End API Key Check ---

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        title: const Text('Vistorias'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0, // Remove shadow
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: const IconThemeData(color: Colors.white), // Ensure back button is white if needed
        actions: [
          // Connectivity Status Chip
          StreamBuilder<List<ConnectivityResult>>(
            stream: _connectivity.onConnectivityChanged.distinct(), // Use distinct to avoid rapid rebuilds
            initialData: _isOnline ? [ConnectivityResult.wifi] : [ConnectivityResult.none], // Provide initial based on state
            builder: (context, snapshot) {
              // Determine connectivity from the stream data OR the initial state
               bool isCurrentlyOnline = _isOnline; // Start with state value
               if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  isCurrentlyOnline = snapshot.data!.any((result) => result != ConnectivityResult.none);
                  // Update state if stream differs (optional, handle potential loops)
                  // Future.microtask(() { if (mounted && _isOnline != isCurrentlyOnline) setState(() => _isOnline = isCurrentlyOnline); });
               }

              return Container(
                // ... (Connectivity Chip styling unchanged) ...
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: isCurrentlyOnline ? Colors.green.shade700 : Colors.orange.shade700, // Darker shades
                  borderRadius: BorderRadius.circular(12),
                ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Icon(
                       isCurrentlyOnline ? Icons.wifi : Icons.wifi_off,
                       color: Colors.white,
                       size: 16,
                     ),
                     const SizedBox(width: 6),
                     Text(
                       isCurrentlyOnline ? 'Online' : 'Offline',
                       style: const TextStyle(
                           fontSize: 12,
                           color: Colors.white,
                           fontWeight: FontWeight.bold),
                     ),
                   ],
                 ),
              );
            },
          ),
          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Atualizar Vistorias', // Add tooltip
            onPressed: _isLoading ? null : _loadInspections, // Disable while loading
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white)) // Loading indicator
          : _inspections.isEmpty
              ? _buildEmptyState() // Show empty state if no inspections
              : RefreshIndicator(
                  onRefresh: _loadInspections, // Enable pull-to-refresh
                  color: Colors.white, // Refresh indicator color
                  backgroundColor: Colors.blue, // Refresh indicator background
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _inspections.length,
                    itemBuilder: (context, index) {
                      final inspection = _inspections[index];
                      return InspectionCard(
                        inspection: inspection,
                        // --- Pass the API Key ---
                        // Use a fallback empty string if the key is somehow null here,
                        // although _loadApiKey should handle it. MapLocationCard will show an error.
                        googleMapsApiKey: _googleMapsApiKey ?? '',
                        onViewDetails: () {
                          log('[InspectionsTab] Navigating to details for inspection ID: ${inspection['id']}');
                          _navigateToInspectionDetail(inspection['id']);
                        },
                        onComplete: inspection['status'] == 'in_progress'
                            ? () => _completeInspection(inspection['id'])
                            : null,
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    // ... (implementation unchanged) ...
     return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(Icons.list_alt_outlined, size: 64, color: Colors.blueGrey.shade300), // Changed icon
           const SizedBox(height: 16),
           const Text(
             'Nenhuma vistoria encontrada',
             style: TextStyle(fontSize: 18, color: Colors.white70),
           ),
           const SizedBox(height: 8),
            const Text(
             'Novas vistorias aparecerão aqui.', // Added explanation
             style: TextStyle(fontSize: 14, color: Colors.white60),
           ),
           const SizedBox(height: 24),
           ElevatedButton.icon(
             style: ElevatedButton.styleFrom(
                 foregroundColor: Colors.white, backgroundColor: Colors.blue // Text color
                 ),
             onPressed: _isLoading ? null : _loadInspections, // Disable while loading
             icon: const Icon(Icons.refresh),
             label: const Text('Tentar Novamente'),
           ),
         ],
       ),
     );
  }

  Future<void> _navigateToInspectionDetail(String inspectionId) async {
     if (!mounted) return; // Check if widget is still mounted

    final result = await Navigator.of(context).push<bool>( // Expect a boolean result (true if data changed)
      MaterialPageRoute(
        builder: (context) => InspectionDetailScreen(
          inspectionId: inspectionId,
          // You could pass the API Key here too if needed inside DetailScreen
          // googleMapsApiKey: _googleMapsApiKey ?? '',
        ),
      ),
    );

    // Reload inspections ONLY if the detail screen indicated a change (optional optimization)
     log('[InspectionsTab] Returned from Detail Screen for $inspectionId. Result: $result');
    // if (result == true) { // Example: Reload only if detail screen signals changes
    //   log('[InspectionsTab] Reloading inspections after detail screen update.');
    //  _loadInspections();
    // } else {
      // Always reload for simplicity unless performance becomes an issue
      _loadInspections();
    // }
  }
}