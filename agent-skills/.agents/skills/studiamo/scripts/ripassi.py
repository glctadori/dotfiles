#!/usr/bin/env python3
"""Legge un registro Markdown e calcola i ripassi, senza scritture."""

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

INTERVALLI = (1, 3, 7, 16, 35, 90)
COLONNE = ("id", "dimensione", "data", "esito", "modalita", "evidenza")


def data_iso(value):
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        raise ValueError("data richiesta nel formato YYYY-MM-DD")
    return dt.date.fromisoformat(value)


def calcola(markdown, oggi):
    errori, eventi = [], []
    sezione = False
    sezioni = 0
    intestazione = False
    separatore = False
    in_codice = None
    for numero, riga in enumerate(markdown.splitlines(), 1):
        riga = riga.strip()
        fence = re.match(r"^(`{3,}|~{3,})", riga)
        if fence:
            marker = fence.group(1)
            if in_codice is None:
                in_codice = marker
            elif marker[0] == in_codice[0] and len(marker) >= len(in_codice):
                in_codice = None
            continue
        if in_codice:
            continue
        if re.match(r"^#{1,2}\s", riga):
            sezione = riga == "## Registro ripassi"
            if sezione:
                sezioni += 1
            continue
        if not sezione or not riga:
            continue
        if not riga.startswith("|") or not riga.endswith("|"):
            errori.append(f"riga {numero}: nel registro è richiesta una riga di tabella")
            continue
        celle = [c.strip() for c in riga[1:-1].split("|")]
        if not intestazione:
            if tuple(celle) != COLONNE:
                errori.append(f"riga {numero}: intestazione attesa: {' | '.join(COLONNE)}")
            else:
                intestazione = True
            continue
        if not separatore:
            if len(celle) != 6 or not all(re.fullmatch(r":?-{3,}:?", c) for c in celle):
                errori.append(f"riga {numero}: separatore Markdown mancante o invalido")
            else:
                separatore = True
            continue
        if len(celle) != 6 or not all(celle):
            errori.append(f"riga {numero}: servono sei celle non vuote")
            continue
        ident, dimensione, data, esito, modalita, evidenza = celle
        try:
            giorno = data_iso(data)
        except ValueError as exc:
            errori.append(f"riga {numero}: {exc}")
            continue
        if dimensione not in ("comprensione", "pratica"):
            errori.append(f"riga {numero}: dimensione invalida")
        elif esito not in ("riuscita", "incerta", "fallita"):
            errori.append(f"riga {numero}: esito invalido")
        elif modalita not in ("autonoma", "assistita"):
            errori.append(f"riga {numero}: modalita invalida")
        elif giorno > oggi:
            errori.append(f"riga {numero}: data futura")
        else:
            eventi.append((numero, ident, dimensione, giorno, esito, modalita, evidenza))
    if sezioni != 1:
        errori.append("serve una sola sezione '## Registro ripassi'")
    if not intestazione or not separatore:
        errori.append("tabella del registro mancante o incompleta")

    stati, visti = {}, set()
    for numero, ident, dimensione, giorno, esito, modalita, evidenza in eventi:
        chiave = (ident, dimensione)
        evento = (ident, dimensione, giorno, esito, modalita, evidenza)
        if evento in visti:
            errori.append(f"riga {numero}: evento duplicato")
            continue
        visti.add(evento)
        precedente = stati.get(chiave)
        if precedente and giorno < precedente["ultima_prova"]:
            errori.append(f"riga {numero}: eventi fuori ordine per {ident}/{dimensione}")
            continue
        livello = precedente["livello"] if precedente else 0
        if esito == "fallita":
            livello = 0
        elif precedente and esito == "riuscita" and modalita == "autonoma":
            livello = min(livello + 1, len(INTERVALLI) - 1)
        stati[chiave] = {
            "id": ident, "dimensione": dimensione, "livello": livello,
            "ultima_prova": giorno, "esito": esito, "modalita": modalita,
            "evidenza": evidenza,
        }
    ripassi = []
    if not errori:
        for stato in stati.values():
            scadenza = stato["ultima_prova"] + dt.timedelta(days=INTERVALLI[stato["livello"]])
            ripassi.append({**stato, "ultima_prova": stato["ultima_prova"].isoformat(),
                            "scadenza": scadenza.isoformat(), "dovuto": scadenza <= oggi})
        ripassi.sort(key=lambda s: (s["scadenza"], s["id"], s["dimensione"]))
    return {"oggi": oggi.isoformat(), "ripassi": ripassi,
            "dovuti": [s for s in ripassi if s["dovuto"]], "errori": errori}


def sezioni(markdown):
    """Restituisce [(livello, titolo, testo)] per le intestazioni fuori dai blocchi di codice."""
    risultato, corrente, in_codice = [], None, None
    for riga in markdown.splitlines():
        fence = re.match(r"^\s*(`{3,}|~{3,})", riga)
        if fence:
            marker = fence.group(1)
            if in_codice is None:
                in_codice = marker
            elif marker[0] == in_codice[0] and len(marker) >= len(in_codice):
                in_codice = None
        titolo = None if in_codice or fence else re.match(r"^(#{1,6})\s+(.*\S)", riga)
        if titolo:
            corrente = [len(titolo.group(1)), titolo.group(2), [riga]]
            risultato.append(corrente)
        elif corrente:
            corrente[2].append(riga)
    return [(livello, titolo, "\n".join(righe).strip()) for livello, titolo, righe in risultato]


