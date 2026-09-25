---
name: big-implement
description: "Porta avanti in una sola esecuzione tutte le issue figlie di una issue madre di /issue-flow:big-plan — GitLab o GitHub: una figlia alla volta, nell'ordine della madre, ognuna con il giro di /issue-flow:implement (una fase per subagent, checkbox spuntate, un commit per fase) e la sua merge request — pull request su GitHub — aperta e mai unita. Le figlie non aspettano il merge delle sorelle: i branch si impilano. Trigger: /issue-flow:big-implement, «implementa tutto il progetto N», «porta avanti tutta la roadmap N», «esegui tutte le figlie di N»."
argument-hint: "<madre>"
hooks:
  Stop:
    - hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/goal-stop.sh"
---

# /issue-flow:big-implement

`/issue-flow:implement <madre>` esegue **una** figlia e si ferma: la successiva parte solo
dopo il merge della precedente. Questa skill porta avanti **tutto il progetto** in una volta:
prende le figlie ancora da fare nell'ordine della madre e le esegue **una alla volta**, ognuna
con il suo branch, i suoi commit e la sua MR/PR. Siccome nessuno unisce niente a metà corsa, i
branch si **impilano**: ogni figlia nasce dal branch della precedente, e la sua MR/PR punta lì.

Le regole di esecuzione sono quelle di `implement` e `close` e non si ripetono qui:
`${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md` per le fasi, la verifica, le spunte, i commit
e la modalità goal; `${CLAUDE_PLUGIN_ROOT}/skills/close/SKILL.md` per la verifica finale, la
documentazione e l'apertura della MR/PR; `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` per i comandi delle
due piattaforme. **Leggili tutti e tre prima del primo comando.** Qui sotto c'è solo quello che
cambia.

## Usage

```
/issue-flow:big-implement <madre>   # esegue in sequenza tutte le figlie non ancora unite
```

## Tu sei l'orchestratore, di tutto il progetto

Come in `implement`, non implementi le fasi: le assegni a un subagent `issue-flow:issue-phase`
per fase, ne verifichi l'esito, spunti e committi. In più tieni la visione del progetto: quale
figlia è in corso, su quale branch, nata da quale base, con quale MR/PR.

Il ciclo sta tutto qui, e non in un subagent per figlia, per lo stesso motivo strutturale di
`implement`: un subagent non può lanciarne altri, quindi un subagent «che fa implement» non
potrebbe delegare le fasi e finirebbe a fare tutto il lavoro della figlia nel suo contesto.

**Mai due figlie insieme.** Né in parallelo né intrecciate: la figlia N+1 parte dal codice che
la N ha lasciato, e si comincia solo quando la N ha la sua MR/PR aperta.

## 0. Quale tracker, e risponde

Identico al passo 0 di `implement`.

## 1. Leggi la madre e ricava la catena

Leggi la madre dal server come al passo 1 di `implement`. Se in testa al corpo non c'è
`**Tipo:** roadmap`, non è una madre: dillo e proponi `/issue-flow:implement <numero>`.

Dalla sezione **Issue**, nell'ordine, prendi le righe `- [ ] #<n>`: sono le figlie da portare
avanti. Quelle `- [x]` sono già unite e non si toccano. Per ogni figlia da fare guarda sul
tracker:

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
  fase non spuntata, o dalla sola MR/PR se le fasi sono tutte fatte, o da niente se la MR/PR
  c'è già.

Poi presenta all'utente la catena e parti senza chiedere conferma:

```
#21  issue-21  nasce da main       MR/PR → main
#22  issue-22  nasce da issue-21   MR/PR → issue-21
#23  issue-23  nasce da issue-22   MR/PR → issue-22
```

Se non c'è nessuna figlia da fare, il progetto è finito o in attesa di merge: dillo, e indica
le MR/PR ancora aperte da unire in ordine.

## 2. Il goal copre tutto il progetto

La modalità goal è quella di `implement`, con una differenza: `$GOAL_DIR/goal` contiene **tutte**
le figlie da portare avanti, un numero per riga. L'hook `Stop` rilegge ognuna dal tracker e non
lascia chiudere il turno finché una qualsiasi ha una `- [ ]` nel Piano.

```bash
GOAL_DIR=$(git rev-parse --path-format=absolute --git-path issue-flow)
mkdir -p "$GOAL_DIR" && printf '%s\n' 21 22 23 > "$GOAL_DIR/goal" && rm -f "$GOAL_DIR/in-volo"
```

Lo scrivi dopo aver controllato che la working tree sia pulita (passo 2 di `implement`), prima
della prima fase. `in-volo` funziona come in `implement`: un solo subagent alla volta.

L'hook guarda le checkbox, non le MR/PR: quando l'ultima fase dell'ultima figlia è spuntata ti
lascia fermare anche se la sua MR/PR non è ancora aperta. Non fermarti lì: la consegna arriva
dopo l'ultima MR/PR.

