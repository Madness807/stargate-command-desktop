extends RefCounted
## Objectifs locaux à l'opération ; aucune libération n'est validée avant extraction.

var contacted := false
var translated := false
var shield_disabled := false
var recovered := false
var extracted := false

func objective(compact: bool = false) -> String:
	if compact:
		if extracted:
			return "SKAARA ÉVACUÉ · RÉUSSITE"
		if recovered:
			return "4/4 · Extraire Skaara au DHD"
		if translated:
			return "3/4 · Neutraliser Klorel" if shield_disabled else "3/4 · Couper le bouclier de Klorel"
		if contacted:
			return "2/4 · Protéger la traduction de Daniel"
		return "1/4 · Rejoindre Kasuf"
	if extracted:
		return "SKAARA ÉVACUÉ · OPÉRATION RÉUSSIE"
	if recovered:
		return "4/4 · Rejoindre le DHD avec Skaara"
	if translated:
		return "3/4 · Bouclier coupé · neutraliser Klorel" if shield_disabled else "3/4 · Neutraliser Klorel · Carter doit couper son bouclier"
	if contacted:
		return "2/4 · Protéger Daniel pendant la traduction de la console"
	return "1/4 · Rejoindre Kasuf au sud de la zone d'arrivée"

func next_id() -> String:
	if recovered:
		return "extraction"
	if translated:
		return "klorel"
	if contacted:
		return "translation"
	return "kasuf"


func guidance() -> String:
	if recovered:
		return "Skaara récupéré : rejoignez le DHD puis confirmez le retour. La libération d'Abydos et l'accès à Chulak ne sont validés qu'à cette extraction."
	if translated:
		return "Klorel est invulnérable tant que son bouclier est actif. Lancez l'action de Carter à la console et protégez-la pendant 6 secondes. Elle ne tire pas pendant ce travail ; un nouvel ordre l'interrompt. Concentrez ensuite les tirs sur Klorel."
	if contacted:
		return "Lancez la traduction de Daniel à la console : protégez-le pendant 6 secondes. Il ne tire pas pendant ce travail ; un nouvel ordre l'interrompt. En combat, mettez en pause tactique pour choisir les cibles. Les capacités économisent des soins ; les grands obstacles bloquent les tirs."
	return "Touchez le terrain pour déplacer SG-1 ; le bouton Objectif rejoint Kasuf. En combat, sélectionnez un membre ou SG-1, puis une cible. La pause tactique permet de donner des ordres sans laisser avancer le temps. Repli ramène à la porte sans résoudre le combat ; soins utilisés et blessures restent acquis."
