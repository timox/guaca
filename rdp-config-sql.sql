-- =====================================================
-- Configuration des connexions RDP prédéfinies
-- =====================================================

-- Fonction pour créer une connexion RDP avec tous les paramètres
CREATE OR REPLACE FUNCTION create_rdp_connection(
    p_connection_name VARCHAR(128),
    p_hostname VARCHAR(512),
    p_port INTEGER DEFAULT 3389,
    p_domain VARCHAR(128) DEFAULT NULL,
    p_security VARCHAR(32) DEFAULT 'nla',
    p_ignore_cert BOOLEAN DEFAULT true,
    p_enable_drive BOOLEAN DEFAULT true,
    p_enable_printing BOOLEAN DEFAULT true,
    p_enable_clipboard BOOLEAN DEFAULT true,
    p_console BOOLEAN DEFAULT false,
    p_width INTEGER DEFAULT 1920,
    p_height INTEGER DEFAULT 1080,
    p_dpi INTEGER DEFAULT 96,
    p_color_depth INTEGER DEFAULT 32,
    p_resize_method VARCHAR(32) DEFAULT 'display-update',
    p_recording_path VARCHAR(1024) DEFAULT NULL,
    p_recording_name VARCHAR(256) DEFAULT NULL,
    p_create_recording_path BOOLEAN DEFAULT true
) RETURNS INTEGER AS $$
DECLARE
    v_connection_id INTEGER;
BEGIN
    -- Créer la connexion de base
    INSERT INTO guacamole_connection (
        connection_name,
        protocol,
        parent_id,
        max_connections,
        max_connections_per_user
    ) VALUES (
        p_connection_name,
        'rdp',
        NULL,
        NULL,
        1
    ) RETURNING connection_id INTO v_connection_id;
    
    -- Paramètres de connexion de base
    INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES
        (v_connection_id, 'hostname', p_hostname),
        (v_connection_id, 'port', p_port::TEXT),
        (v_connection_id, 'security', p_security),
        (v_connection_id, 'ignore-cert', p_ignore_cert::TEXT);
    
    -- Domaine Windows (TRÈS IMPORTANT pour l'authentification)
    IF p_domain IS NOT NULL THEN
        INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) 
        VALUES (v_connection_id, 'domain', p_domain);
    END IF;
    
    -- Paramètres d'affichage
    INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES
        (v_connection_id, 'width', p_width::TEXT),
        (v_connection_id, 'height', p_height::TEXT),
        (v_connection_id, 'dpi', p_dpi::TEXT),
        (v_connection_id, 'color-depth', p_color_depth::TEXT),
        (v_connection_id, 'resize-method', p_resize_method);
    
    -- Fonctionnalités
    INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES
        (v_connection_id, 'enable-drive', p_enable_drive::TEXT),
        (v_connection_id, 'drive-name', 'Guacamole Drive'),
        (v_connection_id, 'drive-path', '/drive'),
        (v_connection_id, 'enable-printing', p_enable_printing::TEXT),
        (v_connection_id, 'enable-clipboard', p_enable_clipboard::TEXT),
        (v_connection_id, 'console', p_console::TEXT);
    
    -- Paramètres de performance
    INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES
        (v_connection_id, 'enable-wallpaper', 'true'),
        (v_connection_id, 'enable-theming', 'true'),
        (v_connection_id, 'enable-font-smoothing', 'true'),
        (v_connection_id, 'enable-full-window-drag', 'false'),
        (v_connection_id, 'enable-desktop-composition', 'true'),
        (v_connection_id, 'enable-menu-animations', 'false');
    
    -- Audio
    INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES
        (v_connection_id, 'enable-audio', 'true'),
        (v_connection_id, 'audio-servername', ''),
        (v_connection_id, 'disable-audio', 'false');
    
    -- Enregistrement si configuré
    IF p_recording_path IS NOT NULL THEN
        INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES
            (v_connection_id, 'recording-path', p_recording_path),
            (v_connection_id, 'recording-name', COALESCE(p_recording_name, '${GUAC_USERNAME}_${GUAC_DATE}_${GUAC_TIME}')),
            (v_connection_id, 'create-recording-path', p_create_recording_path::TEXT);
    END IF;
    
    -- Configuration du clavier
    INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES
        (v_connection_id, 'server-layout', 'fr-fr-azerty'),
        (v_connection_id, 'disable-copy', 'false'),
        (v_connection_id, 'disable-paste', 'false');
    
    -- Gateway RD si nécessaire (décommentez et configurez si vous avez un RD Gateway)
    -- INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES
    --     (v_connection_id, 'gateway-hostname', 'rdgateway.company.com'),
    --     (v_connection_id, 'gateway-port', '443'),
    --     (v_connection_id, 'gateway-domain', 'COMPANY');
    
    RETURN v_connection_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- CONNEXIONS RDP AVEC PARAMÈTRES TOKEN (OIDC/LDAP)
