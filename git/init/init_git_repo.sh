#!/bin/bash
# @desc: Crea repo GitHub, aggiunge chiave SSH e inizializza git locale

# ─────────────────────────────────────────────────────────────
# === COLORI ===
# ─────────────────────────────────────────────────────────────
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
MAGENTA="\033[1;35m"
DARK_GRAY="\e[90m"
BOLD="\e[1m"
RESET="\033[0m"

print_ok()   { echo -e "${GREEN}✅ $1${RESET}"; }
print_warn() { echo -e "${YELLOW}⚠️  $1${RESET}"; }
print_err()  { echo -e "${RED}❌ $1${RESET}"; exit 1; }
print_info() { echo -e "${CYAN}ℹ️  $1${RESET}"; }
print_step() { echo -e "\n${MAGENTA}━━━ $1 ━━━${RESET}"; }

# ─────────────────────────────────────────────────────────────
# === BANNER ===
# ─────────────────────────────────────────────────────────────
echo -e "\n${CYAN}${BOLD}╔══════════════════════════════════════╗"
echo -e "║       🌱  INIT GIT REPO              ║"
echo -e "╚══════════════════════════════════════╝${RESET}"
echo -e "${DARK_GRAY}  Crea repo su GitHub + SSH + init locale${RESET}\n"

# ─────────────────────────────────────────────────────────────
# === CARICA CONFIG MARMITTA (se disponibile) ===
# ─────────────────────────────────────────────────────────────
MARMITTA_CONFIG="$HOME/.config/marmitta/config"
MARMITTA_GIT_CONFIG="$HOME/.config/marmitta/git_profiles"

# Valori di default dal config marmitta
DEFAULT_TOKEN=""
DEFAULT_USER=""

if [[ -f "$MARMITTA_CONFIG" ]]; then
  # shellcheck source=/dev/null
  source "$MARMITTA_CONFIG"
  DEFAULT_TOKEN="${GITHUB_TOKEN:-}"
fi

# ─────────────────────────────────────────────────────────────
# === SELEZIONE PROFILO GIT ===
# ─────────────────────────────────────────────────────────────
# I profili sono salvati in ~/.config/marmitta/git_profiles
# Formato: label|github_user|github_token|ssh_key_path
# ─────────────────────────────────────────────────────────────

load_profiles() {
  grep -v '^#' "$MARMITTA_GIT_CONFIG" 2>/dev/null | grep -v '^$' || true
}

save_profile() {
  local label="$1" user="$2" token="$3" ssh_key="$4"
  mkdir -p "$(dirname "$MARMITTA_GIT_CONFIG")"
  [[ ! -f "$MARMITTA_GIT_CONFIG" ]] && \
    echo "# Marmitta git profiles — label|github_user|github_token|ssh_key" \
    > "$MARMITTA_GIT_CONFIG"

  # Evita duplicati sulla label
  if grep -q "^${label}|" "$MARMITTA_GIT_CONFIG" 2>/dev/null; then
    # Aggiorna la riga esistente
    sed -i "s|^${label}|.*|${label}|${user}|${token}|${ssh_key}|" "$MARMITTA_GIT_CONFIG"
  else
    echo "${label}|${user}|${token}|${ssh_key}" >> "$MARMITTA_GIT_CONFIG"
  fi
  print_ok "Profilo '${label}' salvato."
}

