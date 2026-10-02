---
name: big-implement
description: "Porta avanti in una sola esecuzione tutte le issue figlie di una issue madre di /issue-flow:big-plan — GitLab o GitHub — sul branch della madre: un'ondata alla volta, nell'ordine della madre, con le figlie di un'ondata in parallelo, ognuna nel suo worktree di git e affidata a un subagent issue-runner che fa il giro di /issue-flow:implement (un agente checkbox per fase, anche più d'uno insieme, checkbox spuntate, un commit per fase) e quello di /issue-flow:close, che verifica, apre la merge request — pull request su GitHub — verso il branch della madre e la unisce da solo, una figlia alla volta. Alla fine apre la MR/PR della madre verso il branch di destinazione, che unisce solo l'utente. Trigger: /issue-flow:big-implement, «implementa tutto il progetto N», «porta avanti tutta la roadmap N», «esegui tutte le figlie di N»."
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
progetto** in una volta, senza aspettare nessuno fino alla fine, e con le figlie di una stessa
ondata **in parallelo**:

```
main ──────────────────────────────────────────────── ◀── MR/PR issue-20 (la unisce l'utente)
  └─ issue-20 ──●──────────●────●──────────●──────
                ▲          ▲    ▲          ▲
            issue-21   issue-22 issue-23  issue-24
            ondata 1   └── ondata 2 ──┘   ondata 3
                       (insieme, ognuna nel suo worktree;
                        rientrano una alla volta)
```

- la madre ha il suo branch, `${user_config.branch_prefix}<madre>`, nato dal branch di
  destinazione, e la cartella del repo resta su quel branch dall'inizio alla fine;
- ogni figlia lavora nel **suo worktree**, su un branch nato dal branch della madre aggiornato.
  Le figlie di un'ondata partono insieme dallo stesso commit; un'ondata parte quando la
  precedente è tutta unita;
- ogni figlia passa per `close`: verifica sull'albero finale, documentazione, MR/PR **verso il
  branch della madre** — che qui `close` **unisce da solo**, perché il branch della madre non è
  il prodotto: è il cantiere del progetto, e la revisione vera arriva alla fine. Le figlie di
  un'ondata si implementano insieme ma **si integrano una alla volta**: ognuna, prima del suo
  merge, si unisce con quello che le sorelle hanno già portato nel branch della madre e rifà
  la verifica lì sopra;
- quando l'ultima figlia è unita, la MR/PR della madre verso il branch di destinazione si apre
  come sempre e **non si unisce**: quella l'approva e la unisce l'utente.

Le regole di esecuzione sono quelle di `implement` e `close` e non si ripetono qui:
`${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md` per le fasi, la verifica, le spunte, i commit
e la modalità goal; `${CLAUDE_PLUGIN_ROOT}/skills/close/SKILL.md` per la verifica finale, la
documentazione, la MR/PR, il merge nel branch della madre e la chiusura;
`${CLAUDE_PLUGIN_ROOT}/TRACKER.md` per i comandi delle due piattaforme;
`${CLAUDE_PLUGIN_ROOT}/PARALLEL.md` per i ruoli, l'accordo fra lavori paralleli e i worktree.
**Leggili tutti e quattro prima del primo comando.** Qui sotto c'è solo quello che cambia.

## Usage

```
/issue-flow:big-implement <madre>   # esegue, un'ondata alla volta, tutte le figlie non ancora unite
```

## Tu sei l'agente di roadmap, di tutto il progetto

Non implementi le figlie e non ne orchestri le fasi: ogni figlia la affidi a un agente di Issue
— un subagent `issue-flow:issue-runner` —, che fa per lei il giro di `implement` e di `close`
fino al merge nel branch della madre, e a sua volta affida ogni fase a un agente checkbox — un
subagent `issue-flow:issue-phase`:

```
tu (big-implement, agente di roadmap)   il progetto: ondate, accordi, worktree, branch della madre, goal, MR/PR della madre
 └─ issue-runner, uno per figlia        la figlia: fasi, accordi fra le fasi, verifiche, spunte, commit, close, merge
     └─ issue-phase, uno per fase       la fase: le sue checkbox
```

