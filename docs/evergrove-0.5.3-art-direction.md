# Evergrove 0.5.3 — Grid & World Beautification

## Visão
Referências fornecidas: ícones de frutas com contorno escuro e brilho cartunesco; vila arborizada com loja e caminhos; parque ribeirinho com bancos, postes e cercas; praça em desníveis com água e flores; jardim com fonte, gazebo e sebes; praça comercial iluminada ao pôr do sol. Reinterpretar composição e materiais, sem copiar marcas, personagens ou edifícios de Animal Crossing. Preservar o menu aprovado e a UI 0.5.2.

## Planta conceitual por regiões (coordenadas X/Z existentes)
Z positivo fica na parte inferior deste esquema; posições aproximadas, a validar contra colisões e rotas.
```
                         Z negativo
  bosque oeste      bairro norte        bairro nordeste     lago
    (-24,-11)       (-12,-6; 0,-11)      (10,-8)           (22,-7)
  pomar             praça (0,2)          trilha            margem
  (-20,5..15)       jardim central       (14,6)           (17..27)
                    horta (3,5)          casa (13,13)
  caminho oeste     armazém (-3,10)      parque sul
                    casa jogador (-7,19)
                         Z positivo
```

| Área | Direção visual | Regras funcionais |
|---|---|---|
| Praça central | Pavimento de pedra quente, árvore central ou fonte pequena, bancos, flores em pares e postes. Moldura verde, centro livre. | Não bloquear o ponto de chegada, rotas NPC ou recursos. Manter uma faixa de circulação de pelo menos duas células. |
| Armazém | Fachada própria com telhado azul, toldo listrado, vitrine, caixas de madeira e vasos; pequeno largo e caminho até a porta. | Preservar identificação, interação, porta e interiores. |
| Jardim | Composição de sebes, flores em três cores, gazebo, fonte e bancos, em uma clareira reservada após auditoria de ocupação. | Manter as 12 plantações existentes separadas e acessíveis. |
| Margem do lago | Passeio de terra/pedra, bancos orientados à água, postes, cerca baixa descontínua, gramíneas e pedras. Água azul com ondas/reflexos já existentes. | Lago e margens perigosas bloqueiam construção; manter passagens e colisão. |
| Bairro residencial | Pequenos jardins frontais, cercas, caminhos e caixas de correio; paletas de telhado distintas. | Conservar todas as portas, IDs das casas, horários NPC e rotas. |
| Pomar e bosque | Copas densas em camadas, troncos orgânicos, frutos visíveis, clareiras e trilhas. | Manter pontos de coleta e navegação; reservar células para recursos. |
| Quintal e parque sul | Casa do jogador, gramado para personalização, bancos, iluminação acolhedora, áreas amplas para novas decorações. | Migrar a grade local e móveis sem perda; não ocupar a porta. |

## Grade global
- Usar uma célula de 1 unidade de mundo inicialmente, coerente com a grade de construção existente. Coordenadas inteiras X/Z e conversão única world_to_cell/cell_to_world; alinhar à origem e tratar negativos.
- Grade invisível durante exploração; sobreposição visível e câmera elevada somente no modo construção. Jogador continua livre.
- Criar registro de footprints por ID com largura, profundidade, rotação e camada; exemplos: caminho/flor/poste 1×1, banco 2×1, árvore 2×2, mesa 2×2, fonte 3×3, casa 5×4, loja 6×5. Ajustar após medir cada modelo.
- Separar solo/caminho, ocupação sólida, recursos e zonas protegidas. Não permitir sobreposição sólida, água, portas, rotas essenciais ou fora do mapa. Caminhos não impedem caminhada; plantas e mobiliário seguem suas regras.
- Registrar cenário fixo, casas, lago, horta e recursos existentes antes de permitir construção global. Desenhar a área total verde/vermelha; rotação troca dimensões; mover e cancelar preservam estado atomicamente.
- Migrar saves com versão de esquema, preservando IDs, posições de móveis locais, inventário, NPCs e conteúdo dos baús. Para conflitos, manter dados e resolver de modo não destrutivo. Não reposicionar casas automaticamente sem atualizar portas, destinos e navegação.
- Elevações, escadas e cascatas são referência visual futura: só introduzir terreno em níveis se colisões e navegação forem implementadas e testadas. Não criar desníveis meramente visuais que bloqueiem jogadores.

## Direção artística
- Paleta: verde folha, pinho profundo, creme, terracota, azul céu e dourado de iluminação. Saturação viva sem filtro cinza dominante.
- Modelos: formas arredondadas e proporções estilizadas, silhuetas claras; folhas em aglomerados, telhas e tábuas reconhecíveis, postes e bancos com detalhes. Não utilizar geometria pesada para detalhes que podem ser materiais.
- Ícones: contorno escuro da cor do objeto, brilho superior esquerdo, sombras simples, transparência, leitura em 32 px. Começar pelos 11 itens existentes.
- Materiais: grama albedo repetível; depois madeira, pedra, telhado e tecido. Fal para arte e referências, Blender para geometria e UVs, Godot para materiais, animações e luz.
- Personagens: olhos legíveis, cabelo com volume, roupas com materiais coerentes; manter personalização, melhorar gestos e expressões sem romper os rigs procedurais.
- Manter quatro presets, MultiMesh, culling e sombras seletivas; Leve não usa textura extra de grama. Medir FPS e estabilidade no S24 Ultra, alvo 60 FPS, sem prometer desempenho não testado.

## Ordem de implementação
1. Preparar pipeline artístico e importar recursos aprovados.
2. Implementar registro global de ocupação e testes independentes.
3. Migrar cenário estático, grade de construção e saves; testar portas e NPCs.
4. Reformular praça, loja, jardins, margem, bairro e pomar por etapas.
5. Melhorar modelos/ícones e validar desempenho visual em cada preset.
6. Rodar testes de regressão e publicar 0.5.3 com versionCode superior a 8 e a mesma assinatura permanente.

## Aceitação
Testar rotação e limites de footprints, conflitos com água/portas, movimentação livre, salvar/reabrir móveis e baús, construção sem perder objetos, acesso a loja e casa, coleta e horta, navegação NPC, menu e HUD intactos. Testar atualização APK por cima da 0.5.2.1 no dispositivo real.
