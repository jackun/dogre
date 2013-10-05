module ogre.scene.node;

//import std.container;
import std.algorithm;
import std.range;

import ogre.resources.mesh;
import ogre.compat;
import ogre.math.matrix;
import ogre.math.quaternion;
import ogre.math.maths;
import ogre.math.angles;
import ogre.materials.pass;
import ogre.materials.materialmanager;
import ogre.materials.blendmode;
import ogre.general.colourvalue;
import ogre.resources.meshmanager;
import ogre.scene.renderable;
import ogre.resources.resourcegroupmanager;
import ogre.scene.manualobject;
import ogre.sharedptr;

/** Class representing a general-purpose node an articulated scene graph.
 @remarks
 A node in the scene graph is a node in a structured tree. A node contains
 information about the transformation which will apply to
 it and all of it's children. Child nodes can have transforms of their own, which
 are combined with their parent's transformations.
 @par
 This is an abstract class - concrete classes are based on this for specific purposes,
 e.g. SceneNode, Bone
 */
class Node //: public NodeAlloc
{
public:
    /** Enumeration denoting the spaces which a transform can be relative to.
     */
    enum TransformSpace
    {
        /// Transform is relative to the local space
        TS_LOCAL,
        /// Transform is relative to the space of the parent node
        TS_PARENT,
        /// Transform is relative to world space
        TS_WORLD
    }
    
    /*typedef HashMap<string, ref Node> ChildNodeMap;
     typedef MapIterator<ChildNodeMap> ChildNodeIterator;
     typedef ConstMapIterator<ChildNodeMap> ConstChildNodeIterator;
     */
    
    alias Node[string] ChildNodeMap;
    
    /** Listener which gets called back on Node events.
     */
    interface Listener
    {
        //public:
        //this() {}
        //~this() {}
        /** Called when a node gets updated.
         @remarks
         Note that this happens when the node's derived update happens,
         not every time a method altering it's state occurs. There may 
         be several state-changing calls but only one of these calls, 
         when the node graph is fully updated.
         */
        void nodeUpdated(Node n);
        /** Node is being destroyed */
        void nodeDestroyed(Node n);
        /** Node has been attached to a parent */
        void nodeAttached(Node n);
        /** Node has been detached from a parent */
        void nodeDetached(Node n);
    }
    
    /** Inner class for displaying debug renderable for Node. */
    class DebugRenderable : Renderable//, public NodeAlloc
    {
        mixin Renderable.Renderable_Impl!();
        mixin Renderable.Renderable_Any_Impl!();
        
    protected:
        Node mParent;
        SharedPtr!Mesh mMeshPtr;
        SharedPtr!Material mMat;
        Real mScaling;
    public:
        this(ref Node parent)
        {
            string matName = "Ogre/Debug/AxesMat";
            mMat = MaterialManager.getSingleton().getByName(matName);
            if (mMat.isNull())
            {
                mMat = MaterialManager.getSingleton().create(matName, ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME);
                Pass p = mMat.getAs().getTechnique(0).getPass(0);
                p.setLightingEnabled(false);
                p.setPolygonModeOverrideable(false);
                p.setVertexColourTracking(TVC_AMBIENT);
                p.setSceneBlending(SceneBlendType.SBT_TRANSPARENT_ALPHA);
                p.setCullingMode(CullingMode.CULL_NONE);
                p.setDepthWriteEnabled(false);
            }
            
            string meshName = "Ogre/Debug/AxesMesh";
            mMeshPtr = MeshManager.getSingleton().getByName(meshName);
            if (mMeshPtr.isNull())
            {
                ManualObject mo = new ManualObject("tmp");
                mo.begin(mMat.get().getName());
                /* 3 axes, each made up of 2 of these (base plane = XY)
                 *   .------------|\
                 *   '------------|/
                 */
                mo.estimateVertexCount(7 * 2 * 3);
                mo.estimateIndexCount(3 * 2 * 3);
                Quaternion[6] quat;
                ColourValue[3] col;
                
                // x-axis
                quat[0] = Quaternion.IDENTITY;
                quat[1].FromAxes(Vector3.UNIT_X, Vector3.NEGATIVE_UNIT_Z, Vector3.UNIT_Y);
                col[0] = ColourValue.Red;
                col[0].a = 0.8;
                // y-axis
                quat[2].FromAxes(Vector3.UNIT_Y, Vector3.NEGATIVE_UNIT_X, Vector3.UNIT_Z);
                quat[3].FromAxes(Vector3.UNIT_Y, Vector3.UNIT_Z, Vector3.UNIT_X);
                col[1] = ColourValue.Green;
                col[1].a = 0.8;
                // z-axis
                quat[4].FromAxes(Vector3.UNIT_Z, Vector3.UNIT_Y, Vector3.NEGATIVE_UNIT_X);
                quat[5].FromAxes(Vector3.UNIT_Z, Vector3.UNIT_X, Vector3.UNIT_Y);
                col[2] = ColourValue.Blue;
                col[2].a = 0.8;
                
                Vector3[7] basepos = 
                    [
                     // stalk
                     Vector3(0, 0.05, 0), 
                     Vector3(0, -0.05, 0),
                     Vector3(0.7, -0.05, 0),
                     Vector3(0.7, 0.05, 0),
                     // head
                     Vector3(0.7, -0.15, 0),
                     Vector3(1, 0, 0),
                     Vector3(0.7, 0.15, 0)
                     ];
                
                
                // vertices
                // 6 arrows
                for (size_t i = 0; i < 6; ++i)
                {
                    // 7 points
                    for (size_t p = 0; p < 7; ++p)
                    {
                        Vector3 pos = quat[i] * basepos[p];
                        mo.position(pos);
                        mo.colour(col[i / 2]);
                    }
                }
                
                // indices
                // 6 arrows
                for (uint i = 0; i < 6; ++i)
                {
                    uint base = i * 7; 
                    mo.triangle(base + 0, base + 1, base + 2);
                    mo.triangle(base + 0, base + 2, base + 3);
                    mo.triangle(base + 4, base + 5, base + 6);
                }
                
                mo.end();
                
                mMeshPtr = mo.convertToMesh(meshName, ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME);
                
            }
            
        }
        //~this(){}
        override SharedPtr!Material getMaterial()//
        {
            return mMat;
        }
        override void getRenderOperation(ref RenderOperation op)
        {
            mMeshPtr.getAs().getSubMesh(0)._getRenderOperation(op);
        }
        override void getWorldTransforms(ref Matrix4[] xform)
        {
            // Assumes up to date
            insertOrReplace(xform, mParent._getFullTransform());
            if (!Math.RealEqual(mScaling, 1.0))
            {
                Matrix4 m = Matrix4.IDENTITY;
                auto s = Vector3(mScaling, mScaling, mScaling);
                m.setScale(s);
                //*xform = (*xform) * m;
                xform[0] = xform[0] * m; //TODO correct?
            }
        }
        override Real getSquaredViewDepth(Camera cam)
        {
            return mParent.getSquaredViewDepth(cam);
        }
        override LightList getLights()
        {
            // Nodes should not be lit by the scene, this will not get called
            static LightList ll;
            return ll;
        }
        void setScaling(Real s) { mScaling = s; }
    }
    
protected:
    /// Pointer to parent node
    Node mParent;
    /// Collection of pointers to direct children; hashmap for efficiency
    ChildNodeMap mChildren;
    
