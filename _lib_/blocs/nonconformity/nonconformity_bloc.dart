// lib/blocs/nonconformity/nonconformity_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/blocs/nonconformity/nonconformity_event.dart';
import 'package:inspection_app/blocs/nonconformity/nonconformity_state.dart';
import 'package:inspection_app/data/repositories/nonconformity_repository.dart';
import 'package:inspection_app/services/connectivity/connectivity_service.dart';

class NonConformityBloc extends Bloc<NonConformityEvent, NonConformityState> {
  final NonConformityRepository nonConformityRepository;
  final ConnectivityService connectivityService;
  late StreamSubscription _connectivitySubscription;

  NonConformityBloc({
    required this.nonConformityRepository,
    required this.connectivityService,
  }) : super(NonConformityInitial()) {
    on<LoadNonConformities>(_onLoadNonConformities);
    on<AddNonConformity>(_onAddNonConformity);
    on<UpdateNonConformityStatus>(_onUpdateNonConformityStatus);
    on<AddMediaToNonConformity>(_onAddMediaToNonConformity);
    on<RemoveMediaFromNonConformity>(_onRemoveMediaFromNonConformity);
    
    // Subscribe to connectivity changes
    _connectivitySubscription = connectivityService.onConnectivityChanged.listen(
      (isOffline) {
        if (state is NonConformitiesLoaded) {
          final currentState = state as NonConformitiesLoaded;
          if (currentState.isOffline != isOffline) {
            emit(currentState.copyWith(isOffline: isOffline));
          }
        }
      },
    );
  }

  Future<void> _onLoadNonConformities(
    LoadNonConformities event,
    Emitter<NonConformityState> emit,
  ) async {
    emit(NonConformityLoading());
    
    try {
      final nonConformities = await nonConformityRepository.getNonConformitiesByInspection(
        event.inspectionId,
      );
      
      emit(NonConformitiesLoaded(
        nonConformities: nonConformities,
        isOffline: connectivityService.isOffline,
      ));
    } catch (e) {
      emit(NonConformityError('Failed to load non-conformities: $e'));
    }
  }

  Future<void> _onAddNonConformity(
    AddNonConformity event,
    Emitter<NonConformityState> emit,
  ) async {
    if (state is NonConformitiesLoaded) {
      final currentState = state as NonConformitiesLoaded;
      emit(NonConformityLoading());
      
      try {
        final newNonConformity = await nonConformityRepository.addNonConformity(
          event.inspectionId,
          event.roomId,
          event.itemId,
          event.detailId,
          event.description,
          event.severity,
          correctiveAction: event.correctiveAction,
          deadline: event.deadline,
        );
        
        // Add the new non-conformity to the current list
        final updatedNonConformities = List<Map<String, dynamic>>.from(currentState.nonConformities);
        updatedNonConformities.add(newNonConformity);
        
        emit(NonConformitiesLoaded(
          nonConformities: updatedNonConformities,
          isOffline: currentState.isOffline,
        ));
        
        emit(const NonConformityOperationSuccess('Non-conformity added successfully'));
      } catch (e) {
        emit(NonConformityError('Failed to add non-conformity: $e'));
        emit(currentState); // Restore previous state
      }
    }
  }

  Future<void> _onUpdateNonConformityStatus(
    UpdateNonConformityStatus event,
    Emitter<NonConformityState> emit,
  ) async {
    if (state is NonConformitiesLoaded) {
      final currentState = state as NonConformitiesLoaded;
      
      try {
        await nonConformityRepository.updateNonConformityStatus(
          event.nonConformityId,
          event.newStatus,
        );
        
        // Update the status in the current list
        final updatedNonConformities = currentState.nonConformities.map((nc) {
          if (nc['id'] == event.nonConformityId) {
            return {
              ...nc,
              'status': event.newStatus,
              'updated_at': DateTime.now().toIso8601String(),
            };
          }
          return nc;
        }).toList();
        
        emit(NonConformitiesLoaded(
          nonConformities: updatedNonConformities,
          isOffline: currentState.isOffline,
        ));
        
        emit(const NonConformityOperationSuccess('Status updated successfully'));
      } catch (e) {
        emit(NonConformityError('Failed to update status: $e'));
        emit(currentState); // Restore previous state
      }
    }
  }

  Future<void> _onAddMediaToNonConformity(
    AddMediaToNonConformity event,
    Emitter<NonConformityState> emit,
  ) async {
    if (state is NonConformitiesLoaded) {
      final currentState = state as NonConformitiesLoaded;
      
      try {
        await nonConformityRepository.addMediaToNonConformity(
          event.nonConformityId,
          event.mediaPath,
          event.mediaType,
        );
        
        emit(const NonConformityOperationSuccess('Media added successfully'));
      } catch (e) {
        emit(NonConformityError('Failed to add media: $e'));
      }
    }
  }

  Future<void> _onRemoveMediaFromNonConformity(
    RemoveMediaFromNonConformity event,
    Emitter<NonConformityState> emit,
  ) async {
    if (state is NonConformitiesLoaded) {
      final currentState = state as NonConformitiesLoaded;
      
      try {
        await nonConformityRepository.removeMediaFromNonConformity(
          event.nonConformityId,
          event.mediaPath,
        );
        
        emit(const NonConformityOperationSuccess('Media removed successfully'));
      } catch (e) {
        emit(NonConformityError('Failed to remove media: $e'));
      }
    }
  }

  @override
  Future<void> close() {
    _connectivitySubscription.cancel();
    return super.close();
  }
}

// lib/data/repositories/nonconformity_repository.dart
abstract class NonConformityRepository {
  Future<List<Map<String, dynamic>>> getNonConformitiesByInspection(int inspectionId);
  
  Future<Map<String, dynamic>> addNonConformity(
    int inspectionId,
    int roomId,
    int itemId,
    int detailId,
    String description,
    String severity, {
    String? correctiveAction,
    DateTime? deadline,
  });
  
  Future<void> updateNonConformityStatus(int nonConformityId, String newStatus);
  
  Future<List<Map<String, dynamic>>> getMediaByNonConformity(int nonConformityId);
  
  Future<void> addMediaToNonConformity(
    int nonConformityId,
    String mediaPath,
    String mediaType,
  );
  
  Future<void> removeMediaFromNonConformity(
    int nonConformityId,
    String mediaPath,
  );
}
