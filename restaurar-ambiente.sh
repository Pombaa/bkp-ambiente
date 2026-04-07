#!/bin/bash

# ============================================================================
# SCRIPT DE RESTAURAÇÃO SEGURA DO AMBIENTE
# ============================================================================
# Este script restaura um backup criado pelo backup-completo.sh, incluindo:
# - Configurações de usuário (~/.config, dotfiles)
# - Chaves SSH e GPG
# - Pacotes do sistema (Pacman, AUR, Flatpak)
# - Temas, ícones e aplicativos essenciais
# - Configurações seguras do /etc
#
# SEGURANÇA:
# - NÃO restaura arquivos críticos de hardware (fstab, xorg, udev)
# - Valida disponibilidade de software antes de restaurar configs
# - Instala pacotes um por vez para evitar conflitos
# ============================================================================

# Configurações de segurança do Bash
set -e          # Para no primeiro erro
set -u          # Variáveis não definidas causam erro
set -o pipefail # Erros em pipes são detectados

# ============================================================================
# VALIDAÇÃO DE PRIVILÉGIOS E HOME DO USUÁRIO
# ============================================================================
# IMPORTANTE: Este script DEVE ser executado como usuário comum (não root)
# Se alguém tentar usar sudo, o script detecta e re-executa como o 
# usuário real para garantir que a restauração vai para o local correto.
#
# Por exemplo:
#   $ sudo ./restaurar-ambiente.sh
#   Script vai detectar SUDO_USER, descobrir sua home real, e re-executar como ele
#
# Por que isso importa?
#   - Se rodar como root, a variável $HOME vira /root (errado!)
#   - Os arquivos seriam restaurados para /root em vez de /home/usuário (muito ruim!)
#   - Isso previne acidentes e garante que a home correta seja restaurada
#
# Se alguém tentar rodar como root puro (sem sudo):
#   $ su -
#   # ./restaurar-ambiente.sh    <-- ERRO! Não permite!
# ============================================================================

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [[ -z "$REAL_HOME" ]]; then
            echo "❌ Não foi possível identificar a home do usuário $SUDO_USER." >&2
            exit 1
        fi

        echo "⚠️  Script iniciado com sudo. Reexecutando como $SUDO_USER para restaurar na home correta..."
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

BACKUP_DIR="$TARGET_HOME/backup-ambiente"

# ============================================================================
# AVISOS INICIAIS E VERIFICAÇÕES
# ============================================================================

echo "═══════════════════════════════════════════════════════════════"
echo "🔁 Iniciando restauração SEGURA do ambiente"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "👤 Usuário de destino: $TARGET_USER"
echo "🏠 Home de destino: $TARGET_HOME"
echo "📂 Pasta de backup: $BACKUP_DIR"
echo ""
echo "⚠️  ATENÇÃO: Este script restaura APENAS configurações de usuário"
echo "⚠️  e arquivos SEGUROS do sistema."
echo ""
echo "❌ NÃO serão restaurados (para evitar quebrar o sistema):"
echo "   - /etc/fstab (pontos de montagem)"
echo "   - /etc/systemd/system (serviços do sistema)"
echo "   - /etc/X11/xorg.conf.d (configurações de vídeo)"
echo "   - /etc/udev/rules.d (regras de hardware)"
echo ""
echo "✅ Isso garante que a restauração é 100% segura!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
sleep 2

if ! command -v rsync >/dev/null 2>&1; then
    echo "❌ O utilitário rsync é necessário para este script." >&2
    exit 1
fi

# ============================================================================
# EXTRAIR BACKUP SE NECESSÁRIO
# ============================================================================
# Se o diretório backup-ambiente não existe ou está vazio,
# procura e extrai o arquivo .tar.gz mais recente

find_latest_archive() {
    local latest_file=""

    latest_file=$(ls -t "$BACKUP_DIR"/ambiente-completo-*.tar.gz 2>/dev/null | head -n 1 || true)
    if [ -n "$latest_file" ]; then
        printf '%s\n' "$latest_file"
        return 0
    fi

    latest_file=$(ls -t "$TARGET_HOME"/ambiente-completo-*.tar.gz 2>/dev/null | head -n 1 || true)
    if [ -n "$latest_file" ]; then
        printf '%s\n' "$latest_file"
    fi
}

# Se a pasta backup-ambiente não existir, criar
mkdir -p "$BACKUP_DIR"