    //typedef set<Node*>.type ChildUpdateSet;
    alias Node[] ChildUpdateSet;
    /// List of children which need updating, used if self is not out of date but children are
    //mutable 
    ChildUpdateSet mChildrenToUpdate;
    /// Flag to indicate own transform from parent is out of date
    //mutable 
    bool mNeedParentUpdate;
    /// Flag indicating that all children need to be updated
    //mutable 
    bool mNeedChildUpdate;
    /// Flag indicating that parent has been notified about update request
    //mutable 
    bool mParentNotified ;
    /// Flag indicating that the node has been queued for update
    //mutable 
    bool mQueuedForUpdate;
    
    /// Friendly name of this node, can be automatically generated if you don't care
    string mName;
    
    /// Incremented count for next name extension
    static NameGenerator msNameGenerator;
    public static void staticThis()
    {
        msNameGenerator = new NameGenerator("Ogre/");
    }
    
    /// Stores the orientation of the node relative to it's parent.
    Quaternion mOrientation;
    
    /// Stores the position/translation of the node relative to its parent.
    Vector3 mPosition;
    
    /// Stores the scaling factor applied to this node
    Vector3 mScale;
    
    /// Stores whether this node inherits orientation from it's parent
    bool mInheritOrientation;
    
    /// Stores whether this node inherits scale from it's parent
    bool mInheritScale;
    
    /// Only available internally - notification of parent.
    void setParent(Node parent)
    {
        bool different = (parent != mParent);
        
        mParent = parent;
        // Request update from parent
        mParentNotified = false ;
        needUpdate();
        
        // Call listener (note, only called if there's something to do)
        if (mListener && different)
        {
            if (mParent)
                mListener.nodeAttached(this);
            else
                mListener.nodeDetached(this);
        }
        
    }
    
    /** Cached combined orientation.
     @par
     This member is the orientation derived by combining the
     local transformations and those of it's parents.
     This is updated when _updateFromParent is called by the
     SceneManager or the nodes parent.
     */
    //mutable 
    Quaternion mDerivedOrientation;
    
    /** Cached combined position.
     @par
     This member is the position derived by combining the
     local transformations and those of it's parents.
     This is updated when _updateFromParent is called by the
     SceneManager or the nodes parent.
     */
    //mutable 
    Vector3 mDerivedPosition;
    
    /** Cached combined scale.
     @par
     This member is the position derived by combining the
     local transformations and those of it's parents.
     This is updated when _updateFromParent is called by the
     SceneManager or the nodes parent.
     */
    //mutable 
    Vector3 mDerivedScale;
    
    /** Triggers the node to update it's combined transforms.
     @par
     This method is called internally by Ogre to ask the node
     to update it's complete transformation based on it's parents
     derived transform.
     */
    void _updateFromParent()
    {
        updateFromParentImpl();
        
        // Call listener (note, this method only called if there's something to do)
        if (mListener)
        {
            mListener.nodeUpdated(this);
        }
    }
    
    /** Class-specific implementation of _updateFromParent.
     @remarks
     Splitting the implementation of the update away from the update call
     itself allows the detail to be overridden without disrupting the 
     general sequence of updateFromParent (e.g. raising events)
     */
    void updateFromParentImpl()
    {
        if (mParent)
        {
            // Update orientation
            Quaternion parentOrientation = mParent._getDerivedOrientation();
            if (mInheritOrientation)
            {
                // Combine orientation with that of parent
                mDerivedOrientation = parentOrientation * mOrientation;
            }
            else
            {
                // No inheritance
                mDerivedOrientation = mOrientation;
            }
            
            // Update scale
            //
            Vector3 parentScale = mParent._getDerivedScale();
            if (mInheritScale)
            {
                // Scale own position by parent scale, NB just combine
                // as equivalent axes, no shearing
                mDerivedScale = parentScale * mScale;
            }
            else
            {
                // No inheritance
                mDerivedScale = mScale;
            }
            
            // Change position vector based on parent's orientation & scale
            mDerivedPosition = parentOrientation * (parentScale * mPosition);
            
            // Add altered position vector to parents
            mDerivedPosition += mParent._getDerivedPosition();
        }
        else
        {
            // Root node, no parent
            mDerivedOrientation = mOrientation;
            mDerivedPosition = mPosition;
            mDerivedScale = mScale;
        }
        
        mCachedTransformOutOfDate = true;
        mNeedParentUpdate = false;
        
    }
    
    
    /** Internal method for creating a new child node - must be overridden per subclass. */
    abstract Node createChildImpl();
    
