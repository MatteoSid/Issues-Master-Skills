# PARALLEL — chi lavora insieme, e come non si pestano i piedi

Le skill di questo plugin fanno lavorare più agenti insieme **quando si può**: i writer delle
figlie in `/issue-flow:big-plan`, le figlie di una stessa ondata in `/issue-flow:big-implement`,
le fasi di uno stesso gruppo in `/issue-flow:implement`. Questo file è il riferimento unico per
quando si può, per come lo si scrive nelle issue e per come lo si esegue con i worktree di git;
le skill lo citano invece di ripetersi.

## 1. Chi assegna il lavoro a chi

| ruolo | chi è | a chi assegna il lavoro |
|---|---|---|
| **agente di roadmap** | la sessione di `big-plan` — e, all'esecuzione, quella di `big-implement` | agli `issue-writer`, uno per figlia; agli agenti di Issue, uno per figlia |
| **agente di Issue** | la sessione di `implement`, o il subagent `issue-runner` di `big-implement` | agli agenti checkbox, uno per fase |
| **agente checkbox** | il subagent `issue-phase` | a nessuno: porta a termine le checkbox di **una** fase |

La regola che tiene insieme tutto: **il lavoro di due agenti che lavorano insieme lo concorda
l'agente che glielo assegna, prima di assegnarlo.** Due agenti in parallelo non si parlano e
non si vedono: se il loro lavoro deve combaciare, combacia perché chi sta sopra ha deciso in
anticipo chi tocca cosa e con quali nomi. Mai lasciare che lo scoprano da soli, e mai che uno
dei due «si adegui» a quello che crede stia facendo l'altro.

## 2. Quando due pezzi di lavoro vanno in parallelo

Due figlie, o due fasi, si possono eseguire insieme solo se valgono **tutte** queste:

- **perimetri disgiunti.** Ognuna ha un perimetro — i file che può modificare o creare, o la
  sezione di un file quando il file è condiviso («`README.md` §API, solo quella sezione») — e i
  perimetri non si sovrappongono. Leggere un file fuori perimetro va bene; modificarlo no;
- **nessuna ha bisogno del codice dell'altra** per compilare, per i suoi test o per la sua prova
  a mano. Se la B chiama una funzione che nasce con la A, la B viene dopo la A — oppure la firma
  nasce prima, in una fase o figlia precedente, e tutte e due ci si appoggiano;
- **un contratto scritto.** Quello che le due condividono — un tipo, un nome, una firma, un
  formato di dati, un'enumerazione — è deciso da chi le assegna e scritto nella issue, con il
  nome e la forma esatti. Ognuna lo rispetta senza vedere l'altra;
- **nessuna risorsa condivisa nella verifica** che un worktree non isola: una porta fissa, un
  database locale, un container con un nome fisso, una cartella di cache fuori dal repo. Se la
  verifica di entrambe la usa, o vanno in sequenza o la issue lo dice e la verifica la esegue
  l'agente che le ha assegnate, una alla volta.

**I file calamita.** Sono quelli che quasi ogni modifica tocca, e i primi a mandare in conflitto
due lavori paralleli: i lockfile (`package-lock.json`, `poetry.lock`, `uv.lock`), le migrazioni
numerate, i registri di route o di plugin, i file indice che riesportano (`index.ts`,
`__init__.py`), i file di traduzione, il changelog, la configurazione della CI. In un gruppo
parallelo ognuno ha **un solo** proprietario, oppure lo tocca solo chi viene dopo il gruppo —
la fase di chiusura, la figlia successiva. Una dipendenza nuova vuol dire un lockfile toccato:
la fase o figlia che la aggiunge non va in parallelo con un'altra che fa lo stesso.

**Nel dubbio, in sequenza.** Un parallelo sbagliato costa un conflitto, una verifica rossa
sull'albero unito e un giro buttato; un parallelo mancato costa solo il tempo. Le fasi di
verifica e di chiusura, e la fase Figma, non vanno mai in parallelo con niente.

## 3. Come si scrive nelle issue

Il parallelismo si decide **quando si pianifica**, non quando si esegue: chi esegue lo trova
scritto, lo ricontrolla contro il codice e lo segue.

**Nella madre** di `big-plan` le figlie stanno in **ondate**. Le figlie di una stessa ondata
non dipendono l'una dall'altra e si eseguono insieme; un'ondata comincia quando la precedente è
tutta unita. La sezione **Issue** è divisa per ondata, e la sezione **Parallelismo** dice, per
ogni ondata con più di una figlia, il perimetro di ognuna e il contratto fra loro
(`skills/big-plan/TEMPLATE.md`).

**In ogni issue** il Piano si apre con la riga **Esecuzione**, che dà l'ordine delle fasi con i
gruppi paralleli fra parentesi quadre:

```
**Esecuzione:** 1 → 2 → [3 ∥ 4] → 5 → 6
```

Una issue senza fasi parallele ha la riga lo stesso — `1 → 2 → 3 → 4 → 5 → 6` — così chi esegue
sa che il sequenziale è una scelta e non una dimenticanza. Ogni fase di un gruppo parallelo ha,
sotto il titolo, al posto della riga dei file:

