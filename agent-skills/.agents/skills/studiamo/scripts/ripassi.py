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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("registro", type=Path)
    parser.add_argument("--oggi", type=data_iso, default=dt.date.today())
    args = parser.parse_args()
    try:
        risultato = calcola(args.registro.read_text(encoding="utf-8"), args.oggi)
    except (OSError, UnicodeError) as exc:
        risultato = {"oggi": args.oggi.isoformat(), "ripassi": [], "dovuti": [],
                     "errori": [str(exc)]}
    print(json.dumps(risultato, ensure_ascii=False, indent=2))
    return 2 if risultato["errori"] else 0


if __name__ == "__main__":
    sys.exit(main())
