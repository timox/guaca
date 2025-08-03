#!/bin/bash

# Script de configuration avancée pour le mapping des tokens OIDC vers RDP
# Ce script étend docker-entrypoint.sh pour gérer les attributs personnalisés

echo "Configuration du mapping OIDC vers RDP..."

# ========================================
# VARIABLES DE MAPPING OIDC AVANCÉES
# ========================================

# Attributs OIDC à mapper
export OIDC_USERNAME_ATTRIBUTE=${OIDC_USERNAME_ATTRIBUTE:-cn}  # Utiliser CN au lieu de email
export OIDC_EMAIL_ATTRIBUTE=${OIDC_EMAIL_ATTRIBUTE:-email}
export OIDC_UPN_ATTRIBUTE=${OIDC_UPN_ATTRIBUTE:-upn}
export OIDC_DOMAIN_ATTRIBUTE=${OIDC_DOMAIN_ATTRIBUTE:-domain}
export OIDC_GROUPS_ATTRIBUTE=${OIDC_GROUPS_ATTRIBUTE:-groups}
export OIDC_DISPLAY_NAME_ATTRIBUTE=${OIDC_DISPLAY_NAME_ATTRIBUTE:-displayName}
export OIDC_GIVEN_NAME_ATTRIBUTE=${OIDC_GIVEN_NAME_ATTRIBUTE:-givenName}
export OIDC_FAMILY_NAME_ATTRIBUTE=${OIDC_FAMILY_NAME_ATTRIBUTE:-familyName}
export OIDC_DEPARTMENT_ATTRIBUTE=${OIDC_DEPARTMENT_ATTRIBUTE:-department}
export OIDC_EMPLOYEE_ID_ATTRIBUTE=${OIDC_EMPLOYEE_ID_ATTRIBUTE:-employeeID}

# Transformation des attributs
export OIDC_USERNAME_TRANSFORM=${OIDC_USERNAME_TRANSFORM:-none}  # none, lowercase, uppercase, prefix, suffix
export OIDC_USERNAME_PREFIX=${OIDC_USERNAME_PREFIX:-}
export OIDC_USERNAME_SUFFIX=${OIDC_USERNAME_SUFFIX:-}
export OIDC_STRIP_DOMAIN_FROM_USERNAME=${OIDC_STRIP_DOMAIN_FROM_USERNAME:-false}

# Domaine Windows par défaut
export WINDOWS_DEFAULT_DOMAIN=${WINDOWS_DEFAULT_DOMAIN:-}
export WINDOWS_DOMAIN_FROM_TOKEN=${WINDOWS_DOMAIN_FROM_TOKEN:-false}
export WINDOWS_DOMAIN_MAPPING=${WINDOWS_DOMAIN_MAPPING:-}  # Format: oidc_domain:windows_domain,oidc_domain2:windows_domain2

# ========================================
# AJOUT À guacamole.properties
# ========================================

# Fonction pour ajouter les configurations OIDC avancées
add_oidc_advanced_config() {
    cat >> ${GUACAMOLE_HOME}/guacamole.properties << EOF

# Configuration avancée du mapping OIDC
openid-username-claim-type: ${OIDC_USERNAME_ATTRIBUTE}
openid-groups-claim-type: ${OIDC_GROUPS_ATTRIBUTE}
openid-email-claim-type: ${OIDC_EMAIL_ATTRIBUTE}
openid-name-claim-type: ${OIDC_DISPLAY_NAME_ATTRIBUTE}

# Attributs personnalisés OIDC (extension Guacamole)
# Ces attributs seront disponibles comme variables dans les connexions
openid-claim-mapping: cn=${OIDC_USERNAME_ATTRIBUTE},\
    email=${OIDC_EMAIL_ATTRIBUTE},\
    upn=${OIDC_UPN_ATTRIBUTE},\
    domain=${OIDC_DOMAIN_ATTRIBUTE},\
    groups=${OIDC_GROUPS_ATTRIBUTE},\
    displayName=${OIDC_DISPLAY_NAME_ATTRIBUTE},\
    givenName=${OIDC_GIVEN_NAME_ATTRIBUTE},\
    familyName=${OIDC_FAMILY_NAME_ATTRIBUTE},\
    department=${OIDC_DEPARTMENT_ATTRIBUTE},\
    employeeID=${OIDC_EMPLOYEE_ID_ATTRIBUTE}

# Configuration des tokens à utiliser dans les connexions
rdp-username-attribute: ${OIDC_USERNAME_ATTRIBUTE}
rdp-domain-attribute: ${OIDC_DOMAIN_ATTRIBUTE}
rdp-password-attribute: 

# Domaine Windows par défaut
rdp-default-domain: ${WINDOWS_DEFAULT_DOMAIN}

# Transformation automatique des usernames
username-transform: ${OIDC_USERNAME_TRANSFORM}
username-prefix: ${OIDC_USERNAME_PREFIX}
username-suffix: ${OIDC_USERNAME_SUFFIX}
strip-domain: ${OIDC_STRIP_DOMAIN_FROM_USERNAME}

EOF
}

