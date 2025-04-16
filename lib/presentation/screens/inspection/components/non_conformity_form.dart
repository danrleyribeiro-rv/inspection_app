// lib/presentation/screens/inspection/components/non_conformity_form.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/local_database_service.dart';
import 'package:intl/intl.dart';

class NonConformityForm extends StatefulWidget {
  final List<Room> rooms;
  final List<Item> items;
  final List<Detail> details;
  final Room? selectedRoom;
  final Item? selectedItem;
  final Detail? selectedDetail;
  final int inspectionId;
  final bool isOffline;
  final Function(Room) onRoomSelected;
  final Function(Item) onItemSelected;
  final Function(Detail) onDetailSelected;
  final VoidCallback onNonConformitySaved;

  const NonConformityForm({
    Key? key,
    required this.rooms,
    required this.items,
    required this.details,
    required this.selectedRoom,
    required this.selectedItem,
    required this.selectedDetail,
    required this.inspectionId,
    required this.isOffline,
    required this.onRoomSelected,
    required this.onItemSelected,
    required this.onDetailSelected,
    required this.onNonConformitySaved,
  }) : super(key: key);

  @override
  State<NonConformityForm> createState() => _NonConformityFormState();
}

class _NonConformityFormState extends State<NonConformityForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _correctiveActionController = TextEditingController();

  bool _isCreating = false;
  DateTime? _deadline;
  String _severity = 'Média'; // Default value

  @override
  void dispose() {
    _descriptionController.dispose();
    _correctiveActionController.dispose();
    super.dispose();
  }

  Future<void> _saveNonConformity() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.selectedRoom == null ||
        widget.selectedItem == null ||
        widget.selectedDetail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a room, item and detail')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Prepare non-conformity data
      final nonConformityData = {
        'inspection_id': widget.inspectionId,
        'room_id': widget.selectedRoom!.id,
        'item_id': widget.selectedItem!.id,
        'detail_id': widget.selectedDetail!.id,
        'description': _descriptionController.text,
        'severity': _severity,
        'corrective_action': _correctiveActionController.text.isEmpty
            ? null
            : _correctiveActionController.text,
        'deadline': _deadline?.toIso8601String(),
        'status': 'pendente',
        'created_at': DateTime.now().toIso8601String(),
      };

      // Save to local database
      await LocalDatabaseService.saveNonConformity(nonConformityData);

      // Reset form
      _descriptionController.clear();
      _correctiveActionController.clear();
      setState(() {
        _deadline = null;
        _severity = 'Média';
      });

      // Notify parent
      widget.onNonConformitySaved();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Non-conformity registered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error registering non-conformity: $e')),
        );
      }
    } finally {
      setState(() => _isCreating = false);
    }
  }

  Future<void> _pickDeadlineDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() => _deadline = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Offline status indicator
            if (widget.isOffline)
              _buildOfflineIndicator(),

            // Location selection card
            _buildLocationCard(),
            
            // Details card
            _buildDetailsCard(),
            
            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _saveNonConformity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: _isCreating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Register Non-Conformity'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are offline. Non-conformities will be synced when you are online again.',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Non-Conformity Location',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Room dropdown
            DropdownButtonFormField<Room>(
              decoration: const InputDecoration(
                labelText: 'Room',
                border: OutlineInputBorder(),
              ),
              value: widget.selectedRoom,
              items: widget.rooms.map((room) {
                return DropdownMenuItem<Room>(
                  value: room,
                  child: Text(room.roomName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  widget.onRoomSelected(value);
                }
              },
              validator: (value) =>
                  value == null ? 'Select a room' : null,
            ),
            const SizedBox(height: 16),

            // Item dropdown
            DropdownButtonFormField<Item>(
              decoration: const InputDecoration(
                labelText: 'Item',
                border: OutlineInputBorder(),
              ),
              value: widget.selectedItem,
              items: widget.items.map((item) {
                return DropdownMenuItem<Item>(
                  value: item,
                  child: Text(item.itemName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  widget.onItemSelected(value);
                }
              },
              validator: (value) =>
                  value == null ? 'Select an item' : null,
            ),
            const SizedBox(height: 16),

            // Detail dropdown
            DropdownButtonFormField<Detail>(
              decoration: const InputDecoration(
                labelText: 'Detail',
                border: OutlineInputBorder(),
              ),
              value: widget.selectedDetail,
              items: widget.details.map((detail) {
                return DropdownMenuItem<Detail>(
                  value: detail,
                  child: Text(detail.detailName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  widget.onDetailSelected(value);
                }
              },
              validator: (value) =>
                  value == null ? 'Select a detail' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Non-Conformity Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please describe the non-conformity';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Severity dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Severity',
                border: OutlineInputBorder(),
              ),
              value: _severity,
              items: const [
                DropdownMenuItem(value: 'Baixa', child: Text('Low')),
                DropdownMenuItem(value: 'Média', child: Text('Medium')),
                DropdownMenuItem(value: 'Alta', child: Text('High')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _severity = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Deadline date picker
            InkWell(
              onTap: _pickDeadlineDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Deadline',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _deadline == null
                      ? 'Select a date'
                      : DateFormat('dd/MM/yyyy').format(_deadline!),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Corrective action
            TextFormField(
              controller: _correctiveActionController,
              decoration: const InputDecoration(
                labelText: 'Suggested Corrective Action (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}