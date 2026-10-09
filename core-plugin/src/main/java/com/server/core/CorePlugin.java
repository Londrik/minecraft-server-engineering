package com.server.core;

import com.server.infrastructure.data.PlayerDataManager;
import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.bukkit.Bukkit;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.player.AsyncPlayerPreLoginEvent;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.event.player.PlayerQuitEvent;
import org.bukkit.plugin.java.JavaPlugin;

public final class CorePlugin extends JavaPlugin implements Listener {

    private HikariDataSource dataSource;
    private PlayerDataManager playerDataManager;

    @Override
    public void onEnable() {
        initDatabasePool();
        this.playerDataManager = new PlayerDataManager(this, this.dataSource);

        getServer().getPluginManager().registerEvents(this, this);
        getLogger().info("CorePlugin ativado com pool HikariCP e Cache Caffeine L1!");
    }

    @Override
    public void onDisable() {
        if (dataSource != null && !dataSource.isClosed()) {
            dataSource.close();
            getLogger().info("HikariDataSource encerrado com sucesso.");
        }
    }

    private void initDatabasePool() {
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl("jdbc:postgresql://127.0.0.1:5432/minecraft");
        config.setUsername("mc_user");
        config.setPassword("mc_secure_pass");
        config.setMaximumPoolSize(10);
        config.setMinimumIdle(2);
        config.setIdleTimeout(300_000);
        config.setConnectionTimeout(10_000);
        config.setMaxLifetime(600_000);
        config.setPoolName("MinecraftPool-Hikari");

        this.dataSource = new HikariDataSource(config);
    }

    // [Async Thread] Pre-carrega o perfil antes do jogador entrar no mundo
    @EventHandler(priority = EventPriority.MONITOR)
    public void onPreLogin(AsyncPlayerPreLoginEvent event) {
        if (event.getLoginResult() == AsyncPlayerPreLoginEvent.Result.ALLOWED) {
            playerDataManager.loadPlayerProfile(event.getUniqueId(), event.getName()).join();
        }
    }

    // [Main Thread] Sincroniza metadados com a entidade no mundo
    @EventHandler(priority = EventPriority.HIGHEST)
    public void onJoin(PlayerJoinEvent event) {
        Player player = event.getPlayer();
        playerDataManager.loadPlayerProfile(player.getUniqueId(), player.getName())
                .thenAccept(profile -> Bukkit.getScheduler().runTask(this, () -> {
                    if (player.isOnline()) {
                        playerDataManager.syncProfileToPlayer(player, profile);
                    }
                }));
    }

    // [Main Thread] Despacha atualização assíncrona ao desconectar
    @EventHandler
    public void onQuit(PlayerQuitEvent event) {
        playerDataManager.persistPlayerSession(event.getPlayer());
    }

    public PlayerDataManager getPlayerDataManager() {
        return playerDataManager;
    }
}
