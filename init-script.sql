-- Script d'initialisation de la base de données Guacamole
-- Version 1.5.4

-- Création de l'extension UUID si elle n'existe pas
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Configuration des paramètres de connexion
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET effective_io_concurrency = 200;

-- Création des tables principales (schéma simplifié)
-- Note: Le schéma complet sera créé automatiquement par Guacamole au premier démarrage

-- Table des utilisateurs
CREATE TABLE IF NOT EXISTS guacamole_user (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(128) NOT NULL UNIQUE,
    password_hash BYTEA NOT NULL,
    password_salt BYTEA,
    password_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    disabled BOOLEAN DEFAULT FALSE,
    expired BOOLEAN DEFAULT FALSE,
    access_window_start TIME,
    access_window_end TIME,
    valid_from DATE,
    valid_until DATE,
    timezone VARCHAR(64),
    full_name VARCHAR(256),
    email_address VARCHAR(256),
    organization VARCHAR(256),
    organizational_role VARCHAR(256)
);

-- Table des connexions
CREATE TABLE IF NOT EXISTS guacamole_connection (
    connection_id SERIAL PRIMARY KEY,
    connection_name VARCHAR(128) NOT NULL,
    parent_id INTEGER,
    protocol VARCHAR(32) NOT NULL,
    max_connections INTEGER,
    max_connections_per_user INTEGER,
    max_group_connections INTEGER,
    max_group_connections_per_user INTEGER,
    proxy_port INTEGER,
    proxy_hostname VARCHAR(512),
    proxy_encryption_method VARCHAR(32),
    connection_weight INTEGER,
    failover_only BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (parent_id) REFERENCES guacamole_connection_group(connection_group_id) ON DELETE CASCADE
);

-- Table des groupes de connexions
CREATE TABLE IF NOT EXISTS guacamole_connection_group (
    connection_group_id SERIAL PRIMARY KEY,
    parent_id INTEGER,
    connection_group_name VARCHAR(128) NOT NULL,
    type VARCHAR(32) NOT NULL DEFAULT 'ORGANIZATIONAL',
    max_connections INTEGER,
    max_connections_per_user INTEGER,
    enable_session_affinity BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (parent_id) REFERENCES guacamole_connection_group(connection_group_id) ON DELETE CASCADE,
    CHECK (type IN ('ORGANIZATIONAL', 'BALANCING'))
);

-- Table des permissions utilisateur
CREATE TABLE IF NOT EXISTS guacamole_user_permission (
    user_id INTEGER NOT NULL,
    affected_user_id INTEGER NOT NULL,
    permission VARCHAR(32) NOT NULL,
    PRIMARY KEY (user_id, affected_user_id, permission),
    FOREIGN KEY (user_id) REFERENCES guacamole_user(user_id) ON DELETE CASCADE,
    FOREIGN KEY (affected_user_id) REFERENCES guacamole_user(user_id) ON DELETE CASCADE,
    CHECK (permission IN ('READ', 'UPDATE', 'DELETE', 'ADMINISTER'))
);

-- Table des permissions de connexion
CREATE TABLE IF NOT EXISTS guacamole_connection_permission (
    user_id INTEGER NOT NULL,
    connection_id INTEGER NOT NULL,
    permission VARCHAR(32) NOT NULL,
    PRIMARY KEY (user_id, connection_id, permission),
    FOREIGN KEY (user_id) REFERENCES guacamole_user(user_id) ON DELETE CASCADE,
    FOREIGN KEY (connection_id) REFERENCES guacamole_connection(connection_id) ON DELETE CASCADE,
    CHECK (permission IN ('READ', 'UPDATE', 'DELETE', 'ADMINISTER'))
);

-- Table des paramètres de connexion
CREATE TABLE IF NOT EXISTS guacamole_connection_parameter (
    connection_id INTEGER NOT NULL,
    parameter_name VARCHAR(128) NOT NULL,
    parameter_value TEXT,
    PRIMARY KEY (connection_id, parameter_name),
    FOREIGN KEY (connection_id) REFERENCES guacamole_connection(connection_id) ON DELETE CASCADE
);