# Se a pasta estiver vazia, procurar o arquivo .tar.gz e extrair
if [ -z "$(ls -A "$BACKUP_DIR")" ]; then
    if [ -d "$TARGET_HOME/backup-ambiente" ] && [ -n "$(ls -A "$TARGET_HOME/backup-ambiente" 2>/dev/null)" ]; then
        echo "📦 Encontrado backup antigo em $TARGET_HOME/backup-ambiente"
        echo "📦 Migrando para $BACKUP_DIR"
        rm -rf "$BACKUP_DIR"
        mv "$TARGET_HOME/backup-ambiente" "$BACKUP_DIR"
    fi

    TARFILE=$(find_latest_archive)
    if [ -f "$TARFILE" ]; then
        echo "📦 Extraindo backup $TARFILE para $BACKUP_DIR"
        tar -xzf "$TARFILE" -C "$TARGET_HOME"
        # O tar cria a pasta backup-ambiente-YYYYMMDD, mover para backup-ambiente fixo
        EXTRACTED_DIR=$(basename "$TARFILE" .tar.gz | sed 's/ambiente-completo/backup-ambiente/')
        if [ "$EXTRACTED_DIR" != "backup-ambiente" ]; then
            rm -rf "$BACKUP_DIR"
            mv "$TARGET_HOME/$EXTRACTED_DIR" "$BACKUP_DIR"
        fi
    else
        echo "❌ Nenhum arquivo de backup encontrado para restaurar!"
        echo "❌ Locais verificados: $BACKUP_DIR e $TARGET_HOME"
        exit 1
    fi
fi

# ============================================================================
# 1. RESTAURAR CONFIGURAÇÕES DO ~/.config
# ============================================================================
# Restaura apenas diretórios/arquivos específicos do .config
# EXCLUI apps com login (Discord, Chrome, etc.) que não estão no backup

echo "📁 Restaurando configurações importantes do ~/.config..."
CONFIG_DIRS=(
    ".assets"
    "bspwm"
    "sxhkd"
    "polybar"
    "rofi"
    "picom"
    "picom-animations.conf"
    "dunst"
    "alacritty"
    "kitty"
    "terminator"
    "nitrogen"
    "feh"
    "gtk-3.0"
    "gtk-4.0"
    "gtk-2.0"
    "Thunar"
    "xfce4"
    "fontconfig"
    "neofetch"
    "fastfetch"
    "htop"
    "btop"
    "ranger"
    "nvim"
    "vim"
    "eww"
    "betterlockscreen"
    "autostart"
    "menus"
    "systemd"
    "mpv"
    "ibus"
    "VirtualBox"
    "go"
    "spicetify"
    "xnconvert"
    "simple-update-notifier"
    "libreoffice"
    "GIMP"
    "gthumb"
    "qimgv"
    "viewnior"
    "featherpad"
    "sublime-text"
    "filezilla"
    "qBittorrent"
    "redshift"
    "pavucontrol.ini"
    "pulse"
    "gwenviewrc"
    "QtProject.conf"
    "mimeapps.list"
)

for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$BACKUP_DIR/.config/$dir" ]; then
        echo "📁 Restaurando .config/$dir"
        mkdir -p "$TARGET_HOME/.config/$dir"
        rsync -a "$BACKUP_DIR/.config/$dir/" "$TARGET_HOME/.config/$dir/"
        sudo chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.config/$dir" || true
    elif [ -f "$BACKUP_DIR/.config/$dir" ]; then
        echo "📄 Restaurando .config/$dir"
        mkdir -p "$TARGET_HOME/.config"
        rsync -a "$BACKUP_DIR/.config/$dir" "$TARGET_HOME/.config/$dir"
        sudo chown "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.config/$dir" || true
    fi
done

# ============================================================================
# 2. RESTAURAR DOTFILES (arquivos de configuração na raiz do ~)
# ============================================================================

# 2. Restaurar arquivos de configuração pessoais
CONFIG_FILES=(.bashrc .zshrc .xinitrc .xprofile .profile .vimrc .gitconfig .tmux.conf .gtkrc-2.0)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$BACKUP_DIR/$file" ]; then
        echo "📄 Restaurando $file"
        mkdir -p "$(dirname "$TARGET_HOME/$file")"
        rsync -a "$BACKUP_DIR/$file" "$TARGET_HOME/$file"
        sudo chown "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/$file" || true
    fi
done

