// lib/presentation/widgets/template_selector_dialog.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/services/data_loader_service.dart';
import 'package:inspection_app/services/template_cache_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
  final TemplateCacheManager _cacheManager = TemplateCacheManager();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customNameController = TextEditingController();
  
  bool _isLoading = true;
  bool _isOffline = false;
  List<Map<String, dynamic>> _allTemplates = [];
  List<Map<String, dynamic>> _filteredTemplates = [];
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadTemplates();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult == ConnectivityResult.none;
    });
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
      
      // Tentar carregar do gerenciador de cache primeiro (mais rápido)
      if (_isOffline) {
        // No modo offline, sempre usar cache
        switch (widget.type) {
          case 'room':
            templates = await _cacheManager.getRoomTemplates();
            break;
          case 'item':
            if (widget.parentName != null) {
              templates = await _cacheManager.getItemTemplates(widget.parentName!);
            }
            break;
          case 'detail':
            if (widget.parentName != null) {
              templates = await _cacheManager.getDetailTemplates(widget.parentName!);
            }
            break;
        }
      } else {
        // Em modo online, tentar carregar do serviço de dados
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
        
        // Se não conseguiu buscar templates online, tenta usar o cache
        if (templates.isEmpty) {
          switch (widget.type) {
            case 'room':
              templates = await _cacheManager.getRoomTemplates();
              break;
            case 'item':
              if (widget.parentName != null) {
                templates = await _cacheManager.getItemTemplates(widget.parentName!);
              }
              break;
            case 'detail':
              if (widget.parentName != null) {
                templates = await _cacheManager.getDetailTemplates(widget.parentName!);
              }
              break;
          }
        }
      }
      
      setState(() {
        _allTemplates = templates;
        _filteredTemplates = List.from(templates);
        _isLoading = false;
      });
      
      // Se estiver online e não tiver templates no cache, atualizar o cache
      if (!_isOffline && templates.isEmpty) {
        _cacheManager.cacheBasicTemplates();
      }
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
            // Indicador de modo offline
            if (_isOffline)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Você está no modo offline. Usando templates do cache local.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            
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
                      trailing: template.containsKey('isFromLocal') && template['isFromLocal'] == true
                          ? const Icon(Icons.phone_android, size: 16, color: Colors.blue)
                          : null,
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