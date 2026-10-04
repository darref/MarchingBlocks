"""LES IMAGES DES COMPTES (Jordan, 4 octobre 2026 : « la partie création de comptes gratuits pour la com »).

Avatars et bannières aux tailles de chaque réseau, tirés de DEUX sources seulement : l'icône (`icone.png`) et le splash
signé (`splash.png`). On ne retouche jamais ces images à la main : on change la source, on relance ce script.

    python MARQUE/generer_reseaux.py

⚠ Les bannières 3:1 sont prises au CENTRE du splash : la signature (en bas à droite, collée par `composer_splash.py`)
n'y entre pas — une bannière se recadre selon l'écran, une signature coupée ferait plus de tort qu'aucune.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

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


# LE STUDIO (Jordan, 4 octobre 2026) : le compte public est SpannerGames, et rien de MarchingBlocks ne se montre avant
# le 21 décembre (stratégie réseaux sociaux). Avatar et bannières SANS produit : le logo (`spannergames.png`), son fond
# violet, le nom. Les images ci-dessus (icône, splash) attendent la levée du silence.
VIOLET = (40, 25, 67)
COULEUR_NOM = (236, 226, 204)   # celle de la signature (`composer_splash.py`)
POLICES = ["C:/Windows/Fonts/segoeuisl.ttf", "C:/Windows/Fonts/segoeui.ttf",
           "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]
STUDIO_AVATARS = {"studio_avatar_400.png": 400, "studio_avatar_800.png": 800}
STUDIO_BANNIERES = [
    ("studio_banniere_x_1500x500.png", 1500, 500),
    ("studio_banniere_bluesky_3000x1000.png", 3000, 1000),
    ("studio_banniere_youtube_2560x1440.png", 2560, 1440),
    ("studio_banniere_reddit_1920x384.png", 1920, 384),
]


def _police(taille):
    for chemin in POLICES:
        try:
            return ImageFont.truetype(chemin, taille)
        except OSError:
            pass
    return ImageFont.load_default(taille)


def _logo(logo_plein: Image.Image) -> Image.Image:
    """Le S en clé, détouré : l'or garde son alpha, le violet devient transparent."""
    rgb = logo_plein.convert("RGB")
    masque = Image.eval(rgb.split()[1], lambda g: 0 if g < 60 else min(255, (g - 60) * 3))
    rgba = rgb.convert("RGBA")
    rgba.putalpha(masque)
    return rgba.crop(rgba.getbbox())


def studio(sortie: Path) -> None:
    plein = Image.open(ICI / "spannergames.png").convert("RGB")
    # Le logo n'occupe qu'un tiers de son carré : on resserre pour qu'il tienne le CERCLE de l'avatar (X, Bluesky…).
    c = 760
    w, h = plein.size
    serre = plein.crop(((w - c) // 2, (h - c) // 2, (w + c) // 2, (h + c) // 2))
    for nom, cote in STUDIO_AVATARS.items():
        serre.resize((cote, cote), Image.LANCZOS).save(sortie / nom)
    logo = _logo(plein)
    for nom, largeur, hauteur in STUDIO_BANNIERES:
        img = Image.new("RGBA", (largeur, hauteur), VIOLET + (255,))
        # Tout dans la bande centrale : chaque réseau rogne ses bannières selon l'écran (YouTube : 1546 × 423 au centre).
        bande = min(hauteur, round(largeur * 0.274)) if largeur / hauteur < 2 else hauteur
        hl = round(bande * 0.56)
        l = logo.resize((round(logo.width * hl / logo.height), hl), Image.LANCZOS)
        police = _police(round(bande * 0.20))
        nom_studio = "SpannerGames"
        bt = police.getbbox(nom_studio)
        ecart = round(bande * 0.12)
        total = l.width + ecart + (bt[2] - bt[0])
        x0 = (largeur - total) // 2
        img.alpha_composite(l, (x0, (hauteur - hl) // 2))
        d = ImageDraw.Draw(img)
        tx = x0 + l.width + ecart - bt[0]
        ty = (hauteur - (bt[3] - bt[1])) // 2 - bt[1]
        d.text((tx, ty), nom_studio, font=police, fill=COULEUR_NOM + (255,))
        img.convert("RGB").save(sortie / nom)


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
    studio(SORTIE)
    print("écrit :", ", ".join(sorted(p.name for p in SORTIE.glob("*.png"))))


if __name__ == "__main__":
    main()