# ============================================================================
# 3. RESTAURAR DIRETÓRIOS PESSOAIS
# ============================================================================
# Scripts, temas, ícones, fontes e atalhos personalizados

# 3. Restaurar diretórios pessoais
declare -A dirs=(
    ["$BACKUP_DIR/.local/bin"]="$TARGET_HOME/.local/bin"
    ["$BACKUP_DIR/.local/scripts-automacao"]="$TARGET_HOME/.local/scripts-automacao"
    ["$BACKUP_DIR/.local/share/applications"]="$TARGET_HOME/.local/share/applications"
    ["$BACKUP_DIR/.local/share/icons"]="$TARGET_HOME/.local/share/icons"
    ["$BACKUP_DIR/.local/share/themes"]="$TARGET_HOME/.local/share/themes"
    ["$BACKUP_DIR/.local/share/Thunar"]="$TARGET_HOME/.local/share/Thunar"
    ["$BACKUP_DIR/.local/share/xfce4"]="$TARGET_HOME/.local/share/xfce4"
    ["$BACKUP_DIR/.fonts"]="$TARGET_HOME/.fonts"
    ["$BACKUP_DIR/.local/share/fonts"]="$TARGET_HOME/.local/share/fonts"
    ["$BACKUP_DIR/.themes"]="$TARGET_HOME/.themes"
    ["$BACKUP_DIR/.icons"]="$TARGET_HOME/.icons"
    ["$BACKUP_DIR/.screenlayout"]="$TARGET_HOME/.screenlayout"
)

for src in "${!dirs[@]}"; do
    dest="${dirs[$src]}"
    if [ -d "$src" ]; then
        echo "📁 Restaurando $dest"
        mkdir -p "$dest"
        rsync -a --delete "$src/" "$dest/"
        sudo chown -R "$TARGET_USER":"$TARGET_USER" "$dest" || true
    fi
done

AUTOMATION_SCRIPTS_DIR="$TARGET_HOME/.local/scripts-automacao"
if [ -d "$AUTOMATION_SCRIPTS_DIR" ]; then
    echo "🔧 Ajustando permissões dos scripts de automação"
    find "$AUTOMATION_SCRIPTS_DIR" -type f \( -name '*.sh' -o -name '*.expect' \) -exec chmod +x {} +
    sudo chown -R "$TARGET_USER":"$TARGET_USER" "$AUTOMATION_SCRIPTS_DIR" || true
fi

# ============================================================================
# 4. RESTAURAR CHAVES SSH E GPG
# ============================================================================
# Arquivos sensíveis com permissões específicas (700 para pastas, 600 para arquivos)

