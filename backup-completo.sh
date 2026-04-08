#!/bin/bash

# ============================================================================
# SCRIPT DE BACKUP COMPLETO DO AMBIENTE
# ============================================================================
# Este script cria um backup completo e seguro do ambiente Linux, incluindo:
# - Configurações de usuário (~/.config, dotfiles)
# - Chaves SSH e GPG
# - Listas de pacotes instalados (Pacman, AUR, Flatpak)
# - Configurações seguras do sistema (/etc)
# - Temas, ícones e fontes
#
# EXCLUI por segurança:
# - Arquivos críticos de hardware (/etc/fstab, xorg.conf, udev)
# - Apps com contas logadas (Discord, Chrome, Spotify, VSCode, etc.)
# - Caches, logs e arquivos temporários
# ============================================================================

# Configurações de segurança do Bash
set -euo pipefail  # Para na primeira falha, variáveis não definidas causam erro
umask 077          # Arquivos criados serão privados (somente dono)

# ============================================================================
# VALIDAÇÃO DE PRIVILÉGIOS E HOME DO USUÁRIO
# ============================================================================
# IMPORTANTE: Este script DEVE ser executado como usuário comum (não root)
# Se alguém tentar usar sudo, o script detecta e re-executa como o 
# usuário real para garantir que o backup vai para o local correto.
#
# Por exemplo:
#   $ sudo ./backup-completo.sh
#   Script vai detectar SUDO_USER, descobrir sua home real, e re-executar como ele
#
# Por que isso importa?
#   - Se rodar como root, a variável $HOME vira /root (errado!)
#   - Backup precisaria vir de /root em vez de /home/usuário (ruim!)
#   - Isso previne acidentes e garante que a home correta seja backupeada
# ============================================================================

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [[ -z "$REAL_HOME" ]]; then
            echo "❌ Não foi possível identificar a home do usuário $SUDO_USER." >&2
            exit 1
        fi

        echo "⚠️  Script iniciado com sudo. Reexecutando como $SUDO_USER para usar a home correta..."
        exec sudo -H -u "$SUDO_USER" env HOME="$REAL_HOME" USER="$SUDO_USER" bash "$0" "$@"
    fi

    echo "❌ Não execute este script como root." >&2
    echo "❌ Rode com o usuário dono do ambiente; o script pedirá sudo só quando precisar." >&2
    exit 1
fi

TARGET_USER="${USER:-$(id -un)}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

if [[ -z "$TARGET_HOME" || ! -d "$TARGET_HOME" ]]; then
    echo "❌ Não foi possível resolver a home do usuário $TARGET_USER." >&2
    exit 1
fi

BACKUP_ROOT_DIR="$TARGET_HOME/bkp-ambiente"

# Verificação de dependências necessárias
if ! command -v rsync >/dev/null 2>&1; then
    echo "❌ É necessário instalar o rsync para executar este script." >&2
    exit 1
fi

# Variáveis de configuração do backup
TIMESTAMP="$(date +%Y-%m-%d)"
BACKUP_NAME="backup-ambiente-$TIMESTAMP"
STAGING_DIR="$BACKUP_ROOT_DIR/$BACKUP_NAME"
BACKUP_LATEST="$BACKUP_ROOT_DIR/backup-ambiente"
ARCHIVE_PATH="$BACKUP_ROOT_DIR/ambiente-completo-$TIMESTAMP.tar.gz"

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

# Função para registrar mensagens com timestamp
log() {
    printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

# Função de limpeza executada ao sair do script (sucesso ou erro)
cleanup() {
    if [[ -n "${STAGING_DIR:-}" && -d "${STAGING_DIR:-}" ]]; then
        rm -rf "$STAGING_DIR"
    fi
}
trap cleanup EXIT

# Função para copiar arquivos/diretórios do usuário com exclusões inteligentes
# Parâmetros:
#   $1 - Caminho origem
#   $2 - Caminho relativo no backup
# 
# EXCLUSÕES AUTOMÁTICAS (para reduzir tamanho e evitar dados sensíveis):
#   - Cache/ (navegadores, aplicativos): gigabytes desnecessários
#   - Logs: informações temporárias que mudam constantemente
#   - node_modules, .git: regeneráveis, ocupam muito espaço
#   - Dados de login (Discord, Chrome, Spotify, VSCode): contêm tokens/sessões
#   - .venv, __pycache__: ambientes de desenvolvimento, regeneráveis
#
# Por que excluir apps com login?
#   - Discord, Chrome, Spotify etc. contêm cookies e tokens
#   - Restaurar esses cookies em máquina nova é INSEGURO
#   - Melhor: deixar usuário fazer login novamente (autentica corretamente)
# ============================================================================
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
            --exclude='discord/' \
            --exclude='google-chrome/' \
            --exclude='chromium/' \
            --exclude='BraveSoftware/' \
            --exclude='Code/' \
            --exclude='VSCodium/' \
            --exclude='spotify/' \
            --exclude='Slack/' \
            --exclude='obsidian/' \
            --exclude='transmission/' \
            --exclude='Postman/' \
            --exclude='Ferdium/' \
            --exclude='TabNine/' \
            --exclude='apidog/' \
            --exclude='beekeeper-studio/' \
            --exclude='YouTube Music/' \
            "$src/" "$dest/"
    else
        log "📄 Copiando $rel"
        mkdir -p "$(dirname "$dest")"
        rsync -a "$src" "$dest"
    fi
}

