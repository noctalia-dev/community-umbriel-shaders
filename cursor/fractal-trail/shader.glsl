// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
// Time-weighted curve interpolation and bounded path traversal adapted from
// Train Tracks / Comet and the Noctalia trail shader.
const float TRAIL_LIFE = 0.30;
const float MAX_TRAIL_LENGTH = 120.0;
const float TRAIL_WIDTH = 16.0;

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
const float INTENSITY = 1.0;
// Adapted from the Psychedelic family's inversion/fold field.
// Four levels keep nested contours distinct at this compact cursor size.
// Separate narrow and wide orbit traps give crisp colour with a dark keyline.
vec3 trace_fractal(vec2 p,float phase,float pixel) {
    float c=cos(phase),s=sin(phase);
    mat2 turn=mat2(c,-s,s,c);
    vec2 z=p;
    float trap=1.0,field=0.0,weight=0.5;
    for (int i=0;i<4;++i) {
        z=turn*abs(z);
        z=z/clamp(dot(z,z),0.24,2.4)-vec2(0.92,0.64);
        float orbit=abs(length(z)-0.72);
        trap=min(trap,orbit);field+=weight*exp(-3.0*orbit);weight*=0.5;
    }
    float line=1.0-smoothstep(0.018,0.055+min(pixel,0.025),trap);
    float edge=1.0-smoothstep(0.075,0.12+min(pixel,0.025),trap);
    return vec3(line,edge,clamp(field,0.0,1.0));
}
vec3 trace_colour(float t) {
    vec3 rainbow=0.52+0.48*cos(6.28318531*(t+vec3(0.0,0.33,0.67)));
    if (umbriel_palette_count>0) return mix(rainbow,umbriel_palette_at(t).rgb,0.28);
    return rainbow;
}

// nearest: geometric distance, signed cross-track distance, sample age, birth.
void trail_segment(vec2 pixel,vec4 p0,vec4 p1,vec4 p2,vec4 p3,
                   inout float distanceBehind,inout vec4 nearest,
                   inout float nearestBehind ) {
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

}
vec4 cursor(vec2 uv) {
    vec4 source=umbriel_sample(uv);
    if (umbriel_pointer_count<2) return source;
    vec4 nearest=vec4(TRAIL_WIDTH+22.0,0.0,TRAIL_LIFE,0.0);
    float nearestBehind=MAX_TRAIL_LENGTH,distanceBehind=0.0;

    vec4 p0=vec4(0.0),p1=p0,p2=p0,p3=p0;
    for (int k=63;k>=0;--k) {
        if (distanceBehind>=MAX_TRAIL_LENGTH) break;
        if (k<umbriel_pointer_count) {
            vec4 next=umbriel_pointer_path[k];
            if (k==umbriel_pointer_count-1) { p0=next;p1=next;p2=next; }
            p3=p2;p2=p1;p1=p0;p0=next;
            if (k<umbriel_pointer_count-2)
                trail_segment(uv*umbriel_size,p0,p1,p2,p3,distanceBehind,nearest,nearestBehind );
        }
    }
    if (umbriel_pointer_count>=2 && distanceBehind<MAX_TRAIL_LENGTH)
        trail_segment(uv*umbriel_size,p0,p0,p1,p2,distanceBehind,nearest,nearestBehind );
    float tip=smoothstep(3.0,10.0,length((uv-umbriel_pointer)*umbriel_size));
    float fade=trail_fade(nearest.z,nearestBehind)*tip;
    float aa=0.65/max(umbriel_scale,0.5);
    if (fade<=0.0 || nearest.x>=TRAIL_WIDTH) return source;
    // Birth phase wraps seamlessly every 60 s. The pattern stays attached to
    // the deposited trail instead of being driven by a continuously moving clock.
    float phase=nearest.w*18.84955592;
    vec2 q=vec2(1.4*sin(phase),nearest.y/TRAIL_WIDTH*1.25+0.55*cos(phase));
    vec3 mainField=trace_fractal(q,0.52,0.65/TRAIL_WIDTH);
    vec3 fineField=trace_fractal(q*1.4+vec2(0.31,0.57),0.71,0.65/TRAIL_WIDTH);
    float line=max(mainField.x,fineField.x*0.72);
    float edge=max(mainField.y,fineField.y);
    float band=1.0-smoothstep(TRAIL_WIDTH*0.78,TRAIL_WIDTH,nearest.x);
    float strength=clamp(INTENSITY,0.0,1.0)*fade*band;
    vec3 colour=trace_colour(mainField.z*1.7+fineField.z*0.3+nearest.w*0.1);
    colour=mix(colour,vec3(1.0),0.20*line);
    vec3 rgb=mix(source.rgb,vec3(0.045,0.02,0.065)*source.a,edge*strength*0.75);
    rgb=mix(rgb,colour*source.a,line*strength);
    return vec4(rgb,source.a);

}
