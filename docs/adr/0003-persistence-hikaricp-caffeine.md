# ADR 0003: Persistência com HikariCP e Cache L1 com Caffeine

## Status
Aceito

## Contexto
Acessar bancos de dados na Main Thread degrada o TPS, enquanto consultar conexões remotas em todas as interações frequentes satura a rede e o SGBD.

## Decisão
Implementar Caffeine Cache em memória como camada L1 (política W-TinyLFU, leituras lock-free) para acesso em tempo real, integrando-o ao HikariCP para gerenciamento assíncrono de conexões JDBC com o PostgreSQL.

## Consequências
### Positivas
- Latência sub-microssegundo nas operações rotineiras do Game Loop.
- Redução de contenção e uso eficiente de conexões com detecção ativa de vazamentos.

### Negativas
- Complexidade para manter consistência eventual e invalidação de cache entre instâncias.
