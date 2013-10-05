module ogre.general.colourvalue;

import ogre.math.maths;
import ogre.compat;

/** \addtogroup Core
*  @{
*/
/** \addtogroup General
*  @{
*/

alias uint RGBA;
alias uint ARGB;
alias uint ABGR;
alias uint BGRA;

/** Class representing colour.
    @remarks
        Colour is represented as 4 components, each of which is a
        floating-point value from 0.0 to 1.0.
    @par
        The 3 'normal' colour components are red, green and blue, a higher
        number indicating greater amounts of that component in the colour.
        The forth component is the 'alpha' value, which represents
        transparency. In this case, 0.0 is completely transparent and 1.0 is
        fully opaque.
*/
struct ColourValue
{
public:
    float r,g,b,a;

    enum ColourValue ZERO = ColourValue(0.0,0.0,0.0,0.0);
    enum ColourValue Black = ColourValue(0.0,0.0,0.0);
    enum ColourValue White = ColourValue(1.0,1.0,1.0);
    enum ColourValue Red = ColourValue(1.0,0.0,0.0);
    enum ColourValue Green = ColourValue(0.0,1.0,0.0);
    enum ColourValue Blue = ColourValue(0.0,0.0,1.0);

    this( float red = 1.0f,
                float green = 1.0f,
                float blue = 1.0f,
                float alpha = 1.0f )
    {
        r = red; g = green; b = blue; a = alpha;
    }

    bool opEquals(ColourValue rhs) const
    {
        return (r == rhs.r &&
            g == rhs.g &&
            b == rhs.b &&
            a == rhs.a);
    }
    
    //bool operator!=(/+ref+/ColourValue rhs);

    uint getAsRGBA()
    {
        ubyte val8;
        uint val32 = 0;

        version(BigEndian)
        {
            // Convert to 32bit pattern
            // (ABRG = 8888)
    
            // Alpha
            val8 = cast(ubyte)(a * 255);
            val32 = val8 << 24;
    
            // Blue
            val8 = cast(ubyte)(b * 255);
            val32 += val8 << 16;
    
            // Green
            val8 = cast(ubyte)(g * 255);
            val32 += val8 << 8;
    
            // Red
            val8 = cast(ubyte)(r * 255);
            val32 += val8;
        }
        else
        {
            // Convert to 32bit pattern
            // (RGBA = 8888)
    
            // Red
            val8 = cast(ubyte)(r * 255);
            val32 = val8 << 24;
    
            // Green
            val8 = cast(ubyte)(g * 255);
            val32 += val8 << 16;
    
            // Blue
            val8 = cast(ubyte)(b * 255);
            val32 += val8 << 8;
    
            // Alpha
            val8 = cast(ubyte)(a * 255);
            val32 += val8;
        }
        return val32;
    }
    
    uint getAsARGB()
    {
        ubyte val8;
        uint val32 = 0;

        version(BigEndian)
        {
            // Convert to 32bit pattern
            // (ARGB = 8888)
    
            // Blue
            val8 = cast(ubyte)(b * 255);
            val32 = val8 << 24;
    
            // Green
            val8 = cast(ubyte)(g * 255);
            val32 += val8 << 16;
    
            // Red
            val8 = cast(ubyte)(r * 255);
            val32 += val8 << 8;
    
            // Alpha
            val8 = cast(ubyte)(a * 255);
            val32 += val8;
        }
        else
        {
            // Convert to 32bit pattern
            // (ARGB = 8888)
    
            // Alpha
            val8 = cast(ubyte)(a * 255);
            val32 = val8 << 24;
    
            // Red
            val8 = cast(ubyte)(r * 255);
            val32 += val8 << 16;
    
            // Green
            val8 = cast(ubyte)(g * 255);
            val32 += val8 << 8;
    
            // Blue
            val8 = cast(ubyte)(b * 255);
            val32 += val8;
        }
        return val32;
    }
    
    uint getAsBGRA()
    {
        ubyte val8;
        uint val32 = 0;

        version(BigEndian)
        {
            // Convert to 32bit pattern
            // (ARGB = 8888)
    
            // Alpha
            val8 = cast(ubyte)(a * 255);
            val32 = val8 << 24;
    
            // Red
            val8 = cast(ubyte)(r * 255);
            val32 += val8 << 16;
    
            // Green
            val8 = cast(ubyte)(g * 255);
            val32 += val8 << 8;
    
            // Blue
            val8 = cast(ubyte)(b * 255);
            val32 += val8;

        }
        else
        {
            // Convert to 32bit pattern
            // (ARGB = 8888)
    
            // Blue
            val8 = cast(ubyte)(b * 255);
            val32 = val8 << 24;
    
            // Green
            val8 = cast(ubyte)(g * 255);
            val32 += val8 << 16;
    
            // Red
            val8 = cast(ubyte)(r * 255);
            val32 += val8 << 8;
    
            // Alpha
            val8 = cast(ubyte)(a * 255);
            val32 += val8;
        }

        return val32;
    }
    