select_or_create_profile() {
  local profiles
  profiles=$(load_profiles)

  if [[ -z "$profiles" ]]; then
    # Nessun profilo → crea il primo
    echo -e "${YELLOW}Nessun profilo git configurato. Creiamone uno.${RESET}\n"
    create_profile
    return
  fi

  echo -e "${CYAN}${BOLD}👤 Seleziona profilo git:${RESET}\n"

  # Mostra profili numerati
  local i=1
  local labels=()
  while IFS='|' read -r label user token ssh_key; do
    echo -e "  ${CYAN}${i}${RESET}) ${label} ${DARK_GRAY}(${user})${RESET}"
    labels+=("$label")
    (( i++ ))
  done <<< "$profiles"
  echo -e "  ${CYAN}${i}${RESET}) ${YELLOW}+ Crea nuovo profilo${RESET}"

  echo ""
  read -rp "$(echo -e "${YELLOW}Scelta [1]: ${RESET}")" choice
  choice="${choice:-1}"

  if [[ "$choice" -eq "$i" ]]; then
    create_profile
    return
  fi

  # Carica profilo scelto
  local chosen_line
  chosen_line=$(echo "$profiles" | sed -n "${choice}p")
  if [[ -z "$chosen_line" ]]; then
    print_warn "Scelta non valida, uso il primo profilo."
    chosen_line=$(echo "$profiles" | head -1)
  fi

  PROFILE_LABEL=$(echo "$chosen_line" | cut -d'|' -f1)
  GITHUB_USER=$(echo "$chosen_line"   | cut -d'|' -f2)
  GITHUB_TOKEN=$(echo "$chosen_line"  | cut -d'|' -f3)
  SSH_KEY_PATH=$(echo "$chosen_line"  | cut -d'|' -f4)

  print_ok "Profilo caricato: ${PROFILE_LABEL} (${GITHUB_USER})"
}

