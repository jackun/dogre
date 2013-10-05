module ogre.math.axisalignedbox;

import ogre.compat;
import ogre.math.vector;
import ogre.math.matrix;
import ogre.math.maths;
import ogre.math.plane;
import ogre.math.sphere;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Math
 *  @{
 */

/** A 3D box aligned with the x/y/z axes.
 @remarks
 This class represents a simple box which is aligned with the
 axes. Internally it only stores 2 points as the extremeties of
 the box, one which is the minima of all 3 axes, and the other
 which is the maxima of all 3 axes. This class is typically used
 for an axis-aligned bounding box (AABB) for collision and
 visibility determination.
 */
struct AxisAlignedBox
{
public:
    enum Extent
    {
        EXTENT_NULL,
        EXTENT_FINITE,
        EXTENT_INFINITE
    }
    //staticAxisAlignedBox BOX_NULL = AxisAlignedBox();
    //staticAxisAlignedBox BOX_INFINITE = AxisAlignedBox(Extent.EXTENT_INFINITE);
    
protected:

    Vector3 mMinimum = Vector3( -0.5, -0.5, -0.5 ); //Vector3.ZERO;
    Vector3 mMaximum = Vector3( 0.5, 0.5, 0.5 ); //Vector3.UNIT_SCALE;
    Extent mExtent = Extent.EXTENT_NULL;
    //mutable Vector3* mCorners;
    Vector3[8] mCorners;
    

public:
    /*static this()
     {
     BOX_NULL = new AxisAlignedBox();
     BOX_INFINITE = new AxisAlignedBox(Extent.EXTENT_INFINITE);
     }*/
    /*
     1-----2
     /|    /|
     / |   / |
     5-----4  |
     |  0--|--3
     | /   | /
     |/    |/
     6-----7
     */
    enum CornerEnum {
        FAR_LEFT_BOTTOM = 0,
        FAR_LEFT_TOP = 1,
        FAR_RIGHT_TOP = 2,
        FAR_RIGHT_BOTTOM = 3,
        NEAR_RIGHT_BOTTOM = 7,
        NEAR_LEFT_BOTTOM = 6,
        NEAR_LEFT_TOP = 5,
        NEAR_RIGHT_TOP = 4
    }
    
    /** @todo Cannot initialise at compile time???*/
    /*this()
     {
     mMinimum = Vector3.ZERO;
     mMaximum = Vector3.UNIT_SCALE;
     //mCorners = 0;
     // Default to a null box 
     setMinimum( -0.5, -0.5, -0.5 );
     setMaximum( 0.5, 0.5, 0.5 );
     mExtent = Extent.EXTENT_NULL;
     }*/
    //Can initialise at compile time just fine
    this(Extent e) 
    {
        mMinimum = Vector3.ZERO;
        mMaximum = Vector3.UNIT_SCALE;
        //mCorners = 0;
        setMinimum( -0.5, -0.5, -0.5 );
        setMaximum( 0.5, 0.5, 0.5 );
        mExtent = e;
    }

    this(AxisAlignedBox rkBox)
    {
        mMinimum = Vector3.ZERO;
        mMaximum = Vector3.UNIT_SCALE;
        //mCorners = 0;
        if (rkBox.isNull())
            setNull();
        else if (rkBox.isInfinite())
            setInfinite();
        else
            setExtents( rkBox.mMinimum, rkBox.mMaximum );
    }

    this(Vector3 min, Vector3 max )
    {
        mMinimum = Vector3.ZERO;
        mMaximum = Vector3.UNIT_SCALE;
        //mCorners = 0;
        setExtents( min, max );
    }

    this(
        Real mx, Real my, Real mz,
        Real Mx, Real My, Real Mz )
    {
        mMinimum = Vector3.ZERO;
        mMaximum = Vector3.UNIT_SCALE;
        //mCorners = 0;
        setExtents( mx, my, mz, Mx, My, Mz );
    }

    AxisAlignedBox opAssign(AxisAlignedBox rhs)
    {
        // Specifically override to avoid copying mCorners
        if (rhs.isNull())
            setNull();
        else if (rhs.isInfinite())
            setInfinite();
        else
            setExtents(rhs.mMinimum, rhs.mMaximum);

        return this;
    }

    ~this()
    {
        //if (mCorners)
        //    OGRE_FREE(mCorners, MEMCATEGORY_SCENE_CONTROL);
    }

    
    /** Gets the minimum corner of the box.
     */
    const(Vector3) getMinimum() const
    { 
        return mMinimum; 
    }

    /** Gets a modifiable version of the minimum
     corner of the box.
     */
    Vector3 getMinimum()
    { 
        return mMinimum; 
    }

    /** Gets the maximum corner of the box.
     */
    /*const(Vector3) getMaximum() const
    { 
        return mMaximum;
    }*/

    /** Gets a modifiable version of the maximum
     corner of the box.
     */
    Vector3 getMaximum()
    { 
        return mMaximum;
    }

    
    /** Sets the minimum corner of the box.
     */
    void setMinimum(Vector3 vec )
    {
        mExtent = Extent.EXTENT_FINITE;
        mMinimum = vec;
    }

    void setMinimum( Real x, Real y, Real z )
    {
        mExtent = Extent.EXTENT_FINITE;
        mMinimum.x = x;
        mMinimum.y = y;
        mMinimum.z = z;
    }

    /** Changes one of the components of the minimum corner of the box
     used to resize only one dimension of the box
     */
    void setMinimumX(Real x)
    {
        mMinimum.x = x;
    }

    void setMinimumY(Real y)
    {
        mMinimum.y = y;
    }

    void setMinimumZ(Real z)
    {
        mMinimum.z = z;
    }

    /** Sets the maximum corner of the box.
     */
    void setMaximum(Vector3 vec )
    {
        mExtent = Extent.EXTENT_FINITE;
        mMaximum = vec;
    }

    void setMaximum( Real x, Real y, Real z )
    {
        mExtent = Extent.EXTENT_FINITE;
        mMaximum.x = x;
        mMaximum.y = y;
        mMaximum.z = z;
    }

    /** Changes one of the components of the maximum corner of the box
     used to resize only one dimension of the box
     */
    void setMaximumX( Real x )
    {
        mMaximum.x = x;
    }

    void setMaximumY( Real y )
    {
        mMaximum.y = y;
    }

    void setMaximumZ( Real z )
    {
        mMaximum.z = z;
    }

    /** Sets both minimum and maximum extents at once.
     */
    void setExtents(Vector3 min,Vector3 max )
    {
        assert( (min.x <= max.x && min.y <= max.y && min.z <= max.z),
               "The minimum corner of the box must be less than or equal to maximum corner" );

        mExtent = Extent.EXTENT_FINITE;
        mMinimum = min;
        mMaximum = max;
    }

    void setExtents(
        Real mx, Real my, Real mz,
        Real Mx, Real My, Real Mz )
    {
        assert( (mx <= Mx && my <= My && mz <= Mz),
               "The minimum corner of the box must be less than or equal to maximum corner" );

        mExtent = Extent.EXTENT_FINITE;

        mMinimum.x = mx;
        mMinimum.y = my;
        mMinimum.z = mz;

        mMaximum.x = Mx;
        mMaximum.y = My;
        mMaximum.z = Mz;

    }

    /** Returns a pointer to an array of 8 corner points, useful for
     collision vs. non-aligned objects.
     @remarks
     If the order of these corners is important, they are as
     follows: The 4 points of the minimum Z face (note that
     because Ogre uses right-handed coordinates, the minimum Z is
     at the 'back' of the box) starting with the minimum point of
     all, then anticlockwise around this face (if you are looking
     onto the face from outside the box). Then the 4 points of the
     maximum Z face, starting with maximum point of all, then
     anticlockwise around this face (looking onto the face from
     outside the box). Like this:
     <pre>
     1-----2
     /|    /|
     / |   / |
     5-----4  |
     |  0--|--3
     | /   | /
     |/    |/
     6-----7
     </pre>
     @remarks as this implementation uses a static member, make sure to use your own copy !
     * @todo mCorners init
     */
    Vector3[] getAllCorners()
    {
        assert( (mExtent == Extent.EXTENT_FINITE), "Can't get corners of a null or infinite AAB" );

        // The order of these items is, using right-handed co-ordinates:
        // Minimum Z face, starting with Min(all), then anticlockwise
        //   around face (looking onto the face)
        // Maximum Z face, starting with Max(all), then anticlockwise
        //   around face (looking onto the face)
        // Only for optimization/compatibility.
        //if (!mCorners)
        //    mCorners = OGRE_ALLOC_T(Vector3, 8, MEMCATEGORY_SCENE_CONTROL);
        //if (mCorners is null)
        //    mCorners = Vector3[8];
        
        mCorners[0] = mMinimum.copy();
        mCorners[1].x = mMinimum.x; mCorners[1].y = mMaximum.y; mCorners[1].z = mMinimum.z;
        mCorners[2].x = mMaximum.x; mCorners[2].y = mMaximum.y; mCorners[2].z = mMinimum.z;
        mCorners[3].x = mMaximum.x; mCorners[3].y = mMinimum.y; mCorners[3].z = mMinimum.z;            

        mCorners[4] = mMaximum;
        mCorners[5].x = mMinimum.x; mCorners[5].y = mMaximum.y; mCorners[5].z = mMaximum.z;
        mCorners[6].x = mMinimum.x; mCorners[6].y = mMinimum.y; mCorners[6].z = mMaximum.z;
        mCorners[7].x = mMaximum.x; mCorners[7].y = mMinimum.y; mCorners[7].z = mMaximum.z;

        return mCorners;
    }

    /** gets the position of one of the corners
     */
    Vector3 getCorner(CornerEnum cornerToGet)
    {
        switch(cornerToGet)
        {
            case CornerEnum.FAR_LEFT_BOTTOM:
                return mMinimum;
            case CornerEnum.FAR_LEFT_TOP:
                return Vector3(mMinimum.x, mMaximum.y, mMinimum.z);
            case CornerEnum.FAR_RIGHT_TOP:
                return Vector3(mMaximum.x, mMaximum.y, mMinimum.z);
            case CornerEnum.FAR_RIGHT_BOTTOM:
                return Vector3(mMaximum.x, mMinimum.y, mMinimum.z);
            case CornerEnum.NEAR_RIGHT_BOTTOM:
                return Vector3(mMaximum.x, mMinimum.y, mMaximum.z);
            case CornerEnum.NEAR_LEFT_BOTTOM:
                return Vector3(mMinimum.x, mMinimum.y, mMaximum.z);
            case CornerEnum.NEAR_LEFT_TOP:
                return Vector3(mMinimum.x, mMaximum.y, mMaximum.z);
            case CornerEnum.NEAR_RIGHT_TOP:
                return mMaximum;
            default:
                return Vector3();
        }
    }

    string toString()
    {
        switch (mExtent)
        {
            case Extent.EXTENT_NULL:
                return "AxisAlignedBox(null)";

            case Extent.EXTENT_FINITE:
                return "AxisAlignedBox(min=" ~ std.conv.to!string(mMinimum) ~ ", max=" ~ std.conv.to!string(mMaximum) ~ ")";

            case Extent.EXTENT_INFINITE:
                return "AxisAlignedBox(infinite)";

            default: // shut up compiler
                assert( false, "Never reached" );
        }
    }

    /** Merges the passed in box into the current box. The result is the
     box which encompasses both.
     */
    void merge(AxisAlignedBox rhs )
    {
        // Do nothing if rhs null, or this is infinite
        if ((rhs.mExtent == Extent.EXTENT_NULL) || (mExtent == Extent.EXTENT_INFINITE))
        {
            return;
        }
        // Otherwise if rhs is infinite, make this infinite, too
        else if (rhs.mExtent == Extent.EXTENT_INFINITE)
        {
            mExtent = Extent.EXTENT_INFINITE;
        }
        // Otherwise if current null, just take rhs
        else if (mExtent == Extent.EXTENT_NULL)
        {
            setExtents(rhs.mMinimum, rhs.mMaximum);
        }
        // Otherwise merge
        else
        {
            Vector3 min = mMinimum;
            Vector3 max = mMaximum;
            max.makeCeil(rhs.mMaximum);
            min.makeFloor(rhs.mMinimum);

            setExtents(min, max);
        }

    }

    /** Extends the box to encompass the specified point (if needed).
     */
    void merge(Vector3 point )
    {
        switch (mExtent)
        {
            case Extent.EXTENT_NULL: // if null, use this point
                setExtents(point, point);
                return;

            case Extent.EXTENT_FINITE:
                mMaximum.makeCeil(point);
                mMinimum.makeFloor(point);
                return;

            case Extent.EXTENT_INFINITE: // if infinite, makes no difference
                return;
            default:
                break;
        }

        assert( false, "Never reached" );
    }

    /** Transforms the box according to the matrix supplied.
     @remarks
     By calling this method you get the axis-aligned box which
     surrounds the transformed version of this box. Therefore each
     corner of the box is transformed by the matrix, then the
     extents are mapped back onto the axes to produce another
     AABB. Useful when you have a local AABB for an object which
     is then transformed.
     */
    void transform(ref Matrix4 matrix )
    {
        // Do nothing if current null or infinite
        if( mExtent != Extent.EXTENT_FINITE )
            return;

        Vector3 oldMin, oldMax, currentCorner;

        // Getting the old values so that we can use the existing merge method.
        oldMin = mMinimum;
        oldMax = mMaximum;

        // reset
        setNull();

        // We sequentially compute the corners in the following order :
        // 0, 6, 5, 1, 2, 4 ,7 , 3
        // This sequence allows us to only change one member at a time to get at all corners.

        // For each one, we transform it using the matrix
        // Which gives the resulting point and merge the resulting point.

        // First corner 
        // min min min
        currentCorner = oldMin;
        merge( matrix * currentCorner );

        // min,min,max
        currentCorner.z = oldMax.z;
        merge( matrix * currentCorner );

        // min max max
        currentCorner.y = oldMax.y;
        merge( matrix * currentCorner );

        // min max min
        currentCorner.z = oldMin.z;
        merge( matrix * currentCorner );

        // max max min
        currentCorner.x = oldMax.x;
        merge( matrix * currentCorner );

        // max max max
        currentCorner.z = oldMax.z;
        merge( matrix * currentCorner );

        // max min max
        currentCorner.y = oldMin.y;
        merge( matrix * currentCorner );

        // max min min
        currentCorner.z = oldMin.z;
        merge( matrix * currentCorner ); 
    }

    /** Transforms the box according to the affine matrix supplied.
     @remarks
     By calling this method you get the axis-aligned box which
     surrounds the transformed version of this box. Therefore each
     corner of the box is transformed by the matrix, then the
     extents are mapped back onto the axes to produce another
     AABB. Useful when you have a local AABB for an object which
     is then transformed.
     @note
     The matrix must be an affine matrix. @see Matrix4::isAffine.
     */
    void transformAffine(Matrix4 m)
    {
        assert(m.isAffine());

        // Do nothing if current null or infinite
        if ( mExtent != Extent.EXTENT_FINITE )
            return;

        Vector3 centre = getCenter();
        Vector3 halfSize = getHalfSize();

        Vector3 newCentre = m.transformAffine(centre);
        Vector3 newHalfSize = Vector3(
            Math.Abs(m[0][0]) * halfSize.x + Math.Abs(m[0][1]) * halfSize.y + Math.Abs(m[0][2]) * halfSize.z, 
            Math.Abs(m[1][0]) * halfSize.x + Math.Abs(m[1][1]) * halfSize.y + Math.Abs(m[1][2]) * halfSize.z,
            Math.Abs(m[2][0]) * halfSize.x + Math.Abs(m[2][1]) * halfSize.y + Math.Abs(m[2][2]) * halfSize.z);

        setExtents(newCentre - newHalfSize, newCentre + newHalfSize);
    }

    /** Sets the box to a 'null' value i.e. not a box.
     */
    void setNull()
    {
        mExtent = Extent.EXTENT_NULL;
    }

    /** Returns true if the box is null i.e. empty.
     */
    bool isNull()
    {
        return (mExtent == Extent.EXTENT_NULL);
    }

    /** Returns true if the box is finite.
     */
    bool isFinite() const
    {
        return (mExtent == Extent.EXTENT_FINITE);
    }

    /** Sets the box to 'infinite'
     */
    void setInfinite()
    {
        mExtent = Extent.EXTENT_INFINITE;
    }

    /** Returns true if the box is infinite.
     */
    bool isInfinite()
    {
        return (mExtent == Extent.EXTENT_INFINITE);
    }

    /** Returns whether or not this box intersects another. */
    bool intersects(AxisAlignedBox b2)
    {
        // Early-fail for nulls
        if (this.isNull() || b2.isNull())
            return false;

        // Early-success for infinites
        if (this.isInfinite() || b2.isInfinite())
            return true;

        // Use up to 6 separating planes
        if (mMaximum.x < b2.mMinimum.x)
            return false;
        if (mMaximum.y < b2.mMinimum.y)
            return false;
        if (mMaximum.z < b2.mMinimum.z)
            return false;

        if (mMinimum.x > b2.mMaximum.x)
            return false;
        if (mMinimum.y > b2.mMaximum.y)
            return false;
        if (mMinimum.z > b2.mMaximum.z)
            return false;

        // otherwise, must be intersecting
        return true;

    }

    /// Calculate the area of intersection of this box and another
    AxisAlignedBox intersection(ref AxisAlignedBox b2)
    {
        if (this.isNull() || b2.isNull())
        {
            return AxisAlignedBox();
        }
        else if (this.isInfinite())
        {
            return b2;
        }
        else if (b2.isInfinite())
        {
            return this;
        }

        Vector3 intMin = mMinimum;
        Vector3 intMax = mMaximum;

        intMin.makeCeil(b2.getMinimum());
        intMax.makeFloor(b2.getMaximum());

        // Check intersection isn't null
        if (intMin.x < intMax.x &&
            intMin.y < intMax.y &&
            intMin.z < intMax.z)
        {
            return AxisAlignedBox(intMin, intMax);
        }

        return AxisAlignedBox();
    }

    /// Calculate the volume of this box
    Real volume()
    {
        switch (mExtent)
        {
            case Extent.EXTENT_NULL:
                return 0.0f;

            case Extent.EXTENT_FINITE:
            {
                Vector3 diff = mMaximum - mMinimum;
                return diff.x * diff.y * diff.z;
            }

            case Extent.EXTENT_INFINITE:
                return Math.POS_INFINITY;

            default: // shut up compiler
                assert( false, "Never reached" );
                return 0.0f;
        }
    }

    /** Scales the AABB by the vector given. */
    void scale(ref Vector3 s)
    {
        // Do nothing if current null or infinite
        if (mExtent != Extent.EXTENT_FINITE)
            return;

        // NB assumes centered on origin
        Vector3 min = mMinimum * s;
        Vector3 max = mMaximum * s;
        setExtents(min, max);
    }

    /** Tests whether this box intersects a sphere. */
    bool intersects(Sphere s)
    {
        return Math.intersects(s, this);
    }
    /** Tests whether this box intersects a plane. */
    bool intersects(Plane p)
    {
        return Math.intersects(p, this);
    }
    /** Tests whether the vector point is within this box. */
    bool intersects(Vector3 v)
    {
        switch (mExtent)
        {
            case Extent.EXTENT_NULL:
                return false;

            case Extent.EXTENT_FINITE:
                return(v.x >= mMinimum.x  &&  v.x <= mMaximum.x  && 
                       v.y >= mMinimum.y  &&  v.y <= mMaximum.y  && 
                       v.z >= mMinimum.z  &&  v.z <= mMaximum.z);

            case Extent.EXTENT_INFINITE:
                return true;

            default: // shut up compiler
                assert( false, "Never reached" );
                return false;
        }
    }
    /// Gets the centre of the box
    Vector3 getCenter()
    {
        assert( (mExtent == Extent.EXTENT_FINITE), "Can't get center of a null or infinite AAB" );

        return Vector3(
            (mMaximum.x + mMinimum.x) * 0.5f,
            (mMaximum.y + mMinimum.y) * 0.5f,
            (mMaximum.z + mMinimum.z) * 0.5f);
    }
    /// Gets the size of the box
    Vector3 getSize()
    {
        switch (mExtent)
        {
            case Extent.EXTENT_NULL:
                return Vector3.ZERO;

            case Extent.EXTENT_FINITE:
                return mMaximum - mMinimum;

            case Extent.EXTENT_INFINITE:
                return Vector3(
                    Math.POS_INFINITY,
                    Math.POS_INFINITY,
                    Math.POS_INFINITY);

            default: // shut up compiler
                assert( false, "Never reached" );
                return Vector3.ZERO;
        }
    }
    /// Gets the half-size of the box
    Vector3 getHalfSize()
    {
        switch (mExtent)
        {
            case Extent.EXTENT_NULL:
                return Vector3.ZERO;

            case Extent.EXTENT_FINITE:
                return (mMaximum - mMinimum) * 0.5;

            case Extent.EXTENT_INFINITE:
                return Vector3(
                    Math.POS_INFINITY,
                    Math.POS_INFINITY,
                    Math.POS_INFINITY);

            default: // shut up compiler
                assert( false, "Never reached" );
                return Vector3.ZERO;
        }
    }

    /** Tests whether the given point contained by this box.
     */
    bool contains(Vector3 v)
    {
        if (isNull())
            return false;
        if (isInfinite())
            return true;

        return mMinimum.x <= v.x && v.x <= mMaximum.x &&
            mMinimum.y <= v.y && v.y <= mMaximum.y &&
                mMinimum.z <= v.z && v.z <= mMaximum.z;
    }
    
    /** Returns the minimum distance between a given point and any part of the box. */
    Real distance(ref Vector3 v)
    {
        
        if (this.contains(v))
            return 0;
        else
        {
            Real maxDist = Real.min;

            if (v.x < mMinimum.x)
                maxDist = std.math.fmax(maxDist, mMinimum.x - v.x);
            if (v.y < mMinimum.y)
                maxDist = std.math.fmax(maxDist, mMinimum.y - v.y);
            if (v.z < mMinimum.z)
                maxDist = std.math.fmax(maxDist, mMinimum.z - v.z);
            
            if (v.x > mMaximum.x)
                maxDist = std.math.fmax(maxDist, v.x - mMaximum.x);
            if (v.y > mMaximum.y)
                maxDist = std.math.fmax(maxDist, v.y - mMaximum.y);
            if (v.z > mMaximum.z)
                maxDist = std.math.fmax(maxDist, v.z - mMaximum.z);
            
            return maxDist;
        }
    }

    /** Tests whether another box contained by this box.
     */
    bool contains(ref AxisAlignedBox other)
    {
        if (other.isNull() || this.isInfinite())
            return true;

        if (this.isNull() || other.isInfinite())
            return false;

        return this.mMinimum.x <= other.mMinimum.x &&
            this.mMinimum.y <= other.mMinimum.y &&
                this.mMinimum.z <= other.mMinimum.z &&
                other.mMaximum.x <= this.mMaximum.x &&
                other.mMaximum.y <= this.mMaximum.y &&
                other.mMaximum.z <= this.mMaximum.z;
    }

    /** Tests 2 boxes for equality.
     */
    bool opEquals (AxisAlignedBox rhs) const
    {
        if (this.mExtent != rhs.mExtent)
            return false;

        if (!this.isFinite())
            return true;

        return this.mMinimum == rhs.mMinimum &&
            this.mMaximum == rhs.mMaximum;
    }

    /** Tests 2 boxes for inequality.
     */
    /*bool operator!= (ref AxisAlignedBox rhs)
     {
     return !(*this == rhs);
     }*/
}

/** @} */
/** @} */