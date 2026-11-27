# Pipeline de arte — fal + Blender + Godot

A integração não executa IA dentro do APK, não usa rede em runtime e não altera o workflow de assinatura. O fal é uma fonte de imagens durante o desenvolvimento; o Blender continua produzindo os modelos GLB. Somente PNGs aprovados entram no jogo.

## Fluxo
1. Gere referências e artes no fal (ou com outra ferramenta). Use os prompts em `tools/art_pipeline.py` e o plano visual em `docs/evergrove-0.5.3-art-direction.md`.
2. Revise manualmente qualidade, originalidade, consistência e licença do modelo. Remova o fundo dos ícones e confira as bordas repetíveis das texturas.
3. Instale Python 3.9+ e Pillow para preparar arquivos. Para geração opcional pela API, instale também fal-client e configure FAL_KEY apenas localmente. A geração pode consumir créditos.
4. Importe os PNGs aprovados no repositório, nunca a chave da API. O Godot importa as imagens automaticamente; a compilação atual já inclui os recursos do projeto.

Exemplos:
```sh
python -m pip install Pillow
python tools/art_pipeline.py prompt icon fruit
python tools/art_pipeline.py install icon fruit --source /caminho/fruta-transparente.png
python tools/art_pipeline.py install texture grass --source /caminho/grama-seamless.png
# Opcional, com fal-client e FAL_KEY configurada localmente:
python -m pip install fal-client
python tools/art_pipeline.py generate icon fruit --output art-staging/fruit.png
```

## Contrato de assets
- `assets/art/icons/<id>.png`: quadrado 128×128, RGBA, fundo transparente, margem e leitura a 32 px. IDs: axe, pick, hoe, can, seed, wood, stone, twig, fruit, flower, turnip. Todos os locais que usam hud.icon_for recebem a arte nova automaticamente.
- `assets/art/textures/grass.png`: 512×512 RGB, repetível, albedo sem iluminação pintada. No terreno, misturada à cor original; preset Leve mantém a cor procedural.
- Ausência do PNG: ícones vetoriais e terreno procedural atuais continuam funcionando.
- Outros materiais, retratos e modelos poderão seguir o mesmo padrão depois de testes. Não alteramos os modelos Blender nesta preparação.
- Não commitar chaves, imagens de referência não licenciadas, saídas brutas ou arquivos de staging.

Nenhuma geração fal foi executada nesta etapa; os PNGs finais ainda precisam ser produzidos e aprovados. O script opcional usa o endpoint fal-ai/flux/schnell como ponto de partida, não como garantia de textura perfeitamente repetível ou transparência.
