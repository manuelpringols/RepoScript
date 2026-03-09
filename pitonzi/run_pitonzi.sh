#!/bin/bash
# @desc: Launcher script Python con venv temporaneo in RAM e auto-risoluzione dipendenze

# ─────────────────────────────────────────────────────────────
# === PALETTE (coerente con marmitta) ===
# ─────────────────────────────────────────────────────────────
RED='\e[38;5;160m'
BLOOD_RED='\e[38;5;124m'
GREEN='\e[92m'
CYAN='\e[96m'
YELLOW='\e[93m'
MAGENTA='\e[95m'
ORANGE='\e[38;5;208m'
DARK_GRAY='\e[90m'
BOLD='\e[1m'
RESET='\e[0m'

print_ok()   { echo -e "${GREEN}✅ $1${RESET}"; }
print_err()  { echo -e "${RED}❌ $1${RESET}"; exit 1; }
print_warn() { echo -e "${YELLOW}⚠️  $1${RESET}"; }
print_info() { echo -e "${CYAN}ℹ️  $1${RESET}"; }
print_step() { echo -e "${MAGENTA}➡️  $1${RESET}"; }

# ─────────────────────────────────────────────────────────────
# === CONFIG ===
# ─────────────────────────────────────────────────────────────
MARMITTA_CONFIG="$HOME/.config/marmitta/config"
PITONZI_CACHE_DIR="$HOME/.config/marmitta/cache/pitonzi"
PITONZI_LAST="$HOME/.pitonzi_last"

GITHUB_TOKEN=""
AUTH_HEADER=()

# Carica token da marmitta config se disponibile
if [[ -f "$MARMITTA_CONFIG" ]]; then
  # shellcheck source=/dev/null
  source "$MARMITTA_CONFIG"
  [[ -n "$GITHUB_TOKEN" ]] && AUTH_HEADER=(-H "Authorization: token ${GITHUB_TOKEN}")
fi

mkdir -p "$PITONZI_CACHE_DIR"

# ─────────────────────────────────────────────────────────────
# === BANNER ===
# ─────────────────────────────────────────────────────────────
print_banner() {
  # P       I   T        O        N          Z        I
  echo -e "${RED}██████╗ ${CYAN}██╗${BLOOD_RED}████████╗${GREEN} ██████╗ ${MAGENTA}███╗   ██╗${YELLOW}███████╗${RED}██╗${RESET}"
  sleep 0.03
  echo -e "${RED}██╔══██╗${CYAN}██║${BLOOD_RED}╚══██╔══╝${GREEN}██╔═══██╗${MAGENTA}████╗  ██║${YELLOW}   ███╔╝${RED}██║${RESET}"
  sleep 0.03
  echo -e "${RED}██████╔╝${CYAN}██║${BLOOD_RED}   ██║  ${GREEN} ██║   ██║${MAGENTA}██╔██╗ ██║${YELLOW}  ███╔╝ ${RED}██║${RESET}"
  sleep 0.03
  echo -e "${RED}██╔═══╝ ${CYAN}██║${BLOOD_RED}   ██║  ${GREEN} ██║   ██║${MAGENTA}██║╚██╗██║${YELLOW} ███╔╝  ${RED}██║${RESET}"
  sleep 0.06
  echo -e "${RED}██║     ${CYAN}██║${BLOOD_RED}   ██║  ${GREEN} ╚██████╔╝${MAGENTA}██║ ╚████║${YELLOW}███████╗${RED}██║${RESET}"
  echo -e "${DARK_GRAY}╚═╝     ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝${RESET}"
  echo -e "\n${CYAN}${BOLD}  PITONZI — Python Script Launcher 🐍${RESET}"
  echo -e "${DARK_GRAY}  source: ${CURRENT_REPO}@${CURRENT_BRANCH}${RESET}\n"
}

# ─────────────────────────────────────────────────────────────
# === SOURCE SELECTION ===
# ─────────────────────────────────────────────────────────────
CURRENT_REPO=""
CURRENT_BRANCH="master"
CURRENT_BASE_URL=""
CURRENT_API_URL=""
SCRIPT_DESCS=""

