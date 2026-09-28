---
name: big-implement
description: "Porta avanti in una sola esecuzione tutte le issue figlie di una issue madre di /issue-flow:big-plan — GitLab o GitHub — sul branch della madre: una figlia alla volta, nell'ordine della madre, ognuna con il giro di /issue-flow:implement (una fase per subagent, checkbox spuntate, un commit per fase) e quello di /issue-flow:close, che verifica, apre la merge request — pull request su GitHub — verso il branch della madre e la unisce da solo. Alla fine apre la MR/PR della madre verso il branch di destinazione, che unisce solo l'utente. Trigger: /issue-flow:big-implement, «implementa tutto il progetto N», «porta avanti tutta la roadmap N», «esegui tutte le figlie di N»."
argument-hint: "<madre>"
hooks:
  Stop:
    - hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/goal-stop.sh"
---

# /issue-flow:big-implement

`/issue-flow:implement <madre>` esegue **una** figlia e si ferma: la successiva parte solo
dopo il merge della precedente, che fa l'utente. Questa skill porta avanti **tutto il
progetto** in una volta, senza aspettare nessuno fino alla fine:

```
main ──────────────────────────────────────────────── ◀── MR/PR issue-20 (la unisce l'utente)
  └─ issue-20 ──●──────────●──────────●─────────
                ▲          ▲          ▲
            issue-21   issue-22   issue-23     (ognuna nasce da issue-20 e ci torna da sola)
```

- la madre ha il suo branch, `${user_config.branch_prefix}<madre>`, nato dal branch di
  destinazione;
- ogni figlia nasce dal branch della madre aggiornato, si implementa, e poi passa per `close`:
  verifica sull'albero finale, documentazione, MR/PR **verso il branch della madre** — che qui
  `close` **unisce da solo**, perché il branch della madre non è il prodotto: è il cantiere del
  progetto, e la revisione vera arriva alla fine;
- quando l'ultima figlia è unita, la MR/PR della madre verso il branch di destinazione si apre
  come sempre e **non si unisce**: quella l'approva e la unisce l'utente.

Le regole di esecuzione sono quelle di `implement` e `close` e non si ripetono qui:
`${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md` per le fasi, la verifica, le spunte, i commit
e la modalità goal; `${CLAUDE_PLUGIN_ROOT}/skills/close/SKILL.md` per la verifica finale, la
documentazione, la MR/PR, il merge nel branch della madre e la chiusura;
`${CLAUDE_PLUGIN_ROOT}/TRACKER.md` per i comandi delle due piattaforme. **Leggili tutti e tre
prima del primo comando.** Qui sotto c'è solo quello che cambia.

## Usage

```
/issue-flow:big-implement <madre>   # esegue in sequenza tutte le figlie non ancora unite
```

## Tu sei l'orchestratore, di tutto il progetto

Come in `implement`, non implementi le fasi: le assegni a un subagent `issue-flow:issue-phase`
per fase, ne verifichi l'esito, spunti e committi. In più tieni la visione del progetto: quale
figlia è in corso, con quale MR/PR, e quante sono già nel branch della madre.

Il ciclo sta tutto qui, e non in un subagent per figlia, per lo stesso motivo strutturale di
`implement`: un subagent non può lanciarne altri, quindi un subagent «che fa implement» non
potrebbe delegare le fasi e finirebbe a fare tutto il lavoro della figlia nel suo contesto.

**Mai due figlie insieme.** Né in parallelo né intrecciate: la figlia N+1 nasce dal branch della
madre **dopo** che la N ci è stata unita, e parte dal codice che la N ha lasciato.

## 0. Quale tracker, e risponde

Identico al passo 0 di `implement`.

## 1. Leggi la madre e ricava la catena

Leggi la madre dal server come al passo 1 di `implement`. Se in testa al corpo non c'è
`**Tipo:** roadmap`, non è una madre: dillo e proponi `/issue-flow:implement <numero>`.

Dalla sezione **Issue**, nell'ordine, prendi le righe `- [ ] #<n>`: sono le figlie da portare
avanti. Quelle `- [x]` sono già unite — nel branch della madre o, da un giro fatto a mano, nel
branch di destinazione — e non si toccano. Per ogni figlia da fare guarda sul tracker:

