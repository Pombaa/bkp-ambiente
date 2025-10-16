#!/bin/bash

################################################################################
# Script de Backup de Dotfiles - VERSÃO ESSENCIAL
# Autor: Criado para compartilhar configurações base do ambiente
# Data: $(date +%Y-%m-%d)
#
# FOCO: Configurações essenciais do ambiente (WM, terminal, temas)
# EXCLUI: Aplicativos pessoais (Discord, Chrome, VSCode, Spotify, etc.)
#
# Este backup contém apenas:
# - Window Manager e compositing (bspwm, sxhkd, picom)
# - Interface visual (polybar, rofi, dunst)
# - Terminal (alacritty, kitty, tmux)
# - Temas GTK e ícones
# - Shell configs (bash, zsh)
# - Utilitários de sistema (btop, fastfetch, neofetch)
#
# RESTAURAÇÃO (após instalar pacotes base na nova máquina):
# 1. Extrair o backup: tar -xzf dotfiles_essencial_YYYY-MM-DD.tar.gz -C ~
# 2. Configurar tema de ícones: papirus-folders -C violet --theme Papirus
################################################################################

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Nome do arquivo de backup com data atual
BACKUP_NAME="dotfiles_essencial_$(date +%Y-%m-%d).tar.gz"
BACKUP_DIR="$HOME/bkp-ambiente/dots-simplificado"

# Criar diretório de backup se não existir
mkdir -p "$BACKUP_DIR"

# Caminho completo do backup
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Iniciando Backup de Configurações do Ambiente${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Array com os itens para backup (caminhos relativos à home)
# APENAS configurações ESSENCIAIS do ambiente
ITEMS=(
    # ═══════════════════════════════════════════════════════
    # WINDOW MANAGER E COMPOSITING
    # ═══════════════════════════════════════════════════════
    ".config/bspwm"
    ".config/sxhkd"
    ".config/picom"
    
    # ═══════════════════════════════════════════════════════
    # INTERFACE VISUAL (barra, launcher, notificações)
    # ═══════════════════════════════════════════════════════
    ".config/polybar"
    ".config/rofi"
    ".config/dunst"
    
    # ═══════════════════════════════════════════════════════
    # TERMINAIS
    # ═══════════════════════════════════════════════════════
    ".config/alacritty"
    ".config/kitty"
    ".tmux.conf"
    
    # ═══════════════════════════════════════════════════════
    # TEMAS E APARÊNCIA
    # ═══════════════════════════════════════════════════════
    ".config/gtk-3.0/settings.ini"
    ".config/gtk-4.0"
    ".gtkrc-2.0"
    ".themes"
    ".icons"
    ".local/share/fonts"
    
    # ═══════════════════════════════════════════════════════
    # SHELL E DOTFILES
    # ═══════════════════════════════════════════════════════
    ".bashrc"
    ".zshrc"
    ".profile"
    ".shell.pre-oh-my-zsh"
    
    # ═══════════════════════════════════════════════════════
    # UTILITÁRIOS DE SISTEMA (monitoring, fetch, etc)
    # ═══════════════════════════════════════════════════════
    ".config/btop"
    ".config/fastfetch"
    ".config/neofetch"
    
    # ═══════════════════════════════════════════════════════
    # SISTEMA (lockscreen, redshift, file manager)
    # ═══════════════════════════════════════════════════════
    ".config/betterlockscreen"
    ".config/redshift"
    ".config/Thunar"
    ".config/xfce4"
    
    # ═══════════════════════════════════════════════════════
    # VISUALIZADORES DE IMAGEM
    # ═══════════════════════════════════════════════════════
    ".config/viewnior"
    ".config/qimgv"
    
    # ═══════════════════════════════════════════════════════
    # GIT CONFIG (sem credenciais)
    # ═══════════════════════════════════════════════════════
    ".gitconfig"
    
    # ═══════════════════════════════════════════════════════
    # PAPÉIS DE PAREDE
    # ═══════════════════════════════════════════════════════
    "Pictures/Wallpapers"
    
    # ═══════════════════════════════════════════════════════
    # SCRIPTS PERSONALIZADOS (descomente se necessário)
    # ═══════════════════════════════════════════════════════
    # "scripts"
    # ".local/bin"
)

# ╔═══════════════════════════════════════════════════════════════╗
# ║  APLICATIVOS PESSOAIS EXCLUÍDOS PROPOSITALMENTE:              ║
# ║                                                               ║
# ║  ❌ .config/discord         (Discord)                         ║
# ║  ❌ .config/Code            (VSCode/VSCodium)                 ║
# ║  ❌ .config/google-chrome   (Chrome)                          ║
# ║  ❌ .config/chromium        (Chromium)                        ║
# ║  ❌ .config/BraveSoftware   (Brave)                           ║
# ║  ❌ .config/Slack           (Slack)                           ║
# ║  ❌ .config/spotify         (Spotify/Spicetify configs)       ║
# ║  ❌ .config/obsidian        (Obsidian)                        ║
# ║  ❌ .config/libreoffice     (LibreOffice)                     ║
# ║  ❌ .mozilla                (Firefox profiles)                ║
# ║  ❌ .thunderbird            (Thunderbird)                     ║
# ║  ❌ .ssh                    (Chaves SSH - segurança!)         ║
# ║  ❌ .gnupg                  (Chaves GPG - segurança!)         ║
# ║  ❌ .password-store         (Pass - senhas!)                  ║
# ║  ❌ .config/rclone          (Cloud configs com tokens)        ║
# ║  ❌ .config/transmission    (Torrent history)                 ║
# ║  ❌ .local/share/*          (Dados de aplicativos)            ║
# ╚═══════════════════════════════════════════════════════════════╝

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
    echo -e "4. Ajuste permissões: ${BLUE}chmod +x ~/.config/bspwm/bspwmrc${NC}"
    echo ""
    echo -e "${GREEN}📦 Backup contém APENAS configurações essenciais do ambiente${NC}"
    echo -e "${GREEN}✓ SEM dados pessoais de aplicativos (Discord, Chrome, etc.)${NC}"
    echo ""
else
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "\033[0;31m✗ Erro ao criar backup!${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    exit 1
fi