select_source() {
  local sources_file="$HOME/.config/marmitta/sources"

  if [[ ! -f "$sources_file" ]] || ! grep -qv '^#' "$sources_file" 2>/dev/null; then
    # Nessuna source marmitta — chiedi direttamente
    read -rp "$(echo -e "${YELLOW}📦 Repo GitHub (es: manuelpringols/pitonzi): ${RESET}")" CURRENT_REPO < /dev/tty
    read -rp "$(echo -e "${YELLOW}🌿 Branch [master]: ${RESET}")" CURRENT_BRANCH < /dev/tty
    CURRENT_BRANCH="${CURRENT_BRANCH:-master}"
  else
    local sources
    sources=$(grep -v '^#' "$sources_file" | grep -v '^$')
    local count
    count=$(echo "$sources" | wc -l | tr -d ' ')

    local chosen
    if [[ "$count" -le 1 ]]; then
      chosen="$sources"
    else
      chosen=$(echo "$sources" | \
        fzf \
          --height=12 --layout=reverse --border \
          --prompt="🐍 Source Python > " \
          --delimiter="|" --with-nth=1,2 \
          --header="  Seleziona il repo con gli script Python" \
          --color=fg:#d6de35,bg:#121212,hl:#5f87af \
          --color=fg+:#00ffd9,bg+:#5c00e6,hl+:#5fd7ff \
          --color=pointer:green,header:italic \
          --ansi)
      [[ -z "$chosen" ]] && echo -e "${DARK_GRAY}Annullato.${RESET}" && exit 0
    fi

    CURRENT_REPO=$(echo "$chosen"   | cut -d'|' -f2 | xargs)
    CURRENT_BRANCH=$(echo "$chosen" | cut -d'|' -f3 | xargs)
    CURRENT_BRANCH="${CURRENT_BRANCH:-master}"
  fi

  CURRENT_BASE_URL="https://raw.githubusercontent.com/${CURRENT_REPO}/${CURRENT_BRANCH}"
  CURRENT_API_URL="https://api.github.com/repos/${CURRENT_REPO}/contents"
}

# ─────────────────────────────────────────────────────────────
# === DESCRIZIONI (cache locale, stesso meccanismo di marmitta) ===
# ─────────────────────────────────────────────────────────────
_cache_desc_file() {
  echo "${PITONZI_CACHE_DIR}/$(echo "${CURRENT_REPO}" | tr '/' '_')_${CURRENT_BRANCH}.desc"
}

load_descs() {
  local cache_file
  cache_file=$(_cache_desc_file)

  local should_gen=0
  [[ ! -f "$cache_file" ]] && should_gen=1
  [[ -n "$(find "$cache_file" -mmin +1440 2>/dev/null)" ]] && should_gen=1

  if [[ "$should_gen" -eq 1 ]]; then
    local content
    content=$(curl -fsSL "${CURRENT_BASE_URL}/script_desc.txt" 2>/dev/null || echo "")
    if [[ -n "$content" ]]; then
      echo "$content" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' > "$cache_file"
    else
      echo "# generated: $(date) — assente" > "$cache_file"
    fi
  fi

  SCRIPT_DESCS=$(cat "$cache_file" 2>/dev/null || echo "")
}

get_desc() {
  local path="$1"
  local desc
  desc=$(echo "$SCRIPT_DESCS" | grep "^${path}" | sed 's/.*# //' 2>/dev/null || true)
  echo "${desc:----}"
}

