module ogre.scene.entity;

//import std.container;
import std.array;
//import std.range;

import ogre.animation.animations;
import ogre.compat;
import ogre.exception;
import ogre.general.common;
import ogre.general.generals;
import ogre.general.root;
import ogre.lod.lodstrategy;
import ogre.materials.material;
import ogre.materials.materialmanager;
import ogre.materials.pass;
import ogre.math.axisalignedbox;
import ogre.math.edgedata;
import ogre.math.matrix;
import ogre.math.optimisedutil;
import ogre.math.quaternion;
import ogre.math.sphere;
import ogre.math.vector;
import ogre.rendersystem.hardware;
import ogre.rendersystem.renderqueue;
import ogre.rendersystem.vertex;
import ogre.resources.mesh;
import ogre.resources.meshmanager;
import ogre.resources.resource;
import ogre.resources.resourcegroupmanager;
import ogre.scene.camera;
import ogre.scene.light;
import ogre.scene.movableobject;
import ogre.scene.node;
import ogre.scene.renderable;
import ogre.scene.shadowcaster;
import ogre.scene.skeletoninstance;
import ogre.math.maths;
import ogre.general.log;


/** \addtogroup Core
 *  @{
 */
/** \addtogroup Scene
 *  @{
 */

/** Defines an instance of a discrete, movable object based on a Mesh.
 @remarks
 Ogre generally divides renderable objects into 2 groups, discrete
 (separate) and relatively small objects which move around the world,
 and large, sprawling geometry which makes up generally immovable
 scenery, aka 'level geometry'.
 @par
 The Mesh and SubMesh classes deal with the definition of the geometry
 used by discrete movable objects. Entities are actual instances of
 objects based on this geometry in the world. Therefore there is
 usually a single set Mesh for a car, but there may be multiple
 entities based on it in the world. Entities are able to override
 aspects of the Mesh it is defined by, such as changing material
 properties per instance (so you can have many cars using the same
 geometry but different textures for example). Because a Mesh is split
 into SubMeshes for this purpose, the Entity class is a grouping class
 (much like the Mesh class) and much of the detail regarding
 individual changes is kept in the SubEntity class. There is a 1:1
 relationship between SubEntity instances and the SubMesh instances
 associated with the Mesh the Entity is based on.
 @par
 Entity and SubEntity classes are never created directly. Use the
 createEntity method of the SceneManager (passing a model name) to
 create one.
 @par
 Entities are included in the scene by associating them with a
 SceneNode, using the attachEntity method. See the SceneNode class
 for full information.
 @note
 No functions were declared to improve performance.
 */
class Entity: MovableObject, Resource.Listener
{
    // Allow EntityFactory full access
    //friend class EntityFactory;
    //friend class SubEntity;
public:
    
    //typedef set<ref Entity>.type EntitySet;
    //typedef map<ushort, bool>.type SchemeHardwareAnimMap;
    
    alias Entity[] EntitySet;
    alias bool[ushort] SchemeHardwareAnimMap;
    
protected:

    //Ignored callbacks
    void backgroundPreparingComplete(ref Resource r){}
    void loadingComplete(ref Resource r){}
    void preparingComplete(ref Resource r){}
    void unloadingComplete(ref Resource r){}

    /** Private constructor (instances cannot be created directly).
     */
    this()
    {
        mAnimationState = null;
        //mSkelAnimVertexData = null;
        //mSoftwareVertexAnimVertexData = null;
        //mHardwareVertexAnimVertexData = null;
        mPreparedForShadowVolumes = false;
        mBoneWorldMatrices = null;
        mBoneMatrices = null;
        mNumBoneMatrices = 0;
        mFrameAnimationLastUpdated = ulong.max;
        mFrameBonesLastUpdated = null;
        mSharedSkeletonEntities = null;
        mDisplaySkeleton = false;
        mCurrentHWAnimationState = false;
        mHardwarePoseCount = 0;
        mVertexProgramInUse = false;
        mSoftwareAnimationRequests = 0;
        mSoftwareAnimationNormalsRequests = 0;
        mSkipAnimStateUpdates = false;
        mAlwaysUpdateMainSkeleton = false;
        mMeshLodIndex = 0;
        mMeshLodFactorTransformed = 1.0f;
        mMinMeshLodIndex = 99;
        mMaxMeshLodIndex = 0;
        // Backwards remember low value = high detail
        mMaterialLodFactor = 1.0f;
        mMaterialLodFactorTransformed = 1.0f;
        mMinMaterialLodIndex = 99;
        mMaxMaterialLodIndex = 0;
        // Backwards remember low value = high detail
        //mSkeletonInstance = null;
        mInitialised = false;
        mLastParentXform = Matrix4.ZERO;
        mMeshStateCount = 0;
        //mFullBoundingBox ();
        
    }
    /** Private constructor - specify name (the usual constructor used).
     */
    this(string name, ref SharedPtr!Mesh mesh)
    {
        super(name);
        mMesh = mesh;
        mAnimationState = null;
        //mSkelAnimVertexData = 0;
        //mSoftwareVertexAnimVertexData = 0;
        //mHardwareVertexAnimVertexData = 0;
        mPreparedForShadowVolumes = false;
        mBoneWorldMatrices = null;
        mBoneMatrices = null;
        mNumBoneMatrices = 0;
        mFrameAnimationLastUpdated = ulong.max;
        mFrameBonesLastUpdated = null;
        mSharedSkeletonEntities = null;
        mDisplaySkeleton = false;
        mCurrentHWAnimationState = false;
        mHardwarePoseCount = 0;
        mVertexProgramInUse = false;
        mSoftwareAnimationRequests = 0;
        mSoftwareAnimationNormalsRequests = 0;
        mSkipAnimStateUpdates = false;
        mAlwaysUpdateMainSkeleton = false;
        mMeshLodIndex = 0;
        mMeshLodFactorTransformed = 1.0f;
        mMinMeshLodIndex = 99;
        mMaxMeshLodIndex = 0;
        // Backwards remember low value = high detail
        mMaterialLodFactor = 1.0f;
        mMaterialLodFactorTransformed = 1.0f;
        mMinMaterialLodIndex = 99;
        mMaxMaterialLodIndex = 0;
        // Backwards remember low value = high detail
        //mSkeletonInstance = 0;
        mInitialised = false;
        mLastParentXform = Matrix4.ZERO;
        mMeshStateCount = 0;
        //mFullBoundingBox ();
        _initialise();
    }
    
    /** The Mesh that this Entity is based on.
     */
    SharedPtr!Mesh mMesh;
    
    /** List of SubEntities (point to SubMeshes).
     */
    //typedef vector<ref SubEntity>.type SubEntityList;
    alias SubEntity[] SubEntityList;
    SubEntityList mSubEntityList;
    
    
    /// State of animation for animable meshes
    AnimationStateSet mAnimationState;
    
    
    /// Temp buffer details for software skeletal anim of shared geometry
    TempBlendedBufferInfo mTempSkelAnimInfo;
    /// Vertex data details for software skeletal anim of shared geometry
    VertexData mSkelAnimVertexData;
    /// Temp buffer details for software vertex anim of shared geometry
    TempBlendedBufferInfo mTempVertexAnimInfo;
    /// Vertex data details for software vertex anim of shared geometry
    VertexData mSoftwareVertexAnimVertexData;
    /// Vertex data details for hardware vertex anim of shared geometry
    /// - separate since we need to s/w anim for shadows whilst still altering
    ///   the vertex data for hardware morphing (pos2 binding)
    VertexData mHardwareVertexAnimVertexData;
    /// Have we applied any vertex animation to shared geometry?
    bool mVertexAnimationAppliedThisFrame;
    /// Have the temp buffers already had their geometry prepared for use in rendering shadow volumes?
    bool mPreparedForShadowVolumes;
    
    /** Internal method - given vertex data which could be from the Mesh or
     any submesh, finds the temporary blend copy.
     */
    VertexData findBlendedVertexData(VertexData orig)
    {
        bool skel = hasSkeleton();
        
        if (orig == mMesh.getAs().sharedVertexData)
        {
            return skel? mSkelAnimVertexData : mSoftwareVertexAnimVertexData;
        }
        
        foreach (se; mSubEntityList)
        {
            if (orig == se.getSubMesh().vertexData)
            {
                return skel? se._getSkelAnimVertexData() : se._getSoftwareVertexAnimVertexData();
            }
        }
        // None found
        throw new ItemNotFoundError(
            "Cannot find blended version of the vertex data specified.",
            "Entity.findBlendedVertexData");
    }
    /** Internal method - given vertex data which could be from the Mesh or
     any SubMesh, finds the corresponding SubEntity.
     */
    SubEntity findSubEntityForVertexData(VertexData orig)
    {
        if (orig == mMesh.getAs().sharedVertexData)
        {
            return null;
        }

        foreach (se; mSubEntityList)
        {
            if (orig == se.getSubMesh().vertexData)
            {
                return se;
            }
        }
        
        // None found
        return null;
    }
    
