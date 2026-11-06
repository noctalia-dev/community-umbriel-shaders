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
 float t=umbriel_clamped_progress,v=umbriel_direction>0.0?t:1.0-t;
 if(v<=0.0)return vec4(0);if(v>=1.0)return umbriel_sample(uv);
 vec2 size=umbriel_size,p=uv*size;
 // Staggered crystal tessellation, each piece travelling toward its final cell.
 float cellSize=54.0;
 vec2 grid=p/cellSize;grid.x+=mod(floor(grid.y),2.0)*0.5;
 vec2 id=floor(grid),local=fract(grid)-0.5;
 float seed=hash(id+umbriel_random_seed.xy*31.0);
 float delay=0.26*seed+0.20*(1.0-uv.y);
 float assemble=smoothstep(delay,min(delay+0.48,0.98),v);
 vec2 travel=vec2((seed-0.5)*90.0,45.0+seed*75.0)*(1.0-assemble);
 vec4 s=umbriel_sample(uv+travel/size);
 float shard=1.0-smoothstep(0.43,0.5,abs(local.x)+abs(local.y)*0.48*(1.0-assemble));
 float seam=stroke(abs(abs(local.x)+abs(local.y)*0.48-0.45)*cellSize,0.65);
 s=paint(s,mix(CYAN,BRASS,seed),seam*sin(assemble*PI)*0.85);
 return s*assemble*mix(shard,1.0,smoothstep(0.70,1.0,v));
}
