#!/bin/bash
# @desc: Coltellino svizzero AI locale — chat, domande, codice, riassunti, traduzione
#
# ─────────────────────────── USO ─────────────────────────────────────────────
#   ask_ai.sh                            → Chat interattiva (default)
#   ask_ai.sh -q "domanda"               → Risposta diretta, poi esci
#   ask_ai.sh --code                     → Chat in modalità assistente codice
#   ask_ai.sh --explain FILE             → Spiega un file o testo
#   ask_ai.sh --summarize FILE           → Riassumi un file
#   ask_ai.sh --translate "testo"        → Traduci nella lingua configurata
#   ask_ai.sh -m mistral:7b              → Usa un modello specifico
#   ask_ai.sh --install                  → Setup guidato: Ollama + modello
#   ask_ai.sh --models                   → Elenca modelli installati
#   ask_ai.sh --status                   → Stato sistema e configurazione
#   ask_ai.sh -h | --help                → Questa guida
#
# Pipeline supportata:
#   cat errore.log   | ask_ai.sh -q "cosa significa questo errore?"
#   git diff HEAD    | ask_ai.sh -q "scrivi il messaggio di commit"
#   cat script.py    | ask_ai.sh --explain
#
# Configurazione in ~/.config/marmitta/config:
#   MARMITTA_AI_MODEL="llama3.2:3b"   # modello preferito
#   MARMITTA_AI_LANG="italiano"       # lingua delle risposte
# ─────────────────────────────────────────────────────────────────────────────

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
print_err()  { echo -e "${RED}❌ $1${RESET}" >&2; exit 1; }
print_warn() { echo -e "${YELLOW}⚠️  $1${RESET}" >&2; }
print_info() { echo -e "${CYAN}ℹ️  $1${RESET}" >&2; }
print_step() { echo -e "\n${MAGENTA}━━━ $1 ━━━${RESET}" >&2; }

# ─────────────────────────────────────────────────────────────
# === CONFIG (Marmitta + defaults) ===
# ─────────────────────────────────────────────────────────────
MARMITTA_CONFIG="$HOME/.config/marmitta/config"
AI_CACHE_DIR="$HOME/.config/marmitta/cache/ask_ai"
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"

# Carica config Marmitta se disponibile
if [[ -f "$MARMITTA_CONFIG" ]]; then
  # shellcheck source=/dev/null
  source "$MARMITTA_CONFIG"
fi

AI_MODEL="${MARMITTA_AI_MODEL:-}"        # rilevato dinamicamente se vuoto
AI_LANG="${MARMITTA_AI_LANG:-italiano}"

mkdir -p "$AI_CACHE_DIR"

# ─────────────────────────────────────────────────────────────
# === BANNER ===
# ─────────────────────────────────────────────────────────────
print_banner() {
  echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${CYAN}║    🤖  ASK AI  —  locale & gratuito  ║${RESET}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════╝${RESET}"
  echo -e "${DARK_GRAY}  Powered by Ollama · ${AI_MODEL}${RESET}\n"
}

# ─────────────────────────────────────────────────────────────
# === RILEVAMENTO HARDWARE ===
# ─────────────────────────────────────────────────────────────

# Restituisce la RAM totale in GB
detect_ram_gb() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    local bytes
    bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    echo $(( bytes / 1024 / 1024 / 1024 ))
  else
    local kb
    kb=$(grep -m1 MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0)
    echo $(( kb / 1024 / 1024 ))
  fi
}

# Restituisce "nvidia:VRAM_MB" | "apple_silicon" | "amd" | "cpu"
detect_gpu() {
  if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null 2>&1; then
    local vram
    vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null \
           | head -1 | tr -d ' ')
    echo "nvidia:${vram:-0}"
    return
  fi
  if [[ "$OSTYPE" == "darwin"* && "$(uname -m)" == "arm64" ]]; then
    echo "apple_silicon"
    return
  fi
  if command -v rocm-smi &>/dev/null && rocm-smi &>/dev/null 2>&1; then
    echo "amd"
    return
  fi
  echo "cpu"
}

