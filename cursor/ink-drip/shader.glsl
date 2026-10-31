// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
// Time-weighted curve interpolation and bounded path traversal adapted from
// Train Tracks / Comet and the Noctalia trail shader.
const float TRAIL_LIFE = 0.45;
const float MAX_TRAIL_LENGTH = 150.0;
const float TRAIL_WIDTH = 28.0; // Artwork reach used by pixel rejection.

float trail_hash(float n) { return fract(sin(n*127.1+311.7)*43758.5453); }
float trail_distance(vec2 p, vec2 a, vec2 b) {
    vec2 v=b-a;
    return length(p-a-v*clamp(dot(p-a,v)/max(dot(v,v),0.001),0.0,1.0));
}
vec4 trail_over(vec4 under, vec3 colour, float alpha) {
    alpha=clamp(alpha,0.0,1.0);
    return vec4(colour*alpha+under.rgb*(1.0-alpha),alpha+under.a*(1.0-alpha));
}
vec2 trail_point(vec2 a, vec2 b, vec2 m0, vec2 m1, float t) {
    float t2=t*t,t3=t2*t;
    return (2.0*t3-3.0*t2+1.0)*a+(t3-2.0*t2+t)*m0
         +(-2.0*t3+3.0*t2)*b+(t3-t2)*m1;
}
float trail_fade(float age, float behind) {
    return (1.0-smoothstep(TRAIL_LIFE*0.25,TRAIL_LIFE,age))
          *(1.0-smoothstep(MAX_TRAIL_LENGTH*0.6,MAX_TRAIL_LENGTH,behind));
}
const float STROKE_WIDTH = 1.8; // Logical-pixel half-width.
const float DROP_INTERVAL = 0.075; // Seconds; divides the 60-second birth wrap.
const float DROP_DISTANCE = 20.0; // Logical pixels fallen before the splotch.
const float BLOT_SIZE = 9.0; // Maximum main-splotch radius in logical pixels.
vec3 ink_colour() {
    vec3 ink=vec3(0.025,0.032,0.05);
    if (umbriel_palette_count>0) ink=umbriel_palette_at(0.0).rgb;
    return ink;
}
vec3 ink_highlight() {
    if (umbriel_palette_count>0) return mix(ink_colour(),vec3(1.0),0.65);
    return vec3(0.42,0.47,0.54);
}
// Ragged lobes and a small wet sheen distinguish pooled ink from round dots.
// Returns straight colour plus coverage for trail_over.
vec4 ink_mark(vec2 q,float radius,float seed,float wet,float aa) {
    float angle=atan(q.y,q.x+0.00001);
    float edge=radius*(0.82+0.10*sin(angle*5.0+seed*17.0)
                          +0.065*sin(angle*9.0-seed*11.0)
                          +0.035*sin(angle*13.0+seed*7.0));
    float distance=length(q),d=distance-edge;
    float alpha=1.0-smoothstep(-aa,aa,d);
    vec2 normal=q/max(distance,0.001);
    float rim=exp(-abs(d+0.65)*1.8)*max(dot(normal,vec2(-0.6,-0.8)),0.0);
    vec2 reflection=(q+radius*vec2(0.28,0.32))/max(radius*0.20,0.5);
    float glint=exp(-dot(reflection,reflection));
    vec3 colour=mix(ink_colour(),ink_highlight(),
                    clamp(wet*(0.48*rim+0.60*glint),0.0,0.75));
    return vec4(colour,alpha);
}