    /** Internal method for creating a new child node - must be overridden per subclass. */
    abstract Node createChildImpl(string name);
    
    /// The position to use as a base for keyframe animation
    Vector3 mInitialPosition;
    /// The orientation to use as a base for keyframe animation
    Quaternion mInitialOrientation;
    /// The scale to use as a base for keyframe animation
    Vector3 mInitialScale;
    
    /// Cached derived transform as a 4x4 matrix
    //mutable 
    Matrix4 mCachedTransform;
    //mutable 
    bool mCachedTransformOutOfDate;
    
    /** Node listener - only one allowed (no list) for size & performance reasons. */
    Listener mListener;
    
    //typedef vector<ref Node>.type QueuedUpdates;
    alias Node[] QueuedUpdates;
    static QueuedUpdates msQueuedUpdates;
    
    DebugRenderable mDebug;
    
    /// User objects binding.
    UserObjectBindings mUserObjectBindings;
    
public:
    /** Constructor, should only be called by parent, not directly.
     @remarks
     Generates a name.
     */
    this()
    {
        mParent = null;
        mNeedParentUpdate = false;
        mNeedChildUpdate = false;
        mParentNotified = false;
        mQueuedForUpdate = false;
        mOrientation = Quaternion.IDENTITY;
        mPosition = Vector3.ZERO;
        mScale = Vector3.UNIT_SCALE;
        mInheritOrientation = true;
        mInheritScale = true;
        mDerivedOrientation = Quaternion.IDENTITY;
        mDerivedPosition = Vector3.ZERO;
        mDerivedScale = Vector3.UNIT_SCALE;
        mInitialPosition = Vector3.ZERO;
        mInitialOrientation = Quaternion.IDENTITY;
        mInitialScale = Vector3.UNIT_SCALE;
        mCachedTransformOutOfDate = true;
        mListener = null;
        mDebug = null;
        
        // Generate a name
        mName = msNameGenerator.generate();
        
        needUpdate();
        
    }
    /** Constructor, should only be called by parent, not directly.
     @remarks
     Assigned a name.
     */
    this(string name)
    {
        mParent = null;
        mNeedParentUpdate = false;
        mNeedChildUpdate = false;
        mParentNotified = false;
        mQueuedForUpdate = false;
        mName = name;
        mOrientation = Quaternion.IDENTITY;
        mPosition = Vector3.ZERO;
        mScale = Vector3.UNIT_SCALE;
        mInheritOrientation = true;
        mInheritScale = true;
        mDerivedOrientation = Quaternion.IDENTITY;
        mDerivedPosition = Vector3.ZERO;
        mDerivedScale = Vector3.UNIT_SCALE;
        mInitialPosition = Vector3.ZERO;
        mInitialOrientation = Quaternion.IDENTITY;
        mInitialScale = Vector3.UNIT_SCALE;
        mCachedTransformOutOfDate = true;
        mListener = null;
        mDebug = null;
        
        needUpdate();
        
    }
    
    ~this()
    {
        destroy(mDebug);
        mDebug = null;
        
        // Call listener (note, only called if there's something to do)
        if (mListener)
        {
            mListener.nodeDestroyed(this);
        }
        
        removeAllChildren();
        if(mParent)
            mParent.removeChild(this);
        
        if (mQueuedForUpdate)
        {
            // Erase from queued updates
            auto r = .takeOne(msQueuedUpdates.find(this));
            assert(!r.empty);
            if (!r.empty)
            {
                // Optimised algorithm to erase an element from unordered vector.
                r[0] = msQueuedUpdates.back;
                msQueuedUpdates.length --;
            }
        }
        
    }
    
    /** Returns the name of the node. */
   string getName()
    {
        return mName;
    }
    
    /** Gets this node's parent (null if this is the root).
     */
    ref Node getParent()//
    {
        return mParent;
    }
    
    /** Returns a quaternion representing the nodes orientation.
     */
    ref Quaternion getOrientation()//
    {
        return mOrientation;
    }
    
    /** Sets the orientation of this node via a quaternion.
     @remarks
     Orientations, unlike other transforms, are not always inherited by child nodes.
     Whether or not orientations affect the orientation of the child nodes depends on
     the setInheritOrientation option of the child. In some cases you want a orientating
     of a parent node to apply to a child node (e.g. where the child node is a part of
     the same object, so you want it to be the same relative orientation based on the
     parent's orientation), but not in other cases (e.g. where the child node is just
     for positioning another object, you want it to maintain it's own orientation).
     The default is to inherit as with other transforms.
     @par
     Note that rotations are oriented around the node's origin.
     */
    void setOrientation(Quaternion q )
    {
        assert(!q.isNaN() , "Invalid orientation supplied as parameter");
        mOrientation = q;
        mOrientation.normalise();
        needUpdate();
    }
    
    /** Sets the orientation of this node via quaternion parameters.
     @remarks
     Orientations, unlike other transforms, are not always inherited by child nodes.
     Whether or not orientations affect the orientation of the child nodes depends on
     the setInheritOrientation option of the child. In some cases you want a orientating
     of a parent node to apply to a child node (e.g. where the child node is a part of
     the same object, so you want it to be the same relative orientation based on the
     parent's orientation), but not in other cases (e.g. where the child node is just
     for positioning another object, you want it to maintain it's own orientation).
     The default is to inherit as with other transforms.
     @par
     Note that rotations are oriented around the node's origin.
     */
    void setOrientation( Real w, Real x, Real y, Real z)
    {
        setOrientation(Quaternion(w, x, y, z));
    }
    