    uint getAsABGR()
    {
        ubyte val8;
        uint val32 = 0;

        version(BigEndian)
        {
            // Convert to 32bit pattern
            // (RGBA = 8888)
    
            // Red
            val8 = cast(ubyte)(r * 255);
            val32 = val8 << 24;
    
            // Green
            val8 = cast(ubyte)(g * 255);
            val32 += val8 << 16;
    
            // Blue
            val8 = cast(ubyte)(b * 255);
            val32 += val8 << 8;
    
            // Alpha
            val8 = cast(ubyte)(a * 255);
            val32 += val8;
        }
        else
        {
            // Convert to 32bit pattern
            // (ABRG = 8888)
    
            // Alpha
            val8 = cast(ubyte)(a * 255);
            val32 = val8 << 24;
    
            // Blue
            val8 = cast(ubyte)(b * 255);
            val32 += val8 << 16;
    
            // Green
            val8 = cast(ubyte)(g * 255);
            val32 += val8 << 8;
    
            // Red
            val8 = cast(ubyte)(r * 255);
            val32 += val8;
        }

        return val32;
    }

    void setAsRGBA(uint val32)
    {
        version(BigEndian)
        {
            // Convert from 32bit pattern
            // (ABGR = 8888)
    
            // Alpha
            a = ((val32 >> 24) & 0xFF) / 255.0f;
    
            // Blue
            b = ((val32 >> 16) & 0xFF) / 255.0f;
    
            // Green
            g = ((val32 >> 8) & 0xFF) / 255.0f;
    
            // Red
            r = (val32 & 0xFF) / 255.0f;
        }
        else
        {
            // Convert from 32bit pattern
            // (RGBA = 8888)
    
            // Red
            r = ((val32 >> 24) & 0xFF) / 255.0f;
    
            // Green
            g = ((val32 >> 16) & 0xFF) / 255.0f;
    
            // Blue
            b = ((val32 >> 8) & 0xFF) / 255.0f;
    
            // Alpha
            a = (val32 & 0xFF) / 255.0f;
        }
    }
    
    void setAsBGRA(uint val32)
    {

        version(BigEndian)
        {
            // Convert from 32bit pattern
            // (ARGB = 8888)
    
            // Alpha
            a = ((val32 >> 24) & 0xFF) / 255.0f;
    
            // Red
            r = ((val32 >> 16) & 0xFF) / 255.0f;
    
            // Green
            g = ((val32 >> 8) & 0xFF) / 255.0f;
    
            // Blue
            b = (val32 & 0xFF) / 255.0f;
        }
        else
        {
            // Convert from 32bit pattern
            // (ARGB = 8888)
    
            // Blue
            b = ((val32 >> 24) & 0xFF) / 255.0f;
    
            // Green
            g = ((val32 >> 16) & 0xFF) / 255.0f;
    
            // Red
            r = ((val32 >> 8) & 0xFF) / 255.0f;
    
            // Alpha
            a = (val32 & 0xFF) / 255.0f;
        }
    }
    
    void setAsARGB(uint val32)
    {
        version(BigEndian)
        {
            // Convert from 32bit pattern
            // (ARGB = 8888)
    
            // Blue
            b = ((val32 >> 24) & 0xFF) / 255.0f;
    
            // Green
            g = ((val32 >> 16) & 0xFF) / 255.0f;
    
            // Red
            r = ((val32 >> 8) & 0xFF) / 255.0f;
    
            // Alpha
            a = (val32 & 0xFF) / 255.0f;
        }
        else
        {
            // Convert from 32bit pattern
            // (ARGB = 8888)
    
            // Alpha
            a = ((val32 >> 24) & 0xFF) / 255.0f;
    
            // Red
            r = ((val32 >> 16) & 0xFF) / 255.0f;
    
            // Green
            g = ((val32 >> 8) & 0xFF) / 255.0f;
    
            // Blue
            b = (val32 & 0xFF) / 255.0f;
        }
    }
    