# ─────────────────────────────────────────────────────────────
# === RESOLVE DEPS (embedded — nessun download necessario) ===
# ─────────────────────────────────────────────────────────────
_write_resolve_deps() {
  local out="$1"
  cat > "$out" << 'PYDEPS_EOF'
#!/usr/bin/env python3
import sys, os, ast, importlib.util, sysconfig, hashlib, json
from functools import lru_cache

CUSTOM_MAP = {
    'nmap': 'python-nmap', 'impacket': 'impacket', 'smb': 'impacket',
    'Crypto': 'pycryptodome', 'cryptography': 'cryptography',
    'paramiko': 'paramiko', 'scapy': 'scapy', 'netaddr': 'netaddr',
    'requests_ntlm': 'requests-ntlm', 'bs4': 'beautifulsoup4',
    'PIL': 'Pillow', 'cv2': 'opencv-python', 'sklearn': 'scikit-learn',
    'yaml': 'PyYAML', 'pymysql': 'PyMySQL', 'MySQLdb': 'mysqlclient',
    'psycopg2': 'psycopg2-binary', 'matplotlib': 'matplotlib',
    'seaborn': 'seaborn', 'pandas': 'pandas', 'numpy': 'numpy',
    'scipy': 'scipy', 'skimage': 'scikit-image', 'lxml': 'lxml',
    'flask': 'Flask', 'django': 'Django', 'jinja2': 'Jinja2',
    'fastapi': 'fastapi', 'uvicorn': 'uvicorn', 'serial': 'pyserial',
    'dateutil': 'python-dateutil', 'colorama': 'colorama',
    'termcolor': 'termcolor', 'tabulate': 'tabulate', 'dotenv': 'python-dotenv',
    'bcrypt': 'bcrypt', 'aiohttp': 'aiohttp', 'pytest': 'pytest',
    'InquirerPy': 'InquirerPy', 'inquirer': 'inquirer',
    'pytesseract': 'pytesseract', 'platform': None, 'rich': 'rich',
    'click': 'click', 'typer': 'typer', 'httpx': 'httpx',
    'pydantic': 'pydantic', 'sqlalchemy': 'SQLAlchemy',
    'celery': 'celery', 'redis': 'redis', 'boto3': 'boto3',
    'pyperclip': 'pyperclip', 'playsound': 'playsound',
}

CACHE_DIR = os.path.expanduser('~/.cache/resolve_deps')
os.makedirs(CACHE_DIR, exist_ok=True)

STDLIB_PATHS = {
    os.path.realpath(sysconfig.get_paths()['stdlib']),
    os.path.realpath(sysconfig.get_paths().get('platstdlib', '')),
}

@lru_cache(maxsize=None)
def is_builtin_or_stdlib(mod_name):
    try:
        if mod_name in sys.builtin_module_names: return True
        spec = importlib.util.find_spec(mod_name)
        if spec is None: return False
        if spec.origin in (None, 'built-in', 'frozen'): return True
        origin = os.path.realpath(spec.origin)
        if any(x in origin for x in ('site-packages', 'dist-packages')): return False
        return any(origin.startswith(p) for p in STDLIB_PATHS)
    except Exception:
        return False

def extract_imports(filepath):
    h = hashlib.sha256(open(filepath,'rb').read()).hexdigest()
    cache_file = os.path.join(CACHE_DIR, h + '.json')
    if os.path.isfile(cache_file):
        try:
            return set(json.load(open(cache_file))['deps'])
        except: pass

    content = open(filepath, 'r', encoding='utf-8').read()
    modules = set()
    try:
        tree = ast.parse(content)
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for a in node.names: modules.add(a.name.split('.')[0])
            elif isinstance(node, ast.ImportFrom):
                if node.module: modules.add(node.module.split('.')[0])
    except: pass

    deps = set()
    for mod in modules:
        if not mod or is_builtin_or_stdlib(mod): continue
        mapped = CUSTOM_MAP.get(mod, mod)
        if mapped is not None: deps.add(mapped)

    json.dump({'deps': list(deps)}, open(cache_file,'w'))
    return deps

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: resolve_deps.py <script.py>", file=sys.stderr)
        sys.exit(1)
    deps = extract_imports(sys.argv[1])
    print(' '.join(sorted(deps)) if deps else '')
PYDEPS_EOF
}

# ─────────────────────────────────────────────────────────────
# === DEPS IN RAM (pip --target, niente venv) ===
# Installa le dipendenze in una dir temporanea in RAM
# e setta PYTHONPATH — più veloce e nessun problema ensurepip
# ─────────────────────────────────────────────────────────────
_PITONZI_DEPS_DIR=""
trap 'rm -rf "${_PITONZI_DEPS_DIR:-}"' EXIT