    /** Resets the nodes orientation (local axes as world axes, no rotation).
     @remarks
     Orientations, unlike other transforms, are not always inherited by child nodes.
     Whether or not orientations affect the orientation of the child nodes depends on
     the setInheritOrientation option of the child. In some cases you want a orientating
     of a parent node to apply to a child node (e.g. where the child node is a part of
     the same object, so you want it to be the same relative orientation based on the
     parent's orientation), but not in other cases (e.g. where the child node is just
     for positioning another object, you want it to maintain it's own orientation).
     The default is to inherit as with other transforms.
     @par
     Note that rotations are oriented around the node's origin.
     */
    void resetOrientation()
    {
        mOrientation = Quaternion.IDENTITY;
        needUpdate();
    }
    
    /** Sets the position of the node relative to it's parent.
     */
    void setPosition(Vector3 pos)
    {
        assert(!pos.isNaN() , "Invalid vector supplied as parameter");
        mPosition = pos;
        needUpdate();
    }
    
    /** Sets the position of the node relative to it's parent.
     */
    void setPosition(Real x, Real y, Real z)
    {
        auto v = Vector3(x,y,z);
        setPosition(v);
    }
    
    /** Gets the position of the node relative to it's parent.
     */
    Vector3 getPosition()//
    {
        return mPosition;
    }
    
    /** Sets the scaling factor applied to this node.
     @remarks
     Scaling factors, unlike other transforms, are not always inherited by child nodes.
     Whether or not scalings affect the size of the child nodes depends on the setInheritScale
     option of the child. In some cases you want a scaling factor of a parent node to apply to
     a child node (e.g. where the child node is a part of the same object, so you want it to be
     the same relative size based on the parent's size), but not in other cases (e.g. where the
     child node is just for positioning another object, you want it to maintain it's own size).
     The default is to inherit as with other transforms.
     @par
     Note that like rotations, scalings are oriented around the node's origin.
     */
    void setScale(Vector3 scale)
    {
        assert(!scale.isNaN() && "Invalid vector supplied as parameter");
        mScale = scale;
        needUpdate();
    }
    
    /** Sets the scaling factor applied to this node.
     @remarks
     Scaling factors, unlike other transforms, are not always inherited by child nodes.
     Whether or not scalings affect the size of the child nodes depends on the setInheritScale
     option of the child. In some cases you want a scaling factor of a parent node to apply to
     a child node (e.g. where the child node is a part of the same object, so you want it to be
     the same relative size based on the parent's size), but not in other cases (e.g. where the
     child node is just for positioning another object, you want it to maintain it's own size).
     The default is to inherit as with other transforms.
     @par
     Note that like rotations, scalings are oriented around the node's origin.
     */
    void setScale(Real x, Real y, Real z)
    {
        setScale(Vector3(x, y, z));
    }
    
    /** Gets the scaling factor of this node.
     */
    Vector3 getScale()//
    {
        return mScale;
    }
    
    /** Tells the node whether it should inherit orientation from it's parent node.
     @remarks
     Orientations, unlike other transforms, are not always inherited by child nodes.
     Whether or not orientations affect the orientation of the child nodes depends on
     the setInheritOrientation option of the child. In some cases you want a orientating
     of a parent node to apply to a child node (e.g. where the child node is a part of
     the same object, so you want it to be the same relative orientation based on the
     parent's orientation), but not in other cases (e.g. where the child node is just
     for positioning another object, you want it to maintain it's own orientation).
     The default is to inherit as with other transforms.
     @param inherit If true, this node's orientation will be affected by its parent's orientation.
     If false, it will not be affected.
     */
    void setInheritOrientation(bool inherit)
    {
        mInheritOrientation = inherit;
        needUpdate();
    }
    
    /** Returns true if this node is affected by orientation applied to the parent node. 
     @remarks
     Orientations, unlike other transforms, are not always inherited by child nodes.
     Whether or not orientations affect the orientation of the child nodes depends on
     the setInheritOrientation option of the child. In some cases you want a orientating
     of a parent node to apply to a child node (e.g. where the child node is a part of
     the same object, so you want it to be the same relative orientation based on the
     parent's orientation), but not in other cases (e.g. where the child node is just
     for positioning another object, you want it to maintain it's own orientation).
     The default is to inherit as with other transforms.
     @remarks
     See setInheritOrientation for more info.
     */
    bool getInheritOrientation()
    {
        return mInheritOrientation;
    }
    
    /** Tells the node whether it should inherit scaling factors from it's parent node.
     @remarks
     Scaling factors, unlike other transforms, are not always inherited by child nodes.
     Whether or not scalings affect the size of the child nodes depends on the setInheritScale
     option of the child. In some cases you want a scaling factor of a parent node to apply to
     a child node (e.g. where the child node is a part of the same object, so you want it to be
     the same relative size based on the parent's size), but not in other cases (e.g. where the
     child node is just for positioning another object, you want it to maintain it's own size).
     The default is to inherit as with other transforms.
     @param inherit If true, this node's scale will be affected by its parent's scale. If false,
     it will not be affected.
     */
    void setInheritScale(bool inherit)
    {
        mInheritScale = inherit;
        needUpdate();
    }
    
    /** Returns true if this node is affected by scaling factors applied to the parent node. 
     @remarks
     See setInheritScale for more info.
     */
    bool getInheritScale()
    {
        return mInheritScale;
    }
    
    /** Scales the node, combining it's current scale with the passed in scaling factor. 
     @remarks
     This method applies an extra scaling factor to the node's existing scale, (unlike setScale
     which overwrites it) combining it's current scale with the new one. E.g. calling this 
     method twice with Vector3(2,2,2) would have the same effect as setScale(Vector3(4,4,4)) if
     the existing scale was 1.
     @par
     Note that like rotations, scalings are oriented around the node's origin.
     */
    void scale(Vector3 scale)
    {
        mScale = mScale * scale;
        needUpdate();
        
    }
    
