class_name UiKit
extends RefCounted

# Helpers de widgets compartidos por los módulos de presentación (Aprendé Git
# Capa 1 = git_explica.gd, y Capa 2 = git_sandbox.gd). Antes estaban duplicados
# en cada archivo y ya habían divergido (radio/margen 9 vs 10); acá viven una
# sola vez. Son estáticos: se les pasa la fuente porque no guardan estado.
# Colores SIEMPRE desde Tema (la única fuente de verdad de color).


static func label(texto: String, fuente: Font, tam: int, color: Color, halign := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", fuente)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = halign
	return l


static func boton(txt: String, acento: bool, fuente: Font) -> Button:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", fuente)
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(10)
	if acento:
		normal.bg_color = Tema.PRIMARIO
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
	else:
		normal.bg_color = Tema.PANEL
		normal.border_color = Tema.PANEL_BORDE
		normal.set_border_width_all(1)
		b.add_theme_color_override("font_color", Tema.TEXTO)
		b.add_theme_color_override("font_hover_color", Tema.PRIMARIO)
	var hover := normal.duplicate()
	hover.bg_color = (Tema.PRIMARIO.lerp(Color.BLACK, 0.08) if acento else Tema.PRIMARIO_TENUE)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	return b