_get_deps_dir() {
  if [[ -n "$_PITONZI_DEPS_DIR" && -d "$_PITONZI_DEPS_DIR" ]]; then
    return 0
  fi
  local tmpdir
  if [[ -d /dev/shm && -w /dev/shm ]]; then tmpdir="/dev/shm"; else tmpdir="/tmp"; fi
  _PITONZI_DEPS_DIR="${tmpdir}/pitonzi_deps_$$"
  mkdir -p "$_PITONZI_DEPS_DIR"
}

_install_deps() {
  local script_path="$1"

  # Scrivi resolve_deps.py temporaneo
  local resolver
  resolver=$(mktemp /tmp/resolve_deps_XXXXXX.py)
  _write_resolve_deps "$resolver"

  local deps
  deps=$(python3 "$resolver" "$script_path" 2>/dev/null || echo "")
  rm -f "$resolver"

  if [[ -z "$deps" ]]; then
    print_info "Nessuna dipendenza esterna rilevata."
    return 0
  fi

  echo -e "${CYAN}📦 Dipendenze rilevate:${RESET} ${DARK_GRAY}${deps}${RESET}"

  _get_deps_dir
  local pip_cmd="python3 -m pip"

  # Verifica pip disponibile
  if ! python3 -m pip --version &>/dev/null; then
    print_warn "pip non trovato nel sistema."
    if [[ -f /etc/arch-release ]]; then
      print_info "Installo python-pip..."
      sudo pacman -S --noconfirm python-pip &>/dev/null && print_ok "python-pip installato."
    elif [[ -f /etc/debian_version ]]; then
      sudo apt install -y python3-pip &>/dev/null && print_ok "python3-pip installato."
    fi
  fi

  # Installa in dir RAM con --target
  read -ra _deps_array <<< "$deps"
  if python3 -m pip install "${_deps_array[@]}" --target "$_PITONZI_DEPS_DIR" -q --no-warn-script-location 2>/dev/null; then
    print_ok "Dipendenze installate in RAM: ${deps}"
  else
    print_warn "Installazione parziale — lo script potrebbe non funzionare correttamente."
  fi

  # Setta PYTHONPATH per questo processo
  export PYTHONPATH="$_PITONZI_DEPS_DIR${PYTHONPATH:+:$PYTHONPATH}"
}

# ─────────────────────────────────────────────────────────────
# === POST-RUN PAUSE (come marmitta) ===
# ─────────────────────────────────────────────────────────────
_post_run_pause() {
  local exit_code="${1:-0}"
  echo ""
  if [[ "$exit_code" -eq 0 ]]; then
    echo -e "${GREEN}✅ Script terminato con successo (exit 0)${RESET}"
  else
    echo -e "${RED}⚠️  Script terminato con errore (exit ${exit_code})${RESET}"
  fi
  echo -e "${DARK_GRAY}─────────────────────────────────────────${RESET}"
  echo -e "${DARK_GRAY}[ INVIO ] Torna al menu   [ q ] Esci${RESET}"
  local k
  read -rsn1 k < /dev/tty
  [[ "$k" == "q" || "$k" == "Q" ]] && echo -e "\n${DARK_GRAY}Uscita da pitonzi.${RESET}" && exit 0
}

