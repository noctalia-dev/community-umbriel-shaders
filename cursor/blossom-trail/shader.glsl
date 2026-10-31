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

// Time-weighted Hermite interpolation adapted from Witchfire / Comet and
// the Noctalia trail shader. Botanical artwork is original.
const float TRAIL_LIFE = 0.45; // Seconds; matches Train Tracks.
const float MAX_TRAIL_LENGTH = 150.0; // Logical pixels along the recent path.
const float VINE_WIDTH = 1.6; // Logical pixels.
const float BLOSSOM_SIZE = 8.0;
const float FLOWER_INTERVAL = 0.08; // Seconds; divides the 60-second birth wrap.

vec2 blossom_curve(vec2 a, vec2 b, vec2 m0, vec2 m1, float t) {
    float t2=t*t, t3=t2*t;
    return (2.0*t3-3.0*t2+1.0)*a + (t3-2.0*t2+t)*m0
         + (-2.0*t3+3.0*t2)*b + (t3-t2)*m1;
}
void blossom_segment(vec2 pixel, vec4 p0, vec4 p1, vec4 p2, vec4 p3,
                     inout float distanceBehind, inout vec4 paint) {
    vec2 a=p1.xy*umbriel_size, b=p2.xy*umbriel_size;
    vec2 chord=b-a;
    float len=length(chord);
    if (len>800.0 || p2.z>=TRAIL_LIFE) {
        distanceBehind=MAX_TRAIL_LENGTH;
        return;
    }
    if (len<0.5) return;
    if (length((p0.xy-p1.xy)*umbriel_size)>800.0) p0=p1;
    if (length((p3.xy-p2.xy)*umbriel_size)>800.0) p3=p2;
    float dt=max(p1.z-p2.z,0.001);
    vec2 m0=(b-p0.xy*umbriel_size)*dt/max(p0.z-p2.z,0.001);
    vec2 m1=(p3.xy*umbriel_size-a)*dt/max(p1.z-p3.z,0.001);
    m0*=min(1.0,1.5*len/max(length(m0),0.001));
    m1*=min(1.0,1.5*len/max(length(m1),0.001));
    // Account for the path before rejecting pixels, as Train Tracks does.
    // Newest-to-oldest traversal makes the length cap independent of speed.
    float arcLength=0.0;
    vec2 arcPrevious=a;
    for (int j=1;j<=6;++j) {
        vec2 next=blossom_curve(a,b,m0,m1,float(j)/6.0);
        arcLength+=length(next-arcPrevious);
        arcPrevious=next;
    }
    float segmentStart=distanceBehind;
    distanceBehind+=arcLength;
    float u=clamp(dot(pixel-a,chord)/(len*len),0.0,1.0);
    float bulge=(4.0/27.0)*(length(m0-chord)+length(m1-chord));
    if (length(pixel-mix(a,b,u))>bulge+55.0) return;
    vec2 normal=vec2(-chord.y,chord.x)/len;
    float birthSpan=mod(p2.w-p1.w+60.0,60.0);
    float aa=0.75/max(umbriel_scale,0.01);
    // Two slender stems twist around the history curve.
    for (int strand=0;strand<2;++strand) {
        float offset=float(strand)*3.14159265;
        vec2 previous=a+normal*5.5*sin(p1.w*12.56637061+offset);
        float travelled=0.0;
        vec2 basePrevious=a;
        for (int j=1;j<=6;++j) {
            float t=float(j)/6.0;
            float birth=p1.w+birthSpan*t;
            vec2 base=blossom_curve(a,b,m0,m1,t);
            float edgeLength=length(base-basePrevious);
            vec2 next=base+normal*5.5*sin(birth*12.56637061+offset);
            vec2 piece=next-previous;
            float f=clamp(dot(pixel-previous,piece)/max(dot(piece,piece),0.001),0.0,1.0);
            float age=mix(p1.z,p2.z,(float(j)-1.0+f)/6.0);
            float behind=segmentStart+arcLength-travelled-f*edgeLength;
            float life=(1.0-smoothstep(TRAIL_LIFE*0.1,TRAIL_LIFE,age))
                      *(1.0-smoothstep(MAX_TRAIL_LENGTH*0.6,MAX_TRAIL_LENGTH,behind));
            float d=length(pixel-mix(previous,next,f));
            float stem=1.0-smoothstep(VINE_WIDTH-aa,VINE_WIDTH+aa,d);
            vec3 green=mix(vec3(0.10,0.31,0.09),vec3(0.34,0.60,0.18),float(strand));
            paint=garden_over(paint,green,stem*life*0.92);
            travelled+=edgeLength;
            basePrevious=base;
            previous=next;
        }
    }
    // Emit at fixed birth-time boundaries, not sample indices. Flowers keep
    // their positions and seeds as the pointer history slides and wraps.
    float birth=(floor(p1.w/FLOWER_INTERVAL)+1.0)*FLOWER_INTERVAL;
    if (birth>p1.w+birthSpan || birthSpan<0.0001) return;
    float t=clamp((birth-p1.w)/birthSpan,0.0,1.0);
    float age=mix(p1.z,p2.z,t);
    float id=mod(floor(birth/FLOWER_INTERVAL+0.5),60.0/FLOWER_INTERVAL);
    float seed=garden_hash(id);
    vec2 origin=blossom_curve(a,b,m0,m1,t)
               +normal*5.5*sin(birth*12.56637061);
    float along=0.0;
    arcPrevious=a;
    for (int j=1;j<=6;++j) {
        vec2 next=blossom_curve(a,b,m0,m1,float(j)/6.0);
        along+=length(next-arcPrevious)*clamp(t*6.0-float(j-1),0.0,1.0);
        arcPrevious=next;
    }
    float behind=segmentStart+arcLength-along;
    float life=(1.0-smoothstep(TRAIL_LIFE*0.55,TRAIL_LIFE,age))
              *(1.0-smoothstep(MAX_TRAIL_LENGTH*0.6,MAX_TRAIL_LENGTH,behind));
    float bloom=smoothstep(0.0,TRAIL_LIFE*0.12,age);
    // Compress the flower's choreography to fit the much shorter trail.
    float detached=max(age/TRAIL_LIFE-0.26,0.0)/0.74;
    vec2 drift=vec2(sin(seed*20.0+detached*3.0)*detached*10.0,
                    detached*8.0+detached*detached*20.0);
    vec2 q=pixel-origin-drift;
    float size=BLOSSOM_SIZE*(0.7+0.5*seed)*bloom;
    if (size>0.1) {
        vec4 flower=garden_flower(q,size,seed*6.28+detached*2.0,seed,aa);
        paint=garden_over(paint,flower.rgb,flower.a*life);
        // One petal peels away from the falling blossom.
        vec2 petal=q-vec2(detached*10.0,detached*detached*8.0);
        float alpha=garden_petal(petal,size*0.48,seed*8.0+age*4.0,aa);
        paint=garden_over(paint,garden_colour(seed),alpha*life*smoothstep(0.05,0.3,detached));
    }
    vec2 leafq=pixel-origin-normal*7.0;
    float leaf=garden_leaf(leafq,6.0,atan(normal.y,normal.x),aa);
    paint=garden_over(paint,vec3(0.29,0.52,0.15),leaf*bloom*life*0.8);
}
vec4 cursor(vec2 uv) {
    vec4 source=umbriel_sample(uv);
    if (umbriel_pointer_count<2) return source;
    vec4 paint=vec4(0.0);
    vec4 p0=vec4(0.0),p1=p0,p2=p0,p3=p0;
    float distanceBehind=0.0;
    for (int k=63;k>=0;--k) {
        if (distanceBehind>=MAX_TRAIL_LENGTH) break;
        if (k<umbriel_pointer_count) {
            vec4 next=umbriel_pointer_path[k];
            if (k==umbriel_pointer_count-1) { p0=next;p1=next;p2=next; }
            p3=p2;p2=p1;p1=p0;p0=next;
            if (k<umbriel_pointer_count-2)
                blossom_segment(uv*umbriel_size,p0,p1,p2,p3,distanceBehind,paint);
        }
    }
    if (umbriel_pointer_count>=2 && distanceBehind<MAX_TRAIL_LENGTH)
        blossom_segment(uv*umbriel_size,p0,p0,p1,p2,distanceBehind,paint);
    float tip=smoothstep(3.0,11.0,length((uv-umbriel_pointer)*umbriel_size));
    paint*=tip;
    return vec4(source.rgb*(1.0-paint.a)+paint.rgb*source.a,source.a);
}