    /** Internal method for extracting metadata out of source vertex data
     for fast assignment of temporary buffers later.
     */
    void extractTempBufferInfo(VertexData sourceData, TempBlendedBufferInfo info)
    {
        info.extractFrom(sourceData);
    }
    /** Internal method to clone vertex data definitions but to remove blend buffers. */
    VertexData cloneVertexDataRemoveBlendInfo(VertexData source)
    {
        // Clone without copying data
        VertexData ret = source.clone(false);
        bool removeIndices = Root.getSingleton().isBlendIndicesGpuRedundant();
        bool removeWeights = Root.getSingleton().isBlendWeightsGpuRedundant();
        
        ushort safeSource = 0xFFFF;
        VertexElement blendIndexElem =
            source.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_BLEND_INDICES);
        if (blendIndexElem)
        {
            //save the source in order to prevent the next stage from unbinding it.
            safeSource = blendIndexElem.getSource();
            if (removeIndices)
            {
                // Remove buffer reference
                ret.vertexBufferBinding.unsetBinding(blendIndexElem.getSource());
            }
        }
        if (removeWeights)
        {
            // Remove blend weights
            VertexElement blendWeightElem =
                source.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_BLEND_WEIGHTS);
            if (blendWeightElem &&
                blendWeightElem.getSource() != safeSource)
            {
                // Remove buffer reference
                ret.vertexBufferBinding.unsetBinding(blendWeightElem.getSource());
            }
        }
        
        // remove elements from declaration
        if (removeIndices)
            ret.vertexDeclaration.removeElement(VertexElementSemantic.VES_BLEND_INDICES);
        if (removeWeights)
            ret.vertexDeclaration.removeElement(VertexElementSemantic.VES_BLEND_WEIGHTS);
        
        // Close gaps in bindings for effective and safely
        if (removeWeights || removeIndices)
            ret.closeGapsInBindings();
        
        return ret;
    }
    
    /** Internal method for preparing this Entity for use in animation. */
    void prepareTempBlendBuffers()
    {
        if (mSkelAnimVertexData)
        {
            destroy(mSkelAnimVertexData);
            mSkelAnimVertexData = null;
        }
        if (mSoftwareVertexAnimVertexData)
        {
            destroy(mSoftwareVertexAnimVertexData);
            mSoftwareVertexAnimVertexData = null;
        }
        if (mHardwareVertexAnimVertexData)
        {
            destroy(mHardwareVertexAnimVertexData);
            mHardwareVertexAnimVertexData = null;
        }
        
        if (hasVertexAnimation())
        {
            // Shared data
            if (mMesh.getAs().sharedVertexData
                && mMesh.getAs().getSharedVertexDataAnimationType() != VertexAnimationType.VAT_NONE)
            {
                // Create temporary vertex blend info
                // Prepare temp vertex data if needed
                // Clone without copying data, don't remove any blending info
                // (since if we skeletally animate too, we need it)
                mSoftwareVertexAnimVertexData = mMesh.getAs().sharedVertexData.clone(false);
                extractTempBufferInfo(mSoftwareVertexAnimVertexData, mTempVertexAnimInfo);
                
                // Also clone for hardware usage, don't remove blend info since we'll
                // need it if we also hardware skeletally animate
                mHardwareVertexAnimVertexData = mMesh.getAs().sharedVertexData.clone(false);
            }
        }
        
        if (hasSkeleton())
        {
            // Shared data
            if (mMesh.getAs().sharedVertexData)
            {
                // Create temporary vertex blend info
                // Prepare temp vertex data if needed
                // Clone without copying data, remove blending info
                // (since blend is performed in software)
                mSkelAnimVertexData =
                    cloneVertexDataRemoveBlendInfo(mMesh.getAs().sharedVertexData);
                extractTempBufferInfo(mSkelAnimVertexData, mTempSkelAnimInfo);
            }
            
        }
        
        // Do SubEntities
        foreach (s; mSubEntityList)
        {
            s.prepareTempBlendBuffers();
        }
        
        // It's prepared for shadow volumes only if mesh has been prepared for shadow volumes.
        mPreparedForShadowVolumes = mMesh.getAs().isPreparedForShadowVolumes();
    }
    
    /** Mark all vertex data as so far unanimated.
     */
    void markBuffersUnusedForAnimation()
    {
        mVertexAnimationAppliedThisFrame = false;
        foreach (i; mSubEntityList)
        {
            i._markBuffersUnusedForAnimation();
        }
    }
    /** Internal method to restore original vertex data where we didn't
     perform any vertex animation this frame.
     */
    void restoreBuffersForUnusedAnimation(bool hardwareAnimation)
    {
        // Rebind original positions if:
        //  We didn't apply any animation and
        //    We're morph animated (hardware binds keyframe, software is missing)
        //    or we're pose animated and software (hardware is fine, still bound)
        if (mMesh.getAs().sharedVertexData &&
            !mVertexAnimationAppliedThisFrame &&
            (!hardwareAnimation || mMesh.getAs().getSharedVertexDataAnimationType() == VertexAnimationType.VAT_MORPH))
        {
            // Note, VES_POSITION is specified here but if normals are included in animation
            // then these will be re-bound too (buffers must be shared)
            VertexElement srcPosElem =
                mMesh.getAs().sharedVertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
            SharedPtr!HardwareVertexBuffer srcBuf =
                mMesh.getAs().sharedVertexData.vertexBufferBinding.getBuffer(
                    srcPosElem.getSource());
            
            // Bind to software
            VertexElement destPosElem =
                mSoftwareVertexAnimVertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
            mSoftwareVertexAnimVertexData.vertexBufferBinding.setBinding(
                destPosElem.getSource(), srcBuf);
            
        }
        
        // rebind any missing hardware pose buffers
        // Caused by not having any animations enabled, or keyframes which reference
        // no poses
        if (mMesh.getAs().sharedVertexData && hardwareAnimation 
            && mMesh.getAs().getSharedVertexDataAnimationType() == VertexAnimationType.VAT_POSE)
        {
            bindMissingHardwarePoseBuffers(mMesh.getAs().sharedVertexData, mHardwareVertexAnimVertexData);
        }
        
        
        foreach (i; mSubEntityList)
        {
            i._restoreBuffersForUnusedAnimation(hardwareAnimation);
        }
        
    }
    
    /** Ensure that any unbound  pose animation buffers are bound to a safe
     default.
     @param srcData
     Original vertex data containing original positions.
     @param destData
     Hardware animation vertex data to be checked.
     */
    void bindMissingHardwarePoseBuffers(VertexData srcData, 
                                        ref VertexData destData)
    {
        // For hardware pose animation, also make sure we've bound buffers to all the elements
        // required - if there are missing bindings for elements in use,
        // some rendersystems can complain because elements ref er
        // to an unbound source.
        // Get the original position source, we'll use this to fill gaps
        VertexElement srcPosElem = srcData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
        SharedPtr!HardwareVertexBuffer srcBuf =
            srcData.vertexBufferBinding.getBuffer(srcPosElem.getSource());
        
        foreach (animData; destData.hwAnimationDataList)
        {
            if (!destData.vertexBufferBinding.isBufferBound(
                animData.targetBufferIndex))
            {
                // Bind to a safe default
                destData.vertexBufferBinding.setBinding(
                    animData.targetBufferIndex, srcBuf);
            }
        }
        
    }
    
    /** When performing software pose animation, initialise software copy
     of vertex data.
     */
    void initialisePoseVertexData(VertexData srcData, ref VertexData destData, 
                                  bool animateNormals)
    {
        
        // First time through for a piece of pose animated vertex data
        // We need to copy the original position values to the temp accumulator
        VertexElement origelem = 
            srcData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
        VertexElement destelem = 
            destData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
        SharedPtr!HardwareVertexBuffer origBuffer = 
            srcData.vertexBufferBinding.getBuffer(origelem.getSource());
        SharedPtr!HardwareVertexBuffer destBuffer = 
            destData.vertexBufferBinding.getBuffer(destelem.getSource());
        destBuffer.get().copyData(origBuffer.get(), 0, 0, destBuffer.get().getSizeInBytes(), true);
        
        // If normals are included in animation, we want to reset the normals to zero
        if (animateNormals)
        {
            VertexElement normElem =
                destData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_NORMAL);
            
            if (normElem)
            {
                SharedPtr!HardwareVertexBuffer buf = 
                    destData.vertexBufferBinding.getBuffer(normElem.getSource());
                ubyte* pBase = cast(ubyte*)(buf.get().lock(HardwareBuffer.LockOptions.HBL_NORMAL));
                pBase += destData.vertexStart * buf.get().getVertexSize();
                
                for (size_t v = 0; v < destData.vertexCount; ++v)
                {
                    float* pNorm;
                    normElem.baseVertexPointerToElement(pBase, &pNorm);
                    *pNorm++ = 0.0f;
                    *pNorm++ = 0.0f;
                    *pNorm++ = 0.0f;
                    
                    pBase += buf.get().getVertexSize();
                }
                buf.get().unlock();
            }
        }
    }
    
    /** When animating normals for pose animation, finalise normals by filling in
     with the reference mesh normal where applied normal weights < 1.
     */
    void finalisePoseNormals(VertexData srcData, ref VertexData destData)
    {
        VertexElement destNormElem =
            destData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_NORMAL);
        VertexElement srcNormElem =
            srcData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_NORMAL);
        
        if (destNormElem && srcNormElem)
        {
            SharedPtr!HardwareVertexBuffer srcbuf = 
                srcData.vertexBufferBinding.getBuffer(srcNormElem.getSource());
            SharedPtr!HardwareVertexBuffer dstbuf = 
                destData.vertexBufferBinding.getBuffer(destNormElem.getSource());
            ubyte* pSrcBase = cast(ubyte*)(srcbuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
            ubyte* pDstBase = cast(ubyte*)(dstbuf.get().lock(HardwareBuffer.LockOptions.HBL_NORMAL));
            pSrcBase += srcData.vertexStart * srcbuf.get().getVertexSize();
            pDstBase += destData.vertexStart * dstbuf.get().getVertexSize();
            
            // The goal here is to detect the length of the vertices, and to apply
            // the base mesh vertex normal at one minus that length; this deals with 
            // any individual vertices which were either not affected by any pose, or
            // were not affected to a complete extent
            // We also normalise every normal to deal with over-weighting
            for (size_t v = 0; v < destData.vertexCount; ++v)
            {
                float* pDstNorm;
                destNormElem.baseVertexPointerToElement(pDstBase, &pDstNorm);
                auto norm = Vector3(pDstNorm[0], pDstNorm[1], pDstNorm[2]);
                Real len = norm.length();
                if (len + 1e-4f < 1.0f)
                {
                    // Poses did not completely fill in this normal
                    // Apply base mesh
                    float baseWeight = 1.0f - cast(float)len;
                    float* pSrcNorm;
                    srcNormElem.baseVertexPointerToElement(pSrcBase, &pSrcNorm);
                    norm.x += *pSrcNorm++ * baseWeight;
                    norm.y += *pSrcNorm++ * baseWeight;
                    norm.z += *pSrcNorm++ * baseWeight;
                }
                norm.normalise();
                
                *pDstNorm++ = cast(float)norm.x;
                *pDstNorm++ = cast(float)norm.y;
                *pDstNorm++ = cast(float)norm.z;
                
                pDstBase += dstbuf.get().getVertexSize();
                pSrcBase += dstbuf.get().getVertexSize();
            }
            srcbuf.get().unlock();
            dstbuf.get().unlock();
        }
    }
    
    /// Cached bone matrices, including any world transform.
    Matrix4[] mBoneWorldMatrices;
    /// Cached bone matrices in skeleton local space, might shares with other entity instances.
    Matrix4[] mBoneMatrices;
    ushort mNumBoneMatrices;
    /// Records the last frame in which animation was updated.
    ulong mFrameAnimationLastUpdated;
    
    /// Perform all the updates required for an animated entity.
    void updateAnimation()
    {
        // Do nothing if not initialised yet
        if (!mInitialised)
            return;
        
        Root root = Root.getSingleton();
        bool hwAnimation = isHardwareAnimationEnabled();
        bool isNeedUpdateHardwareAnim = hwAnimation && !mCurrentHWAnimationState;
        bool forcedSwAnimation = getSoftwareAnimationRequests()>0;
        bool forcedNormals = getSoftwareAnimationNormalsRequests()>0;
        bool stencilShadows = false;
        if (getCastShadows() && hasEdgeList() && root._getCurrentSceneManager())
            stencilShadows =  root._getCurrentSceneManager().isShadowTechniqueStencilBased();
        bool softwareAnimation = !hwAnimation || stencilShadows || forcedSwAnimation;
        // Blend normals in s/w only if we're not using h/w animation,
        // since shadows only require positions
        bool blendNormals = !hwAnimation || forcedNormals;
        // Animation dirty if animation state modified or manual bones modified
        bool animationDirty =
            (mFrameAnimationLastUpdated != mAnimationState.getDirtyFrameNumber()) ||
                (hasSkeleton() && getSkeleton().getManualBonesDirty());
        
        //update the current hardware animation state
        mCurrentHWAnimationState = hwAnimation;
        
        // We only do these tasks if animation is dirty
        // Or, if we're using a skeleton and manual bones have been moved
        // Or, if we're using software animation and temp buffers are unbound
        if (animationDirty ||
            (softwareAnimation && hasVertexAnimation() && !tempVertexAnimBuffersBound()) ||
            (softwareAnimation && hasSkeleton() && !tempSkelAnimBuffersBound(blendNormals)))
        {
            if (hasVertexAnimation())
            {
                if (softwareAnimation)
                {
                    // grab & bind temporary buffer for positions (& normals if they are included)
                    if (mSoftwareVertexAnimVertexData
                        && mMesh.getAs().getSharedVertexDataAnimationType() != VertexAnimationType.VAT_NONE)
                    {
                        bool useNormals = mMesh.getAs().getSharedVertexDataAnimationIncludesNormals();
                        mTempVertexAnimInfo.checkoutTempCopies(true, useNormals);
                        // NB we suppress hardware upload while doing blend if we're
                        // hardware animation, because the only reason for doing this
                        // is for shadow, which need only be uploaded then
                        mTempVertexAnimInfo.bindTempCopies(mSoftwareVertexAnimVertexData,
                                                           hwAnimation);
                    }

                    foreach (se; mSubEntityList)
                    {
                        // Blend dedicated geometry
                        if (se.isVisible() && se.mSoftwareVertexAnimVertexData
                            && se.getSubMesh().getVertexAnimationType() != VertexAnimationType.VAT_NONE)
                        {
                            bool useNormals = se.getSubMesh().getVertexAnimationIncludesNormals();
                            se.mTempVertexAnimInfo.checkoutTempCopies(true, useNormals);
                            se.mTempVertexAnimInfo.bindTempCopies(se.mSoftwareVertexAnimVertexData,
                                                                  hwAnimation);
                        }
                        
                    }
                }
                applyVertexAnimation(hwAnimation, stencilShadows);
            }
            
            if (hasSkeleton())
            {
                cacheBoneMatrices();
                
                // Software blend?
                if (softwareAnimation)
                {
                    Matrix4[256] blendMatrices;
                    
                    // Ok, we need to do a software blend
                    // Firstly, check out working vertex buffers
                    if (mSkelAnimVertexData)
                    {
                        // Blend shared geometry
                        // NB we suppress hardware upload while doing blend if we're
                        // hardware animation, because the only reason for doing this
                        // is for shadow, which need only be uploaded then
                        mTempSkelAnimInfo.checkoutTempCopies(true, blendNormals);
                        mTempSkelAnimInfo.bindTempCopies(mSkelAnimVertexData,
                                                         hwAnimation);
                        // Prepare blend matrices, TODO: Move out of here
                        Mesh.prepareMatricesForVertexBlend(blendMatrices,
                                                           mBoneMatrices, mMesh.getAs().sharedBlendIndexToBoneIndexMap);
                        // Blend, taking source from either mesh data or morph data
                        Mesh.softwareVertexBlend(
                            (mMesh.getAs().getSharedVertexDataAnimationType() != VertexAnimationType.VAT_NONE) ?
                            mSoftwareVertexAnimVertexData : mMesh.getAs().sharedVertexData,
                            mSkelAnimVertexData,
                            blendMatrices, mMesh.getAs().sharedBlendIndexToBoneIndexMap.length,
                            blendNormals);
                    }

                    foreach (se; mSubEntityList)
                    {
                        // Blend dedicated geometry
                        //SubEntity se = *i;
                        if (se.isVisible() && se.mSkelAnimVertexData)
                        {
                            se.mTempSkelAnimInfo.checkoutTempCopies(true, blendNormals);
                            se.mTempSkelAnimInfo.bindTempCopies(se.mSkelAnimVertexData,
                                                                hwAnimation);
                            // Prepare blend matrices, TODO: Move out of here
                            Mesh.prepareMatricesForVertexBlend(blendMatrices,
                                                               mBoneMatrices, se.mSubMesh.blendIndexToBoneIndexMap);
                            // Blend, taking source from either mesh data or morph data
                            Mesh.softwareVertexBlend(
                                (se.getSubMesh().getVertexAnimationType() != VertexAnimationType.VAT_NONE)?
                                se.mSoftwareVertexAnimVertexData : se.mSubMesh.vertexData,
                                se.mSkelAnimVertexData,
                                blendMatrices, se.mSubMesh.blendIndexToBoneIndexMap.length,
                                blendNormals);
                        }
                        
                    }
                    
                }
            }
            
            // Trigger update of bounding box if necessary
            if (!mChildObjectList.emptyAA())
                mParentNode.needUpdate();
            
            mFrameAnimationLastUpdated = mAnimationState.getDirtyFrameNumber();
        }
        
        // Need to update the child object's transforms when animation dirty
        // or parent node transform has altered.
        if (hasSkeleton() && 
            (isNeedUpdateHardwareAnim || 
         animationDirty || mLastParentXform != _getParentNodeFullTransform()))
        {
            // Cache last parent transform for next frame use too.
            mLastParentXform = _getParentNodeFullTransform();
            
            //--- Update the child object's transforms
            foreach(k, child; mChildObjectList)
            {
                child.getParentNode()._update(true, true);
            }
            
            // Also calculate bone world matrices, since are used as replacement world matrices,
            // but only if it's used (when using hardware animation and skeleton animated).
            if (hwAnimation && _isSkeletonAnimated())
            {
                // Allocate bone world matrices on demand, for better memory footprint
                // when using software animation.
                if (!mBoneWorldMatrices)
                {
                    mBoneWorldMatrices = new Matrix4[mNumBoneMatrices];
                }
                
                OptimisedUtil.getImplementation().concatenateAffineMatrices(
                    mLastParentXform,
                    mBoneMatrices,
                    mBoneWorldMatrices,
                    mNumBoneMatrices);
            }
        }
    }
    
    /// Records the last frame in which the bones was updated.
    /// It's a pointer because it can be shared between different entities with
    /// a shared skeleton.
    ulong *mFrameBonesLastUpdated;
    
    /** A set of all the entities which shares a single SkeletonInstance.
     This is only created if the entity is in fact sharing it's SkeletonInstance with
     other Entities.
     */
    EntitySet mSharedSkeletonEntities;
    
    /** Private method to cache bone matrices from skeleton.
     @return
     True if the bone matrices cache has been updated. False if note.
     */
    bool cacheBoneMatrices()
    {
        Root root = Root.getSingleton();
        ulong currentFrameNumber = root.getNextFrameNumber();
        if ((*mFrameBonesLastUpdated != currentFrameNumber) ||
            (hasSkeleton() && getSkeleton().getManualBonesDirty()))
        {
            if ((!mSkipAnimStateUpdates) && (*mFrameBonesLastUpdated != currentFrameNumber))
                mSkeletonInstance.setAnimationState(mAnimationState);
            mSkeletonInstance._getBoneMatrices(mBoneMatrices);
            *mFrameBonesLastUpdated  = currentFrameNumber;
            
            return true;
        }
        return false;
    }
    
    /// Flag determines whether or not to display skeleton.
    bool mDisplaySkeleton;
    /** Flag indicating whether hardware animation is supported by this entities materials
     data is saved per scehme number.
     */
    SchemeHardwareAnimMap mSchemeHardwareAnim;
    
    /// Current state of the hardware animation as represented by the entities parameters.
    bool mCurrentHWAnimationState;
    
    /// Number of hardware poses supported by materials.
    ushort mHardwarePoseCount;
    /// Flag indicating whether we have a vertex program in use on any of our subentities.
    bool mVertexProgramInUse;
    /// Counter indicating number of requests for software animation.
    int mSoftwareAnimationRequests;
    /// Counter indicating number of requests for software blended normals.
    int mSoftwareAnimationNormalsRequests;
    /// Flag indicating whether to skip automatic updating of the Skeleton's AnimationState.
    bool mSkipAnimStateUpdates;
    /// Flag indicating whether to update the main entity skeleton even when an LOD is displayed.
    bool mAlwaysUpdateMainSkeleton;
    
    
    /// The LOD number of the mesh to use, calculated by _notifyCurrentCamera.
    ushort mMeshLodIndex;
    
    /// LOD bias factor, transformed for optimisation when calculating adjusted lod value.
    Real mMeshLodFactorTransformed;
    /// Index of minimum detail LOD (NB higher index is lower detail).
    ushort mMinMeshLodIndex;
    /// Index of maximum detail LOD (NB lower index is higher detail).
    ushort mMaxMeshLodIndex;
    
    /// LOD bias factor, not transformed.
    Real mMaterialLodFactor;
    /// LOD bias factor, transformed for optimisation when calculating adjusted lod value.
    Real mMaterialLodFactorTransformed;
    /// Index of minimum detail LOD (NB higher index is lower detail).
    ushort mMinMaterialLodIndex;
    /// Index of maximum detail LOD (NB lower index is higher detail).
    ushort mMaxMaterialLodIndex;
    
    /** List of LOD Entity instances (for manual LODs).
     We don't know when the mesh is using manual LODs whether one LOD to the next will have the
     same number of SubMeshes, Therefore we have to allow a separate Entity list
     with each alternate one.
     */
    //typedef vector<ref Entity>.type LODEntityList;
    alias Entity[]   LODEntityList;
    LODEntityList mLodEntityList;
    
    /** This Entity's personal copy of the skeleton, if skeletally animated.
     */
    SkeletonInstance mSkeletonInstance;
    
    /// Has this entity been initialised yet?
    bool mInitialised;
    
    /// Last parent transform.
    Matrix4 mLastParentXform;
    
    /// Mesh state count, used to detect differences.
    size_t mMeshStateCount;
    
    /** Builds a list of SubEntities based on the SubMeshes contained in the Mesh. */
    void buildSubEntityList(ref SharedPtr!Mesh mesh, ref SubEntityList sublist)
    {
        // Create SubEntities
        ushort i, numSubMeshes;
        SubMesh subMesh;
        SubEntity subEnt;
        
        numSubMeshes = mesh.getAs().getNumSubMeshes();
        for (i = 0; i < numSubMeshes; ++i)
        {
            subMesh = mesh.getAs().getSubMesh(i);
            subEnt = new SubEntity(this, subMesh);
            if (subMesh.isMatInitialised())
                subEnt.setMaterialName(subMesh.getMaterialName(), mesh.getAs().getGroup());
            sublist.insert(subEnt);
        }
    }
    
    /// Internal implementation of attaching a 'child' object to this entity and assign the parent node to the child entity.
    void attachObjectImpl(ref MovableObject pMovable, ref TagPoint pAttachingPoint)
    {
        assert((pMovable.getName() in mChildObjectList) is null);
        mChildObjectList[pMovable.getName()] = pMovable;
        pMovable._notifyAttached(pAttachingPoint, true);
    }
    
    /// Internal implementation of detaching a 'child' object of this entity and clear the parent node of the child entity.
    void detachObjectImpl(ref MovableObject obj)
    {
        foreach (k,v; mChildObjectList)
        {
            if (v == obj)
            {
                detachObjectImpl(obj);
                mChildObjectList.remove(k);
                
                // Trigger update of bounding box if necessary
                if (mParentNode)
                    mParentNode.needUpdate();
                break;
            }
        }
    }
    
    /// Internal implementation of detaching all 'child' objects of this entity.
    void detachAllObjectsImpl()
    {
        foreach (k,v; mChildObjectList)
        {
            detachObjectImpl(v);
        }
        mChildObjectList.clear();
    }
    
    /// Ensures reevaluation of the vertex processing usage.
    void reevaluateVertexProcessing()
    {
        //clear the cache so that the values will be reevaluated
        mSchemeHardwareAnim.clear();
    }
    
    /** Calculates the kind of vertex processing in use.
     @remarks
     This function's return value is calculated according to the current 
     active scheme. This is due to the fact that RTSS schemes may be different
     in their handling of hardware animation.
     */
    bool calcVertexProcessing()
    {
        // init
        bool hasHardwareAnimation = false;
        bool firstPass = true;
        
        foreach (sub; mSubEntityList)
        {
            SharedPtr!Material m = sub.getMaterial();
            // Make sure it's loaded
            m.get().load();
            Technique t = m.getAs().getBestTechnique(0, sub);
            if (!t)
            {
                // No supported techniques
                continue;
            }
            if (t.getNumPasses() == 0)
            {
                // No passes, invalid
                continue;
            }
            Pass p = t.getPass(0);
            if (p.hasVertexProgram())
            {
                if (mVertexProgramInUse == false)
                {
                    // If one material uses a vertex program, set this flag
                    // Causes some special processing like forcing a separate light cap
                    mVertexProgramInUse = true;
                    
                    // If shadow renderables already created create their light caps
                    foreach (si; mShadowRenderables)
                    {
                        (cast(EntityShadowRenderable)(si))._createSeparateLightCap();
                    }
                }
                
                if (hasSkeleton())
                {
                    // All materials must support skinning for us to consider using
                    // hardware animation - if one fails we use software
                    if (firstPass)
                    {
                        hasHardwareAnimation = p.getVertexProgram().getAs().isSkeletalAnimationIncluded();
                        firstPass = false;
                    }
                    else
                    {
                        hasHardwareAnimation = hasHardwareAnimation &&
                            p.getVertexProgram().getAs().isSkeletalAnimationIncluded();
                    }
                }
                
                VertexAnimationType animType = VertexAnimationType.VAT_NONE;
                if (sub.getSubMesh().useSharedVertices)
                {
                    animType = mMesh.getAs().getSharedVertexDataAnimationType();
                }
                else
                {
                    animType = sub.getSubMesh().getVertexAnimationType();
                }
                if (animType == VertexAnimationType.VAT_MORPH)
                {
                    // All materials must support morph animation for us to consider using
                    // hardware animation - if one fails we use software
                    if (firstPass)
                    {
                        hasHardwareAnimation = p.getVertexProgram().getAs().isMorphAnimationIncluded();
                        firstPass = false;
                    }
                    else
                    {
                        hasHardwareAnimation = hasHardwareAnimation &&
                            p.getVertexProgram().getAs().isMorphAnimationIncluded();
                    }
                }
                else if (animType == VertexAnimationType.VAT_POSE)
                {
                    // All materials must support pose animation for us to consider using
                    // hardware animation - if one fails we use software
                    if (firstPass)
                    {
                        hasHardwareAnimation = p.getVertexProgram().getAs().isPoseAnimationIncluded();
                        if (sub.getSubMesh().useSharedVertices)
                            mHardwarePoseCount = p.getVertexProgram().getAs().getNumberOfPosesIncluded();
                        else
                            sub.mHardwarePoseCount = p.getVertexProgram().getAs().getNumberOfPosesIncluded();
                        firstPass = false;
                    }
                    else
                    {
                        hasHardwareAnimation = hasHardwareAnimation &&
                            p.getVertexProgram().getAs().isPoseAnimationIncluded();
                        if (sub.getSubMesh().useSharedVertices)
                            mHardwarePoseCount = std.algorithm.max(mHardwarePoseCount,
                                                                   p.getVertexProgram().getAs().getNumberOfPosesIncluded());
                        else
                            sub.mHardwarePoseCount = std.algorithm.max(sub.mHardwarePoseCount,
                                                                       p.getVertexProgram().getAs().getNumberOfPosesIncluded());
                    }
                }
                
            }
        }
        
        // Should be force update of animation if they exists, due reevaluate
        // vertex processing might switchs between hardware/software animation,
        // and then we'll end with null or incorrect mBoneWorldMatrices, or
        // incorrect blended software animation buffers.
        if (mAnimationState)
        {
            mFrameAnimationLastUpdated = mAnimationState.getDirtyFrameNumber() - 1;
        }
        
        return hasHardwareAnimation;
    }
    
    /// Apply vertex animation.
    void applyVertexAnimation(bool hardwareAnimation, bool stencilShadows)
    {
        SharedPtr!Mesh msh = getMesh();
        bool swAnim = !hardwareAnimation || stencilShadows || (mSoftwareAnimationRequests>0);
        
        // make sure we have enough hardware animation elements to play with
        if (hardwareAnimation)
        {
            if (mHardwareVertexAnimVertexData
                && msh.getAs().getSharedVertexDataAnimationType() != VertexAnimationType.VAT_NONE)
            {
                ushort supportedCount =
                    initHardwareAnimationElements(mHardwareVertexAnimVertexData,
                                                  (msh.getAs().getSharedVertexDataAnimationType() == VertexAnimationType.VAT_POSE)
                                                  ? mHardwarePoseCount : 1, 
                                                  msh.getAs().getSharedVertexDataAnimationIncludesNormals());
                
                if (msh.getAs().getSharedVertexDataAnimationType() == VertexAnimationType.VAT_POSE && 
                    supportedCount < mHardwarePoseCount)
                {
                    LogManager.getSingleton().stream() <<
                        "Vertex program assigned to Entity '" << mName << 
                            "' claimed to support " << mHardwarePoseCount << 
                            " morph/pose vertex sets, but in fact only " << supportedCount <<
                            " were able to be supported in the shared mesh data.";
                    mHardwarePoseCount = supportedCount;
                }
                
            }
            foreach (sub; mSubEntityList)
            {
                if (sub.getSubMesh().getVertexAnimationType() != VertexAnimationType.VAT_NONE &&
                    !sub.getSubMesh().useSharedVertices)
                {
                    ushort supportedCount = initHardwareAnimationElements(
                        sub._getHardwareVertexAnimVertexData(),
                        (sub.getSubMesh().getVertexAnimationType() == VertexAnimationType.VAT_POSE)
                        ? sub.mHardwarePoseCount : 1,
                        sub.getSubMesh().getVertexAnimationIncludesNormals());
                    
                    if (sub.getSubMesh().getVertexAnimationType() == VertexAnimationType.VAT_POSE && 
                        supportedCount < sub.mHardwarePoseCount)
                    {
                        LogManager.getSingleton().stream() <<
                            "Vertex program assigned to SubEntity of '" << mName << 
                                "' claimed to support " << sub.mHardwarePoseCount << 
                                " morph/pose vertex sets, but in fact only " << supportedCount <<
                                " were able to be supported in the mesh data.";
                        sub.mHardwarePoseCount = supportedCount;
                    }
                    
                }
            }
            
        }
        else
        {
            // May be blending multiple poses in software
            // Suppress hardware upload of buffers
            // Note, we query position buffer here but it may also include normals
            if (mSoftwareVertexAnimVertexData &&
                mMesh.getAs().getSharedVertexDataAnimationType() == VertexAnimationType.VAT_POSE)
            {
                VertexElement elem = mSoftwareVertexAnimVertexData
                    .vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
                SharedPtr!HardwareVertexBuffer buf = mSoftwareVertexAnimVertexData
                    .vertexBufferBinding.getBuffer(elem.getSource());
                buf.get().suppressHardwareUpdate(true);
                
                initialisePoseVertexData(mMesh.getAs().sharedVertexData, mSoftwareVertexAnimVertexData, 
                                         mMesh.getAs().getSharedVertexDataAnimationIncludesNormals());
            }

            foreach (sub; mSubEntityList)
            {
                if (!sub.getSubMesh().useSharedVertices &&
                    sub.getSubMesh().getVertexAnimationType() == VertexAnimationType.VAT_POSE)
                {
                    VertexData data = sub._getSoftwareVertexAnimVertexData();
                    VertexElement elem = data.vertexDeclaration
                        .findElementBySemantic(VertexElementSemantic.VES_POSITION);
                    SharedPtr!HardwareVertexBuffer buf = data
                        .vertexBufferBinding.getBuffer(elem.getSource());
                    buf.get().suppressHardwareUpdate(true);
                    // if we're animating normals, we need to start with zeros
                    initialisePoseVertexData(sub.getSubMesh().vertexData, data, 
                                             sub.getSubMesh().getVertexAnimationIncludesNormals());
                }
            }
        }
        
        
        // Now apply the animation(s)
        // Note - you should only apply one morph animation to each set of vertex data
        // at once; if you do more, only the last one will actually apply
        markBuffersUnusedForAnimation();
        auto animIt = mAnimationState.getEnabledAnimationStates();
        foreach(state; animIt)
        {
            Animation anim = msh.getAs()._getAnimationImpl(state.getAnimationName());
            if (anim)
            {
                anim.apply(this, state.getTimePosition(), state.getWeight(),
                           swAnim, hardwareAnimation);
            }
        }
        // Deal with cases where no animation applied
        restoreBuffersForUnusedAnimation(hardwareAnimation);
        
        // Unsuppress hardware upload if we suppressed it
        if (!hardwareAnimation)
        {
            if (mSoftwareVertexAnimVertexData &&
                msh.getAs().getSharedVertexDataAnimationType() == VertexAnimationType.VAT_POSE)
            {
                // if we're animating normals, if pose influence < 1 need to use the base mesh
                if (mMesh.getAs().getSharedVertexDataAnimationIncludesNormals())
                    finalisePoseNormals(mMesh.getAs().sharedVertexData, mSoftwareVertexAnimVertexData);
                
                VertexElement elem = mSoftwareVertexAnimVertexData
                    .vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
                SharedPtr!HardwareVertexBuffer buf = mSoftwareVertexAnimVertexData
                    .vertexBufferBinding.getBuffer(elem.getSource());
                buf.get().suppressHardwareUpdate(false);
            }
            foreach (sub; mSubEntityList)
            {
                if (!sub.getSubMesh().useSharedVertices &&
                    sub.getSubMesh().getVertexAnimationType() == VertexAnimationType.VAT_POSE)
                {
                    VertexData data = sub._getSoftwareVertexAnimVertexData();
                    // if we're animating normals, if pose influence < 1 need to use the base mesh
                    if (sub.getSubMesh().getVertexAnimationIncludesNormals())
                        finalisePoseNormals(sub.getSubMesh().vertexData, data);
                    
                    VertexElement elem = data.vertexDeclaration
                        .findElementBySemantic(VertexElementSemantic.VES_POSITION);
                    SharedPtr!HardwareVertexBuffer buf = data
                        .vertexBufferBinding.getBuffer(elem.getSource());
                    buf.get().suppressHardwareUpdate(false);
                }
            }
        }
        
    }
    
    /// Initialise the hardware animation elements for given vertex data.
    ushort initHardwareAnimationElements(ref VertexData vdata, ushort numberOfElements, bool animateNormals)
    {
        ushort elemsSupported = numberOfElements;
        if (vdata.hwAnimationDataList.length < numberOfElements)
        {
            elemsSupported = 
                vdata.allocateHardwareAnimationElements(numberOfElements, animateNormals);
        }
        // Initialise parametrics incase we don't use all of them
        for (size_t i = 0; i < vdata.hwAnimationDataList.length; ++i)
        {
            vdata.hwAnimationDataList[i].parametric = 0.0f;
        }
        // reset used count
        vdata.hwAnimDataItemsUsed = 0;
        
        return elemsSupported;
        
    }
    
    /// Are software vertex animation temp buffers bound?
    bool tempVertexAnimBuffersBound()
    {
        // Do we still have temp buffers for software vertex animation bound?
        bool ret = true;
        if (mMesh.getAs().sharedVertexData && mMesh.getAs().getSharedVertexDataAnimationType() != VertexAnimationType.VAT_NONE)
        {
            ret = ret && mTempVertexAnimInfo.buffersCheckedOut(true, mMesh.getAs().getSharedVertexDataAnimationIncludesNormals());
        }
        foreach (sub; mSubEntityList)
        {
            if (!sub.getSubMesh().useSharedVertices
                && sub.getSubMesh().getVertexAnimationType() != VertexAnimationType.VAT_NONE)
            {
                ret = ret && sub._getVertexAnimTempBufferInfo().buffersCheckedOut(
                    true, sub.getSubMesh().getVertexAnimationIncludesNormals());
            }
        }
        return ret;
    }
    
    /// Are software skeleton animation temp buffers bound?
    bool tempSkelAnimBuffersBound(bool requestNormals)
    {
        // Do we still have temp buffers for software skeleton animation bound?
        if (mSkelAnimVertexData)
        {
            if (!mTempSkelAnimInfo.buffersCheckedOut(true, requestNormals))
                return false;
        }
        foreach (sub; mSubEntityList)
        {
            if (sub.isVisible() && sub.mSkelAnimVertexData)
            {
                if (!sub.mTempSkelAnimInfo.buffersCheckedOut(true, requestNormals))
                    return false;
            }
        }
        return true;
    }
    
