extends Control

var influencia = 100.0
var influencia_por_segundo = 0.0
var energia_actual = 100.0
var datos_paises = {}
var arrastrando = false
var mouse_pos_ant = Vector2.ZERO

func _ready():
	print("SISTEMA: Reinicio total de nodos.")
	cargar_paises()
	# Forzamos que todos sean blancos al arrancar
	if has_node("MapaOceano"):
		for hijo in $MapaOceano.get_children():
			if hijo is Control: hijo.self_modulate = Color(1,1,1)

func _process(delta):
	# Economía
	influencia += influencia_por_segundo * delta
	var lbl = find_child("Label", true, false)
	if lbl: lbl.text = "Puntos: " + str(int(influencia))

	# Movimiento Directo
	var mouse_pos = get_viewport().get_mouse_position()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not arrastrando:
			arrastrando = true
			_chequear_clic_manual(mouse_pos)
		else:
			var delta_mouse = mouse_pos - mouse_pos_ant
			if has_node("MapaOceano"):
				$MapaOceano.position += delta_mouse
		mouse_pos_ant = mouse_pos
	else:
		arrastrando = false
	mouse_pos_ant = mouse_pos

func _chequear_clic_manual(p):
	if not has_node("MapaOceano"): return
	for nodo in $MapaOceano.get_children():
		if nodo is Control and nodo.name.begins_with("Pais"):
			# Usamos la distancia al centro para evitar fallos de Rect
			var centro = nodo.global_position + (nodo.size / 2)
			if p.distance_to(centro) < 80: # Un radio de 80 píxeles
				var id = nodo.name.split("_")[1].to_lower()
				print("DEBUG: Detectado clic en ", id)
				_abrir_panel(id)

func _abrir_panel(id):
	if datos_paises.has(id):
		var p = find_child("PanelInfoPais", true, false)
		if p:
			p.set_meta("pais_id", id)
			p.show()
			# Forzamos que el panel se vea arriba de todo
			p.z_index = 10
			print("SISTEMA: Mostrando panel de ", id)

func cargar_paises():
	if FileAccess.file_exists("res://paises.json"):
		var file = FileAccess.open("res://paises.json", FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			datos_paises = json.data
		file.close()

# Conectá la señal del botón Conquistar a esto:
func _on_boton_conquistar_pressed():
	var p = find_child("PanelInfoPais", true, false)
	if p and p.has_meta("pais_id"):
		var id = p.get_meta("pais_id")
		influencia_por_segundo += 5
		for nodo in $MapaOceano.get_children():
			if nodo.name.to_lower().ends_with(id):
				nodo.self_modulate = Color(1, 0, 0)
		p.hide()
