#!/bin/bash

# Script para visualizar o que está incluído no backup
# Use para verificar antes de fazer o backup

echo "════════════════════════════════════════════════════════════════"
echo "📋 Verificação de Backup - O que será incluído"
echo "════════════════════════════════════════════════════════════════"
echo ""

echo "✅ CONFIGURAÇÕES DE USUÁRIO (~/.config/):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ls -1d ~/.config/* 2>/dev/null | head -20
echo "   ... e todos os outros"
echo ""

echo "✅ DOTFILES:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for file in .bashrc .zshrc .xinitrc .xprofile .profile .vimrc .gitconfig .tmux.conf .gtkrc-2.0; do
    if [ -f "$HOME/$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ⊘ $file (não encontrado)"
    fi
done
echo ""

echo "✅ TEMAS E APARÊNCIA:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for dir in .themes .icons .fonts .local/share/icons .local/share/themes .local/share/fonts; do
    if [ -d "$HOME/$dir" ]; then
        count=$(find "$HOME/$dir" -maxdepth 1 -type d | wc -l)
        echo "  ✓ $dir ($((count - 1)) itens)"
    else
        echo "  ⊘ $dir (não encontrado)"
    fi
done
echo ""

echo "✅ PACOTES INSTALADOS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
pacman_count=$(pacman -Qqen | wc -l)
aur_count=$(pacman -Qqem | wc -l)
echo "  ✓ Pacman: $pacman_count pacotes"
echo "  ✓ AUR:    $aur_count pacotes"
if command -v flatpak >/dev/null 2>&1; then
    flatpak_count=$(flatpak list --app 2>/dev/null | wc -l)
    echo "  ✓ Flatpak: $flatpak_count apps"
fi
echo ""

echo "✅ ARQUIVOS SEGUROS DO /etc:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for file in /etc/pacman.conf /etc/makepkg.conf /etc/hosts /etc/environment; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ⊘ $file (não encontrado)"
    fi
done
echo ""

echo "❌ ARQUIVOS DO SISTEMA NÃO INCLUÍDOS (por segurança):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✗ /etc/fstab              - UUIDs específicos da máquina"
echo "  ✗ /etc/systemd/system/    - Serviços podem não existir"
echo "  ✗ /etc/X11/xorg.conf.d/   - Drivers de vídeo específicos"
echo "  ✗ /etc/udev/rules.d/      - Regras de hardware específicas"
echo "  ✗ /boot/                  - Bootloader e kernel"
echo "  ✗ /var/                   - Dados variáveis do sistema"
echo ""

echo "════════════════════════════════════════════════════════════════"
echo "💡 Resumo:"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Este backup é 100% SEGURO para restaurar em qualquer máquina!"
echo ""
echo "O que SERÁ incluído:"
echo "  ✅ Todas suas configurações pessoais"
echo "  ✅ Lista de pacotes para reinstalar"
echo "  ✅ Temas, ícones e fontes"
echo "  ✅ Configurações seguras do sistema"
echo ""
echo "O que NÃO será incluído:"
echo "  ❌ Configurações críticas de hardware"
echo "  ❌ Arquivos que podem quebrar o boot"
echo "  ❌ Serviços específicos da máquina atual"
echo ""
echo "🚀 Pronto para fazer o backup!"
echo "Execute: ./backup-completo.sh"
echo "════════════════════════════════════════════════════════════════"
