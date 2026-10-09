# 01. Visão Geral e C4 Model

## 1. Contexto do Sistema (C4 Nível 1)
O sistema provê uma infraestrutura de alta performance para Minecraft PaperMC com suporte a crossplay transparente entre edições Java e Bedrock.

```mermaid
flowchart TD
    subgraph Clients["Clientes"]
        JavaPlayer["Jogador Java (PC/macOS/Linux)"]
        BedrockPlayer["Jogador Bedrock (Mobile/Console/Win)"]
    end

    subgraph External["Serviços Externos de Autenticação"]
        MojangAuth["Mojang Auth / Session (HTTPS)"]
        XboxAuth["Xbox Live / Microsoft Auth (HTTPS)"]
    end

    subgraph SystemBoundary["PaperMC Server Ecosystem"]
        ServerCore["Servidor PaperMC (Game Loop 20 TPS)"]
    end

    JavaPlayer -->|TCP 25565| ServerCore
    BedrockPlayer -->|UDP/RakNet 19132| ServerCore
    ServerCore -->|Valida Token Java| MojangAuth
    ServerCore -->|Valida Token XUID Floodgate| XboxAuth

2. Visão de Contêineres (C4 Nível 2)

Detalhamento dos componentes de infraestrutura e serviços de suporte do servidor.
Snippet de código

flowchart TD
    subgraph Ingress["Entrada de Rede"]
        BedrockClient["Jogador Bedrock"] -->|UDP 19132| Geyser["GeyserMC (Tradutor de Protocolo)"]
        JavaClient["Jogador Java"] -->|TCP 25565| PaperCore["PaperMC Core (JVM Java 21)"]
    end

    subgraph InternalTranslation["Camada de Autenticação e Tradução"]
        Geyser -->|Handshake Assimétrico| Floodgate["Floodgate (Auth Shim / XUID->UUID)"]
        Geyser -->|TCP Loopback| PaperCore
        Floodgate -.->|Injeta UUID Determinístico| PaperCore
    end

    subgraph StorageLayer["Armazenamento & Cache"]
        PaperCore <-->|Leitura O(1) Lock-free| Caffeine["Caffeine Cache (L1 In-Memory)"]
        PaperCore -->|Async Worker Threads| Hikari["HikariCP Connection Pool"]
        Hikari <-->|JDBC TCP 5432| Postgres[(PostgreSQL)]
    end

3. Visão de Componentes (C4 Nível 3)

Arquitetura interna dos plugins de negócio acoplados ao ciclo de vida do PaperMC.
Snippet de código

flowchart TD
    subgraph Plugin["Custom Core Plugin"]
        Listeners["Event Listeners (Main Thread)"]
        Manager["PlayerDataManager (Business Logic)"]
        PDC["PersistentDataContainer (NBT Adapter)"]
        Cache["Caffeine L1 Cache"]
        AsyncPool["Async Worker Pool (CompletableFuture)"]
        DBService["DatabaseService (HikariCP / JDBC)"]
    end

    Database[(PostgreSQL)]

    Listeners -->|Gatilho de Evento| Manager
    Manager -->|Leitura / Escrita NBT| PDC
    Manager <-->|Hit / Miss O(1)| Cache
    Manager -->|Offload de I/O| AsyncPool
    AsyncPool -->|PreparedStatements| DBService
    DBService <-->|SQL Queries| Database
    AsyncPool -->|runTask Sync| Manager