```
**Perimetro:** `src/a.ts`, `src/a.test.ts` — solo questi.
**In parallelo con:** Fase 4. **Contratto:** [cosa condividono, con nomi e forme esatti; cosa
questa fase lascia stare perché è della 4]
```

## 4. Come si esegue: i worktree

Più agenti che scrivono codice insieme **non lavorano mai nella stessa cartella**: ognuno ha il
suo worktree di git, su un branch suo, nato dallo stesso commit. La cartella principale del repo
resta di chi li ha assegnati.

### Dove

Tutti i worktree del plugin stanno dentro la cartella git comune, che non finisce mai in un
commit e non sporca `git status`:

```bash
WT=$(git rev-parse --path-format=absolute --git-common-dir)/issue-flow/wt
```

`--git-common-dir` e non `--git-path`: dentro un worktree `--git-path` punta alla cartella privata
di quel worktree, e un runner che lavora in un worktree finirebbe per crearne in un posto diverso
da quello dove li cerca chi gli sta sopra. Il nome è quello del branch: `$WT/issue-21` per una
figlia, `$WT/issue-21-fase-3` per una fase.

### Il giro

Lo fa chi assegna il lavoro — l'agente di Issue per le fasi, l'agente di roadmap per le figlie —
mai chi lo riceve:

```bash
# 1. crea: un branch locale per pezzo, tutti dallo stesso commit
git worktree add "$WT/<branch>-fase-3" -b <branch>-fase-3 HEAD

# 2. prepara: un worktree nasce senza dipendenze installate né file ignorati da git
#    (node_modules, .venv, .env). Il comando di preparazione lo dice la issue, nel Contesto;
#    se non lo dice, quello del progetto: npm ci, uv sync, poetry install…
( cd "$WT/<branch>-fase-3" && <comando di preparazione> )

# 3. assegna: un agente per worktree, tutti nello stesso messaggio, ognuno con il percorso
#    assoluto del suo worktree, il suo perimetro e il contratto

# 4. al ritorno di ognuno: verifica nel SUO worktree, e controlla che sia rimasto nel perimetro
git -C "$WT/<branch>-fase-3" status --porcelain     # solo file del perimetro

# 5. committa nel suo worktree, un commit per fase come sempre
git -C "$WT/<branch>-fase-3" add -A
git -C "$WT/<branch>-fase-3" commit -m "<messaggio della fase> (#<numero>)"
```

L'integrazione nel branch della issue, nella cartella dell'agente di Issue, **in ordine di
fase** e solo quando tutto il gruppo è verificato:

```bash
git cherry-pick <branch>-fase-3 <branch>-fase-4    # un commit per fase, storia lineare
```

e poi la verifica **sull'albero unito**: ogni fase era verde da sola, ma è la prima volta che
girano insieme. Alla fine si toglie tutto — i branch delle fasi sono locali e non vanno mai su
`origin`:

```bash
git worktree remove "$WT/<branch>-fase-3" && git branch -D <branch>-fase-3
```

Le figlie di un'ondata seguono lo stesso giro un livello più su, con due differenze: i branch
sono quelli veri delle figlie (`issue-21`, nati dal branch della madre) e si integrano con il
loro `close`, una alla volta, invece che con un cherry-pick (`skills/big-implement/SKILL.md`).

### Un conflitto vuol dire che il contratto non reggeva

Se il cherry-pick o il merge di integrazione va in conflitto, o la verifica sull'albero unito è
rossa mentre i pezzi erano verdi da soli, **il lavoro non era compatibile**: un perimetro
violato o un contratto incompleto. Non si risolve a mano scegliendo una delle due versioni:

```bash
git cherry-pick --abort     # o: git merge --abort
```

e ci si ferma, dicendo quali pezzi, quali file, quale parte del contratto. Il rimedio è
correggere la issue — perimetri, contratto, o il gruppo diviso in sequenza — prima del codice.

### Quanti insieme

Al massimo `${user_config.max_parallel}` agenti insieme per ogni agente che assegna — vuoto vale
3. Un gruppo più grande si esegue a scaglioni, nell'ordine della issue. `1` spegne il
parallelismo: tutto in sequenza, come se le issue non lo dichiarassero.

## 5. Il goal con più agenti in volo

L'hook `Stop` (`scripts/goal-stop.sh`) lascia chiudere il turno mentre un subagent lavora. Con
più subagent insieme, `in-volo` è una **cartella** con un segnaposto per ognuno:

```bash
GOAL_DIR=$(git rev-parse --path-format=absolute --git-path issue-flow)
mkdir -p "$GOAL_DIR/in-volo" && touch "$GOAL_DIR/in-volo/fase-3" "$GOAL_DIR/in-volo/fase-4"
# al ritorno di ognuno, il suo e solo il suo
rm -f "$GOAL_DIR/in-volo/fase-3"
```

Finché la cartella non è vuota l'hook non blocca: ti risveglia la notifica del prossimo che
torna. Un segnaposto dimenticato spegne il goal, quindi lo togli **appena** quell'agente torna,
prima di verificarne il lavoro.
