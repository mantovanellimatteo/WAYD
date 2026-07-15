# WAYD (What Are You Doing) - macOS

WAYD è un'applicazione nativa per macOS che vive nella barra dei menu e ti aiuta a monitorare la tua produttività chiedendoti periodicamente *"Cosa stai facendo?"*.

L'applicazione salva tutto lo storico delle tue risposte in un semplice file CSV locale in modo compatibile con gli standard di analisi dei dati.

---

## 📸 Schermate

<p align="center">
  <img src="Screenshot/Screenshot%202026-07-15%20alle%2022.19.24.png" width="400" alt="Menu Barra di Stato"/>
  <img src="Screenshot/Screenshot%202026-07-15%20alle%2022.21.23.png" width="400" alt="Visualizzatore Log con Filtri"/>
</p>
<p align="center">
  <img src="Screenshot/Screenshot%202026-07-15%20alle%2022.19.54.png" width="300" alt="Informazioni App"/>
</p>

---

## 🌟 Funzionalità

* **Icona e Info nella Barra dei Menu**: Mostra l'icona di un orologio e l'ultimo log inserito direttamente nella barra in alto.
* **Prompt di Inserimento Nativo**: Una finestra popup SwiftUI pulita ed elegante che appare in primo piano per chiederti cosa stai facendo.
* **Registro Log Completo**:
  * Visualizzazione di tutta la cronologia.
  * **Ricerca libera** (filtro testuale case-insensitive).
  * **Filtro per data** preciso.
  * Possibilità di **modificare** o **eliminare** qualsiasi attività passata direttamente dall'interfaccia.
* **Configurazione e Timer**:
  * Possibilità di attivare/disattivare il prompt in qualsiasi momento dal menu.
  * Regolazione della frequenza del prompt (15 minuti, 30 minuti, 1 ora, 2 ore).

---

## 📂 Struttura del Log

Tutti i dati vengono salvati localmente nella tua cartella utente principale:
* Il registro completo: `~/WAYD_log.csv` (formato: `Data,Ora,"Attività"`)
* L'ultima attività inserita (usata anche per widget esterni o script): `~/.last_entry.txt`

---

## 🛠️ Come Compilare e Avviare

### 1. Prerequisito (Xcode Command Line Tools)
Per compilare l'app, il tuo Mac deve disporre del compilatore Swift (`swiftc`). Se non lo hai ancora installato, apri il **Terminale** ed esegui il seguente comando:

```bash
xcode-select --install
```
Clicca su **Installa** e accetta i termini di servizio.

### 2. Compilazione
Clona o scarica questa cartella, entra nella directory del progetto nel Terminale ed esegui lo script di build:

```bash
./build.sh
```

Questo genererà un'applicazione macOS nativa chiamata `WAYD.app` direttamente nella cartella del progetto.

### 3. Avvio
Puoi avviare l'applicazione semplicemente facendo doppio clic su `WAYD.app` nel Finder, oppure da terminale eseguendo:

```bash
open WAYD.app
```

---

## 📈 Autostart all'avvio del Mac (Opzionale)

Se desideri che l'app si avvii automaticamente ogni volta che accendi il Mac:
1. Apri **Impostazioni di Sistema**.
2. Vai su **Generali > Elementi login**.
3. Sotto la sezione **Apri al login**, clicca sul pulsante `+`.
4. Seleziona la tua app `WAYD.app` appena generata.
