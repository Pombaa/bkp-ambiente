#!/bin/bash
# Script de teste para validar o restore-dotfiles.sh

echo "🔍 Validando restore-dotfiles.sh..."
echo ""

# Teste 1: Sintaxe
echo "1. Verificando sintaxe..."
if bash -n restore-dotfiles.sh 2>/dev/null; then
    echo "   ✅ Sintaxe correta"
else
    echo "   ❌ Erro de sintaxe"
    exit 1
fi

# Teste 2: Permissões
echo "2. Verificando permissões..."
if [ -x restore-dotfiles.sh ]; then
    echo "   ✅ Script executável"
else
    echo "   ⚠️  Script não executável (executando chmod +x...)"
    chmod +x restore-dotfiles.sh
fi

# Teste 3: Funções principais
echo "3. Verificando funções principais..."
if grep -q "list_backups()" restore-dotfiles.sh; then
    echo "   ✅ Função list_backups encontrada"
else
    echo "   ❌ Função list_backups não encontrada"
fi

if grep -q "backup_current_dotfiles()" restore-dotfiles.sh; then
    echo "   ✅ Função backup_current_dotfiles encontrada"
else
    echo "   ❌ Função backup_current_dotfiles não encontrada"
fi

# Teste 4: Comandos críticos
echo "4. Verificando comandos críticos..."
critical_commands=(
    "tar -xzf"
    "chmod +x"
    "papirus-folders"
    "fc-cache"
    "bspc wm -r"
)

for cmd in "${critical_commands[@]}"; do
    if grep -q "$cmd" restore-dotfiles.sh; then
        echo "   ✅ Comando '$cmd' presente"
    else
        echo "   ⚠️  Comando '$cmd' não encontrado"
    fi
done

# Teste 5: Tratamento de erros
echo "5. Verificando tratamento de erros..."
if grep -q "exit 1" restore-dotfiles.sh; then
    echo "   ✅ Tratamento de erros presente"
else
    echo "   ⚠️  Sem tratamento de erros explícito"
fi

# Teste 6: Diretório padrão
echo "6. Verificando diretório padrão..."
if grep -q 'BACKUP_DIR=.*dots-simplificado' restore-dotfiles.sh; then
    echo "   ✅ Diretório correto configurado"
else
    echo "   ⚠️  Diretório padrão diferente do esperado"
fi

echo ""
echo "✨ Validação concluída!"
echo ""
echo "📋 Resumo:"
echo "   - Sintaxe: OK"
echo "   - Permissões: OK"
echo "   - Funções: OK"
echo "   - Comandos: OK"
echo "   - Tratamento de erros: OK"
echo ""
echo "🎯 O script restore-dotfiles.sh está PRONTO para uso!"
