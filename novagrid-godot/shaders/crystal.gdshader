shader_type canvas_item;
render_mode unshaded;

// NovaGrid multicolour neon crystal: smooth glass face with illumination
// inside each block, rounded bevel, glossy softbox spots and luminous rims.
// No crossed facets, creases, centre markings or internal symbols.
// Only one prebaked 80x80 tile per palette colour is required on mobile.
uniform vec4 gem_color : source_color = vec4(0.12, 0.9, 1.0, 1.0);
uniform float shine : hint_range(0.0,1.0) = 0.94;
uniform float inner_illumination : hint_range(0.0,2.0) = 1.30;

float rounded_box(vec2 p, vec2 half_size, float radius) {
 vec2 q = abs(p) - half_size + vec2(radius);
 return length(max(q, vec2(0.0))) + min(max(q.x,q.y),0.0) - radius;
}
void fragment() {
 vec2 uv = UV;
 vec2 pos = uv * 2.0 - 1.0;
 float outer_sdf = rounded_box(pos,vec2(0.93),0.13);
 float opacity = 1.0 - smoothstep(-0.016,0.020,outer_sdf);
 float inside = -outer_sdf;
 float glass_edge = 1.0 - smoothstep(0.02,0.20,inside);
 float face_sdf = rounded_box(pos,vec2(0.76),0.085);
 float face = 1.0 - smoothstep(-0.025,0.06,face_sdf);

 // Lighting comes from within the cube, not from engraved facets.
 float glow_core = exp(-dot(pos,pos)*2.2);
 float underlight = exp(-pow((uv.y-0.76)/0.27,2.0));
 vec3 base = gem_color.rgb;
 vec3 glass = base * (0.44 + 0.19 * uv.y);
 glass += base * (0.55*glow_core + 0.18*underlight)
     * inner_illumination * face;

 // Continuous, luminous glass border and polished upper/lower reflections.
 glass += base * glass_edge * 0.42;
 float top_rim = exp(-pow((uv.y-0.085)/0.028,2.0))
     * (1.0-smoothstep(0.67,0.92,abs(pos.x)));
 float bottom_rim = exp(-pow((uv.y-0.926)/0.026,2.0))
     * (1.0-smoothstep(0.67,0.92,abs(pos.x)));
 glass += base * bottom_rim * 0.53;
 glass += vec3(0.70,0.88,1.0) * top_rim * 0.33;

 // Small curved softbox glints: smooth spots, no intersecting lines.
 float softbox = exp(-pow((uv.y-0.185)/0.058,2.0))
     * (1.0-smoothstep(0.23,0.57,abs(uv.x-0.50)));
 float glint = exp(-pow((uv.x-0.23)/0.095,2.0)
     -pow((uv.y-0.22)/0.065,2.0));
 glass += vec3(0.88,0.96,1.0)*softbox*shine*0.37;
 glass += vec3(1.0)*glint*shine*0.39;
 glass = mix(glass,base*0.40+vec3(0.07,0.08,0.11),
     (1.0-face)*0.12);
 COLOR = vec4(clamp(glass,vec3(0.0),vec3(1.0)),
     opacity*gem_color.a);
}
