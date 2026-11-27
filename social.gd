extends RefCounted

const Bag = preload("res://backpack.gd")
# Name, favorite gift, order quantity, reward, roof color, morning, afternoon, night, friendship.
const PEOPLE := [
	["Lia","flower",2,16,"b76349","As flores abrem antes das janelas. Já viu as do lago?","Guardei as pétalas caídas para tingir uma fita.","Deixei um ramo secando junto da janela.","Separei a flor mais bonita do canteiro para te mostrar."],
	["Davi","wood",2,20,"597e80","Bati numa tábua e acordei até o pomar.","Escuta esse banco. Madeira boa quase canta.","Guardo o martelo cedo. A vizinhança agradece.","Quando eu fizer outra cadeira, vou tirar a medida da sua varanda."],
	["Nina","fruit",2,18,"84905d","Provei a primeira fruta. Azedinha, do jeito que gosto!","Uma pitada de sal deixa a fruta ainda mais doce.","Tem compota esfriando no parapeito.","Minha receita leva casca também. Só você sabe disso."],
	["Bento","stone",2,18,"946e57","O sereno faz os veios das pedras brilharem.","Achei uma pedra lisa. Cabe certinho na palma.","Organizo minhas pedras por lembrança, não por tamanho.","Essa pedrinha azul me lembra o dia em que você chegou."],
	["Íris","turnip",1,24,"96778c","Abri meu caderno numa folha limpa. O que será que brota hoje?","Desenhei as folhas da horta antes que a luz mudasse.","À noite passo os esboços a limpo.","Quer ver meu caderno? Deixei uma página para a sua horta."]
]
const BUY := {"carrot_seed":4,"potato_seed":4,"wheat_seed":4,"tomato_seed":4,"berry_seed":4,"seed":3,"axe":35,"pick":35,"hoe":30,"can":30,"wood":7,"stone":7,"twig":3,"fruit":8,"flower":6}
const SELL := {"carrot":15,"potato":20,"wheat":15,"tomato":25,"berry":20,"seed":1,"wood":4,"stone":4,"twig":1,"fruit":5,"flower":3,"turnip":12}
var coins := 35
var friends := {}

func record(i: int) -> Dictionary:
	var key := str(i)
	if not friends.has(key):
		friends[key] = {"bond":0,"talk":0,"gift":0,"quest":false,"done":0,"visits":0}
	return friends[key]

func talk(i: int, day: int, hour: int, indoors: bool) -> String:
	var p: Array = PEOPLE[i]
	var f := record(i)
	if f.talk != day:
		f.talk = day
		f.bond = mini(100,int(f.bond)+2)
	f.visits = int(f.visits)+1
	if f.quest and int(f.visits)%3 == 0: return "Ainda procuro %d × %s. Conseguiu encontrar?" % [p[2],Bag.NAMES[p[1]]]
	if f.bond >= 20 and int(f.visits)%2 == 0: return p[8]
	if indoors or hour >= 19 or hour < 7: return p[7]
	return p[5] if hour < 12 else p[6]

func gift(i: int,bag,day: int) -> String:
	var f := record(i)
	if f.gift == day: return "Já recebi seu presente hoje!"
	var item: String = bag.held()
	if item.is_empty() or item in Bag.TOOLS: return "Escolha um presente na barra rápida."
	var favorite: bool = item == PEOPLE[i][1]
	bag.use_one()
	f.bond = mini(100,int(f.bond)+(8 if favorite else 4))
	f.gift = day
	return "É meu favorito! Como você adivinhou?" if favorite else "Que gentileza. Vou guardar com carinho."

func quest(i: int,bag,day: int) -> String:
	var f := record(i)
	var p: Array = PEOPLE[i]
	if f.done == day: return "Volte amanhã para outro pedido."
	if not f.quest:
		f.quest = true
		return "Combinado! Vou esperar por aqui na vila."
	if not bag.remove_items(p[1],p[2]): return "Ainda faltam itens para a entrega."
	f.quest = false
	f.done = day
	f.bond = mini(100,int(f.bond)+6)
	coins += int(p[3])
	return "Pedido entregue · +%d folhas" % p[3]

func trade(bag,id: String,buying: bool) -> String:
	var name_text: String = Bag.NAMES[id]
	if buying:
		var price: int = BUY[id]
		if coins < price: return "Folhas insuficientes."
		if not bag.add(id,1): return "Mochila cheia."
		coins -= price
		return "Comprou "+name_text
	if not bag.remove_items(id,1): return "Você não tem esse produto."
	coins += int(SELL[id])
	return "Vendeu "+name_text
