// lib/presentation/screens/media/components/media_filter_panel.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/service_factory.dart';

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
  final ServiceFactory _serviceFactory = ServiceFactory();

  String? _topicId;
  String? _itemId;
  String? _detailId;
  bool _isNonConformityOnly = false;
  String? _mediaType;
  bool _topicOnly = false;

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
    _isNonConformityOnly = widget.isNonConformityOnly ?? false;
    _mediaType = widget.mediaType;

    if (_topicId != null) {
      _loadItems(_topicId!);
    }

    if (_topicId != null && _itemId != null) {
      _loadDetails(_topicId!, _itemId!);
    }
  }

  Future<void> _loadItems(String topicId) async {
    setState(() => _isLoadingItems = true);

    try {
      final items = await _serviceFactory.coordinator.getItems(
        widget.inspectionId,
        topicId,
      );

      setState(() {
        _items = items;
        _isLoadingItems = false;
      });
    } catch (e) {
      debugPrint('Error loading items: $e');
      setState(() => _isLoadingItems = false);
    }
  }

  Future<void> _loadDetails(String topicId, String itemId) async {
    setState(() => _isLoadingDetails = true);

    try {
      final details = await _serviceFactory.coordinator.getDetails(
        widget.inspectionId,
        topicId,
        itemId,
      );

      setState(() {
        _details = details;
        _isLoadingDetails = false;
      });
    } catch (e) {
      debugPrint('Error loading details: $e');
      setState(() => _isLoadingDetails = false);
    }
  }

  void _applyFilters() {
    widget.onApplyFilters(
      topicId: _topicId,
      itemId: _topicOnly ? null : _itemId,
      detailId: _topicOnly ? null : _detailId,
      isNonConformityOnly: _isNonConformityOnly,
      mediaType: _mediaType,
    );

    Navigator.of(context).pop();
  }

  void _clearFilters() {
    setState(() {
      _topicId = null;
      _itemId = null;
      _detailId = null;
      _isNonConformityOnly = false;
      _mediaType = null;
      _topicOnly = false;
      _items = [];
      _details = [];
    });

    widget.onClearFilters();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtrar Mídia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Topic filter
          const Text('Tópico', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 5),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: DropdownButtonFormField<String>(
              value: _topicId,
              isExpanded: true,
              dropdownColor: Colors.grey[800],
              decoration: const InputDecoration(
                hintText: 'Selecione um tópico',
                hintStyle: TextStyle(color: Colors.white70),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                border: InputBorder.none,
              ),
              style: const TextStyle(color: Colors.white),
              items: widget.topics.map((topic) {
                return DropdownMenuItem<String>(
                  value: topic.id,
                  child: Text(topic.topicName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _topicId = value;
                  _itemId = null;
                  _detailId = null;
                  _items = [];
                  _details = [];
                  _topicOnly = false;
                });

                if (value != null) {
                  _loadItems(value);
                }
              },
            ),
          ),
          const SizedBox(height: 10),

          // Checkbox para "Apenas Tópico"
          if (_topicId != null)
            CheckboxListTile(
              title: const Text(
                'Apenas do Tópico',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Incluir mídias apenas do tópico selecionado',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              value: _topicOnly,
              onChanged: (value) {
                setState(() {
                  _topicOnly = value ?? false;
                  if (_topicOnly) {
                    _itemId = null;
                    _detailId = null;
                  }
                });
              },
              activeColor: Colors.blue,
            ),

          // Item filter
          if (!_topicOnly) ...[
            const Text('Item', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 5),
            _isLoadingItems
                ? const LinearProgressIndicator(backgroundColor: Colors.grey)
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _itemId,
                      isExpanded: true,
                      dropdownColor: Colors.grey[800],
                      decoration: const InputDecoration(
                        hintText: 'Selecione um item',
                        hintStyle: TextStyle(color: Colors.white70),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: _items.map((item) {
                        return DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(item.itemName),
                        );
                      }).toList(),
                      onChanged: _topicId == null
                          ? null
                          : (value) {
                              setState(() {
                                _itemId = value;
                                _detailId = null;
                                _details = [];
                              });

                              if (value != null && _topicId != null) {
                                _loadDetails(_topicId!, value);
                              }
                            },
                    ),
                  ),
            const SizedBox(height: 10),

            // Detail filter
            const Text('Detalhe', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 5),
            _isLoadingDetails
                ? const LinearProgressIndicator(backgroundColor: Colors.grey)
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _detailId,
                      isExpanded: true,
                      dropdownColor: Colors.grey[800],
                      decoration: const InputDecoration(
                        hintText: 'Selecione um detalhe',
                        hintStyle: TextStyle(color: Colors.white70),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: _details.map((detail) {
                        return DropdownMenuItem<String>(
                          value: detail.id,
                          child: Text(detail.detailName),
                        );
                      }).toList(),
                      onChanged: _itemId == null
                          ? null
                          : (value) {
                              setState(() {
                                _detailId = value;
                              });
                            },
                    ),
                  ),
            const SizedBox(height: 10),
          ],

          // Non-conformity filter
          SwitchListTile(
            title: const Text(
              'Apenas Não Conformidades',
              style: TextStyle(color: Colors.white),
            ),
            value: _isNonConformityOnly,
            onChanged: (value) {
              setState(() {
                _isNonConformityOnly = value;
              });
            },
            activeColor: Colors.orange,
          ),

          // Media type filter
          const Text('Tipo de Mídia', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 5),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                RadioListTile<String?>(
                  title: const Text('Todos',
                      style: TextStyle(color: Colors.white)),
                  value: null,
                  groupValue: _mediaType,
                  activeColor: Colors.blue,
                  onChanged: (value) {
                    setState(() {
                      _mediaType = value;
                    });
                  },
                ),
                Divider(height: 1, color: Colors.grey[700]),
                RadioListTile<String>(
                  title: const Text('Fotos',
                      style: TextStyle(color: Colors.white)),
                  value: 'image',
                  groupValue: _mediaType,
                  activeColor: Colors.blue,
                  onChanged: (value) {
                    setState(() {
                      _mediaType = value;
                    });
                  },
                ),
                Divider(height: 1, color: Colors.grey[700]),
                RadioListTile<String>(
                  title: const Text('Vídeos',
                      style: TextStyle(color: Colors.white)),
                  value: 'video',
                  groupValue: _mediaType,
                  activeColor: Colors.blue,
                  onChanged: (value) {
                    setState(() {
                      _mediaType = value;
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _clearFilters,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
                child: const Text('Limpar Filtros'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Aplicar Filtros'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
