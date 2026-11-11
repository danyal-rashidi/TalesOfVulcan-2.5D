extends Node
# Autoload Journey: what Vulcan carries, remembers and has seen, from Cinerea on. The names, paths and costs are STORY.md's ("Memories: how Vulcan levels up").

signal changed

const ITEMS := {
	&"iron_sword": {"name": "Iron Sword", "tab": 0, "slot": &"weapon", "icon": 0, "sell": 5, "text": "A legionary's short sword, pitted but sound. It was wrenched from his tomb."},
	&"new_sword": {"name": "New Iron Sword", "tab": 0, "slot": &"weapon", "icon": 13, "price": 25, "sell": 12, "damage": 1.25, "look": "vulcan_new_sword", "text": "Fresh from the smith: no pits, and a true edge. It bites a quarter harder than the legionary's old blade."},
	&"red_flask": {"name": "Red Flask", "tab": 0, "slot": &"", "icon": 2, "price": 6, "text": "Heals. Press 1 to drink, even on the move."},
	&"green_flask": {"name": "Green Flask", "tab": 0, "slot": &"", "icon": 3, "price": 4, "text": "Restores stamina. Press 2 to drink, even on the move."},
	&"hammer_head": {"name": "Hammer Head", "tab": 2, "slot": &"", "icon": 6, "text": "A broken hammer head from the legionary's tomb. It feels familiar in the hand."},
	&"jackal_pelt": {"name": "Jackal Pelt", "tab": 0, "slot": &"", "icon": 8, "sell": 3, "text": "Mangy, and still warm. Cassia buys these."},
	&"scorpion_sting": {"name": "Scorpion Sting", "tab": 0, "slot": &"", "icon": 9, "sell": 5, "text": "Someone pays for the venom. Cassia would know who."},
	&"raider_buckle": {"name": "Raider's Buckle", "tab": 0, "slot": &"", "icon": 10, "sell": 8, "text": "Good bronze off a bad man's belt. Cassia buys these."},
	&"copper_ring": {"name": "Copper Ring", "tab": 0, "slot": &"ring", "icon": 11, "price": 20, "sell": 10, "stamina": 30.0, "text": "A desert charm against tiring. 30 more stamina while you wear it."},
	&"bronze_amulet": {"name": "Bronze Amulet", "tab": 0, "slot": &"amulet", "icon": 12, "price": 30, "sell": 15, "health": 25.0, "text": "An old temple charm, from Cassia's quieter trade. 25 more health while you wear it."},
}
# What a skill does when he uses it, for those he can learn so far. How long, when the blow lands, how far he leaps: Claude's call.
const ABILITIES := {
	"Hammer Blow": {"sheet": "hammer_blow", "time": 1.02, "land": 0.6, "damage": 40.0, "fire_damage": 55.0, "range": 8.0, "cost": 30.0, "cooldown": 30.0},    # hold its key to choose where, let go to leap there (Danyal)
	"Ice Spears": {"sheet": "ice_snap", "time": 2.7, "launch": 2.0, "damage": 40.0, "slow": 4.0, "cost": 30.0, "cooldown": 30.0},    # Elvis's: about 2 s to the launch, 4 s of slow, 30 s to cool (Danyal). Five spears share Hammer Blow's plain 40, so all five land for that. Its cost as Hammer Blow's: Claude's call
}
const TABS: Array[String] = ["Items", "Materials", "Key Items"]
const SLOTS: Array[StringName] = [&"weapon", &"helmet", &"armour", &"boots", &"ring", &"amulet"]
const COSTS: Array[int] = [0, 1, 3, 5, 8]
const PATHS: Array[Dictionary] = [
	{"id": &"hammer", "name": "The Hammer", "skills": ["Hammer Blow", "Repair Armour", "Tempered Steel", "Forge Anywhere", "Master Smith"]},
	{"id": &"bell", "name": "The Bell", "skills": ["Rallying Shout", "Healing Prayer", "Silver Tongue", "Call to Arms", "Beacon of the Faithful"]},
	{"id": &"spark", "name": "The Spark", "skills": ["Fire-Imbued Sword", "Burning Dodge", "Ember Shield", "Flame Wave", "Living Flame"]},
	{"id": &"statue", "name": "The Statue", "skills": ["Leaping Sword Slam", "Bronze Skin", "Ground Shockwave", "Unbreakable Stance", "Colossus"]},
	{"id": &"merchant", "name": "The Merchant", "skills": ["Parry", "Counter-Strike", "Read the Blow", "Riposte Flurry", "Resist the Crown"]},
	{"id": &"name", "name": "The Name", "skills": ["Molten Breath", "Magma Dive", "Eruption", "Firestorm", "Full Fire Form"]},
]
# Region id (the red channel of art/ui/map_regions.png, over 40), its name, and where its name and marker go on the map.
const REGIONS: Array[Dictionary] = [
	{"id": &"mountains", "name": "The Mountains", "at": Vector2(0.5, 0.2)},
	{"id": &"boreas", "name": "Boreas", "at": Vector2(0.3, 0.42)},
	{"id": &"cinderwood", "name": "Cinderwood", "at": Vector2(0.8, 0.5)},
	{"id": &"desert", "name": "The Desert", "at": Vector2(0.5, 0.74)},
	{"id": &"cinerea", "name": "Cinerea", "at": Vector2(0.8, 0.94)},
]
const SAVE := "user://save.cfg"
# What a save keeps of him. Not hammer_upgraded: only play_fire_hammer.bat sets it, and Continue mustn't turn it off. Claude's call
const KEPT: Array[String] = ["bag", "drachma", "embers", "equipped", "memories", "visited", "here", "trust", "ability_slots"]