public:
    /// Contains the child objects (attached to bones) indexed by name.
    //typedef map<string, MovableObject*>.type ChildObjectList;
    //alias MovableObject[string] ChildObjectList;
protected:
    MovableObject[string] mChildObjectList;
    
    
    /// Bounding box that 'contains' all the mesh of each child entity.
    //mutable 
    AxisAlignedBox mFullBoundingBox;
    
    ShadowRenderableList mShadowRenderables;
    
    /** Nested class to allow entity shadows. */
    //static 
    class EntityShadowRenderable : ShadowRenderable
    {

    protected:
        Entity mParent;
        /// Shared link to position buffer.
        SharedPtr!HardwareVertexBuffer mPositionBuffer;
        /// Shared link to w-coord buffer (optional).
        SharedPtr!HardwareVertexBuffer mWBuffer;
        /// Link to current vertex data used to bind (maybe changes).
        VertexData mCurrentVertexData;
        /// Original position buffer source binding.
        ushort mOriginalPosBufferBinding;
        /// Link to SubEntity, only present if SubEntity has it's own geometry.
        SubEntity mSubEntity;
        
        
    public:
        this(ref Entity parent,
             SharedPtr!HardwareIndexBuffer indexBuffer, ref VertexData vertexData,
             bool createSeparateLightCap, ref SubEntity subent, bool isLightCap = false)
            
        {
            mParent = parent; 
            mSubEntity = subent;
            // Save link to vertex data
            mCurrentVertexData = vertexData;
            
            // Initialise render op
            mRenderOp.indexData = new IndexData();
            mRenderOp.indexData.indexBuffer = indexBuffer; //TODO passing pointers
            mRenderOp.indexData.indexStart = 0;
            // index start and count are sorted out later
            
            // Create vertex data which just references position component (and 2 component)
            mRenderOp.vertexData = new VertexData();
            // Map in position data
            mRenderOp.vertexData.vertexDeclaration.addElement(0,0,VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_POSITION);
            mOriginalPosBufferBinding =
                vertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION).getSource();
            mPositionBuffer = vertexData.vertexBufferBinding.getBuffer(mOriginalPosBufferBinding);
            mRenderOp.vertexData.vertexBufferBinding.setBinding(0, mPositionBuffer);
            // Map in w-coord buffer (if present)
            if(!vertexData.hardwareShadowVolWBuffer.isNull())
            {
                mRenderOp.vertexData.vertexDeclaration.addElement(1,0,VertexElementType.VET_FLOAT1, VertexElementSemantic.VES_TEXTURE_COORDINATES, 0);
                mWBuffer = vertexData.hardwareShadowVolWBuffer;
                mRenderOp.vertexData.vertexBufferBinding.setBinding(1, mWBuffer);
            }
            // Use same vertex start as input
            mRenderOp.vertexData.vertexStart = vertexData.vertexStart;
            
            if (isLightCap)
            {
                // Use original vertex count, no extrusion
                mRenderOp.vertexData.vertexCount = vertexData.vertexCount;
            }
            else
            {
                // Vertex count must take into account the doubling of the buffer,
                // because second half of the buffer is the extruded copy
                mRenderOp.vertexData.vertexCount =
                    vertexData.vertexCount * 2;
                if (createSeparateLightCap)
                {
                    _createSeparateLightCap();
                }
            }
        }
        ~this()
        {
            destroy(mRenderOp.indexData);
            destroy(mRenderOp.vertexData);
        }
        
        /// Create the separate light cap if it doesn't already exists.
        void _createSeparateLightCap()
        {
            if (mLightCap is null)
            {
                // Create child light cap
                mLightCap = new EntityShadowRenderable(mParent,
                                                       mRenderOp.indexData.indexBuffer, mCurrentVertexData, false, mSubEntity, true);
            }   
        }
        /// @copydoc ShadowRenderable.getWorldTransforms.
        override void getWorldTransforms(ref Matrix4[] xform)
        {
            insertOrReplace(xform, mParent._getParentNodeFullTransform());
        }
        
        SharedPtr!HardwareVertexBuffer getPositionBuffer() { return mPositionBuffer; }
        SharedPtr!HardwareVertexBuffer getWBuffer() { return mWBuffer; }
        
        /// Rebind the source positions (for temp buffer users).
        void rebindPositionBuffer(VertexData vertexData, bool force)
        {
            if (force || mCurrentVertexData != vertexData)
            {
                mCurrentVertexData = vertexData;
                mPositionBuffer = mCurrentVertexData.vertexBufferBinding.getBuffer(
                    mOriginalPosBufferBinding);
                mRenderOp.vertexData.vertexBufferBinding.setBinding(0, mPositionBuffer);
                if (mLightCap)
                {
                    (cast(EntityShadowRenderable)(mLightCap)).rebindPositionBuffer(vertexData, force);
                }
            }
        }
        /// @copydoc ShadowRenderable.isVisible.
        override bool isVisible()
        {
            if (mSubEntity)
            {
                return mSubEntity.isVisible();
            }
            else
            {
                return ShadowRenderable.isVisible();
            }
        }
        /// @copydoc ShadowRenderable.rebindIndexBuffer.
        override void rebindIndexBuffer(SharedPtr!HardwareIndexBuffer* indexBuffer)
        {
            mRenderOp.indexData.indexBuffer = *indexBuffer;
            if (mLightCap) mLightCap.rebindIndexBuffer(indexBuffer);
        }
    }
