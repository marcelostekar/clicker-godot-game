extends Control

# Variables de Economía
var influencia = 0.0
var influencia_por_segundo = 0.0
var energia_actual = 100.0
var energia_maxima = 100.0
var regeneracion_energia_base = 5.0
var poder_click_actual = 1.0

var arrastrando = false 

var zoom_actual = Vector2(1, 1)

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
		$InterfazFija/PanelInfoPais/TextoInfo.text = data["nombre"] + "\n\n" + data["descripcion"]
# Cambié esto para que coincida con la variable que recibe la función
		$InterfazFija/PanelInfoPais.set_meta("pais_id", id_pais) 
		$InterfazFija/PanelInfoPais.show()

# --- Función para el botón de Conquistar dentro del panel ---
func _on_boton_conquistar_pressed():
	var id = $InterfazFija/PanelInfoPais.get_meta("pais_id")
	var data = datos_paises[id]
	
	if influencia >= data["costo_conquista"]:
		influencia -= data["costo_conquista"]
		influencia_por_segundo += data["produccion_pasiva"]
		
		# --- SOLUCIÓN PARA LOS NOMBRES ---
		# En lugar de adivinar mayúsculas, buscamos el nodo que CONTENGA el nombre
		for nodo in $MapaOceano.get_children():
			if nodo.name.to_lower().ends_with(id.to_lower()):
				nodo.self_modulate = Color(1, 0, 0) # Lo pintamos de rojo furioso
				print("Nodo encontrado y pintado: ", nodo.name)
		
		$InterfazFija/PanelInfoPais.hide()
		actualizar_ui_puntos()
	else:
		print("No te alcanza la influencia, seguí clickeando.")
		
func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			arrastrando = event.pressed
			print("Clic en mapa: ", arrastrando) # Si esto no sale en consola, el Size está mal.

	if event is InputEventMouseMotion and arrastrando:
		position += event.relative