var bag := {}             # item id -> how many
var drachma := 0
var embers := 0
var equipped := {}        # slot -> item id
var memories: Array[StringName] = []
var visited: Array[StringName] = []
var here := &""           # the region Vulcan is in, marked on the map
var trust := {}           # who -> -100 to 100, from what he says to them (DIALOGUE.md)
var ability_slots := {&"ability_f": "", &"ability_q": ""}    # the skills on F and Q, by name
var hammer_upgraded := "fire_hammer" in OS.get_cmdline_user_args()    # Hammer Blow burns and bites harder. Forging at an anvil will set this; it isn't built, so until then only play_fire_hammer.bat does
var story := {}    # Cinerea's finished beats and where he picks up, from the save: Continue hands it over and Cinerea takes it once, as Dev.landing is

func reset() -> void:
	bag.clear()
	equipped.clear()
	memories.clear()
	visited.clear()
	drachma = 0
	embers = 0
	here = &""
	trust.clear()
	ability_slots = {&"ability_f": "", &"ability_q": ""}
	hammer_upgraded = false
	story = {}

# Him, and Cinerea's `beats`, into the save (study item 10: Cinerea saves at each beat).
func save_to(beats: Dictionary, path := SAVE) -> void:
	var cfg := ConfigFile.new()
	for key in KEPT:
		cfg.set_value("journey", key, get(key))
	cfg.set_value("cinerea", "story", beats)
	cfg.save(path)

# The save back into him, over whatever he has; false if there's none. Leaves hammer_upgraded alone.
func load_from(path := SAVE) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	for key in KEPT:
		var v: Variant = cfg.get_value("journey", key, get(key))
		if typeof(v) != typeof(get(key)):
			continue    # a hand-edited or broken value keeps what he has
		if v is Array:
			(get(key) as Array).assign(v)    # memories and visited are typed
		else:
			set(key, v)
	# An old save can't crash a newer build: what it names that no longer exists is dropped.
	for id: Variant in bag.keys():
		if not ITEMS.has(id):
			bag.erase(id)
	for slot: Variant in equipped.keys():
		if not ITEMS.has(equipped[slot]):
			equipped.erase(slot)
	for slot: Variant in ability_slots:
		if not ABILITIES.has(ability_slots[slot]):
			ability_slots[slot] = ""
	var s: Variant = cfg.get_value("cinerea", "story", {})
	story = s if s is Dictionary else {}
	return true

