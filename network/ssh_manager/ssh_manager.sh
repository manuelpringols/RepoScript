#!/bin/bash
# @desc: Gestore connessioni SSH con profili Marmitta — connect, send, tunnel e altro
#
# ─────────────────────────── USO ────────────────────────────────────────────
#   ssh_manager.sh                      → Connetti (selezione fzf)
#   ssh_manager.sh --list    | -l       → Elenca profili con stato online
#   ssh_manager.sh --add     | -a       → Aggiungi nuovo profilo
#   ssh_manager.sh --remove  | -r       → Rimuovi profilo
#   ssh_manager.sh --send    | -s       → Invia file/cartella via SCP
#   ssh_manager.sh --copy-key| -k       → Copia chiave SSH pubblica sul host
#   ssh_manager.sh --tunnel  | -t       → Tunnel SSH (port forwarding locale)
#   ssh_manager.sh --ping    | -p       → Verifica raggiungibilità di tutti i profili
#   ssh_manager.sh --edit    | -e       → Apre il file profili in $EDITOR
#   ssh_manager.sh --help    | -h       → Questa guida
#
# Profili salvati in: ~/.config/marmitta/ssh_profiles
# Formato:            label|user|host|port|ssh_key_path|descrizione
# ────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────
# === PALETTE (coerente con marmitta) ===
# ─────────────────────────────────────────────────────────────
RED='\e[38;5;160m'
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
print_step() { echo -e "\n${MAGENTA}━━━ $1 ━━━${RESET}"; }

# ─────────────────────────────────────────────────────────────
# === CONFIG ===
# ─────────────────────────────────────────────────────────────
MARMITTA_CONFIG="$HOME/.config/marmitta/config"
SSH_PROFILES="$HOME/.config/marmitta/ssh_profiles"

# Carica config Marmitta se disponibile
if [[ -f "$MARMITTA_CONFIG" ]]; then
  # shellcheck source=/dev/null
  source "$MARMITTA_CONFIG"
fi

# Inizializza file profili se assente
mkdir -p "$(dirname "$SSH_PROFILES")"
if [[ ! -f "$SSH_PROFILES" ]]; then
  {
    echo "# SSH Manager — profili Marmitta"
    echo "# Formato: label|user|host|port|ssh_key_path|descrizione"
    echo "# Esempio: homeserver|manuel|192.168.1.10|22|~/.ssh/id_ed25519|Server di casa"
  } > "$SSH_PROFILES"
  chmod 600 "$SSH_PROFILES"
fi

# ─────────────────────────────────────────────────────────────
# === BANNER ===
# ─────────────────────────────────────────────────────────────
print_banner() {
  echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${CYAN}║       🔒  SSH MANAGER                 ║${RESET}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════╝${RESET}"
  echo -e "${DARK_GRAY}  Gestione connessioni SSH con profili Marmitta${RESET}\n"
}

# ─────────────────────────────────────────────────────────────
# === GESTIONE PROFILI ===
# ─────────────────────────────────────────────────────────────

# Restituisce le righe attive (non commenti, non vuote)
load_profiles() {
  grep -v '^#' "$SSH_PROFILES" 2>/dev/null | grep -v '^$' | grep '|' || true
}

# Aggiunge o aggiorna un profilo nel file
save_profile() {
  local label="$1" user="$2" host="$3" port="$4" ssh_key="$5" desc="$6"
  local tmpfile
  tmpfile=$(mktemp)
  grep -v "^${label}|" "$SSH_PROFILES" > "$tmpfile"
  echo "${label}|${user}|${host}|${port}|${ssh_key}|${desc}" >> "$tmpfile"
  mv "$tmpfile" "$SSH_PROFILES"
  chmod 600 "$SSH_PROFILES"
}

# Rimuove un profilo tramite label
remove_profile_from_file() {
  local label="$1"
  local tmpfile
  tmpfile=$(mktemp)
  grep -v "^${label}|" "$SSH_PROFILES" > "$tmpfile"
  mv "$tmpfile" "$SSH_PROFILES"
  chmod 600 "$SSH_PROFILES"
}

