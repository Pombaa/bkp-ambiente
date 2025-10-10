#!/bin/bash

################################################################################
# Script de Backup de Dotfiles e Configurações Visuais
# Autor: Criado para backup de ambiente Arch Linux + bspwm
# Data: $(date +%Y-%m-%d)
#
# ATENÇÃO: Este script foca APENAS em configurações visuais e de usuário.
# NÃO inclui lista de pacotes do sistema nem arquivos de /etc.
#
# RESTAURAÇÃO (após instalar pacotes base na nova máquina):
# 1. Extrair o backup: tar -xzf meu_ambiente_backup_YYYY-MM-DD.tar.gz -C ~
# 2. Configurar tema de ícones: papirus-folders -C violet --theme Papirus
################################################################################

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Nome do arquivo de backup com data atual
BACKUP_NAME="meu_ambiente_backup_$(date +%Y-%m-%d).tar.gz"
BACKUP_DIR="$HOME/bkp-ambiente"

# Criar diretório de backup se não existir
mkdir -p "$BACKUP_DIR"

# Caminho completo do backup
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Iniciando Backup de Configurações do Ambiente${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Array com os itens para backup (caminhos relativos à home)
ITEMS=(
    # Configurações de aplicativos visuais
    ".config/bspwm"
    ".config/sxhkd"
    ".config/polybar"
    ".config/rofi"
    ".config/picom"
    ".config/dunst"
    ".config/alacritty"
    ".config/kitty"
    
    # Tema e aparência
    ".config/gtk-3.0/settings.ini"
    ".config/gtk-4.0"
    ".gtkrc-2.0"
    ".themes"
    ".icons"
    ".local/share/fonts"
    
    # Arquivos do shell
    ".bashrc"
    ".zshrc"
    ".profile"
    ".shell.pre-oh-my-zsh"
    
    # Configurações adicionais úteis
    ".config/betterlockscreen"
    ".config/btop"
    ".config/fastfetch"
    ".config/neofetch"
    ".config/spicetify"
    ".config/redshift"
    ".config/Thunar"
    ".config/xfce4"
    ".config/viewnior"
    ".config/qimgv"
    ".tmux.conf"
    ".gitconfig"
    
    # Papéis de parede
    "Pictures/Wallpapers"
    
    # Scripts personalizados (opcional - comente se não quiser)
    # "scripts"
    # ".local/bin"
)

# Verificar quais itens existem
EXISTING_ITEMS=()
echo -e "${YELLOW}Verificando arquivos e diretórios...${NC}"
echo ""

for item in "${ITEMS[@]}"; do
    if [ -e "$HOME/$item" ]; then
        EXISTING_ITEMS+=("$item")
        echo -e "${GREEN}✓${NC} $item"
    else
        echo -e "${YELLOW}⊘${NC} $item (não encontrado, será ignorado)"
    fi
done

echo ""
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}Criando arquivo de backup...${NC}"
echo ""

# Criar o backup usando tar com caminhos relativos
# -C "$HOME" muda para o diretório home antes de arquivar
# -czf cria arquivo compactado com gzip
# -v modo verbose (opcional, pode remover se quiser menos output)

if tar -czf "$BACKUP_PATH" -C "$HOME" "${EXISTING_ITEMS[@]}" 2>/dev/null; then
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Backup concluído com sucesso!${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Arquivo criado: ${GREEN}$BACKUP_PATH${NC}"
    
    # Mostrar tamanho do arquivo
    BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
    echo -e "Tamanho: ${GREEN}$BACKUP_SIZE${NC}"
    echo ""
    
    echo -e "${YELLOW}Para restaurar em outra máquina:${NC}"
    echo -e "1. Instale os pacotes base necessários (bspwm, polybar, etc.)"
    echo -e "2. Execute: ${BLUE}tar -xzf $BACKUP_NAME -C ~${NC}"
    echo -e "3. Configure os ícones: ${BLUE}papirus-folders -C violet --theme Papirus${NC}"
    echo ""
else
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "\033[0;31m✗ Erro ao criar backup!${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    exit 1
fi
