extends RefCounted

const NAMES := {"sun":"Ensolarado","rain":"Chuva","wind":"Ventania","storm":"Tempestade"}
# Rain intensity, wind and cloud cover. Storms develop from wind or rain.
const LEVELS := {"sun":Vector3(0,.08,0),"rain":Vector3(.55,.28,.62),"wind":Vector3(0,.84,.24),"storm":Vector3(1,1,1)}
const NEXT := {"sun":["wind","rain"],"wind":["sun","sun","rain","storm"],"rain":["sun","wind","storm"],"storm":["rain","wind"]}
var kind: String="sun"
var levels: Vector3=LEVELS.sun
var rng:=RandomNumberGenerator.new()
var remaining: float

func _init() -> void:
	rng.randomize()
	remaining=rng.randf_range(55,120)

func rainy() -> bool:
	return kind=="rain" or kind=="storm"

func spawn_multiplier(group: StringName) -> float:
	if group in [&"insects",&"butterflies"] and kind=="wind": return 2.25
	if group==&"fish" and kind=="storm": return 2.0
	return 1.0

func next_period(phase: float) -> void:
	var choices: Array=NEXT[kind]
	kind=choices[rng.randi_range(0,choices.size()-1)]
	# Cool early hours can prolong rain, clear afternoons can last longer.
	var duration:=rng.randf_range(46,132)
	if (rainy() and phase>0.65) or (kind=="sun" and phase<0.48): duration*=1.2
	remaining=duration

func elapse(seconds: float) -> void:
	remaining-=seconds
	levels=levels.lerp(LEVELS[kind],1.0-exp(-seconds*.46))

func pack() -> Dictionary:
	return {"kind":kind,"remaining":remaining,"rng":str(rng.state),"levels":[levels.x,levels.y,levels.z]}

func restore(data: Dictionary) -> void:
	if not NAMES.has(data.get("kind")): return
	kind=data.kind
	remaining=clampf(float(data.get("remaining",60)),0.001,240)
	var values=data.get("levels")
	levels=LEVELS[kind]
	if values is Array and values.size()==3:
		levels=Vector3(values[0],values[1],values[2]).clamp(Vector3.ZERO,Vector3.ONE)
	if str(data.get("rng","")).is_valid_int(): rng.state=int(data.rng)
