extends Control

# Variables de Economía
var datos_paises = {} # Aquí se guardará el JSON de los países
var poder_click_base = 1
var generacion_pasiva_base = 0

var poder_click_actual = 1
var generacion_pasiva_actual = 0

# --- MOTOR DE NAVEGACIÓN TÁCTIL/MOUSE ---
var arrastrando_mapa = false
var posicion_mouse_previa = Vector2()

# --- SISTEMA DE ENERGÍA ---
var energia_maxima : float = 100.0
var energia_actual : float = 100.0
var regeneracion_energia_base : float = 5.0 # Cuánta energía recupera por segundo
var costo_energia_click : float = 10.0 # Cuánta energía cuesta cada "Tap" en un país

# NUEVAS VARIABLES DE ZOOM
var zoom_minimo = Vector2(0.5, 0.5) 
var zoom_maximo = Vector2(3.0, 3.0) 
var velocidad_zoom = Vector2(0.2, 0.2) # Cuánto sumamos por cada golpe de ruedita
var zoom_objetivo = Vector2(1.0, 1.0) # A dónde queremos llegar
var suavizado_zoom = 10.0 # Qué tan "resbaladizo" o suave es el efecto
# Variable global que recuerda qué país tocamos en el mapa
var id_pais_seleccionado : String = ""

# --- BASE DE DATOS DE PAÍSES (Diccionario para el Mapa Táctico) ---
var mundo = {
	"Pais_Argentina": {"nombre": "Argentina", "poblacion": 46000000.0, "followers": 0, "tasa_natalidad": 0.00005},
	"Pais_Brasil": {"nombre": "Brasil", "poblacion": 214000000.0, "followers": 0, "tasa_natalidad": 0.00008},
	"Pais_EEUU": {"nombre": "Estados Unidos", "poblacion": 331000000.0, "followers": 0, "tasa_natalidad": 0.00004}
}

# --- VARIABLES LOCALES (EL PAÍS ACTUAL) ---
var followers : int = 0
var poblacion_pais : float = 1000.0 

# --- VARIABLES GLOBALES (EL MUNDO) ---
var poblacion_mundial : float = 8000000000.0 
var seguidores_mundiales : int = 0

# --- ECONOMÍA Y MOTOR ---
var influencia : int = 0 
var influencia_por_segundo = 0
var poder_click : int = 1
var seguidores_por_segundo : int = 0
var tiempo_juego_unix : float = 0.0 
var puntos_prestigio : int = 0
var multiplicador_prestigio : float = 1.0

var habilidades = {} # Empezamos con el diccionario vacío

func _ready():
	# Si la variable arranca en 0, le damos el tiempo real de hoy
	if tiempo_juego_unix <= 0:
		tiempo_juego_unix = Time.get_unix_time_from_system()
		
	cargar_datos_desde_json() # <--- El motor de carga
	cargar_paises()
	cargar_partida()
	recalcular_economia()
	configurar_limites_camara()
	$InterfazFija/PanelTienda.hide()
	$InterfazFija/BarraEnergia.max_value = energia_maxima
	actualizar_tienda_dinamica()

func cargar_datos_desde_json():
	var ruta = "res://mejoras.json"
	
	# PASO 1: Verificar existencia física
	if not FileAccess.file_exists(ruta):
		print("ERROR CRÍTICO: Godot no encuentra el archivo en la ruta: ", ruta)
		return
		
	var archivo = FileAccess.open(ruta, FileAccess.READ)
	var json_string = archivo.get_as_text()
	archivo.close()
	
	# PASO 2: Parseo estricto con reporte de errores
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error == OK:
		var datos_parseados = json.data
		
		# PASO 3: Validación de estructura
		if typeof(datos_parseados) == TYPE_DICTIONARY and datos_parseados.has("mejoras_base"):
			for mejora in datos_parseados["mejoras_base"]:
				habilidades[mejora["id"]] = {
					"nombre": mejora["nombre"],
					"costo": mejora["costo"],
					"efecto": mejora["efecto"],
					"tipo": mejora["tipo"],
					"requisito": mejora["requisito"],
					"rama": mejora["rama"],
					"pos_x": mejora["pos_x"],
					"pos_y": mejora["pos_y"],
					"comprado": false
				}
			print("¡ÉXITO! Se inyectaron ", habilidades.size(), " mejoras a la memoria.")
		else:
			print("ERROR: El archivo es un JSON válido, pero no tiene el formato esperado (falta 'mejoras_base').")
	else:
		# PASO 4: Reporte exacto de error de tipeo
		print("ERROR DE SINTAXIS EN EL JSON. Godot no pudo leerlo.")
		print("Falla en la línea: ", json.get_error_line())
		print("Motivo: ", json.get_error_message())

