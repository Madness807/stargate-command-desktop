extends RefCounted
## Les données du jeu : l'équipe, l'armurerie, les règles de progression, puis les planètes
## (adresses de la série), leurs ennemis, leurs gardiens et leur ambiance.
## Rien ici ne change en cours de partie : l'état de la partie est dans game_state.gd.

## Indices 1–39, ordre de l'anneau terrestre ; index 0 inutilisé.
## Référence : stargate-sgc.fandom.com/wiki/Glyph (Voie lactée).
const GLYPH_NAMES := ["", "Origine · Terre", "Crater", "Virgo", "Boötes", "Centaurus", "Libra", "Serpens Caput", "Norma", "Scorpius", "Corona Australis", "Scutum", "Sagittarius", "Aquila", "Microscopium", "Capricornus", "Piscis Austrinus", "Equuleus", "Aquarius", "Pegasus", "Sculptor", "Pisces", "Andromeda", "Triangulum", "Aries", "Perseus", "Cetus", "Taurus", "Auriga", "Eridanus", "Orion", "Canis Minor", "Monoceros", "Gemini", "Hydra", "Lynx", "Cancer", "Sextans", "Leo", "Leo Minor"]

# ---------- L'équipe ----------

## n : nom court · hp : PV au niveau 1 · range : portée de tir en cases
const MEMBERS := {
	"oneill": {"n": "O'Neill", "hp": 30, "range": 7, "role": "Colonel · chef de SG-1", "arm": "P90",
		"ability": "Grenade", "skill": "Lance une grenade à 5 cases au plus : dégâts sur une zone de 3×3."},
	"carter": {"n": "Carter", "hp": 26, "range": 7, "role": "Major · astrophysicienne", "arm": "P90 · zat",
		"ability": "Tir de zat", "skill": "Un tir de zat'n'ktel qui étourdit la cible pendant 3 secondes."},
	"daniel": {"n": "Jackson", "hp": 24, "range": 7, "role": "Docteur · archéologue, linguiste", "arm": "P90",
		"ability": "Diversion", "skill": "Désoriente les ennemis pendant 3 secondes ; contre un gardien, la traduction réduit sa puissance de feu de 25 %."},
	"tealc": {"n": "Teal'c", "hp": 36, "range": 6, "role": "Jaffa · ancien Premier Prime d'Apophis", "arm": "Lance jaffa",
		"ability": "Kel'no'reem", "skill": "Médite pour rendre 40 % de ses PV à son symbiote."},
	"bratac": {"n": "Bra'tac", "hp": 40, "range": 6, "role": "Maître jaffa de Chulak", "arm": "Lance jaffa",
		"ability": "Maître de la lance", "skill": "Frappe à la lance au contact : gros dégâts, l'ennemi est sonné."},
}
const CORE_TEAM := ["oneill", "carter", "daniel", "tealc"]
## Bra'tac rejoint SG-1 quand ce nombre de missions est accompli (Chulak libérée)
const BRATAC_AFTER := 2

# ---------- La progression ----------

const XP_PER_LEVEL := 40         # XP pour passer un niveau : XP_PER_LEVEL × niveau actuel
const HP_PER_LEVEL := 6
const START_NAQ := 20
const START_KITS := 2
const KIT_PRICE := 15
const KIT_MAX := 6


## Multiplicateurs des PV et des dégâts ennemis selon la difficulté (réglage « difficulty »)
const DIFFICULTY := {
	"easy": {"hp": 0.75, "dmg": 0.7},
	"normal": {"hp": 1.0, "dmg": 1.0},
	"hard": {"hp": 1.3, "dmg": 1.25},
}


static func kit_heal(level: int) -> int:
	return 12 + 3 * level


# ---------- L'armurerie : l'armement (pour toute l'équipe, lances comprises) et les protections ----------

## req : nombre de missions accomplies pour débloquer l'objet
const WEAPONS := [
	{"n": "P90 standard", "dmg": 0, "hit": 0, "c": 0, "req": 0, "txt": "L'arme réglementaire de SG-1."},
	{"n": "P90 à visée holographique", "dmg": 1, "hit": 8, "c": 60, "req": 0, "txt": "+1 dégât, +8 % de précision."},
	{"n": "Munitions perforantes", "dmg": 3, "hit": 8, "c": 140, "req": 0, "txt": "+3 dégâts : elles traversent les armures jaffas."},
	{"n": "Fusils asgards", "dmg": 6, "hit": 12, "c": 320, "req": 5, "txt": "+6 dégâts, +12 %. Un cadeau de Thor, après Hala."},
]
const ARMORS := [
	{"n": "Treillis", "armor": 0, "c": 0, "req": 0, "txt": "Le treillis de l'Air Force."},
	{"n": "Gilets tactiques", "armor": 1, "c": 50, "req": 0, "txt": "-1 dégât par tir reçu."},
	{"n": "Gilets pare-balles en céramique", "armor": 2, "c": 120, "req": 0, "txt": "-2 dégâts par tir reçu."},
	{"n": "Armures jaffas renforcées", "armor": 4, "c": 260, "req": 2, "txt": "-4 dégâts. Offertes par Bra'tac, après Chulak."},
]

# ---------- Les planètes ----------

const EARTH := [28, 26, 5, 36, 11, 29]

