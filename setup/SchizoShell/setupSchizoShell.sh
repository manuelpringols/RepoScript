#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║            💀  setupSchizoShell — Arch Linux Edition            ║
# ║   Niri · Noctalia · Kitty · mpvpaper · ZSH · Neovim+LazyVim    ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# === PALETTE & HELPERS ===
# ─────────────────────────────────────────────────────────────
RED='\e[38;5;160m';   GREEN='\e[92m';     CYAN='\e[96m'
YELLOW='\e[93m';      MAGENTA='\e[95m';   DARK_GRAY='\e[90m'
BOLD='\e[1m';         DIM='\e[2m';        RESET='\e[0m'

print_ok()   { echo -e "${GREEN}  ✅  $1${RESET}"; }
print_err()  { echo -e "${RED}  ❌  $1${RESET}"; exit 1; }
print_warn() { echo -e "${YELLOW}  ⚠️   $1${RESET}"; }
print_info() { echo -e "${CYAN}  ℹ️   $1${RESET}"; }
print_step() { echo -e "\n${BOLD}${MAGENTA}══════ $1 ══════${RESET}"; }
print_skip() { echo -e "${DARK_GRAY}  ⏭️   $1 — saltato${RESET}"; }

spinner() {
  local pid=$1 label="${2:-...}" spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${CYAN}${spinstr:$i:1}${RESET}  ${DARK_GRAY}${label}${RESET}   "
    i=$(( (i + 1) % ${#spinstr} ))
    sleep 0.08
  done
  printf "\r%-70s\r" " "
}

pkg_installed() { command -v "$1" &>/dev/null; }

clone_plugin() {
  local name="$1" url="$2" dest="$3"
  if [[ ! -d "$dest" ]]; then
    git clone --depth=1 "$url" "$dest" &>/dev/null &
    spinner $! "Clone ${name}..."
    wait $!
    print_ok "${name} installato."
  else
    print_ok "${name} già presente."
  fi
}

# ─────────────────────────────────────────────────────────────
# === PREREQUISITI ===
# ─────────────────────────────────────────────────────────────
[[ -f /etc/arch-release ]] || { echo -e "${RED}Solo Arch Linux.${RESET}"; exit 1; }
[[ $EUID -eq 0 ]]          && { echo -e "${RED}Non eseguire come root.${RESET}"; exit 1; }

# ─────────────────────────────────────────────────────────────
# === BANNER ===
# ─────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${MAGENTA}"
cat << 'BANNER'
  ██████  ▄████▄  ██░ ██  ██▓▒███████▒ ▒█████     ██████  ██░ ██ ▓█████  ██▓     ██▓
▒██    ▒ ▒██▀ ▀█ ▓██░ ██▒▓██▒▒ ▒ ▒ ▄▀░▒██▒  ██▒ ▒██    ▒ ▓██░ ██▒▓█   ▀ ▓██▒    ▓██▒
░ ▓██▄   ▒▓█    ▄▒██▀▀██░▒██▒░ ▒ ▄▀▀▖ ▒██░  ██▒ ░ ▓██▄   ▒██▀▀██░▒███   ▒██░    ▒██░
  ▒   ██▒▒▓▓▄ ▄██░▓█ ░██ ░██░  ▄▀▀▀▄▄ ▒██   ██░   ▒   ██▒░▓█ ░██ ▒▓█  ▄ ▒██░    ▒██░
▒██████▒▒▒ ▓███▀ ░▓█▒░██▓░██░▒███████▒░ ████▓▒░ ▒██████▒▒░▓█▒░██▓░▒████▒░██████▒░██████▒
BANNER
echo -e "${RESET}${DARK_GRAY}  Niri · Noctalia · Kitty · mpvpaper · ZSH · Neovim+LazyVim  |  Arch Linux${RESET}\n"

# ═════════════════════════════════════════════════════════════════════════════
# ████████████████████    MENU INTERATTIVO TUI    █████████████████████████████
# ═════════════════════════════════════════════════════════════════════════════

# ── Definizione moduli ──────────────────────────────────────────────────────
declare -a MODULE_IDS=(
  "paru"
  "niri"
  "noctalia"
  "kitty"
  "niri_config"
  "mpvpaper"
  "zsh"
  "neovim"
)

declare -A MODULE_NAME=(
  [paru]="AUR Helper (paru)"
  [niri]="Niri + dipendenze Wayland"
  [noctalia]="Noctalia Shell"
  [kitty]="Kitty Terminal + config"
  [niri_config]="Niri config.kdl (Noctalia + keybinds)"
  [mpvpaper]="Wallpaper animato (mpvpaper systemd)"
  [zsh]="ZSH + Oh My Zsh + plugin + .zshrc"
  [neovim]="Neovim + LazyVim"
)

declare -A MODULE_DESC=(
  [paru]="Build paru da AUR — necessario per installare pacchetti AUR"
  [niri]="niri, xwayland-satellite, waybar, mako, fuzzel, swayidle, swaylock, udiskie, mpvpaper"
  [noctalia]="paru -S noctalia-shell  (desktop shell grafica per Niri)"
  [kitty]="Trasparenza 0.82, tab powerline, split, Rosé Pine, JetBrainsMono Nerd Font"
  [niri_config]="config.kdl: window-rules Noctalia, border viola, shadow, Vim+WASD binds"
  [mpvpaper]="Crea ~/.config/systemd/user/mpvpaper-wallpaper.service  (~/Scaricati/1.mp4)"
  [zsh]="syntax-hl, autosugg, history-substring, fzf-tab, Starship, alias eza/bat/niri/nvim"
  [neovim]="nvim da pacman + LazyVim starter clonato + headless plugin sync"
)

# Selezione di default: tutti on
declare -A MODULE_SEL=(
  [paru]=1
  [niri]=1
  [noctalia]=1
  [kitty]=1
  [niri_config]=1
  [mpvpaper]=1
  [zsh]=1
  [neovim]=1
)

# ── Calcola altezza fissa del menu (righe da ridisegnare) ───────────────────
# header(3) + (2 righe per modulo) + footer(2) = 3 + 16 + 2 = 21
MENU_LINES=$(( 3 + ${#MODULE_IDS[@]} * 2 + 2 ))

# ── Funzione: disegna il menu in-place ─────────────────────────────────────
draw_menu() {
  local cursor=$1
  printf "\e[${MENU_LINES}A"   # risali

  echo -e "${BOLD}${CYAN}  Seleziona i moduli da installare${RESET}"
  echo -e "${DARK_GRAY}  ↑↓ naviga   SPAZIO toggle   A tutto   N niente   INVIO conferma${RESET}"
  echo -e "${DARK_GRAY}  ──────────────────────────────────────────────────────────────────${RESET}"

  local i=0
  for id in "${MODULE_IDS[@]}"; do
    local sel="${MODULE_SEL[$id]}"

    local checkbox
    if [[ $sel -eq 1 ]]; then
      checkbox="${GREEN}[✓]${RESET}"
    else
      checkbox="${DARK_GRAY}[ ]${RESET}"
    fi

    if [[ $i -eq $cursor ]]; then
      # Riga selezionata: freccia + bold
      printf "  ${MAGENTA}▶${RESET} %b %-40s\n" "$checkbox" "${BOLD}${MODULE_NAME[$id]}${RESET}"
      # Riga descrizione: visibile solo per il cursore
      printf "       ${DARK_GRAY}%-65s${RESET}\n" "${MODULE_DESC[$id]}"
    else
      printf "    %b %-40s\n" "$checkbox" "${MODULE_NAME[$id]}"
      printf "       %-65s\n" " "   # riga vuota: mantiene altezza fissa
    fi

    (( i++ ))
  done

  echo -e "${DARK_GRAY}  ──────────────────────────────────────────────────────────────────${RESET}"

  local count=0
  for id in "${MODULE_IDS[@]}"; do [[ ${MODULE_SEL[$id]} -eq 1 ]] && (( count++ )) || true; done
  printf "  ${CYAN}Selezionati: ${BOLD}%d/%d${RESET}  ${DARK_GRAY}(INVIO per confermare)${RESET}\n" \
    "$count" "${#MODULE_IDS[@]}"
}

# ── Stampa iniziale (riserva spazio a schermo) ──────────────────────────────
echo -e "${BOLD}${CYAN}  Seleziona i moduli da installare${RESET}"
echo -e "${DARK_GRAY}  ↑↓ naviga   SPAZIO toggle   A tutto   N niente   INVIO conferma${RESET}"
echo -e "${DARK_GRAY}  ──────────────────────────────────────────────────────────────────${RESET}"
for id in "${MODULE_IDS[@]}"; do
  echo -e "    ${GREEN}[✓]${RESET} ${MODULE_NAME[$id]}"
  echo -e "       ${DIM} ${RESET}"
done
echo -e "${DARK_GRAY}  ──────────────────────────────────────────────────────────────────${RESET}"
echo -e "  ${CYAN}Selezionati: ${BOLD}${#MODULE_IDS[@]}/${#MODULE_IDS[@]}${RESET}"

# ── Loop di input ───────────────────────────────────────────────────────────
cursor=0
draw_menu $cursor

_read_key() {
  local key seq1 seq2
  IFS= read -rsn1 key
  if [[ "$key" == $'\x1b' ]]; then
    IFS= read -rsn1 -t 0.1 seq1
    IFS= read -rsn1 -t 0.1 seq2
    key="${key}${seq1}${seq2}"
  fi
  printf '%s' "$key"
}

while true; do
  key=$(_read_key)
  case "$key" in
    $'\x1b[A'|k)
      (( cursor > 0 )) && (( cursor-- )) || true
      ;;
    $'\x1b[B'|j)
      (( cursor < ${#MODULE_IDS[@]} - 1 )) && (( cursor++ )) || true
      ;;
    ' ')
      id="${MODULE_IDS[$cursor]}"
      if [[ ${MODULE_SEL[$id]} -eq 1 ]]; then
        MODULE_SEL[$id]=0
      else
        MODULE_SEL[$id]=1
      fi
      ;;
    a|A)
      for id in "${MODULE_IDS[@]}"; do MODULE_SEL[$id]=1; done
      ;;
    n|N)
      for id in "${MODULE_IDS[@]}"; do MODULE_SEL[$id]=0; done
      ;;
    ''|$'\n')
      break
      ;;
  esac
  draw_menu $cursor
done

echo -e "\n"

# ── Riepilogo selezione ─────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}  Piano di installazione:${RESET}"
any_selected=0
for id in "${MODULE_IDS[@]}"; do
  if [[ ${MODULE_SEL[$id]} -eq 1 ]]; then
    echo -e "  ${GREEN}  ✓  ${MODULE_NAME[$id]}${RESET}"
    any_selected=1
  else
    echo -e "  ${DARK_GRAY}  ✗  ${MODULE_NAME[$id]}${RESET}"
  fi
done

if [[ $any_selected -eq 0 ]]; then
  echo -e "\n${YELLOW}  Nessun modulo selezionato. Uscita.${RESET}\n"
  exit 0
fi

echo ""
read -rp "$(echo -e "  ${MAGENTA}Procedere? [Y/n]: ${RESET}")" confirm < /dev/tty
[[ "$confirm" =~ ^[Nn]$ ]] && { echo -e "\n${YELLOW}  Annullato.${RESET}\n"; exit 0; }
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# ████████████████████    FUNZIONI DI INSTALLAZIONE    ████████████████████████
# ═════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────
install_paru() {
  print_step "0 · AUR helper (paru)"
  if ! pkg_installed paru; then
    sudo pacman -S --noconfirm --needed base-devel git &>/dev/null
    local TMP_PARU; TMP_PARU=$(mktemp -d)
    git clone https://aur.archlinux.org/paru.git "$TMP_PARU" &>/dev/null &
    spinner $! "Clone paru..."
    wait $!
    (cd "$TMP_PARU" && makepkg -si --noconfirm &>/dev/null) &
    spinner $! "Build paru..."
    wait $!
    rm -rf "$TMP_PARU"
    pkg_installed paru && print_ok "paru installato." || print_err "Installazione paru fallita."
  else
    print_ok "paru già presente."
  fi
}

# ─────────────────────────────────────────────────────────────
install_niri() {
  print_step "1 · Niri + dipendenze Wayland"
  local DEPS=(
    niri xwayland-satellite
    waybar mako fuzzel
    swaybg swayidle swaylock alacritty
    xdg-desktop-portal-gtk xdg-desktop-portal-gnome
    udiskie mpvpaper
  )
  paru -S --noconfirm --needed "${DEPS[@]}" &>/dev/null &
  spinner $! "Installo Niri + ecosistema Wayland..."
  wait $!
  pkg_installed niri && print_ok "Niri installato." || print_err "Installazione Niri fallita."
}

# ─────────────────────────────────────────────────────────────
install_noctalia() {
  print_step "2 · Noctalia Shell"
  if ! paru -Qi noctalia-shell &>/dev/null; then
    paru -S --noconfirm noctalia-shell &>/dev/null &
    spinner $! "Installo noctalia-shell da AUR..."
    wait $!
    print_ok "Noctalia Shell installata."
  else
    print_ok "Noctalia Shell già installata."
  fi
}

# ─────────────────────────────────────────────────────────────
install_kitty() {
  print_step "3 · Kitty Terminal"

  paru -S --noconfirm --needed kitty ttf-jetbrains-mono-nerd &>/dev/null &
  spinner $! "Installo Kitty + JetBrainsMono Nerd Font..."
  wait $!
  pkg_installed kitty && print_ok "Kitty installato." || print_err "Kitty non trovato."
  fc-cache -fv &>/dev/null

  sudo update-alternatives --install /usr/bin/x-terminal-emulator \
    x-terminal-emulator "$(which kitty)" 50 &>/dev/null || true
  xdg-mime default kitty.desktop x-scheme-handler/terminal 2>/dev/null || true
  print_ok "Kitty impostato come terminale default."

  mkdir -p "$HOME/.config/kitty"
  cat > "$HOME/.config/kitty/kitty.conf" << 'KITTY_CONF'
# ╔══════════════════════════════════════╗
# ║        kitty.conf — SchizoShell     ║
# ╚══════════════════════════════════════╝

# ── Font ──────────────────────────────
font_family      JetBrainsMono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        12.0

# ── Trasparenza ───────────────────────
background_opacity      0.82
dynamic_background_opacity yes

# ── Tema: Rosé Pine ───────────────────
foreground           #e0def4
background           #191724
selection_foreground #e0def4
selection_background #403d52
cursor               #524f67
cursor_text_color    #e0def4

color0  #26233a
color1  #eb6f92
color2  #31748f
color3  #f6c177
color4  #9ccfd8
color5  #c4a7e7
color6  #ebbcba
color7  #e0def4
color8  #6e6a86
color9  #eb6f92
color10 #31748f
color11 #f6c177
color12 #9ccfd8
color13 #c4a7e7
color14 #ebbcba
color15 #e0def4

# ── Tab Bar ───────────────────────────
tab_bar_edge              top
tab_bar_style             powerline
tab_powerline_style       slanted
tab_title_template        " {index}: {title} "
active_tab_foreground     #191724
active_tab_background     #c4a7e7
inactive_tab_foreground   #6e6a86
inactive_tab_background   #26233a
tab_bar_background        #191724

# ── Window ────────────────────────────
window_padding_width    8
hide_window_decorations yes
confirm_os_window_close 0
draw_minimal_borders    yes

# ── Comportamento ─────────────────────
scrollback_lines     10000
copy_on_select       yes
strip_trailing_spaces smart
enable_audio_bell    no
visual_bell_duration 0.1
kitty_mod            ctrl+shift

# ── Shortcuts: Tab ────────────────────
map ctrl+shift+t        new_tab_with_cwd
map ctrl+shift+w        close_tab
map ctrl+shift+right    next_tab
map ctrl+shift+left     previous_tab
map ctrl+shift+alt+t    set_tab_title

# ── Shortcuts: Split/finestre ─────────
map ctrl+shift+enter        new_window_with_cwd
map ctrl+shift+minus        launch --location=hsplit --cwd=current
map ctrl+shift+backslash    launch --location=vsplit --cwd=current
map ctrl+shift+h            neighboring_window left
map ctrl+shift+l            neighboring_window right
map ctrl+shift+k            neighboring_window up
map ctrl+shift+j            neighboring_window down
map ctrl+shift+z            toggle_layout stack
map ctrl+alt+n              new_os_window_with_cwd

# ── Shell integration ─────────────────
shell_integration enabled
KITTY_CONF

  print_ok "Config Kitty → ~/.config/kitty/kitty.conf"
}

# ─────────────────────────────────────────────────────────────
install_niri_config() {
  print_step "4 · Niri config.kdl"

  mkdir -p "$HOME/.config/niri"
  [[ -f "$HOME/.config/niri/config.kdl" ]] && \
    cp "$HOME/.config/niri/config.kdl" \
       "$HOME/.config/niri/config.kdl.bak.$(date +%s)" && \
    print_info "Backup config esistente salvato."

  cat > "$HOME/.config/niri/config.kdl" << 'NIRI_CONF'
// ╔══════════════════════════════════════════════════════════╗
// ║         niri config.kdl — SchizoShell Edition           ║
// ╚══════════════════════════════════════════════════════════╝

// ── Input ────────────────────────────────────────────────────
input {
    keyboard {
        xkb {
            layout "it"
            // options "ctrl:nocaps"
        }
        repeat-delay 600
        repeat-rate  25
    }
    touchpad {
        tap
        dwt
        natural-scroll
        accel-speed   0.2
        accel-profile "adaptive"
    }
    mouse { accel-speed 0.0 }
}

// ── Output ───────────────────────────────────────────────────
// Configura dopo aver eseguito: niri msg outputs
// Esempio:
// output "HDMI-A-1" {
//     mode "2560x1440@60.000"
//     scale 1.25
// }
// output "eDP-1" { scale 1.0 }

// ── Layout ───────────────────────────────────────────────────
layout {
    gaps 12
    center-focused-column "never"
    default-column-width { proportion 0.5; }
    background-color "transparent"

    border {
        width 2
        active-color   "#c4a7e7"
        inactive-color "#403d52"
    }

    shadow {
        on
        offset-x 0
        offset-y 4
        spread   8
        blur     24
        color    "#00000066"
    }
}

// ── Noctalia: rounded corners ────────────────────────────────
window-rule {
    geometry-corner-radius 20
    clip-to-geometry true
}

// ── Noctalia: XDG activation ─────────────────────────────────
debug {
    honor-xdg-activation-with-invalid-serial
}

// ── Noctalia: overview wallpaper sfocato (Option 1) ──────────
// Richiede "Enable overview wallpaper" ON in Noctalia settings
layer-rule {
    match namespace="^noctalia-overview*"
    place-within-backdrop true
}

// ── Overview ─────────────────────────────────────────────────
overview {
    workspace-shadow { on }
}

// ── Regole app specifiche ─────────────────────────────────────
window-rule {
    match app-id="kitty"
    default-column-width { proportion 0.5; }
}
window-rule {
    match app-id="fuzzel"
    open-floating true
}

// ── Autostart ────────────────────────────────────────────────
spawn-at-startup "mako"
spawn-at-startup "waybar"
spawn-at-startup "udiskie" "--tray"
spawn-at-startup "xwayland-satellite"
// Il wallpaper animato è gestito da systemd (mpvpaper-wallpaper.service)

// ── Keybindings ──────────────────────────────────────────────
binds {
    Mod+T { spawn "kitty"; }
    Mod+D { spawn "fuzzel"; }
    Mod+Q { close-window; }
    Mod+F { maximize-column; }
    Mod+Shift+F { fullscreen-window; }

    // Sistema
    Mod+Ctrl+L  { spawn "swaylock" "-f" "-c" "191724"; }
    Mod+Shift+E { quit; }
    Mod+Shift+P { power-off-monitors; }

    // Screenshot
    Print      { screenshot; }
    Ctrl+Print { screenshot-screen; }
    Alt+Print  { screenshot-window; }

    // Overview
    Mod+O { toggle-overview; }

    // Navigazione Vim
    Mod+H { focus-column-left; }
    Mod+L { focus-column-right; }
    Mod+J { focus-window-or-workspace-down; }
    Mod+K { focus-window-or-workspace-up; }

    // Navigazione WASD
    Mod+A { focus-column-left; }
    Mod+S { focus-window-or-workspace-down; }
    Mod+W { focus-window-or-workspace-up; }

    // Sposta (Vim)
    Mod+Shift+H { move-column-left; }
    Mod+Shift+L { move-column-right; }
    Mod+Shift+J { move-window-down-or-to-workspace-below; }
    Mod+Shift+K { move-window-up-or-to-workspace-above; }

    // Ridimensiona
    Mod+minus       { set-column-width "-5%"; }
    Mod+equal       { set-column-width "+5%"; }
    Mod+Shift+minus { set-window-height "-5%"; }
    Mod+Shift+equal { set-window-height "+5%"; }

    // Workspace 1-5
    Mod+1 { focus-workspace 1; }  Mod+Shift+1 { move-window-to-workspace 1; }
    Mod+2 { focus-workspace 2; }  Mod+Shift+2 { move-window-to-workspace 2; }
    Mod+3 { focus-workspace 3; }  Mod+Shift+3 { move-window-to-workspace 3; }
    Mod+4 { focus-workspace 4; }  Mod+Shift+4 { move-window-to-workspace 4; }
    Mod+5 { focus-workspace 5; }  Mod+Shift+5 { move-window-to-workspace 5; }

    // Audio
    XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
    XF86AudioMute        allow-when-locked=true { spawn "wpctl" "set-mute"   "@DEFAULT_AUDIO_SINK@" "toggle"; }

    // Luminosità
    XF86MonBrightnessUp   { spawn "brightnessctl" "set" "+10%"; }
    XF86MonBrightnessDown { spawn "brightnessctl" "set" "10%-"; }
}
NIRI_CONF

  print_ok "config.kdl → ~/.config/niri/config.kdl"
}

# ─────────────────────────────────────────────────────────────
install_mpvpaper() {
  print_step "5 · mpvpaper — wallpaper animato"

  local SVCDIR="$HOME/.config/systemd/user"
  local VIDEO="$HOME/Scaricati/1.mp4"
  mkdir -p "$SVCDIR"

  cat > "$SVCDIR/mpvpaper-wallpaper.service" << SVCFILE
[Unit]
Description=mpvpaper animated wallpaper — SchizoShell
PartOf=graphical-session.target
After=graphical-session.target
ConditionPathExists=${VIDEO}

[Service]
Type=simple
ExecStart=mpvpaper "*" --mpv-options="--loop-file=inf --no-audio" ${VIDEO}
Restart=on-failure
RestartSec=3
Environment=WAYLAND_DISPLAY=wayland-1

[Install]
WantedBy=graphical-session.target
SVCFILE

  systemctl --user daemon-reload
  systemctl --user enable mpvpaper-wallpaper.service 2>/dev/null || true
  print_ok "Servizio creato e abilitato all'avvio."
  print_info "Comando: systemctl --user start mpvpaper-wallpaper"
  print_warn "Attivo solo se esiste: ${VIDEO}"
}

# ─────────────────────────────────────────────────────────────
install_zsh() {
  print_step "6 · ZSH + Oh My Zsh + plugin + .zshrc"

  # ZSH
  if ! pkg_installed zsh; then
    paru -S --noconfirm --needed zsh &>/dev/null &
    spinner $! "Installo zsh..."; wait $!
    print_ok "zsh installato."
  else
    print_ok "zsh già presente."
  fi

  local ZSH_PATH; ZSH_PATH="$(which zsh)"
  local CURRENT_SHELL; CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
    chsh -s "$ZSH_PATH" && print_ok "Shell default → zsh." || \
      print_warn "chsh fallito. Esegui: chsh -s ${ZSH_PATH}"
  else
    print_ok "zsh già shell default."
  fi

  # Tool extra
  paru -S --noconfirm --needed eza bat fzf starship zsh-completions &>/dev/null &
  spinner $! "Installo eza · bat · fzf · starship..."; wait $!
  print_ok "Tool shell installati."

  # Oh My Zsh
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    export RUNZSH=no KEEP_ZSHRC=yes
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
      "" --unattended &>/dev/null &
    spinner $! "Installo Oh My Zsh..."; wait $!
    [[ -d "$HOME/.oh-my-zsh" ]] && print_ok "Oh My Zsh installato." || \
      print_err "Installazione Oh My Zsh fallita."
  else
    print_ok "Oh My Zsh già installato."
  fi

  # Plugin
  local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  mkdir -p "$HOME/.zsh/plugins"

  clone_plugin "zsh-syntax-highlighting" \
    "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

  clone_plugin "zsh-autosuggestions" \
    "https://github.com/zsh-users/zsh-autosuggestions" \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

  clone_plugin "zsh-history-substring-search" \
    "https://github.com/zsh-users/zsh-history-substring-search" \
    "$HOME/.zsh/plugins/zsh-history-substring-search"

  clone_plugin "fzf-tab" \
    "https://github.com/Aloxaf/fzf-tab.git" \
    "$HOME/.zsh/plugins/fzf-tab"

  # Backup .zshrc
  [[ -f "$HOME/.zshrc" ]] && \
    cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%s)" && \
    print_info "Backup .zshrc precedente salvato."

  # .zshrc
  cat > "$HOME/.zshrc" << 'ZSHRC'
# ╔══════════════════════════════════════════════════════════════════╗
# ║                   .zshrc — SchizoShell Edition                  ║
# ║       Oh My Zsh · syntax-hl · autosugg · fzf-tab · Starship    ║
# ╚══════════════════════════════════════════════════════════════════╝

# ─────────────────────────────────────────────────────────────
# === OH MY ZSH ===
# ─────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""   # Starship gestisce il prompt

zstyle ':omz:update' mode silent
zstyle ':omz:update' frequency 14

plugins=(
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
  sudo               # doppio ESC → aggiunge sudo
  archlinux          # alias pacman/paru
  colored-man-pages
  extract            # 'x file.tar.gz' estrae tutto
  fzf
  z                  # jump directory frequenti
)

source "$ZSH/oh-my-zsh.sh"

# ─────────────────────────────────────────────────────────────
# === PLUGIN EXTRA ===
# ─────────────────────────────────────────────────────────────
ZSH_PLUGINS="$HOME/.zsh/plugins"

[[ -f "$ZSH_PLUGINS/zsh-history-substring-search/zsh-history-substring-search.zsh" ]] && \
  source "$ZSH_PLUGINS/zsh-history-substring-search/zsh-history-substring-search.zsh"

# fzf-tab: DEVE stare dopo compinit, prima di altri wrapper
[[ -f "$ZSH_PLUGINS/fzf-tab/fzf-tab.zsh" ]] && \
  source "$ZSH_PLUGINS/fzf-tab/fzf-tab.zsh"

# ─────────────────────────────────────────────────────────────
# === COMPLETAMENTO ===
# ─────────────────────────────────────────────────────────────
autoload -Uz compinit
# Rigenera .zcompdump solo se > 24h
if [[ -n "$HOME/.zcompdump"(#qN.mh+24) ]]; then compinit; else compinit -C; fi

setopt AUTO_LIST COMPLETE_IN_WORD MENU_COMPLETE

# fzf-tab: preview contestuale
zstyle ':fzf-tab:complete:cd:*' fzf-preview \
  'eza --icons -1 --color=always $realpath 2>/dev/null'
zstyle ':fzf-tab:complete:*:*' fzf-preview \
  'less ${(Q)realpath} 2>/dev/null'
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select

# ─────────────────────────────────────────────────────────────
# === HISTORY ===
# ─────────────────────────────────────────────────────────────
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
setopt SHARE_HISTORY EXTENDED_HISTORY

# ─────────────────────────────────────────────────────────────
# === KEYBINDINGS ===
# ─────────────────────────────────────────────────────────────
bindkey '^[[A'    history-substring-search-up
bindkey '^[[B'    history-substring-search-down
bindkey '^[[3~'   delete-char
bindkey '^[[H'    beginning-of-line
bindkey '^[[F'    end-of-line
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^f'      autosuggest-accept   # Ctrl+F accetta

# ─────────────────────────────────────────────────────────────
# === AUTOSUGGESTIONS ===
# ─────────────────────────────────────────────────────────────
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6e6a86,italic"
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=30

# ─────────────────────────────────────────────────────────────
# === SYNTAX HIGHLIGHTING ===
# ─────────────────────────────────────────────────────────────
ZSH_HIGHLIGHT_STYLES[command]='fg=cyan,bold'
ZSH_HIGHLIGHT_STYLES[path]='fg=#9ccfd8,underline'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#c4a7e7'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#31748f'
ZSH_HIGHLIGHT_STYLES[function]='fg=#f6c177'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#eb6f92,bold'

# ─────────────────────────────────────────────────────────────
# === XTERM TITLE (tab Kitty) ===
# ─────────────────────────────────────────────────────────────
function xterm_title_precmd()  { print -Pn -- '\e]2;%n@%m %~\a'; }
function xterm_title_preexec() { print -Pn -- '\e]2;%n@%m %~ %# ' && print -n -- "${(q)1}\a"; }
if [[ "$TERM" == (kitty*|xterm*|alacritty*|screen*|tmux*) ]]; then
  add-zsh-hook -Uz precmd  xterm_title_precmd
  add-zsh-hook -Uz preexec xterm_title_preexec
fi

# ─────────────────────────────────────────────────────────────
# === ALIAS ===
# ─────────────────────────────────────────────────────────────
# Navigazione
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# File listing
alias ls='eza --icons=always --color=always -a'
alias ll='eza --icons=always --color=always -la --git'
alias lt='eza --icons=always --color=always --tree --level=2'
alias lta='eza --icons=always --color=always --tree'

# Cat
alias cat='bat --theme=base16'

# Arch / paru
alias update='paru -Syu --nocombinedupgrade'
alias install='paru -S'
alias search='paru -Ss'
alias remove='sudo pacman -Rns'
alias orphans='paru -Qtdq | paru -Rns - 2>/dev/null || echo "Nessun orfano."'
alias mirrors='sudo reflector --verbose --latest 10 --country Italy,Germany --age 12 --sort rate --save /etc/pacman.d/mirrorlist'

# Git
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --decorate --color'
alias gd='git diff --color'

# Niri
alias niri-outputs='niri msg outputs'
alias niri-validate='niri validate'

# Wallpaper animato (alias rapidi)
alias wallpaper-on='systemctl --user start mpvpaper-wallpaper'
alias wallpaper-off='systemctl --user stop mpvpaper-wallpaper'

# Systemd user
alias sstart='systemctl --user start'
alias sstop='systemctl --user stop'
alias sstatus='systemctl --user status'

# Neovim
alias v='nvim'
alias vi='nvim'
alias vim='nvim'

# Utility
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ports='ss -tulpn'
alias myip='curl -s ifconfig.me'
alias cls='clear'

# ─────────────────────────────────────────────────────────────
# === PATH & ENV ===
# ─────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:/opt/nvim:$PATH"
export EDITOR="nvim"
export VISUAL="nvim"
export BROWSER="firefox"
export TERM="xterm-256color"

# ─────────────────────────────────────────────────────────────
# === FZF ===
# ─────────────────────────────────────────────────────────────
export FZF_DEFAULT_OPTS="
  --height 40% --layout=reverse --border rounded
  --color=bg:#191724,bg+:#26233a,fg:#e0def4,fg+:#e0def4
  --color=hl:#eb6f92,hl+:#eb6f92,info:#9ccfd8,marker:#f6c177
  --color=prompt:#c4a7e7,spinner:#9ccfd8,pointer:#c4a7e7,header:#6e6a86
  --color=border:#403d52
  --prompt='  ' --pointer='▶' --marker='✓'
"
export FZF_DEFAULT_COMMAND='find . -type f 2>/dev/null'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# ─────────────────────────────────────────────────────────────
# === STARSHIP PROMPT ===
# ─────────────────────────────────────────────────────────────
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
else
  # Fallback prompt stile back_broken
  autoload -Uz vcs_info
  precmd() { vcs_info }
  zstyle ':vcs_info:git:*' formats ' %F{yellow}(%b)%f'
  function _dir_icon { [[ "$PWD" == "$HOME" ]] && echo "~" || echo ""; }
  PS1='%F{magenta}╭── %B%F{blue}%n%f%b $(_dir_icon) %B%F{red}%~%f%b${vcs_info_msg_0_}%f
%F{magenta}╰─%B%F{15}$%b%F{reset} '
fi

# ─────────────────────────────────────────────────────────────
# === WELCOME ===
# ─────────────────────────────────────────────────────────────
if command -v fastfetch &>/dev/null; then
  fastfetch
elif command -v neofetch &>/dev/null; then
  neofetch
fi
ZSHRC

  print_ok ".zshrc → ~/.zshrc"

  # Starship config
  if [[ ! -f "$HOME/.config/starship.toml" ]]; then
    mkdir -p "$HOME/.config"
    cat > "$HOME/.config/starship.toml" << 'STARSHIP'
"$schema" = 'https://starship.rs/config-schema.json'

format = """
[╭──](magenta)[$username](bold blue) [$directory](bold red)[$git_branch$git_status](yellow)[$cmd_duration](bold cyan)
[╰─](magenta)[$character](bold white) """

[username]
style_user  = "bold blue"
style_root  = "bold red"
show_always = true

[directory]
style             = "bold red"
truncate_to_repo  = false
truncation_length = 4
read_only         = " 󰌾"

[git_branch]
symbol = " "
style  = "bold yellow"

[git_status]
style = "bold yellow"

[cmd_duration]
min_time = 2000
format   = " [$duration]($style)"
style    = "bold cyan"

[character]
success_symbol = "[❯](bold green)"
error_symbol   = "[❯](bold red)"
STARSHIP
    print_ok "Starship → ~/.config/starship.toml"
  fi
}

# ─────────────────────────────────────────────────────────────
install_neovim() {
  print_step "7 · Neovim + LazyVim"

  paru -S --noconfirm --needed \
    neovim nodejs npm python ripgrep fd lazygit unzip &>/dev/null &
  spinner $! "Installo Neovim + dipendenze LazyVim..."; wait $!
  pkg_installed nvim && print_ok "Neovim $(nvim --version | head -1) installato." || \
    print_err "Neovim non trovato."

  if [[ ! -d "$HOME/.config/nvim/.git" ]]; then
    [[ -d "$HOME/.config/nvim" ]] && \
      mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak.$(date +%s)" && \
      print_info "Backup config nvim salvato."

    git clone --depth=1 https://github.com/LazyVim/starter \
      "$HOME/.config/nvim" &>/dev/null &
    spinner $! "Clone LazyVim starter..."; wait $!
    rm -rf "$HOME/.config/nvim/.git"

    print_info "Sync plugin headless (un momento)..."
    nvim --headless "+Lazy! sync" +qa 2>/dev/null &
    spinner $! "Sync LazyVim plugins..."; wait $! || true
    print_ok "LazyVim installato."
  else
    print_ok "Config Neovim già presente."
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# ████████████████████    DISPATCH ████████████████████████████████████████████
# ═════════════════════════════════════════════════════════════════════════════

INSTALLED_MODULES=()
SKIPPED_MODULES=()

run_if_selected() {
  local id="$1" fn="$2"
  if [[ "${MODULE_SEL[$id]}" -eq 1 ]]; then
    "$fn"
    INSTALLED_MODULES+=("${MODULE_NAME[$id]}")
  else
    print_skip "${MODULE_NAME[$id]}"
    SKIPPED_MODULES+=("${MODULE_NAME[$id]}")
  fi
}

run_if_selected "paru"        install_paru
run_if_selected "niri"        install_niri
run_if_selected "noctalia"    install_noctalia
run_if_selected "kitty"       install_kitty
run_if_selected "niri_config" install_niri_config
run_if_selected "mpvpaper"    install_mpvpaper
run_if_selected "zsh"         install_zsh
run_if_selected "neovim"      install_neovim

# ═════════════════════════════════════════════════════════════════════════════
# ████████████████████    RIEPILOGO    ████████████████████████████████████████
# ═════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}${MAGENTA}══════ ✅  Setup completato ══════${RESET}\n"

echo -e "${BOLD}${GREEN}  Installati (${#INSTALLED_MODULES[@]}):${RESET}"
for m in "${INSTALLED_MODULES[@]}"; do echo -e "  ${GREEN}  ✓  ${m}${RESET}"; done

if [[ ${#SKIPPED_MODULES[@]} -gt 0 ]]; then
  echo -e "\n${BOLD}${DARK_GRAY}  Saltati (${#SKIPPED_MODULES[@]}):${RESET}"
  for m in "${SKIPPED_MODULES[@]}"; do echo -e "  ${DARK_GRAY}  ✗  ${m}${RESET}"; done
fi

echo ""
echo -e "${YELLOW}  PROSSIMI PASSI:${RESET}"
echo -e "  ${CYAN}1${RESET}  ${BOLD}niri-session${RESET}                                → avvia Niri"
echo -e "  ${CYAN}2${RESET}  ${BOLD}niri msg outputs${RESET}                            → identifica monitor"
echo -e "  ${CYAN}3${RESET}  ${BOLD}systemctl --user start mpvpaper-wallpaper${RESET}   → wallpaper animato"
echo -e "  ${CYAN}4${RESET}  ${BOLD}exec zsh${RESET}                                    → ricarica shell"
echo -e "  ${CYAN}5${RESET}  ${BOLD}nvim${RESET}                                        → primo avvio LazyVim"
echo ""
echo -e "  ${DARK_GRAY}~/.config/niri/config.kdl   |   ~/.config/kitty/kitty.conf${RESET}"
echo -e "  ${DARK_GRAY}~/.zshrc   |   ~/.config/starship.toml   |   ~/.config/nvim/${RESET}"
echo ""
echo -e "${MAGENTA}  💀 SchizoShell è pronta. Buon caos.${RESET}\n"
