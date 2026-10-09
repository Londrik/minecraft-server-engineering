-- Schema inicial para persistência de dados de jogadores (Crossplay & Java)
CREATE TABLE IF NOT EXISTS player_data (
    uuid UUID PRIMARY KEY,
    username VARCHAR(32) NOT NULL,
    coins BIGINT NOT NULL DEFAULT 0,
    rank_name VARCHAR(32) NOT NULL DEFAULT 'DEFAULT',
    last_seen BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_player_data_username ON player_data (username);
CREATE INDEX IF NOT EXISTS idx_player_data_last_seen ON player_data (last_seen);