# ─────────────────────────────────────────────────────────────
# === ESECUZIONE SCRIPT ===
# ─────────────────────────────────────────────────────────────
run_script() {
  local script_path="$1"
  local script_url="$2"
  local script_name
  script_name=$(basename "$script_path")
  local name_noext="${script_name%.py}"

  echo -e "\n${CYAN}🐍 Script:${RESET} ${YELLOW}${script_path}${RESET}"
  echo -e "${CYAN}🔗 URL:${RESET}    ${DARK_GRAY}${script_url}${RESET}"
  echo -e "\n${DARK_GRAY}[ ${GREEN}INVIO${DARK_GRAY} ] Esegui   [ ${YELLOW}i${DARK_GRAY} ] Argomenti   [ ${ORANGE}s${DARK_GRAY} ] Salva env locale   [ ${RED}q${DARK_GRAY} ] Annulla${RESET}"

  local key
  read -rsn1 key < /dev/tty

  [[ "$key" == "q" || "$key" == "Q" ]] && return 1

  # Download script
  local tmp_script
  tmp_script=$(mktemp /tmp/pitonzi_XXXXXX.py)
  print_step "Download script..."
  if ! curl -fsSL "$script_url" -o "$tmp_script"; then
    print_err "Download fallito."
    rm -f "$tmp_script"
    return 1
  fi

  # Salva come ultimo usato
  echo "$script_url" > "$PITONZI_LAST"

  # Installa deps in dir RAM, setta PYTHONPATH
  _install_deps "$tmp_script"

  case "$key" in
    i|I)
      echo ""
      read -rp "$(echo -e "${MAGENTA}⌨️  Argomenti: ${RESET}")" user_args < /dev/tty
      echo -e "\n${GREEN}▶️  Eseguo:${RESET} ${YELLOW}${script_name} ${user_args}${RESET}\n"
      python3 "$tmp_script" $user_args
      local exit_code=$?
      rm -f "$tmp_script"
      _post_run_pause "$exit_code"
      ;;

    s|S)
      # Salva venv persistente su disco
      local saved_venv="./${name_noext}_venv"
      echo -e "\n${CYAN}💾 Salvo venv in ${saved_venv}...${RESET}"
      python3 -m venv "$saved_venv"
      "$saved_venv/bin/pip" install -q --upgrade pip &>/dev/null
      # Reinstalla deps nel venv persistente
      local resolver
      resolver=$(mktemp /tmp/resolve_deps_XXXXXX.py)
      _write_resolve_deps "$resolver"
      local deps
      deps=$(python3 "$resolver" "$tmp_script" 2>/dev/null || echo "")
      rm -f "$resolver"
      [[ -n "$deps" ]] && "$saved_venv/bin/pip" install $deps -q

      cp "$tmp_script" "./${script_name}"
      print_ok "Script salvato: ./${script_name}"
      print_ok "Venv salvato:   ${saved_venv}"

      echo -e "\n${GREEN}▶️  Eseguo...${RESET}\n"
      python3 "$tmp_script"
      local exit_code=$?
      rm -f "$tmp_script"
      _post_run_pause "$exit_code"
      ;;

    *)
      echo -e "\n${GREEN}▶️  Eseguo...${RESET}\n"
      python3 "$tmp_script"
      local exit_code=$?
      rm -f "$tmp_script"
      _post_run_pause "$exit_code"
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────
# === FZF HELPER ===
# ─────────────────────────────────────────────────────────────
fzf_pick() {
  local prompt="$1"
  fzf \
    --height=18 --layout=reverse --border \
    --prompt="$prompt" \
    --delimiter="\t" --with-nth=1 \
    --preview='echo -e "\033[0;96mℹ️  \033[0m" $(echo {} | cut -f2)' \
    --preview-window=up:2:wrap \
    --color=fg:#d6de35,bg:#121212,hl:#5f87af \
    --color=fg+:#00ffd9,bg+:#5c00e6,hl+:#5fd7ff \
    --color=pointer:green,header:italic \
    --ansi | cut -f1
}

