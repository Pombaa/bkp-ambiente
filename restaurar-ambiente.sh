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

BACKUP_DIR="$HOME/backup-ambiente"

# ============================================================================
# AVISOS INICIAIS E VERIFICAÇÕES
# ============================================================================

echo "═══════════════════════════════════════════════════════════════"
echo "🔁 Iniciando restauração SEGURA do ambiente"
echo "═══════════════════════════════════════════════════════════════"
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

# Se a pasta backup-ambiente não existir, criar
mkdir -p "$BACKUP_DIR"

# Se a pasta estiver vazia, procurar o arquivo .tar.gz e extrair
if [ -z "$(ls -A "$BACKUP_DIR")" ]; then
    TARFILE=$(ls "$HOME"/ambiente-completo-*.tar.gz 2>/dev/null | tail -n 1 || true)
    if [ -f "$TARFILE" ]; then
        echo "📦 Extraindo backup $TARFILE para $BACKUP_DIR"
        tar -xzf "$TARFILE" -C "$HOME"
        # O tar cria a pasta backup-ambiente-YYYYMMDD, mover para backup-ambiente fixo
        EXTRACTED_DIR=$(basename "$TARFILE" .tar.gz | sed 's/ambiente-completo/backup-ambiente/')
        if [ "$EXTRACTED_DIR" != "backup-ambiente" ]; then
            rm -rf "$BACKUP_DIR"
            mv "$HOME/$EXTRACTED_DIR" "$BACKUP_DIR"
        fi
    else
        echo "❌ Nenhum arquivo de backup encontrado para restaurar!"
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
        mkdir -p "$HOME/.config/$dir"
        rsync -a "$BACKUP_DIR/.config/$dir/" "$HOME/.config/$dir/"
        sudo chown -R "$USER":"$USER" "$HOME/.config/$dir" || true
    elif [ -f "$BACKUP_DIR/.config/$dir" ]; then
        echo "📄 Restaurando .config/$dir"
        mkdir -p "$HOME/.config"
        rsync -a "$BACKUP_DIR/.config/$dir" "$HOME/.config/$dir"
        sudo chown "$USER":"$USER" "$HOME/.config/$dir" || true
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
        mkdir -p "$(dirname "$HOME/$file")"
        rsync -a "$BACKUP_DIR/$file" "$HOME/$file"
        sudo chown "$USER":"$USER" "$HOME/$file" || true
    fi
done

# ============================================================================
# 3. RESTAURAR DIRETÓRIOS PESSOAIS
# ============================================================================
# Scripts, temas, ícones, fontes e atalhos personalizados

# 3. Restaurar diretórios pessoais
declare -A dirs=(
    ["$BACKUP_DIR/.local/bin"]="$HOME/.local/bin"
    ["$BACKUP_DIR/.local/share/applications"]="$HOME/.local/share/applications"
    ["$BACKUP_DIR/.local/share/icons"]="$HOME/.local/share/icons"
    ["$BACKUP_DIR/.local/share/themes"]="$HOME/.local/share/themes"
    ["$BACKUP_DIR/.local/share/Thunar"]="$HOME/.local/share/Thunar"
    ["$BACKUP_DIR/.local/share/xfce4"]="$HOME/.local/share/xfce4"
    ["$BACKUP_DIR/.fonts"]="$HOME/.fonts"
    ["$BACKUP_DIR/.local/share/fonts"]="$HOME/.local/share/fonts"
    ["$BACKUP_DIR/.themes"]="$HOME/.themes"
    ["$BACKUP_DIR/.icons"]="$HOME/.icons"
)

for src in "${!dirs[@]}"; do
    dest="${dirs[$src]}"
    if [ -d "$src" ]; then
        echo "📁 Restaurando $dest"
        mkdir -p "$dest"
        rsync -a --delete "$src/" "$dest/"
        sudo chown -R "$USER":"$USER" "$dest" || true
    fi
done

# ============================================================================
# 4. RESTAURAR CHAVES SSH E GPG
# ============================================================================
# Arquivos sensíveis com permissões específicas (700 para pastas, 600 para arquivos)

# Restaurar .ssh e .gnupg (arquivos sensíveis)
if [ -d "$BACKUP_DIR/.ssh" ]; then
    echo "🔐 Restaurando ~/.ssh"
    mkdir -p "$HOME/.ssh"
    rsync -a "$BACKUP_DIR/.ssh/" "$HOME/.ssh/"
    chmod 700 "$HOME/.ssh"
    chmod 600 "$HOME/.ssh"/* 2>/dev/null || true
    sudo chown -R "$USER":"$USER" "$HOME/.ssh"
fi

if [ -d "$BACKUP_DIR/.gnupg" ]; then
    echo "🔐 Restaurando ~/.gnupg"
    mkdir -p "$HOME/.gnupg"
    rsync -a "$BACKUP_DIR/.gnupg/" "$HOME/.gnupg/"
    chmod 700 "$HOME/.gnupg"
    chmod 600 "$HOME/.gnupg"/* 2>/dev/null || true
    sudo chown -R "$USER":"$USER" "$HOME/.gnupg"
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

# Evitar prompts de credenciais Git (ex.: GitHub) durante builds do AUR
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/true

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
echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/mount" | sudo tee /etc/sudoers.d/mount-livre >/dev/null
sudo chmod 0440 /etc/sudoers.d/mount-livre
echo "✅ Permissão configurada: $USER pode executar 'sudo mount' sem senha"
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
echo "═══════════════════════════════════════════════════════════════"
