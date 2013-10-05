module ogre.math.plane;

//import std.container;

import ogre.compat;
import ogre.math.axisalignedbox;
import ogre.math.vector;
import ogre.math.matrix;
import ogre.math.sphere;
import ogre.math.ray;
import ogre.math.maths;

/** \addtogroup Core
*  @{
*/
/** \addtogroup Math
*  @{
*/


interface IPlane
{
    /// Can use from SomeImplClass.Side too
    enum Side
    {
        NO_SIDE,
        POSITIVE_SIDE,
        NEGATIVE_SIDE,
        BOTH_SIDE
    }
    
    Side getSide (Vector3 rkPoint);
    Side getSide (ref AxisAlignedBox rkBox);
    Side getSide (Vector3 centre,Vector3 halfSize);
    Real getDistance (Vector3 rkPoint);
    void redefine(Vector3 rkPoint0, Vector3 rkPoint1,
                 Vector3 rkPoint2);
    void redefine(Vector3 rkNormal,Vector3 rkPoint);
    Vector3 projectVector(ref Vector3 v);
    @property Vector3 Normal();
    @property Vector3 Normal(Vector3 v);
    Real normalise();
    bool opEquals(ref Plane rhs);
}

/** Defines a plane in 3D space.
    @remarks
        A plane is defined in 3D space by the equation
        Ax + By + Cz + D = 0
    @par
        This equates to a vector (the normal of the plane, whose x, y
        and z components equate to the coefficients A, B and C
        respectively), and a constant (D) which is the distance along
        the normal you have to go to move the plane back to the origin.
 */
class Plane : IPlane
{
    alias Object.opEquals opEquals;
public:

    Vector3 normal;// = Vector3.ZERO;
    Real d = 0;

    @property
    Vector3 Normal()
    {
        return normal;
    }

    @property
    Vector3 Normal(Vector3 val)
    {
        return (normal = val);
    }

    /** Default constructor - sets everything to 0.
    */
    this()
    {
        normal = Vector3.ZERO;
        d = 0.0;
    }
    //-----------------------------------------------------------------------
    this (ref Plane rhs)
    {
        normal = rhs.normal;
        d = rhs.d;
    }    
    /** Construct a plane through a normal, and a distance to move the plane along the normal.*/
    this (Vector3 rkNormal, Real fConstant)
    {
        normal = rkNormal;
        d = -fConstant;
    }
    /** Construct a plane using the 4 constants directly **/
    this (Real a, Real b, Real c, Real _d)
    {
        normal = Vector3(a, b, c); 
        d = _d;
    }
    this (Vector3 rkNormal,Vector3 rkPoint)
    {
        redefine(rkNormal, rkPoint);
    }
    this (Vector3 rkPoint0,Vector3 rkPoint1,
       Vector3 rkPoint2)
    {
        redefine(rkPoint0, rkPoint1, rkPoint2);
    }

    /** The "positive side" of the plane is the half space to which the
        plane normal points. The "negative side" is the other half
        space. The flag "no side" indicates the plane itself.
    */
    /*enum Side
    {
        NO_SIDE,
        POSITIVE_SIDE,
        NEGATIVE_SIDE,
        BOTH_SIDE
    }*/

    Side getSide (Vector3 rkPoint)
    {
        Real fDistance = getDistance(rkPoint);

        if ( fDistance < 0.0 )
            return Side.NEGATIVE_SIDE;

        if ( fDistance > 0.0 )
            return Side.POSITIVE_SIDE;

        return Side.NO_SIDE;
    }

    /**
    Returns the side where the alignedBox is. The flag BOTH_SIDE indicates an intersecting box.
    One corner ON the plane is sufficient to consider the box and the plane intersecting.
    */
    Side getSide (ref AxisAlignedBox rkBox)
    {
        if (rkBox.isNull()) 
            return Side.NO_SIDE;
        if (rkBox.isInfinite())
            return Side.BOTH_SIDE;

        return getSide(rkBox.getCenter(), rkBox.getHalfSize());
    }

    /** Returns which side of the plane that the given box lies on.
        The box is defined as centre/half-size pairs for effectively.
    @param centre The centre of the box.
    @param halfSize The half-size of the box.
    @return
        POSITIVE_SIDE if the box complete lies on the "positive side" of the plane,
        NEGATIVE_SIDE if the box complete lies on the "negative side" of the plane,
        and BOTH_SIDE if the box intersects the plane.
    */
    Side getSide (Vector3 centre,Vector3 halfSize)
    {
        // Calculate the distance between box centre and the plane
        Real dist = getDistance(centre);

        // Calculate the maximise allows absolute distance for
        // the distance between box centre and plane
        Real maxAbsDist = normal.absDotProduct(halfSize);

        if (dist < -maxAbsDist)
            return Side.NEGATIVE_SIDE;

        if (dist > +maxAbsDist)
            return Side.POSITIVE_SIDE;

        return Side.BOTH_SIDE;
    }

    /** This is a pseudodistance. The sign of the return value is
        positive if the point is on the positive side of the plane,
        negative if the point is on the negative side, and zero if the
        point is on the plane.
        @par
        The absolute value of the return value is the true distance only
        when the plane normal is a unit length vector.
    */
    Real getDistance (Vector3 rkPoint)
    {
        return normal.dotProduct(rkPoint) + d;
    }

