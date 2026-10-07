#!/usr/bin/env python3
"""LES CLÉS DE LICENCE DE MARCHINGBLOCKS — l'outil de Jordan (charte §0, « la vente »).

Une clé est au nom de l'acheteur, SIGNÉE (Ed25519, RFC 8032) par la clé privée de SpannerGames, et vérifiée HORS
LIGNE par l'appli (version SITE), qui porte la clé publique (`app/licence.gd`, `CLE_PUBLIQUE`). Aucune activation,
aucune limite de machines.

⚠ LA CLÉ PRIVÉE N'ENTRE JAMAIS DANS LE DÉPÔT. Elle vit dans `C:/Users/jorda/.marchingblocks/licence_ed25519_privee.hex`
(32 octets en hexadécimal), comme la clé du PCK. Cet outil n'en contient aucune : il la lit. ⚠ LA SAUVEGARDER
(clé USB, coffre de mots de passe) : perdue, plus aucune clé neuve ne se vérifie dans les exe déjà livrés ;
volée, n'importe qui signe des clés — il faudrait alors une paire neuve et une mise à jour de l'appli.

USAGE (Python 3, `pip install cryptography`) :
  python DEV_TOOLS/licence_signer.py generer                    une paire neuve (refuse d'écraser l'existante)
  python DEV_TOOLS/licence_signer.py publique                   la clé publique, à mettre dans app/licence.gd
  python DEV_TOOLS/licence_signer.py signer --nom "Jane Doe" --email jane@example.com [--id COMMANDE]
                                                                 une clé ; notée dans licences_emises.csv (à côté)
  python DEV_TOOLS/licence_signer.py verifier "MBK1.xxxx.yyyy"  dit ce que la clé porte, et si elle est bonne
  python DEV_TOOLS/licence_signer.py essai                      une clé « Export check » (non notée) pour l'export
  python DEV_TOOLS/licence_signer.py vecteurs FICHIER.json      des vecteurs d'essai (clés JETABLES) pour test_vente

LE FORMAT (le même dans `app/licence.gd` — et, un jour, dans la fonction du site qui signe après Paddle) :
  MBK1.<charge en base64url sans « = »>.<signature en base64url sans « = »>
  la charge : du JSON UTF-8 {"product": "MarchingBlocks", "name", "email", "id", "issued": "AAAA-MM-JJ"}
  la signature : Ed25519 de  b"MBK1." + charge   (le préfixe signé : une signature d'un autre format ne sert pas ici)
"""
import argparse
import base64
import csv
import datetime
import json
import os
import secrets
import sys

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey
from cryptography.hazmat.primitives import serialization
from cryptography.exceptions import InvalidSignature

DOSSIER = os.path.join(os.path.expanduser("~"), ".marchingblocks")
PRIVEE = os.path.join(DOSSIER, "licence_ed25519_privee.hex")
REGISTRE = os.path.join(DOSSIER, "licences_emises.csv")
PREFIXE = "MBK1."
PRODUIT = "MarchingBlocks"


def b64url(o: bytes) -> str:
    return base64.urlsafe_b64encode(o).decode("ascii").rstrip("=")


def de_b64url(s: str) -> bytes:
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def brut(publique: Ed25519PublicKey) -> bytes:
    return publique.public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)


def lire_la_privee() -> Ed25519PrivateKey:
    if not os.path.isfile(PRIVEE):
        sys.exit(f"⚠ clé privée introuvable : {PRIVEE} — `generer` d'abord (une seule fois).")
    graine = bytes.fromhex(open(PRIVEE, encoding="ascii").read().strip())
    if len(graine) != 32:
        sys.exit(f"⚠ {PRIVEE} ne porte pas 32 octets.")
    return Ed25519PrivateKey.from_private_bytes(graine)


