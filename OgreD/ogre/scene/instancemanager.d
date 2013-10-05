module ogre.scene.instancemanager;

private
{
    //import std.container;
    import std.array;
}


import ogre.resources.mesh;
import ogre.exception;
import ogre.compat;
import ogre.rendersystem.hardware;
import ogre.scene.instancedentity;
import ogre.math.vector;
import ogre.materials.materialmanager;
import ogre.animation.animations;
import ogre.resources.meshmanager;
import ogre.rendersystem.renderoperation;
import ogre.scene.scenemanager;
import ogre.materials.material;
import ogre.scene.scenenode;
import ogre.rendersystem.vertex;
import ogre.general.common;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Scene
 *  @{
 */

/** This is the main starting point for the new instancing system.
 Each InstanceManager can control one technique and one mesh, but it can manage
 multiple materials at the same time.
 @see SceneManager.createInstanceManager, which creates this InstanceManager. Each one
 must have a unique name. It's wasteless to create two InstanceManagers with the same
 mesh reference, instancing technique and instances per batch count.
 This class takes care of managing batches automatically, so that more are created when
 needed, and reuse existing ones as much as posible; thus the user doesn't have to worry
 of managing all those low level issues.
 @see InstanceBatch & @see InstanceEntity for more information.

 @remarks
 Design discussion webpage: http://www.ogre3d.org/forums/viewtopic.php?f=4&t=59902
 @author
 Matias N. Goldberg ("dark_sylinc")
 @version
 1.0
 */
class InstanceManager //: public FactoryAlloc
{
public:
    enum InstancingTechnique
    {
        ShaderBased,            ///< Any SM 2.0+ @see InstanceBatchShader
        TextureVTF,             ///< Needs Vertex Texture Fetch & SM 3.0+ @see InstanceBatchVTF
        HWInstancingBasic,      ///< Needs SM 3.0+ and HW instancing support @see InstanceBatchHW
        HWInstancingVTF,        ///< Needs SM 3.0+, HW instancing support & VTF @see InstanceBatchHW_VTF
        InstancingTechniquesCount
    }
    
    /** Values to be used in setSetting() & BatchSettings.setting */
    enum BatchSettingId
    {
        /// Makes all batches from same material cast shadows
        CAST_SHADOWS        = 0,
        /// Makes each batch to display it's bounding box. Useful for debugging or profiling
        SHOW_BOUNDINGBOX,
        
        NUM_SETTINGS
    }
    
private:
    struct BatchSettings
    {
        //These are all per material
        bool[BatchSettingId.NUM_SETTINGS] setting = [true, false];

        //TODO ctor
        /*this()
         {
         setting[BatchSettingId.CAST_SHADOWS]     = true;
         setting[BatchSettingId.SHOW_BOUNDINGBOX] = false;
         }*/
    }
    
    //typedef vector<InstanceBatch*>.type        InstanceBatchVec;   //vec[batchN] = Batch
    //typedef map<String, InstanceBatchVec>.type InstanceBatchMap;   //map[materialName] = Vec
    alias InstanceBatch[]        InstanceBatchVec;   //vec[batchN] = Batch
    alias InstanceBatchVec[string]   InstanceBatchMap;   //map[materialName] = Vec
    //alias OrderedMap!(string, InstanceBatchVec*)   InstanceBatchMap;   //map[materialName] = Vec //TODO emulate map iterator
    
    //typedef map<String, BatchSettings>.type    BatchSettingsMap;
    alias BatchSettings[string]      BatchSettingsMap;
    //typedef map<uint32, uint32>::type IndicesMap;
    alias uint[uint] IndicesMap;

    string                  mName;                  //Not the name of the mesh
    SharedPtr!Mesh                 mMeshReference;
    InstanceBatchMap        mInstanceBatches;
    size_t                  mIdCount;
    
    InstanceBatchVec        mDirtyBatches;
    
    RenderOperation         mSharedRenderOperation;
    
    size_t                  mInstancesPerBatch;//FIXME size_t but instance batch classes take ushort :S
    InstancingTechnique     mInstancingTechnique;
    ushort                  mInstancingFlags;       ///< @see InstanceManagerFlags
    ushort                  mSubMeshIdx;
    
    BatchSettingsMap        mBatchSettings;
    SceneManager            mSceneManager;
    
    size_t                  mMaxLookupTableInstances;
    ubyte                   mNumCustomParams;       //Number of custom params per instance.
    
    /** Finds a batch with at least one free instanced entity we can use.
     If none found, creates one.
     */
    InstanceBatch getFreeBatch(string materialName )
    {
        InstanceBatchVec batchVec = mInstanceBatches[materialName];
        
        //InstanceBatchVec.const_reverse_iterator itor = batchVec.rbegin();

        foreach_reverse(itor; batchVec)
        {
            if( !itor.isBatchFull() )
                return itor;
        }
        
        //None found, or they're all full
        return buildNewBatch( materialName, false );
    }
    
    /** Called when batches are fully exhausted (can't return more instances) so a new batch
     is created.
     For the first time use, it can take big build time.
     It takes care of getting the render operation which will be shared by further batches,
     which decreases their build time, and prevents GPU RAM from skyrocketing.
     @param materialName The material name, to know where to put this batch in the map
     @param firstTime True if this is the first time it is called
     @return The created InstancedManager for convenience
     */
    InstanceBatch buildNewBatch(string materialName, bool firstTime )
    {
        //Get the bone to index map for the batches
        Mesh.IndexMap idxMap = mMeshReference.getAs().getSubMesh(mSubMeshIdx).blendIndexToBoneIndexMap;
        idxMap = idxMap.empty() ? mMeshReference.getAs().sharedBlendIndexToBoneIndexMap : idxMap;
        
        //Get the material
        SharedPtr!Material mat = MaterialManager.getSingleton().getByName( materialName,
                                                                                    mMeshReference.getAs().getGroup() );
        
        //Get the array of batches grouped by this material
        InstanceBatchVec materialInstanceBatch = mInstanceBatches[materialName];
        
        InstanceBatch batch = null;
        
        switch( mInstancingTechnique )
        {
            case InstancingTechnique.ShaderBased:
                batch = new InstanceBatchShader( this, mMeshReference, mat, cast(ushort)mInstancesPerBatch,
                                                idxMap, mName ~ "/InstanceBatch_" ~
                                                std.conv.to!string(mIdCount++) );
                break;
            case InstancingTechnique.TextureVTF:
                batch = new InstanceBatchVTF( this, mMeshReference, mat, mInstancesPerBatch,
                                             idxMap, mName ~ "/InstanceBatch_" ~
                                             std.conv.to!string(mIdCount++) );
                (cast(InstanceBatchVTF)batch).setBoneDualQuaternions((mInstancingFlags & InstanceManagerFlags.IM_USEBONEDUALQUATERNIONS) != 0);
                (cast(InstanceBatchVTF)batch).setUseOneWeight((mInstancingFlags & InstanceManagerFlags.IM_USEONEWEIGHT) != 0);
                (cast(InstanceBatchVTF)batch).setForceOneWeight((mInstancingFlags & InstanceManagerFlags.IM_FORCEONEWEIGHT) != 0);
                break;
            case InstancingTechnique.HWInstancingBasic:
                batch = new InstanceBatchHW( this, mMeshReference, mat, mInstancesPerBatch,
                                            idxMap, mName ~ "/InstanceBatch_" ~
                                            std.conv.to!string(mIdCount++) );
                break;
            case InstancingTechnique.HWInstancingVTF:
                batch = new InstanceBatchHW_VTF( this, mMeshReference, mat, mInstancesPerBatch,
                                                idxMap, mName ~ "/InstanceBatch_" ~
                                                std.conv.to!string(mIdCount++) );
                (cast(InstanceBatchHW_VTF)batch).setBoneMatrixLookup((mInstancingFlags & InstanceManagerFlags.IM_VTFBONEMATRIXLOOKUP) != 0, mMaxLookupTableInstances);
                (cast(InstanceBatchHW_VTF)batch).setBoneDualQuaternions((mInstancingFlags & InstanceManagerFlags.IM_USEBONEDUALQUATERNIONS) != 0);
                (cast(InstanceBatchHW_VTF)batch).setUseOneWeight((mInstancingFlags & InstanceManagerFlags.IM_USEONEWEIGHT) != 0);
                (cast(InstanceBatchHW_VTF)batch).setForceOneWeight((mInstancingFlags & InstanceManagerFlags.IM_FORCEONEWEIGHT) != 0);
                break;
            default:
                throw new NotImplementedError(
                    "Unimplemented instancing technique: " ~
                    std.conv.to!string(mInstancingTechnique),
                    "InstanceBatch.buildNewBatch()");
        }
        
        batch._notifyManager( mSceneManager );
        
        
        if( !firstTime )
        {
            //TODO: Check different materials have the same mInstancesPerBatch upper limit
            //otherwise we can't share
            batch.buildFrom( mMeshReference.getAs().getSubMesh(mSubMeshIdx), mSharedRenderOperation );
        }
        else
        {
            //Ensure we don't request more than we can
            size_t maxInstPerBatch = batch.calculateMaxNumInstances( mMeshReference.getAs().
                                                                    getSubMesh(mSubMeshIdx), mInstancingFlags );
            mInstancesPerBatch = std.algorithm.min( maxInstPerBatch, mInstancesPerBatch );
            batch._setInstancesPerBatch( mInstancesPerBatch );
            
            //TODO: Create a "merge" function that merges all submeshes into one big submesh
            //instead of just sending submesh #0
            
            //Get the RenderOperation to be shared with further instances.
            mSharedRenderOperation = batch.build( mMeshReference.getAs().getSubMesh(mSubMeshIdx) );
        }
        
        BatchSettings batchSettings = mBatchSettings[materialName];
        batch.setCastShadows( batchSettings.setting[BatchSettingId.CAST_SHADOWS] );
        
        //Batches need to be part of a scene node so that their renderable can be rendered
        SceneNode sceneNode = mSceneManager.getRootSceneNode().createChildSceneNode();
        sceneNode.attachObject( batch );
        sceneNode.showBoundingBox( batchSettings.setting[BatchSettingId.SHOW_BOUNDINGBOX] );
        
        materialInstanceBatch.insert( batch );
        
        return batch;
    }
    
    /** @see defragmentBatches overload, this takes care of an array of batches
     for a specific material */
    //FIXME Check the logics of the conversion from iterators to arrays
    void defragmentBatches( bool optimizeCull, ref InstancedEntity.InstancedEntityVec usedEntities,
                           ref InstanceBatch.CustomParamsVec usedParams,
                           ref InstanceBatchVec fragmentedBatches )
    {
        //InstanceBatchVec.iterator itor = fragmentedBatches.begin();
        size_t i = 0;
        for( ; i < fragmentedBatches.length && !usedEntities.empty(); i++ )
        {
            auto itor = fragmentedBatches[i];
            if( !itor.isStatic() )
                itor._defragmentBatch( optimizeCull, usedEntities, usedParams );
        }
        
        //InstanceBatchVec lastImportantBatch = itor;
        size_t lastImportantBatch = i;
        
        while( i < fragmentedBatches.length )
        {
            auto itor = fragmentedBatches[i];
            if( !itor.isStatic() )
            {
                //If we get here, this means we hit remaining batches which will be unused.
                //Destroy them
                //Call this to avoid freeing InstancedEntities that were just reparented
                itor._defragmentBatchDiscard();
                destroy(itor);
            }
            else
            {
                //This isn't a meaningless batch, move it forward so it doesn't get wipe
                //when we resize the container (faster than removing element by element)
                //*lastImportantBatch++ = *itor;
                fragmentedBatches[lastImportantBatch++] = fragmentedBatches[i];
            }
            
            ++i;
        }
        
        //Remove remaining batches all at once from the vector
        //size_t remainingBatches = fragmentedBatches.length - lastImportantBatch;
        //fragmentedBatches.resize( fragmentedBatches.size() - remainingBatches );
        fragmentedBatches.length = lastImportantBatch;
    }
    
    /** @see setSetting. This function helps it by setting the given parameter to all batches
     in container.
     */
    void applySettingToBatches( BatchSettingId id, bool value, ref InstanceBatchVec container )
    {
        //InstanceBatchVec.const_iterator itor = container.begin();
        //InstanceBatchVec.const_iterator end  = container.end();
        
        foreach(itor; container)
        {
            switch( id )
            {
                case BatchSettingId.CAST_SHADOWS:
                    itor.setCastShadows( value );
                    break;
                case BatchSettingId.SHOW_BOUNDINGBOX:
                    itor.getParentSceneNode().showBoundingBox( value );
                    break;
                default:
                    break;
            }
        }
    }
    
    /** Called when we you use a mesh which has shared vertices, the function creates separate
     vertex/index buffers and also recreates the bone assignments.
     */
    void unshareVertices(SharedPtr!Mesh mesh)
    {
        // Retrieve data to copy bone assignments
        Mesh.VertexBoneAssignmentList boneAssignments = mesh.getAs().getBoneAssignments();
        //Mesh.VertexBoneAssignmentList.const_iterator it = boneAssignments.begin();
        //Mesh.VertexBoneAssignmentList.const_iterator end = boneAssignments.end();
        size_t curVertexOffset = 0;
        
        // Access shared vertices
        VertexData sharedVertexData = mesh.getAs().sharedVertexData;
        
        for (uint subMeshIdx = 0; subMeshIdx < mesh.getAs().getNumSubMeshes(); subMeshIdx++)
        {
            SubMesh subMesh = mesh.getAs().getSubMesh(subMeshIdx);
            
            IndexData indexData = subMesh.indexData;
            HardwareIndexBuffer.IndexType idxType = indexData.indexBuffer.get().getType();
            IndicesMap indicesMap = (idxType == HardwareIndexBuffer.IndexType.IT_16BIT) ? getUsedIndices!ushort(indexData) :
            getUsedIndices!uint(indexData);
            
            
            VertexData newVertexData = new VertexData();
            newVertexData.vertexCount = indicesMap.lengthAA;
            newVertexData.vertexDeclaration = sharedVertexData.vertexDeclaration.clone();

            //TODO ushort vs size_t
            for (ushort bufIdx = 0; bufIdx < sharedVertexData.vertexBufferBinding.getBufferCount(); bufIdx++) 
            {
                SharedPtr!HardwareVertexBuffer sharedVertexBuffer = sharedVertexData.vertexBufferBinding.getBuffer(bufIdx);
                size_t vertexSize = sharedVertexBuffer.get().getVertexSize();                
                
                SharedPtr!HardwareVertexBuffer newVertexBuffer = HardwareBufferManager.getSingleton().createVertexBuffer
                    (vertexSize, newVertexData.vertexCount, sharedVertexBuffer.get().getUsage(), sharedVertexBuffer.get().hasShadowBuffer());
                
                ubyte *oldLock = cast(ubyte*)sharedVertexBuffer.get().lock(0, sharedVertexData.vertexCount * vertexSize, HardwareBuffer.LockOptions.HBL_READ_ONLY);
                ubyte *newLock = cast(ubyte*)newVertexBuffer.get().lock(0, newVertexData.vertexCount * vertexSize, HardwareBuffer.LockOptions.HBL_NORMAL);

                foreach(k,v; indicesMap)
                {
                    memcpy(newLock + vertexSize * v, oldLock + vertexSize * k, vertexSize);
                }
                
                sharedVertexBuffer.get().unlock();
                newVertexBuffer.get().unlock();
                
                newVertexData.vertexBufferBinding.setBinding(bufIdx, newVertexBuffer);
            }
            
            if (idxType == HardwareIndexBuffer.IndexType.IT_16BIT)
            {
                copyIndexBuffer!ushort(indexData, indicesMap);
            }
            else
            {
                copyIndexBuffer!uint(indexData, indicesMap);
            }
            
            // Store new attributes
            subMesh.useSharedVertices = false;
            subMesh.vertexData = newVertexData;
            
            // Transfer bone assignments to the submesh
            size_t offset = curVertexOffset + newVertexData.vertexCount;
            //TODO multimap
            foreach (first, boneAssignment; boneAssignments)
            {
                size_t vertexIdx = first;
                if (vertexIdx > offset)
                    break;
                
                //VertexBoneAssignment boneAssignment = second;
                foreach(i; 0..boneAssignments[first].length)
                {
                    boneAssignments[first][i].vertexIndex = cast(uint)(boneAssignments[first][i].vertexIndex - curVertexOffset);
                    subMesh.addBoneAssignment(boneAssignments[first][i]);
                }
            }
            curVertexOffset = newVertexData.vertexCount + 1;
        }
        
        // Release shared vertex data
        destroy(mesh.getAs().sharedVertexData);
        mesh.getAs().sharedVertexData = null;
        mesh.getAs().clearBoneAssignments();
    }
    
public:
    this(string customName, ref SceneManager sceneManager,
         string meshName,string groupName,
         InstancingTechnique instancingTechnique, ushort instancingFlags,
         size_t instancesPerBatch, ushort subMeshIdx, bool useBoneMatrixLookup = false)
    {
        mName =  customName ;
        mIdCount =  0 ;
        mInstancesPerBatch =  instancesPerBatch ;
        mInstancingTechnique =  instancingTechnique ;
        mInstancingFlags =  instancingFlags ;
        mSubMeshIdx =  subMeshIdx ;
        mSceneManager =  sceneManager ;
        mMaxLookupTableInstances = 16;
        mNumCustomParams =  0 ;

        mMeshReference = MeshManager.getSingleton().load( meshName, groupName );
        
        if(mMeshReference.getAs().sharedVertexData)
            unshareVertices(mMeshReference);
        
        if( mMeshReference.getAs().hasSkeleton() && !mMeshReference.getAs().getSkeleton().isNull() )
            mMeshReference.getAs().getSubMesh(mSubMeshIdx)._compileBoneAssignments();
    }

    ~this()
    {
        //Remove all batches from all materials we created
        //InstanceBatchMap::const_iterator itor = mInstanceBatches.begin();
        //InstanceBatchMap::const_iterator end  = mInstanceBatches.end();
        
        foreach(k,v; mInstanceBatches)//TODO iterator invalidation?
        {
            //InstanceBatchVec::const_iterator it = itor.second.begin();
            //InstanceBatchVec::const_iterator en = itor.second.end();
            
            foreach(it; v)
                destroy(v);
        }
    }
    
    string getName(){ return mName; }
    
    ref SceneManager getSceneManager(){ return mSceneManager; }
    
    /** Raises an exception if trying to change it after creating the first InstancedEntity
     @remarks The actual value may be less if the technique doesn't support having so much
     @see getMaxOrBestNumInstancesPerBatches for the usefulness of this function
     @param instancesPerBatch New instances per batch number
     */
    void setInstancesPerBatch( size_t instancesPerBatch )
    {
        if( !mInstanceBatches.emptyAA() )
        {
            throw new InvalidStateError("Instances per batch can only be changed before" ~
                                        " building the batch.", "InstanceManager.setInstancesPerBatch");
        }
        
        mInstancesPerBatch = instancesPerBatch;
    }
    
    /** Sets the size of the lookup table for techniques supporting bone lookup table.
     Raises an exception if trying to change it after creating the first InstancedEntity.
     Setting this value below the number of unique (non-sharing) entity instance animations
     will produce a crash during runtime. Setting this value above will increase memory
     consumption and reduce framerate.
     @remarks The value should be as close but not below the actual value. 
     @param maxLookupTableInstances New size of the lookup table
     */
    void setMaxLookupTableInstances( size_t maxLookupTableInstances )
    {
        if( !mInstanceBatches.emptyAA() )
        {
            throw new InvalidStateError("Instances per batch can only be changed before" ~
                                        " building the batch.", "InstanceManager.setMaxLookupTableInstances");
        }
        
        mMaxLookupTableInstances = maxLookupTableInstances;
    }
    
    /** Sets the number of custom parameters per instance. Some techniques (i.e. HWInstancingBasic)
     support this, but not all of them. They also may have limitations to the max number. All
     instancing implementations assume each instance param is a Vector4 (4 floats).
     @remarks
     This function cannot be called after the first batch has been created. Otherwise
     it will raise an exception. If the technique doesn't support custom params, it will
     raise an exception at the time of building the first InstanceBatch.

     HWInstancingBasic:
     * Each custom params adds an additional float4 TEXCOORD.
     HWInstancingVTF:
     * Not implemented. (Recommendation: Implement this as an additional float4 VTF fetch)
     TextureVTF:
     * Not implemented. (see HWInstancingVTF's recommendation)
     ShaderBased:
     * Not supported.
     @param Number of custom parameters each instance will have. Default: 0
     */
    void setNumCustomParams( ubyte numCustomParams )
    {
        if( !mInstanceBatches.emptyAA() )
        {
            throw new InvalidStateError("setNumCustomParams can only be changed before" ~
                                        " building the batch.", "InstanceManager.setNumCustomParams");
        }
        
        mNumCustomParams = numCustomParams;
    }
    
    ubyte getNumCustomParams(){ return mNumCustomParams; }
    
    /** @return Instancing technique this manager was created for. Can't be changed after creation */
    InstancingTechnique getInstancingTechnique()
    { return mInstancingTechnique; }
    
    /** Calculates the maximum (or the best amount, depending on flags) of instances
     per batch given the suggested size for the technique this manager was created for.
     @remarks
     This is done automatically when creating an instanced entity, but this function in conjunction
     with @see setInstancesPerBatch allows more flexible control over the amount of instances
     per batch
     @param materialName Name of the material to base on
     @param suggestedSize Suggested amount of instances per batch
     @param flags @see InstanceManagerFlags
     @return The max/best amount of instances per batch given the suggested size and flags
     */
    size_t getMaxOrBestNumInstancesPerBatch( string materialName, size_t suggestedSize, ushort flags )
    {
        //Get the material
        SharedPtr!Material mat = MaterialManager.getSingleton().getByName( materialName,
                                                                                    mMeshReference.getAs().getGroup() );
        InstanceBatch batch = null;
        
        //Base material couldn't be found
        if( mat.isNull() )
            return 0;
        
        switch( mInstancingTechnique )
        {
            case InstancingTechnique.ShaderBased:
                batch = new InstanceBatchShader( this, mMeshReference, mat, cast(ushort)suggestedSize,
                                                null, mName ~ "/TempBatch" );
                break;
            case InstancingTechnique.TextureVTF:
                batch = new InstanceBatchVTF( this, mMeshReference, mat, cast(ushort)suggestedSize,
                                             null, mName ~ "/TempBatch" );
                (cast(InstanceBatchVTF)batch).setBoneDualQuaternions((mInstancingFlags & InstanceManagerFlags.IM_USEBONEDUALQUATERNIONS) != 0);
                (cast(InstanceBatchVTF)batch).setUseOneWeight((mInstancingFlags & InstanceManagerFlags.IM_USEONEWEIGHT) != 0);
                (cast(InstanceBatchVTF)batch).setForceOneWeight((mInstancingFlags & InstanceManagerFlags.IM_FORCEONEWEIGHT) != 0);
                break;
            case InstancingTechnique.HWInstancingBasic:
                batch = new InstanceBatchHW( this, mMeshReference, mat, cast(ushort)suggestedSize,
                                            null, mName ~ "/TempBatch" );
                break;
            case InstancingTechnique.HWInstancingVTF:
                batch = new InstanceBatchHW_VTF( this, mMeshReference, mat, cast(ushort)suggestedSize,
                                                null, mName ~ "/TempBatch" );
                (cast(InstanceBatchHW_VTF)batch).setBoneMatrixLookup((mInstancingFlags & InstanceManagerFlags.IM_VTFBONEMATRIXLOOKUP) != 0, mMaxLookupTableInstances);
                (cast(InstanceBatchHW_VTF)batch).setBoneDualQuaternions((mInstancingFlags & InstanceManagerFlags.IM_USEBONEDUALQUATERNIONS) != 0);
                (cast(InstanceBatchHW_VTF)batch).setUseOneWeight((mInstancingFlags & InstanceManagerFlags.IM_USEONEWEIGHT) != 0);
                (cast(InstanceBatchHW_VTF)batch).setForceOneWeight((mInstancingFlags & InstanceManagerFlags.IM_FORCEONEWEIGHT) != 0);
                break;
            default:
                throw new NotImplementedError(
                    "Unimplemented instancing technique: " ~
                    std.conv.to!string(mInstancingTechnique),
                    "InstanceBatch.getMaxOrBestNumInstancesPerBatches()");
        }
        
        size_t retVal = batch.calculateMaxNumInstances( mMeshReference.getAs().getSubMesh(mSubMeshIdx),
                                                       flags );
        
        destroy(batch);
        
        return retVal;
    }

    /** @copydoc SceneManager.createInstancedEntity */
    InstancedEntity createInstancedEntity(string materialName )
    {
        InstanceBatch instanceBatch;
        
        if( mInstanceBatches.emptyAA() )
            instanceBatch = buildNewBatch( materialName, true );
        else
            instanceBatch = getFreeBatch( materialName );
        
        return instanceBatch.createInstancedEntity();
    }
    
    /** This function can be useful to improve CPU speed after having too many instances
     created, which where now removed, thus freeing many batches with zero used Instanced Entities
     However the batches aren't automatically removed from memory until the InstanceManager is
     destroyed, or this function is called. This function removes those batches which are completely
     unused (only wasting memory).
     */
    void cleanupEmptyBatches()
    {
        //Do this now to avoid any dangling pointer inside mDirtyBatches
        _updateDirtyBatches();
        
        //InstanceBatchMap::iterator itor = mInstanceBatches.begin();
        //InstanceBatchMap::iterator end  = mInstanceBatches.end();
        
        foreach(_, itor; mInstanceBatches)
        {
            //InstanceBatchVec::iterator it = itor.second.begin();
            //InstanceBatchVec::iterator en = itor.second.end();
            
            foreach(k, it; itor)
            {
                if( it.isBatchUnused() )
                {
                    destroy(it);
                    //TODO Uh,i don't think there's need for this now? Restore invalidated iterators
                    //OGRE_DELETE *it;
                    //Remove it from the list swapping with the last element and popping back
                    //size_t idx = it - itor.second.begin();
                    //*it = itor.second.back();
                    //itor.second.pop_back();
                    
                    //Restore invalidated iterators
                    //it = itor.second.begin() + idx;
                    //en = itor.second.end();
                }
            }
        }
        
        //By this point it may happen that all mInstanceBatches' objects are also empty
        //however if we call mInstanceBatches.clear(), next time we'll create an InstancedObject
        //we'll end up calling buildFirstTime() instead of buildNewBatch(), which is not the idea
        //(takes more time and will leak the shared render operation)
    }
    
    /** After creating many entities (which turns in many batches) and then removing entities that
     are in the middle of these batches, there might be many batches with many free entities.
     Worst case scenario, there could be left one batch per entity. Imagine there can be
     80 entities per batch, there are 80 batches, making a total of 6400 entities. Then
     6320 of those entities are removed in a very specific way, which leads to having
     80 batches, 80 entities, and GPU vertex shader still needs to process 6400!
     This is called fragmentation. This function reparents the InstancedEntities
     to fewer batches, in this case leaving only one batch with 80 entities

     @remarks
     This function takes time. Make sure to call this only when you're sure there's
     too much of fragmentation and you won't be creating more InstancedEntities soon
     Also in many cases cleanupEmptyBatches() ought to be enough
     Defragmentation is done per material
     Static batches won't be defragmented. If you want to degragment them, set them
     to dynamic again, and switch back to static after calling this function.

     @param optimizeCulling When true, entities close together will be reorganized
     in the same batch for more efficient CPU culling. This can take more CPU
     time. You want this to be false if you now you're entities are moving very
     randomly which tends them to get separated and spread all over the scene
     (which nullifies any CPU culling)
     */
    void defragmentBatches( bool optimizeCulling )
    {
        //Do this now to avoid any dangling pointer inside mDirtyBatches
        _updateDirtyBatches();
        
        //Do this for every material
        //InstanceBatchMap::iterator itor = mInstanceBatches.begin();
        //InstanceBatchMap::iterator end  = mInstanceBatches.end();
        
        foreach(_, itor; mInstanceBatches)
        {
            InstanceBatch.InstancedEntityVec   usedEntities;
            InstanceBatch.CustomParamsVec      usedParams;
            //TODO std::vector.reserve
            //usedEntities.reserve( itor.second.size() * mInstancesPerBatch );
            usedEntities.length = itor.length * mInstancesPerBatch;
            
            //Collect all Instanced Entities being used by _all_ batches from this material
            //InstanceBatchVec::iterator it = itor.second.begin();
            //InstanceBatchVec::iterator en = itor.second.end();
            
            foreach(k, it; itor)
            {
                //Don't collect instances from static batches, we assume they're correctly set
                //Plus, we don't want to put InstancedEntities from non-static into static batches
                if( !it.isStatic() )
                    it.getInstancedEntitiesInUse( usedEntities, usedParams );
            }
            
            defragmentBatches( optimizeCulling, usedEntities, usedParams, itor );
        }
    }
    
    /** Applies a setting for all batches using the same material_ existing ones and
     those that will be created in the future.
     @par
     For example setSetting( BatchSetting.CAST_SHADOWS, false ) disables shadow
     casting for all instanced entities (@see MovableObject.setCastShadow)
     @par
     For example setSetting( BatchSetting.SHOW_BOUNDINGBOX, true, "MyMat" )
     will display the bounding box of the batch (not individual InstancedEntities)
     from all batches using material "MyMat"
     @note If the material name hasn't been used, the settings are still stored
     This allows setting up batches before they get even created.
     @param id Setting Id to setup, @see BatchSettings.BatchSettingId
     @param enabled Boolean value. It's meaning depends on the id.
     @param materialName When Blank, the setting is applied to all existing materials
     */
    void setSetting( BatchSettingId id, bool enabled,string materialName = null )
    {
        assert( id < BatchSettingId.NUM_SETTINGS );
        
        if( materialName is null || materialName == "")
        {
            //Setup all existing materials
            //InstanceBatchMap::iterator itor = mInstanceBatches.begin();
            //InstanceBatchMap::iterator end  = mInstanceBatches.end();
            
            foreach(k, v; mInstanceBatches)
            {
                mBatchSettings[k].setting[id] = enabled;
                applySettingToBatches( id, enabled, v );
            }
        }
        else
        {
            //Setup a given material
            mBatchSettings[materialName].setting[id] = enabled;
            
            auto itor = materialName in mInstanceBatches;
            //Don't crash or throw if the batch with that material hasn't been created yet
            if( itor !is null )
                applySettingToBatches( id, enabled, *itor );
        }
    }
    
    /// If settings for the given material didn't exist, default value is returned
    bool getSetting( BatchSettingId id,string materialName )
    {
        assert( id < BatchSettingId.NUM_SETTINGS );
        
        auto itor = materialName in mBatchSettings;
        if( itor !is null )
            return itor.setting[id]; //Return current setting
        
        //Return default
        return BatchSettings().setting[id];
    }
    
    /** Returns true if settings were already created for the given material name.
     If false is returned, it means getSetting will return default settings.
     */
    bool hasSettings(string materialName )
    { return (materialName in mBatchSettings) !is null; }
    
    /** @copydoc InstanceBatch.setStaticAndUpdate */
    void setBatchesAsStaticAndUpdate( bool bStatic )
    {
        foreach(_,itor; mInstanceBatches)
        {
            foreach(k, it; itor)
            {
                it.setStaticAndUpdate( bStatic );
            }
        }
    }

    /** Called by an InstanceBatch when it requests their bounds to be updated for proper culling
     @param dirtyBatch The batch which is dirty, usually same as caller.
     */
    void _addDirtyBatch( InstanceBatch dirtyBatch )
    {
        if( mDirtyBatches.empty() )
            mSceneManager._addDirtyInstanceManager( this );
        
        mDirtyBatches.insert( dirtyBatch );
    }
    
    /** Called by SceneManager when we told it we have at least one dirty batch */
    void _updateDirtyBatches()
    {
        foreach(itor; mDirtyBatches)
        {
            itor._updateBounds();
        }
        
        mDirtyBatches.clear();
    }
    
    //typedef ConstMapIterator<InstanceBatchMap> InstanceBatchMapIterator;
    //typedef ConstVectorIterator<InstanceBatchVec> InstanceBatchIterator;
    
    /// Get non-updateable iterator over instance batches per material
    //InstanceBatchMapIterator getInstanceBatchMapIterator()
    //{ return InstanceBatchMapIterator( mInstanceBatches.begin(), mInstanceBatches.end() ); }

    InstanceBatchMap getInstanceBatchMap() { return mInstanceBatches; }

    /** Get non-updateable iterator over instance batches for given material
     @remarks
     Each InstanceBatch pointer may be modified for low level usage (i.e.
     setCustomParameter), but there's no synchronization mechanism when
     multithreading or creating more instances, that's up to the user.
     */
    //InstanceBatchIterator getInstanceBatchIterator(string materialName )
    //{
    //InstanceBatchMap.const_iterator it = mInstanceBatches.find( materialName );
    //    return InstanceBatchIterator( it.second.begin(), it.second.end() );
    //}

    InstanceBatch[] getInstanceBatch(string materialName )
    {
        auto it = materialName in mInstanceBatches;
        return *it;
    }

    IndicesMap getUsedIndices(T)(ref IndexData idxData)
    {
        T* data = cast(T*)idxData.indexBuffer.get().lock(idxData.indexStart * T.sizeof, 
                                                         idxData.indexCount * T.sizeof, HardwareBuffer.LockOptions.HBL_READ_ONLY);
        
        IndicesMap indicesMap;
        for (size_t i = 0; i < idxData.indexCount; i++) 
        {
            T index = data[i];
            if ((index in indicesMap) is null) 
            {
                indicesMap[index] = cast(uint)(indicesMap.lengthAA);
            }
        }
        
        idxData.indexBuffer.get().unlock();
        return indicesMap;
    }

    void copyIndexBuffer(T)(ref IndexData idxData, ref IndicesMap indicesMap)
    {
        T* data = cast(T*)idxData.indexBuffer.get().lock(idxData.indexStart * T.sizeof, 
                                                         idxData.indexCount * T.sizeof, HardwareBuffer.LockOptions.HBL_NORMAL);
        
        for (uint32 i = 0; i < idxData.indexCount; i++) 
        {
            data[i] = cast(T)indicesMap[data[i]];
        }
        
        idxData.indexBuffer.get().unlock();
    }
}

/*/** @} */
/*/** @} */