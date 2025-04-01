// lib/presentation/widgets/template_selector_dialog.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/services/data_loader_service.dart';

class TemplateSelectorDialog extends StatefulWidget {
  final String title;
  final String type; // 'room', 'item', ou 'detail'
  final String? parentName; // Para itens precisa do roomName, para detalhes precisa do itemName

  const TemplateSelectorDialog({
    Key? key,
    required this.title,
    required this.type,
    this.parentName,
  }) : super(key: key);

  @override
  State<TemplateSelectorDialog> createState() => _TemplateSelectorDialogState();
}

class _TemplateSelectorDialogState extends State<TemplateSelectorDialog> {
  final DataLoaderService _dataLoader = DataLoaderService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customNameController = TextEditingController();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _allTemplates = [];
  List<Map<String, dynamic>> _filteredTemplates = [];
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    
    try {
      List<Map<String, dynamic>> templates = [];
      
      // Carregar templates apropriados baseado no tipo
      switch (widget.type) {
        case 'room':
          templates = await _dataLoader.loadRoomTemplates();
          break;
        case 'item':
          if (widget.parentName != null) {
            templates = await _dataLoader.loadItemTemplates(widget.parentName!);
          }
          break;
        case 'detail':
          if (widget.parentName != null) {
            templates = await _dataLoader.loadDetailTemplates(widget.parentName!);
          }
          break;
      }
      
      setState(() {
        _allTemplates = templates;
        _filteredTemplates = List.from(templates);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar templates: $e')),
        );
      }
    }
  }

  void _filterTemplates(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredTemplates = List.from(_allTemplates);
      });
      return;
    }
    
    setState(() {
      _filteredTemplates = _allTemplates
          .where((template) => 
            template['name'].toString().toLowerCase().contains(query.toLowerCase()) ||
            (template['label'] != null && 
             template['label'].toString().toLowerCase().contains(query.toLowerCase())) ||
            (template['description'] != null && 
             template['description'].toString().toLowerCase().contains(query.toLowerCase()))
          )
          .toList();
    });
  }

  void _toggleCustomInput() {
    setState(() {
      _showCustomInput = !_showCustomInput;
      if (_showCustomInput) {
        _customNameController.clear();
      }
    });
  }
  
  String _getElementName() {
    switch (widget.type) {
      case 'room':
        return 'ambiente';
      case 'item':
        return 'item';
      case 'detail':
        return 'detalhe';
      default:
        return 'elemento';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra de pesquisa
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterTemplates,
            ),
            const SizedBox(height: 8),
            
            // Botão para alternar entre existente e novo
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _toggleCustomInput,
                  icon: Icon(_showCustomInput ? Icons.list : Icons.add),
                  label: Text(_showCustomInput ? 'Usar existente' : 'Criar novo'),
                ),
              ],
            ),
            
            // Input customizado ou lista de templates
            if (_showCustomInput) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _customNameController,
                decoration: InputDecoration(
                  labelText: 'Nome do novo ${_getElementName()}',
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  final name = _customNameController.text.trim();
                  if (name.isNotEmpty) {
                    Navigator.of(context).pop({
                      'name': name,
                      'isCustom': true,
                    });
                  }
                },
                child: Text('Criar ${_getElementName()}'),
              ),
            ] else if (_isLoading) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Carregando templates...'),
            ] else if (_filteredTemplates.isEmpty) ...[
              const SizedBox(height: 16),
              Text('Nenhum ${_getElementName()} encontrado. Tente criar um novo.'),
            ] else ...[
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredTemplates.length,
                  itemBuilder: (context, index) {
                    final template = _filteredTemplates[index];
                    return ListTile(
                      title: Text(template['name']),
                      subtitle: template['label'] != null ? Text(template['label']) : null,
                      onTap: () {
                        Navigator.of(context).pop(template);
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}