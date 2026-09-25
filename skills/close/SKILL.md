---
name: close
description: "Porta in merge request — pull request su GitHub — il lavoro di una issue già implementata: controlla che la roadmap sia davvero tutta spuntata, rifà la verifica sull'albero finale, pusha il branch e apre la MR/PR con Closes #numero. A merge avvenuto chiude la issue e, se è figlia di un /issue-flow:big-plan, la spunta sulla madre. Trigger: /issue-flow:close, «apri la merge request della issue N», «chiudi la issue N»."
argument-hint: "<numero> [--chiudi]"
---

# /issue-flow:close

`/issue-flow:implement` lascia un branch con un commit per fase e la roadmap spuntata. Questa
skill lo porta davanti a chi deve leggerlo: una merge request — una pull request, se il
tracker è GitHub — con il corpo che dice cosa cambia e come è stato verificato. Qui sotto
«MR/PR» sta per quella delle due che vale in questo repo; all'utente dici la parola giusta,
non la barra.

**La MR/PR si apre e non si merga.** Il merge lo chiede l'utente, sempre. Questa skill non
esegue `glab mr merge` né `gh pr merge` in nessun caso, nemmeno se le pipeline sono verdi.

## Usage

```
/issue-flow:close <numero>            # apre la MR/PR della issue
/issue-flow:close <numero> --chiudi   # a merge avvenuto: chiude la issue e allinea lo Stato
/issue-flow:close                     # deduce il numero dal branch corrente
```

## 0. Quale tracker, e risponde

GitLab (`glab`) o GitHub (`gh`) secondo `git remote get-url origin`; la corrispondenza dei
comandi è in `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` — il file `TRACKER.md` nella cartella di
questo plugin — da leggere prima del primo comando.

```bash
glab auth status && glab issue view <numero>          # GitLab
gh   auth status && gh   issue view <numero>          # GitHub
```

Sul 404, o su «could not determine base repo», vale il rimedio di `TRACKER.md` §2: il remote
è un alias SSH che il CLI non riconosce. Se non sei autenticato, fermati e chiedi all'utente
`glab auth login --hostname gitlab.com` o `gh auth login --hostname github.com`: è
interattivo.

## 1. Il lavoro è davvero finito?

Tre controlli, prima di toccare qualsiasi cosa. Se uno fallisce **ti fermi e lo riporti**:
una MR/PR aperta su lavoro incompleto costa più di una non aperta.

**La roadmap è tutta spuntata.** Rileggi la issue dal server e conta. Il conteggio nel corpo
è l'unico che vale su entrambe le piattaforme — `task_completion_status` esiste solo su
GitLab:

```bash
# GitLab
glab issue view <numero> --output json --jq '.description' > "$SCRATCH/roadmap.md"

# GitHub
gh issue view <numero> --json body --jq '.body' > "$SCRATCH/roadmap.md"
sed -i 's/\r$//' "$SCRATCH/roadmap.md"

grep -c '^[[:space:]]*- \[[ xX]\]' "$SCRATCH/roadmap.md"   # totale
grep -c '^[[:space:]]*- \[[xX]\]'  "$SCRATCH/roadmap.md"   # spuntate
grep -n  '^[[:space:]]*- \[ \]'    "$SCRATCH/roadmap.md"   # quelle che restano
```

Se restano caselle vuote, elencale all'utente e chiedi: o manca lavoro — e allora si torna a
`/issue-flow:implement <numero>` — oppure sono cadute e la riga va riscritta per dire il vero.
Non spuntarle tu per far quadrare il conto.

**Il branch è quello giusto e non ha roba sospesa.** Il branch di lavoro è
`${user_config.branch_prefix}<numero>`; quello di destinazione è
`${user_config.default_branch}`, o quello che restituisce
`git symbolic-ref --short refs/remotes/origin/HEAD | sed 's#^origin/##'`.

```bash
git branch --show-current             # deve essere il branch della issue
git status --porcelain                # deve essere vuoto
git log --oneline <base>..HEAD        # i commit delle fasi, uno per fase
```

