---
name: implement
description: "Prende una issue dal tracker del repo — GitLab o GitHub — e ne implementa la roadmap: una fase per subagent, le checkbox spuntate sulla issue mano a mano che il lavoro si chiude, un commit per fase. Si ferma al commit dell'ultima fase: la merge request la apre /issue-flow:close. Con il numero di una issue madre di /issue-flow:big-plan esegue la prima figlia non ancora unita. Trigger: /issue-flow:implement, «implementa la issue N», «porta a termine la issue N», «lavora la issue N»."
argument-hint: "<numero> [--da N]"
hooks:
  Stop:
    - hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/goal-stop.sh"
---

# /issue-flow:implement

`/issue-flow:plan` scrive l'istruzione di lavoro, questa la esegue. Tutto quello che serve sta
nella issue: piano, contesto, roadmap. Non si aggiunge lavoro che la issue non prevede e non
si salta lavoro che prevede.

## Usage

```
/issue-flow:implement <numero>         # esegue la issue dalla prima fase non spuntata
/issue-flow:implement <madre>          # issue madre di big-plan: esegue la prima figlia aperta
/issue-flow:implement <numero> --da 3  # riparte dalla fase 3, ignorando le checkbox
/issue-flow:implement                  # deduce il numero dal branch corrente
```

## Tu sei l'agente di Issue e resti tale

Non implementi le fasi: le assegni agli agenti checkbox — un subagent `issue-flow:issue-phase`
per fase —, ne verifichi l'esito, spunti le caselle e committi. Quando la issue dichiara fasi in
parallelo le assegni insieme, ognuna nel suo worktree di git, e sei tu a concordare il loro
lavoro prima di assegnarlo e a integrarlo dopo (`${CLAUDE_PLUGIN_ROOT}/PARALLEL.md`).

Il motivo è il contesto. Ogni fase parte da un subagent pulito che legge solo i file che le
servono, mentre tu tieni la visione dell'insieme — a che punto è la roadmap, cosa ha deciso
la fase precedente, cosa manca — senza riempirti dei dettagli di ogni singolo file.

Con `/issue-flow:big-implement` questo stesso ciclo scende di un livello: lo esegue per ogni
figlia un subagent `issue-flow:issue-runner`, che legge questa skill come riferimento e lascia
il goal alla sessione principale.

## Lavori in modalità goal

Questa skill si comporta come un `/goal` con la condizione già scritta: **non si ferma finché
la roadmap non è completa**. Lo fa un hook `Stop` del plugin (`scripts/goal-stop.sh`) che a
ogni fine turno rilegge la issue dal tracker: finché nel Piano c'è una `- [ ]`, o l'ultima
fase non è committata, ti rimanda al lavoro dicendoti da quale fase ripartire.

L'hook legge lo stato da una cartella dentro `.git`, che non finisce mai in un commit:

```bash
GOAL_DIR=$(git rev-parse --path-format=absolute --git-path issue-flow)
```

- `$GOAL_DIR/goal` — il numero della issue in lavorazione. Lo scrivi al passo 2; a roadmap
  completa lo cancella l'hook. Finché c'è, il turno non si chiude.
- `$GOAL_DIR/in-volo/` — la cartella degli agenti checkbox al lavoro, un segnaposto per
  ognuno (`PARALLEL.md` §5). Crei il segnaposto subito prima di delegare e lo cancelli appena
  quell'agente torna: finché la cartella non è vuota puoi chiudere il turno, perché ti risveglia
  la notifica del prossimo che torna.

Per fermarti prima della fine — i casi di «Quando fermarsi davvero», o una checkbox che resta
vuota — **cancelli tu `$GOAL_DIR/goal`** e dici all'utente perché. È voluto: lo stop è una
decisione esplicita, non un turno che finisce per caso a metà roadmap. Se ti fermi prima del
passo 2, il file non esiste ancora e non c'è niente da cancellare.

## 0. Quale tracker, e risponde

Il tracker è GitLab (`glab`) o GitHub (`gh`) secondo il remote: `git remote get-url origin`.
La corrispondenza completa dei comandi sta in `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` — il file
`TRACKER.md` nella cartella di questo plugin — da leggere prima del primo comando, perché il
campo del corpo cambia nome fra le due piattaforme e sbagliarlo svuota la issue. Se la issue ha
fasi in parallelo, leggi anche `${CLAUDE_PLUGIN_ROOT}/PARALLEL.md`.

```bash
glab auth status && glab issue view <numero>          # GitLab
gh   auth status && gh   issue view <numero>          # GitHub
```