# ─────────────────────────────────────────────────────────────
# === NAVIGAZIONE (3 livelli, back con ESC — come marmitta) ===
# ─────────────────────────────────────────────────────────────
browse_and_run() {
  # Fetch cartelle root
  local folders_json
  folders_json=$(curl -s "${AUTH_HEADER[@]}" "$CURRENT_API_URL")

  if echo "$folders_json" | grep -q 'rate limit'; then
    print_err "API rate limit superato. Configura GITHUB_TOKEN con: marmitta --config"
  fi

  local categories
  categories=$(echo "$folders_json" | jq -r '.[] | select(.type == "dir") | .name' 2>/dev/null || echo "")
  [[ -z "$categories" ]] && print_err "Nessuna cartella trovata in ${CURRENT_REPO}."

  # Loop esterno — categorie
  while true; do

    local cat_menu=""
    while IFS= read -r cat; do
      [[ -z "$cat" ]] && continue
      cat_menu+="${cat}\t$(get_desc "${cat}")\n"
    done <<< "$categories"

    local chosen_cat
    chosen_cat=$(printf "%b" "$cat_menu" | fzf_pick "🐍 Categoria > ")

    [[ -z "$chosen_cat" ]] && echo -e "\n${DARK_GRAY}Uscita da pitonzi.${RESET}" && return 0

    # Loop medio — subdir o script diretti
    while true; do

      local cat_json
      cat_json=$(curl -s "${AUTH_HEADER[@]}" "${CURRENT_API_URL}/${chosen_cat}")

      local subdirs direct_scripts
      subdirs=$(echo "$cat_json"       | jq -r '.[] | select(.type == "dir")  | .name' 2>/dev/null || echo "")
      direct_scripts=$(echo "$cat_json" | jq -r '.[] | select(.type == "file" and (.name | endswith(".py"))) | .name' 2>/dev/null || echo "")

      if [[ -n "$subdirs" ]]; then

        # Livello 2: subdir + script diretti
        local menu=""
        while IFS= read -r d; do [[ -z "$d" ]] && continue; menu+="📁 ${d}\t—\n"; done <<< "$subdirs"
        while IFS= read -r s; do [[ -z "$s" ]] && continue; menu+="🐍 ${s}\t$(get_desc "${chosen_cat}/${s}")\n"; done <<< "$direct_scripts"

        local chosen_l2
        chosen_l2=$(printf "%b" "$menu" | fzf_pick "📂 ${chosen_cat} > [ESC] torna")
        [[ -z "$chosen_l2" ]] && break

        local item="${chosen_l2:3}"  # rimuove emoji + spazio

        if [[ "$chosen_l2" == 📁* ]]; then

          # Loop interno — script nella subdir
          while true; do
            local sub_json
            sub_json=$(curl -s "${AUTH_HEADER[@]}" "${CURRENT_API_URL}/${chosen_cat}/${item}")
            local sub_scripts
            sub_scripts=$(echo "$sub_json" | jq -r '.[] | select(.type == "file" and (.name | endswith(".py"))) | .name' 2>/dev/null || echo "")

            [[ -z "$sub_scripts" ]] && print_warn "Nessuno script .py in ${chosen_cat}/${item}" && break

            local smenu=""
            while IFS= read -r s; do
              [[ -z "$s" ]] && continue
              smenu+="${s}\t$(get_desc "${chosen_cat}/${item}/${s}")\n"
            done <<< "$sub_scripts"

            local chosen_script
            chosen_script=$(printf "%b" "$smenu" | fzf_pick "🐍 ${chosen_cat}/${item} > [ESC] torna")
            [[ -z "$chosen_script" ]] && break

            local full_path="${chosen_cat}/${item}/${chosen_script}"
            local script_url
            script_url=$(echo "$sub_json" | jq -r ".[] | select(.name == \"${chosen_script}\") | .download_url")
            run_script "$full_path" "$script_url"
          done

        else
          # Script diretto livello 2
          local full_path="${chosen_cat}/${item}"
          local script_url
          script_url=$(echo "$cat_json" | jq -r ".[] | select(.name == \"${item}\") | .download_url")
          run_script "$full_path" "$script_url"
        fi

      else
        # Livello 2 senza subdir
        [[ -z "$direct_scripts" ]] && print_warn "Nessuno script .py in ${chosen_cat}" && break

        local smenu=""
        while IFS= read -r s; do
          [[ -z "$s" ]] && continue
          smenu+="${s}\t$(get_desc "${chosen_cat}/${s}")\n"
        done <<< "$direct_scripts"

        local chosen_script
        chosen_script=$(printf "%b" "$smenu" | fzf_pick "🐍 ${chosen_cat} > [ESC] torna")
        [[ -z "$chosen_script" ]] && break

        local full_path="${chosen_cat}/${chosen_script}"
        local script_url
        script_url=$(echo "$cat_json" | jq -r ".[] | select(.name == \"${chosen_script}\") | .download_url")
        run_script "$full_path" "$script_url"
      fi

    done
  done
}

