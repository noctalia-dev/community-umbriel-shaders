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

vec4 border(vec2 uv){
 vec2 p=(uv-umbriel_border_hole.xy)*umbriel_size;
 vec2 size=umbriel_border_hole.zw*umbriel_size;
 float d=umbriel_border_distance(uv);
 float along=p.x;
 if(p.x>size.x)along=size.x+p.y;
 else if(p.y>size.y)along=size.x+size.y+size.x-p.x;
 else if(p.x<0.0)along=2.0*size.x+size.y+size.y-p.y;
 float cell=floor(along/54.0),x=mod(along,54.0)-27.0;
 float chip=0.65+0.35*noise(vec2(along*0.8,d*2.0));
 float rail=max(stroke(abs(d-1.5),0.6),stroke(abs(d-6.2),0.55))*chip;
 float circuit=min(line(vec2(x,d),vec2(-27,3),vec2(-7,3)),min(line(vec2(x,d),vec2(-7,3),vec2(0,7)),line(vec2(x,d),vec2(0,7),vec2(17,7))));
 float node=stroke(abs(length(vec2(x-18.0,d-7.0))-2.2),0.6);
 float trace=max(stroke(circuit,0.55),node);
 float pulse=pow(0.5+0.5*sin(along*0.017-umbriel_time*2.2),16.0);
 float scar=stroke(line(vec2(x,d),vec2(-5,-1),vec2(6,10)),0.9)*step(0.78,hash(vec2(cell,5)));
 vec3 col=BRASS*(0.55+0.45*pulse);
 float a=rail*0.82;
 float b=trace*(0.40+0.60*pulse);col=mix(col,CYAN,b);a=max(a,b);
 col=mix(col,PINK,scar);a=max(a,scar*0.9);
 float glow=exp(-abs(d-4.0)*0.7)*pulse*0.22;
 a=max(a,glow);
 return vec4(col*a,a);
}
