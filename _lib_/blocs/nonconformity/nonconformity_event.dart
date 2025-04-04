// lib/blocs/nonconformity/nonconformity_event.dart
import 'package:equatable/equatable.dart';

abstract class NonConformityEvent extends Equatable {
  const NonConformityEvent();

  @override
  List<Object?> get props => [];
}

class LoadNonConformities extends NonConformityEvent {
  final int inspectionId;

  const LoadNonConformities(this.inspectionId);

  @override
  List<Object> get props => [inspectionId];
}

class AddNonConformity extends NonConformityEvent {
  final int inspectionId;
  final int roomId;
  final int itemId;
  final int detailId;
  final String description;
  final String severity;
  final String? correctiveAction;
  final DateTime? deadline;

  const AddNonConformity({
    required this.inspectionId,
    required this.roomId,
    required this.itemId,
    required this.detailId,
    required this.description,
    required this.severity,
    this.correctiveAction,
    this.deadline,
  });

  @override
  List<Object?> get props => [
    inspectionId,
    roomId,
    itemId,
    detailId,
    description,
    severity,
    correctiveAction,
    deadline,
  ];
}

class UpdateNonConformityStatus extends NonConformityEvent {
  final int nonConformityId;
  final String newStatus;

  const UpdateNonConformityStatus(this.nonConformityId, this.newStatus);

  @override
  List<Object> get props => [nonConformityId, newStatus];
}

class AddMediaToNonConformity extends NonConformityEvent {
  final int nonConformityId;
  final String mediaPath;
  final String mediaType;

  const AddMediaToNonConformity(
    this.nonConformityId,
    this.mediaPath,
    this.mediaType,
  );

  @override
  List<Object> get props => [nonConformityId, mediaPath, mediaType];
}

class RemoveMediaFromNonConformity extends NonConformityEvent {
  final int nonConformityId;
  final String mediaPath;

  const RemoveMediaFromNonConformity(this.nonConformityId, this.mediaPath);

  @override
  List<Object> get props => [nonConformityId, mediaPath];
}

// lib/blocs/nonconformity/nonconformity_state.dart
import 'package:equatable/equatable.dart';

abstract class NonConformityState extends Equatable {
  const NonConformityState();
  
  @override
  List<Object?> get props => [];
}

class NonConformityInitial extends NonConformityState {}

class NonConformityLoading extends NonConformityState {}

class NonConformitiesLoaded extends NonConformityState {
  final List<Map<String, dynamic>> nonConformities;
  final bool isOffline;
  
  const NonConformitiesLoaded({
    required this.nonConformities,
    required this.isOffline,
  });
  
  @override
  List<Object> get props => [nonConformities, isOffline];
  
  NonConformitiesLoaded copyWith({
    List<Map<String, dynamic>>? nonConformities,
    bool? isOffline,
  }) {
    return NonConformitiesLoaded(
      nonConformities: nonConformities ?? this.nonConformities,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class NonConformityError extends NonConformityState {
  final String message;
  
  const NonConformityError(this.message);
  
  @override
  List<Object> get props => [message];
}

class NonConformityOperationSuccess extends NonConformityState {
  final String message;
  
  const NonConformityOperationSuccess(this.message);
  
  @override
  List<Object> get props => [message];
}

