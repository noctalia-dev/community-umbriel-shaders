// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus. Original Diwali artwork.
// Perimeter geometry adapted from Barrulus's Fairy Lights / Ghostly Tear Border.
// Keep the artwork helpers and constants aligned with the companion shader; see README.md.
#define DIYA_RADII umbriel_border_radius
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
// Client-edge anchors align the outside border and inside companion exactly.
const float LAMP_SPACING = 72.0; // Logical pixels between lamps.
const float LAMP_SCALE = 0.60; // About 14 pixels across, formerly 23.
const float REACH = 14.0; // Hard bound on either side; fade begins at 10px.
const float INTENSITY = 0.98;
const float TAU = 6.28318530718;
float diya_offset(float borderWidth) { return 0.0; }

vec4 diya_radii(vec2 clientSize, float borderWidth) {
    return clamp(DIYA_RADII, 0.0, min(clientSize.x, clientSize.y) * 0.5) + diya_offset(borderWidth);
}

float diya_length(vec2 clientSize, float borderWidth) {
    vec2 size = clientSize + 2.0 * diya_offset(borderWidth);
    return 2.0 * (size.x + size.y) - (2.0 - 1.57079632679) * dot(diya_radii(clientSize, borderWidth), vec4(1.0));
}

// Rounded arclength spaces the lamps evenly around the client.
float diya_perimeter(vec2 coords, vec2 clientSize, float borderWidth) {
    vec2 p = coords + diya_offset(borderWidth);
    vec2 size = clientSize + 2.0 * diya_offset(borderWidth);
    vec4 r = diya_radii(clientSize, borderWidth); // TL, TR, BR, BL
    const float quarter = 1.57079632679;
    float top = size.x - r.x - r.y;
    float right_start = top + quarter * r.y;
    float br_start = right_start + size.y - r.y - r.z;
    float bottom_start = br_start + quarter * r.z;
    float bl_start = bottom_start + size.x - r.z - r.w;
    float left_start = bl_start + quarter * r.w;
    float tl_start = left_start + size.y - r.w - r.x;
    if (p.x >= size.x - r.y && p.y <= r.y)
        return top + r.y * atan(max(p.x - size.x + r.y, 0.00001), max(r.y - p.y, 0.00001));
    if (p.x >= size.x - r.z && p.y >= size.y - r.z)
        return br_start + r.z * atan(max(p.y - size.y + r.z, 0.00001), max(p.x - size.x + r.z, 0.00001));
    if (p.x <= r.w && p.y >= size.y - r.w)
        return bl_start + r.w * atan(max(r.w - p.x, 0.00001), max(p.y - size.y + r.w, 0.00001));
    if (p.x <= r.x && p.y <= r.x)
        return tl_start + r.x * atan(max(r.x - p.y, 0.00001), max(r.x - p.x, 0.00001));
    vec4 distances = abs(vec4(p.y, p.x - size.x, p.y - size.y, p.x));
    float nearest = min(min(distances.x, distances.y), min(distances.z, distances.w));
    if (nearest == distances.x) return clamp(p.x - r.x, 0.0, top);
    if (nearest == distances.y) return right_start + clamp(p.y - r.y, 0.0, size.y - r.y - r.z);
    if (nearest == distances.z) return bottom_start + clamp(size.x - r.z - p.x, 0.0, size.x - r.z - r.w);
    return left_start + clamp(size.y - r.w - p.y, 0.0, size.y - r.w - r.x);
}

// Return a position and outward normal on the same rounded cable path.
vec4 diya_point(float s, vec2 clientSize, float borderWidth) {
    float offset = diya_offset(borderWidth);
    vec2 size = clientSize + 2.0 * offset;
    vec4 r = diya_radii(clientSize, borderWidth);
    const float quarter = 1.57079632679;
    float n = size.x - r.x - r.y;
    if (s < n) return vec4(vec2(r.x+s, 0.0)-offset, 0.0, -1.0);
    s -= n; n = quarter*r.y;
    if (s < n) {
        float a = s/r.y;
        vec2 normal = vec2(sin(a), -cos(a));
        return vec4(vec2(size.x-r.y, r.y)+r.y*normal-offset, normal);
    }
    s -= n; n = size.y-r.y-r.z;
    if (s < n) return vec4(vec2(size.x,r.y+s)-offset, 1.0, 0.0);
    s -= n; n = quarter*r.z;
    if (s < n) {
        float a = s/r.z;
        vec2 normal = vec2(cos(a),sin(a));
        return vec4(vec2(size.x-r.z,size.y-r.z)+r.z*normal-offset,normal);
    }
    s -= n; n = size.x-r.z-r.w;
    if (s < n) return vec4(vec2(size.x-r.z-s,size.y)-offset, 0.0, 1.0);
    s -= n; n = quarter*r.w;
    if (s < n) {
        float a = s/r.w;
        vec2 normal = vec2(-sin(a),cos(a));
        return vec4(vec2(r.w,size.y-r.w)+r.w*normal-offset,normal);
    }
    s -= n; n = size.y-r.w-r.x;
    if (s < n) return vec4(vec2(0.0,size.y-r.w-s)-offset, -1.0, 0.0);
    s -= n;
    float a = s/max(r.x,0.00001);
    vec2 normal = vec2(-cos(a),-sin(a));
    return vec4(vec2(r.x)+r.x*normal-offset,normal);
}


