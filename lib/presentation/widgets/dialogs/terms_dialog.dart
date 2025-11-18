import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsDialog extends StatelessWidget {
  final bool isRegistration;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  // Theme colors (will be set in build method)
  static bool _isDarkMode = true;
  static Color _textColor = Colors.white;
  static Color _primaryColor = const Color(0xFF6F4B99);

  const TermsDialog({
    super.key,
    this.isRegistration = false,
    this.onAccept,
    this.onReject,
  });


  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? const Color(0xFF312456)
        : Theme.of(context).dialogTheme.backgroundColor ?? Colors.white;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final dividerColor = isDarkMode
        ? const Color(0xFF6F4B99)
        : primaryColor.withAlpha((255 * 0.3).round());

    return Dialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.92,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.gavel,
                  color: primaryColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Termos de Uso e Política de Privacidade',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      height: 1.2,
                    ),
                  ),
                ),
                if (!isRegistration)
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: textColor,
                      size: 24,
                    ),
                    tooltip: 'Fechar',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: dividerColor, thickness: 1.5),
            const SizedBox(height: 16),

            // Link to online policies
            _buildOnlinePolicyLink(context, isDarkMode, primaryColor),

            const SizedBox(height: 16),

            // Content
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF4A3B6B).withValues(alpha: 0.3)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode
                        ? const Color(0xFF6F4B99).withValues(alpha: 0.3)
                        : Colors.grey[300]!,
                    width: 1.5,
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _buildFormattedContent(isDarkMode, textColor, primaryColor),
                ),
              ),
            ),

            const SizedBox(height: 20),
            
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

  Widget _buildOnlinePolicyLink(
      BuildContext context, bool isDarkMode, Color primaryColor) {
    return InkWell(
      onTap: () async {
        final url = Uri.parse('https://policies.lincehub.com.br');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Não foi possível abrir o link'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDarkMode
              ? primaryColor.withValues(alpha: 0.15)
              : primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: primaryColor.withValues(alpha: isDarkMode ? 0.4 : 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.language,
              color: primaryColor,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  Text(
                    'Ver online em',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'policies.lincehub.com.br',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      decorationColor: primaryColor,
                    ),
                  ),
                  Icon(
                    Icons.open_in_new,
                    color: primaryColor,
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedContent(
      bool isDarkMode, Color textColor, Color primaryColor) {
    // Store colors in local variables for nested widgets
    _isDarkMode = isDarkMode;
    _textColor = textColor;
    _primaryColor = primaryColor;

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
      style: TextStyle(
        color: _textColor,
        fontSize: 17,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildSubtitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _primaryColor,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildSubheading(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _textColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _textColor.withAlpha((255 * 0.9).round()),
        fontSize: 13,
        height: 1.6,
        letterSpacing: 0.1,
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1.5,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryColor.withAlpha(0),
            _primaryColor.withAlpha((255 * 0.4).round()),
            _primaryColor.withAlpha(0),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(List<String> items) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? _primaryColor.withValues(alpha: 0.15)
            : _primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _primaryColor.withValues(alpha: _isDarkMode ? 0.4 : 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    item,
                    style: TextStyle(
                      color: _textColor.withAlpha((255 * 0.95).round()),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildHighlightBox(List<String> items) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? const Color(0xFF4A3B6B).withValues(alpha: 0.4)
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _primaryColor.withValues(alpha: _isDarkMode ? 0.3 : 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    item,
                    style: TextStyle(
                      color: _textColor.withAlpha((255 * 0.95).round()),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildWarningBox(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: _isDarkMode ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.orange.withValues(alpha: _isDarkMode ? 0.5 : 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: _textColor.withAlpha((255 * 0.9).round()),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionalitiesList() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? const Color(0xFF4A3B6B).withValues(alpha: 0.3)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _primaryColor.withAlpha((255 * 0.2).round()),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          _buildFunctionalityItem('Inspeções Estruturadas',
              'Criação e execução de protocolos de inspeção personalizados'),
          _buildFunctionalityItem('Captura Multimídia',
              'Armazenamento de evidências fotográficas e audiovisuais'),
          _buildFunctionalityItem('Gestão de Não Conformidades',
              'Registro e acompanhamento de irregularidades identificadas'),
          _buildFunctionalityItem('Sincronização Multi-dispositivo',
              'Acesso aos dados em diferentes dispositivos'),
          _buildFunctionalityItem('Relatórios Automáticos',
              'Geração de documentos profissionais de inspeção'),
          _buildFunctionalityItem('Modo Offline',
              'Funcionalidades completas mesmo sem conectividade'),
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
        const SizedBox(height: 10),
        _buildCommitmentSection('Segurança', [
          'Segurança da Conta: Manter a confidencialidade e segurança de suas credenciais de acesso (usuário e senha), sendo integralmente responsável por todas as atividades realizadas em sua conta.',
          'Uso Pessoal: Não compartilhar sua conta com terceiros ou permitir que outras pessoas acessem o Aplicativo usando suas credenciais.'
        ]),
        const SizedBox(height: 10),
        _buildCommitmentSection('Monitoramento', [
          'Notificação: Notificar-nos imediatamente sobre qualquer uso suspeito ou não autorizado de sua conta através do e-mail it@lincehub.com.br.'
        ]),
      ],
    );
  }

  Widget _buildCommitmentSection(String title, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? const Color(0xFF4A3B6B).withValues(alpha: 0.2)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _primaryColor.withAlpha((255 * 0.2).round()),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '• $item',
                  style: TextStyle(
                    color: _textColor.withAlpha((255 * 0.9).round()),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFunctionalityItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: _textColor.withAlpha((255 * 0.75).round()),
                    fontSize: 12,
                    height: 1.4,
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