// Mask surface (pd2_fidelity P8): colour pair x pattern over a library material's grain. Owner: ENV B.
// Original shader. Parameters are set by MaskComposer.build_material(); see content/docs/masks.md.
// UV0: x across the face (0 = viewer's left when looking at the front), y forehead (0) to chin (1).
shader_type spatial;
render_mode cull_disabled;

uniform vec4 color_a : source_color = vec4(1.0);
uniform vec4 color_b : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// MaskPatternDef.Procedural: 0 solid, 1 split, 2 brow band, 3 stripes, 4 chevron, 5 dots, 6 sash,
// 7 diamonds, 8 scales, 9 circuit, 10 prowl, 11 halftone, 12 crackle, 13 starburst (B4-15), 14 guilloche,
// 15 vault bolts, 16 acanthus border, 17 facets, 18 time-lock dial, 19 stencil band (achievement parts, round 244).
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

// Edge with a given anti-alias half width (for patterns that branch per pixel: fwidth() is only
// valid in uniform control flow, so the width is computed once up front in pattern_mask()).
float edge_w(float d, float w) {
	return smoothstep(-w, w, d);
}

// Cheap deterministic cell hash (no global RNG; same on every peer).
float hash21(vec2 p) {
	p = fract(p * vec2(127.13, 311.71));
	p += dot(p, p + 37.19);
	return fract(p.x * p.y);
}

// Overlapping scale rows: half-offset circles, each lower row drawn over the one above, so the
// rounded rims point down toward the chin. color_b = the rims. `w` = AA width in cell units.
float scales(vec2 uv, float s, float w) {
	vec2 g = uv * s;
	float r = 0.62;
	float base_row = floor(g.y);
	for (int k = 2; k >= -1; k--) {
		float row = base_row + float(k);
		float off = mod(row, 2.0) * 0.5;
		float cx = floor(g.x - off) + off + 0.5;
		float best = 8.0;
		for (int n = -1; n <= 1; n++) {
			best = min(best, length(g - vec2(cx + float(n), row)));
		}
		if (best < r) {
			return edge_w(best - (r - 0.11), w);
		}
	}
	return 0.0;
}

// Circuit board: traces between grid cell centres (each link decided once per cell pair by a hash,
// so both cells agree) and ring pads.
float circuit(vec2 uv, float s, float w) {
	vec2 g = uv * s;
	vec2 c = floor(g);
	vec2 f = fract(g) - 0.5;
	float t = 0.07;
	float h_line = 1.0 - edge_w(abs(f.y) - t, w);
	float v_line = 1.0 - edge_w(abs(f.x) - t, w);
	float m = 0.0;
	m = max(m, h_line * (1.0 - edge_w(-f.x - t, w)) * step(0.4, hash21(c + vec2(0.11, 0.0))));
	m = max(m, h_line * (1.0 - edge_w(f.x - t, w)) * step(0.4, hash21(c - vec2(1.0, 0.0) + vec2(0.11, 0.0))));
	m = max(m, v_line * (1.0 - edge_w(-f.y - t, w)) * step(0.5, hash21(c + vec2(0.0, 0.37))));
	m = max(m, v_line * (1.0 - edge_w(f.y - t, w)) * step(0.5, hash21(c - vec2(0.0, 1.0) + vec2(0.0, 0.37))));
	float pad = (1.0 - edge_w(abs(length(f) - 0.17) - 0.05, w)) * step(0.6, hash21(c + vec2(0.53, 0.71)));
	return max(m, pad);
}

// Prowl: wavy stripes that grow in from the sides and fade out at the centre line.
float prowl(vec2 uv, float s, float w) {
	float side = abs(uv.x - 0.5);
	float t = uv.y * s + 0.35 * sin(uv.x * 11.0) + side * 1.5;
	float width = 0.3 * smoothstep(0.06, 0.42, side);
	return 1.0 - edge_w(abs(fract(t) - 0.5) - width, w * 1.5);
}