    /** Scales the node, combining it's current scale with the passed in scaling factor. 
     @remarks
     This method applies an extra scaling factor to the node's existing scale, (unlike setScale
     which overwrites it) combining it's current scale with the new one. E.g. calling this 
     method twice with Vector3(2,2,2) would have the same effect as setScale(Vector3(4,4,4)) if
     the existing scale was 1.
     @par
     Note that like rotations, scalings are oriented around the node's origin.
     */
    void scale(Real x, Real y, Real z)
    {
        mScale.x *= x;
        mScale.y *= y;
        mScale.z *= z;
        needUpdate();
        
    }
    
    /** Moves the node along the Cartesian axes.
     @par
     This method moves the node by the supplied vector along the
     world Cartesian axes, i.e. along world x,y,z
     @param d
     Vector with x,y,z values representing the translation.
     @param relativeTo
     The space which this transform is relative to.
     */
    void translate(Vector3 d, TransformSpace relativeTo = TransformSpace.TS_PARENT)
    {
        final switch(relativeTo)
        {
            case TransformSpace.TS_LOCAL:
                // position is relative to parent so transform downwards
                mPosition += mOrientation * d;
                break;
            case TransformSpace.TS_WORLD:
                // position is relative to parent so transform upwards
                if (mParent)
                {
                    mPosition += (mParent._getDerivedOrientation().Inverse() * d)
                        / mParent._getDerivedScale();
                }
                else
                {
                    mPosition += d;
                }
                break;
            case TransformSpace.TS_PARENT:
                mPosition += d;
                break;
        }
        needUpdate();
        
    }
    /** Moves the node along the Cartesian axes.
     @par
     This method moves the node by the supplied vector along the
     world Cartesian axes, i.e. along world x,y,z
     @param x
     Real @c x value representing the translation.
     @param y
     Real @c y value representing the translation.
     @param z
     Real @c z value representing the translation.
     @param relativeTo
     The space which this transform is relative to.
     */
    void translate(Real x, Real y, Real z, TransformSpace relativeTo = TransformSpace.TS_PARENT)
    {
        auto v = Vector3(x,y,z);
        translate(v, relativeTo);
    }
    /** Moves the node along arbitrary axes.
     @remarks
     This method translates the node by a vector which is relative to
     a custom set of axes.
     @param axes
     A 3x3 Matrix containg 3 column vectors each representing the
     axes X, Y and Z respectively. In this format the standard cartesian
     axes would be expressed as:
     <pre>
     1 0 0
     0 1 0
     0 0 1
     </pre>
     i.e. the identity matrix.
     @param move
     Vector relative to the axes above.
     @param relativeTo
     The space which this transform is relative to.
     */
    void translate(Matrix3 axes, ref Vector3 move, TransformSpace relativeTo = TransformSpace.TS_PARENT)
    {
        Vector3 derived = axes * move;
        translate(derived, relativeTo);
    }
    /** Moves the node along arbitrary axes.
     @remarks
     This method translates the node by a vector which is relative to
     a custom set of axes.
     @param axes
     A 3x3 Matrix containg 3 column vectors each representing the
     axes X, Y and Z respectively. In this format the standard cartesian
     axes would be expressed as
     <pre>
     1 0 0
     0 1 0
     0 0 1
     </pre>
     i.e. the identity matrix.
     @param x
     The @c x translation component relative to the axes above.
     @param y
     The @c y translation component relative to the axes above.
     @param z
     The @c z translation component relative to the axes above.
     @param relativeTo
     The space which this transform is relative to.
     */
    void translate(Matrix3 axes, Real x, Real y, Real z, TransformSpace relativeTo = TransformSpace.TS_PARENT)
    {
        auto d = Vector3(x,y,z);
        translate(axes,d,relativeTo);
    }
    
    /** Rotate the node around the Z-axis.
     */
    void roll(Radian angle, TransformSpace relativeTo = TransformSpace.TS_LOCAL)
    {
        rotate(Vector3.UNIT_Z, angle, relativeTo);
    }
    
    /** Rotate the node around the X-axis.
     */
    void pitch(Radian angle, TransformSpace relativeTo = TransformSpace.TS_LOCAL)
    {
        rotate(Vector3.UNIT_X, angle, relativeTo);
    }
    
    /** Rotate the node around the Y-axis.
     */
    void yaw(Radian angle, TransformSpace relativeTo = TransformSpace.TS_LOCAL)
    {
        rotate(Vector3.UNIT_Y, angle, relativeTo);
        
    }
    
    /** Rotate the node around an arbitrary axis.
     */
    void rotate(Vector3 axis, ref Radian angle, TransformSpace relativeTo = TransformSpace.TS_LOCAL)
    {
        Quaternion q;
        q.FromAngleAxis(angle,axis);
        rotate(q, relativeTo);
    }
    
    /** Rotate the node around an aritrary axis using a Quarternion.
     */
    void rotate(Quaternion q, TransformSpace relativeTo = TransformSpace.TS_LOCAL)
    {
        // Normalise quaternion to avoid drift
        Quaternion qnorm = q;
        qnorm.normalise();
        
        final switch(relativeTo)
        {
            case TransformSpace.TS_PARENT:
                // Rotations are normally relative to local axes, transform up
                mOrientation = qnorm * mOrientation;
                break;
            case TransformSpace.TS_WORLD:
                // Rotations are normally relative to local axes, transform up
                mOrientation = mOrientation * _getDerivedOrientation().Inverse()
                    * qnorm * _getDerivedOrientation();
                break;
            case TransformSpace.TS_LOCAL:
                // Note the order of the mult, i.e. q comes after
                mOrientation = mOrientation * qnorm;
                break;
        }
        needUpdate();
    }
    
