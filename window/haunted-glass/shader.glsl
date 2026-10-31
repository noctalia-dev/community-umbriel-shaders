// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus. Original shader.
// Three hooked talons dent the pane, slash it, and leave healing fractures.
const float INTENSITY = 0.90;
const float ATTACK_SIZE = 120.0; // logical pixels, reduced to fit small windows
const float CYCLE_SECONDS = 12.0;
const float PRESS_DEPTH = 7.0; // logical-pixel refraction at contact
const vec3 IVORY = vec3(0.82,0.88,0.67);
const vec3 GLASS = vec3(0.78,0.94,0.91);
float hash21(vec2 p) {
    vec3 q=fract(vec3(p.xyx)*0.1031);q+=dot(q,q.yzx+33.33);
    return fract((q.x+q.y)*q.z);
}
vec2 rotatePoint(vec2 p,float a) {
    float c=cos(a),s=sin(a);return vec2(c*p.x-s*p.y,s*p.x+c*p.y);
}
float segment(vec2 p,vec2 a,vec2 b) {
    vec2 ab=b-a;return length(p-a-ab*clamp(dot(p-a,ab)/max(dot(ab,ab),0.00001),0.0,1.0));
}
vec2 talonTip(int i) {
    if(i==0)return vec2(-0.55,0.03);
    if(i==1)return vec2(0.0,-0.16);
    return vec2(0.53,-0.03);
}
vec2 rake(float t) {
    return vec2(1.65*t,1.12*t-0.20*sin(t*3.14159265));
}
vec2 trace(vec2 tip,float t) {return rotatePoint(tip,-0.16+0.28*t)+rake(t);}

vec4 window(vec2 uv) {
    vec4 source=umbriel_sample(uv);
    vec2 size=max(umbriel_size,vec2(1.0));
    float unit=min(ATTACK_SIZE,min(size.x/5.2,size.y/4.4));
    float clock=umbriel_time+hash21(floor(size*0.1))*2.0;
    float phase=mod(clock,CYCLE_SECONDS);
    float seed=hash21(vec2(floor(clock/CYCLE_SECONDS),floor(size.x)));
    vec2 origin=size*vec2(mix(0.38,0.47,seed),0.43);
    float mirror=seed<0.5?-1.0:1.0;
    vec2 p=(uv*size-origin)/max(unit,1.0);p.x*=mirror;
    if(phase>8.6 || p.x< -1.5 || p.x>3.1 || p.y< -1.5 || p.y>2.1)return source;
    float attack=clamp((phase-1.7)/0.5,0.0,1.0);
    float drag=attack*attack*(3.0-2.0*attack);
    float appear=smoothstep(0.1,0.85,phase);
    float recoil=smoothstep(2.2,2.85,phase);
    float clawAlpha=appear*(1.0-recoil);
    float pressure=smoothstep(0.6,1.4,phase)*(1.0-smoothstep(2.1,2.55,phase));
    float heal=1.0-smoothstep(4.0,8.4,phase);
    vec2 shift=vec2(0.0);
    float claw=100.0,clawShade=0.0,contact=0.0;
    float slash=1000.0,fracture=1000.0;
    vec2 local=rotatePoint(p-rake(drag)+vec2(0.0,recoil*0.55),0.16-0.28*drag);
    for(int i=0;i<3;++i) {
        vec2 tip=talonTip(i);
        vec2 point=trace(tip,drag);
        vec2 q=p-point;
        float r=length(q);
        // Local pressure dents the content, with a brief ripple as the claw strikes.
        float dent=exp(-r*r/0.15)*pressure;
        float shock=exp(-pow((r-(phase-1.7)*1.8)/0.08,2.0))
            *smoothstep(1.7,1.78,phase)*(1.0-smoothstep(2.1,2.45,phase));
        shift+=q/max(r,0.015)*(dent+shock*0.48)*PRESS_DEPTH;
        contact=max(contact,exp(-r*r/0.0018)*pressure);
        // A heavy recurved talon, tapering from an arched root to the contact tip.
        vec2 a=tip+vec2(-0.31,-0.69),b=tip+vec2(0.36,-0.73),c=tip;
        vec2 previous=a;
        for(int j=1;j<=12;++j) {
            float t=float(j)/12.0;
            vec2 next=mix(mix(a,b,t),mix(b,c,t),t);
            float width=0.12*pow(1.0-t,0.70)+0.004;
            float d=segment(local,previous,next)-width;
            if(d<claw){claw=d;clawShade=t;}
            previous=next;
        }
        if(phase>1.7) {
            for(int j=0;j<12;++j) {
                float t=float(j)/12.0;
                if(t<drag) {
                    vec2 a=trace(tip,t),b=trace(tip,min(float(j+1)/12.0,drag));
                    slash=min(slash,segment(p,a,b)*unit);
                }
            }
            // Fractures fork outward from deposited cuts, never ahead of the talon.
            for(int j=0;j<4;++j) {
                float t=0.12+float(j)*0.23;
                float grow=smoothstep(t,t+0.13,drag);
                if(grow>0.0) {
                    float side=mod(float(i+j),2.0)<1.0?-1.0:1.0;
                    vec2 a=trace(tip,t);
                    float variation=hash21(vec2(float(i*4+j),seed*11.0));
                    vec2 b=a+vec2(-0.10*side,0.13*side)*grow;
                    vec2 c=b+vec2(-0.17*side,0.05*side)*(0.6+variation)*grow;
                    vec2 e=c+vec2(-0.05*side,0.11*side)*grow;
                    fracture=min(fracture,min(segment(p,a,b),min(segment(p,b,c),segment(p,c,e)))*unit);
                    fracture=min(fracture,segment(p,b,b+vec2(0.09*side,0.15*side)*grow)*unit);
                }
            }
        }
    }
    shift.x*=mirror;
    vec4 refracted=umbriel_sample(clamp(uv+shift/size,vec2(0.0),vec2(1.0)));
    vec3 rgb=refracted.rgb/max(refracted.a,0.001)*source.a;
    // Behind the talons, a faint shadow suggests the unseen attacker.
    float shadow=exp(-dot(local-vec2(-0.08,-0.50),local-vec2(-0.08,-0.50))/0.8)*clawAlpha;
    rgb*=1.0-shadow*0.27*INTENSITY;
    float aa=0.7/max(unit*umbriel_scale,1.0);
    float silhouette=1.0-smoothstep(-aa,aa,claw);
    float edge=exp(-abs(claw)*65.0);
    float clawMask=clamp((silhouette*0.73+edge*0.22)*clawAlpha*INTENSITY,0.0,1.0);
    vec3 clawColor=mix(vec3(0.14,0.23,0.18),IVORY,0.35+0.65*clawShade);
    rgb=mix(rgb,clawColor*source.a,clawMask);
    float groove=(1.0-smoothstep(0.7,3.7,slash))*heal*INTENSITY;
    float crackShadow=(1.0-smoothstep(0.5,1.9,fracture))*heal*INTENSITY;
    rgb*=1.0-max(groove*0.75,crackShadow*0.60);
    float lip=exp(-pow((slash-2.8)/0.72,2.0))*heal;
    float cracks=(1.0-smoothstep(0.20,0.80,fracture))*heal;
    rgb=mix(rgb,GLASS*source.a,clamp((lip*0.78+cracks*0.84)*INTENSITY,0.0,1.0));
    rgb=mix(rgb,vec3(0.92,1.0,0.76)*source.a,contact*0.9*INTENSITY);
    return vec4(rgb,source.a);
}
