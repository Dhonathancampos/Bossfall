# Dauntless Lite

Recriação simplificada e jogável do Dauntless (Phoenix Labs, 2019–2025), que foi
desligado em 29/05/2025 e, por ser só online, deixou de existir.

**Quem abre a partida é o servidor.** Não há serviço externo: a máquina do
Anfitrião roda a Simulação e os outros Caçadores se conectam a ela.

- Onda 1 (em construção): 2D visto de cima, Godot 4.7 / GDScript. Ver `ROADMAP.md`.
- Onda 2 (depois): recriação 3D fiel, usando a Simulação da Onda 1 como base.

## Jogar

Abrir o projeto na Godot 4.7 e apertar F5. Ou, pela linha de comando:

    godot --path .

**Na primeira vez**, importe o projeto antes de rodar os testes, para que a
Godot registre os nomes de classe:

    godot --headless --path . --import

## Testes

    godot --headless --path . --script res://tests/run_tests.gd

Sem addon: a Godot mais este repositório são tudo que é preciso.

## Modelos 3D (Onda 2)

Todo asset 3D nasce de um script Python em `tools/models/`, rodado pelo
Blender headless (4.2 LTS portable em `C:\Blender`). Os `.glb` em
`assets/models/` são artefatos de build, nunca editados à mão.

    powershell -File tools/models/build_all.ps1

Ver um modelo gerado sem abrir o editor:

    godot --path . --script res://tools/preview_model.gd -- res://assets/models/totem.glb saida.png idle

## Conferir o visual sem abrir o editor

    godot --path . --script res://tools/screenshot.gd -- saida.png

## Controles

O jogo é 3D em terceira pessoa: o mouse gira a câmera e "frente" é para onde
você olha.

| Tecla | Ação |
| ----- | ---- |
| WASD | Mover (relativo à câmera) |
| Mouse | Girar a câmera / mirar |
| Shift | Correr (gasta Fôlego) |
| Espaço | Rolar (gasta Fôlego, concede Invulnerabilidade) |
| Botão esquerdo | Golpe leve (encadeia em Combo) |
| Botão direito | Golpe pesado (segurar: arma a Rajada do Martelo) |
| R | Recarregar o Martelo (R de novo na janela certa = recarga rápida) |
| F | Especial da arma (com o Éter cheio) |
| Esc | Sair para o menu |

## As armas (estilo clássico)

- **Espada** — combo equilibrado. Especial **Valor**: 8s de dano e velocidade
  extras, e cada Golpe conectado emite uma **Onda** com o Elemento da arma.
- **Martelo** — Impacto puro com **4 munições**: segurar o pesado arma a
  **Rajada Concussiva** (1 munição por segundo segurando, escala por munição);
  o terceiro leve + pesado descarrega tudo no **Estouro Aéter**. Recarregue
  com R — na janela certa, a recarga cronometrada termina na hora; na errada,
  trava mais tempo.
- **Lâminas Correntes** — leves rapidíssimos que enchem o **Momentum** (até 3
  pips); o pesado de longe é o **Gancho** que puxa você até o Behemoth, e
  colado é o **Golpe de Corrente**, que gasta todos os pips. Especial **Dança
  da Ceifadora**: giro contínuo.

## Os Behemoths

- **Gnasher** — o quadrúpede direto: morde, investe, rabada, pisão.
- **Bastião** — o tanque: Partes blindadas seguram o dano da Vida a 15% até a
  placa quebrar (sempre vaza algo, nunca zero). A Cauda-maça é a única carne
  exposta; quebrar a Carapaça atrasa o Rolamento dele para sempre.

## A Caçada

Ao hospedar, um **Gnasher** nasce na Arena. Ele persegue quem mais o irritou,
pinta no chão a área de cada ataque antes de desferi-lo, e entra em **Fúria**
abaixo de 45% de Vida.

Rolar dentro da janela de Invulnerabilidade atravessa o ataque inteiro sem
levar dano.

**Provisório:** com a Vida zerada o Caçador fica Abatido e levanta sozinho
depois de alguns segundos. O sistema de verdade — Fichas de Reviver,
companheiro levantando, derrota — chega no ticket 10.

## Multijogador

Quem clica em **Hospedar** roda a Simulação e é a verdade final. O endereço da
máquina aparece na tela; os outros clicam em **Entrar** e digitam esse
endereço. Até 4 Caçadores. Jogar sozinho é o mesmo caminho: hospedar e não
esperar ninguém.

Conferir a rede com dois processos, sem abrir janela:

    godot --headless --path . --script res://tools/netcheck.gd -- host 14
    godot --headless --path . --script res://tools/netcheck.gd -- join 127.0.0.1 10

## Onde está o quê

| Caminho | O que é |
| ------- | ------- |
| `src/sim/` | A Simulação: todas as regras de jogo. Sem tipo de cena nenhum. |
| `src/game/` | Apresentação: desenha o Instantâneo e lê teclado e mouse. |
| `tests/` | Testes da Simulação, rodados sem janela. |
| `CONTEXT.md` | Glossário do projeto. |
| `ROADMAP.md` | As duas ondas. |
| `.scratch/core-hunt/` | Spec e tickets da Onda 1. |
