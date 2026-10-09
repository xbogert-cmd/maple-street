class_name Film
extends CanvasLayer
## A soft vignette and a trace of film grain over the 3D view, under the interface.

func _ready() -> void:
	layer = 0
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.38;
uniform float grain = 0.035;
float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 c = UV - 0.5;
	float v = smoothstep(0.35, 0.95, length(c * vec2(1.0, 0.85)) * 1.45);
	float g = (rnd(floor(FRAGCOORD.xy * 0.5) + floor(TIME * 12.0)) - 0.5) * grain;
	COLOR = vec4(vec3(0.02, 0.02, 0.05) + g, v * strength + abs(g));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	add_child(r)
