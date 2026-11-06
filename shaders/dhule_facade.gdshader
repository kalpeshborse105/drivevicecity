shader_type spatial;
// Dhule real-building look for the Blosm OSM city mesh:
// walls sample a tiled Indian facade texture (world-space triplanar),
// up/down faces (roofs, soffits) get plain weathered concrete.

uniform sampler2D facade_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 roof_color : source_color = vec3(0.60, 0.58, 0.53);
uniform float tile_meters = 6.0; // one texture tile = 6 m (2 storeys)

varying vec3 w_pos;
varying vec3 w_normal;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (abs(w_normal.y) > 0.7) {
		// Roof / underside — plain concrete, faintly darker with height grime.
		ALBEDO = roof_color;
		ROUGHNESS = 0.95;
	} else {
		// Vertical wall — triplanar using the dominant horizontal axis.
		vec2 uv;
		if (abs(w_normal.x) > abs(w_normal.z)) {
			uv = vec2(w_pos.z, w_pos.y) / tile_meters;
		} else {
			uv = vec2(w_pos.x, w_pos.y) / tile_meters;
		}
		vec4 tex = texture(facade_tex, uv);
		ALBEDO = tex.rgb;
		ROUGHNESS = 0.85;
	}
}
