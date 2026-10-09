# ADR 0004: Adoção das Aikar Flags para Coletor G1GC

## Status
Aceito

## Contexto
Pausas longas de Stop-The-World geradas pela configuração padrão do Garbage Collector do Java excedem a janela de 50ms por tick, causando stuttering e quedas de TPS sob carga intensa.

## Decisão
Adotar formalmente o conjunto Aikar Flags otimizado para o coletor G1GC em Java 21+, fixando -Xms igual a -Xmx, ativando pré-alocação (-XX:+AlwaysPreTouch) e calibrando o tempo alvo de pausa para 200ms com controle de regiões e sobrevivência de curto prazo.

## Consequências
### Positivas
- Mitigação de pausas longas de GC durante picos de movimentação de entidades e carregamento de chunks.
- Eliminação de overhead dinâmico de redimensionamento de memória em execução.

### Negativas
- Inicialização mais lenta do processo JVM devido ao mapeamento inicial completo de memória.
- Reserva estática integral da RAM alocada no host.