# Suggerisce il modello ottimale in base all'hardware
suggest_model() {
  local ram_gb="$1"
  local gpu_info="$2"
  local use_case="${3:-general}"   # general | code

  if [[ "$use_case" == "code" ]]; then
    [[ "$ram_gb" -ge 8 ]] && echo "codellama:7b" || echo "deepseek-coder:1.3b"
    return
  fi

  # GPU disponibile o RAM alta → modello più capace
  if [[ "$gpu_info" != "cpu" ]]; then
    [[ "$ram_gb" -ge 16 ]] && echo "llama3.1:8b" || echo "llama3.2:3b"
  elif [[ "$ram_gb" -ge 16 ]]; then
    echo "llama3.1:8b"
  elif [[ "$ram_gb" -ge 8 ]]; then
    echo "llama3.2:3b"
  else
    echo "phi3:mini"
  fi
}

# ─────────────────────────────────────────────────────────────
# === GESTIONE OLLAMA ===
# ─────────────────────────────────────────────────────────────

check_ollama()      { command -v ollama &>/dev/null; }
is_ollama_running() { curl -sf "${OLLAMA_HOST}/api/version" &>/dev/null; }

start_ollama_server() {
  is_ollama_running && return 0
  print_info "Avvio Ollama server..."
  ollama serve &>/dev/null &
  local attempts=0
  while ! is_ollama_running; do
    sleep 0.5
    (( attempts++ ))
    [[ "$attempts" -gt 10 ]] && print_err "Impossibile avviare Ollama. Prova: ollama serve"
  done
}

install_ollama() {
  print_step "Installazione Ollama"
  if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &>/dev/null; then
    brew install ollama
  else
    curl -fsSL https://ollama.ai/install.sh | sh
  fi
  command -v ollama &>/dev/null || print_err "Installazione Ollama fallita."
  print_ok "Ollama installato."
}

# Scarica il modello se non presente; mostra barra di avanzamento nativa ollama
ensure_model() {
  local model="$1"
  # Controlla se il modello è già disponibile
  if ollama list 2>/dev/null | awk 'NR>1{print $1}' | grep -qx "${model%%:*}:${model#*:}"; then
    return 0
  fi
  if ollama list 2>/dev/null | awk 'NR>1{print $1}' | grep -qx "$model"; then
    return 0
  fi
  print_step "Download modello: ${model}"
  print_info "Primo avvio — potrebbe richiedere qualche minuto..."
  ollama pull "$model" || print_err "Download modello '${model}' fallito."
  print_ok "Modello '${model}' pronto."
}

# Risolve e imposta AI_MODEL se non già configurato
resolve_model() {
  local use_case="${1:-general}"
  if [[ -z "$AI_MODEL" ]]; then
    local ram gpu
    ram=$(detect_ram_gb)
    gpu=$(detect_gpu)
    AI_MODEL=$(suggest_model "$ram" "$gpu" "$use_case")
    print_info "Hardware rilevato — modello consigliato: ${BOLD}${AI_MODEL}${RESET}"
  fi
}

# Salva il modello preferito nel config Marmitta
_save_model_to_config() {
  local model="$1"
  mkdir -p "$(dirname "$MARMITTA_CONFIG")"
  if [[ -f "$MARMITTA_CONFIG" ]]; then
    if grep -q "^MARMITTA_AI_MODEL=" "$MARMITTA_CONFIG"; then
      sed -i "s|^MARMITTA_AI_MODEL=.*|MARMITTA_AI_MODEL=\"${model}\"|" "$MARMITTA_CONFIG"
    else
      echo "MARMITTA_AI_MODEL=\"${model}\"" >> "$MARMITTA_CONFIG"
    fi
  else
    echo "MARMITTA_AI_MODEL=\"${model}\"" > "$MARMITTA_CONFIG"
  fi
}

# ─────────────────────────────────────────────────────────────
# === STREAMING API (Ollama /api/chat) ===
# Stampa i token in tempo reale e restituisce la risposta completa in $REPLY
# ─────────────────────────────────────────────────────────────
_stream_response() {
  local payload="$1"
  REPLY=""
  local token
  while IFS= read -r line; do
    token=$(jq -r '.message.content // empty' 2>/dev/null <<< "$line")
    printf "%s" "$token"
    REPLY+="${token}"
  done < <(curl -s -N "${OLLAMA_HOST}/api/chat" \
    -H "Content-Type: application/json" \
    -d "$payload" 2>/dev/null)
  echo ""
}

# Costruisce il payload JSON per /api/chat
_build_payload() {
  local model="$1"
  local messages="$2"   # JSON array string
  jq -n \
    --arg model "$model" \
    --argjson msgs "$messages" \
    '{"model":$model,"messages":$msgs,"stream":true}'
}

