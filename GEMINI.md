# Análise do Projeto Inspection App (GEMINI.md)

Este documento detalha a estrutura, a função e a importância de cada arquivo e pasta principal dentro do diretório `lib/` do projeto, bem como o arquivo de configuração `pubspec.yaml`.

---

## 1. Arquivo de Configuração Principal

### `pubspec.yaml`

*   **Função**: É o arquivo manifesto do projeto Flutter. Ele define o nome, a descrição, a versão e, mais importante, todas as dependências (pacotes de terceiros) que o aplicativo utiliza. Também configura os assets (imagens, fontes, etc.) que serão incluídos no build final.
*   **Nível de Importância**: **CRÍTICO**. Sem este arquivo, o projeto não pode ser construído. Ele gerencia todas as ferramentas externas que dão poder ao aplicativo.
*   **Referências e Uso**:
    *   **Dependências Principais**:
        *   `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`: Essenciais para a integração com o backend Firebase (autenticação, banco de dados, armazenamento de arquivos).
        *   `hive`, `hive_flutter`, `hive_generator`: Fundamentais para a funcionalidade offline, atuando como o banco de dados local (cache) para inspeções, mídias e templates.
        *   `flutter_bloc`, `equatable`: Usados para gerenciamento de estado, embora a implementação atual pareça usar `StatefulWidget` com `setState`. Podem ser resquícios ou para futuras implementações.
        *   `camera`, `image_picker`, `ffmpeg_kit_flutter_new`, `video_thumbnail`: Pacotes essenciais para a captura, processamento e manipulação de mídias (fotos e vídeos).
        *   `connectivity_plus`: Verifica o status da conexão de rede (online/offline).
        *   `geolocator`, `geocoding`: Para obter a localização do dispositivo.
    *   **Assets**: Define a localização de imagens (`assets/images/`, `assets/icons/`), fontes (`assets/fonts/`) e o arquivo de configuração de ambiente (`.env`).
    *   **Build Runner**: `build_runner` e `json_serializable` são usados em desenvolvimento para gerar automaticamente o código de serialização (`.g.dart`) para os modelos de dados (ex: `OfflineMedia`, `CachedInspection`).

---

## 2. Ponto de Entrada e Configuração Global

### `lib/main.dart`

*   **Função**: É o ponto de entrada da aplicação. A função `main()` é a primeira a ser executada. Ela inicializa serviços essenciais em uma ordem específica:
    1.  Bindings do Flutter.
    2.  Firebase e variáveis de ambiente (`.env`).
    3.  Serviços de base como `CacheService` (Hive) e `FirebaseService`.
    4.  O `ServiceFactory`, que inicializa e disponibiliza todos os outros serviços da aplicação.
    5.  Configura a UI global e inicia o `MyApp`.
    A classe `MyApp` configura o `MaterialApp`, definindo o tema visual, a localização (pt-BR) e, crucialmente, as **rotas de navegação** que mapeiam caminhos (ex: `/login`) para as telas correspondentes.
*   **Nível de Importância**: **CRÍTICO**. É a raiz de toda a aplicação.
*   **Referências e Uso**:
    *   Importa e inicializa `ServiceFactory`, `CacheService`, e `FirebaseService`.
    *   Define todas as rotas de navegação, conectando URLs a widgets de tela (`SplashScreen`, `LoginScreen`, `HomeScreen`, etc.).
    *   Aplica um tema (`ThemeData`) global que estiliza a aparência de toda a aplicação.

### `lib/firebase_options.dart`

*   **Função**: Arquivo gerado automaticamente pela CLI do FlutterFire. Contém as configurações específicas da plataforma (Android, iOS, Web) para a conexão com o projeto Firebase.
*   **Nível de Importância**: **CRÍTICO**. Sem ele, a aplicação não saberia como se conectar ao projeto Firebase correto.
*   **Referências e Uso**: É usado em `lib/main.dart` durante a chamada `Firebase.initializeApp()` para configurar a conexão com o Firebase.

