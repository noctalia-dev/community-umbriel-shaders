// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus. Original Diwali artwork.
// Slowly billowing clouds illuminated from behind by unseen fireworks.
const float INTENSITY = 0.48; // 0..0.8; translucent cloud coverage.
const float CLOUD_SPEED = 0.045; // Slow independent rolling motion; zero freezes clouds.
const float CLOUD_SIZE = 190.0; // Logical pixels per broad billow.
const float FLASH_STRENGTH = 1.0; // 0..2; coloured backlight; zero leaves quiet clouds.
const float FLASH_SPEED = 0.85; // Pulse timing; zero holds the opening illumination.

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
vec3 cloud_flash_colour(float n) {
    float hue=cloud_hash(vec2(n,31.0));
    if(hue<0.20) return vec3(1.0,0.38,0.07);
    if(hue<0.40) return vec3(1.0,0.08,0.34);
    if(hue<0.60) return vec3(0.15,0.52,1.0);
    if(hue<0.80) return vec3(0.65,0.14,1.0);
    return vec3(0.12,1.0,0.55);
}
vec4 window(vec2 uv) {
    vec4 source=umbriel_sample(uv);
    float t=max(umbriel_time,0.0);
    float roll=t*max(CLOUD_SPEED,0.0);
    vec2 p=uv*umbriel_size/max(CLOUD_SIZE,40.0);
    // Independent moving warp fields fold the cloud banks into one another.
    // There is no displacement of the application's text or image underneath.
    vec2 warp=vec2(cloud_fbm(p*0.65+vec2(roll*0.33,-roll*0.20)),
                   cloud_fbm(p*0.65+vec2(-roll*0.24,roll*0.28)+17.3));
    vec2 folded=p+2.0*(warp-0.5)+vec2(roll*0.12,-roll*0.10);
    float broad=cloud_fbm(folded);
    float curl=cloud_noise(folded*3.1+vec2(roll*0.18,0.0));
    float density=smoothstep(0.23,0.76,broad*0.86+curl*0.14);
    float veil=smoothstep(0.12,0.72,broad);
    vec3 illumination=vec3(0.0);
    float clock=t*max(FLASH_SPEED,0.0)+0.75;
    for(int flash=0;flash<4;++flash) {
        float shifted=clock+float(flash)*2.2;
        float cycle=floor(shifted/8.8);
        float age=mod(shifted,8.8);
        if(age>=2.65) continue;
        float seed=mod(cycle,4096.0)*13.0+float(flash)*47.0;
        vec2 centre=vec2(0.08+0.84*cloud_hash(vec2(seed,1.7)),
                         0.08+0.84*cloud_hash(vec2(seed,8.3)))*umbriel_size;
        float attack=0.16+0.12*cloud_hash(vec2(seed,5.1));
        float pulse=smoothstep(0.0,attack,age)*exp(-age*1.45)
            *(1.0-smoothstep(1.8,2.65,age));
        // A softer secondary bloom suggests another shell behind the same bank.
        float echo=smoothstep(0.50,0.72,age)*exp(-max(age-0.72,0.0)*2.3)
            *(1.0-smoothstep(1.5,2.3,age))*0.28;
        float spread=max(80.0,min(umbriel_size.x,umbriel_size.y)*0.68);
        vec2 delta=(uv*umbriel_size-centre)/spread;
        float scatter=exp(-dot(delta,delta)*1.7);
        illumination+=cloud_flash_colour(seed)*(pulse+echo)*scatter;
    }
    // Thick folds stay shadowed; thinner cloud carries the coloured glow.
    float transmission=exp(-density*2.0);
    vec3 ambient=mix(vec3(0.055,0.065,0.10),vec3(0.32,0.34,0.40),density);
    vec3 backlight=illumination*clamp(FLASH_STRENGTH,0.0,2.0);
    vec3 cloud=ambient+backlight*(0.40+1.7*transmission)*veil;
    float light=max(backlight.r,max(backlight.g,backlight.b));
    float alpha=clamp(INTENSITY,0.0,0.8)*(0.22+0.78*density+light*0.22);
    alpha=min(alpha,0.65);
    return vec4(mix(source.rgb,min(cloud,vec3(1.0))*source.a,alpha),source.a);
}
