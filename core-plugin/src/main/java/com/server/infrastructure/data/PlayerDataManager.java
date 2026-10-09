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

    // Cache L1: Caffeine W-TinyLFU, leituras lock-free
    private final Cache<UUID, PlayerProfile> profileCache = Caffeine.newBuilder()
            .maximumSize(5_000)
            .expireAfterAccess(Duration.ofMinutes(30))
            .build();

    public PlayerDataManager(JavaPlugin plugin, HikariDataSource dataSource) {
        this.plugin = plugin;
        this.dataSource = dataSource;
        this.lastLoginKey = new NamespacedKey(plugin, "last_login_epoch");
    }

    // [Main Thread] Inicia lookup no L1 e delega I/O assíncrono se necessário
    public CompletableFuture<PlayerProfile> loadPlayerProfile(UUID playerUuid, String username) {
        PlayerProfile cached = profileCache.getIfPresent(playerUuid);
        if (cached != null) {
            return CompletableFuture.completedFuture(cached);
        }

        return CompletableFuture.supplyAsync(() -> fetchOrCreateProfile(playerUuid, username))
                .thenApply(profile -> {
                    profileCache.put(playerUuid, profile);
                    return profile;
                });
    }

    // [Async Thread] Consulta/Insere isoladamente sem bloquear o Game Loop
    private PlayerProfile fetchOrCreateProfile(UUID playerUuid, String username) {
        final String selectQuery = "SELECT coins, rank_name FROM player_data WHERE uuid = ?";
        final String upsertQuery = """
            INSERT INTO player_data (uuid, username, coins, rank_name, last_seen)
            VALUES (?, ?, 0, 'DEFAULT', ?)
            ON CONFLICT (uuid) DO UPDATE SET username = EXCLUDED.username
            RETURNING coins, rank_name;
        """;

        try (Connection conn = dataSource.getConnection()) {
            try (PreparedStatement stmt = conn.prepareStatement(selectQuery)) {
                stmt.setObject(1, playerUuid);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        long coins = rs.getLong("coins");
                        String rank = rs.getString("rank_name");
                        return new PlayerProfile(playerUuid, coins, rank);
                    }
                }
            }

            try (PreparedStatement insertStmt = conn.prepareStatement(upsertQuery)) {
                insertStmt.setObject(1, playerUuid);
                insertStmt.setString(2, username);
                insertStmt.setLong(3, System.currentTimeMillis());
                try (ResultSet rs = insertStmt.executeQuery()) {
                    if (rs.next()) {
                        return new PlayerProfile(playerUuid, rs.getLong("coins"), rs.getString("rank_name"));
                    }
                }
            }
        } catch (SQLException e) {
            plugin.getLogger().log(Level.SEVERE, "Erro ao carregar/inserir perfil do jogador: " + playerUuid, e);
        }

        return new PlayerProfile(playerUuid, 0L, "DEFAULT");
    }

    // [Main Thread] Sincroniza metadados com a World API e PDC
    public void syncProfileToPlayer(Player player, PlayerProfile profile) {
        PersistentDataContainer pdc = player.getPersistentDataContainer();
        pdc.set(lastLoginKey, PersistentDataType.LONG, System.currentTimeMillis());
        player.setPlayerListName(String.format("§7[%s]§r %s", profile.rank(), player.getName()));
    }

    // [Main Thread] Persiste dados do jogador no encerramento da sessão
    public void persistPlayerSession(Player player) {
        UUID uuid = player.getUniqueId();
        PlayerProfile profile = profileCache.getIfPresent(uuid);
        if (profile == null) {
            return;
        }

        Long lastLogin = player.getPersistentDataContainer().get(lastLoginKey, PersistentDataType.LONG);
        long resolvedLastLogin = lastLogin != null ? lastLogin : System.currentTimeMillis();

        CompletableFuture.runAsync(() -> {
            final String updateSql = "UPDATE player_data SET last_seen = ? WHERE uuid = ?";
            try (Connection conn = dataSource.getConnection();
                 PreparedStatement stmt = conn.prepareStatement(updateSql)) {
                stmt.setLong(1, resolvedLastLogin);
                stmt.setObject(2, uuid);
                stmt.executeUpdate();
            } catch (SQLException e) {
                plugin.getLogger().log(Level.SEVERE, "Falha ao salvar sessão para: " + uuid, e);
            }
        });
    }

    public record PlayerProfile(UUID uuid, long coins, String rank) {}
}
