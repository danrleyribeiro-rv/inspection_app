// lib/presentation/screens/inspection/detail_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/presentation/widgets/media_handling_widget.dart';
import 'package:inspection_app/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:inspection_app/presentation/widgets/rename_dialog.dart';

class DetailWidget extends StatefulWidget {
 final Detail detail;
 final Function(Detail) onDetailUpdated;
 final Function(String) onDetailDeleted;
 final Function(Detail) onDetailDuplicated;
 final bool isExpanded;
 final VoidCallback onExpansionChanged;

 const DetailWidget({
   super.key,
   required this.detail,
   required this.onDetailUpdated,
   required this.onDetailDeleted,
   required this.onDetailDuplicated,
   required this.isExpanded,
   required this.onExpansionChanged,
 });

 @override
 State<DetailWidget> createState() => _DetailWidgetState();
}

class _DetailWidgetState extends State<DetailWidget> {
 final TextEditingController _valueController = TextEditingController();
 final TextEditingController _observationController = TextEditingController();
 late bool _isDamaged;
 Timer? _debounce;

 @override
 void initState() {
   super.initState();
   _valueController.text = widget.detail.detailValue ?? '';
   _observationController.text = widget.detail.observation ?? '';
   _isDamaged = widget.detail.isDamaged ?? false;
 }

 @override
 void dispose() {
   _valueController.dispose();
   _observationController.dispose();
   _debounce?.cancel();
   super.dispose();
 }

 void _updateDetail() {
   if (_debounce?.isActive ?? false) _debounce?.cancel();
   _debounce = Timer(const Duration(milliseconds: 500), () {
     final updatedDetail = widget.detail.copyWith(
       detailValue:
           _valueController.text.isEmpty ? null : _valueController.text,
       observation: _observationController.text.isEmpty
           ? null
           : _observationController.text,
       isDamaged: _isDamaged,
       updatedAt: DateTime.now(),
     );
     widget.onDetailUpdated(updatedDetail);
   });
 }

 Future<void> _renameDetail() async {
   final newName = await showDialog<String>(
     context: context,
     builder: (context) => RenameDialog(
       title: 'Renomear Detalhe',
       label: 'Nome do Detalhe',
       initialValue: widget.detail.detailName,
     ),
   );

   if (newName != null && newName != widget.detail.detailName) {
     final updatedDetail = widget.detail.copyWith(
       detailName: newName,
       updatedAt: DateTime.now(),
     );
     widget.onDetailUpdated(updatedDetail);
   }
 }

 Future<void> _showDeleteConfirmation() async {
   final confirmed = await showDialog<bool>(
     context: context,
     builder: (context) => AlertDialog(
       title: const Text('Excluir Detalhe'),
       content: Text(
           'Tem certeza que deseja excluir "${widget.detail.detailName}"?\n\nTodas as mídias associadas serão excluídas permanentemente.'),
       actions: [
         TextButton(
           onPressed: () => Navigator.of(context).pop(false),
           child: const Text('Cancelar'),
         ),
         TextButton(
           onPressed: () => Navigator.of(context).pop(true),
           style: TextButton.styleFrom(foregroundColor: Colors.red),
           child: const Text('Excluir'),
         ),
       ],
     ),
   );

   if (confirmed == true && widget.detail.id != null) {
     widget.onDetailDeleted(widget.detail.id!);
   }
 }

 Future<void> _editObservationDialog() async {
   final result = await showDialog<String>(
     context: context,
     builder: (context) {
       final controller =
           TextEditingController(text: _observationController.text);
       return AlertDialog(
         title: const Text('Editar Observação'),
         content: SizedBox(
           width: MediaQuery.of(context).size.width *
               0.8, // 80% da largura da tela
           child: ConstrainedBox(
             constraints: const BoxConstraints(maxHeight: 220),
             child: TextFormField(
               controller: controller,
               maxLines: 6,
               decoration:
                   const InputDecoration(hintText: 'Digite a observação...'),
               autofocus: true,
             ),
           ),
         ),
         actions: [
           TextButton(
             onPressed: () => Navigator.of(context).pop(),
             child: const Text('Cancelar'),
           ),
           TextButton(
             onPressed: () => Navigator.of(context).pop(controller.text),
             child: const Text('Salvar'),
           ),
         ],
       );
     },
   );
   if (result != null) {
     _observationController.text = result;
     _updateDetail();
     setState(() {});
   }
 }