---

## 3. Estrutura de Dados (Models)

A pasta `lib/models/` contém as classes que definem a estrutura de dados da aplicação.

### `inspection.dart`, `topic.dart`, `item.dart`, `detail.dart`

*   **Função**: Representam a hierarquia de uma inspeção. `Inspection` é o objeto principal, que contém uma lista de `Topic`s. Cada `Topic` contém uma lista de `Item`s, e cada `Item` contém uma lista de `Detail`s. Eles são a espinha dorsal dos dados de negócio.
*   **Nível de Importância**: **CRÍTICO**. Toda a lógica de negócio e a UI de inspeção dependem desses modelos.
*   **Referências e Uso**: Usados extensivamente em toda a aplicação, especialmente nos `services` para manipulação de dados e nas `screens` de inspeção para exibição e entrada de dados.

### `cached_inspection.dart` e `cached_inspection.g.dart`

*   **Função**: Modelo de dados para o banco de dados local (Hive). `CachedInspection` encapsula os dados de uma inspeção (`data`) junto com metadados para o funcionamento offline, como `lastUpdated`, `needsSync` e `localStatus`. O arquivo `.g.dart` é gerado automaticamente para permitir que o Hive leia e escreva objetos `CachedInspection`.
*   **Nível de Importância**: **ALTO**. É a base da funcionalidade offline para os dados da inspeção.
*   **Referências e Uso**: Utilizado primariamente pelo `CacheService` para armazenar e recuperar inspeções do cache local.

### `offline_media.dart` e `offline_media.g.dart`

*   **Função**: Similar ao `CachedInspection`, mas específico para mídias. Define como uma foto ou vídeo é armazenado localmente, incluindo seu caminho no dispositivo (`localPath`), status de processamento e upload (`isProcessed`, `isUploaded`), e metadados associados. O arquivo `.g.dart` é o código gerado para serialização.
*   **Nível de Importância**: **ALTO**. Essencial para a funcionalidade de captura de mídia offline.
*   **Referências e Uso**: Gerenciado pelo `MediaService` e `CacheService` para salvar, processar e sincronizar mídias.

### `user.dart`

*   **Função**: Define a estrutura de dados para um usuário/inspetor, contendo informações como ID, email, e role.
*   **Nível de Importância**: **ALTO**. Usado para identificar o usuário logado e carregar seu perfil.
*   **Referências e Uso**: Utilizado pelo `AuthService` e pela `ProfileTab` para exibir informações do perfil.

---

## 4. Lógica de Negócio (Services)

A pasta `lib/services/` é o cérebro da aplicação, separando a lógica de negócio da UI.

### `service_factory.dart`

*   **Função**: Implementa o padrão Service Locator. Cria e gerencia uma única instância (singleton) de cada serviço, garantindo que toda a aplicação use a mesma instância. Isso centraliza a inicialização e o acesso aos serviços.
*   **Nível de Importância**: **CRÍTICO**. É o pilar da arquitetura de serviços do app.
*   **Referências e Uso**: Inicializado em `main.dart`. É chamado em toda a aplicação sempre que um serviço (`AuthService`, `MediaService`, etc.) é necessário.

### `inspection_coordinator.dart`

*   **Função**: Atua como um "maestro" ou "fachada" para as operações de inspeção. Em vez de as telas chamarem múltiplos serviços de dados (`TopicService`, `ItemService`, etc.) diretamente, elas chamam o `InspectionCoordinator`, que orquestra as chamadas para os serviços corretos. Isso simplifica a lógica na camada de UI.
*   **Nível de Importância**: **CRÍTICO**. Centraliza e simplifica a lógica de manipulação de dados de inspeção.
*   **Referências e Uso**: Usado principalmente pelas telas de inspeção (`InspectionDetailScreen`, `HierarchicalInspectionView`) para carregar, adicionar, atualizar e deletar tópicos, itens e detalhes.