def signer_avec(privee: Ed25519PrivateKey, nom: str, email: str, ident: str, date: str) -> str:
    charge = json.dumps({"product": PRODUIT, "name": nom, "email": email, "id": ident, "issued": date},
                        ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    signature = privee.sign(PREFIXE.encode("ascii") + charge)
    return PREFIXE + b64url(charge) + "." + b64url(signature)


def lire_la_cle(cle: str, publique: Ed25519PublicKey):
    """(charge en dict, bonne ?) — la même lecture que `app/licence.gd`."""
    cle = "".join(cle.split())
    if not cle.startswith(PREFIXE) or cle.count(".") != 2:
        return None, False
    _, c, s = cle.split(".")
    charge, signature = de_b64url(c), de_b64url(s)
    try:
        publique.verify(signature, PREFIXE.encode("ascii") + charge)
        bonne = True
    except InvalidSignature:
        bonne = False
    return json.loads(charge.decode("utf-8")), bonne


def generer(_):
    if os.path.exists(PRIVEE):
        sys.exit(f"⚠ {PRIVEE} existe déjà : on ne l'écrase JAMAIS (les clés déjà vendues en dépendent).")
    os.makedirs(DOSSIER, exist_ok=True)
    graine = secrets.token_bytes(32)
    with open(PRIVEE, "w", encoding="ascii") as f:
        f.write(graine.hex())
    print("clé privée écrite :", PRIVEE, "— À SAUVEGARDER hors de ce PC, jamais dans un dépôt.")
    publique(None)


def publique(_):
    print(brut(lire_la_privee().public_key()).hex())


def signer(a):
    privee = lire_la_privee()
    ident = a.id or secrets.token_hex(6)
    date = datetime.date.today().isoformat()
    cle = signer_avec(privee, a.nom.strip(), a.email.strip(), ident, date)
    charge, bonne = lire_la_cle(cle, privee.public_key())
    assert bonne and charge["name"] == a.nom.strip(), "la clé signée ne se relit pas"
    neuf = not os.path.exists(REGISTRE)
    with open(REGISTRE, "a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if neuf:
            w.writerow(["date", "id", "nom", "email", "cle"])
        w.writerow([date, ident, charge["name"], charge["email"], cle])
    print(cle)


def essai(_):
    """Une clé d'essai au nom « Export check », NON notée dans le registre : l'export la fait vérifier par l'exe livré."""
    print(signer_avec(lire_la_privee(), "Export check", "", "essai-export", datetime.date.today().isoformat()))


def verifier(a):
    privee = lire_la_privee()
    charge, bonne = lire_la_cle(a.cle, privee.public_key())
    if charge is None:
        sys.exit("⚠ ce n'est pas une clé MarchingBlocks (MBK1.…)")
    print(json.dumps(charge, ensure_ascii=False, indent=1))
    print("SIGNATURE BONNE" if bonne else "⚠ SIGNATURE FAUSSE")
    sys.exit(0 if bonne else 1)


def vecteurs(a):
    """Des cas d'essai pour `DEV_TOOLS/test_vente.gd`, signés par Python `cryptography` (OpenSSL) avec des graines
    JETABLES : la preuve que l'Ed25519 de l'appli (Monocypher) est celui de tout le monde."""
    sortie = {"brut": [], "cles": []}
    for k in range(24):
        graine = secrets.token_bytes(32)
        privee = Ed25519PrivateKey.from_private_bytes(graine)
        message = secrets.token_bytes(k * 7)
        sortie["brut"].append({"graine": graine.hex(), "publique": brut(privee.public_key()).hex(),
                               "message": message.hex(), "signature": privee.sign(message).hex()})
    graine = secrets.token_bytes(32)
    privee = Ed25519PrivateKey.from_private_bytes(graine)
    sortie["graine_des_cles"] = graine.hex()
    sortie["publique_des_cles"] = brut(privee.public_key()).hex()
    for nom, email in [("Jane Doe", "jane@example.com"), ("Zoé Lefèvre-Ñúñez", "zoe@exemple.fr"),
                       ("株式会社テスト", "test@example.jp"), ('Quote "and" \\ backslash', "q@example.com")]:
        sortie["cles"].append({"nom": nom, "email": email,
                               "cle": signer_avec(privee, nom, email, secrets.token_hex(6), "2026-10-07")})
    with open(a.fichier, "w", encoding="utf-8", newline="\n") as f:
        json.dump(sortie, f, ensure_ascii=False, indent="\t")
        f.write("\n")
    print("écrit :", a.fichier)


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sp = p.add_subparsers(dest="commande", required=True)
    sp.add_parser("generer").set_defaults(f=generer)
    sp.add_parser("publique").set_defaults(f=publique)
    s = sp.add_parser("signer")
    s.add_argument("--nom", required=True)
    s.add_argument("--email", required=True)
    s.add_argument("--id", default="")
    s.set_defaults(f=signer)
    sp.add_parser("essai").set_defaults(f=essai)
    v = sp.add_parser("verifier")
    v.add_argument("cle")
    v.set_defaults(f=verifier)
    t = sp.add_parser("vecteurs")
    t.add_argument("fichier")
    t.set_defaults(f=vecteurs)
    a = p.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