func actualizar_texto():
	guardar_partida() # Auto-guardado silencioso en cada segundo que pasa
	
	if followers > int(poblacion_pais):
		followers = int(poblacion_pais)
	
	@warning_ignore("narrowing_conversion")
	var fecha = Time.get_date_dict_from_unix_time(tiempo_juego_unix)
	var texto_fecha = str(fecha.day) + "/" + str(fecha.month) + "/" + str(fecha.year)

	# Actualizamos solo el texto principal
	$InterfazFija/Label.text = "Fecha: " + texto_fecha + "\nInfluencia Global: " + str(influencia)
	
	$InterfazFija/ProgressBar.value = seguidores_mundiales
	
	if $InterfazFija/PanelInfoPais.visible:
		actualizar_datos_panel()

func aplicar_infeccion_manual():
	if id_pais_seleccionado == "": return 
	
	# 1. EL PEAJE DE ENERGÍA: Si no nos alcanza, cortamos la función acá mismo
	if energia_actual < costo_energia_click:
		# Acá a futuro podés hacer que la barra titile en rojo o suene un "Bzz" de error
		return 
		
	# 2. COBRAMOS LA ENERGÍA
	energia_actual -= costo_energia_click
	
	# 3. EL RESTO DE TU LÓGICA DE INFECCIÓN (Esto ya lo tenías)
	var espacio_disponible = int(poblacion_pais) - followers
	var nuevos_seguidores = poder_click
	
	if nuevos_seguidores > espacio_disponible:
		nuevos_seguidores = espacio_disponible 
		
	followers += nuevos_seguidores
	influencia += nuevos_seguidores
	seguidores_mundiales += nuevos_seguidores 
	
	mundo[id_pais_seleccionado]["followers"] = followers
	
	actualizar_texto()

func _on_timer_timeout():
	tiempo_juego_unix += 86400.0
	
	# 1. CRECIMIENTO GLOBAL: Recorremos TODOS los países y aumentamos su población
	for id_pais in mundo:
		mundo[id_pais]["poblacion"] += mundo[id_pais]["poblacion"] * mundo[id_pais]["tasa_natalidad"]
	
	# 2. LÓGICA LOCAL: Solo si tenemos un país seleccionado en pantalla
	if id_pais_seleccionado != "":
		# Sincronizamos la variable local con la base de datos que acaba de crecer
		poblacion_pais = mundo[id_pais_seleccionado]["poblacion"]
		
		# Si tenemos la mejora automática comprada, infectamos
		if seguidores_por_segundo > 0:
			var espacio_disponible = int(poblacion_pais) - followers
			var nuevos_seguidores = seguidores_por_segundo
			
			if nuevos_seguidores > espacio_disponible:
				nuevos_seguidores = espacio_disponible
				
			followers += nuevos_seguidores
			influencia += nuevos_seguidores
			seguidores_mundiales += nuevos_seguidores 
			
			# Guardamos el progreso local
			mundo[id_pais_seleccionado]["followers"] = followers

	actualizar_texto()
	guardar_partida()

func actualizar_datos_panel():
	if id_pais_seleccionado == "": return
	
	var porcentaje = (float(followers) / poblacion_pais) * 100.0
	
	# Extraemos el nombre real del país de nuestra base de datos
	var nombre_actual = mundo[id_pais_seleccionado]["nombre"]
	
	var info = "País: " + nombre_actual + "\n"
	info += "Conquistado: " + str(snapped(porcentaje, 0.1)) + "%\n"
	info += "Población: " + str(followers) + " / " + str(int(poblacion_pais))
	
	$InterfazFija/PanelInfoPais/TextoInfo.text = info

func _on_boton_info_pressed():
	actualizar_datos_panel() 
	$InterfazFija/PanelInfoPais.show()

