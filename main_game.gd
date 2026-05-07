extends Node2D

# Variables de Economía
var influencia = 0.0
var influencia_por_segundo = 0.0
var energia_actual = 100.0
var energia_maxima = 100.0
var regeneracion_energia_base = 5.0
var poder_click_actual = 1.0

# Almacenamiento de Datos
var datos_paises = {}
var habilidades = {}

func _ready():
	cargar_paises()
	# Inicializar la UI
	actualizar_ui_puntos()
	$InterfazFija/ProgressBar.max_value = energia_maxima
	$InterfazFija/ProgressBar.value = energia_actual

func _process(delta):
	# 1. Regenerar Energía
	if energia_actual < energia_maxima:
		energia_actual += regeneracion_energia_base * delta
		$InterfazFija/ProgressBar.value = energia_actual
	
	# 2. Sumar Influencia Pasiva
	influencia += influencia_por_segundo * delta
	
	# 3. Actualizar la etiqueta de puntos (Label)
	$InterfazFija/Label.text = "Influencia: " + str(int(influencia))

func cargar_paises():
	if FileAccess.file_exists("res://paises.json"):
		var file = FileAccess.open("res://paises.json", FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			datos_paises = json.data
			print("JSON de países cargado: ", datos_paises.size(), " países.")
		file.close()
	else:
		print("ERROR: No se encontró paises.json")

func actualizar_ui_puntos():
	$InterfazFija/Label.text = "Influencia: " + str(int(influencia))

# --- Función para los botones del mapa ---
func _on_pais_clickeado(id_pais):
	if datos_paises.has(id_pais):
		var data = datos_paises[id_pais]
		# Rellenamos el panel (Asegurate que estos nombres de nodos existan)
		$InterfazFija/PanelInfoPais/TextoInfo.text = data["nombre"] + "\n\n" + data["descripcion"]
		$InterfazFija/PanelInfoPais/CostoLabel.text = "Costo: " + str(data["costo_conquista"])
		
		# Guardamos el ID en el panel para el botón de compra
		$InterfazFija/PanelInfoPais.set_meta("pais_id", id_id)
		$InterfazFija/PanelInfoPais.show()

# --- Función para el botón de Conquistar dentro del panel ---
func _on_boton_conquistar_pressed():
	var id = $InterfazFija/PanelInfoPais.get_meta("pais_id")
	var data = datos_paises[id]
	
	if influencia >= data["costo_conquista"]:
		influencia -= data["costo_conquista"]
		influencia_por_segundo += data["produccion_pasiva"]
		print("Conquistaste " + data["nombre"])
		$InterfazFija/PanelInfoPais.hide()
		# Aquí podrías cambiar el color del botón del país
	else:
		print("Influencia insuficiente")
