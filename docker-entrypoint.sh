#!/bin/bash
set -e

echo "Configuration de Guacamole avec paramètres personnalisés..."

# ========================================
# VARIABLES D'ENVIRONNEMENT PAR DÉFAUT
# ========================================

# Configuration de base
export GUACAMOLE_HOME=${GUACAMOLE_HOME:-/etc/guacamole}

# Configuration PostgreSQL
export POSTGRES_HOSTNAME=${POSTGRES_HOSTNAME:-postgres}
export POSTGRES_PORT=${POSTGRES_PORT:-5432}
export POSTGRES_DATABASE=${POSTGRES_DATABASE:-guacamole_db}
export POSTGRES_USER=${POSTGRES_USER:-guacamole}
export POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-}
export POSTGRES_DRIVER=${POSTGRES_DRIVER:-org.postgresql.Driver}
export POSTGRES_MAX_CONNECTIONS=${POSTGRES_MAX_CONNECTIONS:-10}
export POSTGRES_MAX_IDLE_TIME=${POSTGRES_MAX_IDLE_TIME:-600}
export POSTGRES_CONNECTION_TIMEOUT=${POSTGRES_CONNECTION_TIMEOUT:-30}

# Configuration LDAP
export LDAP_HOSTNAME=${LDAP_HOSTNAME:-}
export LDAP_PORT=${LDAP_PORT:-389}
export LDAP_ENCRYPTION_METHOD=${LDAP_ENCRYPTION_METHOD:-none}
export LDAP_USER_BASE_DN=${LDAP_USER_BASE_DN:-}
export LDAP_USERNAME_ATTRIBUTE=${LDAP_USERNAME_ATTRIBUTE:-uid}
export LDAP_GROUP_BASE_DN=${LDAP_GROUP_BASE_DN:-}
export LDAP_SEARCH_BIND_DN=${LDAP_SEARCH_BIND_DN:-}
export LDAP_SEARCH_BIND_PASSWORD=${LDAP_SEARCH_BIND_PASSWORD:-}
export LDAP_CONFIG_BASE_DN=${LDAP_CONFIG_BASE_DN:-}
export LDAP_MAX_SEARCH_RESULTS=${LDAP_MAX_SEARCH_RESULTS:-1000}
export LDAP_OPERATION_TIMEOUT=${LDAP_OPERATION_TIMEOUT:-30}
export LDAP_FOLLOW_REFERRALS=${LDAP_FOLLOW_REFERRALS:-false}
export LDAP_USER_SEARCH_FILTER=${LDAP_USER_SEARCH_FILTER:-}
export LDAP_GROUP_NAME_ATTRIBUTE=${LDAP_GROUP_NAME_ATTRIBUTE:-cn}
export LDAP_MEMBER_ATTRIBUTE=${LDAP_MEMBER_ATTRIBUTE:-member}

# Configuration OpenID
export OPENID_AUTHORIZATION_ENDPOINT=${OPENID_AUTHORIZATION_ENDPOINT:-}
export OPENID_TOKEN_ENDPOINT=${OPENID_TOKEN_ENDPOINT:-}
export OPENID_JWKS_ENDPOINT=${OPENID_JWKS_ENDPOINT:-}
export OPENID_ISSUER=${OPENID_ISSUER:-}
export OPENID_CLIENT_ID=${OPENID_CLIENT_ID:-}
export OPENID_CLIENT_SECRET=${OPENID_CLIENT_SECRET:-}
export OPENID_REDIRECT_URI=${OPENID_REDIRECT_URI:-}
export OPENID_SCOPE=${OPENID_SCOPE:-openid profile email}
export OPENID_USERNAME_CLAIM_TYPE=${OPENID_USERNAME_CLAIM_TYPE:-preferred_username}
export OPENID_GROUPS_CLAIM_TYPE=${OPENID_GROUPS_CLAIM_TYPE:-groups}
export OPENID_MAX_TOKEN_VALIDITY=${OPENID_MAX_TOKEN_VALIDITY:-300}
export OPENID_ALLOWED_CLOCK_SKEW=${OPENID_ALLOWED_CLOCK_SKEW:-30}