- **lo stato**: se è già chiusa ma la casella è vuota, la madre è rimasta indietro —
  segnalalo, non rieseguirla, e trattala come unita;
- **le dipendenze** — `· dipende da #<k>` nella madre, `**Dipende da:**` nella figlia: ognuna
  deve essere unita (casella spuntata o issue chiusa) **oppure** una figlia che questa
  esecuzione porta avanti **prima** di lei. Una dipendenza fuori da entrambi i casi — una issue
  esterna aperta, una sorella che viene dopo nell'ordine — è una roadmap che non regge:
  fermati e dillo;
- **se è già iniziata** da un giro precedente: il branch `${user_config.branch_prefix}<n>`
  esiste, ha checkbox spuntate, ha già una MR/PR (`glab mr list --source-branch <branch>`,
  `gh pr list --head <branch>`). Riprendi da dove è rimasta invece di ripartire: dalla prima
  fase non spuntata, dalla MR/PR se le fasi sono tutte fatte, dal merge se la MR/PR è aperta.

Guarda anche la **madre**: se ha già una MR/PR aperta verso il branch di destinazione
(`glab mr list --source-branch <branch-madre>`, `gh pr list --head <branch-madre>`), il
progetto è già consegnato — dillo e non ripartire.

Poi presenta all'utente la catena e parti senza chiedere conferma:

```
issue-20  branch della madre, nasce da main
#21  issue-21  nasce da issue-20   MR/PR → issue-20, unita da close
#22  issue-22  nasce da issue-20   MR/PR → issue-20, unita da close
#23  issue-23  nasce da issue-20   MR/PR → issue-20, unita da close
issue-20  MR/PR → main, la unisce l'utente
```

Se non c'è nessuna figlia da fare ma la madre non ha ancora la sua MR/PR, salta al passo 5.

## 2. Il branch della madre

Il branch della madre è `${user_config.branch_prefix}<madre>` — con il default `issue-`, la
madre #20 ha `issue-20`. Nasce dal branch di destinazione aggiornato, e va **subito sul
remote**: le MR/PR delle figlie ci puntano, e `close` riconosce il flusso di big-implement
proprio dalla sua esistenza su `origin`.

```bash
git status --porcelain                 # deve essere vuoto
git fetch origin
git switch <branch-madre> 2>/dev/null \
  || git switch -c <branch-madre> --track origin/<branch-madre> 2>/dev/null \
  || { git switch <destinazione> && git pull --ff-only && git switch -c <branch-madre>; }
git push -u origin <branch-madre>
```

Se il branch esisteva già da un giro precedente, allinealo a `origin` con `git pull --ff-only`.
Se il branch di destinazione è andato avanti nel frattempo, **non** lo rincorri: il branch della
madre si riallinea una volta sola, al passo 5 — in `close` sulla madre —, dove un conflitto è
una decisione dell'utente.

Porta la riga **Stato:** della madre a `in corso — k di M issue unite in <branch-madre>`.

## 3. Il goal copre tutto il progetto

La modalità goal è quella di `implement`, con una differenza: `$GOAL_DIR/goal` contiene **tutte**
le figlie da portare avanti e **la madre**, un numero per riga. L'hook `Stop` rilegge ognuna dal
tracker e non lascia chiudere il turno finché una qualsiasi ha una `- [ ]`: nel Piano per le
figlie, nella sezione **Issue** per la madre — che si spunta solo quando una figlia è unita nel
suo branch. Così il goal regge fino all'ultimo merge, non solo fino all'ultima fase.

```bash
GOAL_DIR=$(git rev-parse --path-format=absolute --git-path issue-flow)
mkdir -p "$GOAL_DIR" && printf '%s\n' 21 22 23 20 > "$GOAL_DIR/goal" && rm -f "$GOAL_DIR/in-volo"
```

Lo scrivi dopo il passo 2, prima della prima fase. `in-volo` funziona come in `implement`: un
solo subagent alla volta.

Quando l'ultima figlia è unita l'hook ti lascia fermare anche se la MR/PR della madre non è
ancora aperta. Non fermarti lì: la consegna arriva dopo il passo 5.

Per fermarti prima della fine **cancelli tu `$GOAL_DIR/goal`** e dici all'utente perché.

## 4. Il giro, una figlia alla volta

