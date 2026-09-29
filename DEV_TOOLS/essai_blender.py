# L'ESSAI BLENDER, côté Blender — voir essai_blender.gd pour le déroulé.
#   blender --background --factory-startup --python DEV_TOOLS/essai_blender.py -- <dossier>
#
# Il fait ce que ferait l'artiste, et rien de plus : importer, puis exporter en .glb avec les réglages
# PAR DÉFAUT. Aucun « Apply », aucune fusion de sommets : c'est ce que le trancheur doit savoir lire.
import sys

import bpy

dossier = sys.argv[sys.argv.index("--") + 1]


def vider():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def exporter(nom):
    bpy.ops.export_scene.gltf(filepath=f"{dossier}/{nom}", export_format="GLB")


vider()
bpy.ops.wm.obj_import(filepath=f"{dossier}/temoin.obj")
for objet in bpy.context.scene.objects:
    if objet.type == "MESH":
        print(f"TEMOIN {objet.name} : {len(objet.data.polygons)} faces, "
              f"UV {[couche.name for couche in objet.data.uv_layers]}, rotation {tuple(objet.rotation_euler)}")
exporter("temoin_blender.glb")

vider()
bpy.ops.import_scene.gltf(filepath=f"{dossier}/faux.glb")
for objet in bpy.context.scene.objects:
    if objet.type == "MESH":
        images = [n.image.name for m in objet.data.materials if m and m.use_nodes
                  for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image]
        print(f"FAUX {objet.name} : {len(objet.data.polygons)} faces, "
              f"UV {[couche.name for couche in objet.data.uv_layers]}, images {images}")
exporter("faux_blender.glb")
print("BLENDER : fini")
