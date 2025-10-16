#!/bin/bash

################################################################################
# Script de Restauração de Dotfiles - VERSÃO ESSENCIAL
# Autor: Criado para restauração de ambiente Arch Linux + bspwm
# Data: $(date +%Y-%m-%d)
#
# ATENÇÃO: Execute este script APÓS instalar os pacotes base do sistema
# (bspwm, polybar, picom, rofi, etc.)
#
# Este script restaura APENAS configurações essenciais:
# - Window Manager e compositing
# - Interface visual (polybar, rofi, dunst)
# - Terminal e shell
# - Temas GTK e ícones
# - Utilitários de sistema
#
# NÃO restaura dados pessoais de aplicativos (Discord, Chrome, etc.)
#
# Este script:
# 1. Faz backup dos dotfiles atuais (se existirem)
# 2. Extrai o backup das configurações
# 3. Aplica permissões corretas
# 4. Configura temas e ícones
################################################################################

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Diretório padrão de backups
BACKUP_DIR="$HOME/bkp-ambiente/dots-simplificado"

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Restauração de Configurações Essenciais${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Este script restaura APENAS configurações do ambiente${NC}"
echo -e "${GREEN}SEM dados pessoais de aplicativos (Discord, Chrome, etc.)${NC}"
echo ""

# Função para listar backups disponíveis
list_backups() {
    local backups=()
    local count=1
    
    echo -e "${YELLOW}Backups disponíveis em $BACKUP_DIR:${NC}"
    echo ""
    
    # Procurar arquivos .tar.gz no diretório
    while IFS= read -r -d '' file; do
        local filename=$(basename "$file")
        local size=$(du -h "$file" | cut -f1)
        local date=$(stat -c %y "$file" | cut -d' ' -f1)
        
        backups+=("$file")
        echo -e "${GREEN}[$count]${NC} $filename"
        echo -e "    Tamanho: $size | Data: $date"
        echo ""
        ((count++))
    done < <(find "$BACKUP_DIR" -maxdepth 1 -name "*.tar.gz" -type f -print0 2>/dev/null | sort -z)
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${RED}Nenhum backup encontrado em $BACKUP_DIR${NC}"
        echo ""
        echo -e "${YELLOW}Dica:${NC} Copie seu arquivo de backup para $BACKUP_DIR"
        echo -e "      ou especifique o caminho completo como argumento."
        exit 1
    fi
    
    echo "${backups[@]}"
}

# Função para fazer backup dos dotfiles atuais
backup_current_dotfiles() {
    local backup_name="dotfiles_backup_antigo_$(date +%Y%m%d_%H%M%S).tar.gz"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    echo -e "${YELLOW}Fazendo backup dos dotfiles atuais...${NC}"
    
    local items_to_backup=()
    local configs=(
        ".config/bspwm"
        ".config/sxhkd"
        ".config/polybar"
        ".config/rofi"
        ".config/picom"
        ".config/dunst"
        ".config/alacritty"
        ".config/kitty"
        ".bashrc"
        ".zshrc"
        ".profile"
    )
    
    for item in "${configs[@]}"; do
        if [ -e "$HOME/$item" ]; then
            items_to_backup+=("$item")
        fi
    done
    
    if [ ${#items_to_backup[@]} -gt 0 ]; then
        tar -czf "$backup_path" -C "$HOME" "${items_to_backup[@]}" 2>/dev/null
        echo -e "${GREEN}✓${NC} Backup salvo em: $backup_name"
    else
        echo -e "${YELLOW}⊘${NC} Nenhum dotfile existente para fazer backup"
    fi
    echo ""
}

# Verificar se foi passado um arquivo como argumento
if [ -n "$1" ]; then
    BACKUP_FILE="$1"
    
    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "${RED}✗ Arquivo não encontrado: $BACKUP_FILE${NC}"
        exit 1
    fi
else
    # Listar backups disponíveis
    backups_array=($(list_backups))
    
    if [ ${#backups_array[@]} -eq 1 ]; then
        BACKUP_FILE="${backups_array[0]}"
        echo -e "${YELLOW}Usando o único backup disponível:${NC}"
        echo -e "${GREEN}$(basename "$BACKUP_FILE")${NC}"
        echo ""
    else
        echo -e "${YELLOW}Escolha um backup para restaurar:${NC}"
        read -p "Digite o número [1-${#backups_array[@]}] ou 'q' para sair: " choice
        echo ""
        
        if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
            echo -e "${YELLOW}Operação cancelada.${NC}"
            exit 0
        fi
        
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#backups_array[@]} ]; then
            echo -e "${RED}✗ Opção inválida!${NC}"
            exit 1
        fi
        
        BACKUP_FILE="${backups_array[$((choice-1))]}"
    fi
fi

echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}Arquivo selecionado:${NC} $(basename "$BACKUP_FILE")"
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
echo ""

# Confirmar antes de prosseguir
read -p "$(echo -e ${YELLOW}Deseja continuar com a restauração? [s/N]:${NC} )" confirm
echo ""

if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
    echo -e "${YELLOW}Operação cancelada.${NC}"
    exit 0
fi

# Fazer backup dos dotfiles atuais
backup_current_dotfiles

# Extrair o backup
echo -e "${YELLOW}Extraindo backup para $HOME...${NC}"
echo ""

if tar -xzf "$BACKUP_FILE" -C "$HOME" --keep-newer-files 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Arquivos extraídos com sucesso!"
else
    # Tentar sem a flag --keep-newer-files
    if tar -xzf "$BACKUP_FILE" -C "$HOME" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Arquivos extraídos com sucesso!"
    else
        echo -e "${RED}✗ Erro ao extrair backup!${NC}"
        exit 1
    fi
fi
echo ""

# Aplicar permissões corretas aos scripts do bspwm e sxhkd
echo -e "${YELLOW}Aplicando permissões corretas...${NC}"

if [ -f "$HOME/.config/bspwm/bspwmrc" ]; then
    chmod +x "$HOME/.config/bspwm/bspwmrc"
    echo -e "${GREEN}✓${NC} Permissão aplicada: ~/.config/bspwm/bspwmrc"
fi

if [ -d "$HOME/.config/polybar" ]; then
    find "$HOME/.config/polybar" -type f -name "*.sh" -exec chmod +x {} \;
    echo -e "${GREEN}✓${NC} Permissões aplicadas: scripts do polybar"
fi

if [ -d "$HOME/.config/bspwm" ]; then
    find "$HOME/.config/bspwm" -type f -name "*.sh" -exec chmod +x {} \;
    echo -e "${GREEN}✓${NC} Permissões aplicadas: scripts do bspwm"
fi

echo ""

# Configurar tema de ícones Papirus (se instalado)
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}Configurando temas...${NC}"
echo ""

if command -v papirus-folders &> /dev/null; then
    echo -e "${YELLOW}Configurando ícones Papirus...${NC}"
    papirus-folders -C violet --theme Papirus 2>/dev/null
    echo -e "${GREEN}✓${NC} Tema de ícones Papirus configurado (violet)"
else
    echo -e "${YELLOW}⊘${NC} papirus-folders não instalado"
    echo -e "   Instale com: ${BLUE}yay -S papirus-folders${NC}"
fi

echo ""

# Recarregar configurações do GTK (se possível)
if command -v gsettings &> /dev/null && [ -n "$DISPLAY" ]; then
    echo -e "${YELLOW}Recarregando configurações GTK...${NC}"
    
    # Tentar ler configurações do arquivo gtk-3.0
    if [ -f "$HOME/.config/gtk-3.0/settings.ini" ]; then
        gtk_theme=$(grep "^gtk-theme-name=" "$HOME/.config/gtk-3.0/settings.ini" | cut -d'=' -f2)
        icon_theme=$(grep "^gtk-icon-theme-name=" "$HOME/.config/gtk-3.0/settings.ini" | cut -d'=' -f2)
        
        if [ -n "$gtk_theme" ]; then
            gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" 2>/dev/null
            echo -e "${GREEN}✓${NC} Tema GTK: $gtk_theme"
        fi
        
        if [ -n "$icon_theme" ]; then
            gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" 2>/dev/null
            echo -e "${GREEN}✓${NC} Tema de ícones: $icon_theme"
        fi
    fi
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Restauração concluída com sucesso!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Instruções finais
echo -e "${YELLOW}Próximos passos:${NC}"
echo ""
echo -e "1. ${BLUE}Reinicie o bspwm:${NC}"
echo -e "   Execute: ${GREEN}bspc wm -r${NC}"
echo -e "   Ou faça logout/login"
echo ""
echo -e "2. ${BLUE}Verifique as fontes:${NC}"
echo -e "   Execute: ${GREEN}fc-cache -fv${NC}"
echo ""
echo -e "3. ${BLUE}Se usar Polybar:${NC}"
echo -e "   Reinicie com: ${GREEN}pkill polybar && polybar &${NC}"
echo ""
echo -e "4. ${BLUE}Configurações do shell:${NC}"
echo -e "   Recarregue com: ${GREEN}source ~/.zshrc${NC} (ou ~/.bashrc)"
echo ""

# Oferecer para fazer algumas dessas ações automaticamente
read -p "$(echo -e ${YELLOW}Deseja recarregar as configurações agora? [s/N]:${NC} )" reload

if [ "$reload" = "s" ] || [ "$reload" = "S" ]; then
    echo ""
    echo -e "${YELLOW}Recarregando configurações...${NC}"
    
    # Recarregar cache de fontes
    if command -v fc-cache &> /dev/null; then
        fc-cache -fv > /dev/null 2>&1
        echo -e "${GREEN}✓${NC} Cache de fontes atualizado"
    fi
    
    # Recarregar bspwm se estiver rodando
    if pgrep -x bspwm > /dev/null; then
        bspc wm -r 2>/dev/null
        echo -e "${GREEN}✓${NC} bspwm recarregado"
    fi
    
    # Reiniciar polybar se estiver rodando
    if pgrep -x polybar > /dev/null; then
        pkill polybar
        sleep 1
        polybar &> /dev/null &
        echo -e "${GREEN}✓${NC} Polybar reiniciado"
    fi
    
    echo ""
    echo -e "${GREEN}Configurações recarregadas!${NC}"
    echo -e "${YELLOW}Para aplicar as configurações do shell, execute:${NC}"
    echo -e "${GREEN}source ~/.zshrc${NC} (ou abra um novo terminal)"
fi

echo ""
echo -e "${BLUE}Aproveite seu ambiente restaurado! 🚀${NC}"
echo ""
