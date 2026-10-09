# Minecraft Server Engineering & Crossplay Architecture

Documentação de Engenharia de Infraestrutura e Arquitetura de Software para ecossistema Minecraft PaperMC Crossplay (Java & Bedrock).

## Estrutura da Documentação

```text
docs/
├── architecture/
│   ├── 01-overview-and-c4-model.md       # C1 (Contexto), C2 (Contêineres) e C3 (Componentes)
│   ├── 02-concurrency-and-threading.md   # Game Loop 20 TPS (50ms), Main vs Async e World API
│   ├── 03-crossplay-geyser-floodgate.md  # RakNet UDP/TCP, chaves assimétricas e XUID->UUID
│   ├── 04-persistence-and-cache.md       # HikariCP, Caffeine Cache (Lock-free) e PDC (NBT)
│   └── 05-jvm-tuning-and-ops.md          # Aikar Flags, G1GC, cálculo de RAM e Spark Profiler
├── adr/
│   ├── 0001-papermc-game-loop.md
│   ├── 0002-crossplay-geyser-floodgate.md
│   ├── 0003-persistence-hikaricp-caffeine.md
│   ├── 0004-jvm-tuning-aikar-flags.md
│   └── 0005-docs-as-code-c4-arc42.md
└── standards/
    └── code-and-comments-guide.md        # Convenções de Threading e PlayerDataManager.java
```