# Aggiunge un messaggio all'array JSON della conversazione
_append_message() {
  local messages="$1" role="$2" content="$3"
  jq --arg role "$role" --arg content "$content" \
    '. += [{"role":$role,"content":$content}]' <<< "$messages"
}

# Salva la conversazione su file
_save_conversation() {
  local messages="$1" model="$2"
  local fname="${AI_CACHE_DIR}/chat_$(date +%Y%m%d_%H%M%S).json"
  jq --arg model "$model" '{"model":$model,"messages":.}' <<< "$messages" > "$fname"
  print_ok "Conversazione salvata: ${fname}"
}

# ─────────────────────────────────────────────────────────────
# === MODALITÀ: CHAT INTERATTIVA ===
# ─────────────────────────────────────────────────────────────
do_chat() {
  local model="$1"
  local system_prompt="${2:-Sei un assistente AI utile e preciso. Rispondi in ${AI_LANG} in modo conciso ma completo.}"

  start_ollama_server
  ensure_model "$model"
  print_banner

  echo -e "${DARK_GRAY}  /help comandi · /clear reset · /save salva · /model cambia · /exit esci${RESET}"
  echo -e "${DARK_GRAY}────────────────────────────────────────────────────${RESET}\n"

  # Leggi eventuale input da pipe (es: cat file.py | ask_ai.sh)
  local piped_context=""
  if [[ ! -t 0 ]]; then
    piped_context=$(cat)
    print_info "Contesto rilevato da pipe (${#piped_context} chars)."
  fi

  local messages="[]"
  messages=$(_append_message "$messages" "system" "$system_prompt")
  if [[ -n "$piped_context" ]]; then
    messages=$(_append_message "$messages" "user" \
      "Contesto fornito:\n\n${piped_context}\n\nProcedi quando sei pronto.")
    messages=$(_append_message "$messages" "assistant" \
      "Contesto ricevuto. Cosa vuoi sapere o fare con questo?")
  fi

  while true; do
    echo -ne "${GREEN}tu${RESET} ${DARK_GRAY}▸${RESET} "
    IFS= read -r user_input < /dev/tty || break

    case "$user_input" in
      "") continue ;;

      /exit|/quit|/q)
        echo -e "\n${DARK_GRAY}Uscita da ask_ai.${RESET}\n"
        break
        ;;

      /clear)
        messages="[]"
        messages=$(_append_message "$messages" "system" "$system_prompt")
        print_ok "Conversazione resettata."
        continue
        ;;

      /save)
        _save_conversation "$messages" "$model"
        continue
        ;;

      /model*)
        local new_model="${user_input#/model}"
        new_model="${new_model# }"
        if [[ -n "$new_model" ]]; then
          ensure_model "$new_model"
          model="$new_model"
          AI_MODEL="$model"
          print_ok "Modello cambiato: ${model}"
          read -rp "$(echo -e "${YELLOW}Salvare come preferito in Marmitta? [y/N]: ${RESET}")" sv < /dev/tty
          [[ "$sv" =~ ^[Yy]$ ]] && _save_model_to_config "$model"
        else
          echo -e "${YELLOW}Uso: /model <nome_modello>  es: /model mistral:7b${RESET}"
        fi
        continue
        ;;

      /help)
        echo -e "\n${CYAN}${BOLD}Comandi chat:${RESET}"
        echo -e "  ${YELLOW}/clear${RESET}           Resetta la conversazione"
        echo -e "  ${YELLOW}/save${RESET}            Salva la chat in ${AI_CACHE_DIR}/"
        echo -e "  ${YELLOW}/model <nome>${RESET}    Cambia modello (es: /model mistral:7b)"
        echo -e "  ${YELLOW}/exit${RESET}            Esci\n"
        continue
        ;;
    esac

    # Aggiungi messaggio utente alla storia
    messages=$(_append_message "$messages" "user" "$user_input")
    local payload
    payload=$(_build_payload "$model" "$messages")

    echo -ne "\n${CYAN}ai${RESET} ${DARK_GRAY}▸${RESET} ${CYAN}"
    _stream_response "$payload"
    echo -ne "${RESET}"

    # Aggiungi risposta alla storia
    if [[ -n "$REPLY" ]]; then
      messages=$(_append_message "$messages" "assistant" "$REPLY")
    fi
    echo ""
  done
}

