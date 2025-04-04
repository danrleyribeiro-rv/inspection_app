// lib/blocs/inspection/inspection_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/blocs/inspection/inspection_event.dart';
import 'package:inspection_app/blocs/inspection/inspection_state.dart';
import 'package:inspection_app/data/models/inspection.dart';
import 'package:inspection_app/data/models/room.dart';
import 'package:inspection_app/data/repositories/inspection_repository.dart';

class InspectionBloc extends Bloc<InspectionEvent, InspectionState> {
  final InspectionRepository inspectionRepository;
  late StreamSubscription _connectivitySubscription;
  bool _isOffline = false;

  InspectionBloc({required this.inspectionRepository}) : super(InspectionInitial()) {
    on<LoadInspection>(_onLoadInspection);
    on<SyncInspection>(_onSyncInspection);
    on<AddRoom>(_onAddRoom);
    on<UpdateRoom>(_onUpdateRoom);
    on<DeleteRoom>(_onDeleteRoom);
    on<AddItem>(_onAddItem);
    on<UpdateItem>(_onUpdateItem);
    on<DeleteItem>(_onDeleteItem);
    on<AddDetail>(_onAddDetail);
    on<UpdateDetail>(_onUpdateDetail);
    on<DeleteDetail>(_onDeleteDetail);
    on<CompleteInspection>(_onCompleteInspection);
    on<SaveInspection>(_onSaveInspection);
    
    // Initialize connectivity monitoring
    _initConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _initConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _isOffline = connectivityResult == ConnectivityResult.none;
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    _isOffline = result == ConnectivityResult.none;
    
    // If state is InspectionLoaded, update its isOffline property
    if (state is InspectionLoaded) {
      final currentState = state as InspectionLoaded;
      emit(currentState.copyWith(isOffline: _isOffline));
      
      // If we're back online and there's an inspection loaded, try to sync
      if (!_isOffline && currentState.inspection != null) {
        add(SyncInspection(currentState.inspection.id, showSuccess: false));
      }
    }
  }

  Future<void> _onLoadInspection(LoadInspection event, Emitter<InspectionState> emit) async {
    emit(InspectionLoading());
    
    try {
      // Load inspection from local database
      final inspection = await inspectionRepository.getInspection(event.inspectionId);
      
      if (inspection != null) {
        // Load rooms for this inspection
        final rooms = await inspectionRepository.getRooms(event.inspectionId);
        
        // Calculate completion percentage
        final completionPercentage = await inspectionRepository.calculateCompletionPercentage(event.inspectionId);
        
        emit(InspectionLoaded(
          inspection: inspection,
          rooms: rooms,
          completionPercentage: completionPercentage,
          isOffline: _isOffline,
        ));
      } else {
        // Try to download if online
        if (!_isOffline) {
          final downloaded = await inspectionRepository.downloadInspection(event.inspectionId);
          
          if (downloaded) {
            // Now load the downloaded inspection
            final downloadedInspection = await inspectionRepository.getInspection(event.inspectionId);
            if (downloadedInspection != null) {
              final rooms = await inspectionRepository.getRooms(event.inspectionId);
              final completionPercentage = await inspectionRepository.calculateCompletionPercentage(event.inspectionId);
              
              emit(InspectionLoaded(
                inspection: downloadedInspection,
                rooms: rooms,
                completionPercentage: completionPercentage,
                isOffline: _isOffline,
              ));
            } else {
              emit(const InspectionError('Error loading downloaded inspection'));
            }
          } else {
            emit(const InspectionError('Inspection not found and could not be downloaded'));
          }
        } else {
          // Offline and no local data
          emit(const InspectionError('Inspection not found in offline storage'));
        }
      }
    } catch (e) {
      emit(InspectionError('Error loading inspection: $e'));
    }
  }

  Future<void> _onSyncInspection(SyncInspection event, Emitter<InspectionState> emit) async {
    if (_isOffline) {
      if (event.showSuccess) {
        emit(const InspectionError('Cannot sync while offline'));
      }
      return;
    }
    
    if (state is InspectionLoaded) {
      final currentState = state as InspectionLoaded;
      emit(currentState.copyWith(isSyncing: true));
      
      try {
        final success = await inspectionRepository.syncInspection(event.inspectionId);
        
        // Reload data after sync
        final inspection = await inspectionRepository.getInspection(event.inspectionId);
        final rooms = await inspectionRepository.getRooms(event.inspectionId);
        final completionPercentage = await inspectionRepository.calculateCompletionPercentage(event.inspectionId);
        
        emit(InspectionLoaded(
          inspection: inspection!,
          rooms: rooms,
          completionPercentage: completionPercentage,
          isOffline: _isOffline,
          isSyncing: false,
        ));
        
        if (event.showSuccess) {
          emit(InspectionOperationSuccess(
            success ? 'Inspection synced successfully' : 'Error syncing inspection'
          ));
        }
      } catch (e) {
        emit(currentState.copyWith(isSyncing: false));
        
        if (event.showSuccess) {
          emit(InspectionError('Error during sync: $e'));
        }
      }
    }
  }