vec4 diya_over(vec4 back,vec3 colour,float alpha) {
    alpha=clamp(alpha,0.0,1.0);
    return vec4(colour*alpha+back.rgb*(1.0-alpha),alpha+back.a*(1.0-alpha));
}
// Three jewel-coloured lights fill each gap between neighbouring lamps.
vec3 diya_colour(float id) {
    return 0.55+0.45*cos(TAU*(fract(id*0.61803399)+vec3(0.0,0.333333,0.666667)));
}
vec4 diya_material(vec2 point,vec2 size,float d) {
    float pixelAA=0.65/max(umbriel_scale,0.01);
    float perimeter=max(diya_length(size,0.0),1.0);
    float along=diya_perimeter(point,size,0.0);
    float count=max(4.0,floor(perimeter/max(LAMP_SPACING,48.0)+0.5));
    float stepSize=perimeter/count;
    vec4 result=vec4(0.0);
    float cord=1.0-smoothstep(0.20,0.20+pixelAA,abs(d));
    result=diya_over(result,vec3(0.67,0.37,0.10),cord*0.65);
    float lightStep=stepSize/4.0;
    float lightCell=floor(along/lightStep);
    for(int j=-1;j<=1;++j) {
        float id=mod(lightCell+float(j),count*4.0);
        if(mod(id,4.0)==2.0) continue; // This position belongs to a diya.
        vec2 p=point-diya_point(id*lightStep,size,0.0).xy;
        if(max(abs(p.x),abs(p.y))>8.0) continue;
        float radius=length(p);
        vec3 colour=diya_colour(id);
        float twinkle=pow(0.5+0.5*sin(umbriel_time*(1.3+0.35*fract(id*0.37))+id*2.399963),5.0);
        float glow=exp(-dot(p,p)/12.0)*(0.16+0.16*twinkle);
        result=diya_over(result,colour,glow);
        float bulb=1.0-smoothstep(0.85,1.4+pixelAA,radius);
        result=diya_over(result,colour,bulb*(0.7+0.3*twinkle));
        // Short four-point glints pulse independently, with a steady coloured core.
        vec2 q=abs(p);
        float star=min(max(q.x*0.22,q.y),max(q.y*0.22,q.x));
        float rays=(1.0-smoothstep(0.16,0.40+pixelAA*0.4,star))
            *(1.0-smoothstep(2.0,4.5,max(q.x,q.y)));
        result=diya_over(result,mix(colour,vec3(1.0),0.55),rays*twinkle*0.85);
        result=diya_over(result,mix(colour,vec3(1.0),0.7),
            (1.0-smoothstep(0.0,0.65+pixelAA*0.3,radius))*(0.55+0.4*twinkle));
    }
    float aa=pixelAA/LAMP_SCALE;
    float cell=floor(along/stepSize);
    for(int i=-1;i<=1;++i) {
        float id=mod(cell+float(i),count);
        vec4 anchor=diya_point((id+0.5)*stepSize,size,0.0);
        // Oil bowls remain upright on every side, including rounded corners.
        vec2 p=(point-anchor.xy)/LAMP_SCALE+vec2(0.0,-2.6);
        if(abs(p.x)>25.0 || abs(p.y)>25.0) continue;
        float time=umbriel_time;
        float breath=0.90+0.10*sin(time*1.7+id*2.399963);
        vec2 glow=p-vec2(0.0,-5.0);
        float halo=exp(-dot(glow,glow)/90.0)*0.22*breath;
        result=diya_over(result,vec3(1.0,0.49,0.065),halo);
        // Rounded terracotta bowl, open at the top with a bright oil rim.
        float bowl=length((p-vec2(0.0,2.0))/vec2(11.5,6.8));
        float body=(1.0-smoothstep(1.0-aa/6.8,1.0+aa/6.8,bowl))*smoothstep(1.4-aa,2.3+aa,p.y);
        vec3 clay=mix(vec3(0.38,0.07,0.035),vec3(0.85,0.28,0.075),clamp((p.y-1.0)/8.0,0.0,1.0));
        result=diya_over(result,clay,body*0.98);
        float rim=length((p-vec2(0.0,2.1))/vec2(11.5,2.2));
        result=diya_over(result,vec3(0.99,0.65,0.22),(1.0-smoothstep(1.0-aa/2.2,1.0+aa/2.2,rim))*0.95);
        float oil=length((p-vec2(0.0,1.7))/vec2(9.2,1.15));
        result=diya_over(result,vec3(0.46,0.18,0.035),(1.0-smoothstep(0.8,1.2,oil))*0.92);
        float wick=max(abs(p.x)-0.55,abs(p.y-0.5)-1.8);
        result=diya_over(result,vec3(0.27,0.12,0.045),(1.0-smoothstep(-aa,aa,wick))*0.9);
        float h=(1.0-p.y)/15.0;
        if(h>0.0 && h<1.0) {
            float sway=sin(time*1.5+id*1.71)*1.2*h*h;
            float width=4.6*pow(max(sin(3.14159265*h),0.0),0.8)*(1.0-0.6*h);
            float flame=(1.0-smoothstep(width-aa,width+aa,abs(p.x-sway)))*smoothstep(0.0,0.09,h);
            result=diya_over(result,mix(vec3(1.0,0.29,0.015),vec3(1.0,0.76,0.18),h),flame*breath);
            float core=(1.0-smoothstep(width*0.20,width*0.45+aa,abs(p.x-sway)))*(1.0-smoothstep(0.36,0.72,h));
            result=diya_over(result,vec3(1.0,0.97,0.68),core*flame*0.95);
        }
    }
    return result*clamp(INTENSITY,0.0,1.0)*(1.0-smoothstep(REACH-4.0,REACH,abs(d)));
}

vec4 border(vec2 uv) {
    vec2 size=umbriel_border_hole.zw*umbriel_size;
    if(min(size.x,size.y)<=0.0) return vec4(0.0);
    float d=umbriel_border_distance(uv);
    if(d<0.0 || d>=REACH) return vec4(0.0);
    vec2 point=(uv-umbriel_border_hole.xy)*umbriel_size;
    return diya_material(point,size,d);
}
