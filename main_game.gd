extends Control

var influencia = 0.0
var influencia_por_segundo = 0.0
var energia_actual = 100.0
var energia_maxima = 100.0
var regeneracion_energia_base = 5.0
var datos_paises = {}

# Variables para el arrastre a la fuerza
var arrastrando_mapa = false
var mouse_inicio = Vector2.ZERO
var pos_mapa_inicio = Vector2.ZERO

func _ready():
	cargar_paises()
	if has_node("InterfazFija/BarraEnergia"):
		$InterfazFija/BarraEnergia.max_value = energia_maxima
		$InterfazFija/BarraEnergia.value = energia_actual
	actualizar_ui_puntos()

func _process(delta):
	# 1. Economía
	if energia_actual < energia_maxima:
		energia_actual += regeneracion_energia_base * delta
		if has_node("InterfazFija/BarraEnergia"):
			$InterfazFija/BarraEnergia.value = energia_actual
	
	influencia += influencia_por_segundo * delta
	actualizar_ui_puntos()
	
	# 2. MOTOR DE MOVIMIENTO Y CLIC INSTANTÁNEO
	var mouse_actual = get_viewport().get_mouse_position()
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not arrastrando_mapa:
			# EL MOMENTO DEL CLIC: Verificamos ni bien apretás
			verificar_clic_pais_instantaneo(mouse_actual)
			
			arrastrando_mapa = true
			mouse_inicio = mouse_actual
			if has_node("MapaOceano"):
				pos_mapa_inicio = $MapaOceano.position
		else:
			# Arrastre continuo
			var diferencia = mouse_actual - mouse_inicio
			if has_node("MapaOceano"):
				$MapaOceano.position = pos_mapa_inicio + diferencia
	else:
		arrastrando_mapa = false

# Detección por impacto directo (sin esperar a soltar)
func verificar_clic_pais_instantaneo(pos_mouse):
	# Usamos get_rect para ver si la posición global del mouse está dentro del botón
	for pais in ["Pais_Argentina", "Pais_Brasil", "Pais_Eeuu"]:
		var nodo_path = "MapaOceano/" + pais
		if has_node(nodo_path):
			var nodo = get_node(nodo_path)
			if nodo.get_global_rect().has_point(pos_mouse):
				var id = pais.replace("Pais_", "").to_lower()
				_on_pais_clickeado(id)
				# No procesamos más para que no se pisen si están cerca
				return

func _input(event):
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if has_node("MapaOceano"):
				$MapaOceano.scale *= 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if has_node("MapaOceano"):
				$MapaOceano.scale *= 0.9

func cargar_paises():
	if FileAccess.file_exists("res://paises.json"):
		var file = FileAccess.open("res://paises.json", FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			datos_paises = json.data
		file.close()

func actualizar_ui_puntos():
	if has_node("InterfazFija/Label"):
		$InterfazFija/Label.text = "Influencia: " + str(int(influencia))

func _on_pais_clickeado(id_pais):
	if datos_paises.has(id_pais):
		var data = datos_paises[id_pais]
		if has_node("InterfazFija/PanelInfoPais/TextoInfo"):
			$InterfazFija/PanelInfoPais/TextoInfo.text = data["nombre"] + "\n\n" + data["descripcion"]
			$InterfazFija/PanelInfoPais.set_meta("pais_id", id_pais) 
			$InterfazFija/PanelInfoPais.show()

func _on_boton_conquistar_pressed():
	if has_node("InterfazFija/PanelInfoPais"):
		var id = $InterfazFija/PanelInfoPais.get_meta("pais_id")
		if datos_paises.has(id):
			var data = datos_paises[id]
			if influencia >= data["costo_conquista"]:
				influencia -= data["costo_conquista"]
				influencia_por_segundo += data["produccion_pasiva"]
				
				if has_node("MapaOceano"):
					for nodo in $MapaOceano.get_children():
						if nodo.name.to_lower().ends_with(id.to_lower()):
							nodo.self_modulate = Color(1, 0, 0)
				
				$InterfazFija/PanelInfoPais.hide()
				actualizar_ui_puntos()