### `lib/services/core/`

*   **`auth_service.dart`**: Gerencia toda a lógica de autenticação: login, registro, logout, reset de senha. Valida se o usuário tem a permissão de "inspetor". **Importância: CRÍTICA**.
*   **`firebase_service.dart`**: Um wrapper que fornece acesso centralizado às instâncias do Firebase (Auth, Firestore, Storage) e configura o cache offline do Firestore. **Importância: CRÍTICA**.

### `lib/services/data/`

*   **`inspection_service.dart`, `topic_service.dart`, `item_service.dart`, `detail_service.dart`**: Formam a camada de acesso a dados para a hierarquia da inspeção. Eles interagem com o `CacheService` para manipular os dados de forma offline-first. **Importância: ALTA**.
*   **`non_conformity_service.dart`**: Gerencia a lógica de criação e leitura de não conformidades. **Importância: ALTA**.

### `lib/services/features/`

*   **`media_service.dart`**: Um dos serviços mais complexos. Gerencia todo o ciclo de vida da mídia: captura, processamento em background (usando Isolates e FFmpeg), armazenamento local no Hive (`OfflineMedia`), e upload para a nuvem. **Importância: CRÍTICA**.
*   **`template_service.dart`**: Responsável por buscar templates de inspeção do Firestore, armazená-los em cache e aplicá-los a uma inspeção. **Importância: ALTA**.

### `lib/services/utils/`

*   **`cache_service.dart`**: O coração da estratégia offline. Gerencia as "caixas" do Hive para armazenar inspeções, mídias e templates localmente. **Importância: CRÍTICA**.
*   **`download_service.dart`**: Orquestra o download de uma inspeção completa (dados + template + mídias) do Firestore para o cache local, preparando-a para uso offline. **Importância: ALTA**.
*   **`manual_sync_service.dart`**: Gerencia o processo de envio de dados modificados localmente de volta para a nuvem (Firestore). **Importância: ALTA**.
*   **`sync_service.dart`**: Serviço que monitora a conectividade e tenta sincronizar automaticamente os dados pendentes. **Importância: MÉDIA** (a sincronização manual é a principal).
*   **Outros**: `settings_service.dart` (gerencia configurações), `import_export_service.dart` (importa/exporta dados), `map_cache_service.dart` (cache de imagens de mapa), `progress_calculation_service.dart` (calcula progresso), `notification_service.dart` (placeholder). **Importância: MÉDIA**.

---

## 5. Interface do Usuário (Presentation)

A pasta `lib/presentation/` contém todas as telas e widgets que o usuário vê e interage.

### `lib/presentation/screens/`

*   **`auth/`**: Telas de `login`, `register`, `forgot_password`, `reset_password`. Essenciais para o fluxo de autenticação. **Importância: CRÍTICA**.
*   **`home/`**: Contém a `home_screen.dart` (a tela principal com a barra de navegação inferior) e as duas abas principais: `inspection_tab.dart` (lista de inspeções) e `profile_tab.dart` (perfil do usuário). **Importância: CRÍTICA**.
*   **`inspection/`**: Onde a mágica acontece.
    *   `inspection_detail_screen.dart`: A tela principal de uma inspeção, que gerencia o estado e a lógica para exibir a hierarquia.
    *   `hierarchical_inspection_view.dart`: O widget que constrói a visualização navegável de Tópicos -> Itens -> Detalhes.
    *   `non_conformity_screen.dart`: Tela para gerenciar não conformidades.
    *   Outros arquivos em `components/` são os blocos de construção dessas telas. **Importância: CRÍTICA**.
*   **`media/`**: Telas para a galeria de mídia (`media_gallery_screen.dart`) e visualizadores (`media_viewer_screen.dart`). **Importância: ALTA**.
*   **Outras Telas**: `splash_screen.dart` (tela de carregamento inicial), `get_started_screen.dart` (tela de boas-vindas), `settings_screen.dart` (configurações). **Importância: MÉDIA a ALTA**.