    /** Gets a matrix whose columns are the local axes based on
     the nodes orientation relative to it's parent. */
    Matrix3 getLocalAxes()
    {
        Vector3 axisX = Vector3.UNIT_X;
        Vector3 axisY = Vector3.UNIT_Y;
        Vector3 axisZ = Vector3.UNIT_Z;
        
        axisX = mOrientation * axisX;
        axisY = mOrientation * axisY;
        axisZ = mOrientation * axisZ;
        
        return Matrix3(axisX.x, axisY.x, axisZ.x,
                       axisX.y, axisY.y, axisZ.y,
                       axisX.z, axisY.z, axisZ.z);
    }
    
    /** Creates an unnamed new Node as a child of this node.
     @param translate
     Initial translation offset of child relative to parent
     @param rotate
     Initial rotation relative to parent
     */
    ref Node createChild(
       Vector3 translate = Vector3.ZERO, 
       Quaternion rotate = Quaternion.IDENTITY )
    {
        Node newNode = createChildImpl();
        newNode.translate(translate);
        newNode.rotate(rotate);
        this.addChild(newNode);
        
        //return newNode;
        return mChildren[newNode.getName()];
    }
    
    /** Creates a new named Node as a child of this node.
     @remarks
     This creates a child node with a given name, which allows you to look the node up from 
     the parent which holds this collection of nodes.
     @param translate
     Initial translation offset of child relative to parent
     @param rotate
     Initial rotation relative to parent
     */
    ref Node createChild(string name,Vector3 translate = Vector3.ZERO,
                        Quaternion rotate = Quaternion.IDENTITY)
    {
        Node newNode = createChildImpl(name);
        newNode.translate(translate);
        newNode.rotate(rotate);
        this.addChild(newNode);
        
        return mChildren[newNode.getName()];
    }
    
    /** Adds a (precreated) child scene node to this node. If it is attached to another node,
     it must be detached first.
     @param child The Node which is to become a child node of this one
     */
    void addChild(Node child)
    {
        if (child.mParent)
        {
            throw new InvalidParamsError(
                "Node '" ~ child.getName() ~ "' already was a child of '" ~
                child.mParent.getName() ~ "'.",
                "Node.addChild");
        }
        
        mChildren[child.getName()] = child;
        child.setParent(this);
        
    }
    
    /** Reports the number of child nodes under this one.
     */
    ushort numChildren()
    {
        return cast(ushort)( mChildren.length );
    }
    
    /** Gets a pointer to a child node.
     @remarks
     There is an alternate getChild method which returns a named child.
     */
    Node getChild(ushort index)//
    {
        if( index < mChildren.length )
        {
            //ChildNodeMap.const_iterator i = mChildren.begin();
            //while (index--) ++i;
            //return i.second;
            foreach(k, v; mChildren) //But assoc array (hashmap) is not ordered.
            {
                index--;
                if(index <= 0) return v;
            }
        }

        return null;
    }
    
    /** Gets a pointer to a named child node.
     */
    Node getChild(string name)//
    {
        auto i = name in mChildren;
        
        if (i is null)
        {
            throw new ItemNotFoundError( "Child node named " ~ name ~
                                        " does not exist.", "Node.getChild");
        }
        return *i;
        
    }
    
    /** Retrieves an iterator for efficiently looping through all children of this node.
     @remarks
     Using this is faster than repeatedly calling getChild if you want to go through
     all (or most of) the children of this node.
     Note that the returned iterator is only valid whilst no children are added or
     removed from this node. Thus you should not store this returned iterator for
     later use, nor should you add / remove children whilst iterating through it;
     store up changes for later. Note that calling methods on returned items in 
     the iterator IS allowed and does not invalidate the iterator.
     */
    //ChildNodeIterator getChildIterator();
    
    ChildNodeMap getChildren()
    {
        return mChildren;
    }
    
    /** Retrieves an iterator for efficiently looping through all children of this node.
     @remarks
     Using this is faster than repeatedly calling getChild if you want to go through
     all (or most of) the children of this node.
     Note that the returned iterator is only valid whilst no children are added or
     removed from this node. Thus you should not store this returned iterator for
     later use, nor should you add / remove children whilst iterating through it;
     store up changes for later. Note that calling methods on returned items in 
     the iterator IS allowed and does not invalidate the iterator.
     */
    //ConstChildNodeIterator getChildIterator();
    
    /** Drops the specified child from this node. 
     @remarks
     Does not delete the node, just detaches it from
     this parent, potentially to be reattached elsewhere. 
     There is also an alternate version which drops a named
     child from this node.
     @todo Fix indexing.
     */
    Node removeChild(ushort index)
    {
        Node ret;
        if (index < mChildren.length)
        {
            //ret = mChildren[mChildren.keys[index]]; //TODO Ofcourse this is totally wrong right now
            foreach(k,v; mChildren) //But assoc array (hashmap) is not ordered.
            {
                ret = v;
                index--;
                if(index <= 0) break;
            }
            //while (index--) ++i;
            //ret = i.second;
            // cancel any pending update
            cancelUpdate(ret);
            
            mChildren.remove(ret.getName());
            ret.setParent(null);
            return ret;
        }
        else
        {
            throw new InvalidParamsError(
                "Child index out of bounds.",
                "Node.getChild" );
        }
        return null;
    }
    /** Drops the specified child from this node. 
     @remarks
     Does not delete the node, just detaches it from
     this parent, potentially to be reattached elsewhere. 
     There is also an alternate version which drops a named
     child from this node.
     */
    Node removeChild(Node child)
    {
        if (child)
        {
            auto i = child.getName() in mChildren;
            // ensure it's our child
            if (i !is null && *i == child)
            {
                // cancel any pending update
                cancelUpdate(child);
                
                mChildren.remove(child.getName());
                child.setParent(null);
            }
        }
        return child;
    }
    