// nearest: geometric distance, signed cross-track distance, sample age, birth.
void trail_segment(vec2 pixel,vec4 p0,vec4 p1,vec4 p2,vec4 p3,
                   inout float distanceBehind,inout vec4 nearest,
                   inout float nearestBehind,inout vec4 decoration) {
    vec2 a=p1.xy*umbriel_size,b=p2.xy*umbriel_size,chord=b-a;
    float len=length(chord);
    if (len>800.0 || p2.z>=TRAIL_LIFE) { distanceBehind=MAX_TRAIL_LENGTH;return; }
    if (len<0.25) return;
    if (length((p0.xy-p1.xy)*umbriel_size)>800.0) p0=p1;
    if (length((p3.xy-p2.xy)*umbriel_size)>800.0) p3=p2;
    float dt=max(p1.z-p2.z,0.001);
    vec2 m0=(b-p0.xy*umbriel_size)*dt/max(p0.z-p2.z,0.001);
    vec2 m1=(p3.xy*umbriel_size-a)*dt/max(p1.z-p3.z,0.001);
    m0*=min(1.0,1.5*len/max(length(m0),0.001));
    m1*=min(1.0,1.5*len/max(length(m1),0.001));
    float arcLength=0.0;
    vec2 previous=a;
    for (int j=1;j<=6;++j) {
        vec2 next=trail_point(a,b,m0,m1,float(j)/6.0);
        arcLength+=length(next-previous);previous=next;
    }
    float segmentStart=distanceBehind;
    distanceBehind+=arcLength;
    // Advance the shared budget before pixel rejection, so all fragments
    // agree on where the short trail ends.
    float bulge=(4.0/27.0)*(length(m0-chord)+length(m1-chord));
    if (trail_distance(pixel,a,b)>bulge+TRAIL_WIDTH+22.0) return;
    float birthSpan=mod(p2.w-p1.w+60.0,60.0);
    float travelled=0.0;
    previous=a;
    for (int j=1;j<=6;++j) {
        vec2 next=trail_point(a,b,m0,m1,float(j)/6.0);
        vec2 piece=next-previous;
        float edgeLength=length(piece);
        float f=clamp(dot(pixel-previous,piece)/max(dot(piece,piece),0.001),0.0,1.0);
        vec2 delta=pixel-mix(previous,next,f);
        float d=length(delta);
        float t=(float(j)-1.0+f)/6.0;
        float behind=segmentStart+arcLength-travelled-f*edgeLength;
        float age=mix(p1.z,p2.z,t);
        if (d<nearest.x && behind<MAX_TRAIL_LENGTH && age<TRAIL_LIFE) {
            vec2 normal=vec2(-piece.y,piece.x)/max(edgeLength,0.001);
            nearest=vec4(d,dot(delta,normal),age,mod(p1.w+birthSpan*t,60.0));
            nearestBehind=behind;
        }
        travelled+=edgeLength;previous=next;
    }
    // Emit ink at stable birth times, independent of retained sample indices.
    float birth=(floor(p1.w/DROP_INTERVAL)+1.0)*DROP_INTERVAL;
    if (birthSpan<0.0001 || birth>p1.w+birthSpan) return;
    float t=clamp((birth-p1.w)/birthSpan,0.0,1.0);
    float along=0.0;
    previous=a;
    for (int j=1;j<=6;++j) {
        vec2 next=trail_point(a,b,m0,m1,float(j)/6.0);
        along+=length(next-previous)*clamp(t*6.0-float(j-1),0.0,1.0);
        previous=next;
    }
    float age=mix(p1.z,p2.z,t);
    float fade=(1.0-smoothstep(TRAIL_LIFE*0.70,TRAIL_LIFE,age))
              *(1.0-smoothstep(MAX_TRAIL_LENGTH*0.6,MAX_TRAIL_LENGTH,segmentStart+arcLength-along));
    if (fade<=0.0) return;
    vec2 centre=trail_point(a,b,m0,m1,t);
    float seed=trail_hash(mod(floor(birth/DROP_INTERVAL+0.5),800.0));
    float life=age/TRAIL_LIFE;
    float fall=clamp((life-0.12)/0.45,0.0,1.0);
    float drop=2.7+1.5*seed;
    vec2 landing=centre+vec2((seed-0.5)*10.0,DROP_DISTANCE);
    vec2 position=mix(centre,landing,fall*fall);
    float aa=0.65/max(umbriel_scale,0.5);
    vec2 q=pixel-position;
    // The bead elongates while falling, then flattens into an uneven stain.
    q.y/=1.0+0.75*sin(fall*3.14159265);
    float taper=0.72+0.28*smoothstep(-drop,drop,q.y);
    float bead=1.0-smoothstep(drop*taper-aa,drop*taper+aa,length(q));
    vec2 shine=(q+vec2(drop*0.23,drop*0.32))/max(drop*0.25,0.5);
    vec3 colour=mix(ink_colour(),ink_highlight(),exp(-dot(shine,shine))*0.75);
    float falling=smoothstep(0.0,0.08,life)*(1.0-smoothstep(0.85,1.0,fall));
    decoration=trail_over(decoration,colour,bead*falling*fade);
    float impact=smoothstep(0.44,0.62,life);
    float spread=smoothstep(0.46,0.80,life);
    vec2 stain=pixel-landing;
    float radius=BLOT_SIZE*(0.65+0.35*seed)*(0.40+0.60*spread);
    float wet=1.0-smoothstep(0.65,1.0,life);
    vec4 blot=ink_mark(stain,radius,seed,wet,aa);
    decoration=trail_over(decoration,blot.rgb,blot.a*impact*fade);
    // A few unequal satellite spots spread outward at impact, then dry away.
    for (int speck=0;speck<4;++speck) {
        float r=trail_hash(seed*71.0+float(speck)*19.0);
        float angle=r*6.28318531+float(speck)*1.7;
        vec2 offset=vec2(cos(angle),sin(angle))*(radius+3.0+7.0*r)*spread;
        float size=0.9+1.6*trail_hash(seed*37.0+float(speck)*13.0);
        vec4 spot=ink_mark(stain-offset,size,r,wet,aa);
        decoration=trail_over(decoration,spot.rgb,spot.a*impact*fade*0.90);
    }

}
vec4 cursor(vec2 uv) {
    vec4 source=umbriel_sample(uv);
    if (umbriel_pointer_count<2) return source;
    vec4 nearest=vec4(TRAIL_WIDTH+22.0,0.0,TRAIL_LIFE,0.0);
    float nearestBehind=MAX_TRAIL_LENGTH,distanceBehind=0.0;
    vec4 decoration=vec4(0.0);
    vec4 p0=vec4(0.0),p1=p0,p2=p0,p3=p0;
    for (int k=63;k>=0;--k) {
        if (distanceBehind>=MAX_TRAIL_LENGTH) break;
        if (k<umbriel_pointer_count) {
            vec4 next=umbriel_pointer_path[k];
            if (k==umbriel_pointer_count-1) { p0=next;p1=next;p2=next; }
            p3=p2;p2=p1;p1=p0;p0=next;
            if (k<umbriel_pointer_count-2)
                trail_segment(uv*umbriel_size,p0,p1,p2,p3,distanceBehind,nearest,nearestBehind,decoration);
        }
    }
    if (umbriel_pointer_count>=2 && distanceBehind<MAX_TRAIL_LENGTH)
        trail_segment(uv*umbriel_size,p0,p0,p1,p2,distanceBehind,nearest,nearestBehind,decoration);
    float tip=smoothstep(3.0,10.0,length((uv-umbriel_pointer)*umbriel_size));
    float fade=trail_fade(nearest.z,nearestBehind)*tip;
    float aa=0.65/max(umbriel_scale,0.5);
    vec4 paint=vec4(0.0);
    // Slightly uneven ink thickness follows the deposited path, not a clock.
    float width=STROKE_WIDTH*(0.80+0.20*sin(nearest.w*37.69911184));
    float core=1.0-smoothstep(width-aa,width+aa,nearest.x);
    float gloss=exp(-abs(nearest.y+width*0.45)*3.0);
    vec3 colour=mix(ink_colour(),ink_highlight(),gloss*0.32);
    paint=trail_over(paint,colour,core*fade*0.95);
    decoration*=tip;
    paint=vec4(decoration.rgb+paint.rgb*(1.0-decoration.a),
               decoration.a+paint.a*(1.0-decoration.a));
    return vec4(source.rgb*(1.0-paint.a)+paint.rgb*source.a,source.a);
}
