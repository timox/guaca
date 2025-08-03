#!/bin/bash

# Script de déploiement et gestion Guacamole Docker
# Usage: ./deploy.sh [commande] [options]

set -e

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="guacamole"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"
BACKUP_DIR="./backups"

# Fonctions utilitaires
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier les prérequis
check_requirements() {
    log_info "Vérification des prérequis..."
    
    # Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        exit 1
    fi
    
    # Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose n'est pas installé"
        exit 1
    fi
    
    # Fichier .env
    if [ ! -f "$ENV_FILE" ]; then
        log_warning "Fichier .env non trouvé, création depuis .env.example"
        if [ -f ".env.example" ]; then
            cp .env.example .env
            log_success "Fichier .env créé"
            log_warning "Veuillez éditer le fichier .env avec vos paramètres"
            exit 0
        else
            log_error "Fichier .env.example non trouvé"
            exit 1
        fi
    fi
    
    log_success "Tous les prérequis sont satisfaits"
}

# Installation initiale
install() {
    log_info "Installation de Guacamole Docker..."
    
    check_requirements
    
    # Créer les répertoires nécessaires
    log_info "Création des répertoires..."
    mkdir -p init extensions prometheus grafana/provisioning "$BACKUP_DIR"
    
    # Build des images
    log_info "Construction des images Docker..."
    docker-compose build --no-cache
    
    # Démarrage des services
    log_info "Démarrage des services..."
    docker-compose up -d
    
    # Attendre que les services soient prêts
    log_info "Attente du démarrage des services..."
    sleep 10
    
    # Vérifier le statut
    if docker-compose ps | grep -q "Up"; then
        log_success "Installation terminée avec succès!"
        log_info "Accès Guacamole: http://localhost:8080/guacamole"
        log_info "Login par défaut: guacadmin / guacadmin"
        log_warning "IMPORTANT: Changez le mot de passe par défaut!"
    else
        log_error "Erreur lors du démarrage des services"
        docker-compose logs --tail=50
        exit 1
    fi
}

# Démarrage
start() {
    log_info "Démarrage de Guacamole..."
    docker-compose up -d
    log_success "Services démarrés"
}

# Arrêt
stop() {
    log_info "Arrêt de Guacamole..."
    docker-compose down
    log_success "Services arrêtés"
}

# Redémarrage
restart() {
    log_info "Redémarrage de Guacamole..."
    docker-compose restart
    log_success "Services redémarrés"
}

# Statut
status() {
    log_info "Statut des services:"
    docker-compose ps
}

# Logs
logs() {
    service=${1:-}
    follow=${2:-false}
    
    if [ "$follow" = "true" ]; then
        docker-compose logs -f $service
    else
        docker-compose logs --tail=100 $service
    fi
}

# Backup
backup() {
    log_info "Création d'un backup..."
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_file="${BACKUP_DIR}/guacamole_backup_${timestamp}.sql"
    
    # Backup de la base de données
    docker exec guacamole-postgres pg_dump -U guacamole guacamole_db > "$backup_file"
    
    if [ -f "$backup_file" ]; then
        # Compression
        gzip "$backup_file"
        log_success "Backup créé: ${backup_file}.gz"
        
        # Nettoyer les vieux backups (garder les 10 derniers)
        ls -t ${BACKUP_DIR}/*.gz 2>/dev/null | tail -n +11 | xargs -r rm
    else
        log_error "Échec de la création du backup"
        exit 1
    fi
}

# Restauration
restore() {
    backup_file=$1
    
    if [ -z "$backup_file" ]; then
        log_error "Veuillez spécifier un fichier de backup"
        log_info "Backups disponibles:"
        ls -la ${BACKUP_DIR}/*.gz 2>/dev/null || echo "Aucun backup trouvé"
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        log_error "Fichier de backup non trouvé: $backup_file"
        exit 1
    fi
    
    log_warning "Cette opération va écraser la base de données actuelle!"
    read -p "Êtes-vous sûr? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Restauration annulée"
        exit 0
    fi
    
    log_info "Restauration depuis $backup_file..."
    
    # Décompression si nécessaire
    if [[ "$backup_file" == *.gz ]]; then
        gunzip -c "$backup_file" | docker exec -i guacamole-postgres psql -U guacamole guacamole_db
    else
        docker exec -i guacamole-postgres psql -U guacamole guacamole_db < "$backup_file"
    fi
    
    log_success "Restauration terminée"
}

# Mise à jour
update() {
    log_info "Mise à jour de Guacamole..."
    
    # Backup avant mise à jour
    backup
    
    # Pull des nouvelles images
    log_info "Téléchargement des nouvelles images..."
    docker-compose pull
    
    # Rebuild si nécessaire
    log_info "Reconstruction des images personnalisées..."
    docker-compose build --no-cache
    
    # Redémarrage avec les nouvelles images
    log_info "Redémarrage des services..."
    docker-compose up -d
    
    log_success "Mise à jour terminée"
}

# Mode debug
debug() {
    log_info "Activation du mode debug..."
    
    # Sauvegarder la configuration actuelle
    cp .env .env.backup
    
    # Activer le debug
    sed -i 's/ENABLE_DEBUG=.*/ENABLE_DEBUG=true/' .env
    sed -i 's/LOG_LEVEL=.*/LOG_LEVEL=debug/' .env
    
    # Redémarrer
    restart
    
    log_success "Mode debug activé"
    log_info "Port debug Java: 5005"
    log_info "Pour désactiver: ./deploy.sh debug-off"
}