// Halftone: a 45-degree dot screen whose dots grow from the forehead to the chin.
float halftone(vec2 uv, float s, float w) {
	vec2 r = vec2(uv.x + uv.y, uv.x - uv.y) * 0.7071 * s;
	float radius = mix(0.06, 0.48, clamp(uv.y, 0.0, 1.0));
	return 1.0 - edge_w(length(fract(r) - 0.5) - radius, w);
}

// Crackle: thin lines along the borders of jittered cells (second-nearest minus nearest point).
float crackle(vec2 uv, float s, float w) {
	vec2 g = uv * s;
	vec2 c = floor(g);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 n = c + vec2(float(i), float(j));
			vec2 pt = n + vec2(hash21(n), hash21(n + 17.3)) * 0.8 + 0.1;
			float d = length(g - pt);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return 1.0 - edge_w(d2 - d1 - 0.07, w);
}

// Starburst: rays from just above the nose, with a plain disc at the centre. `w` in uv units.
float starburst(vec2 uv, float s, float w) {
	vec2 d = uv - vec2(0.5, 0.42);
	float rays = max(floor(s), 3.0) * 2.0;
	float len = length(d);
	float a = atan(d.y, d.x);
	// signed distance (uv units) to the nearest ray side: no atan seam, no per-pixel fwidth
	float ray = edge_w(sin(a * rays) * len / rays * 3.14159, w);
	return ray * edge_w(len - 0.09, w);
}

// Guilloche: banknote rosette, concentric rings rippled by a petal wave around the face centre.
float guilloche(vec2 uv, float s, float w) {
	vec2 d = uv - vec2(0.5, 0.45);
	float len = length(d);
	float a = atan(d.y, d.x);
	float t = len * s * 2.0 + 0.35 * sin(a * 12.0);
	return 1.0 - edge_w(abs(fract(t) - 0.5) - 0.16, w * s * 2.0);
}

// Vault bolts: a ring of round bolt heads at the rim of a vault door plate, plus a small hub.
float vault_bolts(vec2 uv, float s, float w) {
	vec2 d = uv - vec2(0.5, 0.45);
	float len = length(d);
	float a = atan(d.y, d.x);
	float n = max(floor(s), 6.0) * 2.0;
	float cell = 6.28318 / n;
	float ac = (floor(a / cell) + 0.5) * cell;
	vec2 bolt = vec2(cos(ac), sin(ac)) * 0.33;
	float b = 1.0 - edge_w(length(d - bolt) - 0.045, w);
	float hub = 1.0 - edge_w(len - 0.07, w);
	return max(b, hub);
}

// Acanthus border: a scalloped band round the face edge (frame border), the centre left plain.
float acanthus(vec2 uv, float w) {
	vec2 c = uv - 0.5;
	float r = max(abs(c.x) * 1.1, abs(c.y));
	float wave = 0.025 * sin((atan(c.y, c.x)) * 18.0);
	return 1.0 - edge_w(0.38 + wave - r, w);
}

// Facets: a cut-gem triangle grid (three line families), color_b = the facet edges.
float facets(vec2 uv, float s, float w) {
	vec2 g = uv * s;
	float l1 = abs(fract(g.y) - 0.5);
	float l2 = abs(fract(g.x * 0.866 + g.y * 0.5) - 0.5);
	float l3 = abs(fract(g.x * 0.866 - g.y * 0.5) - 0.5);
	float m = min(l1, min(l2, l3));
	return 1.0 - edge_w(0.06 - (0.5 - m), w * s);
}

// Time-lock dial: a ring band with tick marks round the face centre.
float time_lock_dial(vec2 uv, float s, float w) {
	vec2 d = uv - vec2(0.5, 0.45);
	float len = length(d);
	float a = atan(d.y, d.x);
	float ring = 1.0 - edge_w(abs(len - 0.3) - 0.025, w);
	float ticks = max(floor(s), 6.0) * 4.0;
	float tick = edge_w(sin(a * ticks) * len - 0.012, w) * (1.0 - edge_w(abs(len - 0.36) - 0.03, w));
	return max(ring, tick);
}