-- =====================================================

-- Fonction pour créer une connexion RDP avec mapping de tokens
CREATE OR REPLACE FUNCTION create_rdp_with_token_mapping(
    p_connection_name VARCHAR(128),
    p_hostname VARCHAR(512),
    p_domain VARCHAR(128),
    p_use_token_username BOOLEAN DEFAULT true,
    p_username_attribute VARCHAR(64) DEFAULT 'cn',  -- ou 'preferred_username', 'upn', etc.
    p_password_attribute VARCHAR(64) DEFAULT NULL,
    p_domain_attribute VARCHAR(64) DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_connection_id INTEGER;
BEGIN
    -- Créer la connexion de base
    v_connection_id := create_rdp_connection(
        p_connection_name,
        p_hostname,
        3389,
        p_domain,
        'nla',
        true,
        true,
        true,
        true
    );
    
    -- IMPORTANT: Paramètres de token mapping pour l'authentification automatique
    
    -- Utiliser le username du token OIDC/LDAP
    IF p_use_token_username THEN
        -- ${GUAC_USERNAME} sera remplacé par le username de l'utilisateur connecté
        -- Mais on peut aussi utiliser des attributs spécifiques du token
        INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) 
        VALUES (v_connection_id, 'username', '${GUAC_USERNAME}');
        
        -- Ou utiliser un attribut spécifique du token OIDC
        -- Pour utiliser le CN ou autre attribut du token:
        IF p_username_attribute IS NOT NULL THEN
            DELETE FROM guacamole_connection_parameter 
            WHERE connection_id = v_connection_id AND parameter_name = 'username';
            
            INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) 
            VALUES (v_connection_id, 'username', '${' || p_username_attribute || '}');
        END IF;
    END IF;
    
    -- Password depuis le token (si disponible)
    IF p_password_attribute IS NOT NULL THEN
        INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) 
        VALUES (v_connection_id, 'password', '${' || p_password_attribute || '}');
    END IF;
    
    -- Domain depuis le token (si disponible)
    IF p_domain_attribute IS NOT NULL THEN
        DELETE FROM guacamole_connection_parameter 
        WHERE connection_id = v_connection_id AND parameter_name = 'domain';
        
        INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) 
        VALUES (v_connection_id, 'domain', '${' || p_domain_attribute || '}');
    END IF;
    
    -- Paramètres additionnels pour le SSO
    INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES
        (v_connection_id, 'preconnection-id', ''),
        (v_connection_id, 'load-balance-info', '');
    
    RETURN v_connection_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- EXEMPLES DE CONNEXIONS PRÉDÉFINIES
-- =====================================================

-- 1. Serveur Windows avec domaine imposé et username depuis OIDC
DO $$
DECLARE
    v_conn_id INTEGER;
BEGIN
    -- Serveur RDP principal avec domaine COMPANY
    v_conn_id := create_rdp_with_token_mapping(
        'Serveur Principal - ${GUAC_USERNAME}',  -- Le nom affichera le username
        'srv-rdp01.company.local',
        'COMPANY',  -- Domaine Windows imposé
        true,       -- Utiliser le username du token
        'cn',       -- Utiliser l'attribut 'cn' du token OIDC comme username
        NULL,       -- Pas de password dans le token
        NULL        -- Domaine fixe (pas depuis token)
    );
    
    -- Donner les permissions à tous les utilisateurs authentifiés
    -- (sera filtré par les groupes LDAP/OIDC si configuré)
    RAISE NOTICE 'Connexion créée avec ID: %', v_conn_id;
END $$;

-- 2. Terminal Server avec paramètres spécifiques
DO $$
DECLARE
    v_conn_id INTEGER;
BEGIN
    v_conn_id := create_rdp_connection(
        'Terminal Server',
        'ts01.company.local',
        3389,
        'COMPANY',
        'nla',
        true,
        true,
        true,
        true,
        false,  -- Pas en mode console
        1920,
        1080,
        96,
        32,
        'display-update',
        '/recordings',  -- Enregistrer les sessions
        'ts_${GUAC_USERNAME}_${GUAC_DATE}_${GUAC_TIME}.guac'
    );
    
    -- Username automatique depuis OIDC
    INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) 
    VALUES (v_conn_id, 'username', '${cn}');  -- Utilise le CN du token OIDC
    
    RAISE NOTICE 'Terminal Server créé avec ID: %', v_conn_id;
