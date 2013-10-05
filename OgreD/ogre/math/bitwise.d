module ogre.math.bitwise;
//import ogre.compat;
import core.exception;

/**
 *  WARNING: Preliminary conversion of C++ code to D so all bitwise ops may give utterly wrong results.
 */

/** \addtogroup Core
*  @{
*/
/** \addtogroup Math
*  @{
*/

class Bitwise
{
    /** Returns the most significant bit set in a value.
    */
    static uint mostSignificantBitSet(uint value)
    {
        uint result = 0;
        while (value != 0) {
            ++result;
            value >>= 1;
        }
        return result-1;
    }
    /** Returns the closest power-of-two number greater or equal to value.
        @note 0 and 1 are powers of two, so
            firstPO2From(0)==0 and firstPO2From(1)==1.
    */
    static uint firstPO2From(uint n)
    {
        --n;
        n |= n >> 16;
        n |= n >> 8;
        n |= n >> 4;
        n |= n >> 2;
        n |= n >> 1;
        ++n;
        return n;
    }

    /** Determines whether the number is power-of-two or not.
    @note 0 and 1 are tread as power of two.
    */
    static bool isPO2(T)(T n)
    {
        return (n & (n-1)) == 0;
    }

    static uint getBitShift(T)(T mask)
    {
        if (mask == 0)
            return 0;

        uint result = 0;
        while ((mask & 1) == 0) {
            ++result;
            mask >>= 1;
        }
        return result;
    }

    /** Takes a value with a given src bit mask, and produces another
        value with a desired bit mask.
        @remarks
            This routine is useful for colour conversion.
    */
    static DestT convertBitPattern(SrcT, DestT)(SrcT srcValue, SrcT srcBitMask, DestT destBitMask)
    {
        // Mask off irrelevant source value bits (if any)
        srcValue = srcValue & srcBitMask;

        // Shift source down to bottom of DWORD
       uint srcBitShift = getBitShift(srcBitMask);
        srcValue >>= srcBitShift;

        // Get max value possible in source from srcMask
       SrcT srcMax = srcBitMask >> srcBitShift;

        // Get max available in dest
       uint destBitShift = getBitShift(destBitMask);
       DestT destMax = destBitMask >> destBitShift;

        // Scale source value into destination, and shift back
        DestT destValue = (srcValue * destMax) / srcMax;
        return (destValue << destBitShift);
    }


    /**
     * Convert N bit colour channel value to P bits. It fills P bits with the
     * bit pattern repeated. (this is /((1<<n)-1) in fixed point)
     */
    static uint fixedToFixed(uint value, uint n, uint p)
    {
        if(n > p)
        {
            // Less bits required than available; this is easy
            value >>= n-p;
        }
        else if(n < p)
        {
            // More bits required than are there, do the fill
            // Use old fashioned division, probably better than a loop
            if(value == 0)
                    value = 0;
            else if(value == (cast(uint)(1)<<n)-1)
                    value = (1<<p)-1;
            else    value = value*(1<<p)/((1<<n)-1);
        }
        return value;
    }

    /**
     * Convert floating point colour channel value between 0.0 and 1.0 (otherwise clamped)
     * to integer of a certain number of bits. Works for any value of bits between 0 and 31.
     */
    static uint floatToFixed(float value,uint bits)
    {
        if(value <= 0.0f) return 0;
        else if (value >= 1.0f) return (1<<bits)-1;
        else return cast(uint)(value * (1<<bits));
    }

    /**
     * Fixed point to float
     */
    static float fixedToFloat(/+unsigned+/ uint value, uint bits)
    {
        return cast(float)value/cast(float)((1<<bits)-1);
    }

    /**
     * Write a n*8 bits integer value to memory in native endian.
     */
    static void intWrite(void *dest,int n,uint value)
    {
        switch(n) {
            case 1:
                (cast(ubyte*)dest)[0] = cast(ubyte)value;
                break;
            case 2:
                (cast(ushort*)dest)[0] = cast(ushort)value;
                break;
            case 3:
                version (BigEndian)
                {
                    (cast(ubyte*)dest)[0] = cast(ubyte)((value >> 16) & 0xFF);
                    (cast(ubyte*)dest)[1] = cast(ubyte)((value >> 8) & 0xFF);
                    (cast(ubyte*)dest)[2] = cast(ubyte)(value & 0xFF);
                }
                else
                {
                    (cast(ubyte*)dest)[2] = cast(ubyte)((value >> 16) & 0xFF);
                    (cast(ubyte*)dest)[1] = cast(ubyte)((value >> 8) & 0xFF);
                    (cast(ubyte*)dest)[0] = cast(ubyte)(value & 0xFF);
                }
                break;
            case 4:
                (cast(uint*)dest)[0] = cast(uint)value;
                break;
            default:
                //assert(0); // case not supported
                onSwitchError();
                break;
        }
    }

