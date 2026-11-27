# Evergrove — 0.5.2 · Quality of Life

Simulador de vida rural em desenvolvimento. Godot 4.4.1 / GDScript. Simulador 3D estilizado, câmera ortográfica inclinada, colisões e joystick touchscreen. WASD ou setas no PC.

## Menu principal
O jogo abre em uma vista cinematográfica da vila. Jogar inicia ou continua automaticamente o progresso salvo. Opções oferece quatro níveis gráficos, volume geral, volume da música do menu e informações de controles. As opções ficam salvas no dispositivo. O relógio da vila e o save não são alterados enquanto estiver no menu. Durante o jogo, o menu de pausa oferece retorno ao menu principal.

## Como jogar
Use WASD/setas ou o joystick. Selecione um dos seis espaços rápidos por toque ou com 1–6. Aproxime-se de um recurso e toque na ação indicada ou pressione E. Abra a mochila com I ou pelo botão. Escolha o item e depois o destino para reorganizar os 24 espaços.

A horta fica a leste do ponto inicial. Use enxada, sementes e regador nessa ordem. Um nabo amadurece após duas viradas de dia com rega. Colhê-lo devolve duas sementes. Cada dia dura três minutos de jogo ativo. Recursos silvestres reaparecem pela manhã. O jogo salva automaticamente no dispositivo.

## Vida na vila
Aproxime-se de um morador e use E ou o botão de interação. A primeira conversa e um presente por dia aumentam a amizade, até dez corações. Para presentear, equipe o item antes da conversa. Aceite um pedido e volte com a quantidade combinada para receber folhas. De manhã e à tarde os moradores visitam pontos diferentes. À noite você os encontra em casa.

O armazém tem toldo listrado e fica ao sul da praça. Entre pela porta e aproxime-se do balcão para comprar ou vender. Para sair de qualquer prédio, volte ao tapete junto à entrada. O salvamento inclui a sala atual, amizades, pedidos e saldo.

## Minha casa
A casa de telhado azul fica ao sul da praça. Na cama, use a ação de dormir para amanhecer. No interior, Lar permite ampliar o cômodo por 70 folhas. Lar (B no teclado) também abre a oficina e a aparência. Objetos fabricados ficam no catálogo de construção.

Na planta da casa ou do quintal, toque para escolher um quadrado e arraste para mover a câmera. Gire e confirme a prévia verde. Para mover ou remover, escolha “Selecionar móvel colocado” e toque no objeto. Cancelar desfaz a edição em andamento. Cada baú tem 36 espaços e precisa estar vazio para ser removido.

## Android
Abra a aba Actions, selecione Android APK e baixe o artefato Evergrove-Android após uma compilação bem-sucedida. Extraia o ZIP e instale o APK de depuração. O protótipo ainda não foi validado em aparelho real.

## Modelos 3D do Blender
O workflow Android APK gera os GLBs em `assets/models/generated/` antes da importação do Godot. O Blender não é necessário no dispositivo. Casas da vila (sete paletas), árvores comuns, pinheiros, árvores frutíferas e bancos usam malhas importadas, agrupadas espacialmente via MultiMesh. Personagens usam malhas Blender para cabeça, tronco, membros, sapatos e cabelo, mantendo materiais personalizáveis e animação procedural existente. Colisões e salvamentos continuam independentes das malhas. Móveis construídos, interiores e outros objetos ainda usam os modelos anteriores. Sem GLBs, a versão de desenvolvimento local conserva a geometria procedural como fallback. Para gerar localmente, execute `blender --background --factory-startup --python-exit-code 1 --python tools/generate_blender_assets.py -- --game-assets` antes da importação do Godot. O workflow separado Blender - Generate Evergrove Assets continua gerando as prévias PNG dos três modelos de demonstração.

## Interface 0.5.2
Diálogos dos moradores aparecem na parte inferior, com texto progressivo, som suave e gesto do personagem. Toque no diálogo ou use E para revelar o texto, depois escolha presentear, pedir tarefa ou encerrar. A mochila usa ícones vetoriais, destaque de seleção e indicação de espaços; a ação contextual só aparece quando disponível. Armazém, oficina e baú usam a mesma identidade visual e mostram informações de capacidade e recursos. O formato de save permanece inalterado.
