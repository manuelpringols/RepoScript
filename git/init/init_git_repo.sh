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

# ─────────────────────────────────────────────────────────────
# === UTILITY ===
# ─────────────────────────────────────────────────────────────
print_ok()   { echo -e "${GREEN}✅ $1${RESET}"; }
print_warn() { echo -e "${YELLOW}⚠️  $1${RESET}"; }
print_err()  { echo -e "${RED}❌ $1${RESET}"; }
print_info() { echo -e "${CYAN}ℹ️  $1${RESET}"; }
print_step() { echo -e "${MAGENTA}➡️  $1${RESET}"; }

# Spinner generico: spinner "messaggio" & PID=$! → poi wait $PID
spinner() {
  local msg="${1:-Attendere...}"
  local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  while true; do
    printf "\r${CYAN}%s${RESET} %s" "${spinstr:$i:1}" "$msg"
    i=$(( (i+1) % ${#spinstr} ))
    sleep 0.1
  done
}

run_with_spinner() {
  local msg="$1"; shift
  spinner "$msg" &
  local spin_pid=$!
  "$@" >/dev/null 2>&1
  local rc=$?
  kill "$spin_pid" 2>/dev/null
  wait "$spin_pid" 2>/dev/null
  printf "\r%*s\r" 60 ""   # pulisce la riga
  return $rc
}

# ─────────────────────────────────────────────────────────────
# === BANNER ===
# ─────────────────────────────────────────────────────────────
echo -e "\n${CYAN}${BOLD}╔══════════════════════════════════════╗"
echo -e "║       🌱  INIT GIT REPO              ║"
echo -e "╚══════════════════════════════════════╝${RESET}\n"
echo -e "${DARK_GRAY}Questo script:"
echo -e "  • Legge user e token dal config di marmitta"
echo -e "  • Crea il repo su GitHub (se non esiste)"
echo -e "  • Aggiunge la chiave SSH al tuo account GitHub"
echo -e "  • Inizializza il repo git locale con README${RESET}\n"

# ─────────────────────────────────────────────────────────────
# === CARICA CONFIG MARMITTA ===
# ─────────────────────────────────────────────────────────────
MARMITTA_CONFIG="$HOME/.config/marmitta/config"

if [[ -f "$MARMITTA_CONFIG" ]]; then
  # shellcheck source=/dev/null
  source "$MARMITTA_CONFIG"
fi

# ─────────────────────────────────────────────────────────────
# === GITHUB TOKEN ===
# ─────────────────────────────────────────────────────────────
if [[ -z "$GITHUB_TOKEN" ]]; then
  print_warn "GITHUB_TOKEN non trovato nel config di marmitta."
  read -rsp "$(echo -e "${YELLOW}🔑 Inserisci il tuo GitHub token: ${RESET}")" GITHUB_TOKEN
  echo
  [[ -z "$GITHUB_TOKEN" ]] && print_err "Token obbligatorio." && exit 1
fi

# ─────────────────────────────────────────────────────────────
# === GITHUB USER (da API, non hardcoded) ===
# ─────────────────────────────────────────────────────────────
print_step "Verifico il token e recupero l'utente GitHub..."
GITHUB_USER=$(curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/user | jq -r '.login // empty')

if [[ -z "$GITHUB_USER" ]]; then
  print_err "Token non valido o API non raggiungibile."
  exit 1
fi
print_ok "Autenticato come: ${CYAN}${GITHUB_USER}${RESET}"

# ─────────────────────────────────────────────────────────────
# === INPUT: NOME REPO ===
# ─────────────────────────────────────────────────────────────
read -rp "$(echo -e "\n${YELLOW}📦 Nome del repository: ${RESET}")" REPO_NAME
while [[ -z "$REPO_NAME" ]]; do
  print_err "Il nome è obbligatorio."
  read -rp "$(echo -e "${YELLOW}📦 Nome del repository: ${RESET}")" REPO_NAME
done

# ─────────────────────────────────────────────────────────────
# === INPUT: DESCRIZIONE ===
# ─────────────────────────────────────────────────────────────
read -rp "$(echo -e "${YELLOW}📝 Descrizione (opzionale): ${RESET}")" REPO_DESC

# ─────────────────────────────────────────────────────────────
# === INPUT: VISIBILITÀ ===
# ─────────────────────────────────────────────────────────────
echo -e "${YELLOW}🔒 Visibilità:${RESET}"
echo -e "  ${CYAN}1${RESET}) Pubblico"
echo -e "  ${CYAN}2${RESET}) Privato"
read -rp "$(echo -e "${YELLOW}Scelta [1]: ${RESET}")" vis_choice
case "${vis_choice:-1}" in
  2) REPO_PRIVATE="true"  && print_info "Repo: privato" ;;
  *) REPO_PRIVATE="false" && print_info "Repo: pubblico" ;;
esac

# ─────────────────────────────────────────────────────────────
# === INPUT: CHIAVE SSH ===
# ─────────────────────────────────────────────────────────────
echo -e "\n${YELLOW}🔑 Chiavi SSH disponibili in ~/.ssh/:${RESET}"
mapfile -t ssh_keys < <(find "$HOME/.ssh" -maxdepth 1 -name "*.pub" 2>/dev/null)

if [[ ${#ssh_keys[@]} -eq 0 ]]; then
  print_err "Nessuna chiave SSH pubblica trovata in ~/.ssh/"
  read -rp "Vuoi generarne una ora? [y/N]: " gen_key
  if [[ "$gen_key" =~ ^[Yy]$ ]]; then
    ssh-keygen -t ed25519 -C "${GITHUB_USER}@marmitta" -f "$HOME/.ssh/id_ed25519" -N ""
    ssh_keys=("$HOME/.ssh/id_ed25519.pub")
    print_ok "Chiave generata: $HOME/.ssh/id_ed25519.pub"
  else
    print_err "Chiave SSH obbligatoria. Uscita."
    exit 1
  fi
elif [[ ${#ssh_keys[@]} -eq 1 ]]; then
  SSH_KEY_PATH="${ssh_keys[0]}"
  print_info "Uso chiave: ${SSH_KEY_PATH}"
else
  # Più chiavi → scelta interattiva
  for i in "${!ssh_keys[@]}"; do
    echo -e "  ${CYAN}$((i+1))${RESET}) ${ssh_keys[$i]}"
  done
  read -rp "$(echo -e "${YELLOW}Scegli chiave [1]: ${RESET}")" key_choice
  key_idx=$(( ${key_choice:-1} - 1 ))
  SSH_KEY_PATH="${ssh_keys[$key_idx]:-${ssh_keys[0]}}"
  print_info "Chiave selezionata: ${SSH_KEY_PATH}"
fi

FULL_URL="git@github.com:${GITHUB_USER}/${REPO_NAME}.git"

# ─────────────────────────────────────────────────────────────
# === RIEPILOGO ===
# ─────────────────────────────────────────────────────────────
echo -e "\n${CYAN}${BOLD}📋 Riepilogo${RESET}"
echo -e "  ${DARK_GRAY}Utente:      ${RESET}${GITHUB_USER}"
echo -e "  ${DARK_GRAY}Repository:  ${RESET}${REPO_NAME}"
echo -e "  ${DARK_GRAY}Descrizione: ${RESET}${REPO_DESC:-(nessuna)}"
echo -e "  ${DARK_GRAY}Visibilità:  ${RESET}$( [[ "$REPO_PRIVATE" == "true" ]] && echo "🔒 Privato" || echo "🌐 Pubblico" )"
echo -e "  ${DARK_GRAY}Chiave SSH:  ${RESET}${SSH_KEY_PATH}"
echo -e "  ${DARK_GRAY}Remote URL:  ${RESET}${FULL_URL}"

read -rp "$(echo -e "\n${YELLOW}Confermi? [y/N]: ${RESET}")" confirm
[[ ! "$confirm" =~ ^[Yy]$ ]] && print_warn "Annullato." && exit 0

echo ""

# ─────────────────────────────────────────────────────────────
# === STEP 1: CREA REPO SU GITHUB ===
# ─────────────────────────────────────────────────────────────
print_step "Creo il repository '${REPO_NAME}' su GitHub..."

tmp_resp=$(mktemp)
http_code=$(curl -s -w "%{http_code}" -o "$tmp_resp" \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -X POST https://api.github.com/user/repos \
  -d "{\"name\":\"${REPO_NAME}\",\"description\":\"${REPO_DESC}\",\"private\":${REPO_PRIVATE}}")

case "$http_code" in
  201)
    print_ok "Repository creato su GitHub!"
    ;;
  422)
    # Repo già esistente — non è un errore, procediamo
    print_warn "Repository già esistente su GitHub, procedo con l'inizializzazione locale."
    ;;
  *)
    print_err "Errore creazione repo (HTTP $http_code):"
    jq -r '.message // .' "$tmp_resp"
    rm -f "$tmp_resp"
    exit 1
    ;;
esac
rm -f "$tmp_resp"

# ─────────────────────────────────────────────────────────────
# === STEP 2: AGGIUNGE CHIAVE SSH ===
# ─────────────────────────────────────────────────────────────
print_step "Aggiungo chiave SSH a GitHub..."

KEY_CONTENT=$(cat "$SSH_KEY_PATH")
KEY_TITLE="marmitta — $(hostname) — $(date +'%Y-%m-%d')"

tmp_ssh=$(mktemp)
http_code=$(curl -s -w "%{http_code}" -o "$tmp_ssh" \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -X POST https://api.github.com/user/keys \
  -d "{\"title\":\"${KEY_TITLE}\",\"key\":\"${KEY_CONTENT}\"}")

case "$http_code" in
  201)
    print_ok "Chiave SSH aggiunta a GitHub!"
    ;;
  422)
    if grep -q "key is already in use" "$tmp_ssh" 2>/dev/null; then
      print_warn "Chiave SSH già presente su GitHub, nessuna azione necessaria."
    else
      print_err "Errore aggiunta chiave SSH (HTTP $http_code):"
      jq -r '.message // .' "$tmp_ssh"
      rm -f "$tmp_ssh"
      exit 1
    fi
    ;;
  *)
    print_err "Errore aggiunta chiave SSH (HTTP $http_code):"
    jq -r '.message // .' "$tmp_ssh"
    rm -f "$tmp_ssh"
    exit 1
    ;;
esac
rm -f "$tmp_ssh"

# ─────────────────────────────────────────────────────────────
# === STEP 3: INIZIALIZZA REPO LOCALE ===
# ─────────────────────────────────────────────────────────────
print_step "Inizializzo repository git locale..."

ORIGIN_DIR="$(pwd)"

if [[ -d "$REPO_NAME" ]]; then
  print_warn "Cartella '${REPO_NAME}' già esistente, entro dentro."
else
  mkdir "$REPO_NAME"
fi

cd "$REPO_NAME" || { print_err "Impossibile entrare in ${REPO_NAME}"; exit 1; }

# Init solo se non è già una repo git
if [[ ! -d ".git" ]]; then
  git init -q
  print_ok "git init completato."
else
  print_warn "Repo git già inizializzata, salto git init."
fi

# Aggiunge remote solo se non esiste già
if git remote get-url origin &>/dev/null; then
  print_warn "Remote 'origin' già presente: $(git remote get-url origin)"
else
  git remote add origin "$FULL_URL"
  print_ok "Remote 'origin' → ${FULL_URL}"
fi

# ─────────────────────────────────────────────────────────────
# === STEP 4: CREA README E PRIMO COMMIT ===
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
  print_ok "README.md creato e committato."
fi

# Torna alla directory originale
cd "$ORIGIN_DIR" || true

# ─────────────────────────────────────────────────────────────
# === DONE ===
# ─────────────────────────────────────────────────────────────
echo -e "\n${GREEN}${BOLD}🎉 Tutto fatto!${RESET}"
echo -e "${DARK_GRAY}  Repo locale: ${RESET}$(pwd)/${REPO_NAME}"
echo -e "${DARK_GRAY}  Remote:      ${RESET}${FULL_URL}"
echo -e "\n${CYAN}Prossimo passo:${RESET}"
echo -e "  ${DARK_GRAY}cd ${REPO_NAME} && git push -u origin master${RESET}\n"