# Configuration des logs
export LOG_LEVEL=${LOG_LEVEL:-info}
export ENABLE_DEBUG=${ENABLE_DEBUG:-false}
export LOG_FILE=${LOG_FILE:-/var/log/guacamole/guacamole.log}
export LOG_MAX_FILE_SIZE=${LOG_MAX_FILE_SIZE:-10MB}
export LOG_MAX_HISTORY=${LOG_MAX_HISTORY:-7}
export LOG_PATTERN=${LOG_PATTERN:-%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n}

# Paramètres Java/JVM
export JAVA_OPTS=${JAVA_OPTS:-}
export JVM_HEAP_MIN=${JVM_HEAP_MIN:-256m}
export JVM_HEAP_MAX=${JVM_HEAP_MAX:-1g}
export JVM_METASPACE_SIZE=${JVM_METASPACE_SIZE:-128m}
export JVM_MAX_METASPACE_SIZE=${JVM_MAX_METASPACE_SIZE:-256m}
export JVM_DIRECT_MEMORY_SIZE=${JVM_DIRECT_MEMORY_SIZE:-}

# Configuration JMX
export ENABLE_JMX=${ENABLE_JMX:-false}
export JMX_PORT=${JMX_PORT:-9090}
export JMX_HOSTNAME=${JMX_HOSTNAME:-localhost}
export JMX_AUTHENTICATE=${JMX_AUTHENTICATE:-false}
export JMX_SSL=${JMX_SSL:-false}
export JMX_USERNAME=${JMX_USERNAME:-admin}
export JMX_PASSWORD=${JMX_PASSWORD:-admin}

# Configuration Tomcat
export TOMCAT_MAX_THREADS=${TOMCAT_MAX_THREADS:-200}
export TOMCAT_MIN_SPARE_THREADS=${TOMCAT_MIN_SPARE_THREADS:-10}
export TOMCAT_CONNECTION_TIMEOUT=${TOMCAT_CONNECTION_TIMEOUT:-20000}
export TOMCAT_MAX_CONNECTIONS=${TOMCAT_MAX_CONNECTIONS:-10000}
export TOMCAT_ACCEPT_COUNT=${TOMCAT_ACCEPT_COUNT:-100}
export TOMCAT_MAX_HTTP_HEADER_SIZE=${TOMCAT_MAX_HTTP_HEADER_SIZE:-8192}
export TOMCAT_COMPRESSION=${TOMCAT_COMPRESSION:-on}
export TOMCAT_COMPRESSION_MIN_SIZE=${TOMCAT_COMPRESSION_MIN_SIZE:-2048}

# Configuration Guacamole
export GUACD_HOSTNAME=${GUACD_HOSTNAME:-guacd}
export GUACD_PORT=${GUACD_PORT:-4822}
export API_SESSION_TIMEOUT=${API_SESSION_TIMEOUT:-60}
export EXTENSION_PRIORITY=${EXTENSION_PRIORITY:-ldap,openid}
export ENABLE_CLIPBOARD=${ENABLE_CLIPBOARD:-true}
export ENABLE_PRINTING=${ENABLE_PRINTING:-true}
export ENABLE_DRIVE=${ENABLE_DRIVE:-true}
export MAX_CLIPBOARD_LENGTH=${MAX_CLIPBOARD_LENGTH:-262144}