create_profile() {
  echo -e "${CYAN}${BOLD}➕ Nuovo profilo git${RESET}\n"

  read -rp "$(echo -e "${YELLOW}🏷️  Nome profilo (es: lavoro, personale): ${RESET}")" PROFILE_LABEL
  [[ -z "$PROFILE_LABEL" ]] && PROFILE_LABEL="default"

  # Token
  echo -e "${YELLOW}🔑 GitHub token: ${RESET}"
  read -rs GITHUB_TOKEN
  echo
  while [[ -z "$GITHUB_TOKEN" ]]; do
    print_warn "Token obbligatorio."
    echo -e "${YELLOW}🔑 GitHub token: ${RESET}"
    read -rs GITHUB_TOKEN
    echo
  done

  # Verifica token e ricava user automaticamente
  print_info "Verifico il token..."
  GITHUB_USER=$(curl -s \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    https://api.github.com/user | jq -r '.login // empty')

  if [[ -z "$GITHUB_USER" ]]; then
    echo -e "${RED}❌ Token non valido o API non raggiungibile.${RESET}"
    exit 1
  fi
  print_ok "Token valido — utente GitHub: ${CYAN}${GITHUB_USER}${RESET}"

  # Chiave SSH
  _pick_ssh_key

  # Salva il profilo per riusi futuri
  read -rp "$(echo -e "${YELLOW}💾 Salvare il profilo per usi futuri? [Y/n]: ${RESET}")" save
  if [[ ! "$save" =~ ^[Nn]$ ]]; then
    save_profile "$PROFILE_LABEL" "$GITHUB_USER" "$GITHUB_TOKEN" "$SSH_KEY_PATH"
  fi
}

# Rileva e fa scegliere la chiave SSH
_pick_ssh_key() {
  mapfile -t ssh_keys < <(find "$HOME/.ssh" -maxdepth 1 -name "*.pub" 2>/dev/null | sort)

  if [[ ${#ssh_keys[@]} -eq 0 ]]; then
    print_warn "Nessuna chiave SSH trovata in ~/.ssh/"
    read -rp "$(echo -e "${YELLOW}Generare una chiave ed25519 ora? [Y/n]: ${RESET}")" gen
    if [[ ! "$gen" =~ ^[Nn]$ ]]; then
      ssh-keygen -t ed25519 -C "${GITHUB_USER}@marmitta" \
        -f "$HOME/.ssh/id_ed25519" -N "" -q
      SSH_KEY_PATH="$HOME/.ssh/id_ed25519.pub"
      print_ok "Chiave generata: ${SSH_KEY_PATH}"
    else
      echo -e "${RED}❌ Chiave SSH obbligatoria.${RESET}"; exit 1
    fi
  elif [[ ${#ssh_keys[@]} -eq 1 ]]; then
    SSH_KEY_PATH="${ssh_keys[0]}"
    print_info "Uso chiave: ${SSH_KEY_PATH}"
  else
    echo -e "\n${YELLOW}🔑 Chiavi SSH disponibili:${RESET}"
    for i in "${!ssh_keys[@]}"; do
      echo -e "  ${CYAN}$((i+1))${RESET}) ${ssh_keys[$i]}"
    done
    read -rp "$(echo -e "${YELLOW}Scegli [1]: ${RESET}")" key_idx
    key_idx=$(( ${key_idx:-1} - 1 ))
    SSH_KEY_PATH="${ssh_keys[$key_idx]:-${ssh_keys[0]}}"
    print_info "Chiave selezionata: ${SSH_KEY_PATH}"
  fi
}

# ─────────────────────────────────────────────────────────────
# === SELEZIONE PROFILO ===
# ─────────────────────────────────────────────────────────────
select_or_create_profile

# ─────────────────────────────────────────────────────────────
# === INPUT: DATI REPO ===
# ─────────────────────────────────────────────────────────────
print_step "Configurazione repository"

read -rp "$(echo -e "${YELLOW}📦 Nome del repository: ${RESET}")" REPO_NAME
while [[ -z "$REPO_NAME" ]]; do
  print_warn "Il nome è obbligatorio."
  read -rp "$(echo -e "${YELLOW}📦 Nome del repository: ${RESET}")" REPO_NAME
done

read -rp "$(echo -e "${YELLOW}📝 Descrizione (opzionale): ${RESET}")" REPO_DESC

echo -e "${YELLOW}🔒 Visibilità:${RESET}"
echo -e "  ${CYAN}1${RESET}) Pubblico"
echo -e "  ${CYAN}2${RESET}) Privato"
read -rp "$(echo -e "${YELLOW}Scelta [1]: ${RESET}")" vis_choice
case "${vis_choice:-1}" in
  2) REPO_PRIVATE="true"  ;;
  *) REPO_PRIVATE="false" ;;
esac

FULL_URL="git@github.com:${GITHUB_USER}/${REPO_NAME}.git"

# ─────────────────────────────────────────────────────────────
# === RIEPILOGO ===
# ─────────────────────────────────────────────────────────────
echo -e "\n${CYAN}${BOLD}📋 Riepilogo${RESET}"
echo -e "  ${DARK_GRAY}Profilo:     ${RESET}${PROFILE_LABEL}"
echo -e "  ${DARK_GRAY}Utente:      ${RESET}${GITHUB_USER}"
echo -e "  ${DARK_GRAY}Repository:  ${RESET}${REPO_NAME}"
echo -e "  ${DARK_GRAY}Descrizione: ${RESET}${REPO_DESC:-(nessuna)}"
echo -e "  ${DARK_GRAY}Visibilità:  ${RESET}$( [[ "$REPO_PRIVATE" == "true" ]] && echo "🔒 Privato" || echo "🌐 Pubblico")"
echo -e "  ${DARK_GRAY}Chiave SSH:  ${RESET}${SSH_KEY_PATH}"
echo -e "  ${DARK_GRAY}Remote URL:  ${RESET}${FULL_URL}"

read -rp "$(echo -e "\n${YELLOW}Confermi? [y/N]: ${RESET}")" confirm
[[ ! "$confirm" =~ ^[Yy]$ ]] && print_warn "Annullato." && exit 0

# ─────────────────────────────────────────────────────────────
# === STEP 1: CREA REPO SU GITHUB ===
# ─────────────────────────────────────────────────────────────
print_step "Creazione repository su GitHub"

tmp_resp=$(mktemp)
http_code=$(curl -s -w "%{http_code}" -o "$tmp_resp" \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -X POST https://api.github.com/user/repos \
  -d "{\"name\":\"${REPO_NAME}\",\"description\":\"${REPO_DESC}\",\"private\":${REPO_PRIVATE}}")

case "$http_code" in
  201) print_ok "Repository creato su GitHub!" ;;
  422) print_warn "Repository già esistente, procedo." ;;
  *)
    echo -e "${RED}❌ Errore (HTTP $http_code):${RESET}"
    jq -r '.message // .' "$tmp_resp"
    rm -f "$tmp_resp"; exit 1
    ;;
esac
rm -f "$tmp_resp"

# ─────────────────────────────────────────────────────────────
# === STEP 2: AGGIUNGE CHIAVE SSH ===
# ─────────────────────────────────────────────────────────────
print_step "Aggiunta chiave SSH a GitHub"

KEY_CONTENT=$(cat "$SSH_KEY_PATH")
KEY_TITLE="marmitta — ${PROFILE_LABEL} — $(hostname) — $(date +'%Y-%m-%d')"

tmp_ssh=$(mktemp)
http_code=$(curl -s -w "%{http_code}" -o "$tmp_ssh" \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -X POST https://api.github.com/user/keys \
  -d "{\"title\":\"${KEY_TITLE}\",\"key\":\"${KEY_CONTENT}\"}")

case "$http_code" in
  201) print_ok "Chiave SSH aggiunta!" ;;
  422)
    if grep -q "key is already in use" "$tmp_ssh" 2>/dev/null; then
      print_warn "Chiave già presente su GitHub."
    else
      echo -e "${RED}❌ Errore aggiunta chiave (HTTP $http_code):${RESET}"
      jq -r '.message // .' "$tmp_ssh"
      rm -f "$tmp_ssh"; exit 1
    fi
    ;;
  *)
    echo -e "${RED}❌ Errore (HTTP $http_code):${RESET}"
    jq -r '.message // .' "$tmp_ssh"
    rm -f "$tmp_ssh"; exit 1
    ;;
