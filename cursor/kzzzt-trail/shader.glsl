// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
// Time-weighted curve interpolation and bounded path traversal adapted from
// Train Tracks / Comet and the Noctalia trail shader.
const float TRAIL_LIFE = 0.45;
const float MAX_TRAIL_LENGTH = 150.0;
const float TRAIL_WIDTH = 19.0;

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
const float TRACE_WIDTH = 1.2; // Logical-pixel half-width.
const float NODE_INTERVAL = 0.06; // Seconds; divides the 60-second birth wrap.
vec3 circuit_colour() {
    return umbriel_palette_count>0?umbriel_palette_at(0.0).rgb:vec3(0.22,1.0,0.45);
}

// nearest: geometric distance, signed cross-track distance, sample age, birth.
void trail_segment(vec2 pixel,vec4 p0,vec4 p1,vec4 p2,vec4 p3,
                   inout float distanceBehind,inout vec4 nearest,
                   inout float nearestBehind ,inout vec4 decoration) {
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
    // Stable emission times keep pads and sparks attached to their path.
    float birth=(floor(p1.w/NODE_INTERVAL)+1.0)*NODE_INTERVAL;
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
    float fade=trail_fade(age,segmentStart+arcLength-along);
    if (fade<=0.0) return;
    vec2 centre=trail_point(a,b,m0,m1,t);
    vec2 tangent=(6.0*t*t-6.0*t)*a+(3.0*t*t-4.0*t+1.0)*m0
                +(-6.0*t*t+6.0*t)*b+(3.0*t*t-2.0*t)*m1;
    if (length(tangent)<0.001) tangent=chord;
    tangent/=max(length(tangent),0.001);
    vec2 normal=vec2(-tangent.y,tangent.x);
    vec2 q=vec2(dot(pixel-centre,tangent),dot(pixel-centre,normal));
    float seed=trail_hash(mod(floor(birth/NODE_INTERVAL+0.5),1000.0));
    float side=seed<0.5?-1.0:1.0;
    float reach=TRAIL_WIDTH*(0.62+0.28*seed);
    float run=4.0+8.0*trail_hash(seed*91.0);
    vec2 n0=vec2(0.0),n1=vec2(0.0,side*6.0);
    vec2 n2=vec2(run,side*6.0),n3=vec2(run,side*reach);
    float d=min(trail_distance(q,n0,n1),min(trail_distance(q,n1,n2),trail_distance(q,n2,n3)));
    float pad=abs(length(q-n3)-2.4);
    d=min(d,pad);
    float aa=0.65/max(umbriel_scale,0.5);
    // Dark keyline keeps the fine copper tracks visible over pale content.
    decoration=trail_over(decoration,vec3(0.025,0.045,0.035),
                          (1.0-smoothstep(TRACE_WIDTH+0.7,TRACE_WIDTH+1.4+aa,d))*fade*0.85);
    float trace=1.0-smoothstep(TRACE_WIDTH-aa,TRACE_WIDTH+aa,d);
    decoration=trail_over(decoration,circuit_colour(),trace*fade*0.94);
    float charge=smoothstep(0.0,0.025,age)*(1.0-smoothstep(0.065,0.13,age));
    // A brief bent electrical discharge, confined to the circuit's small pad.
    vec2 z0=n3,z1=n3+vec2(3.0,side*5.0);
    vec2 z2=n3+vec2(-2.0,side*8.0),z3=n3+vec2(4.0,side*13.0);
    float zap=min(trail_distance(q,z0,z1),min(trail_distance(q,z1,z2),trail_distance(q,z2,z3)));
    float spark=1.0-smoothstep(0.6,0.6+aa,zap);
    float split=1.0-smoothstep(0.45,0.45+aa,trail_distance(q,z2,z2+vec2(-5.0,side*3.0)));
    decoration=trail_over(decoration,vec3(0.78,0.97,1.0),max(spark,split)*charge*fade);

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
                trail_segment(uv*umbriel_size,p0,p1,p2,p3,distanceBehind,nearest,nearestBehind ,decoration);
        }
    }
    if (umbriel_pointer_count>=2 && distanceBehind<MAX_TRAIL_LENGTH)
        trail_segment(uv*umbriel_size,p0,p0,p1,p2,distanceBehind,nearest,nearestBehind ,decoration);
    float tip=smoothstep(3.0,10.0,length((uv-umbriel_pointer)*umbriel_size));
    float fade=trail_fade(nearest.z,nearestBehind)*tip;
    float aa=0.65/max(umbriel_scale,0.5);
    vec4 paint=vec4(0.0);
    float d=nearest.x;
    float outline=1.0-smoothstep(TRACE_WIDTH+0.8,TRACE_WIDTH+1.5+aa,d);
    paint=trail_over(paint,vec3(0.025,0.045,0.035),outline*fade*0.85);
    float core=1.0-smoothstep(TRACE_WIDTH-aa,TRACE_WIDTH+aa,d);
    paint=trail_over(paint,circuit_colour(),core*fade*0.95);
    // Separate compositing lets branches survive at crossings of the short path.
    decoration*=tip;
    paint=vec4(decoration.rgb+paint.rgb*(1.0-decoration.a),
               decoration.a+paint.a*(1.0-decoration.a));
    return vec4(source.rgb*(1.0-paint.a)+paint.rgb*source.a,source.a);

}
