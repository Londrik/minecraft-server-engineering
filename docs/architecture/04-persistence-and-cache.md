# 04. Persistência de Dados e Camada de Cache

## 1. Conexões Relacionais com HikariCP
O HikariCP provê acesso JDBC de alta performance, minimizando overhead de alocação de conexões.

### Configuração Recomendada
```properties
dataSourceClassName=org.postgresql.ds.PGSimpleDataSource
dataSource.serverName=127.0.0.1
dataSource.portNumber=5432
dataSource.databaseName=minecraft
dataSource.user=mc_user
dataSource.password=mc_secure_pass

# Pool Tuning
maximumPoolSize=10
minimumIdle=10
idleTimeout=600000
maxLifetime=1800000
connectionTimeout=10000
leakDetectionThreshold=5000
```
- **`maximumPoolSize`**: Dimensionado com base na fórmula `(core_count * 2) + effective_spindle_count`. Para servidores dedicados PaperMC, valores entre `8` e `12` cobrem toda a demanda assíncrona sem exaurir recursos do SGBD.
- **`leakDetectionThreshold`**: Configurado em `5000ms` para emitir stack traces de conexões não fechadas antes de causarem contenção crítica.

## 2. Caffeine Cache (Camada L1 em Memória)
O Caffeine utiliza uma implementação de leitura lock-free com buffers atômicos e algoritmo de evacuação **W-TinyLFU**.

### Arquitetura de Cache
- **Read Path**: Quase 100% lock-free via buffers atômicos. Latência sub-microssegundo na Main Thread.
- **Write Path**: Amortizado em buffers assíncronos de manutenção de concorrência.
- **Evicção**:
  - `maximumSize(5000)`: Limita consumo excessivo de heap.
  - `expireAfterAccess(30, TimeUnit.MINUTES)`: Limpa dados de jogadores inativos automaticamente.

## 3. PersistentDataContainer (PDC)
O PaperMC fornece a API `PersistentDataContainer` para armazenamento de dados primitivos e compostos diretamente no NBT de itens, entidades e chunks.

### Diretrizes de Uso
- **PDC**: Uso restrito a identificadores únicos locais, metadados transitórios de gameplay e flags de instâncias (ex.: `player.getPersistentDataContainer().set(namespacedKey, PersistentDataType.LONG, lastLogin)`).
- **PostgreSQL**: Estado estruturado transacional de longo prazo (balanço, inventários salvos, histórico de punições).
- **Garantia**: O PDC é thread-bound à entidade; leituras e escritas devem ocorrer estritamente na Main Thread.