# ─────────────────────────────────────────────────────────────
# === HANDLER --LAST ===
# ─────────────────────────────────────────────────────────────
do_last() {
  local last
  last=$(cat "$PITONZI_LAST" 2>/dev/null || echo "")
  [[ -z "$last" ]] && print_err "Nessuno script eseguito precedentemente."
  local script_name
  script_name=$(basename "$last")
  echo -e "${CYAN}▶️  Rieseguo:${RESET} ${YELLOW}${last}${RESET}\n"
  local tmp_script
  tmp_script=$(mktemp /tmp/pitonzi_XXXXXX.py)
  curl -fsSL "$last" -o "$tmp_script"
  _install_deps "$tmp_script"
  python3 "$tmp_script"
  local exit_code=$?
  rm -f "$tmp_script"
  _post_run_pause "$exit_code"
}

# ─────────────────────────────────────────────────────────────
# === DIPENDENZE ===
# ─────────────────────────────────────────────────────────────
for cmd in jq fzf python3 curl; do
  command -v "$cmd" &>/dev/null || {
    echo -e "${RED}❌ ${cmd} non trovato. Installalo prima di usare pitonzi.${RESET}"
    exit 1
  }
done

# ─────────────────────────────────────────────────────────────
# === ENTRY POINT ===
# ─────────────────────────────────────────────────────────────
case "${1:-}" in
  -l|--last)   select_source; load_descs; do_last; exit 0 ;;
  --gen-desc)  select_source; load_descs; print_ok "Cache descrizioni aggiornata."; exit 0 ;;
  --add-repo)  _ask_add_repo; select_source; load_descs; print_banner; echo ""; browse_and_run; exit 0 ;;
  -h|--help)
    echo -e "\n${BOLD}${CYAN}PITONZI${RESET} — Python Script Launcher\n"
    echo -e "  ${CYAN}-l, --last${RESET}     Riesegue l'ultimo script"
    echo -e "  ${YELLOW}--gen-desc${RESET}     Rigenera cache descrizioni"
    echo -e "  ${MAGENTA}--add-repo${RESET}     Aggiunge un repo Python alle sources"
    echo -e "  ${RED}-h, --help${RESET}     Mostra questa guida\n"
    exit 0 ;;
esac

# ─────────────────────────────────────────────────────────────
# === AGGIUNGI REPO PYTHON ===
# Chiesto sempre all'avvio — permette di aggiungere repo extra
# ─────────────────────────────────────────────────────────────
_ask_add_repo() {
  local sources_file="$HOME/.config/marmitta/sources"
  echo -e "${DARK_GRAY}──────────────────────────────────────────${RESET}"
  read -rp "$(echo -e "${YELLOW}➕ Aggiungere un repo Python? [y/N]: ${RESET}")" ans < /dev/tty
  [[ ! "$ans" =~ ^[Yy]$ ]] && return 0

  mkdir -p "$(dirname "$sources_file")"
  [[ ! -f "$sources_file" ]] && touch "$sources_file"

  local label user_repo branch
  read -rp "$(echo -e "${YELLOW}🏷️  Label (es: pitonzi): ${RESET}")" label < /dev/tty
  [[ -z "$label" ]] && print_warn "Label vuota — skip." && return 0

  read -rp "$(echo -e "${YELLOW}📦 Repo (es: manuelpringols/pitonzi): ${RESET}")" user_repo < /dev/tty
  user_repo=$(echo "$user_repo" | sed 's|https://github.com/||;s|\.git$||' | xargs)
  [[ -z "$user_repo" || "$user_repo" != */* ]] && print_warn "Repo non valido — skip." && return 0

  read -rp "$(echo -e "${YELLOW}🌿 Branch [master]: ${RESET}")" branch < /dev/tty
  branch="${branch:-master}"

  echo "${label}|${user_repo}|${branch}" >> "$sources_file"
  print_ok "Repo '${label}' aggiunto → ${user_repo}@${branch}"
  echo -e "${DARK_GRAY}──────────────────────────────────────────${RESET}"
}

select_source
load_descs
print_banner
echo ""
browse_and_run