### `lib/presentation/widgets/`

*   Contém widgets reutilizáveis.
    *   **`common/`**: Widgets genéricos como `inspection_card.dart` e `cached_map_image.dart`.
    *   **`dialogs/`**: Diálogos para renomear, selecionar templates, mover mídias, etc.
    *   **`media/`**: Widgets específicos para manipulação de mídia, como `media_handling_widget.dart` e `native_camera_widget.dart`.
    *   **`profile/`**: Widgets para a tela de perfil, como o `qr_code_credentials_dialog.dart`.
    *   **`sync/`**: Widgets para exibir o progresso da sincronização.
*   **Nível de Importância**: **MÉDIO a ALTO**. A reutilização desses componentes é fundamental para a manutenibilidade do código.

---

## 6. Fluxo de Interação e Navegação de Telas

Esta seção detalha como as telas e widgets se conectam para formar a experiência do usuário.

1.  **Fluxo Inicial e Autenticação**:
    *   O app inicia com a `SplashScreen`, que exibe uma animação de carregamento.
    *   Após um breve período, a `SplashScreen` verifica o estado de autenticação via `AuthService`.
    *   **Se o usuário não está logado**: Navega para a `GetStartedScreen`, que oferece as opções de "Login" e "Cadastro".
        *   Clicar em "Login" leva para a `LoginScreen` (`/login`).
        *   Clicar em "Cadastro" leva para a `RegisterScreen` (`/register`).
    *   **Se o usuário já está logado**: Navega diretamente para a `HomeScreen` (`/home`).
    *   A `LoginScreen` e a `RegisterScreen` usam o `AuthService` para se comunicar com o Firebase. Em caso de sucesso, o usuário é redirecionado para a `HomeScreen`. A `LoginScreen` também possui um link para a `ForgotPasswordScreen` (`/forgot-password`).

2.  **Tela Principal (Home)**:
    *   A `HomeScreen` é a tela central após o login. Ela usa um `BottomNavigationBar` para alternar entre duas abas principais: `InspectionsTab` e `ProfileTab`.
    *   **`InspectionsTab`**: Exibe uma lista de vistorias atribuídas ao inspetor. Cada vistoria é representada por um `InspectionCard`.
        *   O `InspectionCard` mostra informações resumidas (título, status, data) e um mapa estático (via `MapLocationCard` e `CachedMapImage`).
        *   Clicar em um `InspectionCard` navega para a `InspectionDetailScreen`, passando o `inspectionId`.
        *   Ações como "Baixar" (`onDownload`) e "Sincronizar" (`onSync`) são gerenciadas aqui, chamando os respectivos serviços (`DownloadService`, `ManualSyncService`).
    *   **`ProfileTab`**: Exibe as informações do inspetor logado. Permite navegar para a `EditProfileScreen` e `SettingsScreen`.

3.  **Detalhes da Inspeção**:
    *   A `InspectionDetailScreen` é a tela mais complexa. Ela carrega todos os dados de uma inspeção (tópicos, itens, detalhes) usando o `InspectionCoordinator`.
    *   A navegação pela hierarquia da inspeção é feita pelo widget `HierarchicalInspectionView`, que usa `PageView`s para permitir o deslize entre tópicos e itens.
    *   **`SwipeableLevelHeader`**: Widget crucial e reutilizável que exibe o cabeçalho de cada nível (Tópico e Item). Ele mostra o progresso, permite a navegação por dropdown e expansão para ver detalhes.
    *   Quando um nível é expandido (ex: Tópico), a seção de detalhes correspondente é exibida (`TopicDetailsSection`, `ItemDetailsSection`).
    *   **`DetailsListSection`**: Exibe a lista de detalhes de um item. Cada `DetailListItem` pode ser expandido para edição.
        *   Dentro de um `DetailListItem` expandido, o usuário pode inserir valores, observações e, mais importante, interagir com o `MediaHandlingWidget`.
    *   **`MediaHandlingWidget`**: Fornece os botões "Câmera" e "Galeria".
        *   "Câmera" abre a `NativeCameraWidget` para captura de mídia.
        *   "Galeria" abre a `MediaGalleryScreen` filtrada para o contexto atual (tópico, item ou detalhe).