# ─────────────────────────────────────────────────────────────
# === MODALITÀ: ONE-SHOT (-q) ===
# Risponde a una domanda e termina. Supporta pipe.
# ─────────────────────────────────────────────────────────────
do_ask() {
  local model="$1"
  local question="$2"
  local system_prompt="${3:-Sei un assistente AI preciso. Rispondi in ${AI_LANG}. Sii conciso.}"

  start_ollama_server
  ensure_model "$model"

  # Aggiungi eventuale contesto dalla pipe
  local piped_context=""
  if [[ ! -t 0 ]]; then
    piped_context=$(cat)
  fi
  [[ -n "$piped_context" ]] && question="${question}\n\nContesto:\n${piped_context}"

  local messages="[]"
  messages=$(_append_message "$messages" "system" "$system_prompt")
  messages=$(_append_message "$messages" "user" "$question")

  local payload
  payload=$(_build_payload "$model" "$messages")

  echo -e "${CYAN}"
  _stream_response "$payload"
  echo -e "${RESET}"
}

# ─────────────────────────────────────────────────────────────
# === MODALITÀ: ASSISTENTE CODICE ===
# ─────────────────────────────────────────────────────────────
do_code() {
  local model="$1"
  local system_prompt="Sei un programmatore senior esperto. \
Fornisci soluzioni di codice pulite, efficienti e ben commentate. \
Usa sempre blocchi markdown per il codice. \
Spiega brevemente le scelte architetturali importanti. \
Rispondi in ${AI_LANG}."

  do_chat "$model" "$system_prompt"
}

# ─────────────────────────────────────────────────────────────
# === MODALITÀ: SPIEGA FILE/TESTO (--explain) ===
# ─────────────────────────────────────────────────────────────
do_explain() {
  local model="$1"
  local target="$2"
  local system_prompt="Sei un esperto tecnico. Analizza e spiega in modo chiaro \
e dettagliato ciò che ti viene mostrato. Evidenzia la logica principale, i pattern \
usati e possibili problemi. Rispondi in ${AI_LANG}."

  local content
  if [[ -f "$target" ]]; then
    content=$(cat "$target")
    print_info "Analizzo: ${target}"
  elif [[ -n "$target" ]]; then
    content="$target"
  elif [[ ! -t 0 ]]; then
    content=$(cat)
    print_info "Analizzo input da pipe..."
  else
    print_err "Specifica un file o passa il testo via pipe. Es: cat file.py | ask_ai.sh --explain"
  fi

  do_ask "$model" "Analizza e spiega il seguente contenuto:\n\n${content}" "$system_prompt"
}

# ─────────────────────────────────────────────────────────────
# === MODALITÀ: RIASSUMI FILE/TESTO (--summarize) ===
# ─────────────────────────────────────────────────────────────
do_summarize() {
  local model="$1"
  local target="$2"
  local system_prompt="Crea un riassunto strutturato. Usa bullet points per i punti chiave. \
Sii conciso ma completo. Rispondi in ${AI_LANG}."

  local content
  if [[ -f "$target" ]]; then
    content=$(cat "$target")
    print_info "Riassumendo: ${target}"
  elif [[ -n "$target" ]]; then
    content="$target"
  elif [[ ! -t 0 ]]; then
    content=$(cat)
  else
    print_err "Specifica un file o passa il testo via pipe."
  fi

  do_ask "$model" "Riassumi il seguente testo:\n\n${content}" "$system_prompt"
}

# ─────────────────────────────────────────────────────────────
# === MODALITÀ: TRADUCI (--translate) ===
# ─────────────────────────────────────────────────────────────
do_translate() {
  local model="$1"
  local text="$2"
  local target_lang="${3:-${AI_LANG}}"
  local system_prompt="Sei un traduttore professionista. \
Traduci mantenendo registro, stile e punteggiatura dell'originale. \
Rispondi SOLO con la traduzione, senza commenti o spiegazioni."

  local content
  if [[ -f "$text" ]]; then
    content=$(cat "$text")
    print_info "Traduco: ${text} → ${target_lang}"
  elif [[ -n "$text" ]]; then
    content="$text"
  elif [[ ! -t 0 ]]; then
    content=$(cat)
  else
    print_err "Specifica un testo o un file. Es: ask_ai.sh --translate 'Hello world'"
  fi

  do_ask "$model" "Traduci in ${target_lang}:\n\n${content}" "$system_prompt"
}