# ========================================
# SCRIPT SQL POUR MAPPING AUTOMATIQUE
# ========================================

# Générer un script SQL pour configurer les connexions avec mapping
generate_connection_mapping_sql() {
    cat > /tmp/oidc_mapping.sql << 'EOF'
-- Script généré automatiquement pour le mapping OIDC

-- Fonction pour appliquer le mapping OIDC à toutes les connexions RDP
CREATE OR REPLACE FUNCTION apply_oidc_mapping_to_all_rdp() RETURNS VOID AS $$
DECLARE
    v_connection RECORD;
    v_username_mapping VARCHAR(256);
    v_domain_mapping VARCHAR(256);
BEGIN
    -- Pour chaque connexion RDP existante
    FOR v_connection IN 
        SELECT connection_id, connection_name 
        FROM guacamole_connection 
        WHERE protocol = 'rdp'
    LOOP
        -- Déterminer le mapping username selon la configuration
        v_username_mapping := CASE 
            WHEN '${OIDC_USERNAME_TRANSFORM}' = 'lowercase' THEN 
                'LOWER(${' || '${OIDC_USERNAME_ATTRIBUTE}' || '})'
            WHEN '${OIDC_USERNAME_TRANSFORM}' = 'uppercase' THEN 
                'UPPER(${' || '${OIDC_USERNAME_ATTRIBUTE}' || '})'
            WHEN '${OIDC_USERNAME_TRANSFORM}' = 'prefix' THEN 
                '${OIDC_USERNAME_PREFIX}' || '${' || '${OIDC_USERNAME_ATTRIBUTE}' || '}'
            WHEN '${OIDC_USERNAME_TRANSFORM}' = 'suffix' THEN 
                '${' || '${OIDC_USERNAME_ATTRIBUTE}' || '}' || '${OIDC_USERNAME_SUFFIX}'
            ELSE 
                '${' || '${OIDC_USERNAME_ATTRIBUTE}' || '}'
        END;
        
        -- Déterminer le mapping domaine
        v_domain_mapping := CASE
            WHEN '${WINDOWS_DOMAIN_FROM_TOKEN}' = 'true' THEN 
                '${' || '${OIDC_DOMAIN_ATTRIBUTE}' || '}'
            WHEN '${WINDOWS_DEFAULT_DOMAIN}' != '' THEN 
                '${WINDOWS_DEFAULT_DOMAIN}'
            ELSE 
                NULL
        END;
        
        -- Mettre à jour ou créer le paramètre username
        INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
        VALUES (v_connection.connection_id, 'username', v_username_mapping)
        ON CONFLICT (connection_id, parameter_name) 
        DO UPDATE SET parameter_value = v_username_mapping
        WHERE guacamole_connection_parameter.parameter_value NOT LIKE '%STATIC_%';  -- Ne pas écraser les valeurs statiques
        
        -- Mettre à jour ou créer le paramètre domain si défini
        IF v_domain_mapping IS NOT NULL THEN
            INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
            VALUES (v_connection.connection_id, 'domain', v_domain_mapping)
            ON CONFLICT (connection_id, parameter_name) 
            DO UPDATE SET parameter_value = v_domain_mapping
            WHERE guacamole_connection_parameter.parameter_value NOT LIKE '%STATIC_%';
        END IF;
        
        RAISE NOTICE 'Mapping OIDC appliqué à: %', v_connection.connection_name;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Exécuter le mapping
SELECT apply_oidc_mapping_to_all_rdp();

-- Créer une table de configuration pour les mappings personnalisés
CREATE TABLE IF NOT EXISTS oidc_custom_mappings (
    mapping_id SERIAL PRIMARY KEY,
    oidc_group VARCHAR(256),           -- Groupe OIDC
    connection_pattern VARCHAR(256),    -- Pattern de connexion
    username_override VARCHAR(256),     -- Override du username
    domain_override VARCHAR(256),       -- Override du domaine
    additional_params JSONB,            -- Paramètres additionnels
    priority INTEGER DEFAULT 100,       -- Priorité du mapping
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Exemples de mappings personnalisés basés sur les groupes
INSERT INTO oidc_custom_mappings (oidc_group, connection_pattern, username_override, domain_override, additional_params, priority)
VALUES 
    ('admins', '%', '${cn}', 'ADMIN-DOMAIN', '{"console": "true", "enable-drive": "true"}'::jsonb, 10),
    ('developers', '%DEV%', '${cn}', 'DEV-DOMAIN', '{"enable-clipboard": "true"}'::jsonb, 50),
    ('users', '%PROD%', '${email}', 'PROD-DOMAIN', '{"enable-drive": "false"}'::jsonb, 100)
ON CONFLICT DO NOTHING;

-- Fonction pour appliquer les mappings personnalisés basés sur les groupes
CREATE OR REPLACE FUNCTION apply_group_based_mappings(
    p_username VARCHAR(256),
    p_groups TEXT[]
) RETURNS TABLE(
    connection_id INTEGER,
    parameter_updates JSONB
) AS $$
DECLARE
    v_mapping RECORD;
    v_updates JSONB;
BEGIN
    -- Pour chaque mapping actif
    FOR v_mapping IN 
        SELECT * FROM oidc_custom_mappings 
        WHERE enabled = true 
        AND oidc_group = ANY(p_groups)
        ORDER BY priority ASC
    LOOP
        -- Construire les mises à jour
        v_updates := jsonb_build_object(
            'username', v_mapping.username_override,
            'domain', v_mapping.domain_override
        ) || COALESCE(v_mapping.additional_params, '{}'::jsonb);
        
        -- Retourner les connexions matching avec leurs updates
        RETURN QUERY
        SELECT 
            c.connection_id,
            v_updates
        FROM guacamole_connection c
        WHERE c.connection_name LIKE v_mapping.connection_pattern;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Vue pour debug : voir tous les mappings actifs
CREATE OR REPLACE VIEW v_active_oidc_mappings AS
SELECT 
    c.connection_name,
    cp_user.parameter_value as username_mapping,
    cp_domain.parameter_value as domain_mapping,
    cp_sec.parameter_value as security_mode,
    c.connection_id
FROM 
    guacamole_connection c
    LEFT JOIN guacamole_connection_parameter cp_user 
        ON c.connection_id = cp_user.connection_id 
        AND cp_user.parameter_name = 'username'
    LEFT JOIN guacamole_connection_parameter cp_domain 
        ON c.connection_id = cp_domain.connection_id 
        AND cp_domain.parameter_name = 'domain'
    LEFT JOIN guacamole_connection_parameter cp_sec 
        ON c.connection_id = cp_sec.connection_id 
        AND cp_sec.parameter_name = 'security'
WHERE 
    c.protocol = 'rdp'
    AND (cp_user.parameter_value LIKE '${%' OR cp_domain.parameter_value LIKE '${%');

EOF
}

# ========================================
# CRÉATION CONFIG EXEMPLES KEYCLOAK
# ========================================

create_keycloak_mapper_examples() {
    cat > /tmp/keycloak_mappers.json << 'EOF'
{
  "description": "Mappers Keycloak pour Guacamole",
  "mappers": [
    {
      "name": "cn",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-attribute-mapper",
      "config": {
        "user.attribute": "cn",
        "claim.name": "cn",
        "jsonType.label": "String",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "userinfo.token.claim": "true"
      }
    },
    {
      "name": "upn",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-attribute-mapper",
      "config": {
        "user.attribute": "userPrincipalName",
        "claim.name": "upn",
        "jsonType.label": "String",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "userinfo.token.claim": "true"
      }
    },
    {
      "name": "windowsDomain",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-hardcoded-claim-mapper",
      "config": {
        "claim.name": "domain",
        "claim.value": "COMPANY",
        "jsonType.label": "String",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "userinfo.token.claim": "true"
      }
    },
    {
      "name": "samAccountName",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-attribute-mapper",
      "config": {
        "user.attribute": "sAMAccountName",
        "claim.name": "samAccountName",
        "jsonType.label": "String",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "userinfo.token.claim": "true"
      }
    },
    {
      "name": "department",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-attribute-mapper",
      "config": {
        "user.attribute": "department",
        "claim.name": "department",
        "jsonType.label": "String",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "userinfo.token.claim": "true"
      }
    },
    {
      "name": "employeeID",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-attribute-mapper",
      "config": {
        "user.attribute": "employeeNumber",
        "claim.name": "employeeID",
        "jsonType.label": "String",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "userinfo.token.claim": "true"
      }
    },
    {
      "name": "groups",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-group-membership-mapper",
      "config": {
        "claim.name": "groups",
        "full.path": "false",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "userinfo.token.claim": "true"
      }
    }
  ]
}
EOF

    echo "Configuration Keycloak créée dans /tmp/keycloak_mappers.json"
}

# ========================================
# FONCTION DE TEST DU MAPPING
# ========================================

test_oidc_mapping() {
    echo "========================================="
    echo "Test du mapping OIDC configuré:"
    echo "========================================="
    echo "Attribut username: ${OIDC_USERNAME_ATTRIBUTE}"
    echo "Transformation: ${OIDC_USERNAME_TRANSFORM}"
    echo "Domaine Windows: ${WINDOWS_DEFAULT_DOMAIN}"
    echo "Domaine depuis token: ${WINDOWS_DOMAIN_FROM_TOKEN}"
    echo ""
    echo "Variables disponibles dans les connexions RDP:"
    echo "  \${cn} - Common Name de l'utilisateur"
    echo "  \${email} - Email de l'utilisateur"
    echo "  \${upn} - User Principal Name"
    echo "  \${domain} - Domaine depuis OIDC"
    echo "  \${groups} - Groupes de l'utilisateur"
    echo "  \${displayName} - Nom d'affichage"
    echo "  \${department} - Département"
    echo "  \${employeeID} - ID employé"
    echo "  \${GUAC_USERNAME} - Username Guacamole"
    echo "========================================="
}

# ========================================
# EXÉCUTION PRINCIPALE
# ========================================

# Ajouter la configuration avancée à guacamole.properties
if [ ! -z "${OPENID_ISSUER}" ]; then
    echo "Application du mapping OIDC avancé..."
    add_oidc_advanced_config
    
    # Générer les scripts SQL
    generate_connection_mapping_sql
    
    # Créer les exemples Keycloak
    create_keycloak_mapper_examples
    
    # Afficher le test
    test_oidc_mapping
    
    # Appliquer le mapping SQL si PostgreSQL est disponible
    if [ ! -z "${POSTGRES_HOSTNAME}" ]; then
        echo "Application du mapping aux connexions RDP existantes..."
        PGPASSWORD=${POSTGRES_PASSWORD} psql \
            -h ${POSTGRES_HOSTNAME} \
            -p ${POSTGRES_PORT} \
            -U ${POSTGRES_USER} \
            -d ${POSTGRES_DATABASE} \
            -f /tmp/oidc_mapping.sql 2>/dev/null || echo "Les mappings seront appliqués au prochain démarrage"
    fi
fi

echo "Configuration du mapping OIDC terminée!"