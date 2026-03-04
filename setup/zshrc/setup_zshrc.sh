#!/bin/bash
# @desc: Installa zsh, Oh My Zsh, plugin e configura .zshrc personalizzato

GREEN="\e[92m"
RED="\e[38;5;160m"
CYAN="\e[96m"
YELLOW="\e[93m"
MAGENTA="\e[95m"
DARK_GRAY="\e[90m"
BOLD="\e[1m"
RESET="\e[0m"

print_ok()   { echo -e "${GREEN}✅ $1${RESET}"; }
print_err()  { echo -e "${RED}❌ $1${RESET}"; exit 1; }
print_warn() { echo -e "${YELLOW}⚠️  $1${RESET}"; }
print_info() { echo -e "${CYAN}ℹ️  $1${RESET}"; }
print_step() { echo -e "\n${MAGENTA}➡️  $1${RESET}"; }

# ─────────────────────────────────────────────────────────────
# === SPINNER ===
# ─────────────────────────────────────────────────────────────
spinner() {
  local pid=$1
  local label="${2:-Attendere...}"
  local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    local char="${spinstr:$i:1}"
    printf "\r  ${CYAN}${char}${RESET}  ${DARK_GRAY}${label}${RESET}"
    i=$(( (i+1) % ${#spinstr} ))
    sleep 0.08
  done
  printf "\r%-50s\r" " "
}

# ─────────────────────────────────────────────────────────────
# === BANNER ===
# ─────────────────────────────────────────────────────────────
echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║       🐚  SETUP ZSHRC                ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════╝${RESET}"
echo -e "${DARK_GRAY}  zsh + Oh My Zsh + plugin + .zshrc personalizzato${RESET}\n"

# ─────────────────────────────────────────────────────────────
# === RILEVA DISTRO ===
# ─────────────────────────────────────────────────────────────
detect_pkg_manager() {
  if   [[ "$OSTYPE" == "darwin"* ]];    then PKG="brew install"
  elif [[ -f /etc/arch-release ]];      then PKG="sudo pacman -S --noconfirm"
  elif [[ -f /etc/debian_version ]];    then PKG="sudo apt install -y"
  elif [[ -f /etc/fedora-release ]];    then PKG="sudo dnf install -y"
  elif [[ -f /etc/redhat-release ]];    then PKG="sudo yum install -y"
  elif grep -qi opensuse /etc/os-release 2>/dev/null; then PKG="sudo zypper install -y"
  else print_err "Distribuzione non supportata."; fi
}

detect_pkg_manager

# ─────────────────────────────────────────────────────────────
# === 0. GENERA spinal (.zshrc template) ===
# Il template è embedded nello script — nessun download necessario
# ─────────────────────────────────────────────────────────────
print_step "Genero file spinal (.zshrc template)..."
SCRIPTS_DIR="$HOME/.manuel_scripts"
mkdir -p "$SCRIPTS_DIR"

cat > "$SCRIPTS_DIR/spinal" << 'SPINAL_EOF'
# ─────────────────────────────────────────────────────────────
# spinal — .zshrc personalizzato
# github.com/manuelpringols/RepoScript
# ─────────────────────────────────────────────────────────────

# Path Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"

# Tema
ZSH_THEME="robbyrussell"

# Plugin
plugins=(git zsh-syntax-highlighting zsh-autosuggestions)

# Carica Oh My Zsh
source $ZSH/oh-my-zsh.sh

# ─────────────────────────────────────────────────────────────
# === HIGHLIGHT COLORS ===
# ─────────────────────────────────────────────────────────────
ZSH_HIGHLIGHT_STYLES[path]='fg=cyan,bold'
ZSH_HIGHLIGHT_STYLES[command]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=red,bold'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=yellow'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=yellow'

# ─────────────────────────────────────────────────────────────
# === PROMPT PERSONALIZZATO ===
# ─────────────────────────────────────────────────────────────
configure_prompt() {
  local prompt_symbol=💀
  local venv_name=""

  if [[ -n "$VIRTUAL_ENV" ]]; then
    venv_name="(%F{magenta}$(basename "$VIRTUAL_ENV")%f)"
  fi

  case "$PROMPT_ALTERNATIVE" in
    twoline)
      PROMPT=$'%F{magenta}╭──'"$venv_name"'(%B%F{15}%n'"$prompt_symbol"$'%m%b%F{magenta})-[%B%F{reset}%(6~.%-1~/%4~.%5~)%b%F{magenta}]- %F{green}.
╰─%B%(#.%F{15}#.%F{15}$)%b%F{reset} '
      ;;
    oneline)
      PROMPT="$venv_name"'%B%F{red}%n@%m%b%F{reset}:%B%F{green}%~%b%F{reset}%(#.#.$) '
      RPROMPT=
      ;;
    backtrack)
      PROMPT="$venv_name"'%B%F{magenta}%n@%m%b%F{reset}:%B%F{blue}%~%b%F{reset}%(#.#.$) '
      RPROMPT=
      ;;
  esac
}

PROMPT_ALTERNATIVE=twoline
configure_prompt
export PROMPT

# ─────────────────────────────────────────────────────────────
# === COMPLETAMENTO ===
# ─────────────────────────────────────────────────────────────
autoload -Uz compinit && compinit

# ─────────────────────────────────────────────────────────────
# === HISTORY ===
# ─────────────────────────────────────────────────────────────
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY

# ─────────────────────────────────────────────────────────────
# === ALIAS UTILI ===
# ─────────────────────────────────────────────────────────────
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias gs='git status'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

# ─────────────────────────────────────────────────────────────
# === SYSTEM INFO ===
# ─────────────────────────────────────────────────────────────
echo "-------------------------------------------------------------------"
neofetch
SPINAL_EOF

print_ok "File spinal generato."

# ─────────────────────────────────────────────────────────────
# === 1. INSTALLA ZSH ===
# ─────────────────────────────────────────────────────────────
print_step "Verifica zsh..."
if command -v zsh &>/dev/null; then
  print_ok "zsh già installato ($(zsh --version | head -1))."
else
  print_info "Installo zsh..."
  $PKG zsh &
  spinner $! "Installazione zsh..."
  wait $!
  command -v zsh &>/dev/null || print_err "Installazione zsh fallita."
  print_ok "zsh installato."
fi

# ─────────────────────────────────────────────────────────────
# === 2. IMPOSTA ZSH COME SHELL DEFAULT ===
# ─────────────────────────────────────────────────────────────
print_step "Imposto zsh come shell default..."
CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7 2>/dev/null || echo "$SHELL")
ZSH_PATH=$(which zsh)

