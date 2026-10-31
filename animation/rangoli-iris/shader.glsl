// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus. Procedural artwork.
// Inspired by the user's circular floral reference: white linework over
// vermilion, green, orange and blue rings. No image texture is embedded.
const float INTENSITY = 0.98; // 0..1; ornament opacity, independent of the iris.
const float BAND_WIDTH = 0.22; // Fraction of the shorter output dimension.
const float LINE_WIDTH = 1.4; // Logical pixels for the white chalk linework.
const float TAU = 6.28318530718;
const vec3 WHITE = vec3(1.0,0.97,0.86);

float rangoli_cell(float angle,float count) {
    return mod(angle+TAU/(2.0*count),TAU/count)-TAU/(2.0*count);
}
float rangoli_line(float distance,float width,float aa) {
    return 1.0-smoothstep(width,width+aa,abs(distance));
}
// White outlined pointed petals between the two radii.
float rangoli_petals(float r,float angle,float start,float end,float count,float width,float aa) {
    float h=clamp((r-start)/max(end-start,0.001),0.0,1.0);
    float local=rangoli_cell(angle,count);
    float tangent=r*sin(local);
    float halfWidth=(start+end)*0.5*TAU/count*0.42;
    float shape=halfWidth*pow(max(sin(3.14159265359*h),0.0),0.85);
    float stroke=rangoli_line(abs(tangent)-shape,width,aa);
    return stroke*smoothstep(start-aa,start+aa,r)*(1.0-smoothstep(end-aa,end+aa,r));
}
vec4 animation(vec2 uv) {
    float p=umbriel_clamped_progress;
    if(p<=0.0) return umbriel_sample(uv);
    if(p>=1.0) return umbriel_sample_incoming(uv);
    vec2 size=max(umbriel_size,vec2(1.0));
    float unit=min(size.x,size.y);
    vec2 point=(uv-0.5)*size;
    float r=length(point);
    float angle=atan(point.y,point.x);
    float aa=0.8/max(umbriel_scale,0.01);
    float line=max(LINE_WIDTH,0.25)*0.5;
    float corner=length(size*0.5);
    // The small complete medallion blooms first, then its centre opens.
    // Radius is monotonic and depends only on held progress, so swipes retrace.
    float radius=(corner+3.0*aa)*smoothstep(0.12,1.0,p);
    float band=max(unit*clamp(BAND_WIDTH,0.08,0.4)*smoothstep(0.0,0.18,p),aa);
    float revealed=1.0-smoothstep(radius-aa,radius+aa,r);
    vec4 source=mix(umbriel_sample(uv),umbriel_sample_incoming(uv),revealed);
    float f=(r-radius)/band;
    if(f<-3.0*aa/band || f>1.0+aa/band) return source;
    float envelope=smoothstep(0.0,0.06,p);
    // Fade the inner ornament only over pixels already fully revealed. This
    // prevents a sliver of the outgoing scene returning at the aperture edge.
    float mask=smoothstep(-3.0*aa,-aa,r-radius)*(1.0-smoothstep(band-aa,band+aa,r-radius));
    vec3 colour=vec3(0.90,0.19,0.16);
    colour=mix(colour,vec3(0.20,0.64,0.24),smoothstep(0.33-aa/band,0.33+aa/band,f));
    colour=mix(colour,vec3(1.0,0.35,0.12),smoothstep(0.60-aa/band,0.60+aa/band,f));
    colour=mix(colour,vec3(0.26,0.43,0.74),smoothstep(0.81-aa/band,0.81+aa/band,f));
    float ink=0.0;
    // Inner flower: long red petals forming the aperture's scalloped collar.
    ink=max(ink,rangoli_petals(r,angle,radius+band*0.015,radius+band*0.325,16.0,line,aa));
    // Green leaf loops and orange lotus petals, offset from the inner flower.
    ink=max(ink,rangoli_petals(r,angle+TAU/40.0,radius+band*0.345,radius+band*0.585,20.0,line,aa));
    ink=max(ink,rangoli_petals(r,angle,radius+band*0.615,radius+band*0.80,24.0,line,aa));
    // Blue scrollwork: one outlined bead with an inward-coiling white spiral.
    if(f>0.805) {
        float count=32.0;
        float local=rangoli_cell(angle+TAU/64.0,count);
        float beadRadius=radius+band*0.90;
        float tangentRadius=max(beadRadius*TAU/count*0.43,aa);
        float radialRadius=max(band*0.074,aa);
        vec2 q=vec2(r*sin(local)/tangentRadius,(r*cos(local)-beadRadius)/radialRadius);
        float qr=length(q);
        float bead=(qr-1.0)*min(tangentRadius,radialRadius);
        ink=max(ink,rangoli_line(bead,line,aa));
        float a=atan(q.y,q.x)+3.14159265359;
        float spiral=100.0;
        for(int turn=0;turn<2;++turn) {
            float target=0.07+0.096*(a+float(turn)*TAU);
            spiral=min(spiral,abs(qr-target));
        }
        float coil=rangoli_line(spiral*min(tangentRadius,radialRadius),line*0.85,aa*0.7);
        ink=max(ink,coil*(1.0-smoothstep(0.88,0.96,qr)));
    }
    // Thin white dividers join the motifs into continuous concentric rings.
    ink=max(ink,rangoli_line((f-0.005)*band,line,aa));
    ink=max(ink,rangoli_line((f-0.33)*band,line,aa));
    ink=max(ink,rangoli_line((f-0.60)*band,line,aa));
    ink=max(ink,rangoli_line((f-0.81)*band,line,aa));
    ink=max(ink,rangoli_line((f-0.995)*band,line,aa));
    colour=mix(colour,WHITE,ink);
    float opacity=mask*envelope*clamp(INTENSITY,0.0,1.0);
    return vec4(mix(source.rgb,colour*source.a,opacity),source.a);
}
