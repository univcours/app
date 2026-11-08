shader_type canvas_item;
render_mode unshaded;

// Lightweight, original cosmic scene: deep-space nebulae, wispy dust,
// twinkling pinprick stars and a soft animated aurora. No downloaded assets.
uniform vec4 void_color : source_color = vec4(0.028,0.014,0.105,1.0);
uniform vec4 blue_nebula : source_color = vec4(0.09,0.59,1.0,1.0);
uniform vec4 magenta_nebula : source_color = vec4(0.81,0.16,1.0,1.0);
uniform bool reduced_effects = false;
uniform float activity : hint_range(0.0,1.0) = 1.0;
uniform float motion_speed : hint_range(0.0,1.0) = 0.13;

float random21(vec2 p) {
 p = fract(p * vec2(123.34, 345.45));
 p += dot(p,p + 34.345);
 return fract(p.x * p.y);
}
float n2(vec2 x) {
 vec2 i=floor(x), f=fract(x);
 f=f*f*(3.0-2.0*f);
 return mix(mix(random21(i),random21(i+vec2(1.0,0.0)),f.x),
            mix(random21(i+vec2(0.0,1.0)),random21(i+vec2(1.0,1.0)),f.x),f.y);
}
float fbm(vec2 p) {
 float v=0.0, a=0.5;
 for (int i=0;i<4;i++) {
  v += a*n2(p);
  p = p*2.13 + vec2(1.3,2.6);
  a *= 0.48;
 }
 return v;
}
void fragment() {
 vec2 uv=UV;
 vec2 x=vec2(uv.x*1.35,uv.y*1.77);
 float t=TIME*motion_speed;
 if (reduced_effects) {
  float haze=n2(x*3.5);
  vec3 low=void_color.rgb+mix(magenta_nebula.rgb,blue_nebula.rgb,uv.x)*haze*.20;
  COLOR=vec4(low,1.0);
 } else {
 float cloudy=fbm(x*2.4+vec2(t,-t*0.32));
 float wisps=fbm(x*4.4-vec2(t*0.4,t*0.25));
 float whirl=sin(uv.y*10.0+uv.x*7.0+cloudy*8.0+t)*0.5+0.5;
 float left=exp(-distance(uv,vec2(0.05+sin(t)*0.07,0.30))*2.15);
 float right=exp(-distance(uv,vec2(0.97,0.72+cos(t*.72)*0.055))*2.10);
 float mag=clamp((cloudy-0.34)*2.35+whirl*.18,0.0,1.0)*left;
 float cyan=clamp((wisps-.31)*2.4+whirl*.12,0.0,1.0)*right;
 vec3 col=void_color.rgb;
 // Bright diagonal Milky Way-like river of original procedural stardust.
 float ribbon=uv.y-(.78-uv.x*.48+sin(uv.x*5.4+t*.8)*.066);
 float band=exp(-pow(ribbon/.24,2.0));
 float band_noise=fbm(uv*vec2(6.7,9.5)+vec2(t*.32,-t*.2));
 vec3 stream_colors=mix(vec3(.29,.10,.62),vec3(.08,.45,.73),clamp(uv.x*.91,0.0,1.0));
 float filament=fbm(uv*vec2(32.0,43.0)+vec2(t*.1));
 float fracture=smoothstep(.39,.7,filament)*band;
 col += band*stream_colors*(.25+band_noise*.75)*activity;
 col += mix(magenta_nebula.rgb,blue_nebula.rgb,uv.x)*fracture*.53*activity;
 col += magenta_nebula.rgb*mag*activity*.90;
 col += blue_nebula.rgb*cyan*activity*.91;
 float cosmic_swirl=exp(-pow((uv.y-.30+.16*sin(uv.x*8.0+t*.8))/.19,2.0));
 col+=vec3(.20,.05,.43)*cosmic_swirl*.22*(.3+cloudy);
 col += vec3(.14,.14,.42)*max(0.0,cloudy-.38)*.31;
 float dust=fbm(uv*vec2(21.0,33.0)+t*.03);
 col += vec3(.08,.15,.27)*pow(dust,4.0)*.17;
 // GPU-sparse starfield, deterministic spatial hashing; no giant particles.
 vec2 space=uv*vec2(155.0,285.0);
 vec2 star_id=floor(space);
 vec2 star_uv=fract(space)-.5;
 float random_star=random21(star_id);
 float dist=length(star_uv);
 float star=1.0-smoothstep(.024,.10,dist);
 float appear=step(.991,random_star);
 float twinkle=.75+.25*sin(TIME*(1.5+random_star*3.0)+random_star*61.0);
 col += vec3(.88,.94,1.0)*star*appear*twinkle*.85;
 col *= 1.0-.16*pow(distance(uv,vec2(.5,.5))*1.14,1.3);
 // Keep the actual puzzle grid legible in the middle.
 float center_fade=1.0-.15*exp(-pow((uv.x-.5)/.39,2.0));
 col*=center_fade;
 COLOR=vec4(col,1.0);
 }
}