# Désactiver debug
debug_off() {
    log_info "Désactivation du mode debug..."
    
    # Restaurer la configuration
    if [ -f .env.backup ]; then
        mv .env.backup .env
    else
        sed -i 's/ENABLE_DEBUG=.*/ENABLE_DEBUG=false/' .env
        sed -i 's/LOG_LEVEL=.*/LOG_LEVEL=info/' .env
    fi
    
    # Redémarrer
    restart
    
    log_success "Mode debug désactivé"
}

# Monitoring
monitoring() {
    action=${1:-start}
    
    case $action in
        start)
            log_info "Démarrage du monitoring..."
            docker-compose --profile monitoring up -d
            log_success "Monitoring démarré"
            log_info "Grafana: http://localhost:3000 (admin/admin)"
            log_info "Prometheus: http://localhost:9092"
            ;;
        stop)
            log_info "Arrêt du monitoring..."
            docker-compose --profile monitoring down
            log_success "Monitoring arrêté"
            ;;
        *)
            log_error "Action inconnue: $action"
            log_info "Usage: ./deploy.sh monitoring [start|stop]"
            ;;
    esac
}

# Nettoyage
cleanup() {
    log_warning "Cette opération va supprimer tous les conteneurs, volumes et images!"
    read -p "Êtes-vous sûr? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Nettoyage annulé"
        exit 0
    fi
    
    log_info "Nettoyage complet..."
    
    # Arrêt des services
    docker-compose down -v
    
    # Suppression des images
    docker-compose down --rmi all
    
    # Nettoyage Docker
    docker system prune -af
    
    log_success "Nettoyage terminé"
}

# Test de connexion
test_connection() {
    log_info "Test de connexion aux services..."
    
    # Test Guacamole
    if curl -f http://localhost:8080/guacamole/ &>/dev/null; then
        log_success "Guacamole: OK"
    else
        log_error "Guacamole: ÉCHEC"
    fi
    
    # Test PostgreSQL
    if docker exec guacamole-postgres pg_isready -U guacamole &>/dev/null; then
        log_success "PostgreSQL: OK"
    else
        log_error "PostgreSQL: ÉCHEC"
    fi
    
    # Test Guacd
    if nc -zv localhost 4822 &>/dev/null; then
        log_success "Guacd: OK"
    else
        log_error "Guacd: ÉCHEC"
    fi
}

# Aide
show_help() {
    cat << EOF
${GREEN}Guacamole Docker - Script de déploiement${NC}

${BLUE}Usage:${NC}
    ./deploy.sh [commande] [options]

${BLUE}Commandes disponibles:${NC}
    install         Installation initiale complète
    start           Démarrer tous les services
    stop            Arrêter tous les services
    restart         Redémarrer tous les services
    status          Afficher le statut des services
    logs [service]  Afficher les logs (optionnel: nom du service)
    backup          Créer un backup de la base de données
    restore [file]  Restaurer depuis un backup
    update          Mettre à jour Guacamole
    debug           Activer le mode debug
    debug-off       Désactiver le mode debug
    monitoring      Gérer le monitoring (start|stop)
    test            Tester les connexions
    cleanup         Nettoyer complètement l'installation
    help            Afficher cette aide

${BLUE}Exemples:${NC}
    ./deploy.sh install                    # Installation initiale
    ./deploy.sh logs guacamole            # Voir les logs de Guacamole
    ./deploy.sh backup                    # Créer un backup
    ./deploy.sh restore backup.sql.gz     # Restaurer un backup
    ./deploy.sh monitoring start           # Démarrer Prometheus/Grafana

${BLUE}Variables d'environnement:${NC}
    Éditer le fichier .env pour configurer l'application

${BLUE}Documentation:${NC}
    Voir README.md pour plus d'informations

EOF
}

# Main
main() {
    command=${1:-help}
    shift || true
    
    case $command in
        install)
            install
            ;;
        start)
            start
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        status)
            status
            ;;
        logs)
            logs "$@"
            ;;
        backup)
            backup
            ;;
        restore)
            restore "$@"
            ;;
        update)
            update
            ;;
        debug)
            debug
            ;;
        debug-off)
            debug_off
            ;;
        monitoring)
            monitoring "$@"
            ;;
        test)
            test_connection
            ;;
        cleanup)
            cleanup
            ;;
        help)
            show_help
            ;;
        *)
            log_error "Commande inconnue: $command"
            show_help
            exit 1
            ;;
    esac
}

# Exécution
main "$@"