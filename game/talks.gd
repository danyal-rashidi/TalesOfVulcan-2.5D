class_name Talks extends RefCounted
# Who says what in Cinerea, from DIALOGUE.md: a line, then you pick Vulcan's answer from a few choices and they reply. He doesn't say the choice again, and his face stays out of it (Danyal). A choice can move their
# Trust, as DIALOGUE.md's tables say. A step is {"who": speaker, "line": text, "face": portrait} or {"choose": [{"label", "answer", "face", "trust", "drachma", "then"}]}.
# The lines marked Claude's call aren't in DIALOGUE.md yet: Tullus and the boy have no choices there, nor Cassia at her stall.
# A choice's "do" is awaited after its answer and before its "then".

const FIRST_LOOK: Array = [
	{"who": "Cassia", "line": "Who are you? You're either a deserter or a ghost."},
	{"choose": [
		{"label": "I don't know which.", "answer": "Well, that's honest, at least. Most men in this town lie before breakfast.", "trust": 5},
		{"label": "Does it matter? Your carriage is still standing.", "answer": "Fair. It'll matter to the raiders, mind. You've made yourself some friends today. The bad kind."},
		{"label": "Say nothing.", "answer": "Strong and silent. Grand. I've a camel just like you."}]},
	{"who": "Cassia", "line": "So what do they call you?"},
	{"choose": [
		{"label": "I... don't remember.", "answer": "You don't remember your own name? Aye, the desert does that to folk.", "trust": 5},
		{"label": "Call me whatever you like.", "answer": "Careful, love. I've called men worse things than you'd believe.", "face": "cassia_angry"},
		{"label": "Why do you care?", "answer": "I don't. But I like to know who I owe.", "trust": -5, "face": "cassia_angry"}]},
	{"who": "Cassia", "line": "Then I'll name you myself. Ignotus. The unknown one. It suits you."},
]
const AFTER_PURSE: Array = [
	{"who": "Cassia", "line": "Ten drachma for the carriage you just saved, and the lass inside it. Dinnae spend it all on the first ale you see."},
	{"choose": [
		{"label": "Thank you.", "answer": "Don't thank me yet. You've not seen the job board.", "trust": 5},
		{"label": "Ten? I saved the whole caravan.", "answer": "Ha! Now you're talking my language. Twelve, and that's robbery.", "trust": 5, "drachma": 2},
		{"label": "Keep them.", "answer": "You're either mad or a saint. Take them anyway. I don't keep debts.", "trust": 2}]},
]
const CASSIA_LEAVE: Array = [
	{"label": "What's the talk in the market?", "answer": "Folk at the market say a red light flew over three nights back, heading for Cinderwood, the black forest past the dunes. Like a falling star going the wrong way.", "then": [
		{"choose": [
			{"label": "That was no star.", "answer": "You say that like you've seen it before. Have you?", "trust": 2},
			{"label": "Where is Cinderwood?", "answer": "Three days east, past the last dunes, if you like walking. My caravan goes in a week, if you like camels."}]}]},
	{"label": "Goodbye.", "answer": "Don't die, you owe me."},
]
# In the shop (DIALOGUE.md "At Cassia's stall"), said in turn; NO_ROOM is Claude's call.
const BOUGHT: Array[String] = ["Pleasure doing business.", "Good choice. That'll keep you breathing."]
const SOLD: Array[String] = ["Rubbish, but I'll take it.", "Where did you find this? No, don't tell me."]
const BROKE := "You cannae afford that, love. Come back richer."
const NO_ROOM := "You've nae room for more, love. Drink one first."
# The raiders at her carriage: it's her they're after, a wealthy merchant, and her money (Danyal). Claude's lines.
const AT_THE_CARRIAGE: Array = [
	{"who": "Raider", "line": "Open up, merchant! We know who rides in there. Cassia of the caravans, and half the desert's gold with her."},
	{"who": "From the carriage", "line": "Half? Cheek. It's closer to two thirds. And that door cost more than your mother, so mind it."},
	{"who": "Raider", "line": "It's not your door we came for, love. It's you. There's folk would pay a king's ransom to have you back."},
	{"who": "Second raider", "line": "And the strongbox. Don't forget the strongbox."},
	{"who": "From the carriage", "line": "Lay a finger on either and I'll bill you for it."},
	{"who": "Raider", "line": "Drag her out."},
]
const LIVIA: Array = [
	{"who": "Livia", "line": "Please, sir. The jackals have taken the well. My boy's not had water since yesterday."},
	{"choose": [
		{"label": "Show me where.", "answer": "Thank you. Oh, thank you. It's past the old shrine.", "trust": 10},
		{"label": "What will you pay me?", "answer": "I have four drachma. It's all we've got.", "trust": -5, "then": [
			{"choose": [
				{"label": "That will do.", "answer": "", "trust": -10, "drachma": 4},
				{"label": "Keep it. Feed your boy.", "answer": "You're a strange one. Thank you.", "trust": 10}]}]}]},
]
const TULLUS: Array = [
	{"who": "Old Tullus", "line": "Forty years on this road and I never once got used to the heat."},
	{"choose": [
		{"label": "Why stay, then?", "answer": "Somebody's got to bring the water. Don't go near the tombs after dark, mind.", "trust": 2},
		{"label": "Say nothing.", "answer": "The sky's been blue three days now. Feels wrong, somehow."}]},
]
const BOY: Array = [
	{"who": "A boy", "line": "Are you a soldier? Where's your armour?"},
	{"choose": [
		{"label": "I lost it.", "answer": "My gran said the fire god lived in that colosseum. I said, Gran, it's a statue."},
		{"label": "Run along.", "answer": "That's him. The one Cassia found in the street!"}]},
]
const FORTUNA: Array = [
	{"who": "Fortuna", "line": "The camel looks at you, and goes on chewing."},
	{"choose": [
		{"label": "Pat the camel.", "answer": "She lets you. Just."},
		{"label": "Leave her be.", "answer": ""}]},
]

