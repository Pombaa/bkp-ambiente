#!/bin/bash

set -euo pipefail

umask 077

if ! command -v rsync >/dev/null 2>&1; then
    echo "❌ É necessário instalar o rsync para executar este script." >&2
    exit 1
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_NAME="backup-ambiente-$TIMESTAMP"
STAGING_DIR="$HOME/$BACKUP_NAME"
BACKUP_LATEST="$HOME/backup-ambiente"
ARCHIVE_PATH="$HOME/ambiente-completo-$TIMESTAMP.tar.gz"

log() {
    printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

cleanup() {
    if [[ -n "${STAGING_DIR:-}" && -d "${STAGING_DIR:-}" ]]; then
        rm -rf "$STAGING_DIR"
    fi
}
trap cleanup EXIT

copy_path() {
    local src="$1"
    local rel="$2"
    local dest="$STAGING_DIR/$rel"

    if [[ ! -e "$src" ]]; then
        log "⚠️  Pulando $rel (não encontrado)"
        return
    fi

    if [[ -d "$src" ]]; then
        log "📁 Copiando $rel"
        mkdir -p "$dest"
        # Excluir caches, logs e arquivos temporários para reduzir tamanho do backup
        rsync -a \
            --exclude='Cache/' \
            --exclude='cache/' \
            --exclude='CachedData/' \
            --exclude='GPUCache/' \
            --exclude='Code Cache/' \
            --exclude='logs/' \
            --exclude='*.log' \
            --exclude='*.tmp' \
            --exclude='.cache/' \
            --exclude='node_modules/' \
            --exclude='.git/' \
            --exclude='*-cache/' \
            --exclude='*.swp' \
            --exclude='*.swo' \
            --exclude='.npm/' \
            --exclude='.yarn/' \
            --exclude='.cargo/registry/' \
            --exclude='.cargo/git/' \
            --exclude='__pycache__/' \
            --exclude='*.pyc' \
            --exclude='.venv/' \
            --exclude='venv/' \
            --exclude='Session Storage/' \
            --exclude='Local Storage/' \
            --exclude='IndexedDB/' \
            --exclude='Service Worker/' \
            "$src/" "$dest/"
    else
        log "📄 Copiando $rel"
        mkdir -p "$(dirname "$dest")"
        rsync -a "$src" "$dest"
    fi
}

copy_system_path() {
    local src="$1"
    local rel="$2"
    local dest="$STAGING_DIR/$rel"

    if [[ ! -e "$src" ]]; then
        log "⚠️  Pulando $rel (não encontrado)"
        return
    fi

    log "🛡️ Copiando $rel"
    sudo mkdir -p "$(dirname "$dest")"
    if [[ -d "$src" ]]; then
        sudo rsync -a "$src/" "$dest/"
    else
        sudo rsync -a "$src" "$dest"
    fi
}

log "🚀 Iniciando backup completo do ambiente ($BACKUP_NAME)"

# Verificar espaço disponível
AVAILABLE_SPACE=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | sed 's/G//')
if [[ $AVAILABLE_SPACE -lt 5 ]]; then
    log "⚠️  AVISO: Espaço em disco baixo (${AVAILABLE_SPACE}GB disponível)"
    log "⚠️  É recomendado ter pelo menos 5GB livres para o backup"
    read -p "Deseja continuar mesmo assim? [s/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        log "❌ Backup cancelado pelo usuário"
        exit 1
    fi
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

CONFIG_DIRS=(
    ".config"
    ".local/bin"
    ".local/share/applications"
    ".local/share/icons"
    ".local/share/themes"
    ".local/share/Thunar"
    ".local/share/xfce4"
    ".fonts"
    ".themes"
    ".icons"
)

CONFIG_FILES=(
    ".bashrc"
    ".zshrc"
    ".xinitrc"
    ".xprofile"
    ".profile"
    ".vimrc"
    ".gitconfig"
    ".tmux.conf"
    ".gtkrc-2.0"
)

for dir in "${CONFIG_DIRS[@]}"; do
    copy_path "$HOME/$dir" "$dir"
done

for file in "${CONFIG_FILES[@]}"; do
    copy_path "$HOME/$file" "$file"
done

copy_path "$HOME/.ssh" ".ssh"
copy_path "$HOME/.gnupg" ".gnupg"

if command -v dconf >/dev/null 2>&1; then
    log "🧠 Exportando configurações do dconf..."
    if dconf dump / > "$STAGING_DIR/dconf-settings.ini" 2>/dev/null; then
        log "✅ dconf exportado para dconf-settings.ini"
    else
        log "⚠️  Não foi possível exportar o dconf. Pulando."
        rm -f "$STAGING_DIR/dconf-settings.ini"
    fi
fi

if command -v flatpak >/dev/null 2>&1; then
    log "📦 Salvando aplicativos Flatpak instalados..."
    if flatpak list --app --columns=application > "$STAGING_DIR/flatpak-apps.txt"; then
        log "✅ Lista de apps Flatpak salva em flatpak-apps.txt"
    else
        log "⚠️  Não foi possível coletar apps Flatpak."
        rm -f "$STAGING_DIR/flatpak-apps.txt"
    fi
