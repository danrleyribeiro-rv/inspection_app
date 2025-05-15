// lib/presentation/screens/inspection/components/non_conformity_form.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NonConformityForm extends StatefulWidget {
  final List<Room> rooms;
  final List<Item> items;
  final List<Detail> details;
  final Room? selectedRoom;
  final Item? selectedItem;
  final Detail? selectedDetail;
  final String inspectionId;
  final bool isOffline;
  final Function(Room) onRoomSelected;
  final Function(Item) onItemSelected;
  final Function(Detail) onDetailSelected;
  final VoidCallback onNonConformitySaved;

  const NonConformityForm({
    super.key,
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
  });

  @override
  State<NonConformityForm> createState() => _NonConformityFormState();
}

class _NonConformityFormState extends State<NonConformityForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _correctiveActionController = TextEditingController();
  final _inspectionService = FirebaseInspectionService();

  bool _isCreating = false;
  DateTime? _deadline;
  String _severity = 'Média'; // Valor padrão

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
        const SnackBar(
            content:
                Text('Selecione um ambiente, item e detalhe')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Create composite ID with sequential part
      final roomId = widget.selectedRoom!.id;
      final itemId = widget.selectedItem!.id;
      final detailId = widget.selectedDetail!.id;
      
      // Get existing non-conformities to determine the next sequential ID
      final inspectionDoc = await _inspectionService.firestore
          .collection('inspections')
          .doc(widget.inspectionId)
          .get();
          
      if (!inspectionDoc.exists) {
        throw Exception('Inspection not found');
      }
      
      final data = inspectionDoc.data() ?? {};
      final ncArray = List<Map<String, dynamic>>.from(data['non_conformities'] ?? []);
      
      // Filter to find non-conformities for the same detail
      final detailNCs = ncArray.where((nc) => 
          nc['room_id'] == roomId && 
          nc['item_id'] == itemId && 
          nc['detail_id'] == detailId
      ).toList();
      
      // Create non-conformity ID with sequential numbering
      final sequentialPart = detailNCs.length.toString();
      final nonConformityId = '${widget.inspectionId}-$roomId-$itemId-$detailId-$sequentialPart';
      
      // Prepare non-conformity data
      final nonConformityData = {
        'id': nonConformityId,
        'inspection_id': widget.inspectionId,
        'room_id': roomId,
        'item_id': itemId,
        'detail_id': detailId,
        'description': _descriptionController.text,
        'severity': _severity,
        'corrective_action': _correctiveActionController.text.isEmpty
            ? null
            : _correctiveActionController.text,
        'deadline': _deadline?.toIso8601String(),
        'status': 'pendente',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Add to the non-conformities array
      ncArray.add(nonConformityData);
      
      // Update the inspection document
      await _inspectionService.firestore
          .collection('inspections')
          .doc(widget.inspectionId)
          .update({
        'non_conformities': ncArray,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      // Also update the detail to mark as damaged
      final detailsArray = List<Map<String, dynamic>>.from(data['details'] ?? []);
      
      // Find the detail
      final detailIndex = detailsArray.indexWhere(
        (detail) => detail['room_id'] == roomId && 
                   detail['item_id'] == itemId && 
                   detail['id'] == detailId
      );
      
      if (detailIndex >= 0) {
        detailsArray[detailIndex]['is_damaged'] = true;
        detailsArray[detailIndex]['updated_at'] = FieldValue.serverTimestamp();
        
        await _inspectionService.firestore
            .collection('inspections')
            .doc(widget.inspectionId)
            .update({
          'details': detailsArray,
        });
      }

      // Reset the form
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
            content: Text('Não conformidade registrada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao registrar não conformidade: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _pickDeadlineDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      // You might want to localize the date picker too, if needed
      // locale: const Locale('pt', 'BR'),
    );

    if (date != null) {
      setState(() => _deadline = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLocationCard(), // Only Room, Item, Detail selection
            const SizedBox(height: 5),
            Card(
              // Card for non-conformity details
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      // Description
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição', // Translated
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (value) => value == null || value.isEmpty
                          ? 'Informe uma descrição' // Translated
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      // Corrective Action
                      controller: _correctiveActionController,
                      decoration: const InputDecoration(
                        labelText: 'Ação Corretiva (opcional)', // Translated
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      // Deadline
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Prazo', // Translated
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _pickDeadlineDate,
                        ),
                      ),
                      controller: TextEditingController(
                        text: _deadline != null
                            ? DateFormat('dd/MM/yyyy').format(_deadline!)
                            : '',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      // Severity
                      decoration: const InputDecoration(
                        labelText: 'Severidade', // Translated
                        border: OutlineInputBorder(),
                      ),
                      value: _severity,
                      items: const [
                        DropdownMenuItem(value: 'Baixa', child: Text('Baixa')),
                        DropdownMenuItem(value: 'Média', child: Text('Média')),
                        DropdownMenuItem(value: 'Alta', child: Text('Alta')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _severity = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              // Save Button
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
                    : const Text('Registrar Não Conformidade'), // Translated
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    // Now only contains Room, Item, and Detail dropdowns
    return Card(
      margin: const EdgeInsets.only(bottom: 0), // Adjusted margin
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Localização da Não Conformidade', // Translated
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Room dropdown
            DropdownButtonFormField<Room>(
              decoration: const InputDecoration(
                labelText: 'Ambiente', // Translated
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
                  value == null ? 'Selecione um ambiente' : null, // Translated
            ),
            const SizedBox(height: 10),

            // Item dropdown
            DropdownButtonFormField<Item>(
              decoration: const InputDecoration(
                labelText: 'Item', // Translated
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
                  value == null ? 'Selecione um item' : null, // Translated
            ),
            const SizedBox(height: 10),

            // Detail dropdown
            DropdownButtonFormField<Detail>(
              decoration: const InputDecoration(
                labelText: 'Detalhe', // Translated
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
                  value == null ? 'Selecione um detalhe' : null, // Translated
            ),
            // Removed duplicate fields from here
          ],
        ),
      ),
    );
  }
}
