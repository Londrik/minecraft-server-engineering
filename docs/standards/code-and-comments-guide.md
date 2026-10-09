# Diretrizes de Código e Padrões de Concorrência

## 1. Convenções de Anotações de Threading
Todo método suscetível a contexto concorrente deve conter marcações explícitas de escopo:
- `// [Main Thread]`: Métodos que acessam World API, entidades Bukkit, inventários ou PDC. Devem rodar estritamente na thread do servidor.
- `// [Async Thread]`: Métodos que executam I/O, rede, JDBC e computação intensiva. Nunca devem tocar a World API.

## 2. Exemplo de Implementação: PlayerDataManager.java

```java
package com.server.infrastructure.data;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import com.zaxxer.hikari.HikariDataSource;
import org.bukkit.NamespacedKey;
import org.bukkit.entity.Player;
import org.bukkit.persistence.PersistentDataContainer;
import org.bukkit.persistence.PersistentDataType;
import org.bukkit.plugin.java.JavaPlugin;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Duration;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.logging.Level;

public final class PlayerDataManager {

    private final JavaPlugin plugin;
    private final HikariDataSource dataSource;
    private final NamespacedKey lastLoginKey;

    // Cache L1 com Caffeine: W-TinyLFU, Lock-free read
    private final Cache<UUID, PlayerProfile> profileCache = Caffeine.newBuilder()
            .maximumSize(5_000)
            .expireAfterAccess(Duration.ofMinutes(30))
            .build();

    public PlayerDataManager(JavaPlugin plugin, HikariDataSource dataSource) {
        this.plugin = plugin;
        this.dataSource = dataSource;
        this.lastLoginKey = new NamespacedKey(plugin, "last_login_epoch");
    }

    // [Main Thread] Inicia carregamento e delega I/O
    public CompletableFuture<PlayerProfile> loadPlayerProfile(UUID playerUuid) {
        PlayerProfile cached = profileCache.getIfPresent(playerUuid);
        if (cached != null) {
            return CompletableFuture.completedFuture(cached);
        }

        // Delega I/O para Async Pool
        return CompletableFuture.supplyAsync(() -> fetchProfileFromDatabase(playerUuid))
                .thenApply(profile -> {
                    profileCache.put(playerUuid, profile);
                    return profile;
                });
    }

    // [Async Thread] Consulta isolada sem bloquear o Game Loop
    private PlayerProfile fetchProfileFromDatabase(UUID playerUuid) {
        final String query = "SELECT coins, rank_name FROM player_data WHERE uuid = ?";
        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(query)) {
            stmt.setObject(1, playerUuid);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    long coins = rs.getLong("coins");
                    String rank = rs.getString("rank_name");
                    return new PlayerProfile(playerUuid, coins, rank);
                }
            }
        } catch (SQLException e) { 
            plugin.getLogger().log(Level.SEVERE, "Erro ao carregar perfil do jogador: " + playerUuid, e);
        }
        return new PlayerProfile(playerUuid, 0L, "DEFAULT");
    }

    // [Main Thread] Aplica os dados carregados na World API de forma Thread-Safe
    public void syncProfileToPlayer(Player player, PlayerProfile profile) {
        // [Main Thread] - Grava metadados locais diretamente no PDC
        PersistentDataContainer pdc = player.getPersistentDataContainer();
        pdc.set(lastLoginKey, PersistentDataType.LONG, System.currentTimeMillis());

        // [Main Thread] - Executa mutação do estado visual/entidade
        player.setPlayerListName(String.format("[%s] %s", profile.rank(), player.getName()));
    }

    // [Main Thread] Salva dados do jogador
    public void persistPlayerSession(Player player) {
        UUID uuid = player.getUniqueId();
        PlayerProfile profile = profileCache.getIfPresent(uuid);
        if (profile == null) {
            return;
        }

        // [Main Thread] Lê estado final do PDC
        Long lastLogin = player.getPersistentDataContainer().get(lastLoginKey, PersistentDataType.LONG);

        // [Async Thread] Despacha UPDATE assíncrono para o HikariCP
        CompletableFuture.runAsync(() -> {
            final String updateSql = "UPDATE player_data SET last_seen = ? WHERE uuid = ?";
            try (Connection conn = dataSource.getConnection();
                 PreparedStatement stmt = conn.prepareStatement(updateSql)) {
                stmt.setLong(1, lastLogin != null ? lastLogin : System.currentTimeMillis());
                stmt.setObject(2, uuid);
                stmt.executeUpdate();
            } catch (SQLException e) { 
                plugin.getLogger().log(Level.SEVERE, "Falha ao salvar sessão para: " + uuid, e);
            }
        });
    }

    public record PlayerProfile(UUID uuid, long coins, String rank) {}
}
```
