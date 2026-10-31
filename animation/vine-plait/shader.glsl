// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
float garden_hash(float n) { return fract(sin(n * 127.1 + 311.7) * 43758.5453); }
vec3 garden_colour(float seed) {
    vec3 pink = vec3(0.96, 0.47, 0.64);
    vec3 lilac = vec3(0.77, 0.60, 0.95);
    vec3 cream = vec3(1.0, 0.91, 0.70);
    vec3 colour = seed < 0.34 ? cream : (seed < 0.67 ? pink : lilac);
    if (umbriel_palette_count > 0)
        colour = mix(colour, umbriel_palette_at(seed).rgb, 0.28);
    return colour;
}
vec4 garden_over(vec4 under, vec3 colour, float alpha) {
    alpha = clamp(alpha, 0.0, 1.0);
    return vec4(colour * alpha + under.rgb * (1.0 - alpha),
                alpha + under.a * (1.0 - alpha));
}
vec2 garden_rotate(vec2 q, float angle) {
    float c = cos(angle), s = sin(angle);
    return vec2(c * q.x + s * q.y, -s * q.x + c * q.y);
}
float garden_petal(vec2 q, float size, float angle, float aa) {
    q = garden_rotate(q, angle);
    // A tapered, gently notched petal rather than a circular particle.
    vec2 radii = vec2(size, size * 0.52);
    float d = (length(q / radii) - 1.0) * size * 0.52;
    float notch = 0.12 * size * exp(-abs(q.y) / max(size * 0.15, 0.01))
                * smoothstep(size * 0.55, size, q.x);
    return 1.0 - smoothstep(-aa, aa, d + notch);
}
vec4 garden_flower(vec2 q, float size, float angle, float seed, float aa) {
    float theta = atan(q.y, q.x + 0.00001) + angle;
    float radius = size * (0.68 + 0.32 * cos(5.0 * theta));
    float distance = length(q);
    float alpha = 1.0 - smoothstep(radius - aa, radius + aa, distance);
    vec3 colour = garden_colour(seed) * (0.78 + 0.22 * smoothstep(0.0, size, distance));
    float centre = 1.0 - smoothstep(size * 0.19, size * 0.19 + aa, distance);
    colour = mix(colour, vec3(1.0, 0.75, 0.22), centre);
    return vec4(colour, alpha);
}
float garden_leaf(vec2 q, float size, float angle, float aa) {
    q = garden_rotate(q, angle);
    float x = q.x / size;
    float width = size * 0.36 * max(1.0 - x*x, 0.0);
    return (1.0 - smoothstep(width - aa, width + aa, abs(q.y)))
         * (1.0 - smoothstep(size - aa, size + aa, abs(q.x)));
}

uniform vec2 umbriel_workspace_axis;
const float BRAID_HEIGHT = 0.27; // Nominal braid height before the uneven drape.
const float STRAND_WIDTH = 28.0; // Minimum half-width in logical pixels.
const float STRAND_FILL = 0.46; // Half-width relative to the braid half-height.
const float WEAVE_SPACING = 260.0; // Broad, irregular twists rather than tight coils.
const float ROLL_TURNS = 0.32; // Partial turn over the whole transition.

float vine_wave(float x) {
    return x/max(WEAVE_SPACING,100.0)*6.28318531;
}
float vine_drape(float x) {
    float w=vine_wave(x), seed=umbriel_random_seed.x*6.28318531;
    return 0.48*sin(w*0.37+seed)+0.18*sin(w*0.91+seed*0.7+1.4);
}
float vine_phase(float x, float strand, float roll) {
    float w=vine_wave(x), seed=umbriel_random_seed.x*6.28318531;
    return w+0.36*sin(w*0.53+seed)+strand*2.09439510
          +0.18*sin(w*0.81+strand*1.7+seed)+roll;
}
float vine_height(float x, float strand, float roll) {
    float w=vine_wave(x), seed=umbriel_random_seed.x*6.28318531;
    float spread=0.64+0.12*sin(w*0.43+strand*1.9+seed);
    return vine_drape(x)+spread*sin(vine_phase(x,strand,roll))
          +0.12*sin(w*1.37+strand*2.3+seed);
}

// Distance to the actual thick strand, rather than a vertical-distance/slope
// estimate that balloons at steep bends. Sample a bounded local curve strip;
// any strand within widthBase of this pixel must lie in this x interval.
vec3 vine_surface(vec2 point, float front, float halfHeight, float lane,
                  float roll, float widthBase) {
    float reach=widthBase+2.0;
    float x=point.x-reach;
    vec2 previous=vec2(x,front+halfHeight*vine_height(x,lane,roll));
    float nearest=1.0e6, nearestX=point.x;
    for (int segment=1;segment<=12;++segment) {
        x=point.x-reach+2.0*reach*float(segment)/12.0;
        vec2 next=vec2(x,front+halfHeight*vine_height(x,lane,roll));
        vec2 edge=next-previous;
        float t=clamp(dot(point-previous,edge)/max(dot(edge,edge),0.001),0.0,1.0);
        vec2 candidate=mix(previous,next,t);
        float distance=length(point-candidate);
        if (distance<nearest) { nearest=distance; nearestX=candidate.x; }
        previous=next;
    }
    return vec3(nearest,nearestX,cos(vine_phase(nearestX,lane,roll)));
}

