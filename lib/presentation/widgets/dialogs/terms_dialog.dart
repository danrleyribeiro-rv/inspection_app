import 'package:flutter/material.dart';

class TermsDialog extends StatelessWidget {
  final bool isRegistration;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const TermsDialog({
    super.key,
    this.isRegistration = false,
    this.onAccept,
    this.onReject,
  });


  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF312456),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.gavel,
                  color: Color(0xFF6F4B99),
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Termos de Uso e Política de Privacidade',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (!isRegistration)
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
            const Divider(color: Color(0xFF6F4B99)),
            const SizedBox(height: 16),
            
            // Content
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A3B6B).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6F4B99).withValues(alpha: 0.3),
                  ),
                ),
                child: SingleChildScrollView(
                  child: _buildFormattedContent(),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Warning for registration
            if (isRegistration) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Para completar seu registro, você deve aceitar os Termos de Uso e Política de Privacidade.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Action buttons
            Row(
              children: [
                if (isRegistration) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                        onReject?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Não Aceito',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                        onAccept?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6F4B99),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Aceito os Termos',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6F4B99),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Fechar',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        _buildTitle('Termos de Uso e Política de Privacidade'),
        _buildSubtitle('Lince Inspeções'),
        
        const SizedBox(height: 16),
        _buildDivider(),
        const SizedBox(height: 16),
        
        // Version info
        _buildInfoBox([
          'Versão: 1.0',
          'Última atualização: 22 de julho de 2025',
          'Vigência: A partir de 22 de julho de 2025'
        ]),
        
        const SizedBox(height: 16),
        _buildDivider(),
        const SizedBox(height: 16),
        
        // Presentation
        _buildSubtitle('Apresentação'),
        const SizedBox(height: 8),
        _buildParagraph('Bem-vindo ao Lince Inspeções!'),
        
        const SizedBox(height: 12),
        _buildSubheading('Empresa Responsável'),
        _buildHighlightBox([
          'LINCE HUB LTDA',
          'CNPJ: 53.027.829/0001-44',
          'Endereço: Rodovia José Carlos Daux 4150, Saco Grande',
          'Florianópolis - SC, CEP: 88032-005'
        ]),
        
        const SizedBox(height: 12),
        _buildSubheading('Sobre Este Documento'),
        _buildParagraph('Este documento estabelece os Termos de Uso e a Política de Privacidade que governam o acesso e uso do aplicativo móvel Lince Inspeções e seus serviços relacionados.'),
        
        const SizedBox(height: 8),
        _buildParagraph('Ao baixar, instalar, acessar ou usar nosso aplicativo, você manifesta sua concordância livre, expressa e informada com todos os termos aqui estabelecidos.'),
        
        const SizedBox(height: 16),
        _buildWarningBox('AVISO IMPORTANTE', 'Se você não concordar com qualquer disposição destes Termos, não instale, acesse ou use o Aplicativo.'),
        
        const SizedBox(height: 16),
        _buildDivider(),
        
        // Part I - Terms of Use
        _buildTitle('PARTE I - TERMOS DE USO'),
        const SizedBox(height: 16),
        _buildDivider(),
        
        const SizedBox(height: 12),
        _buildSubheading('1.1 Aceitação dos Termos'),
        _buildParagraph('Ao criar uma conta, baixar, instalar ou usar nosso Aplicativo, você declara ter capacidade jurídica plena e confirma que leu, entendeu e concorda em ficar vinculado a estes Termos.'),
        
        const SizedBox(height: 8),
        _buildWarningBox('Menores de Idade', 'Caso você seja menor de 18 anos, é necessário o consentimento expresso de seus pais ou responsáveis legais.'),
        
        const SizedBox(height: 12),
        _buildSubheading('1.2 Descrição do Serviço'),
        _buildParagraph('O Lince Inspeções é um aplicativo móvel destinado à realização, documentação e gestão de inspeções técnicas.'),
        
        const SizedBox(height: 8),
        _buildSubheading('Principais Funcionalidades:'),
        _buildFunctionalitiesList(),
        
        const SizedBox(height: 12),
        _buildSubheading('1.3 Contas de Usuário'),
        _buildParagraph('Para acessar as funcionalidades do Aplicativo, você precisará criar uma conta.'),
        
        const SizedBox(height: 8),
        _buildSubheading('Seus Compromissos:'),
        _buildCommitmentsList(),
        
        const SizedBox(height: 16),
        _buildDivider(),
        
        // Part II - Privacy Policy
        _buildTitle('PARTE II - POLÍTICA DE PRIVACIDADE'),
        const SizedBox(height: 16),
        _buildDivider(),
        
        const SizedBox(height: 8),
        _buildWarningBox('Marco Legal', 'Esta Política de Privacidade está em conformidade com a Lei Geral de Proteção de Dados Pessoais (LGPD) - Lei nº 13.709/2018.'),
        
        const SizedBox(height: 12),
        _buildSubheading('2.1 Dados Coletados'),
        _buildParagraph('Coletamos apenas os dados necessários para o funcionamento adequado do aplicativo e prestação dos nossos serviços.'),
        
        const SizedBox(height: 8),
        _buildDataCollectionList(),
        
        const SizedBox(height: 12),
        _buildSubheading('2.2 Finalidades do Tratamento'),
        _buildPurposesList(),
        
        const SizedBox(height: 12),
        _buildSubheading('2.3 Seus Direitos'),
        _buildRightsList(),
        
        const SizedBox(height: 16),
        _buildDivider(),
        
        // Contact
        _buildTitle('CONTATO'),
        const SizedBox(height: 12),
        _buildHighlightBox([
          'Email: it@lincehub.com.br',
          'Responsável pela Proteção de Dados: Equipe Lince Hub',
          'Endereço: Rodovia José Carlos Daux 4150, Saco Grande',
          'Florianópolis - SC, CEP: 88032-005'
        ]),
        
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSubtitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF6F4B99),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSubheading(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        height: 1.5,
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: const Color(0xFF6F4B99).withValues(alpha: 0.3),
    );
  }

  Widget _buildInfoBox(List<String> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF6F4B99).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6F4B99).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            item,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildHighlightBox(List<String> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF4A3B6B).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6F4B99).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            item,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildWarningBox(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionalitiesList() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF4A3B6B).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildFunctionalityItem('Inspeções Estruturadas', 'Criação e execução de protocolos de inspeção personalizados'),
          _buildFunctionalityItem('Captura Multimídia', 'Armazenamento de evidências fotográficas e audiovisuais'),
          _buildFunctionalityItem('Gestão de Não Conformidades', 'Registro e acompanhamento de irregularidades identificadas'),
          _buildFunctionalityItem('Sincronização Multi-dispositivo', 'Acesso aos dados em diferentes dispositivos'),
          _buildFunctionalityItem('Relatórios Automáticos', 'Geração de documentos profissionais de inspeção'),
          _buildFunctionalityItem('Modo Offline', 'Funcionalidades completas mesmo sem conectividade'),
        ],
      ),
    );
  }

  Widget _buildCommitmentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommitmentSection('Informações do Cadastro', [
          'Informações Precisas: Fornecer informações verdadeiras, precisas, atualizadas e completas durante o processo de registro.',
          'Atualização: Manter suas informações de cadastro sempre atualizadas.'
        ]),
        const SizedBox(height: 8),
        _buildCommitmentSection('Segurança', [
          'Segurança da Conta: Manter a confidencialidade e segurança de suas credenciais de acesso (usuário e senha), sendo integralmente responsável por todas as atividades realizadas em sua conta.',
          'Uso Pessoal: Não compartilhar sua conta com terceiros ou permitir que outras pessoas acessem o Aplicativo usando suas credenciais.'
        ]),
        const SizedBox(height: 8),
        _buildCommitmentSection('Monitoramento', [
          'Notificação: Notificar-nos imediatamente sobre qualquer uso suspeito ou não autorizado de sua conta através do e-mail it@lincehub.com.br.'
        ]),
      ],
    );
  }

  Widget _buildCommitmentSection(String title, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF4A3B6B).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6F4B99).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF6F4B99),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '• $item',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildFunctionalityItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFF6F4B99),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCollectionList() {
    return _buildHighlightBox([
      '• Dados de Identificação: Nome, e-mail, telefone, documento (CPF/CNPJ)',
      '• Dados de Localização: Endereço fornecido no cadastro',
      '• Dados Profissionais: Profissão e área de atuação',
      '• Dados de Uso: Logs de acesso e utilização do aplicativo',
      '• Dados de Inspeção: Informações coletadas durante as inspeções',
      '• Dados Multimídia: Fotos e vídeos capturados durante as inspeções'
    ]);
  }

  Widget _buildPurposesList() {
    return _buildHighlightBox([
      '• Prestação dos serviços contratados',
      '• Criação e gerenciamento de conta de usuário',
      '• Comunicação com o usuário sobre atualizações e suporte',
      '• Melhoria contínua dos nossos serviços',
      '• Cumprimento de obrigações legais e regulamentares',
      '• Segurança e integridade da plataforma'
    ]);
  }

  Widget _buildRightsList() {
    return _buildHighlightBox([
      '• Confirmação da existência de tratamento',
      '• Acesso aos dados pessoais',
      '• Correção de dados incompletos, inexatos ou desatualizados',
      '• Anonimização, bloqueio ou eliminação de dados',
      '• Portabilidade dos dados',
      '• Eliminação dos dados pessoais tratados',
      '• Informação sobre compartilhamento de dados',
      '• Revogação do consentimento'
    ]);
  }

  static void show(BuildContext context, {
    bool isRegistration = false,
    VoidCallback? onAccept,
    VoidCallback? onReject,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isRegistration,
      builder: (context) => TermsDialog(
        isRegistration: isRegistration,
        onAccept: onAccept,
        onReject: onReject,
      ),
    );
  }
}