# ─────────────────────────────────────────────────────────────
# === SETUP GUIDATO (--install) ===
# ─────────────────────────────────────────────────────────────
do_install() {
  print_banner
  print_step "Setup guidato Ask AI"

  # 1. Installa Ollama se mancante
  if check_ollama; then
    print_ok "Ollama già installato: $(ollama --version 2>/dev/null | head -1)"
  else
    print_warn "Ollama non trovato."
    read -rp "$(echo -e "${YELLOW}Installare Ollama ora? [Y/n]: ${RESET}")" ans < /dev/tty
    [[ "$ans" =~ ^[Nn]$ ]] && print_warn "Setup annullato." && exit 0
    install_ollama
  fi

  # 2. Rileva hardware e suggerisci modello
  print_step "Rilevamento hardware"
  local ram gpu suggested
  ram=$(detect_ram_gb)
  gpu=$(detect_gpu)
  suggested=$(suggest_model "$ram" "$gpu" "general")
  suggested_code=$(suggest_model "$ram" "$gpu" "code")

  echo -e "  ${DARK_GRAY}RAM disponibile:${RESET}   ${ram}GB"
  echo -e "  ${DARK_GRAY}GPU rilevata:${RESET}      ${gpu}"
  echo -e "  ${DARK_GRAY}Modello generale:${RESET}  ${CYAN}${suggested}${RESET}"
  echo -e "  ${DARK_GRAY}Modello codice:${RESET}    ${CYAN}${suggested_code}${RESET}"

  # 3. Scegli modello
  echo ""
  echo -e "${YELLOW}Modelli disponibili (seleziona o inserisci manuale):${RESET}"
  echo -e "  ${CYAN}1${RESET}) ${suggested}  ${DARK_GRAY}(raccomandato per il tuo hardware)${RESET}"
  echo -e "  ${CYAN}2${RESET}) phi3:mini         ${DARK_GRAY}(leggero, 3.8B — velocissimo)${RESET}"
  echo -e "  ${CYAN}3${RESET}) mistral:7b        ${DARK_GRAY}(qualità, 7B — richiede 8GB RAM)${RESET}"
  echo -e "  ${CYAN}4${RESET}) llama3.1:8b       ${DARK_GRAY}(ottimo, 8B — richiede 8GB RAM)${RESET}"
  echo -e "  ${CYAN}5${RESET}) codellama:7b      ${DARK_GRAY}(specializzato codice, 7B)${RESET}"
  echo -e "  ${CYAN}6${RESET}) Inserisci nome manuale"

  read -rp "$(echo -e "\n${YELLOW}Scelta [1]: ${RESET}")" choice < /dev/tty
  local chosen_model
  case "${choice:-1}" in
    1) chosen_model="$suggested" ;;
    2) chosen_model="phi3:mini" ;;
    3) chosen_model="mistral:7b" ;;
    4) chosen_model="llama3.1:8b" ;;
    5) chosen_model="codellama:7b" ;;
    6)
      read -rp "$(echo -e "${YELLOW}Nome modello (es: gemma2:9b): ${RESET}")" chosen_model < /dev/tty
      [[ -z "$chosen_model" ]] && chosen_model="$suggested"
      ;;
    *) chosen_model="$suggested" ;;
  esac

  # 4. Download modello
  start_ollama_server
  ensure_model "$chosen_model"

  # 5. Lingua risposte
  read -rp "$(echo -e "${YELLOW}Lingua delle risposte [italiano]: ${RESET}")" lang < /dev/tty
  lang="${lang:-italiano}"

  # 6. Salva config Marmitta
  _save_model_to_config "$chosen_model"
  mkdir -p "$(dirname "$MARMITTA_CONFIG")"
  if grep -q "^MARMITTA_AI_LANG=" "$MARMITTA_CONFIG" 2>/dev/null; then
    sed -i "s|^MARMITTA_AI_LANG=.*|MARMITTA_AI_LANG=\"${lang}\"|" "$MARMITTA_CONFIG"
  else
    echo "MARMITTA_AI_LANG=\"${lang}\"" >> "$MARMITTA_CONFIG"
  fi

  AI_MODEL="$chosen_model"
  AI_LANG="$lang"

  echo ""
  print_ok "Setup completato!"
  echo -e "  ${DARK_GRAY}Modello:  ${RESET}${AI_MODEL}"
  echo -e "  ${DARK_GRAY}Lingua:   ${RESET}${AI_LANG}"
  echo -e "  ${DARK_GRAY}Config:   ${RESET}${MARMITTA_CONFIG}"
  echo -e "\n${CYAN}Avvia la chat con:${RESET} ${YELLOW}bash ask_ai.sh${RESET}\n"
}

