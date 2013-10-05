module ogre.scene.instancedentity;

private
{
    //import std.container;
    import std.array;
    import std.algorithm;
}

import ogre.animation.animations;
import ogre.math.matrix;
import ogre.resources.mesh;
import ogre.math.sphere;
import ogre.math.quaternion;
import ogre.exception;
import ogre.math.vector;
import ogre.compat;
import ogre.general.common;
import ogre.math.axisalignedbox;
import ogre.math.optimisedutil;
import ogre.math.angles;
import ogre.scene.camera;
import ogre.scene.movableobject;
import ogre.scene.skeletoninstance;
import ogre.scene.node;
import ogre.rendersystem.renderqueue;
import ogre.scene.renderable;
import ogre.scene.instancemanager;
import ogre.scene.scenenode;
import ogre.math.maths;
import ogre.rendersystem.vertex;
import ogre.rendersystem.hardware;
import ogre.general.root;
import ogre.general.log;
import ogre.resources.texture;
import ogre.resources.texturemanager;
import ogre.image.pixelformat;
import ogre.image.images;
import ogre.math.dualquaternion;
import ogre.materials.materialmanager;
import ogre.materials.pass;
import ogre.materials.textureunitstate;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Scene
 *  @{
 */

/** @see InstanceBatch to understand how instancing works.

 Instanced entities work in a very similar way as how an Entity works, as this interface
 tries to mimic it as most as possible to make the transition between Entity and InstancedEntity
 as straightforward and simple as possible.
 There are a couple inherent limitations, for example setRenderQueueGroup only works on
 the InstanceBatch level, not the individual instance. This limits Z sorting for alpha blending
 quite significantly
 An InstancedEntity won't appear in scene until a SceneNode is attached to them. Once the
 InstancedEntity is no longer needed, call InstanceBatch.removeInstancedEntity to put them
 back into a queue so the batch can return it back again when a new instance is requested.
 @par
 Internally, instanced entities that are not visible (i.e. by setting setVisible(false) or
 when they don't have a SceneNode attached to them) a Zero world matrix is sent to the vertex shader
 which in turn causes a zero area triangle.
 This obviously means no Vertex shader benefit, but saves a bit of pixel shader processing power.
 Also this means this object won't be considered when sizing the InstanceBatch's bounding box.
 @par
 Each instance has an instance ID unique within the batch, which matches the ID sent to the vertex
 shader by some techniques (like InstanceBatchShader).
 @par
 Differences between Entity and InstancedEntity:
 * Setting RenderQueueGroup and other Renderable stuff works at InstanceBatch level, not
 InstancedEntity. This is obviously a limitation from instancing in general, not this particular
 implementation

 @remarks
 Design discussion webpage
 @author
 Matias N. Goldberg ("dark_sylinc")
 @version
 1.0
 */
class InstancedEntity : MovableObject
{
    //friend class InstanceBatch;
    //friend class InstanceBatchShader;
    //friend class InstanceBatchHW;
    //friend class InstanceBatchHW_VTF;
    //friend class BaseInstanceBatchVTF;

package:
    ///For friendlies
    bool _findVisible( ref Camera camera )
    {
        return findVisible( camera );
    }

protected:
    //TODO ushort here but from everywhere else gets assigned a uint???
    ushort mInstanceId; //Note it may change after defragmenting!
    bool mInUse;
    InstanceBatch mBatchOwner;
    
    AnimationStateSet mAnimationState;
    SkeletonInstance  mSkeletonInstance;
    Matrix4[] mBoneMatrices;  //Local space
    Matrix4[] mBoneWorldMatrices; //World space
    ulong mFrameAnimationLastUpdated;
    
    InstancedEntity mSharedTransformEntity;    //When not null, another InstancedEntity controls the skeleton
    
    /** Used in conjunction with bone matrix lookup. Tells the number of the transform for
     as arranged in the vertex texture */
    ushort mTransformLookupNumber;
    
    /// Stores the master when we're the slave, store our slaves when we're the master
    //typedef vector<InstancedEntity*>.type InstancedEntityVec;
    alias InstancedEntity[] InstancedEntityVec;
    InstancedEntityVec mSharingPartners;
    
    //////////////////////////////////////////////////////////////////////////
    // Parameters used for local transformation offset information
    // The 
    //////////////////////////////////////////////////////////////////////////
    
    /// Object position
    Vector3 mPosition;
    Vector3 mDerivedLocalPosition;
    /// Object orientation
    Quaternion mOrientation;
    /// Object scale
    Vector3 mScale;
    /// The maximum absolute scale for all dimension
    Real mMaxScaleLocal;
    /// Full world transform
    Matrix4 mFullLocalTransform;
    /// Tells if mFullTransform needs an updated
    bool mNeedTransformUpdate;
    /// Tells if the animation world transform needs an update
    bool mNeedAnimTransformUpdate;
    /// Tells whether to use the local transform parameters
    bool mUseLocalTransform;
    
    
    /// Returns number of matrices written to transform, assumes transform has enough space
    size_t getTransforms( ref Matrix4[] xform )
    {
        size_t retVal = 1; //TODO With dynamic array, pretty useless
        
        //When not attached, returns zero matrix to avoid rendering this one, not identity
        if( isVisible() && isInScene() )
        {
            if( !mSkeletonInstance )
            {
                xform ~= mBatchOwner.useBoneWorldMatrices() ? 
                    _getParentNodeFullTransform() : Matrix4.IDENTITY;
            }
            else
            {
                Matrix4[] matrices = mBatchOwner.useBoneWorldMatrices() ? mBoneWorldMatrices : mBoneMatrices;
                Mesh.IndexMap indexMap = mBatchOwner._getIndexToBoneMap();
                //Mesh.IndexMap.const_iterator itor = indexMap.begin();
                //Mesh.IndexMap.const_iterator end  = indexMap.end();
                
                foreach(itor; indexMap)
                    xform ~= matrices[itor];
                
                retVal = indexMap.length;
            }
        }
        else
        {
            if( mSkeletonInstance )
                retVal = mBatchOwner._getIndexToBoneMap().length;
            
            //std.fill_n( xform, retVal, Matrix4.ZEROAFFINE );
            //TODO std.fill_n for Matrix4 array
            xform.length = retVal;
            std.algorithm.fill(xform, Matrix4.ZEROAFFINE);
        }
        
        return retVal;
    }

    /// Returns number of 32-bit values written
    //TODO Pointers to dynamic arrays or something, maybe
    size_t getTransforms3x4( ref float[] xform )
    {
        size_t retVal;
        //When not attached, returns zero matrix to avoid rendering this one, not identity
        if( isVisible() && isInScene() )
        {
            if( !mSkeletonInstance )
            {
                Matrix4 mat = mBatchOwner.useBoneWorldMatrices() ? 
                    _getParentNodeFullTransform() : Matrix4.IDENTITY;
                for( int i=0; i<3; ++i )
                {
                    Real[4] row = mat[i];
                    for( int j=0; j<4; ++j )
                        xform ~= row[j];
                }
                
                retVal = 12;
            }
            else
            {
                Matrix4[] matrices = mBatchOwner.useBoneWorldMatrices() ? mBoneWorldMatrices : mBoneMatrices;
                
                Mesh.IndexMap indexMap = mBatchOwner._getIndexToBoneMap();
                //Mesh.IndexMap.const_iterator itor = indexMap.begin();
                //Mesh.IndexMap.const_iterator end  = indexMap.end();
                
                foreach(itor; indexMap)
                {
                    Matrix4 mat = matrices[itor];
                    for( int i=0; i<3; ++i )
                    {
                        Real[4] row = mat[i];//TODO Maybe pointer, less copying?
                        for( int j=0; j<4; ++j )
                            xform ~= row[j];
                    }
                }
                
                retVal = indexMap.length * 4 * 3;
            }
        }
        else
        {
            if( mSkeletonInstance )
                retVal = mBatchOwner._getIndexToBoneMap().length * 3 * 4;
            else
                retVal = 12;
            
            //std.fill_n( xform, retVal, 0.0f );
            //TODO std.fill_n for Matrix4 array
            xform.length = retVal;
            std.algorithm.fill(xform, 0.0f);
        }
        
        return retVal;
    }

    size_t getTransforms3x4( float *xform ) //const
    {
        size_t retVal;
        //When not attached, returns zero matrix to avoid rendering this one, not identity
        if( isVisible() && isInScene() )
        {
            if( !mSkeletonInstance )
            {
                Matrix4 mat = mBatchOwner.useBoneWorldMatrices() ? 
                    _getParentNodeFullTransform() : Matrix4.IDENTITY;
                for( int i=0; i<3; ++i )
                {
                    Real[4] row = mat[i];
                    for( int j=0; j<4; ++j )
                        *xform++ = cast(float)row[j];
                }
                
                retVal = 12;
            }
            else
            {
                Matrix4[] matrices = mBatchOwner.useBoneWorldMatrices() ? mBoneWorldMatrices : mBoneMatrices;
                
                Mesh.IndexMap indexMap = mBatchOwner._getIndexToBoneMap();
                
                foreach(itor; indexMap)//TODO map ordering?
                {
                    Matrix4 mat = matrices[itor];
                    for( int i=0; i<3; ++i )
                    {
                        Real[4] row = mat[i];
                        for( int j=0; j<4; ++j )
                            *xform++ = cast(float)row[j];
                    }
                }
                
                retVal = indexMap.length * 4 * 3;
            }
        }
        else
        {
            if( mSkeletonInstance )
                retVal = mBatchOwner._getIndexToBoneMap().length * 3 * 4;
            else
                retVal = 12;

            foreach(_; 0..retVal)
                *xform++ = 0.0f;
        }
        
        return retVal;
    }
    
    /// Returns true if this InstancedObject is visible to the current camera
    bool findVisible( ref Camera camera )
    {
        //Object is active
        bool retVal = isInScene();
        if (retVal) 
        {
            //check object is explicitly visible
            retVal = isVisible();
            
            //Object's bounding box is viewed by the camera
            if( retVal && camera )
                retVal = camera.isVisible(Sphere(_getDerivedPosition(), getBoundingRadius()), null);
        }
        
        return retVal;
    }

    //TODO SIMD
    /// Creates/destroys our own skeleton, also tells slaves to unlink if we're destroying
    void createSkeletonInstance()
    {
        //Is mesh skeletally animated?
        if( mBatchOwner._getMeshRef().getAs().hasSkeleton() &&
           !mBatchOwner._getMeshRef().getAs().getSkeleton().isNull() &&
           mBatchOwner._supportsSkeletalAnimation() )
        {
            mSkeletonInstance = new SkeletonInstance( mBatchOwner._getMeshRef().getAs().getSkeleton() );
            mSkeletonInstance.load();
            
            mBoneMatrices       = new Matrix4[mSkeletonInstance.getNumBones()];
            //cast(Matrix4)(OGRE_MALLOC_SIMD( sizeof(Matrix4) *
            //                                       mSkeletonInstance.getNumBones(),
            //                                       MEMCATEGORY_ANIMATION));
            if (mBatchOwner.useBoneWorldMatrices())
            {
                mBoneWorldMatrices  = new Matrix4[mSkeletonInstance.getNumBones()]; 
                //static_cast<Matrix4*>(OGRE_MALLOC_SIMD( sizeof(Matrix4) *
                // mSkeletonInstance.getNumBones(),
                // MEMCATEGORY_ANIMATION));
            }
            
            mAnimationState = new AnimationStateSet();
            mBatchOwner._getMeshRef().getAs()._initAnimationState( mAnimationState );
        }
    }
    //TODO unnecessery nulls
    void destroySkeletonInstance()
    {
        if( mSkeletonInstance )
        {
            //Tell the ones sharing skeleton with us to use their own
            //sharing partners will remove themselves from notifyUnlink
            while( mSharingPartners.empty() == false )
            {
                mSharingPartners.front.stopSharingTransform();
            }
            mSharingPartners.clear();
            
            destroy(mSkeletonInstance);
            destroy(mAnimationState);
            destroy(mBoneMatrices);
            destroy(mBoneWorldMatrices);
            
            mSkeletonInstance   = null;
            mAnimationState     = null;
            mBoneMatrices       = null;
            mBoneWorldMatrices  = null;
        }
    }
    
    /// When this entity is a slave, stopSharingTransform delegates to this function.
    /// nofityMaster = false is used to prevent iterator invalidation in specific cases.
    void stopSharingTransformAsSlave( bool notifyMaster )
    {
        unlinkTransform( notifyMaster );
        createSkeletonInstance();
    }
    
    /// Just unlinks, and tells our master we're no longer sharing
    void unlinkTransform( bool notifyMaster=true )
    {
        if( mSharedTransformEntity )
        {
            //Tell our master we're no longer his slave
            if( notifyMaster )
                mSharedTransformEntity.notifyUnlink( this );
            mBatchOwner._markTransformSharingDirty();
            
            mSkeletonInstance   = null;
            mAnimationState     = null;
            mBoneMatrices       = null;
            mBoneWorldMatrices  = null;
            mSharedTransformEntity = null;
        }
    }
    
    /// Called when a slave has unlinked from us
    void notifyUnlink( ref InstancedEntity slave )
    {
        //Find the slave and remove it
        foreach(itor; mSharingPartners)
        {
            if( itor == slave )
            {
                std.algorithm.swap(itor, mSharingPartners.back);
                mSharingPartners.popBack();
                break;
            }
        }
    }
    
    /// Mark the transformation matrixes as dirty
    void markTransformDirty()
    {
        mNeedTransformUpdate = true;
        mNeedAnimTransformUpdate = true; 
        mBatchOwner._boundsDirty();
    }
    
    /// Incremented count for next name extension
    static NameGenerator msNameGenerator;
    
public:
    /**
     * @param sharedTransformEntity set null if none to be used.
     * */
    this( InstanceBatch batchOwner, /*uint*/ ushort instanceID, InstancedEntity sharedTransformEntity = null)
    {
        mInstanceId =  instanceID ;
        mInUse =  false ;
        mBatchOwner =  batchOwner ;
        //mAnimationState =  0 ;
        //mSkeletonInstance =  0 ;
        //mBoneMatrices = 0;
        //mBoneWorldMatrices = 0;
        mFrameAnimationLastUpdated = ulong.max - 1;
        //mSharedTransformEntity =  0 ;
        mTransformLookupNumber = instanceID;
        mPosition = Vector3.ZERO;
        mDerivedLocalPosition = Vector3.ZERO;
        mOrientation = Quaternion.IDENTITY;
        mScale = Vector3.UNIT_SCALE;
        mMaxScaleLocal = 1;
        mNeedTransformUpdate = true;
        mNeedAnimTransformUpdate = true;
        mUseLocalTransform = false;

        //Use a static name generator to ensure this name stays unique (which may not happen
        //otherwise due to reparenting when defragmenting)
        mName = std.conv.text(batchOwner.getName(), "/InstancedEntity_", mInstanceId, "/",
                              msNameGenerator.generate());
        
        if (sharedTransformEntity)
        {
            sharedTransformEntity.shareTransformWith(this);
        }
        else
        {
            createSkeletonInstance();
        }
        updateTransforms();
    }

    ~this()
    {
        unlinkTransform();
        destroySkeletonInstance();
    }
    
    /** Shares the entire transformation with another InstancedEntity. This is useful when a mesh
     has more than one submeshes, Therefore creating multiple InstanceManagers (one for each
     submesh). With this function, sharing makes the skeleton to be shared (less memory) and
     updated once (performance optimization).
     Note that one InstancedEntity (i.e. submesh 0) must be chosen as "master" which will share
     with the other instanced entities (i.e. submeshes 1-N) which are called "slaves"
     @par
     Requirements to share trasnformations:
     * Both InstancedEntities must have use the same skeleton
     * An InstancedEntity can't be both "master" and "slave" at the same time
     @remarks
     Sharing does nothing if the original mesh doesn't have a skeleton
     When an InstancedEntity is removed (@see InstanceBatch.removeInstancedEntity), it stops
     sharing the transform. If the instanced entity was the master one, all it's slaves stop
     sharing and start having their own transform too.
     @param slave The InstancedEntity that should share with us and become our slave
     @return true if successfully shared (may fail if they aren't skeletally animated)
     */
    bool shareTransformWith( ref InstancedEntity slave )
    {
        if( !this.mBatchOwner._getMeshRef().getAs().hasSkeleton() ||
           this.mBatchOwner._getMeshRef().getAs().getSkeleton().isNull() ||
           !this.mBatchOwner._supportsSkeletalAnimation() )
        {
            return false;
        }
        
        if( this.mSharedTransformEntity  )
        {
            throw new InvalidStateError("Attempted to share '" ~ mName ~ "' transforms " ~
                                        "with slave '" ~ slave.mName ~ "' but '" ~ mName ~ "' is " ~
                                        "already sharing. Hierarchical sharing not allowed.",
                                        "InstancedEntity.shareTransformWith" );
            return false;
        }
        
        if( this.mBatchOwner._getMeshRef().getAs().getSkeleton() !=
           slave.mBatchOwner._getMeshRef().getAs().getSkeleton() )
        {
            throw new InvalidStateError("Sharing transforms requires both instanced" ~
                                        " entities to have the same skeleton",
                                        "InstancedEntity.shareTransformWith" );
            return false;
        }
        
        slave.unlinkTransform();
        slave.destroySkeletonInstance();
        
        slave.mSkeletonInstance    = this.mSkeletonInstance;
        slave.mAnimationState      = this.mAnimationState;
        slave.mBoneMatrices        = this.mBoneMatrices;
        if (mBatchOwner.useBoneWorldMatrices())
        {
            slave.mBoneWorldMatrices   = this.mBoneWorldMatrices;
        }
        slave.mSharedTransformEntity = this;
        //The sharing partners are kept in the parent entity 
        this.mSharingPartners.insert( slave );
        
        slave.mBatchOwner._markTransformSharingDirty();
        
        return true;
    }
    
    /** @see shareTransformWith
     Stops sharing the transform if this is a slave, and notifies the master we're no longer
     a slave.
     If this is a master, tells all it's slave to stop sharing
     @remarks
     This function is automatically called in InstanceBatch.removeInstancedEntity
     */
    void stopSharingTransform()
    {
        if( mSharedTransformEntity )
        {
            stopSharingTransformAsSlave( true );
        }
        else
        {
            //Tell the ones sharing skeleton with us to use their own
            foreach(itor; mSharingPartners)
            {
                itor.stopSharingTransformAsSlave( false );
            }
            mSharingPartners.clear();
        }
    }
    
    ref InstanceBatch _getOwner(){ return mBatchOwner; }
    
    override string getMovableType()
    {
        static string sType = "InstancedEntity";
        return sType;
    }
    
    override AxisAlignedBox getBoundingBox()
    {
        //TODO: Add attached objects (TagPoints) to the bbox
        return mBatchOwner._getMeshReference().getAs().getBounds();
    }

    override Real getBoundingRadius()
    {
        return mBatchOwner._getMeshReference().getAs().getBoundingSphereRadius() * getMaxScaleCoef();
    }
    
    /** This is used by our batch owner to get the closest entity's depth, returns infinity
     when not attached to a scene node */
    Real getSquaredViewDepth( ref Camera cam )
    {
        return _getDerivedPosition().squaredDistance(cam.getDerivedPosition());
    }
    
    /// Overriden so we can tell the InstanceBatch it needs to update it's bounds
    override void _notifyMoved()
    {
        markTransformDirty();
        super._notifyMoved();
        updateTransforms();
    }

    override void _notifyAttached(Node parent, bool isTagPoint = false )
    {
        markTransformDirty();
        super._notifyAttached( parent, isTagPoint );
        updateTransforms();
    }
    
    /// Do nothing, InstanceBatch takes care of this.
    override void _updateRenderQueue( RenderQueue queue )   {}
    override void visitRenderables( Renderable.Visitor visitor, bool debugRenderables = false ) {}
    
    /** @see Entity.hasSkeleton */
    bool hasSkeleton(){ return mSkeletonInstance !is null; }
    /** @see Entity.getSkeleton */
    ref SkeletonInstance getSkeleton(){ return mSkeletonInstance; }
    
    /** @see Entity.getAnimationState */
    ref AnimationState getAnimationState(string name)
    {
        if (!mAnimationState)
        {
            throw new ItemNotFoundError("Entity is not animated",
                                        "InstancedEntity.getAnimationState");
        }
        
        return mAnimationState.getAnimationState(name);
    }

    /** @see Entity.getAllAnimationStates */
    ref AnimationStateSet getAllAnimationStates()
    {
        return mAnimationState;
    }
    
    /** Called by InstanceBatch in <i>his</i> _updateRenderQueue to tell us we need
     to calculate our bone matrices.
     @remarks Assumes it has a skeleton (mSkeletonInstance != 0)
     @return true if something was actually updated
     */
    bool _updateAnimation()
    {
        if (mSharedTransformEntity)
        {
            return mSharedTransformEntity._updateAnimation();
        }
        else
        {
            bool animationDirty =
                (mFrameAnimationLastUpdated != mAnimationState.getDirtyFrameNumber()) ||
                    (mSkeletonInstance.getManualBonesDirty());
            
            if( animationDirty || (mNeedAnimTransformUpdate &&  mBatchOwner.useBoneWorldMatrices()))
            {
                mSkeletonInstance.setAnimationState( mAnimationState );
                mSkeletonInstance._getBoneMatrices( mBoneMatrices );
                
                // Cache last parent transform for next frame use too.
                if (mBatchOwner.useBoneWorldMatrices())
                {
                    OptimisedUtil.getImplementation().concatenateAffineMatrices(
                        _getParentNodeFullTransform(),
                        mBoneMatrices,
                        mBoneWorldMatrices,
                        mSkeletonInstance.getNumBones() );
                    mNeedAnimTransformUpdate = false;
                }
                
                mFrameAnimationLastUpdated = mAnimationState.getDirtyFrameNumber();
                
                return true;
            }
        }
        
        return false;
    }
    
    /** Sets the transformation look up number */
    void setTransformLookupNumber(ushort num) { mTransformLookupNumber = num;}
    
    /** Retrieve the position */
    Vector3 getPosition(){ return mPosition; }
    /** Set the position or the offset from the parent node if a parent node exists */ 
    void setPosition(Vector3 position, bool doUpdate = true)
    { 
        mPosition = position; 
        mDerivedLocalPosition = position;
        mUseLocalTransform = true;
        markTransformDirty();
        if (doUpdate) updateTransforms();
    } 
    
    /** Retrieve the orientation */
    Quaternion getOrientation(){ return mOrientation; }
    /** Set the orientation or the offset from the parent node if a parent node exists */
    void setOrientation(Quaternion orientation, bool doUpdate = true)
    { 
        mOrientation = orientation;  
        mUseLocalTransform = true;
        markTransformDirty();
        if (doUpdate) updateTransforms();
    }
    
    /** Retrieve the local scale */ 
    Vector3 getScale(){ return mScale; }
    /** Set the  scale or the offset from the parent node if a parent node exists  */ 
    void setScale(Vector3 scale, bool doUpdate = true)
    { 
        mScale = scale; 
        mMaxScaleLocal = std.algorithm.max(std.algorithm.max(Math.Abs(mScale.x), 
                                                             Math.Abs(mScale.y)), Math.Abs(mScale.z)); 
        mUseLocalTransform = true;
        markTransformDirty();
        if (doUpdate) updateTransforms();
    }
    
    /** Returns the maximum derived scale coefficient among the xyz values */
    Real getMaxScaleCoef()
    { 
        if (mParentNode)
        {
            Vector3 parentScale = mParentNode._getDerivedScale();
            return mMaxScaleLocal * std.algorithm.max(std.algorithm.max(
                Math.Abs(parentScale.x), Math.Abs(parentScale.y)), Math.Abs(parentScale.z)); 
        }
        return mMaxScaleLocal; 
    }
    
    /** Update the world transform and derived values */
    void updateTransforms()
    {
        if (mUseLocalTransform && mNeedTransformUpdate)
        {
            if (mParentNode)
            {
                Vector3 parentPosition = mParentNode._getDerivedPosition();
                Quaternion parentOrientation = mParentNode._getDerivedOrientation();
                Vector3 parentScale = mParentNode._getDerivedScale();
                
                Quaternion derivedOrientation = parentOrientation * mOrientation;
                Vector3 derivedScale = parentScale * mScale;
                mDerivedLocalPosition = parentOrientation * (parentScale * mPosition) + parentPosition;
                
                mFullLocalTransform.makeTransform(mDerivedLocalPosition, derivedScale, derivedOrientation);
            }
            else
            {
                mFullLocalTransform.makeTransform(mPosition,mScale,mOrientation);
            }
            mNeedTransformUpdate = false;
        }
    }
    
    /** Tells if the entity is in use. */
    bool isInUse(){ return mInUse; }
    /** Sets whether the entity is in use. */
    void setInUse(bool used)
    {
        mInUse = used;
        //Remove the use of local transform if the object is deleted
        mUseLocalTransform &= used;
    }
    
    /** Returns the world transform of the instanced entity including local transform */
    override Matrix4 _getParentNodeFullTransform(){ 
        assert((!mNeedTransformUpdate || !mUseLocalTransform), "Transform data should be updated at this point");
        return mUseLocalTransform ? mFullLocalTransform :
        mParentNode ? mParentNode._getFullTransform() : Matrix4.IDENTITY;
    }
    
    /** Returns the derived position of the instanced entity including local transform */
    Vector3 _getDerivedPosition(){
        assert((!mNeedTransformUpdate || !mUseLocalTransform), "Transform data should be updated at this point");
        return mUseLocalTransform ? mDerivedLocalPosition :
        mParentNode ? mParentNode._getDerivedPosition() : Vector3.ZERO;
    }
    
    /** @copydoc MovableObject.isInScene. */
    override bool isInScene()
    {
        //We assume that the instanced entity is in the scene if it is in use
        //It is in the scene whether it has a parent node or not
        return mInUse;
    }
    
    /** Sets the custom parameter for this instance @see InstanceManager.setNumCustomParams
     Because not all techniques support custom params, and some users may not need it while
     using millions of InstancedEntities, the params have been detached from InstancedEntity
     and stored in it's InstanceBatch instead, to reduce memory overhead.
     @remarks
     If this function is never called, all instances default to Vector4.ZERO. Watch out!
     If you destroy an instanced entity and then create it again (remember! Instanced entities
     are pre-allocated) it's custom param will contain the old value when it was destroyed.
     @param Index of the param. In the range [0; InstanceManager.getNumCustomParams())
     @param New parameter
     */
    void setCustomParam( ubyte idx,Vector4 newParam )
    {
        mBatchOwner._setCustomParam( this, idx, newParam );
    }
    Vector4 getCustomParam( ubyte idx )
    {
        return mBatchOwner._getCustomParam( this, idx );
    }
}

/** InstanceBatch forms part of the new Instancing system
 This is an abstract class that must be derived to implement different instancing techniques
 (@see InstanceManager.InstancingTechnique)
 OGRE wasn't truly thought for instancing. OGRE assumes that either:
 a. One MovableObject . No Renderable
 b. One MovableObject . One Renderable
 c. One MovableObject . Many Renderable.
 However, instances work on reverse: Many MovableObject have the same Renderable.
 <b>Instancing is already difficult to cull by a CPU</b>, but the main drawback from this assumption
 is that it makes it even harder to take advantage from OGRE's culling capabilities
 (i.e. @see OctreeSceneManager)
 @par
 To workaround this problem, InstanceBatch updates on almost every frame,
 growing the bounding box to fit all instances that are not being culled individually.
 This helps by avoiding a huge bbox that may cover the whole scene, which decreases shadow
 quality considerably (as it is seen as large shadow receiver)
 Furthermore, if no individual instance is visible, the InstanceBatch switches it's visibility
 (@see MovableObject.setVisible) to avoid sending this Renderable to the GPU. This happens because
 even when no individual instance is visible, their merged bounding box may cause OGRE to think
 the batch is visible (i.e. the camera is looking between object A & B, but A & B aren't visible)
 @par
 <b>As it happens with instancing in general, all instanced entities from the same batch will share
 the same textures and materials</b>
 @par
 Each InstanceBatch preallocates a fixed amount of mInstancesPerBatch instances once it's been
 built (@see build, @see buildFrom).
 @see createInstancedEntity and @see removeInstancedEntity on how to retrieve those instances
 remove them from scene.
 Note that, on GPU side, removing an instance from scene doesn't save GPU cycles on what
 respects vertex shaders, but saves a little fillrate and pixel shaders; unless all instances
 are removed, which saves GPU.
 For more information, @see InstancedEntity
 For information on how Ogre manages multiple Instance batches, @see InstanceManager

 @remarks
 Design discussion webpage
 @author
 Matias N. Goldberg ("dark_sylinc")
 @version
 1.0
 */
class InstanceBatch : MovableObject, Renderable
{
    mixin Renderable.Renderable_Impl;
    mixin Renderable.Renderable_Any_Impl;
    
public:
    //typedef vector<InstancedEntity*>.type  InstancedEntityVec;
    //typedef vector<Vector4>.type           CustomParamsVec;
    alias InstancedEntity[]   InstancedEntityVec;
    alias Vector4[]           CustomParamsVec;
protected:
    RenderOperation     mRenderOperation;
    size_t              mInstancesPerBatch;
    
    InstanceManager     mCreator;
    
    SharedPtr!Material         mMaterial;
    
    SharedPtr!Mesh             mMeshReference;
    Mesh.IndexMap       mIndexToBoneMap;
    
    //InstancedEntities are all allocated at build time and kept as "unused"
    //when they're requested, they're removed from there when requested,
    //and put back again when they're no longer needed
    //Note each InstancedEntity has a unique ID ranging from [0; mInstancesPerBatch)
    InstancedEntityVec  mInstancedEntities;
    InstancedEntityVec  mUnusedEntities;
    
    ///@see InstanceManager.setNumCustomParams(). Because this may not even be used,
    ///our implementations keep the params separate from the InstancedEntity to lower
    ///the memory overhead. They default to Vector4.ZERO
    CustomParamsVec     mCustomParams;
    
    /// This bbox contains all (visible) instanced entities
    AxisAlignedBox      mFullBoundingBox;
    Real                mBoundingRadius;
    bool                mBoundsDirty;
    bool                mBoundsUpdated; //Set to false by derived classes that need it
    Camera              mCurrentCamera;
    
    ushort              mMaterialLodIndex;
    
    bool                mDirtyAnimation; //Set to false at start of each _updateRenderQueue
    
    /// False if a technique doesn't support skeletal animation
    bool                mTechnSupportsSkeletal;
    
    /// Cached distance to last camera for getSquaredViewDepth
    //mutable 
    Real mCachedCameraDist;
    /// The camera for which the cached distance is valid
    //mutable 
    Camera mCachedCamera;
    
    /// Tells that the list of entity instances with shared transforms has changed
    bool mTransformSharingDirty;
    
    /// When true remove the memory of the VertexData we've created because no one else will
    bool mRemoveOwnVertexData;
    /// When true remove the memory of the IndexData we've created because no one else will
    bool mRemoveOwnIndexData;
    
    abstract void setupVertices( ref SubMesh baseSubMesh );
    abstract void setupIndices( ref SubMesh baseSubMesh );
    
    void createAllInstancedEntities()
    {
        mInstancedEntities.length = ( mInstancesPerBatch );
        mUnusedEntities.length = ( mInstancesPerBatch );
        
        for( ushort i=0; i<mInstancesPerBatch; ++i )
        {
            InstancedEntity instance = generateInstancedEntity(i);
            mInstancedEntities.insert( instance );
            mUnusedEntities.insert( instance );
        }
    }
    
    void deleteAllInstancedEntities()
    {
        foreach(itor; mInstancedEntities)
        {
            if( itor.getParentSceneNode() )
                itor.getParentSceneNode().detachObject( itor );
            
            destroy(itor);
        }
    }
    
    void deleteUnusedInstancedEntities()
    {
        foreach(itor; mUnusedEntities)
            destroy(itor);
        
        mUnusedEntities.clear();
    }
    
    /// Creates a new InstancedEntity instance
    InstancedEntity generateInstancedEntity(size_t num)
    {
        return new InstancedEntity(this, cast(ushort)num);
    }
    
    /** Takes an array of 3x4 matrices and makes it camera relative. Note the second argument
     takes number of floats in the array, not number of matrices. Assumes mCachedCamera
     contains the camera which is about to be rendered to.
     */
    void makeMatrixCameraRelative3x4( float *mat3x4, size_t numFloats )
    {
        Vector3 cameraRelativePosition = mCurrentCamera.getDerivedPosition();
        
        for( size_t i=0; i<numFloats >> 2; i += 3 )
        {
            auto worldTrans = Vector3( mat3x4[(i+0) * 4 + 3], mat3x4[(i+1) * 4 + 3],
                                      mat3x4[(i+2) * 4 + 3] );
            auto newPos = worldTrans - cameraRelativePosition;
            
            mat3x4[(i+0) * 4 + 3] = cast(float)newPos.x;
            mat3x4[(i+1) * 4 + 3] = cast(float)newPos.y;
            mat3x4[(i+2) * 4 + 3] = cast(float)newPos.z;
        }
    }
    
    /// Returns false on errors that would prevent building this batch from the given submesh
    bool checkSubMeshCompatibility( ref SubMesh baseSubMesh )
    {
        if( baseSubMesh.operationType != RenderOperation.OperationType.OT_TRIANGLE_LIST )
        {
            throw new NotImplementedError("Only meshes with OT_TRIANGLE_LIST are supported",
                                          "InstanceBatch.checkSubMeshCompatibility");
        }
        
        if( !mCustomParams.empty() && mCreator.getInstancingTechnique() != InstanceManager.InstancingTechnique.HWInstancingBasic )
        {
            //Implementing this for ShaderBased is impossible. All other variants can be.
            throw new InvalidParamsError("Custom parameters not supported for this " ~
                                         "technique. Do you dare implementing it?" ~
                                         "See InstanceManager.setNumCustomParams " ~
                                         "documentation.",
                                         "InstanceBatch.checkSubMeshCompatibility");
        }
        
        return true;
    }
    
    void updateVisibility()
    {
        mVisible = false;
        
        //while( itor != end && !mVisible )
        foreach(itor; mInstancedEntities)
        {
            //Trick to force Ogre not to render us if none of our instances is visible
            //Because we do Camera.isVisible(), it is better if the SceneNode from the
            //InstancedEntity is not part of the scene graph (i.e. ultimate parent is root node)
            //to avoid unnecessary wasteful calculations
            mVisible |= itor._findVisible( mCurrentCamera );
            if(mVisible) break;
        }
    }
    
    /** @see _defragmentBatch */
    void defragmentBatchNoCull( ref InstancedEntityVec usedEntities, ref CustomParamsVec usedParams )
    {
        size_t maxInstancesToCopy = std.algorithm.min( mInstancesPerBatch, usedEntities.length );
        //InstancedEntityVec.iterator 
        auto first = usedEntities.length - maxInstancesToCopy;
        //CustomParamsVec.iterator 
        auto firstParams = usedParams.length - maxInstancesToCopy *
            mCreator.getNumCustomParams();
        
        //Copy from the back to front, into m_instancedEntities
        mInstancedEntities.insertBeforeIdx( 0, usedEntities[first..$] );
        //Remove them from the array
        usedEntities.length = usedEntities.length - maxInstancesToCopy;
        
        mCustomParams.insertBeforeIdx( 0, usedParams[firstParams..$] );
    }
    
    /** @see _defragmentBatch
     This one takes the entity closest to the minimum corner of the bbox, then starts
     gathering entities closest to this entity. There might be much better algorithms (i.e.
     involving space partition), but this one is simple and works well enough
     */
    void defragmentBatchDoCull( ref InstancedEntityVec usedEntities, ref CustomParamsVec usedParams )
    {
        //Get the the entity closest to the minimum bbox edge and put into "first"
        //InstancedEntityVec.const_iterator itor   = usedEntities.begin();
        //InstancedEntityVec.const_iterator end   = usedEntities.end();
        
        Vector3 vMinPos = Vector3.ZERO, firstPos = Vector3.ZERO;
        InstancedEntity first = null;
        
        if( !usedEntities.empty() )
        {
            first      = usedEntities[0];
            firstPos   = first._getDerivedPosition();
            vMinPos    = first._getDerivedPosition();
        }
        
        foreach(itor; usedEntities)
        {
            Vector3 vPos      = itor._getDerivedPosition();
            
            vMinPos.x = std.algorithm.min( vMinPos.x, vPos.x );
            vMinPos.y = std.algorithm.min( vMinPos.y, vPos.y );
            vMinPos.z = std.algorithm.min( vMinPos.z, vPos.z );
            
            if( vMinPos.squaredDistance( vPos ) < vMinPos.squaredDistance( firstPos ) )
            {
                firstPos   = vPos;
            }
        }
        
        //Now collect entities closest to 'first'
        while( !usedEntities.empty() && mInstancedEntities.length < mInstancesPerBatch )
        {
            //InstancedEntityVec.iterator 
            auto closest   = usedEntities[0];
            //InstancedEntityVec.iterator it        = usedEntities.begin();
            //InstancedEntityVec.iterator e         = usedEntities.end();
            
            Vector3 closestPos;
            closestPos = closest._getDerivedPosition();
            
            //size_t idx = 0, i = 0; // Or use countUntil later
            foreach(it; usedEntities)
            {
                Vector3 vPos   = it._getDerivedPosition();
                
                if( firstPos.squaredDistance( vPos ) < firstPos.squaredDistance( closestPos ) )
                {
                    closest      = it;
                    closestPos   = vPos;
                    //idx = i;
                }
                //i++;
            }
            
            mInstancedEntities.insert( closest );
            //Now the custom params
            //size_t idx = closest - usedEntities.begin();  
            size_t idx = std.algorithm.countUntil(usedEntities, closest);
            for( ubyte i=0; i<mCreator.getNumCustomParams(); ++i )
            {
                mCustomParams.insert( usedParams[idx + i] );
            }
            
            //Remove 'closest' from usedEntities & usedParams using swap and pop_back trick
            //*closest = *(usedEntities.end() - 1);
            //usedEntities.pop_back();
            
            closest = usedEntities.back;// [$-1];
            usedEntities.popBack();
            
            for( ubyte i=1; i<=mCreator.getNumCustomParams(); ++i )
            {
                usedParams[idx + mCreator.getNumCustomParams() - i] = usedParams.back; //*(usedParams.end() - 1);
                usedParams.popBack();
            }
        }
    }
    
public:
    this( InstanceManager creator, SharedPtr!Mesh meshReference,SharedPtr!Material material,
         size_t instancesPerBatch, ref Mesh.IndexMap indexToBoneMap,
         string batchName )
    {
        assert( instancesPerBatch );
        mInstancesPerBatch =  instancesPerBatch ;
        mCreator =  creator ;
        mMaterial =  material ;
        mMeshReference =  meshReference ;
        mIndexToBoneMap =  indexToBoneMap ;
        mBoundingRadius =  0 ;
        mBoundsDirty =  false ;
        mBoundsUpdated =  false ;
        //mCurrentCamera =  null ;
        mMaterialLodIndex =  0 ;
        mTechnSupportsSkeletal =  true ;
        //mCachedCamera =  null ;
        mTransformSharingDirty = true;
        mRemoveOwnVertexData = false;
        mRemoveOwnIndexData = false;
        
        //Force batch visibility to be always visible. The instanced entities
        //have individual visibility flags. If none matches the scene's current,
        //then this batch won't rendered.
        mVisibilityFlags = uint.max;
        
        if( indexToBoneMap )
        {
            assert( !(meshReference.getAs().hasSkeleton() && indexToBoneMap.empty()) );
        }
        
        mFullBoundingBox.setExtents( -Vector3.ZERO, Vector3.ZERO );
        
        mName = batchName;
        
        mCustomParams.length = mCreator.getNumCustomParams() * mInstancesPerBatch;
        //mCustomParams[] = Vector4.ZERO;
    }
    
    ~this()
    {
        deleteAllInstancedEntities();
        
        //Remove the parent scene node automatically
        SceneNode sceneNode = getParentSceneNode();
        if( sceneNode )
        {
            sceneNode.detachAllObjects();
            sceneNode.getParentSceneNode().removeAndDestroyChild( sceneNode.getName() );
        }
        
        if( mRemoveOwnVertexData )
            destroy(mRenderOperation.vertexData);
        if( mRemoveOwnIndexData )
            destroy(mRenderOperation.indexData);
        DestroyRenderable();
    }
    
    ref SharedPtr!Mesh _getMeshRef() { return mMeshReference; }
    
    /** Raises an exception if trying to change it after being built
     */
    void _setInstancesPerBatch( size_t instancesPerBatch )
    {
        if( !mInstancedEntities.empty() )
        {
            throw new InvalidStateError("Instances per batch can only be changed before" ~
                                        " building the batch.", "InstanceBatch._setInstancesPerBatch");
        }
        
        mInstancesPerBatch = instancesPerBatch;
    }
    
    ref Mesh.IndexMap _getIndexToBoneMap(){ return mIndexToBoneMap; }
    
    /** Returns true if this technique supports skeletal animation
     @remarks
     A function could have been used, but using a simple variable overriden
     by the derived class is faster than call overhead. And both are clean
     ways of implementing it.
     */
    bool _supportsSkeletalAnimation(){ return mTechnSupportsSkeletal; }
    
    /** @see InstanceManager.updateDirtyBatches */
    void _updateBounds()
    {
        mFullBoundingBox.setNull();
        
        Real maxScale = 0;
        foreach(ent; mInstancedEntities)
        {
            //Only increase the bounding box for those objects we know are in the scene
            if( ent.isInScene() )
            {
                maxScale = std.algorithm.max(maxScale, ent.getMaxScaleCoef());
                mFullBoundingBox.merge( ent._getDerivedPosition() );
            }
        }
        
        Real addToBound = maxScale * _getMeshReference().getAs().getBoundingSphereRadius();
        mFullBoundingBox.setMaximum(mFullBoundingBox.getMaximum() + addToBound);
        mFullBoundingBox.setMinimum(mFullBoundingBox.getMinimum() - addToBound);
        
        
        mBoundingRadius = Math.boundingRadiusFromAABB( mFullBoundingBox );
        
        //Tell the SceneManager our bounds have changed
        getParentSceneNode().needUpdate(true);
        
        mBoundsDirty    = false;
        mBoundsUpdated  = true;
    }
    
    /** Some techniques have a limit on how many instances can be done.
     Sometimes even depends on the material being used.
     @par
     Note this is a helper function, as such it takes a submesh base to compute
     the parameters, instead of using the object's own. This allows
     querying for a technique without requiering to actually build it.
     @param baseSubMesh The base submesh that will be using to build it.
     @param flags @see InstanceManagerFlags
     @return The max instances limit
     */
    abstract size_t calculateMaxNumInstances( SubMesh baseSubMesh, ushort flags );
    
    /** Constructs all the data needed to use this batch, as well as the
     InstanceEntities. Placed here because in the constructor virtual
     tables may not have been yet filled.
     @param baseSubMesh A sub mesh which the instances will be based upon from.
     @remarks
     Call this only ONCE. This is done automatically by Ogre.InstanceManager
     Caller is responsable for freeing buffers in this RenderOperation
     Buffers inside the RenderOp may be null if the built failed.
     @return
     A render operation which is very useful to pass to other InstanceBatches
     (@see buildFrom) so that they share the same vertex buffers and indices,
     when possible
     */
    RenderOperation build( ref SubMesh baseSubMesh )
    {
        if( checkSubMeshCompatibility( baseSubMesh ) )
        {
            //Only triangle list at the moment
            mRenderOperation.operationType  = RenderOperation.OperationType.OT_TRIANGLE_LIST;
            mRenderOperation.srcRenderable  = this;
            mRenderOperation.useIndexes = true;
            setupVertices( baseSubMesh );
            setupIndices( baseSubMesh );
            
            createAllInstancedEntities();
        }
        
        return mRenderOperation;
    }
    
    /** Instancing consumes significantly more GPU memory than regular rendering
     methods. However, multiple batches can share most, if not all, of the
     vertex & index buffers to save memory.
     Derived classes are free to overload this method to manipulate what to
     reference from Render Op.
     For example, Hardware based instancing uses it's own vertex buffer for the
     last source binding, but shares the other sources.
     @param renderOperation The RenderOp to reference.
     @remarks
     Caller is responsable for freeing buffers passed as input arguments
     This function replaces the need to call build()
     baseSubMesh is not used.
     */
    //TODO Remove baseSubMesh  ?
    void buildFrom( /*ref*/SubMesh baseSubMesh, ref RenderOperation renderOperation )
    {
        mRenderOperation = renderOperation;
        createAllInstancedEntities();
    }
    
    ref SharedPtr!Mesh _getMeshReference(){ return mMeshReference; }
    
    /** @return true if it can not create more InstancedEntities
     (Num InstancedEntities == mInstancesPerBatch)
     */
    bool isBatchFull(){ return mUnusedEntities.empty(); }
    
    /** Returns true if it no instanced entity has been requested or all of them have been removed
     */
    bool isBatchUnused(){ return mUnusedEntities.length == mInstancedEntities.length; }
    
    /** Fills the input vector with the instances that are currently being used or were requested.
     Used for defragmentation, @see InstanceManager.defragmentBatches
     */
    void getInstancedEntitiesInUse( ref InstancedEntityVec outEntities, ref CustomParamsVec outParams )
    {
        foreach(itor; mInstancedEntities)
        {
            if( itor.isInUse() )
            {
                outEntities.insert( itor );
                
                for( ubyte i=0; i<mCreator.getNumCustomParams(); ++i )
                    outParams.insert( _getCustomParam( itor, i ) );
            }
        }
    }
    
    /** @see InstanceManager.defragmentBatches
     This function takes InstancedEntities and pushes back all entities it can fit here
     Extra entities in mUnusedEntities are destroyed
     (so that used + unused = mInstancedEntities.length)
     @param optimizeCulling true will call the DoCull version, false the NoCull
     @param usedEntities Array of InstancedEntities to parent with this batch. Those reparented
     are removed from this input vector
     @param Array of Custom parameters correlated with the InstancedEntities in usedEntities.
     They follow the fate of the entities in that vector.
     @remarks:
     This function assumes caller holds data to mInstancedEntities! Otherwise
     you can get memory leaks. Don't call this directly if you don't know what you're doing!
     */
    void _defragmentBatch( bool optimizeCulling, ref InstancedEntityVec usedEntities,
                          ref CustomParamsVec usedParams )
    {
        //Remove and clear what we don't need
        mInstancedEntities.clear();
        mCustomParams.clear();
        deleteUnusedInstancedEntities();
        
        if( !optimizeCulling )
            defragmentBatchNoCull( usedEntities, usedParams );
        else
            defragmentBatchDoCull( usedEntities, usedParams );
        
        //Reassign instance IDs and tell we're the new parent
        ushort instanceId = 0;//TODO was uint, wtf why when ctor takes ushort
        
        foreach(itor; mInstancedEntities)
        {
            itor.mInstanceId = instanceId++; //XXX As long as InstancedEntity is a class
            itor.mBatchOwner = this;
        }
        
        //Recreate unused entities, if there's left space in our container
        // cast to signed
        assert( cast(ptrdiff_t)mInstancesPerBatch - cast(ptrdiff_t)mInstancedEntities.length >= 0 );
        mInstancedEntities.length = ( mInstancesPerBatch );
        mUnusedEntities.length = ( mInstancesPerBatch );
        mCustomParams.length = ( mCreator.getNumCustomParams() * mInstancesPerBatch );
        for( ushort i=cast(ushort)mInstancedEntities.length; i<mInstancesPerBatch; ++i )
        {
            InstancedEntity instance = generateInstancedEntity(i);
            mInstancedEntities.insert( instance );
            mUnusedEntities.insert( instance );
            mCustomParams.insert( cast(Vector4)Vector4.ZERO );
        }
        
        //We've potentially changed our bounds
        if( !isBatchUnused() )
            _boundsDirty();
    }
    
    /** @see InstanceManager._defragmentBatchDiscard
     Destroys unused entities and clears the mInstancedEntity container which avoids leaving
     dangling pointers from reparented InstancedEntities
     Usually called before deleting this pointer. Don't call directly!
     */
    void _defragmentBatchDiscard()
    {
        //Remove and clear what we don't need
        mInstancedEntities.clear();
        deleteUnusedInstancedEntities();
    }
    
    /** Called by InstancedEntity(s) to tell us we need to update the bounds
     (we touch the SceneNode so the SceneManager aknowledges such change)
     */
    void _boundsDirty()
    {
        if( mCreator && !mBoundsDirty ) 
            mCreator._addDirtyBatch( this );
        mBoundsDirty = true;
    }
    
    /** Tells this batch to stop updating animations, positions, rotations, and display
     all it's active instances. Currently only InstanceBatchHW & InstanceBatchHW_VTF support it.
     This option makes the batch behave pretty much like Static Geometry, but with the GPU RAM
     memory advantages (less VRAM, less bandwidth) and not LOD support. Very useful for
     billboards of trees, repeating vegetation, etc.
     @remarks
     This function moves a lot of processing time from the CPU to the GPU. If the GPU
     is already a bottleneck, you may see a decrease in performance instead!
     Call this function again (with bStatic=true) if you've made a change to an
     InstancedEntity and wish this change to take effect.
     Be sure to call this after you've set all your instances
     @see InstanceBatchHW.setStaticAndUpdate
     */
    void setStaticAndUpdate( bool bStatic )     {}
    
    /** Returns true if this batch was set as static. @see setStaticAndUpdate
     */
    bool isStatic()                      { return false; }
    
    /** Returns a pointer to a new InstancedEntity ready to use
     Note it's actually preallocated, so no memory allocation happens at
     this point.
     @remarks
     Returns NULL if all instances are being used
     */
    InstancedEntity createInstancedEntity()
    {
        InstancedEntity retVal = null;
        
        if( !mUnusedEntities.empty() )
        {
            retVal = mUnusedEntities.back();
            mUnusedEntities.popBack();
            
            retVal.setInUse(true);
        }
        
        return retVal;
    }
    
    /** Removes an InstancedEntity from the scene retrieved with
     getNewInstancedEntity, putting back into a queue
     @remarks
     Throws an exception if the instanced entity wasn't created by this batch
     Removed instanced entities save little CPU time, but _not_ GPU
     */
    void removeInstancedEntity( ref InstancedEntity instancedEntity )
    {
        if( instancedEntity.mBatchOwner != this )
        {
            throw new InvalidParamsError(
                "Trying to remove an InstancedEntity from scene created" ~
                " with a different InstanceBatch",
                "InstanceBatch.removeInstancedEntity()");
        }
        if( !instancedEntity.isInUse() )
        {
            throw new InvalidStateError(
                "Trying to remove an InstancedEntity that is already removed!",
                "InstanceBatch.removeInstancedEntity()");
        }
        
        if( instancedEntity.getParentSceneNode() )
            instancedEntity.getParentSceneNode().detachObject( instancedEntity );
        
        instancedEntity.setInUse(false);
        instancedEntity.stopSharingTransform();
        
        //Put it back into the queue
        mUnusedEntities.insert( instancedEntity );
    }
    
    /** Tells whether world bone matrices need to be calculated.
     This does not include bone matrices which are calculated regardless
     */
    bool useBoneWorldMatrices(){ return true; }
    
    /** Tells that the list of entity instances with shared transforms has changed */
    void _markTransformSharingDirty() { mTransformSharingDirty = true; }
    
    /** @see InstancedEntity.setCustomParam */
    void _setCustomParam( ref InstancedEntity instancedEntity, ubyte idx,Vector4 newParam )
    {
        mCustomParams[instancedEntity.mInstanceId * mCreator.getNumCustomParams() + idx] = newParam;
    }
    
    /** @see InstancedEntity.getCustomParam */
    Vector4 _getCustomParam( ref InstancedEntity instancedEntity, ubyte idx )
    {
        return mCustomParams[instancedEntity.mInstanceId * mCreator.getNumCustomParams() + idx];
    }
    
    //Renderable overloads
    /** @copydoc Renderable.getMaterial. */
    SharedPtr!Material getMaterial()     { return mMaterial; }
    /** @copydoc Renderable.getRenderOperation. */
    void getRenderOperation( ref RenderOperation op )  { op = mRenderOperation; }
    
    /** @copydoc Renderable.getSquaredViewDepth. */
    Real getSquaredViewDepth( Camera cam )
    {
        if( mCachedCamera != cam )
        {
            mCachedCameraDist = Real.infinity;
            
            foreach(itor; mInstancedEntities)
            {
                if( itor.isVisible() )
                    mCachedCameraDist = std.algorithm.min( mCachedCameraDist, itor.getSquaredViewDepth( cam ) );
            }
            
            mCachedCamera = cam;
        }
        
        return mCachedCameraDist;
    }
    
    /** @copydoc Renderable.getLights. */
    LightList getLights()
    {
        return queryLights();
    }
    
    /** @copydoc Renderable.getTechnique. */
    Technique getTechnique()
    {
        return mMaterial.getAs().getBestTechnique( mMaterialLodIndex, this );
    }
    
    /** @copydoc MovableObject.getMovableType. */
    override string getMovableType()
    {
        static string sType = "InstanceBatch";
        return sType;
    }
    
    /** @copydoc MovableObject._notifyCurrentCamera. */
    override void _notifyCurrentCamera( Camera cam )
    {
        mCurrentCamera = cam;
        
        //See DistanceLodStrategy.getValueImpl()
        //We use our own because our SceneNode is just filled with zeroes, and updating it
        //with real values is expensive, plus we would need to make sure it doesn't get to
        //the shader
        Real depth = Math.Sqrt( getSquaredViewDepth(cam) ) -
            mMeshReference.getAs().getBoundingSphereRadius();
        depth = std.algorithm.max( depth, 0 );
        Real lodValue = depth * cam._getLodBiasInverse();
        
        //Now calculate Material LOD
        /*LodStrategy *materialStrategy = m_material.getLodStrategy();
         
         //Calculate lod value for given strategy
         Real lodValue = materialStrategy.getValue( this, cam );*/
        
        //Get the index at this depth
        ushort idx = mMaterial.getAs().getLodIndex( lodValue );
        
        //TODO: Replace subEntity for MovableObject
        // Construct event object
        /*EntityMaterialLodChangedEvent subEntEvt;
         subEntEvt.subEntity = this;
         subEntEvt.camera = cam;
         subEntEvt.lodValue = lodValue;
         subEntEvt.previousLodIndex = m_materialLodIndex;
         subEntEvt.newLodIndex = idx;

         //Notify lod event listeners
         cam.getSceneManager()._notifyEntityMaterialLodChanged(subEntEvt);*/
        
        //Change lod index
        mMaterialLodIndex = idx;
        
        super._notifyCurrentCamera( cam );
    }
    
    /** @copydoc MovableObject.getBoundingBox. */
    override AxisAlignedBox getBoundingBox()
    {
        return mFullBoundingBox;
    }
    
    /** @copydoc MovableObject.getBoundingRadius. */
    override Real getBoundingRadius()
    {
        return mBoundingRadius;
    }
    
    override void _updateRenderQueue(RenderQueue queue)
    {
        /*if( m_boundsDirty )
         _updateBounds();*/
        
        mDirtyAnimation = false;
        
        //Is at least one object in the scene?
        updateVisibility();
        
        if( mVisible )
        {
            if( mMeshReference.getAs().hasSkeleton() )
            {
                foreach(itor; mInstancedEntities)
                {
                    mDirtyAnimation |= itor._updateAnimation();
                }
            }
            
            queue.addRenderable( this, mRenderQueueID, mRenderQueuePriority );
        }
        
        //Reset visibility once we skipped addRenderable (which saves GPU time), because OGRE for some
        //reason stops updating our render queue afterwards, preventing us to recalculate visibility
        mVisible = true;
    }
    
    override void visitRenderables( Renderable.Visitor visitor, bool debugRenderables = false )
    {
        visitor.visit( this, 0, false );
    }
    
    // resolve ambiguity of get/setUserAny due to inheriting from Renderable and MovableObject
    //using Renderable.getUserAny;
    //using Renderable.setUserAny;
    //Using MovableObject's
}

/** This is the same technique the old "InstancedGeometry" implementation used (with improvements).
 Basically it creates a large vertex buffer with many repeating entities, and sends per instance
 data through shader constants. Because SM 2.0 & 3.0 have up to 256 shader constant registers,
 this means there can be approx up to 84 instances per batch, assuming they're not skinned
 But using shader constants for other stuff (i.e. lighting) also affects negatively this number
 A mesh with skeletally animated 2 bones reduces the number 84 to 42 instances per batch.
 @par
 The main advantage of this technique is that it's supported on a high variety of hardware
 (SM 2.0 cards are required) and the same shader can be used for both skeletally animated
 normal entities and instanced entities without a single change required.
 @par
 Unlike the old InstancedGeometry implementation, the developer doesn't need to worry about
 reaching the 84 instances limit, the InstanceManager automatically takes care of splitting
 and creating new batches. But beware internally, this means less performance improvement.
 Another improvement is that vertex buffers are shared between batches, which significantly
 reduces GPU VRAM usage.

 @remarks
 Design discussion webpage: http://www.ogre3d.org/forums/viewtopic.php?f=4&t=59902
 @author
 Matias N. Goldberg ("dark_sylinc")
 @version
 1.0
 */
class InstanceBatchShader : InstanceBatch
{
    ushort  mNumWorldMatrices;
    
    override void setupVertices( ref SubMesh baseSubMesh )
    {
        mRenderOperation.vertexData = new VertexData();
        mRemoveOwnVertexData = true; //Raise flag to remove our own vertex data in the end (not always needed)
        
        VertexData thisVertexData = mRenderOperation.vertexData;
        VertexData baseVertexData = baseSubMesh.vertexData;
        
        thisVertexData.vertexStart = 0;
        thisVertexData.vertexCount = baseVertexData.vertexCount * mInstancesPerBatch;
        
        HardwareBufferManager.getSingleton().destroyVertexDeclaration( thisVertexData.vertexDeclaration );
        thisVertexData.vertexDeclaration = baseVertexData.vertexDeclaration.clone();
        
        if( mMeshReference.getAs().hasSkeleton() && !mMeshReference.getAs().getSkeleton().isNull() )
        {
            //Building hw skinned batches follow a different path
            setupHardwareSkinned( baseSubMesh, thisVertexData, baseVertexData );
            return;
        }
        
        //TODO: Can't we, instead of using another source, put the index ID in the same source?
        thisVertexData.vertexDeclaration.addElement(
            cast(ushort)(thisVertexData.vertexDeclaration.getMaxSource() + 1), 0,
            VertexElementType.VET_UBYTE4, VertexElementSemantic.VES_BLEND_INDICES );
        
        
        for( ushort i=0; i<thisVertexData.vertexDeclaration.getMaxSource(); ++i )
        {
            //Create our own vertex buffer
            SharedPtr!HardwareVertexBuffer vertexBuffer =
                HardwareBufferManager.getSingleton().createVertexBuffer(
                    thisVertexData.vertexDeclaration.getVertexSize(i),
                    thisVertexData.vertexCount,
                    HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY );
            thisVertexData.vertexBufferBinding.setBinding( i, vertexBuffer );
            
            //Grab the base submesh data
            SharedPtr!HardwareVertexBuffer baseVertexBuffer =
                baseVertexData.vertexBufferBinding.getBuffer(i);
            
            ubyte* thisBuf = cast(ubyte*)(vertexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
            ubyte* baseBuf = cast(ubyte*)(baseVertexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
            
            //Copy and repeat
            foreach(j; 0..mInstancesPerBatch)
            {
                size_t sizeOfBuffer = baseVertexData.vertexCount *
                    baseVertexData.vertexDeclaration.getVertexSize(i);
                memcpy( thisBuf + j * sizeOfBuffer, baseBuf, sizeOfBuffer );
            }
            
            baseVertexBuffer.get().unlock();
            vertexBuffer.get().unlock();
        }
        
        {
            //Now create the vertices "index ID" to individualize each instance
            ushort lastSource = thisVertexData.vertexDeclaration.getMaxSource();
            SharedPtr!HardwareVertexBuffer vertexBuffer =
                HardwareBufferManager.getSingleton().createVertexBuffer(
                    thisVertexData.vertexDeclaration.getVertexSize( lastSource ),
                    thisVertexData.vertexCount,
                    HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY );
            thisVertexData.vertexBufferBinding.setBinding( lastSource, vertexBuffer );
            
            ubyte* thisBuf = cast(ubyte*)(vertexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
            foreach(ubyte j; 0..cast(ubyte)mInstancesPerBatch)
            {
                foreach(k; 0..baseVertexData.vertexCount)
                {
                    *thisBuf++ = j;
                    *thisBuf++ = j;
                    *thisBuf++ = j;
                    *thisBuf++ = j;
                }
            }
            
            vertexBuffer.get().unlock();
        }
    }

    override void setupIndices( ref SubMesh baseSubMesh )
    {
        mRenderOperation.indexData = new IndexData();
        mRemoveOwnIndexData = true; //Raise flag to remove our own index data in the end (not always needed)
        
        IndexData thisIndexData = mRenderOperation.indexData;
        IndexData baseIndexData = baseSubMesh.indexData;
        
        thisIndexData.indexStart = 0;
        thisIndexData.indexCount = baseIndexData.indexCount * mInstancesPerBatch;
        
        //TODO: Check numVertices is below max supported by GPU
        HardwareIndexBuffer.IndexType indexType = HardwareIndexBuffer.IndexType.IT_16BIT;
        if( mRenderOperation.vertexData.vertexCount > 65535 )
            indexType = HardwareIndexBuffer.IndexType.IT_32BIT;
        thisIndexData.indexBuffer = HardwareBufferManager.getSingleton().createIndexBuffer(
            indexType, thisIndexData.indexCount,
            HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY );
        
        void *buf     = thisIndexData.indexBuffer.get().lock( HardwareBuffer.LockOptions.HBL_DISCARD );
        void *baseBuf = baseIndexData.indexBuffer.get().lock( HardwareBuffer.LockOptions.HBL_READ_ONLY );
        
        ushort *thisBuf16 = cast(ushort*)(buf);
        uint *thisBuf32 = cast(uint*)(buf);
        
        for( size_t i=0; i<mInstancesPerBatch; ++i )
        {
            uint vertexOffset = cast(uint)(i * mRenderOperation.vertexData.vertexCount / mInstancesPerBatch);
            
            ushort *initBuf16 = cast(ushort*)(baseBuf);
            uint   *initBuf32 = cast(uint*)(baseBuf);
            
            for( size_t j=0; j<baseIndexData.indexCount; ++j )
            {
                uint originalVal;
                if( baseSubMesh.indexData.indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_16BIT )
                    originalVal = *initBuf16++;
                else
                    originalVal = *initBuf32++;
                
                if( indexType == HardwareIndexBuffer.IndexType.IT_16BIT )
                    *thisBuf16++ = cast(ushort)(originalVal + vertexOffset);
                else
                    *thisBuf32++ = originalVal + vertexOffset;
            }
        }
        
        baseIndexData.indexBuffer.get().unlock();
        thisIndexData.indexBuffer.get().unlock();
    }
    
    /** When the mesh is (hardware) skinned, a different code path is called so that
     we reuse the index buffers and modify them in place. For example Instance #2
     with reference to bone #5 would have BlendIndex = 2 + 5 = 7
     Everything is copied identically except the VES_BLEND_INDICES semantic
     */
    void setupHardwareSkinned( ref SubMesh baseSubMesh, VertexData thisVertexData,
                              VertexData baseVertexData )
    {
        size_t numBones = baseSubMesh.blendIndexToBoneIndexMap.length;
        mNumWorldMatrices = cast(ushort)(mInstancesPerBatch * numBones);
        
        for( ushort i=0; i<=thisVertexData.vertexDeclaration.getMaxSource(); ++i )
        {
            //Create our own vertex buffer
            SharedPtr!HardwareVertexBuffer vertexBuffer =
                HardwareBufferManager.getSingleton().createVertexBuffer(
                    thisVertexData.vertexDeclaration.getVertexSize(i),
                    thisVertexData.vertexCount,
                    HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY );
            thisVertexData.vertexBufferBinding.setBinding( i, vertexBuffer );
            
            VertexDeclaration.VertexElementList veList =
                thisVertexData.vertexDeclaration.findElementsBySource(i);
            
            //Grab the base submesh data
            SharedPtr!HardwareVertexBuffer baseVertexBuffer =
                baseVertexData.vertexBufferBinding.getBuffer(i);
            
            ubyte* thisBuf = cast(ubyte*)(vertexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
            ubyte* baseBuf = cast(ubyte*)(baseVertexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
            ubyte* startBuf = baseBuf;
            
            //Copy and repeat
            for( size_t j=0; j<mInstancesPerBatch; ++j )
            {
                //Repeat source
                baseBuf = startBuf;
                
                for( size_t k=0; k<baseVertexData.vertexCount; ++k )
                {
                    foreach(it; veList)
                    {
                        switch( it.getSemantic() )
                        {
                            case VertexElementSemantic.VES_BLEND_INDICES:
                                *(thisBuf + it.getOffset() + 0) = cast(ubyte)(*(baseBuf + it.getOffset() + 0) + j * numBones);
                                *(thisBuf + it.getOffset() + 1) = cast(ubyte)(*(baseBuf + it.getOffset() + 1) + j * numBones);
                                *(thisBuf + it.getOffset() + 2) = cast(ubyte)(*(baseBuf + it.getOffset() + 2) + j * numBones);
                                *(thisBuf + it.getOffset() + 3) = cast(ubyte)(*(baseBuf + it.getOffset() + 3) + j * numBones);
                                break;
                            default:
                                memcpy( thisBuf + it.getOffset(), baseBuf + it.getOffset(), it.getSize() );
                                break;
                        }
                    }
                    thisBuf += baseVertexData.vertexDeclaration.getVertexSize(i);
                    baseBuf += baseVertexData.vertexDeclaration.getVertexSize(i);
                }
            }
            
            baseVertexBuffer.get().unlock();
            vertexBuffer.get().unlock();
        }
    }
    
public:
    this( InstanceManager creator, SharedPtr!Mesh meshReference, SharedPtr!Material material,
         /*size_t*/ ushort instancesPerBatch, Mesh.IndexMap indexToBoneMap,
         string batchName )
    {
        super( creator, meshReference, material, instancesPerBatch,
              indexToBoneMap, batchName );
        mNumWorldMatrices = instancesPerBatch;
    }

    ~this(){}
    
    /** @see InstanceBatch.calculateMaxNumInstances */
    override size_t calculateMaxNumInstances( SubMesh baseSubMesh, ushort flags )// const;
    {
        size_t numBones = std.algorithm.max( 1, baseSubMesh.blendIndexToBoneIndexMap.length );
        
        mMaterial.getAs().load();
        Technique technique = mMaterial.getAs().getBestTechnique();
        if( technique )
        {
            GpuProgramParametersPtr vertexParam = technique.getPass(0).getVertexProgramParameters();
            GpuConstantDefinitionMap itor = vertexParam.get().getConstantDefinitionMap();
            foreach(k, constDef; itor)
            {
                //const GpuConstantDefinition &constDef = itor.getNext();
                if(((constDef.constType == GpuConstantType.GCT_MATRIX_3X4 ||
                     constDef.constType == GpuConstantType.GCT_MATRIX_4X3 ||             //OGL GLSL bitches without this
                     constDef.constType == GpuConstantType.GCT_MATRIX_2X4 ||
                     constDef.constType == GpuConstantType.GCT_FLOAT4)                   //OGL GLSL bitches without this
                    && constDef.isFloat()) ||
                   ((constDef.constType == GpuConstantType.GCT_MATRIX_DOUBLE_3X4 ||
                  constDef.constType == GpuConstantType.GCT_MATRIX_DOUBLE_4X3 ||      //OGL GLSL bitches without this
                  constDef.constType == GpuConstantType.GCT_MATRIX_DOUBLE_2X4 ||
                  constDef.constType == GpuConstantType.GCT_DOUBLE4)                  //OGL GLSL bitches without this
                 && constDef.isDouble())
                   )
                {
                    GpuProgramParameters.AutoConstantEntry entry =
                        vertexParam.get()._findRawAutoConstantEntryFloat( constDef.physicalIndex );
                    if( entry && (entry.paramType == GpuProgramParameters.AutoConstantType.ACT_WORLD_MATRIX_ARRAY_3x4 || entry.paramType == GpuProgramParameters.AutoConstantType.ACT_WORLD_DUALQUATERNION_ARRAY_2x4))
                    {
                        //Material is correctly done!
                        size_t arraySize = constDef.arraySize;
                        
                        //Deal with GL "hacky" way of doing 4x3 matrices
                        if(entry.paramType == GpuProgramParameters.AutoConstantType.ACT_WORLD_MATRIX_ARRAY_3x4 && constDef.constType == GpuConstantType.GCT_FLOAT4)
                            arraySize /= 3;
                        else if(entry.paramType == GpuProgramParameters.AutoConstantType.ACT_WORLD_DUALQUATERNION_ARRAY_2x4 && constDef.constType == GpuConstantType.GCT_FLOAT4)
                            arraySize /= 2;
                        
                        //Check the num of arrays
                        size_t retVal = arraySize / numBones;
                        
                        if( flags & InstanceManagerFlags.IM_USE16BIT )
                        {
                            if( baseSubMesh.vertexData.vertexCount * retVal > 0xFFFF )
                                retVal = 0xFFFF / baseSubMesh.vertexData.vertexCount;
                        }
                        
                        if((retVal < 3 && entry.paramType == GpuProgramParameters.AutoConstantType.ACT_WORLD_MATRIX_ARRAY_3x4) ||
                           (retVal < 2 && entry.paramType == GpuProgramParameters.AutoConstantType.ACT_WORLD_DUALQUATERNION_ARRAY_2x4))
                        {
                            LogManager.getSingleton().logMessage( "InstanceBatchShader: Mesh " ~
                                                                 mMeshReference.getAs().getName() ~ " using material " ~
                                                                 mMaterial.getAs().getName() ~ " contains many bones. The amount of "
                                                                 "instances per batch is very low. Performance benefits will "
                                                                 "be minimal, if any. It might be even slower!",
                                                                 LML_NORMAL );
                        }
                        
                        return retVal;
                    }
                }
            }
            
            //Reaching here means material is supported, but malformed
            throw new InvalidParamsError(
                "Material '" ~ mMaterial.getAs().getName() ~ "' is malformed for this instancing technique",
                "InstanceBatchShader:.calculateMaxNumInstances");
        }
        
        //Reaching here the material is just unsupported.
        
        return 0;
    }
    
    /** @see InstanceBatch.buildFrom */
    override void buildFrom( SubMesh baseSubMesh, ref RenderOperation renderOperation )
    {
        if( mMeshReference.getAs().hasSkeleton() && !mMeshReference.getAs().getSkeleton().isNull() )
            mNumWorldMatrices = cast(ushort)(mInstancesPerBatch * baseSubMesh.blendIndexToBoneIndexMap.length);
        super.buildFrom( baseSubMesh, renderOperation );
    }
    
    //Renderable overloads
    void getWorldTransforms( ref Matrix4[] xform )// const;
    {
        xform.length = 0;
        foreach(itor; mInstancedEntities)
        {
            Matrix4[] t;
            itor.getTransforms( t );
            xform ~= t;
        }
    }

    override ushort getNumWorldTransforms()// const;
    {
        return mNumWorldMatrices;
    }
}

/** Instancing implementation using vertex texture through Vertex Texture Fetch (VTF)
 This implementation has the following advantages:
 * Supports huge amount of instances per batch
 * Supports skinning even with huge ammounts of instances per batch
 * Doesn't need shader constants registers.
 * Best suited for skinned entities

 But beware the disadvantages:
 * VTF is only fast on modern GPUs (ATI Radeon HD 2000+, GeForce 8+ series onwards)
 * On GeForce 6/7 series VTF is too slow
 * VTF isn't (controversely) supported on old ATI X1800 hardware
 * Only one bone weight per vertex is supported
 * GPUs with low memory bandwidth (i.e. laptops and integrated GPUs)
 may perform even worse than no instancing

 Whether this performs great or bad depends on the hardware. It improved up to 4x performance on
 a Intel Core 2 Quad Core X9650 GeForce 8600 GTS, and in an Intel Core 2 Duo P7350 ATI
 Mobility Radeon HD 4650, but went 0.75x slower on an AthlonX2 5000+ integrated nForce 6150 SE
 Each BaseInstanceBatchVTF has it's own texture, which occupies memory in VRAM.
 Approx VRAM usage can be computed by doing 12 bytes * 3 * numInstances * numBones
 Use flag IM_VTFBESTFIT to avoid wasting VRAM (but may reduce amount of instances per batch).
 @par
 The material requires at least a texture unit stage named "InstancingVTF"

 @remarks
 Design discussion webpage: http://www.ogre3d.org/forums/viewtopic.php?f=4&t=59902
 @author
 Matias N. Goldberg ("dark_sylinc")
 @version
 1.0
 */
class BaseInstanceBatchVTF : InstanceBatch
{
    enum ushort c_maxTexWidth   = 4096;
    enum ushort c_maxTexHeight  = 4096;

protected:
    //typedef vector<ubyte>::type HWBoneIdxVec;
    //typedef vector<float>::type HWBoneWgtVec;
    //typedef vector<Matrix4>::type Matrix4Vec;

    alias ubyte[] HWBoneIdxVec;
    alias float[] HWBoneWgtVec;
    alias Matrix4[] Matrix4Vec;
    
    size_t                  mMatricesPerInstance; //number of bone matrices per instance
    size_t                  mNumWorldMatrices;  //Num bones * num instances
    SharedPtr!Texture              mMatrixTexture; //The VTF
    
    //Used when all matrices from each instance must be in the same row (i.e. HW Instancing).
    //A few pixels are wasted, but resizing the texture puts the danger of not sampling the
    //right pixel... (in theory it should work, but in practice doesn't)
    size_t                  mWidthFloatsPadding;
    size_t                  mMaxFloatsPerLine;
    
    size_t                  mRowLength;
    size_t                  mWeightCount;
    //Temporary array used to store 3x4 matrices before they are converted to dual quaternions
    float[]                 mTempTransformsArray3x4;
    
    // The state of the usage of bone matrix lookup
    bool mUseBoneMatrixLookup;
    size_t mMaxLookupTableInstances;
    
    bool mUseBoneDualQuaternions;
    bool mForceOneWeight;
    bool mUseOneWeight;
    
    /** Clones the base material so it can have it's own vertex texture, and also
     clones it's shadow caster materials, if it has any
     */
    void cloneMaterial( SharedPtr!Material material )
    {
        //Used to track down shadow casters, so the same material caster doesn't get cloned twice
        SharedPtr!Material[string] clonedMaterials;
        
        //We need to clone the material so we can have different textures for each batch.
        mMaterial = material.getAs().clone( mName ~ "/VTFMaterial" );
        
        //Now do the same with the techniques which have a material shadow caster
        foreach(technique; material.getAs().getTechniques())
        {
            if( !technique.getShadowCasterMaterial().isNull() )
            {
                SharedPtr!Material casterMat    = technique.getShadowCasterMaterial();
                string casterName        = casterMat.get().getName();
                
                //Was this material already cloned?
                auto itor = casterName in clonedMaterials;
                
                if( itor is null )
                {
                    //No? Clone it and track it
                    SharedPtr!Material cloned = casterMat.getAs().clone(std.conv.text(mName, "/VTFMaterialCaster",
                                                                             clonedMaterials.length));
                    technique.setShadowCasterMaterial( cloned );
                    clonedMaterials[casterName] = cloned;
                }
                else
                    technique.setShadowCasterMaterial( *itor ); //Reuse the previously cloned mat
            }
        }
    }

    /** Retrieves bone data from the original sub mesh and puts it into an appropriate buffer,
     later to be read when creating the vertex semantics.
     Assumes outBoneIdx has enough space (base submesh vertex count)
     */
    void retrieveBoneIdx( VertexData baseVertexData, out HWBoneIdxVec outBoneIdx )
    {
        VertexElement ve = baseVertexData.vertexDeclaration.
            findElementBySemantic( VertexElementSemantic.VES_BLEND_INDICES );
        VertexElement veWeights = baseVertexData.vertexDeclaration.findElementBySemantic( VertexElementSemantic.VES_BLEND_WEIGHTS );
        
        SharedPtr!HardwareVertexBuffer buff = baseVertexData.vertexBufferBinding.getBuffer(ve.getSource());
        ubyte *baseBuffer = cast(ubyte*)(buff.get().lock( HardwareBuffer.LockOptions.HBL_READ_ONLY ));
        
        for( size_t i=0; i<baseVertexData.vertexCount; ++i )
        {
            float *pWeights = cast(float*)(baseBuffer + veWeights.getOffset());
            
            ubyte biggestWeightIdx = 0;
            for( size_t j=1; j< mWeightCount; ++j )
            {
                biggestWeightIdx = cast(ubyte)(pWeights[biggestWeightIdx] < pWeights[j] ? j : biggestWeightIdx);
            }
            
            ubyte *pIndex = cast(ubyte*)(baseBuffer + ve.getOffset());
            outBoneIdx[i] = pIndex[biggestWeightIdx];
            
            baseBuffer += baseVertexData.vertexDeclaration.getVertexSize(ve.getSource());
        }
        
        buff.get().unlock();
    }
    
    /** @see retrieveBoneIdx()
     Assumes outBoneIdx has enough space (twice the base submesh vertex count, one for each weight)
     Assumes outBoneWgt has enough space (twice the base submesh vertex count, one for each weight)
     */
    void retrieveBoneIdxWithWeights(VertexData baseVertexData, out HWBoneIdxVec outBoneIdx, out HWBoneWgtVec outBoneWgt)
    {
        VertexElement ve = baseVertexData.vertexDeclaration.findElementBySemantic( VertexElementSemantic.VES_BLEND_INDICES );
        VertexElement veWeights = baseVertexData.vertexDeclaration.findElementBySemantic( VertexElementSemantic.VES_BLEND_WEIGHTS );
        
        SharedPtr!HardwareVertexBuffer buff = baseVertexData.vertexBufferBinding.getBuffer(ve.getSource());
        ubyte *baseBuffer = cast(ubyte*)(buff.get().lock( HardwareBuffer.LockOptions.HBL_READ_ONLY ));
        
        for( size_t i=0; i<baseVertexData.vertexCount * mWeightCount; i += mWeightCount)
        {
            float *pWeights = cast(float*)(baseBuffer + veWeights.getOffset());
            ubyte *pIndex = cast(ubyte*)(baseBuffer + ve.getOffset());
            
            float weightMagnitude = 0.0f;
            for( size_t j=0; j < mWeightCount; ++j )
            {
                outBoneWgt[i+j] = pWeights[j];
                weightMagnitude += pWeights[j];
                outBoneIdx[i+j] = pIndex[j];
            }
            
            //Normalize the bone weights so they add to one
            for(size_t j=0; j < mWeightCount; ++j)
            {
                outBoneWgt[i+j] /= weightMagnitude;
            }
            
            baseBuffer += baseVertexData.vertexDeclaration.getVertexSize(ve.getSource());
        }
        
        buff.get().unlock();
    }
    
    /** Setups the material to use a vertex texture */
    void setupMaterialToUseVTF( TextureType textureType, ref SharedPtr!Material material )
    {
        Technique[] techItor = material.getAs().getTechniques();
        foreach(technique; techItor)
        {
            Pass[] passItor = technique.getPasses();
            
            foreach(pass; passItor)
            {
                bool bTexUnitFound = false;

                TextureUnitState[] texUnitItor = pass.getTextureUnitStates();
                
                foreach(texUnit; texUnitItor)
                {
                    if(bTexUnitFound) break;
                    
                    if( texUnit.getName() == "InstancingVTF" )
                    {
                        texUnit.setTextureName( mMatrixTexture.get().getName(), textureType );
                        texUnit.setTextureFiltering( TextureFilterOptions.TFO_NONE );
                        texUnit.setBindingType( TextureUnitState.BindingType.BT_VERTEX );
                    }
                }
            }
            
            if( !technique.getShadowCasterMaterial().isNull() )
            {
                SharedPtr!Material matCaster = technique.getShadowCasterMaterial();
                setupMaterialToUseVTF( textureType, matCaster );
            }
        }
    }
    
    /** Creates the vertex texture */
    void createVertexTexture( SubMesh baseSubMesh )
    {
        /*
         TODO: Find a way to retrieve max texture resolution,
         http://www.ogre3d.org/forums/viewtopic.php?t=38305

         Currently assuming it's 4096x4096, which is a safe bet for any hardware with decent VTF*/
        
        size_t uniqueAnimations = mInstancesPerBatch;
        if (useBoneMatrixLookup())
        {
            uniqueAnimations = std.algorithm.min(getMaxLookupTableInstances(), uniqueAnimations);
        }
        mMatricesPerInstance = std.algorithm.max( 1, baseSubMesh.blendIndexToBoneIndexMap.length );
        
        if(mUseBoneDualQuaternions && !mTempTransformsArray3x4)
        {
            mTempTransformsArray3x4 = new float[mMatricesPerInstance * 3 * 4];
        }
        
        mNumWorldMatrices = uniqueAnimations * mMatricesPerInstance;
        
        //Calculate the width & height required to hold all the matrices. Start by filling the width
        //first (i.e. 4096x1 4096x2 4096x3, etc)
        
        size_t texWidth         = std.algorithm.min( mNumWorldMatrices * mRowLength, c_maxTexWidth );
        size_t maxUsableWidth   = texWidth;
        if( matricesTogetherPerRow() )
        {
            //The technique requires all matrices from the same instance in the same row
            //i.e. 4094 . 4095 . skip 4096 . 0 (next row) contains data from a new instance 
            mWidthFloatsPadding = texWidth % (mMatricesPerInstance * mRowLength);
            
            if( mWidthFloatsPadding )
            {
                mMaxFloatsPerLine = texWidth - mWidthFloatsPadding;
                
                maxUsableWidth = mMaxFloatsPerLine;
                
                //Values are in pixels, convert them to floats (1 pixel = 4 floats)
                mWidthFloatsPadding *= 4;
                mMaxFloatsPerLine   *= 4;
            }
        }
        
        size_t texHeight = mNumWorldMatrices * mRowLength / maxUsableWidth;
        
        if( (mNumWorldMatrices * mRowLength) % maxUsableWidth )
            texHeight += 1;
        
        //Don't use 1D textures, as OGL goes crazy because the shader should be calling texture1D()...
        //TextureType texType = texHeight == 1 ? TEX_TYPE_1D : TEX_TYPE_2D;
        TextureType texType = TextureType.TEX_TYPE_2D;
        
        mMatrixTexture = TextureManager.getSingleton().createManual(
            mName ~ "/VTF", mMeshReference.getAs().getGroup(), texType,
            cast(uint)texWidth, cast(uint)texHeight,
            0, PixelFormat.PF_FLOAT32_RGBA, TextureUsage.TU_DYNAMIC_WRITE_ONLY_DISCARDABLE );
        
        //Set our cloned material to use this custom texture!
        setupMaterialToUseVTF( texType, mMaterial );
    }
    
    /** Creates 2 TEXCOORD semantics that will be used to sample the vertex texture */
    abstract void createVertexSemantics( VertexData thisVertexData, VertexData baseVertexData,
                                        out HWBoneIdxVec hwBoneIdx, out HWBoneWgtVec hwBoneWgt);
    
    size_t convert3x4MatricesToDualQuaternions(float* matrices, size_t numOfMatrices, float* outDualQuaternions)
    {
        DualQuaternion dQuat;
        Matrix4 matrix;
        size_t floatsWritten = 0;
        
        foreach (m; 0..numOfMatrices)
        {
            for(int i = 0; i < 3; ++i)
            {
                for(int b = 0; b < 4; ++b)
                {
                    matrix[i, b] = *matrices++;
                }
            }
            
            matrix[3, 0] = 0;
            matrix[3, 1] = 0;
            matrix[3, 2] = 0;
            matrix[3, 3] = 1;

            dQuat = new DualQuaternion(matrix);
            
            //Copy the 2x4 matrix
            for(int i = 0; i < 8; ++i)
            {
                *outDualQuaternions++ = cast(float)( dQuat[i] );
                ++floatsWritten;
            }
        }
        
        return floatsWritten;
    }

    size_t convert3x4MatricesToDualQuaternions(ref Matrix4[] matrices, size_t numOfMatrices, out DualQuaternion[] outDualQuaternions)
    {
        DualQuaternion dQuat;
        Matrix4 matrix;
        //Actually DualQuaternions returned and ultimately unneeded
        size_t floatsWritten = 0;
        outDualQuaternions.length = 0;

        foreach(m; matrices)
        {
            matrix = m;
            
            matrix[3, 0] = 0;
            matrix[3, 1] = 0;
            matrix[3, 2] = 0;
            matrix[3, 3] = 1;
            
            dQuat = new DualQuaternion(matrix);
            outDualQuaternions ~= dQuat;
            ++floatsWritten;
        }
        return floatsWritten*8;
    }

    /** Keeps filling the VTF with world matrix data */
    void updateVertexTexture()
    {
        //Now lock the texture and copy the 4x3 matrices!
        mMatrixTexture.getAs().getBuffer().get().lock( HardwareBuffer.LockOptions.HBL_DISCARD );
        PixelBox pixelBox = mMatrixTexture.getAs().getBuffer().get().getCurrentLock();
        
        float *pDest = cast(float*)(pixelBox.data);

        float* transforms;
        
        //If using dual quaternion skinning, write the transforms to a temporary buffer,
        //then convert to dual quaternions, then later write to the pixel buffer
        //Otherwise simply write the transforms to the pixel buffer directly
        if(mUseBoneDualQuaternions)
        {
            transforms = mTempTransformsArray3x4.ptr;
        }
        else
        {
            transforms = pDest;
        }
        
        
        foreach(itor; mInstancedEntities)
        {
            size_t floatsWritten = itor.getTransforms3x4( transforms );
            
            if( mManager.getCameraRelativeRendering() )
                makeMatrixCameraRelative3x4( transforms, floatsWritten );
            
            if(mUseBoneDualQuaternions)
            {
                floatsWritten = convert3x4MatricesToDualQuaternions(transforms, floatsWritten / 12, pDest);
                pDest += floatsWritten;
            }
            else
            {
                transforms += floatsWritten;
            }
        }
        
        mMatrixTexture.getAs().getBuffer().get().unlock();
    }
    
    /** Affects VTF texture's width dimension */
    abstract bool matricesTogetherPerRow();// const;
    
    /** update the lookup numbers for entities with shared transforms */
    void updateSharedLookupIndexes()
    {
        if (mTransformSharingDirty)
        {
            if (useBoneMatrixLookup())
            {
                //In each entity update the "transform lookup number" so that:
                // 1. All entities sharing the same transformation will share the same unique number
                // 2. "transform lookup number" will be numbered from 0 up to getMaxLookupTableInstances
                size_t lookupCounter = 0;
                size_t[Matrix4*] transformToId;

                foreach(itEnt; mInstancedEntities)
                {
                    if (itEnt.isInScene())
                    {
                        Matrix4* transformUniqueId = itEnt.mBoneMatrices.ptr;
                        size_t* itLu = transformUniqueId in transformToId;
                        if (itLu is null)
                        {
                            transformToId[transformUniqueId] = lookupCounter;
                            itLu = &transformToId[transformUniqueId];//std::map.insert().first
                            ++lookupCounter;
                        }
                        itEnt.setTransformLookupNumber(cast(ushort)*itLu);
                    }
                    else 
                    {
                        itEnt.setTransformLookupNumber(0);
                    }
                }
                
                if (lookupCounter > getMaxLookupTableInstances())
                {
                    throw new InvalidStateError("Number of unique bone matrix states exceeds current limitation.","BaseInstanceBatchVTF.updateSharedLookupIndexes()");
                }
            }
            
            mTransformSharingDirty = false;
        }
    }

    /** @see InstanceBatch::generateInstancedEntity() */
    override InstancedEntity generateInstancedEntity(size_t num)
    {
        InstancedEntity sharedTransformEntity;
        if ((useBoneMatrixLookup()) && (num >= getMaxLookupTableInstances()))
        {
            sharedTransformEntity = mInstancedEntities[num % getMaxLookupTableInstances()];
            if (sharedTransformEntity.mSharedTransformEntity)
            {
                sharedTransformEntity = sharedTransformEntity.mSharedTransformEntity;
            }
        }
        
        return new InstancedEntity( this, cast(ushort)num, sharedTransformEntity);
    }
    
public:
    this( InstanceManager creator, SharedPtr!Mesh meshReference, SharedPtr!Material material,
         size_t instancesPerBatch, Mesh.IndexMap indexToBoneMap,
         string batchName)
    {
        super( creator, meshReference, material, instancesPerBatch,
              indexToBoneMap, batchName );
        mNumWorldMatrices =  instancesPerBatch ;
        mWidthFloatsPadding =  0 ;
        mMaxFloatsPerLine =  size_t.max;
        mRowLength = 3;
        mWeightCount = 1;
        //mTempTransformsArray3x4 = 0;
        mUseBoneMatrixLookup = false;
        mMaxLookupTableInstances = 16;
        mUseBoneDualQuaternions = false;
        mForceOneWeight = false;
        mUseOneWeight = false;

        cloneMaterial( mMaterial );
    }

    ~this()
    {
        //Remove cloned caster materials (if any)
        auto techItor = mMaterial.getAs().getTechniques();
        foreach(technique; techItor)
        {
            if( !technique.getShadowCasterMaterial().isNull() )
                MaterialManager.getSingleton().remove( technique.getShadowCasterMaterial().get().getName() );
        }
        
        //Remove cloned material
        MaterialManager.getSingleton().remove( mMaterial.getAs().getName() );
        
        //Remove the VTF texture
        if( !mMatrixTexture.isNull() )
            TextureManager.getSingleton().remove( mMatrixTexture.get().getName() );
        
        destroy(mTempTransformsArray3x4);
    }
    
    /** @see InstanceBatch::buildFrom */
    override void buildFrom( SubMesh baseSubMesh, ref RenderOperation renderOperation )
    {
        if (useBoneMatrixLookup())
        {
            //when using bone matrix lookup resource are not shared
            //
            //Future implementation: while the instance vertex buffer can't be shared
            //The texture can be.
            //
            build(baseSubMesh);
        }
        else
        {
            createVertexTexture( baseSubMesh );
            super.buildFrom( baseSubMesh, renderOperation );
        }
    }
    
    //Renderable overloads
    void getWorldTransforms( ref Matrix4[] xform )// const;
    {
        xform.length = 0;
        xform ~= Matrix4.IDENTITY;
    }

    override ushort getNumWorldTransforms() //const;
    {
        return 1;
    }
    
    /** Overloaded to be able to updated the vertex texture */
    override void _updateRenderQueue(RenderQueue queue)
    {
        super._updateRenderQueue( queue );
        
        if( mBoundsUpdated || mDirtyAnimation || mManager.getCameraRelativeRendering() )
            updateVertexTexture();
        
        mBoundsUpdated = false;
    }
    
    /** Sets the state of the usage of bone matrix lookup
     
     Under default condition each instance entity is assigned a specific area in the vertex 
     texture for bone matrix data. When turned on the amount of area in the vertex texture 
     assigned for bone matrix data will be relative to the amount of unique animation states.
     Instanced entities sharing the same animation state will share the same area in the matrix.
     The specific position of each entity is placed in the vertex data and added in a second phase
     in the shader.

     Note this feature only works in VTF_HW for now.
     This value needs to be set before adding any instanced entities
     */
    void setBoneMatrixLookup(bool enable, size_t maxLookupTableInstances) { assert(mInstancedEntities.empty()); 
        mUseBoneMatrixLookup = enable; mMaxLookupTableInstances = maxLookupTableInstances; }
    
    /** Tells whether to use bone matrix lookup
     @see setBoneMatrixLookup()
     */
    bool useBoneMatrixLookup() const { return mUseBoneMatrixLookup; }
    
    void setBoneDualQuaternions(bool enable) { assert(mInstancedEntities.empty());
        mUseBoneDualQuaternions = enable; mRowLength = (mUseBoneDualQuaternions ? 2 : 3); }
    
    bool useBoneDualQuaternions() const { return mUseBoneDualQuaternions; }
    
    void setForceOneWeight(bool enable) {  assert(mInstancedEntities.empty());
        mForceOneWeight = enable; }
    
    bool forceOneWeight() const { return mForceOneWeight; }
    
    void setUseOneWeight(bool enable) {  assert(mInstancedEntities.empty());
        mUseOneWeight = enable; }
    
    bool useOneWeight() const { return mUseOneWeight; }
    
    /** @see InstanceBatch::useBoneWorldMatrices()  */
    override bool useBoneWorldMatrices() //const 
    { return !mUseBoneMatrixLookup; }
    
    /** @return the maximum amount of shared transform entities when using lookup table*/
    size_t getMaxLookupTableInstances() //const 
    { return mMaxLookupTableInstances; }
    
}

class InstanceBatchVTF :  BaseInstanceBatchVTF
{
    
    override void setupVertices( ref SubMesh baseSubMesh )
    {
        mRenderOperation.vertexData = new VertexData();
        mRemoveOwnVertexData = true; //Raise flag to remove our own vertex data in the end (not always needed)
        
        VertexData thisVertexData = mRenderOperation.vertexData;
        VertexData baseVertexData = baseSubMesh.vertexData;
        
        thisVertexData.vertexStart = 0;
        thisVertexData.vertexCount = baseVertexData.vertexCount * mInstancesPerBatch;
        
        HardwareBufferManager.getSingleton().destroyVertexDeclaration( thisVertexData.vertexDeclaration );
        thisVertexData.vertexDeclaration = baseVertexData.vertexDeclaration.clone();
        
        HWBoneIdxVec hwBoneIdx;
        HWBoneWgtVec hwBoneWgt;
        
        //Blend weights may not be present because HW_VTF does not require to be skeletally animated
        VertexElement veWeights = baseVertexData.vertexDeclaration.
            findElementBySemantic( VertexElementSemantic.VES_BLEND_WEIGHTS );
        if( veWeights )
        {
            //One weight is recommended for VTF
            mWeightCount = (forceOneWeight() || useOneWeight()) ?
                1 : veWeights.getSize() / float.sizeof;
        }
        else
        {
            mWeightCount = 1;
        }
        
        hwBoneIdx.length = baseVertexData.vertexCount * mWeightCount;
        
        if( mMeshReference.getAs().hasSkeleton() && !mMeshReference.getAs().getSkeleton().isNull() )
        {
            if(mWeightCount > 1)
            {
                hwBoneWgt.length = baseVertexData.vertexCount * mWeightCount;
                retrieveBoneIdxWithWeights(baseVertexData, hwBoneIdx, hwBoneWgt);
            }
            else
            {
                retrieveBoneIdx( baseVertexData, hwBoneIdx );
                thisVertexData.vertexDeclaration.removeElement( VertexElementSemantic.VES_BLEND_INDICES );
                thisVertexData.vertexDeclaration.removeElement( VertexElementSemantic.VES_BLEND_WEIGHTS );
                
                thisVertexData.vertexDeclaration.closeGapsInSource();
            }
            
        }
        
        foreach(ushort i;0..cast(ushort)(thisVertexData.vertexDeclaration.getMaxSource()+1))
        {
            //Create our own vertex buffer
            SharedPtr!HardwareVertexBuffer vertexBuffer =
                HardwareBufferManager.getSingleton().createVertexBuffer(
                    thisVertexData.vertexDeclaration.getVertexSize(i),
                    thisVertexData.vertexCount,
                    HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY );
            thisVertexData.vertexBufferBinding.setBinding( i, vertexBuffer );
            
            //Grab the base submesh data
            SharedPtr!HardwareVertexBuffer baseVertexBuffer =
                baseVertexData.vertexBufferBinding.getBuffer(i);
            
            ubyte* thisBuf = cast(ubyte*)(vertexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
            ubyte* baseBuf = cast(ubyte*)(baseVertexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
            
            //Copy and repeat
            for( size_t j=0; j<mInstancesPerBatch; ++j )
            {
                const size_t sizeOfBuffer = baseVertexData.vertexCount *
                    baseVertexData.vertexDeclaration.getVertexSize(i);
                memcpy( thisBuf + j * sizeOfBuffer, baseBuf, sizeOfBuffer );
            }
            
            baseVertexBuffer.get().unlock();
            vertexBuffer.get().unlock();
        }
        
        createVertexTexture( baseSubMesh );
        createVertexSemantics( thisVertexData, baseVertexData, hwBoneIdx, hwBoneWgt);
    }

    override void setupIndices( ref SubMesh baseSubMesh )
    {
        mRenderOperation.indexData = new IndexData();
        mRemoveOwnIndexData = true; //Raise flag to remove our own index data in the end (not always needed)
        
        IndexData thisIndexData = mRenderOperation.indexData;
        IndexData baseIndexData = baseSubMesh.indexData;
        
        thisIndexData.indexStart = 0;
        thisIndexData.indexCount = baseIndexData.indexCount * mInstancesPerBatch;
        
        //TODO: Check numVertices is below max supported by GPU
        HardwareIndexBuffer.IndexType indexType = HardwareIndexBuffer.IndexType.IT_16BIT;
        if( mRenderOperation.vertexData.vertexCount > 65535 )
            indexType = HardwareIndexBuffer.IndexType.IT_32BIT;
        thisIndexData.indexBuffer = HardwareBufferManager.getSingleton().createIndexBuffer(
            indexType, thisIndexData.indexCount,
            HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY );
        
        void *buf     = thisIndexData.indexBuffer.get().lock( HardwareBuffer.LockOptions.HBL_DISCARD );
        void *baseBuf = baseIndexData.indexBuffer.get().lock( HardwareBuffer.LockOptions.HBL_READ_ONLY );
        
        ushort *thisBuf16 = cast(ushort*)(buf);
        uint   *thisBuf32 = cast(uint  *)(buf);
        
        for( size_t i=0; i<mInstancesPerBatch; ++i )
        {
            size_t vertexOffset = i * mRenderOperation.vertexData.vertexCount / mInstancesPerBatch;
            
            ushort *initBuf16 = cast(ushort*)(baseBuf);
            uint   *initBuf32 = cast(uint  *)(baseBuf);
            
            for( size_t j=0; j<baseIndexData.indexCount; ++j )
            {
                uint originalVal;
                if( baseSubMesh.indexData.indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_16BIT )
                    originalVal = *initBuf16++;
                else
                    originalVal = *initBuf32++;
                
                if( indexType == HardwareIndexBuffer.IndexType.IT_16BIT )
                    *thisBuf16++ = cast(ushort)(originalVal + vertexOffset);
                else
                    *thisBuf32++ = cast(uint)(originalVal + vertexOffset);
            }
        }
        
        baseIndexData.indexBuffer.get().unlock();
        thisIndexData.indexBuffer.get().unlock();
    }
    
    /** Creates 2 TEXCOORD semantics that will be used to sample the vertex texture */
    override void createVertexSemantics( VertexData thisVertexData, VertexData baseVertexData,
                                        out HWBoneIdxVec hwBoneIdx, out HWBoneWgtVec hwBoneWgt )
    {
        size_t texWidth  = mMatrixTexture.getAs().getWidth();
        size_t texHeight = mMatrixTexture.getAs().getHeight();
        
        //Calculate the texel offsets to correct them offline
        //Akwardly enough, the offset is needed in OpenGL too
        Vector2 texelOffsets;
        //RenderSystem *renderSystem = Root::getSingleton().getRenderSystem();
        texelOffsets.x = /*renderSystem.getHorizontalTexelOffset()*/ -0.5f / cast(float)texWidth;
        texelOffsets.y = /*renderSystem.getVerticalTexelOffset()*/ -0.5f / cast(float)texHeight;
        
        //Only one weight per vertex is supported. It would not only be complex, but prohibitively slow.
        //Put them in a new buffer, since it's 32 bytes aligned :-)
        ushort newSource = cast(ushort)(thisVertexData.vertexDeclaration.getMaxSource() + 1);
        size_t maxFloatsPerVector = 4;
        size_t offset = 0;
        
        for(size_t i = 0; i < mWeightCount; i += maxFloatsPerVector / mRowLength)
        {
            offset += thisVertexData.vertexDeclaration.addElement( newSource, offset, VertexElementType.VET_FLOAT4, 
                                                                  VertexElementSemantic.VES_TEXTURE_COORDINATES,
                                                                  thisVertexData.vertexDeclaration.
                                                                  getNextFreeTextureCoordinate() ).getSize();
            offset += thisVertexData.vertexDeclaration.addElement( newSource, offset, VertexElementType.VET_FLOAT4, 
                                                                  VertexElementSemantic.VES_TEXTURE_COORDINATES,
                                                                  thisVertexData.vertexDeclaration.
                                                                  getNextFreeTextureCoordinate() ).getSize();
        }
        
        //Add the weights (supports up to four, which is Ogre's limit)
        if(mWeightCount > 1)
        {
            thisVertexData.vertexDeclaration.addElement(newSource, offset, VertexElementType.VET_FLOAT4, VertexElementSemantic.VES_BLEND_WEIGHTS,
                                                        thisVertexData.vertexDeclaration.getNextFreeTextureCoordinate() ).getSize();
        }
        
        //Create our own vertex buffer
        SharedPtr!HardwareVertexBuffer vertexBuffer =
            HardwareBufferManager.getSingleton().createVertexBuffer(
                thisVertexData.vertexDeclaration.getVertexSize(newSource),
                thisVertexData.vertexCount,
                HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY );
        thisVertexData.vertexBufferBinding.setBinding( newSource, vertexBuffer );
        
        float *thisFloat = cast(float*)(vertexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
        
        //Copy and repeat
        for( size_t i=0; i<mInstancesPerBatch; ++i )
        {
            for( size_t j=0; j<baseVertexData.vertexCount * mWeightCount; j += mWeightCount )
            {
                size_t numberOfMatricesInLine = 0;
                
                for(size_t wgtIdx = 0; wgtIdx < mWeightCount; ++wgtIdx)
                {
                    for( size_t k=0; k < mRowLength; ++k)
                    {
                        size_t instanceIdx = (hwBoneIdx[j+wgtIdx] + i * mMatricesPerInstance) * mRowLength + k;
                        //x
                        *thisFloat++ = ((instanceIdx % texWidth) / cast(float)texWidth) - cast(float)texelOffsets.x;
                        //y
                        *thisFloat++ = ((instanceIdx / texWidth) / cast(float)texHeight) - cast(float)texelOffsets.y;
                    }
                    
                    ++numberOfMatricesInLine;
                    
                    //If another matrix can't be fit, we're on another line, or if this is the last weight
                    if((numberOfMatricesInLine + 1) * mRowLength > maxFloatsPerVector || (wgtIdx+1) == mWeightCount)
                    {
                        //Place zeroes in the remaining coordinates
                        for ( size_t k=mRowLength * numberOfMatricesInLine; k < maxFloatsPerVector; ++k)
                        {
                            *thisFloat++ = 0.0f;
                            *thisFloat++ = 0.0f;
                        }
                        
                        numberOfMatricesInLine = 0;
                    }
                }
                
                //Don't need to write weights if there is only one
                if(mWeightCount > 1)
                {
                    //Write the weights
                    for(size_t wgtIdx = 0; wgtIdx < mWeightCount; ++wgtIdx)
                    {
                        *thisFloat++ = hwBoneWgt[j+wgtIdx];
                    }
                    
                    //Fill the rest of the line with zeros
                    for(size_t wgtIdx = mWeightCount; wgtIdx < maxFloatsPerVector; ++wgtIdx)
                    {
                        *thisFloat++ = 0.0f;
                    }
                }
            }
        }
        
        vertexBuffer.get().unlock();
        
    }
    
    override bool matricesTogetherPerRow() //const 
    { return false; }

public:
    this( InstanceManager creator, SharedPtr!Mesh meshReference, SharedPtr!Material material,
         size_t instancesPerBatch, Mesh.IndexMap indexToBoneMap,
         string batchName)
    {
        super (creator, meshReference, material, 
               instancesPerBatch, indexToBoneMap, batchName);
    }
    ~this(){}
    
    /** @see InstanceBatch::calculateMaxNumInstances */
    override size_t calculateMaxNumInstances( SubMesh baseSubMesh, ushort flags ) //const
    {
        size_t retVal = 0;
        
        RenderSystem renderSystem = Root.getSingleton().getRenderSystem();
        RenderSystemCapabilities capabilities = renderSystem.getCapabilities();
        
        //VTF must be supported
        if( capabilities.hasCapability( Capabilities.RSC_VERTEX_TEXTURE_FETCH ) )
        {
            //TODO: Check PF_FLOAT32_RGBA is supported (should be, since it was the 1st one)
            size_t numBones = std.algorithm.max( 1, baseSubMesh.blendIndexToBoneIndexMap.length );
            retVal = c_maxTexWidth * c_maxTexHeight / mRowLength / numBones;
            
            if( flags & InstanceManagerFlags.IM_USE16BIT )
            {
                if( baseSubMesh.vertexData.vertexCount * retVal > 0xFFFF )
                    retVal = 0xFFFF / baseSubMesh.vertexData.vertexCount;
            }
            
            if( flags & InstanceManagerFlags.IM_VTFBESTFIT )
            {
                size_t instancesPerBatch = std.algorithm.min( retVal, mInstancesPerBatch );
                //Do the same as in createVertexTexture()
                size_t numWorldMatrices = instancesPerBatch * numBones;
                
                size_t texWidth  = std.algorithm.min( numWorldMatrices * mRowLength, c_maxTexWidth );
                size_t texHeight = numWorldMatrices * mRowLength / c_maxTexWidth;
                
                size_t remainder = (numWorldMatrices * mRowLength) % c_maxTexWidth;
                
                if( remainder && texHeight > 0 )
                    retVal = cast(size_t)(texWidth * texHeight / cast(float)mRowLength / cast(float)(numBones));
            }
        }
        
        return retVal;
        
    }
}

/** Instancing implementation using vertex texture through Vertex Texture Fetch (VTF) and
 hardware instancing.
 @see BaseInstanceBatchVTF and @see InstanceBatchHW

 The advantage over TextureVTF technique, is that this implements a basic culling algorithm
 to avoid useless processing in vertex shader and uses a lot less VRAM and memory bandwidth

 Basically it has the benefits of both TextureVTF (skeleton animations) and HWInstancingBasic
 (lower memory consumption and basic culling) techniques

 @remarks
 Design discussion webpage: http://www.ogre3d.org/forums/viewtopic.php?f=4&t=59902
 @author
 Matias N. Goldberg ("dark_sylinc")
 @version
 1.2
 */
class InstanceBatchHW_VTF : BaseInstanceBatchVTF
{
protected:
    bool    mKeepStatic;
    
    //Pointer to the buffer containing the per instance vertex data
    SharedPtr!HardwareVertexBuffer mInstanceVertexBuffer;
    
    override void setupVertices( ref SubMesh baseSubMesh )
    {
        mRenderOperation.vertexData = new VertexData();
        mRemoveOwnVertexData = true; //Raise flag to remove our own vertex data in the end (not always needed)
        
        VertexData thisVertexData = mRenderOperation.vertexData;
        VertexData baseVertexData = baseSubMesh.vertexData;
        
        thisVertexData.vertexStart = 0;
        thisVertexData.vertexCount = baseVertexData.vertexCount;
        mRenderOperation.numberOfInstances = mInstancesPerBatch;
        
        HardwareBufferManager.getSingleton().destroyVertexDeclaration(
            thisVertexData.vertexDeclaration );
        thisVertexData.vertexDeclaration = baseVertexData.vertexDeclaration.clone();
        
        //Reuse all vertex buffers
        foreach(bufferIdx, vBuf; baseVertexData.vertexBufferBinding.getBindings())
        {
            thisVertexData.vertexBufferBinding.setBinding( bufferIdx, vBuf );
        }
        
        //Remove the blend weights & indices
        HWBoneIdxVec hwBoneIdx;
        HWBoneWgtVec hwBoneWgt;
        
        //Blend weights may not be present because HW_VTF does not require to be skeletally animated
        VertexElement veWeights = baseVertexData.vertexDeclaration.
            findElementBySemantic( VertexElementSemantic.VES_BLEND_WEIGHTS ); 
        if( veWeights )
            mWeightCount = forceOneWeight() ? 1 : veWeights.getSize() / float.sizeof;
        else
            mWeightCount = 1;
        
        hwBoneIdx.length = baseVertexData.vertexCount * mWeightCount;
        
        if( mMeshReference.getAs().hasSkeleton() && !mMeshReference.getAs().getSkeleton().isNull() )
        {
            if(mWeightCount > 1)
            {
                hwBoneWgt.length = baseVertexData.vertexCount * mWeightCount;
                retrieveBoneIdxWithWeights(baseVertexData, hwBoneIdx, hwBoneWgt);
            }
            else
            {
                retrieveBoneIdx( baseVertexData, hwBoneIdx );
            }
            
            VertexElement pElement = thisVertexData.vertexDeclaration.findElementBySemantic
                (VertexElementSemantic.VES_BLEND_INDICES);
            if (pElement) 
            {
                ushort skelDataSource = pElement.getSource();
                thisVertexData.vertexDeclaration.removeElement( VertexElementSemantic.VES_BLEND_INDICES );
                thisVertexData.vertexDeclaration.removeElement( VertexElementSemantic.VES_BLEND_WEIGHTS );
                if (thisVertexData.vertexDeclaration.findElementsBySource(skelDataSource).empty())
                {
                    thisVertexData.vertexDeclaration.closeGapsInSource();
                    thisVertexData.vertexBufferBinding.unsetBinding(skelDataSource);
                    VertexBufferBinding.BindingIndexMap tmpMap;
                    thisVertexData.vertexBufferBinding.closeGaps(tmpMap);
                }
            }
        }
        
        createVertexTexture( baseSubMesh );
        createVertexSemantics( thisVertexData, baseVertexData, hwBoneIdx, hwBoneWgt);
    }

    override void setupIndices( ref SubMesh baseSubMesh )
    {
        //We could use just a reference, but the InstanceManager will in the end attampt to delete
        //the pointer, and we can't give it something that doesn't belong to us.
        mRenderOperation.indexData = baseSubMesh.indexData.clone( true );
        mRemoveOwnIndexData = true; //Raise flag to remove our own index data in the end (not always needed)
    }

    /** Creates 2 TEXCOORD semantics that will be used to sample the vertex texture */
    override void createVertexSemantics( VertexData thisVertexData, VertexData baseVertexData,
                               out HWBoneIdxVec hwBoneIdx, out HWBoneWgtVec hwBoneWgt )
    {
        float texWidth  = cast(float)mMatrixTexture.getAs().getWidth();
        
        //Only one weight per vertex is supported. It would not only be complex, but prohibitively slow.
        //Put them in a new buffer, since it's 16 bytes aligned :-)
        ushort newSource = cast(ushort)(thisVertexData.vertexDeclaration.getMaxSource() + 1);
        
        size_t offset = 0;
        
        size_t maxFloatsPerVector = 4;
        
        //Can fit two dual quaternions in every float4, but only one 3x4 matrix
        for(size_t i = 0; i < mWeightCount; i += maxFloatsPerVector / mRowLength)
        {
            offset += thisVertexData.vertexDeclaration.addElement( newSource, offset, VertexElementType.VET_FLOAT4, 
                                                                  VertexElementSemantic.VES_TEXTURE_COORDINATES,
                                                                  thisVertexData.vertexDeclaration.getNextFreeTextureCoordinate() ).getSize();
        }
        
        //Add the weights (supports up to four, which is Ogre's limit)
        if(mWeightCount > 1)
        {
            thisVertexData.vertexDeclaration.addElement(newSource, offset, VertexElementType.VET_FLOAT4, 
                                                        VertexElementSemantic.VES_BLEND_WEIGHTS,
                                                        0 ).getSize();
        }
        
        //Create our own vertex buffer
        SharedPtr!HardwareVertexBuffer vertexBuffer =
            HardwareBufferManager.getSingleton().createVertexBuffer(
                thisVertexData.vertexDeclaration.getVertexSize(newSource),
                thisVertexData.vertexCount,
                HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY );
        thisVertexData.vertexBufferBinding.setBinding( newSource, vertexBuffer );
        
        float *thisFloat = cast(float*)(vertexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
        
        //Create the UVs to sample from the right bone/matrix
        for( size_t j=0; j < baseVertexData.vertexCount * mWeightCount; j += mWeightCount)
        {
            size_t numberOfMatricesInLine = 0;
            
            //Write the matrices, adding padding as needed
            for(size_t i = 0; i < mWeightCount; ++i)
            {
                //Write the matrix
                for( size_t k=0; k < mRowLength; ++k)
                {
                    //Only calculate U (not V) since all matrices are in the same row. We use the instanced
                    //(repeated) buffer to tell how much U & V we need to offset
                    size_t instanceIdx = hwBoneIdx[j+i] * mRowLength + k;
                    *thisFloat++ = instanceIdx / texWidth;
                }
                
                ++numberOfMatricesInLine;
                
                //If another matrix can't be fit, we're on another line, or if this is the last weight
                if((numberOfMatricesInLine + 1) * mRowLength > maxFloatsPerVector || (i+1) == mWeightCount)
                {
                    //Place zeroes in the remaining coordinates
                    for ( size_t k=mRowLength * numberOfMatricesInLine; k < maxFloatsPerVector; ++k)
                    {
                        *thisFloat++ = 0.0f;
                    }
                    
                    numberOfMatricesInLine = 0;
                }
            }
            
            //Don't need to write weights if there is only one
            if(mWeightCount > 1)
            {
                //Write the weights
                for(size_t i = 0; i < mWeightCount; ++i)
                {
                    *thisFloat++ = hwBoneWgt[j+i];
                }
                
                //Write the empty space
                for(size_t i = mWeightCount; i < maxFloatsPerVector; ++i)
                {
                    *thisFloat++ = 0.0f;
                }
            }
        }
        
        vertexBuffer.get().unlock();
        
        //Now create the instance buffer that will be incremented per instance, contains UV offsets
        newSource = cast(ushort)(thisVertexData.vertexDeclaration.getMaxSource() + 1);
        offset = thisVertexData.vertexDeclaration.addElement( newSource, 0, VertexElementType.VET_FLOAT2, 
                                                             VertexElementSemantic.VES_TEXTURE_COORDINATES,
                                                             thisVertexData.vertexDeclaration.getNextFreeTextureCoordinate() ).getSize();
        if (useBoneMatrixLookup())
        {
            //if using bone matrix lookup we will need to add 3 more float4 to contain the matrix. containing
            //the personal world transform of each entity.
            offset += thisVertexData.vertexDeclaration.addElement( newSource, offset, VertexElementType.VET_FLOAT4, VertexElementSemantic.VES_TEXTURE_COORDINATES,
                                                                  thisVertexData.vertexDeclaration.getNextFreeTextureCoordinate() ).getSize();
            offset += thisVertexData.vertexDeclaration.addElement( newSource, offset, VertexElementType.VET_FLOAT4, VertexElementSemantic.VES_TEXTURE_COORDINATES,
                                                                  thisVertexData.vertexDeclaration.getNextFreeTextureCoordinate() ).getSize();
            thisVertexData.vertexDeclaration.addElement( newSource, offset, VertexElementType.VET_FLOAT4, VertexElementSemantic.VES_TEXTURE_COORDINATES,
                                                        thisVertexData.vertexDeclaration.getNextFreeTextureCoordinate() ).getSize();
            //Add two floats of padding here? or earlier?
            //If not using bone matrix lookup, is it ok that it is 8 bytes since divides evenly into 16
            
        }
        
        //Create our own vertex buffer
        mInstanceVertexBuffer = HardwareBufferManager.getSingleton().createVertexBuffer(
            thisVertexData.vertexDeclaration.getVertexSize(newSource),
            mInstancesPerBatch,
            HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY );
        thisVertexData.vertexBufferBinding.setBinding( newSource, mInstanceVertexBuffer );

        //Mark this buffer as instanced
        mInstanceVertexBuffer.get().setIsInstanceData( true );
        mInstanceVertexBuffer.get().setInstanceDataStepRate( 1 );
        Camera c = null;
        updateInstanceDataBuffer(true, c);
    }
    
    /** updates the vertex buffer containing the per instance data 
     @param[in] isFirstTime Tells if this is the first time the buffer is being updated
     @param[in] currentCamera The camera being used for render (valid when using bone matrix lookup)
     @return The number of instances to be rendered
     */
    size_t updateInstanceDataBuffer(bool isFirstTime, ref Camera currentCamera)
    {
        size_t visibleEntityCount = 0;
        bool useMatrixLookup = useBoneMatrixLookup();
        if (isFirstTime ^ useMatrixLookup)
        {
            //update the mTransformLookupNumber value in the entities if needed 
            updateSharedLookupIndexes();
            
            float texWidth  = cast(float)(mMatrixTexture.getAs().getWidth());
            float texHeight = cast(float)(mMatrixTexture.getAs().getHeight());
            
            //Calculate the texel offsets to correct them offline
            //Awkwardly enough, the offset is needed in OpenGL too
            Vector2 texelOffsets;
            //RenderSystem *renderSystem = Root::getSingleton().getRenderSystem();
            texelOffsets.x = /*renderSystem.getHorizontalTexelOffset()*/ -0.5f / texWidth;
            texelOffsets.y = /*renderSystem.getHorizontalTexelOffset()*/ -0.5f / texHeight;
            
            float *thisVec = cast(float*)(mInstanceVertexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
            
            size_t maxPixelsPerLine = std.algorithm.min( mMatrixTexture.getAs().getWidth(), mMaxFloatsPerLine >> 2 );
            
            //Calculate UV offsets, which change per instance
            for( size_t i=0; i<mInstancesPerBatch; ++i )
            {
                InstancedEntity entity = useMatrixLookup ? mInstancedEntities[i] : null;
                if  //Update if we are not using a lookup bone matrix method. In this case the function will 
                    //be called only once
                    (!useMatrixLookup || 
                     //Update if we are in the visible range of the camera (for look up bone matrix method
                     //and static mode).
                     (entity.findVisible(currentCamera)))
                {
                    size_t matrixIndex = useMatrixLookup ? entity.mTransformLookupNumber : i;
                    size_t instanceIdx = matrixIndex * mMatricesPerInstance * mRowLength;
                    *thisVec = ((instanceIdx % maxPixelsPerLine) / texWidth) - cast(float)(texelOffsets.x);
                    *(thisVec + 1) = ((instanceIdx / maxPixelsPerLine) / texHeight) - cast(float)(texelOffsets.y);
                    thisVec += 2;
                    
                    if (useMatrixLookup)
                    {
                        Matrix4 mat =  entity._getParentNodeFullTransform();
                        *(thisVec)     = cast(float)( mat[0][0] );
                        *(thisVec + 1) = cast(float)( mat[0][1] );
                        *(thisVec + 2) = cast(float)( mat[0][2] );
                        *(thisVec + 3) = cast(float)( mat[0][3] );
                        *(thisVec + 4) = cast(float)( mat[1][0] );
                        *(thisVec + 5) = cast(float)( mat[1][1] );
                        *(thisVec + 6) = cast(float)( mat[1][2] );
                        *(thisVec + 7) = cast(float)( mat[1][3] );
                        *(thisVec + 8) = cast(float)( mat[2][0] );
                        *(thisVec + 9) = cast(float)( mat[2][1] );
                        *(thisVec + 10)= cast(float)( mat[2][2] );
                        *(thisVec + 11)= cast(float)( mat[2][3] );
                        if(currentCamera && mManager.getCameraRelativeRendering()) // && useMatrixLookup
                        {
                            Vector3 cameraRelativePosition = currentCamera.getDerivedPosition();
                            *(thisVec + 3) -= cast(float)( cameraRelativePosition.x );
                            *(thisVec + 7) -= cast(float)( cameraRelativePosition.y );
                            *(thisVec + 11) -=  cast(float)( cameraRelativePosition.z );
                        }
                        thisVec += 12;
                    }
                    ++visibleEntityCount;
                }
            }
            
            mInstanceVertexBuffer.get().unlock();
        }
        else
        {
            visibleEntityCount = mInstancedEntities.length;
        }
        return visibleEntityCount;
    }
    
    
    override bool checkSubMeshCompatibility( ref SubMesh baseSubMesh )
    {
        //Max number of texture coordinates is _usually_ 8, we need at least 2 available
        ushort neededTextureCoord = 2;
        if (useBoneMatrixLookup())
        {
            //we need another 3 for the unique world transform of each instanced entity
            neededTextureCoord += 3;
        }
        if( baseSubMesh.vertexData.vertexDeclaration.getNextFreeTextureCoordinate() > 8 - neededTextureCoord )
        {
            throw new NotImplementedError(
                "Given mesh must have at least "~
                std.conv.to!string(neededTextureCoord) ~ "free TEXCOORDs",
                "InstanceBatchHW_VTF.checkSubMeshCompatibility");
        }
        
        return super.checkSubMeshCompatibility( baseSubMesh );
    }
    
    /** Keeps filling the VTF with world matrix data. Overloaded to avoid culled objects
     and update visible instances' animation
     */
    size_t updateVertexTexture( ref Camera currentCamera )
    {
        size_t renderedInstances = 0;
        bool useMatrixLookup = useBoneMatrixLookup();
        if (useMatrixLookup)
        {
            //if we are using bone matrix look up we have to update the instance buffer for the 
            //vertex texture to be relevant
            
            //also note that in this case the number of instances to render comes directly from the 
            //updateInstanceDataBuffer() function, not from this function.
            renderedInstances = updateInstanceDataBuffer(false, currentCamera);
        }
        
        
        mDirtyAnimation = false;
        
        //Now lock the texture and copy the 4x3 matrices!
        mMatrixTexture.getAs().getBuffer().get().lock( HardwareBuffer.LockOptions.HBL_DISCARD );
        PixelBox pixelBox = mMatrixTexture.getAs().getBuffer().get().getCurrentLock();
        
        float *pSource = cast(float*)(pixelBox.data);
        
        //InstancedEntityVec::const_iterator itor = mInstancedEntities.begin();
        
        bool[] writtenPositions;
        writtenPositions.length = getMaxLookupTableInstances();
        writtenPositions[] = false;
        
        size_t floatPerEntity = mMatricesPerInstance * mRowLength * 4;
        size_t entitiesPerPadding = cast(size_t)(mMaxFloatsPerLine / floatPerEntity);
        
        size_t instanceCount = mInstancedEntities.length;
        size_t updatedInstances = 0;
        
        float* transforms = null;
        //If using dual quaternions, write 3x4 matrices to a temporary buffer, then convert to dual quaternions
        if(mUseBoneDualQuaternions)
        {
            transforms = mTempTransformsArray3x4.ptr;
        }
        
        for(size_t i = 0 ; i < instanceCount ; ++i)
        {
            InstancedEntity entity = mInstancedEntities[i];
            size_t textureLookupPosition = updatedInstances;
            if (useMatrixLookup)
            {
                textureLookupPosition = entity.mTransformLookupNumber;
            }
            //Check that we are not using a lookup matrix or that we have not already written
            //The bone data
            if (((!useMatrixLookup) || !writtenPositions[entity.mTransformLookupNumber]) &&
                //Cull on an individual basis, the less entities are visible, the less instances we draw.
                //No need to use null matrices at all!
                (entity.findVisible( currentCamera )))
            {
                float* pDest = pSource + floatPerEntity * textureLookupPosition + 
                    cast(size_t)(textureLookupPosition / entitiesPerPadding) * mWidthFloatsPadding;
                
                if(!mUseBoneDualQuaternions)
                {
                    transforms = pDest;
                }
                
                if( mMeshReference.getAs().hasSkeleton() )
                    mDirtyAnimation |= entity._updateAnimation();
                
                size_t floatsWritten = entity.getTransforms3x4( transforms );
                
                if( !useMatrixLookup && mManager.getCameraRelativeRendering() )
                    makeMatrixCameraRelative3x4( transforms, floatsWritten );
                
                if(mUseBoneDualQuaternions)
                {
                    convert3x4MatricesToDualQuaternions(transforms, floatsWritten / 12, pDest);
                }
                
                if (useMatrixLookup)
                {
                    writtenPositions[entity.mTransformLookupNumber] = true;
                }
                else
                {
                    ++updatedInstances;
                }
            }
            
            // ++itor; //TODO uh?
        }
        
        if (!useMatrixLookup)
        {
            renderedInstances = updatedInstances;
        }
        
        mMatrixTexture.getAs().getBuffer().get().unlock();
        
        return renderedInstances;
    }

    override bool matricesTogetherPerRow() //const
    { return true; }
public:
    enum ushort c_maxTexWidthHW  = 4096;
    enum ushort c_maxTexHeightHW = 4096;

    this( InstanceManager creator, SharedPtr!Mesh meshReference, SharedPtr!Material material,
         size_t instancesPerBatch, Mesh.IndexMap indexToBoneMap,
         string batchName )
    {
        super( creator, meshReference, material, 
              instancesPerBatch, indexToBoneMap, batchName);
        mKeepStatic = false;
    }

    ~this() {}

    /** @see InstanceBatch::calculateMaxNumInstances */
    override size_t calculateMaxNumInstances( SubMesh baseSubMesh, ushort flags )// const;
    {
        size_t retVal = 0;
        
        RenderSystem renderSystem = Root.getSingleton().getRenderSystem();
        RenderSystemCapabilities capabilities = renderSystem.getCapabilities();
        
        //VTF & HW Instancing must be supported
        if( capabilities.hasCapability( Capabilities.RSC_VERTEX_BUFFER_INSTANCE_DATA ) &&
           capabilities.hasCapability( Capabilities.RSC_VERTEX_TEXTURE_FETCH ) )
        {
            //TODO: Check PF_FLOAT32_RGBA is supported (should be, since it was the 1st one)
            size_t numBones = std.algorithm.max( 1, baseSubMesh.blendIndexToBoneIndexMap.length );
            
            size_t maxUsableWidth = c_maxTexWidthHW - (c_maxTexWidthHW % (numBones * mRowLength));
            
            //See InstanceBatchHW::calculateMaxNumInstances for the 65535
            retVal = std.algorithm.min( 65535, maxUsableWidth * c_maxTexHeightHW / mRowLength / numBones );
            
            if( flags & InstanceManagerFlags.IM_VTFBESTFIT )
            {
                size_t numUsedSkeletons = mInstancesPerBatch;
                if (flags & InstanceManagerFlags.IM_VTFBONEMATRIXLOOKUP)
                    numUsedSkeletons = std.algorithm.min(getMaxLookupTableInstances(), numUsedSkeletons);
                size_t instancesPerBatch = std.algorithm.min( retVal, numUsedSkeletons );
                //Do the same as in createVertexTexture(), but changing c_maxTexWidthHW for maxUsableWidth
                size_t numWorldMatrices = instancesPerBatch * numBones;
                
                size_t texWidth  = std.algorithm.min( numWorldMatrices * mRowLength, maxUsableWidth );
                size_t texHeight = numWorldMatrices * mRowLength / maxUsableWidth;
                
                size_t remainder = (numWorldMatrices * mRowLength) % maxUsableWidth;
                
                if( remainder && texHeight > 0 )
                    retVal = cast(size_t)(texWidth * texHeight / cast(float)mRowLength / cast(float)(numBones));
            }
        }
        
        return retVal;
    }
    
    /** @copydoc InstanceBatchHW::_boundsDirty */
    override void _boundsDirty()
    {
        //Don't update if we're static, but still mark we're dirty
        if( !mBoundsDirty && !mKeepStatic && mCreator)
            mCreator._addDirtyBatch( this );
        mBoundsDirty = true;
    }

    /** @copydoc InstanceBatchHW::setStaticAndUpdate */
    override void setStaticAndUpdate( bool bStatic )
    {
        //We were dirty but didn't update bounds. Do it now.
        if( mKeepStatic && mBoundsDirty )
            mCreator._addDirtyBatch( this );
        
        mKeepStatic = bStatic;
        if( mKeepStatic )
        {
            //One final update, since there will be none from now on
            //(except further calls to this function). Pass NULL because
            //we want to include only those who were added to the scene
            //but we don't want to perform culling
            Camera c = null;
            mRenderOperation.numberOfInstances = updateVertexTexture( c );
        }
    }
    
    override bool isStatic() const { return mKeepStatic; }
    
    /** Overloaded to visibility on a per unit basis and finally updated the vertex texture */
    override void _updateRenderQueue( RenderQueue queue )
    {
        if( !mKeepStatic )
        {
            //Completely override base functionality, since we don't cull on an "all-or-nothing" basis
            if( (mRenderOperation.numberOfInstances = updateVertexTexture( mCurrentCamera )) > 0)
                queue.addRenderable( this, mRenderQueueID, mRenderQueuePriority );
        }
        else
        {
            if( mManager.getCameraRelativeRendering() )
            {
                throw new InvalidStateError("Camera-relative rendering is incompatible"
                                            " with Instancing's static batches. Disable at least one of them",
                                            "InstanceBatch._updateRenderQueue");
            }
            
            //Don't update when we're static
            if( mRenderOperation.numberOfInstances )
                queue.addRenderable( this, mRenderQueueID, mRenderQueuePriority );
        }
    }
}

/** This is technique requires true instancing hardware support.
        Basically it creates a cloned vertex buffer from the original, with an extra buffer containing
        3 additional TEXCOORDS (12 bytes) repeated as much as the instance count.
        That will be used for each instance data.
        @par
        The main advantage of this technique is that it's <u>VERY</u> fast; but it doesn't support
        skeletal animation at all. Very reduced memory consumption and bandwidth. Great for particles,
        debris, bricks, trees, sprites.
        This batch is one of the few (if not the only) techniques that allows culling on an individual
        basis. This means we can save vertex shader performance for instances that aren't in scene or
        just not focused by the camera.

        @remarks
            Design discussion webpage: http://www.ogre3d.org/forums/viewtopic.php?f=4&t=59902
        @author
            Matias N. Goldberg ("dark_sylinc")
        @version
            1.1
     */
class InstanceBatchHW : InstanceBatch
{
    bool    mKeepStatic;
    
    override void setupVertices( ref SubMesh baseSubMesh )
    {
        mRenderOperation.vertexData = baseSubMesh.vertexData.clone();
        mRemoveOwnVertexData = true; //Raise flag to remove our own vertex data in the end (not always needed)
        
        VertexData thisVertexData = mRenderOperation.vertexData;
        
        //No skeletal animation support in this technique, sorry
        removeBlendData();
        
        //Modify the declaration so it contains an extra source, where we can put the per instance data
        size_t offset               = 0;
        ushort nextTexCoord = thisVertexData.vertexDeclaration.getNextFreeTextureCoordinate();
        ushort newSource = cast(ushort)(thisVertexData.vertexDeclaration.getMaxSource() + 1);
        for( ubyte i=0; i<3 + mCreator.getNumCustomParams(); ++i )
        {
            thisVertexData.vertexDeclaration.addElement( newSource, offset, VertexElementType.VET_FLOAT4,
                                                        VertexElementSemantic.VES_TEXTURE_COORDINATES, nextTexCoord++ );
            offset = thisVertexData.vertexDeclaration.getVertexSize( newSource );
        }
        
        //Create the vertex buffer containing per instance data
        SharedPtr!HardwareVertexBuffer vertexBuffer =
            HardwareBufferManager.getSingleton().createVertexBuffer(
                thisVertexData.vertexDeclaration.getVertexSize(newSource),
                mInstancesPerBatch,
                HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY );
        thisVertexData.vertexBufferBinding.setBinding( newSource, vertexBuffer );
        vertexBuffer.get().setIsInstanceData( true );
        vertexBuffer.get().setInstanceDataStepRate( 1 );
    }

    override void setupIndices( ref SubMesh baseSubMesh )
    {
        //We could use just a reference, but the InstanceManager will in the end attampt to delete
        //the pointer, and we can't give it something that doesn't belong to us.
        mRenderOperation.indexData = baseSubMesh.indexData.clone( true );
        mRemoveOwnIndexData = true; //Raise flag to remove our own index data in the end (not always needed)
    }

    
    void removeBlendData()
    {
        VertexData thisVertexData = mRenderOperation.vertexData;
        
        ushort safeSource = 0xFFFF;
        VertexElement blendIndexElem = thisVertexData.vertexDeclaration.findElementBySemantic(
            VertexElementSemantic.VES_BLEND_INDICES );
        if( blendIndexElem )
        {
            //save the source in order to prevent the next stage from unbinding it.
            safeSource = blendIndexElem.getSource();
            // Remove buffer reference
            thisVertexData.vertexBufferBinding.unsetBinding( blendIndexElem.getSource() );
        }
        // Remove blend weights
        VertexElement blendWeightElem = thisVertexData.vertexDeclaration.findElementBySemantic(
            VertexElementSemantic.VES_BLEND_WEIGHTS );
        if( blendWeightElem && blendWeightElem.getSource() != safeSource )
        {
            // Remove buffer reference
            thisVertexData.vertexBufferBinding.unsetBinding( blendWeightElem.getSource() );
        }
        
        thisVertexData.vertexDeclaration.removeElement(VertexElementSemantic.VES_BLEND_INDICES);
        thisVertexData.vertexDeclaration.removeElement(VertexElementSemantic.VES_BLEND_WEIGHTS);
        thisVertexData.closeGapsInBindings();
    }

    override bool checkSubMeshCompatibility( ref SubMesh baseSubMesh )
    {
        //Max number of texture coordinates is _usually_ 8, we need at least 3 available
        if( baseSubMesh.vertexData.vertexDeclaration.getNextFreeTextureCoordinate() > 8-2 )
        {
            throw new NotImplementedError("Given mesh must have at "
                        "least 3 free TEXCOORDs",
                        "InstanceBatchHW.checkSubMeshCompatibility");
        }
        if( baseSubMesh.vertexData.vertexDeclaration.getNextFreeTextureCoordinate() >
           8-2-mCreator.getNumCustomParams() ||
           3 + mCreator.getNumCustomParams() >= 8 )
        {
            throw new InvalidParamsError("There are not enough free TEXCOORDs to hold the "
                        "custom parameters (required: " ~
                        std.conv.to!string( 3 + mCreator.
                                            getNumCustomParams() ) ~ "). See InstanceManager"
                        ".setNumCustomParams documentation",
                        "InstanceBatchHW.checkSubMeshCompatibility");
        }
        
        return super.checkSubMeshCompatibility( baseSubMesh );
    }
    
    size_t updateVertexBuffer( ref Camera currentCamera )
    {
        size_t retVal = 0;
        
        //Now lock the vertex buffer and copy the 4x3 matrices, only those who need it!
        ushort bufferIdx = cast(ushort)(mRenderOperation.vertexData.vertexBufferBinding.getBufferCount()-1);
        float *pDest = cast(float*)(mRenderOperation.vertexData.vertexBufferBinding.
                                           getBuffer(bufferIdx).get().lock( HardwareBuffer.LockOptions.HBL_DISCARD ));

        ubyte numCustomParams = mCreator.getNumCustomParams();
        size_t customParamIdx = 0;
        
        foreach(itor; mInstancedEntities)
        {
            //Cull on an individual basis, the less entities are visible, the less instances we draw.
            //No need to use null matrices at all!
            if( itor.findVisible( currentCamera ) )
            {
                size_t floatsWritten = itor.getTransforms3x4( pDest );
                
                if( mManager.getCameraRelativeRendering() )
                    makeMatrixCameraRelative3x4( pDest, floatsWritten );
                
                pDest += floatsWritten;
                
                //Write custom parameters, if any
                for( ubyte i=0; i<numCustomParams; ++i )
                {
                    *pDest++ = mCustomParams[customParamIdx+i].x;
                    *pDest++ = mCustomParams[customParamIdx+i].y;
                    *pDest++ = mCustomParams[customParamIdx+i].z;
                    *pDest++ = mCustomParams[customParamIdx+i].w;
                }
                
                ++retVal;
            }
            
            customParamIdx += numCustomParams;
        }
        
        mRenderOperation.vertexData.vertexBufferBinding.getBuffer(bufferIdx).get().unlock();
        
        return retVal;
    }
    
public:
    this( InstanceManager creator, SharedPtr!Mesh meshReference, SharedPtr!Material material,
                    size_t instancesPerBatch, Mesh.IndexMap indexToBoneMap,
                    string batchName )
    {
        super( creator, meshReference, material, instancesPerBatch,
                      indexToBoneMap, batchName );
        mKeepStatic = false;
        //Override defaults, so that InstancedEntities don't create a skeleton instance
        mTechnSupportsSkeletal = false;
    }

    ~this(){}
    
    /** @see InstanceBatch::calculateMaxNumInstances */
    override size_t calculateMaxNumInstances( SubMesh baseSubMesh, ushort flags )// const;
    {
        size_t retVal = 0;
        
        RenderSystem renderSystem = Root.getSingleton().getRenderSystem();
        RenderSystemCapabilities capabilities = renderSystem.getCapabilities();
        
        if( capabilities.hasCapability( Capabilities.RSC_VERTEX_BUFFER_INSTANCE_DATA ) )
        {
            //This value is arbitrary (theorical max is 2^30 for D3D9) but is big enough and safe
            retVal = 65535;
        }
        
        return retVal;
    }

    /** @see InstanceBatch::buildFrom */
    override void buildFrom( SubMesh baseSubMesh, ref RenderOperation renderOperation )
    {
        super.buildFrom( baseSubMesh, renderOperation );
        
        //We need to clone the VertexData (but just reference all buffers, except the last one)
        //because last buffer contains data specific to this batch, we need a different binding
        mRenderOperation.vertexData = mRenderOperation.vertexData.clone( false );
        VertexData thisVertexData   = mRenderOperation.vertexData;
        ushort lastSource = thisVertexData.vertexDeclaration.getMaxSource();
        SharedPtr!HardwareVertexBuffer vertexBuffer =
            HardwareBufferManager.getSingleton().createVertexBuffer(
                thisVertexData.vertexDeclaration.getVertexSize(lastSource),
                mInstancesPerBatch,
                HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY );
        thisVertexData.vertexBufferBinding.setBinding( lastSource, vertexBuffer );
        vertexBuffer.get().setIsInstanceData( true );
        vertexBuffer.get().setInstanceDataStepRate( 1 );
    }
    
    /** Overloaded so that we don't perform needless updates when in static mode. Also doing that
            could cause glitches with shadow mapping (since Ogre thinks we're small/bigger than we
            really are when displaying, or that we're somewhere else)
        */
    override void _boundsDirty()
    {
        //Don't update if we're static, but still mark we're dirty
        if( !mBoundsDirty && !mKeepStatic )
            mCreator._addDirtyBatch( this );
        mBoundsDirty = true;
    }
    
    /** @see InstanceBatch::setStaticAndUpdate. While this flag is true, no individual per-entity
            cull check is made. This means if the camera is looking at only one instance, all instances
            are sent to the vertex shader (unlike when this flag is false). This saves a lot of CPU
            power and a bit of bus bandwidth.
        */
    override void setStaticAndUpdate( bool bStatic )
    {
        //We were dirty but didn't update bounds. Do it now.
        if( mKeepStatic && mBoundsDirty )
            mCreator._addDirtyBatch( this );
        
        mKeepStatic = bStatic;
        if( mKeepStatic )
        {
            //One final update, since there will be none from now on
            //(except further calls to this function). Pass NULL because
            //we want to include only those who were added to the scene
            //but we don't want to perform culling
            Camera c;
            mRenderOperation.numberOfInstances = updateVertexBuffer( c );
        }
    }
    
    override bool isStatic() const { return mKeepStatic; }
    
    //Renderable overloads
    void getWorldTransforms( ref Matrix4[] xform )// const;
    {
        xform.length = 0;
        xform ~= Matrix4.IDENTITY;
    }
    override ushort getNumWorldTransforms() const
    {
        return 1;
    }
    
    /** Overloaded to avoid updating skeletons (which we don't support), check visibility on a
            per unit basis and finally updated the vertex buffer */
    override void _updateRenderQueue( RenderQueue queue )
    {
        if( !mKeepStatic )
        {
            //Completely override base functionality, since we don't cull on an "all-or-nothing" basis
            //and we don't support skeletal animation
            if( (mRenderOperation.numberOfInstances = updateVertexBuffer( mCurrentCamera )) >0 )
                queue.addRenderable( this, mRenderQueueID, mRenderQueuePriority );
        }
        else
        {
            if( mManager.getCameraRelativeRendering() )
            {
                throw new InvalidStateError("Camera-relative rendering is incompatible"
                            " with Instancing's static batches. Disable at least one of them",
                            "InstanceBatch._updateRenderQueue");
            }
            
            //Don't update when we're static
            if( mRenderOperation.numberOfInstances )
                queue.addRenderable( this, mRenderQueueID, mRenderQueuePriority );
        }
    }
}

/*@}*/
/*@}*/