4.  **Fluxo de Mídia**:
    *   A `MediaGalleryScreen` exibe todas as mídias de uma inspeção em uma grade (`MediaGrid`).
    *   Ela possui um painel de filtros (`MediaFilterPanel`) que permite ao usuário refinar a busca por tópico, item, detalhe, tipo de mídia ou status de não conformidade.
    *   Clicar em uma mídia na grade abre a `MediaViewerScreen` para visualização em tela cheia.
    *   A `MediaDetailsBottomSheet` é um pop-up que mostra os detalhes de uma mídia específica e permite sua edição ou exclusão.

5.  **Não Conformidades (NCs)**:
    *   A partir de um `DetailListItem`, o usuário pode navegar para a `NonConformityScreen`.
    *   Esta tela tem duas abas: um formulário (`NonConformityForm`) para criar novas NCs e uma lista (`NonConformityList`) para ver as existentes.
    *   A `NonConformityList` usa o `NonConformityMediaWidget` para permitir a adição de mídias específicas para a não conformidade.

---

## 7. Arquitetura e Lógica Offline-First

O design do aplicativo é centrado na capacidade de funcionar de forma robusta sem conexão com a internet. A seguir, detalhamos os componentes e o fluxo que tornam isso possível.

### Componentes Chave

1.  **`CacheService` (`lib/services/utils/cache_service.dart`)**: **O Coração do Sistema Offline**.
    *   **Tecnologia**: Utiliza o banco de dados NoSQL **Hive**, que é extremamente rápido e armazenado localmente no dispositivo.
    *   **Função**: Armazena três tipos principais de dados em "caixas" (Boxes) separadas:
        *   **Inspeções (`inspectionsBox`)**: Guarda os dados completos de cada inspeção que foi baixada pelo usuário. Usa o modelo `CachedInspection` para adicionar metadados de controle (`needsSync`, `localStatus`, `lastUpdated`).
        *   **Mídias Offline (`offlineMediaBox`)**: Armazena metadados de cada foto ou vídeo capturado offline. Usa o modelo `OfflineMedia` para rastrear o caminho do arquivo local, status de processamento e upload.
        *   **Templates (`templatesBox`)**: Guarda a estrutura de templates de inspeção para que possam ser aplicados mesmo sem conexão.

2.  **`DownloadService` (`lib/services/download_service.dart`)**: **A Porta de Entrada para o Mundo Offline**.
    *   **Função**: Responsável por baixar uma inspeção completa da nuvem (Firestore) e prepará-la para uso offline.
    *   **Fluxo**: 
        1.  Busca os dados da inspeção no Firestore.
        2.  Chama o `CacheService` para salvar esses dados na caixa de inspeções com o status `'downloaded'`.
        3.  Se a inspeção usa um template, ele também é baixado e salvo no cache de templates.
        4.  (Futuramente) Baixará todas as mídias já associadas à inspeção na nuvem.

3.  **`ManualSyncService` (`lib/services/manual_sync_service.dart`)**: **A Ponte de Volta para a Nuvem**.
    *   **Função**: Envia as alterações feitas localmente de volta para o Firestore. Este processo é **manual**, iniciado pelo usuário.
    *   **Fluxo**:
        1.  Identifica as inspeções marcadas como `needsSync = true` no `CacheService`.
        2.  Para cada inspeção, envia os dados do `CachedInspection.data` para o documento correspondente no Firestore.
        3.  Chama o `MediaService` para fazer o upload das mídias pendentes associadas àquela inspeção.
        4.  Após o sucesso, reseta a flag `needsSync` para `false` no `CachedInspection`.

