# 05. JVM Tuning e Operações de Infraestrutura

## 1. Script de Inicialização (Aikar Flags)
Configuração de referência para Java 21+ com Garbage-First Garbage Collector (G1GC).

```bash
#!/usr/bin/env bash
set -euo pipefail

JAVA_CMD="/usr/lib/jvm/java-21-openjdk/bin/java"
MEMORY="12G"

EXEC_FLAGS=(
  -Xms${MEMORY}
  -Xmx${MEMORY}
  -XX:+UseG1GC
  -XX:+ParallelRefProcEnabled
  -XX:MaxGCPauseMillis=200
  -XX:+UnlockExperimentalVMOptions
  -XX:+DisableExplicitGC
  -XX:+AlwaysPreTouch
  -XX:G1NewSizePercent=30
  -XX:G1MaxNewSizePercent=40
  -XX:G1ReservePercent=20
  -XX:G1HeapWastePercent=5
  -XX:G1MixedGCCountTarget=4
  -XX:InitiatingHeapOccupancyPercent=15
  -XX:G1MixedGCLiveThresholdPercent=90
  -XX:G1RSetUpdatingPauseTimePercent=5
  -XX:SurvivorRatio=32
  -XX:+PerfDisableSharedMem
  -XX:MaxTenuringThreshold=1
  -Dusing.aikars.flags=[https://mcflags.emc.gs](https://mcflags.emc.gs)
  -Daikars.new.flags=true
  -Xlog:gc*,gc+age=trace,safepoint=info:file=logs/gc-%t.log:time,uptime,pid:filecount=5,filesize=20M
  -jar paper.jar --nogui
)

exec "${JAVA_CMD}" "${EXEC_FLAGS[@]}"
```

## 2. Dimensionamento e Alocação de Memória
- **Regra de Ouro**: `-Xms == -Xmx` para eliminar re-alocação e desfragmentação de páginas pelo SO em tempo de execução.
- **AlwaysPreTouch**: Aloca e mapeia todas as páginas na subida do processo, evitando falhas de página (*page faults*) no gameplay.
- **Headroom Operacional do SO**:
  - Host com `16GB RAM`: Atribuir no máximo `12GB` à Heap (`-Xmx12G`).
  - Headroom reservado de `4GB`: Metaspace, memória nativa/off-heap (Netty buffers), threads C++ e Page Cache do Kernel Linux.

## 3. Diagnóstico e Profiling com Spark
O Spark Profiler é o mecanismo oficial para análise de desempenho no PaperMC.

### Comandos Essenciais
```bash
# Resumo de TPS e MSPT (Milliseconds Per Tick)
spark tps

# Monitoramento de CPU e contagem de threads ativas
spark health

# Amostragem ativa do profiler de CPU com upload de flamegraph
spark sampler --timeout 180 --upload

# Geração de heap dump para auditoria de memory leak
spark heapdump
```
