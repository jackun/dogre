module ogre.math.sphere;

import ogre.compat;
import ogre.math.angles;
import ogre.math.maths;
import ogre.math.axisalignedbox;
import ogre.math.plane;
import ogre.math.vector;

/** \addtogroup Core
*  @{
*/
/** \addtogroup Math
*  @{
*/
/** A sphere primitive, mostly used for bounds checking. 
@remarks
    A sphere in math texts is normally represented by the function
    x^2 + y^2 + z^2 = r^2 (for sphere's centered on the origin). Ogre stores spheres
    simply as a center point and a radius.
*/
struct Sphere
{
protected:
    Real mRadius = 1f;
    Vector3 mCenter;// = Vector3.ZERO;
    /*static this()
    {
        mCenter = Vector3.ZERO;
    }*/
public:
    /** Standard constructor - creates a unit sphere around the origin.*/
    /*this()
    {
        mRadius = (1.0); mCenter = Vector3.ZERO;
    }*/
    /** Constructor allowing arbitrary spheres. 
        @param center The center point of the sphere.
        @param radius The radius of the sphere.
    */
    this(Vector3 center, Real radius)
    {
        mRadius = radius; 
        mCenter = center;
    }

    /** Returns the radius of the sphere. */
    Real getRadius(){ return mRadius; }

    /** Sets the radius of the sphere. */
    void setRadius(Real radius){ mRadius = radius; }

    /** Returns the center point of the sphere. */
   Vector3 getCenter(){ return mCenter; }

    /** Sets the center point of the sphere. */
    void setCenter(Vector3 center){ mCenter = center; }

    /** Returns whether or not this sphere intersects another sphere. */
    bool intersects(Sphere s)
    {
        return (s.mCenter - mCenter).squaredLength() <=
            Math.Sqr(s.mRadius + mRadius);
    }
    /** Returns whether or not this sphere intersects a box. */
    bool intersects( AxisAlignedBox box)
    {
        return Math.intersects(this, box);
    }
    /** Returns whether or not this sphere intersects a plane. */
    bool intersects( Plane plane)
    {
        return Math.intersects(this, plane);
    }
    /** Returns whether or not this sphere intersects a point. */
    bool intersects( Vector3 v)
    {
        return ((v - mCenter).squaredLength() <= Math.Sqr(mRadius));
    }
    /** Merges another Sphere into the current sphere */
    void merge(ref Sphere oth)
    {
        Vector3 diff =  oth.getCenter() - mCenter;
        Real lengthSq = diff.squaredLength();
        Real radiusDiff = oth.getRadius() - mRadius;
        
        // Early-out
        if (Math.Sqr(radiusDiff) >= lengthSq) 
        {
            // One fully contains the other
            if (radiusDiff <= 0.0f) 
                return; // no change
            else 
            {
                mCenter = oth.getCenter();
                mRadius = oth.getRadius();
                return;
            }
        }
        
        Real length = Math.Sqrt(lengthSq);
        
        Vector3 newCenter;
        Real newRadius;
        if ((length + oth.getRadius()) > mRadius) 
        {
            Real t = (length + radiusDiff) / (2.0f * length);
            newCenter = mCenter + diff * t;
        } 
        // otherwise, we keep our existing center
        
        newRadius = 0.5f * (length + mRadius + oth.getRadius());
        
        mCenter = newCenter;
        mRadius = newRadius;
    }
    

};
/** @} */
/** @} */