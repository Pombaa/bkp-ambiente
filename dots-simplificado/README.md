# 🎨 Dotfiles Essencial - Backup e Restauração

Scripts otimizados para backup e restauração de **configurações essenciais** do ambiente Linux (bspwm/Arch).

## 📋 O que está incluído

### ✅ Configurações incluídas no backup:

#### 🪟 Window Manager e Compositing
- `bspwm` - Window manager
- `sxhkd` - Hotkeys
- `picom` - Compositor

#### 🎯 Interface Visual
- `polybar` - Barra de status
- `rofi` - Launcher de aplicativos
- `dunst` - Notificações

#### 💻 Terminal e Shell
- `alacritty` / `kitty` - Emuladores de terminal
- `bashrc` / `zshrc` - Configurações do shell
- `tmux` - Multiplexador de terminal

#### 🎨 Temas e Aparência
- Configurações GTK (3.0 e 4.0)
- Temas de ícones (`.icons`)
- Temas personalizados (`.themes`)
- Fontes customizadas (`.local/share/fonts`)

#### 🛠️ Utilitários de Sistema
- `btop` - Monitor de recursos
- `fastfetch` / `neofetch` - System info
- `betterlockscreen` - Lockscreen
- `redshift` - Filtro de luz azul
- `Thunar` / `xfce4` - File manager

#### 🖼️ Extras
- Papéis de parede (`Pictures/Wallpapers`)
- Visualizadores de imagem (`viewnior`, `qimgv`)
- Git config básico (`.gitconfig`)

---

### ❌ O que NÃO está incluído (propositalmente):

Para manter o backup **limpo e compartilhável**, os seguintes itens são **excluídos**:

#### 🚫 Aplicativos Pessoais
- **Discord** (`.config/discord`)
- **VSCode/VSCodium** (`.config/Code`)
- **Google Chrome** (`.config/google-chrome`)
- **Chromium** (`.config/chromium`)
- **Brave** (`.config/BraveSoftware`)
- **Slack** (`.config/Slack`)
- **Spotify** (`.config/spotify`)
- **Obsidian** (`.config/obsidian`)
- **LibreOffice** (`.config/libreoffice`)

#### 🔒 Dados Sensíveis (SEGURANÇA!)
- **SSH Keys** (`.ssh`) - Nunca compartilhe!
- **GPG Keys** (`.gnupg`) - Nunca compartilhe!
- **Senhas** (`.password-store`) - Nunca compartilhe!
- **Tokens Cloud** (`.config/rclone`)

#### 📁 Dados de Navegadores
- **Firefox profiles** (`.mozilla`)
- **Thunderbird** (`.thunderbird`)
- **Histórico de Torrents** (`.config/transmission`)

#### 💾 Dados de Aplicativos
- **Dados locais** (`.local/share/*`)
- **Cache** (`.cache/*`)

---

## 🚀 Como usar

### 1️⃣ Fazer Backup das Configurações

```bash
cd ~/bkp-ambiente/dots-simplificado
chmod +x backup-dotfiles.sh
./backup-dotfiles.sh
```

**Resultado:**
- Cria arquivo: `dotfiles_essencial_YYYY-MM-DD.tar.gz`
- Salvo em: `~/bkp-ambiente/dots-simplificado/`
- Contém APENAS configurações essenciais

### 2️⃣ Restaurar em Outra Máquina

#### Pré-requisitos (instalar antes):

```bash
# Arch Linux / Yay
yay -S bspwm sxhkd polybar rofi picom dunst \
       alacritty kitty ttf-jetbrains-mono \
       papirus-icon-theme papirus-folders \
       btop fastfetch
```

#### Executar restauração:

```bash
cd ~/bkp-ambiente/dots-simplificado
chmod +x restore-dotfiles.sh
./restore-dotfiles.sh
```

**O script vai:**
1. Listar backups disponíveis
2. Fazer backup das configs atuais (segurança)
3. Extrair o backup selecionado
4. Aplicar permissões corretas
5. Configurar temas de ícones (Papirus)
6. Recarregar configurações automaticamente

### 3️⃣ Finalizar Configuração

Após a restauração, execute:

```bash
# Recarregar bspwm
bspc wm -r

# Atualizar cache de fontes
fc-cache -fv

# Recarregar shell
source ~/.zshrc  # ou ~/.bashrc

# Configurar ícones Papirus (se não automático)
papirus-folders -C violet --theme Papirus
```

---

## 📦 Compartilhar com Amigos

Para passar suas configurações para um amigo:

1. **Fazer backup:**
   ```bash
   ./backup-dotfiles.sh
   ```

2. **Copiar arquivo gerado:**
   ```bash
   cp ~/bkp-ambiente/dots-simplificado/dotfiles_essencial_*.tar.gz /caminho/destino/
   ```

3. **Seu amigo deve:**
   - Instalar os pacotes base (bspwm, polybar, etc.)
   - Executar `./restore-dotfiles.sh`
   - Ajustar configurações pessoais (wallpaper, cores, etc.)

### ✅ Vantagens deste backup:
- ✔️ **Limpo** - Sem dados pessoais
- ✔️ **Seguro** - Sem credenciais ou senhas
- ✔️ **Focado** - Apenas ambiente visual/funcional
- ✔️ **Compartilhável** - Pronto para passar adiante

---

## 🔧 Customização

### Adicionar mais itens ao backup:

Edite `backup-dotfiles.sh` e adicione na array `ITEMS`:

```bash
ITEMS=(
    # ... existentes ...
    ".config/seu-app"    # Adicione aqui
)
```

### Excluir itens específicos:

Comente a linha com `#`:

```bash
# ".config/picom"    # Não fazer backup do picom
```

---

## 📝 Notas Importantes

1. **Wallpapers grandes:** Se `Pictures/Wallpapers` for muito grande, comente esta linha
2. **Scripts personalizados:** Por padrão, scripts em `~/scripts` e `~/.local/bin` estão comentados
3. **Fontes:** Se tiver muitas fontes, o backup pode ficar grande
4. **Git config:** O `.gitconfig` é incluído, mas sem credenciais (seguro)

---

## 🆘 Troubleshooting

### Backup muito grande?
- Remova `Pictures/Wallpapers` da lista
- Remova `.themes` ou `.icons` se não customizou
- Remova `.local/share/fonts` se usar fontes do sistema

### Permissões incorretas após restaurar?
```bash
chmod +x ~/.config/bspwm/bspwmrc
chmod +x ~/.config/polybar/*.sh
chmod +x ~/.config/bspwm/*.sh
```

### Polybar não inicia?
```bash
pkill polybar
polybar &
```

### Temas GTK não aplicam?
```bash
# Verificar arquivo de configuração
cat ~/.config/gtk-3.0/settings.ini

# Reaplicar manualmente
lxappearance  # ou nwg-look
```

---

## 📄 Licença

Livre para usar e modificar. Compartilhe com seus amigos! 🚀

---

## 🤝 Contribuindo

Sinta-se livre para:
- Adicionar mais configurações úteis
- Melhorar os scripts
- Reportar bugs
- Sugerir melhorias

**Mantenha sempre o foco:** configurações essenciais, sem dados pessoais!
