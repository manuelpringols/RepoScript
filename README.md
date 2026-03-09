# RepoScript

Raccolta di script Bash per automatizzare operazioni comuni di sviluppo, setup del sistema e gestione Git.
Progettato per integrarsi con **[Marmitta](https://github.com/manuelpringols/marmitta)**, che centralizza credenziali, profili Git e configurazioni condivise.

---

## Struttura

```
RepoScript/
├── ai/           → Strumenti AI e automazione
├── backend/      → Script per applicazioni backend
├── fun/          → Script inutili ma divertenti
├── git/          → Gestione repository Git
├── network/      → Rete e connettività
├── pitonzi/      → Launcher script Python
├── setup/        → Installazione e configurazione ambiente
└── system/       → Utilità di sistema
```

---

## Requisiti comuni

- `bash` ≥ 5
- `git`, `curl`, `jq` — usati da più script
- `fzf` — richiesto da pitonzi, install_dev_tools
- `python3` — richiesto da pitonzi

Installabili tutti insieme con `install_dev_tools.sh`.

---

## Script implementati

### Git

#### `git/init/init_git_repo.sh`
Crea un repository su GitHub, configura la chiave SSH e inizializza il repo locale in un unico flusso interattivo.

**Funzionalità:**
- Selezione o creazione di profili Git (utente + token + chiave SSH)
- Creazione repo via GitHub API
- Aggiunta automatica della chiave SSH pubblica all'account
- `git init` + `git remote add origin` + primo commit con README
- Profili salvati in `~/.config/marmitta/git_profiles` (riutilizzabili)

**Uso:**
```bash
bash git/init/init_git_repo.sh
```

**Integrazione Marmitta:**
- Legge `~/.config/marmitta/config` per il token
- Legge/scrive `~/.config/marmitta/git_profiles` per i profili

---

#### `git/push/slither_push_repo.sh`
Commit e push rapido con preview delle modifiche e rilevamento automatico del branch.

**Funzionalità:**
- Preview colorata dei file modificati/aggiunti/eliminati
- Prompt messaggio di commit (o accetta argomento inline)
- Rileva automaticamente se il branch ha un upstream; usa `--set-upstream` se necessario
- Mostra i commit in coda prima del push
- Barra di caricamento animata a push completato

**Uso:**
```bash
# Interattivo
bash git/push/slither_push_repo.sh

# Con messaggio diretto
bash git/push/slither_push_repo.sh "fix: corretto bug nel login"
```

---

### Setup

#### `setup/install_dev_tools/install_dev_tools.sh`
Installa tool di sviluppo con selezione interattiva via `fzf`. Supporta più distribuzioni.

**Distribuzioni supportate:** Arch Linux, Debian/Ubuntu, Fedora, RHEL, openSUSE, macOS

**Tool disponibili (selezione):**
`neovim`, `docker`, `kubectl`, `postgresql`, `redis`, `nodejs`, `python`, `java`, `go`, `rust`, `fzf`, `bat`, `eza`, `tmux`, `wezterm`, `vscode`, e altri

**Funzionalità:**
- Multi-selezione con `TAB` in fzf
- Mostra lo stato di installazione per ogni tool
- Skip automatico dei tool già installati
- Comandi post-install (es. `systemctl enable docker`)
- Aggiornamento indice pacchetti con cache Marmitta (skip se < 6 ore)
- Su Arch: installa automaticamente `yay` se mancante

**Uso:**
```bash
bash setup/install_dev_tools/install_dev_tools.sh
```

---

#### `setup/zshrc/setup_zshrc.sh`
Installa e configura `zsh` + Oh My Zsh con plugin e `.zshrc` personalizzato.

**Funzionalità:**
- Installazione `zsh` (multi-distro)
- Installazione Oh My Zsh
- Plugin: `zsh-syntax-highlighting`, `zsh-autosuggestions`
- Template `.zshrc` embedded (`spinal`) con prompt personalizzato, alias utili, history condivisa
- Backup automatico del `.zshrc` esistente prima di sovrascrivere
- Opzione per ASCII art di Spongebob all'avvio

**Uso:**
```bash
bash setup/zshrc/setup_zshrc.sh
```

**Template generato in:** `~/.config/marmitta/templates/spinal`

---

### Pitonzi

#### `pitonzi/run_pitonzi.sh`
Launcher interattivo per script Python remoti su GitHub. Scarica, installa le dipendenze in RAM e li esegue senza inquinare il sistema.

**Funzionalità:**
- Navigazione a 3 livelli (categoria → sottocartella → script) via `fzf`
- Risoluzione automatica delle dipendenze Python (analisi AST delle import)
- Installazione dipendenze in `/dev/shm` (RAM) con `pip --target` — nessun venv permanente
- Cache descrizioni script (24h) in `~/.config/marmitta/cache/pitonzi/`
- Salvataggio opzionale script + venv persistente su disco (`s`)
- Pulizia automatica della dir RAM all'uscita

**Uso:**
```bash
# Avvio normale
bash pitonzi/run_pitonzi.sh

# Riesegui l'ultimo script
bash pitonzi/run_pitonzi.sh --last

# Aggiungi un repo Python alle sources
bash pitonzi/run_pitonzi.sh --add-repo

# Rigenera cache descrizioni
bash pitonzi/run_pitonzi.sh --gen-desc
```

**Integrazione Marmitta:**
- `~/.config/marmitta/config` → `GITHUB_TOKEN` per le API GitHub
- `~/.config/marmitta/sources` → lista repo Python (formato: `label|user/repo|branch`)
- `~/.config/marmitta/cache/pitonzi/` → cache descrizioni

**Formato `sources`:**
```
# label      | repo                    | branch
pitonzi      | manuelpringols/pitonzi  | master
miei-script  | tuousername/py-scripts  | main
```

---

### Network

#### `network/ssh_manager/ssh_manager.sh`
Gestore completo di connessioni SSH con profili salvati in Marmitta. Sostituisce la gestione manuale di host, porte e chiavi.

**Modalità disponibili:**

| Flag | Azione |
|------|--------|
| *(nessun flag)* | Connetti a un host (selezione fzf) |
| `-l, --list` | Elenca tutti i profili con stato online in tempo reale |
| `-a, --add` | Aggiungi nuovo profilo interattivamente |
| `-r, --remove` | Rimuovi profilo |
| `-s, --send` | Invia file o cartella via SCP |
| `-k, --copy-key` | Copia chiave SSH pubblica sul host (con fallback manuale) |
| `-t, --tunnel` | Tunnel SSH — port forwarding locale, foreground o background |
| `-p, --ping` | Verifica raggiungibilità di tutti i profili con latenza |
| `-e, --edit` | Apre il file profili in `$EDITOR` |

**Uso:**
```bash
# Connetti a un host salvato
bash network/ssh_manager/ssh_manager.sh

# Aggiungi il tuo server di casa
bash network/ssh_manager/ssh_manager.sh --add

# Esponi la porta 5432 del DB remoto in locale
bash network/ssh_manager/ssh_manager.sh --tunnel
# → porta locale: 5432  |  endpoint remoto: localhost:5432

# Invia un dump del DB
bash network/ssh_manager/ssh_manager.sh --send

# Controlla quali host sono online
bash network/ssh_manager/ssh_manager.sh --ping
```

**Integrazione Marmitta:**
- Profili salvati in `~/.config/marmitta/ssh_profiles` (permessi 600)
- Legge `~/.config/marmitta/config` per variabili custom
- Formato profili: `label|user|host|port|ssh_key_path|descrizione`

---

## Script in sviluppo (placeholder)

| Script | Descrizione |
|--------|-------------|
| `network/wake_on_lan/accendi_pc.sh` | Accende il PC principale via Wake-on-LAN |
| `network/wake_on_lan/spegni_pc.sh` | Spegne il PC principale via SSH |
| `network/scp/scp_send.sh` | Invia file a un server remoto via SCP *(coperto da `ssh_manager --send`)* |
| `system/report/system_report.sh` | Report completo del sistema |
| `system/report/check_fs.sh` | Controllo stato filesystem |
| `system/report/check_security_problems.sh` | Verifica vulnerabilità note |
| `system/report/high_consumption_processes.sh` | Processi ad alto consumo |
| `system/service/shutdown_service.sh` | Arresto sicuro di un servizio |
| `ai/ask_ai/ask_ai.sh` | Chat AI da terminale con Ollama + llama3.2 |
| `setup/arch/arch_install.sh` | Installazione automatizzata Arch Linux |
| `setup/hyprland/setup_hyprland.sh` | Configurazione Hyprland |
| `setup/lazyvim/lazyvim_installer.sh` | NeoVim + LazyVim setup |
| `setup/wezterm/setup_wezterm.sh` | Installazione e configurazione WezTerm |
| `backend/spring_boot/update_keystore.sh` | Aggiornamento keystore Spring Boot |
| `fun/spongebob/spongebob_ascii.sh` | ASCII art animata di Spongebob |

---

## Integrazione Marmitta

[Marmitta](https://github.com/manuelpringols/marmitta) è il sistema di configurazione centrale per questi script.
Non è obbligatorio — gli script funzionano in standalone con input interattivo — ma con Marmitta attivo le credenziali e i profili vengono caricati automaticamente.

**File usati da RepoScript:**

| File | Usato da | Contenuto |
|------|----------|-----------|
| `~/.config/marmitta/config` | pitonzi, init_git_repo | Variabili shell (es. `GITHUB_TOKEN`, `MARMITTA_REPO_URL`) |
| `~/.config/marmitta/sources` | pitonzi | Lista repo Python (`label\|user/repo\|branch`) |
| `~/.config/marmitta/git_profiles` | init_git_repo | Profili Git (`label\|user\|token\|ssh_key`) |
| `~/.config/marmitta/cache/pitonzi/` | pitonzi | Cache descrizioni script (TTL 24h) |
| `~/.config/marmitta/cache/pkg_update_last` | install_dev_tools | Timestamp ultimo aggiornamento indice pacchetti |
| `~/.config/marmitta/templates/spinal` | setup_zshrc | Template `.zshrc` generato |

---

## Licenza

Uso personale — nessuna licenza formale.