public:
    /** Default destructor.
     */
    ~this()
    {
        _deinitialise();
        // Unregister our listener
        mMesh.getAs().removeListener(this);
    }
    
    /** Gets the Mesh that this Entity is based on.
     */
    ref SharedPtr!Mesh getMesh()
    {
        return mMesh;
    }
    
    /** Gets a pointer to a SubEntity, ie a part of an Entity.
     */
    ref SubEntity getSubEntity(uint index)
    {
        if (index >= mSubEntityList.length)
            throw new InvalidParamsError(
                "Index out of bounds.",
                "Entity.getSubEntity");
        return mSubEntityList[index];
    }
    
    /** Gets a pointer to a SubEntity by name
     @remarks 
     Names should be initialized during a Mesh creation.
     */
    ref SubEntity getSubEntity(string name )
    {
        ushort index = mMesh.getAs()._getSubMeshIndex(name);
        return getSubEntity(index);
    }
    
    /** Retrieves the number of SubEntity objects making up this entity.
     */
    uint getNumSubEntities()
    {
        return cast( uint )( mSubEntityList.length );
    }
    
    /** Clones this entity and returns a pointer to the clone.
     @remarks
     Useful method for duplicating an entity. The new entity must be
     given a unique name, and is not attached to the scene in any way
     so must be attached to a SceneNode to be visible (exactly as
     entities returned from SceneManager.createEntity).
     @param newName
     Name for the new entity.
     */
    Entity clone(string newName )
    {
        if (!mManager)
        {
            throw new ItemNotFoundError(
                "Cannot clone an Entity that wasn't created through a "
                "SceneManager", "Entity.clone");
        }
        Entity newEnt = mManager.createEntity(newName, getMesh().getAs().getName() );
        
        if (mInitialised)
        {
            // Copy material settings
            uint n = 0;
            foreach (sub; mSubEntityList)
            {
                newEnt.getSubEntity(n).setMaterialName(sub.getMaterialName());
                n++;
            }
            if (mAnimationState)
            {
                destroy(newEnt.mAnimationState);
                newEnt.mAnimationState = new AnimationStateSet(mAnimationState);
            }
        }
        
        return newEnt;
    }
    
    /** Sets the material to use for the whole of this entity.
     @remarks
     This is a shortcut method to set all the materials for all
     subentities of this entity. Only use this method is you want to
     set the same material for all subentities or if you know there
     is only one. Otherwise call getSubEntity() and call the same
     method on the individual SubEntity.
     */
    void setMaterialName(string name,string groupName = ResourceGroupManager.AUTODETECT_RESOURCE_GROUP_NAME )
    {
        // Set for all subentities
        foreach (i; mSubEntityList)
        {
            i.setMaterialName(name, groupName);
        }
        
    }
    
    
    /** Sets the material to use for the whole of this entity.
     @remarks
     This is a shortcut method to set all the materials for all
     subentities of this entity. Only use this method is you want to
     set the same material for all subentities or if you know there
     is only one. Otherwise call getSubEntity() and call the same
     method on the individual SubEntity.
     */
    void setMaterial(SharedPtr!Material material)
    {
        // Set for all subentities
        foreach (sub; mSubEntityList)
        {
            sub.setMaterial(material);
        }
    }
    
    /** @copydoc MovableObject._notifyCurrentCamera.
     */
    override void _notifyCurrentCamera(Camera cam)
    {
        MovableObject._notifyCurrentCamera(cam);
        
        // Calculate the LOD
        if (mParentNode)
        {
            // Get mesh lod strategy
            LodStrategy meshStrategy = mMesh.getAs().getLodStrategy();
            // Get the appropriate lod value
            Real lodValue = meshStrategy.getValue(this, cam);
            // Bias the lod value
            Real biasedMeshLodValue = lodValue * mMeshLodFactorTransformed;
            
            
            // Get the index at this biased depth
            ushort newMeshLodIndex = mMesh.getAs().getLodIndex(biasedMeshLodValue);
            // Apply maximum detail restriction (remember lower = higher detail)
            newMeshLodIndex = std.algorithm.max(mMaxMeshLodIndex, newMeshLodIndex);
            // Apply minimum detail restriction (remember higher = lower detail)
            newMeshLodIndex = std.algorithm.min(mMinMeshLodIndex, newMeshLodIndex);
            
            // Construct event object
            EntityMeshLodChangedEvent evt;
            evt.entity = this;
            evt.camera = cam;
            evt.lodValue = biasedMeshLodValue;
            evt.previousLodIndex = mMeshLodIndex;
            evt.newLodIndex = newMeshLodIndex;
            
            // Notify lod event listeners
            cam.getSceneManager()._notifyEntityMeshLodChanged(evt);
            
            // Change lod index
            mMeshLodIndex = evt.newLodIndex;
            
            // Now do material LOD
            lodValue *= mMaterialLodFactorTransformed;
            
            
            foreach (sub; mSubEntityList)
            {
                // Get sub-entity material
                SharedPtr!Material material = sub.getMaterial();
                
                // Get material lod strategy
                LodStrategy materialStrategy = material.getAs().getLodStrategy();
                
                // Recalculate lod value if strategies do not match
                Real biasedMaterialLodValue;
                if (meshStrategy == materialStrategy)
                    biasedMaterialLodValue = lodValue;
                else
                    biasedMaterialLodValue = materialStrategy.getValue(this, cam) * materialStrategy.transformBias(mMaterialLodFactor);
                
                // Get the index at this biased depth
                ushort idx = material.getAs().getLodIndex(biasedMaterialLodValue);
                // Apply maximum detail restriction (remember lower = higher detail)
                idx = std.algorithm.max(mMaxMaterialLodIndex, idx);
                // Apply minimum detail restriction (remember higher = lower detail)
                idx = std.algorithm.min(mMinMaterialLodIndex, idx);
                
                // Construct event object
                EntityMaterialLodChangedEvent subEntEvt;
                subEntEvt.subEntity = sub;
                subEntEvt.camera = cam;
                subEntEvt.lodValue = biasedMaterialLodValue;
                subEntEvt.previousLodIndex = sub.mMaterialLodIndex;
                subEntEvt.newLodIndex = idx;
                
                // Notify lod event listeners
                cam.getSceneManager()._notifyEntityMaterialLodChanged(subEntEvt);
                
                // Change lod index
                sub.mMaterialLodIndex = subEntEvt.newLodIndex;
                
                // Also invalidate any camera distance cache
                sub._invalidateCameraCache ();
            }
            
            
        }
        // Notify any child objects
        foreach(k, child; mChildObjectList)
        {
            child._notifyCurrentCamera(cam);
        }
    }
    
    /// @copydoc MovableObject.setRenderQueueGroup.
    //void setRenderQueueGroup(ushort queueID)
    override void setRenderQueueGroup(ubyte queueID)
    {
        super.setRenderQueueGroup(queueID);
        
        // Set render queue for all manual LOD entities
        if (mMesh.getAs().isLodManual())
        {
            foreach (lod; mLodEntityList)
            {
                lod.setRenderQueueGroup(queueID);
            }
        }
    }

    //alias MovableObject.setRenderQueueGroupAndPriority setRenderQueueGroupAndPriority;
    //alias MovableObject.setRenderQueueGroup setRenderQueueGroup;
    //TODO using ushort instead of ubyte to differentiate
    /// @copydoc MovableObject.setRenderQueueGroupAndPriority.
    //void setRenderQueueGroupAndPriority(ushort queueID, ushort priority)
    override void setRenderQueueGroupAndPriority(ubyte queueID, ushort priority)
    {
        super.setRenderQueueGroupAndPriority(cast(ubyte)queueID, priority);
        
        // Set render queue for all manual LOD entities
        if (mMesh.getAs().isLodManual())
        {
            foreach (lod; mLodEntityList)
            {
                lod.setRenderQueueGroupAndPriority(queueID, priority);
            }
        }
    }
    
    /** @copydoc MovableObject.getBoundingBox.
     */
    override AxisAlignedBox getBoundingBox()
    {
        // Get from Mesh
        if (mMesh.getAs().isLoaded())
        {
            mFullBoundingBox = mMesh.getAs().getBounds();
            mFullBoundingBox.merge(getChildObjectsBoundingBox());
            
            // Don't scale here, this is taken into account when world BBox calculation is done
        }
        else
            mFullBoundingBox.setNull();
        
        return mFullBoundingBox;
    }
    
    /// Merge all the child object Bounds a return it.
    AxisAlignedBox getChildObjectsBoundingBox()
    {
        AxisAlignedBox aa_box;
        AxisAlignedBox full_aa_box;
        full_aa_box.setNull();
        
        foreach(k, child; mChildObjectList)
        {
            aa_box = child.getBoundingBox();
            TagPoint tp = cast(TagPoint)child.getParentNode();
            // Use transform local to skeleton since world xform comes later
            aa_box.transformAffine(tp._getFullLocalTransform());
            
            full_aa_box.merge(aa_box);
        }
        
        return full_aa_box;
    }
    
    /** @copydoc MovableObject._updateRenderQueue.
     */
    override void _updateRenderQueue(RenderQueue queue)
    {
        debug(STDERR) std.stdio.stderr.writeln("Entity._updateRenderQueue:", mInitialised);
        // Do nothing if not initialised yet
        if (!mInitialised)
            return;
        
        // Check mesh state count, will be incremented if reloaded
        if (mMesh.getAs().getStateCount() != mMeshStateCount)
        {
            // force reinitialise
            _initialise(true);
        }
        
        Entity displayEntity = this;
        // Check we're not using a manual LOD
        if (mMeshLodIndex > 0 && mMesh.getAs().isLodManual())
        {
            // Use alternate entity
            assert( cast(size_t)( mMeshLodIndex - 1 ) < mLodEntityList.length ,
                   "No LOD EntityList - did you build the manual LODs after creating the entity?");
            // index - 1 as we skip index 0 (original lod)
            if (hasSkeleton() && mLodEntityList[mMeshLodIndex - 1].hasSkeleton())
            {
                // Copy the animation state set to lod entity, we assume the lod
                // entity only has a subset animation states
                AnimationStateSet targetState = mLodEntityList[mMeshLodIndex - 1].mAnimationState;
                if (mAnimationState != targetState) // only copy if lods use different skeleton instances
                {
                    if (mAnimationState.getDirtyFrameNumber() != targetState.getDirtyFrameNumber()) // only copy if animation was updated
                        mAnimationState.copyMatchingState(targetState);
                }
            }
            displayEntity = mLodEntityList[mMeshLodIndex - 1];
        }
        
        debug(STDERR) std.stdio.stderr.writeln("Entity._updateRenderQueue sub list:", displayEntity.mSubEntityList);
        // Add each visible SubEntity to the queue
        foreach (sub; displayEntity.mSubEntityList)
        {
            if(sub.isVisible())
            {
                // Order: first use subentity queue settings, if available
                //        if not then use entity queue settings, if available
                //        finally fall back on default queue settings
                if(sub.isRenderQueuePrioritySet())
                {
                    assert(sub.isRenderQueueGroupSet() == true);
                    queue.addRenderable(sub, sub.getRenderQueueGroup(), sub.getRenderQueuePriority());
                }
                else if(sub.isRenderQueueGroupSet())
                {
                    queue.addRenderable(sub, sub.getRenderQueueGroup());
                }
                else if (mRenderQueuePrioritySet)
                {
                    assert(mRenderQueueIDSet == true);
                    queue.addRenderable(sub, mRenderQueueID, mRenderQueuePriority);
                }
                else if(mRenderQueueIDSet)
                {
                    queue.addRenderable(sub, mRenderQueueID);
                }
                else
                {
                    queue.addRenderable(sub);
                }
            }
        }
        
        if (getAlwaysUpdateMainSkeleton() && hasSkeleton() && (mMeshLodIndex > 0))
        {
            //check if an update was made
            if (cacheBoneMatrices())
            {
                getSkeleton()._updateTransforms();
                //We will mark the skeleton as dirty. Otherwise, if in the same frame the entity will 
                //be rendered first with a low LOD and then with a high LOD the system wont know that
                //the bone matrices has changed and there for will not update the vertex buffers
                getSkeleton()._notifyManualBonesDirty();
            }
        }
        
        // Since we know we're going to be rendered, take this opportunity to
        // update the animation
        if (displayEntity.hasSkeleton() || displayEntity.hasVertexAnimation())
        {
            displayEntity.updateAnimation();
            
            //--- pass this point,  we are sure that the transformation matrix of each bone and tagPoint have been updated
            foreach(k,child; mChildObjectList)
            {
                bool visible = child.isVisible();
                if (visible && (displayEntity != this))
                {
                    //Check if the bone exists in the current LOD
                    
                    //The child is connected to a tagpoint which is connected to a bone
                    Bone bone = cast(Bone)(child.getParentNode().getParent());
                    if (!displayEntity.getSkeleton().hasBone(bone.getName()))
                    {
                        //Current LOD entity does not have the bone that the
                        //child is connected to. Do not display.
                        visible = false;
                    }
                }
                if (visible)
                {
                    child._updateRenderQueue(queue);
                }
            }
        }
        
        // HACK to display bones
        // This won't work if the entity is not centered at the origin
        // TODO work out a way to allow bones to be rendered when Entity not centered
        if (mDisplaySkeleton && hasSkeleton())
        {
            int numBones = mSkeletonInstance.getNumBones();
            for (ushort b = 0; b < numBones; ++b)
            {
                Bone bone = mSkeletonInstance.getBone(b);
                if (mRenderQueuePrioritySet)
                {
                    assert(mRenderQueueIDSet == true);
                    queue.addRenderable(bone.getDebugRenderable(1), mRenderQueueID, mRenderQueuePriority);
                }
                else if(mRenderQueueIDSet)
                {
                    queue.addRenderable(bone.getDebugRenderable(1), mRenderQueueID);
                } 
                else 
                {
                    queue.addRenderable(bone.getDebugRenderable(1));
                }
            }
        }
        
        
        
        
    }
    
    /** @copydoc MovableObject.getMovableType */
    override string getMovableType()
    {
        return EntityFactory.FACTORY_TYPE_NAME;
    }
    
    /** For entities based on animated meshes, gets the AnimationState object for a single animation.
     @remarks
     You animate an entity by updating the animation state objects. Each of these represents the
     current state of each animation available to the entity. The AnimationState objects are
     initialised from the Mesh object.
     */
    ref AnimationState getAnimationState(string name)
    {
        if (!mAnimationState)
        {
            throw new ItemNotFoundError("Entity is not animated",
                                        "Entity.getAnimationState");
        }
        
        return mAnimationState.getAnimationState(name);
    }
    
    /** Returns whether the AnimationState with the given name exists. */
    bool hasAnimationState(string name)
    {
        return mAnimationState && mAnimationState.hasAnimationState(name);
    }
    /** For entities based on animated meshes, gets the AnimationState objects for all animations.
     @return
     In case the entity is animated, this functions returns the pointer to a AnimationStateSet
     containing all animations of the entries. If the entity is not animated, it returns 0.
     @remarks
     You animate an entity by updating the animation state objects. Each of these represents the
     current state of each animation available to the entity. The AnimationState objects are
     initialised from the Mesh object.
     */
    AnimationStateSet getAllAnimationStates()
    {
        return mAnimationState;
    }
    
    /** Tells the Entity whether or not it should display it's skeleton, if it has one.
     */
    void setDisplaySkeleton(bool display)
    {
        mDisplaySkeleton = display;
    }
    
    /** Returns whether or not the entity is currently displaying its skeleton.
     */
    bool getDisplaySkeleton()
    {
        return mDisplaySkeleton;
    }
    
    /** Gets a pointer to the entity representing the numbered manual level of detail.
     @remarks
     The zero-based index never includes the original entity, unlike
     Mesh.getLodLevel.
     */
    ref Entity getManualLodLevel(size_t index)
    {
        assert(index < mLodEntityList.length);
        
        return mLodEntityList[index];
    }
    
    /** Returns the number of manual levels of detail that this entity supports.
     @remarks
     This number never includes the original entity, it is difference
     with Mesh.getNumLodLevels.
     */
    size_t getNumManualLodLevels()
    {
        return mLodEntityList.length;
    }
    
    /** Returns the current LOD used to render
     */
    ushort getCurrentLodIndex() { return mMeshLodIndex; }
    
    /** Sets a level-of-detail bias for the mesh detail of this entity.
     @remarks
     Level of detail reduction is normally applied automatically based on the Mesh
     settings. However, it is possible to influence this behaviour for this entity
     by adjusting the LOD bias. This 'nudges' the mesh level of detail used for this
     entity up or down depending on your requirements. You might want to use this
     if there was a particularly important entity in your scene which you wanted to
     detail better than the others, such as a player model.
     @par
     There are three parameters to this method; the first is a factor to apply; it
     defaults to 1.0 (no change), by increasing this to say 2.0, this model would
     take twice as long to reduce in detail, whilst at 0.5 this entity would use lower
     detail versions twice as quickly. The other 2 parameters are hard limits which
     let you set the maximum and minimum level-of-detail version to use, after all
     other calculations have been made. This lets you say that this entity should
     never be simplified, or that it can only use LODs below a certain level even
     when right next to the camera.
     @param factor
     Proportional factor to apply to the distance at which LOD is changed.
     Higher values increase the distance at which higher LODs are displayed (2.0 is
     twice the normal distance, 0.5 is half).
     @param maxDetailIndex
     The index of the maximum LOD this entity is allowed to use (lower
     indexes are higher detail: index 0 is the original full detail model).
     @param minDetailIndex
     The index of the minimum LOD this entity is allowed to use (higher
     indexes are lower detail). Use something like 99 if you want unlimited LODs (the actual
     LOD will be limited by the number in the Mesh).
     */
    void setMeshLodBias(Real factor, ushort maxDetailIndex = 0, ushort minDetailIndex = 99)
    {
        mMeshLodFactorTransformed = mMesh.getAs().getLodStrategy().transformBias(factor);
        mMaxMeshLodIndex = maxDetailIndex;
        mMinMeshLodIndex = minDetailIndex;
        
    }
    
    /** Sets a level-of-detail bias for the material detail of this entity.
     @remarks
     Level of detail reduction is normally applied automatically based on the Material
     settings. However, it is possible to influence this behaviour for this entity
     by adjusting the LOD bias. This 'nudges' the material level of detail used for this
     entity up or down depending on your requirements. You might want to use this
     if there was a particularly important entity in your scene which you wanted to
     detail better than the others, such as a player model.
     @par
     There are three parameters to this method; the first is a factor to apply; it
     defaults to 1.0 (no change), by increasing this to say 2.0, this entity would
     take twice as long to use a lower detail material, whilst at 0.5 this entity
     would use lower detail versions twice as quickly. The other 2 parameters are
     hard limits which let you set the maximum and minimum level-of-detail index
     to use, after all other calculations have been made. This lets you say that
     this entity should never be simplified, or that it can only use LODs below
     a certain level even when right next to the camera.
     @param factor
     Proportional factor to apply to the distance at which LOD is changed.
     Higher values increase the distance at which higher LODs are displayed (2.0 is
     twice the normal distance, 0.5 is half).
     @param maxDetailIndex
     The index of the maximum LOD this entity is allowed to use (lower
     indexes are higher detail: index 0 is the original full detail model).
     @param minDetailIndex
     The index of the minimum LOD this entity is allowed to use (higher
     indexes are lower detail. Use something like 99 if you want unlimited LODs (the actual
     LOD will be limited by the number of lod indexes used in the Material).
     */
    void setMaterialLodBias(Real factor, ushort maxDetailIndex = 0, ushort minDetailIndex = 99)
    {
        mMaterialLodFactor = factor;
        mMaterialLodFactorTransformed = mMesh.getAs().getLodStrategy().transformBias(factor);
        mMaxMaterialLodIndex = maxDetailIndex;
        mMinMaterialLodIndex = minDetailIndex;
        
    }
    
    /** Sets whether the polygon mode of this entire entity may be
     overridden by the camera detail settings.
     */
    void setPolygonModeOverrideable(bool PolygonModeOverrideable)
    {
        foreach( sub; mSubEntityList)
        {
            sub.setPolygonModeOverrideable(PolygonModeOverrideable);
        }
    }
    /** Attaches another object to a certain bone of the skeleton which this entity uses.
     @remarks
     This method can be used to attach another object to an animated part of this entity,
     by attaching it to a bone in the skeleton (with an offset if required). As this entity
     is animated, the attached object will move relative to the bone to which it is attached.
     @par
     An exception is thrown if the movable object is already attached to the bone, another bone or scenenode.
     If the entity has no skeleton or the bone name cannot be found then an exception is thrown.
     @param boneName
     The name of the bone (in the skeleton) to attach this object
     @param pMovable
     Pointer to the object to attach
     @param offsetOrientation
     An adjustment to the orientation of the attached object, relative to the bone.
     @param offsetPosition
     An adjustment to the position of the attached object, relative to the bone.
     @return
     The TagPoint to which the object has been attached
     */
    TagPoint attachObjectToBone(string boneName,
                                ref MovableObject pMovable,
                                Quaternion offsetOrientation = Quaternion.IDENTITY,
                                Vector3 offsetPosition = Vector3.ZERO)
    {
        if ((pMovable.getName() in mChildObjectList) !is null)
        {
            throw new DuplicateItemError(
                "An object with the name " ~ pMovable.getName() ~ " already attached",
                "Entity.attachObjectToBone");
        }
        if(pMovable.isAttached())
        {
            throw new InvalidParamsError( "Object already attached to a sceneNode or a Bone",
                                         "Entity.attachObjectToBone");
        }
        if (!hasSkeleton())
        {
            throw new InvalidParamsError( "This entity's mesh has no skeleton to attach object to.",
                                         "Entity.attachObjectToBone");
        }
        Bone bone = mSkeletonInstance.getBone(boneName);
        if (!bone)
        {
            throw new InvalidParamsError( "Cannot locate bone named " ~ boneName,
                                         "Entity.attachObjectToBone");
        }
        
        TagPoint tp = mSkeletonInstance.createTagPointOnBone(
            bone, offsetOrientation, offsetPosition);
        tp.setParentEntity(this);
        tp.setChildObject(pMovable);
        
        attachObjectImpl(pMovable, tp);
        
        // Trigger update of bounding box if necessary
        if (mParentNode)
            mParentNode.needUpdate();
        
        return tp;
    }
    
    /** Detach a MovableObject previously attached using attachObjectToBone.
     If the movable object name is not found then an exception is raised.
     @param movableName
     The name of the movable object to be detached.
     */
    MovableObject detachObjectFromBone(string movableName)
    {
        auto i = movableName in mChildObjectList;
        
        if (i is null)
        {
            throw new ItemNotFoundError("No child object entry found named " ~ movableName,
                                        "Entity.detachObjectFromBone");
        }
        MovableObject obj = *i;
        detachObjectImpl(obj);
        mChildObjectList.remove(movableName);
        
        // Trigger update of bounding box if necessary
        if (mParentNode)
            mParentNode.needUpdate();
        
        return obj;
    }
    
    /** Detaches an object by pointer.
     @remarks
     Use this method to destroy a MovableObject which is attached to a bone of belonging this entity.
     But sometimes the object may be not in the child object list because it is a lod entity,
     this method can safely detect and ignore in this case and won't raise an exception.
     */
    void detachObjectFromBone(ref MovableObject obj)
    {
        foreach (k, child; mChildObjectList)
        {
            if (child == obj)
            {
                detachObjectImpl(obj);
                mChildObjectList.remove(k);
                
                // Trigger update of bounding box if necessary
                if (mParentNode)
                    mParentNode.needUpdate();
                break;
            }
        }
    }
    
    /// Detach all MovableObjects previously attached using attachObjectToBone
    void detachAllObjectsFromBone()
    {
        detachAllObjectsImpl();
        
        // Trigger update of bounding box if necessary
        if (mParentNode)
            mParentNode.needUpdate();
    }
    
    //typedef MapIterator<ChildObjectList> ChildObjectListIterator;
    /** Gets an iterator to the list of objects attached to bones on this entity. */
    //ChildObjectListIterator getAttachedObjectIterator();

    ref MovableObject[string] getAttachedObjects()
    {
        return mChildObjectList;
    }

    /** @copydoc MovableObject.getBoundingRadius */
    override Real getBoundingRadius()
    {
        return mMesh.getAs().getBoundingSphereRadius();
    }
    
    /** @copydoc MovableObject.getWorldBoundingBox */
    override AxisAlignedBox getWorldBoundingBox(bool derive = false)
    {
        if (derive)
        {
            // derive child bounding boxes
            foreach(k,child; mChildObjectList)
            {
                child.getWorldBoundingBox(true);
            }
        }
        return MovableObject.getWorldBoundingBox(derive);
    }
    
    /** @copydoc MovableObject.getWorldBoundingSphere */
    override Sphere getWorldBoundingSphere(bool derive = false) //const
    {
        if (derive)
        {
            // derive child bounding boxes
            foreach(k,child; mChildObjectList)
            {
                child.getWorldBoundingSphere(true);
            }
        }
        return MovableObject.getWorldBoundingSphere(derive);
        
    }
    
    /** @copydoc ShadowCaster.getEdgeList. */
    override EdgeData getEdgeList()
    {
        // Get from Mesh
        return mMesh.getAs().getEdgeList(mMeshLodIndex);
    }
    
    /** @copydoc ShadowCaster.hasEdgeList. */
    override bool hasEdgeList()
    {
        // check if mesh has an edge list attached
        // give mesh a chance to built it if scheduled
        return (mMesh.getAs().getEdgeList(mMeshLodIndex) !is null);
    }
    
    /** @copydoc ShadowCaster.getShadowVolumeRenderableIterator. */
    override ShadowRenderableList getShadowVolumeRenderables(
        ShadowTechnique shadowTechnique, ref Light light,
        SharedPtr!HardwareIndexBuffer* indexBuffer,
        bool extrude, Real extrusionDistance, ulong flags = 0 )
    {
        assert(indexBuffer !is null , "Only external index buffers are supported right now");
        assert(indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_16BIT ,
               "Only 16-bit indexes supported for now");
        
        // Potentially delegate to LOD entity
        if (mMesh.getAs().isLodManual() && mMeshLodIndex > 0)
        {
            // Use alternate entity
            assert( mMeshLodIndex - 1 < mLodEntityList.length ,
                   "No LOD EntityList - did you build the manual LODs after creating the entity?");
            // delegate, we're using manual LOD and not the top lod index
            if (hasSkeleton() && mLodEntityList[mMeshLodIndex - 1].hasSkeleton())
            {
                // Copy the animation state set to lod entity, we assume the lod
                // entity only has a subset animation states
                AnimationStateSet targetState = mLodEntityList[mMeshLodIndex - 1].mAnimationState;
                if (mAnimationState != targetState) // only copy if lods have different skeleton instances
                {
                    if (mAnimationState.getDirtyFrameNumber() != targetState.getDirtyFrameNumber()) // only copy if animation was updated
                        mAnimationState.copyMatchingState(targetState);
                }
            }
            return mLodEntityList[mMeshLodIndex-1].getShadowVolumeRenderables(
                shadowTechnique, light, indexBuffer, extrude,
                extrusionDistance, flags);
        }
        
        
        // Prepare temp buffers if required
        if (!mPreparedForShadowVolumes)
        {
            mMesh.getAs().prepareForShadowVolume();
            // reset frame last updated to force update of animations if they exist
            if (mAnimationState)
                mFrameAnimationLastUpdated = mAnimationState.getDirtyFrameNumber() - 1;
            // re-prepare buffers
            prepareTempBlendBuffers();
        }
        
        
        bool hasAnimation = (hasSkeleton() || hasVertexAnimation());
        
        // Update any animation
        if (hasAnimation)
        {
            updateAnimation();
        }
        
        // Calculate the object space light details
        Vector4 lightPos = light.getAs4DVector();
        Matrix4 world2Obj = mParentNode._getFullTransform().inverseAffine();
        lightPos = world2Obj.transformAffine(lightPos);
        Matrix3 world2Obj3x3;
        world2Obj.extract3x3Matrix(world2Obj3x3);
        extrusionDistance *= Math.Sqrt(std.algorithm.min(std.algorithm.min(world2Obj3x3.GetColumn(0).squaredLength(), world2Obj3x3.GetColumn(1).squaredLength()), world2Obj3x3.GetColumn(2).squaredLength()));
        
        // We need to search the edge list for silhouette edges
        EdgeData edgeList = getEdgeList();
        
        if (!edgeList)
        {
            // we can't get an edge list for some reason, return blank
            // really we shouldn't be able to get here, but this is a safeguard
            return mShadowRenderables;//ShadowRenderableListIterator(mShadowRenderables.begin(), mShadowRenderables.end());
        }
        
        // Init shadow renderable list if required
        bool init = mShadowRenderables.empty();
        
        //EdgeData.EdgeGroupList.iterator egi;
        //ShadowRenderableList.iterator si, siend;
        EntityShadowRenderable esr;

        if (init)
            mShadowRenderables.length = edgeList.edgeGroups.length;
        
        bool isAnimated = hasAnimation;
        bool updatedSharedGeomNormals = false;
        size_t egi = 0;
        foreach (ref si; mShadowRenderables)
        {
            auto eg = edgeList.edgeGroups[egi++];
            VertexData pVertData;
            if (isAnimated)
            {
                // Use temp buffers
                pVertData = findBlendedVertexData(eg.vertexData);
            }
            else
            {
                pVertData = eg.vertexData;
            }
            if (init)
            {
                // Try to find corresponding SubEntity; this allows the
                // linkage of visibility between ShadowRenderable and SubEntity
                SubEntity subent = findSubEntityForVertexData(eg.vertexData);
                // Create a new renderable, create a separate light cap if
                // we're using a vertex program (either for this model, or
                // for extruding the shadow volume) since otherwise we can
                // get depth-fighting on the light cap
                //TODO passing pointers
                si = new EntityShadowRenderable(this, *indexBuffer, pVertData,
                                                mVertexProgramInUse || !extrude, subent);
            }
            else
            {
                // If we have animation, we have no guarantee that the position
                // buffer we used last frame is the same one we used last frame
                // since a temporary buffer is requested each frame
                // Therefore, we need to update the EntityShadowRenderable
                // with the current position buffer
                (cast(EntityShadowRenderable)si).rebindPositionBuffer(pVertData, hasAnimation);
                
            }
            // Get shadow renderable
            esr = cast(EntityShadowRenderable)si;
            SharedPtr!HardwareVertexBuffer esrPositionBuffer = esr.getPositionBuffer();
            // For animated entities we need to recalculate the face normals
            if (hasAnimation)
            {
                if (eg.vertexData != mMesh.getAs().sharedVertexData || !updatedSharedGeomNormals)
                {
                    // recalculate face normals
                    edgeList.updateFaceNormals(eg.vertexSet, esrPositionBuffer);
                    // If we're not extruding in software we still need to update
                    // the latter part of the buffer (the hardware extruded part)
                    // with the latest animated positions
                    if (!extrude)
                    {
                        // Lock, we'll be locking the (suppressed hardware update) shadow buffer
                        float* pSrc = cast(float*)(
                            esrPositionBuffer.get().lock(HardwareBuffer.LockOptions.HBL_NORMAL));
                        float* pDest = pSrc + (eg.vertexData.vertexCount * 3);
                        memcpy(pDest, pSrc, float.sizeof * 3 * eg.vertexData.vertexCount);
                        esrPositionBuffer.get().unlock();
                    }
                    if (eg.vertexData == mMesh.getAs().sharedVertexData)
                    {
                        updatedSharedGeomNormals = true;
                    }
                }
            }
            // Extrude vertices in software if required
            if (extrude)
            {
                extrudeVertices(esrPositionBuffer,
                                eg.vertexData.vertexCount,
                                lightPos, extrusionDistance);
                
            }
            // Stop suppressing hardware update now, if we were
            esrPositionBuffer.get().suppressHardwareUpdate(false);
            
        }
        // Calc triangle light facing
        updateEdgeListLightFacing(edgeList, lightPos);
        
        // Generate indexes and update renderables
        generateShadowVolume(edgeList, indexBuffer, light,
                             mShadowRenderables, flags);
        
        
        return mShadowRenderables;//ShadowRenderableListIterator(mShadowRenderables.begin(), mShadowRenderables.end());
    }
    
    /** Internal method for retrieving bone matrix information. */
    Matrix4[] _getBoneMatrices(){ return mBoneMatrices;}
    /** Internal method for retrieving bone matrix information. */
    ushort _getNumBoneMatrices(){ return mNumBoneMatrices; }
    /** Returns whether or not this entity is skeletally animated. */
    bool hasSkeleton(){ return mSkeletonInstance !is null; }
    /** Get this Entity's personal skeleton instance. */
    ref SkeletonInstance getSkeleton(){ return mSkeletonInstance; }
    /** Returns whether or not hardware animation is enabled.
     @remarks
     Because fixed-function indexed vertex blending is rarely supported
     by existing graphics cards, hardware animation can only be done if
     the vertex programs in the materials used to render an entity support
     it. Therefore, this method will only return true if all the materials
     assigned to this entity have vertex programs assigned, and all those
     vertex programs must support 'includes_morph_animation true' if using
     morph animation, 'includes_pose_animation true' if using pose animation
     and 'includes_skeletal_animation true' if using skeletal animation.

     Also note the the function returns value according to the current active
     scheme. This is due to the fact that RTSS schemes may be different in their
     handling of hardware animation.
     */
    bool isHardwareAnimationEnabled()
    {
        //find whether the entity has hardware animation for the current active sceme
        ushort schemeIndex = MaterialManager.getSingleton()._getActiveSchemeIndex();
        auto it = schemeIndex in mSchemeHardwareAnim;
        if (it is null)
        {
            //evaluate the animation hardware value
            mSchemeHardwareAnim[schemeIndex] = calcVertexProcessing();
            it = &mSchemeHardwareAnim[schemeIndex];
        }
        return *it;
    }
    
    /** @copydoc MovableObject._notifyAttached */
    override void _notifyAttached(Node parent, bool isTagPoint = false)
    {
        super._notifyAttached(parent, isTagPoint);
        // Also notify LOD entities
        foreach (i; mLodEntityList)
        {
            i._notifyAttached(parent, isTagPoint);
        }
        
    }
    /** Returns the number of requests that have been made for software animation
     @remarks
     If non-zero then software animation will be performed in updateAnimation
     regardless of the current setting of isHardwareAnimationEnabled or any
     internal optimise for eliminate software animation. Requests for software
     animation are made by calling the addSoftwareAnimationRequest() method.
     */
    int getSoftwareAnimationRequests(){ return mSoftwareAnimationRequests; }
    /** Returns the number of requests that have been made for software animation of normals
     @remarks
     If non-zero, and getSoftwareAnimationRequests() also returns non-zero,
     then software animation of normals will be performed in updateAnimation
     regardless of the current setting of isHardwareAnimationEnabled or any
     internal optimise for eliminate software animation. Currently it is not
     possible to force software animation of only normals. Consequently this
     value is always less than or equal to that returned by getSoftwareAnimationRequests().
     Requests for software animation of normals are made by calling the
     addSoftwareAnimationRequest() method with 'true' as the parameter.
     */
    int getSoftwareAnimationNormalsRequests(){ return mSoftwareAnimationNormalsRequests; }
    /** Add a request for software animation
     @remarks
     Tells the entity to perform animation calculations for skeletal/vertex
     animations in software, regardless of the current setting of
     isHardwareAnimationEnabled().  Software animation will be performed
     any time one or more requests have been made.  If 'normalsAlso' is
     'true', then the entity will also do software blending on normal
     vectors, in addition to positions. This advanced method useful for
     situations in which access to actual mesh vertices is required,
     such as accurate collision detection or certain advanced shading
     techniques. When software animation is no longer needed,
     the caller of this method should always remove the request by calling
     removeSoftwareAnimationRequest(), passing the same value for
     'normalsAlso'.
     */
    void addSoftwareAnimationRequest(bool normalsAlso)
    {
        mSoftwareAnimationRequests++;
        if (normalsAlso) {
            mSoftwareAnimationNormalsRequests++;
        }
    }
    /** Removes a request for software animation
     @remarks
     Calling this decrements the entity's internal counter of the number
     of requests for software animation.  If the counter is already zero
     then calling this method throws an exception.  The 'normalsAlso'
     flag if set to 'true' will also decrement the internal counter of
     number of requests for software animation of normals.
     */
    void removeSoftwareAnimationRequest(bool normalsAlso)
    {
        if (mSoftwareAnimationRequests == 0 ||
            (normalsAlso && mSoftwareAnimationNormalsRequests == 0))
        {
            throw new InvalidParamsError(
                "Attempt to remove nonexistent request.",
                "Entity.removeSoftwareAnimationRequest");
        }
        mSoftwareAnimationRequests--;
        if (normalsAlso) {
            mSoftwareAnimationNormalsRequests--;
        }
    }
    
    /** Shares the SkeletonInstance with the supplied entity.
     Note that in order for this to work, both entities must have the same
     Skeleton.
     */
    void shareSkeletonInstanceWith(ref Entity entity)
    {
        if (entity.getMesh().getAs().getSkeleton() != getMesh().getAs().getSkeleton())
        {
            throw new RTAssertionFailedError(
                "The supplied entity has a different skeleton.",
                "Entity.shareSkeletonWith");
        }
        if (!mSkeletonInstance)
        {
            throw new RTAssertionFailedError(
                "This entity has no skeleton.",
                "Entity.shareSkeletonWith");
        }
        if (mSharedSkeletonEntities !is null && entity.mSharedSkeletonEntities !is null)
        {
            throw new RTAssertionFailedError(
                "Both entities already shares their SkeletonInstances! At least " ~
                "one of the instances must not share it's instance.",
                "Entity.shareSkeletonWith");
        }
        
        //check if we already share our skeletoninstance, we don't want to delete it if so
        if (mSharedSkeletonEntities !is null)
        {
            entity.shareSkeletonInstanceWith(this);
        }
        else
        {
            destroy(mSkeletonInstance);
            destroy(mBoneMatrices);
            destroy(mAnimationState);
            // using OGRE_FREE since ulong is not a destructor
            destroy(mFrameBonesLastUpdated);
            mSkeletonInstance = entity.mSkeletonInstance;
            mNumBoneMatrices = entity.mNumBoneMatrices;
            mBoneMatrices = entity.mBoneMatrices;
            mAnimationState = entity.mAnimationState;
            mFrameBonesLastUpdated = entity.mFrameBonesLastUpdated;
            if (entity.mSharedSkeletonEntities is null)
            {
                //entity.mSharedSkeletonEntities = new EntitySet;
                entity.mSharedSkeletonEntities.insert(entity);
            }
            mSharedSkeletonEntities = entity.mSharedSkeletonEntities;
            mSharedSkeletonEntities.insert(this);
        }
    }
    
    /** Returns whether or not this entity is either morph or pose animated.
     */
    bool hasVertexAnimation()
    {
        return mMesh.getAs().hasVertexAnimation();
    }
    
    
    /** Stops sharing the SkeletonInstance with other entities.
     */
    void stopSharingSkeletonInstance()
    {
        if (mSharedSkeletonEntities is null)
        {
            throw new RTAssertionFailedError(
                "This entity is not sharing it's skeletoninstance.",
                "Entity.shareSkeletonWith");
        }
        //check if there's no other than us sharing the skeleton instance
        if (mSharedSkeletonEntities.length == 1)
        {
            //just reset
            destroy(mSharedSkeletonEntities);
            mSharedSkeletonEntities = null;
        }
        else
        {
            mSkeletonInstance = new SkeletonInstance(mMesh.getAs().getSkeleton());
            mSkeletonInstance.load();
            mAnimationState = new AnimationStateSet();
            mMesh.getAs()._initAnimationState(mAnimationState);
            mFrameBonesLastUpdated = new ulong;
            *mFrameBonesLastUpdated = ulong.max;
            mNumBoneMatrices = mSkeletonInstance.getNumBones();
            mBoneMatrices = new Matrix4[mNumBoneMatrices];
            
            mSharedSkeletonEntities.removeFromArray(this);
            if (mSharedSkeletonEntities.length == 1)
            {
                mSharedSkeletonEntities[0].stopSharingSkeletonInstance();
            }
            mSharedSkeletonEntities = null;
        }
    }
    
    
    /** Returns whether this entity shares it's SkeltonInstance with other entity instances.
     */
    bool sharesSkeletonInstance(){ return mSharedSkeletonEntities !is null; }
    
    /** Returns a pointer to the set of entities which share a SkeletonInstance.
     If this instance does not share it's SkeletonInstance with other instances @c null will be returned
     */
    ref EntitySet getSkeletonInstanceSharingSet(){ return mSharedSkeletonEntities; }
    
    /** Updates the internal animation state set to include the latest
     available animations from the attached skeleton.
     @remarks
     Use this method if you manually add animations to a skeleton, or have
     linked the skeleton to another for animation purposes since creating
     this entity.
     @note
     If you have called getAnimationState prior to calling this method,
     the pointers will still remain valid.
     */
    void refreshAvailableAnimationState()
    {
        mMesh.getAs()._refreshAnimationState(mAnimationState);
    }
    
    /** Advanced method to perform all the updates required for an animated entity.
     @remarks
     You don't normally need to call this, but it's here in case you wish
     to manually update the animation of an Entity at a specific point in
     time. Animation will not be updated more than once a frame no matter
     how many times you call this method.
     */
    void _updateAnimation()
    {
        // Externally visible method
        if (hasSkeleton() || hasVertexAnimation())
        {
            updateAnimation();
        }
    }
    
    /** Tests if any animation applied to this entity.
     @remarks
     An entity is animated if any animation state is enabled, or any manual bone
     applied to the skeleton.
     */
    bool _isAnimated()
    {
        return (mAnimationState && mAnimationState.hasEnabledAnimationState()) ||
            (getSkeleton() && getSkeleton().hasManualBones());
    }
    
    /** Tests if skeleton was animated.
     */
    bool _isSkeletonAnimated()
    {
        return getSkeleton() &&
            (mAnimationState.hasEnabledAnimationState() || getSkeleton().hasManualBones());
    }
    
    /** Advanced method to get the temporarily blended skeletal vertex information
     for entities which are software skinned.
     @remarks
     Internal engine will eliminate software animation if possible, this
     information is unreliable unless added request for software animation
     via addSoftwareAnimationRequest.
     @note
     The positions/normals of the returned vertex data is in object space.
     */
    ref VertexData _getSkelAnimVertexData()
    {
        assert (mSkelAnimVertexData , "Not software skinned or has no shared vertex data!");
        return mSkelAnimVertexData;
    }
    /** Advanced method to get the temporarily blended software vertex animation information
     @remarks
     Internal engine will eliminate software animation if possible, this
     information is unreliable unless added request for software animation
     via addSoftwareAnimationRequest.
     @note
     The positions/normals of the returned vertex data is in object space.
     */
    ref VertexData _getSoftwareVertexAnimVertexData()
    {
        assert (mSoftwareVertexAnimVertexData , "Not vertex animated or has no shared vertex data!");
        return mSoftwareVertexAnimVertexData;
    }
    /** Advanced method to get the hardware morph vertex information
     @note
     The positions/normals of the returned vertex data is in object space.
     */
    ref VertexData _getHardwareVertexAnimVertexData()
    {
        assert (mHardwareVertexAnimVertexData , "Not vertex animated or has no shared vertex data!");
        return mHardwareVertexAnimVertexData;
    }
    /** Advanced method to get the temp buffer information for software
     skeletal animation.
     */
    ref TempBlendedBufferInfo _getSkelAnimTempBufferInfo()
    {
        return mTempSkelAnimInfo;
    }
    /** Advanced method to get the temp buffer information for software
     morph animation.
     */
    ref TempBlendedBufferInfo _getVertexAnimTempBufferInfo()
    {
        return mTempVertexAnimInfo;
    }
    /// Override to return specific type flag.
    override uint getTypeFlags()
    {
        return SceneManager.ENTITY_TYPE_MASK;
    }
    /// Retrieve the VertexData which should be used for GPU binding.
    ref VertexData getVertexDataForBinding()
    {
        Entity.VertexDataBindChoice c =
            chooseVertexDataForBinding(mMesh.getAs().getSharedVertexDataAnimationType() != VertexAnimationType.VAT_NONE);
        switch(c)
        {
            case VertexDataBindChoice.BIND_ORIGINAL:
                return mMesh.getAs().sharedVertexData;
            case VertexDataBindChoice.BIND_HARDWARE_MORPH:
                return mHardwareVertexAnimVertexData;
            case VertexDataBindChoice.BIND_SOFTWARE_MORPH:
                return mSoftwareVertexAnimVertexData;
            case VertexDataBindChoice.BIND_SOFTWARE_SKELETAL:
                return mSkelAnimVertexData;
            default: 
                break;
        }
        // keep compiler happy
        return mMesh.getAs().sharedVertexData;
    }
    
    /// Identify which vertex data we should be sending to the renderer.
    enum VertexDataBindChoice
    {
        BIND_ORIGINAL,
        BIND_SOFTWARE_SKELETAL,
        BIND_SOFTWARE_MORPH,
        BIND_HARDWARE_MORPH
    }
    /// Choose which vertex data to bind to the renderer.
    VertexDataBindChoice chooseVertexDataForBinding(bool hasVertexAnim)
    {
        if (hasSkeleton())
        {
            if (!isHardwareAnimationEnabled())
            {
                // all software skeletal binds same vertex data
                // may be a 2-stage s/w transform including morph earlier though
                return VertexDataBindChoice.BIND_SOFTWARE_SKELETAL;
            }
            else if (hasVertexAnim)
            {
                // hardware morph animation
                return VertexDataBindChoice.BIND_HARDWARE_MORPH;
            }
            else
            {
                // hardware skeletal, no morphing
                return VertexDataBindChoice.BIND_ORIGINAL;
            }
        }
        else if (hasVertexAnim)
        {
            // morph only, no skeletal
            if (isHardwareAnimationEnabled())
            {
                return VertexDataBindChoice.BIND_HARDWARE_MORPH;
            }
            else
            {
                return VertexDataBindChoice.BIND_SOFTWARE_MORPH;
            }
            
        }
        else
        {
            return VertexDataBindChoice.BIND_ORIGINAL;
        }
        
    }
    
    /** Are buffers already marked as vertex animated? */
    bool _getBuffersMarkedForAnimation(){ return mVertexAnimationAppliedThisFrame; }
    /** Mark just this vertex data as animated.
     */
    void _markBuffersUsedForAnimation()
    {
        mVertexAnimationAppliedThisFrame = true;
        // no cascade
    }
    
    /** Has this Entity been initialised yet?
     @remarks
     If this returns false, it means this Entity hasn't been completely
     constructed yet from the underlying resources (Mesh, Skeleton), which 
     probably means they were delay-loaded and aren't available yet. This
     Entity won't render until it has been successfully initialised, nor
     will many of the manipulation methods function.
     */
    bool isInitialised(){ return mInitialised; }
    
    /** Try to initialise the Entity from the underlying resources.
     @remarks
     This method builds the internal structures of the Entity based on it
     resources (Mesh, Skeleton). This may or may not succeed if the 
     resources it references have been earmarked for background loading,
     so you should check isInitialised afterwards to see if it was successful.
     @param forceReinitialise
     If @c true, this forces the Entity to tear down it's
     internal structures and try to rebuild them. Useful if you changed the
     content of a Mesh or Skeleton at runtime.
     */
    void _initialise(bool forceReinitialise = false)
    {
        if (forceReinitialise)
            _deinitialise();
        
        if (mInitialised)
            return;
        
        if (mMesh.getAs().isBackgroundLoaded() && !mMesh.getAs().isLoaded())
        {
            // register for a callback when mesh is finished loading
            // do this before asking for load to happen to avoid race
            mMesh.getAs().addListener(this);
        }
        
        // On-demand load
        mMesh.getAs().load();
        // If loading failed, or deferred loading isn't done yet, defer
        // Will get a callback in the case of deferred loading
        // Skeletons are cascade-loaded so no issues there
        if (!mMesh.getAs().isLoaded())
            return;
        
        // Is mesh skeletally animated?
        if (mMesh.getAs().hasSkeleton() && !mMesh.getAs().getSkeleton().isNull())
        {
            mSkeletonInstance = new SkeletonInstance(mMesh.getAs().getSkeleton());
            mSkeletonInstance.load();
        }
        
        // Build main subentity list
        buildSubEntityList(mMesh, mSubEntityList);
        
        // Check if mesh is using manual LOD
        if (mMesh.getAs().isLodManual())
        {
            ushort i, numLod;
            numLod = mMesh.getAs().getNumLodLevels();
            // NB skip LOD 0 which is the original
            for (i = 1; i < numLod; ++i)
            {
                MeshLodUsage usage = mMesh.getAs().getLodLevel(i);
                // Manually create entity
                Entity lodEnt = new Entity(mName ~ "Lod" ~ std.conv.to!string(i),
                                           usage.manualMesh);
                mLodEntityList.insert(lodEnt);
            }
        }
        
        
        // Initialise the AnimationState, if Mesh has animation
        if (hasSkeleton())
        {
            mFrameBonesLastUpdated = new ulong;
            *mFrameBonesLastUpdated = ulong.max;
            mNumBoneMatrices = mSkeletonInstance.getNumBones();
            mBoneMatrices = new Matrix4[mNumBoneMatrices];
        }
        if (hasSkeleton() || hasVertexAnimation())
        {
            mAnimationState = new AnimationStateSet();
            mMesh.getAs()._initAnimationState(mAnimationState);
            prepareTempBlendBuffers();
        }
        
        reevaluateVertexProcessing();
        
        // Update of bounds of the parent SceneNode, if Entity already attached
        // this can happen if Mesh is loaded in background or after reinitialisation
        if( mParentNode )
        {
            getParentSceneNode().needUpdate();
        }
        
        mInitialised = true;
        mMeshStateCount = mMesh.getAs().getStateCount();
        
    }
    
    /** Tear down the internal structures of this Entity, rendering it uninitialised. */
    void _deinitialise()
    {
        if (!mInitialised)
            return;
        
        // Delete submeshes
        foreach (i; mSubEntityList)
        {
            // Delete SubEntity
            destroy(i);
        }
        mSubEntityList.clear();
        
        // Delete LOD entities
        foreach (li; mLodEntityList)
        {
            // Delete
            destroy(li);
        }
        mLodEntityList.clear();
        
        // Delete shadow renderables
        foreach (si; mShadowRenderables)
        {
            destroy(si);
        }
        mShadowRenderables.clear();
        
        // Detach all child objects, do this manually to avoid needUpdate() call
        // which can fail because of deleted items
        detachAllObjectsImpl();
        
        if (mSkeletonInstance) {
            //OGRE_FREE_SIMD(mBoneWorldMatrices, MEMCATEGORY_ANIMATION);
            //mBoneWorldMatrices = 0;
            destroy(mBoneWorldMatrices);
            
            if (mSharedSkeletonEntities) {
                mSharedSkeletonEntities.removeFromArray(this);
                if (mSharedSkeletonEntities.length == 1)
                {
                    mSharedSkeletonEntities[0].stopSharingSkeletonInstance();
                }
                // Should never occur, just in case
                else if (mSharedSkeletonEntities.empty())
                {
                    destroy(mSharedSkeletonEntities); mSharedSkeletonEntities = null;
                    // using OGRE_FREE since ulong is not a destructor
                    destroy(mFrameBonesLastUpdated); mFrameBonesLastUpdated = null;
                    destroy(mSkeletonInstance); mSkeletonInstance = null;
                    destroy(mBoneMatrices); mBoneMatrices = null;
                    destroy(mAnimationState); mAnimationState = null;
                }
            } else {
                // using OGRE_FREE since ulong is not a destructor
                destroy(mFrameBonesLastUpdated); mFrameBonesLastUpdated = null;
                destroy(mSkeletonInstance); mSkeletonInstance = null;
                destroy(mBoneMatrices); mBoneMatrices = null;
                destroy(mAnimationState); mAnimationState = null;
            }
        }
        else if (hasVertexAnimation())
        {
            destroy(mAnimationState);
            //mAnimationState = 0;
        }
        
        destroy(mSkelAnimVertexData); //mSkelAnimVertexData = 0;
        destroy(mSoftwareVertexAnimVertexData); //mSoftwareVertexAnimVertexData = 0;
        destroy(mHardwareVertexAnimVertexData); //mHardwareVertexAnimVertexData = 0;
        
        mInitialised = false;
    }
    
    /** Resource.Listener hook to notify Entity that a delay-loaded Mesh is
     complete.
     */
    void backgroundLoadingComplete(ref Resource res)
    {
        if (res == mMesh.getAs())
        {
            // mesh loading has finished, we canruct ourselves now
            _initialise();
        }
    }
    
    /// @copydoc MovableObject.visitRenderables
    override void visitRenderables(Renderable.Visitor visitor, 
                                   bool debugRenderables = false)
    {
        // Visit each SubEntity
        foreach (i; mSubEntityList)
        {
            visitor.visit(i, 0, false, Any());
        }
        // if manual LOD is in use, visit those too
        ushort lodi = 1;
        foreach (e; mLodEntityList)
        {
            
            uint nsub = e.getNumSubEntities();
            for (uint s = 0; s < nsub; ++s)
            {
                visitor.visit(e.getSubEntity(s), lodi, false, Any());
            }
            lodi++;
        }
        
    }
    
    /** Get the lod strategy transformation of the mesh lod factor. */
    Real _getMeshLodFactorTransformed()
    {
        return mMeshLodFactorTransformed;
    }
    
    /** Entity's skeleton's AnimationState will not be automatically updated when set to true.
     Useful if you wish to handle AnimationState updates manually.
     */
    void setSkipAnimationStateUpdate(bool skip) {
        mSkipAnimStateUpdates = skip;
    }
    
    /** Entity's skeleton's AnimationState will not be automatically updated when set to true.
     Useful if you wish to handle AnimationState updates manually.
     */
    bool getSkipAnimationStateUpdate(){
        return mSkipAnimStateUpdates;
    }
    
    
    /** The skeleton of the main entity will be updated even if the an LOD entity is being displayed.
     useful if you have entities attached to the main entity. Otherwise position of attached
     entities will not be updated.
     */
    void setAlwaysUpdateMainSkeleton(bool update) {
        mAlwaysUpdateMainSkeleton = update;
    }
    
    /** The skeleton of the main entity will be updated even if the an LOD entity is being displayed.
     useful if you have entities attached to the main entity. Otherwise position of attached
     entities will not be updated.
     */
    bool getAlwaysUpdateMainSkeleton(){
        return mAlwaysUpdateMainSkeleton;
    }
    
    
}