    /**
     * Read a n*8 bits integer value to memory in native endian.
     */
    static uint intRead(void *src, int n) {
        switch(n) {
            case 1:
                return (cast(ubyte*)src)[0];
            case 2:
                return (cast(ushort*)src)[0];
            case 3:
                version (BigEndian) //core.bitop.bswap
                {
                    return (cast(uint)(cast(ubyte*)src)[0]<<16)|
                            (cast(uint)(cast(ubyte*)src)[1]<<8)|
                            (cast(uint)(cast(ubyte*)src)[2]);
                }
                else
                {
                    return (cast(uint)(cast(ubyte*)src)[0])|
                            (cast(uint)(cast(ubyte*)src)[1]<<8)|
                            (cast(uint)(cast(ubyte*)src)[2]<<16);
                }
            case 4:
                return (cast(uint*)src)[0];
            default:
                //assert(0); // case not supported
                onSwitchError();
                break;
        } 
        return 0; // ?
    }

    /** Convert a float32 to a float16 (NV_half_float)
     *  Courtesy of OpenEXR
     */
    static ushort floatToHalf(float i)
    {
        union V { float f; uint i; };
        V v;
        v.f = i;
        return floatToHalfI(v.i);
    }
    
    /** Converts float in uint format to a a half in ushort format
    */
    static ushort floatToHalfI(uint i)
    {
        int s =  (i >> 16) & 0x00008000;
        int e = ((i >> 23) & 0x000000ff) - (127 - 15);
        int m =   i        & 0x007fffff;
    
        if (e <= 0)
        {
            if (e < -10)
            {
                return 0;
            }
            m = (m | 0x00800000) >> (1 - e);
    
            return cast(ushort)(s | (m >> 13));
        }
        else if (e == 0xff - (127 - 15))
        {
            if (m == 0) // Inf
            {
                return cast(ushort)(s | 0x7c00);
            } 
            else    // NAN
            {
                m >>= 13;
                return cast(ushort)(s | 0x7c00 | m | (m == 0));
            }
        }
        else
        {
            if (e > 30) // Overflow
            {
                return cast(ushort)(s | 0x7c00);
            }
    
            return cast(ushort)(s | (e << 10) | (m >> 13));
        }
    }
    
    /**
     * Convert a float16 (NV_half_float) to a float32
     * Courtesy of OpenEXR
     */
    static float halfToFloat(ushort y)
    {
        union V { float f; uint i; };
        V v;
        v.i = halfToFloatI(y);
        return v.f;
    }
    /** Converts a half in ushort format to a float
         in uint format
     */
    static uint halfToFloatI(ushort y)
    {
        int s = (y >> 15) & 0x00000001;
        int e = (y >> 10) & 0x0000001f;
        int m =  y        & 0x000003ff;
    
        if (e == 0)
        {
            if (m == 0) // Plus or minus zero
            {
                return s << 31;
            }
            else // Denormalized number -- renormalize it
            {
                while (!(m & 0x00000400))
                {
                    m <<= 1;
                    e -=  1;
                }
    
                e += 1;
                m &= ~0x00000400;
            }
        }
        else if (e == 31)
        {
            if (m == 0) // Inf
            {
                return (s << 31) | 0x7f800000;
            }
            else // NaN
            {
                return (s << 31) | 0x7f800000 | (m << 13);
            }
        }
    
        e = e + (127 - 15);
        m = m << 13;
    
        return (s << 31) | (e << 23) | m;
    }
    
    unittest
    {
        import std.math;
        //assert(fixedToFloat(128, 8) == 0.501961); //Ofcourse because floats etc -> fail
        assert(std.math.floor(fixedToFloat(128, 8)*10) == 5.0); //FIXME
        assert(isPO2!int(8) == true);
        assert(isPO2!int(7) == false);
        assert(isPO2!uint(3) == false);
        assert(isPO2!byte(32) == true);
    }
}

/** @} */
/** @} */