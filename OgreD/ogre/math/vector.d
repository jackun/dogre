module ogre.math.vector;

//import core.simd;
import ogre.compat;
import ogre.math.maths;

import ogre.math.angles;
import ogre.math.quaternion;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Math
 *  @{
 */
/** Standard 2-dimensional vector.
 @remarks
 A direction in 2D space represented as distances along the 2
 orthogonal axes (x, y). Note that positions, directions and
 scaling factors can be represented by a vector, depending on how
 you interpret the values.
 */
struct Vector2
{
public:
    Real x, y;

    immutable static Vector2 ZERO = Vector2( 0, 0);
    immutable static Vector2 UNIT_X = Vector2( 1, 0);
    immutable static Vector2 UNIT_Y = Vector2( 0, 1);
    immutable static Vector2 NEGATIVE_UNIT_X = Vector2( -1,  0);
    immutable static Vector2 NEGATIVE_UNIT_Y = Vector2(  0, -1);
    immutable static Vector2 UNIT_SCALE = Vector2(1, 1);

public:

    /*static this()
     {
     ZERO = Vector2( 0, 0);
     UNIT_X = Vector2( 1, 0);
     UNIT_Y = Vector2( 0, 1);
     NEGATIVE_UNIT_X = Vector2( -1,  0);
     NEGATIVE_UNIT_Y = Vector2(  0, -1);
     UNIT_SCALE = Vector2(1, 1);
     }*/
    
    this(Real fX,Real fY )
    {
        x = fX;
        y = fY;
    }

    this(Real scaler )
    {
        x = scaler;
        y = scaler;
    }

    this(Real afCoordinate[2] )
    {
        x = afCoordinate[0];
        y = afCoordinate[1];
    }

    this(int afCoordinate[2] )
    {
        x = cast(Real)afCoordinate[0];
        y = cast(Real)afCoordinate[1];
    }

    /*this( Real* r )
     {
     x = r[0];
     y = r[1];
     }*/
    
    this( Real[] r )
    {
        x = r[0];
        y = r[1];
    }

    /** Exchange the contents of this vector with another. 
     */
    void swap(Vector2 other)
    {
        std.algorithm.swap(x, other.x);
        std.algorithm.swap(y, other.y);
    }

    /** @todo opIndex: can rely on tupleof ?
     */
    Real opIndex (size_t i )
    {
        assert( i < 2 );

        //return *(&x+i);
        //return this.tupleof[i];
        return [x,y][i];
    }

    const(Real) opIndex (size_t i ) const
    {
        assert( i < 2 );

        //return *(&x+i);
        //return this.tupleof[i];
        return [x,y][i];
    }

    /// Pointer accessor for direct copying
    @property
    Real* ptr()
    {
        return &x;
    }
    /*
     /// Pointer accessor for direct copying
     inlineReal* ptr()
     {
     return &x;
     }*/

    /** Assigns the value of the other vector.
     @param
     rkVector The other vector
     */
    Vector2 opAssign (Vector2 rkVector )
    {
        x = rkVector.x;
        y = rkVector.y;

        return this;
    }

    Vector2 opAssign (Real fScalar)
    {
        x = fScalar;
        y = fScalar;

        return this;
    }

    bool opEquals (Vector2 rkVector ) const
    {
        return ( x == rkVector.x && y == rkVector.y );
    }

    /*bool operator != (Vector2& rkVector )
     {
     return ( x != rkVector.x || y != rkVector.y  );
     }*/

    // arithmetic operations
    Vector2 opAdd (Vector2 rkVector )
    {
        return Vector2(
            x + rkVector.x,
            y + rkVector.y);
    }

    Vector2 opSub (Vector2 rkVector )
    {
        return Vector2(
            x - rkVector.x,
            y - rkVector.y);
    }

    Vector2 opMul (Real fScalar )
    {
        return Vector2(
            x * fScalar,
            y * fScalar);
    }

    Vector2 opMul (Vector2 rhs)
    {
        return Vector2(
            x * rhs.x,
            y * rhs.y);
    }

    Vector2 opDiv (Real fScalar )
    {
        assert( fScalar != 0.0 );

        Real fInv = 1.0f / fScalar;

        return Vector2(
            x * fInv,
            y * fInv);
    }

    Vector2 opDiv (Vector2 rhs)
    {
        return Vector2(
            x / rhs.x,
            y / rhs.y);
    }

    Vector2 opUnary(string s)() {
        if (s == "-") { return Vector2(-x, -y); }
        else if (s == "+") { return this; }
        //else if (s == "+" || s == "*") { return this; }
    }

    // overloaded operators to help Vector2
    /** @todo Needed?*/
    /*
     inline friend Vector2 operator * (Real fScalar,Vector2& rkVector )
     {
     return Vector2(
     fScalar * rkVector.x,
     fScalar * rkVector.y);
     }

     inline friend Vector2 operator / (Real fScalar,Vector2& rkVector )
     {
     return Vector2(
     fScalar / rkVector.x,
     fScalar / rkVector.y);
     }

     inline friend Vector2 operator + (Vector2& lhs,Real rhs)
     {
     return Vector2(
     lhs.x + rhs,
     lhs.y + rhs);
     }

     inline friend Vector2 operator + (Real lhs,Vector2& rhs)
     {
     return Vector2(
     lhs + rhs.x,
     lhs + rhs.y);
     }

     inline friend Vector2 operator - (Vector2& lhs,Real rhs)
     {
     return Vector2(
     lhs.x - rhs,
     lhs.y - rhs);
     }

     inline friend Vector2 operator - (Real lhs,Vector2& rhs)
     {
     return Vector2(
     lhs - rhs.x,
     lhs - rhs.y);
     }*/

    // arithmetic updates
    Vector2 opAddAssign (Vector2 rkVector )
    {
        x += rkVector.x;
        y += rkVector.y;

        return this;
    }

    Vector2 opAddAssign (Real fScaler )
    {
        x += fScaler;
        y += fScaler;

        return this;
    }

    Vector2 opSubAssign (Vector2 rkVector )
    {
        x -= rkVector.x;
        y -= rkVector.y;

        return this;
    }

    Vector2 opSubAssign (Real fScaler )
    {
        x -= fScaler;
        y -= fScaler;

        return this;
    }

    Vector2 opMulAssign (Real fScalar )
    {
        x *= fScalar;
        y *= fScalar;

        return this;
    }

    Vector2 opMulAssign (Vector2 rkVector )
    {
        x *= rkVector.x;
        y *= rkVector.y;

        return this;
    }

    Vector2 opDivAssign (Real fScalar )
    {
        assert( fScalar != 0.0 );

        Real fInv = 1.0f / fScalar;

        x *= fInv;
        y *= fInv;

        return this;
    }

    Vector2 opDivAssign (Vector2 rkVector )
    {
        x /= rkVector.x;
        y /= rkVector.y;

        return this;
    }

    /** Returns the length (magnitude) of the vector.
     @warning
     This operation requires a square root and is expensive in
     terms of CPU operations. If you don't need to know the exact
     length (e.g. for just comparing lengths) use squaredLength()
     instead.
     */
    Real length ()
    {
        return Math.Sqrt( x * x + y * y );
    }

    /** Returns the square of the length(magnitude) of the vector.
     @remarks
     This  method is for efficiency - calculating the actual
     length of a vector requires a square root, which is expensive
     in terms of the operations required. This method returns the
     square of the length of the vector, i.e. the same as the
     length but before the square root is taken. Use this if you
     want to find the longest / shortest vector without incurring
     the square root.
     */
    Real squaredLength ()
    {
        return x * x + y * y;
    }

    /** Returns the distance to another vector.
     @warning
     This operation requires a square root and is expensive in
     terms of CPU operations. If you don't need to know the exact
     distance (e.g. for just comparing distances) use squaredDistance()
     instead.
     */
    Real distance(Vector2 rhs)
    {
        return (this - rhs).length();
    }

    /** Returns the square of the distance to another vector.
     @remarks
     This method is for efficiency - calculating the actual
     distance to another vector requires a square root, which is
     expensive in terms of the operations required. This method
     returns the square of the distance to another vector, i.e.
     the same as the distance but before the square root is taken.
     Use this if you want to find the longest / shortest distance
     without incurring the square root.
     */
    Real squaredDistance(Vector2 rhs)
    {
        return (this - rhs).squaredLength();
    }

    /** Calculates the dot (scalar) product of this vector with another.
     @remarks
     The dot product can be used to calculate the angle between 2
     vectors. If both are unit vectors, the dot product is the
     cosine of the angle; otherwise the dot product must be
     divided by the product of the lengths of both vectors to get
     the cosine of the angle. This result can further be used to
     calculate the distance of a point from a plane.
     @param
     vec Vector with which to calculate the dot product (together
     with this one).
     @return
     A float representing the dot product value.
     */
    Real dotProduct(Vector2 vec)
    {
        return x * vec.x + y * vec.y;
    }

    /** Normalises the vector.
     @remarks
     This method normalises the vector such that it's
     length / magnitude is 1. The result is called a unit vector.
     @note
     This function will not crash for zero-sized vectors, but there
     will be no changes made to their components.
     @return The previous length of the vector.
     */

    Real normalise()
    {
        Real fLength = Math.Sqrt( x * x + y * y);

        // Will also work for zero-sized vectors, but will change nothing
        // We're not using epsilons because we don't need to.
        // Read http://www.ogre3d.org/forums/viewtopic.php?f=4&t=61259
        if ( fLength > cast(Real)0.0f )
        {
            Real fInvLength = 1.0f / fLength;
            x *= fInvLength;
            y *= fInvLength;
        }

        return fLength;
    }

    /** Returns a vector at a point half way between this and the passed
     in vector.
     */
    Vector2 midPoint(Vector2 vec )
    {
        return Vector2(
            ( x + vec.x ) * 0.5f,
            ( y + vec.y ) * 0.5f );
    }

    /** Returns true if the vector's scalar components are all greater
     that the ones of the vector it is compared against.
     * @todo D operator overloading.
     */
    bool opLessThan (Vector2 rhs )
    {
        if( x < rhs.x && y < rhs.y )
            return true;
        return false;
    }

    /** Returns true if the vector's scalar components are all smaller
     that the ones of the vector it is compared against.
     * @todo D operator overloading.
     */
    bool opGreaterThan (Vector2 rhs )
    {
        if( x > rhs.x && y > rhs.y )
            return true;
        return false;
    }

    /** Sets this vector's components to the minimum of its own and the
     ones of the passed in vector.
     @remarks
     'Minimum' in this case means the combination of the lowest
     value of x, y and z from both vectors. Lowest is taken just
     numerically, not magnitude, so -1 < 0.
     */
    void makeFloor(Vector2 cmp )
    {
        if( cmp.x < x ) x = cmp.x;
        if( cmp.y < y ) y = cmp.y;
    }

    /** Sets this vector's components to the maximum of its own and the
     ones of the passed in vector.
     @remarks
     'Maximum' in this case means the combination of the highest
     value of x, y and z from both vectors. Highest is taken just
     numerically, not magnitude, so 1 > -3.
     */
    void makeCeil(Vector2 cmp )
    {
        if( cmp.x > x ) x = cmp.x;
        if( cmp.y > y ) y = cmp.y;
    }

    /** Generates a vector perpendicular to this vector (eg an 'up' vector).
     @remarks
     This method will return a vector which is perpendicular to this
     vector. There are an infinite number of possibilities but this
     method will guarantee to generate one of them. If you need more
     control you should use the Quaternion class.
     */
    Vector2 perpendicular()
    {
        return Vector2 (-y, x);
    }

    /** Calculates the 2 dimensional cross-product of 2 vectors, which results
     in a single floating point value which is 2 times the area of the triangle.
     */
    Real crossProduct(Vector2 rkVector )
    {
        return x * rkVector.y - y * rkVector.x;
    }

    /** Generates a new random vector which deviates from this vector by a
     given angle in a random direction.
     @remarks
     This method assumes that the random number generator has already
     been seeded appropriately.
     @param angle
     The angle at which to deviate in radians
     @return
     A random vector which deviates from this vector by angle. This
     vector will not be normalised, normalise it if you wish
     afterwards.
     */
    Vector2 randomDeviant(Real angle)
    {

        angle *=  Math.UnitRandom() * Math.TWO_PI;
        Real cosa = std.math.cos(angle);
        Real sina = std.math.sin(angle);
        return Vector2(cosa * x - sina * y,
                       sina * x + cosa * y);
    }

    /** Returns true if this vector is zero length. */
    bool isZeroLength()
    {
        Real sqlen = (x * x) + (y * y);
        return (sqlen < (1e-06 * 1e-06));

    }

    /** As normalise, except that this vector is unaffected and the
     normalised vector is returned as a copy. */
    Vector2 normalisedCopy()
    {
        //Vector2 ret = *this;
        Vector2 ret = Vector2(x, y);
        ret.normalise();
        return ret;
    }

    /** Calculates a reflection vector to the plane with the given normal .
     @remarks NB assumes 'this' is pointing AWAY FROM the plane, invert if it is not.
     */
    Vector2 reflect(Vector2 normal)
    {
        return ( this - ( 2 * this.dotProduct(normal) * normal ) );
        //return Vector2( this - ( 2 * this.dotProduct(normal) * normal ) );
    }

    /// Check whether this vector contains valid values
    bool isNaN()
    {
        return Math.isNaN(x) || Math.isNaN(y);
    }

    /**  Gets the angle between 2 vectors.
     @remarks
     Vectors do not have to be unit-length but must represent directions.
     */
    Radian angleBetween(Vector2 other)
    {       
        Real lenProduct = length() * other.length();
        // Divide by zero check
        if(lenProduct < 1e-6f)
            lenProduct = 1e-6f;
        
        Real f = dotProduct(other) / lenProduct;

        f = Math.Clamp(f, cast(Real)-1.0, cast(Real)1.0);
        return Math.ACos(f);
    }

    /**  Gets the oriented angle between 2 vectors.
     @remarks
     Vectors do not have to be unit-length but must represent directions.
     The angle is comprised between 0 and 2 PI.
     */
    Radian angleTo(Vector2 other)
    {
        Radian angle = angleBetween(other);
        
        if (crossProduct(other)<0)          
            angle = (Radian(Math.TWO_PI)) - angle;

        return angle;
    }

    /** Function for writing to a stream.
     */
    string toString()
    {
        return "Vector2(" ~ std.conv.to!string(x) ~ ", " ~ std.conv.to!string(y) ~ ")";
    }
}

/** Standard 3-dimensional vector.
 @remarks
 A direction in 3D space represented as distances along the 3
 orthogonal axes (x, y, z). Note that positions, directions and
 scaling factors can be represented by a vector, depending on how
 you interpret the values.
 */
struct Vector3
{
public:
    Real x, y, z;
    /*union //Vecs 
     {
     struct {Real x,y,z;}
     Real[3] v;
     }*/
    //Vecs vecs;*/

    // With enum - cannot create struct until size is determined.
    immutable static Vector3 ZERO = Vector3( 0f, 0f, 0f );

    immutable static Vector3 UNIT_X = Vector3( 1, 0, 0 );
    immutable static Vector3 UNIT_Y = Vector3( 0, 1, 0 );
    immutable static Vector3 UNIT_Z = Vector3( 0, 0, 1 );
    immutable static Vector3 NEGATIVE_UNIT_X = Vector3( -1,  0,  0 );
    immutable static Vector3 NEGATIVE_UNIT_Y = Vector3(  0, -1,  0 );
    immutable static Vector3 NEGATIVE_UNIT_Z = Vector3(  0,  0, -1 );
    immutable static Vector3 UNIT_SCALE = Vector3(1, 1, 1);

public:

    /*@property Real x(){ return x; }
     @property Real y(){ return y; }
     @property Real z(){ return z; }
     
     @property Real x(Real v) { return x = v; }
     @property Real y(Real v) { return y = v; }
     @property Real z(Real v) { return z = v; }*/
    
    /*static this()
    {
        ZERO = Vector3( 0, 0, 0 );
        UNIT_X = Vector3( 1, 0, 0 );
        UNIT_Y = Vector3( 0, 1, 0 );
        UNIT_Z = Vector3( 0, 0, 1 );
        NEGATIVE_UNIT_X = Vector3( -1,  0,  0 );
        NEGATIVE_UNIT_Y = Vector3(  0, -1,  0 );
        NEGATIVE_UNIT_Z = Vector3(  0,  0, -1 );
        UNIT_SCALE = Vector3(1, 1, 1);
    }*/

    /*this()
     {
     }*/

    this(Real fX,Real fY,Real fZ )
    {
        x = fX; 
        y = fY; 
        z = fZ;
    }

    this(Real afCoordinate[3] )
    {
        x = afCoordinate[0];
        y = afCoordinate[1];
        z = afCoordinate[2];
    }

    this(int afCoordinate[3] )
    {
        x = cast(Real)afCoordinate[0];
        y = cast(Real)afCoordinate[1];
        z = cast(Real)afCoordinate[2];
    }

    /*this(Real*  r ) //collides with Real[] :S
     {
     x = r[0];
     y = r[1];
     z = r[2];
     }*/

    this(Real[] r )
    {
        x = r[0];
        y = r[1];
        z = r[2];
    }
    
    this(Real scaler )
    {
        x = scaler;
        y = scaler;
        z = scaler;
    }

    
    /** Exchange the contents of this vector with another. 
     * @todo Check if same behaviour as in C++.
     */
    void swap(ref Vector3 other)
    {
        std.algorithm.swap(x, other.x);
        std.algorithm.swap(y, other.y);
        std.algorithm.swap(z, other.z);
        //std.algorithm.swap(vecs, other.vecs);
    }

    /**
     * Return field at the index.
     * @todo Are we assured x,y,z are always in same order?
     * */
    Real opIndex(size_t i )
    {
        assert( i < 3 );

        //return *(&x+i);
        //return this.tupleof[i];
        //return v[i];
        return [x,y,z][i];
    }
    
    Real opIndexAssign( Real v,size_t i )
    {
        assert( i < 3 );

        //return *(&x+i);
        //return this.tupleof[i];
        //v[i] = v;
        //return v[i];
        switch(i)
        {
            case 0:
                return x = v;
            case 1:
                return y = v;
            case 2:
                return z = v;
            default:
                assert(0);
        }
    }

    /+inline Real& operator [] (size_t i )
     {
     assert( i < 3 );

     return *(&x+i);
     }+/

    /// Pointer accessor for direct copying
    @property 
    Real* ptr()
    {
        return &x; //v.ptr;
    }
    
    /** Assigns the value of the other vector.
     @param
     rkVector The other vector
     */
    Vector3 opAssign(Vector3 rkVector )
    {
        x = rkVector.x;
        y = rkVector.y;
        z = rkVector.z;
        return this;
    }

    Vector3 opAssign ( Real fScaler )
    {
        x = fScaler;
        y = fScaler;
        z = fScaler;

        return this;
    }

    bool opEquals (Vector3 rkVector ) const
    {
        return ( x == rkVector.x && y == rkVector.y && z == rkVector.z );
    }

    //Expressions of the form a != b are rewritten as !(a == b).
    /+bool operator != (Vector3 rkVector )
     {
     return ( x != rkVector.x || y != rkVector.y || z != rkVector.z );
     }+/

    // arithmetic operations
    /+const+/ Vector3 opAdd (Vector3 rkVector ) const
    {
        return Vector3(
            x + rkVector.x,
            y + rkVector.y,
            z + rkVector.z);
    }

    /+const+/ Vector3 opSub (/+ref+/ Vector3 rkVector ) const
    {
        return Vector3(
            x - rkVector.x,
            y - rkVector.y,
            z - rkVector.z);
    }
    
    /+const+/ Vector3 opMul (Real fScalar ) const
    {
        return Vector3(
            x * fScalar,
            y * fScalar,
            z * fScalar);
    }

    /+const+/Vector3 opMul (Vector3 rhs) const
    {
        return Vector3(
            x * rhs.x,
            y * rhs.y,
            z * rhs.z);
    }

    /+const+/ Vector3 opDiv (Real fScalar ) const
    {
        assert( fScalar != 0.0 );

        Real fInv = 1.0f / fScalar;

        return Vector3(
            x * fInv,
            y * fInv,
            z * fInv);
    }

    /+const+/ Vector3 opDiv (Vector3 rhs) const
    {
        return Vector3(
            x / rhs.x,
            y / rhs.y,
            z / rhs.z);
    }

    /** @todo Op * is needed? */
    Vector3 opUnary(string s)() const 
    {
        if (s == "-") { return Vector3(-x, -y, -z); }
        else if (s == "+" || s == "*") { return this; }
        assert(0);
    }

    /** @todo dafuq */
    /+
     // overloaded operators to help Vector3
     inline friend Vector3 operator * (Real fScalar,Vector3& rkVector )
     {
     return Vector3(
     fScalar * rkVector.x,
     fScalar * rkVector.y,
     fScalar * rkVector.z);
     }

     inline friend Vector3 operator / (Real fScalar,Vector3& rkVector )
     {
     return Vector3(
     fScalar / rkVector.x,
     fScalar / rkVector.y,
     fScalar / rkVector.z);
     }

     inline friend Vector3 operator + (Vector3& lhs,Real rhs)
     {
     return Vector3(
     lhs.x + rhs,
     lhs.y + rhs,
     lhs.z + rhs);
     }

     inline friend Vector3 operator + (Real lhs,Vector3& rhs)
     {
     return Vector3(
     lhs + rhs.x,
     lhs + rhs.y,
     lhs + rhs.z);
     }

     inline friend Vector3 operator - (Vector3& lhs,Real rhs)
     {
     return Vector3(
     lhs.x - rhs,
     lhs.y - rhs,
     lhs.z - rhs);
     }

     inline friend Vector3 operator - (Real lhs,Vector3& rhs)
     {
     return Vector3(
     lhs - rhs.x,
     lhs - rhs.y,
     lhs - rhs.z);
     }
     +/
    
    // arithmetic updates
    Vector3 opAddAssign (Vector3 rkVector )
    {
        x += rkVector.x;
        y += rkVector.y;
        z += rkVector.z;
        return this;
    }

    Vector3 opAddAssign (Real fScalar )
    {
        x += fScalar;
        y += fScalar;
        z += fScalar;
        return this;
    }

    Vector3 opAdd (Real fScalar )
    {
        return Vector3(x + fScalar,
                       y + fScalar,
                       z + fScalar);
    }

    Vector3 opSub (Real fScalar )
    {
        return Vector3(x - fScalar,
                       y - fScalar,
                       z - fScalar);
    }

    Vector3 opSubAssign (Vector3 rkVector )
    {
        x -= rkVector.x;
        y -= rkVector.y;
        z -= rkVector.z;
        return this;
    }

    Vector3 opSubAssign (Real fScalar )
    {
        x -= fScalar;
        y -= fScalar;
        z -= fScalar;
        return this;
    }

    Vector3 opMulAssign (Real fScalar )
    {
        x *= fScalar;
        y *= fScalar;
        z *= fScalar;
        return this;
    }

    Vector3 opMulAssign (Vector3 rkVector )
    {
        x *= rkVector.x;
        y *= rkVector.y;
        z *= rkVector.z;

        return this;
    }

    Vector3 opDivAssign (Real fScalar )
    {
        assert( fScalar != 0.0 );

        Real fInv = 1.0f / fScalar;

        x *= fInv;
        y *= fInv;
        z *= fInv;

        return this;
    }

    Vector3 opDivAssign (Vector3 rkVector )
    {
        x /= rkVector.x;
        y /= rkVector.y;
        z /= rkVector.z;

        return this;
    }

    
    /** Returns the length (magnitude) of the vector.
     @warning
     This operation requires a square root and is expensive in
     terms of CPU operations. If you don't need to know the exact
     length (e.g. for just comparing lengths) use squaredLength()
     instead.
     */
    Real length ()
    {
        return Math.Sqrt( x * x + y * y + z * z );
    }

    /** Returns the square of the length(magnitude) of the vector.
     @remarks
     This  method is for efficiency - calculating the actual
     length of a vector requires a square root, which is expensive
     in terms of the operations required. This method returns the
     square of the length of the vector, i.e. the same as the
     length but before the square root is taken. Use this if you
     want to find the longest / shortest vector without incurring
     the square root.
     */
    Real squaredLength ()
    {
        return x * x + y * y + z * z;
    }

    /** Returns the distance to another vector.
     @warning
     This operation requires a square root and is expensive in
     terms of CPU operations. If you don't need to know the exact
     distance (e.g. for just comparing distances) use squaredDistance()
     instead.
     */
    Real distance(Vector3 rhs)
    {
        return (this - rhs).length();
    }

    /** Returns the square of the distance to another vector.
     @remarks
     This method is for efficiency - calculating the actual
     distance to another vector requires a square root, which is
     expensive in terms of the operations required. This method
     returns the square of the distance to another vector, i.e.
     the same as the distance but before the square root is taken.
     Use this if you want to find the longest / shortest distance
     without incurring the square root.
     */
    Real squaredDistance(Vector3 rhs)
    {
        return (this - rhs).squaredLength();
    }

    /** Calculates the dot (scalar) product of this vector with another.
     @remarks
     The dot product can be used to calculate the angle between 2
     vectors. If both are unit vectors, the dot product is the
     cosine of the angle; otherwise the dot product must be
     divided by the product of the lengths of both vectors to get
     the cosine of the angle. This result can further be used to
     calculate the distance of a point from a plane.
     @param
     vec Vector with which to calculate the dot product (together
     with this one).
     @return
     A float representing the dot product value.
     */
    Real dotProduct(Vector3 vec)
    {
        return x * vec.x + y * vec.y + z * vec.z;
    }

    /** Calculates the absolute dot (scalar) product of this vector with another.
     @remarks
     This function work similar dotProduct, except it use absolute value
     of each component of the vector to computing.
     @param
     vec Vector with which to calculate the absolute dot product (together
     with this one).
     @return
     A Real representing the absolute dot product value.
     */
    Real absDotProduct(Vector3 vec)
    {
        return Math.Abs(x * vec.x) + Math.Abs(y * vec.y) + Math.Abs(z * vec.z);
    }

    /** Normalises the vector.
     @remarks
     This method normalises the vector such that it's
     length / magnitude is 1. The result is called a unit vector.
     @note
     This function will not crash for zero-sized vectors, but there
     will be no changes made to their components.
     @return The previous length of the vector.
     */
    Real normalise()
    {
        Real fLength = Math.Sqrt( x * x + y * y + z * z );

        // Will also work for zero-sized vectors, but will change nothing
        // We're not using epsilons because we don't need to.
        // Read http://www.ogre3d.org/forums/viewtopic.php?f=4&t=61259
        if ( fLength > cast(Real)0.0f )
        {
            Real fInvLength = 1.0f / fLength;
            x *= fInvLength;
            y *= fInvLength;
            z *= fInvLength;
        }

        return fLength;
    }

    /** Calculates the cross-product of 2 vectors, i.e. the vector that
     lies perpendicular to them both.
     @remarks
     The cross-product is normally used to calculate the normal
     vector of a plane, by calculating the cross-product of 2
     non-equivalent vectors which lie on the plane (e.g. 2 edges
     of a triangle).
     @param rkVector
     Vector which, together with this one, will be used to
     calculate the cross-product.
     @return
     A vector which is the result of the cross-product. This
     vector will <b>NOT</b> be normalised, to maximise efficiency
     - call Vector3::normalise on the result if you wish this to
     be done. As for which side the resultant vector will be on, the
     returned vector will be on the side from which the arc from 'this'
     to rkVector is anticlockwise, e.g. UNIT_Y.crossProduct(UNIT_Z)
     = UNIT_X, whilst UNIT_Z.crossProduct(UNIT_Y) = -UNIT_X.
     This is because OGRE uses a right-handed coordinate system.
     @par
     For a clearer explanation, look a the left and the bottom edges
     of your monitor's screen. Assume that the first vector is the
     left edge and the second vector is the bottom edge, both of
     them starting from the lower-left corner of the screen. The
     resulting vector is going to be perpendicular to both of them
     and will go <i>inside</i> the screen, towards the cathode tube
     (assuming you're using a CRT monitor, of course).
     */
    Vector3 crossProduct(Vector3 rkVector ) const
    {
        return Vector3(
            y * rkVector.z - z * rkVector.y,
            z * rkVector.x - x * rkVector.z,
            x * rkVector.y - y * rkVector.x);
    }

    /** Returns a vector at a point half way between this and the passed
     in vector.
     */
    Vector3 midPoint(Vector3 vec )
    {
        return Vector3(
            ( x + vec.x ) * 0.5f,
            ( y + vec.y ) * 0.5f,
            ( z + vec.z ) * 0.5f );
    }

    //FIXME
    int opCmp (Vector3 rhs)
    {
        if( x > rhs.x && y > rhs.y && z > rhs.z )
            return 1;
        else if( x < rhs.x && y < rhs.y && z < rhs.z )
            return -1;
        return 0;
    }
    
    /** Returns true if the vector's scalar components are all greater
     that the ones of the vector it is compared against.
     * @todo D operator overloading.
     */
    bool opLessThan (Vector3 rhs )
    {
        if( x < rhs.x && y < rhs.y && z < rhs.z )
            return true;
        return false;
    }

    /** Returns true if the vector's scalar components are all smaller
     that the ones of the vector it is compared against.
     * @todo D operator overloading.
     */
    bool opGreaterThan (Vector3 rhs )
    {
        if( x > rhs.x && y > rhs.y && z > rhs.z )
            return true;
        return false;
    }

    /** Sets this vector's components to the minimum of its own and the
     ones of the passed in vector.
     @remarks
     'Minimum' in this case means the combination of the lowest
     value of x, y and z from both vectors. Lowest is taken just
     numerically, not magnitude, so -1 < 0.
     */
    void makeFloor(Vector3 cmp )
    {
        if( cmp.x < x ) x = cmp.x;
        if( cmp.y < y ) y = cmp.y;
        if( cmp.z < z ) z = cmp.z;
    }

    /** Sets this vector's components to the maximum of its own and the
     ones of the passed in vector.
     @remarks
     'Maximum' in this case means the combination of the highest
     value of x, y and z from both vectors. Highest is taken just
     numerically, not magnitude, so 1 > -3.
     */
    void makeCeil( Vector3 cmp )
    {
        if( cmp.x > x ) x = cmp.x;
        if( cmp.y > y ) y = cmp.y;
        if( cmp.z > z ) z = cmp.z;
    }

    /** Generates a vector perpendicular to this vector (eg an 'up' vector).
     @remarks
     This method will return a vector which is perpendicular to this
     vector. There are an infinite number of possibilities but this
     method will guarantee to generate one of them. If you need more
     control you should use the Quaternion class.
     */
    Vector3 perpendicular()
    {
        static Real fSquareZero = cast(Real)(1e-06 * 1e-06);

        Vector3 perp = this.crossProduct( UNIT_X );

        // Check length
        if( perp.squaredLength() < fSquareZero )
        {
            /* This vector is the Y axis multiplied by a scalar, so we have
             to use another axis.
             */
            perp = this.crossProduct( UNIT_Y );
        }
        perp.normalise();

        return perp;
    }
    /** Generates a new random vector which deviates from this vector by a
     given angle in a random direction.
     @remarks
     This method assumes that the random number generator has already
     been seeded appropriately.
     @param
     angle The angle at which to deviate
     @param
     up Any vector perpendicular to this one (which could generated
     by cross-product of this vector and any other non-colinear
     vector). If you choose not to provide this the function will
     derive one on it's own, however if you provide one yourself the
     function will be faster (this allows you to reuse up vectors if
     you call this method more than once)
     @return
     A random vector which deviates from this vector by angle. This
     vector will not be normalised, normalise it if you wish
     afterwards.
     */
    Vector3 randomDeviant(
        Radian angle,
        Vector3 up = ZERO )
    {
        Vector3 newUp;

        if (up == ZERO)
        {
            // Generate an up vector
            newUp = this.perpendicular();
        }
        else
        {
            newUp = up;
        }

        // Rotate up vector by random amount around this
        Quaternion q = Quaternion();
        Radian r = Radian(Math.UnitRandom() * Math.TWO_PI);
        q.FromAngleAxis( r, this );
        newUp = q * newUp;

        // Finally rotate this by given angle around randomised up
        q.FromAngleAxis( angle, newUp );
        return q * this;
    }

    /** Gets the angle between 2 vectors.
     @remarks
     Vectors do not have to be unit-length but must represent directions.
     */
    Radian angleBetween(Vector3 dest)
    {
        Real lenProduct = length() * dest.length();

        // Divide by zero check
        if(lenProduct < 1e-6f)
            lenProduct = 1e-6f;

        Real f = dotProduct(dest) / lenProduct;

        f = Math.Clamp(f, cast(Real)-1.0, cast(Real)1.0);
        return Math.ACos(f);

    }
    /** Gets the shortest arc quaternion to rotate this vector to the destination
     vector.
     @remarks
     If you call this with a dest vector that is close to the inverse
     of this vector, we will rotate 180 degrees around the 'fallbackAxis'
     (if specified, or a generated axis if not) since in this case
     ANY axis of rotation is valid.
     */
    Quaternion getRotationTo(Vector3 dest,
                             Vector3 fallbackAxis = ZERO) const
    {
        // Based on Stan Melax's article in Game Programming Gems
        Quaternion q;
        // Copy, since cannot modify local
        Vector3 v0 = this;//.copy();
        Vector3 v1 = dest;//.copy();
        v0.normalise();
        v1.normalise();

        Real d = v0.dotProduct(v1);
        // If dot == 1, vectors are the same
        if (d >= 1.0f)
        {
            return Quaternion.IDENTITY;
        }
        if (d < (1e-6f - 1.0f))
        {
            if (fallbackAxis != ZERO)
            {
                // rotate 180 degrees about the fallback axis
                Radian r = Radian(Math.PI);
                q.FromAngleAxis(r, fallbackAxis);
            }
            else
            {
                // Generate an axis
                Vector3 axis = UNIT_X.crossProduct(this);
                if (axis.isZeroLength()) // pick another if colinear
                    axis = UNIT_Y.crossProduct(this);
                axis.normalise();
                Radian r = Radian(Math.PI);
                q.FromAngleAxis(r, axis);
            }
        }
        else
        {
            Real s = Math.Sqrt( (1+d)*2 );
            Real invs = 1 / s;

            Vector3 c = v0.crossProduct(v1);

            q.x = c.x * invs;
            q.y = c.y * invs;
            q.z = c.z * invs;
            q.w = s * 0.5f;
            q.normalise();
        }
        return q;
    }

    /** Returns true if this vector is zero length. */
    bool isZeroLength()
    {
        Real sqlen = (x * x) + (y * y) + (z * z);
        return (sqlen < (1e-06 * 1e-06));

    }

    /** As normalise, except that this vector is unaffected and the
     normalised vector is returned as a copy. */
    Vector3 normalisedCopy()
    {
        //Vector3 ret = this;
        Vector3 ret = Vector3(x, y, z);
        ret.normalise();
        return ret;
    }

    /** Calculates a reflection vector to the plane with the given normal .
     @remarks NB assumes 'this' is pointing AWAY FROM the plane, invert if it is not.
     */
    Vector3 reflect(Vector3 normal)
    {
        return this - ( 2 * this.dotProduct(normal) * normal );
        //return Vector3( this - ( 2 * this.dotProduct(normal) * normal ) );
    }

    /** Returns whether this vector is within a positional tolerance
     of another vector.
     @param rhs The vector to compare with
     @param tolerance The amount that each element of the vector may vary by
     and still be considered equal
     */
    bool positionEquals(Vector3 rhs, Real tolerance = 1e-03)
    {
        return Math.RealEqual(x, rhs.x, tolerance) &&
            Math.RealEqual(y, rhs.y, tolerance) &&
                Math.RealEqual(z, rhs.z, tolerance);

    }

    /** Returns whether this vector is within a positional tolerance
     of another vector, also take scale of the vectors into account.
     @param rhs The vector to compare with
     @param tolerance The amount (related to the scale of vectors) that distance
     of the vector may vary by and still be considered close
     */
    bool positionCloses(ref Vector3 rhs, Real tolerance = 1e-03f)
    {
        return squaredDistance(rhs) <=
            (squaredLength() + rhs.squaredLength()) * tolerance;
    }

    /** Returns whether this vector is within a directional tolerance
     of another vector.
     @param rhs The vector to compare with
     @param tolerance The maximum angle by which the vectors may vary and
     still be considered equal
     @note Both vectors should be normalised.
     */
    bool directionEquals(Vector3 rhs,
                         Radian tolerance)
    {
        Real dot = dotProduct(rhs);
        Radian angle = Math.ACos(dot);

        return Math.Abs(angle.valueRadians()) <= tolerance.valueRadians();

    }

    /// Check whether this vector contains valid values
    bool isNaN()
    {
        return Math.isNaN(x) || Math.isNaN(y) || Math.isNaN(z);
    }

    /// Extract the primary (dominant) axis from this direction vector
    Vector3 primaryAxis()
    {
        Real absx = Math.Abs(x);
        Real absy = Math.Abs(y);
        Real absz = Math.Abs(z);
        if (absx > absy)
            if (absx > absz)
                return x > 0 ? UNIT_X : NEGATIVE_UNIT_X;
        else
            return z > 0 ? UNIT_Z : NEGATIVE_UNIT_Z;
        else // absx <= absy
            if (absy > absz)
                return y > 0 ? UNIT_Y : NEGATIVE_UNIT_Y;
        else
            return z > 0 ? UNIT_Z : NEGATIVE_UNIT_Z;
    }

    Vector3 copy()
    {
        return Vector3(x, y, z);
    }

    /** Function for writing to a stream.
     */
    string toString()
    {
        return "Vector3(" 
            ~ std.conv.to!string(x) ~ ", " 
                ~ std.conv.to!string(y) ~ ", " 
                ~ std.conv.to!string(z) ~ ")";
    }
    
    unittest
    {
        import std.stdio;
        Vector3 vec0 = Vector3(1f,2f,3f);
        Vector3 vec1 = Vector3(3f,2f,1f);
        Vector3 vec2 = vec0 + vec1;
        vec0 *= 2f;
        vec1 /= 2f;
        //writeln(vec0);
        //writeln(vec1);
        assert(vec2 == Vector3(4,4,4));
    }
}

/** 4-dimensional homogeneous vector.
 */
struct Vector4
{
public:
    //union
    //{
    //  Real x, y, z, w;
    Real[4] xyzw;
    //}
    immutable static Vector4 ZERO = Vector4( 0, 0, 0, 0 );
    
public:
    @property Real x() {return xyzw[0];}
    @property Real y() {return xyzw[1];}
    @property Real z() {return xyzw[2];}
    @property Real w() {return xyzw[3];}

    @property void x(Real v) {xyzw[0]=v;}
    @property void y(Real v) {xyzw[1]=v;}
    @property void z(Real v) {xyzw[2]=v;}
    @property void w(Real v) {xyzw[3]=v;}

    /*this()
     {
     }
     
     static this()
     {
     ZERO = Vector4( 0, 0, 0, 0 );
     }*/

    this(Real fX,Real fY,Real fZ,Real fW )
    {
        x = fX;
        y = fY;
        z = fZ;
        w = fW;
    }

    this(Real afCoordinate[4] )
    {
        x = afCoordinate[0];
        y = afCoordinate[1];
        z = afCoordinate[2];
        w = afCoordinate[3];
    }

    this(int afCoordinate[4] )
    {
        x = cast(Real)afCoordinate[0];
        y = cast(Real)afCoordinate[1];
        z = cast(Real)afCoordinate[2];
        w = cast(Real)afCoordinate[3];
    }

    this(Real* r )
    {
        x = r[0];
        y = r[1];
        z = r[2];
        w = r[3];
    }

    this(Real[] r )
    {
        x = r[0];
        y = r[1];
        z = r[2];
        w = r[3];
    }

    this(Real scaler )
    {
        x = scaler;
        y = scaler;
        z = scaler;
        w = scaler;
    }

    this(Vector3 rhs)
    {
        x = rhs.x;
        y = rhs.y;
        z = rhs.z;
        w = 1.0f;
    }

    /** Exchange the contents of this vector with another. 
     */
    void swap(Vector4 other)
    {
        std.algorithm.swap(xyzw, other.xyzw);
        //std.algorithm.swap(x, other.x);
        //std.algorithm.swap(y, other.y);
        //std.algorithm.swap(z, other.z);
        //std.algorithm.swap(w, other.w);
    }

    /** @todo opIndex*/
    Real opIndex (size_t i )
    {
        assert( i < 4 );

        //return *(&x+i);
        //return this.tupleof[i];
        return [x,y,z,w][i];
    }

    Real opIndexAssign (Real val, size_t i)
    {
        assert( i < 4 );
        
        //return *(&x+i);
        //return this.tupleof[i];
        xyzw[i] = val;
        return xyzw[i];
    }

    /*Real& operator [] (size_t i )
     {
     assert( i < 4 );

     return *(&x+i);
     }*/

    /// Pointer accessor for direct copying
    @property
    Real* ptr()
    {
        return xyzw.ptr;
    }

    /** Assigns the value of the other vector.
     @param
     rkVector The other vector
     */
    Vector4 opAssign (Vector4 rkVector )
    {
        x = rkVector.x;
        y = rkVector.y;
        z = rkVector.z;
        w = rkVector.w;

        return this;
    }

    Vector4 opAssign (Real fScalar)
    {
        x = fScalar;
        y = fScalar;
        z = fScalar;
        w = fScalar;
        return this;
    }

    bool opEquals (Vector4 rkVector ) const
    {
        return xyzw == rkVector.xyzw;
        /*return ( x == rkVector.x &&
                y == rkVector.y &&
                z == rkVector.z &&
                w == rkVector.w );*/
    }

    /*bool operator != (Vector4 rkVector )
     {
     return ( x != rkVector.x ||
     y != rkVector.y ||
     z != rkVector.z ||
     w != rkVector.w );
     }*/

    Vector4 opAssign (Vector3 rhs)
    {
        x = rhs.x;
        y = rhs.y;
        z = rhs.z;
        w = 1.0f;
        return this;
    }

    // arithmetic operations
    Vector4 opAdd (Vector4 rkVector )
    {
        return Vector4(
            x + rkVector.x,
            y + rkVector.y,
            z + rkVector.z,
            w + rkVector.w);
    }

    Vector4 opSub (Vector4 rkVector )
    {
        return Vector4(
            x - rkVector.x,
            y - rkVector.y,
            z - rkVector.z,
            w - rkVector.w);
    }

    Vector4 opMul (Real fScalar )
    {
        return Vector4(
            x * fScalar,
            y * fScalar,
            z * fScalar,
            w * fScalar);
    }

    Vector4 opMul (Vector4 rhs)
    {
        return Vector4(
            rhs.x * x,
            rhs.y * y,
            rhs.z * z,
            rhs.w * w);
    }

    Vector4 opDiv (Real fScalar )
    {
        assert( fScalar != 0.0 );

        Real fInv = 1.0f / fScalar;

        return Vector4(
            x * fInv,
            y * fInv,
            z * fInv,
            w * fInv);
    }

    Vector4 opDiv_r (Real fScalar)
    {
        return Vector4(
            fScalar / x,
            fScalar / y,
            fScalar / z,
            fScalar / w);
    }

    Vector4 opDiv (Vector4 rhs)
    {
        return Vector4(
            x / rhs.x,
            y / rhs.y,
            z / rhs.z,
            w / rhs.w);
    }

    Vector4 opUnary(string op)
    {
        if (op == "-")
            return Vector4(-x, -y, -z, -w);
        else if (op == "+")
            return this;
        assert(0);
    }
    /*
     friend Vector4 operator * (Real fScalar,Vector4 rkVector )
     {
     return Vector4(
     fScalar * rkVector.x,
     fScalar * rkVector.y,
     fScalar * rkVector.z,
     fScalar * rkVector.w);
     }

     friend Vector4 opDiv (Real fScalar,Vector4 rkVector )
     {
     return Vector4(
     fScalar / rkVector.x,
     fScalar / rkVector.y,
     fScalar / rkVector.z,
     fScalar / rkVector.w);
     }

     friend Vector4 operator + (Vector4 lhs,Real rhs)
     {
     return Vector4(
     lhs.x + rhs,
     lhs.y + rhs,
     lhs.z + rhs,
     lhs.w + rhs);
     }

     friend Vector4 operator + (Real lhs,Vector4 rhs)
     {
     return Vector4(
     lhs + rhs.x,
     lhs + rhs.y,
     lhs + rhs.z,
     lhs + rhs.w);
     }

     friend Vector4 operator - (Vector4 lhs, Real rhs)
     {
     return Vector4(
     lhs.x - rhs,
     lhs.y - rhs,
     lhs.z - rhs,
     lhs.w - rhs);
     }

     friend Vector4 operator - (Real lhs,Vector4 rhs)
     {
     return Vector4(
     lhs - rhs.x,
     lhs - rhs.y,
     lhs - rhs.z,
     lhs - rhs.w);
     }
     */
    // arithmetic updates
    Vector4 opAddAssign (Vector4 rkVector )
    {
        xyzw[0] += rkVector.x;
        xyzw[1] += rkVector.y;
        xyzw[2] += rkVector.z;
        xyzw[3] += rkVector.w;

        return this;
    }

    Vector4 opSubAssign (Vector4 rkVector )
    {
        xyzw[0] -= rkVector.x;
        xyzw[1] -= rkVector.y;
        xyzw[2] -= rkVector.z;
        xyzw[3] -= rkVector.w;

        return this;
    }

    Vector4 opMulAssign (Real fScalar )
    {
        xyzw[0] *= fScalar;
        xyzw[1] *= fScalar;
        xyzw[2] *= fScalar;
        xyzw[3] *= fScalar;
        return this;
    }

    Vector4 opAddAssign (Real fScalar )
    {
        xyzw[0] += fScalar;
        xyzw[1] += fScalar;
        xyzw[2] += fScalar;
        xyzw[3] += fScalar;
        return this;
    }

    Vector4 opSubAssign (Real fScalar )
    {
        xyzw[0] -= fScalar;
        xyzw[1] -= fScalar;
        xyzw[2] -= fScalar;
        xyzw[3] -= fScalar;
        return this;
    }

    Vector4 opMulAssign (Vector4 rkVector )
    {
        xyzw[0] *= rkVector.x;
        xyzw[1] *= rkVector.y;
        xyzw[2] *= rkVector.z;
        xyzw[3] *= rkVector.w;

        return this;
    }

    Vector4 opDivAssign (Real fScalar )
    {
        assert( fScalar != 0.0 );

        Real fInv = 1.0f / fScalar;

        xyzw[0] *= fInv;
        xyzw[1] *= fInv;
        xyzw[2] *= fInv;
        xyzw[3] *= fInv;

        return this;
    }

    Vector4 opDivAssign (Vector4 rkVector )
    {
        xyzw[0] /= rkVector.x;
        xyzw[1] /= rkVector.y;
        xyzw[2] /= rkVector.z;
        xyzw[3] /= rkVector.w;

        return this;
    }

    /** Calculates the dot (scalar) product of this vector with another.
     @param
     vec Vector with which to calculate the dot product (together
     with this one).
     @return
     A float representing the dot product value.
     */
    Real dotProduct(Vector4 vec)
    {
        return x * vec.x + y * vec.y + z * vec.z + w * vec.w;
    }
    /// Check whether this vector contains valid values
    bool isNaN()
    {
        return Math.isNaN(x) || Math.isNaN(y) || Math.isNaN(z) || Math.isNaN(w);
    }

    string to(T: string)()
    {
        return toString();
    }

    /** Function for writing to a stream.
     */
    string toString()
    {
        return "Vector4("
            ~ std.conv.to!string(x) ~ ", "
                ~ std.conv.to!string(y) ~ ", "
                ~ std.conv.to!string(z) ~ ", "
                ~ std.conv.to!string(w) ~ ")";
    }
}

/** @} */
/** @} */
