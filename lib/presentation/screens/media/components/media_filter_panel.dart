// lib/presentation/screens/media/components/media_filter_panel.dart
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';

class MediaFilterPanel extends StatefulWidget {
  final String inspectionId;
  final List<Topic> topics;
  final String? selectedTopicId;
  final String? selectedItemId;
  final String? selectedDetailId;
  final bool? isNonConformityOnly;
  final String? mediaType;
  final Function({
    String? topicId,
    String? itemId,
    String? detailId,
    bool? isNonConformityOnly,
    String? mediaType,
    required bool topicOnly,
    required bool itemOnly,
  }) onApplyFilters;
  final VoidCallback onClearFilters;

  const MediaFilterPanel({
    super.key,
    required this.inspectionId,
    required this.topics,
    this.selectedTopicId,
    this.selectedItemId,
    this.selectedDetailId,
    this.isNonConformityOnly,
    this.mediaType,
    required this.onApplyFilters,
    required this.onClearFilters,
  });

  @override
  State<MediaFilterPanel> createState() => _MediaFilterPanelState();
}

class _MediaFilterPanelState extends State<MediaFilterPanel> {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;

  String? _topicId;
  String? _itemId;
  String? _detailId;
  bool? _isNonConformityOnly;
  String? _mediaType;
  bool _topicOnly = false;
  bool _itemOnly = false;

  List<Item> _items = [];
  List<Detail> _details = [];

  bool _isLoadingItems = false;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _topicId = widget.selectedTopicId;
    _itemId = widget.selectedItemId;
    _detailId = widget.selectedDetailId;
    _isNonConformityOnly = widget.isNonConformityOnly;
    _mediaType = widget.mediaType;
    _topicOnly = (_topicId != null && _itemId == null && _detailId == null);
    _itemOnly = (_itemId != null && _detailId == null);