# Configuration de sécurité
export ENABLE_ENVIRONMENT_PROPERTIES=${ENABLE_ENVIRONMENT_PROPERTIES:-true}
export SKIP_IF_UNAVAILABLE=${SKIP_IF_UNAVAILABLE:-postgresql,ldap,openid}
export ALLOWED_LANGUAGES=${ALLOWED_LANGUAGES:-en,fr,de,es}
export ENABLE_WEBSOCKET=${ENABLE_WEBSOCKET:-true}
export ENABLE_HTTP_AUTH=${ENABLE_HTTP_AUTH:-false}
export ENABLE_TOTP=${ENABLE_TOTP:-false}
export ENABLE_DUO=${ENABLE_DUO:-false}

# Configuration cache
export CACHE_ENABLED=${CACHE_ENABLED:-true}
export CACHE_MAX_SIZE=${CACHE_MAX_SIZE:-10000}
export CACHE_TTL=${CACHE_TTL:-600}

# ========================================
# CONFIGURATION JVM
# ========================================

# Construction des options JVM
JVM_OPTIONS="-server"
JVM_OPTIONS="${JVM_OPTIONS} -Xms${JVM_HEAP_MIN}"
JVM_OPTIONS="${JVM_OPTIONS} -Xmx${JVM_HEAP_MAX}"
JVM_OPTIONS="${JVM_OPTIONS} -XX:MetaspaceSize=${JVM_METASPACE_SIZE}"
JVM_OPTIONS="${JVM_OPTIONS} -XX:MaxMetaspaceSize=${JVM_MAX_METASPACE_SIZE}"

# Options de performance
JVM_OPTIONS="${JVM_OPTIONS} -XX:+UseG1GC"
JVM_OPTIONS="${JVM_OPTIONS} -XX:MaxGCPauseMillis=200"
JVM_OPTIONS="${JVM_OPTIONS} -XX:+ParallelRefProcEnabled"
JVM_OPTIONS="${JVM_OPTIONS} -XX:+UseStringDeduplication"

# DirectMemory si spécifié
if [ ! -z "${JVM_DIRECT_MEMORY_SIZE}" ]; then
    JVM_OPTIONS="${JVM_OPTIONS} -XX:MaxDirectMemorySize=${JVM_DIRECT_MEMORY_SIZE}"
fi

# Configuration JMX
if [ "${ENABLE_JMX}" = "true" ]; then
    JVM_OPTIONS="${JVM_OPTIONS} -Dcom.sun.management.jmxremote"
    JVM_OPTIONS="${JVM_OPTIONS} -Dcom.sun.management.jmxremote.port=${JMX_PORT}"
    JVM_OPTIONS="${JVM_OPTIONS} -Dcom.sun.management.jmxremote.rmi.port=${JMX_PORT}"
    JVM_OPTIONS="${JVM_OPTIONS} -Dcom.sun.management.jmxremote.host=${JMX_HOSTNAME}"
    JVM_OPTIONS="${JVM_OPTIONS} -Dcom.sun.management.jmxremote.ssl=${JMX_SSL}"
    JVM_OPTIONS="${JVM_OPTIONS} -Dcom.sun.management.jmxremote.authenticate=${JMX_AUTHENTICATE}"
    
    if [ "${JMX_AUTHENTICATE}" = "true" ]; then
        # Création des fichiers de configuration JMX
        echo "${JMX_USERNAME} ${JMX_PASSWORD}" > /tmp/jmxremote.password
        echo "${JMX_USERNAME} readwrite" > /tmp/jmxremote.access
        chmod 600 /tmp/jmxremote.password /tmp/jmxremote.access
        
        JVM_OPTIONS="${JVM_OPTIONS} -Dcom.sun.management.jmxremote.password.file=/tmp/jmxremote.password"
        JVM_OPTIONS="${JVM_OPTIONS} -Dcom.sun.management.jmxremote.access.file=/tmp/jmxremote.access"
    fi
fi

# Mode debug
if [ "${ENABLE_DEBUG}" = "true" ]; then
    JVM_OPTIONS="${JVM_OPTIONS} -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"
    JVM_OPTIONS="${JVM_OPTIONS} -verbose:gc"
    JVM_OPTIONS="${JVM_OPTIONS} -XX:+PrintGCDetails"
    JVM_OPTIONS="${JVM_OPTIONS} -XX:+PrintGCDateStamps"
    JVM_OPTIONS="${JVM_OPTIONS} -Xloggc:/var/log/guacamole/gc.log"
