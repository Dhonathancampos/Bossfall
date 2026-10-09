# 01: Pipeline Blender → Godot

**What to build:** um comando que gera um modelo 3D por script e ele aparece
dentro da Godot. É a fundação de toda a arte do jogo: provado isso, modelo
vira código.

**Blocked by:** None (can start immediately)

**Status:** done

- [x] Blender 4.2 portable funcional em C:\Blender, rodando headless
- [x] tools/models/common.py: utilidades compartilhadas (malha low-poly,
      materiais por paleta, rig básico, exportação .glb)
- [x] Um modelo de prova gerado por script, com uma animação, exportado para
      assets/models/
- [x] tools/models/build_all.ps1 regenera todos os modelos
- [x] A Godot importa o .glb sem erro e as animações têm os nomes esperados
- [x] Teste headless: o .glb existe, importa e contém as animações