    /** Drops the named child from this node. 
     @remarks
     Does not delete the node, just detaches it from
     this parent, potentially to be reattached elsewhere.
     */
    Node removeChild(string name)
    {
        auto i = name in mChildren;
        
        if (i is null)
        {
            throw new ItemNotFoundError( "Child node named " ~ name ~
                                        " does not exist.", "Node.removeChild");
        }
        
        Node ret = *i;
        // Cancel any pending update
        cancelUpdate(ret);
        
        mChildren.remove(name);
        ret.setParent(null);
        
        return ret;
        
        
    }
    /** Removes all child Nodes attached to this node. Does not delete the nodes, just detaches them from
     this parent, potentially to be reattached elsewhere.
     */
    void removeAllChildren()
    {
        foreach (k,v; mChildren)
        {
            v.setParent(null);
        }
        mChildren.clear();
        mChildrenToUpdate.clear();
    }
    
    /** Sets the final world position of the node directly.
     @remarks 
     It's advisable to use the local setPosition if possible
     */
    void _setDerivedPosition(Vector3 pos)
    {
        //find where the node would end up in parent's local space
        setPosition( mParent.convertWorldToLocalPosition( pos ) );
    }
    
    /** Sets the final world orientation of the node directly.
     @remarks 
     It's advisable to use the local setOrientation if possible, this simply does
     the conversion for you.
     */
    void _setDerivedOrientation(Quaternion q)
    {
        //find where the node would end up in parent's local space
        setOrientation( mParent.convertWorldToLocalOrientation( q ) );
    }
    
    /** Gets the orientation of the node as derived from all parents.
     */
    Quaternion _getDerivedOrientation() //const
    {
        if (mNeedParentUpdate)
        {
            _updateFromParent();
        }
        return mDerivedOrientation;
    }
    
    /** Gets the position of the node as derived from all parents.
     */
    Vector3 _getDerivedPosition() //const
    {
        if (mNeedParentUpdate)
        {
            _updateFromParent();
        }
        
        return mDerivedPosition;
    }
    
    /** Gets the scaling factor of the node as derived from all parents.
     */
    Vector3 _getDerivedScale()
    {
        if (mNeedParentUpdate)
        {
            _updateFromParent();
        }
        return mDerivedScale;
    }
    
    /** Gets the full transformation matrix for this node.
     @remarks
     This method returns the full transformation matrix
     for this node, including the effect of any parent node
     transformations, provided they have been updated using the Node._update method.
     This should only be called by a SceneManager which knows the
     derived transforms have been updated before calling this method.
     Applications using Ogre should just use the relative transforms.
     */
    ref Matrix4 _getFullTransform()
    {
        if (mCachedTransformOutOfDate)
        {
            // Use derived values
            mCachedTransform.makeTransform(
                _getDerivedPosition(),
                _getDerivedScale(),
                _getDerivedOrientation());
            mCachedTransformOutOfDate = false;
        }
        return mCachedTransform;
    }
    
    /** Internal method to update the Node.
     @note
     Updates this node and any relevant children to incorporate transforms etc.
     Don't call this yourself unless you are writing a SceneManager implementation.
     @param updateChildren
     If @c true, the update cascades down to all children. Specify false if you wish to
     update children separately, e.g. because of a more selective SceneManager implementation.
     @param parentHasChanged
     This flag indicates that the parent transform has changed,
     so the child should retrieve the parent's transform and combine
     it with its own even if it hasn't changed itself.
     */
    void _update(bool updateChildren, bool parentHasChanged)
    {
        // always clear information about parent notification
        mParentNotified = false;
        
        // See if we should process everyone
        if (mNeedParentUpdate || parentHasChanged)
        {
            // Update transforms from parent
            _updateFromParent();
        }
        
        if(updateChildren)
        {
            if (mNeedChildUpdate || parentHasChanged)
            {
                foreach (k, child; mChildren)
                {
                    child._update(true, true);
                }
            }
            else
            {
                // Just update selected children
                foreach(child; mChildrenToUpdate)
                {
                    child._update(true, false);
                }
                
            }
            
            mChildrenToUpdate.clear();
            mNeedChildUpdate = false;
        }
    }
    
    /** Sets a listener for this Node.
     @remarks
     Note for size and performance reasons only one listener per node is
     allowed.
     */
    void setListener(Listener listener) { mListener = listener; }
    
    /** Gets the current listener for this Node.
     */
    ref Listener getListener(){ return mListener; }
    
    
    /** Sets the current transform of this node to be the 'initial state' ie that
     position / orientation / scale to be used as a basis for delta values used
     in keyframe animation.
     @remarks
     You never need to call this method unless you plan to animate this node. If you do
     plan to animate it, call this method once you've loaded the node with it's base state,
     ie the state on which all keyframes are based.
     @par
     If you never call this method, the initial state is the identity transform, ie do nothing.
     */
    void setInitialState()
    {
        mInitialPosition = mPosition;
        mInitialOrientation = mOrientation;
        mInitialScale = mScale;
    }
    
    /** Resets the position / orientation / scale of this node to it's initial state, see setInitialState for more info. */
    void resetToInitialState()
    {
        mPosition = mInitialPosition;
        mOrientation = mInitialOrientation;
        mScale = mInitialScale;
        
        needUpdate();
    }
    
    /** Gets the initial position of this node, see setInitialState for more info. 
     @remarks
     Also resets the cumulative animation weight used for blending.
     */
    ref Vector3 getInitialPosition()
    {
        return mInitialPosition;
    }
    
    
    /** Gets the initial orientation of this node, see setInitialState for more info. */
    ref Quaternion getInitialOrientation()
    {
        return mInitialOrientation;
        
    }
    