Una figlia portata avanti da `/issue-flow:big-implement` può essere **impilata**: nasce dal
branch della sorella precedente, non ancora unita, e la sua MR/PR punta lì. In quel caso
`<base>`, qui e al passo 3, è il branch della sorella.

Se la working tree è sporca, fermati: quel lavoro non è in nessun commit e non finirebbe
nella MR/PR.

**La verifica passa sull'albero finale.** I singoli commit erano verdi uno per uno; qui conta
il risultato di tutti insieme. Esegui i comandi che la issue elenca nella sua fase di verifica
— o `${user_config.verify_commands}` — e guarda l'output vero, non il riassunto.

Poi la prova a mano su ciò che la issue prometteva si dovesse vedere. Se qualcosa è rosso non
apri la MR/PR: lo sistemi con un commit sul branch, oppure ti fermi e lo riporti.

## 2. La documentazione

Prima della MR/PR, non dopo: la documentazione deve descrivere il comportamento nuovo, non
quello vecchio. Rileggi i file che la fase di chiusura della issue nominava — o quelli in
`${user_config.docs_paths}` — e controllali contro il codice che c'è adesso. Se ne manca uno,
aggiornalo e committalo prima di proseguire.

## 3. Apri la MR/PR

```bash
git push -u origin <branch>

# GitLab
glab mr create \
  --related-issue <numero> \
  --source-branch <branch> \
  --target-branch <base> \
  --title "<lo stesso titolo della issue>" \
  --description-file "$SCRATCH/mr.md" \
  --remove-source-branch \
  --yes

# GitHub — niente `--related-issue` né `--remove-source-branch`: il collegamento lo fa il
# `Closes #<numero>` in testa al corpo, e il branch si cancella dopo il merge
gh pr create \
  --head <branch> \
  --base <base> \
  --title "<lo stesso titolo della issue>" \
  --body-file "$SCRATCH/mr.md"
```

Il numero della MR/PR è quello che il comando stampa nell'URL: leggilo da lì. Su GitHub non
sarà quello della issue — issue e pull request condividono la stessa sequenza di numeri.

Il corpo è corto e sta in piedi da solo — la issue ha il piano, la MR/PR ha l'esito. Chi
rivede non deve aprire due pagine per capire cosa sta guardando:

```markdown
Closes #<numero della issue>