func _on_boton_cerrar_pressed():
	$InterfazFija/PanelInfoPais.hide()
	

var arrastrando_mundo = false

func _input(event):
	# Frenamos el evento manualmente si la tienda está abierta
	if $InterfazFija/PanelTienda.visible:
		return
		
	# LOGICA ZOOM
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			$Camera2D.zoom += Vector2(0.1, 0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			$Camera2D.zoom -= Vector2(0.1, 0.1)
			
		$Camera2D.zoom = $Camera2D.zoom.clamp(Vector2(0.5, 0.5), Vector2(3.0, 3.0))

	# DETECTOR DE CLIC
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			arrastrando_mundo = event.pressed
			print("Clic izquierdo forzado: ", arrastrando_mundo)

	# DETECTOR DE MOVIMIENTO
	if event is InputEventMouseMotion and arrastrando_mundo:
		$Camera2D.position -= event.relative / $Camera2D.zoom
		
		
func _on_pais_argentina_pressed():
	var id = "argentina"
	if datos_paises.has(id):
		var data = datos_paises[id]
		print("Datos de ", data["nombre"], ": ", data["costo_conquista"], " de influencia.")
		# Aquí es donde abrirías tu PanelInfo con la info de 'data'
	else:
		print("El ID 'argentina' no existe en el JSON")

func _on_pais_brasil_pressed():
	seleccionar_pais("Pais_Brasil")
	aplicar_infeccion_manual() # <--- Agregamos el ataque directo
	efecto_resplandor("Pais_Brasil") # <--- Agregamos el resplandor

func _on_pais_eeuu_pressed() -> void:
	seleccionar_pais("Pais_EEUU")
	aplicar_infeccion_manual() # <--- Agregamos el ataque directo
	efecto_resplandor("Pais_EEUU") # <--- Agregamos el resplandor
	
func seleccionar_pais(id_nodo):
	# 1. Si veníamos de otro país, guardamos su crecimiento de población antes de irnos
	if id_pais_seleccionado != "":
		mundo[id_pais_seleccionado]["poblacion"] = poblacion_pais
	
	# 2. Asignamos el nuevo país
	id_pais_seleccionado = id_nodo
	
	# 3. Cargamos los datos exactos del nuevo país desde la base de datos
	poblacion_pais = mundo[id_nodo]["poblacion"]
	followers = mundo[id_nodo]["followers"]
	
	# 4. Actualizamos y mostramos la tarjeta
	actualizar_datos_panel()
	$InterfazFija/PanelInfoPais.show()

func configurar_limites_camara():
	# Leemos dónde empieza y cuánto mide el océano
	var tamaño_mapa = $MapaOceano.size
	var posicion_mapa = $MapaOceano.position
	
	# Le pasamos esos límites físicos a la cámara
	$Camera2D.limit_left = int(posicion_mapa.x)
	$Camera2D.limit_top = int(posicion_mapa.y)
	$Camera2D.limit_right = int(posicion_mapa.x + tamaño_mapa.x)
	$Camera2D.limit_bottom = int(posicion_mapa.y + tamaño_mapa.y)
	
	
func _process(delta):
	# Ejecutamos los límites de la cámara
	#enjaular_camara()
	
	# --- MOTOR DE REGENERACIÓN DE ENERGÍA ---
	if energia_actual < energia_maxima:
		energia_actual += regeneracion_energia_base * delta
		
		# Tope de seguridad
		if energia_actual > energia_maxima:
			energia_actual = energia_maxima
			
	# Actualizamos la barra visual constantemente
	$InterfazFija/BarraEnergia.value = energia_actual
	
func efecto_resplandor(id_nodo):
	# Buscamos el botón físico en el mapa
	var boton_pais = get_node("MapaOceano/" + id_nodo)
	
	# Creamos el animador matemático
	var tween = get_tree().create_tween()
	
	# Le damos un color brillante de golpe (Amarillo/Blanco intenso)
	boton_pais.modulate = Color(2.0, 2.0, 1.5) 
	
	# Le decimos al Tween que devuelva el color a la normalidad (Color.WHITE) en 0.4 segundos
	tween.tween_property(boton_pais, "modulate", Color.WHITE, 0.4)
	
# --- SISTEMA DE GUARDADO (SAVE/LOAD) ---
var ruta_guardado = "user://conquista_mundial.save"

func guardar_partida():
	var datos = {
		"mundo": mundo,
		"influencia": influencia,
		"seguidores_mundiales": seguidores_mundiales,
		"poder_click": poder_click,
		"seguidores_por_segundo": seguidores_por_segundo,
		"energia_actual": energia_actual,
		"energia_maxima": energia_maxima,
		"regeneracion_energia_base": regeneracion_energia_base,
		# GUARDAMOS EL DICCIONARIO DE HABILIDADES:
		"habilidades": habilidades,
		"puntos_prestigio": puntos_prestigio
	}
	
	var archivo = FileAccess.open(ruta_guardado, FileAccess.WRITE)
	archivo.store_string(JSON.stringify(datos))
	archivo.close()
	print("Partida guardada con éxito en el disco.")

func cargar_partida():
	if FileAccess.file_exists(ruta_guardado):
		var archivo = FileAccess.open(ruta_guardado, FileAccess.READ)
		var datos = JSON.parse_string(archivo.get_as_text())
		archivo.close()
		
		# Cargamos la base general verificando que el dato exista
		if datos.has("mundo"): mundo = datos["mundo"]
		@warning_ignore("narrowing_conversion")
		if datos.has("influencia"): influencia = float(datos["influencia"]) 
		@warning_ignore("narrowing_conversion")
		if datos.has("seguidores_mundiales"): seguidores_mundiales = float(datos["seguidores_mundiales"])
		@warning_ignore("narrowing_conversion")
		if datos.has("poder_click"): poder_click = float(datos["poder_click"])
		@warning_ignore("narrowing_conversion")
		if datos.has("seguidores_por_segundo"): seguidores_por_segundo = float(datos["seguidores_por_segundo"])
		if datos.has("tiempo_juego_unix"): tiempo_juego_unix = float(datos["tiempo_juego_unix"])
		
		# Sistema de Energía (Carga segura)
		if datos.has("energia_actual"): energia_actual = float(datos["energia_actual"])
		if datos.has("energia_maxima"): energia_maxima = float(datos["energia_maxima"])
		if datos.has("regeneracion_energia_base"): regeneracion_energia_base = float(datos["regeneracion_energia_base"])
		if datos.has("costo_energia_click"): costo_energia_click = float(datos["costo_energia_click"])
			
		# Sistema de Mejoras Dinámico
		if datos.has("habilidades"):
			for id in datos["habilidades"]:
				# Solo actualizamos el estado de compra, respetando el resto del JSON
				if habilidades.has(id) and datos["habilidades"][id].has("comprado"):
					habilidades[id]["comprado"] = datos["habilidades"][id]["comprado"]
			
func _on_boton_abrir_tienda_pressed():
	$InterfazFija/PanelTienda.show()
	$InterfazFija/BotonAbrirTienda.hide() 
	$InterfazFija/BarraEnergia.hide()
	
	var mapa = $InterfazFija/PanelTienda/MapaHabilidades
	mapa.scale = Vector2(1, 1) 
	# CORRECCIÓN AQUÍ: Usamos zoom_actual para que coincida con el otro script
	mapa.zoom_actual = Vector2(1, 1) 
	mapa.arrastrando = false  
	
	actualizar_tienda_dinamica()
	
	var centro_pantalla = get_viewport().get_visible_rect().size / 2
	mapa.position = centro_pantalla - Vector2(1500, 1500)

func _on_boton_cerrar_tienda_pressed():
	# 1. Revertimos la visibilidad
	$InterfazFija/PanelTienda.hide()
	$InterfazFija/BotonAbrirTienda.show() # El botón vuelve a aparecer
	$InterfazFija/BarraEnergia.show()


func _on_boton_recargar_energia_pressed() -> void:
	# En el futuro, acá pondrías: if mostrar_anuncio_recompensado() == true:
	energia_actual = energia_maxima

func enjaular_camara():
	var pantalla = get_viewport_rect().size / $Camera2D.zoom
	var min_x = $MapaOceano.position.x + (pantalla.x / 2.0)
	var max_x = $MapaOceano.position.x + $MapaOceano.size.x - (pantalla.x / 2.0)
	var min_y = $MapaOceano.position.y + (pantalla.y / 2.0)
	var max_y = $MapaOceano.position.y + $MapaOceano.size.y - (pantalla.y / 2.0)
	
	if min_x < max_x:
		$Camera2D.position.x = clamp($Camera2D.position.x, min_x, max_x)
	else:
		$Camera2D.position.x = $MapaOceano.position.x + ($MapaOceano.size.x / 2.0)
		
	if min_y < max_y:
		$Camera2D.position.y = clamp($Camera2D.position.y, min_y, max_y)
	else:
		$Camera2D.position.y = $MapaOceano.position.y + ($MapaOceano.size.y / 2.0)
		
func actualizar_tienda_dinamica():
	# RUTA ACTUALIZADA: Directo de PanelTienda a MapaHabilidades
	var mapa = $InterfazFija/PanelTienda/MapaHabilidades
	
	# Limpieza de seguridad
	for n in mapa.get_children():
		n.queue_free()
		
	var offset_centro = Vector2(60, 30) 
	var botones_creados = 0
	
	# ==========================================
	# PASADA 1: DIBUJAR LAS LÍNEAS
	# ==========================================
	for id in habilidades:
		var h = habilidades[id]
		var req_id = h["requisito"]
		
		var req_cumplido = req_id == "" or (habilidades.has(req_id) and habilidades[req_id]["comprado"])
		var mostrar_nodo = h["comprado"] or req_cumplido
		
		if mostrar_nodo and req_id != "" and habilidades.has(req_id):
			var padre = habilidades[req_id]
			var linea = Line2D.new()
			
			var pos_padre = Vector2(padre.get("pos_x", 1500), padre.get("pos_y", 1500)) + offset_centro
			var pos_hijo = Vector2(h.get("pos_x", 1500), h.get("pos_y", 1500)) + offset_centro
			
			linea.add_point(pos_padre)
			linea.add_point(pos_hijo)
			
			linea.width = 4.0
			if h["comprado"]:
				linea.default_color = Color(0.5, 0.0, 0.0) 
			else:
				linea.default_color = Color(0.2, 0.2, 0.2) 
				
			mapa.add_child(linea)

	# ==========================================
	# PASADA 2: DIBUJAR LOS BOTONES
	# ==========================================
	for id in habilidades:
		var h = habilidades[id]
		var req_id = h["requisito"]
		
		var req_cumplido = req_id == "" or (habilidades.has(req_id) and habilidades[req_id]["comprado"])
		var mostrar_nodo = h["comprado"] or req_cumplido
		
		if mostrar_nodo:
			var boton = Button.new()
			
			if h["comprado"]:
				boton.text = "[DOMINADO]\n" + h["nombre"]
				boton.disabled = true 
			else:
				boton.text = h["nombre"] + "\n[$" + str(h["costo"]) + "]"
				boton.pressed.connect(func(): _on_habilidad_comprada(id))
			
			boton.custom_minimum_size = Vector2(120, 60)
			boton.position = Vector2(h.get("pos_x", 1500), h.get("pos_y", 1500))
			boton.set_meta("id_mejora", id)
			
			mapa.add_child(boton)
			botones_creados += 1
			
func _on_habilidad_comprada(id):
	var h = habilidades[id]
	if influencia >= h["costo"]:
		influencia -= h["costo"]
		h["comprado"] = true
		
		recalcular_economia()
		
		# APLICAR EFECTOS SEGÚN EL TIPO
		match h["tipo"]:
			"poder_click": 
				poder_click += h["efecto"]
			"auto_inf": 
				seguidores_por_segundo += h["efecto"]
			"max_energia": 
				energia_maxima += h["efecto"]
				$InterfazFija/BarraEnergia.max_value = energia_maxima
			"reg_energia": 
				regeneracion_energia_base += h["efecto"]
		
		# Refrescamos todo
		actualizar_texto()
		actualizar_tienda_dinamica()
		guardar_partida()
	else:
		print("Influencia insuficiente")

func actualizar_colores_arbol():
	var mapa = $InterfazFija/PanelTienda/ScrollContainer/MapaHabilidades
	
	# Colores base (podés ajustar los códigos RGB)
	var color_raiz = Color(0.4, 0.1, 0.5) # Ejemplo: Un púrpura oscuro/corrupción
	var color_verde = Color(0.1, 0.8, 0.1)
	var color_rojo = Color(0.8, 0.1, 0.1)
	var color_gris_bloqueado = Color(0.2, 0.2, 0.2)

	for boton in mapa.get_children():
		if not boton.has_meta("id_mejora"): continue # Verificación de seguridad
		
		var id = boton.get_meta("id_mejora")
		var h = habilidades[id]
		
		# Creamos una caja de estilo dinámico para este botón
		var estilo = StyleBoxFlat.new()
		estilo.border_width_bottom = 3
		estilo.border_width_top = 3
		estilo.border_width_left = 3
		estilo.border_width_right = 3
		
		if h["comprado"]:
			# ESTADO 4: Comprado (Color de tu infección/raíz)
			estilo.bg_color = color_raiz
			estilo.border_color = color_raiz
		else:
			# No está comprado. Verificamos si alcanza la plata
			estilo.bg_color = color_gris_bloqueado # Fondo oscuro
			if influencia >= h["costo"]:
				# ESTADO 3: Alcanza la plata (Borde Verde)
				estilo.border_color = color_verde
			else:
				# ESTADO 2: No alcanza la plata (Borde Rojo)
				estilo.border_color = color_rojo
				
		# Aplicamos el estilo al botón
		boton.add_theme_stylebox_override("normal", estilo)
		boton.add_theme_stylebox_override("hover", estilo)
		boton.add_theme_stylebox_override("pressed", estilo)
		
func recalcular_economia():
	var total_pasivo = 0
	for id in habilidades:
		if habilidades[id]["comprado"] and habilidades[id]["tipo"] == "auto_inf":
			total_pasivo += habilidades[id]["efecto"]
	
	influencia_por_segundo = total_pasivo


func _on_timer_produccion_timeout():
	influencia += influencia_por_segundo
	
	# Actualizar texto (con la ruta que copiaste arriba)
	$InterfazFija/LabelPuntos.text = "Influencia: " + str(influencia)
	
	# Lógica de conquista visual
	if influencia >= 1000:
		$MapaOceano/Pais_Argentina.self_modulate = Color(0.5, 0, 0) # Rojo oscuro

func cargar_paises():
	# ... (El código de carga que vimos antes)
	# Esto llena el diccionario 'datos_paises'
	pass
	
func _on_pais_clickeado(id_del_pais: String):
	# El id_del_pais será "argentina", "brasil", etc.
	if datos_paises.has(id_del_pais):
		var data = datos_paises[id_del_pais]

		# 1. Pasamos la info al Panel que ya tenés
		$InterfazFija/PanelInfoPais/TextoInfo.text = data["nombre"]
		$InterfazFija/PanelInfoPais/HabitantesLabel.text = "Población: " + str(data["habitantes"])
		$InterfazFija/PanelInfoPais/CostoLabel.text = "Costo: " + str(data["costo_conquista"])

		# 2. Guardamos qué país estamos mirando para el botón "Conquistar"
		$InterfazFija/PanelInfoPais.set_meta("pais_actual", id_del_pais)
		
		# 3. Mostramos el panel
		$InterfazFija/PanelInfoPais.show()
	


func _on_boton_conquistar_pressed():
	# Recuperamos qué país estamos mirando (guardado en el meta anteriormente)
	var id_pais = $InterfazFija/PanelInfoPais.get_meta("pais_actual")
	var data = datos_paises[id_pais]
	var costo = data["costo_conquista"]
	
	if influencia >= costo:
		# 1. Pagamos el costo
		influencia -= costo
		
		# 2. Sumamos la producción pasiva al total global
		influencia_por_segundo += data["produccion_pasiva"]
		
		# 3. Marcamos el país como conquistado (Visual)
		# Suponiendo que tus botones se llaman "Pais_Argentina", etc.
		var ruta_boton = "MapaOceano/Pais_" + id_pais.capitalize()
		get_node(ruta_boton).self_modulate = Color(0.8, 0.2, 0.2) # Rojo de dominación
		
		# 4. Feedback y cierre
		print("Has conquistado ", data["nombre"], "!")
		$InterfazFija/PanelInfoPais.hide()
		actualizar_ui_puntos() # Función para refrescar los labels de puntos
	else:
		print("No tienes suficiente influencia. Necesitas: ", costo)
		
		