Per ogni figlia della catena, in ordine, tre passi.

### 4.1 Il branch, dalla madre

La base di ogni figlia è il branch della madre aggiornato, **dopo** il merge della sorella
precedente:

```bash
git status --porcelain                 # deve essere vuoto
git switch <branch> 2>/dev/null \
  || { git switch <branch-madre> && git pull --ff-only && git switch -c <branch>; }
```

È la regola del passo 2 di `implement` con il branch della madre al posto di quello di
destinazione: è lì che stanno le sorelle già unite. Il controllo del passo **1 ter** di
`implement` si fa contro il branch della madre: le dipendenze sono chiuse e il loro lavoro è lì
(`git log --oneline <branch-madre> | grep '#<k>'`), e i punti d'aggancio «nasce con #<k>»
esistono lì. Se non reggono, ti fermi come dice `implement`.

### 4.2 Le fasi

Il passo 3 di `implement` senza varianti: un subagent `issue-flow:issue-phase` **nuovo** per
ogni fase con il contesto integrale della figlia, verifica eseguita da te, spunta sulla issue
rileggendola dal server, un commit per fase con `(#<figlia>)` nel messaggio. A fine fasi, la
riga **Stato:** della figlia come al passo 4 di `implement`.

Quando passi il contesto al subagent, aggiungi cosa hanno lasciato le sorelle già unite in
questa esecuzione, se hanno deviato dalla loro issue — il writer della figlia le conosceva solo
come piano.

### 4.3 Close, fino al merge nel branch della madre

Tutto `close` sulla figlia, nel suo ramo «figlia con il branch della madre»: i controlli del
passo 1, la documentazione del passo 2, la MR/PR del passo 3 **verso il branch della madre**,
poi il merge e la chiusura del passo 3 bis, che non aspettano l'utente. Alla fine:

- la MR/PR della figlia è unita nel branch della madre, e il branch della figlia è cancellato;
- la figlia è chiusa, con **Stato:** `chiusa — unita in <branch-madre> il GG/MM/AAAA`;
- la sua casella sulla madre è spuntata, e lo **Stato:** della madre dice `k di M`;
- sei sul branch della madre, aggiornato: la figlia successiva nasce da qui.

Se `close` si ferma — una casella vuota, una verifica rossa, una pipeline fallita, una MR/PR che
il server non unisce — ti fermi anche tu: vedi «Quando fermarsi davvero».

Poi passa alla figlia successiva.

## 5. La MR/PR della madre

Quando tutte le caselle della sezione **Issue** della madre sono spuntate, `close` sulla madre,
nel suo ramo «madre»: rifà la verifica sull'albero finale del branch della madre, allinea la
documentazione, pusha e apre la MR/PR `branch della madre → branch di destinazione` con
`Closes #<madre>`. **Mai il merge**: questa l'approva e la unisce l'utente, come ogni MR/PR
verso il branch di destinazione.

## 6. Consegna

Il link della MR/PR della madre, in cima: è l'unica cosa che l'utente deve fare. Poi una
tabella, nell'ordine in cui le figlie sono entrate nel branch della madre:

```
figlia  MR/PR  fasi  unita in
#21     !40    6/6   issue-20
#22     !41    7/7   issue-20
#23     !42    5/5   issue-20
```

Poi le checkbox rimaste vuote con il motivo, le deviazioni scritte nelle roadmap, i problemi
che i subagent hanno visto fuori dal loro perimetro. E come si prosegue: a merge avvenuto della
MR/PR della madre, `/issue-flow:close <madre> --chiudi`, che chiude la madre e cancella il suo
branch.

Non incollare le issue né il diff.

## Quando fermarsi davvero

Tutti i casi di «Quando fermarsi davvero» di `implement` e di `close`, più uno: **se una figlia
si ferma, il progetto si ferma con lei.** La successiva nascerebbe da un branch della madre
senza il suo lavoro, quindi non si salta avanti. Nella consegna di' quale figlia si è fermata,
a che punto — fase, MR/PR, merge — perché, e che si riprende con
`/issue-flow:big-implement <madre>` una volta sistemata: il passo 1 ritrova le figlie già unite e
riparte da lì.

Prima di fermarti, `rm -f "$GOAL_DIR/goal"`: altrimenti l'hook ti rimanda al lavoro.