    void setAsABGR(uint val32)
    {
        version(BigEndian)
        {
            // Convert from 32bit pattern
            // (RGBA = 8888)
    
            // Red
            r = ((val32 >> 24) & 0xFF) / 255.0f;
    
            // Green
            g = ((val32 >> 16) & 0xFF) / 255.0f;
    
            // Blue
            b = ((val32 >> 8) & 0xFF) / 255.0f;
    
            // Alpha
            a = (val32 & 0xFF) / 255.0f;
        }
        else
        {
            // Convert from 32bit pattern
            // (ABGR = 8888)
    
            // Alpha
            a = ((val32 >> 24) & 0xFF) / 255.0f;
    
            // Blue
            b = ((val32 >> 16) & 0xFF) / 255.0f;
    
            // Green
            g = ((val32 >> 8) & 0xFF) / 255.0f;
    
            // Red
            r = (val32 & 0xFF) / 255.0f;
        }
    }
    /** Clamps colour value to the range [0, 1].
    */
    void saturate()
    {
        if (r < 0)
            r = 0;
        else if (r > 1)
            r = 1;

        if (g < 0)
            g = 0;
        else if (g > 1)
            g = 1;

        if (b < 0)
            b = 0;
        else if (b > 1)
            b = 1;

        if (a < 0)
            a = 0;
        else if (a > 1)
            a = 1;
    }

    /** As saturate, except that this colour value is unaffected and
        the saturated colour value is returned as a copy. */
    ColourValue saturateCopy()
    {
        ColourValue ret = ColourValue(r,g,b,a);//*this;
        ret.saturate();
        return ret;
    }

    /// Array accessor operator
    float opIndex (size_t i )
    {
        assert( i < 4 );

        //return *(&r+i);
        return [r,g,b,a][i];
    }

    /// Array accessor operator
    /*float& operator [] (size_t i )
    {
        assert( i < 4 );

        return *(&r+i);
    }*/

    /// Pointer accessor for direct copying
    @property
    float* ptr()
    {
        return &r;
    }

    
    // arithmetic operations
    ColourValue opAdd (/+ref+/ ColourValue rkVector )
    {
        ColourValue kSum;

        kSum.r = r + rkVector.r;
        kSum.g = g + rkVector.g;
        kSum.b = b + rkVector.b;
        kSum.a = a + rkVector.a;

        return kSum;
    }

    ColourValue opSub (/+ref+/ColourValue rkVector )
    {
        ColourValue kDiff;

        kDiff.r = r - rkVector.r;
        kDiff.g = g - rkVector.g;
        kDiff.b = b - rkVector.b;
        kDiff.a = a - rkVector.a;

        return kDiff;
    }

    ColourValue opMul (float fScalar )
    {
        ColourValue kProd;

        kProd.r = fScalar*r;
        kProd.g = fScalar*g;
        kProd.b = fScalar*b;
        kProd.a = fScalar*a;

        return kProd;
    }

    ColourValue opMul (/+ref+/ColourValue rhs)
    {
        ColourValue kProd;

        kProd.r = rhs.r * r;
        kProd.g = rhs.g * g;
        kProd.b = rhs.b * b;
        kProd.a = rhs.a * a;

        return kProd;
    }

    ColourValue opDiv (/+ref+/ColourValue rhs)
    {
        ColourValue kProd;

        kProd.r = r / rhs.r;
        kProd.g = g / rhs.g;
        kProd.b = b / rhs.b;
        kProd.a = a / rhs.a;

        return kProd;
    }

    ColourValue opDiv (float fScalar )
    {
        assert( fScalar != 0.0 );

        ColourValue kDiv;

        float fInv = 1.0f / fScalar;
        kDiv.r = r * fInv;
        kDiv.g = g * fInv;
        kDiv.b = b * fInv;
        kDiv.a = a * fInv;

        return kDiv;
    }

    //TODO opBinary("*")?
    /*friend ColourValue opMul (float fScalar,/+ref+/ColourValue rkVector )
    {
        ColourValue kProd;

        kProd.r = fScalar * rkVector.r;
        kProd.g = fScalar * rkVector.g;
        kProd.b = fScalar * rkVector.b;
        kProd.a = fScalar * rkVector.a;

        return kProd;
    }*/

    // arithmetic updates
    /+ref+/ColourValue opAddAssign (/+ref+/ColourValue rkVector )
    {
        r += rkVector.r;
        g += rkVector.g;
        b += rkVector.b;
        a += rkVector.a;

        return this;
    }

    /+ref+/ColourValue opSubAssign (/+ref+/ColourValue rkVector )
    {
        r -= rkVector.r;
        g -= rkVector.g;
        b -= rkVector.b;
        a -= rkVector.a;

        return this;
    }

    /+ref+/ColourValue opMulAssign (float fScalar )
    {
        r *= fScalar;
        g *= fScalar;
        b *= fScalar;
        a *= fScalar;
        return this;
    }

    /+ref+/ColourValue opDivAssign (float fScalar )
    {
        assert( fScalar != 0.0 );

        float fInv = 1.0f / fScalar;

        r *= fInv;
        g *= fInv;
        b *= fInv;
        a *= fInv;

        return this;
    }

