shader_type canvas_item;
render_mode unshaded;

// Lightweight, original cosmic scene: deep-space nebulae, wispy dust,
// twinkling pinprick stars and a soft animated aurora. No downloaded assets.
uniform vec4 void_color : source_color = vec4(0.018,0.024,0.095,1.0);
uniform vec4 blue_nebula : source_color = vec4(0.08,0.39,0.93,1.0);
uniform vec4 magenta_nebula : source_color = vec4(0.60,0.15,0.95,1.0);
uniform float activity : hint_range(0.0,1.0) = 0.56;
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
 vec2 x=vec2(uv.x*1.5,uv.y*2.05);
 float t=TIME*motion_speed;
 float cloudy=fbm(x*2.4+vec2(t,-t*0.32));
 float wisps=fbm(x*4.4-vec2(t*0.4,t*0.25));
 float whirl=sin(uv.y*10.0+uv.x*7.0+cloudy*8.0+t)*0.5+0.5;
 float left=exp(-distance(uv,vec2(0.11+sin(t)*0.07,0.28))*3.55);
 float right=exp(-distance(uv,vec2(0.94,0.72+cos(t*.72)*0.055))*3.3);
 float mag=clamp((cloudy-0.34)*2.35+whirl*.18,0.0,1.0)*left;
 float cyan=clamp((wisps-.31)*2.4+whirl*.12,0.0,1.0)*right;
 vec3 col=void_color.rgb;
 col += magenta_nebula.rgb*mag*activity*.40;
 col += blue_nebula.rgb*cyan*activity*.55;
 col += vec3(.09,.11,.3)*max(0.0,cloudy-.5)*.20;
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
 col += vec3(.67,.86,1.0)*star*appear*twinkle*.60;
 col *= 1.0-.25*pow(distance(uv,vec2(.5,.5))*1.14,1.3);
 COLOR=vec4(col,1.0);
}
