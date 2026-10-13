# Progressi e registro dei ripassi

`progressi-<progetto>.md` contiene il riferimento al percorso approvato, evidenze (conoscenza dichiarata/documentata/dimostrata e aiuti ricevuti), difficoltà ricorrenti e un punto di ripresa. Il registro è una sezione strutturata dentro questo normale file Markdown; il resto resta testo libero. Nessuna migrazione automatica dei file esistenti.

Usa una sola sezione `## Registro ripassi` e la seguente tabella. Mantieni gli eventi in ordine cronologico per ogni coppia capacità/dimensione. Non sovrascrivere gli eventi precedenti. `id` è un identificatore stabile della capacità; `dimensione` è `comprensione` o `pratica`.

```markdown
## Registro ripassi

| id | dimensione | data | esito | modalita | evidenza |
| --- | --- | --- | --- | --- | --- |
| misura-tensione | comprensione | 2026-10-12 | riuscita | autonoma | Spiega e calcola la tensione attesa senza aiuti. |
| misura-tensione | pratica | 2026-10-12 | riuscita | assistita | Misura al banco con un indizio sulla scala. |
```

Date ISO `YYYY-MM-DD`, senza date future rispetto al giorno di valutazione. Ogni riga richiede un'evidenza concreta; evita il carattere `|` nelle celle. Le prove incomplete restano nel testo libero e non diventano eventi. Sono ammessi più eventi lo stesso giorno, nell'ordine effettivo: ogni riga deve rappresentare una prova distinta, senza registrazioni duplicate.

Intervalli dei livelli 0–5: **1, 3, 7, 16, 35, 90 giorni**. La prima prova completata avvia il livello 0, qualunque sia l'esito; evidenzia e recupera una capacità ancora fragile. Poi:

- `riuscita` + `autonoma`: avanza di un livello, fino al massimo 5;
- `incerta`, oppure qualunque riuscita assistita: mantiene il livello;
- `fallita`: torna al livello 0, anche se assistita.

`modalita` è sempre `autonoma` o `assistita`. La scadenza è la data dell'ultima prova completata più l'intervallo del livello risultante; al livello 5 le prove successive riuscite restano distanziate di 90 giorni. Un ripasso saltato non genera una riga e non sposta la scadenza. Una scadenza uguale a oggi è dovuta. Le due dimensioni hanno cronologie indipendenti.

L'helper legge **l'intero Markdown** e valida il registro, incluse righe successive a quelle già dovute. Senza opzioni stampa JSON compatto con i ripassi dovuti (con evidenza), i prossimi tre e gli errori; `--tutti` aggiunge l'elenco completo. `--contesto` stampa invece testo con punto di ripresa, preferenze, blocco corrente del percorso collegato (il primo codice di blocco, come `B0` o `P5a`, citato nel punto di ripresa) e ripassi; un percorso non trovato produce un avviso, non un errore. Codice di uscita 0 per un registro valido (anche vuoto), 2 per dati mancanti/invalidi o errori di lettura. In presenza di errori non emette scadenze parziali: correggi il registro prima di usarlo per scegliere la sessione. Sezione e intestazione sono obbligatorie; una tabella vuota è ammessa. `--oggi YYYY-MM-DD` permette simulazioni riproducibili, senza scrivere nulla.