END $$;

-- 3. Serveur d'applications avec RemoteApp
DO $$
DECLARE
    v_conn_id INTEGER;
BEGIN
    v_conn_id := create_rdp_with_token_mapping(
        'Application SAP',
        'app-sap.company.local',
        'COMPANY',
        true,
        'sAMAccountName',  -- Utiliser le sAMAccountName pour SAP
        NULL,
        NULL
    );
    
    -- Configuration RemoteApp
    INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES
        (v_conn_id, 'remote-app', 'true'),
        (v_conn_id, 'remote-app-program', '||SAP'),
        (v_conn_id, 'remote-app-dir', 'C:\Program Files\SAP'),
        (v_conn_id, 'remote-app-args', '');
    
    RAISE NOTICE 'RemoteApp SAP créé avec ID: %', v_conn_id;
END $$;

-- =====================================================
-- GROUPES DE CONNEXIONS ORGANISÉS
-- =====================================================

-- Créer des groupes pour organiser les connexions
INSERT INTO guacamole_connection_group (connection_group_name, type, parent_id) 
VALUES 
    ('Production', 'ORGANIZATIONAL', NULL),
    ('Développement', 'ORGANIZATIONAL', NULL),
    ('Applications', 'ORGANIZATIONAL', NULL)
ON CONFLICT DO NOTHING;

-- Fonction pour assigner les connexions aux groupes
CREATE OR REPLACE FUNCTION assign_connection_to_group(
    p_connection_name VARCHAR(128),
    p_group_name VARCHAR(128)
) RETURNS VOID AS $$
DECLARE
    v_conn_id INTEGER;
    v_group_id INTEGER;
BEGIN
    SELECT connection_id INTO v_conn_id 
    FROM guacamole_connection 
    WHERE connection_name = p_connection_name;
    
    SELECT connection_group_id INTO v_group_id 
    FROM guacamole_connection_group 
    WHERE connection_group_name = p_group_name;
    
    IF v_conn_id IS NOT NULL AND v_group_id IS NOT NULL THEN
        UPDATE guacamole_connection 
        SET parent_id = v_group_id 
        WHERE connection_id = v_conn_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PERMISSIONS BASÉES SUR LES GROUPES OIDC/LDAP
-- =====================================================

-- Table de mapping groupe OIDC/LDAP -> permissions Guacamole
CREATE TABLE IF NOT EXISTS oidc_group_mapping (
    oidc_group VARCHAR(256) PRIMARY KEY,
    connection_pattern VARCHAR(256),  -- Pattern pour matcher les connexions
    permission_level VARCHAR(32)      -- READ, UPDATE, DELETE, ADMINISTER
);

-- Exemples de mappings
INSERT INTO oidc_group_mapping (oidc_group, connection_pattern, permission_level) VALUES
    ('IT-Admins', '%', 'ADMINISTER'),           -- Admins ont accès à tout
    ('RDP-Users-Prod', '%Production%', 'READ'), -- Accès lecture production
    ('RDP-Users-Dev', '%Développement%', 'READ'),  -- Accès dev
    ('SAP-Users', '%SAP%', 'READ')              -- Accès SAP uniquement
ON CONFLICT DO NOTHING;

-- =====================================================
-- PARAMÈTRES AVANCÉS POUR SSO
-- =====================================================

-- Table pour stocker les mappings d'attributs OIDC personnalisés
CREATE TABLE IF NOT EXISTS oidc_attribute_mapping (
    mapping_id SERIAL PRIMARY KEY,
    connection_id INTEGER REFERENCES guacamole_connection(connection_id),
    guacamole_param VARCHAR(128),  -- Paramètre Guacamole (username, domain, etc.)
    oidc_attribute VARCHAR(256),   -- Attribut OIDC/claim (cn, upn, email, etc.)
    transform_rule VARCHAR(512)    -- Règle de transformation optionnelle
);

