// lib/presentation/screens/inspection/components/landscape_view.dart (updated with rename)
import 'package:flutter/material.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';
import 'package:inspection_app/presentation/widgets/rename_dialog.dart';

class LandscapeView extends StatelessWidget {
  final List<Room> rooms;
  final int selectedRoomIndex;
  final int selectedItemIndex;
  final List<Item> selectedRoomItems;
  final List<Detail> selectedItemDetails;
  final String inspectionId;
  final Function(int) onRoomSelected;
  final Function(int) onItemSelected;
  final Function(Room) onRoomDuplicate;
  final Function(String) onRoomDelete;
  final FirebaseInspectionService inspectionService;
  final VoidCallback onAddRoom;

  const LandscapeView({
    super.key,
    required this.rooms,
    required this.selectedRoomIndex,
    required this.selectedItemIndex,
    required this.selectedRoomItems,
    required this.selectedItemDetails,
    required this.inspectionId,
    required this.onRoomSelected,
    required this.onItemSelected,
    required this.onRoomDuplicate,
    required this.onRoomDelete,
    required this.inspectionService,
    required this.onAddRoom,
  });

  Future<String?> _showTextInputDialog(
      BuildContext context, String title, String label, {String? initialValue}) async {
    return showDialog<String>(
      context: context,
      builder: (context) => RenameDialog(
        title: title,
        label: label,
        initialValue: initialValue ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Container(
      constraints: BoxConstraints(
        maxWidth: screenSize.width,
        maxHeight: screenSize.height - kToolbarHeight - 80,
      ),
      child: Row(
        children: [
          // Rooms column
          Expanded(
            flex: isSmallScreen ? 2 : 2,
            child: _buildRoomsColumn(context),
          ),
          VerticalDivider(thickness: 1, width: 1, color: Colors.grey[700]),
          // Items column
          Expanded(
            flex: isSmallScreen ? 3 : 3,
            child: _buildItemsColumn(context),
          ),
          VerticalDivider(thickness: 1, width: 1, color: Colors.grey[700]),
          // Details column
          Expanded(
            flex: isSmallScreen ? 4 : 5,
            child: _buildDetailsColumn(context),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsColumn(BuildContext context) {
    if (rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_work_outlined, size: 50, color: Colors.grey),
            const SizedBox(height: 8),
            const Text('Nenhum tópico', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: onAddRoom,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Adicionar'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          color: selectedRoomIndex == index 
              ? Colors.blue.withOpacity(0.2) 
              : Colors.grey.shade800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          child: InkWell(
            onTap: () => onRoomSelected(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Room name
                  Expanded(
                    child: Text(
                      room.roomName, 
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  // Action buttons
                  SizedBox(
                    width: 80, // Increased width for rename button
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Rename button
                        InkWell(
                          onTap: () async {
                            final newName = await _showTextInputDialog(
                              context,
                              'Rename Room',
                              'Room name',
                              initialValue: room.roomName,
                            );
                            
                            if (newName != null && newName.isNotEmpty && newName != room.roomName) {
                              final updatedRoom = room.copyWith(
                                roomName: newName,
                                updatedAt: DateTime.now(),
                              );
                              await inspectionService.updateRoom(updatedRoom);
                              // Trigger reload of rooms
                              onRoomSelected(selectedRoomIndex);
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.edit, 
                              color: Colors.white, 
                              size: 18
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 4),
                        
                        // Duplicate button
                        InkWell(
                          onTap: () => onRoomDuplicate(room),
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.copy, 
                              color: Colors.white, 
                              size: 18
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 4),
                        
                        // Delete button
                        InkWell(
                          onTap: () async {
                            if (room.id != null) {
                              await onRoomDelete(room.id!);
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.delete, 
                              color: Colors.white, 
                              size: 18
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemsColumn(BuildContext context) {
    if (selectedRoomIndex < 0) {
      return const Center(
          child: Text('Selecione um tópico', style: TextStyle(color: Colors.white)));
    }

    return Column(
      children: [
        // Header with add item button
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Itens - ${selectedRoomIndex >= 0 && selectedRoomIndex < rooms.length ? rooms[selectedRoomIndex].roomName : ""}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Add button
              InkWell(
                onTap: () async {
                  // Logic to add item
                  if (selectedRoomIndex >= 0 &&
                      rooms[selectedRoomIndex].id != null) {
                    final name = await _showTextInputDialog(
                        context, 'Add Item', 'Item name');
                    if (name != null && name.isNotEmpty) {
                      await inspectionService.addItem(
                        inspectionId,
                        rooms[selectedRoomIndex].id!,
                        name,
                      );
                      onRoomSelected(selectedRoomIndex);
                    }
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(Icons.add_circle, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),

        // Items list
        Expanded(
          child: selectedRoomItems.isEmpty
              ? const Center(
                  child: Text('Nenhum item neste tópico',
                      style: TextStyle(color: Colors.white)))
              : ListView.builder(
                  itemCount: selectedRoomItems.length,
                  itemBuilder: (context, index) {
                    final item = selectedRoomItems[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                      color: selectedItemIndex == index 
                          ? Colors.blue.withOpacity(0.2) 
                          : Colors.grey.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: InkWell(
                        onTap: () => onItemSelected(index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            children: [
                              // Item name
                              Expanded(
                                child: Text(
                                  item.itemName,
                                  style: const TextStyle(color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              
                              // Action buttons
                              SizedBox(
                                width: 60,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Rename button
                                    InkWell(
                                      onTap: () async {
                                        final newName = await _showTextInputDialog(
                                          context,
                                          'Rename Item',
                                          'Item name',
                                          initialValue: item.itemName,
                                        );
                                        
                                        if (newName != null && newName.isNotEmpty && newName != item.itemName) {
                                          final updatedItem = item.copyWith(
                                            itemName: newName,
                                            updatedAt: DateTime.now(),
                                          );
                                          await inspectionService.updateItem(updatedItem);
                                          onRoomSelected(selectedRoomIndex);
                                        }
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(4.0),
                                        child: Icon(
                                          Icons.edit, 
                                          color: Colors.white, 
                                          size: 18
                                        ),
                                      ),
                                    ),
                                    
                                    const SizedBox(width: 4),
                                    
                                    // Delete button
                                    InkWell(
                                      onTap: () async {
                                        if (item.id != null && item.roomId != null) {
                                          await inspectionService.deleteItem(
                                            inspectionId,
                                            item.roomId!,
                                            item.id!,
                                          );
                                          onRoomSelected(selectedRoomIndex);
                                        }
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(4.0),
                                        child: Icon(
                                          Icons.delete, 
                                          color: Colors.white, 
                                          size: 18
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDetailsColumn(BuildContext context) {
    if (selectedItemIndex < 0) {
      return const Center(
          child: Text('Selecione um item', style: TextStyle(color: Colors.white)));
    }

    return Column(
      children: [
        // Header with add detail button
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Detalhes - ${selectedItemIndex >= 0 && selectedItemIndex < selectedRoomItems.length ? selectedRoomItems[selectedItemIndex].itemName : ""}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Add button
              InkWell(
                onTap: () async {
                  // Logic to add detail
                  if (selectedItemIndex >= 0) {
                    final item = selectedRoomItems[selectedItemIndex];
                    if (item.id != null && item.roomId != null) {
                      final name = await _showTextInputDialog(
                          context, 'Add Detail', 'Detail name');
                      if (name != null && name.isNotEmpty) {
                        await inspectionService.addDetail(
                          inspectionId,
                          item.roomId!,
                          item.id!,
                          name,
                        );
                        onItemSelected(selectedItemIndex);
                      }
                    }
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(Icons.add_circle, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),

        // Details list
        Expanded(
          child: selectedItemDetails.isEmpty
              ? const Center(
                  child: Text('Nenhum detalhe neste item',
                      style: TextStyle(color: Colors.white)))
              : ListView.builder(
                  itemCount: selectedItemDetails.length,
                  itemBuilder: (context, index) {
                    final detail = selectedItemDetails[index];
                    return _buildDetailCard(context, detail);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDetailCard(BuildContext context, Detail detail) {
    return Card(
      margin: const EdgeInsets.all(8),
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Detail header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    detail.detailName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Rename button
                InkWell(
                  onTap: () async {
                    final newName = await _showTextInputDialog(
                      context,
                      'Rename Detail',
                      'Detail name',
                      initialValue: detail.detailName,
                    );
                    
                    if (newName != null && newName.isNotEmpty && newName != detail.detailName) {
                      final updatedDetail = detail.copyWith(
                        detailName: newName,
                        updatedAt: DateTime.now(),
                      );
                      await inspectionService.updateDetail(updatedDetail);
                      onItemSelected(selectedItemIndex);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                // Delete button
                InkWell(
                  onTap: () async {
                    // Logic to delete detail
                    if (detail.id != null &&
                        detail.roomId != null &&
                        detail.itemId != null) {
                      await inspectionService.deleteDetail(
                        inspectionId,
                        detail.roomId!,
                        detail.itemId!,
                        detail.id!,
                      );
                      onItemSelected(selectedItemIndex);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.delete, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // "Damaged" checkbox
            Row(
              children: [
                SizedBox(
                  width: 24, 
                  height: 24,
                  child: Checkbox(
                    value: detail.isDamaged ?? false,
                    visualDensity: VisualDensity.compact,
                    onChanged: (value) async {
                      // Update the detail
                      final updatedDetail = detail.copyWith(
                        isDamaged: value,
                        updatedAt: DateTime.now(),
                      );
                      await inspectionService.updateDetail(updatedDetail);
                      onItemSelected(selectedItemIndex);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Damaged', style: TextStyle(color: Colors.white)),
              ],
            ),

            // Value field
            const SizedBox(height: 8),
            TextFormField(
              initialValue: detail.detailValue,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: Colors.white70),
                fillColor: Colors.white10,
                filled: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (value) async {
                // Update the detail after a delay
                final updatedDetail = detail.copyWith(
                  detailValue: value,
                  updatedAt: DateTime.now(),
                );
                await inspectionService.updateDetail(updatedDetail);
              },
            ),

            // Observation field
            const SizedBox(height: 12),
            TextFormField(
              initialValue: detail.observation,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Observation',
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: Colors.white70),
                fillColor: Colors.white10,
                filled: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              maxLines: 3,
              minLines: 2,
              onChanged: (value) async {
                // Update the detail after a delay
                final updatedDetail = detail.copyWith(
                  observation: value,
                  updatedAt: DateTime.now(),
                );
                await inspectionService.updateDetail(updatedDetail);
              },
            ),

            // Add non-conformity button
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate to non-conformity screen with this detail pre-selected
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => NonConformityScreen(
                        inspectionId: inspectionId,
                        preSelectedRoom: detail.roomId,
                        preSelectedItem: detail.itemId,
                        preSelectedDetail: detail.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.report_problem, size: 18),
                label: const Text('Adicionar Não-Conformidade'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}