## Cosa cambia
[due o tre righe su cosa succede di diverso per chi usa il prodotto, non l'elenco dei file]

## Come è stata verificata
[i comandi eseguiti e cosa hanno stampato davvero, con i numeri; la prova a mano e cosa si è
visto]

## Deviazioni dal piano
[le righe della roadmap riscritte durante l'implementazione, con il perché. «Nessuna» se non
ce ne sono.]
```

I numeri qui dentro sono quelli che hai **letto** al passo 1, non quelli che ti aspettavi:
una MR/PR che dichiara test verdi mai eseguiti è il modo più veloce per far passare un errore.

Poi porta la riga **Stato:** della issue a `in revisione — !<numero MR>` su GitLab, o
`in revisione — #<numero PR>` su GitHub, rileggendo sempre il corpo dal server prima di
riscriverlo, perché l'update sostituisce l'intero campo e non fa merge:

```bash
# GitLab
glab issue view <numero> --output json --jq '.description' > "$SCRATCH/roadmap.md"
# GitHub
gh issue view <numero> --json body --jq '.body' > "$SCRATCH/roadmap.md" && sed -i 's/\r$//' "$SCRATCH/roadmap.md"

# tocchi solo la riga «**Stato:**»

glab issue update <numero> --description-file "$SCRATCH/roadmap.md"   # GitLab
gh   issue edit   <numero> --body-file        "$SCRATCH/roadmap.md"   # GitHub
```

## 4. Dopo il merge — `--chiudi`

Solo quando l'utente dice che la MR/PR è stata unita. Verifichi che sia vero, poi chiudi:

```bash
# GitLab — lo stato è minuscolo
glab mr view <numero-o-branch> --output json --jq '.state'    # deve dire "merged"
glab issue close <numero>

# GitHub — lo stato è maiuscolo, e la issue può essere già chiusa dal `Closes #<numero>`
gh pr view <numero-o-branch> --json state --jq '.state'       # deve dire "MERGED"
gh issue view <numero> --json state --jq '.state'             # se è già "CLOSED", non richiuderla
gh issue close <numero>
```

e porti la riga **Stato:** a `chiusa — unita il GG/MM/AAAA`, con la data di oggi. In locale:
`git switch <base> && git pull --ff-only`. Il branch di lavoro si cancella solo se il server
non l'ha già fatto: su GitLab lo fa `--remove-source-branch`, su GitHub l'opzione
«Automatically delete head branches» del repo, e se nessuna delle due l'ha tolto,
`git push origin --delete <branch>`.

Se lo stato della MR/PR non è `merged`/`MERGED`, non chiudere niente e dillo.

### Le MR/PR impilate su questa

Se `/issue-flow:big-implement` ha impilato altre MR/PR sul branch appena unito, **prima di
cancellarlo** portale sul branch di destinazione — altrimenti restano a puntare su un branch che
non esiste più. Di solito il server lo fa da solo quando cancella il branch unito; controlla:

```bash
glab mr list --target-branch <branch>     # GitLab
gh   pr list --base          <branch>     # GitHub

glab mr update <n> --target-branch <base> # GitLab — per ognuna rimasta
gh   pr edit   <n> --base          <base> # GitHub
```

Su GitHub il `Closes #<figlia>` della PR ritargettata comincia a valere adesso, perché la PR
ora punta al branch di default.

### La madre, se la issue è una figlia

Se in testa al corpo della issue c'è `**Roadmap:** #<madre>`, la figlia appena chiusa va
spuntata sulla madre: è l'unico posto dove si legge a che punto è il progetto.

```bash
# GitLab
glab issue view <madre> --output json --jq '.description' > "$SCRATCH/madre.md"
# GitHub
gh issue view <madre> --json body --jq '.body' > "$SCRATCH/madre.md" && sed -i 's/\r$//' "$SCRATCH/madre.md"

# giri in `- [x]` SOLO la riga `- [ ] #<numero>` della sezione Issue
# porti la riga «**Stato:**» della madre a `in corso — k di M issue unite`

glab issue update <madre> --description-file "$SCRATCH/madre.md"   # GitLab
gh   issue edit   <madre> --body-file        "$SCRATCH/madre.md"   # GitHub
```

Le regole di sempre: rileggi dal server, controlla che il file non sia vuoto, tocca solo quelle
due righe. La MR/PR della figlia porta `Closes #<figlia>` e **mai** il numero della madre: la
madre non si chiude al merge di una figlia.

Se dopo la spunta tutte le caselle della sezione Issue sono `- [x]`, il progetto è finito:
porta lo **Stato:** della madre a `chiusa — completata il GG/MM/AAAA` e chiudila
(`glab issue close <madre>`, `gh issue close <madre>`). Altrimenti, nella consegna, nomina la
figlia successiva: la prima `- [ ] #<n>` rimasta, da cominciare con
`/issue-flow:implement <n>` — o `/issue-flow:implement <madre>`, che la trova da solo.

## 5. Consegna

Il link della MR/PR, cosa hai verificato con i numeri veri, i file di documentazione che hai
dovuto aggiornare, e quello che hai trovato non a posto e hai sistemato per poterla aprire.
Dopo un `--chiudi` su una figlia, a che punto è la madre (`k di M issue unite`) e quale figlia
viene dopo. Se
ti sei fermato, la ragione in una riga e cosa serve per sbloccare.

## Quando fermarsi davvero

Fermati e chiedi, invece di aprire la MR/PR, se: restano checkbox non spuntate; la working
tree è sporca; una verifica è rossa e la causa non è un refuso evidente; il branch è dietro
quello di destinazione in modo che richiede un rebase con conflitti da decidere; la issue è
già chiusa o ha già una MR/PR aperta.
