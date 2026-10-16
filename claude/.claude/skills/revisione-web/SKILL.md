---
name: revisione-web
description: Revisione settimanale della cronologia Brave per ridurre l'uso dispersivo del web; analizza i siti più usati, confronta con le settimane precedenti e propone modifiche alla lista dei blocchi a calendario (scheduled-names.txt) del filtro web.
---

# Revisione settimanale del web

Lavora in italiano. **Scopo unico: ridurre l'uso dispersivo della tecnologia** dell'utente. Ogni dato che riporti e ogni proposta che fai devono servire a questo; ciò che non aiuta a capire o ridurre la dispersione non entra nel riepilogo. Non giudicare: descrivi, proponi, lascia decidere.

Dispersivo = attività tech che sembra lavoro o necessità ma non porta avanti un obiettivo dell'utente: controlli compulsivi (home aperta senza uno scopo), confronto continuo di strumenti, modelli o prezzi senza decisione, personalizzazione e configurazione oltre il necessario, acquisti rimandati e ricontrollati, navigazione di svago che sostituisce il lavoro. Non è dispersivo l'uso mirato di strumenti per i progetti, lo studio e le vendite.

File coinvolti (repo `/home/gian/projects/dotfiles`):
- `webfilter/.config/web-filter/scheduled-names.txt`: domini bloccati tutti i giorni tranne `OPEN_DAY` (in `schedule.conf`, oggi domenica).
- Stato in `~/.local/state/web-review/`: `last-review` (scritto da `--mark`) e `reviews.md` (diario delle revisioni).

## Procedura

1. Leggi `~/.local/state/web-review/reviews.md` se esiste: serve per confrontare con la settimana scorsa e non riproporre ciò che l'utente ha già rifiutato.
2. Lancia `web-review-report` (parte dall'ultima revisione; `--days N` o `--since` per cambiare finestra). Dà visite per dominio, giorni attivi, visite alla sola home, appartenenza alla lista a calendario, visite di domenica, titoli, ricerche, distribuzione per giorno e ora. Il tempo di permanenza manca di proposito: con le tab aperte è inaffidabile.
3. Raggruppa i domini per categoria (IA, acquisti, lavoro/progetti, studio, svago, desktop/configurazione, altro) e separa quota dispersiva e quota mirata. Riassumi in poche righe: quanta dispersione c'è e dove, come è cambiata rispetto al diario (la tendenza conta più del singolo numero), quali domini in lista vengono ancora visitati e se lo fanno soprattutto la domenica (blocco che funziona) o negli altri giorni (tentativi di aggirarlo, o sottodomini non bloccati). Segnala anche gli spostamenti: se un sito bloccato viene sostituito da un altro simile, è dispersione che si sposta, non che diminuisce.
4. Distingui lo scopo, non solo il sito: home aperta senza ricerca = controllo di abitudine; titoli di prodotto o pagine di documentazione = uso con un obiettivo. Un sito misto (eBay: vendite sì, acquisti no) non si può bloccare a livello DNS: dillo, non proporlo.
5. Parti dall'intervento che riduce più dispersione, non dall'elenco completo: al massimo 3-4 proposte in ordine di effetto atteso. Proponi modifiche concrete a `scheduled-names.txt`: domini da aggiungere (con visite e motivo), da togliere (inutili o ormai non visitati, o bloccano lavoro vero) e cosa lasciare fuori. Se il blocco non basta (siti misti, dispersione dentro strumenti utili), proponi un'alternativa non di blocco: una sessione a orario fisso, una lista unica degli acquisti, una domanda da farsi prima di aprire il sito. Non proporre di bloccare strumenti di lavoro (ChatGPT, Claude, GitHub, datasheet, documentazione dei progetti) né studio. Libri e siti di svago solo se l'utente lo chiede.
6. Aspetta conferma. Poi modifica il file, spiega che per applicare serve `~/projects/dotfiles/webfilter/.local/bin/web-filter-install` con sudo (non lanciarlo tu) e che dopo conviene riavviare Brave.
7. Chiudi la revisione: esegui `web-review-report --mark` per registrare la data e aggiungi in `reviews.md` un blocco breve: data, visite totali, 3-5 domini/categorie principali con i numeri, cosa è stato aggiunto/tolto/rifiutato e una riga sulla dispersione: in aumento, stabile o in calo rispetto alla revisione precedente, e perché.

## Regole
- Dati sensibili: la cronologia contiene anche ricerche private. Nel riepilogo cita solo ciò che serve alla decisione e non ripetere ricerche personali non pertinenti.
- Non cambiare `OPEN_DAY`, il filtro o le liste del filtro (`denied-names.txt`, liste scaricate) salvo richiesta esplicita.
- Se la finestra è corta (meno di 5 giorni) o la cronologia è stata cancellata, dillo: i numeri non sono confrontabili con le settimane precedenti.
