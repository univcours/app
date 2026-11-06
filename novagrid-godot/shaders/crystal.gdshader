shader_type canvas_item;
render_mode unshaded;
uniform vec4 gem_color : source_color = vec4(0.1,0.9,1.0,1.0);
uniform float shine : hint_range(0.0,1.0) = 0.67;

float rounded_sdf(vec2 p,vec2 b,float r) {
 vec2 q=abs(p)-b+r;
 return length(max(q,0.0))+min(max(q.x,q.y),0.0)-r;
}
void fragment() {
 vec2 p=UV;
 float sdf=rounded_sdf((p-.5)*2.0,vec2(.91,.91),.23);
 float shell=1.0-smoothstep(-.016,.022,sdf);
 float rim=1.0-smoothstep(.025,.11,abs(sdf));
 float bevel=1.0-smoothstep(.03,.20,abs(sdf+.14));
 float top=pow(clamp(1.0-p.y,0.0,1.0),1.55);
 float bottom=pow(p.y,2.1);
 float broad=exp(-pow((p.y-.19)/.17,2.0))*smoothstep(.09,.22,p.x)*(1.0-smoothstep(.78,.96,p.x));
 float edge_light=smoothstep(.14,.02,p.x)*(1.0-p.y)*.24 + smoothstep(.16,.02,p.y)*.28;
 float caustic=sin((p.x*8.0-p.y*4.0)+TIME*1.4)*.5+.5;
 float caustic_line=pow(max(0.0,1.0-abs(p.y-(.59+.035*sin(p.x*6.0+TIME*.32)))*15.0),4.0);
 vec3 col=gem_color.rgb*(.47+top*.62-bottom*.23);
 col += vec3(1.0)*broad*.28*shine;
 col += vec3(.83,.94,1.0)*(edge_light+bevel*.16);
 col += gem_color.rgb*(caustic_line*.08+caustic*.018)*shine;
 col=mix(col,col*.36,bottom*.29);
 col += vec3(1.0)*rim*.13;
 float alpha=shell;
 COLOR=vec4(col,alpha);
}
