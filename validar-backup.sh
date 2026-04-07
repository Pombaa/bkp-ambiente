#!/bin/bash

# Script para validar a segurança do backup gerado
# Execute após criar o backup para garantir que está seguro

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║       🔍 VALIDAÇÃO DE SEGURANÇA DO BACKUP 🔍                  ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Encontrar o backup mais recente
BACKUP_ROOT_DIR="$HOME/bkp-ambiente"
BACKUP_FILE=$(ls -t "$BACKUP_ROOT_DIR"/ambiente-completo-*.tar.gz 2>/dev/null | head -1)

if [[ -z "$BACKUP_FILE" ]]; then
    BACKUP_FILE=$(ls -t ~/ambiente-completo-*.tar.gz 2>/dev/null | head -1)
fi

if [[ -z "$BACKUP_FILE" ]]; then
    echo "❌ Nenhum arquivo de backup encontrado em $BACKUP_ROOT_DIR nem em ~/"
    echo ""
    echo "Execute primeiro: ./backup-completo.sh"
    exit 1
fi

echo "📦 Validando backup: $(basename "$BACKUP_FILE")"
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "📊 Tamanho: $BACKUP_SIZE"
echo ""

# Verificar arquivos perigosos
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Verificando arquivos PERIGOSOS..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DANGEROUS_FOUND=0

# Verificar /etc/fstab
if tar -tzf "$BACKUP_FILE" | grep -q "etc/fstab"; then
    echo "❌ PERIGO: /etc/fstab encontrado!"
    echo "   → Isso VAI quebrar o sistema na restauração!"
    DANGEROUS_FOUND=1
else
    echo "✅ /etc/fstab: NÃO incluído (seguro)"
fi

# Verificar /etc/systemd/system
if tar -tzf "$BACKUP_FILE" | grep -q "etc/systemd/system/"; then
    echo "❌ PERIGO: /etc/systemd/system/ encontrado!"
    echo "   → Serviços podem causar falha no boot!"
    DANGEROUS_FOUND=1
else
    echo "✅ /etc/systemd/system/: NÃO incluído (seguro)"
fi

# Verificar /etc/X11/xorg.conf.d
if tar -tzf "$BACKUP_FILE" | grep -q "etc/X11/xorg.conf.d"; then
    echo "❌ PERIGO: /etc/X11/xorg.conf.d encontrado!"
    echo "   → Configurações de vídeo podem causar tela preta!"
    DANGEROUS_FOUND=1
else
    echo "✅ /etc/X11/xorg.conf.d: NÃO incluído (seguro)"
fi

# Verificar /etc/udev/rules.d
if tar -tzf "$BACKUP_FILE" | grep -q "etc/udev/rules.d"; then
    echo "❌ PERIGO: /etc/udev/rules.d encontrado!"
    echo "   → Regras de hardware podem causar problemas!"
    DANGEROUS_FOUND=1
else
    echo "✅ /etc/udev/rules.d: NÃO incluído (seguro)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Verificando arquivos SEGUROS incluídos..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar arquivos seguros do /etc
SAFE_FILES=(
    "etc/pacman.conf"
    "etc/makepkg.conf"
    "etc/hosts"
    "etc/environment"
)

for file in "${SAFE_FILES[@]}"; do
    if tar -tzf "$BACKUP_FILE" | grep -q "$file"; then
        echo "✅ /$file: incluído"
    else
        echo "⊘  /$file: não encontrado (normal se não existir)"
    fi
done

echo ""

# Verificar configurações essenciais
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Verificando configurações ESSENCIAIS..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ESSENTIAL_PATHS=(
    ".config/"
    ".bashrc"
    ".zshrc"
    "pkglist-pacman.txt"
    "pkglist-aur.txt"
)

for path in "${ESSENTIAL_PATHS[@]}"; do
    if tar -tzf "$BACKUP_FILE" | grep -q "$path"; then
        echo "✅ $path: incluído"
    else
        echo "⚠️  $path: NÃO encontrado"
    fi
done

echo ""

# Verificar caches desnecessários
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧹 Verificando CACHES e arquivos temporários..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CACHE_COUNT=$(tar -tzf "$BACKUP_FILE" | grep -i "/Cache/" | wc -l)
NODE_MODULES=$(tar -tzf "$BACKUP_FILE" | grep "node_modules/" | wc -l)
GIT_FOLDERS=$(tar -tzf "$BACKUP_FILE" | grep "/.git/" | wc -l)

if [[ $CACHE_COUNT -gt 0 ]]; then
    echo "⚠️  Caches encontrados: $CACHE_COUNT arquivos"
    echo "   → Aumenta o tamanho do backup desnecessariamente"
else
    echo "✅ Nenhum cache incluído (otimizado)"
fi

if [[ $NODE_MODULES -gt 0 ]]; then
    echo "⚠️  node_modules encontrado: $NODE_MODULES arquivos"
    echo "   → Pode ser reinstalado com npm/yarn"
else
    echo "✅ Nenhum node_modules incluído (otimizado)"
fi

if [[ $GIT_FOLDERS -gt 0 ]]; then
    echo "⚠️  Pastas .git encontradas: $GIT_FOLDERS arquivos"
    echo "   → Git repos devem ser clonados novamente"
else
    echo "✅ Nenhuma pasta .git incluída (otimizado)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 ESTATÍSTICAS DO BACKUP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TOTAL_FILES=$(tar -tzf "$BACKUP_FILE" | wc -l)
CONFIG_FILES=$(tar -tzf "$BACKUP_FILE" | grep "\.config/" | wc -l)
DOTFILES=$(tar -tzf "$BACKUP_FILE" | grep -E "\.(bashrc|zshrc|vimrc|gitconfig|tmux)" | wc -l)

echo "📁 Total de arquivos/pastas: $TOTAL_FILES"
echo "⚙️  Arquivos em .config/: $CONFIG_FILES"
echo "📝 Dotfiles encontrados: $DOTFILES"
echo "💾 Tamanho do arquivo: $BACKUP_SIZE"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"

if [[ $DANGEROUS_FOUND -eq 0 ]]; then
    echo "║          ✅ BACKUP APROVADO - 100% SEGURO! ✅                 ║"
    echo "║                                                               ║"
    echo "║  Este backup pode ser restaurado em qualquer máquina         ║"
    echo "║  sem risco de quebrar o sistema!                             ║"
else
    echo "║       ❌ BACKUP REPROVADO - CONTÉM ARQUIVOS PERIGOSOS! ❌     ║"
    echo "║                                                               ║"
    echo "║  NÃO use este backup! Revise o script backup-completo.sh     ║"
fi

echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

if [[ $DANGEROUS_FOUND -eq 0 ]]; then
    exit 0
else
    exit 1
fi