# Verifica se host:port è raggiungibile (timeout 2s)
check_host() {
  local host="$1" port="$2"
  nc -zw2 "$host" "$port" &>/dev/null
}

# Selezione profilo via fzf — restituisce la riga raw label|user|host|port|key|desc
fzf_pick_profile() {
  local header="${1:-Seleziona un host SSH}"
  local profiles
  profiles=$(load_profiles)

  # Se non ci sono profili, guida l'utente ad aggiungerne uno
  if [[ -z "$profiles" ]]; then
    print_warn "Nessun profilo configurato."
    read -rp "$(echo -e "${YELLOW}Aggiungere un profilo ora? [Y/n]: ${RESET}")" ans < /dev/tty
    [[ "$ans" =~ ^[Nn]$ ]] && exit 0
    do_add
    profiles=$(load_profiles)
    [[ -z "$profiles" ]] && exit 0
  fi

  # Costruisce lista fzf con formato: raw_line<TAB>display
  local fzf_list=""
  while IFS='|' read -r label user host port ssh_key desc; do
    [[ -z "$label" ]] && continue
    local display
    display="$(printf "%-18s  ${CYAN}%-32s${RESET}  ${DARK_GRAY}%s${RESET}" \
      "$label" "${user}@${host}:${port}" "${desc:-(—)}")"
    fzf_list+="${label}|${user}|${host}|${port}|${ssh_key}|${desc}"$'\t'"${display}"$'\n'
  done <<< "$profiles"

  local chosen
  chosen=$(printf "%s" "$fzf_list" | fzf \
    --height=14 --layout=reverse --border \
    --prompt="🔒 Host > " \
    --delimiter=$'\t' --with-nth=2 \
    --header="  ${header}" \
    --color=fg:#d6de35,bg:#121212,hl:#5f87af \
    --color=fg+:#00ffd9,bg+:#5c00e6,hl+:#5fd7ff \
    --color=pointer:green,header:italic \
    --ansi)

  [[ -z "$chosen" ]] && echo -e "${DARK_GRAY}Annullato.${RESET}" && exit 0
  echo "$chosen" | cut -f1
}

# Espande ~ nel path della chiave SSH
_expand_key() { echo "${1/\~/$HOME}"; }

# ─────────────────────────────────────────────────────────────
# === CONNECT ===
# ─────────────────────────────────────────────────────────────
do_connect() {
  print_banner
  local profile
  profile=$(fzf_pick_profile "Seleziona host a cui connetterti")
  IFS='|' read -r label user host port ssh_key desc <<< "$profile"

  echo -e "${CYAN}🔒 Connessione a:${RESET} ${YELLOW}${user}@${host}${RESET}  ${DARK_GRAY}porta ${port}${RESET}"
  [[ -n "$desc" ]] && echo -e "${DARK_GRAY}   ${desc}${RESET}"
  echo -e "${DARK_GRAY}─────────────────────────────────────────${RESET}\n"

  local ssh_args=(-p "$port")
  local key_path
  key_path=$(_expand_key "$ssh_key")
  [[ -n "$ssh_key" && -f "$key_path" ]] && ssh_args+=(-i "$key_path")

  ssh "${ssh_args[@]}" "${user}@${host}"
}

# ─────────────────────────────────────────────────────────────
# === LIST ===
# ─────────────────────────────────────────────────────────────
do_list() {
  print_banner
  local profiles
  profiles=$(load_profiles)

  if [[ -z "$profiles" ]]; then
    print_warn "Nessun profilo configurato. Usa --add per aggiungerne uno."
    exit 0
  fi

  print_step "Profili SSH"
  echo -e "${DARK_GRAY}  Verifica raggiungibilità in corso...${RESET}\n"
  printf "     ${BOLD}%-18s  %-22s  %-6s  %-22s  %s${RESET}\n" \
    "LABEL" "HOST" "PORTA" "CHIAVE" "DESCRIZIONE"
  echo -e "  ${DARK_GRAY}$(printf '%0.s─' {1..85})${RESET}"

  while IFS='|' read -r label user host port ssh_key desc; do
    [[ -z "$label" ]] && continue
    local sym col
    if check_host "$host" "$port"; then
      sym="●" col="$GREEN"
    else
      sym="●" col="$RED"
    fi
    local key_display
    key_display=$(basename "${ssh_key:-—}")
    printf "  ${col}${sym}${RESET}  %-18s  ${CYAN}${user}@${RESET}%-22s  %-6s  %-22s  ${DARK_GRAY}%s${RESET}\n" \
      "$label" "$host" "$port" "$key_display" "${desc:-(—)}"
  done <<< "$profiles"

  echo -e "\n  ${GREEN}●${RESET} raggiungibile   ${RED}●${RESET} non raggiungibile\n"
}

