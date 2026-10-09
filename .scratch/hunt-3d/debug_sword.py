import os, sys
sys.path.insert(0, r"C:\AI\dauntless-lite\tools\models")
import bpy
import importlib
import common

# Reconstrói a espada sem exportar, e mede cada peça.
import weapon_sword  # executa build() na importação

for obj in bpy.context.scene.objects:
    if obj.type != "MESH":
        continue
    zs = [ (obj.matrix_world @ v.co).z for v in obj.data.vertices ]
    xs = [ (obj.matrix_world @ v.co).x for v in obj.data.vertices ]
    print("PIECE %-8s z=[%.3f, %.3f] x=[%.3f, %.3f]" % (obj.name, min(zs), max(zs), min(xs), max(xs)))
