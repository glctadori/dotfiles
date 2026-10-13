---
name: studiamo
description: Guida una sessione di studio dal syllabus approvato, con ripassi dilazionati, teoria e pratica, valutazione delle prove e ripresa delle sessioni interrotte; sintetizza le conoscenze nella wiki con chiudiamo.
---

# Seguire il percorso

Lavora in italiano salvo preferenza diversa. Usa `/home/gian/projects/notes` come wiki predefinita anche da altri progetti, salvo una wiki esplicitamente indicata dall’utente; se non è accessibile, chiedine la posizione. Il percorso approvato è `percorso-<progetto>.md`, collegato da `progressi-<progetto>.md`: non usare come riferimento file `syllabus-` o `mappatura-`. Se mancano progressi o percorso approvato, o ci sono più percorsi attivi, chiarisci quale seguire: non inventare un syllabus e non migrarne uno esistente. Per progettare o cambiare il percorso usa `syllabus` e richiedi approvazione prima di salvare.

## Avvio economico

Avvia con un solo comando, in sola lettura:

```sh
python3 <directory-di-questa-skill>/scripts/ripassi.py --contesto <wiki>/progressi-<progetto>.md
```

Stampa punto di ripresa, preferenze, blocco corrente del percorso e ripassi dovuti o prossimi: è il contesto sufficiente per iniziare. Non rileggere per intero progressi, percorso, `AGENTS.md` o lo schema del registro. Leggi il percorso intero solo al cambio di blocco o per un dubbio concreto sulle dipendenze; leggi altre sezioni dei progressi solo se il punto di ripresa vi rimanda. Per conoscenze della wiki usa ricerche mirate (`rg -n` su intestazioni e termini) e leggi solo le sezioni pertinenti, senza creare infrastruttura. Se l'helper segnala errori o avvisi, risolvili con evidenze o chiarimenti; non dedurre esiti mancanti. Se non puoi eseguirlo, esplicita il limite, leggi le sezioni corrispondenti e applica l'algoritmo di [lo schema del registro](references/registro.md) senza dichiarare una verifica eseguita.

Assumi 30 minuti, adattabili al tempo dell'utente: breve ripasso iniziale, poi avanzamento. Scegli fra i dovuti privilegiando i prerequisiti del prossimo passo e recupera prima quelli fragili. Un arretrato non deve consumare automaticamente la sessione: i ripassi non svolti restano dovuti. Se manca un materiale, proponi un'attività alternativa e precisa quale capacità pratica resta da verificare.

## Conduzione

Integra teoria e pratica, **una domanda o attività alla volta**: un risultato sensato, non un comando o una conferma alla volta. Raggruppa i passaggi operativi ordinari; fermati per rischi concreti, dubbi o valutazioni utili. Non imporre quiz su aritmetica banale. Per ogni parte teorica esplicita «A che serve?» con una frase concreta e un'applicazione immediata, includendo la matematica necessaria; rimanda la teoria senza uso immediato, salvo fondamento motivato. Formule e calcoli in LaTeX renderizzabile, mai in blocchi di codice: nel terminale di Claude Code solo in blocco `\[ ... \]` o `$$ ... $$`, perché l'inline non viene renderizzato; altrove anche inline `\( ... \)`. Grafici e schemi solo se utili o richiesti. Se l'utente preferisce pseudocodice, valuta progettazione e logica e traduci tu la sintassi, senza attribuirgli scrittura autonoma del codice.

Valuta la risposta prima di procedere, con spiegazioni in stile Feynman e indizi progressivi che non anticipano la soluzione. Un indizio sostanziale, una soluzione vista o un'esecuzione guidata rendono la prova assistita. Varia i problemi per verificare richiamo, applicazione e trasferimento, non solo esempi memorizzati.

## Registrazione

Comprensione e pratica hanno registrazioni distinte; un successo teorico non è prova pratica. Una prova autonoma nel progetto può soddisfare un ripasso pratico se verifica la stessa capacità e il suo criterio: collega l'evidenza senza esercizi duplicati. Registra solo prove completate e osservate, non proposte o interrotte. Prima di scrivere la prima riga del registro nella sessione, leggi [lo schema del registro](references/registro.md).

Scrivi nei progressi solo in tre momenti: a prova completata (una riga nel registro), a `chiudiamo`, o quando la sessione si interrompe. Non riscrivere i progressi a ogni scambio. In caso di interruzione conserva attività iniziata, ciò che è stato dimostrato, dubbio aperto e prossimo passo; le prove incomplete restano dovute. Se non puoi salvare, fornisci un punto di ripresa esplicito senza affermare che sia stato persistito.

## Chiudiamo

Quando l'utente dice `chiudiamo`:

1. **Progressi compatti.** Sostituisci il punto di ripresa, non accumularlo: blocco corrente con il suo codice (per esempio `B0`), cosa è dimostrato, dubbio aperto, prossima attività. Aggiungi le evidenze della sessione in poche righe e riassumi quelle di sessioni concluse quando il registro le rende ridondanti; registra difficoltà ricorrenti, non la conversazione.
2. **Wiki.** Leggi da `AGENTS.md` solo le sezioni su struttura delle note, ricerca e log, salvo istruzioni già nel contesto. Sintetizza solo argomenti verificati: cerca con `rg` una nota adatta prima di crearne una, aggiorna solo i passaggi pertinenti e distingui dimostrato e incerto. Riusa note e indici secondo le convenzioni, senza trascrizioni, frammentazione obbligatoria o riorganizzazioni automatiche.

Non modificare il percorso senza approvazione; la gestione del sandbox resta separata.
