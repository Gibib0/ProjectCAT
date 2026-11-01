shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float d = distance(UV, vec2(0.5));                       // расстояние от центра экрана
	float edge = smoothstep(0.3, 0.8, d) * intensity;        // 0 в центре, растёт к краям
	COLOR = vec4(0.5, 0.0, 0.0, edge);                       // тёмно-красный с прозрачностью
}