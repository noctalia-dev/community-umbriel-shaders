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
 vec4 s=umbriel_sample(uv);float t=umbriel_clamped_progress;
 if(umbriel_direction<=0.0||t<=0.0||t>=1.0)return s;
 vec2 p=uv*umbriel_size;float e=edge(p,umbriel_size);
 float a=atan((uv.y-0.5)*umbriel_size.y,(uv.x-0.5)*umbriel_size.x);
 float delta=abs(mod(a-t*6.2831853+PI,6.2831853)-PI);
 float charge=exp(-delta*5.0)*sin(t*PI);
 // Constrain decoration to the perimeter even when the host target is a window capture.
 float ring=1.0-smoothstep(4.0,12.0,e);
 return paint(s,mix(BRASS,CYAN,charge),ring*sin(t*PI)*(0.25+0.75*charge));
}
