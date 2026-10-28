extends RefCounted
## Répartition fondée sur RDA / GateWorld ; projection latérale adaptée au jeu.
## https://www.rdanderson.com/stargate/cheyenne/index.htm
## https://www.gateworld.net/wiki/Stargate_Command
## Les étages non représentés sont sautés par l'ascenseur, pas renumérotés.
const WORLD := Vector2(1560, 1520)
const FLOOR_NUMBERS := [18, 21, 22, 24, 25, 27, 28]
const FLOORS := [205.0, 405.0, 605.0, 805.0, 1005.0, 1245.0, 1465.0]
const LIFT_X := 110.0
const GATE_LEVEL := 6
const BRIEFING_LEVEL := 5
const SPAWN := Vector2(1110, 1465)
const STAIR_BOTTOM := Vector2(540, 1465)
const STAIR_LANDING := Vector2(620, 1355)
const STAIR_TOP := Vector2(540, 1245)
const ROOMS := {
	"daniel": {"name": "LABORATOIRE DE DANIEL", "level": 0, "x": 470.0, "left": 210.0, "width": 740.0, "color": Color("ceaf83"), "npc": "JACKSON"},
	"archives": {"name": "ARCHIVES / TRADUCTIONS", "level": 0, "x": 1210.0, "left": 990.0, "width": 480.0, "color": Color("ceaf83"), "npc": ""},
	"infirmary": {"name": "INFIRMERIE", "level": 1, "x": 490.0, "left": 210.0, "width": 740.0, "color": Color("84c6bd"), "npc": "DR FRAISER"},
	"isolation": {"name": "ISOLEMENT MÉDICAL", "level": 1, "x": 1210.0, "left": 990.0, "width": 480.0, "color": Color("84c6bd"), "npc": ""},
	"mess": {"name": "MESS / CAFÉTÉRIA", "level": 2, "x": 490.0, "left": 210.0, "width": 740.0, "color": Color("c6ac7d"), "npc": ""},
	"kitchen": {"name": "CUISINE", "level": 2, "x": 1210.0, "left": 990.0, "width": 480.0, "color": Color("c6ac7d"), "npc": ""},
	"malp": {"name": "ATELIER MALP / UAV", "level": 3, "x": 490.0, "left": 210.0, "width": 740.0, "color": Color("94b9b6"), "npc": ""},
	"storage": {"name": "STOCKAGE LOGISTIQUE", "level": 3, "x": 1210.0, "left": 990.0, "width": 480.0, "color": Color("94b9b6"), "npc": ""},
	"team": {"name": "QUARTIERS SG-1", "level": 4, "x": 490.0, "left": 210.0, "width": 740.0, "color": Color("8cb59d"), "npc": "TEAL'C"},
	"lockers": {"name": "VESTIAIRES / ÉQUIPEMENT", "level": 4, "x": 1210.0, "left": 990.0, "width": 480.0, "color": Color("8cb59d"), "npc": ""},
	"office": {"name": "BUREAU DU GÉNÉRAL", "level": 5, "x": 365.0, "left": 210.0, "width": 300.0, "color": Color("d4ad65"), "npc": "HAMMOND"},
	"briefing": {"name": "BRIEFING", "level": 5, "x": 790.0, "left": 650.0, "width": 300.0, "color": Color("d4ad65"), "npc": ""},
	"armory": {"name": "ARMURERIE", "level": 6, "x": 365.0, "left": 210.0, "width": 300.0, "color": Color("caac78"), "npc": "SILER"},
	"control": {"name": "CONTRÔLE", "level": 6, "x": 790.0, "left": 650.0, "width": 300.0, "color": Color("7eafcb"), "npc": "HARRIMAN"},
	"gate": {"name": "SALLE DE LA PORTE", "level": 6, "x": 1110.0, "left": 980.0, "width": 490.0, "height": 396.0, "color": Color("80c6d8"), "npc": ""},
}


static func walk_limit(level: int) -> float:
	# Au 27, la salle de la porte est un vide en double hauteur, pas un couloir.
	return 930.0 if level == BRIEFING_LEVEL else 1450.0
