#!/bin/bash
# @desc: Installa tool di sviluppo con selezione interattiva (fzf)

GREEN="\e[92m"
RED="\e[38;5;160m"
CYAN="\e[96m"
YELLOW="\e[93m"
MAGENTA="\e[95m"
DARK_GRAY="\e[90m"
BOLD="\e[1m"
RESET="\e[0m"

print_ok()    { echo -e "${GREEN}✅ $1${RESET}"; }
print_err()   { echo -e "${RED}❌ $1${RESET}"; exit 1; }
print_warn()  { echo -e "${YELLOW}⚠️  $1${RESET}"; }
print_info()  { echo -e "${CYAN}ℹ️  $1${RESET}"; }
print_step()  { echo -e "\n${MAGENTA}➡️  $1${RESET}"; }
print_skip()  { echo -e "${DARK_GRAY}⏭️  $1 già installato — skip.${RESET}"; }

# ─────────────────────────────────────────────────────────────
# === SPINNER ===
# ─────────────────────────────────────────────────────────────
spinner() {
  local pid=$1
  local label="${2:-Attendere...}"
  local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${CYAN}${spinstr:$i:1}${RESET}  ${DARK_GRAY}${label}${RESET}   "
    i=$(( (i+1) % ${#spinstr} ))
    sleep 0.08
  done
  printf "\r%-60s\r" " "
}

# ─────────────────────────────────────────────────────────────
# === BANNER ===
# ─────────────────────────────────────────────────────────────
echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║    🛠️   INSTALL DEV TOOLS             ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════╝${RESET}"
echo -e "${DARK_GRAY}  Seleziona i tool da installare con SPAZIO, conferma con ENTER${RESET}\n"

# ─────────────────────────────────────────────────────────────
# === VERIFICA FZF ===
# ─────────────────────────────────────────────────────────────
if ! command -v fzf &>/dev/null; then
  print_err "fzf non trovato. Installalo prima di continuare."
fi

# ─────────────────────────────────────────────────────────────
# === RILEVA DISTRO E PKG MANAGER ===
# ─────────────────────────────────────────────────────────────
DISTRO=""
PKG_INSTALL=""
PKG_UPDATE=""
HAS_AUR=0

if [[ "$OSTYPE" == "darwin"* ]]; then
  DISTRO="macos"
  PKG_INSTALL="brew install"
  PKG_UPDATE="brew update"
elif [[ -f /etc/arch-release ]]; then
  DISTRO="arch"
  PKG_INSTALL="sudo pacman -S --noconfirm"
  PKG_UPDATE="sudo pacman -Syu --noconfirm"
  # Installa yay se mancante
  if ! command -v yay &>/dev/null; then
    print_step "yay non trovato — installazione AUR helper..."
    sudo pacman -S --needed --noconfirm git base-devel
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay" &>/dev/null
    (cd "$tmpdir/yay" && makepkg -si --noconfirm &>/dev/null)
    rm -rf "$tmpdir"
    command -v yay &>/dev/null && print_ok "yay installato." || print_warn "yay non installato — i pacchetti AUR saranno saltati."
  fi
  command -v yay &>/dev/null && HAS_AUR=1
elif [[ -f /etc/debian_version ]]; then
  DISTRO="debian"
  PKG_INSTALL="sudo apt install -y"
  PKG_UPDATE="sudo apt update"
elif [[ -f /etc/fedora-release ]]; then
  DISTRO="fedora"
  PKG_INSTALL="sudo dnf install -y"
  PKG_UPDATE="sudo dnf check-update; true"
elif [[ -f /etc/redhat-release ]]; then
  DISTRO="rhel"
  PKG_INSTALL="sudo yum install -y"
  PKG_UPDATE="sudo yum update -y"
elif grep -qi opensuse /etc/os-release 2>/dev/null; then
  DISTRO="opensuse"
  PKG_INSTALL="sudo zypper install -y"
  PKG_UPDATE="sudo zypper refresh"
else
  print_err "Distribuzione non supportata."
fi

print_info "Distro rilevata: ${CYAN}${DISTRO}${RESET}"

# ─────────────────────────────────────────────────────────────
# === CATALOGO PACCHETTI ===
# Formato: "label|check_cmd|arch_pkg|debian_pkg|fedora_pkg|macos_pkg|aur_pkg|post_install"
# aur_pkg: usato solo su Arch se HAS_AUR=1 (ha precedenza su arch_pkg)
# post_install: comando da eseguire dopo (es. per npm global, systemctl)
# ─────────────────────────────────────────────────────────────
declare -A PKG_CHECK PKG_ARCH PKG_DEB PKG_FED PKG_MAC PKG_AUR PKG_POST PKG_GROUP

_def() {
  local label="$1"
  PKG_CHECK["$label"]="$2"
  PKG_ARCH["$label"]="$3"
  PKG_DEB["$label"]="$4"
  PKG_FED["$label"]="$5"
  PKG_MAC["$label"]="$6"
  PKG_AUR["$label"]="$7"
  PKG_POST["$label"]="$8"
  PKG_GROUP["$label"]="$9"
}

# label | check | arch | deb | fedora | mac | aur | post | group
_def "Visual Studio Code"  "code"        ""          "code"           "code"          "visual-studio-code" "code"               ""                                                   "Editor"
_def "Neovim"              "nvim"        "neovim"    "neovim"         "neovim"        "neovim"             ""                   ""                                                   "Editor"
_def "Micro"               "micro"       "micro"     "micro"          "micro"         "micro"              ""                   ""                                                   "Editor"
_def "Docker"              "docker"      "docker"    "docker.io"      "docker"        "docker"             ""                   "sudo systemctl enable --now docker"                 "DevOps"
_def "Docker Compose"      "docker-compose" "docker-compose" "docker-compose" "docker-compose" "docker-compose" ""              ""                                                   "DevOps"
_def "kubectl"             "kubectl"     "kubectl"   "kubectl"        "kubernetes-client" "kubectl"        ""                   ""                                                   "DevOps"
_def "PostgreSQL"          "psql"        "postgresql" "postgresql"    "postgresql"    "postgresql"         ""                   "sudo systemctl enable --now postgresql"             "Database"
_def "MySQL"               "mysql"       "mysql"     "mysql-server"   "mysql-server"  "mysql"              ""                   "sudo systemctl enable --now mysql"                  "Database"
_def "Redis"               "redis-cli"   "redis"     "redis"          "redis"         "redis"              ""                   "sudo systemctl enable --now redis"                  "Database"
_def "Node.js + npm"       "node"        "nodejs npm" "nodejs npm"    "nodejs npm"    "node"               ""                   ""                                                   "Frontend"
_def "Angular CLI"         "ng"          ""          ""               ""              ""                   ""                   "sudo npm install -g @angular/cli"                   "Frontend"
_def "Vite"                "vite"        ""          ""               ""              ""                   ""                   "sudo npm install -g vite"                           "Frontend"
_def "Python + pip"        "python3"     "python python-pip" "python3 python3-pip" "python3 python3-pip" "python3"  ""         ""                                                   "Backend"
_def "Java (JDK 21)"       "java"        "jdk21-openjdk" "openjdk-21-jdk" "java-21-openjdk" "openjdk@21" ""          ""                                                   "Backend"
_def "Maven"               "mvn"         "maven"     "maven"          "maven"         "maven"              ""                   ""                                                   "Backend"
_def "Gradle"              "gradle"      "gradle"    "gradle"         "gradle"        "gradle"             ""                   ""                                                   "Backend"
_def "Go"                  "go"          "go"        "golang"         "golang"        "go"                 ""                   ""                                                   "Backend"
_def "Rust"                "rustc"       "rust"      "rustc"          "rust"          "rust"               ""                   ""                                                   "Backend"
_def "WezTerm"             "wezterm"     ""          ""               ""              "wezterm"            "wezterm-bin"        ""                                                   "Terminal"
_def "Alacritty"           "alacritty"   "alacritty" "alacritty"      "alacritty"     "alacritty"          ""                   ""                                                   "Terminal"
_def "tmux"                "tmux"        "tmux"      "tmux"           "tmux"          "tmux"               ""                   ""                                                   "Terminal"
_def "Firefox"             "firefox"     "firefox"   "firefox"        "firefox"       "firefox"            ""                   ""                                                   "Browser"
_def "Spotify"             "spotify"     ""          ""               ""              "spotify"            "spotify"            ""                                                   "Media"
_def "Discord"             "discord"     "discord"   "discord"        "discord"       "discord"            ""                   ""                                                   "Media"
_def "Obsidian"            "obsidian"    ""          ""               ""              "obsidian"           "obsidian"           ""                                                   "Produttività"
_def "Bitwarden CLI"       "bw"          "bitwarden-cli" ""           ""              "bitwarden-cli"      ""                   ""                                                   "Sicurezza"
_def "git"                 "git"         "git"       "git"            "git"           "git"                ""                   ""                                                   "Base"
_def "curl"                "curl"        "curl"      "curl"           "curl"          "curl"               ""                   ""                                                   "Base"
_def "jq"                  "jq"          "jq"        "jq"             "jq"            "jq"                 ""                   ""                                                   "Base"
_def "fzf"                 "fzf"         "fzf"       "fzf"            "fzf"           "fzf"                ""                   ""                                                   "Base"
_def "eza"                 "eza"         "eza"       ""               ""              "eza"                "eza"                ""                                                   "Base"
_def "bat"                 "bat"         "bat"       "bat"            "bat"           "bat"                ""                   ""                                                   "Base"
_def "htop"                "htop"        "htop"      "htop"           "htop"          "htop"               ""                   ""                                                   "Base"

# ─────────────────────────────────────────────────────────────
# === MENU FZF MULTI-SELECT ===
# Raggruppa per categoria, mostra se già installato
# ─────────────────────────────────────────────────────────────
print_step "Selezione pacchetti..."
echo -e "${DARK_GRAY}  TAB = seleziona/deseleziona  |  ENTER = conferma  |  ESC = annulla${RESET}\n"

_is_installed() {
  local check="$1"
  [[ -z "$check" ]] && return 1
  command -v "$check" &>/dev/null
}

# Costruisce lista per fzf con gruppo e stato
fzf_list=""
declare -a ALL_LABELS
for label in "${!PKG_CHECK[@]}"; do
  ALL_LABELS+=("$label")
done

# Ordina per gruppo poi per nome
IFS=$'\n' sorted_labels=($(
  for label in "${ALL_LABELS[@]}"; do
    echo "${PKG_GROUP[$label]}|${label}"
  done | sort | cut -d'|' -f2
))
unset IFS

for label in "${sorted_labels[@]}"; do
  group="${PKG_GROUP[$label]}"
  if _is_installed "${PKG_CHECK[$label]}"; then
    status="${DARK_GRAY}[già installato]${RESET}"
  else
    status="${GREEN}[da installare]${RESET}"
  fi
  fzf_list+="$(printf "%-30s  %-15s  %s" "$label" "[$group]" "$status")\n"
done

selected=$(printf "%b" "$fzf_list" | \
  fzf \
    --multi \
    --height=70% --layout=reverse --border \
    --prompt="📦 Pacchetti > " \
    --header="  TAB seleziona · ENTER conferma · ESC annulla" \
    --color=fg:#d6de35,bg:#121212,hl:#5f87af \
    --color=fg+:#00ffd9,bg+:#5c00e6,hl+:#5fd7ff \
    --color=pointer:green,marker:yellow,header:italic \
    --bind="space:toggle" \
    --marker="✓" \
    --ansi \
  | sed 's/^[[:space:]]*//' | awk '{print $1, $2, $3, $4}' | sed 's/ *\[.*$//' | sed 's/[[:space:]]*$//')

if [[ -z "$selected" ]]; then
  print_warn "Nessun pacchetto selezionato. Uscita."
  exit 0
fi

# ─────────────────────────────────────────────────────────────
# === AGGIORNAMENTO SISTEMA ===
# ─────────────────────────────────────────────────────────────
print_step "Aggiornamento indice pacchetti..."
eval "$PKG_UPDATE" &
spinner $! "Aggiornamento..."
wait $!
print_ok "Sistema aggiornato."

# ─────────────────────────────────────────────────────────────
# === INSTALLAZIONE ===
# ─────────────────────────────────────────────────────────────
print_step "Installazione pacchetti selezionati..."
echo ""

INSTALLED=()
SKIPPED=()
FAILED=()

while IFS= read -r label; do
  [[ -z "$label" ]] && continue

  # Cerca il match esatto nella mappa
  matched=""
  for k in "${!PKG_CHECK[@]}"; do
    [[ "$k" == "$label" ]] && matched="$k" && break
  done
  [[ -z "$matched" ]] && continue

  # Già installato?
  if _is_installed "${PKG_CHECK[$matched]}"; then
    print_skip "$matched"
    SKIPPED+=("$matched")
    continue
  fi

  # Scegli pkg corretto per distro
  pkg=""
  case "$DISTRO" in
    arch)
      if [[ "$HAS_AUR" -eq 1 && -n "${PKG_AUR[$matched]}" ]]; then
        pkg="${PKG_AUR[$matched]}"
        cmd="yay -S --noconfirm $pkg"
      elif [[ -n "${PKG_ARCH[$matched]}" ]]; then
        pkg="${PKG_ARCH[$matched]}"
        cmd="sudo pacman -S --noconfirm $pkg"
      fi
      ;;
    debian)   [[ -n "${PKG_DEB[$matched]}" ]]  && pkg="${PKG_DEB[$matched]}"  && cmd="$PKG_INSTALL $pkg" ;;
    fedora)   [[ -n "${PKG_FED[$matched]}" ]]  && pkg="${PKG_FED[$matched]}"  && cmd="$PKG_INSTALL $pkg" ;;
    rhel)     [[ -n "${PKG_FED[$matched]}" ]]  && pkg="${PKG_FED[$matched]}"  && cmd="$PKG_INSTALL $pkg" ;;
    macos)    [[ -n "${PKG_MAC[$matched]}" ]]  && pkg="${PKG_MAC[$matched]}"  && cmd="$PKG_INSTALL $pkg" ;;
    opensuse) [[ -n "${PKG_ARCH[$matched]}" ]] && pkg="${PKG_ARCH[$matched]}" && cmd="$PKG_INSTALL $pkg" ;;
  esac

  # Post-install only (es. Angular CLI via npm)
  if [[ -z "$pkg" && -n "${PKG_POST[$matched]}" ]]; then
    echo -ne "  ${CYAN}⠿${RESET}  ${DARK_GRAY}Installo ${matched}...${RESET}"
    eval "${PKG_POST[$matched]}" &>/dev/null &
    spinner $! "Installo $matched..."
    wait $!
    if _is_installed "${PKG_CHECK[$matched]}"; then
      print_ok "$matched"
      INSTALLED+=("$matched")
    else
      print_warn "$matched — installazione post-hook fallita."
      FAILED+=("$matched")
    fi
    continue
  fi

  if [[ -z "$pkg" ]]; then
    print_warn "$matched — non disponibile per ${DISTRO}."
    FAILED+=("$matched")
    continue
  fi

  # Installa
  eval "$cmd" &>/dev/null &
  spinner $! "Installo $matched..."
  wait $!

  if _is_installed "${PKG_CHECK[$matched]}"; then
    print_ok "$matched"
    INSTALLED+=("$matched")
    # Post-install (es. systemctl enable)
    if [[ -n "${PKG_POST[$matched]}" ]]; then
      eval "${PKG_POST[$matched]}" &>/dev/null || true
    fi
  else
    print_warn "$matched — installazione fallita."
    FAILED+=("$matched")
  fi

done <<< "$selected"

# ─────────────────────────────────────────────────────────────
# === RIEPILOGO ===
# ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}── Riepilogo ─────────────────────────────${RESET}"
echo -e "  ${GREEN}✅ Installati:   ${#INSTALLED[@]}${RESET}"
echo -e "  ${DARK_GRAY}⏭️  Già presenti: ${#SKIPPED[@]}${RESET}"
[[ ${#FAILED[@]} -gt 0 ]] && echo -e "  ${YELLOW}⚠️  Falliti:      ${#FAILED[@]} — ${FAILED[*]}${RESET}"
echo ""
echo -e "${GREEN}${BOLD}🎉 Installazione completata!${RESET}\n"