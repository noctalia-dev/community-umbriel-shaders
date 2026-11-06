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

vec4 cursor(vec2 uv){
 vec4 s=umbriel_sample(uv);vec2 p=uv*umbriel_size;
 float cyan=0.0,pink=0.0,sparks=0.0;
 for(int i=0;i<63;i++)if(i+1<umbriel_pointer_count){
  vec4 a=umbriel_pointer_path[i],b=umbriel_pointer_path[i+1];
  vec2 start=a.xy*umbriel_size,v=(b.xy-a.xy)*umbriel_size;float len=length(v);
  if(len>0.4&&len<200.0&&b.z<0.42){
   float f=clamp(dot(p-start,v)/max(dot(v,v),0.001),0.0,1.0);
   float age=mix(a.z,b.z,f),fade=1.0-smoothstep(0.03,0.42,age);
   vec2 n=vec2(-v.y,v.x)/len,q=p-start;
   float birth=mix(a.w,b.w,f),wave=sin(birth*75.0)*5.0;
   cyan=max(cyan,stroke(line(p,start,start+v),1.1)*fade);
   vec2 offset=n*(5.0+wave);
   pink=max(pink,stroke(line(p,start+offset,start+v+offset),0.8)*fade*step(-0.45,sin(birth*125.0)));
   vec2 mote=start+n*(10.0+age*24.0)*sign(sin(a.w*91.0));
   float fleck=stroke(line(p,mote,mote+vec2(3,-4)),0.7)*fade*step(0.82,hash(vec2(a.w,3.0)));
   sparks=max(sparks,fleck);
  }
 }
 float tip=smoothstep(5.0,13.0,length((uv-umbriel_pointer)*umbriel_size));
 s=paint(s,vec3(0.035,0.025,0.09),max(cyan,pink)*tip*0.8);
 s=paint(s,CYAN,cyan*tip*0.9);s=paint(s,PINK,pink*tip*0.85);
 return paint(s,vec3(0.85,0.95,1.0),sparks*tip);
}