const PLANETS := [
	{"n": "Abydos", "adr": [27, 7, 15, 32, 12, 30], "gate": true,
		"brief": "Kasuf nous a fait prévenir : Klorel, le Goa'uld qui a pris Skaara pour hôte, a été vu près de la pyramide de Râ.",
		"ground": [Color("d9a560"), Color("e6b673")], "far": Color("b8874e"), "obj": "rock", "lair": "pyramid",
		"sky_top": Color("5f8fcf"), "sky_hz": Color("f2c48a"), "sun": Color("ffe2b0"), "sun_e": 1.5, "fog": Color("e8c08a"), "fx": "",
		"foes": [{"n": "Gardes Serpent", "a": "serpent", "pow": 8, "xp": 8, "naq": 8}, {"n": "Mastadge enragé", "a": "beast", "pow": 6, "xp": 6, "naq": 4}],
		"boss": {"n": "Klorel", "a": "klorel", "guard": "serpent", "pow": 18, "xp": 30, "naq": 35, "q": "Agenouillez-vous devant votre dieu !"}},
	{"n": "Chulak", "adr": [9, 2, 23, 15, 37, 20], "gate": true,
		"brief": "Maître Bra'tac nous a transmis l'adresse : Apophis rassemble ses Jaffas autour de son temple sur Chulak.",
		"ground": [Color("4f8a3c"), Color("5c9a46")], "far": Color("3d6b2e"), "obj": "tree", "lair": "temple",
		"sky_top": Color("4a86c8"), "sky_hz": Color("cfe6dc"), "sun": Color("fff4dd"), "sun_e": 1.3, "fog": Color("a8c8b8"), "fx": "",
		"foes": [{"n": "Jaffas d'Apophis", "a": "jaffa", "pow": 12, "xp": 12, "naq": 12}, {"n": "Prêtre jaffa", "a": "priest", "pow": 11, "xp": 12, "naq": 14}],
		"boss": {"n": "Apophis", "a": "apophis", "guard": "serpent", "pow": 26, "xp": 55, "naq": 60, "q": "Vous allez souffrir pour votre insolence, Tau'ri."}},
	{"n": "Cimmeria", "adr": [11, 35, 22, 17, 6, 26], "gate": true,
		"brief": "Gairwyn appelle à l'aide : depuis que le marteau de Thor est détruit, Heru'ur a envahi Cimmeria.",
		"ground": [Color("e8eef4"), Color("d6e0ea")], "far": Color("aebccc"), "obj": "pine", "lair": "camp",
		"sky_top": Color("7d9cc8"), "sky_hz": Color("e6eef5"), "sun": Color("f0f4ff"), "sun_e": 1.1, "fog": Color("dde6ee"), "fx": "snow",
		"foes": [{"n": "Jaffas d'Heru'ur", "a": "jaffa2", "pow": 16, "xp": 16, "naq": 16}, {"n": "Gardes Horus", "a": "horus", "pow": 17, "xp": 17, "naq": 17}],
		"boss": {"n": "Heru'ur", "a": "heruur", "guard": "horus", "pow": 34, "xp": 85, "naq": 90, "q": "Je suis Heru'ur, fils de Râ. Prosternez-vous."}},
	{"n": "Netu", "adr": [], "gate": false,
		"brief": "Netu n'est pas reliée au réseau des portes. Un Tel'tak tok'ra vous déposera par les anneaux de transport.",
		"ground": [Color("3a1a12"), Color("4a2216")], "far": Color("1a0a06"), "obj": "lava", "lair": "fortress",
		"sky_top": Color("120303"), "sky_hz": Color("5a1208"), "sun": Color("ff7a40"), "sun_e": 0.8, "fog": Color("3a0e06"), "fx": "embers",
		"foes": [{"n": "Prisonniers de Netu", "a": "prisoner", "pow": 19, "xp": 20, "naq": 18}, {"n": "Gardes de Bynarr", "a": "brute", "pow": 21, "xp": 22, "naq": 22}],
		"boss": {"n": "Sokar", "a": "sokar", "guard": "brute", "pow": 42, "xp": 120, "naq": 130, "q": "Je suis le diable de Netu, et vous êtes en enfer."}},
	{"n": "Hala", "adr": [28, 2, 22, 3, 27, 9], "gate": true,
		"brief": "Thor nous prévient : les Réplicateurs piégés sur Hala ont pris forme humaine. Leur meneur, le Cinquième, construit une sortie.",
		"ground": [Color("4a5060"), Color("3e4452")], "far": Color("1c2028"), "obj": "block", "lair": "tower",
		"sky_top": Color("0b0e16"), "sky_hz": Color("2a3142"), "sun": Color("c0d0ff"), "sun_e": 0.8, "fog": Color("1a2030"), "fx": "",
		"foes": [{"n": "Réplicateurs", "a": "replic", "pow": 22, "xp": 24, "naq": 25}, {"n": "Essaim de Réplicateurs", "a": "swarm", "pow": 24, "xp": 28, "naq": 28}],
		"boss": {"n": "le Cinquième", "a": "cinq", "guard": "replic", "pow": 50, "xp": 170, "naq": 180, "q": "Je voulais seulement vous comprendre."}},
	{"n": "Dakara", "adr": [16, 28, 3, 8, 33, 4], "gate": true,
		"brief": "Anubis marche sur Dakara avec ses Kulls pour s'emparer de l'arme des Anciens. Bonne chance, SG-1.",
		"ground": [Color("c9a06a"), Color("b98f5c")], "far": Color("8a6a42"), "obj": "column", "lair": "temple2",
		"sky_top": Color("c8603a"), "sky_hz": Color("f6c27a"), "sun": Color("ffc080"), "sun_e": 1.4, "fog": Color("e8a870"), "fx": "",
		"foes": [{"n": "Guerriers Kull", "a": "kull", "pow": 28, "xp": 35, "naq": 35}, {"n": "Jaffas d'Anubis", "a": "jaffa3", "pow": 26, "xp": 30, "naq": 30}],
		"boss": {"n": "Anubis", "a": "anubis", "guard": "kull", "pow": 60, "xp": 0, "naq": 0, "q": "Je suis au-delà de la mort elle-même. Inclinez-vous."}},
]
