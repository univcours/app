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
 vec2 p=uv*2.0-1.0;
 float outer=rounded_box(p,vec2(.97),.065);
 float mask=1.0-smoothstep(-.008,.018,outer);
 float inset=.155;
 vec2 inner=clamp((uv-inset)/(1.0-2.0*inset),0.0,1.0);
 float bevel=min(min(uv.x,1.0-uv.x),min(uv.y,1.0-uv.y));
 float top_facet=step(uv.y,uv.x)*step(uv.y,1.0-uv.x)*(1.0-step(inset,bevel));
 float left_facet=step(uv.x,uv.y)*step(uv.x,1.0-uv.y)*(1.0-step(inset,bevel));
 float bottom_facet=step(1.0-uv.y,uv.x)*step(1.0-uv.y,1.0-uv.x)*(1.0-step(inset,bevel));
 vec3 base=gem_color.rgb;
 float diamond=abs(inner.x-.5)+abs(inner.y-.5);
 float crease=1.0-smoothstep(.006,.032,abs(diamond-.48));
 float triangle=step(abs(inner.x-.5),abs(inner.y-.5));
 vec3 core=base*(.55+uv.y*.24+triangle*.11);
 core+=base*top_facet*.48+base*left_facet*.16;
 core-=base*bottom_facet*.22;
 // Softbox reflection restricted to the crown, with a diagonal glass streak.
 float crown=exp(-pow((uv.y-.16)/.075,2.0))*(1.0-smoothstep(.25,.50,abs(uv.x-.5)));
 float diagonal=exp(-pow((uv.x+uv.y*.72-.43)/.06,2.0));
 core=mix(core,vec3(.94,.97,1.0),crown*.52*shine);
 core+=vec3(.7,.85,1.0)*crease*.18;
 core+=base*diagonal*.18;
 float rim=1.0-smoothstep(.01,.035,bevel);
 core=mix(core,base*.50+vec3(.48),rim*.78);
 float bottom_rim=exp(-pow((uv.y-.956)/.012,2.0));
 core+=base*bottom_rim*.25;
 COLOR=vec4(clamp(core,vec3(0.0),vec3(1.0)),mask);
}
