// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
const vec3 CYAN=vec3(0.08,0.80,1.0);
const vec3 PINK=vec3(0.96,0.12,0.48);
const vec3 BRASS=vec3(0.72,0.49,0.22);
const float PI=3.14159265;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);}
float grain(vec2 p){return 0.55*noise(p*0.035)+0.30*noise(p*0.13)+0.15*noise(p*0.6);}
float line(vec2 p,vec2 a,vec2 b){vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/max(dot(v,v),0.001),0.0,1.0));}
float stroke(float d,float w){return 1.0-smoothstep(w,w+0.8/max(umbriel_scale,0.5),d);}
vec4 paint(vec4 s,vec3 c,float a){return vec4(mix(s.rgb,c*s.a,clamp(a,0.0,1.0)),s.a);}
float edge(vec2 p,vec2 size){return min(min(p.x,p.y),min(size.x-p.x,size.y-p.y));}
// Etched broken concentric rings, radial ticks and an inner diamond.
float seal(vec2 q,float radius){
 float r=length(q),a=atan(q.y,q.x);
 float ring=stroke(abs(r-radius),0.8)*step(-0.7,sin(a*3.0+0.4));
 ring=max(ring,stroke(abs(r-radius*0.78),0.55)*step(0.1,cos(a*5.0)));
 float tick=stroke(abs(sin(a*12.0))*r,0.65)*step(radius*0.87,r)*(1.0-step(radius*1.10,r));
 float diamond=stroke(abs(abs(q.x)+abs(q.y)-radius*0.72)*0.707,0.65);
 return max(max(ring,tick),diamond);
}

vec4 animation(vec2 uv){
 float t=umbriel_clamped_progress;if(t<=0.0||t>=1.0)return umbriel_sample(uv);
 float pulse=sin(t*PI),release=sin(t*PI)*sin(t*PI);
 vec2 size=umbriel_size,p=uv*size,q=p-size*0.5;
 vec4 s=umbriel_sample(uv);
 // Three spatial echoes; this is a deterministic temporal impression, not feedback.
 for(int i=1;i<=3;i++){
  float k=float(i),a=0.012*pulse*k;
  vec2 ghost=mat2(cos(a),-sin(a),sin(a),cos(a))*q+size*0.5+vec2(-5,2)*k*pulse;
  vec4 echo=umbriel_sample(ghost/size);
  float outlines=abs(echo.a-s.a)+length(echo.rgb-s.rgb)*0.5;
  s=paint(s,mix(CYAN,vec3(0.27,0.90,0.59),k/3.0),clamp(outlines,0.0,1.0)*release*0.30/k);
 }
 float radius=min(size.x,size.y)*0.40;
 float clock=seal(q,radius)*(1.0-smoothstep(0.35,0.8,t))*pulse;
 return paint(s,BRASS,clock*0.25);
}
