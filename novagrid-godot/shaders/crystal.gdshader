shader_type canvas_item;
render_mode unshaded;

// Faceted, semi-translucent neon crystal. The mockup's V-shaped bevel,
// milky specular crown, colored glass core, light piping and bright bottom rim
// are built into one fast single-pass CanvasItem shader.
uniform vec4 gem_color : source_color = vec4(1.0, 0.7, 0.08, 1.0);
uniform float shine : hint_range(0.0,1.0) = 0.93;

float rounded_box(vec2 p, vec2 b, float radius) {
 vec2 q=abs(p)-b+radius;
 return length(max(q,0.0))+min(max(q.x,q.y),0.0)-radius;
}
void fragment() {
 vec2 uv=UV;
 vec2 p=(uv-.5)*2.0;
 float outer=rounded_box(p,vec2(.94,.94),.18);
 float mask=1.0-smoothstep(-.012,.035,outer);
 float inner=rounded_box(p,vec2(.74,.74),.075);
 float rim=clamp((inner-outer)*9.0,0.0,1.0);
 float top=pow(1.0-uv.y,2.0);
 float bottom=pow(uv.y,4.0);
 float left=pow(1.0-uv.x,4.0);
 float right=pow(uv.x,4.0);
 // Reference-like crystal facets: symmetric translucent diamond / X.
 float top_v=1.0-smoothstep(.012,.070,abs(uv.y-(.14+.52*abs(uv.x-.5))));
 float bottom_v=1.0-smoothstep(.018,.085,abs(uv.y-(.85-.53*abs(uv.x-.5))));
 float broad_highlight=exp(-pow((uv.y-.16)/.155,2.0))*
  smoothstep(.05,.23,uv.x)*(1.0-smoothstep(.77,.95,uv.x));
 float spine=1.0-smoothstep(.02,.055,abs(uv.x-.5));
 float edge=smoothstep(.06,.0,abs(p.x)-.83)+smoothstep(.06,.0,abs(p.y)-.83);
 float glint=pow(max(0.0,sin((uv.x*9.1-uv.y*12.0)+TIME*1.1)),12.0)*.05;
 vec3 base=gem_color.rgb;
 vec3 core=mix(base*.72,base*1.18,top*.55);
 core=mix(core,vec3(1.0),broad_highlight*.52*shine);
 core+=vec3(1.0)*rim*(.26+.36*(top+bottom+left+right));
 core+=vec3(1.0)*(top_v*.19+bottom_v*.21+spine*.025);
 core+=base*(glint*.25+bottom*.16);
 core+=vec3(.89,.96,1.0)*edge*.09;
 // Bright neon hot cores, restrained to avoid washed-out whites.
 core=clamp(core,vec3(0.0),vec3(1.3));
 float transparency=mask*(.96-.065*(1.0-rim));
 COLOR=vec4(core,transparency);
}
