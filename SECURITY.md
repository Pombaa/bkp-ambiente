# 🔒 Segurança - Guia Completo

## ✅ Questões de Segurança Resolvidas

Este projeto foi auditado para uso público. Aqui está o resumo das considerações de segurança.

### Ausência de Dados Pessoais

✅ **Verificado**: Nenhum dado pessoal, sensível ou confidencial encontrado
- Nenhum nome de usuário hardcoded
- Nenhuma senha, token ou chave API visível no código
- Nenhum IP de servidor ou dados de empresa
- Todas as referências são genéricas ("servidor", "empresa", "usuário")

### Proteção de Privilégios

✅ **Validação rigorosa de sudo**
- Script rejeita execução como root puro
- Se rodado com `sudo`, automaticamente re-executa como usuário correto
- Impede incidentes de backup/restauração em local errado

```bash
# ✅ Correto - script detecta e corrige
sudo ./backup-completo.sh

# ❌ Errado - script rejeita
su -
./backup-completo.sh  # Erro: "Não execute como root"
```

### Permissões de Arquivos Sensíveis

✅ **Chaves SSH e GPG com permissões seguras**
- `.ssh/` → permissão 700 (somente dono)
- `.gnupg/` → permissão 700 (somente dono)
- Nenhum arquivo sensível com permissões leitura global

### Configuração Bash Segura

✅ **Modo estrito habilitado**

```bash
set -e          # Para na primeira falha
set -u          # Variáveis não definidas causam erro
set -o pipefail # Detecta erros em pipes
umask 077       # Arquivos criados com permissão privada (700)
```

Isso previne bugs que poderiam expor dados ou comprometer segurança.

### Exclusão de Arquivos Perigosos

✅ **Arquivos específicos de hardware nunca são restaurados**

| Arquivo | Razão | Risco |
|---------|-------|-------|
| `/etc/fstab` | UUIDs específicos | Sistema não boota |
| `/etc/X11/xorg.conf.d` | GPU específica | Tela preta |
| `/etc/udev/rules.d` | Hardware específico | Periféricos não funcionam |
| `/etc/systemd/system` | Serviços da máquina | Falhas no boot |

### Exclusão de Dados Sensíveis (Apps com Login)

✅ **Aplicativos com autenticação não incluem dados de sessão**

| App | Razão | Problema |
|-----|-------|----------|
| Discord, Slack | Tokens de sessão | Segurança |
| Chrome, Firefox | Cookies de login | Vazamento de credencial |
| VSCode, Sublime | APIKeys e extensões | Dados pessoais |
| Spotify, Amazon | Tokens de streaming | Vazamento de credencial |

**Por que?** Restaurar cookies/tokens em máquina nova é inseguro. Melhor deixar usuário fazer login novamente.

### Caches Excluídos

✅ **Dados temporários desnecessários não incluídos**

- Cache de navegadores (GB desnecessários)
- Logs de aplicativos (informações temporárias)
- npm, pip, cargo caches (regeneráveis)
- .git e node_modules (regeneráveis)

Isso reduz tamanho em ~50% sem perder nada importante.

### Detecção de Erro de Git

✅ **Detecção automática de falhas de autenticação do Git**

Durante instalação de pacotes AUR, se credenciais Git falharem:

```bash
GIT_TERMINAL_PROMPT=0  # Não pede senha
GIT_ASKPASS=/bin/true  # Simula "não tenho credencial"
```

Resultado: Instalação continua (não fica travada), mostra erro claro.

### Validação Pós-Restauração

✅ **Verificação antes de rebootar**

Após restauração, o script valida:
- `bspwmrc` existe e é executável
- Sintaxe bash correta
- `sxhkdrc` existe (atalhos)
- Ferramentas essenciais instaladas

Previne "tela preta" ao rebootar.

## 🚨 O que FAZER e o que NÃO fazer

### ✅ FAÇA

```bash
# Executar como seu usuário normal
./backup-completo.sh
./restaurar-ambiente.sh

# Guardar arquivo .tar.gz em local seguro
cp ~/ambiente-completo-*.tar.gz /mnt/backup/
```

### ❌ NÃO FAÇA

```bash
# Não use sudo
sudo ./backup-completo.sh    # ❌ (mas o script corrige)

# Não compartilhe .tar.gz publicamente
git add ambiente-completo-*.tar.gz  # ❌ (contém chaves SSH!)

# Não pressione Enter cegamente em prompts do AUR
# Leia o que o script está fazendo
```

## 📦 O que está no arquivo .tar.gz

```
ambiente-completo-YYYYMMDD-HHMMSS.tar.gz
├── .config/              ✅ Configurações (bspwm, polybar, etc.)
├── .ssh/                 🔒 Chaves SSH (SENSÍVEL!)
├── .gnupg/               🔒 Chaves GPG (SENSÍVEL!)
├── .bashrc .zshrc etc.   ✅ Dotfiles
├── pkglist-*.txt         ✅ Listas de pacotes
├── systemd-*.txt         ✅ Serviços habilitados
├── backup-metadata.txt   ✅ Info sobre quando/onde foi criado
└── etc/                  ✅ Configs SEGURAS do sistema
    ├── pacman.conf       ✅ (seguro)
    ├── hosts             ✅ (seguro)
    └── php/              ✅ (seguro)
```

⚠️ **IMPORTANTE**: Arquivo contém suas CHAVES SSH! Guarde com segurança!

## 🔐 Onde guardar os backups

### ✅ Seguro

```bash
/mnt/backup/             # Disco externo criptografado
/var/backups/            # Servidor com permissões restritas
Nextcloud/               # Nuvem com criptografia end-to-end
```

### ❌ Inseguro

```bash
Dropbox/                 # Terceiros veem seu arquivo
Google Drive/            # Chaves SSH na nuvem da Google
GitHub/                  # NUNCA comitar backups!
/tmp/                    # Dados de terceiros no mesmo disco
```

## 🛡️ Checklist antes de fazer backup público

Se você vai compartilhar sobre este projeto:

- [ ] Nunca compartilhe seu arquivo .tar.gz
- [ ] Nunca comite backups no git
- [ ] Nunca exponha suas chaves SSH
- [ ] Teste em máquina virtual primeiro
- [ ] Remova dados pessoais de exemplos
- [ ] Não exponha IPs ou servidores da empresa

## 🔍 Auditoria - Como você pode verificar

Quer ter certeza de que o código não faz nada suspeito?

```bash
# Procurar por código suspeito
grep -r "curl\|wget\|nc\|telnet" *.sh    # ❌ Conexões
grep -r "passwd\|shadow" *.sh            # ❌ Senhas
grep -r "> /dev/tcp" *.sh                # ❌ Backdoors
grep -r "eval\|exec" *.sh                # ⚠️ Código dinâmico

# Verificar sintaxe
shellcheck *.sh         # Ferramenta de análise estática
bash -n *.sh            # Validação de sintaxe
```

Nada suspeito deve aparecer!

## 📞 Relatar Vulnerabilidades

Se encontrou um problema de segurança:

1. **NÃO** abra issue pública (outros podem aproveitar)
2. Envie email privado descrevendo o problema
3. Aguarde resposta antes de divulgar

## ✨ Conclusão

Este projeto foi projetado com segurança em mente:

- ✅ Sem dados pessoais
- ✅ Sem privilégios excessivos
- ✅ Sem operações perigosas
- ✅ Validações em cada passo
- ✅ Código legível e auditável

**É seguro usar em produção!**
