// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus. Original Diwali artwork.
// Stable birth phases keep every spark anchored to its emission point.
const float TRAIL_LIFE = 1.45; // Seconds, below two-second history retention.
const float INTENSITY = 0.95; // 0..1.
const float DENSITY = 0.82; // Fraction of eligible motion samples, 0..1.
const float LIFT = 22.0; // Logical pixels per second; useful range 10..28.
const float TAU = 6.28318530718;
float spark_hash(float p) { return fract(sin(p*127.1+311.7)*43758.5453); }
vec4 cursor(vec2 uv) {
    vec4 source=umbriel_sample(uv);
    if(umbriel_pointer_count<3) return source;
    vec2 here=uv*umbriel_size;
    float gold=0.0,rose=0.0,glow=0.0;
    vec4 previous=vec4(0.0);
    for(int k=0;k<64;++k) {
        if(k<umbriel_pointer_count) {
            vec4 samplePoint=umbriel_pointer_path[k];
            if(k>0 && k<umbriel_pointer_count-1) {
                float travel=length((samplePoint.xy-previous.xy)*umbriel_size);
                float age=samplePoint.z;
                float seed=spark_hash(samplePoint.w+0.137);
                if(travel>=1.0 && travel<=180.0 && age<TRAIL_LIFE && seed<clamp(DENSITY,0.0,1.0)) {
                    float r=spark_hash(samplePoint.w+19.71);
                    float s=spark_hash(samplePoint.w+43.29);
                    float life=smoothstep(0.035,0.12,age)*(1.0-smoothstep(0.35,TRAIL_LIFE,age));
                    // Paired sparks fan gently outward and lift like warm embers.
                    for(int n=0;n<2;++n) {
                        float side=float(n)*2.0-1.0;
                        vec2 drift=vec2(side*(4.0+12.0*r)*age+sin(age*2.5+s*TAU)*age*3.0,
                            -age*LIFT*(0.65+0.35*s)+side*2.0);
                        vec2 q=here-samplePoint.xy*umbriel_size-drift;
                        if(dot(q,q)>144.0) continue;
                        float turn=r*TAU+age*(s-0.5)*0.6;
                        vec2 p=vec2(cos(turn)*q.x+sin(turn)*q.y,-sin(turn)*q.x+cos(turn)*q.y);
                        float core=exp(-dot(q,q)/(0.8+1.3*r));
                        float rays=exp(-abs(p.x)*2.3-abs(p.y)/(2.0+r*1.6))
                            +exp(-abs(p.y)*2.3-abs(p.x)/(2.0+r*1.6));
                        float glint=0.65+0.35*sin(age*2.0+r*TAU);
                        float amount=clamp(core*0.7+rays*0.45,0.0,1.0)*life*glint;
                        if(s>0.78 && n==1) rose=max(rose,amount);
                        else gold=max(gold,amount);
                        glow=max(glow,exp(-dot(q,q)/25.0)*life*0.16);
                    }
                }
            }
            previous=samplePoint;
        }
    }
    float tip=smoothstep(4.0,11.0,length((uv-umbriel_pointer)*umbriel_size));
    float strength=clamp(INTENSITY,0.0,1.0)*tip;
    vec3 colour=mix(source.rgb,vec3(1.0,0.43,0.055)*source.a,glow*strength);
    colour=mix(colour,vec3(1.0,0.85,0.36)*source.a,gold*strength);
    colour=mix(colour,vec3(1.0,0.30,0.39)*source.a,rose*strength);
    return vec4(colour,source.a);
}
