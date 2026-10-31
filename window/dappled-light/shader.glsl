// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
const float SHADOW_STRENGTH = 0.10; // 0..0.25; preserve readable content.
const float LIGHT_STRENGTH = 0.025; // 0..0.10; warm reflected light.
const float LEAF_SCALE = 110.0; // Logical pixels per canopy cell.
const float BREEZE_SPEED = 0.22;
float leaf_hash(vec2 p) {
    return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
vec4 window(vec2 uv) {
    vec4 source=umbriel_sample(uv);
    float t=umbriel_time*BREEZE_SPEED;
    vec2 p=uv*umbriel_size/max(LEAF_SCALE,30.0);
    vec2 cell=floor(p);
    float shadow=0.0;
    for (int y=-1;y<=1;++y) {
        for (int x=-1;x<=1;++x) {
            vec2 id=cell+vec2(float(x),float(y));
            float seed=leaf_hash(id);
            vec2 centre=id+vec2(0.25+0.5*seed,0.25+0.5*leaf_hash(id+23.0));
            centre+=0.08*vec2(sin(t+seed*19.0),cos(t*0.73+seed*23.0));
            float angle=seed*6.28+0.12*sin(t*0.81+seed*13.0);
            vec2 q=p-centre;
            q=vec2(cos(angle)*q.x+sin(angle)*q.y,-sin(angle)*q.x+cos(angle)*q.y);
            float length=0.34+0.18*seed;
            float width=0.22*max(1.0-q.x*q.x/(length*length),0.0);
            float shape=(1.0-smoothstep(width-0.05,width+0.14,abs(q.y)))
                       *(1.0-smoothstep(length-0.04,length+0.12,abs(q.x)));
            shadow=max(shadow,shape*(0.55+0.45*seed));
        }
    }
    float light=0.5+0.5*sin(p.x*1.7+p.y*1.1+0.3*sin(t));
    float shade=clamp(SHADOW_STRENGTH,0.0,0.25)*shadow;
    vec3 colour=source.rgb*(1.0-shade);
    vec3 warm=vec3(1.0,0.93,0.76);
    colour=mix(colour,warm*source.a,clamp(LIGHT_STRENGTH,0.0,0.10)*light*(1.0-shadow));
    return vec4(colour,source.a);
}
