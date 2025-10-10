# 🛡️ Sistema de Backup e Restauração SEGURO - Arch Linux + bspwm

## 📌 O que mudou (versão segura)

### ⚠️ **PROBLEMA IDENTIFICADO:**
A versão anterior do backup incluía arquivos críticos do sistema que causavam falha no boot quando restaurados em outra máquina:

- ❌ `/etc/fstab` - UUIDs de partições diferentes → **sistema não boota**
- ❌ `/etc/systemd/system` - Serviços inexistentes → **falhas no boot**
- ❌ `/etc/X11/xorg.conf.d` - Drivers diferentes → **tela preta/sem interface gráfica**
- ❌ `/etc/udev/rules.d` - Hardware diferente → **problemas de detecção**

### ✅ **SOLUÇÃO IMPLEMENTADA:**

Agora o backup inclui **APENAS configurações seguras**:

#### Arquivos do `/etc` incluídos (SEGUROS):
```bash
✅ /etc/pacman.conf     # Configurações de repositórios
✅ /etc/makepkg.conf    # Flags de compilação
✅ /etc/hosts           # Hosts personalizados
✅ /etc/environment     # Variáveis de ambiente globais
```

#### Tudo mais é do usuário:
- Configurações do bspwm, polybar, rofi, etc. (`.config/`)
- Dotfiles (`.bashrc`, `.zshrc`, etc.)
- Temas, ícones e fontes
- Lista de pacotes instalados
- Serviços habilitados (apenas lista, não os arquivos)

---

## 🚀 Como Usar

### 1️⃣ **Fazer Backup (máquina atual)**

```bash
cd ~/bkp-ambiente
./backup-completo.sh
```

**Resultado:**
- Cria arquivo: `ambiente-completo-YYYYMMDD-HHMMSS.tar.gz`
- Cria pasta: `~/backup-ambiente` com todos os arquivos
- **100% seguro** para restaurar em qualquer máquina!

---

### 2️⃣ **Restaurar (máquina nova)**

#### Passo 1: Instalar sistema base
```bash
# Instale Arch Linux normalmente
# Configure partições, bootloader, etc.
# Instale pacotes essenciais:
sudo pacman -S base-devel git xorg bspwm sxhkd
```

#### Passo 2: Copiar e extrair backup
```bash
# Copie o arquivo .tar.gz para a nova máquina
# Execute o script de restauração:
cd ~/bkp-ambiente
./restaurar-ambiente.sh
```

**O script vai:**
1. ✅ Extrair todos os arquivos
2. ✅ Restaurar configurações do usuário
3. ✅ Reinstalar TODOS os pacotes (pacman + AUR)
4. ✅ Restaurar aplicativos Flatpak
5. ✅ Habilitar serviços do systemd
6. ✅ Aplicar configurações seguras do `/etc`
7. ✅ Ajustar permissões (.ssh, .gnupg, etc.)

#### Passo 3: Reiniciar
```bash
sudo reboot
```

---

## 📋 O que é backup e o que NÃO é

### ✅ **É feito backup:**

| Item | Descrição |
|------|-----------|
| **~/.config/** | Todas configurações de aplicativos |
| **Dotfiles** | .bashrc, .zshrc, .gitconfig, etc. |
| **Temas** | ~/.themes, ~/.icons, ~/.fonts |
| **Scripts** | ~/.local/bin |
| **Pacotes** | Lista completa (pacman + AUR) |
| **Flatpak** | Lista de aplicativos instalados |
| **Systemd** | Lista de serviços habilitados |
| **dconf** | Configurações GNOME/GTK |
| **.ssh/.gnupg** | Chaves e configurações (com permissões corretas) |

### ❌ **NÃO é feito backup (por segurança):**

| Item | Motivo |
|------|--------|
| **/etc/fstab** | UUIDs específicos da máquina |
| **/etc/systemd/system/** | Serviços podem não existir na nova máquina |
| **/etc/X11/xorg.conf.d/** | Drivers de vídeo diferentes |
| **/etc/udev/rules.d/** | Hardware específico |
| **/boot/** | Bootloader e kernel específicos |
| **/var/** | Dados variáveis do sistema |

---

## 🔍 Verificações de Segurança

### Antes de restaurar, o script verifica:
- ✅ Existe backup disponível?
- ✅ `rsync` está instalado?
- ✅ Permissões corretas em `.ssh` e `.gnupg`

### Durante a restauração:
- ⚠️ Mostra avisos sobre arquivos não restaurados
- ⚠️ Continua mesmo se alguns pacotes falharem
- ⚠️ Não sobrescreve configurações críticas do sistema

---

## 🛠️ Solução de Problemas

### ❓ "Sistema não boota após restauração"
**Causa:** Backup antigo com `/etc/fstab` ou `/etc/systemd/system`

**Solução:**
1. Boote com Live USB
2. Monte o sistema
3. Verifique `/etc/fstab` - deve ter UUIDs corretos da máquina atual
4. Execute: `genfstab -U /mnt >> /mnt/etc/fstab`

### ❓ "Interface gráfica não inicia"
**Causa:** Possível conflito em `/etc/X11/xorg.conf.d/`

**Solução:**
```bash
sudo rm -rf /etc/X11/xorg.conf.d/*
sudo pacman -S xf86-video-intel  # ou nvidia, amd conforme sua GPU
```

### ❓ "Alguns pacotes falharam na instalação"
**Normal!** Alguns pacotes podem ter sido removidos dos repositórios.

**Solução:**
```bash
# Veja a lista completa
cat ~/backup-ambiente/pkglist-all.txt

# Instale manualmente os que falharam
yay -S nome-do-pacote
```

---

## 📊 Comparação: Backup Antigo vs Novo

| Aspecto | Versão ANTIGA | Versão SEGURA |
|---------|---------------|---------------|
| `/etc/fstab` | ❌ Incluído | ✅ Excluído |
| `/etc/systemd/system/` | ❌ Incluído | ✅ Excluído |
| `/etc/X11/` | ❌ Incluído | ✅ Excluído |
| Segurança no boot | ❌ Pode quebrar | ✅ 100% seguro |
| Portabilidade | ❌ Limitada | ✅ Total |
| Configurações de usuário | ✅ Completo | ✅ Completo |

---

## 📝 Arquivos do Sistema de Backup

```
~/bkp-ambiente/
├── backup-completo.sh          # Script de backup
├── restaurar-ambiente.sh        # Script de restauração
├── README.md                    # Este arquivo
├── ambiente-completo-*.tar.gz   # Backups criados
└── backup-ambiente/             # Última versão extraída
```

---

## 🎯 Resumo

### ✅ **SEGURO para:**
- Migrar entre computadores diferentes
- Reinstalar o sistema
- Criar múltiplas máquinas com mesmo ambiente
- Testar em máquinas virtuais

### ❌ **NÃO substitui:**
- Backup de dados pessoais (documentos, fotos, etc.)
- Backup do sistema inteiro
- Snapshot do disco

---

## 💡 Dicas Extras

1. **Faça backups regulares:**
   ```bash
   # Adicione ao cron para backup semanal
   0 2 * * 0 ~/bkp-ambiente/backup-completo.sh
   ```

2. **Guarde em lugar seguro:**
   - Upload para nuvem (Google Drive, Dropbox, etc.)
   - Cópia em HD externo
   - Git privado

3. **Teste a restauração:**
   - Use uma VM para testar antes de usar em produção

---

**Criado em:** 8 de outubro de 2025  
**Sistema:** Arch Linux + bspwm  
**Versão:** 2.0 (Segura)

🛡️ **Backup seguro, restauração confiável!**