// Stencil band: a forehead band of blocky stencil marks (container numbering), gaps like stencil bridges.
float stencil(vec2 uv, float s, float w) {
	float band = edge_w(uv.y - 0.12, w) * (1.0 - edge_w(uv.y - 0.27, w));
	vec2 g = vec2(uv.x * s * 1.5, (uv.y - 0.12) / 0.15 * 3.0);
	vec2 c = floor(g);
	float on = step(0.45, hash21(c + vec2(3.1, 7.7)));
	vec2 f = fract(g);
	float block = edge_w(f.x - 0.12, w * s) * (1.0 - edge_w(f.x - 0.82, w * s));
	return band * on * block;
}

// RT-B1 road lines: edge lines down both sides, a dashed centre line down to the nose, a stop line across the mouth.
float road_lines(vec2 uv, float s, float w) {
	float dx = abs(uv.x - 0.5);
	float side = edge_w(dx - 0.36, w) * (1.0 - edge_w(dx - 0.40, w));
	float dash = (1.0 - edge_w(dx - 0.02, w)) * (1.0 - edge_w(abs(fract(uv.y * s * 0.5) - 0.5) - 0.25, w * s))
		* (1.0 - edge_w(uv.y - 0.62, w));
	float stop = edge_w(uv.y - 0.70, w) * (1.0 - edge_w(uv.y - 0.76, w)) * (1.0 - edge_w(dx - 0.36, w));
	return max(max(side, dash), stop);
}

// RT-B1 tread: a tyre-tread band run down the face, V blocks pointing up it (as D's tex_mask_pattern_tread).
float tread(vec2 uv, float s, float w) {
	float dx = abs(uv.x - 0.5);
	float band = 1.0 - edge_w(dx - 0.28, w);
	float v = fract(uv.y * s + dx * 2.0);
	return band * (1.0 - edge_w(abs(v - 0.5) - 0.22, w * s));
}

// AH-B1 vinyl_label: a record's centre label, a disc at the nose bridge with a spindle hole (as D's
// tex_mask_pattern_vinyl_label off mask_base_vinyl).
float vinyl_label(vec2 uv, float w) {
	float r = length(uv - vec2(0.5, 0.45));
	return (1.0 - edge_w(r - 0.12, w)) * edge_w(r - 0.015, w);
}

float pattern_mask(vec2 uv) {
	float s = pattern_scale;
	// AA half width in uv units, taken here in uniform control flow (see edge_w).
	float aa = max(fwidth(uv.x) + fwidth(uv.y), 0.0005) * 0.75;
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
	} else if (pattern == 8) {
		return scales(uv, s, aa * s);
	} else if (pattern == 9) {
		return circuit(uv, s, aa * s);
	} else if (pattern == 10) {
		return prowl(uv, s, aa * s);
	} else if (pattern == 11) {
		return halftone(uv, s, aa * s);
	} else if (pattern == 12) {
		return crackle(uv, s, aa * s);
	} else if (pattern == 13) {
		return starburst(uv, s, aa);
	} else if (pattern == 14) {
		return guilloche(uv, s, aa);
	} else if (pattern == 15) {
		return vault_bolts(uv, s, aa);
	} else if (pattern == 16) {
		return acanthus(uv, aa);
	} else if (pattern == 17) {
		return facets(uv, s, aa);
	} else if (pattern == 18) {
		return time_lock_dial(uv, s, aa);
	} else if (pattern == 19) {
		return stencil(uv, s, aa);
	} else if (pattern == 20) {
		return road_lines(uv, s, aa);
	} else if (pattern == 21) {
		return tread(uv, s, aa);
	} else if (pattern == 22) {
		return vinyl_label(uv, aa);
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
	// D (round 244): on metal the colour pair drowned in reflections at 2 m; the pattern's color_b areas
	// lose half the metal so the pattern stays readable (no effect on non-metal materials).
	METALLIC = metallic_value * mix(1.0, 0.5, m * step(0.5, metallic_value));
	AO = mix(1.0, orm.r, detail_strength);
	if (has_normal) {
		NORMAL_MAP = texture(detail_normal, tuv).rgb;
		NORMAL_MAP_DEPTH = detail_strength;
	}
}