# Função para copiar arquivos do sistema (/etc) com permissões de superusuário
# Parâmetros:
#   $1 - Caminho origem (geralmente em /etc)
#   $2 - Caminho relativo no backup
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

# ============================================================================
# INÍCIO DO PROCESSO DE BACKUP
# ============================================================================

log "🚀 Iniciando backup completo do ambiente ($BACKUP_NAME)"
log "👤 Usuário de destino: $TARGET_USER"
log "🏠 Home de destino: $TARGET_HOME"
log "📂 Pasta de backup: $BACKUP_ROOT_DIR"

mkdir -p "$BACKUP_ROOT_DIR"

# Verificar espaço disponível (mínimo recomendado: 5GB)
AVAILABLE_SPACE=$(df -BG "$TARGET_HOME" | awk 'NR==2 {print $4}' | sed 's/G//')
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

# ============================================================================
# LISTA DE DIRETÓRIOS E ARQUIVOS A SEREM COPIADOS
# ============================================================================

# Diretórios de configuração importantes do usuário
# Inclui: WM (bspwm), barras (polybar), launchers (rofi), editores, apps GUI, etc.
# EXCLUI: Apps com login (Discord, Chrome, Spotify, VSCode definidos nos --exclude)
CONFIG_DIRS=(
    ".config/.assets"
    ".config/bspwm"
    ".config/sxhkd"
    ".config/polybar"
    ".config/rofi"
    ".config/picom"
    ".config/picom-animations.conf"
    ".config/dunst"
    ".config/alacritty"
    ".config/kitty"
    ".config/terminator"
    ".config/nitrogen"
    ".config/feh"
    ".config/gtk-3.0"
    ".config/gtk-4.0"
    ".config/gtk-2.0"
    ".config/Thunar"
    ".config/xfce4"
    ".config/fontconfig"
    ".config/neofetch"
    ".config/fastfetch"
    ".config/htop"
    ".config/btop"
    ".config/ranger"
    ".config/nvim"
    ".config/vim"
    ".config/eww"
    ".config/betterlockscreen"
    ".config/autostart"
    ".config/menus"
    ".config/systemd"
    ".config/mpv"
    ".config/ibus"
    ".config/VirtualBox"
    ".config/go"
    ".config/spicetify"
    ".config/xnconvert"
    ".config/simple-update-notifier"
    ".config/libreoffice"
    ".config/GIMP"
    ".config/gthumb"
    ".config/qimgv"
    ".config/viewnior"
    ".config/featherpad"
    ".config/sublime-text"
    ".config/filezilla"
    ".config/qBittorrent"
    ".config/redshift"
    ".config/pipewire"
    ".config/wireplumber"
    ".config/gwenviewrc"
    ".config/QtProject.conf"
    ".config/picom-animations.conf"
    ".config/mimeapps.list"
    ".local/bin"
    ".local/scripts-automacao"
    ".local/share/applications"
    ".local/share/icons"
    ".local/share/themes"
    ".local/share/Thunar"
    ".local/share/xfce4"
    ".fonts"
    ".themes"
    ".icons"
    ".screenlayout"
)

# ============================================================================
# SALVAR LISTAS DE TEMAS E ÍCONES DO SISTEMA
# ============================================================================
# Salva uma lista de referência dos temas/ícones instalados em /usr/share
# para facilitar reinstalação posterior

# Copiar temas especiais (Catppuccin, Dracula, etc.)
if [[ -d "/usr/share/themes" ]]; then
    log "🎨 Salvando lista de temas do sistema..."
    ls -1 /usr/share/themes > "$STAGING_DIR/system-themes.txt" 2>/dev/null || true
fi

if [[ -d "/usr/share/icons" ]]; then
    log "🎨 Salvando lista de ícones do sistema..."
    ls -1 /usr/share/icons > "$STAGING_DIR/system-icons.txt" 2>/dev/null || true
fi

# ============================================================================
# COPIAR DOTFILES (arquivos de configuração na raiz do ~)
# ============================================================================

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

# ============================================================================
# EXECUTAR CÓPIAS DE ARQUIVOS E DIRETÓRIOS
# ============================================================================

