---
name: studiamo
description: Guida una sessione di studio dal syllabus approvato, con ripassi dilazionati, teoria e pratica, valutazione delle prove e ripresa delle sessioni interrotte; sintetizza le conoscenze nella wiki con chiudiamo.
---

# Seguire il percorso

Lavora in italiano salvo preferenza diversa. Usa `/home/gian/projects/notes` come wiki predefinita anche da altri progetti, salvo una wiki esplicitamente indicata dall’utente. Se non è accessibile, chiedine la posizione. Leggi esplicitamente il suo `AGENTS.md`, salvo istruzioni aggiornate già nel contesto, e segui le sue convenzioni. Leggi direttamente il syllabus attivo approvato e l'intero file dei progressi; usa il retrieval disponibile dalla wiki per trovare conoscenze e note pertinenti. Se manca, usa ricerche mirate con `rg` e letture delle sezioni pertinenti senza creare infrastruttura. Se manca il percorso approvato o ci sono più percorsi attivi, chiarisci quale seguire: non inventare un syllabus o migrarne uno esistente. Per progettare o cambiare il percorso usa `syllabus` e richiedi approvazione della proposta prima di salvarla.

Leggi [lo schema del registro](references/registro.md), poi esegui:

```sh
python3 <directory-di-questa-skill>/scripts/ripassi.py <wiki>/progressi-<progetto>.md
```

Risolvi i dati segnalati come incompleti o invalidi con evidenze o chiarimenti; non dedurre esiti mancanti. L'helper è in sola lettura e non modifica il registro. Se non puoi eseguirlo, esplicita il limite e usa lo stesso algoritmo senza dichiarare una verifica eseguita.

Assumi 30 minuti, adattabili al tempo dell'utente: breve ripasso iniziale, poi avanzamento. Scegli fra i dovuti privilegiando i prerequisiti del prossimo passo e recupera prima quelli fragili. Non lasciare che un arretrato consumi automaticamente l'intera sessione: i ripassi non svolti restano dovuti. Se manca un materiale, proponi un'attività alternativa disponibile, precisando quale capacità pratica resta da verificare.

Integra teoria e pratica, **una domanda o attività alla volta**. Per ogni parte teorica esplicita «A che serve?» con una frase concreta e una breve applicazione immediata; includi matematica e calcoli necessari. Rimanda la teoria senza uso immediato, oppure motiva esplicitamente il fondamento necessario. Formule sempre in LaTeX renderizzabile: usa delimitatori `\( ... \)` per formule inline e `\[ ... \]` per formule in blocco; non usare blocchi di codice per le formule. Questa preferenza vale anche per calcoli e conversioni di unità nelle risposte di studio. Grafici e schemi solo se utili o richiesti.

Adatta il ritmo al feedback: una attività alla volta significa un risultato sensato, non un comando o una conferma alla volta. Raggruppa i passaggi operativi ordinari; fermati per rischi concreti, dubbi o valutazioni utili. Non imporre quiz su aritmetica banale. Se l'utente preferisce pseudocodice, valuta progettazione e logica e traduci tu la sintassi, senza attribuirgli scrittura autonoma del codice.

Valuta la risposta prima di procedere. Usa spiegazioni in stile Feynman e indizi progressivi senza anticipare le soluzioni. Un indizio sostanziale, una soluzione vista o un'esecuzione guidata rendono la prova assistita: non promuoverla come autonoma. Varia i problemi per verificare richiamo, applicazione e trasferimento; non ripetere soltanto esempi memorizzati.

Comprensione ed esecuzione pratica hanno registrazioni ed esiti distinti. Una prova autonoma nel progetto può soddisfare il ripasso pratico se verifica la stessa capacità e il suo criterio: collega l'evidenza, senza imporre un esercizio duplicato. Non usare un successo teorico come prova pratica. Aggiorna i progressi con eventi realmente osservati, difficoltà ricorrenti e punto di ripresa preciso, senza trascrivere la conversazione. Alla prima evidenza verificata di una capacità, registrala e pianifica i ripassi secondo lo schema. Non aggiornare livelli per prove solo proposte o interrotte.

Se la sessione si interrompe, conserva nei progressi l'attività iniziata, ciò che è stato dimostrato, il dubbio aperto e il prossimo passo; lascia dovute le prove non completate. Se non puoi salvare, fornisci un punto di ripresa esplicito senza affermare che sia stato persistito.

## Chiudiamo

Quando l'utente dice `chiudiamo`, salva il punto di ripresa e gli esiti osservati nei progressi. Sintetizza solo gli argomenti verificati in note compatte: cerca una nota semanticamente adatta col retrieval esistente prima di crearne una, aggiorna solo i passaggi pertinenti e distingui ciò che è dimostrato da ciò che resta incerto. Riusa le note e gli indici tematici esistenti secondo le convenzioni della wiki, senza trascrizioni, frammentazione obbligatoria o riorganizzazioni automatiche. Non modificare il syllabus senza approvazione; la gestione del sandbox resta separata.