fi

log "📦 Salvando listas de pacotes do Pacman/Yay..."
pacman -Qqen > "$STAGING_DIR/pkglist-pacman.txt"
pacman -Qqem > "$STAGING_DIR/pkglist-aur.txt"
pacman -Qq > "$STAGING_DIR/pkglist-all.txt"

if command -v systemctl >/dev/null 2>&1; then
    log "⚙️ Registrando serviços habilitados do usuário..."
    if systemctl --user list-unit-files --state=enabled --no-legend 2>/dev/null | awk '{print $1}' | sort -u > "$STAGING_DIR/systemd-user-units.txt"; then
        log "✅ Serviços de usuário registrados em systemd-user-units.txt"
    else
        log "⚠️  Não foi possível registrar serviços de usuário."
        rm -f "$STAGING_DIR/systemd-user-units.txt"
    fi

    log "⚙️ Registrando serviços habilitados do sistema..."
    if sudo systemctl list-unit-files --state=enabled --no-legend 2>/dev/null | awk '{print $1}' | sort -u > "$STAGING_DIR/systemd-system-units.txt"; then
        log "✅ Serviços do sistema registrados em systemd-system-units.txt"
    else
        log "⚠️  Não foi possível registrar serviços do sistema."
        rm -f "$STAGING_DIR/systemd-system-units.txt"
    fi
fi

if crontab -l >/dev/null 2>&1; then
    log "⏰ Exportando crontab do usuário..."
    crontab -l > "$STAGING_DIR/crontab.txt"
else
    log "ℹ️ Nenhuma crontab encontrada para o usuário."
fi

log "🧱 Copiando APENAS configurações SEGURAS do /etc..."
# ⚠️ REMOVIDOS: /etc/fstab, /etc/systemd/system, /etc/X11/xorg.conf.d, /etc/udev/rules.d
SYSTEM_PATHS=(
    "/etc/pacman.conf"
    "/etc/makepkg.conf"
    "/etc/hosts"
    "/etc/environment"
)

for path in "${SYSTEM_PATHS[@]}"; do
    rel="etc/${path#/etc/}"
    copy_system_path "$path" "$rel"
done

if [[ -d "$STAGING_DIR/etc" ]]; then
    sudo chown -R "$USER":"$USER" "$STAGING_DIR/etc"
fi

cat > "$STAGING_DIR/backup-metadata.txt" <<EOF
host: $(hostname)
user: $USER
timestamp: $TIMESTAMP
archive: $(basename "$ARCHIVE_PATH")
EOF

log "🗜️  Gerando arquivo comprimido $ARCHIVE_PATH"
tar -czf "$ARCHIVE_PATH" -C "$HOME" "$BACKUP_NAME"

# Verificação de segurança: garantir que arquivos perigosos não foram incluídos
log "🔍 Verificando integridade e segurança do backup..."
DANGEROUS_FILES=$(tar -tzf "$ARCHIVE_PATH" | grep -E "etc/(fstab|X11/xorg.conf.d|udev/rules.d|systemd/system)" || true)

if [[ -n "$DANGEROUS_FILES" ]]; then
    log "⚠️  AVISO: Arquivos potencialmente perigosos encontrados no backup!"
    log "⚠️  Isso não deveria acontecer. Lista:"
    echo "$DANGEROUS_FILES" | while read -r file; do
        log "   - $file"
    done
    log ""
    log "⚠️  Recomenda-se revisar o script antes de usar este backup!"
else
    log "✅ Verificação de segurança aprovada - nenhum arquivo perigoso encontrado"
fi

log "🔄 Atualizando diretório base $BACKUP_LATEST"
rm -rf "$BACKUP_LATEST"
mv "$STAGING_DIR" "$BACKUP_LATEST"
STAGING_DIR=""

log "✅ Backup concluído com sucesso!"
log "📦 Arquivo final disponível em: $ARCHIVE_PATH"
log ""
log "ℹ️  Este backup NÃO inclui configurações críticas do sistema como:"
log "   - /etc/fstab (pontos de montagem)"
log "   - /etc/systemd/system (serviços do sistema)"
log "   - /etc/X11/xorg.conf.d (configurações de vídeo)"
log "   - /etc/udev/rules.d (regras de hardware)"
log ""
log "ℹ️  Também NÃO inclui (para reduzir tamanho):"
log "   - Caches de navegadores e aplicativos"
log "   - Arquivos temporários e logs"
log "   - node_modules e .git"
log ""
log "✅ Isso garante que a restauração não quebre o sistema!"
log "✅ E mantém o backup com tamanho otimizado!"
log ""

# Mostrar tamanho do arquivo gerado
if [[ -f "$ARCHIVE_PATH" ]]; then
    BACKUP_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
    log "📊 Tamanho do backup: $BACKUP_SIZE"
fi