func add_trust(who: String, by: int) -> void:
	trust[who] = clampi(int(trust.get(who, 0)) + by, -100, 100)

func add_item(id: StringName, count := 1) -> void:
	bag[id] = int(bag.get(id, 0)) + count
	changed.emit()

func remove_item(id: StringName) -> void:
	bag[id] = int(bag.get(id, 0)) - 1
	if bag[id] <= 0:
		bag.erase(id)
	changed.emit()

# Puts it on, or takes it off if it's on. False if it can't be worn.
func toggle_equip(id: StringName) -> bool:
	var slot: StringName = ITEMS[id]["slot"]
	if slot == &"" or not bag.has(id):
		return false
	if equipped.get(slot) == id:
		equipped.erase(slot)
	else:
		equipped[slot] = id
	changed.emit()
	return true

func has_weapon() -> bool:
	return equipped.has(&"weapon")

# How much harder the sword in his hand bites than the one from the tomb.
func sword_scale() -> float:
	return float(ITEMS[equipped[&"weapon"]].get("damage", 1.0)) if has_weapon() else 1.0

# The art/ folder that draws him with what's in his hand.
func look() -> String:
	return ITEMS[equipped[&"weapon"]].get("look", "vulcan_human") if has_weapon() else "vulcan_human"

# What everything he wears adds to `stat` ("health", "stamina").
func gear_bonus(stat: String) -> float:
	var total := 0.0
	for id: StringName in equipped.values():
		total += float(ITEMS[id].get(stat, 0.0))
	return total

# DIALOGUE.md's Trust table: higher prices when she's wary, discounts once she likes him. How much is Claude's call.
func price_scale() -> float:
	var t := int(trust.get("Cassia", 0))
	if t < 0:
		return 1.25
	if t < 25:
		return 1.0
	return 0.9 if t < 60 else 0.8

func buy_price(id: StringName) -> int:
	return maxi(1, roundi(int(ITEMS[id]["price"]) * price_scale()))

func sell_price(id: StringName) -> int:
	return maxi(1, roundi(int(ITEMS[id]["sell"]) / price_scale()))


# A memory opens its path, with the path's first skill already learned (STORY.md). The rest are forged at an anvil.
func remember(path: StringName) -> void:
	if path not in memories:
		memories.append(path)
		for p: Dictionary in PATHS:    # what he's just learned goes on the first free key, so it works at once
			if p["id"] == path and ABILITIES.has(p["skills"][0]):
				for slot: StringName in ability_slots:
					if ability_slots[slot] == "":
						ability_slots[slot] = p["skills"][0]
						break
		changed.emit()

# A learned skill goes on F, then on Q, then off. Each key holds one.
func cycle_ability(skill: String) -> void:
	if ability_slots[&"ability_f"] == skill:
		ability_slots[&"ability_f"] = ""
		ability_slots[&"ability_q"] = skill
	elif ability_slots[&"ability_q"] == skill:
		ability_slots[&"ability_q"] = ""
	else:
		ability_slots[&"ability_f"] = skill
	changed.emit()

# Where a skill's icon is in art/ui/skills.png: each path's five, one path after another.
func skill_icon(skill: String) -> int:
	for p in PATHS.size():
		var at: int = PATHS[p]["skills"].find(skill)
		if at >= 0:
			return p * 5 + at
	return -1

func is_learned(path: int, skill: int) -> bool:
	return skill == 0 and PATHS[path]["id"] in memories

func visit(region: StringName) -> void:
	here = region
	if region not in visited:
		visited.append(region)
		changed.emit()