esac
rm -f "$tmp_ssh"

# ─────────────────────────────────────────────────────────────
# === STEP 3: INIZIALIZZA REPO LOCALE ===
# ─────────────────────────────────────────────────────────────
print_step "Inizializzazione repo locale"

ORIGIN_DIR="$(pwd)"

if [[ -d "$REPO_NAME" ]]; then
  print_warn "Cartella '${REPO_NAME}' già esistente, entro dentro."
else
  mkdir "$REPO_NAME"
fi

cd "$REPO_NAME" || { echo -e "${RED}❌ Impossibile entrare in ${REPO_NAME}${RESET}"; exit 1; }

if [[ ! -d ".git" ]]; then
  git init -q
  print_ok "git init completato."
else
  print_warn "Repo git già inizializzata, salto git init."
fi

if git remote get-url origin &>/dev/null; then
  print_warn "Remote 'origin' già presente: $(git remote get-url origin)"
else
  git remote add origin "$FULL_URL"
  print_ok "Remote 'origin' → ${FULL_URL}"
fi

# ─────────────────────────────────────────────────────────────
# === STEP 4: README E PRIMO COMMIT ===
# ─────────────────────────────────────────────────────────────
if [[ ! -f "README.md" ]]; then
  cat > README.md <<EOF
# ${REPO_NAME}

${REPO_DESC}

---
*Inizializzato con [marmitta](https://github.com/${GITHUB_USER}/marmitta)*
EOF
  git add README.md
  git commit -q -m "init: primo commit — README generato da marmitta"
  print_ok "README.md creato e primo commit effettuato."
fi

cd "$ORIGIN_DIR" || true

# ─────────────────────────────────────────────────────────────
# === DONE ===
# ─────────────────────────────────────────────────────────────
echo -e "\n${GREEN}${BOLD}🎉 Tutto fatto!${RESET}"
echo -e "  ${DARK_GRAY}Repo locale:${RESET} $(pwd)/${REPO_NAME}"
echo -e "  ${DARK_GRAY}Remote:     ${RESET}${FULL_URL}"
echo -e "\n${CYAN}Prossimo passo:${RESET}"
echo -e "  ${DARK_GRAY}cd ${REPO_NAME} && git push -u origin master${RESET}\n"