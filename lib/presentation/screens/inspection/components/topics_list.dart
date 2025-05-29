// lib/presentation/screens/inspection/components/topics_list.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/presentation/screens/inspection/topic_widget.dart';
import 'package:inspection_app/services/service_factory.dart';

class TopicsList extends StatefulWidget {
 final List<Topic> topics;
 final int expandedTopicIndex;
 final Function(Topic) onTopicUpdated;
 final Function(String) onTopicDeleted;
 final Function(Topic) onTopicDuplicated;
 final Function(int) onExpansionChanged;
 final String inspectionId;
 final VoidCallback? onTopicsReordered;

 const TopicsList({
   super.key,
   required this.topics,
   required this.expandedTopicIndex,
   required this.onTopicUpdated,
   required this.onTopicDeleted,
   required this.onTopicDuplicated,
   required this.onExpansionChanged,
   required this.inspectionId,
   this.onTopicsReordered,
 });

 @override
 State<TopicsList> createState() => _TopicsListState();
}

class _TopicsListState extends State<TopicsList> {
 final ServiceFactory _serviceFactory = ServiceFactory();
 bool _isReordering = false;
 late List<Topic> _localTopics;

 @override
 void initState() {
   super.initState();
   _localTopics = List.from(widget.topics);
 }

 @override
 void didUpdateWidget(TopicsList oldWidget) {
   super.didUpdateWidget(oldWidget);
   if (widget.topics != oldWidget.topics) {
     _localTopics = List.from(widget.topics);
   }
 }

@override
Widget build(BuildContext context) {
  return ReorderableListView.builder(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0), // Reduzido de 8 para 4
    itemCount: _localTopics.length,
    onReorder: _onReorder,
    itemBuilder: (context, index) {
      final topic = _localTopics[index];

      return TopicWidget(
        key: ValueKey(topic.id),
        topic: topic,
        onTopicUpdated: widget.onTopicUpdated,
        onTopicDeleted: widget.onTopicDeleted,
        onTopicDuplicated: widget.onTopicDuplicated,
        isExpanded: index == widget.expandedTopicIndex,
        onExpansionChanged: () => widget.onExpansionChanged(index),
      );
    },
  );
}

 void _onReorder(int oldIndex, int newIndex) async {
   if (_isReordering) return;
   setState(() => _isReordering = true);

   // Ajustar o newIndex quando arrastar para baixo
   if (oldIndex < newIndex) {
     newIndex -= 1;
   }

   try {
     // Reordenar a lista local primeiro
     setState(() {
       final topic = _localTopics.removeAt(oldIndex);
       _localTopics.insert(newIndex, topic);
     });

     // Obter a lista de IDs na nova ordem
     final List<String> topicIds = _localTopics
         .where((topic) => topic.id != null)
         .map((topic) => topic.id!)
         .toList();

     // Atualizar no Firestore
     await _serviceFactory.coordinator.reorderTopics(widget.inspectionId, topicIds);

     // Chamar o callback para atualizar os dados
     widget.onTopicsReordered?.call();

     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text('Tópicos reordenados com sucesso'),
           duration: Duration(seconds: 1),
         ),
       );
     }
   } catch (e) {
     // Em caso de erro, reverter para a ordem original
     setState(() {
       _localTopics = List.from(widget.topics);
     });

     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Erro ao reordenar: $e')),
       );
     }
   } finally {
     if (mounted) {
       setState(() => _isReordering = false);
     }
   }
 }
}