Il motivo è il contesto, come in `implement` ma un livello più su: le fasi di tutte le figlie
nel tuo contesto lo riempirebbero a metà progetto. Tu tieni la visione del progetto — quale
ondata è in corso, quali figlie, con quali MR/PR, quante sono già nel branch della madre, cosa
hanno cambiato in corsa — e controlli l'esito di ogni figlia sul tracker e su git, non sul
racconto del runner.

La catena usa tutta la profondità che Claude Code concede: sotto la sessione principale i
subagent possono lanciarne altri per due livelli, e il terzo non ha più il tool `Agent`. Per
questo `issue-phase` non delega, e il runner non deve mai essere lanciato da un altro subagent.

**Insieme solo le figlie della stessa ondata**, e solo dopo l'accordo del passo 4.1. Figlie di
ondate diverse mai: la prima figlia dell'ondata N+1 nasce dal branch della madre **dopo** che
tutta l'ondata N ci è stata unita, e parte dal codice che quella ha lasciato.

## 0. Quale tracker, e risponde

Identico al passo 0 di `implement`.

## 1. Leggi la madre e ricava le ondate

Leggi la madre dal server come al passo 1 di `implement`. Se in testa al corpo non c'è
`**Tipo:** roadmap`, non è una madre: dillo e proponi `/issue-flow:implement <numero>`.

Dalla sezione **Issue**, nell'ordine, prendi le righe `- [ ] #<n>` con la loro **Ondata**: sono
le figlie da portare avanti. Una madre scritta prima che le ondate esistessero non le ha: ogni
figlia è un'ondata da sola. Quelle `- [x]` sono già unite — nel branch della madre o, da un giro
fatto a mano, nel branch di destinazione — e non si toccano. Per ogni figlia da fare guarda sul
tracker:

- **lo stato**: se è già chiusa ma la casella è vuota, la madre è rimasta indietro —
  segnalalo, non rieseguirla, e trattala come unita;
- **le dipendenze** — `· dipende da #<k>` nella madre, `**Dipende da:**` nella figlia: ognuna
  deve essere unita (casella spuntata o issue chiusa) **oppure** una figlia che questa
  esecuzione porta avanti in un'ondata **prima** della sua. Una dipendenza fuori da entrambi i
  casi — una issue esterna aperta, una sorella della stessa ondata o di una dopo — è una roadmap
  che non regge: fermati e dillo;
- **se è già iniziata** da un giro precedente: il branch `${user_config.branch_prefix}<n>`
  esiste, ha un worktree (`git worktree list`), ha checkbox spuntate, ha già una MR/PR
  (`glab mr list --source-branch <branch>`, `gh pr list --head <branch>`). Riprendi da dove è
  rimasta invece di ripartire: dalla prima fase non spuntata, dall'integrazione se le fasi sono
  tutte fatte, dal merge se la MR/PR è aperta.

Guarda anche la **madre**: se ha già una MR/PR aperta verso il branch di destinazione
(`glab mr list --source-branch <branch-madre>`, `gh pr list --head <branch-madre>`), il
progetto è già consegnato — dillo e non ripartire.

Poi presenta all'utente le ondate e parti senza chiedere conferma:

