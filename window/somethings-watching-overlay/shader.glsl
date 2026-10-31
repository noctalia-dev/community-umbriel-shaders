// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus. Original procedural artwork.
// Shared artwork must remain identical in the border and companion overlay.
const float INTENSITY = 0.95;
const float PUMPKIN_SIZE = 22.0; // fruit half-width in logical pixels
const float SKELETON_SCALE = 1.15;
const float PARADE_SPEED = 22.0; // logical pixels / second
const float PI = 3.14159265;
float hash21(vec2 p) {
    vec3 q=fract(vec3(p.xyx)*0.1031); q+=dot(q,q.yzx+33.33);
    return fract((q.x+q.y)*q.z);
}
float segment(vec2 p,vec2 a,vec2 b) {
    vec2 ab=b-a;
    return length(p-a-ab*clamp(dot(p-a,ab)/max(dot(ab,ab),0.001),0.0,1.0));
}
vec2 rotatePoint(vec2 p,float angle) {
    float c=cos(angle),s=sin(angle);return vec2(c*p.x-s*p.y,s*p.x+c*p.y);
}
vec4 over(vec4 under,vec3 color,float alpha) {
    alpha=clamp(alpha,0.0,1.0);return vec4(color*alpha,alpha)+under*(1.0-alpha);
}
float coverage(float distance) {
    float aa=0.65/max(umbriel_scale,0.1);
    return 1.0-smoothstep(-aa,aa,distance);
}
float radiusFor(vec2 size) { return min(18.0,min(size.x,size.y)*0.18); }
float perimeter(vec2 size,float r) { return 2.0*(size.x+size.y-4.0*r)+2.0*PI*r; }
// Clockwise arclength and signed inward distance, including rounded corners.
vec2 frameCoord(vec2 p,vec2 size,float r) {
    float x=size.x-2.0*r,y=size.y-2.0*r,a=PI*r*0.5;
    if(p.x<r && p.y<r) {
        vec2 q=p-vec2(r);return vec2(2.0*x+2.0*y+3.0*a+(atan(q.y,q.x)+PI)*r,r-length(q));
    }
    if(p.x>size.x-r && p.y<r) {
        vec2 q=p-vec2(size.x-r,r);return vec2(x+(atan(q.y,q.x)+PI*0.5)*r,r-length(q));
    }
    if(p.x>size.x-r && p.y>size.y-r) {
        vec2 q=p-(size-vec2(r));return vec2(x+y+a+atan(q.y,q.x)*r,r-length(q));
    }
    if(p.x<r && p.y>size.y-r) {
        vec2 q=p-vec2(r,size.y-r);return vec2(2.0*x+y+2.0*a+(atan(q.y,q.x)-PI*0.5)*r,r-length(q));
    }
    float d=min(min(p.x,size.x-p.x),min(p.y,size.y-p.y));
    if(d==p.y) return vec2(p.x-r,d);
    if(d==size.x-p.x) return vec2(x+a+p.y-r,d);
    if(d==size.y-p.y) return vec2(x+y+2.0*a+size.x-r-p.x,d);
    return vec2(2.0*x+y+3.0*a+size.y-r-p.y,d);
}
vec2 framePoint(float u,vec2 size,float r) {
    float x=size.x-2.0*r,y=size.y-2.0*r,a=PI*r*0.5;
    u=mod(u,perimeter(size,r));
    if(u<x)return vec2(r+u,0.0);u-=x;
    if(u<a){float t=u/r-PI*0.5;return vec2(size.x-r,r)+r*vec2(cos(t),sin(t));}u-=a;
    if(u<y)return vec2(size.x,r+u);u-=y;
    if(u<a){float t=u/r;return size-vec2(r)+r*vec2(cos(t),sin(t));}u-=a;
    if(u<x)return vec2(size.x-r-u,size.y);u-=x;
    if(u<a){float t=u/r+PI*0.5;return vec2(r,size.y-r)+r*vec2(cos(t),sin(t));}u-=a;
    if(u<y)return vec2(0.0,size.y-r-u);u-=y;
    float t=u/r+PI;return vec2(r)+r*vec2(cos(t),sin(t));
}
vec4 pumpkin(vec4 art,vec2 p,vec2 anchor,vec2 inward,float seed) {
    float phase=mod(umbriel_time+seed*15.0,15.0);
    float growth=smoothstep(0.0,4.0,phase);
    float dissolve=1.0-smoothstep(13.2,15.0,phase);
    float fruitScale=(0.14+0.86*growth)*(0.80+seed*0.27);
    float rx=PUMPKIN_SIZE*fruitScale, ry=rx*0.79;
    vec2 center=anchor+inward*(12.0+rx*0.75);
    center+=vec2(sin(umbriel_time*0.7+seed*9.0)*2.0,0.0);
    if(length(p-center)>rx+38.0)return art;
    // Curved stalk connects the vine to the top of an upright pumpkin.
    vec2 top=center+vec2(-2.0,-ry-4.0);
    vec2 control=mix(anchor,top,0.5)+vec2(-12.0, -8.0);
    float stem=1000.0;vec2 previous=anchor;
    for(int j=1;j<=5;++j){float t=float(j)/5.0;vec2 point=mix(mix(anchor,control,t),mix(control,top,t),t);stem=min(stem,segment(p,previous,point));previous=point;}
    art=over(art,vec3(0.19,0.32,0.07),coverage(stem-1.7)*dissolve);
    vec2 q=(p-center)/max(vec2(rx,ry),vec2(1.0));
    float angle=atan(q.y,q.x);
    float shape=(length(q)-1.0+0.038*cos(angle*6.0))*min(rx,ry);
    float silhouette=coverage(shape);
    float rib=0.5+0.5*cos(q.x*PI*4.0);
    float shade=clamp(0.75-0.22*q.x-0.16*q.y,0.2,1.0);
    vec3 orange=mix(vec3(0.45,0.095,0.008),vec3(1.0,0.43,0.055),shade*(0.70+0.30*rib));
    art=over(art,vec3(0.075,0.045,0.02),coverage(shape-1.4)*0.8*dissolve);
    art=over(art,orange,silhouette*dissolve);
    // Carved triangular eyes and a jagged grin, lit by a candle.
    vec2 eye=vec2(abs(q.x)-0.36,q.y+0.15);
    float triangle=max(abs(eye.x)*1.3-(eye.y+0.18)*0.65, max(-eye.y-0.18,eye.y-0.14));
    float eyes=1.0-smoothstep(-0.025,0.025,triangle);
    float mouthY=0.36+0.10*cos(q.x*PI*1.8);
    float teeth=0.035+0.035*step(0.0,sin(q.x*30.0));
    float mouth=(1.0-smoothstep(0.44,0.53,abs(q.x)))*(1.0-smoothstep(teeth,teeth+0.04,abs(q.y-mouthY)));
    float face=max(eyes,mouth)*silhouette*smoothstep(0.3,0.7,growth)*dissolve;
    float candle=0.82+0.12*sin(umbriel_time*5.0+seed*13.0)+0.06*sin(umbriel_time*11.0);
    art=over(art,vec3(1.0,0.82,0.24)*candle,face);
    // Short woody stem, visible above the fruit lobes.
    float stalk=segment(p,center+vec2(-2.0,-ry+2.0),top+vec2(3.0,-2.0));
    art=over(art,vec3(0.28,0.34,0.08),coverage(stalk-2.1)*dissolve);
    return art;
}
vec4 skeleton(vec4 art,vec2 p,vec2 foot,float phase) {
    vec2 q=(p-foot)/SKELETON_SCALE;
    if(abs(q.x)>17.0 || q.y < -41.0 || q.y>5.0)return art;
    q.y+=abs(sin(phase))*1.3;
    float walk=sin(phase);
    float bones=segment(q,vec2(0.0,-24.0),vec2(0.0,-12.0))-0.95;
    for(int side=0;side<2;++side){
        float s=side==0?-1.0:1.0;
        float stepPhase=walk*s;
        vec2 knee=vec2(s*3.5+stepPhase*3.0,-6.0-max(stepPhase,0.0)*1.5);
        vec2 ankle=vec2(s*3.5+stepPhase*5.0,-max(stepPhase,0.0)*3.0);
        bones=min(bones,segment(q,vec2(s*3.8,-12.0),knee)-1.0);
        bones=min(bones,segment(q,knee,ankle)-0.9);
        bones=min(bones,segment(q,ankle,ankle+vec2(3.0,0.0))-1.0);
        vec2 elbow=vec2(s*7.0-stepPhase*2.5,-18.0);
        bones=min(bones,segment(q,vec2(s*3.8,-23.0),elbow)-0.9);
        bones=min(bones,segment(q,elbow,vec2(s*8.0-stepPhase*4.0,-13.0))-0.85);
        for(int rib=0;rib<3;++rib){float y=-22.0+float(rib)*3.0;bones=min(bones,segment(q,vec2(0.0,y),vec2(s*(4.4-float(rib)*0.5),y+1.2))-0.7);}
        bones=min(bones,segment(q,vec2(0.0,-10.0),vec2(s*4.0,-12.0))-1.0);
    }
    float skull=(length((q-vec2(0.0,-31.0))/vec2(5.6,6.0))-1.0)*5.6;
    float jaw=max(abs(q.x)-3.8,abs(q.y+25.8)-2.0);
    float shape=min(bones,min(skull,jaw));
    art=over(art,vec3(0.035,0.05,0.04),coverage((shape-1.0)*SKELETON_SCALE)*0.8);
    art=over(art,vec3(0.85,0.91,0.69),coverage(shape*SKELETON_SCALE));
    float eye=min(length(q-vec2(-2.3,-31.0)),length(q-vec2(2.3,-31.0)))-1.5;
    float nose=length((q-vec2(0.0,-28.3))/vec2(0.65,1.0))-1.0;
    float teeth=max(abs(q.y+25.7)-1.0,abs(fract((q.x+4.0)/2.0)-0.5)*2.0-0.18);
    float holes=max(coverage(min(eye,nose)*SKELETON_SCALE),coverage(teeth*SKELETON_SCALE)*(1.0-step(3.5,abs(q.x))));
    return over(art,vec3(0.035,0.065,0.045),holes*coverage(shape*SKELETON_SCALE));
}
vec4 eyes(vec4 art,vec2 p,vec2 size) {
    for(int i=0;i<4;++i){
        float fi=float(i),clock=umbriel_time+fi*2.3,phase=mod(clock,11.0);
        float show=smoothstep(0.0,0.7,phase)*(1.0-smoothstep(4.0,4.7,phase));
        float along=mix(0.15,0.85,hash21(vec2(floor(clock/11.0),fi+8.0)));
        vec2 center;
        if(i==0)center=vec2(size.x*along,12.0);
        else if(i==1)center=vec2(size.x-12.0,size.y*along);
        else if(i==2)center=vec2(size.x*along,size.y-12.0);
        else center=vec2(12.0,size.y*along);
        vec2 q=(p-center)/1.7;float side=q.x<0.0?-1.0:1.0;q.x-=side*5.0;
        q.y+=side*q.x*0.18;
        float blink=1.0-0.95*exp(-pow((phase-2.6)/0.10,2.0));
        float shape=length(q/vec2(3.8,max(0.2,2.3*blink)));
        float a=(1.0-smoothstep(0.8,1.15,shape))*show;
        float pupil=1.0-smoothstep(0.40,0.85,abs(q.x));
        art=over(art,mix(vec3(0.20,0.96,0.38),vec3(0.025,0.045,0.025),pupil),a);
    }
    return art;
}
vec4 garden(vec2 p,vec2 size) {
    float r=radiusFor(size),total=perimeter(size,r);
    vec2 frame=frameCoord(p,size,r);
    float u=frame.x,d=frame.y;
    if(d>70.0 || d < -48.0)return vec4(0.0);
    float waves=max(4.0,floor(total/105.0));
    float phase=u/total*waves*2.0*PI-umbriel_time*0.48;
    phase+=0.28*sin(u/total*6.0*PI);
    float twist=sin(phase);
    float amplitude=7.5+2.0*sin(u/total*10.0*PI+umbriel_time*0.2);
    vec4 art=vec4(0.0);
    // Two stems braid over and under one another around the complete frame.
    for(int i=0;i<2;++i){
        float side=i==0?-1.0:1.0;
        float center=2.0+side*amplitude*twist;
        float dist=abs(d-center);
        float width=i==0?2.8:2.0;
        float light=0.55+0.45*(0.5+0.5*side*cos(phase));
        art=over(art,vec3(0.025,0.055,0.018),coverage(dist-width-1.2)*0.8);
        art=over(art,mix(vec3(0.10,0.22,0.035),vec3(0.40,0.64,0.13),light),coverage(dist-width));
        art=over(art,vec3(0.63,0.75,0.24),coverage(abs(d-center+width*0.45)-0.45)*0.5);
    }
    // Leaves grow on alternating sides, with a central vein.
    float leafCount=max(8.0,floor(total/47.0)),cell=total/leafCount;
    float leafIndex=floor(u/cell),side=mod(leafIndex,2.0)<1.0?-1.0:1.0;
    vec2 leaf=vec2(mod(u,cell)-cell*0.5,d-(2.0+side*12.0));
    leaf=rotatePoint(leaf,side*0.75+0.10*sin(umbriel_time+leafIndex));
    float leafShape=length(leaf/vec2(9.0,4.4))-1.0;
    art=over(art,mix(vec3(0.12,0.30,0.05),vec3(0.32,0.52,0.09),hash21(vec2(leafIndex,2.0))),coverage(leafShape*4.4));
    art=over(art,vec3(0.50,0.66,0.18),coverage(abs(leaf.y)-0.45)*coverage(leafShape*4.4)*0.7);
    // Spiral tendrils fill the gaps between fruits.
    vec2 curl=vec2(mod(u,cell*2.0)-cell,d-17.0);
    float theta=atan(curl.y,curl.x),rad=length(curl);
    float coil=abs(rad-(5.0+theta*1.0));
    art=over(art,vec3(0.30,0.49,0.08),coverage(coil-0.75)*(1.0-smoothstep(7.0,9.0,rad)));
    for(int i=0;i<8;++i){
        float fi=float(i),pair=mod(fi,2.0),edge=floor(fi/2.0);
        float axis=(edge==0.0 || edge==2.0)?size.x:size.y;
        if(axis>210.0 || pair<0.5){
            float along=axis>210.0?mix(0.23,0.73,pair):0.5;
            vec2 anchor,inward;
            if(i<2){anchor=vec2(size.x*along,0.0);inward=vec2(0.0,1.0);}
            else if(i<4){anchor=vec2(size.x,size.y*along);inward=vec2(-1.0,0.0);}
            else if(i<6){anchor=vec2(size.x*along,size.y);inward=vec2(0.0,-1.0);}
            else{anchor=vec2(0.0,size.y*along);inward=vec2(1.0,0.0);}
            art=pumpkin(art,p,anchor,inward,hash21(vec2(fi,5.0)));
        }
    }
    for(int i=0;i<3;++i){
        float walk=umbriel_time*PARADE_SPEED+float(i)*total/3.0;
        vec2 foot=framePoint(walk,size,r);
        art=skeleton(art,p,foot,umbriel_time*6.5+float(i)*2.1);
    }
    art=eyes(art,p,size);
    return art*INTENSITY;
}

vec4 window(vec2 uv) {
    vec4 source=umbriel_sample(uv);
    vec4 art=garden(uv*umbriel_size,umbriel_size);
    return vec4(art.rgb*source.a+source.rgb*(1.0-art.a),source.a);
}