    /** Redefine this plane based on 3 points. */
    void redefine(Vector3 rkPoint0, Vector3 rkPoint1,
       Vector3 rkPoint2)
    {
        Vector3 kEdge1 = rkPoint1 - rkPoint0;
        Vector3 kEdge2 = rkPoint2 - rkPoint0;
        normal = kEdge1.crossProduct(kEdge2);
        normal.normalise();
        d = -normal.dotProduct(rkPoint0);
    }

    /** Redefine this plane based on a normal and a point. */
    void redefine(Vector3 rkNormal, Vector3 rkPoint)
    {
        normal = rkNormal;
        d = -rkNormal.dotProduct(rkPoint);
    }

    /** Project a vector onto the plane. 
    @remarks This gives you the element of the input vector that is perpendicular 
        to the normal of the plane. You can get the element which is parallel
        to the normal of the plane by subtracting the result of this method
        from the original vector, since parallel + perpendicular = original.
    @param v The input vector
    */
    Vector3 projectVector(ref Vector3 v)
    {
        // We know plane normal is unit length, so use simple method
        Matrix3 xform;
        xform[0, 0] = 1.0f - normal.x * normal.x;
        xform[0, 1] = -normal.x * normal.y;
        xform[0, 2] = -normal.x * normal.z;
        xform[1, 0] = -normal.y * normal.x;
        xform[1, 1] = 1.0f - normal.y * normal.y;
        xform[1, 2] = -normal.y * normal.z;
        xform[2, 0] = -normal.z * normal.x;
        xform[2, 1] = -normal.z * normal.y;
        xform[2, 2] = 1.0f - normal.z * normal.z;
        return xform * v;

    }

    /** Normalises the plane.
        @remarks
            This method normalises the plane's normal and the length scale of d
            is as well.
        @note
            This function will not crash for zero-sized vectors, but there
            will be no changes made to their components.
        @return The previous length of the plane's normal.
    */
    Real normalise()
    {
        Real fLength = normal.length();

        // Will also work for zero-sized vectors, but will change nothing
        // We're not using epsilons because we don't need to.
        // Read http://www.ogre3d.org/forums/viewtopic.php?f=4&t=61259
        if ( fLength > cast(Real)(0.0f) )
        {
            Real fInvLength = 1.0f / fLength;
            normal *= fInvLength;
            d *= fInvLength;
        }

        return fLength;
    }

    /// Comparison operator
    bool opEquals(ref Plane rhs)
    {
        return (rhs.d == d && rhs.normal == normal);
    }
    /*bool operator!=(Plane& rhs)
    {
        return (rhs.d != d || rhs.normal != normal);
    }*/

    override 
    string toString()
    {
        //return "Plane(normal=" ~ std.conv.to!string(normal) ~ ", d=" ~ std.conv.to!string(d) ~ ")";
        return to!string();
    }
    
    string to(T)() if(is(T == string))
    {
        return "Plane(normal=" ~ std.conv.to!string(normal) ~ ", d=" ~ std.conv.to!string(d) ~ ")";
    }
}

//typedef vector<Plane>::type PlaneList;
alias Plane[] PlaneList;


/** Represents a convex volume bounded by planes.
    */
class PlaneBoundedVolume
{
public:
    //typedef vector<Plane>::type PlaneList;
    alias Plane[] PlaneList;
    /// Publicly accessible plane list, you can modify this direct
    PlaneList planes;
    Plane.Side outside;
    
    this() 
    {
        outside = Plane.Side.NEGATIVE_SIDE; 
    }
    
    /** Constructor, determines which side is deemed to be 'outside' */
    this(Plane.Side theOutside) 
    {
        outside = theOutside;
    }
    
    /** Intersection test with AABB
        @remarks May return false positives but will never miss an intersection.
        */
    bool intersects(AxisAlignedBox box)//
    {
        if (box.isNull()) return false;
        if (box.isInfinite()) return true;
        
        // Get centre of the box
        Vector3 centre = box.getCenter();
        // Get the half-size of the box
        Vector3 halfSize = box.getHalfSize();
        
        
        foreach (plane; planes)
        {
            auto side = plane.getSide(centre, halfSize);
            if (side == outside)
            {
                // Found a splitting plane Therefore return not intersecting
                return false;
            }
        }
        
        // couldn't find a splitting plane, assume intersecting
        return true;
        
    }
    /** Intersection test with Sphere
        @remarks May return false positives but will never miss an intersection.
        */
    bool intersects(Sphere sphere)//
    {
        foreach (plane; planes)
        {
            // Test which side of the plane the sphere is
            Real d = plane.getDistance(sphere.getCenter());
            // Negate d if planes point inwards
            if (outside == Plane.Side.NEGATIVE_SIDE) d = -d;
            
            if ( (d - sphere.getRadius()) > 0)
                return false;
        }
        
        return true;
        
    }
    
    /** Intersection test with a Ray
        @return std::pair of hit (bool) and distance
        @remarks May return false positives but will never miss an intersection.
        */
    pair!(bool, Real) intersects(Ray ray)
    {
        return Math.intersects(ray, planes, outside == Plane.Side.POSITIVE_SIDE);
    }
    
}

//typedef vector<PlaneBoundedVolume>::type PlaneBoundedVolumeList;
alias PlaneBoundedVolume[] PlaneBoundedVolumeList;
/** @} */
/** @} */