-- Table d'historique des connexions
CREATE TABLE IF NOT EXISTS guacamole_connection_history (
    history_id SERIAL PRIMARY KEY,
    user_id INTEGER,
    username VARCHAR(128) NOT NULL,
    remote_host VARCHAR(256),
    connection_id INTEGER,
    connection_name VARCHAR(128),
    sharing_profile_id INTEGER,
    sharing_profile_name VARCHAR(128),
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE,
    FOREIGN KEY (user_id) REFERENCES guacamole_user(user_id) ON DELETE SET NULL,
    FOREIGN KEY (connection_id) REFERENCES guacamole_connection(connection_id) ON DELETE SET NULL
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_connection_history_user_id ON guacamole_connection_history(user_id);
CREATE INDEX IF NOT EXISTS idx_connection_history_connection_id ON guacamole_connection_history(connection_id);
CREATE INDEX IF NOT EXISTS idx_connection_history_start_date ON guacamole_connection_history(start_date);
CREATE INDEX IF NOT EXISTS idx_connection_history_end_date ON guacamole_connection_history(end_date);
CREATE INDEX IF NOT EXISTS idx_connection_parent_id ON guacamole_connection(parent_id);
CREATE INDEX IF NOT EXISTS idx_connection_group_parent_id ON guacamole_connection_group(parent_id);

-- Création d'un utilisateur administrateur par défaut
-- Mot de passe: guacadmin (sera changé au premier login)
INSERT INTO guacamole_user (username, password_hash, password_salt, password_date)
VALUES (
    'guacadmin',
    decode('CA458A7D494E3BE824F5E1E175A1556C0F8EEF2C2D7DF3633BEC4A29C4411960', 'hex'),
    decode('FE24ADC5E11E2B25288D1704ABE67A79E342ECC26064CE69C5B3177795A82264', 'hex'),
    CURRENT_TIMESTAMP
) ON CONFLICT (username) DO NOTHING;

-- Donner tous les droits à l'administrateur
INSERT INTO guacamole_user_permission (user_id, affected_user_id, permission)
SELECT 
    u1.user_id,
    u2.user_id,
    p.permission
FROM 
    guacamole_user u1,
    guacamole_user u2,
    (VALUES ('READ'), ('UPDATE'), ('DELETE'), ('ADMINISTER')) AS p(permission)
WHERE 
    u1.username = 'guacadmin'
    AND u2.username = 'guacadmin'
ON CONFLICT DO NOTHING;

-- Création d'un groupe racine
INSERT INTO guacamole_connection_group (connection_group_name, type)
VALUES ('ROOT', 'ORGANIZATIONAL')
ON CONFLICT DO NOTHING;

-- Fonction pour nettoyer l'historique des connexions
CREATE OR REPLACE FUNCTION cleanup_connection_history()
RETURNS void AS $$
BEGIN
    DELETE FROM guacamole_connection_history
    WHERE end_date < CURRENT_TIMESTAMP - INTERVAL '90 days';
END;
$$ LANGUAGE plpgsql;

-- Création d'une tâche de maintenance programmée (nécessite pg_cron extension)
-- CREATE EXTENSION IF NOT EXISTS pg_cron;
-- SELECT cron.schedule('cleanup-history', '0 2 * * *', 'SELECT cleanup_connection_history();');

-- Statistiques de connexion
CREATE OR REPLACE VIEW connection_statistics AS
SELECT 
    c.connection_name,
    COUNT(h.history_id) as total_connections,
    AVG(EXTRACT(EPOCH FROM (h.end_date - h.start_date))/60) as avg_duration_minutes,
    MAX(h.start_date) as last_connection
FROM 
    guacamole_connection c
    LEFT JOIN guacamole_connection_history h ON c.connection_id = h.connection_id
GROUP BY 
    c.connection_id, c.connection_name;

-- Statistiques utilisateur
CREATE OR REPLACE VIEW user_statistics AS
SELECT 
    u.username,
    u.full_name,
    COUNT(h.history_id) as total_connections,
    MAX(h.start_date) as last_login,
    u.disabled,
    u.expired
FROM 
    guacamole_user u
    LEFT JOIN guacamole_connection_history h ON u.user_id = h.user_id
GROUP BY 
    u.user_id, u.username, u.full_name, u.disabled, u.expired;

-- Grant des permissions nécessaires
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO guacamole;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO guacamole;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO guacamole;

-- Message de fin
DO $$
BEGIN
    RAISE NOTICE 'Base de données Guacamole initialisée avec succès';
    RAISE NOTICE 'Utilisateur par défaut: guacadmin / guacadmin';
    RAISE NOTICE 'Pensez à changer le mot de passe au premier login!';
END $$;