# ─────────────────────────────────────────────────────────────
# === ADD ===
# ─────────────────────────────────────────────────────────────
do_add() {
  print_banner
  print_step "Nuovo profilo SSH"

  local label user host port ssh_key desc

  read -rp "$(echo -e "${YELLOW}🏷️  Label (es: homeserver): ${RESET}")" label < /dev/tty
  [[ -z "$label" ]] && print_warn "Label vuota — annullato." && return 1

  # Controlla duplicati
  if grep -q "^${label}|" "$SSH_PROFILES" 2>/dev/null; then
    print_warn "Profilo '${label}' già esistente — verrà aggiornato."
  fi

  read -rp "$(echo -e "${YELLOW}👤 Utente SSH (es: root): ${RESET}")" user < /dev/tty
  [[ -z "$user" ]] && print_warn "Utente vuoto — annullato." && return 1

  read -rp "$(echo -e "${YELLOW}🌐 Host / IP (es: 192.168.1.10): ${RESET}")" host < /dev/tty
  [[ -z "$host" ]] && print_warn "Host vuoto — annullato." && return 1

  read -rp "$(echo -e "${YELLOW}🔌 Porta SSH [22]: ${RESET}")" port < /dev/tty
  port="${port:-22}"
  if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 || "$port" -gt 65535 ]]; then
    print_warn "Porta non valida — uso 22."
    port=22
  fi

  # Selezione chiave SSH privata
  mapfile -t pub_keys < <(find "$HOME/.ssh" -maxdepth 1 -name "*.pub" 2>/dev/null | sort)
  if [[ ${#pub_keys[@]} -eq 0 ]]; then
    print_warn "Nessuna chiave SSH trovata — il profilo userà la config SSH di sistema."
    ssh_key=""
  elif [[ ${#pub_keys[@]} -eq 1 ]]; then
    ssh_key="${pub_keys[0]%.pub}"
    print_info "Chiave rilevata: ${ssh_key}"
  else
    echo -e "\n${YELLOW}🔑 Chiavi SSH disponibili:${RESET}"
    for i in "${!pub_keys[@]}"; do
      echo -e "  ${CYAN}$((i+1))${RESET}) ${pub_keys[$i]}"
    done
    echo -e "  ${CYAN}$((${#pub_keys[@]}+1))${RESET}) ${DARK_GRAY}Nessuna (usa config di sistema)${RESET}"
    read -rp "$(echo -e "${YELLOW}Scelta [1]: ${RESET}")" kidx < /dev/tty
    if [[ "${kidx:-1}" =~ ^[0-9]+$ ]] && \
       [[ "${kidx:-1}" -ge 1 ]] && \
       [[ "${kidx:-1}" -le "${#pub_keys[@]}" ]]; then
      ssh_key="${pub_keys[$(( ${kidx:-1} - 1 ))]%.pub}"
    else
      ssh_key=""
    fi
  fi

  read -rp "$(echo -e "${YELLOW}📝 Descrizione (opzionale): ${RESET}")" desc < /dev/tty

  # Riepilogo
  echo -e "\n${CYAN}${BOLD}📋 Riepilogo${RESET}"
  echo -e "  ${DARK_GRAY}Label:       ${RESET}${label}"
  echo -e "  ${DARK_GRAY}Connessione: ${RESET}${user}@${host}:${port}"
  echo -e "  ${DARK_GRAY}Chiave SSH:  ${RESET}${ssh_key:-(config di sistema)}"
  echo -e "  ${DARK_GRAY}Descrizione: ${RESET}${desc:-(nessuna)}"

  read -rp "$(echo -e "\n${YELLOW}Confermi? [Y/n]: ${RESET}")" confirm < /dev/tty
  [[ "$confirm" =~ ^[Nn]$ ]] && print_warn "Annullato." && return 0

  save_profile "$label" "$user" "$host" "$port" "$ssh_key" "$desc"
  print_ok "Profilo '${label}' salvato."
}

# ─────────────────────────────────────────────────────────────
# === REMOVE ===
# ─────────────────────────────────────────────────────────────
do_remove() {
  print_banner
  print_step "Rimuovi profilo SSH"

  local profile
  profile=$(fzf_pick_profile "Seleziona il profilo da rimuovere")
  IFS='|' read -r label user host port _ desc <<< "$profile"

  echo -e "${YELLOW}⚠️  Stai per rimuovere:${RESET} ${BOLD}${label}${RESET} ${DARK_GRAY}(${user}@${host}:${port})${RESET}"
  read -rp "$(echo -e "${RED}Confermi la rimozione? [y/N]: ${RESET}")" confirm < /dev/tty
  [[ ! "$confirm" =~ ^[Yy]$ ]] && print_warn "Annullato." && exit 0

  remove_profile_from_file "$label"
  print_ok "Profilo '${label}' rimosso."
}

# ─────────────────────────────────────────────────────────────
# === SEND FILE via SCP ===
# ─────────────────────────────────────────────────────────────
do_send() {
  print_banner
  print_step "Invia file via SCP"

  local profile
  profile=$(fzf_pick_profile "Seleziona host destinazione")
  IFS='|' read -r label user host port ssh_key desc <<< "$profile"

  echo -e "${CYAN}📤 Destinazione:${RESET} ${user}@${host}:${port}\n"

  read -rp "$(echo -e "${YELLOW}📁 File/directory locale (es: ./report.pdf): ${RESET}")" local_path < /dev/tty
  [[ -z "$local_path" ]] && print_warn "Percorso vuoto — annullato." && exit 0
  local_path="${local_path/#\~/$HOME}"
  [[ ! -e "$local_path" ]] && print_err "Percorso non trovato: ${local_path}"

  read -rp "$(echo -e "${YELLOW}📂 Destinazione remota [~/]: ${RESET}")" remote_path < /dev/tty
  remote_path="${remote_path:-~/}"

  local scp_args=(-P "$port")
  local key_path
  key_path=$(_expand_key "$ssh_key")
  [[ -n "$ssh_key" && -f "$key_path" ]] && scp_args+=(-i "$key_path")
  [[ -d "$local_path" ]] && scp_args+=(-r)

  echo -e "\n${CYAN}📤 Invio:${RESET} ${YELLOW}${local_path}${RESET} → ${CYAN}${user}@${host}:${remote_path}${RESET}\n"
  scp "${scp_args[@]}" "$local_path" "${user}@${host}:${remote_path}"

  if [[ $? -eq 0 ]]; then
    print_ok "Trasferimento completato."
  else
    print_err "Trasferimento fallito — controlla permessi e connessione."
  fi
}

# ─────────────────────────────────────────────────────────────
# === COPY SSH KEY ===
# ─────────────────────────────────────────────────────────────
do_copy_key() {
  print_banner
  print_step "Copia chiave SSH pubblica sul host"

  local profile
  profile=$(fzf_pick_profile "Seleziona host destinazione")
  IFS='|' read -r label user host port ssh_key desc <<< "$profile"

  # Seleziona chiave pubblica: preferisce quella del profilo, altrimenti chiede
  local pub_key
  local key_path
  key_path=$(_expand_key "$ssh_key")
  if [[ -n "$ssh_key" && -f "${key_path}.pub" ]]; then
    pub_key="${key_path}.pub"
    print_info "Uso chiave del profilo: ${pub_key}"
  else
    mapfile -t pub_keys < <(find "$HOME/.ssh" -maxdepth 1 -name "*.pub" 2>/dev/null | sort)
    [[ ${#pub_keys[@]} -eq 0 ]] && print_err "Nessuna chiave pubblica trovata in ~/.ssh/"
    if [[ ${#pub_keys[@]} -eq 1 ]]; then
      pub_key="${pub_keys[0]}"
    else
      echo -e "\n${YELLOW}🔑 Scegli la chiave pubblica da copiare:${RESET}"
      for i in "${!pub_keys[@]}"; do
        echo -e "  ${CYAN}$((i+1))${RESET}) ${pub_keys[$i]}"
      done
      read -rp "$(echo -e "${YELLOW}Scelta [1]: ${RESET}")" kidx < /dev/tty
      if [[ "${kidx:-1}" =~ ^[0-9]+$ ]] && [[ "${kidx:-1}" -le "${#pub_keys[@]}" ]]; then
        pub_key="${pub_keys[$(( ${kidx:-1} - 1 ))]}"
      else
        pub_key="${pub_keys[0]}"
      fi
    fi
  fi

  echo -e "${CYAN}🔑 Copia:${RESET} ${pub_key} → ${user}@${host}:${port}\n"

  # ssh-copy-id con fallback manuale
  if command -v ssh-copy-id &>/dev/null; then
    ssh-copy-id -i "$pub_key" -p "$port" "${user}@${host}"
  else
    print_warn "ssh-copy-id non trovato — uso fallback manuale."
    local pub_content
    pub_content=$(cat "$pub_key")
    ssh -p "$port" "${user}@${host}" \
      "mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
       echo '${pub_content}' >> ~/.ssh/authorized_keys && \
       chmod 600 ~/.ssh/authorized_keys"
  fi

  [[ $? -eq 0 ]] && print_ok "Chiave copiata con successo." \
                 || print_err "Copia chiave fallita — verifica credenziali."
}

# ─────────────────────────────────────────────────────────────
# === TUNNEL SSH ===
# ─────────────────────────────────────────────────────────────
do_tunnel() {
  print_banner
  print_step "Tunnel SSH (port forwarding locale)"

  local profile
  profile=$(fzf_pick_profile "Seleziona host per il tunnel")
  IFS='|' read -r label user host port ssh_key desc <<< "$profile"

  echo -e "${CYAN}🔒 Bastion:${RESET} ${user}@${host}:${port}\n"

  local local_port remote_endpoint
  read -rp "$(echo -e "${YELLOW}🔌 Porta locale [8080]: ${RESET}")" local_port < /dev/tty
  local_port="${local_port:-8080}"
  if ! [[ "$local_port" =~ ^[0-9]+$ ]]; then
    print_warn "Porta non valida — uso 8080."
    local_port=8080
  fi

  read -rp "$(echo -e "${YELLOW}🎯 Endpoint remoto da esporre [localhost:80]: ${RESET}")" remote_endpoint < /dev/tty
  remote_endpoint="${remote_endpoint:-localhost:80}"

  read -rp "$(echo -e "${YELLOW}🔄 Esegui in background? [y/N]: ${RESET}")" bg_ans < /dev/tty

  local ssh_args=(-N -L "${local_port}:${remote_endpoint}" -p "$port")
  local key_path
  key_path=$(_expand_key "$ssh_key")
  [[ -n "$ssh_key" && -f "$key_path" ]] && ssh_args+=(-i "$key_path")
  ssh_args+=("${user}@${host}")

  echo -e "\n${CYAN}🔀 Tunnel:${RESET} ${GREEN}localhost:${local_port}${RESET} → ${YELLOW}${remote_endpoint}${RESET} via ${host}"

  if [[ "$bg_ans" =~ ^[Yy]$ ]]; then
    ssh "${ssh_args[@]}" &
    local tunnel_pid=$!
    print_ok "Tunnel avviato in background (PID ${tunnel_pid})"
    echo -e "${DARK_GRAY}  Chiudi con: kill ${tunnel_pid}${RESET}\n"
  else
    echo -e "${DARK_GRAY}─────────────────────────────────────────${RESET}"
    print_info "Tunnel attivo — premi Ctrl+C per chiudere."
    echo -e "${DARK_GRAY}─────────────────────────────────────────${RESET}\n"
    ssh "${ssh_args[@]}"
  fi
}

# ─────────────────────────────────────────────────────────────
# === PING ALL ===
# ─────────────────────────────────────────────────────────────
do_ping() {
  print_banner
  print_step "Verifica raggiungibilità profili"

  local profiles
  profiles=$(load_profiles)
  [[ -z "$profiles" ]] && print_warn "Nessun profilo configurato." && exit 0

  local total=0 reachable=0
  echo ""
  while IFS='|' read -r label user host port _ desc; do
    [[ -z "$label" ]] && continue
    (( total++ ))
    local t_start t_end ms
    t_start=$(date +%s%3N)
    if check_host "$host" "$port"; then
      t_end=$(date +%s%3N)
      ms=$(( t_end - t_start ))
      printf "  ${GREEN}●${RESET}  %-18s  ${CYAN}%-26s${RESET}  ${DARK_GRAY}%dms${RESET}\n" \
        "$label" "${host}:${port}" "$ms"
      (( reachable++ ))
    else
      printf "  ${RED}●${RESET}  %-18s  ${DARK_GRAY}%-26s  non raggiungibile${RESET}\n" \
        "$label" "${host}:${port}"
    fi
  done <<< "$profiles"

  echo ""
  echo -e "  ${DARK_GRAY}Risultato: ${GREEN}${reachable}${DARK_GRAY}/${total} host raggiungibili${RESET}\n"
}

# ─────────────────────────────────────────────────────────────
# === DIPENDENZE ===
# ─────────────────────────────────────────────────────────────
for _cmd in ssh scp fzf nc; do
  command -v "$_cmd" &>/dev/null || {
    echo -e "${RED}❌ '${_cmd}' non trovato. Installalo prima di usare ssh_manager.${RESET}"
    exit 1
  }
done
unset _cmd

# ─────────────────────────────────────────────────────────────
# === ENTRY POINT ===
# ─────────────────────────────────────────────────────────────
case "${1:-}" in
  -l|--list)       do_list ;;
  -a|--add)        do_add ;;
  -r|--remove)     do_remove ;;
  -s|--send)       do_send ;;
  -k|--copy-key)   do_copy_key ;;
  -t|--tunnel)     do_tunnel ;;
  -p|--ping)       do_ping ;;
  -e|--edit)       "${EDITOR:-nano}" "$SSH_PROFILES" ;;
  -h|--help)
    echo -e "\n${BOLD}${CYAN}SSH MANAGER${RESET} — Gestione connessioni SSH con profili Marmitta\n"
    echo -e "  ${GREEN}(nessun flag)${RESET}        Connetti (selezione fzf)"
    echo -e "  ${CYAN}-l, --list${RESET}           Elenca profili con stato online"
    echo -e "  ${CYAN}-a, --add${RESET}            Aggiungi nuovo profilo"
    echo -e "  ${CYAN}-r, --remove${RESET}         Rimuovi profilo"
    echo -e "  ${YELLOW}-s, --send${RESET}           Invia file/cartella via SCP"
    echo -e "  ${YELLOW}-k, --copy-key${RESET}       Copia chiave SSH pubblica sul host"
    echo -e "  ${MAGENTA}-t, --tunnel${RESET}         Tunnel SSH (port forwarding locale)"
    echo -e "  ${ORANGE}-p, --ping${RESET}           Verifica raggiungibilità di tutti i profili"
    echo -e "  ${DARK_GRAY}-e, --edit${RESET}           Apre il file profili in \$EDITOR"
    echo -e "  ${RED}-h, --help${RESET}           Mostra questa guida\n"
    echo -e "${DARK_GRAY}  Profili: ${SSH_PROFILES}${RESET}\n"
    ;;
  "")  do_connect ;;
  *)   print_err "Flag non riconosciuto: '${1}'. Usa --help per la guida." ;;
esac
