#!/usr/bin/env python3
"""Legge i registri Markdown delle note della wiki e calcola i ripassi, senza scritture."""

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

INTERVALLI = {"comprensione": (1, 3, 7, 16, 35, 90), "pratica": (3, 7, 21, 45, 90, 180)}
LIVELLO_MAX = 5
COLONNE = ("id", "dimensione", "data", "esito", "modalita", "evidenza")
SEZIONE = "## Registro ripassi"
DA_AVVIARE = re.compile(r"^- da avviare: ([a-z0-9][a-z0-9-]*) — (\S.*)$")
MOSTRA_DA_AVVIARE = 8
LIVELLO_SCREENING = 3


def data_iso(value):
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        raise ValueError("data richiesta nel formato YYYY-MM-DD")
    return dt.date.fromisoformat(value)


def calcola(markdown, oggi):
    """Registro di una sola nota: ripassi, voci da avviare, errori e numero di sezioni."""
    errori, eventi, avviare = [], [], []
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
            sezione = riga == SEZIONE
            if sezione:
                sezioni += 1
            continue
        if not sezione or not riga:
            continue
        if riga.startswith("- "):
            voce = DA_AVVIARE.match(riga)
            if not voce:
                errori.append(f"riga {numero}: voce attesa '- da avviare: <id> — <testo>'")
            elif intestazione:
                errori.append(f"riga {numero}: le voci da avviare vanno prima della tabella")
            else:
                avviare.append((numero, voce.group(1), voce.group(2)))
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
    if sezioni > 1:
        errori.append(f"serve una sola sezione '{SEZIONE}'")
    if sezioni and (not intestazione or not separatore):
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
        if (not precedente and esito == "riuscita" and modalita == "autonoma"
                and evidenza.startswith("Screening:")):
            livello = LIVELLO_SCREENING
        elif esito == "fallita":
            livello = 0
        elif precedente and esito == "riuscita" and modalita == "autonoma":
            livello = min(livello + 1, LIVELLO_MAX)
        stati[chiave] = {
            "id": ident, "dimensione": dimensione, "livello": livello,
            "ultima_prova": giorno, "esito": esito, "modalita": modalita,
            "evidenza": evidenza,
        }
    provati = {ident for ident, _ in stati}
    nomi = set()
    for numero, ident, _ in avviare:
        if ident in nomi:
            errori.append(f"riga {numero}: voce da avviare duplicata per {ident}")
        elif ident in provati:
            errori.append(f"riga {numero}: {ident} ha già prove nel registro, togli la voce da avviare")
        nomi.add(ident)
    ripassi = []
    if not errori:
        for stato in stati.values():
            scadenza = stato["ultima_prova"] + dt.timedelta(days=INTERVALLI[stato["dimensione"]][stato["livello"]])
            ripassi.append({**stato, "ultima_prova": stato["ultima_prova"].isoformat(),
                            "scadenza": scadenza.isoformat(), "dovuto": scadenza <= oggi})
    da_avviare = [] if errori else [{"id": ident, "testo": testo} for _, ident, testo in avviare]
    return {"ripassi": ripassi, "da_avviare": da_avviare, "errori": errori, "sezioni": sezioni}


def raccogli(cartella, oggi):
    """Unisce i registri di tutte le note nella radice della wiki; una nota invalida è esclusa."""
    ripassi, avviare, errori = [], [], []
    for percorso in sorted(cartella.glob("*.md")):
        try:
            markdown = percorso.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as exc:
            errori.append(f"{percorso.stem}: {exc}")
            continue
        if SEZIONE not in markdown:
            continue
        nota = calcola(markdown, oggi)
        if not nota["sezioni"]:
            continue
        errori += [f"{percorso.stem}: {e}" for e in nota["errori"]]
        ripassi += [{"nota": percorso.stem, **s} for s in nota["ripassi"]]
        avviare += [{"nota": percorso.stem, **v} for v in nota["da_avviare"]]
    ripassi.sort(key=lambda s: (s["scadenza"], s["nota"], s["id"], s["dimensione"]))
    # Le voci marcate «fragile» per prime, poi nell'ordine delle note e del file.
    avviare.sort(key=lambda v: "fragile" not in v["testo"].lower())
    return {"oggi": oggi.isoformat(), "ripassi": ripassi,
            "dovuti": [s for s in ripassi if s["dovuto"]],
            "prossimi": [s for s in ripassi if not s["dovuto"]][:3],
            "da_avviare": avviare, "errori": errori}


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
    testo = (f"- {s['nota']} › {s['id']} / {s['dimensione']}: livello {s['livello']}, "
             f"scadenza {s['scadenza']}, ultima {s['ultima_prova']} {s['esito']} {s['modalita']}")
    return testo + (f" — {s['evidenza']}" if evidenza else "")