4.  **`MediaService` (`lib/services/features/media_service.dart`)**: **Gerenciamento Robusto de Mídia**.
    *   **Função**: Lida com todo o ciclo de vida da mídia de forma offline.
    *   **Fluxo de Captura**:
        1.  Quando o usuário tira uma foto/vídeo, o `MediaService` é chamado.
        2.  Ele imediatamente cria um registro `OfflineMedia` no Hive, apontando para o arquivo bruto capturado.
        3.  Inicia um processo em **background (Isolate)** para processar a mídia (ex: cortar imagem para 4:3) sem travar a UI.
        4.  Após o processamento, o `OfflineMedia` é atualizado com o caminho do novo arquivo processado e marcado como `isProcessed = true`.
    *   **Fluxo de Upload (acionado pelo `ManualSyncService`)**:
        1.  Busca mídias que estão `isProcessed = true` e `isUploaded = false`.
        2.  Faz o upload do arquivo local para o Firebase Storage.
        3.  Após o sucesso, atualiza o registro `OfflineMedia` com a URL do arquivo na nuvem e marca `isUploaded = true`.

### Fluxo de Uso Offline na Prática

1.  **Preparação (Online)**: Na `InspectionsTab`, o usuário vê a lista de suas inspeções. As que não estão disponíveis offline têm um botão **"Baixar"**. Ao clicar, o `DownloadService` entra em ação, salvando a inspeção e seus dados no Hive.

2.  **Execução (Offline)**: O usuário abre a `InspectionDetailScreen` de uma inspeção baixada.
    *   A tela **não tenta buscar dados do Firestore**. Em vez disso, o `InspectionCoordinator` busca os dados diretamente do `CacheService`.
    *   Qualquer alteração (preencher um detalhe, adicionar uma observação) é salva diretamente no objeto `CachedInspection` no Hive através do `CacheService`.
    *   Simultaneamente, a flag `needsSync` da `CachedInspection` é setada para `true`, indicando que há alterações locais pendentes.

3.  **Captura de Mídia (Offline)**: O usuário tira uma foto.
    *   O `MediaService` salva a foto no dispositivo e cria um registro `OfflineMedia` no Hive, associado ao `inspectionId`.
    *   A UI pode exibir a imagem imediatamente usando o caminho do arquivo local (`localPath`).

4.  **Sincronização (Online)**: De volta à `InspectionsTab`, o usuário vê um indicador de que a inspeção tem alterações locais (ex: um ícone de "sincronização pendente").
    *   Ao clicar no botão **"Sincronizar"**, o `ManualSyncService` é acionado.
    *   O serviço envia os dados da inspeção do Hive para o Firestore.
    *   Em seguida, ele busca todas as `OfflineMedia` pendentes para essa inspeção e faz o upload de cada uma para o Firebase Storage, atualizando os documentos no Firestore com as novas URLs das mídias.
    *   Finalmente, a inspeção no Hive é marcada como sincronizada (`needsSync = false`).

Esta arquitetura garante que o usuário possa realizar 100% do trabalho de inspeção em campo, sem depender de uma conexão com a internet, e sincronizar tudo de uma vez quando estiver em uma rede estável.

---

## 8. Análise de Problemas na Arquitetura Offline-First

Apesar da intenção de ser um aplicativo "offline-first", a implementação atual possui algumas falhas arquitetônicas que impedem o funcionamento 100% offline durante a edição de uma vistoria. Quando o dispositivo está online, certas operações locais ainda tentam se comunicar com a rede, o que pode causar lentidão e inconsistências, além de não seguir o paradigma estrito de "local primeiro, sincronização depois".

Os problemas principais são:

### Problema 1: Estratégia de Leitura de Dados Incorreta no `CacheService`

