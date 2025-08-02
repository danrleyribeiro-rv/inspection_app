// Widget de teste para verificar se o loading do botão de sincronização está funcionando
// Execute este widget para testar o botão isoladamente

import 'package:flutter/material.dart';
import 'package:lince_inspecoes/presentation/widgets/common/inspection_card.dart';

class TestSyncButton extends StatefulWidget {
  const TestSyncButton({super.key});

  @override
  State<TestSyncButton> createState() => _TestSyncButtonState();
}

class _TestSyncButtonState extends State<TestSyncButton> {
  bool _isSyncing = false;
  bool _isVerified = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teste do Botão de Sincronização'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Controles para testar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Controles de Teste', 
                         style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    
                    SwitchListTile(
                      title: const Text('isSyncing'),
                      subtitle: Text(_isSyncing ? 'Sincronizando...' : 'Não sincronizando'),
                      value: _isSyncing,
                      onChanged: (value) {
                        setState(() {
                          _isSyncing = value;
                          if (value) {
                            _isVerified = false; // Reset verified when syncing starts
                          }
                        });
                      },
                    ),
                    
                    SwitchListTile(
                      title: const Text('isVerified'),
                      subtitle: Text(_isVerified ? 'Verificado' : 'Não verificado'),
                      value: _isVerified,
                      onChanged: (value) {
                        setState(() {
                          _isVerified = value;
                          if (value) {
                            _isSyncing = false; // Stop syncing when verified
                          }
                        });
                      },
                    ),
                    
                    ElevatedButton(
                      onPressed: () {
                        // Simular sincronização completa
                        setState(() {
                          _isSyncing = true;
                        });
                        
                        // Simular delay da sincronização
                        Future.delayed(const Duration(seconds: 3), () {
                          if (mounted) {
                            setState(() {
                              _isSyncing = false;
                              _isVerified = true;
                            });
                          }
                        });
                      },
                      child: const Text('Simular Sincronização'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // InspectionCard de teste
            InspectionCard(
              inspection: {
                'id': 'test_inspection',
                'title': 'Inspeção de Teste',
                'cod': 'TEST-001',
                'scheduled_date': DateTime.now().toIso8601String(),
              },
              onViewDetails: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ver detalhes')),
                );
              },
              onSync: () async {
                print('🔄 Botão de sincronização clicado!');
                
                // Simular início da sincronização
                setState(() {
                  _isSyncing = true;
                  _isVerified = false;
                });
                
                // Simular delay da sincronização
                await Future.delayed(const Duration(seconds: 3));
                
                // Simular conclusão
                if (mounted) {
                  setState(() {
                    _isSyncing = false;
                    _isVerified = true;
                  });
                }
              },
              googleMapsApiKey: 'test_key',
              isFullyDownloaded: true,
              needsSync: !_isVerified,
              hasConflicts: false,
              
              // ESTES SÃO OS PARÂMETROS CRÍTICOS
              isSyncing: _isSyncing,  // ← Este valor controla o loading!
              isVerified: _isVerified,
              
              pendingImagesCount: _isSyncing ? null : 2,
            ),
            
            const SizedBox(height: 20),
            
            // Status atual
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status Atual:', 
                         style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('isSyncing: $_isSyncing'),
                    Text('isVerified: $_isVerified'),
                    const SizedBox(height: 8),
                    Text(
                      _isSyncing 
                          ? '🔄 O botão deve mostrar loading...' 
                          : _isVerified 
                              ? '✅ O botão deve mostrar "Verificado"' 
                              : '📤 O botão deve mostrar "Sincronizar"',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}