Per fermarti prima della fine **cancelli tu `$GOAL_DIR/goal`** e dici all'utente perché.

## 3. Il giro, una figlia alla volta

Per ogni figlia della catena, in ordine, quattro passi.

### 3.1 Il branch, impilato

La base della figlia è:

- il **branch di destinazione** aggiornato (`git switch <base> && git pull --ff-only`) se tutte
  le sue dipendenze sono già unite — di norma solo la prima della catena;
- il **branch della figlia precedente** della catena altrimenti.

```bash
git status --porcelain                 # deve essere vuoto
git switch <branch> 2>/dev/null || { git switch <base-impilata> && git switch -c <branch>; }
```

Questa è l'unica regola di `implement` che big-implement cambia: al passo 2 `implement` vuole
che una figlia nasca **sempre** dal branch di destinazione, perché lì stanno le sorelle unite;
qui le sorelle non sono unite ma sono nel branch da cui nasci, ed è lo stesso codice.

Di conseguenza il controllo del passo **1 ter** di `implement` si fa contro la base impilata:
le dipendenze sono unite **oppure** il loro lavoro è nel branch da cui nasci
(`git log --oneline <base-impilata> | grep '#<k>'`), e i punti d'aggancio «nasce con #<k>»
esistono lì. Se non reggono, ti fermi come dice `implement`.

### 3.2 Le fasi

Il passo 3 di `implement` senza varianti: un subagent `issue-flow:issue-phase` **nuovo** per
ogni fase con il contesto integrale della figlia, verifica eseguita da te, spunta sulla issue
rileggendola dal server, un commit per fase con `(#<figlia>)` nel messaggio. A fine fasi, la
riga **Stato:** della figlia come al passo 4 di `implement`.

Quando passi il contesto al subagent, aggiungi che la figlia è impilata: cosa hanno lasciato
le sorelle precedenti di questa esecuzione, se hanno deviato dalla loro issue — il writer della
figlia le conosceva solo come piano.

### 3.3 La MR/PR, impilata

I passi 1, 2 e 3 di `close`, con una sola differenza: il **target** della MR/PR è la base
impilata del passo 3.1, non il branch di destinazione.

```bash
git push -u origin <branch>
glab mr create ... --target-branch <base-impilata> ...   # GitLab
gh   pr create ... --base          <base-impilata> ...   # GitHub
```

Il corpo è quello di `close`, con `Closes #<figlia>` in testa e, per una MR/PR impilata, una
riga subito sotto:

```markdown
Impilata su !<MR della figlia precedente> — da unire dopo quella.   # GitLab
Impilata su #<PR della figlia precedente> — da unire dopo quella.   # GitHub
```

La riga **Stato:** della figlia va a `in revisione — !<n>` / `#<n>` come in `close`.

**Mai il merge**, come in `close`: nemmeno della prima MR/PR, nemmeno con le pipeline verdi.

### 3.4 La madre

Rileggi la madre dal server e porta la sua riga **Stato:** a
`in corso — k di M implementate, j unite`. **Non spuntare** la casella della figlia: si spunta
quando la figlia è unita, con `/issue-flow:close <figlia> --chiudi`, perché lo stato della madre
è quello che sta davvero nel branch di destinazione.

Poi passa alla figlia successiva.

## 4. Consegna

Poche righe e una tabella, nell'ordine in cui le MR/PR vanno unite:

```
figlia  branch    MR/PR  target     fasi
#21     issue-21  !40    main       6/6
#22     issue-22  !41    issue-21   7/7
#23     issue-23  !42    issue-22   5/5
```

Poi le checkbox rimaste vuote con il motivo, le deviazioni scritte nelle roadmap, i problemi
che i subagent hanno visto fuori dal loro perimetro. E come si prosegue:

- le MR/PR **si uniscono in ordine**, dalla prima;
- dopo ogni merge, `/issue-flow:close <figlia> --chiudi`: chiude la figlia, la spunta sulla madre
  e porta la MR/PR successiva a puntare sul branch di destinazione, se il server non l'ha già
  fatto;
- su GitHub il `Closes #<figlia>` di una PR impilata agisce solo quando la PR punta al branch di
  default, cioè dopo quel ritarget: fino ad allora la issue resta aperta, ed è normale.

Non incollare le issue né il diff.

## Quando fermarsi davvero

Tutti i casi di «Quando fermarsi davvero» di `implement` e di `close`, più uno: **se una figlia
si ferma, il progetto si ferma con lei.** La successiva nascerebbe dal suo branch incompleto,
quindi non si salta avanti. Nella consegna di' quale figlia si è fermata, a che fase, perché, e
che si riprende con `/issue-flow:big-implement <madre>` una volta sistemata — il passo 1 ritrova
le figlie già fatte e riparte da lì.

Prima di fermarti, `rm -f "$GOAL_DIR/goal"`: altrimenti l'hook ti rimanda al lavoro.