# Her greeting at the stall by Trust level (DIALOGUE.md "At Cassia's stall").
static func stall_greeting(trust: int) -> String:
	if trust < 0:
		return "You again. Coin first, chat later."
	if trust < 25:
		return "Ignotus. Buying, selling, or just blocking my light?"
	if trust < 60:
		return "There's my favourite ghost. I put something aside for you."
	return "Sit, sit. Fortuna missed you. I didn't, obviously."

# `shop` opens the shop at its page (0 buying, 1 selling) and returns when he leaves it. The two answers are to her "Buying, selling, or...".
static func at_stall(trust: int, shop: Callable) -> Array:
	var bye: Array = [{"who": "Cassia", "line": "Mind the jackals."}]
	var trade: Array = [{"label": "I'm buying.", "answer": "", "do": shop.bind(0), "then": bye}, {"label": "I'm selling.", "answer": "", "do": shop.bind(1), "then": bye}]
	return [{"who": "Cassia", "line": stall_greeting(trust)}, {"choose": trade + CASSIA_LEAVE}]

static func _face(who: String) -> String:
	match who:
		"Cassia": return "cassia"
		"Old Tullus": return "tullus"
		"Livia": return "livia"
	return ""

static var _faces := {}    # loaded once: a new texture shows white for its first frame

static func _portrait(key: String) -> Texture2D:
	if not _faces.has(key):
		var path := "res://art/portraits/%s.png" % key
		_faces[key] = ImageTexture.create_from_image(Image.load_from_file(path)) if key != "" and FileAccess.file_exists(path) else null
	return _faces[key]

static func say(hud: Hud, who: String, line: String, face := "") -> void:
	hud.portrait = _portrait(face if face != "" else _face(who))
	hud.say(who, line)
	await hud.line_done
	hud.portrait = null

# Plays `steps`. `who`: whose Trust the choices move and who answers, as Journey names them.
static func play(hud: Hud, steps: Array, who: String) -> void:
	for step: Dictionary in steps:
		if step.has("line"):
			await say(hud, step["who"], step["line"], step.get("face", ""))
		else:
			var options: Array = step["choose"]
			var labels := PackedStringArray()
			for o: Dictionary in options:
				labels.append(o["label"])
			var pick: int = await hud.choose(labels)
			var o: Dictionary = options[pick]
			Journey.add_trust(who, int(o.get("trust", 0)))
			Journey.drachma += int(o.get("drachma", 0))
			if o["answer"] != "":
				await say(hud, who, o["answer"], o.get("face", ""))
			if o.has("do"):
				await o["do"].call()
			if o.has("then"):
				await play(hud, o["then"], who)
