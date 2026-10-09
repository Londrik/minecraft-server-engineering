# ADR 0001: Arquitetura de Game Loop Síncrono e Isolamento de I/O

## Status
Aceito

## Contexto
O PaperMC executa a simulação do mundo (World API, entidades, IA e blocos) na Main Thread sob um orçamento rígido de 50ms por tick (20 TPS). Chamadas bloqueantes de rede ou disco nessa thread atrasam o ciclo, provocando Tick Loop Lag.

## Decisão
Proibir operações de I/O síncronas na Main Thread. Toda interação externa (JDBC, HTTP, arquivos) deve rodar em pools assíncronos (CompletableFuture / BukkitScheduler assíncrono). Apenas a mutação de estado final do jogo retorna via runTask para execução na Main Thread.

## Consequências
### Positivas
- Manutenção contínua de 20 TPS sem travamentos gerados por latência externa.
- Desacoplamento entre estabilidade de gameplay e disponibilidade de serviços.

### Negativas
- Maior complexidade no fluxo de código para tratar callbacks assíncronos.
- Risco de concorrência caso métodos da Bukkit API sejam invocados fora da Main Thread sem sincronização.