/** Factory object for creating Entity instances */
class EntityFactory : MovableObjectFactory
{
protected:
    override MovableObject createInstanceImpl(string name, NameValuePairList params)
    {
        // must have mesh parameter
        SharedPtr!Mesh pMesh;
        if (!params.emptyAA)
        {
            string groupName = ResourceGroupManager.AUTODETECT_RESOURCE_GROUP_NAME;
            
            auto ni = "resourceGroup" in params;
            if (ni !is null)
            {
                groupName = *ni;
            }
            
            ni = "mesh" in params;
            if (ni !is null)
            {
                // Get mesh (load if required)
                pMesh = MeshManager.getSingleton().load(
                    *ni,
                    // autodetect group location
                    groupName );
            }
            
        }
        if (pMesh.isNull())
        {
            throw new InvalidParamsError(
                "'mesh' parameter required when constructing an Entity.",
                "EntityFactory.createInstance");
        }
        
        return new Entity(name, pMesh);
        
    }
public:
    this() {}
    ~this() {}
    
    immutable static string FACTORY_TYPE_NAME = "Entity";
    
    override string getType()
    {
        return FACTORY_TYPE_NAME;
    }
    
    override void destroyInstance( ref MovableObject obj)
    {
        destroy(obj);
    }
    
}

/** Utility class which defines the sub-parts of an Entity.
 @remarks
 Just as meshes are split into submeshes, an Entity is made up of
 potentially multiple SubMeshes. These are mainly here to provide the
 link between the Material which the SubEntity uses (which may be the
 default Material for the SubMesh or may have been changed for this
 object) and the SubMesh data.
 @par
 The SubEntity also allows the application some flexibility in the
 material properties for this section of a particular instance of this
 Mesh, e.g. tinting the windows on a car model.
 @par
 SubEntity instances are never created manually. They are created at
 the same time as their parent Entity by the SceneManager method
 createEntity.
 */