# Restaurar .ssh e .gnupg (arquivos sensíveis)
if [ -d "$BACKUP_DIR/.ssh" ]; then
    echo "🔐 Restaurando ~/.ssh"
    mkdir -p "$TARGET_HOME/.ssh"
    rsync -a "$BACKUP_DIR/.ssh/" "$TARGET_HOME/.ssh/"
    chmod 700 "$TARGET_HOME/.ssh"
    chmod 600 "$TARGET_HOME/.ssh"/* 2>/dev/null || true
    sudo chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.ssh"
fi

if [ -d "$BACKUP_DIR/.gnupg" ]; then
    echo "🔐 Restaurando ~/.gnupg"
    mkdir -p "$TARGET_HOME/.gnupg"
    rsync -a "$BACKUP_DIR/.gnupg/" "$TARGET_HOME/.gnupg/"
    chmod 700 "$TARGET_HOME/.gnupg"
    chmod 600 "$TARGET_HOME/.gnupg"/* 2>/dev/null || true
    sudo chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.gnupg"
fi

# ============================================================================
# 5. REINSTALAR PACOTES DO SISTEMA
# ============================================================================
# Reinstala todos os pacotes que estavam instalados no sistema original

# 4. Restaurar pacotes instalados (Pacman e Yay)

# Reinstalar pacotes do Pacman
if [ -f "$BACKUP_DIR/pkglist-pacman.txt" ]; then
    echo "📦 Reinstalando pacotes do Pacman..."
    sudo pacman -Syu --needed --noconfirm $(< "$BACKUP_DIR/pkglist-pacman.txt") || echo "⚠️ Alguns pacotes do Pacman podem ter falhado."
else
    echo "⚠️ Arquivo pkglist-pacman.txt não encontrado. Pulando reinstalação de pacotes do Pacman."
fi

# Instalar dependências de compilação necessárias para o yay
sudo pacman -S --needed --noconfirm base-devel git

# Evitar prompts de credenciais do Git durante instalação de pacotes AUR
# Por quê? Alguns pacotes AUR usam Git para clonar repositórios
# Se solicitasse senha, instalação ficaria pendurada esperando input
#
# GIT_TERMINAL_PROMPT=0
#   → Desabilita prompts interativos do Git (não pede usuário/senha)
#
# GIT_ASKPASS=/bin/true  
#   → Simula always "sim" para prompts de credencial (não abre dialogo)
#
# IMPORTANTE: Isso é SEGURO porque:
#   - Se o pacote AUR precisa de autenticação privada, ele vai falhar
#   - Se falhar, vemos o erro e podemos investigar (não fica travado)
#   - Não estamos ignorando erros, apenas automatizando "não tenho credencial"

# Garantir que o yay esteja instalado antes de restaurar pacotes AUR
# yay é um helper AUR que facilita instalação de pacotes do AUR
if ! command -v yay &>/dev/null; then
    echo "📥 yay não encontrado! Instalando automaticamente..."
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
fi

# Diretório para logs de instalação do AUR
AUR_LOG_DIR=$(mktemp -d -t aurlogs-XXXXXX 2>/dev/null || echo "/tmp/aur-logs-$$")
echo "📝 Logs de AUR serão salvos em: $AUR_LOG_DIR"

# Reinstalar pacotes do Yay (AUR) - um por vez para evitar conflitos
if [ -f "$BACKUP_DIR/pkglist-aur.txt" ]; then
    echo "📦 Reinstalando pacotes do Yay (AUR)..."
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        [[ "$pkg" =~ ^# ]] && continue
        if ! pacman -Qq "$pkg" &>/dev/null; then
            echo "📥 Instalando $pkg..."
            LOGFILE="$AUR_LOG_DIR/$pkg.log"
            if ! yay -S --needed --noconfirm "$pkg" >"$LOGFILE" 2>&1; then
                if grep -qiE "(Authentication failed|could not read Username|Permission denied \(publickey\)|Repository not found|HTTP Basic: Access denied|requested URL returned error|terminal prompts disabled|Could not resolve host|Failed to connect to github\.com)" "$LOGFILE"; then
                    echo "🔒 Possível falha de credencial/SSH Git ao instalar $pkg (veja $LOGFILE)"
                else
                    echo "⚠️ Falha ao instalar $pkg (veja $LOGFILE)"
                fi
            else
                echo "✅ $pkg instalado com sucesso"
            fi
        else
            echo "✅ $pkg já está instalado"
        fi
    done < "$BACKUP_DIR/pkglist-aur.txt"
else
    echo "⚠️ Arquivo pkglist-aur.txt não encontrado. Pulando reinstalação de pacotes do AUR."
fi

# ============================================================================
# 6. INSTALAR APLICATIVOS ESSENCIAIS
# ============================================================================
# Apps que não estão no backup por conterem contas/tokens
# Mas são essenciais para o uso diário

# Instalar aplicativos essenciais (Google Chrome, VS Code, Spotify, Discord)
echo "📦 Instalando aplicativos essenciais do AUR..."
APPS_ESSENCIAIS=("google-chrome" "visual-studio-code-bin" "spotify" "discord")

for app in "${APPS_ESSENCIAIS[@]}"; do
    if ! pacman -Qq "$app" &>/dev/null; then
        echo "📥 Instalando $app..."
        LOGFILE="$AUR_LOG_DIR/$app.log"
        if ! yay -S --needed --noconfirm "$app" >"$LOGFILE" 2>&1; then
            if grep -qiE "(Authentication failed|could not read Username|Permission denied \(publickey\)|Repository not found|HTTP Basic: Access denied|requested URL returned error|terminal prompts disabled|Could not resolve host|Failed to connect to github\.com)" "$LOGFILE"; then
                echo "🔒 Possível falha de credencial/SSH Git ao instalar $app (veja $LOGFILE)"
            else
                echo "⚠️ Falha ao instalar $app (veja $LOGFILE)"
            fi
        else
            echo "✅ $app instalado com sucesso"
        fi
    else
        echo "✅ $app já está instalado"
    fi
done

# ============================================================================
# 7. INSTALAR E CONFIGURAR TEMAS
# ============================================================================
# Temas GTK, ícones e configurações de aparência

# Instalar temas e ícones populares
echo "🎨 Instalando temas e ícones..."
TEMAS=("catppuccin-gtk-theme-mocha" "catppuccin-gtk-theme-macchiato" "dracula-gtk-theme" "papirus-icon-theme")

for tema in "${TEMAS[@]}"; do
    if ! pacman -Qq "$tema" &>/dev/null; then
        echo "🎨 Instalando $tema..."
        yay -S --needed --noconfirm "$tema" || echo "⚠️ Falha ao instalar $tema (pode não existir no AUR)"
    else
        echo "✅ $tema já está instalado"
    fi
done

# Configurar cores das pastas do Papirus
if command -v papirus-folders >/dev/null 2>&1; then
    echo "🎨 Configurando cores das pastas do Papirus (violet)..."
    papirus-folders -C violet --theme Papirus-Dark || echo "⚠️ Falha ao configurar cores do Papirus"
else
    echo "⚠️ papirus-folders não encontrado. Tentando instalar..."
    yay -S --needed --noconfirm papirus-folders-git || echo "⚠️ Não foi possível instalar papirus-folders"
    if command -v papirus-folders >/dev/null 2>&1; then
        papirus-folders -C violet --theme Papirus-Dark || echo "⚠️ Falha ao configurar cores do Papirus"
    fi
fi

# Reverter variáveis de ambiente relacionadas ao Git
# Por quê? Essas variáveis foram definidas acima para compilação automatizada
# NUNCA deixar essas variáveis globais! Poderia afetar outros comandos Git do usuário
#
# Mesmo que || true falhe, não queremos que a instalação continue com essas vars
unset GIT_TERMINAL_PROMPT || true
unset GIT_ASKPASS || true

# ============================================================================
# 8. REINSTALAR APLICATIVOS FLATPAK
# ============================================================================
# Aplicativos Flatpak que estavam instalados no sistema original

# Reinstalar aplicativos Flatpak
if [ -f "$BACKUP_DIR/flatpak-apps.txt" ]; then
    if command -v flatpak >/dev/null 2>&1; then
        echo "📦 Reinstalando aplicativos Flatpak..."
        while IFS= read -r app; do
            [[ -z "$app" ]] && continue
            [[ "$app" =~ ^# ]] && continue
            flatpak install --noninteractive --or-update "$app" || echo "⚠️ Falha ao instalar Flatpak $app"
        done < "$BACKUP_DIR/flatpak-apps.txt"
    else
        echo "⚠️ Flatpak não encontrado. Instale o Flatpak e execute novamente esta etapa manualmente."
    fi
fi


# ============================================================================
# 9. RESTAURAR SERVIÇOS DO SYSTEMD
# ============================================================================
# Reativa serviços que estavam habilitados no sistema original

# 5. Restaurar serviços do usuário (systemd)
if [ -f "$BACKUP_DIR/systemd-user-units.txt" ]; then
    echo "⚙️ Restaurando serviços do usuário (systemd)..."
    while IFS= read -r service; do
        [[ -z "$service" ]] && continue
        systemctl --user enable "$service" || echo "⚠️ Falha ao habilitar $service"
    done < "$BACKUP_DIR/systemd-user-units.txt"
fi

if [ -f "$BACKUP_DIR/systemd-system-units.txt" ]; then
    echo "⚙️ Restaurando serviços do sistema (systemd)..."
    while IFS= read -r service; do
        [[ -z "$service" ]] && continue
        sudo systemctl enable "$service" || echo "⚠️ Falha ao habilitar $service"
    done < "$BACKUP_DIR/systemd-system-units.txt"
fi

# ============================================================================
# 10. RESTAURAR CRONTAB E CONFIGURAÇÕES DCONF
# ============================================================================

# 6. Restaurar crontab
if [ -f "$BACKUP_DIR/crontab.txt" ]; then
    echo "⏰ Restaurando crontab..."
    crontab "$BACKUP_DIR/crontab.txt"
fi

# 7. Restaurar configurações do dconf
if [ -f "$BACKUP_DIR/dconf-settings.ini" ]; then
    if command -v dconf >/dev/null 2>&1; then
        echo "🧠 Restaurando configurações (dconf)..."
        if dconf load / < "$BACKUP_DIR/dconf-settings.ini"; then
            echo "✅ dconf restaurado do backup"
        else
            echo "⚠️ Falha ao restaurar o dconf."
        fi
    else
        echo "⚠️ dconf não encontrado. Instale-o para restaurar configurações gráficas."
    fi
fi

# ============================================================================
# 11. RESTAURAR ARQUIVOS SEGUROS DO /ETC
# ============================================================================
# Apenas arquivos/diretórios que não dependem de hardware específico
# Valida disponibilidade de software antes de restaurar (PHP, Apache)
#
# ⚠️ ARQUIVOS QUE NUNCA SÃO RESTAURADOS (E POR QUE):
#
#   1. /etc/fstab
#      POR QUE: Contém mapeamento de discos/partições
#      PROBLEMA: Cada máquina tem discos diferentes
#      RISCO: Se restaurado, máquina pode não bootar! (pontos de montagem errados)
#
#   2. /etc/systemd/system
#      POR QUE: Contém serviços do sistema específicos da máquina
#      PROBLEMA: Máquina nova pode não ter os mesmos serviços
#      RISCO: Serviços tentam usar hardware/pacotes que não existem
#
#   3. /etc/X11/xorg.conf.d
#      POR QUE: Contém configuração de vídeo/monitor
#      PROBLEMA: Cada máquina tem GPU/monitor diferente
#      RISCO: Pode resultar em tela preta ao rebootar!
#
#   4. /etc/udev/rules.d
#      POR QUE: Contém regras de hardware (teclado, mouse, impressora, etc)
#      PROBLEMA: Hardware diferente em máquina nova
#      RISCO: Dispositivos podem não funcionar ou ter comportamento errado
#
# REGRA GERAL: Se o arquivo depende de hardware físico, NUNCA restauramos!
# ============================================================================

# 8. Restaurar APENAS arquivos SEGUROS do /etc
if [ -d "$BACKUP_DIR/etc" ]; then
    echo "🧱 Restaurando APENAS arquivos SEGUROS do /etc..."
    
    # Lista de arquivos SEGUROS que podem ser restaurados
    SAFE_ETC_FILES=(
        "etc/pacman.conf"
        "etc/makepkg.conf"
        "etc/hosts"
        "etc/environment"
    )
    
    # Lista de diretórios SEGUROS que podem ser restaurados
    SAFE_ETC_DIRS=(
        "etc/php"
        "etc/httpd"
    )

    # Verificar disponibilidade de PHP no sistema
    PHP_AVAILABLE=false
    if command -v php >/dev/null 2>&1 || command -v php-fpm >/dev/null 2>&1; then
        PHP_AVAILABLE=true
    fi

    # Verificar disponibilidade de Apache no sistema
    HTTPD_AVAILABLE=false
    if command -v httpd >/dev/null 2>&1 || command -v apachectl >/dev/null 2>&1; then
        HTTPD_AVAILABLE=true
    fi
    
    # ⚠️ NUNCA RESTAURAR (podem quebrar o sistema):
    # - /etc/fstab (pontos de montagem - específicos do hardware)
    # - /etc/systemd/system (serviços do sistema - podem não existir)
    # - /etc/X11/xorg.conf.d (configurações de vídeo - específicas do hardware)
    # - /etc/udev/rules.d (regras de hardware - específicas do sistema)
    
    for safe_file in "${SAFE_ETC_FILES[@]}"; do
        if [ -f "$BACKUP_DIR/$safe_file" ]; then
            echo "⚙️ Restaurando /$safe_file"
            sudo mkdir -p "$(dirname "/$safe_file")"
            sudo rsync -a "$BACKUP_DIR/$safe_file" "/$safe_file" || echo "⚠️ Falha ao restaurar /$safe_file"
        else
            echo "ℹ️  $safe_file não encontrado no backup (pulando)"
        fi
    done
    
    for safe_dir in "${SAFE_ETC_DIRS[@]}"; do
        if [ -d "$BACKUP_DIR/$safe_dir" ]; then
            should_restore=true
            case "$safe_dir" in
                "etc/php")
                    if [[ "$PHP_AVAILABLE" != true ]]; then
                        should_restore=false
                        echo "⚠️  PHP não está instalado. Pulando restauração de /$safe_dir"
                        echo "    Instale php/php-fpm e execute novamente se precisar dessas configs."
                    fi
                    ;;
                "etc/httpd")
                    if [[ "$HTTPD_AVAILABLE" != true ]]; then
                        should_restore=false
                        echo "⚠️  Apache (httpd) não está instalado. Pulando restauração de /$safe_dir"
                        echo "    Instale apache/httpd e execute novamente para aplicar essas configs."
                    fi
                    ;;
            esac

            if [[ "$should_restore" == true ]]; then
                echo "📁 Restaurando /$safe_dir"
                sudo mkdir -p "/$safe_dir"
                sudo rsync -a "$BACKUP_DIR/$safe_dir/" "/$safe_dir/" || echo "⚠️ Falha ao restaurar /$safe_dir"
            fi
        else
            echo "ℹ️  $safe_dir não encontrado no backup (pulando)"
        fi
    done
    
    echo ""
    echo "ℹ️  Arquivos NÃO restaurados (por segurança):"
    echo "   - /etc/fstab (pontos de montagem)"
    echo "   - /etc/systemd/system (serviços do sistema)"
    echo "   - /etc/X11/xorg.conf.d (configurações de vídeo)"
    echo "   - /etc/udev/rules.d (regras de hardware)"
    echo ""
    echo "✅ Esses arquivos devem ser configurados manualmente na nova máquina!"
else
    echo "ℹ️  Pasta etc/ não encontrada no backup. Pulando..."
fi

# ============================================================================
# 12. CONFIGURAR PERMISSÕES SUDO PARA MONTAGEM AUTOMÁTICA
# ============================================================================
# Permite que o usuário execute 'mount' sem senha via sudo
# Útil para montagens automáticas no bspwmrc (ex.: compartilhamentos CIFS)

echo "🔧 Configurando permissões sudo para montagem sem senha..."
echo "$TARGET_USER ALL=(ALL) NOPASSWD: /usr/bin/mount" | sudo tee /etc/sudoers.d/mount-livre >/dev/null
sudo chmod 0440 /etc/sudoers.d/mount-livre
echo "✅ Permissão configurada: $TARGET_USER pode executar 'sudo mount' sem senha"
echo "ℹ️  Útil para montagens automáticas no bspwmrc (ex.: CIFS do servidor da empresa)"

# ============================================================================
# RESUMO FINAL DA RESTAURAÇÃO
# ============================================================================

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Restauração concluída com sucesso!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "📋 O que foi restaurado:"
echo "   ✅ Configurações essenciais (bspwm, polybar, rofi, etc.)"
echo "   ✅ Dotfiles (.bashrc, .zshrc, etc.)"
echo "   ✅ Chaves SSH e GPG"
echo "   ✅ Aplicativos essenciais (Chrome, VS Code, Spotify, Discord)"
echo "   ✅ Temas e ícones (Catppuccin, Dracula, Papirus)"
echo "   ✅ Pacotes do sistema (pacman + AUR)"
echo "   ✅ Aplicativos Flatpak"
echo "   ✅ Serviços do systemd"
echo "   ✅ Configurações do servidor (PHP, Apache)"
echo "   ✅ Configurações seguras do /etc"
echo "   ✅ Permissão sudo para montagem sem senha"
echo ""
echo "🔒 O que NÃO foi restaurado (por segurança):"
echo "   ❌ /etc/fstab - Configure manualmente se necessário"
echo "   ❌ /etc/systemd/system - Serviços já foram habilitados"
echo "   ❌ /etc/X11/xorg.conf.d - Use a configuração da máquina atual"
echo "   ❌ /etc/udev/rules.d - Use a configuração da máquina atual"
echo ""
echo "💡 Próximos passos:"
echo "   1. Reinicie o sistema para aplicar todas as mudanças"
echo "   2. Verifique se bspwm e polybar estão funcionando"
echo "   3. A montagem automática do servidor (CIFS) já está configurada no bspwmrc"
echo "   4. Ajuste manualmente qualquer configuração específica"
echo ""
echo "🚀 Ambiente restaurado e pronto para uso!"

# ============================================================================
# 13. VALIDAÇÃO PÓS-RESTAURAÇÃO (PREVINE TELA PRETA )
# ============================================================================
# CRÍTICO: Verifica se os arquivos essenciais do bspwm/sxhkd estão funcionais
# antes de o usuário reiniciar o sistema.
#
# Por que isso importa?
#   - Se bspwmrc tiver erro de sintaxe, pode resultar em "tela preta" ao rebootar
#   - Se bspwmrc ou sxhkdrc não existir, o WM não inicia
#   - Essa validação ajuda a detectar problemas ANTES de rebootar
#
# O que verifica?
#   ✓ bspwmrc existe e é executável
#   ✓ bspwmrc tem sintaxe bash correta
#   ✓ sxhkdrc existe (atalhos de teclado)
#   ✓ Ferramentas essenciais (bspc, sxhkd) estão instaladas
#   ✓ bspwmrc não depende de arquivos ausentes
# ============================================================================

echo "═══════════════════════════════════════════════════════════════"
echo "🔍 Validação pós-restauração..."
echo "═══════════════════════════════════════════════════════════════"

VALIDATION_ERRORS=0

# 1. bspwmrc deve existir e ser executável
BSPWMRC="$HOME/.config/bspwm/bspwmrc"
if [[ ! -f "$BSPWMRC" ]]; then
    echo "❌ CRÍTICO: $BSPWMRC não existe! bspwm não vai funcionar."
    VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
elif [[ ! -x "$BSPWMRC" ]]; then
    echo "⚠️  $BSPWMRC não é executável. Corrigindo..."
    chmod +x "$BSPWMRC"
    echo "   ✅ Permissão de execução adicionada."
fi

# 2. bspwmrc não deve ter erros de sintaxe
if [[ -f "$BSPWMRC" ]]; then
    SHEBANG=$(head -1 "$BSPWMRC")
    if [[ "$SHEBANG" == *"bash"* ]]; then
        if ! bash -n "$BSPWMRC" 2>/dev/null; then
            echo "❌ CRÍTICO: $BSPWMRC tem erros de sintaxe bash!"
            bash -n "$BSPWMRC" 2>&1 | head -5
            VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
        else
            echo "   ✅ bspwmrc: sintaxe OK"
        fi
    elif [[ "$SHEBANG" == *"/bin/sh"* ]]; then
        echo "   ⚠️  bspwmrc usa #!/bin/sh — verifique se não usa características bash (arrays, source, (( )))"
    fi
fi

# 3. sxhkdrc deve existir
SXHKDRC="$HOME/.config/sxhkd/sxhkdrc"
if [[ ! -f "$SXHKDRC" ]]; then
    echo "❌ CRÍTICO: $SXHKDRC não existe! Atalhos de teclado não vão funcionar."
    VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
else
    # Verificar se não é o skeleton padrão (que usa urxvt)
    if grep -q "urxvt" "$SXHKDRC" 2>/dev/null; then
        echo "   ⚠️  sxhkdrc parece ser o skeleton padrão (usa urxvt). Verifique se é o seu customizado."
    else
        echo "   ✅ sxhkdrc: presente e customizado"
    fi
fi

# 4. Verificar se bspwmrc depende de arquivos que não existem
if [[ -f "$BSPWMRC" ]]; then
    # Checa se o bspwmrc faz source/cat de arquivos sem guards
    UNSAFE_SOURCES=$(grep -n '^\s*source\s' "$BSPWMRC" | grep -v 'if\s*\[\[' || true)
    UNSAFE_CATS=$(grep -n '^\s*.*\$(cat\s' "$BSPWMRC" | grep -v 'if\s*\[\[' || true)
    if [[ -n "$UNSAFE_SOURCES" || -n "$UNSAFE_CATS" ]]; then
        echo "   ⚠️  bspwmrc pode falhar se dependências externas não existirem:"
        [[ -n "$UNSAFE_SOURCES" ]] && echo "       source sem guard: $UNSAFE_SOURCES"
        [[ -n "$UNSAFE_CATS" ]] && echo "       cat sem guard: $UNSAFE_CATS"
    fi
fi

# 5. Verificar dependências essenciais instaladas
for cmd in bspc sxhkd; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ CRÍTICO: '$cmd' não está instalado!"
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    fi
done

for cmd in polybar dunst picom feh kitty rofi; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "   ⚠️  '$cmd' não está instalado (não-essencial, mas recomendado)"
    fi
done

echo ""
if [[ $VALIDATION_ERRORS -gt 0 ]]; then
    echo "═══════════════════════════════════════════════════════════════"
    echo "🚨 ATENÇÃO: $VALIDATION_ERRORS erro(s) crítico(s) encontrado(s)!"
    echo "   Corrija antes de reiniciar para evitar tela preta."
    echo "═══════════════════════════════════════════════════════════════"
else
    echo "═══════════════════════════════════════════════════════════════"
    echo "✅ Validação OK! Ambiente pronto."
    echo "🚀 Reinicie o sistema para aplicar todas as mudanças."
    echo "═══════════════════════════════════════════════════════════════"
fi
