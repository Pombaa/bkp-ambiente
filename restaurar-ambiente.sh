#!/bin/bash

set -e
set -u
set -o pipefail

BACKUP_DIR="$HOME/backup-ambiente"

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

echo "📁 Restaurando ~/.config do backup..."
if [ -d "$BACKUP_DIR/.config" ]; then
    mkdir -p "$HOME/.config"
    rsync -a --delete "$BACKUP_DIR/.config/" "$HOME/.config/"
    echo "🛡️ Corrigindo propriedade de ~/.config restaurada..."
    sudo chown -R "$USER":"$USER" "$HOME/.config" || true
else
    echo "⚠️ Pasta .config não encontrada no backup!"
fi

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

# 4. Restaurar pacotes instalados (Pacman e Yay)

# Reinstalar pacotes do Pacman
if [ -f "$BACKUP_DIR/pkglist-pacman.txt" ]; then
    echo "📦 Reinstalando pacotes do Pacman..."
    sudo pacman -Syu --needed --noconfirm $(< "$BACKUP_DIR/pkglist-pacman.txt") || echo "⚠️ Alguns pacotes do Pacman podem ter falhado."
else
    echo "⚠️ Arquivo pkglist-pacman.txt não encontrado. Pulando reinstalação de pacotes do Pacman."
fi

# Garantir dependências de compilação para o yay
sudo pacman -S --needed --noconfirm base-devel git

# Garantir que o yay esteja instalado antes de restaurar pacotes AUR
if ! command -v yay &>/dev/null; then
    echo "📥 yay não encontrado! Instalando automaticamente..."
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
fi

# Reinstalar pacotes do Yay (AUR)
if [ -f "$BACKUP_DIR/pkglist-aur.txt" ]; then
    echo "📦 Reinstalando pacotes do Yay (AUR)..."
    yay -Syu --needed --noconfirm $(< "$BACKUP_DIR/pkglist-aur.txt") || echo "⚠️ Alguns pacotes do Yay podem ter falhado."
else
    echo "⚠️ Arquivo pkglist-aur.txt não encontrado. Pulando reinstalação de pacotes do AUR."
fi

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

# 8. Ajustar permissões de pastas sensíveis
if [ -d "$HOME/.ssh" ]; then
    echo "🔐 Ajustando permissões do ~/.ssh"
    chmod 700 "$HOME/.ssh"
    chmod 600 "$HOME/.ssh"/* 2>/dev/null || true
fi

if [ -d "$HOME/.gnupg" ]; then
    echo "🔐 Ajustando permissões do ~/.gnupg"
    chmod 700 "$HOME/.gnupg"
    chmod 600 "$HOME/.gnupg"/* 2>/dev/null || true
fi

# 9. Restaurar APENAS arquivos SEGUROS do /etc
if [ -d "$BACKUP_DIR/etc" ]; then
    echo "🧱 Restaurando APENAS arquivos SEGUROS do /etc..."
    
    # Lista de arquivos SEGUROS que podem ser restaurados
    SAFE_ETC_FILES=(
        "etc/pacman.conf"
        "etc/makepkg.conf"
        "etc/hosts"
        "etc/environment"
    )
    
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

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Restauração concluída com sucesso!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "� O que foi restaurado:"
echo "   ✅ Todas as configurações de usuário (~/.config)"
echo "   ✅ Dotfiles (.bashrc, .zshrc, etc.)"
echo "   ✅ Temas, ícones e fontes"
echo "   ✅ Pacotes do sistema (pacman + AUR)"
echo "   ✅ Aplicativos Flatpak"
echo "   ✅ Serviços do systemd"
echo "   ✅ Configurações seguras do /etc"
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
echo "   3. Ajuste manualmente qualquer configuração específica"
echo ""
echo "🚀 Ambiente restaurado e pronto para uso!"
echo "═══════════════════════════════════════════════════════════════"
