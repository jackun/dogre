module ogre.math.maths;

import std.math;
import std.random;
//import std.container;
import std.algorithm;

import ogre.compat;
import ogre.math.axisalignedbox;
import ogre.math.ray;
import ogre.math.vector;
import ogre.math.matrix;
import ogre.math.quaternion;
import ogre.math.plane;
import ogre.math.sphere;
import ogre.math.angles;

/** @todo check that ops are logical.*/

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Math
 *  @{
 */

/** Wrapper class which identifies a value as the currently default angle
 type, as defined by Math.setAngleUnit.
 @remarks
 Angle values will be automatically converted between radians and degrees,
 as appropriate.
 */
struct Angle
{
    Real mAngle;
public:
    this ( Real angle ) { mAngle = angle; }
    Radian toRadian()
    {
        return Radian(Math.AngleUnitsToRadians(mAngle));
    }
    Degree toDegree()
    {
        return Degree(Math.AngleUnitsToDegrees(mAngle));
    }
}


/** Class to provide access to common mathematical functions.
 @remarks
 Most of the maths functions are aliased versions of the C runtime
 library functions. They are aliased here to provide future
 optimisation opportunities, either from faster RTLs or custom
 math approximations.
 @note
 <br>This is based on MgcMath.h from
 <a href="http://www.geometrictools.com/">Wild Magic</a>.
 */
class Math
{
public:
    /** The angular units used by the API. This functionality is now deprecated in favor
     of discreet angular unit types ( see Degree and Radian above ). The only place
     this functionality is actually still used is when parsing files. Search for
     usage of the Angle class for those instances
     */
    static enum AngleUnit
    {
        AU_DEGREE,
        AU_RADIAN
    }

    enum Real POS_INFINITY = Real.infinity; //std.numeric_limits<Real>.infinity();
    enum Real NEG_INFINITY = -Real.infinity;//-std.numeric_limits<Real>.infinity();
    /**
     * Because CFTE errors, initialize in constructor.
     * D fails at CTFE. Let us help. */
    enum Real PI = 3.141592741013f; //Real( 4.0 * atanf( 1.0f ) );
    enum Real TWO_PI = cast(Real)( 2.0 * PI );
    enum Real HALF_PI = cast(Real)( 0.5 * PI );
    enum Real fDeg2Rad = PI / cast(Real)(180.0);
    enum Real fRad2Deg = cast(Real)(180.0) / PI;
    /** D fails at CTFE. Let us help. */
    /// Stored value of log(2) for frequent use
    enum Real LOG2 = 0.693147180560f;//log(cast(Real)(2.0));

    

    /** This class is used to provide an external random value provider.
     */
    interface RandomValueProvider
    {
        /** When called should return a random values in the range of [0,1] */
        Real getRandomUnit();
    }

protected:
    // angle units used by the api
    static AngleUnit msAngleUnit;

    /// Size of the trig tables as determined by constructor.
    static int mTrigTableSize;

    /// Radian . index factor value ( mTrigTableSize / 2 * PI )
    static Real mTrigTableFactor;
    static Real[] mSinTable;
    static Real[] mTanTable;

    // A random value provider. overriding the default random number generator.
    static RandomValueProvider mRandProvider = null;

    /** Private function to build trig tables.
     */
    void buildTrigTables()
    {
        // Build trig lookup tables
        // Could get away with building only PI sized Sin table but simpler this
        // way. Who cares, it'll ony use an extra 8k of memory anyway and I like
        // simplicity.
        Real angle;
        for (int i = 0; i < mTrigTableSize; ++i)
        {
            angle = TWO_PI * i / mTrigTableSize;
            mSinTable[i] = sin(angle);
            mTanTable[i] = tan(angle);
        }
    }

    static Real SinTable (Real fValue)
    {
        // Convert range to index values, wrap if required
        int idx;
        if (fValue >= 0)
        {
            idx = cast(int)(fValue * mTrigTableFactor) % mTrigTableSize;
        }
        else
        {
            idx = mTrigTableSize - (cast(int)(-fValue * mTrigTableFactor) % mTrigTableSize) - 1;
        }

        return mSinTable[idx];
    }

    static Real TanTable (Real fValue)
    {
        // Convert range to index values, wrap if required
        int idx = cast(int)(fValue *= mTrigTableFactor) % mTrigTableSize;
        return mTanTable[idx];
    }

public:
    /** Default constructor.
     @param
     trigTableSize Optional parameter to set the size of the
     tables used to implement Sin, Cos, Tan
     */
    //this(){ this(4096); }
    this(uint trigTableSize = 4096)
    {
        /+PI = Real( 4.0 * atan( 1.0 ) );
         TWO_PI = Real( 2.0 * PI );
         HALF_PI = Real( 0.5 * PI );
         fDeg2Rad = PI / Real(180.0);
         fRad2Deg = Real(180.0) / PI;
         LOG2 = log(Real(2.0));+/
        msAngleUnit = AngleUnit.AU_DEGREE;
        mTrigTableSize = trigTableSize;
        mTrigTableFactor = mTrigTableSize / TWO_PI;

        mSinTable = new Real[mTrigTableSize]; //OGRE_ALLOC_T(Real, mTrigTableSize, MEMCATEGORY_GENERAL);
        mTanTable = new Real[mTrigTableSize]; //OGRE_ALLOC_T(Real, mTrigTableSize, MEMCATEGORY_GENERAL);

        buildTrigTables();
    }

    /** Default destructor.
     */
    ~this(){}

    static int IAbs (int iValue) { return ( iValue >= 0 ? iValue : -iValue ); }
    static int ICeil (float fValue) { return cast(int)(ceil(fValue)); }
    static int IFloor (float fValue) { return cast(int)(floor(fValue)); }
    static int ISign (int iValue)
    {
        return ( iValue > 0 ? +1 : ( iValue < 0 ? -1 : 0 ) );
    }

    /** Absolute value function
     @param
     fValue The value whose absolute value will be returned.
     */
    static Real Abs (Real fValue) { return abs(fValue); }

    /** Absolute value function
     @param dValue
     The value, in degrees, whose absolute value will be returned.
     */
    static Degree Abs (Degree dValue) { return Degree(abs(dValue.valueDegrees())); }

    /** Absolute value function
     @param rValue
     The value, in radians, whose absolute value will be returned.
     */
    static Radian Abs (Radian rValue) { return Radian(abs(rValue.valueRadians())); }

    /** Arc cosine function
     @param fValue
     The value whose arc cosine will be returned.
     */
    static Radian ACos (Real fValue)
    {
        if ( -1.0 < fValue )
        {
            if ( fValue < 1.0 )
                return Radian(acos(fValue));
            else
                return Radian(0.0);
        }
        else
        {
            return Radian(PI);
        }
    }

    /** Arc sine function
     @param fValue
     The value whose arc sine will be returned.
     */
    static Radian ASin (Real fValue)
    {
        if ( -1.0 < fValue )
        {
            if ( fValue < 1.0 )
                return Radian(asin(fValue));
            else
                return Radian(HALF_PI);
        }
        else
        {
            return Radian(-HALF_PI);
        }
    }

    /** Arc tangent function
     @param fValue
     The value whose arc tangent will be returned.
     */
    static Radian ATan (Real fValue) { return Radian(atan(fValue)); }

    /** Arc tangent between two values function
     @param fY
     The first value to calculate the arc tangent with.
     @param fX
     The second value to calculate the arc tangent with.
     */
    static Radian ATan2 (Real fY, Real fX) { return Radian(atan2(fY,fX)); }

    /** Ceiling function
     Returns the smallest following integer. (example: Ceil(1.1) = 2)

     @param fValue
     The value to round up to the nearest integer.
     */
    static Real Ceil (Real fValue) { return cast(Real)(ceil(fValue)); }

    /**@todo Replace with D's isNan().*/
    static bool isNaN(Real f)
    {
        // std.isnan() is C99, not supported by all compilers
        // However NaN always fails this next test, no other number does.
        
        //return f != f;
        return (f !<>= 0.0);
        //return std.math.isnan(f);
    }
    /** Cosine function.
     @param fValue
     Angle in radians
     @param useTables
     If true, uses lookup tables rather than
     calculation - faster but less accurate.
     */
    static Real Cos (Radian fValue, bool useTables = false) {
        return (!useTables) ? cast(Real)(cos(fValue.valueRadians())) : SinTable(fValue.valueRadians() + HALF_PI);
    }
    /** Cosine function.
     @param fValue
     Angle in radians
     @param useTables
     If true, uses lookup tables rather than
     calculation - faster but less accurate.
     */
    static Real Cos (Real fValue, bool useTables = false) {
        return (!useTables) ? cast(Real)(cos(fValue)) : SinTable(fValue + HALF_PI);
    }

    static Real Exp (Real fValue) { return cast(Real)(exp(fValue)); }

    /** Floor function
     Returns the largest previous integer. (example: Floor(1.9) = 1)

     @param fValue
     The value to round down to the nearest integer.
     */
    static Real Floor (Real fValue) { return cast(Real)(floor(fValue)); }

    static Real Log (Real fValue) { return cast(Real)log(fValue); }

    static Real Log2 (Real fValue) { return cast(Real)(log(fValue)/LOG2); }

    static Real LogN (Real base, Real fValue) { return cast(Real)(log(fValue)/log(base)); }

    static Real Pow (Real fBase, Real fExponent) { return cast(Real)(pow(fBase,fExponent)); }

    static Real Sign (Real fValue)
    {
        if ( fValue > 0.0 )
            return 1.0;

        if ( fValue < 0.0 )
            return -1.0;

        return 0.0;
    }

    static Radian Sign (Radian rValue )
    {
        return Radian(Sign(rValue.valueRadians()));
    }
    static Degree Sign (Degree dValue )
    {
        return Degree(Sign(dValue.valueDegrees()));
    }

    //Simulate the shader function saturate that clamps a parameter value between 0 and 1
    static float saturate(float t) { return (t < 0) ? 0 : ((t > 1) ? 1 : t); }
    static double saturate(double t) { return (t < 0) ? 0 : ((t > 1) ? 1 : t); }

    //Simulate the shader function lerp which performers linear interpolation
    //given 3 parameters v0, v1 and t the function returns the value of (1  t)* v0 + t * v1.
    //where v0 and v1 are matching vector or scalar types and t can be either a scalar or a vector of the same type as a and b.
    /*template Tlerp(V, T) {
     static V lerp(V v0,V v1,T t) {
     return v0 * (1 - t) + v1 * t;
     }
     }*/

    /** Sine function.
     @param fValue
     Angle in radians
     @param useTables
     If true, uses lookup tables rather than
     calculation - faster but less accurate.
     */
    static Real Sin (Radian fValue, bool useTables = false) {
        return (!useTables) ? cast(Real)(sin(fValue.valueRadians())) : SinTable(fValue.valueRadians());
    }
    /** Sine function.
     @param fValue
     Angle in radians
     @param useTables
     If true, uses lookup tables rather than
     calculation - faster but less accurate.
     */
    static Real Sin (Real fValue, bool useTables = false) {
        return (!useTables) ? cast(Real)(sin(fValue)) : SinTable(fValue);
    }

    /** Squared function.
     @param fValue
     The value to be squared (fValue^2)
     */
    static Real Sqr (Real fValue) { return fValue*fValue; }

    /** Square root function.
     @param fValue
     The value whose square root will be calculated.
     */
    static Real Sqrt (Real fValue) { return cast(Real)(sqrt(fValue)); }

    /** Square root function.
     @param fValue
     The value, in radians, whose square root will be calculated.
     @return
     The square root of the angle in radians.
     */
    static Radian Sqrt (Radian fValue) { return Radian(sqrt(fValue.valueRadians())); }

    /** Square root function.
     @param fValue
     The value, in degrees, whose square root will be calculated.
     @return
     The square root of the angle in degrees.
     */
    static Degree Sqrt (Degree fValue) { return Degree(sqrt(fValue.valueDegrees())); }

    /** Inverse square root i.e. 1 / Sqrt(x), good for vector
     normalisation.
     @todo Unoptimized native D version.
     @param fValue
     The value whose inverse square root will be calculated.
     */
    static Real InvSqrt (Real fValue)
    {
        return cast(Real)1.0 / sqrt(fValue);//asm_rsq(fValue);
    }

    /** Generate a random number of unit length.
     * @note
     *         Currently lacking generic implementation.
     @return
     A random number in the range from [0,1].
     */
    static Real UnitRandom ()
    {
        if (mRandProvider)
            return mRandProvider.getRandomUnit();
        //else return asm_rand() / asm_rand_max(); // TODO
        else return uniform(cast(Real)0.0, cast(Real)1.0);
    }

    /** Generate a random number within the range provided.
     @param fLow
     The lower bound of the range.
     @param fHigh
     The upper bound of the range.
     @return
     A random number in the range from [fLow,fHigh].
     */
    static Real RangeRandom (Real fLow, Real fHigh)
    {
        return (fHigh-fLow)*UnitRandom() + fLow;
    }

    /** Generate a random number in the range [-1,1].
     @return
     A random number in the range from [-1,1].
     */
    static Real SymmetricRandom ()
    {
        return 2.0f * UnitRandom() - 1.0f;
    }

    static void SetRandomValueProvider(ref RandomValueProvider provider)
    {
        mRandProvider = provider;
    }
    /** Tangent function.
     @param fValue
     Angle in radians
     @param useTables
     If true, uses lookup tables rather than
     calculation - faster but less accurate.
     */
    static Real Tan (Radian fValue, bool useTables = false) {
        return (!useTables) ? cast(Real)(tan(fValue.valueRadians())) : TanTable(fValue.valueRadians());
    }
    /** Tangent function.
     @param fValue
     Angle in radians
     @param useTables
     If true, uses lookup tables rather than
     calculation - faster but less accurate.
     */
    static Real Tan (Real fValue, bool useTables = false) {
        return (!useTables) ? cast(Real)(tan(fValue)) : TanTable(fValue);
    }

    static Real DegreesToRadians(Real degrees) { return degrees * fDeg2Rad; }
    static Real RadiansToDegrees(Real radians) { return radians * fRad2Deg; }

    /** These functions used to set the assumed angle units (radians or degrees)
     expected when using the Angle type.
     @par
     You can set this directly after creating a new Root, and also before/after resource creation,
     depending on whether you want the change to affect resource files.
     */
    static void setAngleUnit(AngleUnit unit) { msAngleUnit = unit; }
    /** Get the unit being used for angles. */
    static AngleUnit getAngleUnit() { return msAngleUnit; }

    /** Convert from the current AngleUnit to radians. */
    static Real AngleUnitsToRadians(Real angleunits)
    {
        if (msAngleUnit == AngleUnit.AU_DEGREE)
            return angleunits * fDeg2Rad;
        else
            return angleunits;
    }
    /** Convert from radians to the current AngleUnit . */
    static Real RadiansToAngleUnits(Real radians)
    {
        if (msAngleUnit == AngleUnit.AU_DEGREE)
            return radians * fRad2Deg;
        else
            return radians;
    }
    /** Convert from the current AngleUnit to degrees. */
    static Real AngleUnitsToDegrees(Real angleunits)
    {
        if (msAngleUnit == AngleUnit.AU_RADIAN)
            return angleunits * fRad2Deg;
        else
            return angleunits;
    }
    /** Convert from degrees to the current AngleUnit. */
    static Real DegreesToAngleUnits(Real degrees)
    {
        if (msAngleUnit == AngleUnit.AU_RADIAN)
            return degrees * fDeg2Rad;
        else
            return degrees;
    }

    /** Checks whether a given point is inside a triangle, in a
     2-dimensional (Cartesian) space.
     @remarks
     The vertices of the triangle must be given in either
     trigonometrical (anticlockwise) or inverse trigonometrical
     (clockwise) order.
     @param p
     The point.
     @param a
     The triangle's first vertex.
     @param b
     The triangle's second vertex.
     @param c
     The triangle's third vertex.
     @return
     If the point resides in the triangle, <b>true</b> is
     returned.
     @par
     If the point is outside the triangle, <b>false</b> is
     returned.
     */
    static bool pointInTri2D(Vector2 p,Vector2 a,
                             Vector2 b,Vector2 c)
    {
        // Winding must be consistent from all edges for point to be inside
        Vector2 v1, v2;
        Real dot[3];
        bool zeroDot[3];

        v1 = b - a;
        v2 = p - a;

        // Note we don't care about normalisation here since sign is all we need
        // It means we don't have to worry about magnitude of cross products either
        dot[0] = v1.crossProduct(v2);
        zeroDot[0] = RealEqual(dot[0], 0.0f, 1e-3);

        
        v1 = c - b;
        v2 = p - b;

        dot[1] = v1.crossProduct(v2);
        zeroDot[1] = RealEqual(dot[1], 0.0f, 1e-3);

        // Compare signs (ignore colinear / coincident points)
        if(!zeroDot[0] && !zeroDot[1]
           && Sign(dot[0]) != Sign(dot[1]))
        {
            return false;
        }

        v1 = a - c;
        v2 = p - c;

        dot[2] = v1.crossProduct(v2);
        zeroDot[2] = RealEqual(dot[2], 0.0f, 1e-3);
        // Compare signs (ignore colinear / coincident points)
        if((!zeroDot[0] && !zeroDot[2]
            && Sign(dot[0]) != Sign(dot[2])) ||
           (!zeroDot[1] && !zeroDot[2]
         && Sign(dot[1]) != Sign(dot[2])))
        {
            return false;
        }

        
        return true;
    }

    /** Checks whether a given 3D point is inside a triangle.
     @remarks
     The vertices of the triangle must be given in either
     trigonometrical (anticlockwise) or inverse trigonometrical
     (clockwise) order, and the point must be guaranteed to be in the
     same plane as the triangle
     @param p
     p The point.
     @param a
     The triangle's first vertex.
     @param b
     The triangle's second vertex.
     @param c
     The triangle's third vertex.
     @param normal
     The triangle plane's normal (passed in rather than calculated
     on demand since the caller may already have it)
     @return
     If the point resides in the triangle, <b>true</b> is
     returned.
     @par
     If the point is outside the triangle, <b>false</b> is
     returned.
     */
    static bool pointInTri3D(ref Vector3 p,ref Vector3 a,
                             ref Vector3 b,ref Vector3 c,ref Vector3 normal)
    {
        // Winding must be consistent from all edges for point to be inside
        Vector3 v1, v2;
        Real dot[3];
        bool zeroDot[3];

        v1 = b - a;
        v2 = p - a;

        // Note we don't care about normalisation here since sign is all we need
        // It means we don't have to worry about magnitude of cross products either
        dot[0] = v1.crossProduct(v2).dotProduct(normal);
        zeroDot[0] = RealEqual(dot[0], 0.0f, 1e-3);

        
        v1 = c - b;
        v2 = p - b;

        dot[1] = v1.crossProduct(v2).dotProduct(normal);
        zeroDot[1] = RealEqual(dot[1], 0.0f, 1e-3);

        // Compare signs (ignore colinear / coincident points)
        if(!zeroDot[0] && !zeroDot[1]
           && Sign(dot[0]) != Sign(dot[1]))
        {
            return false;
        }

        v1 = a - c;
        v2 = p - c;

        dot[2] = v1.crossProduct(v2).dotProduct(normal);
        zeroDot[2] = RealEqual(dot[2], 0.0f, 1e-3);
        // Compare signs (ignore colinear / coincident points)
        if((!zeroDot[0] && !zeroDot[2]
            && Sign(dot[0]) != Sign(dot[2])) ||
           (!zeroDot[1] && !zeroDot[2]
         && Sign(dot[1]) != Sign(dot[2])))
        {
            return false;
        }

        
        return true;
    }
    /** Ray / plane intersection, returns boolean result and distance. */
    static pair!(bool, Real) intersects(Ray ray,Plane plane)
    {
        Real denom = plane.normal.dotProduct(ray.getDirection());
        if (Abs(denom) < Real.epsilon)
        {
            // Parallel
            return pair!(bool, Real)(false, cast(Real)0);
        }
        else
        {
            Real nom = plane.normal.dotProduct(ray.getOrigin()) + plane.d;
            Real t = -(nom/denom);
            return pair!(bool, Real)(t >= 0, cast(Real)t);
        }
    }

    /** Ray / sphere intersection, returns boolean result and distance. */
    static pair!(bool, Real) intersects(Ray ray,Sphere sphere,
                                        bool discardInside = true)
    {
        Vector3 raydir = ray.getDirection();
        // Adjust ray origin relative to sphere center
        Vector3 rayorig = ray.getOrigin() - sphere.getCenter();
        Real radius = sphere.getRadius();

        // Check origin inside first
        if (rayorig.squaredLength() <= radius*radius && discardInside)
        {
            return pair!(bool, Real)(true, cast(Real)0);
        }

        // Mmm, quadratics
        // Build coeffs which can be used with std quadratic solver
        // ie t = (-b +/- sqrt(b*b + 4ac)) / 2a
        Real a = raydir.dotProduct(raydir);
        Real b = 2 * rayorig.dotProduct(raydir);
        Real c = rayorig.dotProduct(rayorig) - radius*radius;

        // Calc determinant
        Real d = (b*b) - (4 * a * c);
        if (d < 0)
        {
            // No intersection
            return pair!(bool, Real)(false, cast(Real)0);
        }
        else
        {
            // BTW, if d=0 there is one intersection, if d > 0 there are 2
            // But we only want the closest one, so that's ok, just use the 
            // '-' version of the solver
            Real t = ( -b - Sqrt(d) ) / (2 * a);
            if (t < 0)
                t = ( -b + Sqrt(d) ) / (2 * a);
            return pair!(bool, Real)(true, cast(Real)t);
        }
    }

    /** Ray / box intersection, returns boolean result and distance. */
    static pair!(bool, Real) intersects(Ray ray,AxisAlignedBox box)
    {
        if (box.isNull()) return pair!(bool, Real)(false, cast(Real)0);
        if (box.isInfinite()) return pair!(bool, Real)(true, cast(Real)0);

        Real lowt = 0.0f;
        Real t;
        bool hit = false;
        Vector3 hitpoint;
        Vector3 min = box.getMinimum();
        Vector3 max = box.getMaximum();
        Vector3 rayorig = ray.getOrigin();
        Vector3 raydir = ray.getDirection();

        // Check origin inside first
        if ( rayorig.opGreaterThan(min) && rayorig.opLessThan(max) )
        {
            return pair!(bool, Real)(true, cast(Real)0);
        }

        // Check each face in turn, only check closest 3
        // Min x
        if (rayorig.x <= min.x && raydir.x > 0)
        {
            t = (min.x - rayorig.x) / raydir.x;
            if (t >= 0)
            {
                // Substitute t back into ray and check bounds and dist
                hitpoint = rayorig + raydir * t;
                if (hitpoint.y >= min.y && hitpoint.y <= max.y &&
                    hitpoint.z >= min.z && hitpoint.z <= max.z &&
                    (!hit || t < lowt))
                {
                    hit = true;
                    lowt = t;
                }
            }
        }
        // Max x
        if (rayorig.x >= max.x && raydir.x < 0)
        {
            t = (max.x - rayorig.x) / raydir.x;
            if (t >= 0)
            {
                // Substitute t back into ray and check bounds and dist
                hitpoint = rayorig + raydir * t;
                if (hitpoint.y >= min.y && hitpoint.y <= max.y &&
                    hitpoint.z >= min.z && hitpoint.z <= max.z &&
                    (!hit || t < lowt))
                {
                    hit = true;
                    lowt = t;
                }
            }
        }
        // Min y
        if (rayorig.y <= min.y && raydir.y > 0)
        {
            t = (min.y - rayorig.y) / raydir.y;
            if (t >= 0)
            {
                // Substitute t back into ray and check bounds and dist
                hitpoint = rayorig + raydir * t;
                if (hitpoint.x >= min.x && hitpoint.x <= max.x &&
                    hitpoint.z >= min.z && hitpoint.z <= max.z &&
                    (!hit || t < lowt))
                {
                    hit = true;
                    lowt = t;
                }
            }
        }
        // Max y
        if (rayorig.y >= max.y && raydir.y < 0)
        {
            t = (max.y - rayorig.y) / raydir.y;
            if (t >= 0)
            {
                // Substitute t back into ray and check bounds and dist
                hitpoint = rayorig + raydir * t;
                if (hitpoint.x >= min.x && hitpoint.x <= max.x &&
                    hitpoint.z >= min.z && hitpoint.z <= max.z &&
                    (!hit || t < lowt))
                {
                    hit = true;
                    lowt = t;
                }
            }
        }
        // Min z
        if (rayorig.z <= min.z && raydir.z > 0)
        {
            t = (min.z - rayorig.z) / raydir.z;
            if (t >= 0)
            {
                // Substitute t back into ray and check bounds and dist
                hitpoint = rayorig + raydir * t;
                if (hitpoint.x >= min.x && hitpoint.x <= max.x &&
                    hitpoint.y >= min.y && hitpoint.y <= max.y &&
                    (!hit || t < lowt))
                {
                    hit = true;
                    lowt = t;
                }
            }
        }
        // Max z
        if (rayorig.z >= max.z && raydir.z < 0)
        {
            t = (max.z - rayorig.z) / raydir.z;
            if (t >= 0)
            {
                // Substitute t back into ray and check bounds and dist
                hitpoint = rayorig + raydir * t;
                if (hitpoint.x >= min.x && hitpoint.x <= max.x &&
                    hitpoint.y >= min.y && hitpoint.y <= max.y &&
                    (!hit || t < lowt))
                {
                    hit = true;
                    lowt = t;
                }
            }
        }

        return pair!(bool, Real)(hit, cast(Real)lowt);

    }

    /** Ray / box intersection, returns boolean result and two intersection distance.
     @param ray
     The ray.
     @param box
     The box.
     @param d1
     A real pointer to retrieve the near intersection distance
     from the ray origin, maybe <b>null</b> which means don't care
     about the near intersection distance.
     @param d2
     A real pointer to retrieve the far intersection distance
     from the ray origin, maybe <b>null</b> which means don't care
     about the far intersection distance.
     @return
     If the ray is intersects the box, <b>true</b> is returned, and
     the near intersection distance is return by <i>d1</i>, the
     far intersection distance is return by <i>d2</i>. Guarantee
     <b>0</b> <= <i>d1</i> <= <i>d2</i>.
     @par
     If the ray isn't intersects the box, <b>false</b> is returned, and
     <i>d1</i> and <i>d2</i> is unmodified.
     @todo return in macro
     */
    static bool intersects(ref Ray ray, AxisAlignedBox box,
                           ref Real d1, ref Real d2)
    {
        if (box.isNull())
            return false;

        if (box.isInfinite())
        {
            d1 = 0;
            d2 = POS_INFINITY;
            return true;
        }

        Vector3 min = box.getMinimum();
        Vector3 max = box.getMaximum();
        Vector3 rayorig = ray.getOrigin();
        Vector3 raydir = ray.getDirection();

        Vector3 absDir;
        absDir[0] = Abs(raydir[0]);
        absDir[1] = Abs(raydir[1]);
        absDir[2] = Abs(raydir[2]);

        // Sort the axis, ensure check minimise floating error axis first
        int imax = 0, imid = 1, imin = 2;
        if (absDir[0] < absDir[2])
        {
            imax = 2;
            imin = 0;
        }
        if (absDir[1] < absDir[imin])
        {
            imid = imin;
            imin = 1;
        }
        else if (absDir[1] > absDir[imax])
        {
            imid = imax;
            imax = 1;
        }

        Real start = 0, end = POS_INFINITY;

        /+ nested function replacing the macro +/
        bool _CALC_AXIS(int i)
        {
            Real denom = 1 / raydir[i];
            Real newstart = (min[i] - rayorig[i]) * denom;
            Real newend = (max[i] - rayorig[i]) * denom;
            if (newstart > newend) std.algorithm.swap(newstart, newend);
            if (newstart > end || newend < start) return false; /** @todo return in macro*/
            if (newstart > start) start = newstart;
            if (newend < end) end = newend;
            return true;
        }

        // Check each axis in turn

        if(!_CALC_AXIS(imax)) return false;

        if (absDir[imid] < Real.epsilon)
        {
            // Parallel with middle and minimise axis, check bounds only
            if (rayorig[imid] < min[imid] || rayorig[imid] > max[imid] ||
                rayorig[imin] < min[imin] || rayorig[imin] > max[imin])
                return false;
        }
        else
        {
            if(!_CALC_AXIS(imid)) return false;

            if (absDir[imin] < Real.epsilon)
            {
                // Parallel with minimise axis, check bounds only
                if (rayorig[imin] < min[imin] || rayorig[imin] > max[imin])
                    return false;
            }
            else
            {
                if(!_CALC_AXIS(imin)) return false;
            }
        }

        d1 = start; //TODO was pointery stuff in C++
        d2 = end;

        return true;
    }

    /** Ray / triangle intersection, returns boolean result and distance.
     @param ray
     The ray.
     @param a
     The triangle's first vertex.
     @param b
     The triangle's second vertex.
     @param c
     The triangle's third vertex.
     @param normal
     The triangle plane's normal (passed in rather than calculated
     on demand since the caller may already have it), doesn't need
     normalised since we don't care.
     @param positiveSide
     Intersect with "positive side" of the triangle
     @param negativeSide
     Intersect with "negative side" of the triangle
     @return
     If the ray is intersects the triangle, a pair of <b>true</b> and the
     distance between intersection point and ray origin returned.
     @par
     If the ray isn't intersects the triangle, a pair of <b>false</b> and
     <b>0</b> returned.
     */
    static pair!(bool, Real) intersects(ref Ray ray,ref Vector3 a,
                                        ref Vector3 b,ref Vector3 c,ref Vector3 normal,
                                        bool positiveSide = true, bool negativeSide = true)
    {
        //
        // Calculate intersection with plane.
        //
        Real t;
        {
            Real denom = normal.dotProduct(ray.getDirection());

            // Check intersect side
            if (denom > + Real.epsilon)
            {
                if (!negativeSide)
                    return pair!(bool, Real)(false, cast(Real)0);
            }
            else if (denom < - Real.epsilon)
            {
                if (!positiveSide)
                    return pair!(bool, Real)(false, cast(Real)0);
            }
            else
            {
                // Parallel or triangle area is close to zero when
                // the plane normal not normalised.
                return pair!(bool, Real)(false, cast(Real)0);
            }

            t = normal.dotProduct(a - ray.getOrigin()) / denom;

            if (t < 0)
            {
                // Intersection is behind origin
                return pair!(bool, Real)(false, cast(Real)0);
            }
        }

        //
        // Calculate the largest area projection plane in X, Y or Z.
        //
        size_t i0, i1;
        {
            Real n0 = Abs(normal[0]);
            Real n1 = Abs(normal[1]);
            Real n2 = Abs(normal[2]);

            i0 = 1; i1 = 2;
            if (n1 > n2)
            {
                if (n1 > n0) i0 = 0;
            }
            else
            {
                if (n2 > n0) i1 = 0;
            }
        }

        //
        // Check the intersection point is inside the triangle.
        //
        {
            Real u1 = b[i0] - a[i0];
            Real v1 = b[i1] - a[i1];
            Real u2 = c[i0] - a[i0];
            Real v2 = c[i1] - a[i1];
            Real u0 = t * ray.getDirection()[i0] + ray.getOrigin()[i0] - a[i0];
            Real v0 = t * ray.getDirection()[i1] + ray.getOrigin()[i1] - a[i1];

            Real alpha = u0 * v2 - u2 * v0;
            Real beta  = u1 * v0 - u0 * v1;
            Real area  = u1 * v2 - u2 * v1;

            // epsilon to avoid float precision error
            Real EPSILON = 1e-6f;

            Real tolerance = - EPSILON * area;

            if (area > 0)
            {
                if (alpha < tolerance || beta < tolerance || alpha+beta > area-tolerance)
                    return pair!(bool, Real)(false, cast(Real)0);
            }
            else
            {
                if (alpha > tolerance || beta > tolerance || alpha+beta < area-tolerance)
                    return pair!(bool, Real)(false, cast(Real)0);
            }
        }

        return pair!(bool, Real)(true, cast(Real)t);
    }

    
    /** Ray / triangle intersection, returns boolean result and distance.
     @param ray
     The ray.
     @param a
     The triangle's first vertex.
     @param b
     The triangle's second vertex.
     @param c
     The triangle's third vertex.
     @param positiveSide
     Intersect with "positive side" of the triangle
     @param negativeSide
     Intersect with "negative side" of the triangle
     @return
     If the ray is intersects the triangle, a pair of <b>true</b> and the
     distance between intersection point and ray origin returned.
     @par
     If the ray isn't intersects the triangle, a pair of <b>false</b> and
     <b>0</b> returned.
     */
    static pair!(bool, Real) intersects(ref Ray ray,ref Vector3 a,
                                        ref Vector3 b,ref Vector3 c,
                                        bool positiveSide = true, bool negativeSide = true)
    {
        Vector3 normal = calculateBasicFaceNormalWithoutNormalize(a, b, c);
        return intersects(ray, a, b, c, normal, positiveSide, negativeSide);
    }

    /** Sphere / box intersection test. */
    static bool intersects(Sphere sphere, AxisAlignedBox box)
    {
        if (box.isNull()) return false;
        if (box.isInfinite()) return true;

        // Use splitting planes
        Vector3 center = sphere.getCenter();
        Real radius = sphere.getRadius();
        Vector3 min = box.getMinimum();
        Vector3 max = box.getMaximum();

        // Arvo's algorithm
        Real s, d = 0;
        for (int i = 0; i < 3; ++i)
        {
            if (center[i] < min[i])
            {
                s = center[i] - min[i];
                d += s * s; 
            }
            else if(center[i] > max[i])
            {
                s = center[i] - max[i];
                d += s * s; 
            }
        }
        return d <= radius * radius;

    }

    /** Plane / box intersection test. */
    static bool intersects(ref Plane plane,ref AxisAlignedBox box)
    {
        return (plane.getSide(box) == Plane.Side.BOTH_SIDE);
    }

    /** Ray / convex plane list intersection test.
     @param ray The ray to test with
     @param planeList List of planes which form a convex volume
     @param normalIsOutside Does the normal point outside the volume
     */
    static pair!(bool, Real) intersects(
        ref Ray ray, ref Plane[] planeList,
        bool normalIsOutside)
    {
        bool allInside = true;
        pair!(bool, Real) ret;
        pair!(bool, Real) end;
        ret.first = false;
        ret.second = 0.0f;
        end.first = false;
        end.second = 0;

        
        // derive side
        // NB we don't pass directly since that would require Plane.Side in 
        // interface, which results in recursive includes since Math is so fundamental
        // TODO @todo D suffers from this too?
        Plane.Side outside = normalIsOutside ? Plane.Side.POSITIVE_SIDE : Plane.Side.NEGATIVE_SIDE;

        foreach(plane; planeList)
        {
            // is origin outside?
            if (plane.getSide(ray.getOrigin()) == outside)
            {
                allInside = false;
                // Test single plane
                pair!(bool, Real) planeRes = 
                    ray.intersects(plane);
                if (planeRes.first)
                {
                    // Ok, we intersected
                    ret.first = true;
                    // Use the most distant result since convex volume
                    ret.second = fmax(ret.second, planeRes.second);
                }
                else
                {
                    ret.first =false;
                    ret.second=0.0f;
                    return ret;
                }
            }
            else
            {
                pair!(bool, Real) planeRes = 
                    ray.intersects(plane);
                if (planeRes.first)
                {
                    if( !end.first )
                    {
                        end.first = true;
                        end.second = planeRes.second;
                    }
                    else
                    {
                        end.second = fmin( planeRes.second, end.second );
                    }

                }

            }
        }

        if (allInside)
        {
            // Intersecting at 0 distance since inside the volume!
            ret.first = true;
            ret.second = 0.0f;
            return ret;
        }

        if( end.first )
        {
            if( end.second < ret.second )
            {
                ret.first = false;
                return ret;
            }
        }
        return ret;
    }

    // IGNORE
    /** Ray / convex plane list intersection test.
     @param ray The ray to test with
     @param planeList List of planes which form a convex volume
     @param normalIsOutside Does the normal point outside the volume
     */
    /+static pair!(bool, Real) intersects(
     ref Ray ray,ref Plane[] planeList,
     bool normalIsOutside)
     {
     for (vector<Plane>::type.const_iterator i = planes.begin(); i != planes.end(); ++i)
     {
     planesList.insertBack(*i);
     }
     return intersects(ray, planesList, normalIsOutside);
     }+/

    /** Sphere / plane intersection test.
     @remarks NB just do a plane.getDistance(sphere.getCenter()) for more detail!
     */
    static bool intersects(Sphere sphere, ref Plane plane)
    {
        return (
            Abs(plane.getDistance(sphere.getCenter()))
            <= sphere.getRadius() );
    }

    /** Compare 2 reals, using tolerance for inaccuracies.
     */
    static bool RealEqual(Real a, Real b, Real tolerance = Real.epsilon)
    {
        if (abs(b-a) <= tolerance)
            return true;
        else
            return false;
    }
    /** Calculates the tangent space vector for a given set of positions / texture coords. */
    static Vector3 calculateTangentSpaceVector(
        ref Vector3 position1,ref Vector3 position2,ref Vector3 position3,
        Real u1, Real v1, Real u2, Real v2, Real u3, Real v3)
    {
        //side0 is the vector along one side of the triangle of vertices passed in, 
        //and side1 is the vector along another side. Taking the cross product of these returns the normal.
        Vector3 side0 = position1 - position2;
        Vector3 side1 = position3 - position1;
        //Calculate face normal
        Vector3 normal = side1.crossProduct(side0);
        normal.normalise();
        //Now we use a formula to calculate the tangent. 
        Real deltaV0 = v1 - v2;
        Real deltaV1 = v3 - v1;
        Vector3 tangent = deltaV1 * side0 - deltaV0 * side1;
        tangent.normalise();
        //Calculate binormal
        Real deltaU0 = u1 - u2;
        Real deltaU1 = u3 - u1;
        Vector3 binormal = deltaU1 * side0 - deltaU0 * side1;
        binormal.normalise();
        //Now, we take the cross product of the tangents to get a vector which 
        //should point in the same direction as our normal calculated above. 
        //If it points in the opposite direction (the dot product between the normals is less than zero), 
        //then we need to reverse the s and t tangents. 
        //This is because the triangle has been mirrored when going from tangent space to object space.
        //reverse tangents if necessary
        Vector3 tangentCross = tangent.crossProduct(binormal);
        if (tangentCross.dotProduct(normal) < 0.0f)
        {
            tangent = -tangent;
            binormal = -binormal;
        }

        return tangent;

    }

    /** Build a reflection matrix for the passed in plane. */
    static Matrix4 buildReflectionMatrix(Plane p)
    {
        return Matrix4(
            -2 * p.normal.x * p.normal.x + 1,   -2 * p.normal.x * p.normal.y,       -2 * p.normal.x * p.normal.z,       -2 * p.normal.x * p.d, 
            -2 * p.normal.y * p.normal.x,       -2 * p.normal.y * p.normal.y + 1,   -2 * p.normal.y * p.normal.z,       -2 * p.normal.y * p.d, 
            -2 * p.normal.z * p.normal.x,       -2 * p.normal.z * p.normal.y,       -2 * p.normal.z * p.normal.z + 1,   -2 * p.normal.z * p.d, 
            0,                                  0,                                  0,                                  1);
    }
    /** Calculate a face normal, including the w component which is the offset from the origin. */
    static Vector4 calculateFaceNormal(ref Vector3 v1,ref Vector3 v2,ref Vector3 v3)
    {
        Vector3 normal = calculateBasicFaceNormal(v1, v2, v3);
        // Now set up the w (distance of tri from origin
        return Vector4(normal.x, normal.y, normal.z, -(normal.dotProduct(v1)));
    }
    /** Calculate a face normal, no w-information. */
    static Vector3 calculateBasicFaceNormal(ref Vector3 v1,ref Vector3 v2,ref Vector3 v3)
    {
        Vector3 normal = (v2 - v1).crossProduct(v3 - v1);
        normal.normalise();
        return normal;
    }
    /** Calculate a face normal without normalize, including the w component which is the offset from the origin. */
    static Vector4 calculateFaceNormalWithoutNormalize(ref Vector3 v1,ref Vector3 v2,ref Vector3 v3)
    {
        Vector3 normal = calculateBasicFaceNormalWithoutNormalize(v1, v2, v3);
        // Now set up the w (distance of tri from origin)
        return Vector4(normal.x, normal.y, normal.z, -(normal.dotProduct(v1)));
    }
    /** Calculate a face normal without normalize, no w-information. */
    static Vector3 calculateBasicFaceNormalWithoutNormalize(ref Vector3 v1,ref Vector3 v2,ref Vector3 v3)
    {
        Vector3 normal = (v2 - v1).crossProduct(v3 - v1);
        return normal;
    }
    /** Generates a value based on the Gaussian (normal) distribution function
     with the given offset and scale parameters.
     */
    static Real gaussianDistribution(Real x, Real offset = 0.0f, Real scale = 1.0f)
    {
        Real nom = Exp(
            -Sqr(x - offset) / (2 * Sqr(scale)));
        Real denom = scale * Sqrt(2 * PI);

        return nom / denom;

    }
    /** Clamp a value within an inclusive range. 
     * @todo Fix D templating.
     */
    /*template Clamp(T) {
         static T Clamp(T val, T minval, T maxval)
         {
             assert (minval <= maxval && "Invalid clamp range");
             return max(min(val, maxval), minval);
         }
     }*/

    static Matrix4 makeViewMatrix(ref Vector3 position,ref Quaternion orientation,
                                  Matrix4* reflectMatrix)
    {
        Matrix4 viewMatrix;

        // View matrix is:
        //
        //  [ Lx  Uy  Dz  Tx  ]
        //  [ Lx  Uy  Dz  Ty  ]
        //  [ Lx  Uy  Dz  Tz  ]
        //  [ 0   0   0   1   ]
        //
        // Where T = -(Transposed(Rot) * Pos)

        // This is most efficiently done using 3x3 Matrices
        Matrix3 rot;
        orientation.ToRotationMatrix(rot);

        // Make the translation relative to new axes
        Matrix3 rotT = rot.Transpose();
        Vector3 trans = -rotT * position;

        // Make final matrix
        viewMatrix = Matrix4.IDENTITY;
        viewMatrix = rotT; // fills upper 3x3
        viewMatrix[0, 3] = trans.x;
        viewMatrix[1, 3] = trans.y;
        viewMatrix[2, 3] = trans.z;

        // Deal with reflections
        if (reflectMatrix !is null)
        {
            viewMatrix = viewMatrix * (*reflectMatrix);
        }

        return viewMatrix;

    }
    /** Get a bounding radius value from a bounding box. */
    static Real boundingRadiusFromAABB(AxisAlignedBox aabb)
    {
        Vector3 max = aabb.getMaximum();
        Vector3 min = aabb.getMinimum();

        Vector3 magnitude = max;
        magnitude.makeCeil(-max);
        magnitude.makeCeil(min);
        magnitude.makeCeil(-min);

        return magnitude.length();
    }
    
    /*static Real Clamp(Real val, Real minval, Real maxval)
     {
     assert (minval <= maxval && "Invalid clamp range");
     return std.math.fmax(std.math.fmin(val, maxval), minval);
     }*/
    
    //Simulate the shader function lerp which performers linear interpolation
    //given 3 parameters v0, v1 and t the function returns the value of (1  t)* v0 + t * v1.
    //where v0 and v1 are matching vector or scalar types and t can be either a scalar or a vector of the same type as a and b.
    
    static V lerp(V,T)(V v0,V v1,T t) {
        return v0 * (1 - t) + v1 * t;
    }
    
    /**
     * @todo template static if to choose if to use max/min or fmax/fmin ?
     */
    static T Clamp(T)(T val, T minval, T maxval)
    {
        assert (minval <= maxval, "Invalid clamp range");
        return std.math.fmax(std.math.fmin(val, maxval), minval);
    }
}

/** @} */
/** @} */

unittest
{
    {
        //import std.stdio: writeln;
        auto r = Radian(3);
        auto nr = -r;
        auto d = Degree(45);
        auto nd = -d;
        assert(nr == Radian(-3));
        assert(nd == Degree(-45));
        //writeln(r, ",", nr.valueDegrees());
        //writeln(d.valueRadians(), ",", nd.valueRadians());
    }

}