  Future<void> _onAddRoom(AddRoom event, Emitter<InspectionState> emit) async {
    if (state is InspectionLoaded) {
      final currentState = state as InspectionLoaded;
      emit(InspectionLoading());
      
      try {
        // Add room
        final newRoom = await inspectionRepository.addRoom(
          event.inspectionId,
          event.roomName,
          label: event.roomLabel,
        );
        
        // Reload rooms
        final rooms = await inspectionRepository.getRooms(event.inspectionId);
        
        // Update completion percentage
        final completionPercentage = await inspectionRepository.calculateCompletionPercentage(event.inspectionId);
        
        // Get updated inspection
        final inspection = await inspectionRepository.getInspection(event.inspectionId);
        
        emit(InspectionLoaded(
          inspection: inspection!,
          rooms: rooms,
          completionPercentage: completionPercentage,
          isOffline: _isOffline,
        ));
        
        // Try to sync if online
        if (!_isOffline) {
          add(SyncInspection(event.inspectionId, showSuccess: false));
        }
      } catch (e) {
        emit(InspectionError('Error adding room: $e'));
        
        // Restore previous state
        emit(currentState);
      }
    }
  }

  Future<void> _onUpdateRoom(UpdateRoom event, Emitter<InspectionState> emit) async {
    if (state is InspectionLoaded) {
      final currentState = state as InspectionLoaded;
      
      try {
        // Update room
        await inspectionRepository.updateRoom(event.room);
        
        // Update local state optimistically
        final updatedRooms = currentState.rooms.map((room) {
          return room.id == event.room.id ? event.room : room;
        }).toList();
        
        emit(currentState.copyWith(rooms: updatedRooms));
        
        // Try to sync if online
        if (!_isOffline) {
          add(SyncInspection(event.room.inspectionId, showSuccess: false));
        }
        
        // Update completion percentage
        final completionPercentage = await inspectionRepository.calculateCompletionPercentage(event.room.inspectionId);
        emit(currentState.copyWith(completionPercentage: completionPercentage));
      } catch (e) {
        emit(InspectionError('Error updating room: $e'));
        
        // Restore previous state
        emit(currentState);
      }
    }
  }

  Future<void> _onDeleteRoom(DeleteRoom event, Emitter<InspectionState> emit) async {
    if (state is InspectionLoaded) {
      final currentState = state as InspectionLoaded;
      
      try {
        // Delete room
        await inspectionRepository.deleteRoom(event.inspectionId, event.roomId);
        
        // Update local state optimistically
        final updatedRooms = currentState.rooms.where((room) => room.id != event.roomId).toList();
        
        // Update completion percentage
        final completionPercentage = await inspectionRepository.calculateCompletionPercentage(event.inspectionId);
        
        emit(currentState.copyWith(
          rooms: updatedRooms,
          completionPercentage: completionPercentage,
        ));
        
        // Try to sync if online
        if (!_isOffline) {
          add(SyncInspection(event.inspectionId, showSuccess: false));
        }
      } catch (e) {
        emit(InspectionError('Error deleting room: $e'));
        
        // Restore previous state
        emit(currentState);
      }
    }
  }

  // Implementation for the remaining event handlers...
  Future<void> _onAddItem(AddItem event, Emitter<InspectionState> emit) async {
    // Implementation similar to _onAddRoom
    try {
      await inspectionRepository.addItem(
        event.inspectionId,
        event.roomId,
        event.itemName,
        label: event.itemLabel,
      );
      
      if (state is InspectionLoaded) {
        final currentState = state as InspectionLoaded;
        final completionPercentage = await inspectionRepository.calculateCompletionPercentage(event.inspectionId);
        emit(currentState.copyWith(completionPercentage: completionPercentage));
        
        // Try to sync if online
        if (!_isOffline) {
          add(SyncInspection(event.inspectionId, showSuccess: false));
        }
      }
      
      emit(const InspectionOperationSuccess('Item added successfully'));
    } catch (e) {
      emit(InspectionError('Error adding item: $e'));
    }
  }

  Future<void> _onUpdateItem(UpdateItem event, Emitter<InspectionState> emit) async {
    try {
      await inspectionRepository.updateItem(event.item);
      
      if (state is InspectionLoaded) {
        final currentState = state as InspectionLoaded;
        final completionPercentage = await inspectionRepository.calculateCompletionPercentage(event.item.inspectionId);
        emit(currentState.copyWith(completionPercentage: completionPercentage));
        
        // Try to sync if online
        if (!_isOffline) {
          add(SyncInspection(event.item.inspectionId, showSuccess: false));
        }
      }
    } catch (e) {
      emit(InspectionError('Error updating item: $e'));
    }
  }