```
issue-20  branch della madre, nasce da main
ondata 1   #21  issue-21  worktree, nasce da issue-20   MR/PR → issue-20, unita da close
ondata 2   #22  issue-22  worktree, nasce da issue-20   ┐ insieme
           #23  issue-23  worktree, nasce da issue-20   ┘ unite una alla volta: #22, poi #23
ondata 3   #24  issue-24  worktree, nasce da issue-20   MR/PR → issue-20, unita da close
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

Da qui alla fine **la cartella del repo resta sul branch della madre**, e pulita: le figlie
lavorano nei loro worktree, e qui arrivano solo i loro merge, con un `git pull --ff-only`.

Porta la riga **Stato:** della madre a `in corso — k di M issue unite in <branch-madre>`.

## 3. Il goal copre tutto il progetto

La modalità goal è quella di `implement`, con una differenza: `$GOAL_DIR/goal` contiene **tutte**
le figlie da portare avanti e **la madre**, un numero per riga. L'hook `Stop` rilegge ognuna dal
tracker e non lascia chiudere il turno finché una qualsiasi ha una `- [ ]`: nel Piano per le
figlie, nella sezione **Issue** per la madre — che si spunta solo quando una figlia è unita nel
suo branch. Così il goal regge fino all'ultimo merge, non solo fino all'ultima fase.

```bash
GOAL_DIR=$(git rev-parse --path-format=absolute --git-path issue-flow)
mkdir -p "$GOAL_DIR" && printf '%s\n' 21 22 23 24 20 > "$GOAL_DIR/goal" && rm -rf "$GOAL_DIR/in-volo"
```

Lo scrivi dopo il passo 2, prima della prima figlia. `in-volo/` funziona come in `implement`
(`PARALLEL.md` §5), con un segnaposto per **runner** al lavoro: lo crei subito prima di
delegare la figlia — `touch "$GOAL_DIR/in-volo/figlia-<n>"` — e lo togli appena quel runner
torna, anche se altri sono ancora al lavoro. I runner non toccano `.git/issue-flow/` fuori da
`wt/`: il goal e `in-volo/` sono solo tuoi.

Quando l'ultima figlia è unita l'hook ti lascia fermare anche se la MR/PR della madre non è
ancora aperta. Non fermarti lì: la consegna arriva dopo il passo 5.

Per fermarti prima della fine **cancelli tu `$GOAL_DIR/goal`** e dici all'utente perché.

## 4. Il giro, un'ondata alla volta

Per ogni ondata, in ordine: l'accordo e i worktree (4.1), le figlie delegate ai runner tutte
insieme (4.2), il giro di ogni figlia fatto dal suo runner (4.3), l'integrazione una figlia alla
volta (4.4), il controllo di ognuna (4.5). Poi l'ondata successiva.

Un'ondata di una figlia sola fa lo stesso giro, più corto: niente accordo da confermare, e il
runner fa `close` di seguito, senza aspettare il via dell'integrazione.

### 4.1 L'accordo e i worktree

Le figlie di un'ondata le ha messe insieme chi ha scritto la roadmap, ma **l'accordo lo confermi
tu**, sul branch della madre com'è adesso, prima di assegnarle: le ondate prima hanno cambiato il
codice, e chi le ha implementate può aver deviato. Rileggi la sezione **Parallelismo** della
madre e i Piani delle figlie dell'ondata, e controlla:

- che i perimetri siano ancora disgiunti: nessun file, o sezione di file, che compare nel Piano
  di due figlie dell'ondata — compresi i file calamita di `PARALLEL.md` §2;
- che il **Contratto** regga sul branch della madre: i tipi, le interfacce, i file su cui si
  appoggia esistono, con il nome e la forma che dice — le deviazioni riportate dai runner delle
  ondate prima sono il primo posto dove guardare;
- che nessuna figlia dell'ondata dipenda da un'altra della stessa ondata.

Se qualcosa non regge, l'ondata **si esegue in sequenza**, nell'ordine della madre, una figlia
alla volta: è sempre corretto, e lo dici nella consegna. Se reggeva solo con un contratto più
preciso — un nome che la madre lasciava implicito —, fissalo tu, mettilo nel prompt di **tutti**
i runner dell'ondata e riscrivi la sezione **Parallelismo** della madre rileggendola dal
server. Non spostare lavoro fra le figlie: quello è un `/issue-flow:plan rivedi`.

Poi, per ogni figlia dell'ondata, il suo worktree, dal branch della madre aggiornato
(`PARALLEL.md` §4):

```bash
git pull --ff-only                                         # sei sul branch della madre
WT=$(git rev-parse --path-format=absolute --git-common-dir)/issue-flow/wt
git worktree add "$WT/<branch>" -b <branch> <branch-madre>  # o, se il branch c'è già:
git worktree add "$WT/<branch>" <branch>                    #   lo riprende dov'era
( cd "$WT/<branch>" && <comando di preparazione> )
```

Il comando di preparazione è quello che la figlia scrive nel suo **Contesto**, o quello del
progetto.

### 4.2 Delega le figlie, tutte insieme

Un'invocazione del tool `Agent` con `subagent_type: "issue-flow:issue-runner"` per ogni figlia
dell'ondata — al massimo `${user_config.max_parallel}` insieme, vuoto vale 3; le altre a
scaglioni —, **tutte in un solo messaggio**. Il runner non ha visto la conversazione: **quello
che non gli scrivi non esiste**. Nel prompt:

- il numero e il titolo della figlia, il numero della madre, il branch della madre e il branch
  di destinazione;
- il **percorso assoluto del suo worktree**, e che lavora solo lì: la cartella del repo è tua;
- i percorsi assoluti delle istruzioni che deve leggere:
  `${CLAUDE_PLUGIN_ROOT}/skills/big-implement/SKILL.md` — per il passo 4.3, il suo giro —,
  `${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md`, `${CLAUDE_PLUGIN_ROOT}/skills/close/SKILL.md`,
  `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` e `${CLAUDE_PLUGIN_ROOT}/PARALLEL.md`;
- i valori della configurazione: `${user_config.branch_prefix}`, `${user_config.default_branch}`,
  `${user_config.verify_commands}`, `${user_config.docs_paths}`, `${user_config.figma_file}`,
  `${user_config.max_parallel}` — vuoti compresi, detti come vuoti;
- se l'ondata ha più figlie: il **suo perimetro**, quelli delle sorelle e il **Contratto**,
  integrali dalla sezione **Parallelismo** della madre, con quello che hai fissato al passo 4.1;
  e che si ferma a «pronta per l'integrazione» e aspetta il tuo via prima di `close`;
- da dove riprendere, se il passo 1 ha trovato la figlia già iniziata: la prima fase non
  spuntata, l'integrazione, la MR/PR già aperta, il merge;
- cosa hanno lasciato le figlie delle ondate prima, se hanno deviato dalla loro issue — il
  writer della figlia le conosceva solo come piano. È il campo «deviazioni» dei report dei
  runner precedenti.

Ogni runner ha il suo segnaposto in `$GOAL_DIR/in-volo/`, creato subito prima dell'invocazione e
tolto appena torna, prima del controllo.

Regole non negoziabili: **un runner nuovo per ogni figlia**, mai riusarne uno con `SendMessage`
per un'altra figlia; mai insieme figlie di ondate diverse. Mentre i runner lavorano non tocchi i
loro worktree né le loro issue; la cartella del repo resta sul branch della madre, pulita.

### 4.3 Il giro della figlia

Questo lo fa il runner, e sta qui perché è il suo riferimento. Tre passi, tutti nel worktree
che il prompt gli dà.

#### Il branch, dalla madre

Il worktree è già sul branch della figlia, nato dal branch della madre aggiornato. Il controllo
del passo **1 ter** di `implement` si fa contro il branch della madre: le dipendenze sono chiuse
e il loro lavoro è lì (`git log --oneline <branch-madre> | grep '#<k>'`), e i punti d'aggancio
«nasce con #<k>» esistono lì. Se non reggono, ti fermi come dice `implement`.

#### Le fasi

Il passo 3 di `implement`, con due varianti: niente `in-volo/` né `goal`, che sono di
`big-implement`; e la cartella del repo, per te, è il tuo worktree — i worktree delle fasi
parallele li crei con `git -C <tuo worktree> worktree add …`, nello stesso `$WT`, e li
integri nel tuo worktree. Un subagent `issue-flow:issue-phase` **nuovo** per ogni fase con il
contesto integrale della figlia, le fasi di un gruppo insieme dopo il tuo accordo, verifica
eseguita da te, spunta sulla issue rileggendola dal server, un commit per fase con
`(#<figlia>)` nel messaggio. A fine fasi, la riga **Stato:** della figlia come al passo 4 di
`implement`.

Le fasi della figlia stanno nel **perimetro della figlia**: se una fase ti chiede un file fuori,
non lo concedi tu — ti fermi e lo scrivi nel report, perché quel file è di una sorella.

Nel prompt di ogni fase va anche cosa hanno lasciato le figlie già unite, se hanno deviato
dalla loro issue.

Se l'ondata ha più figlie, a fasi finite **ti fermi**: report con «pronta per l'integrazione».
Il resto lo fai quando `big-implement` ti dà il via, al passo 4.4.

#### Close, fino al merge nel branch della madre

Tutto `close` sulla figlia, nel suo ramo «figlia con il branch della madre», nel tuo worktree:
i controlli del passo 1 — che portano nel branch della figlia quello che le sorelle hanno già
unito nel branch della madre (`git merge origin/<branch-madre>`) e rifanno la verifica
sull'albero unito —, la documentazione del passo 2, la MR/PR del passo 3 **verso il branch della
madre**, poi il merge e la chiusura del passo 3 bis, che non aspettano l'utente. Alla fine:

- la MR/PR della figlia è unita nel branch della madre;
- la figlia è chiusa, con **Stato:** `chiusa — unita in <branch-madre> il GG/MM/AAAA`;
- la sua casella sulla madre è spuntata, e lo **Stato:** della madre dice `k di M`;
- il worktree resta dov'è, con il branch della figlia: lo toglie `big-implement`.

Un conflitto nel merge con il branch della madre vuol dire che il lavoro di due sorelle non era
compatibile: `git merge --abort`, ti fermi e lo scrivi nel report con i file in conflitto. Non
lo risolvi tu: l'accordo l'ha fatto chi sta sopra, e tocca a lui.

Se `close` si ferma — una casella vuota, una verifica rossa, una pipeline fallita, una MR/PR che
il server non unisce — il runner si ferma e lo scrive nel report.

### 4.4 L'integrazione, una figlia alla volta

Le figlie di un'ondata rientrano nel branch della madre **una alla volta, nell'ordine della
madre**, perché ognuna deve fare la verifica sull'albero con dentro le sorelle già unite. Quando
tutti i runner dell'ondata sono tornati «pronta per l'integrazione», per ogni figlia in ordine:

1. dai il via al **suo** runner con `SendMessage` — «integra: fai `close` secondo il passo 4.3»
   —, così riprende con il contesto della figlia; se non risponde più, un runner nuovo con lo
   stesso prompt del 4.2, il report del primo e l'indicazione di ripartire da `close`. Il suo
   segnaposto in `in-volo/` torna finché lavora;
2. al ritorno, il controllo del passo 4.5;
3. aggiorni la cartella del repo e togli il worktree:

```bash
git pull --ff-only                                   # il branch della madre, con dentro la figlia
git worktree remove "$WT/<branch>"
git branch -D <branch> 2>/dev/null                   # unito, e già cancellato sul server
```

Poi la figlia successiva dell'ondata. Mai due integrazioni insieme: la seconda si verificherebbe
su un branch della madre senza la prima.

Se un runner si è fermato prima dell'integrazione, o una figlia non si integra, l'ondata si
ferma lì: le figlie già unite restano unite, le altre restano nei loro worktree con i loro
commit — vedi «Quando fermarsi davvero».

### 4.5 Controlla come è finita

Il report del runner è un racconto, non una prova. Prima di passare alla figlia successiva
controlli tu, sul server e su git:

```bash
# la MR/PR della figlia è unita nel branch della madre
glab mr list --source-branch <branch> --target-branch <branch-madre> --merged   # GitLab
gh   pr list --head <branch> --base <branch-madre> --state merged               # GitHub

# la figlia è chiusa, con tutte le caselle del Piano spuntate
glab issue view <figlia> --output json --jq '.state'    # "closed"
gh   issue view <figlia> --json state --jq '.state'     # "CLOSED"

# la sua casella è spuntata sulla madre: rileggi la madre dal server

# la cartella del repo è sul branch della madre, pulita, e dopo il pull ha i commit della figlia
git branch --show-current && git status --porcelain
git fetch origin && git status -sb | head -1              # niente «behind»
git log --oneline <branch-madre> | grep '(#<figlia>)'
```

Se il runner si è fermato, o uno di questi controlli non torna, il progetto si ferma: vedi
«Quando fermarsi davvero». Un runner che dice «unita» quando il server dice altro non si
riprova: la figlia va guardata.

Tieni le deviazioni del report: vanno nel prompt dei runner dell'ondata successiva, nel tuo
accordo del passo 4.1 e nella consegna.

Quando tutta l'ondata è unita, passa all'ondata successiva.

## 5. La MR/PR della madre

Quando tutte le caselle della sezione **Issue** della madre sono spuntate, `close` sulla madre,
nel suo ramo «madre»: rifà la verifica sull'albero finale del branch della madre, allinea la
documentazione, pusha e apre la MR/PR `branch della madre → branch di destinazione` con
`Closes #<madre>`. **Mai il merge**: questa l'approva e la unisce l'utente, come ogni MR/PR
verso il branch di destinazione.

Prima, `git worktree list`: non deve restare nessun worktree in `$WT` di questo progetto.

## 6. Consegna

Il link della MR/PR della madre, in cima: è l'unica cosa che l'utente deve fare. Poi una
tabella, nell'ordine in cui le figlie sono entrate nel branch della madre:

```
ondata  figlia  MR/PR  fasi  unita in
1       #21     !40    6/6   issue-20
2       #22     !41    7/7   issue-20   in parallelo con #23
2       #23     !42    5/5   issue-20   in parallelo con #22
3       #24     !43    6/6   issue-20
```

Poi le ondate e i gruppi di fasi che hai eseguito in sequenza invece che in parallelo, con il
motivo; le checkbox rimaste vuote con il motivo, le deviazioni scritte nelle roadmap, i problemi
che i subagent hanno visto fuori dal loro perimetro. E come si prosegue: a merge avvenuto della
MR/PR della madre, `/issue-flow:close <madre> --chiudi`, che chiude la madre e cancella il suo
branch.

Non incollare le issue né il diff.

## Quando fermarsi davvero

Tutti i casi di «Quando fermarsi davvero» di `implement` e di `close` — che per una figlia li
incontra il runner, e te li riporta —, più due:

- **se una figlia si ferma, il progetto si ferma con lei.** L'ondata successiva nascerebbe da un
  branch della madre senza il suo lavoro, quindi non si salta avanti. Le sorelle della stessa
  ondata che lavorano ancora le lasci finire — sono nei loro worktree, non danno fastidio a
  nessuno — e integri quelle che arrivano pronte, ma non apri l'ondata dopo;
- **se due figlie di un'ondata non si integrano** — un conflitto nel merge con il branch della
  madre, o la verifica rossa sull'albero unito mentre ognuna era verde da sola —, l'accordo non
  reggeva. Non lo risolve nessun runner: dillo all'utente con le figlie, i file e la parte del
  contratto in causa, e proponi di correggere le issue — la sezione **Parallelismo** della madre,
  `/issue-flow:plan rivedi <figlia>` — prima del codice.

Nella consegna di' quale figlia si è fermata, a che punto — fase, integrazione, MR/PR, merge —,
perché, quali worktree restano (`git worktree list`) e che si riprende con
`/issue-flow:big-implement <madre>` una volta sistemata: il passo 1 ritrova le figlie già unite
e i worktree rimasti, e riparte da lì.

Prima di fermarti, `rm -f "$GOAL_DIR/goal"`: altrimenti l'hook ti rimanda al lavoro.