fi

# Ajout des options Java personnalisées
if [ ! -z "${JAVA_OPTS}" ]; then
    JVM_OPTIONS="${JVM_OPTIONS} ${JAVA_OPTS}"
fi

export JAVA_OPTS="${JVM_OPTIONS}"

# ========================================
# GÉNÉRATION guacamole.properties
# ========================================

cat > ${GUACAMOLE_HOME}/guacamole.properties << EOF
# Configuration générée automatiquement
# $(date)

# Configuration de base
guacd-hostname: ${GUACD_HOSTNAME}
guacd-port: ${GUACD_PORT}
api-session-timeout: ${API_SESSION_TIMEOUT}
extension-priority: ${EXTENSION_PRIORITY}
enable-environment-properties: ${ENABLE_ENVIRONMENT_PROPERTIES}
skip-if-unavailable: ${SKIP_IF_UNAVAILABLE}
allowed-languages: ${ALLOWED_LANGUAGES}
enable-websocket: ${ENABLE_WEBSOCKET}
enable-clipboard-integration: ${ENABLE_CLIPBOARD}
enable-printing: ${ENABLE_PRINTING}
enable-drive: ${ENABLE_DRIVE}
max-clipboard-length: ${MAX_CLIPBOARD_LENGTH}

# Configuration PostgreSQL
postgresql-hostname: ${POSTGRES_HOSTNAME}
postgresql-port: ${POSTGRES_PORT}
postgresql-database: ${POSTGRES_DATABASE}
postgresql-username: ${POSTGRES_USER}
postgresql-password: ${POSTGRES_PASSWORD}
postgresql-driver: ${POSTGRES_DRIVER}
postgresql-max-connections: ${POSTGRES_MAX_CONNECTIONS}
postgresql-max-idle-time: ${POSTGRES_MAX_IDLE_TIME}
postgresql-connection-timeout: ${POSTGRES_CONNECTION_TIMEOUT}
postgresql-default-max-connections: 5
postgresql-default-max-group-connections: 5
postgresql-absolute-max-connections: 0
postgresql-auto-create-accounts: true

EOF

# Configuration LDAP si activée
if [ ! -z "${LDAP_HOSTNAME}" ]; then
    cat >> ${GUACAMOLE_HOME}/guacamole.properties << EOF
# Configuration LDAP
ldap-hostname: ${LDAP_HOSTNAME}
ldap-port: ${LDAP_PORT}
ldap-encryption-method: ${LDAP_ENCRYPTION_METHOD}
ldap-user-base-dn: ${LDAP_USER_BASE_DN}
ldap-username-attribute: ${LDAP_USERNAME_ATTRIBUTE}
ldap-group-base-dn: ${LDAP_GROUP_BASE_DN}
ldap-search-bind-dn: ${LDAP_SEARCH_BIND_DN}
ldap-search-bind-password: ${LDAP_SEARCH_BIND_PASSWORD}
ldap-config-base-dn: ${LDAP_CONFIG_BASE_DN}
ldap-max-search-results: ${LDAP_MAX_SEARCH_RESULTS}
ldap-operation-timeout: ${LDAP_OPERATION_TIMEOUT}
ldap-follow-referrals: ${LDAP_FOLLOW_REFERRALS}
ldap-user-search-filter: ${LDAP_USER_SEARCH_FILTER}
ldap-group-name-attribute: ${LDAP_GROUP_NAME_ATTRIBUTE}
ldap-member-attribute: ${LDAP_MEMBER_ATTRIBUTE}

EOF
fi

# Configuration OpenID si activée
if [ ! -z "${OPENID_AUTHORIZATION_ENDPOINT}" ]; then
    cat >> ${GUACAMOLE_HOME}/guacamole.properties << EOF