Deve mostrare la issue, non un 404. Se dà 404 o «could not determine base repo» il remote è
un alias SSH e il rimedio è in `TRACKER.md` §2. Se non sei autenticato, fermati e chiedi
all'utente `glab auth login --hostname gitlab.com` o `gh auth login --hostname github.com`:
è interattivo, non puoi farlo tu.

## 1. Leggi la issue, per intero, dal server

```bash
# GitLab
glab issue view <numero> --output json > "$SCRATCH/issue.json"
jq -r '.title'       "$SCRATCH/issue.json"
jq -r '.description' "$SCRATCH/issue.json" > "$SCRATCH/roadmap.md"

# GitHub
gh issue view <numero> --json title,body > "$SCRATCH/issue.json"
jq -r '.title' "$SCRATCH/issue.json"
jq -r '.body'  "$SCRATCH/issue.json" | sed 's/\r$//' > "$SCRATCH/roadmap.md"
```

Controlla che `roadmap.md` non sia vuoto prima di andare avanti: se lo è, hai pescato il
campo dell'altra piattaforma.

Se in testa al corpo c'è `**Tipo:** roadmap`, è la madre di un `/issue-flow:big-plan` e non
si implementa: vai al passo 1 bis. Se c'è `**Roadmap:** #<madre>`, è una figlia: vale tutto
quello che segue, più il passo 1 ter prima del branch.

Leggila tutta, non solo il Piano: **Obiettivo**, **Contesto** e **Fuori perimetro** sono ciò
che impedisce ai subagent di reinventare le decisioni già prese, e vanno passati loro.

Poi ricava, e dillo all'utente prima di partire:

- il branch di lavoro, `${user_config.branch_prefix}<numero>` — con il default `issue-`, la
  issue #12 si lavora su `issue-12`;
- l'elenco delle fasi (`###` dentro `## Piano`) con quante checkbox hanno e quante sono già
  spuntate, e da quale fase riparti;
- l'ordine di esecuzione dalla riga **Esecuzione** in testa al Piano, con i gruppi paralleli —
  `1 → 2 → [3 ∥ 4] → 5 → 6`. Una issue scritta prima che la riga esistesse non ce l'ha: è tutta
  in sequenza;
- se la issue non ha fasi con checkbox, **fermati**: non è una issue eseguibile. Riportalo e
  proponi `/issue-flow:plan rivedi <numero>`.

## 1 bis. La madre: quale figlia tocca

Qui le figlie si eseguono **una alla volta, in ordine**. Nella sezione **Issue** della madre, la
prima riga `- [ ] #<n>` non spuntata è la figlia da eseguire — dentro un'ondata l'ordine è
libero, e se la prima ha una dipendenza aperta puoi prendere un'altra figlia della stessa
ondata:

```bash
grep -n '^[[:space:]]*- \[ \] #[0-9]' "$SCRATCH/roadmap.md" | head -1
```

Prima di prenderla, guarda che le figlie da cui dipende — la riga `· dipende da #<k>` nella
madre, `**Dipende da:**` nella figlia — siano **chiuse** sul tracker
(`glab issue view <k> --output json --jq '.state'` → `closed`, `gh issue view <k> --json state
--jq '.state'` → `CLOSED`). Una figlia con una dipendenza ancora aperta non si comincia: dillo
all'utente e indica quale va chiusa prima — di solito è una MR/PR in attesa di merge.

Se tutte le caselle della madre sono spuntate, il progetto è finito: dillo, e se la madre è
ancora aperta proponi di chiuderla. Se una casella è vuota ma la figlia è già chiusa sul
tracker, la madre è rimasta indietro: segnalalo invece di rieseguire la figlia.

Poi dì all'utente «procedo con #<n> — <titolo>» e ricomincia dal passo 1 con il numero della
figlia. **Mai due figlie nella stessa esecuzione**: ognuna ha il suo branch e la sua MR/PR, e la
successiva parte dal codice che questa avrà unito.

Per portare avanti tutte le figlie in una volta sola, senza aspettare i merge, c'è
`/issue-flow:big-implement <madre>`: stessa esecuzione sul branch della madre, con le figlie di
un'ondata insieme, ognuna nel suo worktree — ogni figlia ci entra da sola, e al branch di
destinazione arriva solo la MR/PR della madre.

## 1 ter. La figlia regge ancora?

Una figlia è stata scritta prima che le sorelle da cui dipende fossero implementate: i suoi
`file:riga` e i punti d'aggancio marcati «nasce con #<k>» descrivevano un codice che adesso è
diverso. Prima di delegare la prima fase, controlla:

- le dipendenze sono **chiuse** sul tracker e il loro lavoro è **nella base** del passo 2
  (`git log --oneline <base> | grep '#<k>'`, o i file che dovevano far nascere esistono);
- i punti d'aggancio «nasce con #<k>» esistono davvero, con il nome che la figlia si aspetta;
- i `file:riga` della prima fase puntano ancora a quello che la issue descrive.

Se qualcosa non regge in modo sostanziale — un file che non esiste, un'interfaccia nata con
un'altra forma, una decisione che la sorella ha cambiato in corsa — **fermati** e proponi
`/issue-flow:plan rivedi <numero>`. Le righe solo spostate di qualche posizione non sono un
motivo per fermarsi: il subagent le riverifica comunque. Il rimedio giusto è correggere la
issue prima del codice.

## 2. Il branch

Il lavoro non tocca mai il branch di destinazione — `${user_config.default_branch}`, o quello
che restituisce `git symbolic-ref --short refs/remotes/origin/HEAD | sed 's#^origin/##'`.

```bash
git status --porcelain                # deve essere vuoto: un commit per fase ha senso
                                      # solo se il commit contiene la fase e nient'altro
git switch <branch> 2>/dev/null \
  || { git switch <base> && git pull --ff-only && git switch -c <branch>; }
```

Se ci sono modifiche non committate, fermati e chiedi cosa farne.

Sul branch giusto, attiva il goal — con il numero della issue che stai eseguendo, che per una
madre è quello della figlia:

```bash
mkdir -p "$GOAL_DIR" && echo <numero> > "$GOAL_DIR/goal" && rm -rf "$GOAL_DIR/in-volo"
```

Il `rm` toglie un `in-volo` rimasto da una sessione interrotta, che altrimenti lascerebbe il
goal sempre spento. Per lo stesso motivo guarda `git worktree list`: un worktree di una fase
rimasto da un giro interrotto (`$WT/<branch>-fase-<N>`, `PARALLEL.md` §4) o ha un commit da
integrare — la fase era verificata e committata, e riparti dall'integrazione — o va tolto, e la
fase rifatta.

Per una figlia di un big-plan il branch nasce **sempre** dal branch in cui stanno le sorelle
già unite, appena aggiornato — il `git pull --ff-only` qui sopra:

- il **branch della madre**, `${user_config.branch_prefix}<madre>`, se esiste su `origin`
  (`git ls-remote --exit-code --heads origin <branch-madre>`): il progetto è portato avanti da
  `/issue-flow:big-implement`, e le sorelle si uniscono lì;
- il branch di destinazione altrimenti.

Mai dal branch di una sorella non ancora unita.

## 3. Il ciclo, un passo della riga Esecuzione alla volta

Per ogni passo della riga **Esecuzione** non completato, in ordine. Un passo è una fase da sola
oppure un gruppo parallelo, `[3 ∥ 4]`. Una fase da sola fa i quattro passi qui sotto, nella
cartella del repo, sul branch della issue. Un gruppo fa gli stessi quattro passi per ognuna
delle sue fasi, nel suo worktree, più due: l'accordo prima (3.1) e l'integrazione dopo (3.2).

### Delega

Un'invocazione del tool `Agent` con `subagent_type: "issue-flow:issue-phase"`. Il subagent non
ha visto la conversazione e non ha letto la issue: **quello che non gli scrivi non esiste**.
Nel prompt vanno, integrali e non riassunti:

- numero e titolo della issue, e branch su cui si sta lavorando;
- le sezioni **Obiettivo**, **Contesto** e **Fuori perimetro** della issue;
- il numero della fase e il suo **testo integrale**: cappello, elenco dei file, tutte le
  checkbox con i frammenti di codice sotto, la riga «Fatto quando»;
- cosa hanno lasciato le fasi precedenti, se hanno deviato dal piano scritto.

Subito prima dell'invocazione `mkdir -p "$GOAL_DIR/in-volo" && touch "$GOAL_DIR/in-volo/fase-<N>"`,
e appena il subagent torna `rm -f "$GOAL_DIR/in-volo/fase-<N>"`, prima della verifica.

Regole non negoziabili:

- **un subagent nuovo per ogni fase.** Mai riusarne uno con `SendMessage` per la fase dopo,
  mai passargliene due insieme, **mai due fasi in parallelo che la riga Esecuzione non mette
  nello stesso gruppo**, e mai due agenti nella stessa cartella: la fase N+1 parte dal codice
  che la fase N ha lasciato, e due agenti nella stessa working tree si pestano i piedi;