*   **Onde**: `lib/services/utils/cache_service.dart` (no método `getInspection`)
*   **Descrição**: O método `getInspection` no `CacheService`, que deveria ser a fonte de verdade para dados locais, possui uma lógica que tenta buscar dados do Firestore sempre que o aplicativo está online. Ele só retorna os dados do cache imediatamente se o dispositivo estiver comprovadamente offline.
*   **Impacto**: Isso quebra o princípio do "offline-first". Qualquer parte do aplicativo que precise ler os dados de uma inspeção (mesmo para uma pequena atualização de UI) irá, inadvertidamente, iniciar uma requisição de rede se houver conexão. Isso torna a edição dependente da rede, mesmo que os dados já estejam disponíveis localmente.
*   **Solução Ideal**: O `CacheService` deve **sempre** ler do cache (Hive) primeiro. A responsabilidade de buscar novos dados da nuvem (sincronizar) deve ser uma ação explícita e separada, controlada pelo usuário (ex: botão "Atualizar") ou por um serviço de sincronização em background, e não embutida na camada de acesso a dados.

### Problema 2: Recarregamento Ineficiente de Dados na Edição

*   **Onde**: `lib/services/data/detail_service.dart`, `item_service.dart`, `topic_service.dart`.
*   **Descrição**: Ao atualizar um campo de um `Detail` (por exemplo, ao digitar em um campo de texto), a lógica de salvamento (`updateDetail`) recarrega o objeto `Inspection` inteiro a partir do `CacheService`. O mesmo padrão se repete para Itens e Tópicos.
*   **Impacto**: Esta abordagem é altamente ineficiente. Como o `CacheService.getInspection` tenta se conectar à internet (Problema 1), uma ação simples como digitar uma letra pode, na prática, disparar múltiplas leituras da rede. Isso causa lentidão e uma experiência de usuário ruim.
*   **Solução Ideal**: A tela `InspectionDetailScreen` deveria carregar o objeto da inspeção **uma vez** e mantê-lo em seu estado. As atualizações seriam feitas nesse objeto em memória e, após cada mudança, o objeto completo e atualizado seria salvo no `CacheService`. Isso evitaria leituras repetidas e desnecessárias da fonte de dados.

### Problema 3: Recarregamento Total da UI Após Ações Locais

*   **Onde**: `lib/presentation/screens/inspection/inspection_detail_screen.dart` (no método `_addTopic` e outros similares).
*   **Descrição**: Após adicionar um novo tópico, item ou detalhe (ações que são realizadas localmente no cache), a tela chama o método `_loadAllData()`. Este método reinicia todo o processo de leitura de dados a partir do `InspectionCoordinator`.
*   **Impacto**: Assim como no Problema 2, isso desencadeia o Problema 1, resultando em uma tentativa de acesso à rede para uma operação que deveria ser puramente local. A UI deveria ser atualizada de forma "otimista", simplesmente adicionando o novo elemento à lista local em seu estado, em vez de recarregar tudo.

Em resumo, a arquitetura atual mistura as responsabilidades de **leitura de dados locais** com a de **sincronização com a nuvem**. Para que o aplicativo funcione 100% offline na edição, essas responsabilidades precisam ser completamente separadas. A camada de dados deve interagir apenas com o cache local, e um serviço de sincronização distinto (como o `ManualSyncService`) deve ser o único responsável por mediar a comunicação entre o cache e a nuvem, sob o comando explícito do usuário.

---

## 9. Utilitários e Exemplos

### `lib/utils/`

*   **`constants.dart`**: Armazena valores constantes, como a lista de profissões. Ajuda a evitar "magic strings" no código. **Importância: MÉDIA**.
*   **`media_debug.dart`**: Ferramenta de depuração. **Importância: BAIXA** (apenas para desenvolvimento).

### `lib/examples/`

*   **`offline_media_usage_example.dart`**: Arquivo de exemplo que demonstra como usar o `MediaService`. Não é usado na aplicação final. **Importância: BAIXA** (apenas para referência).