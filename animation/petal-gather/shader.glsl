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

const bool GATHER = true;
const float PETAL_SIZE = 8.0; // Logical pixels.
const float WIND_CURL = 0.11; // Fraction of the shorter window dimension.
const float PETAL_OPACITY = 0.94;

vec4 animation(vec2 uv) {
    float p=umbriel_clamped_progress;
    vec4 source=umbriel_sample(uv);
    if (p<=0.0) return GATHER?vec4(0.0):source;
    if (p>=1.0) return GATHER?source:vec4(0.0);
    vec2 size=max(umbriel_size,vec2(1.0));
    float unit=min(size.x,size.y);
    vec2 pixel=uv*size;
    float aa=0.8/max(umbriel_scale,0.01);
    float travel=GATHER?p:1.0-p;
    float front=mix(-unit*0.30,size.x+unit*0.30,travel);
    float edge=front+unit*0.045*sin(pixel.y/unit*9.0)
                    +unit*0.025*sin(pixel.y/unit*21.0+umbriel_random_seed.x*6.28);
    float coverage=1.0-smoothstep(edge-2.0*aa,edge+2.0*aa,pixel.x);
    vec4 paint=vec4(0.0);
    float envelope=smoothstep(0.0,0.10,p)*(1.0-smoothstep(0.86,1.0,p));
    // Fixed per-transition seeds keep flowers continuous while the gust moves.
    for (int i=0;i<64;++i) {
        float id=float(i)+umbriel_random_seed.y*79.0;
        float a=garden_hash(id+3.0),b=garden_hash(id+19.0),c=garden_hash(id+53.0);
        float flight=fract(p*1.3+a);
        float flutter=sin(flight*3.14159265);
        float lateral=GATHER?(1.0-flight)*unit*0.42:flight*unit*0.62;
        // Gathering spirals toward the reveal edge; scattering peels away
        // from the receding edge and accelerates into the cleared region.
        float x=front+lateral-unit*0.09;
        float y=(b*1.16-0.08)*size.y
               +unit*WIND_CURL*sin(flight*6.28318531+c*6.28)*flutter;
        if (!GATHER) y+=unit*0.16*flight*flight*(c-0.25);
        vec2 q=pixel-vec2(x,y);
        float radius=PETAL_SIZE*(0.65+0.75*c);
        if (abs(q.x)>radius*1.5 || abs(q.y)>radius*1.5) continue;
        float angle=c*6.28+flight*(GATHER?-5.0:8.0);
        // Tilt around the long axis to make the petals flutter in depth.
        q.y/=max(0.28,abs(cos(angle*0.7)));
        float petal=garden_petal(q,radius,angle,aa);
        float fade=smoothstep(0.0,0.12,flight)*(1.0-smoothstep(0.85,1.0,flight));
        vec3 colour=garden_colour(c)*(0.84+0.16*flutter);
        paint=garden_over(paint,colour,petal*fade*envelope*PETAL_OPACITY);
    }
    // Artwork is confined to the captured source silhouette, including alpha.
    float alpha=coverage*(1.0-paint.a)+paint.a;
    return vec4(source.rgb*coverage*(1.0-paint.a)+paint.rgb*source.a,source.a*alpha);
}
