---
name: studiamo
description: Guida una sessione di studio dal syllabus approvato o di soli ripassi, con ripassi dilazionati nelle note-argomento della wiki, teoria e pratica, valutazione delle prove e ripresa delle sessioni interrotte; aggiunge ai ripassi lo studio esterno (libri, corsi) e sintetizza le conoscenze nella wiki con chiudiamo.
---

# Seguire il percorso

Lavora in italiano salvo preferenza diversa. Usa `/home/gian/projects/notes` come wiki predefinita anche da altri progetti, salvo una wiki esplicitamente indicata dall’utente; se non è accessibile, chiedine la posizione. Il percorso approvato è `percorso-<progetto>.md`, collegato da `progressi-<progetto>.md`: non usare come riferimento file `syllabus-` o `mappatura-`. I ripassi stanno nelle note-argomento della wiki, non nei progressi, e valgono anche senza percorso. Se l'utente vuole avanzare nel percorso ma mancano progressi o percorso approvato, o ci sono più percorsi attivi, chiarisci quale seguire: non inventare un syllabus e non migrarne uno esistente. Per progettare o cambiare il percorso usa `syllabus` e richiedi approvazione prima di salvare.

## Avvio economico

Avvia con un solo comando, in sola lettura:

```sh
python3 <directory-di-questa-skill>/scripts/ripassi.py --contesto <wiki>/progressi-<progetto>.md
```

Stampa punto di ripresa, preferenze, blocco corrente del percorso e i ripassi di tutte le note (dovuti, da avviare, prossimi): è il contesto sufficiente per iniziare. Per una sessione di soli ripassi, o senza percorso attivo, usa `ripassi.py --contesto --wiki <wiki>`. Non rileggere per intero progressi, percorso, `AGENTS.md` o lo schema del registro. Leggi il percorso intero solo al cambio di blocco o per un dubbio concreto sulle dipendenze; leggi altre sezioni dei progressi solo se il punto di ripresa vi rimanda. Per conoscenze della wiki usa ricerche mirate (`rg -n` su intestazioni e termini) e leggi solo le sezioni pertinenti, senza creare infrastruttura. Se l'helper segnala errori o avvisi, risolvili con evidenze o chiarimenti; non dedurre esiti mancanti. Se non puoi eseguirlo, esplicita il limite, leggi le sezioni corrispondenti e applica l'algoritmo di [lo schema del registro](references/registro.md) senza dichiarare una verifica eseguita.

Assumi 30 minuti, adattabili al tempo dell'utente: breve ripasso iniziale, poi avanzamento. Scegli al massimo cinque dovuti, privilegiando i prerequisiti del prossimo passo, quelli fragili e quelli più in ritardo; poi avvia al massimo tre voci da avviare, a partire da quelle in testa. In una sessione di soli ripassi vale lo stesso tetto sui dovuti; le voci da avviare si fanno quante ne consente il tempo.

**Screening.** Quando l'utente chiede di scremare le voci da avviare, procedi per nota con un esercizio breve e nuovo per ciascuna voce (circa due minuti, 15–20 per sessione), senza indizi. Per ciascuna:

- risposta sicura e autonoma: registra `riuscita` `autonoma` con evidenza che comincia con `Screening:`; parte dal livello 3;
- esitazione, indizio o errore: registra l'esito reale senza prefisso, con l'errore preciso; parte dal livello 0;
- l'utente dichiara che non gli interessa più: togli la voce, senza riga.

Scrivi le righe e togli le voci alla fine di ogni nota, non a ogni esercizio. Un arretrato non deve consumare automaticamente la sessione: i ripassi non svolti restano dovuti e le voci restano da avviare. Se manca un materiale, proponi un'attività alternativa e precisa quale capacità pratica resta da verificare.

## Conduzione

Integra teoria e pratica, **una domanda o attività alla volta**: un risultato sensato, non un comando o una conferma alla volta. Raggruppa i passaggi operativi ordinari; fermati per rischi concreti, dubbi o valutazioni utili. Non imporre quiz su aritmetica banale. Per ogni parte teorica esplicita «A che serve?» con una frase concreta e un'applicazione immediata, includendo la matematica necessaria; rimanda la teoria senza uso immediato, salvo fondamento motivato. Mostra sempre ogni equazione, formula o calcolo, anche breve, in LaTeX renderizzabile, mai in blocchi di codice né in testo semplice, e mai in linea (`$ ... $`, `\( ... \)`), in qualunque ambiente. Ogni espressione sta in un blocco a sé `$$ ... $$` (o `\[ ... \]`) fuori dal testo; nel testo corrente un singolo simbolo si scrive in Unicode (τ, ω_q), mentre frazioni, somme, derivate e relazioni vanno nel blocco dopo la frase. Grafici e schemi solo se utili o richiesti. Se l'utente preferisce pseudocodice, valuta progettazione e logica e traduci tu la sintassi, senza attribuirgli scrittura autonoma del codice.