for dir in "${CONFIG_DIRS[@]}"; do
    copy_path "$TARGET_HOME/$dir" "$dir"
done

for file in "${CONFIG_FILES[@]}"; do
    copy_path "$TARGET_HOME/$file" "$file"
done

# Copiar chaves SSH e GPG (arquivos sensíveis)
copy_path "$TARGET_HOME/.ssh" ".ssh"
copy_path "$TARGET_HOME/.gnupg" ".gnupg"

# ============================================================================
# EXPORTAR CONFIGURAÇÕES DO SISTEMA
# ============================================================================

# Exportar configurações do dconf (GNOME/GTK settings)
if command -v dconf >/dev/null 2>&1; then
    log "🧠 Exportando configurações do dconf..."
    if dconf dump / > "$STAGING_DIR/dconf-settings.ini" 2>/dev/null; then
        log "✅ dconf exportado para dconf-settings.ini"
    else
        log "⚠️  Não foi possível exportar o dconf. Pulando."
        rm -f "$STAGING_DIR/dconf-settings.ini"
    fi
fi

# Salvar lista de aplicativos Flatpak instalados
if command -v flatpak >/dev/null 2>&1; then
    log "📦 Salvando aplicativos Flatpak instalados..."
    if flatpak list --app --columns=application > "$STAGING_DIR/flatpak-apps.txt"; then
        log "✅ Lista de apps Flatpak salva em flatpak-apps.txt"
    else
        log "⚠️  Não foi possível coletar apps Flatpak."
        rm -f "$STAGING_DIR/flatpak-apps.txt"
    fi
fi

# Salvar listas de pacotes instalados via Pacman/Yay
# - pkglist-pacman.txt: Pacotes oficiais dos repos
# - pkglist-aur.txt: Pacotes do AUR
# - pkglist-all.txt: Todos os pacotes (referência completa)
log "📦 Salvando listas de pacotes do Pacman/Yay..."
pacman -Qqen > "$STAGING_DIR/pkglist-pacman.txt"
pacman -Qqem > "$STAGING_DIR/pkglist-aur.txt"
pacman -Qq > "$STAGING_DIR/pkglist-all.txt"

# Salvar serviços do systemd habilitados (para reativar após restauração)
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

# Exportar crontab do usuário (agendamentos de tarefas)
if crontab -l >/dev/null 2>&1; then
    log "⏰ Exportando crontab do usuário..."
    crontab -l > "$STAGING_DIR/crontab.txt"
else
    log "ℹ️ Nenhuma crontab encontrada para o usuário."
fi

# ============================================================================
# COPIAR ARQUIVOS SEGUROS DO /ETC
# ============================================================================
# APENAS arquivos seguros que não quebram o sistema em outra máquina
#
# ⚠️ ARQUIVOS QUE NUNCA SÃO INCLUÍDOS NO BACKUP (E POR QUE):
#
#   1. /etc/fstab
#      POR QUE: Contém mapeamento de discos/partições (específico do hardware)
#      RISCO: Ao restaurar em máquina diferente com discos diferentes = 
#             máquina pode não bootar ou montar partições erradas!
#
#   2. /etc/systemd/system
#      POR QUE: Contém serviços específicos do sistema
#      RISCO: Serviços podem referenciar hardware/pacotes que não existem na nova máquina
#
#   3. /etc/X11/xorg.conf.d
#      POR QUE: Contém configuração de vídeo/GPU (específico do hardware)
#      RISCO: GPU diferente na nova máquina = tela preta ao rebootar!
#
#   4. /etc/udev/rules.d
#      POR QUE: Contém regras de detecção de hardware
#      RISCO: Hardware diferente = comportamento imprevisível de periféricos
#
# REGRA DE OURO: Se o arquivo descreve hardware físico, NÃO é backupeado!
# ============================================================================

log "🧱 Copiando APENAS configurações SEGURAS do /etc..."
# ⚠️ REMOVIDOS: /etc/fstab, /etc/systemd/system, /etc/X11/xorg.conf.d, /etc/udev/rules.d
SYSTEM_PATHS=(
    "/etc/pacman.conf"
    "/etc/makepkg.conf"
    "/etc/hosts"
    "/etc/environment"
    "/etc/php"
    "/etc/httpd"
)

for path in "${SYSTEM_PATHS[@]}"; do
    rel="etc/${path#/etc/}"
    copy_system_path "$path" "$rel"
done

if [[ -d "$STAGING_DIR/etc" ]]; then
    sudo chown -R "$TARGET_USER":"$TARGET_USER" "$STAGING_DIR/etc"
fi

# ============================================================================
# CRIAR ARQUIVO DE METADADOS DO BACKUP
# ============================================================================
# Informações sobre origem do backup para identificação futura

