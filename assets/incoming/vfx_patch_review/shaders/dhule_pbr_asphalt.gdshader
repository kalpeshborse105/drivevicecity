shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Realistic High-VFX Wet/Dry PBR Asphalt Shader for DriveViceCity (Dhule OSM Roads)
uniform vec4 albedo_color : source_color = vec4(0.14, 0.14, 0.16, 1.0);
uniform vec4 lane_paint_color : source_color = vec4(0.95, 0.82, 0.22, 1.0);
uniform float roughness_base : hint_range(0.0, 1.0) = 0.72;
uniform float wetness : hint_range(0.0, 1.0) = 0.28;
uniform float puddle_scale : hint_range(0.01, 1.0) = 0.08;
uniform float road_width : hint_range(2.0, 30.0) = 10.0;
uniform bool show_center_dashed_line = true;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float grain = noise(world_pos.xz * 18.0) * 0.06;
	float puddle = smoothstep(0.55 - wetness * 0.35, 0.65 - wetness * 0.35, noise(world_pos.xz * puddle_scale));
	
	vec3 col = albedo_color.rgb + vec3(grain);
	
	// Edge curbs / shoulder wear
	float edge_factor = abs(UV.x - 0.5) * 2.0;
	if (edge_factor > 0.88) {
		col = mix(col, vec3(0.85, 0.85, 0.82), smoothstep(0.88, 0.91, edge_factor) * (1.0 - smoothstep(0.93, 0.95, edge_factor)));
	}
	
	// Center dashed yellow line (Indian highway / Dhule Agra Road style)
	if (show_center_dashed_line) {
		float center_dist = abs(UV.x - 0.5);
		float dash = step(0.45, fract(world_pos.z * 0.12 + world_pos.x * 0.12));
		if (center_dist < 0.022 && dash > 0.5) {
			col = mix(col, lane_paint_color.rgb, 0.92);
		}
	}
	
	ALBEDO = mix(col, col * 0.55, puddle * wetness);
	ROUGHNESS = mix(roughness_base, 0.06, puddle * wetness);
	METALLIC = mix(0.05, 0.35, puddle * wetness);
	SPECULAR = mix(0.45, 0.95, puddle * wetness);
}
