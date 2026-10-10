// Mask surface (pd2_fidelity P8): colour pair x pattern over a library material's grain. Owner: ENV B.
// Original shader. Parameters are set by MaskComposer.build_material(); see content/docs/masks.md.
// UV0: x across the face (0 = viewer's left when looking at the front), y forehead (0) to chin (1).
shader_type spatial;
render_mode cull_disabled;

uniform vec4 color_a : source_color = vec4(1.0);
uniform vec4 color_b : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// MaskPatternDef.Procedural: 0 solid, 1 split, 2 brow band, 3 stripes, 4 chevron, 5 dots, 6 sash, 7 diamonds.
uniform int pattern = 0;
uniform float pattern_scale = 4.0;
uniform bool use_pattern_tex = false;
uniform sampler2D pattern_tex : hint_default_black, filter_linear_mipmap;
uniform sampler2D detail_albedo : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_orm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
uniform float detail_strength = 0.5;
uniform float detail_mean = 0.5;
uniform float uv_tile = 1.5;
uniform float metallic_value = 0.0;
uniform float roughness_value = 0.5;

float edge(float d) {
	float w = max(fwidth(d), 0.0005);
	return smoothstep(-w, w, d);
}

float pattern_mask(vec2 uv) {
	float s = pattern_scale;
	if (pattern == 1) {
		return edge(uv.x - 0.5);
	} else if (pattern == 2) {
		return edge(uv.y - 0.2) * (1.0 - edge(uv.y - 0.4));
	} else if (pattern == 3) {
		return edge(abs(fract(uv.y * s) - 0.5) - 0.25);
	} else if (pattern == 4) {
		return edge(abs(fract((uv.y + abs(uv.x - 0.5)) * s) - 0.5) - 0.25);
	} else if (pattern == 5) {
		return 1.0 - edge(length(fract(uv * s) - 0.5) - 0.26);
	} else if (pattern == 6) {
		return 1.0 - edge(abs(uv.x - uv.y) - 0.12);
	} else if (pattern == 7) {
		vec2 r = vec2(uv.x + uv.y, uv.x - uv.y) * s * 0.5;
		vec2 c = fract(r) - 0.5;
		return edge(c.x * c.y);
	}
	return 0.0;
}

void fragment() {
	vec2 tuv = UV * uv_tile;
	float m = use_pattern_tex ? texture(pattern_tex, UV).r : pattern_mask(UV);
	vec3 base = mix(color_a.rgb, color_b.rgb, m);
	vec3 detail = texture(detail_albedo, tuv).rgb;
	float lum = dot(detail, vec3(0.299, 0.587, 0.114));
	float grain = mix(1.0, clamp(lum / max(detail_mean, 0.05), 0.0, 1.4), detail_strength);
	ALBEDO = clamp(base * grain, vec3(0.0), vec3(1.0));
	vec3 orm = texture(detail_orm, tuv).rgb;
	ROUGHNESS = clamp(roughness_value * mix(1.0, orm.g * 1.4, detail_strength), 0.03, 1.0);
	METALLIC = metallic_value;
	AO = mix(1.0, orm.r, detail_strength);
	if (has_normal) {
		NORMAL_MAP = texture(detail_normal, tuv).rgb;
		NORMAL_MAP_DEPTH = detail_strength;
	}
}