def testo_ripassi(risultato):
    righe = ["## Ripassi"]
    if risultato["errori"]:
        righe.append("Note escluse per registro invalido (correggile prima di usarle):")
        righe += [f"- {e}" for e in risultato["errori"]]
    righe.append("Dovuti:" if risultato["dovuti"] else "Dovuti: nessuno")
    righe += [riga_ripasso(s, evidenza=True) for s in risultato["dovuti"]]
    avviare = risultato["da_avviare"]
    if avviare:
        righe.append(f"Da avviare ({len(avviare)}"
                     + (f", i primi {MOSTRA_DA_AVVIARE}):" if len(avviare) > MOSTRA_DA_AVVIARE else "):"))
        righe += [f"- {v['nota']} › {v['id']} — {v['testo']}" for v in avviare[:MOSTRA_DA_AVVIARE]]
    if risultato["prossimi"]:
        righe.append("Prossimi:")
        righe += [riga_ripasso(s) for s in risultato["prossimi"]]
    return "\n".join(righe)


def contesto(progressi, risultato, cartella):
    """Testo compatto per avviare la sessione con una sola lettura."""
    parti = [f"# Contesto di studio — oggi {risultato['oggi']}"]
    if progressi is not None:
        elenco = sezioni(progressi)
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
        blocco, avviso = blocco_corrente(progressi, ripresa, cartella)
        if blocco:
            parti.append(f"## Blocco corrente — {blocco[0]}\n\n" + blocco[1])
        else:
            parti.append(f"## Blocco corrente\n(avviso: {avviso})")
    parti.append(testo_ripassi(risultato))
    return "\n\n".join(parti)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("progressi", type=Path, nargs="?",
                        help="progressi del percorso: ripresa, preferenze e blocco corrente")
    parser.add_argument("--wiki", type=Path,
                        help="cartella della wiki (predefinita: quella dei progressi)")
    parser.add_argument("--oggi", type=data_iso, default=dt.date.today())
    parser.add_argument("--contesto", action="store_true",
                        help="stampa ripresa, preferenze, blocco corrente e ripassi in testo compatto")
    parser.add_argument("--tutti", action="store_true",
                        help="include nel JSON tutti i ripassi e tutte le voci da avviare")
    args = parser.parse_args()
    if args.progressi is None and args.wiki is None:
        parser.error("indica i progressi o --wiki")
    cartella = args.wiki or args.progressi.parent
    progressi, errore = None, None
    if args.progressi is not None:
        try:
            progressi = args.progressi.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as exc:
            errore = f"progressi non leggibili: {exc}"
    risultato = raccogli(cartella, args.oggi)
    if errore:
        risultato["errori"].insert(0, errore)
    if args.contesto:
        print(contesto(progressi, risultato, args.progressi.parent if args.progressi else cartella))
    else:
        risultato["da_avviare_totale"] = len(risultato["da_avviare"])
        if not args.tutti:
            for s in risultato["prossimi"]:
                s.pop("evidenza", None)
            del risultato["ripassi"]
            risultato["da_avviare"] = risultato["da_avviare"][:MOSTRA_DA_AVVIARE]
        print(json.dumps(risultato, ensure_ascii=False, separators=(",", ":")))
    return 2 if risultato["errori"] else 0


if __name__ == "__main__":
    sys.exit(main())
