// lib/blocs/inspection/inspection_state.dart
import 'package:equatable/equatable.dart';
import 'package:inspection_app/data/models/inspection.dart';
import 'package:inspection_app/data/models/room.dart';
import 'package:inspection_app/data/models/item.dart';
import 'package:inspection_app/data/models/detail.dart';

abstract class InspectionState extends Equatable {
  const InspectionState();
  
  @override
  List<Object?> get props => [];
}

class InspectionInitial extends InspectionState {}

class InspectionLoading extends InspectionState {}

class InspectionLoaded extends InspectionState {
  final Inspection inspection;
  final List<Room> rooms;
  final double completionPercentage;
  final bool isOffline;
  final bool isSyncing;
  
  const InspectionLoaded({
    required this.inspection,
    required this.rooms,
    this.completionPercentage = 0.0,
    this.isOffline = false,
    this.isSyncing = false,
  });
  
  @override
  List<Object?> get props => [inspection, rooms, completionPercentage, isOffline, isSyncing];
  
  InspectionLoaded copyWith({
    Inspection? inspection,
    List<Room>? rooms,
    double? completionPercentage,
    bool? isOffline,
    bool? isSyncing,
  }) {
    return InspectionLoaded(
      inspection: inspection ?? this.inspection,
      rooms: rooms ?? this.rooms,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      isOffline: isOffline ?? this.isOffline,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

class ItemsLoaded extends InspectionState {
  final List<Item> items;
  
  const ItemsLoaded(this.items);
  
  @override
  List<Object> get props => [items];
}

class DetailsLoaded extends InspectionState {
  final List<Detail> details;
  
  const DetailsLoaded(this.details);
  
  @override
  List<Object> get props => [details];
}

class InspectionError extends InspectionState {
  final String message;
  
  const InspectionError(this.message);
  
  @override
  List<Object> get props => [message];
}

class InspectionOperationSuccess extends InspectionState {
  final String message;
  
  const InspectionOperationSuccess(this.message);
  
  @override
  List<Object> get props => [message];
}
