# Registro dei ripassi nelle note-argomento

I ripassi stanno nelle note-argomento della wiki (per esempio `integrali-di-linea.md`, `statica.md`), non in file per libro, corso o percorso. Ogni nota che entra nello studio ha al massimo una sezione `## Registro ripassi`, in fondo. `progressi-<progetto>.md` non ha registro: contiene riferimento al percorso approvato, punto di ripresa, preferenze, evidenze in prosa (conoscenza dichiarata/documentata/dimostrata e aiuti ricevuti) e difficoltà ricorrenti. Nessuna migrazione automatica dei file esistenti.

La sezione contiene prima le voci da avviare, opzionali, poi la tabella:

```markdown
## Registro ripassi

- da avviare: teorema-green — Applicare il teorema di Green a un campo nel piano (Kreyszig §10.4, dichiarato 2026-10-15)
- da avviare: legge-coseni — Legge dei coseni con il segno corretto (storico fragile: box 3 al 2026-07-10, errore ricorrente di segno)

| id | dimensione | data | esito | modalita | evidenza |
| --- | --- | --- | --- | --- | --- |
| misura-tensione | comprensione | 2026-10-12 | riuscita | autonoma | Spiega e calcola la tensione attesa senza aiuti. |
| misura-tensione | pratica | 2026-10-12 | riuscita | assistita | Misura al banco con un indizio sulla scala. |
```

**Voci da avviare.** Formato esatto `- da avviare: <id> — <capacità osservabile e fonte>`, con `id` in minuscolo con trattini. Rappresentano capacità studiate o dichiarate ma non ancora provate in questo sistema: non sono eventi e non hanno scadenza. La parola `fragile` nel testo (storico debole, errori ricorrenti) le porta in testa all'elenco. Alla prima prova completata aggiungi la riga in tabella e togli la voce, nella stessa modifica.

**Tabella.** `id` è stabile e unico nella nota; la chiave globale è nota/id/dimensione. `dimensione` è `comprensione` o `pratica`. Mantieni gli eventi in ordine cronologico per ogni coppia id/dimensione e non sovrascrivere quelli precedenti. Fonte, sezione del libro o blocco del percorso vanno nell'evidenza, non nell'id.

Date ISO `YYYY-MM-DD`, senza date future rispetto al giorno di valutazione. Ogni riga richiede un'evidenza concreta che descrive in breve l'esercizio svolto, così che i ripassi successivi ne scelgano uno diverso. Con esito `incerta` o `fallita` l'evidenza indica l'errore preciso, per esempio «segno di −2ab cos γ invertito» e non «errore di calcolo», perché il ripasso successivo lo possa mettere alla prova con un esercizio diverso. Evita il carattere `|` nelle celle. Le prove incomplete restano nel testo libero dei progressi e non diventano eventi. Sono ammessi più eventi lo stesso giorno, nell'ordine effettivo: ogni riga deve rappresentare una prova distinta, senza registrazioni duplicate. Livelli di sistemi precedenti non si importano come righe: vanno nel testo della voce da avviare.

Intervalli dei livelli 0–5: per `comprensione` **1, 3, 7, 16, 35, 90 giorni**; per `pratica` **3, 7, 21, 45, 90, 180 giorni**, perché le abilità pratiche decadono più lentamente, costano banco e materiali e spesso si esercitano già nel progetto. La prima prova completata avvia il livello 0, qualunque sia l'esito; evidenzia e recupera una capacità ancora fragile. Eccezione per lo screening: se la prima prova è `riuscita` + `autonoma` e l'evidenza comincia con `Screening:`, parte dal livello 3 (16 giorni per la comprensione, 45 per la pratica). Usala solo per una risposta sicura, senza esitazioni né indizi; un esito incerto o fallito durante lo screening si registra normalmente e parte dal livello 0. Poi:

- `riuscita` + `autonoma`: avanza di un livello, fino al massimo 5;
- `incerta`, oppure qualunque riuscita assistita: mantiene il livello;
- `fallita`: torna al livello 0, anche se assistita.

`modalita` è sempre `autonoma` o `assistita`. La scadenza è la data dell'ultima prova completata più l'intervallo del livello risultante; al livello 5 le prove successive riuscite restano distanziate dell'intervallo massimo della dimensione. Un ripasso saltato non genera una riga e non sposta la scadenza. Una scadenza uguale a oggi è dovuta. Le due dimensioni hanno cronologie indipendenti.

## Helper

`scripts/ripassi.py [progressi] [--wiki DIR]` legge tutte le note `*.md` nella radice della wiki (predefinita: la cartella dei progressi) che hanno la sezione, e valida ogni registro per intero. Una nota con errori è esclusa e segnalata con nome e riga; le altre producono comunque le scadenze. Senza opzioni stampa JSON compatto con dovuti (con evidenza), prossimi tre, prime voci da avviare, totale da avviare ed errori; `--tutti` aggiunge l'elenco completo dei ripassi e delle voci. `--contesto` stampa invece testo: con i progressi anche punto di ripresa, preferenze e blocco corrente del percorso collegato (il primo codice di blocco, come `B0` o `P5a`, citato nel punto di ripresa; un percorso non trovato produce un avviso), senza progressi solo i ripassi. Codice di uscita 0 se tutti i registri sono validi, 2 se qualche nota è esclusa o i progressi non sono leggibili. `--oggi YYYY-MM-DD` permette simulazioni riproducibili, senza scrivere nulla.