if [[ "$CURRENT_SHELL" == "$ZSH_PATH" ]]; then
  print_ok "zsh è già la shell default."
else
  chsh -s "$ZSH_PATH" &
  spinner $! "chsh..."
  wait $!
  print_ok "Shell default impostata a zsh."
fi

# ─────────────────────────────────────────────────────────────
# === 3. INSTALLA OH MY ZSH ===
# ─────────────────────────────────────────────────────────────
print_step "Verifica Oh My Zsh..."
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  print_ok "Oh My Zsh già installato."
else
  print_info "Installo Oh My Zsh..."
  export RUNZSH=no
  export KEEP_ZSHRC=yes
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" &
  spinner $! "Installazione Oh My Zsh..."
  wait $!
  [[ -d "$HOME/.oh-my-zsh" ]] || print_err "Installazione Oh My Zsh fallita."
  print_ok "Oh My Zsh installato."
fi

# ─────────────────────────────────────────────────────────────
# === 4. PLUGIN ===
# ─────────────────────────────────────────────────────────────
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

print_step "Verifica plugin zsh-syntax-highlighting..."
if [[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  print_ok "zsh-syntax-highlighting già presente."
else
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" &
  spinner $! "Clone zsh-syntax-highlighting..."
  wait $!
  print_ok "zsh-syntax-highlighting installato."
fi

print_step "Verifica plugin zsh-autosuggestions..."
if [[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  print_ok "zsh-autosuggestions già presente."
else
  git clone https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions" &
  spinner $! "Clone zsh-autosuggestions..."
  wait $!
  print_ok "zsh-autosuggestions installato."
fi

# ─────────────────────────────────────────────────────────────
# === 5. SPONGEBOB ===
# ─────────────────────────────────────────────────────────────
print_step "ASCII Art opzionale..."
SPONGEBOB_LINE='[ -f ~/frames/spongebob_ascii.sh ] && bash ~/frames/spongebob_ascii.sh'
WANT_SPONGEBOB=0
read -rp "$(echo -e "${YELLOW}🧽 Vuoi abilitare l'ASCII art di Spongebob all'avvio di zsh? [y/N]: ${RESET}")" sponge_ans < /dev/tty
[[ "$sponge_ans" =~ ^[Yy]$ ]] && WANT_SPONGEBOB=1

# ─────────────────────────────────────────────────────────────
# === 6. CONFIGURA .ZSHRC ===
# ─────────────────────────────────────────────────────────────
print_step "Configurazione .zshrc..."

if [[ -f "$HOME/.zshrc" ]]; then
  print_warn "Un file .zshrc esiste già."
  read -rp "$(echo -e "${YELLOW}Sovrascrivere con il template spinal? [y/N]: ${RESET}")" overwrite < /dev/tty
  if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
    print_warn "Sovrascrittura annullata — .zshrc non modificato."
    SKIP_ZSHRC=1
  else
    # Backup
    cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%Y%m%d_%H%M%S)"
    print_info "Backup salvato in ~/.zshrc.bak.*"
    SKIP_ZSHRC=0
  fi
else
  SKIP_ZSHRC=0
fi

if [[ "$SKIP_ZSHRC" -eq 0 ]]; then
  cp "$SCRIPTS_DIR/spinal" "$HOME/.zshrc"

  # Aggiungi o rimuovi spongebob
  if [[ "$WANT_SPONGEBOB" -eq 1 ]]; then
    grep -qF "$SPONGEBOB_LINE" "$HOME/.zshrc" || echo "$SPONGEBOB_LINE" >> "$HOME/.zshrc"
    print_ok "Spongebob abilitato nel .zshrc."
  else
    sed -i "\\|${SPONGEBOB_LINE}|d" "$HOME/.zshrc"
    print_ok "Spongebob non incluso."
  fi

  print_ok ".zshrc configurato correttamente."
fi

# ─────────────────────────────────────────────────────────────
# === FINE ===
# ─────────────────────────────────────────────────────────────
echo -e "\n${GREEN}${BOLD}🎉 Setup completato!${RESET}"
echo -e "${DARK_GRAY}  Per applicare le modifiche esegui:${RESET}"
echo -e "  ${CYAN}exec zsh${RESET}  oppure apri un nuovo terminale\n"