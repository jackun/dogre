/**
 * NOT USED
 * Initially i was going to use this to fix CTFE errors, but G/SET_FLOAT_WORD create their own, uhhhh.
 * 
 * */
module ogre.math.ieee754;
import std.math;
import std.bitmanip;

alias abs fabsf;

struct Float2Word
{
    union
    {
        float value;
        mixin(bitfields!(
                  uint,  "word", 31,
                  bool, "sign", 1));// Blabla shift by 32 out of range, blabla field must be sum of 32
    }
    enum uint wordBits = 31, signBits = 1;
}


union ieee_float_shape_type { uint i; float f;}

void GET_FLOAT_WORD(ref uint x, float y)
{
    Float2Word fw;
    fw.value = y;
    x = fw.loword | fw.hiword << 16;
    /*version(__ctfe)
    {
        x = 0;
        uint *yy = cast(uint*)&y;
        uint mask = 1;
        for(int i = 0; i < float.sizeof * 8; i++)
        {
            x = x | (*yy & mask << i);
        }
    }
    else
    {
        ieee_float_shape_type f2i;
        f2i.f = y;
        x = f2i.i;
    }*/
}

void GET_FLOAT_WORD(ref int x, float y)
{
    Float2Word fw;
    fw.value = y;
    x = fw.word | fw.sign << fw.wordBits;
    
    /+
        ieee_float_shape_type f2i;
        f2i.f = y;
        x = f2i.i;
    +/
}

void SET_FLOAT_WORD(ref float x, int y)
{
    ieee_float_shape_type f2i;
    f2i.i = y;
    x = f2i.f;
}

staticfloat
tiny  = 1.0e-30,
zero  = 0.0,
pi_o_4  = 7.8539818525e-01,  /* 0x3f490fdb */
pi_o_2  = 1.5707963705e+00,  /* 0x3fc90fdb */
pi      = 3.1415927410e+00,  /* 0x40490fdb */
pi_lo   = -8.7422776573e-08; /* 0xb3bbbd2e */

float atanf (float x)
{
    return atan2f(x, 1.0f);
}

float atan2f (float y, float x)
{
    float z;
    int k,m,hx,hy,ix,iy;

    GET_FLOAT_WORD(hx,x);
    ix = hx&0x7fffffff;
    GET_FLOAT_WORD(hy,y);
    iy = hy&0x7fffffff;
    if((ix>0x7f800000)||
       (iy>0x7f800000)) /* x or y is NaN */
       return x+y;
    if(hx==0x3f800000) return __atanf(y);   /* x=1.0 */
    m = ((hy>>31)&1)|((hx>>30)&2);  /* 2*sign(x)+sign(y) */

    /* when y = 0 */
    if(iy==0) {
        switch(m) {
        case 0:
        case 1: return y;   /* atan(+-0,+anything)=+-0 */
        case 2: return  pi+tiny;/* atan(+0,-anything) = pi */
        case 3: return -pi-tiny;/* atan(-0,-anything) =-pi */
        default: assert(0);
        }
    }
    /* when x = 0 */
    if(ix==0) return (hy<0)?  -pi_o_2-tiny: pi_o_2+tiny;

    /* when x is INF */
    if(ix==0x7f800000) {
        if(iy==0x7f800000) {
        switch(m) {
            case 0: return  pi_o_4+tiny;/* atan(+INF,+INF) */
            case 1: return -pi_o_4-tiny;/* atan(-INF,+INF) */
            case 2: return  cast(float)3.0*pi_o_4+tiny;/*atan(+INF,-INF)*/
            case 3: return  cast(float)-3.0*pi_o_4-tiny;/*atan(-INF,-INF)*/
            default: assert(0);
        }
        } else {
        switch(m) {
            case 0: return  zero  ; /* atan(+...,+INF) */
            case 1: return -zero  ; /* atan(-...,+INF) */
            case 2: return  pi+tiny  ;  /* atan(+...,-INF) */
            case 3: return -pi-tiny  ;  /* atan(-...,-INF) */
            default: assert(0);
        }
        }
    }
    /* when y is INF */
    if(iy==0x7f800000) return (hy<0)? -pi_o_2-tiny: pi_o_2+tiny;

    /* compute y/x */
    k = (iy-ix)>>23;
    if(k > 60) z=pi_o_2+cast(float)0.5*pi_lo;   /* |y/x| >  2**60 */
    else if(hx<0&&k<-60) z=0.0; /* |y|/x < -2**60 */
    else z=__atanf(fabsf(y/x)); /* safe to do y/x */
    switch (m) {
        case 0: return       z  ;   /* atan(+,+) */
        case 1: {
              uint zh;
              GET_FLOAT_WORD(zh,z);
              SET_FLOAT_WORD(z,zh ^ 0x80000000);
            }
            return       z  ;   /* atan(-,+) */
        case 2: return  pi-(z-pi_lo);/* atan(+,-) */
        default: /* case 3 */
            return  (z-pi_lo)-pi;/* atan(-,-) */
    }
}