class SubEntity: RenderableClass //Renderable //, public SubEntityAlloc
{
    //mixin Renderable.Renderable_Impl!();
    //mixin Renderable.Renderable_Any_Impl;

    // Note no functions for efficiency
    //friend class Entity;
    //friend class SceneManager;
protected:
    /** Private constructor - don't allow creation by anybody else.
     */
    this(Entity parent, SubMesh subMeshBasis)
    {
        mParentEntity = parent;
        //mMaterialName = "BaseWhite";
        mSubMesh = subMeshBasis;
        //mCachedCamera = 0;
        
        //mMaterialPtr = MaterialManager.getSingleton().getByName(mMaterialName, subMeshBasis.parent.getGroup());
        mMaterialLodIndex = 0;
        mVisible = true;
        mRenderQueueIDSet = false;
        mRenderQueuePrioritySet = false;
        //mSkelAnimVertexData = 0;
        //mSoftwareVertexAnimVertexData = 0;
        //mHardwareVertexAnimVertexData = 0;
        mHardwarePoseCount = 0;
        
        mTempSkelAnimInfo = new TempBlendedBufferInfo;
        mTempVertexAnimInfo = new TempBlendedBufferInfo;
    }
    
    /** Private destructor.
     */
    ~this()
    {
        DestroyRenderable();
        if (mSkelAnimVertexData)
            destroy(mSkelAnimVertexData);
        if (mHardwareVertexAnimVertexData)
            destroy(mHardwareVertexAnimVertexData);
        if (mSoftwareVertexAnimVertexData)
            destroy(mSoftwareVertexAnimVertexData);
    }
    