Valuta la risposta prima di procedere, con spiegazioni in stile Feynman e indizi progressivi che non anticipano la soluzione. Un indizio sostanziale, una soluzione vista o un'esecuzione guidata rendono la prova assistita. Varia i problemi per verificare richiamo, applicazione e trasferimento, non solo esempi memorizzati. Ogni ripasso usa un esercizio nuovo: mai lo stesso già annotato nelle evidenze della capacità, e cambia anche contesto, numeri e forma (calcolo, spiegazione, caso applicato, controesempio), così l'utente non riconosce uno schema ma ricostruisce il ragionamento. Se l'ultima evidenza riporta un errore, il ripasso deve dare l'occasione di ricaderci, con un esercizio diverso: per esempio, dopo un segno sbagliato nella legge dei coseni, un triangolo ottuso in un problema di altro tipo. Usa l'evidenza precedente solo per scegliere l'esercizio: non citarla nel testo della prova, perché confonde e suggerisce la risposta.

**Formato delle prove.** Uno scenario di due o tre righe e una sola domanda; la richiesta successiva arriva solo dopo la risposta. Un ripasso è una prova di pochi minuti su una sola capacità: non accorpare più ripassi in un compito con più consegne. Un tentativo autonomo o un compito integrato di blocco è avanzamento nel percorso, non un ripasso, e si propone solo quando l'utente lo sceglie. Se una prova risulta banale, la successiva è più sostanziosa sulla stessa capacità, non più grande. Non commentare all'utente cosa registri né le regole su indizi e aiuti: registra e prosegui. Dopo una risposta parziale riconosci ciò che è giusto e dai un solo indizio o una sola domanda più stretta, senza aggiungere nuovi elenchi di domande. Una prova pratica si fa al banco, con le mani, o nel lavoro sul progetto: senza materiale non chiedere di ragionare sul circuito ricordato registrandola come pratica; il ripasso pratico resta dovuto, oppure, se l'utente lo vuole, fai una prova di comprensione e registrala come tale.

## Aggiungere studio esterno

Quando l'utente dice di aver studiato qualcosa fuori dal percorso («ho fatto Kreyszig §9.3», «aggiungi ai ripassi…»), organizza per argomento, non per fonte. Leggi da `AGENTS.md` solo struttura delle note e ricerca, salvo istruzioni già nel contesto; cerca con `rg` la nota-argomento adatta e riusala, creane una solo se l'argomento ha valore autonomo, collegandola a hub o `index.md` secondo le convenzioni. Integra una sintesi breve di ciò che ha studiato, presentata come dichiarata e non dimostrata, chiedendo solo i dettagli necessari. Aggiungi nel registro della nota una o più voci da avviare, con capacità osservabili e fonte nel testo (per esempio «Calcolare un integrale di linea indipendente dal cammino (Kreyszig §10.2)»), non «capitolo 10». Non scrivere righe in tabella senza una prova; se l'utente chiede una prova subito, conducila e registrala.

## Registrazione

Ogni prova, del percorso o esterna, va nel registro della nota-argomento pertinente: cercala con `rg` e creala solo secondo le convenzioni di `AGENTS.md`; i progressi ricevono solo ripresa ed evidenze in prosa. Comprensione e pratica hanno registrazioni distinte; un successo teorico non è prova pratica. Una prova autonoma nel progetto può soddisfare un ripasso pratico se verifica la stessa capacità e il suo criterio: collega l'evidenza senza esercizi duplicati. Registra solo prove completate e osservate, non proposte o interrotte. Prima di scrivere la prima riga del registro nella sessione, leggi [lo schema del registro](references/registro.md).

Scrivi nel registro di una nota a prova completata (una riga, e togli l'eventuale voce da avviare), nei progressi solo a `chiudiamo` o quando la sessione si interrompe. Non riscrivere i progressi a ogni scambio. In caso di interruzione conserva attività iniziata, ciò che è stato dimostrato, dubbio aperto e prossimo passo; le prove incomplete restano dovute. Se non puoi salvare, fornisci un punto di ripresa esplicito senza affermare che sia stato persistito.

## Chiudiamo

Quando l'utente dice `chiudiamo`:

1. **Progressi compatti** (se la sessione seguiva un percorso). Sostituisci il punto di ripresa, non accumularlo: blocco corrente con il suo codice (per esempio `B0`), cosa è dimostrato, dubbio aperto, prossima attività. Aggiungi le evidenze della sessione in poche righe e riassumi quelle di sessioni concluse quando i registri delle note le rendono ridondanti; registra difficoltà ricorrenti, non la conversazione.
2. **Wiki.** Leggi da `AGENTS.md` solo le sezioni su struttura delle note, ricerca e log, salvo istruzioni già nel contesto. Sintetizza solo argomenti verificati: cerca con `rg` una nota adatta prima di crearne una, aggiorna solo i passaggi pertinenti e distingui dimostrato e incerto. Riusa note e indici secondo le convenzioni, senza trascrizioni, frammentazione obbligatoria o riorganizzazioni automatiche.

Non modificare il percorso senza approvazione; la gestione del sandbox resta separata.