# Configuration OpenID
openid-authorization-endpoint: ${OPENID_AUTHORIZATION_ENDPOINT}
openid-token-endpoint: ${OPENID_TOKEN_ENDPOINT}
openid-jwks-endpoint: ${OPENID_JWKS_ENDPOINT}
openid-issuer: ${OPENID_ISSUER}
openid-client-id: ${OPENID_CLIENT_ID}
openid-client-secret: ${OPENID_CLIENT_SECRET}
openid-redirect-uri: ${OPENID_REDIRECT_URI}
openid-scope: ${OPENID_SCOPE}
openid-username-claim-type: ${OPENID_USERNAME_CLAIM_TYPE}
openid-groups-claim-type: ${OPENID_GROUPS_CLAIM_TYPE}
openid-max-token-validity: ${OPENID_MAX_TOKEN_VALIDITY}
openid-allowed-clock-skew: ${OPENID_ALLOWED_CLOCK_SKEW}

EOF
fi

# Configuration HTTP Auth si activée
if [ "${ENABLE_HTTP_AUTH}" = "true" ]; then
    cat >> ${GUACAMOLE_HOME}/guacamole.properties << EOF
# Configuration HTTP Authentication
http-auth-enabled: true
http-auth-header: REMOTE_USER

EOF
fi

# Configuration TOTP si activée
if [ "${ENABLE_TOTP}" = "true" ]; then
    cat >> ${GUACAMOLE_HOME}/guacamole.properties << EOF
# Configuration TOTP
totp-issuer: Guacamole
totp-digits: 6
totp-period: 30
totp-mode: sha1

EOF
fi

# ========================================
# CONFIGURATION LOGBACK
# ========================================

# Détermination du niveau de log
LOG_LEVEL_UPPER=$(echo ${LOG_LEVEL} | tr '[:lower:]' '[:upper:]')
if [ "${ENABLE_DEBUG}" = "true" ]; then
    LOG_LEVEL_UPPER="DEBUG"
fi

cat > ${GUACAMOLE_HOME}/logback.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <!-- Console Appender -->
    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>${LOG_PATTERN}</pattern>
        </encoder>
    </appender>

    <!-- File Appender -->
    <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>${LOG_FILE}</file>
        <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
            <fileNamePattern>${LOG_FILE}.%d{yyyy-MM-dd}.gz</fileNamePattern>
            <maxHistory>${LOG_MAX_HISTORY}</maxHistory>
        </rollingPolicy>
        <triggeringPolicy class="ch.qos.logback.core.rolling.SizeBasedTriggeringPolicy">
            <maxFileSize>${LOG_MAX_FILE_SIZE}</maxFileSize>
        </triggeringPolicy>
        <encoder>
            <pattern>${LOG_PATTERN}</pattern>
        </encoder>
    </appender>

    <!-- Niveaux de log par package -->
    <logger name="org.apache.guacamole" level="${LOG_LEVEL_UPPER}"/>
    <logger name="org.apache.guacamole.auth" level="${LOG_LEVEL_UPPER}"/>
    <logger name="org.apache.guacamole.tunnel" level="${LOG_LEVEL_UPPER}"/>
    
    <!-- Logs spécifiques pour les extensions -->
    <logger name="org.apache.guacamole.auth.ldap" level="${LOG_LEVEL_UPPER}"/>
    <logger name="org.apache.guacamole.auth.openid" level="${LOG_LEVEL_UPPER}"/>
    <logger name="org.apache.guacamole.auth.jdbc" level="${LOG_LEVEL_UPPER}"/>
    
    <!-- Logs pour debugging si activé -->
EOF