    if (_topicId != null) _loadItems(_topicId!);
    if (_topicId != null && _itemId != null) _loadDetails(_topicId!, _itemId!);
  }

  Future<void> _loadItems(String topicId) async {
    setState(() => _isLoadingItems = true);
    try {
      final items = await _serviceFactory.dataService.getItems(topicId);
      if (mounted) setState(() => _items = items);
    } finally {
      if (mounted) setState(() => _isLoadingItems = false);
    }
  }

  Future<void> _loadDetails(String topicId, String itemId) async {
    setState(() => _isLoadingDetails = true);
    try {
      final details = await _serviceFactory.dataService.getDetails(itemId);
      if (mounted) setState(() => _details = details);
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  void _applyFilters() {
    widget.onApplyFilters(
      topicId: _topicId,
      itemId: _itemId,
      detailId: _detailId,
      isNonConformityOnly: _isNonConformityOnly,
      mediaType: _mediaType,
      topicOnly: _topicOnly,
      itemOnly: _itemOnly,
    );
    Navigator.of(context).pop();
  }

  void _clearFilters() {
    setState(() {
      _topicId = null;
      _itemId = null;
      _detailId = null;
      _isNonConformityOnly = null;
      _mediaType = null;
      _topicOnly = false;
      _itemOnly = false;
      _items = [];
      _details = [];
    });
    widget.onClearFilters();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              16,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filtrar Mídia',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 8),

              // --- TOPIC FILTER ---
              const Text('Tópico', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 5),
              Container(
                decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonFormField<String>(
                  value: _topicId,
                  isExpanded: true,
                  dropdownColor: Colors.grey[800],
                  decoration: const InputDecoration(
                      hintText: 'Todos os Tópicos',
                      hintStyle: TextStyle(color: Colors.white70),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      border: InputBorder.none),
                  items: widget.topics
                      .map((topic) => DropdownMenuItem<String>(
                          value: topic.id, child: Text(topic.topicName)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _topicId = value;
                      _itemId = null;
                      _detailId = null;
                      _items = [];
                      _details = [];
                      _topicOnly = (value != null);
                      _itemOnly = false;
                    });
                    if (value != null) _loadItems(value);
                  },
                ),
              ),
              const SizedBox(height: 10),

              if (_topicId != null)
                CheckboxListTile(
                  title: const Text('Apenas do Tópico'),
                  subtitle:
                      const Text('Incluir mídias apenas do tópico selecionado'),
                  value: _topicOnly,
                  onChanged: (value) {
                    setState(() {
                      _topicOnly = value ?? false;
                      if (_topicOnly) {
                        _itemOnly = false;
                        _itemId = null;
                        _detailId = null;
                      }
                    });
                  },
                  activeColor: Colors.blue,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),

              // --- ITEM FILTER ---
              if (!_topicOnly && _topicId != null) ...[
                const SizedBox(height: 10),
                const Text('Item', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 5),
                _isLoadingItems
                    ? const LinearProgressIndicator()
                    : Container(
                        decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8)),
                        child: DropdownButtonFormField<String>(
                          value: _itemId,
                          isExpanded: true,
                          dropdownColor: Colors.grey[800],
                          decoration: const InputDecoration(
                              hintText: 'Todos os Itens',
                              hintStyle: TextStyle(color: Colors.white70),
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 16),
                              border: InputBorder.none),
                          items: _items
                              .map((item) => DropdownMenuItem<String>(
                                  value: item.id, child: Text(item.itemName)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _itemId = value;
                              _detailId = null;
                              _details = [];
                              _itemOnly = (value != null);
                            });
                            if (value != null) _loadDetails(_topicId!, value);
                          },
                        ),
                      ),
              ],

              if (_itemId != null && !_topicOnly)
                CheckboxListTile(
                  title: const Text('Apenas do Item'),
                  subtitle:
                      const Text('Incluir mídias apenas do item selecionado'),
                  value: _itemOnly,
                  onChanged: (value) {
                    setState(() {
                      _itemOnly = value ?? false;
                      if (_itemOnly) {
                        _detailId = null;
                      }
                    });
                  },
                  activeColor: Colors.blue,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),

              // --- DETAIL FILTER ---
              if (!_topicOnly && !_itemOnly && _itemId != null) ...[
                const SizedBox(height: 10),
                const Text('Detalhe', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 5),
                _isLoadingDetails
                    ? const LinearProgressIndicator()
                    : Container(
                        decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8)),
                        child: DropdownButtonFormField<String>(
                          value: _detailId,
                          isExpanded: true,
                          dropdownColor: Colors.grey[800],
                          decoration: const InputDecoration(
                              hintText: 'Todos os Detalhes',
                              hintStyle: TextStyle(color: Colors.white70),
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 16),
                              border: InputBorder.none),
                          items: _details
                              .map((detail) => DropdownMenuItem<String>(
                                  value: detail.id,
                                  child: Text(detail.detailName)))
                              .toList(),
                          onChanged: (value) {
                            setState(() => _detailId = value);
                          },
                        ),
                      ),
              ],
              const SizedBox(height: 16),

              // --- NC FILTER ---
              SwitchListTile(
                title: const Text('Apenas Não Conformidades'),
                value: _isNonConformityOnly ?? false,
                onChanged: (value) =>
                    setState(() => _isNonConformityOnly = value),
                activeColor: Colors.orange,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 10),

              // --- MEDIA TYPE FILTER ---
              const Text('Tipo de Mídia',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 5),
              Container(
                decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    RadioListTile<String?>(
                        title: const Text('Todos'),
                        value: null,
                        groupValue: _mediaType,
                        onChanged: (value) =>
                            setState(() => _mediaType = value),
                        activeColor: Colors.blue),
                    Divider(height: 1, color: Colors.grey[700]),
                    RadioListTile<String>(
                        title: const Text('Fotos'),
                        value: 'image',
                        groupValue: _mediaType,
                        onChanged: (value) =>
                            setState(() => _mediaType = value),
                        activeColor: Colors.blue),
                    Divider(height: 1, color: Colors.grey[700]),
                    RadioListTile<String>(
                        title: const Text('Vídeos'),
                        value: 'video',
                        groupValue: _mediaType,
                        onChanged: (value) =>
                            setState(() => _mediaType = value),
                        activeColor: Colors.blue),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- ACTION BUTTONS ---
              Row(
                children: [
                  Expanded(
                      child: TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Limpar'))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text('Aplicar Filtros'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
