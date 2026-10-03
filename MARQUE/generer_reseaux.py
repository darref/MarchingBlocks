"""LES IMAGES DES COMPTES (Jordan, 4 octobre 2026 : « la partie création de comptes gratuits pour la com »).

Avatars et bannières aux tailles de chaque réseau, tirés de DEUX sources seulement : l'icône (`icone.png`) et le splash
signé (`splash.png`). On ne retouche jamais ces images à la main : on change la source, on relance ce script.

    python MARQUE/generer_reseaux.py

⚠ Les bannières 3:1 sont prises au CENTRE du splash : la signature (en bas à droite, collée par `composer_splash.py`)
n'y entre pas — une bannière se recadre selon l'écran, une signature coupée ferait plus de tort qu'aucune.
"""
from pathlib import Path

from PIL import Image

ICI = Path(__file__).parent
SORTIE = ICI / "reseaux"

AVATARS = {
    "avatar_400.png": 400,      # X
    "avatar_800.png": 800,      # YouTube, Bluesky, Reddit, TikTok
    "avatar_512.png": 512,      # Discord (icône du serveur)
}
# nom, largeur, hauteur — recadrées au centre du splash, puis mises à la taille
BANNIERES = [
    ("banniere_x_1500x500.png", 1500, 500),
    ("banniere_bluesky_3000x1000.png", 3000, 1000),
    ("banniere_youtube_2560x1440.png", 2560, 1440),
    ("banniere_discord_960x540.png", 960, 540),
    ("banniere_reddit_1920x384.png", 1920, 384),
]


def recadrer_au_centre(img: Image.Image, largeur: int, hauteur: int) -> Image.Image:
    rapport = largeur / hauteur
    w, h = img.size
    if w / h > rapport:
        nw = round(h * rapport)
        boite = ((w - nw) // 2, 0, (w - nw) // 2 + nw, h)
    else:
        nh = round(w / rapport)
        boite = (0, (h - nh) // 2, w, (h - nh) // 2 + nh)
    return img.crop(boite).resize((largeur, hauteur), Image.LANCZOS)


def main() -> None:
    SORTIE.mkdir(exist_ok=True)
    icone = Image.open(ICI / "icone.png").convert("RGBA")
    for nom, cote in AVATARS.items():
        # Un fond opaque : plusieurs réseaux remplacent la transparence par du blanc ou du noir au hasard de l'écran.
        fond = Image.new("RGBA", icone.size, (24, 26, 18, 255))
        fond.alpha_composite(icone)
        fond.convert("RGB").resize((cote, cote), Image.LANCZOS).save(SORTIE / nom)
    splash = Image.open(ICI / "splash.png").convert("RGB")
    for nom, largeur, hauteur in BANNIERES:
        recadrer_au_centre(splash, largeur, hauteur).save(SORTIE / nom)
    print("écrit :", ", ".join(sorted(p.name for p in SORTIE.glob("*.png"))))


if __name__ == "__main__":
    main()