# ─────────────────────────────────────────────────────────────
# === STATO SISTEMA (--status) ===
# ─────────────────────────────────────────────────────────────
do_status() {
  print_banner
  print_step "Stato sistema"

  # Ollama
  if check_ollama; then
    print_ok "Ollama: $(ollama --version 2>/dev/null | head -1)"
  else
    print_warn "Ollama: non installato — esegui: ask_ai.sh --install"
  fi

  if is_ollama_running; then
    print_ok "Server:  in esecuzione su ${OLLAMA_HOST}"
  else
    print_warn "Server:  non attivo (verrà avviato automaticamente)"
  fi

  # Hardware
  local ram gpu
  ram=$(detect_ram_gb)
  gpu=$(detect_gpu)
  echo -e "\n${CYAN}Hardware:${RESET}"
  echo -e "  ${DARK_GRAY}RAM:${RESET}  ${ram}GB"
  echo -e "  ${DARK_GRAY}GPU:${RESET}  ${gpu}"
  echo -e "  ${DARK_GRAY}OS:${RESET}   ${OSTYPE} / $(uname -m)"

  # Config attiva
  echo -e "\n${CYAN}Configurazione:${RESET}"
  echo -e "  ${DARK_GRAY}Modello:  ${RESET}${AI_MODEL:-(auto-detect)}"
  echo -e "  ${DARK_GRAY}Lingua:   ${RESET}${AI_LANG}"
  echo -e "  ${DARK_GRAY}Config:   ${RESET}${MARMITTA_CONFIG}"
  echo -e "  ${DARK_GRAY}Cache:    ${RESET}${AI_CACHE_DIR}"

  # Modelli installati
  if check_ollama && is_ollama_running; then
    echo -e "\n${CYAN}Modelli installati:${RESET}"
    ollama list 2>/dev/null | tail -n +2 | while IFS= read -r line; do
      echo -e "  ${GREEN}•${RESET} ${line}"
    done
  fi

  # Storico chat salvate
  local chat_count
  chat_count=$(find "$AI_CACHE_DIR" -name "chat_*.json" 2>/dev/null | wc -l | tr -d ' ')
  [[ "$chat_count" -gt 0 ]] && \
    echo -e "\n${CYAN}Chat salvate:${RESET} ${chat_count} in ${AI_CACHE_DIR}/"

  echo ""
}

# ─────────────────────────────────────────────────────────────
# === LISTA MODELLI (--models) ===
# ─────────────────────────────────────────────────────────────
do_list_models() {
  check_ollama || print_err "Ollama non installato. Esegui: ask_ai.sh --install"
  start_ollama_server
  echo -e "\n${CYAN}${BOLD}Modelli installati:${RESET}\n"
  ollama list 2>/dev/null
  echo -e "\n${DARK_GRAY}Aggiungi un modello con: ollama pull <nome>${RESET}"
  echo -e "${DARK_GRAY}Sfoglia i modelli su:   https://ollama.com/library${RESET}\n"
}

# ─────────────────────────────────────────────────────────────
# === DIPENDENZE ===
# ─────────────────────────────────────────────────────────────
for _cmd in curl jq; do
  command -v "$_cmd" &>/dev/null || {
    echo -e "${RED}❌ '${_cmd}' non trovato. Installalo prima di usare ask_ai.${RESET}" >&2
    exit 1
  }
done
unset _cmd

