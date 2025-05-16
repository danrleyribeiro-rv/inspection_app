// lib/presentation/screens/inspection/non_conformity_screen.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/presentation/screens/inspection/components/non_conformity_form.dart';
import 'package:inspection_app/presentation/screens/inspection/components/non_conformity_list.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';

class NonConformityScreen extends StatefulWidget {
 final String inspectionId;
 final dynamic preSelectedTopic; // Aceita String ou int
 final dynamic preSelectedItem; // Aceita String ou int
 final dynamic preSelectedDetail; // Aceita String ou int

 const NonConformityScreen({
   super.key,
   required this.inspectionId,
   this.preSelectedTopic,
   this.preSelectedItem,
   this.preSelectedDetail,
 });

 @override
 State<NonConformityScreen> createState() => _NonConformityScreenState();
}

class _NonConformityScreenState extends State<NonConformityScreen>
   with SingleTickerProviderStateMixin {
 final _inspectionService = FirebaseInspectionService();
 final _connectivityService = Connectivity();
 late TabController _tabController;

 bool _isLoading = true;
 bool _isOffline = false;
 List<Topic> _topics = [];
 List<Item> _items = [];
 List<Detail> _details = [];
 List<Map<String, dynamic>> _nonConformities = [];

 Topic? _selectedTopic;
 Item? _selectedItem;
 Detail? _selectedDetail;

 // Flag para operações de edição/exclusão
 bool _isProcessing = false;

 @override
 void initState() {
   super.initState();
   _tabController = TabController(length: 2, vsync: this);
   _connectivityService.checkConnectivity().then((result) {
     if (mounted) {
       setState(() {
         _isOffline = result == ConnectivityResult.none;
       });
     }
   });
   _loadData();
 }

 @override
 void dispose() {
   _tabController.dispose();
   super.dispose();
 }

 Future<void> _loadData() async {
   setState(() => _isLoading = true);

   try {
     // Load topics
     final topics = await _inspectionService.getTopics(widget.inspectionId);
     setState(() => _topics = topics);

     // Se houver pré-seleção, localizar o tópico correspondente
     if (widget.preSelectedTopic != null) {
       // Procurar tópico pelo ID usando toString() para comparação segura
       Topic? selectedTopic;
       for (var topic in _topics) {
         if (topic.id != null &&
             topic.id.toString() == widget.preSelectedTopic.toString()) {
           selectedTopic = topic;
           break;
         }
       }

       // Se encontrou o tópico pré-selecionado, carregá-lo
       if (selectedTopic != null) {
         await _topicSelected(selectedTopic);
       } else if (_topics.isNotEmpty) {
         // Senão, carrega o primeiro tópico disponível
         await _topicSelected(_topics.first);
       }

       // Se tiver item pré-selecionado e tiver itens carregados
       if (widget.preSelectedItem != null && _items.isNotEmpty) {
         // Procurar item pelo ID
         Item? selectedItem;
         for (var item in _items) {
           if (item.id != null &&
               item.id.toString() == widget.preSelectedItem.toString()) {
             selectedItem = item;
             break;
           }
         }

         // Se encontrou o item pré-selecionado, carregá-lo
         if (selectedItem != null) {
           await _itemSelected(selectedItem);
         } else if (_items.isNotEmpty) {
           // Senão, carrega o primeiro item disponível
           await _itemSelected(_items.first);
         }

         // Se tiver detalhe pré-selecionado e tiver detalhes carregados
         if (widget.preSelectedDetail != null && _details.isNotEmpty) {
           // Procurar detalhe pelo ID
           Detail? selectedDetail;
           for (var detail in _details) {
             if (detail.id != null &&
                 detail.id.toString() == widget.preSelectedDetail.toString()) {
               selectedDetail = detail;
               break;
             }
           }

           // Se encontrou o detalhe pré-selecionado, selecioná-lo
           if (selectedDetail != null) {
             _detailSelected(selectedDetail);
           } else if (_details.isNotEmpty) {
             // Senão, seleciona o primeiro detalhe disponível
             _detailSelected(_details.first);
           }
         }
       }
     }

     // Carregar não conformidades existentes
     await _loadNonConformities();

     setState(() => _isLoading = false);
   } catch (e) {
     print('Erro ao carregar dados: $e');
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Erro ao carregar dados: $e')),
       );
       setState(() => _isLoading = false);
     }
   }
 }

 Future<void> _loadNonConformities() async {
   try {
     final nonConformities = await _inspectionService
         .getNonConformitiesByInspection(widget.inspectionId);

     if (mounted) {
       setState(() {
         _nonConformities = nonConformities;
       });
     }
   } catch (e) {
     print('Erro ao carregar não conformidades: $e');
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Erro ao carregar não conformidades: $e')),
       );
     }
   }
 }

 Future<void> _topicSelected(Topic topic) async {
   setState(() {
     _selectedTopic = topic;
     _selectedItem = null;
     _selectedDetail = null;
     _items = [];
     _details = [];
   });

   if (topic.id != null) {
     try {
       final items =
           await _inspectionService.getItems(widget.inspectionId, topic.id!);
       setState(() => _items = items);
     } catch (e) {
       print('Erro ao carregar itens: $e');
     }
   }
 }

 Future<void> _itemSelected(Item item) async {
   setState(() {
     _selectedItem = item;
     _selectedDetail = null;
     _details = [];
   });

   if (item.id != null && item.topicId != null) {
     try {
       final details = await _inspectionService.getDetails(
           widget.inspectionId, item.topicId!, item.id!);
       setState(() => _details = details);
     } catch (e) {
       print('Erro ao carregar detalhes: $e');
     }
   }
 }

 void _detailSelected(Detail detail) {
   setState(() => _selectedDetail = detail);
 }

 // Método para atualizar status de não conformidade
 Future<void> _updateNonConformityStatus(String id, String newStatus) async {
   if (_isProcessing) return;

   setState(() => _isProcessing = true);

   try {
     await _inspectionService.updateNonConformityStatus(id, newStatus);

     // Reload list
     await _loadNonConformities();

     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text('Status atualizado com sucesso!'),
           backgroundColor: Colors.green,
         ),
       );
     }
   } catch (e) {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Erro ao atualizar status: $e')),
       );
     }
   } finally {
     if (mounted) {
       setState(() => _isProcessing = false);
     }
   }
 }

 // Método para editar uma não conformidade
 Future<void> _updateNonConformity(Map<String, dynamic> updatedData) async {
   if (_isProcessing) return;

   setState(() => _isProcessing = true);

   try {
     // Verifica se já possui ID composto, caso contrário cria
     String nonConformityId = updatedData['id'];
     if (!nonConformityId.contains('-')) {
       nonConformityId = '${widget.inspectionId}-${updatedData['topic_id']}-${updatedData['item_id']}-${updatedData['detail_id']}-$nonConformityId';
     }
     
     await _inspectionService.updateNonConformity(nonConformityId, updatedData);

     // Atualizar a lista
     await _loadNonConformities();

     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text('Não conformidade atualizada com sucesso!'),
           backgroundColor: Colors.green,
         ),
       );
     }
   } catch (e) {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Erro ao atualizar não conformidade: $e')),
       );
     }
   } finally {
     if (mounted) {
       setState(() => _isProcessing = false);
     }
   }
 }

 // Método para excluir uma não conformidade
 Future<void> _deleteNonConformity(String id) async {
   if (_isProcessing) return;

   setState(() => _isProcessing = true);

   try {
     await _inspectionService.deleteNonConformity(id, widget.inspectionId);

     // Atualizar a lista
     await _loadNonConformities();

     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text('Não conformidade excluída com sucesso!'),
           backgroundColor: Colors.green,
         ),
       );
     }
   } catch (e) {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Erro ao excluir não conformidade: $e')),
       );
     }
   } finally {
     if (mounted) {
       setState(() => _isProcessing = false);
     }
   }
 }

 void _onNonConformitySaved() {
   // Reload the list of non-conformities
   _loadNonConformities();

   // Switch to the list tab
   _tabController.animateTo(1);
 }

 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(
       title: const Text('Não Conformidades'),
       bottom: TabBar(
         controller: _tabController,
         tabs: const [
           Tab(text: 'Nova Não Conformidade'),
           Tab(text: 'Não Conformidades'),
         ],
       ),
       actions: [
         // Mostrar indicador de carregamento se estiver processando
         if (_isProcessing)
           const Padding(
             padding: EdgeInsets.symmetric(horizontal: 16),
             child: SizedBox(
               width: 24,
               height: 24,
               child: CircularProgressIndicator(
                 color: Colors.white,
                 strokeWidth: 2,
               ),
             ),
           ),
       ],
     ),
     body: _isLoading
         ? const Center(child: CircularProgressIndicator())
         : TabBarView(
             controller: _tabController,
             children: [
               NonConformityForm(
                 topics: _topics,
                 items: _items,
                 details: _details,
                 selectedTopic: _selectedTopic,
                 selectedItem: _selectedItem,
                 selectedDetail: _selectedDetail,
                 inspectionId: widget.inspectionId,
                 isOffline: _isOffline,
                 onTopicSelected: _topicSelected,
                 onItemSelected: _itemSelected,
                 onDetailSelected: _detailSelected,
                 onNonConformitySaved: _onNonConformitySaved,
               ),
               NonConformityList(
                 nonConformities: _nonConformities,
                 inspectionId: widget.inspectionId,
                 onStatusUpdate: _updateNonConformityStatus,
                 onDeleteNonConformity: _deleteNonConformity,
                 onEditNonConformity: _updateNonConformity,
               ),
             ],
           ),
   );
 }
}