    /** Gets the initial position of this node, see setInitialState for more info. */
    ref Vector3 getInitialScale()
    {
        return mInitialScale;
    }
    
    /** Helper function, get the squared view depth.  */
    Real getSquaredViewDepth(Camera cam)
    {
        Vector3 diff = _getDerivedPosition() - cam.getDerivedPosition();
        
        // NB use squared length rather than real depth to avoid square root
        return diff.squaredLength();
    }
    
    /** Gets the local position, relative to this node, of the given world-space position */
    Vector3 convertWorldToLocalPosition( ref Vector3 worldPos )
    {
        if (mNeedParentUpdate)
        {
            _updateFromParent();
        }
        return mDerivedOrientation.Inverse() * (worldPos - mDerivedPosition) / mDerivedScale;
    }
    
    /** Gets the world position of a point in the node local space
     useful for simple transforms that don't require a child node.*/
    Vector3 convertLocalToWorldPosition( ref Vector3 localPos )
    {
        if (mNeedParentUpdate)
        {
            _updateFromParent();
        }
        return (mDerivedOrientation * (localPos * mDerivedScale)) + mDerivedPosition;
    }
    
    /** Gets the local orientation, relative to this node, of the given world-space orientation */
    Quaternion convertWorldToLocalOrientation( ref Quaternion worldOrientation )
    {
        if (mNeedParentUpdate)
        {
            _updateFromParent();
        }
        return mDerivedOrientation.Inverse() * worldOrientation;
    }
    
    /** Gets the world orientation of an orientation in the node local space
     useful for simple transforms that don't require a child node.*/
    Quaternion convertLocalToWorldOrientation( ref Quaternion localOrientation )
    {
        if (mNeedParentUpdate)
        {
            _updateFromParent();
        }
        return mDerivedOrientation * localOrientation;
        
    }
    /** To be called in the event of transform changes to this node that require it's recalculation.
     @remarks
     This not only tags the node state as being 'dirty', it also requests it's parent to 
     know about it's dirtiness so it will get an update next time.
     @param forceParentUpdate Even if the node thinks it has already told it's
     parent, tell it anyway
     */
    void needUpdate(bool forceParentUpdate = false)
    {
        
        mNeedParentUpdate = true;
        mNeedChildUpdate = true;
        mCachedTransformOutOfDate = true;
        
        // Make sure we're not root and parent hasn't been notified before
        if (mParent && (!mParentNotified || forceParentUpdate))
        {
            mParent.requestUpdate(this, forceParentUpdate);
            mParentNotified = true ;
        }
        
        // all children will be updated
        mChildrenToUpdate.clear();
    }
    /** Called by children to notify their parent that they need an update. 
     @param forceParentUpdate Even if the node thinks it has already told it's
     parent, tell it anyway
     */
    void requestUpdate(ref Node child, bool forceParentUpdate = false)
    {
        // If we're already going to update everything this doesn't matter
        if (mNeedChildUpdate)
        {
            return;
        }
        
        mChildrenToUpdate.insert(child);
        // Request selective update of me, if we didn't do it before
        if (mParent && (!mParentNotified || forceParentUpdate))
        {
            mParent.requestUpdate(this, forceParentUpdate);
            mParentNotified = true ;
        }
        
    }
    /** Called by children to notify their parent that they no longer need an update. */
    void cancelUpdate(ref Node child)
    {
        mChildrenToUpdate.removeFromArray(child);
        
        // Propagate this up if we're done
        if (mChildrenToUpdate.empty() && mParent && !mNeedChildUpdate)
        {
            mParent.cancelUpdate(this);
            mParentNotified = false ;
        }
    }
    
    /** Queue a 'needUpdate' call to a node safely.
     @remarks
     You can't call needUpdate() during the scene graph update, e.g. in
     response to a Node.Listener hook, because the graph is already being 
     updated, and update flag changes cannot be made reliably in that context. 
     Call this method if you need to queue a needUpdate call in this case.
     */
    static void queueNeedUpdate(Node n)
    {
        // Don't queue the node more than once
        if (!n.mQueuedForUpdate)
        {
            n.mQueuedForUpdate = true;
            msQueuedUpdates.insert(n);
        }
    }
    /** Process queued 'needUpdate' calls. */
    static void processQueuedUpdates()
    {
        foreach (ref n; msQueuedUpdates)
        {
            debug(STDERR) std.stdio.stderr.writeln("Node.processQueuedUpdates: ", n);
            // Update, and force parent update since chances are we've ended
            // up with some mixed state in there due to re-entrancy
            n.mQueuedForUpdate = false;
            n.needUpdate(true);
        }
        msQueuedUpdates.clear();
    }
    
    /** Get a debug renderable for rendering the Node.  */
    DebugRenderable getDebugRenderable(Real scaling)
    {
        if (!mDebug)
        {
            mDebug = new DebugRenderable(this);
        }
        mDebug.setScaling(scaling);
        return mDebug;
    }
    
    /** @deprecated use UserObjectBindings.setUserAny via getUserObjectBindings() instead.
     Sets any kind of user value on this object.
     @remarks
     This method allows you to associate any user value you like with 
     this Node. This can be a pointer back to one of your own
     classes for instance.
     */
    void setUserAny(Any anything) { getUserObjectBindings().setUserAny(anything); }
    
    /** @deprecated use UserObjectBindings.getUserAny via getUserObjectBindings() instead.
     Retrieves the custom user value associated with this object.
     */
    ref Any getUserAny(){ return getUserObjectBindings().getUserAny(); }
    
    /** Return an instance of user objects binding associated with this class.
     You can use it to associate one or more custom objects with this class instance.
     @see UserObjectBindings.setUserAny.
     */
    ref UserObjectBindings getUserObjectBindings() { return mUserObjectBindings; }

}
