import 'package:inspection_app/services/inspection_service_coordinator.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';
import 'package:inspection_app/services/offline_inspection_service.dart';
import 'package:inspection_app/services/import_export_service.dart';
import 'package:inspection_app/services/checkpoint_dialog_service.dart';
import 'package:inspection_app/services/inspection_checkpoint_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ServiceFactory {
  static final ServiceFactory _instance = ServiceFactory._internal();
  factory ServiceFactory() => _instance;
  ServiceFactory._internal();

  // Singletons
  InspectionServiceCoordinator? _coordinator;
  FirebaseInspectionService? _firebaseService;
  OfflineInspectionService? _offlineService;
  ImportExportService? _importExportService;
  InspectionCheckpointService? _checkpointService;

  // Get services (singleton pattern)
  InspectionServiceCoordinator get coordinator {
    _coordinator ??= InspectionServiceCoordinator();
    return _coordinator!;
  }

  FirebaseInspectionService get firebaseService {
    _firebaseService ??= FirebaseInspectionService();
    return _firebaseService!;
  }

  OfflineInspectionService get offlineService {
    _offlineService ??= OfflineInspectionService();
    return _offlineService!;
  }

  ImportExportService get importExportService {
    _importExportService ??= ImportExportService();
    return _importExportService!;
  }

  InspectionCheckpointService get checkpointService {
    _checkpointService ??= InspectionCheckpointService();
    return _checkpointService!;
  }

  // Create configured services
  CheckpointDialogService createCheckpointDialogService(
    context,
    Function() onReloadData,
  ) {
    return CheckpointDialogService(
      context,
      checkpointService,
      onReloadData,
    );
  }

  // Initialize all services
  void initialize() {
    offlineService.initialize();
  }

  // Dispose all services
  void dispose() {
    _offlineService?.dispose();
  }

  // Check if online
  Future<bool> isOnline() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.wifi) ||
           result.contains(ConnectivityResult.mobile);
  }
}