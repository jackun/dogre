module ogre.math.ray;

import ogre.compat;
import ogre.math.angles;
import ogre.math.maths;
import ogre.math.axisalignedbox;
import ogre.math.plane;
import ogre.math.sphere;
import ogre.math.vector;


/** \addtogroup Core
*  @{
*/
/** \addtogroup Math
*  @{
*/
/** Representation of a ray in space, i.e. a line with an origin and direction. */
class Ray
{
protected:
    Vector3 mOrigin;
    Vector3 mDirection;
public:
    this()
    {
        mOrigin = Vector3.ZERO;
        mDirection = Vector3.UNIT_Z;
    }
    this(ref Vector3 origin,ref Vector3 direction)
    {
        mOrigin = origin;
        mDirection = direction;
    }

    /** Sets the origin of the ray. */
    void setOrigin(ref Vector3 origin) {mOrigin = origin;} 
    /** Gets the origin of the ray. */
   Vector3 getOrigin(){return mOrigin;} 

    /** Sets the direction of the ray. */
    void setDirection(ref Vector3 dir) {mDirection = dir;} 
    /** Gets the direction of the ray. */
   Vector3 getDirection(){return mDirection;} 

    /** Gets the position of a point t units along the ray. */
    Vector3 getPoint(Real t){ 
        return mOrigin + (mDirection * t);
    }
    
    /** Gets the position of a point t units along the ray. */
    Vector3 opMul(Real t){ 
        return getPoint(t);
    }

    /** Tests whether this ray intersects the given plane. 
    @return A pair structure where the first element indicates whether
        an intersection occurs, and if true, the second element will
        indicate the distance along the ray at which it intersects. 
        This can be converted to a point in space by calling getPoint().
    */
    pair!(bool, Real) intersects(Plane p)
    {
        return Math.intersects(this, p);
    }
    /** Tests whether this ray intersects the given plane bounded volume. 
    @return A pair structure where the first element indicates whether
    an intersection occurs, and if true, the second element will
    indicate the distance along the ray at which it intersects. 
    This can be converted to a point in space by calling getPoint().
    */
    pair!(bool, Real) intersects(PlaneBoundedVolume p)
    {
        return Math.intersects(this, p.planes, p.outside == Plane.Side.POSITIVE_SIDE);
    }
    /** Tests whether this ray intersects the given sphere. 
    @return A pair structure where the first element indicates whether
        an intersection occurs, and if true, the second element will
        indicate the distance along the ray at which it intersects. 
        This can be converted to a point in space by calling getPoint().
    */
    pair!(bool, Real) intersects(Sphere s)
    {
        return Math.intersects(this, s);
    }
    /** Tests whether this ray intersects the given box. 
    @return A pair structure where the first element indicates whether
        an intersection occurs, and if true, the second element will
        indicate the distance along the ray at which it intersects. 
        This can be converted to a point in space by calling getPoint().
    */
    pair!(bool, Real) intersects(AxisAlignedBox box)
    {
        return Math.intersects(this, box);
    }

}
/** @} */
/** @} */
