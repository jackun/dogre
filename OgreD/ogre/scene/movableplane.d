module ogre.scene.movableplane;
import ogre.math.plane;
import ogre.math.quaternion;
import ogre.math.axisalignedbox;
import ogre.compat;
import ogre.rendersystem.renderqueue;
import ogre.scene.movableobject;
import ogre.math.vector;
import ogre.scene.camera;
import ogre.scene.renderable;

/** Definition of a Plane that may be attached to a node, and the derived
        details of it retrieved simply.
    @remarks
        This plane is not here for rendering purposes, it's to allow you to attach
        planes to the scene in order to have them move and follow nodes on their
        own, which is useful if you're using the plane for some kind of calculation,
        e.g. reflection.
    */
//TODO No multiple class inheritance, making Plane a member
class MovablePlane : MovableObject , IPlane
{
    alias Object.opEquals opEquals;

public:
    @property
    Plane plane()
    {
        return mPlane;
    }

    @property
    Vector3 Normal()
    {
        return mPlane.normal;
    }

    @property
    Vector3 Normal(Vector3 v)
    {
        return (mPlane.normal = v);
    }

protected:
    Plane mPlane; // Our plane
    //mutable 
    Plane mDerivedPlane;
    //mutable 
    Vector3 mLastTranslate;
    //mutable 
    Quaternion mLastRotate;
    AxisAlignedBox mNullBB;
    //mutable 
    bool mDirty;
    immutable static string msMovableType = "MovablePlane";
public:
    
    this(string name)
    {
        super(name);
        mLastTranslate = Vector3.ZERO;
        mLastRotate = Quaternion.IDENTITY;
        mDirty = true;
    }
    
    this (Plane rhs)
    {
        mPlane = cast(Plane)rhs;
        mLastTranslate = Vector3.ZERO;
        mLastRotate = Quaternion.IDENTITY;
        mDirty = true;
    }
    
    /** Construct a plane through a normal, and a distance to move the plane along the normal.*/
    this (Vector3 rkNormal, Real fConstant)
    {
        mPlane = new Plane (rkNormal, fConstant);
        mLastTranslate = Vector3.ZERO;
        mLastRotate = Quaternion.IDENTITY;
        mDirty = true;
    }
    
    this (Vector3 rkNormal,Vector3 rkPoint)
    {
        mPlane = new Plane(rkNormal, rkPoint);
        mLastTranslate = Vector3.ZERO;
        mLastRotate = Quaternion.IDENTITY;
        mDirty = true;
    }
    
    this (Vector3 rkPoint0,Vector3 rkPoint1,
         Vector3 rkPoint2)
    {
        mPlane = new Plane(rkPoint0, rkPoint1, rkPoint2);
        mLastTranslate = Vector3.ZERO;
        mLastRotate = Quaternion.IDENTITY;
        mDirty = true;
    }
    
    ~this() {}
    
    /// Overridden from MovableObject
    override void _notifyCurrentCamera(Camera c) { /* don't care */ }
    /// Overridden from MovableObject
    override AxisAlignedBox getBoundingBox(){ return mNullBB; }
    /// Overridden from MovableObject
    override Real getBoundingRadius(){ return 0.0f; }
    /// Overridden from MovableObject
    override void _updateRenderQueue(RenderQueue r) { /* do nothing */}
    /// Overridden from MovableObject
    override string getMovableType()
    {
        return msMovableType;
    }
    
    /// Get the derived plane as transformed by its parent node. 
    //(IPlane) _getDerivedPlane()
    Plane _getDerivedPlane()
    {
        if (mParentNode)
        {
            if (mDirty ||
                !(mParentNode._getDerivedOrientation() == mLastRotate &&
              mParentNode._getDerivedPosition() == mLastTranslate))
            {
                mLastRotate = mParentNode._getDerivedOrientation();
                mLastTranslate = mParentNode._getDerivedPosition();
                // Rotate normal
                mDerivedPlane.normal = mLastRotate * mPlane.normal;
                // d remains the same in rotation, since rotation happens first
                mDerivedPlane.d = mPlane.d;
                // Add on the effect of the translation (project onto new normal)
                mDerivedPlane.d -= mDerivedPlane.normal.dotProduct(mLastTranslate);
                
                mDirty = false;
                
            }
        }
        else
        {
            return mPlane;//NOTE Returning internal Plane instead of this MovablePlane
            //return cast(IPlane)this;
        }
        
        return mDerivedPlane;
    }
    
    /// @copydoc MovableObject::visitRenderables
    override void visitRenderables(Renderable.Visitor visitor, 
                          bool debugRenderables = false)
    {
        /* do nothing */
    }

    Vector3 getNormal()
    {
        return mPlane.normal;
    }
    /// Interface implementation
    
    Side getSide (Vector3 rkPoint){ return mPlane.getSide(rkPoint); }
    Side getSide (ref AxisAlignedBox rkBox){ return mPlane.getSide(rkBox); }
    Side getSide (Vector3 centre,Vector3 halfSize){ return mPlane.getSide(centre, halfSize); }
    Real getDistance (Vector3 rkPoint){ return mPlane.getDistance(rkPoint); }
    void redefine(Vector3 rkPoint0,Vector3 rkPoint1,
                 Vector3 rkPoint2)
    { return mPlane.redefine(rkPoint0, rkPoint1, rkPoint2); }
    void redefine(Vector3 rkNormal,Vector3 rkPoint)
    { return mPlane.redefine(rkNormal, rkPoint); }
    Vector3 projectVector(ref Vector3 v)
    { return mPlane.projectVector(v); }
    Real normalise()
    { return mPlane.normalise(); }
    bool opEquals(ref Plane rhs)
    { return mPlane.opEquals(rhs); }
}
