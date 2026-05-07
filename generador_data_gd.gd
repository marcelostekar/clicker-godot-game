extends Node

func _ready():
	generar_json_global()

func generar_json_global():
	# Lista extendida para que tengas volumen de juego
	var base_paises = {
		"argentina": [46.0, 0.72], "brasil": [214.0, 0.75], "mexico": [126.0, 0.76],
		"eeuu": [333.0, 0.92], "china": [1412.0, 0.77], "india": [1408.0, 0.65],
		"alemania": [83.0, 0.94], "japon": [125.0, 0.93], "rusia": [143.0, 0.82],
		"nigeria": [213.0, 0.54], "espana": [47.0, 0.90], "francia": [67.0, 0.90],
		"uk": [67.0, 0.93], "italia": [59.0, 0.89], "canada": [38.0, 0.93],
		"australia": [25.0, 0.95], "noruega": [5.4, 0.96], "suiza": [8.7, 0.96],
		"sudafrica": [59.0, 0.71], "egipto": [109.0, 0.73], "corea_sur": [51.0, 0.92],
		"indonesia": [273.0, 0.70], "turquia": [85.0, 0.83], "uruguay": [3.4, 0.82],
		"chile": [19.0, 0.85], "colombia": [51.0, 0.76], "peru": [33.0, 0.77]
	}

	var json_final = {}

	for id_id in base_paises:
		var pob = base_paises[id_id][0] 
		var idh = base_paises[id_id][1] 

		# Fórmula: El costo escala fuerte con el IDH para dar dificultad
		var costo = int(pow(idh * 12, 5.2) + (pob * 20))
		# Producción: Mezcla de gente + riqueza
		var produccion = int((pob * 5) * idh)
		
		json_final[id_id] = {
			"nombre": id_id.capitalize().replace("_", " "),
			"habitantes": int(pob * 1000000),
			"costo_conquista": costo,
			"produccion_pasiva": produccion,
			"dificultad": stepify(idh * 5, 0.1),
			"descripcion": "Nivel de desarrollo: " + str(idh)
		}

	# Esto imprime el JSON listo para copiar
	print(JSON.stringify(json_final, "\t"))
	print("--- GENERACIÓN FINALIZADA ---")