-- Fonction pour mapper automatiquement les attributs OIDC
CREATE OR REPLACE FUNCTION map_oidc_attribute(
    p_connection_id INTEGER,
    p_guacamole_param VARCHAR(128),
    p_oidc_attribute VARCHAR(256),
    p_transform_rule VARCHAR(512) DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    -- Supprimer l'ancien mapping s'il existe
    DELETE FROM guacamole_connection_parameter 
    WHERE connection_id = p_connection_id 
    AND parameter_name = p_guacamole_param;
    
    -- Créer le nouveau mapping
    IF p_transform_rule IS NOT NULL THEN
        -- Avec transformation
        INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
        VALUES (p_connection_id, p_guacamole_param, p_transform_rule);
    ELSE
        -- Sans transformation, utilisation directe
        INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
        VALUES (p_connection_id, p_guacamole_param, '${' || p_oidc_attribute || '}');
    END IF;
    
    -- Enregistrer le mapping
    INSERT INTO oidc_attribute_mapping (connection_id, guacamole_param, oidc_attribute, transform_rule)
    VALUES (p_connection_id, p_guacamole_param, p_oidc_attribute, p_transform_rule)
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- VUES UTILES POUR L'ADMINISTRATION
-- =====================================================

-- Vue pour voir toutes les connexions avec leurs paramètres token
CREATE OR REPLACE VIEW v_rdp_connections_with_tokens AS
SELECT 
    c.connection_id,
    c.connection_name,
    c.protocol,
    MAX(CASE WHEN cp.parameter_name = 'hostname' THEN cp.parameter_value END) as hostname,
    MAX(CASE WHEN cp.parameter_name = 'domain' THEN cp.parameter_value END) as domain,
    MAX(CASE WHEN cp.parameter_name = 'username' THEN cp.parameter_value END) as username_mapping,
    MAX(CASE WHEN cp.parameter_name = 'security' THEN cp.parameter_value END) as security,
    COUNT(DISTINCT cp.parameter_name) as total_parameters
FROM 
    guacamole_connection c
    LEFT JOIN guacamole_connection_parameter cp ON c.connection_id = cp.connection_id
WHERE 
    c.protocol = 'rdp'
GROUP BY 
    c.connection_id, c.connection_name, c.protocol;

-- Vue pour voir les mappings OIDC actifs
CREATE OR REPLACE VIEW v_oidc_mappings AS
SELECT 
    c.connection_name,
    m.guacamole_param,
    m.oidc_attribute,
    m.transform_rule,
    cp.parameter_value as current_value
FROM 
    oidc_attribute_mapping m
    JOIN guacamole_connection c ON m.connection_id = c.connection_id
    LEFT JOIN guacamole_connection_parameter cp 
        ON m.connection_id = cp.connection_id 
        AND m.guacamole_param = cp.parameter_name;

-- =====================================================
-- PROCÉDURE DE CRÉATION EN MASSE
-- =====================================================

-- Créer plusieurs serveurs RDP avec la même configuration
CREATE OR REPLACE FUNCTION create_rdp_servers_bulk(
    p_servers TEXT[],  -- Array de serveurs hostname
    p_domain VARCHAR(128),
    p_name_prefix VARCHAR(128) DEFAULT 'Server'
) RETURNS VOID AS $$
DECLARE
    v_server TEXT;
    v_conn_id INTEGER;
    v_index INTEGER := 1;
BEGIN
    FOREACH v_server IN ARRAY p_servers
    LOOP
        v_conn_id := create_rdp_with_token_mapping(
            p_name_prefix || ' ' || v_index || ' - ' || v_server,
            v_server,
            p_domain,
            true,
            'cn',
            NULL,
            NULL
        );
        v_index := v_index + 1;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Exemple d'utilisation pour créer plusieurs serveurs
-- SELECT create_rdp_servers_bulk(
--     ARRAY['srv01.company.local', 'srv02.company.local', 'srv03.company.local'],
--     'COMPANY',
--     'Production Server'
-- );

-- Message final
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Configuration RDP avec tokens OIDC créée!';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Les connexions utilisent automatiquement:';
    RAISE NOTICE '- Le CN depuis OIDC comme username';
    RAISE NOTICE '- Le domaine Windows imposé';
    RAISE NOTICE '- Les paramètres RDP optimisés';
    RAISE NOTICE '';
    RAISE NOTICE 'Variables disponibles depuis OIDC:';
    RAISE NOTICE '${cn} - Common Name';
    RAISE NOTICE '${preferred_username} - Username préféré';
    RAISE NOTICE '${email} - Email';
    RAISE NOTICE '${upn} - User Principal Name';
    RAISE NOTICE '${groups} - Groupes';
    RAISE NOTICE '${GUAC_USERNAME} - Username Guacamole';
    RAISE NOTICE '===========================================';
END $$;