# Get hostname using multiple fallback methods
HOSTNAME_VALUE=""
if [[ -r /proc/sys/kernel/hostname ]]; then
    HOSTNAME_VALUE=$(cat /proc/sys/kernel/hostname 2>/dev/null)
elif command -v uname >/dev/null 2>&1; then
    HOSTNAME_VALUE=$(uname -n 2>/dev/null)
elif [[ -n "$HOSTNAME" ]]; then
    HOSTNAME_VALUE="$HOSTNAME"
elif [[ -r /etc/hostname ]]; then
    HOSTNAME_VALUE=$(cat /etc/hostname 2>/dev/null)
else
    HOSTNAME_VALUE="unknown"
fi

cat > "$STAGING_DIR/backup-metadata.txt" <<EOF
host: ${HOSTNAME_VALUE}
user: $TARGET_USER
home: $TARGET_HOME
timestamp: $TIMESTAMP
archive: $(basename "$ARCHIVE_PATH")
EOF

# ============================================================================
# COMPRIMIR E FINALIZAR BACKUP
# ============================================================================

log "🗂️  Gerando arquivo comprimido $ARCHIVE_PATH"
tar -czf "$ARCHIVE_PATH" -C "$BACKUP_ROOT_DIR" "$BACKUP_NAME"

# ============================================================================
# VERIFICAÇÃO DE SEGURANÇA
# ============================================================================
# Garante que nenhum arquivo perigoso foi incluído por engano

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

# ============================================================================
# FINALIZAR E EXIBIR RESUMO
# ============================================================================

# ============================================================================
# VALIDAÇÃO DE DEPENDÊNCIAS DO BSPWMRC
# ============================================================================
# Verifica se o bspwmrc referencia arquivos que estão sendo backupeados.
# Previne o cenário de restaurar um bspwmrc que depende de arquivos ausentes.

BSPWMRC_FILE="$STAGING_DIR/.config/bspwm/bspwmrc"
if [[ -f "$BSPWMRC_FILE" ]]; then
    log "🔍 Validando dependências do bspwmrc..."
    BSPWM_OK=true

    # Verificar shebang: se usa bash features, deve ter #!/bin/bash
    SHEBANG=$(head -1 "$BSPWMRC_FILE")
    if grep -qE '\(\(|\[\[|source |declare ' "$BSPWMRC_FILE" 2>/dev/null; then
        if [[ "$SHEBANG" != *"bash"* ]]; then
            log "⚠️  bspwmrc usa sintaxe bash mas tem shebang '$SHEBANG' — pode falhar!"
            BSPWM_OK=false
        fi
    fi

    # Verificar se .config/.assets foi backupeado (tema)
    if grep -q '\.assets' "$BSPWMRC_FILE" 2>/dev/null; then
        if [[ ! -d "$STAGING_DIR/.config/.assets" ]]; then
            log "⚠️  bspwmrc referencia .config/.assets mas este NÃO foi backupeado!"
            BSPWM_OK=false
        fi
    fi

    # Verificar se .screenlayout foi backupeado
    if grep -q '\.screenlayout' "$BSPWMRC_FILE" 2>/dev/null; then
        if [[ ! -d "$STAGING_DIR/.screenlayout" ]]; then
            log "⚠️  bspwmrc referencia .screenlayout mas este NÃO foi backupeado!"
            log "   Certifique-se de ter guards (if [[ -x ... ]]) no bspwmrc."
        fi
    fi

    # Verificar sintaxe bash
    if [[ "$SHEBANG" == *"bash"* ]]; then
        if ! bash -n "$BSPWMRC_FILE" 2>/dev/null; then
            log "❌ bspwmrc tem erros de sintaxe!"
            bash -n "$BSPWMRC_FILE" 2>&1 | head -5 | while read -r line; do log "   $line"; done
            BSPWM_OK=false
        fi
    fi

    if [[ "$BSPWM_OK" == true ]]; then
        log "✅ bspwmrc validado — dependências OK"
    fi
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
log "ℹ️  Também NÃO inclui (para reduzir tamanho e evitar conflitos):"
log "   - Apps com login: Discord, Chrome, Spotify, VSCode, Postman, Ferdium, etc."
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

# ============================================================================
# REMOVER BACKUPS COM MAIS DE 7 DIAS
# ============================================================================
log "🗑️  Verificando backups antigos (mais de 7 dias)..."
OLD_BACKUPS=$(find "$BACKUP_ROOT_DIR" -maxdepth 1 -name "ambiente-completo-*.tar.gz" -mtime +7 2>/dev/null)

if [[ -n "$OLD_BACKUPS" ]]; then
    while IFS= read -r f; do
        log "   Removendo: $(basename "$f")"
        rm -f "$f"
    done <<< "$OLD_BACKUPS"
    log "✅ Backups antigos removidos."
else
    log "ℹ️  Nenhum backup com mais de 7 dias encontrado."
fi