#!/bin/bash
# @desc: Commit e push rapido con status preview e branch dinamico

GREEN="\e[1;32m"
CYAN="\e[1;36m"
YELLOW="\e[1;33m"
RED="\e[1;31m"
MAGENTA="\e[1;35m"
DARK_GRAY="\e[90m"
BOLD="\e[1m"
RESET="\e[0m"

print_ok()   { echo -e "${GREEN}✅ $1${RESET}"; }
print_err()  { echo -e "${RED}❌ $1${RESET}"; exit 1; }
print_warn() { echo -e "${YELLOW}⚠️  $1${RESET}"; }
print_info() { echo -e "${CYAN}ℹ️  $1${RESET}"; }

# ─────────────────────────────────────────────────────────────
# === VERIFICA REPO GIT ===
# ─────────────────────────────────────────────────────────────
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  print_err "Non sei dentro una repository git."
fi

# ─────────────────────────────────────────────────────────────
# === BRANCH CORRENTE ===
# ─────────────────────────────────────────────────────────────
BRANCH=$(git branch --show-current 2>/dev/null)
[[ -z "$BRANCH" ]] && print_err "Impossibile rilevare il branch corrente."

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
REPO_NAME=$(basename "$REPO_ROOT")

echo -e "\n${BOLD}${CYAN}🐍 SLITHER PUSH${RESET}"
echo -e "${DARK_GRAY}  repo:   ${RESET}${REPO_NAME}"
echo -e "${DARK_GRAY}  branch: ${RESET}${GREEN}${BRANCH}${RESET}\n"

# ─────────────────────────────────────────────────────────────
# === STATUS PREVIEW ===
# ─────────────────────────────────────────────────────────────
STATUS=$(git status --short 2>/dev/null)

if [[ -z "$STATUS" ]]; then
  print_warn "Nessuna modifica rilevata. Niente da committare."
  exit 0
fi

echo -e "${YELLOW}📋 Modifiche rilevate:${RESET}"
while IFS= read -r line; do
  flag="${line:0:2}"
  file="${line:3}"
  case "$flag" in
    "M "|" M") echo -e "  ${CYAN}~${RESET}  ${file}" ;;
    "A "|" A") echo -e "  ${GREEN}+${RESET}  ${file}" ;;
    "D "|" D") echo -e "  ${RED}-${RESET}  ${file}" ;;
    "??")      echo -e "  ${DARK_GRAY}?${RESET}  ${file}" ;;
    *)         echo -e "  ${MAGENTA}*${RESET}  ${file}" ;;
  esac
done <<< "$STATUS"
echo ""

# ─────────────────────────────────────────────────────────────
# === MESSAGGIO COMMIT ===
# ─────────────────────────────────────────────────────────────
if [[ $# -gt 0 ]]; then
  commit_msg="$*"
  echo -e "${DARK_GRAY}Messaggio da argomento:${RESET} ${commit_msg}\n"
else
  read -rp "$(echo -e "${YELLOW}💬 Messaggio di commit: ${RESET}")" commit_msg < /dev/tty
  while [[ -z "$commit_msg" ]]; do
    print_warn "Il messaggio non può essere vuoto."
    read -rp "$(echo -e "${YELLOW}💬 Messaggio di commit: ${RESET}")" commit_msg < /dev/tty
  done
fi

# ─────────────────────────────────────────────────────────────
# === GIT ADD + COMMIT ===
# ─────────────────────────────────────────────────────────────
echo -e "\n${YELLOW}📝 git add .${RESET}"
git add . || print_err "git add fallito."

echo -e "${YELLOW}💾 git commit${RESET}"
git commit -m "$commit_msg" || print_err "Commit fallito."

# ─────────────────────────────────────────────────────────────
# === PUSH ===
# ─────────────────────────────────────────────────────────────
echo -e "${CYAN}🌐 git push origin ${BRANCH}${RESET}"
git push origin "$BRANCH"
PUSH_EXIT=$?

# ─────────────────────────────────────────────────────────────
# === LOADING BAR (feedback visivo post-push) ===
# ─────────────────────────────────────────────────────────────
if [[ $PUSH_EXIT -eq 0 ]]; then
  echo -n -e "\n🚀  ${GREEN}["
  for ((i=0; i<20; i++)); do
    color=$((31 + i % 6))
    echo -ne "\e[48;5;${color}m \e[0m"
    sleep 0.05
  done
  echo -e "${GREEN}]${RESET}\n"
  print_ok "Push completato! ${DARK_GRAY}→ origin/${BRANCH}${RESET}"
else
  print_err "Push fallito. Controlla connessione o permessi su origin/${BRANCH}."
fi