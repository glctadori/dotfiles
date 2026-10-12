---
name: llm-wiki
description: Consulta la wiki personale, integra conoscenza su richiesta, processa l’inbox esplicitamente richiesta, revisiona note mirate o conduce la review mensile con memoria dei mesi precedenti, anche lavorando da altri progetti. Non sostituisce i workflow di syllabus e studio.
---

# Lavorare con la wiki personale

Usa `/home/gian/projects/notes` come wiki predefinita, anche se la directory di lavoro è un altro progetto. Una wiki esplicitamente indicata dall’utente prevale. Se la directory non è accessibile, segnala il limite e chiedi la posizione; non creare una raccolta sostitutiva.

Leggi esplicitamente `AGENTS.md` nella wiki prima di cercare o modificare contenuti, salvo che le sue istruzioni aggiornate siano già nel contesto. Le convenzioni locali governano organizzazione, letture autorizzate, fonti, inbox, indice e log: non duplicarle qui. La directory di lavoro esterna non estende l’ambito della ricerca oltre la wiki.

## Consultare

Chiarisci un argomento ambiguo prima di cercare. Usa i comandi di retrieval disponibili secondo le convenzioni locali, eseguendoli dalla wiki: non presumere che esistano uno script o una cache embeddings. Se il retrieval non è disponibile, usa `rg` su titoli e termini pertinenti, poi leggi soltanto le sezioni necessarie. Per stringhe esatte usa `rg -n -F --glob '*.md' -- "string" .` dalla wiki. Non installare o generare infrastruttura come ripiego.

Rispondi con riferimenti alle note e alle fonti pertinenti, distinguendo conoscenza documentata, osservazioni personali e ipotesi. Una ricerca senza risultati non prova l’assenza assoluta del tema. Una domanda autorizza consultazione, non scrittura.

## Integrare

Quando l’utente chiede di salvare o aggiornare conoscenza, cerca prima una nota semanticamente adatta. Integra solo i risultati durevoli nei passaggi pertinenti; crea una nota quando il tema ha valore autonomo. Applica i criteri editoriali locali, conserva condizioni e limiti delle affermazioni e non promuovere proposte o attività pianificate a risultati osservati. Non salvare trascrizioni per impostazione predefinita.

Per «processa inbox» segui il workflow locale completo; non inventariare o leggere l’inbox durante una semplice domanda o un salvataggio di sintesi. Per una revisione, resta nel tema o nei file richiesti e proponi cambiamenti strutturali ampi prima di applicarli.

Controlla contenuti e collegamenti modificati, aggiorna indice e log solo quando previsto dalle convenzioni e termina con un resoconto conciso. I workflow di progettazione e sessione di studio restano nelle skill `syllabus` e `studiamo`.

## Review mensile

Quando l’utente chiede «facciamo la review del mese» o equivalente, chiarisci il mese da rivedere solo se ambiguo. Il quadernino resta il riferimento operativo: lavora con il racconto o gli estratti che l’utente fornisce, senza richiedere una trascrizione completa.

Usa `review-mensili.md` nella wiki come memoria essenziale. Le sezioni sono intestate `## YYYY-MM` per il mese rivisto. Leggi solo le ultime tre sezioni disponibili in ordine cronologico; risali a mesi più lontani soltanto per un riferimento pertinente emerso nella conversazione. Se il registro manca o non contiene review, parti dal racconto attuale, senza inventare uno storico. Il focus per il mese successivo resta nella sezione della review che lo ha scelto, con il mese destinatario esplicito.

Conduci la conversazione con poche domande, **una alla volta**, adattate alle risposte e allo storico:

- Riprendi focus, decisioni, abitudini ed esperimenti concordati e chiedi come sono andati. Distingui obiettivi pianificati, esiti riferiti e questioni aperte; l’assenza di aggiornamenti non prova completamento o fallimento.
- Esplora progressi, soddisfazioni, difficoltà e consumo di energie. Quando un rinvio si ripete, chiedi se la cosa interessa ancora senza presumere che vada abbandonata.
- Per le attività aperte aiuta a scegliere se continuare, ridurre, rimandare a un mese preciso o abbandonare; non riportarle automaticamente come arretrati.
- Consulta la sezione del mese successivo in `future.md` per impegni, scadenze e idee da rivalutare, senza dedurre giorno, anno o ricorrenza non indicati.
- Aiuta a scegliere una priorità principale e poche attività compatibili con tempo, energie e impegni reali.

Prepara in chat una sintesi da trascrivere sul quadernino: mese destinatario, focus, motivazione, risultato concreto desiderato, primo passo, impegni e date, eventuale abitudine da mantenere o sperimentare e cose in pausa. Presentala come proposta finché l’utente non conferma le scelte; la richiesta iniziale di review non conferma automaticamente il piano emerso.

Alla chiusura, dopo la conferma delle scelte, salva nel registro un breve resoconto: focus precedente ed esiti riferiti, decisioni, abitudini o esperimenti, questioni da riprendere e focus successivo con il mese esplicito. Crea la sezione del mese rivisto o aggiorna solo quella pertinente, preservando le altre; non salvare trascrizioni. Se le scelte non sono confermate, restano in chat.

Integra apprendimenti nelle note tematiche e modifica `future.md` solo su richiesta esplicita. Per indice e log segui le convenzioni locali. Non introdurre notifiche automatiche, retrieval o un secondo registro operativo.
