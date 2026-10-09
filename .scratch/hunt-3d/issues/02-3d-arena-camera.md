# 02: Arena 3D, câmera em terceira pessoa e movimento

**What to build:** o jogo abre em 3D. Um boneco provisório (cápsula) anda pela
Arena com WASD relativo à câmera, o mouse orbita a câmera, e a rede continua
funcionando igual.

**Blocked by:** 01

**Status:** done

- [x] Cena 3D: chão circular da Arena, limite visível, luz e céu
- [x] Caçador provisório (cápsula) posicionado pelo Instantâneo da Sim (x, z)
- [x] Câmera orbita com o mouse (yaw livre, pitch limitado), atrás do ombro
- [x] WASD anda relativo à câmera; a Sim segue recebendo um vetor no plano
- [x] A mira enviada à Sim é o yaw da câmera
- [x] Esquiva, corrida, Golpes e Fôlego funcionam (HUD mínimo: 3 barras)
- [x] Hospedar/Entrar funcionam em 3D; 2 processos se veem andando
- [x] O desenho 2D (arena_screen, behemoth_view) é removido
- [x] Captura de tela 3D no screenshot.gd