vec4 animation(vec2 uv) {
    float p=umbriel_clamped_progress;
    if (p<=0.0) return umbriel_sample(uv);
    if (p>=1.0) return umbriel_sample_incoming(uv);
    vec2 size=max(umbriel_size,vec2(1.0));
    bool upwards=umbriel_workspace_axis.x+umbriel_workspace_axis.y<0.0;
    vec2 point=vec2(uv.x,upwards?1.0-uv.y:uv.y)*size;
    float halfHeight=size.y*clamp(BRAID_HEIGHT,0.12,0.45)*0.5;
    // Keep the braid densely filled on large outputs as well as previews.
    float widthBase=max(clamp(STRAND_WIDTH,2.0,64.0),
                        halfHeight*clamp(STRAND_FILL,0.0,0.65));
    float margin=1.55*halfHeight+widthBase+32.0;
    float front=mix(-margin,size.y+margin,p);
    float wave=vine_wave(point.x);
    float aa=0.9/max(umbriel_scale,0.01);
    // Fixed irregular arrival field: the old/new gaps never shimmer backwards.
    float arrival=point.y-halfHeight*(vine_drape(point.x)
                   +0.42*sin(wave*0.91+umbriel_random_seed.x*4.0));
    float reveal=1.0-smoothstep(front-aa,front+aa,arrival);
    vec4 scene=mix(umbriel_sample(uv),umbriel_sample_incoming(uv),reveal);
    if (abs(point.y-front)>margin) return scene;
    vec4 paint=vec4(0.0);
    float roll=p*6.28318531*clamp(ROLL_TURNS,0.0,0.5);
    vec3 strand0=vine_surface(point,front,halfHeight,0.0,roll,widthBase);
    vec3 strand1=vine_surface(point,front,halfHeight,1.0,roll,widthBase);
    vec3 strand2=vine_surface(point,front,halfHeight,2.0,roll,widthBase);
    for (int pass=0;pass<2;++pass) {
        for (int strand=0;strand<3;++strand) {
            float lane=float(strand);
            vec3 surface=strand==0?strand0:(strand==1?strand1:strand2);
            float depth=surface.z;
            float d=surface.x;
            float localWave=vine_wave(surface.y);
            // Slow, unequal bulges squeeze the openings into irregular pockets.
            float width=widthBase*(0.84+0.12*sin(localWave*0.67+lane*2.1)
                                      +0.04*sin(localWave*1.43+lane*4.2));
            float stem=1.0-smoothstep(width-aa,width+aa,d);
            vec3 green=mix(vec3(0.07,0.22,0.065),vec3(0.31,0.55,0.14),0.5+0.5*depth);
            green+=vec3(0.08,0.10,0.025)*exp(-d*d/max(width*width*0.16,1.0));
            if ((pass==0 && depth<0.0)||(pass==1 && depth>=0.0))
                paint=garden_over(paint,green,stem);
            // Uneven spacing, orientation and size break the repeated motif.
            float spacing=max(WEAVE_SPACING,100.0)*0.5;
            float cell=floor(point.x/spacing);
            for (int n=-1;n<=1;++n) {
                float id=cell+float(n);
                float seed=garden_hash(id+lane*37.0);
                float x=(id+0.26+0.48*seed)*spacing;
                float angle=vine_phase(x,lane,roll);
                float nodeDepth=cos(angle);
                if ((pass==0 && nodeDepth>=0.0)||(pass==1 && nodeDepth<0.0)) continue;
                vec2 node=vec2(x,front+halfHeight*vine_height(x,lane,roll));
                vec2 delta=point-node;
                if (length(delta)>31.0) continue;
                float leafAngle=0.25+0.8*seed+0.10*sin(angle);
                vec2 leafOrigin=vec2(10.0+3.0*seed,8.0);
                float leaf=garden_leaf(delta-leafOrigin,11.0+4.0*seed,leafAngle,aa);
                paint=garden_over(paint,vec3(0.32,0.54,0.15)*(0.8+0.2*nodeDepth),leaf);
                float vein=exp(-abs(garden_rotate(delta-leafOrigin,leafAngle).y)*1.8);
                paint=garden_over(paint,vec3(0.55,0.68,0.28),leaf*vein*0.35);
                vec4 flower=garden_flower(delta+vec2(3.0,2.0),8.0+4.0*seed,angle*0.25,seed,aa);
                paint=garden_over(paint,flower.rgb,flower.a);
            }
        }
    }
    return vec4(scene.rgb*(1.0-paint.a)+paint.rgb*scene.a,scene.a);
}