    /// Pointer to parent.
    Entity mParentEntity;
    
    /// Name of Material in use by this SubEntity.
    string mMaterialName;
    
    /// Cached pointer to material.
    SharedPtr!Material mMaterialPtr;
    
    // Pointer to the SubMesh defining geometry.
    SubMesh mSubMesh;
    
    /// Is this SubEntity visible?
    bool mVisible;
    
    /// The render queue to use when rendering this renderable
    ubyte mRenderQueueID;
    /// Flags whether the RenderQueue's default should be used.
    bool mRenderQueueIDSet;
    /// The render queue priority to use when rendering this renderable
    ushort mRenderQueuePriority;
    /// Flags whether the RenderQueue's default should be used.
    bool mRenderQueuePrioritySet;
    
    /// The LOD number of the material to use, calculated by Entity._notifyCurrentCamera
    ushort mMaterialLodIndex;
    
    /// blend buffer details for dedicated geometry
    VertexData mSkelAnimVertexData;
    /// Quick lookup of buffers
    TempBlendedBufferInfo mTempSkelAnimInfo;
    /// Temp buffer details for software Vertex anim geometry
    TempBlendedBufferInfo mTempVertexAnimInfo;
    /// Vertex data details for software Vertex anim of shared geometry
    VertexData mSoftwareVertexAnimVertexData;
    /// Vertex data details for hardware Vertex anim of shared geometry
    /// - separate since we need to s/w anim for shadows whilst still altering
    ///   the vertex data for hardware morphing (pos2 binding)
    VertexData mHardwareVertexAnimVertexData;
    /// Have we applied any vertex animation to geometry?
    bool mVertexAnimationAppliedThisFrame;
    /// Number of hardware blended poses supported by material
    ushort mHardwarePoseCount;
    /// Cached distance to last camera for getSquaredViewDepth
    //mutable 
    Real mCachedCameraDist;
    /// The camera for which the cached distance is valid
    //mutable 
    Camera mCachedCamera;
    
    /** Internal method for preparing this Entity for use in animation. */
    void prepareTempBlendBuffers()
    {
        if (mSubMesh.useSharedVertices)
            return;
        
        if (mSkelAnimVertexData) 
        {
            destroy (mSkelAnimVertexData);
            //mSkelAnimVertexData = 0;
        }
        if (mSoftwareVertexAnimVertexData) 
        {
            destroy (mSoftwareVertexAnimVertexData);
            //mSoftwareVertexAnimVertexData = 0;
        }
        if (mHardwareVertexAnimVertexData) 
        {
            destroy (mHardwareVertexAnimVertexData);
            //mHardwareVertexAnimVertexData = 0;
        }
        
        if (!mSubMesh.useSharedVertices)
        {
            if (mSubMesh.getVertexAnimationType() != VertexAnimationType.VAT_NONE)
            {
                // Create temporary vertex blend info
                // Prepare temp vertex data if needed
                // Clone without copying data, don't remove any blending info
                // (since if we skeletally animate too, we need it)
                mSoftwareVertexAnimVertexData = mSubMesh.vertexData.clone(false);
                mParentEntity.extractTempBufferInfo(mSoftwareVertexAnimVertexData, mTempVertexAnimInfo);
                
                // Also clone for hardware usage, don't remove blend info since we'll
                // need it if we also hardware skeletally animate
                mHardwareVertexAnimVertexData = mSubMesh.vertexData.clone(false);
            }
            
            if (mParentEntity.hasSkeleton())
            {
                // Create temporary vertex blend info
                // Prepare temp vertex data if needed
                // Clone without copying data, remove blending info
                // (since blend is performed in software)
                mSkelAnimVertexData = 
                    mParentEntity.cloneVertexDataRemoveBlendInfo(mSubMesh.vertexData);
                mParentEntity.extractTempBufferInfo(mSkelAnimVertexData, mTempSkelAnimInfo);
                
            }
        }
    }
    
public:
    /** Gets the name of the Material in use by this instance.
     */
    string getMaterialName()
    {
        return !mMaterialPtr.isNull() ? mMaterialPtr.getName() : null;
        //return mMaterialName;
    }
    