if [ "${ENABLE_DEBUG}" = "true" ]; then
    cat >> ${GUACAMOLE_HOME}/logback.xml << EOF
    <logger name="org.apache.ibatis" level="DEBUG"/>
    <logger name="org.mybatis" level="DEBUG"/>
    <logger name="com.google" level="DEBUG"/>
    <logger name="org.apache.directory" level="DEBUG"/>
    <logger name="org.postgresql" level="DEBUG"/>
EOF
fi

cat >> ${GUACAMOLE_HOME}/logback.xml << EOF

    <!-- Root Logger -->
    <root level="${LOG_LEVEL_UPPER}">
        <appender-ref ref="CONSOLE"/>
        <appender-ref ref="FILE"/>
    </root>
</configuration>
EOF

# ========================================
# CONFIGURATION TOMCAT
# ========================================

# Configuration server.xml si nécessaire
if [ -f /usr/local/tomcat/conf/server.xml ]; then
    # Backup du fichier original
    cp /usr/local/tomcat/conf/server.xml /usr/local/tomcat/conf/server.xml.bak
    
    # Mise à jour des paramètres du connecteur
    sed -i "s/maxThreads=\"[0-9]*\"/maxThreads=\"${TOMCAT_MAX_THREADS}\"/g" /usr/local/tomcat/conf/server.xml
    sed -i "s/minSpareThreads=\"[0-9]*\"/minSpareThreads=\"${TOMCAT_MIN_SPARE_THREADS}\"/g" /usr/local/tomcat/conf/server.xml
    sed -i "s/connectionTimeout=\"[0-9]*\"/connectionTimeout=\"${TOMCAT_CONNECTION_TIMEOUT}\"/g" /usr/local/tomcat/conf/server.xml
    sed -i "s/maxConnections=\"[0-9]*\"/maxConnections=\"${TOMCAT_MAX_CONNECTIONS}\"/g" /usr/local/tomcat/conf/server.xml
    sed -i "s/acceptCount=\"[0-9]*\"/acceptCount=\"${TOMCAT_ACCEPT_COUNT}\"/g" /usr/local/tomcat/conf/server.xml
    sed -i "s/maxHttpHeaderSize=\"[0-9]*\"/maxHttpHeaderSize=\"${TOMCAT_MAX_HTTP_HEADER_SIZE}\"/g" /usr/local/tomcat/conf/server.xml
    sed -i "s/compression=\"[a-z]*\"/compression=\"${TOMCAT_COMPRESSION}\"/g" /usr/local/tomcat/conf/server.xml
    sed -i "s/compressionMinSize=\"[0-9]*\"/compressionMinSize=\"${TOMCAT_COMPRESSION_MIN_SIZE}\"/g" /usr/local/tomcat/conf/server.xml
fi

# ========================================
# COPIE DES EXTENSIONS
# ========================================

# Activation des extensions
cp /opt/guacamole/extensions/*.jar ${GUACAMOLE_HOME}/extensions/ 2>/dev/null || true

# ========================================
# AFFICHAGE DE LA CONFIGURATION
# ========================================

echo "========================================="
echo "Configuration Guacamole appliquée:"
echo "========================================="
echo "Mode Debug: ${ENABLE_DEBUG}"
echo "Niveau de log: ${LOG_LEVEL_UPPER}"
echo "JVM Heap: ${JVM_HEAP_MIN} - ${JVM_HEAP_MAX}"
echo "JMX activé: ${ENABLE_JMX}"
echo "Extensions activées: ${EXTENSION_PRIORITY}"
echo "PostgreSQL: ${POSTGRES_HOSTNAME}:${POSTGRES_PORT}/${POSTGRES_DATABASE}"
if [ ! -z "${LDAP_HOSTNAME}" ]; then
    echo "LDAP: ${LDAP_HOSTNAME}:${LDAP_PORT}"
fi
if [ ! -z "${OPENID_AUTHORIZATION_ENDPOINT}" ]; then
    echo "OpenID: ${OPENID_ISSUER}"
fi
echo "========================================="

# Lancement de l'application
exec /opt/guacamole/bin/start.sh "$@"