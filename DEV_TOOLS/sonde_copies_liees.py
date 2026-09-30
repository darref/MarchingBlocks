# SONDE — le témoin lié dans Blender, côté Blender (voir sonde_copies_liees.gd pour le déroulé).
#   blender --background --factory-startup --python DEV_TOOLS/sonde_copies_liees.py -- <dossier>
#
# Ce que ferait l'artiste : importer, retoucher UNE occurrence de la tuile la plus partagée, exporter en
# .glb (réglages PAR DÉFAUT). Deux fois : import par défaut, puis import avec « Merge Vertices ».
import sys

import bpy

dossier = sys.argv[sys.argv.index("--") + 1]

for fusion, sortie in ((False, "temoin_lie_blender.glb"), (True, "temoin_lie_blender_soude.glb")):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f"{dossier}/temoin_lie.glb", merge_vertices=fusion)
    objets = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    donnees = {}
    for o in objets:
        donnees.setdefault(o.data.name, []).append(o)
    nom, copies = max(donnees.items(), key=lambda e: len(e[1]))
    print(f"BLENDER merge_vertices={fusion} : {len(objets)} objets, {len(donnees)} maillages ; "
          f"« {nom} » partagé par {len(copies)}, {len(copies[0].data.vertices)} sommets")
    une = copies[0]
    avant = [tuple(o.matrix_world @ o.data.vertices[0].co) for o in copies[:3]]
    une.data.vertices[0].co.z += 0.05   # retouche UNE occurrence
    apres = [tuple(o.matrix_world @ o.data.vertices[0].co) for o in copies[:3]]
    print(f"BLENDER retouche de {une.name} : les autres suivent ? {[a != b for a, b in zip(avant, apres)]}")
    bpy.ops.export_scene.gltf(filepath=f"{dossier}/{sortie}", export_format="GLB")
print("BLENDER : fini")
