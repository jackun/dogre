module ogre.scene.simplerenderable;
import ogre.math.matrix;
import ogre.math.axisalignedbox;
import ogre.rendersystem.renderqueue;
import ogre.materials.materialmanager;
import ogre.compat;
import ogre.scene.movableobject;
import ogre.scene.renderable;
import ogre.sharedptr;

/** Simple implementation of MovableObject and Renderable for single-part custom objects. 
    @see ManualObject for a simpler interface with more flexibility
    */
class SimpleRenderable : MovableObject, Renderable
{
    mixin Renderable.Renderable_Impl!();
    //FIXME Little clashing with Renderable interface and MovableObject
    mixin Renderable.Renderable_Any_Impl;
    
protected:
    RenderOperation mRenderOp;
    
    Matrix4 mWorldTransform;
    AxisAlignedBox mBox;
    
    string mMatName;
    SharedPtr!Material mMaterial;
    
    /// The scene manager for the current frame.
    SceneManager mParentSceneManager;
    
    /// The camera for the current frame.
    Camera mCamera;
    
    /// Static member used to automatically generate names for SimpleRendaerable objects.
    static uint msGenNameCount = 0;
    
public:
    /// Constructor
    this()
    {
        mWorldTransform = Matrix4.IDENTITY;
        mMatName = "BaseWhite";
        mMaterial = MaterialManager.getSingleton().getByName("BaseWhite");
        mParentSceneManager = null;
        mCamera = null;
        // Generate name
        mName = std.conv.text("SimpleRenderable", msGenNameCount++);
        //FIXME mRenderOp supposed to be assigned or create default too?
        mRenderOp = new RenderOperation;
    }
    
    /// Named constructor
    this(string name)
    {
        super(name);
        mWorldTransform = Matrix4.IDENTITY;
        mMatName = "BaseWhite";
        mMaterial = MaterialManager.getSingleton().getByName("BaseWhite");
        mParentSceneManager = null;
        mCamera = null;
        // Generate name
        mName = name;
        //FIXME mRenderOp supposed to be assigned or create default too?
        mRenderOp = new RenderOperation;
    }
    
    ~this() { DestroyRenderable();}
    
    void setMaterial(string matName )
    {
        mMatName = matName;
        mMaterial = MaterialManager.getSingleton().getByName(mMatName);
        if (mMaterial.isNull())
            throw new ItemNotFoundError( "Could not find material " ~ mMatName,
                                        "SimpleRenderable.setMaterial" );
        
        // Won't load twice anyway
        mMaterial.getAs().load();
    }
    SharedPtr!Material getMaterial()
    {
        return mMaterial;
    }
    
    void setRenderOperation(RenderOperation rend )
    {
        mRenderOp = rend;
    }
    
    void getRenderOperation(ref RenderOperation op)
    {
        op = mRenderOp;
    }
    
    void setWorldTransform( ref Matrix4 xform )
    {
        mWorldTransform = xform;
    }
    
    void getWorldTransforms( ref Matrix4[] xform )
    {
        xform.insertOrReplace(mWorldTransform * mParentNode._getFullTransform());
    }
    
    override void _notifyCurrentCamera(Camera cam)
    {
        super._notifyCurrentCamera(cam);
        mCamera = cam;
    }
    
    void setBoundingBox( AxisAlignedBox box )
    {
        mBox = box;
    }
    
    override AxisAlignedBox getBoundingBox()
    {
        return mBox;
    }
    
    override void _updateRenderQueue(RenderQueue queue)
    {
        queue.addRenderable( this, mRenderQueueID, OGRE_RENDERABLE_DEFAULT_PRIORITY); 
    }
    
    /// @copydoc MovableObject::visitRenderables
    override void visitRenderables(Renderable.Visitor visitor, 
                                   bool debugRenderables = false)
    {
        visitor.visit(this, 0, false, Any());
    }
    
    
    /** Overridden from MovableObject */
    override string getMovableType()
    {
        immutable static string movType = "SimpleRenderable";
        return movType;
    }
    
    /** @copydoc Renderable::getLights */
    LightList getLights()
    {
        // Use movable query lights
        return queryLights();
    }

    //FIXME Little clashing with Renderable interface and MovableObject
    /*override void setUserAny(Any anything)
    {
        super.setUserAny(anything);
    }

    override ref Any getUserAny()
    {
        return super.getUserAny();
    }

    override ref UserObjectBindings getUserObjectBindings()
    {
        return super.getUserObjectBindings();
    }*/
}
