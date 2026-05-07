extends Control

var arrastrando = false
var zoom_actual = Vector2(1, 1)

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event):
	# 1. DETECTAR CLIC PARA ARRASTRAR
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			arrastrando = event.pressed
			accept_event()
			
		# 2. ZOOM (Directo por índice de botón para asegurar compatibilidad)
		if event.pressed:
			var viejo_zoom = zoom_actual
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_actual += Vector2(0.1, 0.1)
				accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_actual -= Vector2(0.1, 0.1)
				accept_event()
			
			zoom_actual = zoom_actual.clamp(Vector2(0.3, 0.3), Vector2(1.8, 1.8))
			scale = zoom_actual
			
			# Compensación de posición para que el zoom se sienta natural
			if viejo_zoom != zoom_actual:
				var mouse_pos = get_local_mouse_position()
				position -= mouse_pos * (zoom_actual - viejo_zoom)

	# 3. MOVER EL MAPA
	if event is InputEventMouseMotion and arrastrando:
		# Movemos la posición relativa al movimiento del mouse
		position += event.relative
		accept_event()