  Future<void> _onDeleteItem(DeleteItem event, Emitter<InspectionState> emit) async {
    try {
      await inspectionRepository.deleteItem(event.inspectionId, event.roomId, event.itemId);
      
      if (state is InspectionLoaded) {
        final currentState = state as InspectionLoaded;
        final completionPercentage = await inspectionRepository.calculateCompletionPercentage(event.inspectionId);
        emit(currentState.copyWith(completionPercentage: completionPercentage));
        
        // Try to sync if online
        if (!_isOffline) {
          add(SyncInspection(event.inspectionId, showSuccess: false));
        }
      }
      
      emit(const InspectionOperationSuccess('Item deleted successfully'));
    } catch (e) {
      emit(InspectionError('Error deleting item: $e'));
    }
  }

  Future<void> _onAddDetail(AddDetail event, Emitter<InspectionState> emit) async {
    try {
      await inspectionRepository.addDetail(
        event.inspectionId,
        event.roomId,
        event.itemId,
        event.detailName,
        value: event.detailValue,
      );
      
      if (state is InspectionLoaded) {
        final currentState = state as InspectionLoaded;
        final completionPercentage = await inspectionRepository.calculateCompletionPercentage(event.inspectionId);
        emit(currentState.copyWith(completionPercentage: completionPercentage));
        
        // Try to sync if online
        if (!_isOffline) {
          add(SyncInspection(event.inspectionId, showSuccess: false));
        }
      }
      
      emit(const InspectionOperationSuccess('Detail added successfully'));
    } catch (e) {
      emit(InspectionError('Error adding detail: $e'));
    }
  }

  Future<void> _onUpdateDetail(UpdateDetail event, Emitter<InspectionState> emit) async {
    try {
      await inspectionRepository.updateDetail(event.detail);
      
      if (state is InspectionLoaded) {
        final currentState = state as InspectionLoaded;
        final completionPercentage = await inspectionRepository.calculateCompletionPercentage(event.detail.inspectionId);
        emit(currentState.copyWith(completionPercentage: completionPercentage));
        
        // Try to sync if online
        if (!_isOffline) {
          add(SyncInspection(event.detail.inspectionId, showSuccess: false));
        }
      }
    } catch (e) {
      emit(InspectionError('Error updating detail: $e'));
    }
  }

  Future<void> _onDeleteDetail(DeleteDetail event, Emitter<InspectionState> emit) async {
    try {
      await inspectionRepository.deleteDetail(event.inspectionId, event.roomId, event.itemId, event.detailId);
      
      if (state is InspectionLoaded) {
        final currentState = state as InspectionLoaded;
        final completionPercentage = await inspectionRepository.calculateCompletionPercentage(event.inspectionId);
        emit(currentState.copyWith(completionPercentage: completionPercentage));
        
        // Try to sync if online
        if (!_isOffline) {
          add(SyncInspection(event.inspectionId, showSuccess: false));
        }
      }
      
      emit(const InspectionOperationSuccess('Detail deleted successfully'));
    } catch (e) {
      emit(InspectionError('Error deleting detail: $e'));
    }
  }

  Future<void> _onCompleteInspection(CompleteInspection event, Emitter<InspectionState> emit) async {
    if (state is InspectionLoaded) {
      final currentState = state as InspectionLoaded;
      emit(InspectionLoading());
      
      try {
        // Update inspection status and add completion timestamp
        final updatedInspection = currentState.inspection.copyWith(
          status: 'completed',
          finishedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        // Save to local database
        await inspectionRepository.saveInspection(updatedInspection, syncNow: false);
        
        // Update state
        emit(InspectionLoaded(
          inspection: updatedInspection,
          rooms: currentState.rooms,
          completionPercentage: 1.0, // 100% complete
          isOffline: _isOffline,
        ));
        
        // Try to sync immediately
        await inspectionRepository.syncInspection(event.inspectionId);
        
        emit(const InspectionOperationSuccess('Inspection completed successfully'));
      } catch (e) {
        emit(InspectionError('Error completing inspection: $e'));
        
        // Restore previous state
        emit(currentState);
      }
    }
  }

  Future<void> _onSaveInspection(SaveInspection event, Emitter<InspectionState> emit) async {
    if (state is InspectionLoaded) {
      final currentState = state as InspectionLoaded;
      
      try {
        // Update status if pending
        Inspection updatedInspection;
        if (currentState.inspection.status == 'pending') {
          updatedInspection = currentState.inspection.copyWith(
            status: 'in_progress',
            updatedAt: DateTime.now(),
          );
        } else {
          updatedInspection = currentState.inspection.copyWith(
            updatedAt: DateTime.now(),
          );
        }
        
        // Save to local database
        await inspectionRepository.saveInspection(updatedInspection, syncNow: !_isOffline);
        
        // Update state
        emit(currentState.copyWith(inspection: updatedInspection));
        
        emit(const InspectionOperationSuccess('Inspection saved successfully'));
      } catch (e) {
        emit(InspectionError('Error saving inspection: $e'));
      }
    }
  }

  @override
  Future<void> close() {
    _connectivitySubscription.cancel();
    return super.close();
  }
}
