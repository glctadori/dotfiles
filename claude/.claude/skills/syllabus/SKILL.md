---
name: syllabus
description: Progetta o revisiona un percorso di apprendimento orientato a un progetto concreto, diagnosticando competenze e prerequisiti prima di proporre un syllabus da approvare.
---

# Progettare il percorso

Lavora in italiano salvo preferenza diversa. Conduci un'indagine progressiva con poche domande mirate alla volta; non presentare subito un questionario completo o un programma standard.

1. Chiarisci cosa l'utente vuole costruire, le capacità da acquisire e come riconoscere il risultato finale. Se l'obiettivo è ambiguo, chiariscilo prima di cercare nella wiki; non assumere il progetto dalle note esistenti.
2. Raccogli esperienza, strumenti, materiali già disponibili, budget e tempo. Non dare per disponibili attrezzature o acquisti futuri.
3. Usa `/home/gian/projects/notes` come wiki predefinita anche da altri progetti, salvo una wiki esplicitamente indicata dall’utente. Se non è accessibile, chiedine la posizione. Leggi esplicitamente il suo `AGENTS.md`, salvo istruzioni aggiornate già nel contesto. Usa il retrieval disponibile dalla wiki per conoscenze e note; se manca, usa ricerche mirate con `rg` e letture delle sezioni pertinenti senza creare infrastruttura; leggi direttamente percorso e progressi pertinenti. Distingui conoscenze **dichiarate**, **documentate** e **dimostrate**: una nota non prova padronanza attuale. Verifica i prerequisiti incerti con spiegazioni dell'utente, esercizi e piccole prove pratiche, una alla volta. Registra se una prova è autonoma o assistita; non anticipare la soluzione durante la diagnosi.
4. Ordina il percorso per prerequisiti e tappe con risultati concreti. Includi i fondamentali utili a diagnosticare errori e trasferire le capacità a casi nuovi. Se manca un prerequisito, inserisci una tappa di recupero; se manca un materiale, proponi un'alternativa praticabile e dichiara cosa non potrà verificare. Colloca gli acquisti vicino al momento d'uso, entro il budget.

Ogni modulo deve contenere:

- **Saper fare**: capacità osservabile, prodotto o evidenza attesa e criterio di verifica.
- **Pratica**: costruzione, esperimento, misura o programma.
- **Teoria necessaria**: anche matematica e calcoli algebrici, quando servono. Per ogni parte teorica scrivi **«A che serve?»** in una frase concreta e una breve applicazione immediata sul quaderno, al banco o nel codice. Rimanda ciò che non ha utilità spiegabile e applicazione breve, oppure motivane esplicitamente il ruolo di fondamento necessario e il momento in cui verrà applicato.
- **Prerequisiti, materiali e strumenti**, indicando ciò che è disponibile e ciò che manca.

Usa LaTeX per le formule. Grafici e schemi solo se utili o richiesti.

Presenta la proposta completa per revisione. Salva o modifica il syllabus **solo dopo approvazione della proposta concreta**. Non interpretare una richiesta iniziale di progettazione come approvazione del programma non ancora visto. Mantieni un solo syllabus attivo nella wiki: se ne esiste uno per un altro progetto, concorda la sostituzione e la conservazione del precedente prima di cambiare lo stato attivo. Non migrare o rinominare automaticamente syllabus preesistenti.

Dopo approvazione usa `percorso-<progetto>.md` per il syllabus e `progressi-<progetto>.md` per evidenze, ripassi, difficoltà ricorrenti e punto di ripresa. Indica esplicitamente `Stato: attivo` nel percorso; conserva il riferimento al percorso nei progressi. Per lo schema dei ripassi leggi [il registro condiviso](../studiamo/references/registro.md). Non introdurre infrastruttura di retrieval o modifiche al sandbox.

Le note tematiche restano compatte: cerca prima una nota adatta, riusala e collegala negli indici tematici esistenti quando necessario. Non salvare trascrizioni, non imporre una nota per lezione e non riorganizzare la wiki. La sintesi delle conoscenze verificate avviene quando l'utente dice `chiudiamo`, secondo le istruzioni di `studiamo`.