# ─────────────────────────────────────────────────────────────
# === PARSING ARGOMENTI ===
# ─────────────────────────────────────────────────────────────
FLAG_MODE=""
FLAG_QUESTION=""
FLAG_TARGET=""
FLAG_LANG=""
FLAG_MODEL_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -q|--ask)
      FLAG_MODE="ask"
      FLAG_QUESTION="$2"
      shift 2
      ;;
    --code|-c)
      FLAG_MODE="code"
      shift
      ;;
    --explain|-e)
      FLAG_MODE="explain"
      FLAG_TARGET="${2:-}"
      [[ -n "$FLAG_TARGET" && "$FLAG_TARGET" != -* ]] && shift
      shift
      ;;
    --summarize|-s)
      FLAG_MODE="summarize"
      FLAG_TARGET="${2:-}"
      [[ -n "$FLAG_TARGET" && "$FLAG_TARGET" != -* ]] && shift
      shift
      ;;
    --translate|-T)
      FLAG_MODE="translate"
      FLAG_TARGET="${2:-}"
      [[ -n "$FLAG_TARGET" && "$FLAG_TARGET" != -* ]] && shift
      # Lingua opzionale: --translate "testo" --to francese
      if [[ "${2:-}" == "--to" ]]; then
        FLAG_LANG="$3"
        shift 2
      fi
      shift
      ;;
    -m|--model)
      FLAG_MODEL_OVERRIDE="$2"
      shift 2
      ;;
    --install)
      do_install
      exit 0
      ;;
    --models)
      do_list_models
      exit 0
      ;;
    --status)
      do_status
      exit 0
      ;;
    -h|--help)
      echo -e "\n${BOLD}${CYAN}ASK AI${RESET} — Coltellino svizzero AI locale (Ollama)\n"
      echo -e "  ${GREEN}(nessun flag)${RESET}              Chat interattiva"
      echo -e "  ${CYAN}-q, --ask \"domanda\"${RESET}        Risposta diretta"
      echo -e "  ${CYAN}-c, --code${RESET}                 Chat assistente codice"
      echo -e "  ${CYAN}-e, --explain [FILE]${RESET}       Spiega file o testo da pipe"
      echo -e "  ${CYAN}-s, --summarize [FILE]${RESET}     Riassumi file o testo da pipe"
      echo -e "  ${YELLOW}-T, --translate [TESTO]${RESET}    Traduci (--to LINGUA opzionale)"
      echo -e "  ${YELLOW}-m, --model <nome>${RESET}         Usa un modello specifico"
      echo -e "  ${MAGENTA}--install${RESET}                  Setup guidato: Ollama + modello"
      echo -e "  ${MAGENTA}--models${RESET}                   Elenca modelli installati"
      echo -e "  ${ORANGE}--status${RESET}                   Stato sistema e config"
      echo -e "  ${RED}-h, --help${RESET}                 Mostra questa guida\n"
      echo -e "${DARK_GRAY}  Esempi con pipe:${RESET}"
      echo -e "  ${DARK_GRAY}  cat file.py   | ask_ai.sh -q \"refactora questa funzione\"${RESET}"
      echo -e "  ${DARK_GRAY}  git diff HEAD | ask_ai.sh -q \"scrivi il messaggio di commit\"${RESET}"
      echo -e "  ${DARK_GRAY}  cat doc.txt   | ask_ai.sh --summarize${RESET}\n"
      exit 0
      ;;
    *)
      print_err "Flag non riconosciuto: '${1}'. Usa --help per la guida."
      ;;
  esac
done

# ─────────────────────────────────────────────────────────────
# === ENTRY POINT ===
# ─────────────────────────────────────────────────────────────

# Controlla Ollama installato per tutto tranne --install/--help/--status
if [[ "$FLAG_MODE" != "install" ]]; then
  if ! check_ollama; then
    print_warn "Ollama non è installato."
    read -rp "$(echo -e "${YELLOW}Eseguire setup guidato ora? [Y/n]: ${RESET}")" ans < /dev/tty
    [[ "$ans" =~ ^[Nn]$ ]] && print_err "Installa Ollama manualmente: https://ollama.ai"
    do_install
  fi
fi

# Applica override modello da flag -m
[[ -n "$FLAG_MODEL_OVERRIDE" ]] && AI_MODEL="$FLAG_MODEL_OVERRIDE"

# Risolve modello ottimale se non configurato
case "$FLAG_MODE" in
  code) resolve_model "code" ;;
  *)    resolve_model "general" ;;
esac

# Esegui la modalità selezionata
case "$FLAG_MODE" in
  ask)       do_ask       "$AI_MODEL" "$FLAG_QUESTION" ;;
  code)      do_code      "$AI_MODEL" ;;
  explain)   do_explain   "$AI_MODEL" "$FLAG_TARGET" ;;
  summarize) do_summarize "$AI_MODEL" "$FLAG_TARGET" ;;
  translate) do_translate "$AI_MODEL" "$FLAG_TARGET" "${FLAG_LANG}" ;;
  "")        do_chat      "$AI_MODEL" ;;
esac
