// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus. Original Diwali artwork.
// A brief billowing cloud puff with vivid firework backlighting.
const float INTENSITY = 1.0; // 0..1, transient cloud opacity.
const float LIGHTING = 1.35; // 0..2, saturated coloured illumination.
const float CLOUD_SIZE = 105.0; // Logical pixels per billow.
float cloud_hash(vec2 p) {
    p=mod(p,4096.0);
    vec3 q=fract(vec3(p.xyx)*vec3(0.1031,0.1030,0.0973));
    q+=dot(q,q.yzx+33.33);
    return fract((q.x+q.y)*q.z);
}
float cloud_noise(vec2 p) {
    vec2 cell=floor(p),f=fract(p);
    f=f*f*(3.0-2.0*f);
    return mix(mix(cloud_hash(cell),cloud_hash(cell+vec2(1.0,0.0)),f.x),
               mix(cloud_hash(cell+vec2(0.0,1.0)),cloud_hash(cell+vec2(1.0)),f.x),f.y);
}
float cloud_fbm(vec2 p) {
    float sum=0.0,weight=0.533333;
    for(int octave=0;octave<4;++octave) {
        sum+=weight*cloud_noise(p);
        p=mat2(0.80,-0.60,0.60,0.80)*p*2.03+vec2(7.1,3.7);
        weight*=0.5;
    }
    return sum;
}

vec4 animation(vec2 uv) {
    float progress=clamp(umbriel_linear_progress,0.0,1.0);
    bool opening=umbriel_direction>0.0;
    vec4 source=umbriel_sample(uv);
    if(progress<=0.0) return opening?vec4(0.0):source;
    if(progress>=1.0) return opening?source:vec4(0.0);
    vec2 size=max(umbriel_size,vec2(1.0));
    vec2 seed=umbriel_random_seed.xy*31.0;
    vec2 p=uv*size/max(CLOUD_SIZE,30.0);
    // The same outward puff runs on both events; only content visibility differs.
    vec2 warp=vec2(cloud_fbm(p*0.63+seed+vec2(progress*0.5,-progress*0.8)),
                   cloud_fbm(p*0.63+seed+vec2(-progress*0.7,progress*0.4)+17.3));
    vec2 folded=p+2.1*(warp-0.5)+vec2(0.0,-progress*0.9);
    float broad=cloud_fbm(folded);
    float density=smoothstep(0.20,0.78,broad);
    vec2 centre=vec2(0.5,0.54)-vec2(0.0,progress*0.08);
    float distance=length((uv-centre)*size)/max(length(size*0.56),1.0);
    float radius=mix(-0.12,1.35,1.0-pow(1.0-progress,1.7));
    float front=distance-radius+(broad-0.5)*0.30;
    float puff=1.0-smoothstep(-0.08,0.10,front);
    float envelope=smoothstep(0.0,0.15,progress)*(1.0-smoothstep(0.56,1.0,progress));
    float lobes=smoothstep(0.12,0.65,broad);
    float paint=puff*envelope*(0.40+0.60*lobes)*clamp(INTENSITY,0.0,1.0);
    float coverage;
    if(opening) {
        float reveal=1.0-smoothstep(-0.09,0.09,distance-radius+0.13);
        coverage=mix(reveal*smoothstep(0.12,0.58,progress),1.0,smoothstep(0.65,1.0,progress));
    } else {
        coverage=1.0-smoothstep(0.02,0.58,progress);
    }
    // Multiple quick blooms light the folds from behind, with deep coloured shadows.
    float gold=exp(-pow((progress-0.24)/0.17,2.0));
    float rose=exp(-pow((progress-0.43)/0.21,2.0));
    float cyan=exp(-pow((progress-0.61)/0.19,2.0));
    vec2 q=(uv-0.5)*size/max(min(size.x,size.y),1.0);
    float left=exp(-dot(q+vec2(0.30,0.05),q+vec2(0.30,0.05))*2.5);
    float right=exp(-dot(q-vec2(0.28,-0.10),q-vec2(0.28,-0.10))*2.5);
    vec3 light=vec3(1.0,0.52,0.035)*gold*left
              +vec3(1.0,0.025,0.31)*rose*right
              +vec3(0.035,0.68,1.0)*cyan*(0.3+0.7*left);
    float transmission=0.35+1.6*exp(-density*1.9);
    vec3 cloud=vec3(0.13,0.025,0.22)*(0.35+0.65*density)
        +light*transmission*clamp(LIGHTING,0.0,2.0);
    float hot=gold*left*pow(1.0-density,2.0);
    cloud=mix(min(cloud,vec3(1.0)),vec3(1.0,0.94,0.67),clamp(hot*0.65,0.0,0.55));
    float alpha=(coverage+(1.0-coverage)*paint)*source.a;
    // Reveal content over the puff, so rolling folds cannot uncover a closing
    // window again or briefly re-cover a window that has already appeared.
    vec3 rgb=source.rgb*coverage+cloud*paint*(1.0-coverage)*source.a;
    return vec4(rgb,alpha);
}
