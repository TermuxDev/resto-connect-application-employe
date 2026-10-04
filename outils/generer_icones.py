"""Génère les icônes de l'application (Android et iOS) à partir du logo Resto Connect.

Le logo est celui affiché dans l'application : deux anneaux concentriques, en blanc sur le vert de la marque.
À relancer seulement si le logo change :
    ../SERVEUR/.venv/Scripts/python outils/generer_icones.py
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw

RACINE = Path(__file__).resolve().parent.parent
VERT_CLAIR = (42, 132, 86)     # #2A8456
VERT_FONCE = (15, 61, 39)      # #0F3D27
BLANC = (255, 255, 255)
SURECHANTILLON = 4             # Dessin en grand puis réduction : bords lisses.


def degrade(taille):
    """Fond en dégradé diagonal, comme les cartes vertes de l'interface."""
    fond = Image.new("RGB", (taille, taille))
    pixels = fond.load()
    for y in range(taille):
        for x in range(taille):
            t = (x + y) / (2 * (taille - 1))
            pixels[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(VERT_CLAIR, VERT_FONCE))
    return fond


def anneaux(image, centre, diametre):
    """Le logo : anneau extérieur épais, anneau intérieur plus fin (proportions du widget Logo)."""
    dessin = ImageDraw.Draw(image)
    for proportion, epaisseur in ((1.0, 0.09), (0.42, 0.075)):
        rayon = diametre * proportion / 2
        trait = max(1, round(diametre * epaisseur))
        dessin.ellipse(
            (centre - rayon, centre - rayon, centre + rayon, centre + rayon),
            outline=BLANC, width=trait,
        )


def icone(taille, logo=0.56, fond=True):
    """Icône carrée : logo centré occupant `logo` de la largeur ; fond vert ou transparent."""
    grande = taille * SURECHANTILLON
    image = degrade(grande).convert("RGBA") if fond else Image.new("RGBA", (grande, grande), (0, 0, 0, 0))
    anneaux(image, grande / 2, grande * logo)
    return image.resize((taille, taille), Image.LANCZOS)


def android():
    res = RACINE / "android/app/src/main/res"
    for dossier, taille in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        icone(taille).convert("RGB").save(res / f"mipmap-{dossier}/ic_launcher.png")
        # Icône adaptative (Android 8+) : premier plan 108 dp, logo dans la zone sûre centrale (66 dp).
        premier_plan = icone(round(taille * 108 / 48), logo=0.40, fond=False)
        premier_plan.save(res / f"mipmap-{dossier}/ic_launcher_foreground.png")

    (res / "mipmap-anydpi-v26").mkdir(exist_ok=True)
    (res / "mipmap-anydpi-v26/ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@drawable/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n',
        encoding="utf-8",
    )
    (res / "drawable/ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- Fond de l\'icône adaptative : dégradé vert de la marque. -->\n'
        '<shape xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <gradient android:angle="315" android:startColor="#2A8456" android:endColor="#0F3D27" />\n'
        '</shape>\n',
        encoding="utf-8",
    )


def ios():
    dossier = RACINE / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for image in json.loads((dossier / "Contents.json").read_text(encoding="utf-8"))["images"]:
        cote = float(image["size"].split("x")[0]) * int(image["scale"].rstrip("x"))
        # iOS refuse la transparence dans les icônes : image RGB, sans canal alpha.
        icone(round(cote)).convert("RGB").save(dossier / image["filename"])


if __name__ == "__main__":
    android()
    ios()
    print("Icônes générées.")