def estrai(elenco, indice):
    """Testo della sezione indicata, incluse le sottosezioni."""
    livello = elenco[indice][0]
    parti = [elenco[indice][2]]
    for sotto in elenco[indice + 1:]:
        if sotto[0] <= livello:
            break
        parti.append(sotto[2])
    return "\n\n".join(parti)


def blocco_corrente(progressi, ripresa, cartella):
    """Trova il percorso collegato nei progressi e il blocco citato nel punto di ripresa."""
    link = re.search(r"\]\(\s*<?(percorso-[^)#>\s]+?)(?:\.md)?>?\s*(?:#[^)]*)?\)", progressi)
    if not link:
        return None, "riferimento al percorso non trovato nei progressi"
    percorso = cartella / f"{link.group(1)}.md"
    try:
        elenco = sezioni(percorso.read_text(encoding="utf-8"))
    except (OSError, UnicodeError) as exc:
        return None, f"percorso non leggibile: {exc}"
    codici = {}
    for indice, (livello, titolo, _) in enumerate(elenco):
        codice = re.match(r"([A-Z]+\d+[a-z]?)\b", titolo)
        if livello > 1 and codice:
            codici.setdefault(codice.group(1), indice)
    citati = [m.group(1) for m in re.finditer(r"\b([A-Z]+\d+[a-z]?)\b", ripresa)
              if m.group(1) in codici]
    if not citati:
        return None, f"nessun blocco di {percorso.name} citato nel punto di ripresa"
    indice = codici[citati[0]]
    return (f"{percorso.name} § {elenco[indice][1]}", estrai(elenco, indice)), None


def riga_ripasso(s, evidenza=False):
    testo = (f"- {s['id']} / {s['dimensione']}: livello {s['livello']}, scadenza {s['scadenza']}, "
             f"ultima {s['ultima_prova']} {s['esito']} {s['modalita']}")
    return testo + (f" — {s['evidenza']}" if evidenza else "")


def contesto(markdown, risultato, cartella):
    """Testo compatto per avviare la sessione con una sola lettura."""
    elenco = sezioni(markdown)
    parti = [f"# Contesto di studio — oggi {risultato['oggi']}"]
    ripresa = ""
    for prefisso in ("Punto di ripresa", "Preferenze"):
        indice = next((i for i, (_, t, _) in enumerate(elenco) if t.startswith(prefisso)), None)
        if indice is None:
            parti.append(f"## {prefisso}\n(sezione assente nei progressi)")
            continue
        testo = estrai(elenco, indice)
        if prefisso == "Punto di ripresa":
            ripresa = testo
        parti.append(testo)
    blocco, avviso = blocco_corrente(markdown, ripresa, cartella)
    if blocco:
        parti.append(f"## Blocco corrente — {blocco[0]}\n\n" + blocco[1])
    else:
        parti.append(f"## Blocco corrente\n(avviso: {avviso})")
    righe = ["## Ripassi"]
    if risultato["errori"]:
        righe.append("Registro invalido, nessuna scadenza calcolata:")
        righe += [f"- {e}" for e in risultato["errori"]]
    else:
        righe.append("Dovuti:" if risultato["dovuti"] else "Dovuti: nessuno")
        righe += [riga_ripasso(s, evidenza=True) for s in risultato["dovuti"]]
        if risultato["prossimi"]:
            righe.append("Prossimi:")
            righe += [riga_ripasso(s) for s in risultato["prossimi"]]
    parti.append("\n".join(righe))
    return "\n\n".join(parti)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("registro", type=Path)
    parser.add_argument("--oggi", type=data_iso, default=dt.date.today())
    parser.add_argument("--contesto", action="store_true",
                        help="stampa ripresa, preferenze, blocco corrente e ripassi in testo compatto")
    parser.add_argument("--tutti", action="store_true", help="include tutti i ripassi nel JSON")
    args = parser.parse_args()
    markdown = ""
    try:
        markdown = args.registro.read_text(encoding="utf-8")
        risultato = calcola(markdown, args.oggi)
    except (OSError, UnicodeError) as exc:
        risultato = {"oggi": args.oggi.isoformat(), "ripassi": [], "dovuti": [],
                     "errori": [str(exc)]}
    risultato["prossimi"] = [s for s in risultato["ripassi"] if not s["dovuto"]][:3]
    if args.contesto and markdown:
        print(contesto(markdown, risultato, args.registro.parent))
    else:
        if not args.tutti:
            for s in risultato["prossimi"]:
                s.pop("evidenza", None)
            del risultato["ripassi"]
        print(json.dumps(risultato, ensure_ascii=False, separators=(",", ":")))
    return 2 if risultato["errori"] else 0


if __name__ == "__main__":
    sys.exit(main())