- se la roadmap ha una fase Figma, è una fase come le altre e va al suo subagent, che userà la
  skill `figma:figma-use` e il tool `use_figma` sul file `${user_config.figma_file}`. Va
  **prima** del codice, sempre, perché il codice si adegua al Figma e non viceversa;
- la fase di chiusura — documentazione e commit — la tieni tu: è coordinamento, non
  implementazione.

### Verifica

Al ritorno del subagent esegui **tu** i comandi della fase e guarda l'output vero. Il report
di un subagent è un racconto, non una prova.

Se la fase non porta comandi propri, valgono quelli del progetto per la parte toccata: quelli
che la issue elenca nella fase di verifica, o `${user_config.verify_commands}`.

Se la verifica fallisce: una seconda passata con un subagent **nuovo**, a cui dai l'output
dell'errore e cosa era stato tentato. Se fallisce di nuovo, fermati e riporta — due
fallimenti sulla stessa fase dicono che è sbagliata la issue, non il subagent.

### Spunta le caselle sulla issue

Appena la verifica passa, e non a lavoro finito. È il passo che rende la issue leggibile a
chi riprende dopo un `/clear`: senza, la roadmap mente.

```bash
# GitLab
glab issue view <numero> --output json --jq '.description' > "$SCRATCH/roadmap.md"

# GitHub
gh issue view <numero> --json body --jq '.body' > "$SCRATCH/roadmap.md"
sed -i 's/\r$//' "$SCRATCH/roadmap.md"

# giri in `- [x]` SOLO le checkbox della fase appena chiusa
# porti la riga «**Stato:**» a `in corso — fase N di M`

glab issue update <numero> --description-file "$SCRATCH/roadmap.md"   # GitLab
gh   issue edit   <numero> --body-file        "$SCRATCH/roadmap.md"   # GitHub
```

**Rileggi sempre il corpo dal server prima di riscriverlo**, mai da una copia tenuta in
conversazione: l'update sostituisce l'intero campo e non fa merge, quindi una versione vecchia
cancella quello che l'utente ha spuntato dalla pagina mentre lavoravi. E controlla che il file
non sia vuoto prima di rimandarlo su.

Se durante l'implementazione una decisione è cambiata, **riscrivi la riga** invece di
spuntarla: la roadmap deve dire cosa è stato fatto davvero. Se il subagent non è riuscito a
completare una checkbox, resta `- [ ]` e il motivo va detto all'utente alla fine.
Con una checkbox vuota la roadmap non risulta mai completa: a fine lavoro cancella tu
`$GOAL_DIR/goal`, sennò l'hook ti rimanda indietro.

### Committa

La fase e nient'altro:

```bash
git add -A && git commit -m "<tipo>(<ambito>): <cosa cambia per chi usa> (#<numero>)"
```

I messaggi seguono la convenzione già nel log del progetto — guardalo con
`git log --oneline -20` prima del primo commit, invece di imporne una tua. Mai committare con
la verifica fallita, mai un commit che copre due fasi.

### 3.1 Un gruppo parallelo: l'accordo, poi tutti insieme

Le fasi di un gruppo le ha dichiarate parallele chi ha scritto la issue, ma **l'accordo lo
confermi tu**, sul codice di adesso, prima di assegnarle: sei l'agente che assegna il lavoro, e
quello che due agenti checkbox fanno insieme deve combaciare per come l'hai deciso tu, non per
caso. Controlla:

- che i **Perimetri** delle fasi del gruppo siano disgiunti e coprano tutti i file che le loro
  checkbox nominano — compresi i file calamita di `PARALLEL.md` §2, come un lockfile per una
  dipendenza nuova;
- che il **Contratto** regga sul codice: i nomi e i tipi su cui si appoggia esistono, con quella
  forma, nel branch della issue com'è adesso;
- che nessuna fase del gruppo abbia bisogno del codice di un'altra per la sua verifica.

Se qualcosa non regge, **esegui il gruppo in sequenza**, nell'ordine dei numeri, e dillo
all'utente nella consegna: è sempre corretto, e costa solo il tempo. Se reggeva solo con un
contratto più preciso — un nome che la issue lasciava implicito —, fissalo tu, scrivilo nel
prompt di **tutte** le fasi del gruppo e riscrivi la riga del Contratto nella issue.

Poi, per ogni fase, il worktree di `PARALLEL.md` §4 — creato dal commit in cui sta il branch
della issue, e preparato con il comando del **Contesto** — e la **Delega** di sempre, con in più
nel prompt:

- il percorso assoluto del worktree, e che lavora solo lì;
- il suo **Perimetro**, e che fuori modifica niente;
- il **Contratto** e cosa fanno le fasi sorelle, con i loro perimetri: non deve rifarlo né
  toccarlo.

Tutte le fasi del gruppo — al massimo `${user_config.max_parallel}`, vuoto vale 3; le altre a
scaglioni — partono **in un solo messaggio**, ognuna con il suo segnaposto in
`$GOAL_DIR/in-volo/`. Al ritorno di ognuna togli il suo segnaposto, e fai la **Verifica** nel
suo worktree (`cd <worktree> && …`), più il controllo che sia rimasta nel perimetro:

```bash
git -C "$WT/<branch>-fase-<N>" status --porcelain    # solo file del Perimetro
```

Una fase uscita dal perimetro non si integra: una seconda passata con un agente nuovo nello
stesso worktree, con detto quali file doveva lasciare stare. Una fase verde si **committa nel
suo worktree** (`git -C "$WT/…" add -A && git -C "$WT/…" commit -m …`), un commit per fase come
sempre. Le caselle non si spuntano ancora.

### 3.2 Un gruppo parallelo: l'integrazione

Quando tutte le fasi del gruppo sono committate nei loro worktree, le porti nel branch della
issue, nella cartella del repo, **in ordine di numero**:

```bash
git cherry-pick <branch>-fase-3 <branch>-fase-4
```

Poi la **Verifica sull'albero unito** — i comandi di tutte le fasi del gruppo, più quelli del
progetto per la parte toccata —: ognuna era verde da sola, ma è la prima volta che girano
insieme. Solo adesso spunti le caselle di **tutte** le fasi del gruppo, in una riscrittura sola
del corpo riletto dal server, e togli i worktree con i loro branch (`PARALLEL.md` §4).

Un conflitto nel cherry-pick, o una verifica rossa sull'albero unito mentre le fasi erano verdi
da sole, vuol dire che il lavoro non era compatibile: `git cherry-pick --abort`, e ti fermi —
vedi «Quando fermarsi davvero». Non lo risolvi scegliendo una delle due versioni: il rimedio è
nella issue, nei perimetri o nel contratto.

## 4. Dove finisce questa skill

Al commit dell'ultima fase, con tutte le caselle spuntate sulla issue. **La MR/PR non la apri
qui**: la apre `/issue-flow:close <numero>`, che rifà la verifica sull'albero finale e ne
scrive il corpo. Dirlo all'utente nella consegna è parte del lavoro — sennò resta con un
branch pronto e nessuno che glielo porta a destinazione.

Porta la riga **Stato:** della issue a `implementata — in attesa di merge request` (su GitHub:
`in attesa di pull request`), così chi riapre la pagina sa a che punto è senza guardare il log
di git.

## 5. Consegna

Poche righe: le fasi chiuse con i loro commit (`git log --oneline`), i gruppi eseguiti in
parallelo e quelli che hai riportato in sequenza con il motivo, le checkbox rimaste
vuote con il motivo, le deviazioni scritte nella roadmap, i problemi che i subagent hanno
visto fuori dal loro perimetro, e come si prosegue: `/issue-flow:close <numero>`. Non
incollare la issue né il diff.

Se era una figlia di un big-plan, dillo anche: quale è la figlia successiva nella madre, e che
si comincia solo dopo il merge di questa, con `/issue-flow:close <numero> --chiudi` che spunta
la casella sulla madre — oppure che `/issue-flow:big-implement <madre>` porta avanti tutte le
figlie restanti senza aspettare i merge. Se la figlia è nata dal branch della madre,
`/issue-flow:close <numero>` la unisce lì da solo, e non c'è merge da aspettare.

## Quando fermarsi davvero

Fermati e chiedi, invece di proseguire, se: la stessa fase fallisce due volte; una fase
richiede una decisione che la issue non ha preso; il lavoro tocca in modo sostanziale file
che la issue non prevedeva; una verifica non è eseguibile su questa macchina (porta, servizio
o credenziale mancanti); la issue è in contraddizione con il codice che trovi; due fasi di un
gruppo parallelo non si integrano — un conflitto, o l'albero unito rosso. In quest'ultimo caso
lascia i worktree dove sono, con i loro commit: servono a chi deve capire cosa non combaciava.

Prima di fermarti, `rm -f "$GOAL_DIR/goal"`: altrimenti l'hook ti rimanda al lavoro.

Il rimedio giusto è quasi sempre correggere la issue prima di correggere il codice.