    /** Sets the name of the Material to be used.
     @remarks
     By default a SubEntity uses the default Material that the SubMesh
     uses. This call can alter that so that the Material is different
     for this instance.
     */
    void setMaterialName(string name,string groupName = ResourceGroupManager.AUTODETECT_RESOURCE_GROUP_NAME )
    {
        
        
        SharedPtr!Material material = MaterialManager.getSingleton().getByName(name, groupName);
        
        if( material.isNull() )
        {
            LogManager.getSingleton().logMessage("Can't assign material " ~ name ~
                                                 " to SubEntity of " ~ mParentEntity.getName() ~ " because this " ~
                                                 "Material does not exist. Have you forgotten to define it in a " ~
                                                 ".material script?");
            
            material = MaterialManager.getSingleton().getByName("BaseWhite");
            
            if (material.isNull())
            {
                throw new InternalError("Can't assign default material " ~
                            "to SubEntity of " ~ mParentEntity.getName() ~ ". Did " ~
                            "you forget to call MaterialManager.initialise()?",
                            "SubEntity.setMaterialName");
            }
        }
        
        setMaterial( material );
    }
    
    /** Sets a Material to be used.
     @remarks
     By default a SubEntity uses the default Material that the SubMesh
     uses. This call can alter that so that the Material is different
     for this instance.
     */
    void setMaterial( SharedPtr!Material material )
    {
        mMaterialPtr = material;
        
        if (mMaterialPtr.isNull())
        {
            LogManager.getSingleton().logMessage("Can't assign material to SubEntity of " ~ mParentEntity.getName() ~ 
                                                 " because this Material does not exist. Have you forgotten to define it in a " ~
                                                 ".material script?");
            
            mMaterialPtr = MaterialManager.getSingleton().getByName("BaseWhite");
            
            if (mMaterialPtr.isNull())
            {
                throw new InternalError( "Can't assign default material "  ~
                                        "to SubEntity of " ~ mParentEntity.getName() ~ ". Did " ~
                                        "you forget to call MaterialManager.initialise()?",
                                        "SubEntity.setMaterial");
            }
        }
        
        // Ensure new material loaded (will not load again if already loaded)
        mMaterial.getAs().load();
        
        // tell parent to reconsider material vertex processing options
        mParentEntity.reevaluateVertexProcessing();
        
    }
    
    /** Tells this SubEntity whether to be visible or not. */
    void setVisible(bool visible)
    {
        mVisible = visible;
    }
    
    /** Returns whether or not this SubEntity is supposed to be visible. */
    bool isVisible()
    {
        return mVisible;
    }
    
    /** Sets the render queue group this subentity will be rendered through.
     @remarks
     Render queues are grouped to allow you to more tightly control the ordering
     of rendered objects. If you do not call this method, the SubEntity will use
     either the Entity's queue or it will use the default
     (RenderQueue.getDefaultQueueGroup).
     @par
     See Entity.setRenderQueueGroup for more details.
     @param queueID Enumerated value of the queue group to use. See the
     enum RenderQueueGroupID for what kind of values can be used here.
     */
    void setRenderQueueGroup(ubyte queueID)
    {
        mRenderQueueIDSet = true;
        mRenderQueueID = queueID;
    }
    
    /** Sets the render queue group and group priority this subentity will be rendered through.
     @remarks
     Render queues are grouped to allow you to more tightly control the ordering
     of rendered objects. Within a single render group there another type of grouping
     called priority which allows further control.  If you do not call this method, 
     all Entity objects default to the default queue and priority 
     (RenderQueue.getDefaultQueueGroup, RenderQueue.getDefaultRenderablePriority).
     @par
     See Entity.setRenderQueueGroupAndPriority for more details.
     @param queueID Enumerated value of the queue group to use. See the
     enum RenderQueueGroupID for what kind of values can be used here.
     @param priority The priority within a group to use.
     */
    void setRenderQueueGroupAndPriority(ubyte queueID, ushort priority)
    {
        setRenderQueueGroup(queueID);
        mRenderQueuePrioritySet = true;
        mRenderQueuePriority = priority;
    }
    
    /** Gets the queue group for this entity, see setRenderQueueGroup for full details. */
    ubyte getRenderQueueGroup()
    {
        return mRenderQueueID;
    }
    
    /** Gets the queue group for this entity, see setRenderQueueGroup for full details. */
    ushort getRenderQueuePriority()
    {
        return mRenderQueuePriority;
    }
    
    /** Gets the queue group for this entity, see setRenderQueueGroup for full details. */
    bool isRenderQueueGroupSet()
    {
        return mRenderQueueIDSet;
    }
    
    /** Gets the queue group for this entity, see setRenderQueueGroup for full details. */
    bool isRenderQueuePrioritySet()
    {
        return mRenderQueuePrioritySet;
    }
    
    /** Accessor method to read mesh data.
     */
    ref SubMesh getSubMesh()
    {
        return mSubMesh;
    }
    
    /** Accessor to get parent Entity */
    ref Entity getParent(){ return mParentEntity; }
    
    /** Overridden - see Renderable.
     */
    override SharedPtr!Material getMaterial()
    {
        return mMaterialPtr;
    }
    
    /** Overridden - see Renderable.
     */
    override Technique getTechnique()
    {
        return mMaterialPtr.getBestTechnique(mMaterialLodIndex, this);
    }
    
    /** Overridden - see Renderable.
     */
    override void getRenderOperation(ref RenderOperation op)
    {
        // Use LOD
        mSubMesh._getRenderOperation(op, mParentEntity.mMeshLodIndex);
        // Deal with any vertex data overrides
        op.vertexData = getVertexDataForBinding();
        
    }
    
    /** Overridden - see Renderable.
     */
    override void getWorldTransforms(ref Matrix4[] xform)
    {
        if (!mParentEntity.mNumBoneMatrices ||
            !mParentEntity.isHardwareAnimationEnabled())
        {
            // No skeletal animation, or software skinning
            xform.insertOrReplace(mParentEntity._getParentNodeFullTransform());
        }
        else
        {
            // Hardware skinning, pass all actually used matrices
            Mesh.IndexMap indexMap = mSubMesh.useSharedVertices ?
                mSubMesh.parent.sharedBlendIndexToBoneIndexMap : mSubMesh.blendIndexToBoneIndexMap;
            assert(indexMap.length <= mParentEntity.mNumBoneMatrices);
            
            if (mParentEntity._isSkeletonAnimated())
            {
                // Bones, use cached matrices built when Entity._updateRenderQueue was called
                assert(mParentEntity.mBoneWorldMatrices);
                //int i = 0;
                foreach (it; indexMap)
                {
                    xform ~= mParentEntity.mBoneWorldMatrices[it];
                    //i++;
                }
            }
            else
            {
                // All animations disabled, use parent entity world transform only
                //std.fill_n(xform, indexMap.length, mParentEntity._getParentNodeFullTransform());
                foreach (i; 0..indexMap.length)
                {
                    xform ~= mParentEntity._getParentNodeFullTransform();
                }
            }
        }
    }
    /** Overridden - see Renderable.
     */
    override ushort getNumWorldTransforms()
    {
        if (!mParentEntity.mNumBoneMatrices ||
            !mParentEntity.isHardwareAnimationEnabled())
        {
            // No skeletal animation, or software skinning
            return 1;
        }
        else
        {
            // Hardware skinning, pass all actually used matrices
            Mesh.IndexMap indexMap = mSubMesh.useSharedVertices ?
                mSubMesh.parent.sharedBlendIndexToBoneIndexMap : mSubMesh.blendIndexToBoneIndexMap;
            assert(indexMap.length <= mParentEntity.mNumBoneMatrices);
            
            return cast(ushort)(indexMap.length);
        }
    }
    
    /** Overridden, see Renderable */
    override Real getSquaredViewDepth(Camera cam)
    {
        // First of all, check the cached value
        // NB this is manually invalidated by parent each _notifyCurrentCamera call
        // Done this here rather than there since we only need this for transparent objects
        if (mCachedCamera == cam)
            return mCachedCameraDist;
        
        Node n = mParentEntity.getParentNode();
        assert(n);
        Real dist;
        if (!mSubMesh.extremityPoints.empty())
        {
            Vector3 cp = cam.getDerivedPosition();
            Matrix4 l2w = mParentEntity._getParentNodeFullTransform();
            dist = Real.infinity;
            foreach (i; mSubMesh.extremityPoints)
            {
                Vector3 v = l2w * i;
                Real d = (v - cp).squaredLength();
                
                dist = std.algorithm.min(d, dist);
            }
        }
        else
            dist = n.getSquaredViewDepth(cam);
        
        mCachedCameraDist = dist;
        mCachedCamera = cam;
        
        return dist;
    }
    
    /** @copydoc Renderable.getLights */
    override LightList getLights()
    {
        return mParentEntity.queryLights();
    }
    
    /** @copydoc Renderable.getCastsShadows */
    override bool getCastsShadows()
    {
        return mParentEntity.getCastShadows();
    }
    
    /** Advanced method to get the temporarily blended vertex information
     for entities which are software skinned. 
     @remarks
     Internal engine will eliminate software animation if possible, this
     information is unreliable unless added request for software animation
     via Entity.addSoftwareAnimationRequest.
     @note
     The positions/normals of the returned vertex data is in object space.
     */
    ref VertexData _getSkelAnimVertexData()
    {
        assert (mSkelAnimVertexData , "Not software skinned or has no dedicated geometry!");
        return mSkelAnimVertexData;
    }
    /** Advanced method to get the temporarily blended software morph vertex information
     @remarks
     Internal engine will eliminate software animation if possible, this
     information is unreliable unless added request for software animation
     via Entity.addSoftwareAnimationRequest.
     @note
     The positions/normals of the returned vertex data is in object space.
     */
    ref VertexData _getSoftwareVertexAnimVertexData()
    {
        assert (mSoftwareVertexAnimVertexData , "Not vertex animated or has no dedicated geometry!");
        return mSoftwareVertexAnimVertexData;
    }
    /** Advanced method to get the hardware morph vertex information
     @note
     The positions/normals of the returned vertex data is in object space.
     */
    ref VertexData _getHardwareVertexAnimVertexData()
    {
        assert (mHardwareVertexAnimVertexData , "Not vertex animated or has no dedicated geometry!");
        return mHardwareVertexAnimVertexData;
    }
    /** Advanced method to get the temp buffer information for software 
     skeletal animation.
     */
    TempBlendedBufferInfo _getSkelAnimTempBufferInfo()
    {
        return mTempSkelAnimInfo;
    }
    /** Advanced method to get the temp buffer information for software 
     morph animation.
     */
    TempBlendedBufferInfo _getVertexAnimTempBufferInfo()
    {
        return mTempVertexAnimInfo;
    }
    /// Retrieve the VertexData which should be used for GPU binding
    ref VertexData getVertexDataForBinding()
    {
        if (mSubMesh.useSharedVertices)
        {
            return mParentEntity.getVertexDataForBinding();
        }
        else
        {
            Entity.VertexDataBindChoice c = 
                mParentEntity.chooseVertexDataForBinding(
                    mSubMesh.getVertexAnimationType() != VertexAnimationType.VAT_NONE);
            switch(c)
            {
                case Entity.VertexDataBindChoice.BIND_ORIGINAL:
                    return mSubMesh.vertexData;
                case Entity.VertexDataBindChoice.BIND_HARDWARE_MORPH:
                    return mHardwareVertexAnimVertexData;
                case Entity.VertexDataBindChoice.BIND_SOFTWARE_MORPH:
                    return mSoftwareVertexAnimVertexData;
                case Entity.VertexDataBindChoice.BIND_SOFTWARE_SKELETAL:
                    return mSkelAnimVertexData;
                default:
                    break;
            }
            // keep compiler happy
            return mSubMesh.vertexData;
            
        }
    }
    
    /** Mark all vertex data as so far unanimated. 
     */
    void _markBuffersUnusedForAnimation()
    {
        mVertexAnimationAppliedThisFrame = false;
    }
    
    /** Mark all vertex data as animated. 
     */
    void _markBuffersUsedForAnimation()
    {
        mVertexAnimationAppliedThisFrame = true;
    }
    
    /** Are buffers already marked as vertex animated? */
    bool _getBuffersMarkedForAnimation(){ return mVertexAnimationAppliedThisFrame; }
    /** Internal method to copy original vertex data to the morph structures
     should there be no active animation in use.
     */
    void _restoreBuffersForUnusedAnimation(bool hardwareAnimation)
    {
        // Rebind original positions if:
        //  We didn't apply any animation and 
        //    We're morph animated (hardware binds keyframe, software is missing)
        //    or we're pose animated and software (hardware is fine, still bound)
        if (mSubMesh.getVertexAnimationType() != VertexAnimationType.VAT_NONE && 
            !mSubMesh.useSharedVertices && 
            !mVertexAnimationAppliedThisFrame &&
            (!hardwareAnimation || mSubMesh.getVertexAnimationType() == VertexAnimationType.VAT_MORPH))
        {
            // Note, VES_POSITION is specified here but if normals are included in animation
            // then these will be re-bound too (buffers must be shared)
            VertexElement srcPosElem = 
                mSubMesh.vertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
            SharedPtr!HardwareVertexBuffer srcBuf = 
                mSubMesh.vertexData.vertexBufferBinding.getBuffer(
                    srcPosElem.getSource());
            
            // Bind to software
            VertexElement destPosElem = 
                mSoftwareVertexAnimVertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
            mSoftwareVertexAnimVertexData.vertexBufferBinding.setBinding(
                destPosElem.getSource(), srcBuf);
            
        }
        
        // rebind any missing hardware pose buffers
        // Caused by not having any animations enabled, or keyframes which reference
        // no poses
        if (!mSubMesh.useSharedVertices && hardwareAnimation 
            && mSubMesh.getVertexAnimationType() == VertexAnimationType.VAT_POSE)
        {
            mParentEntity.bindMissingHardwarePoseBuffers(
                mSubMesh.vertexData, mHardwareVertexAnimVertexData);
        }
        
    }
    
    
    /** Overridden from Renderable to provide some custom behaviour. */
    override void _updateCustomGpuParameter(
        GpuProgramParameters.AutoConstantEntry constantEntry,
        GpuProgramParameters params)
    {
        if (constantEntry.paramType == GpuProgramParameters.AutoConstantType.ACT_ANIMATION_PARAMETRIC)
        {
            // Set up to 4 values, or up to limit of hardware animation entries
            // Pack into 4-elementants offset based on constant data index
            // If there are more than 4 entries, this will be called more than once
            auto val = Vector4(0.0f,0.0f,0.0f,0.0f);
            VertexData vd = mHardwareVertexAnimVertexData ? mHardwareVertexAnimVertexData : mParentEntity.mHardwareVertexAnimVertexData;
            
            size_t animIndex = constantEntry.data * 4;
            for (size_t i = 0; i < 4 && 
                 animIndex < vd.hwAnimationDataList.length;
                 ++i, ++animIndex)
            {
                val[i] = 
                    vd.hwAnimationDataList[animIndex].parametric;
            }
            // set the parametric morph value
            params._writeRawConstant(constantEntry.physicalIndex, val);
        }
        else
        {
            // TODO super would be Renderable, but it is now an interface
            // and Impl get overridden with this _updateCustomGpuParameter
            // HACK custom RenderableClass
            // default
            super._updateCustomGpuParameter(constantEntry, params);
        }
    }
    
    /** Invalidate the camera distance cache */
    void _invalidateCameraCache ()
    { mCachedCamera = null; }
}

/** @} */
/** @} */