    /** Set a colour value from Hue, Saturation and Brightness.
    @param hue Hue value, scaled to the [0,1] range as opposed to the 0-360
    @param saturation Saturation level, [0,1]
    @param brightness Brightness level, [0,1]
    */
    void setHSB(Real hue, Real saturation, Real brightness)
    {
        // wrap hue
        if (hue > 1.0f)
        {
            hue -= cast(int)hue;
        }
        else if (hue < 0.0f)
        {
            hue += cast(int)hue + 1;
        }
        // clamp saturation / brightness
        saturation = std.math.fmin(saturation, cast(Real)1.0);
        saturation = std.math.fmax(saturation, cast(Real)0.0);
        brightness = std.math.fmin(brightness, cast(Real)1.0);
        brightness = std.math.fmax(brightness, cast(Real)0.0);

        if (brightness == 0.0f)
        {   
            // early exit, this has to be black
            r = g = b = 0.0f;
            return;
        }

        if (saturation == 0.0f)
        {   
            // early exit, this has to be grey

            r = g = b = brightness;
            return;
        }


        Real hueDomain  = hue * 6.0f;
        if (hueDomain >= 6.0f)
        {
            // wrap around, and allow mathematical errors
            hueDomain = 0.0f;
        }
        ushort domain = cast(ushort)hueDomain;
        Real f1 = brightness * (1 - saturation);
        Real f2 = brightness * (1 - saturation * (hueDomain - domain));
        Real f3 = brightness * (1 - saturation * (1 - (hueDomain - domain)));

        switch (domain)
        {
        case 0:
            // red domain; green ascends
            r = brightness;
            g = f3;
            b = f1;
            break;
        case 1:
            // yellow domain; red descends
            r = f2;
            g = brightness;
            b = f1;
            break;
        case 2:
            // green domain; blue ascends
            r = f1;
            g = brightness;
            b = f3;
            break;
        case 3:
            // cyan domain; green descends
            r = f1;
            g = f2;
            b = brightness;
            break;
        case 4:
            // blue domain; red ascends
            r = f3;
            g = f1;
            b = brightness;
            break;
        case 5:
            // magenta domain; blue descends
            r = brightness;
            g = f1;
            b = f2;
            break;
        default:
            assert(0);
        }
    }
    /** Convert the current colour to Hue, Saturation and Brightness values. 
    @param hue Output hue value, scaled to the [0,1] range as opposed to the 0-360
    @param saturation Output saturation level, [0,1]
    @param brightness Output brightness level, [0,1]
    */
    void getHSB(Real* hue, Real* saturation, Real* brightness)
    {

        Real vMin = std.math.fmin(r, std.math.fmin(g, b));
        Real vMax = std.math.fmax(r, std.math.fmax(g, b));
        Real delta = vMax - vMin;

        *brightness = vMax;

        if (Math.RealEqual(delta, 0.0f, 1e-6))
        {
            // grey
            *hue = 0;
            *saturation = 0;
        }
        else                                    
        {
            // a colour
            *saturation = delta / vMax;

            Real deltaR = (((vMax - r) / 6.0f) + (delta / 2.0f)) / delta;
            Real deltaG = (((vMax - g) / 6.0f) + (delta / 2.0f)) / delta;
            Real deltaB = (((vMax - b) / 6.0f) + (delta / 2.0f)) / delta;

            if (Math.RealEqual(r, vMax))
                *hue = deltaB - deltaG;
            else if (Math.RealEqual(g, vMax))
                *hue = 0.3333333f + deltaR - deltaB;
            else if (Math.RealEqual(b, vMax)) 
                *hue = 0.6666667f + deltaG - deltaR;

            if (*hue < 0.0f) 
                *hue += 1.0f;
            if (*hue > 1.0f)
                *hue -= 1.0f;
        }

        
    }

    /** Function for writing to a stream.
    */
    string toString()
    {
        return "ColourValue(" 
                ~ std.conv.to!string(r) ~ ", " 
                ~ std.conv.to!string(g) ~ ", "
                ~ std.conv.to!string(b) ~ ", " 
                ~ std.conv.to!string(a) ~ ")";
    }

    unittest
    {
        ColourValue v0 = ColourValue(1f, 0.75f, 0.5f, 0.25f);
        version(BigEndian)
        {
            assert(v0.getAsABGR() == 0xffbf7f3f);
            assert(v0.getAsRGBA() == 0x3f7fbfff);
        }
        else
        {
            assert(v0.getAsABGR() == 0x3f7fbfff);
            assert(v0.getAsRGBA() == 0xffbf7f3f);
        }
        
        float h,s,b;
        v0.getHSB(&h,&s,&b);
        assert(s == 0.5f && b == 1f);
        assert(h - float.epsilon <= 0.0833334f && 0.0833334f <= h + float.epsilon);
    }
}
/** @} */
/** @} */