 Future<void> _selectOptionDialog() async {
   if (widget.detail.options == null || widget.detail.options!.isEmpty) return;
   final result = await showDialog<String>(
     context: context,
     builder: (context) {
       return AlertDialog(
         title: const Text('Selecione uma opção'),
         content: SizedBox(
           width: MediaQuery.of(context).size.width * 0.8,
           child: ConstrainedBox(
             constraints: const BoxConstraints(maxHeight: 220),
             child: SingleChildScrollView(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: widget.detail.options!
                     .map((opt) => ListTile(
                           title: Text(opt),
                           onTap: () => Navigator.of(context).pop(opt),
                         ))
                     .toList(),
               ),
             ),
           ),
         ),
       );
     },
   );
   if (result != null) {
     _valueController.text = result;
     _updateDetail();
     setState(() {});
   }
 }

 @override
 Widget build(BuildContext context) {
   return Card(
     margin: const EdgeInsets.only(bottom: 10),
     elevation: 0,
     shape: RoundedRectangleBorder(
       borderRadius: BorderRadius.zero,
       side: BorderSide(
           color: _isDamaged ? Colors.red : Colors.grey.shade300,
           width: _isDamaged ? 2 : 1),
     ),
     child: Column(
       children: [
         InkWell(
           onTap: widget.onExpansionChanged,
           child: Padding(
             padding: const EdgeInsets.all(12),
             child: Row(
               children: [
                 if (_isDamaged)
                   const Icon(Icons.warning, color: Colors.red, size: 16),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Text(
                     widget.detail.detailName,
                     style: TextStyle(
                       fontSize: 16,
                       fontWeight: FontWeight.bold,
                       color: _isDamaged ? Colors.red : null,
                     ),
                   ),
                 ),
                 if (_valueController.text.isNotEmpty)
                   Container(
                     padding: const EdgeInsets.symmetric(
                         horizontal: 8, vertical: 4),
                     decoration: BoxDecoration(
                       color: Colors.blue.shade100,
                       borderRadius: BorderRadius.circular(6),
                     ),
                     child: Text(
                       _valueController.text,
                       style: TextStyle(
                           fontSize: 12, color: Colors.blue.shade900),
                     ),
                   ),
                 const SizedBox(width: 4),
                 IconButton(
                   icon: const Icon(Icons.edit, size: 18),
                   onPressed: _renameDetail,
                   padding: EdgeInsets.zero,
                   constraints: const BoxConstraints(),
                   tooltip: 'Renomear Detalhe',
                 ),
                 const SizedBox(width: 4),
                 IconButton(
                   icon: const Icon(Icons.copy, size: 18),
                   onPressed: () => widget.onDetailDuplicated(widget.detail),
                   padding: EdgeInsets.zero,
                   constraints: const BoxConstraints(),
                   tooltip: 'Duplicar Detalhe',
                 ),
                 const SizedBox(width: 4),
                 IconButton(
                   icon: const Icon(Icons.delete, size: 18),
                   onPressed: _showDeleteConfirmation,
                   padding: EdgeInsets.zero,
                   constraints: const BoxConstraints(),
                   tooltip: 'Excluir Detalhe',
                 ),
                 const SizedBox(width: 4),
                 Icon(
                     widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                     size: 18),
               ],
             ),
           ),
         ),
         if (widget.isExpanded) ...[
           Divider(height: 1, thickness: 1, color: Colors.grey[300]),
           Padding(
             padding: const EdgeInsets.all(16),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                     Checkbox(
                       value: _isDamaged,
                       onChanged: (value) {
                         setState(() {
                           _isDamaged = value ?? false;
                         });
                         _updateDetail();
                       },
                     ),
                     const Text('Detalhe danificado'),
                   ],
                 ),
                 const SizedBox(height: 5),
                 if (widget.detail.type == 'select' &&
                     widget.detail.options != null &&
                     widget.detail.options!.isNotEmpty)
                   GestureDetector(
                     onTap: _selectOptionDialog,
                     child: InputDecorator(
                       decoration: const InputDecoration(
                         labelText: 'Opção',
                         border: OutlineInputBorder(),
                       ),
                       child: Text(_valueController.text.isEmpty
                           ? 'Selecione...'
                           : _valueController.text),
                     ),
                   )
                 else
                   TextFormField(
                     controller: _valueController,
                     decoration: const InputDecoration(
                       labelText: 'Valor',
                       border: OutlineInputBorder(),
                     ),
                     onChanged: (_) => _updateDetail(),
                   ),
                 const SizedBox(height: 16),
                 GestureDetector(
                   onTap: _editObservationDialog,
                   child: AbsorbPointer(
                     child: TextFormField(
                       controller: _observationController,
                       decoration: const InputDecoration(
                         labelText: 'Observação',
                         border: OutlineInputBorder(),
                       ),
                       maxLines: 3,
                     ),
                   ),
                 ),
                 const SizedBox(height: 16),
                 if (widget.detail.id != null &&
                     widget.detail.topicId != null &&
                     widget.detail.itemId != null)
                   MediaHandlingWidget(
                     inspectionId: widget.detail.inspectionId,
                     topicId: widget.detail.topicId!,
                     itemId: widget.detail.itemId!,
                     detailId: widget.detail.id!,
                     onMediaAdded: (_) => setState(() {}),
                     onMediaDeleted: (_) => setState(() {}),
                     onMediaMoved: (_, __, ___, ____) => setState(() {}),
                   ),
                 const SizedBox(height: 5),
                 ElevatedButton.icon(
                   onPressed: () {
                     if (widget.detail.id != null &&
                         widget.detail.topicId != null &&
                         widget.detail.itemId != null) {
                       Navigator.of(context).push(
                         MaterialPageRoute(
                           builder: (context) => NonConformityScreen(
                             inspectionId: widget.detail.inspectionId,
                             preSelectedTopic: widget.detail.topicId,
                             preSelectedItem: widget.detail.itemId,
                             preSelectedDetail: widget.detail.id,
                           ),
                         ),
                       );
                     } else {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(
                           content: Text(
                               'Não foi possível abrir a tela de não-conformidade. IDs ausentes.'),
                           backgroundColor: Colors.red,
                         ),
                       );
                     }
                   },
                   icon: const Icon(Icons.report_problem),
                   label: const Text('+ Não Conformidade'),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: const Color.fromARGB(255, 255, 0, 0),
                     foregroundColor: const Color.fromARGB(255, 255, 255, 255),
                   ),
                 ),
               ],
             ),
           ),
         ],
       ],
     ),
   );
 }
}