staticfloat[] atanhi = [
  4.6364760399e-01, /* atan(0.5)hi 0x3eed6338 */
  7.8539812565e-01, /* atan(1.0)hi 0x3f490fda */
  9.8279368877e-01, /* atan(1.5)hi 0x3f7b985e */
  1.5707962513e+00, /* atan(inf)hi 0x3fc90fda */
];

staticfloat[] atanlo = [
  5.0121582440e-09, /* atan(0.5)lo 0x31ac3769 */
  3.7748947079e-08, /* atan(1.0)lo 0x33222168 */
  3.4473217170e-08, /* atan(1.5)lo 0x33140fb4 */
  7.5497894159e-08, /* atan(inf)lo 0x33a22168 */
];

staticfloat[] aT = [
  3.3333334327e-01, /* 0x3eaaaaaa */
 -2.0000000298e-01, /* 0xbe4ccccd */
  1.4285714924e-01, /* 0x3e124925 */
 -1.1111110449e-01, /* 0xbde38e38 */
  9.0908870101e-02, /* 0x3dba2e6e */
 -7.6918758452e-02, /* 0xbd9d8795 */
  6.6610731184e-02, /* 0x3d886b35 */
 -5.8335702866e-02, /* 0xbd6ef16b */
  4.9768779427e-02, /* 0x3d4bda59 */
 -3.6531571299e-02, /* 0xbd15a221 */
  1.6285819933e-02, /* 0x3c8569d7 */
];

staticfloat
one   = 1.0,
huge   = 1.0e30;

float __atanf(float x)
{
    float w,s1,s2,z;
    int ix,hx,id;

    GET_FLOAT_WORD(hx,x);
    ix = hx&0x7fffffff;
    if(ix>=0x50800000) {    /* if |x| >= 2^34 */
        if(ix>0x7f800000)
        return x+x;     /* NaN */
        if(hx>0) return  atanhi[3]+atanlo[3];
        else     return -atanhi[3]-atanlo[3];
    } if (ix < 0x3ee00000) {    /* |x| < 0.4375 */
        if (ix < 0x31000000) {  /* |x| < 2^-29 */
        if(huge+x>one) return x;    /* raise inexact */
        }
        id = -1;
    } else {
    x = fabsf(x);
    if (ix < 0x3f980000) {      /* |x| < 1.1875 */
        if (ix < 0x3f300000) {  /* 7/16 <=|x|<11/16 */
        id = 0; x = (cast(float)2.0*x-one)/(cast(float)2.0+x); 
        } else {            /* 11/16<=|x|< 19/16 */
        id = 1; x  = (x-one)/(x+one); 
        }
    } else {
        if (ix < 0x401c0000) {  /* |x| < 2.4375 */
        id = 2; x  = (x-cast(float)1.5)/(one+cast(float)1.5*x);
        } else {            /* 2.4375 <= |x| < 2^66 */
        id = 3; x  = -cast(float)1.0/x;
        }
    }}
    /* end of argument reduction */
    z = x*x;
    w = z*z;
    /* break sum from i=0 to 10 aT[i]z**(i+1) into odd and even poly */
    s1 = z*(aT[0]+w*(aT[2]+w*(aT[4]+w*(aT[6]+w*(aT[8]+w*aT[10])))));
    s2 = w*(aT[1]+w*(aT[3]+w*(aT[5]+w*(aT[7]+w*aT[9]))));
    if (id<0) return x - x*(s1+s2);
    else {
        z = atanhi[id] - ((x*(s1+s2) - atanlo[id]) - x);
        return (hx<0)? -z:z;
    }
}


unittest
{
    class Test
    {
        static this()
        {
            enum float PI = 4.0f * atanf( 1.0f );
            //enum float PI = 3.14159f;
            enum float TWO_PI = 2.0f * PI;
            enum float HALF_PI = 0.5f * PI;
            enum float fDeg2Rad = PI / 180.0f;
            enum float fRad2Deg = 180.0f / PI;
            enum float LOG2 = 0.693147f; //log(2.0f);
        }
    }
    
    //TODO uh, floats
    import std.stdio;
    writeln("atan2f(0.45f, 1.0f) = ", atan2f(0.45f,1.0f), ". Should be 0.422854"); // atan2f(0.45f, 1.0f) = 0.422854
    writeln("4*atan2f(1.0f, 1.0f) = ", 4 * atan2f(1.0f,1.0f), ". Should be 3.14159");
}

