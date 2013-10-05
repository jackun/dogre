module ogre.resources.mesh;

import core.stdc.string: memcpy, memset;
//import std.container;
import std.string;
debug import std.stdio;

import ogre.animation.animations;
import ogre.math.axisalignedbox;
import ogre.compat;
import ogre.config;
import ogre.exception;
import ogre.lod.lodstrategy;
import ogre.resources.datastream;
import ogre.math.matrix;
import ogre.math.vector;
import ogre.math.edgedata;
import ogre.general.common;
import ogre.rendersystem.hardware;
import ogre.strings;
import ogre.resources.resource;
import ogre.rendersystem.vertex;
import ogre.resources.resourcegroupmanager;
import ogre.resources.meshserializer;
import ogre.resources.meshmanager;
import ogre.lod.lodstrategymanager;
import ogre.animation.skeletonmanager;
import ogre.math.tangentspacecalc;
import ogre.math.optimisedutil;
import ogre.materials.materialmanager;
import ogre.materials.material;
import ogre.resources.resourcemanager;
import ogre.rendersystem.renderoperation;
import ogre.math.maths;
import ogre.resources.meshfileformat;
import ogre.general.root;
import ogre.general.colourvalue;
import ogre.lod.distancelodstrategy;
import ogre.general.serializer;
import ogre.general.generals;
import ogre.general.log;
public import ogre.sharedptr;
import ogre.lod.pixelcountlodstrategy;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Resources
 *  @{
 */

//TODO dumping this here
/**
 * @brief Structure for automatic Lod configuration.
 */
struct LodLevel
{
    /**
     * @brief Type of the reduction.
     *
     * Note: The vertex count is determined by unique vertices per submesh.
     * A mesh may have duplicate vertices with same position.
     */
    alias uint VertexReductionMethod;
    enum : VertexReductionMethod
    {
        /**
         * @brief Percentage of vertexes to be removed from each submesh.
         *
         * Valid range is a number between 0.0 and 1.0
         */
        VRM_PROPORTIONAL,
        
        /**
         * @brief Exact vertex count to be removed from each submesh.
         *
         * Pass only integers or it will be rounded.
         */
        VRM_CONSTANT,
        
        /**
         * @brief Reduces the vertices, until the cost is bigger then the given value.
         *
         * Collapse cost is equal to the amount of artifact the reduction causes.
         * This generates the best Lod output, but the collapse cost depends on implementation.
         */
        VRM_COLLAPSE_COST
    }
    
    /**
     * @brief Distance to swap the Lod.
     *
     * This depends on LodStrategy.
     */
    Real distance;
    
    /**
     * @brief Reduction method to use.
     *
     * @see ProgressiveMeshGenerator::VertexReductionMethod
     */
    VertexReductionMethod reductionMethod;
    
    /**
     * @brief The value, which depends on reductionMethod.
     */
    Real reductionValue;
    
    /**
     * @brief This is set by ProgressiveMeshGenerator::build() function.
     *
     * Use Mesh::getNumLodLevels() for generated Lod count.
     */
    size_t outUniqueVertexCount;
    
    /**
     * @brief Whether the Lod level generation was skipped, because it has same vertex count as the previous Lod level.
     */
    bool outSkipped;
}

struct LodConfig
{
    MeshPtr mesh;
    LodStrategy strategy;
    //typedef vector<LodLevel>::type LodLevelList;
    alias LodLevel[] LodLevelList;
    LodLevelList levels;
}

/** Resource holding data about 3D mesh.
 @remarks
 This class holds the data used to represent a discrete
 3-dimensional object. Mesh data usually contains more
 than just vertices and triangle information; it also
 includes references to materials (and the faces which use them),
 level-of-detail reduction information, convex hull definition,
 skeleton/bones information, keyframe animation etc.
 However, it is important to note the emphasis on the word
 'discrete' here. This class does not cover the large-scale
 sprawling geometry found in level / landscape data.
 @par
 Multiple world objects can (indeed should) be created from a
 single mesh object - see the Entity class for more info.
 The mesh object will have it's own default
 material properties, but potentially each world instance may
 wish to customise the materials from the original. When the object
 is instantiated into a scene node, the mesh material properties
 will be taken by default but may be changed. These properties
 are actually held at the SubMesh level since a single mesh may
 have parts with different materials.
 @par
 As described above, because the mesh may have sections of differing
 material properties, a mesh is inherently a compoundruct,
 consisting of one or more SubMesh objects.
 However, it strongly 'owns' it's SubMeshes such that they
 are loaded / unloaded at the same time. This is contrary to
 the approach taken to hierarchically related (but loosely owned)
 scene nodes, where data is loaded / unloaded separately. Note
 also that mesh sub-sections (when used in an instantiated object)
 share the same scene node as the parent.
 */
class Mesh: Resource, AnimationContainer
{
    /*friend class SubMesh;
     friend class MeshSerializerImpl;
     friend class MeshSerializerImpl_v1_4;
     friend class MeshSerializerImpl_v1_2;
     friend class MeshSerializerImpl_v1_1;*/
    
public:
    /*typedef vector<Real>::type LodValueList;
     typedef vector<MeshLodUsage>::type MeshLodUsageList;
     /// Multimap of vertex bone assignments (orders by vertex index).
     typedef multimap<size_t, VertexBoneAssignment>::type VertexBoneAssignmentList;
     typedef MapIterator<VertexBoneAssignmentList> BoneAssignmentIterator;
     typedef vector<SubMesh*>::type SubMeshList;
     typedef vector<ushort>::type IndexMap;*/
    
    alias Real[] LodValueList;
    alias MeshLodUsage[] MeshLodUsageList;
    /// Multimap of vertex bone assignments (orders by vertex index).
    //alias SortedMap!(size_t, VertexBoneAssignment[]) VertexBoneAssignmentList;
    alias VertexBoneAssignment[][size_t] VertexBoneAssignmentList;
    //alias MultiMap!(size_t, VertexBoneAssignment) VertexBoneAssignmentList;
    alias SubMesh[] SubMeshList;
    alias ushort[] IndexMap;

    //typedef multimap<Real, Mesh::VertexBoneAssignmentList::iterator>::type WeightIteratorMap;
    //typedef multimap<Real, Mesh::VertexBoneAssignmentList::iterator>::type WeightIteratorMap;

    /*@property
    AxisAlignedBox _getAABB()
    {
        return mAABB;
    }

    @property
    Real _getBoundRadius()
    { return mBoundRadius; }

    
    @property
    bool _AutoBuildEdgeLists()
    { return mAutoBuildEdgeLists; }
    
    @property
    bool _AutoBuildEdgeLists(bool b)
    { return (mAutoBuildEdgeLists = b); }

    @property
    HardwareBuffer.Usage _IndexBufferUsage()
    { return mIndexBufferUsage; }

    @property
    bool _IndexBufferShadowBuffer()
    { return mIndexBufferShadowBuffer; }

    @property
    HardwareBuffer.Usage _VertexBufferUsage()
    { return mVertexBufferUsage; }
    
    @property
    bool _VertexBufferShadowBuffer()
    { return mVertexBufferShadowBuffer; }*/

protected:
    /** A list of submeshes which make up this mesh.
     Each mesh is made up of 1 or more submeshes, which
     are each based on a single material and can have their
     own vertex data (they may not - they can share vertex data
     from the Mesh, depending on preference).
     */
    SubMeshList mSubMeshList;
    
    /** Internal method for making the space for a vertex element to hold tangents. */
    void organiseTangentsBuffer(ref VertexData vertexData, 
                                VertexElementSemantic targetSemantic, ushort index, 
                                ushort sourceTexCoordSet)
    {
        VertexDeclaration vDecl = vertexData.vertexDeclaration ;
        VertexBufferBinding vBind = vertexData.vertexBufferBinding ;
        
        VertexElement tangentsElem = vDecl.findElementBySemantic(targetSemantic, index);
        bool needsToBeCreated = false;
        
        if (!tangentsElem)
        { // no tex coords with index 1
            needsToBeCreated = true ;
        }
        else if (tangentsElem.getType() != VertexElementType.VET_FLOAT3)
        {
            //  buffer exists, but not 3D
            throw new InvalidParamsError(
                "Target semantic set already exists but is not 3D, Therefore " ~
                "cannot contain tangents. Pick an alternative destination semantic. ",
                "Mesh.organiseTangentsBuffer");
        }
        
        SharedPtr!HardwareVertexBuffer newBuffer;
        if (needsToBeCreated)
        {
            // To be most efficient with our vertex streams,
            // tack the new tangents onto the same buffer as the
            // source texture coord set
            VertexElement prevTexCoordElem =
                vertexData.vertexDeclaration.findElementBySemantic(
                    VertexElementSemantic.VES_TEXTURE_COORDINATES, sourceTexCoordSet);
            if (!prevTexCoordElem)
            {
                throw new ItemNotFoundError(
                    "Cannot locate the first texture coordinate element to " ~
                    "which to append the new tangents.", 
                    "Mesh.organiseTangentsBuffer");
            }
            // Find the buffer associated with  this element
            SharedPtr!HardwareVertexBuffer origBuffer =
                vertexData.vertexBufferBinding.getBuffer(
                    prevTexCoordElem.getSource());
            // Now create a new buffer, which includes the previous contents
            // plus extra space for the 3D coords
            newBuffer = HardwareBufferManager.getSingleton().createVertexBuffer(
                origBuffer.get().getVertexSize() + 3*float.sizeof,
                vertexData.vertexCount,
                origBuffer.get().getUsage(),
                origBuffer.get().hasShadowBuffer() );
            // Add the new element
            vDecl.addElement(
                prevTexCoordElem.getSource(),
                origBuffer.get().getVertexSize(),
                VertexElementType.VET_FLOAT3,
                targetSemantic,
                index);
            // Now copy the original data across
            ubyte* pSrc = cast(ubyte*)(origBuffer.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
            ubyte* pDest = cast(ubyte*)(newBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
            size_t vertSize = origBuffer.get().getVertexSize();
            for (size_t v = 0; v < vertexData.vertexCount; ++v)
            {
                // Copy original vertex data
                memcpy(pDest, pSrc, vertSize);
                pSrc += vertSize;
                pDest += vertSize;
                // Set the new part to 0 since we'll accumulate in this
                memset(pDest, 0, float.sizeof*3);
                pDest += float.sizeof*3;
            }
            origBuffer.get().unlock();
            newBuffer.get().unlock();
            
            // Rebind the new buffer
            vBind.setBinding(prevTexCoordElem.getSource(), newBuffer);
        }
    }
    
public:
    /** A hashmap used to store optional SubMesh names.
     Translates a name into SubMesh index.
     */
    //typedef HashMap<string, ushort> SubMeshNameMap ;
    alias ushort[string] SubMeshNameMap ;

package:
    ///For friendlies
    @property
    SubMeshNameMap _getSubMeshNameMap()
    { return mSubMeshNameMap; }

    ///For friendlies
    @property
    VertexBoneAssignmentList _getBoneAssignments()
    { return mBoneAssignments; }
    
protected:
    
    DataStream mFreshFromDisk;
    
    SubMeshNameMap mSubMeshNameMap;
    
    /// Local bounding box volume.
    AxisAlignedBox mAABB;
    /// Local bounding sphere radius (centered on object).
    Real mBoundRadius;
    
    /// Optional linked skeleton.
    string mSkeletonName;
    SharedPtr!Skeleton mSkeleton;
    
    
    VertexBoneAssignmentList mBoneAssignments;
    
    /// Flag indicating that bone assignments need to be recompiled.
    bool mBoneAssignmentsOutOfDate;
    
    /** Build the index map between bone index and blend index. */
    void buildIndexMap(VertexBoneAssignmentList boneAssignments,
                       ref IndexMap boneIndexToBlendIndexMap, ref IndexMap blendIndexToBoneIndexMap)
    {
        if (boneAssignments.length == 0)
        {
            // Just in case
            boneIndexToBlendIndexMap.clear();
            blendIndexToBoneIndexMap.clear();
            return;
        }
        
        //typedef set<ushort>::type BoneIndexSet;
        //TODO Needs a set maybe
        ushort[] usedBoneIndices;
        
        // Collect actually used bones

        //TODO Not sure
        foreach (k,vl; boneAssignments)
        {
            foreach (v; vl)
                usedBoneIndices.insert(v.boneIndex);
        }

        //FIXME WTF moment below
        // Allocate space for index map
        blendIndexToBoneIndexMap.length = usedBoneIndices.length;
        //boneIndexToBlendIndexMap.resize(*usedBoneIndices.rbegin() + 1); //TODO What?
        std.algorithm.sort(usedBoneIndices);
        boneIndexToBlendIndexMap.length = usedBoneIndices[$-1] + 1;
        
        // Make index map between bone index and blend index

        ushort blendIndex = 0;
        foreach (itBoneIndex; usedBoneIndices)
        {
            boneIndexToBlendIndexMap[itBoneIndex] = blendIndex;
            blendIndexToBoneIndexMap[blendIndex] = itBoneIndex;
            ++blendIndex;
        }
    }
    
    /** Compile bone assignments into blend index and weight buffers. */
    void compileBoneAssignments(VertexBoneAssignmentList boneAssignments,
                                ushort numBlendWeightsPerVertex, 
                                ref IndexMap blendIndexToBoneIndexMap,
                                ref VertexData targetVertexData)
    {
        // Create or reuse blend weight / indexes buffer
        // Indices are always a UBYTE4 no matter how many weights per vertex
        // Weights are more specific though since they are Reals
        VertexDeclaration decl = targetVertexData.vertexDeclaration;
        VertexBufferBinding bind = targetVertexData.vertexBufferBinding;
        ushort bindIndex;
        
        // Build the index map brute-force. It's possible to store the index map
        // in .mesh, but maybe trivial.
        IndexMap boneIndexToBlendIndexMap;
        buildIndexMap(boneAssignments, boneIndexToBlendIndexMap, blendIndexToBoneIndexMap);
        
        auto testElem = decl.findElementBySemantic(VertexElementSemantic.VES_BLEND_INDICES);
        if (testElem)
        {
            // Already have a buffer, unset it & delete elements
            bindIndex = testElem.getSource();
            // unset will cause deletion of buffer
            bind.unsetBinding(bindIndex);
            decl.removeElement(VertexElementSemantic.VES_BLEND_INDICES);
            decl.removeElement(VertexElementSemantic.VES_BLEND_WEIGHTS);
        }
        else
        {
            // Get new binding
            bindIndex = bind.getNextIndex();
        }
        
        SharedPtr!HardwareVertexBuffer vbuf =
            HardwareBufferManager.getSingleton().createVertexBuffer(
                ubyte.sizeof*4 + float.sizeof*numBlendWeightsPerVertex,
                targetVertexData.vertexCount,
                HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY,
                true // use shadow buffer
                );
        // bind new buffer
        bind.setBinding(bindIndex, vbuf);
        VertexElement pIdxElem, pWeightElem;
        
        // add new vertex elements
        // Note, insert directly after all elements using the same source as
        // position to abide by pre-Dx9 format restrictions
        VertexElement firstElem = decl.getElement(0);
        if(firstElem.getSemantic() == VertexElementSemantic.VES_POSITION)
        {
            ushort insertPoint = 1;
            while (insertPoint < decl.getElementCount() &&
                   decl.getElement(insertPoint).getSource() == firstElem.getSource())
            {
                ++insertPoint;
            }
            VertexElement idxElem =
                decl.insertElement(insertPoint, 
                                   bindIndex, 0, 
                                   VertexElementType.VET_UBYTE4, 
                                   VertexElementSemantic.VES_BLEND_INDICES);
            VertexElement wtElem =
                decl.insertElement(cast(ushort)(insertPoint+1), 
                                   bindIndex, 
                                   ubyte.sizeof*4,
                                   VertexElement.multiplyTypeCount(VertexElementType.VET_FLOAT1, numBlendWeightsPerVertex),
                                   VertexElementSemantic.VES_BLEND_WEIGHTS);
            pIdxElem = idxElem;
            pWeightElem = wtElem;
        }
        else
        {
            // Position is not the first semantic, Therefore this declaration is
            // not pre-Dx9 compatible anyway, so just tack it on the end
            VertexElement idxElem =
                decl.addElement(bindIndex, 0, VertexElementType.VET_UBYTE4, VertexElementSemantic.VES_BLEND_INDICES);
            VertexElement wtElem =
                decl.addElement(bindIndex, ubyte.sizeof*4,
                                VertexElement.multiplyTypeCount(VertexElementType.VET_FLOAT1, numBlendWeightsPerVertex),
                                VertexElementSemantic.VES_BLEND_WEIGHTS);
            pIdxElem = idxElem;
            pWeightElem = wtElem;
        }

        ubyte *pBase = cast(ubyte*)(vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));

        // Assign data
        size_t v, i, iend;
        // Iterate by vertex
        float *pWeight;
        ubyte *pIndex;
        for (v = 0; v < targetVertexData.vertexCount; ++v)
        {
            iend = boneAssignments[v].length;
            i = 0;

            /// Convert to specific pointers
            pWeightElem.baseVertexPointerToElement(pBase, &pWeight);
            pIdxElem.baseVertexPointerToElement(pBase, &pIndex);
            for (ushort bone = 0; bone < numBlendWeightsPerVertex; ++bone)
            {
                // Do we still have data for this vertex?
                if (i < iend && boneAssignments[v][i].vertexIndex == v)
                {
                    VertexBoneAssignment ass = boneAssignments[v][i];
                    // If so, write weight
                    *pWeight++ = ass.weight;
                    *pIndex++ = cast(ubyte)(boneIndexToBlendIndexMap[ass.boneIndex]);
                    ++i;
                }
                else
                {
                    // Ran out of assignments for this vertex, use weight 0 to indicate empty.
                    // If no bones are defined (an error in itself) set bone 0 as the assigned bone. 
                    *pWeight++ = (bone == 0) ? 1.0f : 0.0f;
                    *pIndex++ = 0;
                }
            }
            pBase += vbuf.get().getVertexSize();
        }
        
        vbuf.get().unlock();
        
    }
    
    LodStrategy mLodStrategy;
    bool mIsLodManual;
    ushort mNumLods;
    MeshLodUsageList mMeshLodUsageList;
    
    HardwareBuffer.Usage mVertexBufferUsage;
    HardwareBuffer.Usage mIndexBufferUsage;
    bool mVertexBufferShadowBuffer;
    bool mIndexBufferShadowBuffer;
    
    
    bool mPreparedForShadowVolumes;
    bool mEdgeListsBuilt;
    bool mAutoBuildEdgeLists;
    
    /// Storage of morph animations, lookup by name
    //typedef map<string, Animation*>::type AnimationList;
    alias Animation[string] AnimationList;
    AnimationList mAnimationsList;
    /// The vertex animation type associated with the shared vertex data
    //mutable 
    VertexAnimationType mSharedVertexDataAnimationType;
    /// Whether vertex animation includes normals
    //mutable 
    bool mSharedVertexDataAnimationIncludesNormals;
    /// Do we need to scan animations for animation types?
    //mutable 
    bool mAnimationTypesDirty;
    
    /// List of available poses for shared and dedicated geometryPoseList
    PoseList mPoseList;
    //mutable 
    bool mPosesIncludeNormals;
    
    
    /** Loads the mesh from disk.  This call only performs IO, it
     does not parse the bytestream or check for any errors therein.
     It also does not set up submeshes, etc.  You have to call load()
     to do that.
     */
    override void prepareImpl()
    {
        // Load from specified 'name'
        if (getCreator().getVerbose())
            LogManager.getSingleton().logMessage("Mesh: Loading " ~ mName ~ ".");
        
        mFreshFromDisk =
            ResourceGroupManager.getSingleton().openResource(
                mName, mGroup, true, this);
        
        // fully prebuffer into host RAM
        mFreshFromDisk = new MemoryDataStream(mName,mFreshFromDisk);
    }
    
    /** Destroys data cached by prepareImpl.
     */
    override void unprepareImpl()
    {
        mFreshFromDisk = null; //.setNull();
    }
    
    /// @copydoc Resource.loadImpl
    override void loadImpl()
    {
        auto serializer = new MeshSerializer;
        serializer.setListener(MeshManager.getSingleton().getListener());
        
        // If the only copy is local on the stack, it will be cleaned
        // up reliably in case of exceptions, etc
        // -- Letting GC do that --
        //DataStreamPtr data(mFreshFromDisk);
        //mFreshFromDisk.setNull();

        
        if (mFreshFromDisk is null/*.isNull()*/) {
            throw new InvalidStateError(
                "Data doesn't appear to have been prepared in " ~ mName,
                "Mesh.loadImpl()");
        }
        
        serializer.importMesh(mFreshFromDisk, this);
        
        /* check all submeshes to see if their materials should be
         updated.  If the submesh has texture aliases that match those
         found in the current material then a new material is created using
         the textures from the submesh.
         */
        updateMaterialForAllSubMeshes();
    }
    
    /// @copydoc Resource.postLoadImpl
    override void postLoadImpl()
    {
        // Prepare for shadow volumes?
        if (MeshManager.getSingleton().getPrepareAllMeshesForShadowVolumes())
        {
            if (mEdgeListsBuilt || mAutoBuildEdgeLists)
            {
                prepareForShadowVolume();
            }
            
            if (!mEdgeListsBuilt && mAutoBuildEdgeLists)
            {
                buildEdgeList();
            }
        }
        
        // The loading process accesses lod usages directly, so
        // transformation of user values must occur after loading is complete.
        
        // Transform user lod values (starting at index 1, no need to transform base value)
        foreach (i; mMeshLodUsageList)
            i.value = mLodStrategy.transformUserValue(i.userValue);
    }
    
    /// @copydoc Resource.unloadImpl
    override void unloadImpl()
    {
        // Teardown submeshes
        foreach (i; mSubMeshList)
        {
            destroy(i);
        }
        if (sharedVertexData)
        {
            destroy(sharedVertexData);
            sharedVertexData = null;
        }
        // Clear SubMesh lists
        mSubMeshList.clear();
        mSubMeshNameMap.clear();
        // Removes all LOD data
        removeLodLevels();
        mPreparedForShadowVolumes = false;
        
        // remove all poses & animations
        removeAllAnimations();
        removeAllPoses();
        
        // Clear bone assignments
        mBoneAssignments.clear();
        mBoneAssignmentsOutOfDate = false;
        
        // Removes reference to skeleton
        setSkeletonName("");
    }
    /// @copydoc Resource.calculateSize
    override size_t calculateSize()
    {
        // calculate GPU size
        size_t ret = 0;
        ushort i;
        // Shared vertices
        if (sharedVertexData)
        {
            for (i = 0;
                 i < sharedVertexData.vertexBufferBinding.getBufferCount();
                 ++i)
            {
                ret += sharedVertexData.vertexBufferBinding
                    .getBuffer(i).get().getSizeInBytes();
            }
        }
        
        
        foreach (si; mSubMeshList)
        {
            // Dedicated vertices
            if (!si.useSharedVertices)
            {
                for (i = 0;
                     i < si.vertexData.vertexBufferBinding.getBufferCount();
                     ++i)
                {
                    ret += si.vertexData.vertexBufferBinding
                        .getBuffer(i).get().getSizeInBytes();
                }
            }
            if (!si.indexData.indexBuffer.isNull())
            {
                // Index data
                ret += si.indexData.indexBuffer.get().getSizeInBytes();
            }
            
        }
        return ret;
    }
    
    void mergeAdjacentTexcoords( ushort finalTexCoordSet,
                                ushort texCoordSetToDestroy, ref VertexData vertexData )
    {
        VertexDeclaration vDecl    = vertexData.vertexDeclaration;
        
        VertexElement uv0 = vDecl.findElementBySemantic( VertexElementSemantic.VES_TEXTURE_COORDINATES,
                                                        finalTexCoordSet );
        VertexElement uv1 = vDecl.findElementBySemantic( VertexElementSemantic.VES_TEXTURE_COORDINATES,
                                                        texCoordSetToDestroy );
        
        if( uv0 && uv1 )
        {
            //Check that both base types are compatible (mix floats w/ shorts) and there's enough space
            VertexElementType baseType0 = VertexElement.getBaseType( uv0.getType() );
            VertexElementType baseType1 = VertexElement.getBaseType( uv1.getType() );
            
            ushort totalTypeCount = cast(ushort)(VertexElement.getTypeCount( uv0.getType() ) +
                VertexElement.getTypeCount( uv1.getType() ));
            if( baseType0 == baseType1 && totalTypeCount <= 4 )
            {
                VertexDeclaration.VertexElementList veList = vDecl.getElements();
                //auto uv0Itor = std.find( veList.begin(), veList.end(), *uv0 );
                ushort elem_idx     = cast(ushort)std.algorithm.countUntil(veList, uv0); //std.distance( veList.begin(), uv0Itor );
                VertexElementType newType = VertexElement.multiplyTypeCount( baseType0,
                                                                            totalTypeCount );
                
                if( ( uv0.getOffset() + uv0.getSize() == uv1.getOffset() ||
                     uv1.getOffset() + uv1.getSize() == uv0.getOffset() ) &&
                   uv0.getSource() == uv1.getSource() )
                {
                    //Special case where they adjacent, just change the declaration & we're done.
                    size_t newOffset = std.algorithm.min( uv0.getOffset(), uv1.getOffset() );
                    ushort newIdx    = std.algorithm.min( uv0.getIndex(), uv1.getIndex() );
                    
                    vDecl.modifyElement( elem_idx, uv0.getSource(), newOffset, newType,
                                        VertexElementSemantic.VES_TEXTURE_COORDINATES, newIdx );
                    vDecl.removeElement( VertexElementSemantic.VES_TEXTURE_COORDINATES, texCoordSetToDestroy );
                    uv1 = null;
                }
                
                vDecl.closeGapsInSource();
            }
        }
    }
    
public:
    /** Default constructor - used by MeshManager
     @warning
     Do not call this method directly.
     */
    this(ResourceManager creator, string name, ResourceHandle handle,
         string group, bool isManual = false, ManualResourceLoader loader = null)
    {
        super(creator, name, handle, group, isManual, loader);
        mBoundRadius = 0.0f;
        mBoneAssignmentsOutOfDate = false;
        mIsLodManual = false;
        mNumLods = 1;
        mVertexBufferUsage = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY;
        mIndexBufferUsage = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY;
        mVertexBufferShadowBuffer = true;
        mIndexBufferShadowBuffer = true;
        mPreparedForShadowVolumes = false;
        mEdgeListsBuilt = false;
        mAutoBuildEdgeLists = true; // will be set to false by serializers of 1.30 and above
        mSharedVertexDataAnimationType = VertexAnimationType.VAT_NONE;
        mSharedVertexDataAnimationIncludesNormals = false;
        mAnimationTypesDirty = true;
        mPosesIncludeNormals = false;
        //sharedVertexData = null;
        
        // Initialise to default strategy
        mLodStrategy = LodStrategyManager.getSingleton().getDefaultStrategy();
        
        // Init first (manual) lod
        MeshLodUsage lod;
        lod.userValue = 0; // User value not used for base lod level
        lod.value = mLodStrategy.getBaseValue();
        lod.edgeData = null;
        //lod.manualMesh = SharedPtr!Mesh(); //TODO SharedPtr!Mesh() or null and !is null checks?
        lod.manualMesh.setNull();
        mMeshLodUsageList.insert(lod);
        
    }
    
    ~this()
    {
        // c++
        // have to call this here rather than in Resource destructor
        // since calling methods in base destructors causes crash
        unload();
    }
    
    // NB All methods below are non-virtual since they will be
    // called in the rendering loop - speed is of the essence.
    
    /** Creates a new SubMesh.
     @remarks
     Method for manually creating geometry for the mesh.
     Note - use with extreme caution - you must be sure that
     you have set up the geometry properly.
     */
    SubMesh createSubMesh()
    {
        SubMesh sub = new SubMesh();
        sub.parent = this;
        
        mSubMeshList.insert(sub);
        
        if (isLoaded())
            _dirtyState();
        
        return sub;
    }
    
    /** Creates a new SubMesh and gives it a name
     */
    SubMesh createSubMesh(string name)
    {
        SubMesh sub = createSubMesh();
        nameSubMesh(name, cast(ushort)(mSubMeshList.length-1));
        return sub;
    }
    
    /** Gives a name to a SubMesh
     */
    void nameSubMesh(string name, ushort index)
    {
        mSubMeshNameMap[name] = index ;
    }
    
    /** Removes a name from a SubMesh
     */
    void unnameSubMesh(string name)
    {
        auto i = name in mSubMeshNameMap;
        if (i !is null)
            mSubMeshNameMap.remove(name);
    }
    
    /** Gets the index of a submesh with a given name.
     @remarks
     Useful if you identify the SubMeshes by name (using nameSubMesh)
     but wish to have faster repeat access.
     */
    ushort _getSubMeshIndex(string name)
    {
        auto i = name in mSubMeshNameMap;
        if (i is null)
            throw new ItemNotFoundError( "No SubMesh named " ~ name ~ " found.",
                                        "Mesh._getSubMeshIndex");
        
        return *i;
    }
    
    /** Gets the number of sub meshes which comprise this mesh.
     */
    ushort getNumSubMeshes()
    {
        return cast(ushort)( mSubMeshList.length );
    }
    
    /** Gets a pointer to the submesh indicated by the index.
     */
    ref SubMesh getSubMesh(uint index)
    {
        if (index >= mSubMeshList.length)
        {
            throw new InvalidParamsError(
                "Index out of bounds.",
                "Mesh.getSubMesh");
        }
        
        return mSubMeshList[index];
    }
    
    /** Gets a SubMesh by name
     */
    ref SubMesh getSubMesh(string name)
    {
        ushort index = _getSubMeshIndex(name);
        return getSubMesh(index);
    }
    
    /** Destroy a SubMesh with the given index. 
     @note
     This will invalidate the contents of any existing Entity, or
     any other object that is ref erring to the SubMesh list. Entity will
     detect this and reinitialise, but it is still a disruptive action.
     */
    void destroySubMesh(ushort index)
    {
        if (index >= mSubMeshList.length)
        {
            throw new InvalidParamsError(
                "Index out of bounds.",
                "Mesh.removeSubMesh");
        }
        //SubMeshList.iterator i = mSubMeshList.begin();
        //std.advance(i, index);
        mSubMeshList.removeFromArrayIdx(index);
        
        // Fix up any name/index entries
        foreach(k; mSubMeshNameMap.keys)
        {
            auto v = mSubMeshNameMap[k];
            if (v == index)
            {
                mSubMeshNameMap.remove(k);
            }
            else
            {
                // reduce indexes following
                if (v > index)
                    mSubMeshNameMap[k] = cast(ushort)(v - 1);
            }
        }
        
        // fix edge list data by simply recreating all edge lists
        if( mEdgeListsBuilt)
        {
            this.freeEdgeList();
            this.buildEdgeList();
        }
        
        if (isLoaded())
            _dirtyState();
        
    }
    
    /** Destroy a SubMesh with the given name. 
     @note
     This will invalidate the contents of any existing Entity, or
     any other object that is ref erring to the SubMesh list. Entity will
     detect this and reinitialise, but it is still a disruptive action.
     */
    void destroySubMesh(string name)
    {
        ushort index = _getSubMeshIndex(name);
        destroySubMesh(index);
    }
    
    //typedef VectorIterator<SubMeshList> SubMeshIterator;
    /// Gets an iterator over the available submeshes
    //SubMeshIterator getSubMeshIterator()
    //{ return SubMeshIterator(mSubMeshList.begin(), mSubMeshList.end()); }
    
    /** Shared vertex data.
     @remarks
     This vertex data can be shared among multiple submeshes. SubMeshes may not have
     their own VertexData, they may share this one.
     @par
     The use of shared or non-shared buffers is determined when
     model data is converted to the OGRE .mesh format.
     */
    VertexData sharedVertexData;
    
    /** Shared index map for translating blend index to bone index.
     @remarks
     This index map can be shared among multiple submeshes. SubMeshes might not have
     their own IndexMap, they might share this one.
     @par
     We collect actually used bones of all bone assignments, and build the
     blend index in 'packed' form, then the range of the blend index in vertex
     data VES_BLEND_INDICES element is continuous, with no gaps. Thus, by
     minimising the world matrix array constants passing to GPU, we can support
     more bones for a mesh when hardware skinning is used. The hardware skinning
     support limit is applied to each set of vertex data in the mesh, in other words, the
     hardware skinning support limit is applied only to the actually used bones of each
     SubMeshes, not all bones across the entire Mesh.
     @par
     Because the blend index is different to the bone index, Therefore, we use
     the index map to translate the blend index to bone index.
     @par
     The use of shared or non-shared index map is determined when
     model data is converted to the OGRE .mesh format.
     */
    IndexMap sharedBlendIndexToBoneIndexMap;
    
    /** Makes a copy of this mesh object and gives it a new name.
     @remarks
     This is useful if you want to tweak an existing mesh without affecting the original one. The
     newly cloned mesh is registered with the MeshManager under the new name.
     @param newName
     The name to give the clone.
     @param newGroup
     Optional name of the new group to assign the clone to;
     if you leave this blank, the clone will be assigned to the same
     group as this Mesh.
     */
    SharedPtr!Mesh clone(string newName, string newGroup = "")
    {
        // This is a bit like a copy constructor, but with the additional aspect of registering the clone with
        //  the MeshManager
        
        // New Mesh is assumed to be manually defined rather than loaded since you're cloning it for a reason
        string theGroup;
        if (newGroup == "")
        {
            theGroup = this.getGroup();
        }
        else
        {
            theGroup = newGroup;
        }
        SharedPtr!Mesh newMesh = MeshManager.getSingleton().createManual(newName, theGroup);
        
        // Copy submeshes first
        //vector<SubMesh*>::type.iterator subi;
        SubMesh newSub;
        foreach (subi; mSubMeshList)
        {
            newSub = newMesh.getAs().createSubMesh();
            newSub.mMaterialName = subi.mMaterialName;
            newSub.mMatInitialised = subi.mMatInitialised;
            newSub.operationType = subi.operationType;
            newSub.useSharedVertices = subi.useSharedVertices;
            newSub.extremityPoints = subi.extremityPoints;
            
            if (!subi.useSharedVertices)
            {
                // Copy unique vertex data
                newSub.vertexData = subi.vertexData.clone();
                // Copy unique index map
                newSub.blendIndexToBoneIndexMap = subi.blendIndexToBoneIndexMap;
            }
            
            // Copy index data
            destroy( newSub.indexData );
            newSub.indexData = subi.indexData.clone();
            // Copy any bone assignments
            newSub.mBoneAssignments = subi.mBoneAssignments;
            newSub.mBoneAssignmentsOutOfDate = subi.mBoneAssignmentsOutOfDate;
            // Copy texture aliases
            newSub.mTextureAliases = subi.mTextureAliases;
            
            // Copy lod face lists
            newSub.mLodFaceList.length = (subi.mLodFaceList.length);
            //SubMesh.LODFaceList.const_iterator facei;
            foreach (facei; subi.mLodFaceList) {
                IndexData newIndexData = facei.clone();
                newSub.mLodFaceList.insert(newIndexData);
            }
        }
        
        // Copy shared geometry and index map, if any
        if (sharedVertexData)
        {
            newMesh.getAs().sharedVertexData = sharedVertexData.clone();
            newMesh.getAs().sharedBlendIndexToBoneIndexMap = sharedBlendIndexToBoneIndexMap;
        }
        
        // Copy submesh names
        newMesh.getAs().mSubMeshNameMap = mSubMeshNameMap ;
        // Copy any bone assignments
        newMesh.getAs().mBoneAssignments = mBoneAssignments;
        newMesh.getAs().mBoneAssignmentsOutOfDate = mBoneAssignmentsOutOfDate;
        // Copy bounds
        newMesh.getAs().mAABB = mAABB;
        newMesh.getAs().mBoundRadius = mBoundRadius;
        
        newMesh.getAs().mLodStrategy = mLodStrategy;
        newMesh.getAs().mIsLodManual = mIsLodManual;
        newMesh.getAs().mNumLods = mNumLods;
        newMesh.getAs().mMeshLodUsageList = mMeshLodUsageList;
        newMesh.getAs().mAutoBuildEdgeLists = mAutoBuildEdgeLists;
        // Unreference edge lists, otherwise we'll delete the same lot twice, build on demand

        foreach (ref lod; newMesh.getAs().mMeshLodUsageList) {
            lod.edgeData = null;
            // TODO: Copy manual lod meshes
        }
        
        newMesh.getAs().mVertexBufferUsage = mVertexBufferUsage;
        newMesh.getAs().mIndexBufferUsage = mIndexBufferUsage;
        newMesh.getAs().mVertexBufferShadowBuffer = mVertexBufferShadowBuffer;
        newMesh.getAs().mIndexBufferShadowBuffer = mIndexBufferShadowBuffer;
        
        newMesh.getAs().mSkeletonName = mSkeletonName;
        newMesh.getAs().mSkeleton = mSkeleton;
        
        // Keep prepared shadow volume info (buffers may already be prepared)
        newMesh.getAs().mPreparedForShadowVolumes = mPreparedForShadowVolumes;
        
        // mEdgeListsBuilt and edgeData of mMeshLodUsageList
        // will up to date on demand. Not copied since internal references, and mesh
        // data may be altered
        
        // Clone vertex animation
        foreach (k,v; mAnimationsList)
        {
            Animation newAnim = v.clone(v.getName());
            newMesh.getAs().mAnimationsList[v.getName()] = newAnim;
        }
        // Clone pose list
        foreach (pose; mPoseList)
        {
            Pose newPose = pose.clone();
            newMesh.getAs().mPoseList.insert(newPose);
        }
        newMesh.getAs().mSharedVertexDataAnimationType = mSharedVertexDataAnimationType;
        newMesh.getAs().mAnimationTypesDirty = true;
        
        newMesh.get().load();
        newMesh.getAs().touch();
        
        return newMesh;
    }
    
    /** Get the axis-aligned bounding box for this mesh.
     */
    AxisAlignedBox getBounds()
    {
        return mAABB;
    }
    
    /** Gets the radius of the bounding sphere surrounding this mesh. */
    Real getBoundingSphereRadius()
    {
        return mBoundRadius;
    }
    
    /** Manually set the bounding box for this Mesh.
     @remarks
         Calling this method is required when building manual meshes now, because OGRE can no longer 
         update the bounds for you, because it cannot necessarily read vertex data back from 
         the vertex buffers which this mesh uses (they very well might be write-only, and even
         if they are not, reading data from a hardware buffer is a bottleneck).
     @param pad If true, a certain padding will be added to the bounding box to separate it from the mesh
     */
    void _setBounds(AxisAlignedBox bounds, bool pad = true)
    {
        mAABB = bounds;
        mBoundRadius = Math.boundingRadiusFromAABB(mAABB);
        
        if( mAABB.isFinite() )
        {
            Vector3 max = mAABB.getMaximum();
            Vector3 min = mAABB.getMinimum();
            
            if (pad)
            {
                // Pad out the AABB a little, helps with most bounds tests
                Vector3 scaler = (max - min) * MeshManager.getSingleton().getBoundsPaddingFactor();
                mAABB.setExtents(min  - scaler, max + scaler);
                // Pad out the sphere a little too
                mBoundRadius = mBoundRadius + (mBoundRadius * MeshManager.getSingleton().getBoundsPaddingFactor());
            }
        }
    }
    
    /** Manually set the bounding radius. 
     @remarks
     Calling this method is required when building manual meshes now, because OGRE can no longer 
     update the bounds for you, because it cannot necessarily read vertex data back from 
     the vertex buffers which this mesh uses (they very well might be write-only, and even
     if they are not, reading data from a hardware buffer is a bottleneck).
     */
    void _setBoundingSphereRadius(Real radius)
    {
        mBoundRadius = radius;
    }
    
    /** Sets the name of the skeleton this Mesh uses for animation.
     @remarks
     Meshes can optionally be assigned a skeleton which can be used to animate
     the mesh through bone assignments. The default is for the Mesh to use no
     skeleton. Calling this method with a valid skeleton filename will cause the
     skeleton to be loaded if it is not already (a single skeleton can be shared
     by many Mesh objects).
     @param skelName
     The name of the .skeleton file to use, or an empty string to use
     no skeleton
     */
    void setSkeletonName(string skelName)
    in
    {
        assert(skelName !is null);
    }
    body
    {
        if (skelName != mSkeletonName)
        {
            mSkeletonName = skelName;
            
            if (skelName == "")
            {
                // No skeleton
                mSkeleton.setNull();
            }
            else
            {
                // Load skeleton
                try {
                    mSkeleton = SkeletonManager.getSingleton().load(skelName, mGroup);
                }
                catch
                {
                    mSkeleton.setNull();
                    // Log this error
                    string msg = "Unable to load skeleton ";
                    msg ~= skelName ~ " for Mesh " ~ mName
                        ~ ". This Mesh will not be animated. "
                            ~ "You can ignore this message if you are using an offline tool.";
                    LogManager.getSingleton().logMessage(msg);
                }
            }
            if (isLoaded())
                _dirtyState();
        }
    }
    
    /** Returns true if this Mesh has a linked Skeleton. */
    bool hasSkeleton()
    {
        return mSkeletonName && (mSkeletonName != "");
    }
    
    /** Returns whether or not this mesh has some kind of vertex animation. 
     */
    bool hasVertexAnimation()
    {
        return mAnimationsList.length != 0;
    }
    
    /** Gets a pointer to any linked Skeleton. 
     @return
     Weak reference to the skeleton - copy this if you want to hold a strong pointer.
     */
    ref SharedPtr!Skeleton getSkeleton()
    {
        return mSkeleton;
    }
    
    /** Gets the name of any linked Skeleton */
    string getSkeletonName()
    {
        return mSkeletonName;
    }
    /** Initialise an animation set suitable for use with this mesh. 
     @remarks
     Only recommended for use inside the engine, not by applications.
     */
    void _initAnimationState(AnimationStateSet animSet)
    {
        // Animation states for skeletal animation
        if (!mSkeleton.isNull())
        {
            // Delegate to Skeleton
            mSkeleton.getAs()._initAnimationState(animSet);
            
            // Take the opportunity to update the compiled bone assignments
            _updateCompiledBoneAssignments();
        }
        
        // Animation states for vertex animation
        foreach (k, anim; mAnimationsList)
        {
            // Only create a new animation state if it doesn't exist
            // We can have the same named animation in both skeletal and vertex
            // with a shared animation state affecting both, for combined effects
            // The animations should be the same length if this feature is used!
            if (!animSet.hasAnimationState(anim.getName()))
            {
                animSet.createAnimationState(anim.getName(), 0.0,
                                             anim.getLength());
            }
            
        }
        
    }
    
    /** Refresh an animation set suitable for use with this mesh. 
     @remarks
     Only recommended for use inside the engine, not by applications.
     */
    void _refreshAnimationState(ref AnimationStateSet animSet)
    {
        if (!mSkeleton.isNull())
        {
            mSkeleton.getAs()._refreshAnimationState(animSet);
        }
        
        // Merge in any new vertex animations
        foreach (k, anim; mAnimationsList)
        {
            // Create animation at time index 0, default params mean this has weight 1 and is disabled
            string animName = anim.getName();
            if (!animSet.hasAnimationState(animName))
            {
                animSet.createAnimationState(animName, 0.0, anim.getLength());
            }
            else
            {
                // Update length incase changed
                AnimationState animState = animSet.getAnimationState(animName);
                animState.setLength(anim.getLength());
                animState.setTimePosition(std.algorithm.min(anim.getLength(), animState.getTimePosition()));
            }
        }
        
    }
    /** Assigns a vertex to a bone with a given weight, for skeletal animation. 
     @remarks    
     This method is only valid after calling setSkeletonName.
     Since this is a one-off process there exists only 'addBoneAssignment' and
     'clearBoneAssignments' methods, no 'editBoneAssignment'. You should not need
     to modify bone assignments during rendering (only the positions of bones) and OGRE
     reserves the right to do some internal data ref ormatting of this information, depending
     on render system requirements.
     @par
     This method is for assigning weights to the shared geometry of the Mesh. To assign
     weights to the per-SubMesh geometry, see the equivalent methods on SubMesh.
     */
    void addBoneAssignment(VertexBoneAssignment vertBoneAssign)
    {
        mBoneAssignments[vertBoneAssign.vertexIndex].insert(vertBoneAssign);
        mBoneAssignmentsOutOfDate = true;
    }
    
    /** Removes all bone assignments for this mesh. 
     @remarks
     This method is for modifying weights to the shared geometry of the Mesh. To assign
     weights to the per-SubMesh geometry, see the equivalent methods on SubMesh.
     */
    void clearBoneAssignments()
    {
        mBoneAssignments.clear();
        mBoneAssignmentsOutOfDate = true;
    }
    
    /** Internal notification, used to tell the Mesh which Skeleton to use without loading it. 
     @remarks
     This is only here for unusual situation where you want to manually set up a
     Skeleton. Best to let OGRE deal with this, don't call it yourself unless you
     really know what you're doing.
     */
    void _notifySkeleton(ref SharedPtr!Skeleton pSkel)
    {
        mSkeleton = pSkel;
        mSkeletonName = pSkel.get().getName();
    }
    
    
    /** Gets an iterator for access all bone assignments. 
     */
    //BoneAssignmentIterator getBoneAssignmentIterator();
    
    /** Gets areference to the list of bone assignments
     */
    ref VertexBoneAssignmentList getBoneAssignments(){ return mBoneAssignments; }
    
    
    /** Returns the number of levels of detail that this mesh supports. 
     @remarks
     This number includes the original model.
     */
    ushort getNumLodLevels()
    {
        return mNumLods;
    }
    
    /** Gets details of the numbered level of detail entry. */
    MeshLodUsage getLodLevel(ushort index)
    {
        index = std.algorithm.min(index, cast(ushort)(mMeshLodUsageList.length - 1));
        if (mIsLodManual && index > 0 && mMeshLodUsageList[index].manualMesh.isNull())
        {
            // Load the mesh now
            try {
                string groupName = mMeshLodUsageList[index].manualGroup.length == 0 ? 
                    mGroup : mMeshLodUsageList[index].manualGroup;
                mMeshLodUsageList[index].manualMesh =
                    MeshManager.getSingleton().load(
                        mMeshLodUsageList[index].manualName,
                        groupName);
                // get the edge data, if required
                if (!mMeshLodUsageList[index].edgeData)
                {
                    mMeshLodUsageList[index].edgeData =
                        mMeshLodUsageList[index].manualMesh.getAs().getEdgeList(0);
                }
            }
            catch
            {
                LogManager.getSingleton().stream()
                    << "Error while loading manual LOD level "
                        << mMeshLodUsageList[index].manualName
                        << " - this LOD level will not be rendered. You can "
                        << "ignore this error in offline mesh tools.\n";
            }
            
        }
        return mMeshLodUsageList[index];
    }
    /** Adds a new manual level-of-detail entry to this Mesh.
     @remarks
     As an alternative to generating lower level of detail versions of a mesh, you can
     use your own manually modelled meshes as lower level versions. This lets you 
     have complete control over the LOD, and in addition lets you scale down other
     aspects of the model which cannot be done using the generated method; for example, 
     you could use less detailed materials and / or use less bones in the skeleton if
     this is an animated mesh. Therefore for complex models you are likely to be better off
     modelling your LODs yourself and using this method, whilst for models with fairly
     simple materials and no animation you can just use the generateLodLevels method.
     @param value
     The value from which this Lod will apply.
     @param meshName
     The name of the mesh which will be the lower level detail version.
     */
    void createManualLodLevel(Real lodValue, string meshName, string groupName = "")
    {
        
        // Basic prerequisites
        assert((mIsLodManual || mNumLods == 1) , "Generated LODs already in use!");
        
        mIsLodManual = true;
        MeshLodUsage lod;
        lod.userValue = lodValue;
        lod.value = mLodStrategy.transformUserValue(lod.userValue);
        lod.manualName = meshName;
        lod.manualGroup = groupName is null ? mGroup : groupName;
        //lod.manualMesh = SharedPtr!Mesh();
        lod.manualMesh.setNull();
        lod.edgeData = null;
        mMeshLodUsageList.insert(lod);
        ++mNumLods;
        
        mLodStrategy.sort(mMeshLodUsageList);
    }
    
    /** Changes the alternate mesh to use as a manual LOD at the given index.
     @remarks
     Note that the index of a LOD may change if you insert other LODs. If in doubt,
     use getLodIndex().
     @param index
     The index of the level to be changed.
     @param meshName
     The name of the mesh which will be the lower level detail version.
     */
    void updateManualLodLevel(ushort index, string meshName)
    {
        
        // Basic prerequisites
        assert(mIsLodManual , "Not using manual LODs!");
        assert(index != 0 , "Can't modify first lod level (full detail)");
        assert(index < mMeshLodUsageList.length , "Index out of bounds");
        // get lod
        MeshLodUsage lod = mMeshLodUsageList[index];
        
        lod.manualName = meshName;
        lod.manualMesh.setNull();
        if (lod.edgeData) destroy( lod.edgeData );
        lod.edgeData = null;
    }
    
    /** Retrieves the level of detail index for the given lod value. 
     @note
     The value passed in is the 'transformed' value. If you are dealing with
     an original source value (e.g. distance), use LodStrategy.transformUserValue
     to turn this into a lookup value.
     */
    ushort getLodIndex(Real value)
    {
        // Get index from strategy
        return mLodStrategy.getIndex(value, mMeshLodUsageList);
    }
    
    /** Returns true if this mesh is using manual LOD.
     @remarks
     A mesh can either use automatically generated LOD, or it can use alternative
     meshes as provided by an artist. A mesh can only use either all manual LODs 
     or all generated LODs, not a mixture of both.
     */
    bool isLodManual(){ return mIsLodManual; }
    
    /** Internal methods for loading LOD, do not use. */
    void _setLodInfo(ushort numLevels, bool isManual)
    {
        assert(!mEdgeListsBuilt , "Can't modify LOD after edge lists built");
        
        // Basic prerequisites
        assert(numLevels > 0 , "Must be at least one level (full detail level must exist)");
        
        mNumLods = numLevels;
        mMeshLodUsageList.length = numLevels;
        // Resize submesh face data lists too
        foreach (i; mSubMeshList)
        {
            i.mLodFaceList.length = numLevels - 1;
        }
        mIsLodManual = isManual;
    }
    
    /** Internal methods for loading LOD, do not use. */
    void _setLodUsage(ushort level, ref MeshLodUsage usage)
    {
        assert(!mEdgeListsBuilt , "Can't modify LOD after edge lists built");
        
        // Basic prerequisites
        assert(level != 0 , "Can't modify first lod level (full detail)");
        assert(level < mMeshLodUsageList.length , "Index out of bounds");
        
        mMeshLodUsageList[level] = usage;
    }
    
    /** Internal methods for loading LOD, do not use. */
    void _setSubMeshLodFaceList(ushort subIdx, ushort level, ref IndexData facedata)
    {
        assert(!mEdgeListsBuilt , "Can't modify LOD after edge lists built");
        
        // Basic prerequisites
        assert(!mIsLodManual , "Not using generated LODs!");
        assert(subIdx <= mSubMeshList.length , "Index out of bounds");
        assert(level != 0 , "Can't modify first lod level (full detail)");
        assert(level <= mSubMeshList[subIdx].mLodFaceList.length , "Index out of bounds");
        
        SubMesh sm = mSubMeshList[subIdx];
        sm.mLodFaceList[level - 1] = facedata;
        
    }
    
    /** Removes all LOD data from this Mesh. */
    void removeLodLevels()
    {
        if (!mIsLodManual)
        {
            // Remove data from SubMeshes
            foreach (isub; mSubMeshList)
            {
                isub.removeLodLevels();
            }
        }
        
        freeEdgeList();
        mMeshLodUsageList.clear();
        
        // Reinitialise
        mNumLods = 1;
        // Init first (manual) lod
        MeshLodUsage lod;
        lod.userValue = 0;
        if(mLodStrategy !is null) //FIXME fix dtors. Exception on system shutdown otherwise
            lod.value = mLodStrategy.getBaseValue();
        lod.edgeData = null;
        //lod.manualMesh = SharedPtr!Mesh();
        lod.manualMesh.setNull();
        mMeshLodUsageList ~= (lod);
        mIsLodManual = false;
        
        
    }
    
    /** Sets the policy for the vertex buffers to be used when loading
     this Mesh.
     @remarks
     By default, when loading the Mesh, static, write-only vertex and index buffers 
     will be used where possible in order to improve rendering performance. 
     However, such buffers
     cannot be manipulated on the fly by CPU code (although shader code can). If you
     wish to use the CPU to modify these buffers, you should call this method. Note,
     however, that it only takes effect after the Mesh has been reloaded. Note that you
     still have the option of manually repacing the buffers in this mesh with your
     own if you see fit too, in which case you don't need to call this method since it
     only affects buffers created by the mesh itself.
     @par
     You can define the approach to a Mesh by changing the default parameters to 
     MeshManager.load if you wish; this means the Mesh is loaded with those options
     the first time instead of you having to reload the mesh after changing these options.
     @param usage
     The usage flags, which by default are 
     HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY
     @param shadowBuffer
     If set to @c true, the vertex buffers will be created with a
     system memory shadow buffer. You should set this if you want to be able to
     read from the buffer, because reading from a hardware buffer is a no-no.
     */
    void setVertexBufferPolicy(HardwareBuffer.Usage vbUsage, bool shadowBuffer = false)
    {
        mVertexBufferUsage = vbUsage;
        mVertexBufferShadowBuffer = shadowBuffer;
    }
    
    /** Sets the policy for the index buffers to be used when loading
     this Mesh.
     @remarks
     By default, when loading the Mesh, static, write-only vertex and index buffers 
     will be used where possible in order to improve rendering performance. 
     However, such buffers
     cannot be manipulated on the fly by CPU code (although shader code can). If you
     wish to use the CPU to modify these buffers, you should call this method. Note,
     however, that it only takes effect after the Mesh has been reloaded. Note that you
     still have the option of manually repacing the buffers in this mesh with your
     own if you see fit too, in which case you don't need to call this method since it
     only affects buffers created by the mesh itself.
     @par
     You can define the approach to a Mesh by changing the default parameters to 
     MeshManager.load if you wish; this means the Mesh is loaded with those options
     the first time instead of you having to reload the mesh after changing these options.
     @param usage
     The usage flags, which by default are 
     HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY
     @param shadowBuffer
     If set to @c true, the index buffers will be created with a
     system memory shadow buffer. You should set this if you want to be able to
     read from the buffer, because reading from a hardware buffer is a no-no.
     */
    void setIndexBufferPolicy(HardwareBuffer.Usage vbUsage, bool shadowBuffer = false)
    {
        mIndexBufferUsage = vbUsage;
        mIndexBufferShadowBuffer = shadowBuffer;
    }
    
    /** Gets the usage setting for this meshes vertex buffers. */
    HardwareBuffer.Usage getVertexBufferUsage(){ return mVertexBufferUsage; }
    /** Gets the usage setting for this meshes index buffers. */
    HardwareBuffer.Usage getIndexBufferUsage(){ return mIndexBufferUsage; }
    /** Gets whether or not this meshes vertex buffers are shadowed. */
    bool isVertexBufferShadowed(){ return mVertexBufferShadowBuffer; }
    /** Gets whether or not this meshes index buffers are shadowed. */
    bool isIndexBufferShadowed(){ return mIndexBufferShadowBuffer; }
    
    
    /** Rationalises the passed in bone assignment list.
     @remarks
     OGRE supports up to 4 bone assignments per vertex. The reason for this limit
     is that this is the maximum number of assignments that can be passed into
     a hardware-assisted blending algorithm. This method identifies where there are
     more than 4 bone assignments for a given vertex, and eliminates the bone
     assignments with the lowest weights to reduce to this limit. The remaining
     weights are then re-balanced to ensure that they sum to 1.0.
     @param vertexCount
     The number of vertices.
     @param assignments
     The bone assignment list to rationalise. This list will be modified and
     entries will be removed where the limits are exceeded.
     @return
     The maximum number of bone assignments per vertex found, clamped to [1-4]
     */
    //FIXME Might be a mess down here
    ushort _rationaliseBoneAssignments(size_t vertexCount, ref VertexBoneAssignmentList assignments)
    {
        // Iterate through, finding the largest # bones per vertex
        ushort maxBones = 0;
        bool existsNonSkinnedVertices = false;
        
        for (size_t v = 0; v < vertexCount; ++v)
        {
            // Get number of entries for this vertex
            //short currBones = cast(ushort)(assignments.count(v));
            //TODO correct?
            short currBones = cast(ushort)(assignments[v].length);
            if (currBones <= 0)
                existsNonSkinnedVertices = true;
            
            // Deal with max bones update
            // (note this will record maxBones even if they exceed limit)
            if (maxBones < currBones)
                maxBones = currBones;
            // does the number of bone assignments exceed limit?
            if (currBones > OGRE_MAX_BLEND_WEIGHTS)
            {
                // D: Keeping this iterator stuff commented for reference

                // To many bone assignments on this vertex
                // Find the start & end (end is in iterator terms ie exclusive)
                //std::pair<VertexBoneAssignmentList::iterator, VertexBoneAssignmentList::iterator> range;
                // map to sort by weight
                //WeightIteratorMap weightToAssignmentMap;
                //range = assignments.equal_range(v);
                // Add all the assignments to map
                //for (i = range.first; i != range.second; ++i)
                //{
                //    // insert value weight.iterator
                //    weightToAssignmentMap.insert(
                //        WeightIteratorMap.value_type(i.second.weight, i));
                //}

                // Reverse iterate over weight map, remove lowest n
                int numToRemove = currBones - OGRE_MAX_BLEND_WEIGHTS;
                //WeightIteratorMap.iterator remIt = weightToAssignmentMap.begin();

                //while (numToRemove--)
                //{
                //    // Erase this one
                //    assignments.erase(remIt.second);
                //    ++remIt;
                //}

                VertexBoneAssignment*[Real] weights;
                for(size_t i=0; i < assignments[v].length; i++)
                    weights[assignments[v][i].weight] = &assignments[v][i];
                
                auto keys = std.algorithm.sort(weights.keys);
                foreach(k; keys[0..numToRemove])
                {
                    assignments[v].removeFromArray(weights[k]);
                }

            } // if (currBones > OGRE_MAX_BLEND_WEIGHTS)
            
            // Make sure the weights are normalised
            // Do this irrespective of whether we had to remove assignments or not
            //   since it gives us a guarantee that weights are normalised
            //  We assume this, so it's a good idea since some modellers may not
            //auto normalise_range = assignments.equal_range(v);
            //auto normalise_range = assumeSorted(assignments).equalRange(v);
            Real totalWeight = 0;
            // Find total first
            foreach (ass; assignments[v])
            {
                totalWeight += ass.weight;
            }
            // Now normalise if total weight is outside tolerance
            if (!Math.RealEqual(totalWeight, 1.0f))
            {
                foreach (ref ass; assignments[v])
                {
                    ass.weight = ass.weight / totalWeight;
                }
            }
            
        }
        
        if (maxBones > OGRE_MAX_BLEND_WEIGHTS)
        {
            // Warn that we've reduced bone assignments
            LogManager.getSingleton().logMessage("WARNING: the mesh '" ~ mName ~ "' includes vertices with more than " ~
                                                 std.conv.to!string(OGRE_MAX_BLEND_WEIGHTS) ~ " bone assignments. " ~
                                                 "The lowest weighted assignments beyond this limit have been removed, so " ~
                                                 "your animation may look slightly different. To eliminate this, reduce " ~
                                                 "the number of bone assignments per vertex on your mesh to " ~
                                                 std.conv.to!string(OGRE_MAX_BLEND_WEIGHTS) ~ ".");
            // we've adjusted them down to the max
            maxBones = OGRE_MAX_BLEND_WEIGHTS;
            
        }
        
        if (existsNonSkinnedVertices)
        {
            // Warn that we've non-skinned vertices
            LogManager.getSingleton().logMessage("WARNING: the mesh '" ~ mName ~ "' " ~
                                                 "includes vertices without bone assignments. Those vertices will " ~
                                                 "transform to wrong position when skeletal animation enabled. " ~
                                                 "To eliminate this, assign at least one bone assignment per vertex " ~
                                                 "on your mesh.");
        }
        
        return maxBones;
    }
    
    /** Internal method, be called once to compile bone assignments into geometry buffer. 
     @remarks
     The OGRE engine calls this method automatically. It compiles the information 
     submitted as bone assignments into a format usable in realtime. It also 
     eliminates excessive bone assignments (max is OGRE_MAX_BLEND_WEIGHTS)
     and re-normalises the remaining assignments.
     */
    void _compileBoneAssignments()
    {
        if (sharedVertexData)
        {
            ushort maxBones = _rationaliseBoneAssignments(sharedVertexData.vertexCount, mBoneAssignments);
            
            if (maxBones != 0)
            {
                compileBoneAssignments(mBoneAssignments, maxBones, 
                                       sharedBlendIndexToBoneIndexMap, sharedVertexData);
            }
        }
        mBoneAssignmentsOutOfDate = false;
    }
    
    /** Internal method, be called once to update the compiled bone assignments.
     @remarks
     The OGRE engine calls this method automatically. It updates the compiled bone
     assignments if requested.
     */
    void _updateCompiledBoneAssignments()
    {
        if (mBoneAssignmentsOutOfDate)
            _compileBoneAssignments();

        foreach (i; mSubMeshList)
        {
            if (i.mBoneAssignmentsOutOfDate)
            {
                i._compileBoneAssignments();
            }
        }
    }
    
    /** This method collapses two texcoords into one for all submeshes where this is possible.
     @remarks
     Often a submesh can have two tex. coords. (i.e. TEXCOORD0 & TEXCOORD1), being both
     composed of two floats. There are many practical reasons why it would be more convenient
     to merge both of them into one TEXCOORD0 of 4 floats. This function does exactly that
     The finalTexCoordSet must have enough space for the merge, or else the submesh will be
     skipped. (i.e. you can't merge a tex. coord with 3 floats with one having 2 floats)

     finalTexCoordSet & texCoordSetToDestroy must be in the same buffer source, and must
     be adjacent.
     @param finalTexCoordSet The tex. coord index to merge to. Should have enough space to
     actually work.
     @param texCoordSetToDestroy The texture coordinate index that will disappear on
     successfull merges.
     */
    void mergeAdjacentTexcoords( ushort finalTexCoordSet, ushort texCoordSetToDestroy )
    {
        if( sharedVertexData )
            mergeAdjacentTexcoords( finalTexCoordSet, texCoordSetToDestroy, sharedVertexData );
        
        foreach( itor; mSubMeshList)
        {
            if( !itor.useSharedVertices )
                mergeAdjacentTexcoords( finalTexCoordSet, texCoordSetToDestroy, itor.vertexData );
        }
    }
    
    /** This method builds a set of tangent vectors for a given mesh into a 3D texture coordinate buffer.
     @remarks
     Tangent vectors are vectors representing the local 'X' axis for a given vertex based
     on the orientation of the 2D texture on the geometry. They are built from a combination
     of existing normals, and from the 2D texture coordinates already baked into the model.
     They can be used for a number of things, but most of all they are useful for 
     vertex and fragment programs, when you wish to arrive at a common space for doing
     per-pixel calculations.
     @par
     The prerequisites for calling this method include that the vertex data used by every
     SubMesh has both vertex normals and 2D texture coordinates.
     @param targetSemantic
     The semantic to store the tangents in. Defaults to 
     the explicit tangent binding, but note that this is only usable on more
     modern hardware (Shader Model 2), so if you need portability with older
     cards you should change this to a texture coordinate binding instead.
     @param sourceTexCoordSet
     The texture coordinate index which should be used as the source
     of 2D texture coordinates, with which to calculate the tangents.
     @param index
     The element index, ie the texture coordinate set which should be used to store the 3D
     coordinates representing a tangent vector per vertex, if targetSemantic is 
     VES_TEXTURE_COORDINATES. If this already exists, it will be overwritten.
     @param splitMirrored
     Sets whether or not to split vertices when a mirrored tangent space
     transition is detected (matrix parity differs). @see TangentSpaceCalc.setSplitMirrored
     @param splitRotated
     Sets whether or not to split vertices when a rotated tangent space
     is detected. @see TangentSpaceCalc.setSplitRotated
     @param storeParityInW
     If @c true, store tangents as a 4-vector and include parity in w.
     */
    void buildTangentVectors(VertexElementSemantic targetSemantic = VertexElementSemantic.VES_TANGENT,
                             ushort sourceTexCoordSet = 0, ushort index = 0, 
                             bool splitMirrored = false, bool splitRotated = false, bool storeParityInW = false)
    {
        
        auto tangentsCalc = new TangentSpaceCalc;
        tangentsCalc.setSplitMirrored(splitMirrored);
        tangentsCalc.setSplitRotated(splitRotated);
        tangentsCalc.setStoreParityInW(storeParityInW);
        
        // shared geometry first
        if (sharedVertexData)
        {
            tangentsCalc.setVertexData(sharedVertexData);
            bool found = false;
            foreach (sm; mSubMeshList)
            {
                if (sm.useSharedVertices)
                {
                    tangentsCalc.addIndexData(sm.indexData);
                    found = true;
                }
            }
            if (found)
            {
                TangentSpaceCalc.Result res = 
                    tangentsCalc.build(targetSemantic, sourceTexCoordSet, index);
                
                // If any vertex splitting happened, we have to give them bone assignments
                if (getSkeletonName() && getSkeletonName() != "")
                {
                    foreach (remap; res.indexesRemapped)
                    {
                        // Copy all bone assignments from the split vertex
                        //size_t vbstart = std.algorithm.countUntil!"a > b"(mBoneAssignments, remap.splitVertex.first);
                        //size_t vbend = std.algorithm.countUntil!"a < b"(mBoneAssignments, remap.splitVertex.first);

                        //VertexBoneAssignmentList.iterator vbstart = mBoneAssignments.lower_bound(remap.splitVertex.first);
                        //VertexBoneAssignmentList.iterator vbend = mBoneAssignments.upper_bound(remap.splitVertex.first);
                        //FIXME Incorrect probably
                        //foreach (i; vbstart..vbend)
                        foreach (newAsgn; mBoneAssignments[remap.splitVertex.first])
                        {
                            //auto vba = mBoneAssignments[mBoneAssignments.keys[i]];
                            //VertexBoneAssignment newAsgn = vba;//.second;
                            newAsgn.vertexIndex = cast(uint)(remap.splitVertex.second);
                            // multimap insert doesn't invalidate iterators
                            addBoneAssignment(newAsgn);
                        }
                        
                    }
                }
                
                // Update poses (some vertices might have been duplicated)
                // we will just check which vertices have been split and copy
                // the offset for the original vertex to the corresponding new vertex
                
                foreach(current_pose; getPoseList())
                {
                    Pose.VertexOffsetMap offset_map = current_pose.getVertexOffsets();
                    
                    foreach( TangentSpaceCalc.VertexSplit split; res.vertexSplits)
                    {
                        // copy the offset
                        //if( offset_map.hasKey( split.first ) )
                        if( (split.first in offset_map) !is null )
                        {
                            Vector3 found_offset = offset_map[split.first];
                            current_pose.addVertex( split.second, found_offset/*.second*/ );
                        }
                    }
                }
            }
        }
        
        // Dedicated geometry
        foreach (sm; mSubMeshList)
        {
            if (!sm.useSharedVertices)
            {
                tangentsCalc.clear();
                tangentsCalc.setVertexData(sm.vertexData);
                tangentsCalc.addIndexData(sm.indexData, sm.operationType);
                TangentSpaceCalc.Result res = 
                    tangentsCalc.build(targetSemantic, sourceTexCoordSet, index);
                
                // If any vertex splitting happened, we have to give them bone assignments
                if (getSkeletonName() != "")
                {
                    foreach (remap; res.indexesRemapped)
                    {
                        // Copy all bone assignments from the split vertex
                        //VertexBoneAssignmentList.const_iterator vbstart = 
                        //    sm.getBoneAssignments().lower_bound(remap.splitVertex.first);
                        //VertexBoneAssignmentList.const_iterator vbend = 
                        //    sm.getBoneAssignments().upper_bound(remap.splitVertex.first);

                        //FIXME Assuming splitVertex.first is the vertex index
                        foreach (newAsgn; sm.getBoneAssignments()[remap.splitVertex.first])
                        {
                            //VertexBoneAssignment newAsgn = vba.second;
                            newAsgn.vertexIndex = cast(uint)(remap.splitVertex.second);
                            // multimap insert doesn't invalidate iterators
                            sm.addBoneAssignment(newAsgn);
                        }
                        
                    }
                    
                }
            }
        }
        
    }
    
    /** Ask the mesh to suggest parameters to a future buildTangentVectors call, 
     should you wish to use texture coordinates to store the tangents. 
     @remarks
     This helper method will suggest source and destination texture coordinate sets
     for a call to buildTangentVectors. It will detect when there are inappropriate
     conditions (such as multiple geometry sets which don't agree). 
     Moreover, it will return 'true' if it detects that there are aleady 3D 
     coordinates in the mesh, and Therefore tangents may have been prepared already.
     @param targetSemantic
     The semantic you intend to use to store the tangents
     if they are not already present;
     most likely options are VES_TEXTURE_COORDINATES or VES_TANGENT; you should
     use texture coordinates if you want compatibility with older, pre-SM2
     graphics cards, and the tangent binding otherwise.
     @param outSourceCoordSet
     Reference to a source texture coordinate set which 
     will be populated.
     @param outIndex
     Reference to a destination element index (e.g. texture coord set)
     which will be populated
     */
    bool suggestTangentVectorBuildParams(VertexElementSemantic targetSemantic,
                                         ref ushort outSourceCoordSet, ref ushort outIndex)
    {
        // Go through all the vertex data and locate source and dest (must agree)
        bool sharedGeometryDone = false;
        bool foundExisting = false;
        bool firstOne = true;
        
        foreach (sm; mSubMeshList)
        {
            VertexData vertexData;
            
            if (sm.useSharedVertices)
            {
                if (sharedGeometryDone)
                    continue;
                vertexData = sharedVertexData;
                sharedGeometryDone = true;
            }
            else
            {
                vertexData = sm.vertexData;
            }
            
            VertexElement sourceElem;
            ushort targetIndex = 0;
            for (targetIndex = 0; targetIndex < OGRE_MAX_TEXTURE_COORD_SETS; ++targetIndex)
            {
                VertexElement testElem =
                    vertexData.vertexDeclaration.findElementBySemantic(
                        VertexElementSemantic.VES_TEXTURE_COORDINATES, targetIndex);
                if (!testElem)
                    break; // finish if we've run out, t will be the target
                
                if (!sourceElem)
                {
                    // We're still looking for the source texture coords
                    if (testElem.getType() == VertexElementType.VET_FLOAT2)
                    {
                        // Ok, we found it
                        sourceElem = testElem;
                    }
                }
                
                if(!foundExisting && targetSemantic == VertexElementSemantic.VES_TEXTURE_COORDINATES)
                {
                    // We're looking for the destination
                    // Check to see if we've found a possible
                    if (testElem.getType() == VertexElementType.VET_FLOAT3)
                    {
                        // This is a 3D set, might be tangents
                        foundExisting = true;
                    }
                    
                }
                
            }
            
            if (!foundExisting && targetSemantic != VertexElementSemantic.VES_TEXTURE_COORDINATES)
            {
                targetIndex = 0;
                // Look for existing semantic
                VertexElement testElem =
                    vertexData.vertexDeclaration.findElementBySemantic(
                        targetSemantic, targetIndex);
                if (testElem)
                {
                    foundExisting = true;
                }
                
            }
            
            // After iterating, we should have a source and a possible destination (t)
            if (!sourceElem)
            {
                throw new ItemNotFoundError(
                    "Cannot locate an appropriate 2D texture coordinate set for "
                    "all the vertex data in this mesh to create tangents from. ",
                    "Mesh.suggestTangentVectorBuildParams");
            }
            // Check that we agree with previous decisions, if this is not the
            // first one, and if we're not just using the existing one
            if (!firstOne && !foundExisting)
            {
                if (sourceElem.getIndex() != outSourceCoordSet)
                {
                    throw new InvalidParamsError(
                        "Multiple sets of vertex data in this mesh disagree on "
                        "the appropriate index to use for the source texture coordinates. "
                        "This ambiguity must be rectified before tangents can be generated.",
                        "Mesh.suggestTangentVectorBuildParams");
                }
                if (targetIndex != outIndex)
                {
                    throw new InvalidParamsError(
                        "Multiple sets of vertex data in this mesh disagree on "
                        "the appropriate index to use for the target texture coordinates. "
                        "This ambiguity must be rectified before tangents can be generated.",
                        "Mesh.suggestTangentVectorBuildParams");
                }
            }
            
            // Otherwise, save this result
            outSourceCoordSet = sourceElem.getIndex();
            outIndex = targetIndex;
            
            firstOne = false;
            
        }
        
        return foundExisting;
        
    }
    
    /** Builds an edge list for this mesh, which can be used for generating a shadow volume
     among other things.
     */
    void buildEdgeList()
    {
        if (mEdgeListsBuilt)
            return;
        
        // Loop over LODs
        for (ushort lodIndex = 0; lodIndex < cast(ushort)mMeshLodUsageList.length; ++lodIndex)
        {
            // use getLodLevel to enforce loading of manual mesh lods
            MeshLodUsage usage = getLodLevel(lodIndex);
            
            bool atLeastOneIndexSet = false;
            
            if (mIsLodManual && lodIndex != 0)
            {
                // Delegate edge building to manual mesh
                // It should have already built it's own edge list while loading
                if (!usage.manualMesh.isNull())
                {
                    usage.edgeData = usage.manualMesh.getAs().getEdgeList(0);
                }
            }
            else
            {
                // Build
                EdgeListBuilder eb;
                size_t vertexSetCount = 0;
                
                if (sharedVertexData)
                {
                    eb.addVertexData(sharedVertexData);
                    vertexSetCount++;
                }
                
                // Prepare the builder using the submesh information
                
                foreach (s; mSubMeshList)
                {
                    if (s.operationType != RenderOperation.OperationType.OT_TRIANGLE_FAN && 
                        s.operationType != RenderOperation.OperationType.OT_TRIANGLE_LIST && 
                        s.operationType != RenderOperation.OperationType.OT_TRIANGLE_STRIP)
                    {
                        continue;
                    }
                    if (s.useSharedVertices)
                    {
                        // Use shared vertex data, index as set 0
                        if (lodIndex == 0)
                        {
                            eb.addIndexData(s.indexData, 0, s.operationType);
                        }
                        else
                        {
                            eb.addIndexData(s.mLodFaceList[lodIndex-1], 0,
                                            s.operationType);
                        }
                    }
                    else if(s.isBuildEdgesEnabled())
                    {
                        // own vertex data, add it and reference it directly
                        eb.addVertexData(s.vertexData);
                        if (lodIndex == 0)
                        {
                            // Base index data
                            eb.addIndexData(s.indexData, vertexSetCount++,
                                            s.operationType);
                        }
                        else
                        {
                            // LOD index data
                            eb.addIndexData(s.mLodFaceList[lodIndex-1],
                                            vertexSetCount++, s.operationType);
                        }
                        
                    }
                    atLeastOneIndexSet = true;
                }
                
                if (atLeastOneIndexSet)
                {
                    usage.edgeData = eb.build();
                    
                    version(Debug)
                    {
                        // Override default log
                        Log log = LogManager.getSingleton().createLog(
                            mName ~ "_lod" ~ std.conv.to!string(lodIndex) ~
                            "_prepshadow.log", false, false);
                        usage.edgeData.log(log);
                        // clean up log & close file handle
                        LogManager.getSingleton().destroyLog(log);
                    }
                }
                else
                {
                    // create empty edge data
                    usage.edgeData = new EdgeData();
                }
            }
        }
        mEdgeListsBuilt = true;
    }
    
    /** Destroys and frees the edge lists this mesh has built. */
    void freeEdgeList()
    {
        if (!mEdgeListsBuilt)
            return;
        
        // Loop over LODs
        ushort index = 0;
        foreach (usage; mMeshLodUsageList)
        {
            
            if (!mIsLodManual || index == 0)
            {
                // Only delete if we own this data
                // Manual LODs > 0 own their own
                destroy(usage.edgeData);
            }
            usage.edgeData = null;
        }
        
        mEdgeListsBuilt = false;
    }
    
    /** This method prepares the mesh for generating a renderable shadow volume. 
     @remarks
     Preparing a mesh to generate a shadow volume involves firstly ensuring that the 
     vertex buffer containing the positions for the mesh is a standalone vertex buffer,
     with no other components in it. This method will Therefore break apart any existing
     vertex buffers this mesh holds if position is sharing a vertex buffer. 
     Secondly, it will double the size of this vertex buffer so that there are 2 copies of 
     the position data for the mesh. The first half is used for the original, and the second 
     half is used for the 'extruded' version of the mesh. The vertex count of the main 
     VertexData used to render the mesh will remain the same though, so as not to add any 
     overhead to regular rendering of the object.
     Both copies of the position are required in one buffer because shadow volumes stretch 
     from the original mesh to the extruded version. 
     @par
     Because shadow volumes are rendered in turn, no additional
     index buffer space is allocated by this method, a shared index buffer allocated by the
     shadow rendering algorithm is used for addressing this extended vertex buffer.
     */
    void prepareForShadowVolume()
    {
        if (mPreparedForShadowVolumes)
            return;
        
        if (sharedVertexData)
        {
            sharedVertexData.prepareForShadowVolume();
        }
        
        foreach (s; mSubMeshList)
        {
            if (!s.useSharedVertices && 
                (s.operationType == RenderOperation.OperationType.OT_TRIANGLE_FAN || 
             s.operationType == RenderOperation.OperationType.OT_TRIANGLE_LIST ||
             s.operationType == RenderOperation.OperationType.OT_TRIANGLE_STRIP))
            {
                s.vertexData.prepareForShadowVolume();
            }
        }
        mPreparedForShadowVolumes = true;
    }
    
    /** Return the edge list for this mesh, building it if required. 
     @remarks
     You must ensure that the Mesh as been prepared for shadow volume 
     rendering if you intend to use this information for that purpose.
     @param lodIndex
     The LOD at which to get the edge list, 0 being the highest.
     */
    ref EdgeData getEdgeList(ushort lodIndex = 0)
    {
        // Build edge list on demand
        if (!mEdgeListsBuilt && mAutoBuildEdgeLists)
        {
            buildEdgeList();
        }
        
        return getLodLevel(lodIndex).edgeData;
    }
    
    /** Return the edge list for this mesh, building it if required. 
     @remarks
     You must ensure that the Mesh as been prepared for shadow volume 
     rendering if you intend to use this information for that purpose.
     @param lodIndex
     The LOD at which to get the edge list, 0 being the highest.
     */
    //EdgeData* getEdgeList(ushort lodIndex = 0);
    
    /** Returns whether this mesh has already had it's geometry prepared for use in 
     rendering shadow volumes. */
    bool isPreparedForShadowVolumes(){ return mPreparedForShadowVolumes; }
    
    /** Returns whether this mesh has an attached edge list. */
    bool isEdgeListBuilt(){ return mEdgeListsBuilt; }
    
    /** Prepare matrices for software indexed vertex blend.
     @remarks
     This function organise bone indexed matrices to blend indexed matrices,
     so software vertex blending can access to the matrix via blend index
     directly.
     @param blendMatrices
     Pointer to an array of matrix pointers to store
     prepared results, which indexed by blend index.
     @param boneMatrices
     Pointer to an array of matrices to be used to blend,
     which indexed by bone index.
     @param indexMap
     The index map used to translate blend index to bone index.
     */
    static void prepareMatricesForVertexBlend(ref Matrix4[256] blendMatrices,
                                              Matrix4[] boneMatrices,ref IndexMap indexMap)
    {
        assert(indexMap.length <= 256);

        size_t i = 0;
        foreach (it; indexMap)
        {
            blendMatrices[i++] = boneMatrices[it];
        }
    }
    
    /** Performs a software indexed vertex blend, of the kind used for
     skeletal animation although it can be used for other purposes. 
     @remarks
     This function is supplied to update vertex data with blends 
     done in software, either because no hardware support is available, 
     or that you need the results of the blend for some other CPU operations.
     @param sourceVertexData
     VertexData class containing positions, normals,
     blend indices and blend weights.
     @param targetVertexData
     VertexData class containing target position
     and normal buffers which will be updated with the blended versions.
     Note that the layout of the source and target position / normal 
     buffers must be identical, ie they must use the same buffer indexes
     @param blendMatrices
     Pointer to an array of matrix pointers to be used to blend,
     indexed by blend indices in the sourceVertexData
     @param numMatrices
     Number of matrices in the blendMatrices, it might be used
     as a hint for optimisation.
     @param blendNormals
     If @c true, normals are blended as well as positions.
     */
    static void softwareVertexBlend(VertexData sourceVertexData, 
                                    ref VertexData targetVertexData,
                                    ref Matrix4[256] blendMatrices, size_t numMatrices,
                                    bool blendNormals)
    {
        float *pSrcPos = null;
        float *pSrcNorm = null;
        float *pDestPos = null;
        float *pDestNorm = null;
        float *pBlendWeight = null;
        ubyte* pBlendIdx = null;
        size_t srcPosStride = 0;
        size_t srcNormStride = 0;
        size_t destPosStride = 0;
        size_t destNormStride = 0;
        size_t blendWeightStride = 0;
        size_t blendIdxStride = 0;
        
        
        // Get elements for source
        auto srcElemPos = sourceVertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
        auto srcElemNorm = sourceVertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_NORMAL);
        auto srcElemBlendIndices = sourceVertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_BLEND_INDICES);
        auto srcElemBlendWeights = sourceVertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_BLEND_WEIGHTS);
        
        assert (srcElemPos && srcElemBlendIndices && srcElemBlendWeights ,
                "You must supply at least positions, blend indices and blend weights");
        // Get elements for target
        auto destElemPos = targetVertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
        auto destElemNorm = targetVertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_NORMAL);
        
        // Do we have normals and want to blend them?
        bool includeNormals = blendNormals && (srcElemNorm !is null) && (destElemNorm !is null);
        
        
        // Get buffers for source
        SharedPtr!HardwareVertexBuffer srcPosBuf = sourceVertexData.vertexBufferBinding.getBuffer(srcElemPos.getSource());
        SharedPtr!HardwareVertexBuffer srcIdxBuf = sourceVertexData.vertexBufferBinding.getBuffer(srcElemBlendIndices.getSource());
        SharedPtr!HardwareVertexBuffer srcWeightBuf = sourceVertexData.vertexBufferBinding.getBuffer(srcElemBlendWeights.getSource());
        SharedPtr!HardwareVertexBuffer srcNormBuf;
        
        srcPosStride = srcPosBuf.get().getVertexSize();
        
        blendIdxStride = srcIdxBuf.get().getVertexSize();
        
        blendWeightStride = srcWeightBuf.get().getVertexSize();
        if (includeNormals)
        {
            srcNormBuf = sourceVertexData.vertexBufferBinding.getBuffer(srcElemNorm.getSource());
            srcNormStride = srcNormBuf.get().getVertexSize();
        }
        // Get buffers for target
        SharedPtr!HardwareVertexBuffer destPosBuf = targetVertexData.vertexBufferBinding.getBuffer(destElemPos.getSource());
        SharedPtr!HardwareVertexBuffer destNormBuf;
        destPosStride = destPosBuf.get().getVertexSize();
        if (includeNormals)
        {
            destNormBuf = targetVertexData.vertexBufferBinding.getBuffer(destElemNorm.getSource());
            destNormStride = destNormBuf.get().getVertexSize();
        }
        
        void* pBuffer;
        
        // Lock source buffers for reading
        pBuffer = srcPosBuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY);
        srcElemPos.baseVertexPointerToElement(pBuffer, &pSrcPos);
        if (includeNormals)
        {
            if (srcNormBuf != srcPosBuf)
            {
                // Different buffer
                pBuffer = srcNormBuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY);
            }
            srcElemNorm.baseVertexPointerToElement(pBuffer, &pSrcNorm);
        }
        
        // Indices must be 4 bytes
        assert(srcElemBlendIndices.getType() == VertexElementType.VET_UBYTE4 &&
               "Blend indices must be VertexElementType.VET_UBYTE4");
        pBuffer = srcIdxBuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY);
        srcElemBlendIndices.baseVertexPointerToElement(pBuffer, &pBlendIdx);
        if (srcWeightBuf != srcIdxBuf)
        {
            // Lock buffer
            pBuffer = srcWeightBuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY);
        }
        srcElemBlendWeights.baseVertexPointerToElement(pBuffer, &pBlendWeight);
        ushort numWeightsPerVertex =
            VertexElement.getTypeCount(srcElemBlendWeights.getType());
        
        
        // Lock destination buffers for writing
        pBuffer = destPosBuf.get().lock(
            (destNormBuf != destPosBuf && destPosBuf.get().getVertexSize() == destElemPos.getSize()) ||
            (destNormBuf == destPosBuf && destPosBuf.get().getVertexSize() == destElemPos.getSize() + destElemNorm.getSize()) ?
            HardwareBuffer.LockOptions.HBL_DISCARD : HardwareBuffer.LockOptions.HBL_NORMAL);
        destElemPos.baseVertexPointerToElement(pBuffer, &pDestPos);
        if (includeNormals)
        {
            if (destNormBuf != destPosBuf)
            {
                pBuffer = destNormBuf.get().lock(
                    destNormBuf.get().getVertexSize() == destElemNorm.getSize() ?
                    HardwareBuffer.LockOptions.HBL_DISCARD : HardwareBuffer.LockOptions.HBL_NORMAL);
            }
            destElemNorm.baseVertexPointerToElement(pBuffer, &pDestNorm);
        }
        
        OptimisedUtil.getImplementation().softwareVertexSkinning(
            pSrcPos, pDestPos,
            pSrcNorm, pDestNorm,
            pBlendWeight, pBlendIdx,
            blendMatrices,
            srcPosStride, destPosStride,
            srcNormStride, destNormStride,
            blendWeightStride, blendIdxStride,
            numWeightsPerVertex,
            targetVertexData.vertexCount);
        
        // Unlock source buffers
        srcPosBuf.get().unlock();
        srcIdxBuf.get().unlock();
        if (srcWeightBuf != srcIdxBuf)
        {
            srcWeightBuf.get().unlock();
        }
        if (includeNormals && srcNormBuf != srcPosBuf)
        {
            srcNormBuf.get().unlock();
        }
        // Unlock destination buffers
        destPosBuf.get().unlock();
        if (includeNormals && destNormBuf != destPosBuf)
        {
            destNormBuf.get().unlock();
        }
        
    }
    
    /** Performs a software vertex morph, of the kind used for
     morph animation although it can be used for other purposes. 
     @remarks
     This function will linearly interpolate positions between two
     source buffers, into a third buffer.
     @param t
     Parametric distance between the start and end buffer positions.
     @param b1
     Vertex buffer containing VertexElementType.VET_FLOAT3 entries for the start positions.
     @param b2
     Vertex buffer containing VertexElementType.VET_FLOAT3 entries for the end positions.
     @param targetVertexData
     VertexData destination; assumed to have a separate position
     buffer already bound, and the number of vertices must agree with the
     number in start and end
     */
    static void softwareVertexMorph(Real t, 
                                    SharedPtr!HardwareVertexBuffer b1, 
                                    SharedPtr!HardwareVertexBuffer b2, 
                                    ref VertexData targetVertexData)
    {
        float* pb1 = cast(float*)(b1.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
        float* pb2;
        if (b1.get() != b2.get())
        {
            pb2 = cast(float*)(b2.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
        }
        else
        {
            // Same buffer - track with only one entry or time index exactly matching
            // one keyframe
            // For simplicity of main code, interpolate still but with same val
            pb2 = pb1;
        }
        
        auto posElem = targetVertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
        assert(posElem);
        auto normElem = targetVertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_NORMAL);
        
        bool morphNormals = false;
        if (normElem && normElem.getSource() == posElem.getSource() &&
            b1.get().getVertexSize() == 24 && b2.get().getVertexSize() == 24)
            morphNormals = true;
        
        SharedPtr!HardwareVertexBuffer destBuf =
            targetVertexData.vertexBufferBinding.getBuffer(
                posElem.getSource());
        assert((posElem.getSize() == destBuf.get().getVertexSize()
                || (morphNormals && posElem.getSize() + normElem.getSize() == destBuf.get().getVertexSize())) ,
               "Positions (or positions & normals) must be in a buffer on their own for morphing");
        float* pdst = cast(float*)(destBuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
        
        OptimisedUtil.getImplementation().softwareVertexMorph(
            t, pb1, pb2, pdst,
            b1.get().getVertexSize(), b2.get().getVertexSize(), destBuf.get().getVertexSize(),
            targetVertexData.vertexCount,
            morphNormals);
        
        destBuf.get().unlock();
        b1.get().unlock();
        if (b1.get() != b2.get())
            b2.get().unlock();
    }
    
    /** Performs a software vertex pose blend, of the kind used for
     morph animation although it can be used for other purposes. 
     @remarks
     This function will apply a weighted offset to the positions in the 
     incoming vertex data (Therefore this is a read/write operation, and 
     if you expect to call it more than once with the same data, then
     you would be best to suppress hardware uploads of the position buffer
     for the duration).
     @param weight
     Parametric weight to scale the offsets by.
     @param vertexOffsetMap
     Potentially sparse map of vertex index . offset.
     @param normalsMap
     Potentially sparse map of vertex index . normal.
     @param targetVertexData 
     VertexData destination; assumed to have a separate position
     buffer already bound, and the number of vertices must agree with the
     number in start and end.
     */
    static void softwareVertexPoseBlend(Real weight, 
                                        //map<size_t, Vector3>::type& vertexOffsetMap,
                                        //map<size_t, Vector3>::type& normalsMap,
                                        ref Vector3[size_t] vertexOffsetMap,
                                        ref Vector3[size_t] normalsMap,
                                        ref VertexData targetVertexData)
    {
        // Do nothing if no weight
        if (weight == 0.0f)
            return;
        
        auto posElem = targetVertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
        auto normElem = targetVertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_NORMAL);
        assert(posElem);
        // Support normals if they're in the same buffer as positions and pose includes them
        bool normals = normElem && !normalsMap.length == 0 && posElem.getSource() == normElem.getSource();
        SharedPtr!HardwareVertexBuffer destBuf =
            targetVertexData.vertexBufferBinding.getBuffer(
                posElem.getSource());
        
        size_t elemsPerVertex = destBuf.get().getVertexSize()/float.sizeof;
        
        // Have to lock in normal mode since this is incremental
        float* pBase = cast(float*)(
            destBuf.get().lock(HardwareBuffer.LockOptions.HBL_NORMAL));

        //FIXME SORTING ORDER
        // Iterate over affected vertices
        foreach (k,v; vertexOffsetMap)
        {
            // Adjust pointer
            float *pdst = pBase + k*elemsPerVertex;
            
            *pdst = *pdst + (v.x * weight);
            ++pdst;
            *pdst = *pdst + (v.y * weight);
            ++pdst;
            *pdst = *pdst + (v.z * weight);
            ++pdst;
            
        }
        
        if (normals)
        {
            float* pNormBase;
            normElem.baseVertexPointerToElement(cast(void*)pBase, &pNormBase);
            //FIXME SORTING ORDER
            foreach (k,v; normalsMap)
            {
                // Adjust pointer
                float *pdst = pNormBase + k*elemsPerVertex;
                
                *pdst = *pdst + (v.x * weight);
                ++pdst;
                *pdst = *pdst + (v.y * weight);
                ++pdst;
                *pdst = *pdst + (v.z * weight);
                ++pdst;             
                
            }
        }
        destBuf.get().unlock();
    }
    
    /** Gets a reference to the optional name assignments of the SubMeshes. */
    ref SubMeshNameMap getSubMeshNameMap(){ return mSubMeshNameMap; }
    
    /** Sets whether or not this Mesh should automatically build edge lists
     when asked for them, or whether it should never build them if
     they are not already provided.
     @remarks
     This allows you to create meshes which do not have edge lists calculated, 
     because you never want to use them. This value defaults to 'true'
     for mesh formats which did not include edge data, and 'false' for 
     newer formats, where edge lists are expected to have been generated
     in advance.
     */
    void setAutoBuildEdgeLists(bool autobuild) { mAutoBuildEdgeLists = autobuild; }
    /** Sets whether or not this Mesh should automatically build edge lists
     when asked for them, or whether it should never build them if
     they are not already provided.
     */
    bool getAutoBuildEdgeLists(){ return mAutoBuildEdgeLists; }
    
    /** Gets the type of vertex animation the shared vertex data of this mesh supports.
     */
    VertexAnimationType getSharedVertexDataAnimationType()
    {
        if (mAnimationTypesDirty)
        {
            _determineAnimationTypes();
        }
        
        return mSharedVertexDataAnimationType;
    }
    
    /// Returns whether animation on shared vertex data includes normals.
    bool getSharedVertexDataAnimationIncludesNormals(){ return mSharedVertexDataAnimationIncludesNormals; }
    
    /** Creates a new Animation object for vertex animating this mesh. 
     @param name
     The name of this animation.
     @param length
     The length of the animation in seconds.
     */
    auto ref Animation createAnimation(string name, Real length)
    {
        // Check name not used
        if ((name in mAnimationsList) !is null)
        {
            throw new DuplicateItemError(
                "An animation with the name " ~ name ~ " already exists",
                "Mesh.createAnimation");
        }
        
        Animation ret = new Animation(name, length);
        ret._notifyContainer(this);
        
        // Add to list
        mAnimationsList[name] = ret;
        
        // Mark animation types dirty
        mAnimationTypesDirty = true;
        
        return mAnimationsList[name]; //ret;
        
    }
    
    /** Returns the named vertex Animation object. 
     @param name
     The name of the animation.
     */
    Animation getAnimation(string name)
    {
        Animation ret = _getAnimationImpl(name);
        if (!ret)
        {
            throw new ItemNotFoundError(
                "No animation entry found named " ~ name,
                "Mesh.getAnimation");
        }
        
        return ret;
    }
    
    /** Internal access to the named vertex Animation object - returns null 
     if it does not exist. 
     @param name
     The name of the animation.
     */
    Animation _getAnimationImpl(string name)
    {
        Animation ret = null;
        auto i = name in mAnimationsList;
        
        if (i !is null)
        {
            ret = *i;
        }
        
        return ret;
        
    }
    
    /** Returns whether this mesh contains the named vertex animation. */
    bool hasAnimation(string name)
    {
        return _getAnimationImpl(name) !is null;
    }
    
    /** Removes vertex Animation from this mesh. */
    void removeAnimation(string name)
    {
        auto i = name in mAnimationsList;
        
        if (i is null)
        {
            throw new ItemNotFoundError( "No animation entry found named " ~ name,
                                        "Mesh.getAnimation");
        }
        
        destroy(*i);
        
        mAnimationsList.remove(name);
        
        mAnimationTypesDirty = true;
    }
    
    /** Gets the number of morph animations in this mesh. */
    ushort getNumAnimations()
    {
        return cast(ushort)(mAnimationsList.length);
    }
    
    /** Gets a single morph animation by index. 
     */
    Animation getAnimation(ushort index)
    {
        // If you hit this assert, then the index is out of bounds.
        assert( index < mAnimationsList.length );
        
        //AnimationList.const_iterator i = mAnimationsList.begin();
        //std.advance(i, index);
        
        auto i = mAnimationsList[mAnimationsList.keysAA[index]];
        
        return i;
        
    }
    
    /** Removes all morph Animations from this mesh. */
    void removeAllAnimations()
    {
        foreach (k,v; mAnimationsList)
        {
            destroy(v);
        }
        mAnimationsList.clear();
        mAnimationTypesDirty = true;
    }
    
    /** Gets a pointer to a vertex data element based on a morph animation 
     track handle.
     @remarks
     0 means the shared vertex data, 1+ means a submesh vertex data (index+1)
     */
    ref VertexData getVertexDataByTrackHandle(ushort handle)
    {
        if (handle == 0)
        {
            return sharedVertexData;
        }
        else
        {
            return getSubMesh(handle-1).vertexData;
        }
    }
    /** Iterates through all submeshes and requests them 
     to apply their texture aliases to the material they use.
     @remarks
     The submesh will only apply texture aliases to the material if matching
     texture alias names are found in the material.  If a match is found, the
     submesh will automatically clone the original material and then apply its
     texture to the new material.
     @par
     This method is normally called by the protected method loadImpl when a 
     mesh if first loaded.
     */
    void updateMaterialForAllSubMeshes()
    {
        // iterate through each sub mesh and request the submesh to update its material
        //vector<SubMesh*>::type.iterator subi;
        foreach (subi; mSubMeshList)
        {
            subi.updateMaterialUsingTextureAliases();
        }
        
    }
    
    /** Internal method which, if animation types have not been determined,
     scans any vertex animations and determines the type for each set of
     vertex data (cannot have 2 different types).
     */
    void _determineAnimationTypes()
    {
        // Don't check flag here; since detail checks on track changes are not
        // done, allow caller to force if they need to
        
        // Initialise all types to nothing
        mSharedVertexDataAnimationType = VertexAnimationType.VAT_NONE;
        mSharedVertexDataAnimationIncludesNormals = false;
        foreach (i; mSubMeshList)
        {
            i.mVertexAnimationType = VertexAnimationType.VAT_NONE;
            i.mVertexAnimationIncludesNormals = false;
        }
        
        mPosesIncludeNormals = false;
        foreach (i; mPoseList)
        {
            if (i == mPoseList[0])
                mPosesIncludeNormals = i.getIncludesNormals();
            else if (mPosesIncludeNormals != i.getIncludesNormals())
                // only support normals if consistently included
                mPosesIncludeNormals = mPosesIncludeNormals && i.getIncludesNormals();
        }
        
        // Scan all animations and determine the type of animation tracks
        // relating to each vertex data
        foreach(k, anim; mAnimationsList)
        {
            //Animation.VertexTrackIterator vit = anim.getVertexTrackIterator();
            //while (vit.hasMoreElements())
            foreach(track; anim._getVertexTrackList())
            {
                ushort handle = track.getHandle();
                if (handle == 0)
                {
                    // shared data
                    if (mSharedVertexDataAnimationType != VertexAnimationType.VAT_NONE &&
                        mSharedVertexDataAnimationType != track.getAnimationType())
                    {
                        // Mixing of morph and pose animation on same data is not allowed
                        throw new InvalidParamsError(
                            "Animation tracks for shared vertex data on mesh "
                            ~ mName ~ " try to mix vertex animation types, which is "
                            "not allowed.",
                            "Mesh._determineAnimationTypes");
                    }
                    mSharedVertexDataAnimationType = track.getAnimationType();
                    if (track.getAnimationType() == VertexAnimationType.VAT_MORPH)
                        mSharedVertexDataAnimationIncludesNormals = track.getVertexAnimationIncludesNormals();
                    else 
                        mSharedVertexDataAnimationIncludesNormals = mPosesIncludeNormals;
                    
                }
                else
                {
                    // submesh index (-1)
                    SubMesh sm = getSubMesh(handle-1);
                    if (sm.mVertexAnimationType != VertexAnimationType.VAT_NONE &&
                        sm.mVertexAnimationType != track.getAnimationType())
                    {
                        // Mixing of morph and pose animation on same data is not allowed
                        throw new InvalidParamsError(
                            "Animation tracks for dedicated vertex data "
                            ~ std.conv.to!string(handle-1) ~ " on mesh "
                            ~ mName ~ " try to mix vertex animation types, which is "
                            "not allowed.",
                            "Mesh._determineAnimationTypes");
                    }
                    sm.mVertexAnimationType = track.getAnimationType();
                    if (track.getAnimationType() == VertexAnimationType.VAT_MORPH)
                        sm.mVertexAnimationIncludesNormals = track.getVertexAnimationIncludesNormals();
                    else 
                        sm.mVertexAnimationIncludesNormals = mPosesIncludeNormals;
                    
                }
            }
        }
        
        mAnimationTypesDirty = false;
    }
    
    /** Are the derived animation types out of date? */
    bool _getAnimationTypesDirty(){ return mAnimationTypesDirty; }
    
    /** Create a new Pose for this mesh or one of its submeshes.
     @param target
     The target geometry index; 0 is the shared Mesh geometry, 1+ is the
     dedicated SubMesh geometry belonging to submesh index + 1.
     @param name
     Name to give the pose, which is optional.
     @return
     A new Pose ready for population.
     */
    ref Pose createPose(ushort target, string name = "")
    {
        Pose retPose = new Pose(target, name);
        mPoseList.insert(retPose);
        return mPoseList[$-1];//retPose;
    }
    
    /** Get the number of poses.*/
    size_t getPoseCount(){ return mPoseList.length; }
    /** Retrieve an existing Pose by index.*/
    ref Pose getPose(ushort index)
    {
        if (index >= getPoseCount())
        {
            throw new InvalidParamsError(
                "Index out of bounds",
                "Mesh.getPose");
        }
        
        return mPoseList[index];
    }
    
    /** Retrieve an existing Pose by name.*/
    Pose getPose(string name)
    {
        foreach (i; mPoseList)
        {
            if (i.getName() == name)
                return i;
        }
        
        throw new ItemNotFoundError(
            "No pose called " ~ name ~ " found in Mesh " ~ mName,
            "Mesh.getPose");
        
    }
    
    /** Destroy a pose by index.
     @note
     This will invalidate any animation tracks ref erring to this pose or those after it.
     */
    void removePose(ushort index)
    {
        if (index >= getPoseCount())
        {
            throw new InvalidParamsError(
                "Index out of bounds",
                "Mesh.removePose");
        }
        //PoseList.iterator i = mPoseList.begin();
        //std.advance(i, index);
        auto i = mPoseList[index];
        mPoseList.removeFromArrayIdx(index);
        destroy(i);
    }
    
    /** Destroy a pose by name.
     @note
     This will invalidate any animation tracks ref erring to this pose or those after it.
     */
    void removePose(string name)
    {
        foreach (i; 0..mPoseList.length)
        {
            if (mPoseList[i].getName() == name)
            {
                destroy(mPoseList[i]);
                mPoseList.removeFromArrayIdx(i);
                return;
            }
        }
        
        
        throw new ItemNotFoundError(
            "No pose called " ~ name ~ " found in Mesh " ~ mName,
            "Mesh.removePose");
    }
    
    /** Destroy all poses. */
    void removeAllPoses()
    {
        foreach (i; mPoseList)
        {
            destroy(i);
        }
        mPoseList.clear();
    }
    
    //typedef VectorIterator<PoseList> PoseIterator;
    //typedef ConstVectorIterator<PoseList> ConstPoseIterator;
    
    /** Get an iterator over all the poses defined. */
    //PoseIterator getPoseIterator();
    /** Get an iterator over all the poses defined. */
    //ConstPoseIterator getPoseIterator();
    /** Get pose list. */
    ref PoseList getPoseList()
    {
        return mPoseList;
    }
    
    /** Get lod strategy used by this mesh. */
    ref LodStrategy getLodStrategy()
    {
        return mLodStrategy;
    }
    
    /** Set the lod strategy used by this mesh. */
    void setLodStrategy(LodStrategy lodStrategy)
    {
        mLodStrategy = lodStrategy;
        
        assert(mMeshLodUsageList.length);
        mMeshLodUsageList[0].value = mLodStrategy.getBaseValue();
        
        // Re-transform user lod values (starting at index 1, no need to transform base value)
        foreach (i; mMeshLodUsageList)
            i.value = mLodStrategy.transformUserValue(i.userValue);
        
    }

    void _configureMeshLodUsage( LodConfig lodConfig )
    {
        // In theory every mesh should have a submesh.
        assert(getNumSubMeshes() > 0);
        setLodStrategy(lodConfig.strategy);
        SubMesh submesh = getSubMesh(0);
        mNumLods = cast(ushort)(submesh.mLodFaceList.length + 1);
        mMeshLodUsageList.length = mNumLods;
        for (size_t n = 0, i = 0; i < lodConfig.levels.length; i++) {
            // Record usages. First Lod usage is the mesh itself.
            
            // Skip lods, which have the same amount of vertices. No buffer generated for them.
            if (!lodConfig.levels[i].outSkipped) {
                // Generated buffers are less then the reported by ProgressiveMesh.
                // This would fail if you use QueuedProgressiveMesh and the MeshPtr is force unloaded before lod generation completes.
                assert(mMeshLodUsageList.length > n + 1);
                MeshLodUsage* lod = &mMeshLodUsageList[++n];
                lod.userValue = lodConfig.levels[i].distance;
                lod.value = getLodStrategy().transformUserValue(lod.userValue);
                lod.edgeData = null;
                lod.manualMesh.setNull();
            }
        }
        
        // TODO: Fix this in PixelCountLodStrategy::getIndex()
        // Fix bug in Ogre with pixel count Lod strategy.
        // Changes [0, 20, 15, 10, 5] to [max, 20, 15, 10, 5].
        // Fixes PixelCountLodStrategy::getIndex() function, which returned always 0 index.
        if (lodConfig.strategy == PixelCountLodStrategy.getSingleton()) {
            mMeshLodUsageList[0].userValue = Real.max;
            mMeshLodUsageList[0].value = Real.max;
        } else {
            mMeshLodUsageList[0].userValue = 0;
            mMeshLodUsageList[0].value = 0;
        }
    }
    
}

/** C++: Specialisation of SharedPtr to allow SharedPtr to be assigned to SharedPtr!Mesh 
 @note Has to be a subclass since we need operator=.
 We could templatise this instead of repeating per Resource subclass, 
 except to do so requires a form VC6 does not support i.e.
 ResourceSubclassPtr<T> : public SharedPtr<T>
 */
//alias Mesh SharedPtr!Mesh;

//alias SharedPtr!Mesh MeshPtr;
/+class _MeshPtr : SharedPtr!Mesh
{
public:
    this() {}
    this(Mesh rep) { super(rep); }
    this(ResourceSubclassPtr!Mesh r) { super(r); } 
    this(ResourceSubclassPtr!Resource r) { super(r); }

protected:
    //FIXME What destroy()?
    /// Override destroy since we need to delete Mesh after fully defined.
    /*void destroy()
    {
        // We're only overriding so that we can destroy after full definition of Mesh
        super.destroy();
    }*/
}+/

/** A way of recording the way each LODs is recorded this Mesh. */
struct MeshLodUsage
{
    /** User-supplied values used to determine when th is lod applies.
     @remarks
     This is required in case the lod strategy changes.
     */
    Real userValue;
    
    /** Value used by to determine when this lod applies.
     @remarks
     May be interpretted differently by different strategies.
     Transformed from user-supplied values with LodStrategy.transformUserValue.
     */
    Real value;
    
    /// Only relevant if mIsLodManual is true, the name of the alternative mesh to use.
    string manualName;
    /// Only relevant if mIsLodManual is true, the name of the group of the alternative mesh.
    string manualGroup;
    /// Hard link to mesh to avoid looking up each time.
    //mutable 
    SharedPtr!Mesh manualMesh;
    /// Edge list for this LOD level (may be derived from manual mesh).
    //mutable 
    EdgeData edgeData;
    
    /*this() 
     {
     userValue = 0.0;
     value = 0.0;
     edgeData = 0;
     }*/
}

/** Defines a part of a complete mesh.
 @remarks
 Meshes which make up the definition of a discrete 3D object
 are made up of potentially multiple parts. This is because
 different parts of the mesh may use different materials or
 use different vertex formats, such that a rendering state
 change is required between them.
 @par
 Like the Mesh class, instantiations of 3D objects in the scene
 share the SubMesh instances, and have the option of overriding
 their material differences on a per-object basis if required.
 See the SubEntity class for more information.
 */
class SubMesh //: public SubMeshAlloc
{
    /*friend class Mesh;
     friend class MeshSerializerImpl;
     friend class MeshSerializerImpl_v1_2;
     friend class MeshSerializerImpl_v1_1;*/
package:

    ///For friendlies
    VertexBoneAssignmentList _getBoneAssignments() @property
    { return mBoneAssignments; }

    AliasTextureNamePairList _getTextureAliases() @property
    {
        return mTextureAliases;
    }

public:
    this()
    {
        useSharedVertices = true;
        operationType = RenderOperation.OperationType.OT_TRIANGLE_LIST;
        //vertexData = null;
        mMatInitialised = false;
        mBoneAssignmentsOutOfDate = false;
        mVertexAnimationType = VertexAnimationType.VAT_NONE;
        mVertexAnimationIncludesNormals = false;
        mBuildEdgesEnabled = true;
        
        indexData = new IndexData();
    }
    ~this()
    {
        destroy(vertexData);
        destroy(indexData);
        
        removeLodLevels();
    }


    /// Indicates if this submesh shares vertex data with other meshes or whether it has it's own vertices.
    bool useSharedVertices;
    
    /// The render operation type used to render this submesh
    RenderOperation.OperationType operationType;
    
    /** Dedicated vertex data (only valid if useSharedVertices = false).
     @remarks
     This data is completely owned by this submesh.
     @par
     The use of shared or non-shared buffers is determined when
     model data is converted to the OGRE .mesh format.
     */
    VertexData vertexData;
    
    /// Face index data
    IndexData indexData;
    
    /** Dedicated index map for translate blend index to bone index (only valid if useSharedVertices = false).
     @remarks
     This data is completely owned by this submesh.
     @par
     We collect actually used bones of all bone assignments, and build the
     blend index in 'packed' form, then the range of the blend index in vertex
     data VES_BLEND_INDICES element is continuous, with no gaps. Thus, by
     minimising the world matrix array constants passing to GPU, we can support
     more bones for a mesh when hardware skinning is used. The hardware skinning
     support limit is applied to each set of vertex data in the mesh, in other words, the
     hardware skinning support limit is applied only to the actually used bones of each
     SubMeshes, not all bones across the entire Mesh.
     @par
     Because the blend index is different to the bone index, Therefore, we use
     the index map to translate the blend index to bone index.
     @par
     The use of shared or non-shared index map is determined when
     model data is converted to the OGRE .mesh format.
     */
    //typedef vector<ushort>::type IndexMap;
    alias ushort[] IndexMap;
    IndexMap blendIndexToBoneIndexMap;
    
    //typedef vector<IndexData*>::type LODFaceList;
    alias IndexData[] LODFaceList;
    LODFaceList mLodFaceList;
    
    /** A list of extreme points on the submesh (optional).
     @remarks
     These points are some arbitrary points on the mesh that are used
     by engine to better sort submeshes by depth. This doesn't matter
     much for non-transparent submeshes, as Z-buffer takes care of invisible
     surface culling anyway, but is pretty useful for semi-transparent
     submeshes because the order in which transparent submeshes must be
     rendered cannot be always correctly deduced from entity position.
     @par
     These points are intelligently chosen from the points that make up
     the submesh, the criteria for choosing them should be that these points
     somewhat characterize the submesh outline, e.g. they should not be
     close to each other, and they should be on the outer hull of the submesh.
     They can be stored in the .mesh file, or generated at runtime
     (see generateExtremes ()).
     @par
     If this array is empty, submesh sorting is done like in older versions -
     by comparing the positions of the owning entity.
     */
    //vector<Vector3>::type extremityPoints;
    Vector3[] extremityPoints;
    
    /// Reference to parent Mesh (not a smart pointer so child does not keep parent alive).
    Mesh parent;
    
    /// Sets the name of the Material which this SubMesh will use
    void setMaterialName(string matName, string groupName = ResourceGroupManager.AUTODETECT_RESOURCE_GROUP_NAME )
    {
        mMaterialName = matName;
        mMatInitialised = true;
    }
    
    string getMaterialName()
    {
        return mMaterialName;
    }
    
    /** Returns true if a material has been assigned to the submesh, otherwise returns false.
     */
    bool isMatInitialised()
    {
        return mMatInitialised;
    }
    
    /** Returns a RenderOperation structure required to render this mesh.
     @param 
     rend Reference to a RenderOperation structure to populate.
     @param
     lodIndex The index of the LOD to use. 
     */
    void _getRenderOperation(ref RenderOperation ro, ushort lodIndex = 0)
    {
        
        ro.useIndexes = indexData.indexCount != 0;
        if (lodIndex > 0 && cast(size_t)( lodIndex - 1 ) < mLodFaceList.length)
        {
            // lodIndex - 1 because we don't store full detail version in mLodFaceList
            ro.indexData = mLodFaceList[lodIndex-1];
        }
        else
        {
            ro.indexData = indexData;
        }
        ro.operationType = operationType;
        ro.vertexData = useSharedVertices? parent.sharedVertexData : vertexData;
        
    }
    
    /** Assigns a vertex to a bone with a given weight, for skeletal animation. 
     @remarks    
     This method is only valid after calling setSkeletonName.
     Since this is a one-off process there exists only 'addBoneAssignment' and
     'clearBoneAssignments' methods, no 'editBoneAssignment'. You should not need
     to modify bone assignments during rendering (only the positions of bones) and OGRE
     reserves the right to do some internal data ref ormatting of this information, depending
     on render system requirements.
     @par
     This method is for assigning weights to the dedicated geometry of the SubMesh. To assign
     weights to the shared Mesh geometry, see the equivalent methods on Mesh.
     */
    void addBoneAssignment(VertexBoneAssignment vertBoneAssign)
    {
        if (useSharedVertices)
        {
            throw new InvalidParamsError("This SubMesh uses shared geometry,  you " ~
                                         "must assign bones to the Mesh, not the SubMesh", "SubMesh.addBoneAssignment");
        }
        mBoneAssignments.initAA(vertBoneAssign.vertexIndex);
        mBoneAssignments[vertBoneAssign.vertexIndex].insert(vertBoneAssign);
        mBoneAssignmentsOutOfDate = true;
    }
    
    /** Removes all bone assignments for this mesh. 
     @par
     This method is for assigning weights to the dedicated geometry of the SubMesh. To assign
     weights to the shared Mesh geometry, see the equivalent methods on Mesh.
     */
    void clearBoneAssignments()
    {
        mBoneAssignments.clear();
        mBoneAssignmentsOutOfDate = true;
    }
    
    /// Multimap of verex bone assignments (orders by vertex index)
    //typedef multimap<size_t, VertexBoneAssignment>::type VertexBoneAssignmentList;
    alias VertexBoneAssignment[][size_t] VertexBoneAssignmentList;
    //typedef MapIterator<VertexBoneAssignmentList> BoneAssignmentIterator;
    
    /** Gets an iterator for access all bone assignments. 
     @remarks
     Only valid if this SubMesh has dedicated geometry.
     */
    //BoneAssignmentIterator getBoneAssignmentIterator();
    
    /** Gets areference to the list of bone assignments
     */
    ref VertexBoneAssignmentList getBoneAssignments() { return mBoneAssignments; }
    
    
    /** Must be called once to compile bone assignments into geometry buffer. */
    void _compileBoneAssignments()
    {
        ushort maxBones =
            parent._rationaliseBoneAssignments(vertexData.vertexCount, mBoneAssignments);
        
        if (maxBones != 0)
        {
            parent.compileBoneAssignments(mBoneAssignments, maxBones, 
                                          blendIndexToBoneIndexMap, vertexData);
        }
        
        mBoneAssignmentsOutOfDate = false;
    }
    
    //typedef ConstMapIterator<AliasTextureNamePairList> AliasTextureIterator;
    /** Gets an constant iterator to access all texture alias names assigned to this submesh. 

     */
    //AliasTextureIterator getAliasTextureIterator();
    ref AliasTextureNamePairList getAliasTextures()
    {
        return mTextureAliases;
    }
    
    /** Adds the alias or replaces an existing one and associates the texture name to it.
     @remarks
     The submesh uses the texture alias to replace textures used in the material applied
     to the submesh.
     @param
     aliasName is the name of the alias.
     @param
     textureName is the name of the texture to be associated with the alias

     */
    void addTextureAlias(string aliasName, string textureName)
    {
        mTextureAliases[aliasName] = textureName;
    }
    /** Remove a specific texture alias name from the sub mesh
     @param
     aliasName is the name of the alias to be removed.  If it is not found 
     then it is ignored.
     */
    void removeTextureAlias(string aliasName)
    {
        mTextureAliases.remove(aliasName);
    }
    /** removes all texture aliases from the sub mesh
     */
    void removeAllTextureAliases()
    {
        mTextureAliases.clear();
    }
    /** returns true if the sub mesh has texture aliases
     */
    bool hasTextureAliases(){ return !mTextureAliases.length == 0; }
    /** Gets the number of texture aliases assigned to the sub mesh.
     */
    size_t getTextureAliasCount(){ return mTextureAliases.length; }
    
    /**  The current material used by the submesh is copied into a new material
     and the submesh's texture aliases are applied if the current texture alias
     names match those found in the original material.
     @remarks
     The submesh's texture aliases must be setup prior to calling this method.
     If a new material has to be created, the subMesh autogenerates the new name.
     The new name is the old name + "_" + number.
     @return 
     True if texture aliases were applied and a new material was created.
     */
    bool updateMaterialUsingTextureAliases()
    {
        bool newMaterialCreated = false;
        // if submesh has texture aliases
        // ask the material manager if the current summesh material exists
        if (hasTextureAliases() && MaterialManager.getSingleton().resourceExists(mMaterialName))
        {
            // get the current submesh material
            SharedPtr!Material material = MaterialManager.getSingleton().getByName( mMaterialName );
            // get test result for if change will occur when the texture aliases are applied
            if (material.getAs().applyTextureAliases(mTextureAliases, false))
            {
                string newMaterialName;
                
                // If this material was already derived from another material
                // due to aliasing, let's strip off the aliasing suffix and
                // generate a new one using our current aliasing table.
                
                ptrdiff_t pos = mMaterialName.indexOf("?TexAlias(");
                if( pos != -1 )
                    newMaterialName = mMaterialName[0..pos];
                else
                    newMaterialName = mMaterialName;
                
                newMaterialName ~= "?TexAlias(";
                // Iterate deterministically over the aliases (always in the same
                // order via std.map's sorted iteration nature).
                auto aliasIter = getAliasTextures();
                foreach(k,v; aliasIter)
                {
                    newMaterialName ~= k;
                    newMaterialName ~= "=";
                    newMaterialName ~= v;
                    newMaterialName ~= " ";
                }
                newMaterialName ~= ")";
                
                // Reuse the material if it's already been created. This decreases batch
                // count and keeps material explosion under control.
                if(!MaterialManager.getSingleton().resourceExists(newMaterialName))
                {
                    SharedPtr!Material newMaterial = MaterialManager.getSingleton().create(
                        newMaterialName, material.getAs().getGroup());
                    // copy parent material details to new material
                    material.getAs().copyDetailsTo(newMaterial);
                    // apply texture aliases to new material
                    newMaterial.getAs().applyTextureAliases(mTextureAliases);
                }
                // place new material name in submesh
                setMaterialName(newMaterialName);
                newMaterialCreated = true;
            }
        }
        
        return newMaterialCreated;
    }
    
    /** Get the type of any vertex animation used by dedicated geometry.
     */
    VertexAnimationType getVertexAnimationType()
    {
        if(parent._getAnimationTypesDirty())
        {
            parent._determineAnimationTypes();
        }
        return mVertexAnimationType;
    }
    
    /// Returns whether animation on dedicated vertex data includes normals
    bool getVertexAnimationIncludesNormals(){ return mVertexAnimationIncludesNormals; }
    
    
    /* To find as many points from different domains as we need,
     * such that those domains are from different parts of the mesh,
     * we implement a simplified Heckbert quantization algorithm.
     *
     * This struct is like AxisAlignedBox with some specialized methods
     * for doing quantization.
     */
    struct Cluster
    {
        Vector3 mMin, mMax;
        //set<uint>::type mIndices;
        uint[] mIndices;
        
        
        bool empty ()
        {
            if (mIndices.length == 0)
                return true;
            if (mMin == mMax)
                return true;
            return false;
        }
        
        float volume ()
        {
            return (mMax.x - mMin.x) * (mMax.y - mMin.y) * (mMax.z - mMin.z);
        }
        
        void extend (float *v)
        {
            if (v [0] < mMin.x) mMin.x = v [0];
            if (v [1] < mMin.y) mMin.y = v [1];
            if (v [2] < mMin.z) mMin.z = v [2];
            if (v [0] > mMax.x) mMax.x = v [0];
            if (v [1] > mMax.y) mMax.y = v [1];
            if (v [2] > mMax.z) mMax.z = v [2];
        }
        
        void computeBBox (ref VertexElement poselem, ubyte *vdata, size_t vsz)
        {
            mMin.x = mMin.y = mMin.z = Math.POS_INFINITY;
            mMax.x = mMax.y = mMax.z = Math.NEG_INFINITY;
            
            foreach (i; mIndices)
            {
                float *v;
                poselem.baseVertexPointerToElement (vdata + i * vsz, &v);
                extend (v);
            }
        }
        
        Cluster split (int split_axis, ref VertexElement poselem,
                       ubyte *vdata, size_t vsz)
        {
            Real r = (mMin [split_axis] + mMax [split_axis]) * 0.5f;
            Cluster newbox;
            
            // Separate all points that are inside the new bbox
            foreach (i; 0..mIndices.length)
            {
                float *v;
                poselem.baseVertexPointerToElement (vdata + mIndices[i] * vsz, &v);
                if (v [split_axis] > r)
                {
                    newbox.mIndices.insert (mIndices[i]);
                    //set<uint>::type.iterator x = i++;
                    mIndices.removeFromArrayIdx(i);
                }
            }
            
            computeBBox (poselem, vdata, vsz);
            newbox.computeBBox (poselem, vdata, vsz);
            
            return newbox;
        }
    }
    
    /** Generate the submesh extremes (@see extremityPoints).
     @param count
     Number of extreme points to compute for the submesh.
     */
    void generateExtremes(size_t count)
    {
        extremityPoints.clear();
        
        /* Currently this uses just one criteria: the points must be
         * as far as possible from each other. This at least ensures
         * that the extreme points characterise the submesh as
         * detailed as it's possible.
         */
        
        VertexData vert = useSharedVertices ? parent.sharedVertexData : vertexData;
        VertexElement poselem = vert.vertexDeclaration.findElementBySemantic (VertexElementSemantic.VES_POSITION);
        SharedPtr!HardwareVertexBuffer vbuf = vert.vertexBufferBinding.getBuffer (poselem.getSource ());
        ubyte *vdata = cast(ubyte *)vbuf.get().lock (HardwareBuffer.LockOptions.HBL_READ_ONLY);
        size_t vsz = vbuf.get().getVertexSize ();
        
        //vector<Cluster>::type boxes;
        Cluster[] boxes;
        //boxes.reserve (count);
        
        // First of all, find min and max bounding box of the submesh
        boxes.insert (Cluster ());
        
        if (indexData.indexCount > 0)
        {
            
            uint elsz = indexData.indexBuffer.get().getType () == HardwareIndexBuffer.IndexType.IT_32BIT ? 4 : 2;
            ubyte *idata = cast(ubyte *)indexData.indexBuffer.get().lock (
                indexData.indexStart * elsz, indexData.indexCount * elsz,
                HardwareIndexBuffer.LockOptions.HBL_READ_ONLY);
            
            for (size_t i = 0; i < indexData.indexCount; i++)
            {
                uint idx = (elsz == 2) ? (cast(ushort *)idata) [i] : (cast(uint *)idata) [i];
                boxes [0].mIndices.insert (idx);
            }
            indexData.indexBuffer.get().unlock ();
            
        }
        else
        {
            // just insert all indexes
            for (size_t i = vertexData.vertexStart; i < vertexData.vertexCount; i++)
            {
                boxes [0].mIndices.insert (cast(uint)i);
            }
            
        }
        
        boxes [0].computeBBox (poselem, vdata, vsz);
        
        // Remember the geometrical center of the submesh
        Vector3 center = (boxes [0].mMax + boxes [0].mMin) * 0.5;
        
        // Ok, now loop until we have as many boxes, as we need extremes
        while (boxes.length < count)
        {
            // Find the largest box with more than one vertex :)
            Cluster *split_box = null;
            Real split_volume = -1;
            foreach (b; boxes)
            {
                if (b.empty ())
                    continue;
                Real v = b.volume ();
                if (v > split_volume)
                {
                    split_volume = v;
                    split_box = &b;
                }
            }
            
            // If we don't have what to split, break
            if (split_box is null)
                break;
            
            // Find the coordinate axis to split the box into two
            int split_axis = 0;
            Real split_length = split_box.mMax.x - split_box.mMin.x;
            for (int i = 1; i < 3; i++)
            {
                Real l = split_box.mMax [i] - split_box.mMin [i];
                if (l > split_length)
                {
                    split_length = l;
                    split_axis = i;
                }
            }
            
            // Now split the box into halves
            boxes.insert (split_box.split (split_axis, poselem, vdata, vsz));
        }
        
        // Fine, now from every cluster choose the vertex that is most
        // distant from the geometrical center and from other extremes.
        foreach (b; boxes)
        {
            Real rating = 0;
            Vector3 best_vertex;
            
            foreach (i; b.mIndices)
            {
                float *v;
                poselem.baseVertexPointerToElement (vdata + i * vsz, &v);
                
                auto vv = Vector3(v [0], v [1], v [2]);
                Real r = (vv - center).squaredLength ();
                
                foreach (e; extremityPoints)
                    r += (e - vv).squaredLength ();
                
                if (r > rating)
                {
                    rating = r;
                    best_vertex = vv;
                }
            }
            
            if (rating > 0)
                extremityPoints.insert (best_vertex);
        }
        
        vbuf.get().unlock ();
    }
    
    /** Returns true(by default) if the submesh should be included in the mesh EdgeList, otherwise returns false.
     */      
    bool isBuildEdgesEnabled(){ return mBuildEdgesEnabled; }
    void setBuildEdgesEnabled(bool b)
    {
        mBuildEdgesEnabled = b;
        if(parent)
        {
            parent.freeEdgeList();
            parent.setAutoBuildEdgeLists(true);
        }
    }
    
protected:
    
    /// Name of the material this SubMesh uses.
    string mMaterialName;
    
    /// Is there a material yet?
    bool mMatInitialised;
    
    /// paired list of texture aliases and texture names
    AliasTextureNamePairList mTextureAliases;
    
    VertexBoneAssignmentList mBoneAssignments;
    
    /// Flag indicating that bone assignments need to be recompiled
    bool mBoneAssignmentsOutOfDate;
    
    /// Type of vertex animation for dedicated vertex data (populated by Mesh)
    //mutable 
    VertexAnimationType mVertexAnimationType;
    
    /// Whether normals are included in vertex animation keyframes
    //mutable 
    bool mVertexAnimationIncludesNormals;
    
    /// Is Build Edges Enabled
    bool mBuildEdgesEnabled;
    
    /// Internal method for removing LOD data
    void removeLodLevels()
    {
        foreach (lod; mLodFaceList)
        {
            destroy(lod);
        }
        
        mLodFaceList.clear();
        
    }
}

//TODO Check that structs are 'pointered' (like '&edgeData.triangles') or they remove 'zeroed'

/// stream overhead = ID + size
enum int MSTREAM_OVERHEAD_SIZE = ushort.sizeof + uint.sizeof;

/** Internal implementation of Mesh reading / writing for the latest version of the
 .mesh format.
 @remarks
 In order to maintain compatibility with older versions of the .mesh format, there
 will be alternative subclasses of this class to load older versions, whilst this class
 will remain to load the latest version.

 @note
 This mesh format was used from Ogre v1.8.

 */
class MeshSerializerImpl : Serializer
{
public:
    this()
    {
        // Version number
        mVersion = "[MeshSerializer_v1.8]";
    }
    ~this(){}
    
    /** Exports a mesh to the file specified. 
     @remarks
     This method takes an externally created Mesh object, and exports both it
     and optionally the Materials it uses to a .mesh file.
     @param pMesh Pointer to the Mesh to export
     @param stream The destination stream
     @param endianMode The endian mode for the written file
     */
    void exportMesh(Mesh pMesh, DataStream stream,
                    Endian endianMode = Endian.ENDIAN_NATIVE)
    {
        LogManager.getSingleton().logMessage("MeshSerializer writing mesh data to stream " ~ stream.getName() ~ "...");
        
        // Decide on endian mode
        determineEndianness(endianMode);
        
        // Check that the mesh has it's bounds set
        if (pMesh.getBounds().isNull() || pMesh.getBoundingSphereRadius() == 0.0f)
        {
            throw new InvalidParamsError("The Mesh you have supplied does not have its"~
                                         " bounds completely defined. Define them first before exporting.",
                                         "MeshSerializerImpl.exportMesh");
        }
        mStream = stream;
        if (!stream.isWriteable())
        {
            throw new InvalidParamsError(
                "Unable to use stream " ~ stream.getName() ~ " for writing",
                "MeshSerializerImpl.exportMesh");
        }
        
        writeFileHeader();
        LogManager.getSingleton().logMessage("File header written.");
        
        
        LogManager.getSingleton().logMessage("Writing mesh data...");
        writeMesh(pMesh);
        LogManager.getSingleton().logMessage("Mesh data exported.");
        
        LogManager.getSingleton().logMessage("MeshSerializer export successful.");
    }
    
    /** Imports Mesh and (optionally) Material data from a .mesh file DataStream.
     @remarks
     This method imports data from a DataStream opened from a .mesh file and places it's
     contents into the Mesh object which is passed in. 
     @param stream The DataStream holding the .mesh data. Must be initialised (pos at the start of the buffer).
     @param pDest Pointer to the Mesh object which will receive the data. Should be blank already.
     */
    void importMesh(DataStream stream, ref Mesh pDest, ref MeshSerializerListener listener)
    {
        // Determine endianness (must be the first thing we do!)
        determineEndianness(stream);
        
        // Check header
        readFileHeader(stream);
        
        ushort streamID;
        while(!stream.eof())
        {
            streamID = readChunk(stream);
            switch (streamID)
            {
                case MeshChunkID.M_MESH:
                    readMesh(stream, pDest, listener);
                    break;
                default:
                    break;
            }
            
        }
    }
    
protected:
    
    // Internal methods
    // Added by DrEvil
    void writeSubMeshNameTable(Mesh pMesh)
    {
        // Header
        writeChunkHeader(MeshChunkID.M_SUBMESH_NAME_TABLE, calcSubMeshNameTableSize(pMesh));
        
        // Loop through and save out the index and names.
        foreach(k,v; pMesh.mSubMeshNameMap)
        {
            // Header
            writeChunkHeader(MeshChunkID.M_SUBMESH_NAME_TABLE_ELEMENT, MSTREAM_OVERHEAD_SIZE +
                             ushort.sizeof + k.length + 1);
            
            // write the index
            writeShorts(&v, 1);
            // name
            writeString(k);
        }
    }
    
    void writeMesh(Mesh pMesh)
    {
        // Header
        writeChunkHeader(MeshChunkID.M_MESH, calcMeshSize(pMesh));
        
        // bool skeletallyAnimated
        bool skelAnim = pMesh.hasSkeleton();
        writeBools(&skelAnim, 1);
        
        // Write shared geometry
        if (pMesh.sharedVertexData)
            writeGeometry(pMesh.sharedVertexData);
        
        // Write Submeshes
        for (ushort i = 0; i < pMesh.getNumSubMeshes(); ++i)
        {
            LogManager.getSingleton().logMessage("Writing submesh...");
            writeSubMesh(pMesh.getSubMesh(i));
            LogManager.getSingleton().logMessage("Submesh exported.");
        }
        
        // Write skeleton info if required
        if (pMesh.hasSkeleton())
        {
            LogManager.getSingleton().logMessage("Exporting skeleton link...");
            // Write skeleton link
            writeSkeletonLink(pMesh.getSkeletonName());
            LogManager.getSingleton().logMessage("Skeleton link exported.");
            
            // Write bone assignments
            if (!pMesh.mBoneAssignments.emptyAA())
            {
                LogManager.getSingleton().logMessage("Exporting shared geometry bone assignments...");
                
                foreach (k,v; pMesh.mBoneAssignments)
                {
                    foreach(bone; v)
                        writeMeshBoneAssignment(bone);
                }
                
                LogManager.getSingleton().logMessage("Shared geometry bone assignments exported.");
            }
        }
        
        // Write LOD data if any
        if (pMesh.getNumLodLevels() > 1)
        {
            LogManager.getSingleton().logMessage("Exporting LOD information....");
            writeLodInfo(pMesh);
            LogManager.getSingleton().logMessage("LOD information exported.");
            
        }
        // Write bounds information
        LogManager.getSingleton().logMessage("Exporting bounds information....");
        writeBoundsInfo(pMesh);
        LogManager.getSingleton().logMessage("Bounds information exported.");
        
        // Write submesh name table
        LogManager.getSingleton().logMessage("Exporting submesh name table...");
        writeSubMeshNameTable(pMesh);
        LogManager.getSingleton().logMessage("Submesh name table exported.");
        
        // Write edge lists
        if (pMesh.isEdgeListBuilt())
        {
            LogManager.getSingleton().logMessage("Exporting edge lists...");
            writeEdgeList(pMesh);
            LogManager.getSingleton().logMessage("Edge lists exported");
        }
        
        // Write morph animation
        writePoses(pMesh);
        if (pMesh.hasVertexAnimation())
        {
            writeAnimations(pMesh);
        }
        
        // Write submesh extremes
        writeExtremes(pMesh);
    }
    
    void writeSubMesh(SubMesh s)
    {
        // Header
        writeChunkHeader(MeshChunkID.M_SUBMESH, calcSubMeshSize(s));
        
        // char* materialName
        writeString(s.getMaterialName());
        
        // bool useSharedVertices
        writeBools(&s.useSharedVertices, 1);
        
        uint indexCount = cast(uint)s.indexData.indexCount;
        writeInts(&indexCount, 1);
        
        // bool indexes32Bit
        bool idx32bit = (!s.indexData.indexBuffer.isNull() &&
                         s.indexData.indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_32BIT);
        writeBools(&idx32bit, 1);
        
        if (indexCount > 0)
        {
            // ushort* faceVertexIndices ((indexCount)
            SharedPtr!HardwareIndexBuffer ibuf = s.indexData.indexBuffer;
            void* pIdx = ibuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY);
            if (idx32bit)
            {
                uint* pIdx32 = cast(uint*)(pIdx);
                writeInts(pIdx32, s.indexData.indexCount);
            }
            else
            {
                ushort* pIdx16 = cast(ushort*)(pIdx);
                writeShorts(pIdx16, s.indexData.indexCount);
            }
            ibuf.get().unlock();
        }
        
        // M_GEOMETRY stream (Optional: present only if useSharedVertices = false)
        if (!s.useSharedVertices)
        {
            writeGeometry(s.vertexData);
        }
        
        // end of sub mesh chunk
        
        // write out texture alias chunks
        writeSubMeshTextureAliases(s);
        
        // Operation type
        writeSubMeshOperation(s);
        
        // Bone assignments
        if (!s.mBoneAssignments.emptyAA())
        {
            LogManager.getSingleton().logMessage("Exporting dedicated geometry bone assignments...");
            
            foreach (k,v; s.mBoneAssignments)
            {
                foreach(bone; v)
                    writeSubMeshBoneAssignment(bone);
            }
            
            LogManager.getSingleton().logMessage("Dedicated geometry bone assignments exported.");
        }
        
        
    }
    
    void writeSubMeshOperation(SubMesh sm)
    {
        // Header
        writeChunkHeader(MeshChunkID.M_SUBMESH_OPERATION, calcSubMeshOperationSize(sm));
        
        // ushort operationType
        ushort opType = cast(ushort)(sm.operationType);
        writeShorts(&opType, 1);
    }
    
    void writeSubMeshTextureAliases(SubMesh s)
    {
        size_t chunkSize;
        
        LogManager.getSingleton().logMessage("Exporting submesh texture aliases...");
        
        // iterate through texture aliases and write them out as a chunk
        foreach (k,v; s.mTextureAliases)
        {
            // calculate chunk size based on string length + 1.  Add 1 for the line feed.
            chunkSize = MSTREAM_OVERHEAD_SIZE + k.length + v.length + 2;
            writeChunkHeader(MeshChunkID.M_SUBMESH_TEXTURE_ALIAS, chunkSize);
            // write out alias name
            writeString(k);
            // write out texture name
            writeString(v);
        }
        
        LogManager.getSingleton().logMessage("Submesh texture aliases exported.");
    }
    
    void writeGeometry(VertexData vertexData)
    {
        // calc size
        auto elemList = vertexData.vertexDeclaration.getElements();
        VertexBufferBinding.VertexBufferBindingMap bindings = vertexData.vertexBufferBinding.getBindings();
        
        size_t size = MSTREAM_OVERHEAD_SIZE + uint.sizeof + // base
            (MSTREAM_OVERHEAD_SIZE + elemList.length * (MSTREAM_OVERHEAD_SIZE + ushort.sizeof * 5)); // elements
        
        foreach (k,vbuf; bindings)
        {
            size += (MSTREAM_OVERHEAD_SIZE * 2) + (ushort.sizeof * 2) + vbuf.get().getSizeInBytes();
        }
        
        // Header
        writeChunkHeader(MeshChunkID.M_GEOMETRY, size);
        
        uint vertexCount = cast(uint)vertexData.vertexCount;
        writeInts(&vertexCount, 1);
        
        // Vertex declaration
        size = MSTREAM_OVERHEAD_SIZE + elemList.length * (MSTREAM_OVERHEAD_SIZE + ushort.sizeof * 5);
        writeChunkHeader(MeshChunkID.M_GEOMETRY_VERTEX_DECLARATION, size);
        
        
        ushort tmp;
        size = MSTREAM_OVERHEAD_SIZE + ushort.sizeof * 5;
        foreach (elem; elemList)
        {
            writeChunkHeader(MeshChunkID.M_GEOMETRY_VERTEX_ELEMENT, size);
            // ushort source;   // buffer bind source
            tmp = elem.getSource();
            writeShorts(&tmp, 1);
            // ushort type;     // VertexElementType
            tmp = cast(ushort)(elem.getType());
            writeShorts(&tmp, 1);
            // ushort semantic; // VertexElementSemantic
            tmp = cast(ushort)(elem.getSemantic());
            writeShorts(&tmp, 1);
            // ushort offset;   // start offset in buffer in bytes
            tmp = cast(ushort)(elem.getOffset());
            writeShorts(&tmp, 1);
            // ushort index;    // index of the semantic (for colours and texture coords)
            tmp = elem.getIndex();
            writeShorts(&tmp, 1);
            
        }
        
        // Buffers and bindings
        foreach (k,vbuf; bindings)
        {
            size = (MSTREAM_OVERHEAD_SIZE * 2) + (ushort.sizeof * 2) + vbuf.get().getSizeInBytes();
            writeChunkHeader(MeshChunkID.M_GEOMETRY_VERTEX_BUFFER,  size);
            // ushort bindIndex;    // Index to bind this buffer to
            tmp = k;
            writeShorts(&tmp, 1);
            // ushort vertexSize;   // Per-vertex size, must agree with declaration at this index
            tmp = cast(ushort)vbuf.get().getVertexSize();
            writeShorts(&tmp, 1);
            
            // Data
            size = MSTREAM_OVERHEAD_SIZE + vbuf.get().getSizeInBytes();
            writeChunkHeader(MeshChunkID.M_GEOMETRY_VERTEX_BUFFER_DATA, size);
            void* pBuf = vbuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY);
            
            if (mFlipEndian)
            {
                // endian conversion
                // Copy data
                //unsigned char* tempData = OGRE_ALLOC_T(unsigned char, vbuf.getSizeInBytes(), MEMCATEGORY_GEOMETRY);
                ubyte[] tempData = new ubyte[vbuf.get().getSizeInBytes()];
                memcpy(tempData.ptr, pBuf, vbuf.get().getSizeInBytes());
                flipToLittleEndian(
                    tempData.ptr,
                    vertexData.vertexCount,
                    vbuf.get().getVertexSize(),
                    vertexData.vertexDeclaration.findElementsBySource(k));
                writeData(tempData.ptr, vbuf.get().getVertexSize(), vertexData.vertexCount);
                destroy(tempData);
            }
            else
            {
                writeData(pBuf, vbuf.get().getVertexSize(), vertexData.vertexCount);
            }
            vbuf.get().unlock();
        }
        
        
    }
    
    void writeSkeletonLink(string skelName)
    {
        writeChunkHeader(MeshChunkID.M_MESH_SKELETON_LINK, calcSkeletonLinkSize(skelName));
        
        writeString(skelName);
        
    }
    
    void writeMeshBoneAssignment(VertexBoneAssignment assign)
    {
        writeChunkHeader(MeshChunkID.M_MESH_BONE_ASSIGNMENT, calcBoneAssignmentSize());
        
        // uint vertexIndex;
        writeInts(&(assign.vertexIndex), 1);
        // ushort boneIndex;
        writeShorts(&(assign.boneIndex), 1);
        // float weight;
        writeFloats(&(assign.weight), 1);
    }
    
    void writeSubMeshBoneAssignment(VertexBoneAssignment assign)
    {
        writeChunkHeader(MeshChunkID.M_SUBMESH_BONE_ASSIGNMENT, calcBoneAssignmentSize());
        
        // uint vertexIndex;
        writeInts(&(assign.vertexIndex), 1);
        // ushort boneIndex;
        writeShorts(&(assign.boneIndex), 1);
        // float weight;
        writeFloats(&(assign.weight), 1);
    }
    
    void writeLodInfo(Mesh pMesh)
    {
        LodStrategy strategy = pMesh.getLodStrategy();
        ushort numLods = pMesh.getNumLodLevels();
        bool manual = pMesh.isLodManual();
        writeLodSummary(numLods, manual, strategy);
        
        // Loop from LOD 1 (not 0, this is full detail)
        for (ushort i = 1; i < numLods; ++i)
        {
            MeshLodUsage usage = pMesh.getLodLevel(i);
            if (manual)
            {
                writeLodUsageManual(usage);
            }
            else
            {
                writeLodUsageGenerated(pMesh, usage, i);
            }
        }
    }
    
    void writeLodSummary(ushort numLevels, bool manual, ref LodStrategy strategy)
    {
        // Header
        size_t size = MSTREAM_OVERHEAD_SIZE;
        // ushort numLevels;
        size += ushort.sizeof;
        // bool manual;  (true for manual alternate meshes, false for generated)
        size += bool.sizeof;
        writeChunkHeader(MeshChunkID.M_MESH_LOD, size);
        
        // Details
        // string strategyName;
        writeString(strategy.getName());
        // ushort numLevels;
        writeShorts(&numLevels, 1);
        // bool manual;  (true for manual alternate meshes, false for generated)
        writeBools(&manual, 1);
    }
    
    void writeLodUsageManual(MeshLodUsage usage)
    {
        // Header
        size_t size = MSTREAM_OVERHEAD_SIZE;
        size_t manualSize = MSTREAM_OVERHEAD_SIZE;
        // float lodValue;
        size += float.sizeof;
        // Manual part size
        
        // string manualMeshName;
        manualSize += usage.manualName.length + 1;
        
        size += manualSize;
        
        writeChunkHeader(MeshChunkID.M_MESH_LOD_USAGE, size);
        writeFloats(&(usage.userValue), 1);
        
        writeChunkHeader(MeshChunkID.M_MESH_LOD_MANUAL, manualSize);
        writeString(usage.manualName);
    }
    
    void writeLodUsageGenerated(Mesh pMesh, ref MeshLodUsage usage, ushort lodNum)
    {
        // Usage Header
        size_t size = MSTREAM_OVERHEAD_SIZE;
        ushort subidx;
        
        // float fromDepthSquared;
        size += float.sizeof;
        
        // Calc generated SubMesh sections size
        for(subidx = 0; subidx < pMesh.getNumSubMeshes(); ++subidx)
        {
            // header
            size += MSTREAM_OVERHEAD_SIZE;
            // uint numFaces;
            size += uint.sizeof;
            SubMesh sm = pMesh.getSubMesh(subidx);
            IndexData indexData = sm.mLodFaceList[lodNum - 1];
            
            // bool indexes32Bit
            size += bool.sizeof;
            // ushort*/int* faceIndexes;
            if (!indexData.indexBuffer.isNull() &&
                indexData.indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_32BIT)
            {
                size += cast(ulong)(uint.sizeof * indexData.indexCount);
            }
            else
            {
                size += cast(ulong)(ushort.sizeof * indexData.indexCount);
            }
            
        }
        
        writeChunkHeader(MeshChunkID.M_MESH_LOD_USAGE, size);
        writeFloats(&(usage.userValue), 1);
        
        // Now write sections
        // Calc generated SubMesh sections size
        for(subidx = 0; subidx < pMesh.getNumSubMeshes(); ++subidx)
        {
            size = MSTREAM_OVERHEAD_SIZE;
            // uint numFaces;
            size += uint.sizeof;
            SubMesh sm = pMesh.getSubMesh(subidx);
            IndexData indexData = sm.mLodFaceList[lodNum - 1];
            // bool indexes32Bit
            size += bool.sizeof;
            // Lock index buffer to write
            SharedPtr!HardwareIndexBuffer ibuf = indexData.indexBuffer;
            // bool indexes32bit
            bool idx32 = (!ibuf.isNull() && ibuf.get().getType() == HardwareIndexBuffer.IndexType.IT_32BIT);
            // ushort*/int* faceIndexes;
            if (idx32)
            {
                size += cast(ulong)(uint.sizeof * indexData.indexCount);
            }
            else
            {
                size += cast(ulong)(ushort.sizeof * indexData.indexCount);
            }
            
            writeChunkHeader(MeshChunkID.M_MESH_LOD_GENERATED, size);
            uint idxCount = cast(uint)(indexData.indexCount);
            writeInts(&idxCount, 1);
            writeBools(&idx32, 1);
            
            if (idxCount > 0)
            {
                if (idx32)
                {
                    uint* pIdx = cast(uint*)(
                        ibuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
                    writeInts(pIdx, indexData.indexCount);
                    ibuf.get().unlock();
                }
                else
                {
                    ushort* pIdx = cast(ushort*)(
                        ibuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
                    writeShorts(pIdx, indexData.indexCount);
                    ibuf.get().unlock();
                }
            }
        }
    }
    
    void writeBoundsInfo(Mesh pMesh)
    {
        // Usage Header
        ulong size = MSTREAM_OVERHEAD_SIZE;
        
        size += float.sizeof * 7;
        writeChunkHeader(MeshChunkID.M_MESH_BOUNDS, size);
        
        // float minx, miny, minz
        Vector3 min = pMesh.mAABB.getMinimum();
        Vector3 max = pMesh.mAABB.getMaximum();
        writeFloats(&min.x, 1);
        writeFloats(&min.y, 1);
        writeFloats(&min.z, 1);
        // float maxx, maxy, maxz
        writeFloats(&max.x, 1);
        writeFloats(&max.y, 1);
        writeFloats(&max.z, 1);
        // float radius
        Real r = pMesh.mBoundRadius;
        writeFloats(&r, 1);
        
    }
    
    void writeEdgeList(Mesh pMesh)
    {
        writeChunkHeader(MeshChunkID.M_EDGE_LISTS, calcEdgeListSize(pMesh));
        
        for (ushort i = 0; i < pMesh.getNumLodLevels(); ++i)
        {
            EdgeData edgeData = pMesh.getEdgeList(i);
            bool isManual = pMesh.isLodManual() && (i > 0);
            writeChunkHeader(MeshChunkID.M_EDGE_LIST_LOD, calcEdgeListLodSize(edgeData, isManual));
            
            // unsigned short lodIndex
            writeShorts(&i, 1);
            
            // bool isManual            // If manual, no edge data here, loaded from manual mesh
            writeBools(&isManual, 1);
            if (!isManual)
            {
                // bool isClosed
                writeBools(&edgeData.isClosed, 1);
                // ulong  numTriangles
                uint count = cast(uint)(edgeData.triangles.length);
                writeInts(&count, 1);
                // ulong numEdgeGroups
                count = cast(uint)(edgeData.edgeGroups.length);
                writeInts(&count, 1);
                // Triangle* triangleList
                // Iterate rather than writing en-masse to allow endian conversion
                //EdgeData.TriangleList::const_iterator t = edgeData.triangles.begin();
                //EdgeData.TriangleFaceNormalList::const_iterator fni = edgeData.triangleFaceNormals.begin();
                foreach (ti; 0..edgeData.triangles.length)
                {
                    EdgeData.Triangle* tri = &edgeData.triangles[ti];
                    auto fni = edgeData.triangleFaceNormals[ti];
                    
                    // ulong indexSet;
                    uint[3] tmp;
                    tmp[0] = cast(uint)tri.indexSet;
                    writeInts(tmp.ptr, 1);
                    // ulong vertexSet;
                    tmp[0] = cast(uint)tri.vertexSet;
                    writeInts(tmp.ptr, 1);
                    // ulong vertIndex[3];
                    tmp[0] = cast(uint)tri.vertIndex[0];
                    tmp[1] = cast(uint)tri.vertIndex[1];
                    tmp[2] = cast(uint)tri.vertIndex[2];
                    writeInts(tmp.ptr, 3);
                    // ulong sharedVertIndex[3];
                    tmp[0] = cast(uint)tri.sharedVertIndex[0];
                    tmp[1] = cast(uint)tri.sharedVertIndex[1];
                    tmp[2] = cast(uint)tri.sharedVertIndex[2];
                    writeInts(tmp.ptr, 3);
                    // float normal[4];
                    writeFloats(fni.xyzw.ptr, 4);
                    
                }
                // Write the groups
                foreach (edgeGroup; edgeData.edgeGroups)
                {
                    writeChunkHeader(MeshChunkID.M_EDGE_GROUP, calcEdgeGroupSize(edgeGroup));
                    // ulong vertexSet
                    uint vertexSet = cast(uint)(edgeGroup.vertexSet);
                    writeInts(&vertexSet, 1);
                    // ulong triStart
                    uint triStart = cast(uint)(edgeGroup.triStart);
                    writeInts(&triStart, 1);
                    // ulong triCount
                    uint triCount = cast(uint)(edgeGroup.triCount);
                    writeInts(&triCount, 1);
                    // ulong numEdges
                    count = cast(uint)(edgeGroup.edges.length);
                    writeInts(&count, 1);
                    // Edge* edgeList
                    // Iterate rather than writing en-masse to allow endian conversion
                    foreach (edge; edgeGroup.edges)
                    {
                        uint[2] tmp;
                        // ulong  triIndex[2]
                        tmp[0] = cast(uint)edge.triIndex[0];
                        tmp[1] = cast(uint)edge.triIndex[1];
                        writeInts(tmp.ptr, 2);
                        // ulong  vertIndex[2]
                        tmp[0] = cast(uint)edge.vertIndex[0];
                        tmp[1] = cast(uint)edge.vertIndex[1];
                        writeInts(tmp.ptr, 2);
                        // ulong  sharedVertIndex[2]
                        tmp[0] = cast(uint)edge.sharedVertIndex[0];
                        tmp[1] = cast(uint)edge.sharedVertIndex[1];
                        writeInts(tmp.ptr, 2);
                        // bool degenerate
                        writeBools(&(edge.degenerate), 1);
                    }
                    
                }
                
            }
            
        }
    }
    
    void writeAnimations(Mesh pMesh)
    {
        writeChunkHeader(MeshChunkID.M_ANIMATIONS, calcAnimationsSize(pMesh));
        
        foreach (ushort a; 0..pMesh.getNumAnimations())
        {
            Animation anim = pMesh.getAnimation(a);
            LogManager.getSingleton().logMessage("Exporting animation " ~ anim.getName());
            writeAnimation(anim);
            LogManager.getSingleton().logMessage("Animation exported.");
        }
    }
    
    void writeAnimation(Animation anim)
    {
        writeChunkHeader(MeshChunkID.M_ANIMATION, calcAnimationSize(anim));
        // char* name
        writeString(anim.getName());
        // float length
        float len = anim.getLength();
        writeFloats(&len, 1);
        
        if (anim.getUseBaseKeyFrame())
        {
            size_t size = MSTREAM_OVERHEAD_SIZE;
            // char* baseAnimationName (including terminator)
            size += anim.getBaseKeyFrameAnimationName().length + 1;
            // float baseKeyFrameTime
            size += float.sizeof;
            
            writeChunkHeader(MeshChunkID.M_ANIMATION_BASEINFO, size);
            
            // char* baseAnimationName (blank for self)
            writeString(anim.getBaseKeyFrameAnimationName());
            
            // float baseKeyFrameTime
            float t = cast(float)anim.getBaseKeyFrameTime();
            writeFloats(&t, 1);
        }
        
        // tracks
        foreach (vt; anim.getVertexTracks())
        {
            writeAnimationTrack(vt);
        }
        
        
    }
    
    void writePoses(Mesh pMesh)
    {
        auto poses = pMesh.getPoseList();
        if (poses.length)
        {
            writeChunkHeader(MeshChunkID.M_POSES, calcPosesSize(pMesh));
            foreach(pose; poses)
            {
                writePose(pose);
            }
        }
        
    }
    
    void writePose(Pose pose)
    {
        writeChunkHeader(MeshChunkID.M_POSE, calcPoseSize(pose));
        
        // char* name (may be blank)
        writeString(pose.getName());
        
        // ushort target
        ushort val = pose.getTarget();
        writeShorts(&val, 1);
        
        // bool includesNormals
        bool includesNormals = pose.getNormals().length > 0;
        writeBools(&includesNormals, 1);
        
        size_t vertexSize = calcPoseVertexSize(pose);
        size_t nit = 0;
        //TODO Ok, getNormals() should probably be ordered map, std::map.getNext() 
        // returns in order of insertion?
        // OrderedMap should emulate this
        auto normals = pose.getNormals();
        foreach(_vertexIndex, offset; pose.getVertexOffsets())
        {
            uint vertexIndex = cast(uint)_vertexIndex;
            //Vector3 offset = vit.getNext();
            writeChunkHeader(MeshChunkID.M_POSE_VERTEX, vertexSize);
            // ulong vertexIndex
            writeInts(&vertexIndex, 1);
            // float xoffset, yoffset, zoffset
            writeFloats(offset.ptr(), 3);
            if (includesNormals)
            {
                Vector3 normal = normals[normals.keysAA[nit++]];//nit.getNext();
                // float xnormal, ynormal, znormal
                writeFloats(normal.ptr(), 3);
            }
        }
        
        
    }
    
    void writeAnimationTrack(VertexAnimationTrack track)
    {
        writeChunkHeader(MeshChunkID.M_ANIMATION_TRACK, calcAnimationTrackSize(track));
        // ushort type          // 1 == morph, 2 == pose
        ushort animType = cast(ushort)track.getAnimationType();
        writeShorts(&animType, 1);
        // ushort target
        ushort target = track.getHandle();
        writeShorts(&target, 1);
        
        if (track.getAnimationType() == VertexAnimationType.VAT_MORPH)
        {
            foreach (ushort i; 0..track.getNumKeyFrames())
            {
                VertexMorphKeyFrame kf = track.getVertexMorphKeyFrame(i);
                writeMorphKeyframe(kf, track.getAssociatedVertexData().vertexCount);
            }
        }
        else // VertexAnimationType.VAT_POSE
        {
            foreach (ushort i; 0..track.getNumKeyFrames())
            {
                VertexPoseKeyFrame kf = track.getVertexPoseKeyFrame(i);
                writePoseKeyframe(kf);
            }
        }
        
    }
    
    void writeMorphKeyframe(VertexMorphKeyFrame kf, size_t vertexCount)
    {
        writeChunkHeader(MeshChunkID.M_ANIMATION_MORPH_KEYFRAME, calcMorphKeyframeSize(kf, vertexCount));
        // float time
        float timePos = kf.getTime();
        writeFloats(&timePos, 1);
        // bool includeNormals
        bool includeNormals = kf.getVertexBuffer().get().getVertexSize() > (float.sizeof * 3);
        writeBools(&includeNormals, 1);
        // float x,y,z          // repeat by number of vertices in original geometry
        float* pSrc = cast(float*)(
            kf.getVertexBuffer().get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
        writeFloats(pSrc, vertexCount * (includeNormals ? 6 : 3));
        kf.getVertexBuffer().get().unlock();
    }
    
    void writePoseKeyframe(VertexPoseKeyFrame kf)
    {
        writeChunkHeader(MeshChunkID.M_ANIMATION_POSE_KEYFRAME, calcPoseKeyframeSize(kf));
        // float time
        float timePos = kf.getTime();
        writeFloats(&timePos, 1);
        
        // pose references
        auto poseRefs = kf.getPoseRefs();
        foreach (r; poseRefs)
        {
            writePoseKeyframePoseRef(r);
        }
    }
    
    void writePoseKeyframePoseRef(VertexPoseKeyFrame.PoseRef poseRef)
    {
        writeChunkHeader(MeshChunkID.M_ANIMATION_POSE_REF, calcPoseKeyframePoseRefSize());
        // ushort poseIndex
        writeShorts(&(poseRef.poseIndex), 1);
        // float influence
        writeFloats(&(poseRef.influence), 1);
    }
    
    void writeExtremes(Mesh pMesh)
    {
        bool has_extremes = false;
        for (ushort i = 0; i < pMesh.getNumSubMeshes(); ++i)
        {
            SubMesh sm = pMesh.getSubMesh(i);
            if (!sm.extremityPoints.length)
                continue;
            if (!has_extremes)
            {
                has_extremes = true;
                LogManager.getSingleton().logMessage("Writing submesh extremes...");
            }
            writeSubMeshExtremes(i, sm);
        }
        if (has_extremes)
            LogManager.getSingleton().logMessage("Extremes exported.");
    }
    
    void writeSubMeshExtremes(ushort idx, ref SubMesh s)
    {
        size_t chunkSize = MSTREAM_OVERHEAD_SIZE + ushort.sizeof +
            s.extremityPoints.length * float.sizeof * 3;
        writeChunkHeader(MeshChunkID.M_TABLE_EXTREMES, chunkSize);
        
        writeShorts(&idx, 1);
        
        float[] vertices = new float [s.extremityPoints.length * 3];
        float *pVert = vertices.ptr;
        
        foreach (i; s.extremityPoints)
        {
            *pVert++ = i.x;
            *pVert++ = i.y;
            *pVert++ = i.z;
        }
        
        writeFloats(vertices.ptr, s.extremityPoints.length * 3);
        destroy(vertices);
    }
    
    size_t calcMeshSize(Mesh pMesh)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        
        // Num shared vertices
        size += uint.sizeof;
        
        // Geometry
        if (pMesh.sharedVertexData && pMesh.sharedVertexData.vertexCount > 0)
        {
            size += calcGeometrySize(pMesh.sharedVertexData);
        }
        
        // Submeshes
        for (ushort i = 0; i < pMesh.getNumSubMeshes(); ++i)
        {
            size += calcSubMeshSize(pMesh.getSubMesh(i));
        }
        
        // Skeleton link
        if (pMesh.hasSkeleton())
        {
            size += calcSkeletonLinkSize(pMesh.getSkeletonName());
        }
        
        // Submesh name table
        size += calcSubMeshNameTableSize(pMesh);
        
        // Edge list
        if (pMesh.isEdgeListBuilt())
        {
            size += calcEdgeListSize(pMesh);
        }
        
        // Animations
        foreach (ushort a; 0..pMesh.getNumAnimations())
        {
            Animation anim = pMesh.getAnimation(a);
            size += calcAnimationSize(anim);
        }
        
        return size;
    }
    
    size_t calcSubMeshSize(SubMesh pSub)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        
        bool idx32bit = (!pSub.indexData.indexBuffer.isNull() &&
                         pSub.indexData.indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_32BIT);
        
        // Material name
        size += pSub.getMaterialName().length + 1;
        
        // bool useSharedVertices
        size += bool.sizeof;
        // unsigned int indexCount
        size += uint.sizeof;
        // bool indexes32bit
        size += bool.sizeof;
        // unsigned int* / ushort* faceVertexIndices
        if (idx32bit)
            size += uint.sizeof * pSub.indexData.indexCount;
        else
            size += ushort.sizeof * pSub.indexData.indexCount;
        // Geometry
        if (!pSub.useSharedVertices)
        {
            size += calcGeometrySize(pSub.vertexData);
        }
        
        size += calcSubMeshTextureAliasesSize(pSub);
        size += calcSubMeshOperationSize(pSub);
        
        // Bone assignments
        if (!pSub.mBoneAssignments.emptyAA())
        {
            foreach (vi; pSub.mBoneAssignments)
            {
                size += calcBoneAssignmentSize();
            }
        }
        
        return size;
    }
    
    size_t calcGeometrySize(VertexData vertexData)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        
        // Num vertices
        size += uint.sizeof;
        
        VertexDeclaration.VertexElementList elems =
            vertexData.vertexDeclaration.getElements();
        // Vertex declaration
        size += MSTREAM_OVERHEAD_SIZE + elems.length * (MSTREAM_OVERHEAD_SIZE + ushort.sizeof * 5);
        
        foreach (elem; elems)
        {
            // Vertex element header
            size += MSTREAM_OVERHEAD_SIZE + ushort.sizeof * 5;
            
            // Vertex element
            size += VertexElement.getTypeSize(elem.getType()) * vertexData.vertexCount;
        }
        return size;
    }
    
    size_t calcSkeletonLinkSize(string skelName)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        
        size += skelName.length + 1;
        
        return size;
    }
    
    size_t calcBoneAssignmentSize()
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        
        // Vert index
        size += uint.sizeof;
        // Bone index
        size += ushort.sizeof;
        // weight
        size += float.sizeof;
        
        return size;
    }
    
    size_t calcSubMeshOperationSize(SubMesh pSub)
    {
        return MSTREAM_OVERHEAD_SIZE + ushort.sizeof;
    }
    
    size_t calcSubMeshNameTableSize(Mesh pMesh)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        // Figure out the size of the Name table.
        // Iterate through the subMeshList & add up the size of the indexes and names.
        foreach(k,v; pMesh.mSubMeshNameMap)
        {
            // size of the index + header size for each element chunk
            size += MSTREAM_OVERHEAD_SIZE + ushort.sizeof;
            // name
            size += k.length + 1;
            
        }
        
        // size of the sub-mesh name table.
        return size;
    }
    
    size_t calcEdgeListSize(Mesh pMesh)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        
        for (ushort i = 0; i < pMesh.getNumLodLevels(); ++i)
        {
            
            EdgeData edgeData = pMesh.getEdgeList(i);
            bool isManual = pMesh.isLodManual() && (i > 0);
            
            size += calcEdgeListLodSize(edgeData, isManual);
            
        }
        
        return size;
    }
    
    size_t calcEdgeListLodSize(EdgeData edgeData, bool isManual)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        
        // ushort lodIndex
        size += ushort.sizeof;
        
        // bool isManual            // If manual, no edge data here, loaded from manual mesh
        size += bool.sizeof;
        if (!isManual)
        {
            // bool isClosed
            size += bool.sizeof;
            // ulong numTriangles
            size += uint.sizeof;
            // ulong numEdgeGroups
            size += uint.sizeof;
            // Triangle* triangleList
            size_t triSize = 0;
            // ulong indexSet
            // ulong vertexSet
            // ulong vertIndex[3]
            // ulong sharedVertIndex[3]
            // float normal[4]
            triSize += uint.sizeof * 8
                + float.sizeof * 4;
            
            size += triSize * edgeData.triangles.length;
            // Write the groups
            foreach (edgeGroup; edgeData.edgeGroups)
            {
                size += calcEdgeGroupSize(edgeGroup);
            }
            
        }
        
        return size;
    }
    
    size_t calcEdgeGroupSize(EdgeData.EdgeGroup group)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        
        // ulong vertexSet
        size += uint.sizeof;
        // ulong triStart
        size += uint.sizeof;
        // ulong triCount
        size += uint.sizeof;
        // ulong numEdges
        size += uint.sizeof;
        // Edge* edgeList
        size_t edgeSize = 0;
        // ulong  triIndex[2]
        // ulong  vertIndex[2]
        // ulong  sharedVertIndex[2]
        // bool degenerate
        edgeSize += uint.sizeof * 6 + bool.sizeof;
        size += edgeSize * group.edges.length;
        
        return size;
    }
    
    size_t calcPosesSize(Mesh pMesh)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        
        auto poseIt = pMesh.getPoseList();
        foreach (pose; poseIt)
        {
            size += calcPoseSize(pose);
        }
        return size;
    }
    
    size_t calcPoseSize(Pose pose)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        
        // char* name (may be blank)
        size += pose.getName().length + 1;
        // ushort target
        size += ushort.sizeof;
        // bool includesNormals
        size += bool.sizeof;
        
        // vertex offsets
        size += pose.getVertexOffsets().length * calcPoseVertexSize(pose);
        
        return size;
        
    }
    
    size_t calcAnimationsSize(Mesh pMesh)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        
        foreach (ushort a; 0..pMesh.getNumAnimations())
        {
            Animation anim = pMesh.getAnimation(a);
            size += calcAnimationSize(anim);
        }
        return size;
        
    }
    
    size_t calcAnimationSize(Animation anim)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        // char* name
        size += anim.getName().length + 1;
        
        // float length
        size += float.sizeof;
        
        auto trackIt = anim._getVertexTrackList();
        foreach (vt; trackIt)
        {
            size += calcAnimationTrackSize(vt);
        }
        
        return size;
    }
    
    size_t calcAnimationTrackSize(VertexAnimationTrack track)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        // ushort type
        size += ushort.sizeof;
        // ushort target        // 0 for shared geometry,
        size += ushort.sizeof;
        
        if (track.getAnimationType() == VertexAnimationType.VAT_MORPH)
        {
            foreach (ushort i; 0..track.getNumKeyFrames())
            {
                VertexMorphKeyFrame kf = track.getVertexMorphKeyFrame(i);
                size += calcMorphKeyframeSize(kf, track.getAssociatedVertexData().vertexCount);
            }
        }
        else
        {
            foreach (ushort i; 0..track.getNumKeyFrames())
            {
                VertexPoseKeyFrame kf = track.getVertexPoseKeyFrame(i);
                size += calcPoseKeyframeSize(kf);
            }
        }
        return size;
    }
    
    size_t calcMorphKeyframeSize(VertexMorphKeyFrame kf, size_t vertexCount)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        // float time
        size += float.sizeof;
        // float x,y,z[,nx,ny,nz]
        bool includesNormals = kf.getVertexBuffer().get().getVertexSize() > (float.sizeof * 3);
        size += float.sizeof * (includesNormals ? 6 : 3) * vertexCount;
        
        return size;
    }
    
    size_t calcPoseKeyframeSize(VertexPoseKeyFrame kf)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        
        // float time
        size += float.sizeof;
        
        size += calcPoseKeyframePoseRefSize() * kf.getPoseReferences().length;
        
        return size;
        
    }
    
    size_t calcPoseKeyframePoseRefSize()
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        // ushort poseIndex
        size += ushort.sizeof;
        // float influence
        size += float.sizeof;
        
        return size;
        
    }
    
    size_t calcPoseVertexSize(Pose pose)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        // ulong vertexIndex
        size += uint.sizeof;
        // float xoffset, yoffset, zoffset
        size += float.sizeof * 3;
        // optional normals
        if (pose.getNormals().length)
            size += float.sizeof * 3;
        
        return size;
    }
    
    size_t calcSubMeshTextureAliasesSize(SubMesh pSub)
    {
        size_t chunkSize = 0;
        
        // iterate through texture alias map and calc size of strings
        foreach (k,v; pSub.mTextureAliases)
        {
            // calculate chunk size based on string length + 1.  Add 1 for the line feed.
            chunkSize += MSTREAM_OVERHEAD_SIZE + k.length + v.length + 2;
        }
        
        return chunkSize;
    }
    
    
    void readTextureLayer(DataStream stream, ref Mesh pMesh, ref SharedPtr!Material pMat)
    {
        // Material definition section phased out of 1.1
    }
    
    void readSubMeshNameTable(DataStream stream, ref Mesh pMesh)
    {
        // The map for
        string[ushort] subMeshNames;
        ushort streamID, subMeshIndex;
        
        // Need something to store the index, and the objects name
        // This table is a method that imported meshes can retain their naming
        // so that the names established in the modelling software can be used
        // to get the sub-meshes by name. The exporter must support exporting
        // the optional stream M_SUBMESH_NAME_TABLE.
        
        // Read in all the sub-streams. Each sub-stream should contain an index and Ogre::string for the name.
        if (!stream.eof())
        {
            streamID = readChunk(stream);
            while(!stream.eof() && (streamID == MeshChunkID.M_SUBMESH_NAME_TABLE_ELEMENT ))
            {
                // Read in the index of the submesh.
                readShorts(stream, &subMeshIndex, 1);
                // Read in the string and map it to its index.
                subMeshNames[subMeshIndex] = readString(stream);
                
                // If we're not end of file get the next stream ID
                if (!stream.eof())
                    streamID = readChunk(stream);
            }
            if (!stream.eof())
            {
                // Backpedal back to start of stream
                stream.skip(-MSTREAM_OVERHEAD_SIZE);
            }
        }
        
        // Set all the submeshes names
        // ?
        
        // Loop through and save out the index and names.
        
        foreach(k,v; subMeshNames)
        {
            // Name this submesh to the stored name.
            pMesh.nameSubMesh(v, k);
        }
        
    }
    
    void readMesh(DataStream stream, ref Mesh pMesh, ref MeshSerializerListener listener)
    {
        // Never automatically build edge lists for this version
        // expect them in the file or not at all
        pMesh.mAutoBuildEdgeLists = false;
        
        // bool skeletallyAnimated
        bool skeletallyAnimated;
        readBools(stream, &skeletallyAnimated, 1);
        
        // Find all substreams
        if (!stream.eof())
        {
            ushort streamID = readChunk(stream);
            while(!stream.eof() &&
                  (streamID == MeshChunkID.M_GEOMETRY ||
             streamID == MeshChunkID.M_SUBMESH ||
             streamID == MeshChunkID.M_MESH_SKELETON_LINK ||
             streamID == MeshChunkID.M_MESH_BONE_ASSIGNMENT ||
             streamID == MeshChunkID.M_MESH_LOD ||
             streamID == MeshChunkID.M_MESH_BOUNDS ||
             streamID == MeshChunkID.M_SUBMESH_NAME_TABLE ||
             streamID == MeshChunkID.M_EDGE_LISTS ||
             streamID == MeshChunkID.M_POSES ||
             streamID == MeshChunkID.M_ANIMATIONS ||
             streamID == MeshChunkID.M_TABLE_EXTREMES))
            {
                switch(streamID)
                {
                    case MeshChunkID.M_GEOMETRY:
                        pMesh.sharedVertexData = new VertexData();
                        try {
                            readGeometry(stream, pMesh, pMesh.sharedVertexData);
                        }
                        catch (ItemNotFoundError e)
                        {
                            // duff geometry data entry with 0 vertices
                            destroy(pMesh.sharedVertexData);
                            pMesh.sharedVertexData = null;
                            // Skip this stream (pointer will have been returned to just after header)
                            stream.skip(mCurrentstreamLen - MSTREAM_OVERHEAD_SIZE);
                        }
                        break;
                    case MeshChunkID.M_SUBMESH:
                        readSubMesh(stream, pMesh, listener);
                        break;
                    case MeshChunkID.M_MESH_SKELETON_LINK:
                        readSkeletonLink(stream, pMesh, listener);
                        break;
                    case MeshChunkID.M_MESH_BONE_ASSIGNMENT:
                        readMeshBoneAssignment(stream, pMesh);
                        break;
                    case MeshChunkID.M_MESH_LOD:
                        readMeshLodInfo(stream, pMesh);
                        break;
                    case MeshChunkID.M_MESH_BOUNDS:
                        readBoundsInfo(stream, pMesh);
                        break;
                    case MeshChunkID.M_SUBMESH_NAME_TABLE:
                        readSubMeshNameTable(stream, pMesh);
                        break;
                    case MeshChunkID.M_EDGE_LISTS:
                        readEdgeList(stream, pMesh);
                        break;
                    case MeshChunkID.M_POSES:
                        readPoses(stream, pMesh);
                        break;
                    case MeshChunkID.M_ANIMATIONS:
                        readAnimations(stream, pMesh);
                        break;
                    case MeshChunkID.M_TABLE_EXTREMES:
                        readExtremes(stream, pMesh);
                        break;
                    default:
                        break;
                }
                
                if (!stream.eof())
                {
                    streamID = readChunk(stream);
                }
                
            }
            if (!stream.eof())
            {
                // Backpedal back to start of stream
                stream.skip(-MSTREAM_OVERHEAD_SIZE);
            }
        }
        
    }
    
    void readSubMesh(DataStream stream, ref Mesh pMesh, ref MeshSerializerListener listener)
    {
        ushort streamID;
        
        SubMesh sm = pMesh.createSubMesh();
        
        // char* materialName
        string materialName = readString(stream);
        if(listener)
            listener.processMaterialName(pMesh, materialName);
        sm.setMaterialName(materialName, pMesh.getGroup());
        debug stderr.writeln("Material: ", materialName);
        
        // bool useSharedVertices
        readBools(stream,&sm.useSharedVertices, 1);
        
        sm.indexData.indexStart = 0;
        uint indexCount = 0;
        readInts(stream, &indexCount, 1);
        sm.indexData.indexCount = indexCount;
        debug stderr.writeln("indexCount: ", sm.indexData.indexCount);
        
        SharedPtr!HardwareIndexBuffer ibuf;
        // bool indexes32Bit
        bool idx32bit;
        readBools(stream, &idx32bit, 1);
        if (indexCount > 0)
        {
            if (idx32bit)
            {
                ibuf = HardwareBufferManager.getSingleton().
                    createIndexBuffer(
                        HardwareIndexBuffer.IndexType.IT_32BIT,
                        sm.indexData.indexCount,
                        pMesh.mIndexBufferUsage,
                        pMesh.mIndexBufferShadowBuffer);
                // uint* faceVertexIndices
                uint* pIdx = cast(uint*)(
                    ibuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD)
                    );
                readInts(stream, pIdx, sm.indexData.indexCount);
                ibuf.get().unlock();
                
            }
            else // 16-bit
            {
                ibuf = HardwareBufferManager.getSingleton().
                    createIndexBuffer(
                        HardwareIndexBuffer.IndexType.IT_16BIT,
                        sm.indexData.indexCount,
                        pMesh.mIndexBufferUsage,
                        pMesh.mIndexBufferShadowBuffer);
                // ushort* faceVertexIndices
                ushort* pIdx = cast(ushort*)(
                    ibuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD)
                    );
                debug stderr.writeln("16-bit IndexBuffer: ", ibuf, " Lock:", pIdx, ",", stream.size, ",", stream.tell());
                readShorts(stream, pIdx, sm.indexData.indexCount);
                ibuf.get().unlock();
            }
        }
        sm.indexData.indexBuffer = ibuf;
        
        // MeshChunkID.M_GEOMETRY stream (Optional: present only if useSharedVertices = false)
        if (!sm.useSharedVertices)
        {
            streamID = readChunk(stream);
            if (streamID != MeshChunkID.M_GEOMETRY)
            {
                throw new InternalError("Missing geometry data in mesh file",
                                        "MeshSerializerImpl.readSubMesh");
            }
            sm.vertexData = new VertexData();
            readGeometry(stream, pMesh, sm.vertexData);
        }
        
        
        // Find all bone assignments, submesh operation, and texture aliases (if present)
        if (!stream.eof())
        {
            streamID = readChunk(stream);
            while(!stream.eof() &&
                  (streamID == MeshChunkID.M_SUBMESH_BONE_ASSIGNMENT ||
             streamID == MeshChunkID.M_SUBMESH_OPERATION ||
             streamID == MeshChunkID.M_SUBMESH_TEXTURE_ALIAS))
            {
                switch(streamID)
                {
                    case MeshChunkID.M_SUBMESH_OPERATION:
                        readSubMeshOperation(stream, pMesh, sm);
                        break;
                    case MeshChunkID.M_SUBMESH_BONE_ASSIGNMENT:
                        readSubMeshBoneAssignment(stream, pMesh, sm);
                        break;
                    case MeshChunkID.M_SUBMESH_TEXTURE_ALIAS:
                        readSubMeshTextureAlias(stream, pMesh, sm);
                        break;
                    default:
                        break;
                }
                
                if (!stream.eof())
                {
                    streamID = readChunk(stream);
                }
                
            }
            if (!stream.eof())
            {
                // Backpedal back to start of stream
                stream.skip(-MSTREAM_OVERHEAD_SIZE);
            }
        }
        
        
    }
    
    void readSubMeshOperation(DataStream stream, ref Mesh pMesh, ref SubMesh sub)
    {
        // ushort operationType
        ushort opType;
        readShorts(stream, &opType, 1);
        sub.operationType = cast(RenderOperation.OperationType)(opType);
    }
    
    void readSubMeshTextureAlias(DataStream stream, ref Mesh pMesh, ref SubMesh sub)
    {
        string aliasName = readString(stream);
        string textureName = readString(stream);
        sub.addTextureAlias(aliasName, textureName);
    }
    
    void readGeometry(DataStream stream, ref Mesh pMesh, ref VertexData dest)
    {
        
        dest.vertexStart = 0;
        
        uint vertexCount = 0;
        readInts(stream, &vertexCount, 1);
        dest.vertexCount = vertexCount;
        
        // Find optional geometry streams
        if (!stream.eof())
        {
            ushort streamID = readChunk(stream);
            while(!stream.eof() &&
                  (streamID == MeshChunkID.M_GEOMETRY_VERTEX_DECLARATION ||
             streamID == MeshChunkID.M_GEOMETRY_VERTEX_BUFFER ))
            {
                switch (streamID)
                {
                    case MeshChunkID.M_GEOMETRY_VERTEX_DECLARATION:
                        readGeometryVertexDeclaration(stream, pMesh, dest);
                        break;
                    case MeshChunkID.M_GEOMETRY_VERTEX_BUFFER:
                        readGeometryVertexBuffer(stream, pMesh, dest);
                        break;
                    default:
                        break;
                }
                // Get next stream
                if (!stream.eof())
                {
                    streamID = readChunk(stream);
                }
            }
            if (!stream.eof())
            {
                // Backpedal back to start of non-submesh stream
                stream.skip(-MSTREAM_OVERHEAD_SIZE);
            }
        }
        
        // Perform any necessary colour conversion for an active rendersystem
        if (Root.getSingletonPtr() && Root.getSingleton().getRenderSystem())
        {
            // We don't know the source type if it's VertexElementType.VET_COLOUR, but assume ARGB
            // since that's the most common. Won't get used unless the mesh is
            // ambiguous anyway, which will have been warned about in the log
            dest.convertPackedColour(VertexElementType.VET_COLOUR_ARGB, 
                                     VertexElement.getBestColourVertexElementType());
        }
    }
    
    void readGeometryVertexDeclaration(DataStream stream, ref Mesh pMesh, ref VertexData dest)
    {
        // Find optional geometry streams
        if (!stream.eof())
        {
            ushort streamID = readChunk(stream);
            while(!stream.eof() &&
                  (streamID == MeshChunkID.M_GEOMETRY_VERTEX_ELEMENT ))
            {
                switch (streamID)
                {
                    case MeshChunkID.M_GEOMETRY_VERTEX_ELEMENT:
                        readGeometryVertexElement(stream, pMesh, dest);
                        break;
                    default:
                        break;
                }
                // Get next stream
                if (!stream.eof())
                {
                    streamID = readChunk(stream);
                }
            }
            if (!stream.eof())
            {
                // Backpedal back to start of non-submesh stream
                stream.skip(-MSTREAM_OVERHEAD_SIZE);
            }
        }
        
    }
    
    void readGeometryVertexElement(DataStream stream, ref Mesh pMesh, ref VertexData dest)
    {
        ushort source, offset, index, tmp;
        VertexElementType vType;
        VertexElementSemantic vSemantic;
        // ushort source;   // buffer bind source
        readShorts(stream, &source, 1);
        // ushort type;     // VertexElementType
        readShorts(stream, &tmp, 1);
        vType = cast(VertexElementType)(tmp);
        // ushort semantic; // VertexElementSemantic
        readShorts(stream, &tmp, 1);
        vSemantic = cast(VertexElementSemantic)(tmp);
        // ushort offset;   // start offset in buffer in bytes
        readShorts(stream, &offset, 1);
        // ushort index;    // index of the semantic
        readShorts(stream, &index, 1);
        
        dest.vertexDeclaration.addElement(source, offset, vType, vSemantic, index);
        
        if (vType == VertexElementType.VET_COLOUR)
        {
            LogManager.getSingleton().stream()
                << "Warning: VertexElementType.VET_COLOUR element type is deprecated, you should use "
                    << "one of the more specific types to indicate the byte order. "
                    << "Use OgreMeshUpgrade on " << pMesh.getName() << " as soon as possible. ";
        }
        
    }
    
    void readGeometryVertexBuffer(DataStream stream, ref Mesh pMesh, ref VertexData dest)
    {
        ushort bindIndex, vertexSize;
        // ushort bindIndex;    // Index to bind this buffer to
        readShorts(stream, &bindIndex, 1);
        // ushort vertexSize;   // Per-vertex size, must agree with declaration at this index
        readShorts(stream, &vertexSize, 1);
        
        // Check for vertex data header
        ushort headerID;
        headerID = readChunk(stream);
        if (headerID != MeshChunkID.M_GEOMETRY_VERTEX_BUFFER_DATA)
        {
            throw new ItemNotFoundError("Can't find vertex buffer data area",
                                        "MeshSerializerImpl.readGeometryVertexBuffer");
        }
        // Check that vertex size agrees
        if (dest.vertexDeclaration.getVertexSize(bindIndex) != vertexSize)
        {
            throw new InternalError("Buffer vertex size does not agree with vertex declaration",
                                    "MeshSerializerImpl.readGeometryVertexBuffer");
        }
        
        // Create / populate vertex buffer
        SharedPtr!HardwareVertexBuffer vbuf;
        vbuf = HardwareBufferManager.getSingleton().createVertexBuffer(
            vertexSize,
            dest.vertexCount,
            pMesh.mVertexBufferUsage,
            pMesh.mVertexBufferShadowBuffer);
        //TODO mem copy to void*
        ubyte* pBuf = cast(ubyte*)vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD);
        ubyte[] bb;
        stream.read(bb, dest.vertexCount * vertexSize);
        pBuf[0..dest.vertexCount * vertexSize] = bb;
        
        // endian conversion for OSX
        flipFromLittleEndian(
            pBuf,
            dest.vertexCount,
            vertexSize,
            dest.vertexDeclaration.findElementsBySource(bindIndex));
        vbuf.get().unlock();
        
        // Set binding
        dest.vertexBufferBinding.setBinding(bindIndex, vbuf);
        
    }
    
    void readSkeletonLink(DataStream stream, ref Mesh pMesh, ref MeshSerializerListener listener)
    {
        string skelName = readString(stream);
        
        if(listener)
            listener.processSkeletonName(pMesh, skelName);
        
        pMesh.setSkeletonName(skelName);
    }
    
    void readMeshBoneAssignment(DataStream stream, ref Mesh pMesh)
    {
        VertexBoneAssignment assign;
        
        // uint vertexIndex;
        readInts(stream, &(assign.vertexIndex),1);
        // ushort boneIndex;
        readShorts(stream, &(assign.boneIndex),1);
        // float weight;
        readFloats(stream, &(assign.weight), 1);
        
        pMesh.addBoneAssignment(assign);
        
    }
    
    void readSubMeshBoneAssignment(DataStream stream, ref Mesh pMesh, 
                                   ref SubMesh sub)
    {
        VertexBoneAssignment assign;
        
        // uint vertexIndex;
        readInts(stream, &(assign.vertexIndex),1);
        // ushort boneIndex;
        readShorts(stream, &(assign.boneIndex),1);
        // float weight;
        readFloats(stream, &(assign.weight), 1);
        
        sub.addBoneAssignment(assign);
        
    }
    
    void readMeshLodInfo(DataStream stream, ref Mesh pMesh)
    {
        ushort streamID, i;
        
        // Read the strategy to be used for this mesh
        string strategyName = readString(stream);
        LodStrategy strategy = LodStrategyManager.getSingleton().getStrategy(strategyName);
        pMesh.setLodStrategy(strategy);
        
        // ushort numLevels;
        readShorts(stream, &(pMesh.mNumLods), 1);
        // bool manual;  (true for manual alternate meshes, false for generated)
        readBools(stream, &(pMesh.mIsLodManual), 1);
        
        // Preallocate submesh lod face data if not manual
        if (!pMesh.mIsLodManual)
        {
            ushort numsubs = pMesh.getNumSubMeshes();
            for (i = 0; i < numsubs; ++i)
            {
                SubMesh sm = pMesh.getSubMesh(i);
                sm.mLodFaceList.length = (pMesh.mNumLods-1);
            }
        }
        
        // Loop from 1 rather than 0 (full detail index is not in file)
        for (i = 1; i < pMesh.mNumLods; ++i)
        {
            streamID = readChunk(stream);
            if (streamID != MeshChunkID.M_MESH_LOD_USAGE)
            {
                throw new ItemNotFoundError(
                    "Missing MeshChunkID.M_MESH_LOD_USAGE stream in " ~ pMesh.getName(),
                    "MeshSerializerImpl.readMeshLodInfo");
            }
            // Read depth
            MeshLodUsage usage;
            readFloats(stream, &(usage.userValue), 1);
            
            if (pMesh.isLodManual())
            {
                readMeshLodUsageManual(stream, pMesh, i, usage);
            }
            else //(!pMesh.isLodManual)
            {
                readMeshLodUsageGenerated(stream, pMesh, i, usage);
            }
            usage.edgeData = null;
            
            // Save usage
            pMesh.mMeshLodUsageList.insert(usage);
        }
        
        
    }
    
    void readMeshLodUsageManual(DataStream stream, ref Mesh pMesh, 
                                ushort lodNum, ref MeshLodUsage usage)
    {
        ulong streamID;
        // Read detail stream
        streamID = readChunk(stream);
        if (streamID != MeshChunkID.M_MESH_LOD_MANUAL)
        {
            throw new ItemNotFoundError(
                "Missing MeshChunkID.M_MESH_LOD_MANUAL stream in " ~ pMesh.getName(),
                "MeshSerializerImpl.readMeshLodUsageManual");
        }
        
        usage.manualName = readString(stream);
        usage.manualMesh.setNull(); // will trigger load later
    }
    
    void readMeshLodUsageGenerated(DataStream stream, ref Mesh pMesh, 
                                   ushort lodNum, ref MeshLodUsage usage)
    {
        usage.manualName = "";
        usage.manualMesh.setNull();
        
        // Get one set of detail per SubMesh
        ushort numSubs, i;
        ulong streamID;
        numSubs = pMesh.getNumSubMeshes();
        for (i = 0; i < numSubs; ++i)
        {
            streamID = readChunk(stream);
            if (streamID != MeshChunkID.M_MESH_LOD_GENERATED)
            {
                throw new ItemNotFoundError(
                    "Missing MeshChunkID.M_MESH_LOD_GENERATED stream in " ~ pMesh.getName(),
                    "MeshSerializerImpl.readMeshLodUsageGenerated");
            }
            
            SubMesh sm = pMesh.getSubMesh(i);
            // lodNum - 1 because SubMesh doesn't store full detail LOD
            sm.mLodFaceList[lodNum - 1] = new IndexData();
            IndexData indexData = sm.mLodFaceList[lodNum - 1];
            // uint numIndexes
            uint numIndexes;
            readInts(stream, &numIndexes, 1);
            indexData.indexCount = cast(size_t)(numIndexes);
            // bool indexes32Bit
            bool idx32Bit;
            readBools(stream, &idx32Bit, 1);
            // ushort*/int* faceIndexes;  ((v1, v2, v3) * numFaces)
            if (idx32Bit)
            {
                indexData.indexBuffer = HardwareBufferManager.getSingleton().
                    createIndexBuffer(HardwareIndexBuffer.IndexType.IT_32BIT, indexData.indexCount,
                                      pMesh.mIndexBufferUsage, pMesh.mIndexBufferShadowBuffer);
                uint* pIdx = cast(uint*)(
                    indexData.indexBuffer.get().lock(
                    0,
                    indexData.indexBuffer.get().getSizeInBytes(),
                    HardwareBuffer.LockOptions.HBL_DISCARD) );
                
                readInts(stream, pIdx, indexData.indexCount);
                indexData.indexBuffer.get().unlock();
                
            }
            else
            {
                indexData.indexBuffer = HardwareBufferManager.getSingleton().
                    createIndexBuffer(HardwareIndexBuffer.IndexType.IT_16BIT, indexData.indexCount,
                                      pMesh.mIndexBufferUsage, pMesh.mIndexBufferShadowBuffer);
                ushort* pIdx = cast(ushort*)(
                    indexData.indexBuffer.get().lock(
                    0,
                    indexData.indexBuffer.get().getSizeInBytes(),
                    HardwareBuffer.LockOptions.HBL_DISCARD) );
                readShorts(stream, pIdx, indexData.indexCount);
                indexData.indexBuffer.get().unlock();
                
            }
            
        }
    }
    
    void readBoundsInfo(DataStream stream, ref Mesh pMesh)
    {
        Vector3 min, max;
        // float minx, miny, minz
        readFloats(stream, &min.x, 1);
        readFloats(stream, &min.y, 1);
        readFloats(stream, &min.z, 1);
        // float maxx, maxy, maxz
        readFloats(stream, &max.x, 1);
        readFloats(stream, &max.y, 1);
        readFloats(stream, &max.z, 1);
        auto box = AxisAlignedBox(min, max);
        pMesh._setBounds(box, true);
        // float radius
        float radius;
        readFloats(stream, &radius, 1);
        pMesh._setBoundingSphereRadius(radius);
        
    }
    
    void readEdgeList(DataStream stream, ref Mesh pMesh)
    {
        if (!stream.eof())
        {
            ushort streamID = readChunk(stream);
            while(!stream.eof() &&
                  streamID == MeshChunkID.M_EDGE_LIST_LOD)
            {
                // Process single LOD
                
                // ushort lodIndex
                ushort lodIndex;
                readShorts(stream, &lodIndex, 1);
                
                // bool isManual            // If manual, no edge data here, loaded from manual mesh
                bool isManual;
                readBools(stream, &isManual, 1);
                // Only load in non-manual levels; others will be connected up by Mesh on demand
                if (!isManual)
                {
                    MeshLodUsage usage = pMesh.getLodLevel(lodIndex);
                    
                    usage.edgeData = new EdgeData();
                    
                    // Read detail information of the edge list
                    readEdgeListLodInfo(stream, usage.edgeData);
                    
                    // Postprocessing edge groups
                    foreach (ref edgeGroup; usage.edgeData.edgeGroups)
                    {
                        // Populate edgeGroup.vertexData pointers
                        // If there is shared vertex data, vertexSet 0 is that,
                        // otherwise 0 is first dedicated
                        if (pMesh.sharedVertexData)
                        {
                            if (edgeGroup.vertexSet == 0)
                            {
                                edgeGroup.vertexData = pMesh.sharedVertexData;
                            }
                            else
                            {
                                edgeGroup.vertexData = pMesh.getSubMesh(
                                    cast(ushort)edgeGroup.vertexSet-1).vertexData;
                            }
                        }
                        else
                        {
                            edgeGroup.vertexData = pMesh.getSubMesh(
                                cast(ushort)edgeGroup.vertexSet).vertexData;
                        }
                    }
                }
                
                if (!stream.eof())
                {
                    streamID = readChunk(stream);
                }
                
            }
            if (!stream.eof())
            {
                // Backpedal back to start of stream
                stream.skip(-MSTREAM_OVERHEAD_SIZE);
            }
        }
        
        pMesh.mEdgeListsBuilt = true;
    }
    
    void readEdgeListLodInfo(DataStream stream, ref EdgeData edgeData)
    {
        // bool isClosed
        readBools(stream, &edgeData.isClosed, 1);
        // ulong numTriangles
        uint numTriangles;
        readInts(stream, &numTriangles, 1);
        // Allocate correct amount of memory
        edgeData.triangles.length = (numTriangles);
        edgeData.triangleFaceNormals.length = (numTriangles);
        edgeData.triangleLightFacings.length = (numTriangles);
        // ulong numEdgeGroups
        uint numEdgeGroups;
        readInts(stream, &numEdgeGroups, 1);
        // Allocate correct amount of memory
        edgeData.edgeGroups.length = (numEdgeGroups);
        // Triangle* triangleList
        uint[3] tmp;
        for (size_t t = 0; t < numTriangles; ++t)
        {
            EdgeData.Triangle *tri = &(edgeData.triangles[t]);
            // ulong indexSet
            readInts(stream, tmp.ptr, 1);
            tri.indexSet = tmp[0];
            // ulong vertexSet
            readInts(stream, tmp.ptr, 1);
            tri.vertexSet = tmp[0];
            // ulong vertIndex[3]
            readInts(stream, tmp.ptr, 3);
            tri.vertIndex[0] = tmp[0];
            tri.vertIndex[1] = tmp[1];
            tri.vertIndex[2] = tmp[2];
            // ulong sharedVertIndex[3]
            readInts(stream, tmp.ptr, 3);
            tri.sharedVertIndex[0] = tmp[0];
            tri.sharedVertIndex[1] = tmp[1];
            tri.sharedVertIndex[2] = tmp[2];
            // float normal[4]
            readFloats(stream, edgeData.triangleFaceNormals[t].ptr, 4);
            
        }
        
        for (uint eg = 0; eg < numEdgeGroups; ++eg)
        {
            ushort streamID = readChunk(stream);
            if (streamID != MeshChunkID.M_EDGE_GROUP)
            {
                throw new InternalError(
                    "Missing MeshChunkID.M_EDGE_GROUP stream",
                    "MeshSerializerImpl.readEdgeListLodInfo");
            }
            EdgeData.EdgeGroup* edgeGroup = &(edgeData.edgeGroups[eg]);
            
            // ulong vertexSet
            readInts(stream, tmp.ptr, 1);
            edgeGroup.vertexSet = tmp[0];
            // ulong triStart
            readInts(stream, tmp.ptr, 1);
            edgeGroup.triStart = tmp[0];
            // ulong triCount
            readInts(stream, tmp.ptr, 1);
            edgeGroup.triCount = tmp[0];
            // ulong numEdges
            uint numEdges;
            readInts(stream, &numEdges, 1);
            edgeGroup.edges.length = (numEdges);
            // Edge* edgeList
            for (uint e = 0; e < numEdges; ++e)
            {
                EdgeData.Edge* edge = &(edgeGroup.edges[e]);
                // ulong  triIndex[2]
                readInts(stream, tmp.ptr, 2);
                edge.triIndex[0] = tmp[0];
                edge.triIndex[1] = tmp[1];
                // ulong  vertIndex[2]
                readInts(stream, tmp.ptr, 2);
                edge.vertIndex[0] = tmp[0];
                edge.vertIndex[1] = tmp[1];
                // ulong  sharedVertIndex[2]
                readInts(stream, tmp.ptr, 2);
                edge.sharedVertIndex[0] = tmp[0];
                edge.sharedVertIndex[1] = tmp[1];
                // bool degenerate
                readBools(stream, &(edge.degenerate), 1);
            }
        }
    }
    
    void readPoses(DataStream stream, ref Mesh pMesh)
    {
        // Find all substreams
        if (!stream.eof())
        {
            ushort streamID = readChunk(stream);
            while(!stream.eof() &&
                  (streamID == MeshChunkID.M_POSE))
            {
                switch(streamID)
                {
                    case MeshChunkID.M_POSE:
                        readPose(stream, pMesh);
                        break;
                    default:
                        break;
                        
                }
                
                if (!stream.eof())
                {
                    streamID = readChunk(stream);
                }
                
            }
            if (!stream.eof())
            {
                // Backpedal back to start of stream
                stream.skip(-MSTREAM_OVERHEAD_SIZE);
            }
        }
    }
    
    void readPose(DataStream stream, ref Mesh pMesh)
    {
        // char* name (may be blank)
        string name = readString(stream);
        // ushort target
        ushort target;
        readShorts(stream, &target, 1);
        
        // bool includesNormals
        bool includesNormals;
        readBools(stream, &includesNormals, 1);
        
        Pose pose = pMesh.createPose(target, name);
        
        // Find all substreams
        if (!stream.eof())
        {
            ushort streamID = readChunk(stream);
            while(!stream.eof() &&
                  (streamID == MeshChunkID.M_POSE_VERTEX))
            {
                switch(streamID)
                {
                    case MeshChunkID.M_POSE_VERTEX:
                        // create vertex offset
                        uint vertIndex;
                        Vector3 offset, normal;
                        // ulong vertexIndex
                        readInts(stream, &vertIndex, 1);
                        // float xoffset, yoffset, zoffset
                        readFloats(stream, offset.ptr(), 3);
                        
                        if (includesNormals)
                        {
                            readFloats(stream, normal.ptr(), 3);
                            pose.addVertex(vertIndex, offset, normal);                      
                        }
                        else 
                        {
                            pose.addVertex(vertIndex, offset);
                        }
                        
                        
                        break;
                    default:
                        break;
                        
                }
                
                if (!stream.eof())
                {
                    streamID = readChunk(stream);
                }
                
            }
            if (!stream.eof())
            {
                // Backpedal back to start of stream
                stream.skip(-MSTREAM_OVERHEAD_SIZE);
            }
        }
        
    }
    
    void readAnimations(DataStream stream, ref Mesh pMesh)
    {
        // Find all substreams
        if (!stream.eof())
        {
            ushort streamID = readChunk(stream);
            while(!stream.eof() &&
                  (streamID == MeshChunkID.M_ANIMATION))
            {
                switch(streamID)
                {
                    case MeshChunkID.M_ANIMATION:
                        readAnimation(stream, pMesh);
                        break;
                    default:
                        break;
                        
                }
                
                if (!stream.eof())
                {
                    streamID = readChunk(stream);
                }
                
            }
            if (!stream.eof())
            {
                // Backpedal back to start of stream
                stream.skip(-MSTREAM_OVERHEAD_SIZE);
            }
        }
        
        
    }
    
    void readAnimation(DataStream stream, ref Mesh pMesh)
    {
        
        // char* name
        string name = readString(stream);
        // float length
        float len;
        readFloats(stream, &len, 1);
        
        Animation anim = pMesh.createAnimation(name, len);
        
        // tracks
        if (!stream.eof())
        {
            ushort streamID = readChunk(stream);
            
            // Optional base info is possible
            if (streamID == MeshChunkID.M_ANIMATION_BASEINFO)
            {
                // char baseAnimationName
                string baseAnimName = readString(stream);
                // float baseKeyFrameTime
                float baseKeyTime;
                readFloats(stream, &baseKeyTime, 1);
                
                anim.setUseBaseKeyFrame(true, baseKeyTime, baseAnimName);
                
                if (!stream.eof())
                {
                    // Get next stream
                    streamID = readChunk(stream);
                }
            }
            
            while(!stream.eof() &&
                  streamID == MeshChunkID.M_ANIMATION_TRACK)
            {
                switch(streamID)
                {
                    case MeshChunkID.M_ANIMATION_TRACK:
                        readAnimationTrack(stream, anim, pMesh);
                        break;
                    default:
                        break;
                }
                if (!stream.eof())
                {
                    streamID = readChunk(stream);
                }
                
            }
            if (!stream.eof())
            {
                // Backpedal back to start of stream
                stream.skip(-MSTREAM_OVERHEAD_SIZE);
            }
        }
    }
    
    void readAnimationTrack(DataStream stream, ref Animation anim, 
                            ref Mesh pMesh)
    {
        // ushort type
        ushort inAnimType;
        readShorts(stream, &inAnimType, 1);
        VertexAnimationType animType = cast(VertexAnimationType)inAnimType;
        
        // ushort target
        ushort target;
        readShorts(stream, &target, 1);
        
        VertexAnimationTrack track = anim.createVertexTrack(target,
                                                             pMesh.getVertexDataByTrackHandle(target), animType);
        
        // keyframes
        if (!stream.eof())
        {
            ushort streamID = readChunk(stream);
            while(!stream.eof() &&
                  (streamID == MeshChunkID.M_ANIMATION_MORPH_KEYFRAME ||
             streamID == MeshChunkID.M_ANIMATION_POSE_KEYFRAME))
            {
                switch(streamID)
                {
                    case MeshChunkID.M_ANIMATION_MORPH_KEYFRAME:
                        readMorphKeyFrame(stream, track);
                        break;
                    case MeshChunkID.M_ANIMATION_POSE_KEYFRAME:
                        readPoseKeyFrame(stream, track);
                        break;
                    default:
                        break;
                }
                if (!stream.eof())
                {
                    streamID = readChunk(stream);
                }
                
            }
            if (!stream.eof())
            {
                // Backpedal back to start of stream
                stream.skip(-MSTREAM_OVERHEAD_SIZE);
            }
        }
        
    }
    
    void readMorphKeyFrame(DataStream stream, ref VertexAnimationTrack track)
    {
        // float time
        float timePos;
        readFloats(stream, &timePos, 1);
        
        // bool includesNormals
        bool includesNormals;
        readBools(stream, &includesNormals, 1);
        
        VertexMorphKeyFrame kf = track.createVertexMorphKeyFrame(timePos);
        
        // Create buffer, allow read and use shadow buffer
        size_t vertexCount = track.getAssociatedVertexData().vertexCount;
        size_t vertexSize = float.sizeof * (includesNormals ? 6 : 3);
        SharedPtr!HardwareVertexBuffer vbuf =
            HardwareBufferManager.getSingleton().createVertexBuffer(
                vertexSize, vertexCount,
                HardwareBuffer.Usage.HBU_STATIC, true);
        // float x,y,z          // repeat by number of vertices in original geometry
        float* pDst = cast(float*)(
            vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
        readFloats(stream, pDst, vertexCount * (includesNormals ? 6 : 3));
        vbuf.get().unlock();
        kf.setVertexBuffer(vbuf);
        
    }
    
    void readPoseKeyFrame(DataStream stream, ref VertexAnimationTrack track)
    {
        // float time
        float timePos;
        readFloats(stream, &timePos, 1);
        
        // Create keyframe
        VertexPoseKeyFrame kf = track.createVertexPoseKeyFrame(timePos);
        
        if (!stream.eof())
        {
            ushort streamID = readChunk(stream);
            while(!stream.eof() &&
                  streamID == MeshChunkID.M_ANIMATION_POSE_REF)
            {
                switch(streamID)
                {
                    case MeshChunkID.M_ANIMATION_POSE_REF:
                        ushort poseIndex;
                        float influence;
                        // ushort poseIndex
                        readShorts(stream, &poseIndex, 1);
                        // float influence
                        readFloats(stream, &influence, 1);
                        
                        kf.addPoseReference(poseIndex, influence);
                        
                        break;
                    default:
                        break;
                }
                if (!stream.eof())
                {
                    streamID = readChunk(stream);
                }
                
            }
            if (!stream.eof())
            {
                // Backpedal back to start of stream
                stream.skip(-MSTREAM_OVERHEAD_SIZE);
            }
        }
        
    }
    
    void readExtremes(DataStream stream, ref Mesh pMesh)
    {
        ushort idx;
        readShorts(stream, &idx, 1);
        
        SubMesh sm = pMesh.getSubMesh (idx);
        
        size_t n_floats = (mCurrentstreamLen - MSTREAM_OVERHEAD_SIZE -
                        ushort.sizeof / float.sizeof);
        
        assert ((n_floats % 3) == 0);
        
        float[] vert = new float [n_floats];
        readFloats(stream, vert.ptr, n_floats);
        
        for (int i = 0; i < n_floats; i += 3)
            sm.extremityPoints.insert(Vector3(vert [i], vert [i + 1], vert [i + 2]));
        
        destroy(vert);
    }
    
    
    /// Flip an entire vertex buffer from little endian
    void flipFromLittleEndian(void* pData, size_t vertexCount, size_t vertexSize, VertexDeclaration.VertexElementList elems)
    {
        if (mFlipEndian)
        {
            flipEndian(pData, vertexCount, vertexSize, elems);
        }
    }
    
    /// Flip an entire vertex buffer to little endian
    void flipToLittleEndian(void* pData, size_t vertexCount, size_t vertexSize, VertexDeclaration.VertexElementList elems)
    {
        if (mFlipEndian)
        {
            flipEndian(pData, vertexCount, vertexSize, elems);
        }
    }
    
    /// Flip the endianness of an entire vertex buffer, passed in as a 
    /// pointer to locked or temporary memory 
    void flipEndian(void* pData, size_t vertexCount, size_t vertexSize, ref VertexDeclaration.VertexElementList elems)
    {
        void *pBase = pData;
        for (size_t v = 0; v < vertexCount; ++v)
        {
            foreach (ei; elems)
            {
                void *pElem;
                // re-base pointer to the element
                ei.baseVertexPointerToElement(pBase, &pElem);
                // Flip the endian based on the type
                size_t typeSize = 0;
                switch (VertexElement.getBaseType(ei.getType()))
                {
                    case VertexElementType.VET_FLOAT1:
                        typeSize = float.sizeof;
                        break;
                    case VertexElementType.VET_DOUBLE1:
                        typeSize = double.sizeof;
                        break;
                    case VertexElementType.VET_SHORT1:
                        typeSize = short.sizeof;
                        break;
                    case VertexElementType.VET_USHORT1:
                        typeSize = ushort.sizeof;
                        break;
                    case VertexElementType.VET_INT1:
                        typeSize = int.sizeof;
                        break;
                    case VertexElementType.VET_UINT1:
                        typeSize = uint.sizeof;
                        break;
                    case VertexElementType.VET_COLOUR:
                    case VertexElementType.VET_COLOUR_ABGR:
                    case VertexElementType.VET_COLOUR_ARGB:
                        typeSize = RGBA.sizeof;
                        break;
                    case VertexElementType.VET_UBYTE4:
                        typeSize = 0; // NO FLIPPING
                        break;
                    default:
                        assert(false); // Should never happen
                }
                super.flipEndian(pElem, typeSize,
                                 VertexElement.getTypeCount(ei.getType()));
                
            }
            
            pBase = cast(void*)(cast(ubyte*)(pBase) + vertexSize);
            
        }
    }
    
    
    
}

/** Class for providing backwards-compatibility for loading version 1.41 of the .mesh format. 
 This mesh format was used from Ogre v1.7.
 */
class MeshSerializerImpl_v1_41 : MeshSerializerImpl
{
public:
    this()
    {
        // Version number
        mVersion = "[MeshSerializer_v1.41]";
    }
    
    ~this() {}
protected:
    override void writeMorphKeyframe(VertexMorphKeyFrame kf, size_t vertexCount)
    {
        writeChunkHeader(MeshChunkID.M_ANIMATION_MORPH_KEYFRAME, calcMorphKeyframeSize(kf, vertexCount));
        // float time
        float timePos = kf.getTime();
        writeFloats(&timePos, 1);
        // float x,y,z          // repeat by number of vertices in original geometry
        float* pSrc = cast(float*)(
            kf.getVertexBuffer().get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
        writeFloats(pSrc, vertexCount * 3);
        kf.getVertexBuffer().get().unlock();
    }
    
    override void readMorphKeyFrame(DataStream stream, ref VertexAnimationTrack track)
    {
        // float time
        float timePos;
        readFloats(stream, &timePos, 1);
        
        VertexMorphKeyFrame kf = track.createVertexMorphKeyFrame(timePos);
        
        // Create buffer, allow read and use shadow buffer
        size_t vertexCount = track.getAssociatedVertexData().vertexCount;
        SharedPtr!HardwareVertexBuffer vbuf =
            HardwareBufferManager.getSingleton().createVertexBuffer(
                VertexElement.getTypeSize(VertexElementType.VET_FLOAT3), vertexCount,
                HardwareBuffer.Usage.HBU_STATIC, true);
        // float x,y,z          // repeat by number of vertices in original geometry
        float* pDst = cast(float*)(
            vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
        readFloats(stream, pDst, vertexCount * 3);
        vbuf.get().unlock();
        kf.setVertexBuffer(vbuf);
    }
    
    override void writePose(Pose pose)
    {
        writeChunkHeader(MeshChunkID.M_POSE, calcPoseSize(pose));
        
        // char* name (may be blank)
        writeString(pose.getName());
        
        // ushort target
        ushort val = pose.getTarget();
        writeShorts(&val, 1);
        
        size_t vertexSize = calcPoseVertexSize();
        auto vit = pose.getVertexOffsets();
        foreach(vertexIndex, offset; vit)
        {
            //uint vertexIndex = cast(uint)vit.peekNextKey();
            //Vector3 offset = vit.getNext();
            writeChunkHeader(MeshChunkID.M_POSE_VERTEX, vertexSize);
            // ulong vertexIndex
            uint _vertexIndex = cast(uint)vertexIndex;
            writeInts(&_vertexIndex, 1);
            // float xoffset, yoffset, zoffset
            writeFloats(offset.ptr(), 3);
        }
    }
    
    override void readPose(DataStream stream, ref Mesh pMesh)
    {
        // char* name (may be blank)
        string name = readString(stream);
        // ushort target
        ushort target;
        readShorts(stream, &target, 1);
        
        Pose pose = pMesh.createPose(target, name);
        
        // Find all substreams
        if (!stream.eof())
        {
            ushort streamID = readChunk(stream);
            while(!stream.eof() &&
                  (streamID == MeshChunkID.M_POSE_VERTEX))
            {
                switch(streamID)
                {
                    case MeshChunkID.M_POSE_VERTEX:
                        // create vertex offset
                        uint vertIndex;
                        Vector3 offset;
                        // ulong vertexIndex
                        readInts(stream, &vertIndex, 1);
                        // float xoffset, yoffset, zoffset
                        readFloats(stream, offset.ptr(), 3);
                        
                        pose.addVertex(vertIndex, offset);
                        break;
                    default:
                        break;
                        
                }
                
                if (!stream.eof())
                {
                    streamID = readChunk(stream);
                }
                
            }
            if (!stream.eof())
            {
                // Backpedal back to start of stream
                stream.skip(-MSTREAM_OVERHEAD_SIZE);
            }
        }
    }
    
    override size_t calcMorphKeyframeSize(VertexMorphKeyFrame kf, size_t vertexCount)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        // float time
        size += float.sizeof;
        // float x,y,z
        size += float.sizeof * 3 * vertexCount;
        
        return size;
    }
    
    override size_t calcPoseSize(Pose pose)
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        
        // char* name (may be blank)
        size += pose.getName().length + 1;
        // ushort target
        size += ushort.sizeof;
        
        // vertex offsets
        size += pose.getVertexOffsets().length * calcPoseVertexSize();
        
        return size;
        
    }
    
    size_t calcPoseVertexSize()
    {
        size_t size = MSTREAM_OVERHEAD_SIZE;
        // ulong vertexIndex
        size += uint.sizeof;
        // float xoffset, yoffset, zoffset
        size += float.sizeof * 3;
        
        return size;
    }
}

/** Class for providing backwards-compatibility for loading version 1.4 of the .mesh format. 
 This mesh format was used from Ogre v1.4.
 */
class MeshSerializerImpl_v1_4 : MeshSerializerImpl_v1_41
{
public:
    this()
    {
        // Version number
        mVersion = "[MeshSerializer_v1.40]";
    }
    
    ~this() {}
protected:
    override void writeLodSummary(ushort numLevels, bool manual, ref LodStrategy strategy)
    {
        // Header
        size_t size = MSTREAM_OVERHEAD_SIZE;
        // ushort numLevels;
        size += ushort.sizeof;
        // bool manual;  (true for manual alternate meshes, false for generated)
        size += bool.sizeof;
        writeChunkHeader(MeshChunkID.M_MESH_LOD, size);
        
        // Details
        // ushort numLevels;
        writeShorts(&numLevels, 1);
        // bool manual;  (true for manual alternate meshes, false for generated)
        writeBools(&manual, 1);
        
        
    }
    
    override void writeLodUsageManual(MeshLodUsage usage)
    {
        // Header
        size_t size = MSTREAM_OVERHEAD_SIZE;
        size_t manualSize = MSTREAM_OVERHEAD_SIZE;
        // float fromDepthSquared;
        size += float.sizeof;
        // Manual part size
        
        // string manualMeshName;
        manualSize += usage.manualName.length + 1;
        
        size += manualSize;
        
        writeChunkHeader(MeshChunkID.M_MESH_LOD_USAGE, size);
        // Main difference to later version here is that we use 'value' (squared depth)
        // rather than 'userValue' which is just depth
        writeFloats(&(usage.value), 1);
        
        writeChunkHeader(MeshChunkID.M_MESH_LOD_MANUAL, manualSize);
        writeString(usage.manualName);
        
        
    }
    
    override void writeLodUsageGenerated(Mesh pMesh, ref MeshLodUsage usage,
                                         ushort lodNum)
    {
        // Usage Header
        size_t size = MSTREAM_OVERHEAD_SIZE;
        ushort subidx;
        
        // float fromDepthSquared;
        size += float.sizeof;
        
        // Calc generated SubMesh sections size
        for(subidx = 0; subidx < pMesh.getNumSubMeshes(); ++subidx)
        {
            // header
            size += MSTREAM_OVERHEAD_SIZE;
            // uint numFaces;
            size += uint.sizeof;
            SubMesh sm = pMesh.getSubMesh(subidx);
            IndexData indexData = sm.mLodFaceList[lodNum - 1];
            
            // bool indexes32Bit
            size += bool.sizeof;
            // ushort*/int* faceIndexes;
            if (!indexData.indexBuffer.isNull() &&
                indexData.indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_32BIT)
            {
                size += cast(ulong)(
                    uint.sizeof * indexData.indexCount);
            }
            else
            {
                size += cast(ulong)(
                    ushort.sizeof * indexData.indexCount);
            }
            
        }
        
        writeChunkHeader(MeshChunkID.M_MESH_LOD_USAGE, size);
        // Main difference to later version here is that we use 'value' (squared depth)
        // rather than 'userValue' which is just depth
        writeFloats(&(usage.value), 1);
        
        // Now write sections
        // Calc generated SubMesh sections size
        for(subidx = 0; subidx < pMesh.getNumSubMeshes(); ++subidx)
        {
            size = MSTREAM_OVERHEAD_SIZE;
            // uint numFaces;
            size += uint.sizeof;
            SubMesh sm = pMesh.getSubMesh(subidx);
            IndexData indexData = sm.mLodFaceList[lodNum - 1];
            // bool indexes32Bit
            size += bool.sizeof;
            // Lock index buffer to write
            SharedPtr!HardwareIndexBuffer ibuf = indexData.indexBuffer;
            // bool indexes32bit
            bool idx32 = (!ibuf.isNull() 
                          && ibuf.get().getType() == HardwareIndexBuffer.IndexType.IT_32BIT);
            // ushort*/int* faceIndexes;
            if (idx32)
            {
                size += cast(ulong)(
                    uint.sizeof * indexData.indexCount);
            }
            else
            {
                size += cast(ulong)(
                    ushort.sizeof * indexData.indexCount);
            }
            
            writeChunkHeader(MeshChunkID.M_MESH_LOD_GENERATED, size);
            uint idxCount = cast(uint)(indexData.indexCount);
            writeInts(&idxCount, 1);
            writeBools(&idx32, 1);
            
            if (idxCount > 0)
            {
                if (idx32)
                {
                    uint* pIdx = cast(uint*)(
                        ibuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
                    writeInts(pIdx, indexData.indexCount);
                    ibuf.get().unlock();
                }
                else
                {
                    ushort* pIdx = cast(ushort*)(
                        ibuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
                    writeShorts(pIdx, indexData.indexCount);
                    ibuf.get().unlock();
                }
            }
        }
        
        
    }   
    
    override void readMeshLodInfo(DataStream stream, ref Mesh pMesh)
    {
        ushort streamID, i;
        
        // Use the old strategy for this mesh
        LodStrategy strategy = DistanceLodStrategy.getSingleton();
        pMesh.setLodStrategy(strategy);
        
        // ushort numLevels;
        readShorts(stream, &(pMesh.mNumLods), 1);
        // bool manual;  (true for manual alternate meshes, false for generated)
        readBools(stream, &(pMesh.mIsLodManual), 1);
        
        // Preallocate submesh lod face data if not manual
        if (!pMesh.mIsLodManual)
        {
            ushort numsubs = pMesh.getNumSubMeshes();
            for (i = 0; i < numsubs; ++i)
            {
                SubMesh sm = pMesh.getSubMesh(i);
                sm.mLodFaceList.length = (pMesh.mNumLods-1);
            }
        }
        
        // Loop from 1 rather than 0 (full detail index is not in file)
        for (i = 1; i < pMesh.mNumLods; ++i)
        {
            streamID = readChunk(stream);
            if (streamID != MeshChunkID.M_MESH_LOD_USAGE)
            {
                throw new ItemNotFoundError(
                    "Missing MeshChunkID.M_MESH_LOD_USAGE stream in " ~ pMesh.getName(),
                    "MeshSerializerImpl.readMeshLodInfo");
            }
            // Read depth
            MeshLodUsage usage;
            readFloats(stream, &(usage.value), 1);
            usage.userValue = Math.Sqrt(usage.value);
            
            if (pMesh.isLodManual())
            {
                readMeshLodUsageManual(stream, pMesh, i, usage);
            }
            else //(!pMesh.isLodManual)
            {
                readMeshLodUsageGenerated(stream, pMesh, i, usage);
            }
            usage.edgeData = null;
            
            // Save usage
            pMesh.mMeshLodUsageList.insert(usage);
        }
        
    }
}

/** Class for providing backwards-compatibility for loading version 1.3 of the .mesh format. 
 This mesh format was used from Ogre v1.0 (and some pre-releases)
 */
class MeshSerializerImpl_v1_3 : MeshSerializerImpl_v1_4
{
public:
    this()
    {
        // Version number
        mVersion = "[MeshSerializer_v1.30]";
    }
    ~this(){}
protected:
    override void readEdgeListLodInfo(DataStream stream, ref EdgeData edgeData)
    {
        // ulong numTriangles
        uint numTriangles;
        readInts(stream, &numTriangles, 1);
        // Allocate correct amount of memory
        edgeData.triangles.length = (numTriangles);
        edgeData.triangleFaceNormals.length = (numTriangles);
        edgeData.triangleLightFacings.length = (numTriangles);
        // ulong numEdgeGroups
        uint numEdgeGroups;
        readInts(stream, &numEdgeGroups, 1);
        // Allocate correct amount of memory
        edgeData.edgeGroups.length = (numEdgeGroups);
        // Triangle* triangleList
        uint[3] tmp;
        for (size_t t = 0; t < numTriangles; ++t)
        {
            EdgeData.Triangle* tri = &(edgeData.triangles[t]);
            // ulong indexSet
            readInts(stream, tmp.ptr, 1);
            tri.indexSet = tmp[0];
            // ulong vertexSet
            readInts(stream, tmp.ptr, 1);
            tri.vertexSet = tmp[0];
            // ulong vertIndex[3]
            readInts(stream, tmp.ptr, 3);
            tri.vertIndex[0] = tmp[0];
            tri.vertIndex[1] = tmp[1];
            tri.vertIndex[2] = tmp[2];
            // ulong sharedVertIndex[3]
            readInts(stream, tmp.ptr, 3);
            tri.sharedVertIndex[0] = tmp[0];
            tri.sharedVertIndex[1] = tmp[1];
            tri.sharedVertIndex[2] = tmp[2];
            // float normal[4]
            readFloats(stream, edgeData.triangleFaceNormals[t].ptr, 4);
            
        }
        
        // Assume the mesh is closed, it will update later
        edgeData.isClosed = true;
        
        for (uint eg = 0; eg < numEdgeGroups; ++eg)
        {
            ushort streamID = readChunk(stream);
            if (streamID != MeshChunkID.M_EDGE_GROUP)
            {
                throw new InternalError(
                    "Missing MeshChunkID.M_EDGE_GROUP stream",
                    "MeshSerializerImpl_v1_3.readEdgeListLodInfo");
            }
            EdgeData.EdgeGroup* edgeGroup = &(edgeData.edgeGroups[eg]);
            
            // ulong vertexSet
            readInts(stream, tmp.ptr, 1);
            edgeGroup.vertexSet = tmp[0];
            // ulong numEdges
            uint numEdges;
            readInts(stream, &numEdges, 1);
            edgeGroup.edges.length = (numEdges);
            // Edge* edgeList
            for (uint e = 0; e < numEdges; ++e)
            {
                EdgeData.Edge* edge = &(edgeGroup.edges[e]);
                // ulong  triIndex[2]
                readInts(stream, tmp.ptr, 2);
                edge.triIndex[0] = tmp[0];
                edge.triIndex[1] = tmp[1];
                // ulong  vertIndex[2]
                readInts(stream, tmp.ptr, 2);
                edge.vertIndex[0] = tmp[0];
                edge.vertIndex[1] = tmp[1];
                // ulong  sharedVertIndex[2]
                readInts(stream, tmp.ptr, 2);
                edge.sharedVertIndex[0] = tmp[0];
                edge.sharedVertIndex[1] = tmp[1];
                // bool degenerate
                readBools(stream, &(edge.degenerate), 1);
                
                // The mesh is closed only if no degenerate edge here
                if (edge.degenerate)
                {
                    edgeData.isClosed = false;
                }
            }
        }
        
        reorganiseTriangles(edgeData);
    }
    
    /// Reorganise triangles of the edge list to group by vertex set
    void reorganiseTriangles(ref EdgeData edgeData)
    {
        size_t numTriangles = edgeData.triangles.length;
        
        if (edgeData.edgeGroups.length == 1)
        {
            // Special case for only one edge group in the edge list, which occurring
            // most time. In this case, all triangles belongs to that group.
            edgeData.edgeGroups[0].triStart = 0;
            edgeData.edgeGroups[0].triCount = numTriangles;
        }
        else
        {
            // Calculate number of triangles for edge groups
            
            foreach (ref egi; edgeData.edgeGroups)
            {
                egi.triStart = 0;
                egi.triCount = 0;
            }
            
            bool isGrouped = true;
            EdgeData.EdgeGroup* lastEdgeGroup = null;
            for (size_t t = 0; t < numTriangles; ++t)
            {
                // Gets the edge group that the triangle belongs to
                EdgeData.Triangle* tri = &(edgeData.triangles[t]);
                EdgeData.EdgeGroup* edgeGroup = &(edgeData.edgeGroups[tri.vertexSet]);
                
                // Does edge group changes from last edge group?
                if (isGrouped && edgeGroup != lastEdgeGroup)
                {
                    // Remember last edge group
                    lastEdgeGroup = edgeGroup;
                    
                    // Is't first time encounter this edge group?
                    if (!edgeGroup.triCount && !edgeGroup.triStart)
                    {
                        // setup first triangle of this edge group
                        edgeGroup.triStart = t;
                    }
                    else
                    {
                        // original triangles doesn't grouping by edge group
                        isGrouped = false;
                    }
                }
                
                // Count number of triangles for this edge group
                if(edgeGroup !is null)
                    ++edgeGroup.triCount;
            }
            
            //
            // Note that triangles has been sorted by vertex set for a long time,
            // but never stored to old version mesh file.
            //
            // Adopt this fact to avoid remap triangles here.
            //
            
            // Does triangles grouped by vertex set?
            if (!isGrouped)
            {
                // Ok, the triangles of this edge list isn't grouped by vertex set
                // perfectly, seems ancient mesh file.
                //
                // We need work hardly to group triangles by vertex set.
                //
                
                // Calculate triStart and reset triCount to zero for each edge group first
                size_t triStart = 0;
                foreach (ref egi; edgeData.edgeGroups)
                {
                    egi.triStart = triStart;
                    triStart += egi.triCount;
                    egi.triCount = 0;
                }
                
                // The map used to mapping original triangle index to new index
                //typedef vector<size_t>::type TriangleIndexRemap;
                //size_t[] TriangleIndexRemap;
                //TriangleIndexRemap triangleIndexRemap(numTriangles);
                size_t[] triangleIndexRemap = new size_t[numTriangles];
                
                // New triangles information that should be group by vertex set.
                //TODO works? 
                //auto newTriangles = EdgeData.TriangleList(numTriangles);
                //auto newTriangleFaceNormals = EdgeData.TriangleFaceNormalList(numTriangles);
                
                EdgeData.TriangleList newTriangles;
                newTriangles.length = numTriangles;
                
                EdgeData.TriangleFaceNormalList newTriangleFaceNormals; 
                newTriangleFaceNormals.length = numTriangles;
                
                // Calculate triangle index map and organise triangles information
                for (size_t t = 0; t < numTriangles; ++t)
                {
                    // Gets the edge group that the triangle belongs to
                    EdgeData.Triangle* tri = &(edgeData.triangles[t]);
                    EdgeData.EdgeGroup* edgeGroup = &(edgeData.edgeGroups[tri.vertexSet]);
                    
                    // Calculate new index
                    size_t newIndex = edgeGroup.triStart + edgeGroup.triCount;
                    ++edgeGroup.triCount;
                    
                    // Setup triangle index mapping entry
                    triangleIndexRemap[t] = newIndex;
                    
                    // Copy triangle info to new placement
                    //TODO Pointer to old struct or copy?
                    newTriangles[newIndex] = *tri;
                    newTriangleFaceNormals[newIndex] = edgeData.triangleFaceNormals[t];
                }
                
                //TODO Does swap work?
                // Replace with new triangles information
                std.algorithm.swap(edgeData.triangles, newTriangles);
                std.algorithm.swap(edgeData.triangleFaceNormals, newTriangleFaceNormals);
                
                // Now, update old triangle indices to new index
                foreach (ref egi; edgeData.edgeGroups)
                {
                    foreach (ref ei; egi.edges)
                    {
                        ei.triIndex[0] = triangleIndexRemap[ei.triIndex[0]];
                        if (!ei.degenerate)
                        {
                            ei.triIndex[1] = triangleIndexRemap[ei.triIndex[1]];
                        }
                    }
                }
            }
        }
    }
    
    override void writeEdgeList(Mesh pMesh)
    {
        writeChunkHeader(MeshChunkID.M_EDGE_LISTS, calcEdgeListSize(pMesh));
        
        for (ushort i = 0; i < pMesh.getNumLodLevels(); ++i)
        {
            EdgeData edgeData = pMesh.getEdgeList(i);
            bool isManual = pMesh.isLodManual() && (i > 0);
            writeChunkHeader(MeshChunkID.M_EDGE_LIST_LOD, calcEdgeListLodSize(edgeData, isManual));
            
            // ushort lodIndex
            writeShorts(&i, 1);
            
            // bool isManual            // If manual, no edge data here, loaded from manual mesh
            writeBools(&isManual, 1);
            if (!isManual)
            {
                // ulong  numTriangles
                uint count = cast(uint)(edgeData.triangles.length);
                writeInts(&count, 1);
                // ulong numEdgeGroups
                count = cast(uint)(edgeData.edgeGroups.length);
                writeInts(&count, 1);
                // Triangle* triangleList
                // Iterate rather than writing en-masse to allow endian conversion
                //auto t = edgeData.triangles.begin();
                
                foreach (t; 0..edgeData.triangles.length)
                {
                    auto tri = edgeData.triangles[t];
                    auto fni = edgeData.triangleFaceNormals[t];
                    
                    // ulong indexSet;
                    uint[3] tmp;
                    tmp[0] = cast(uint)tri.indexSet;
                    writeInts(tmp.ptr, 1);
                    // ulong vertexSet;
                    tmp[0] = cast(uint)tri.vertexSet;
                    writeInts(tmp.ptr, 1);
                    // ulong vertIndex[3];
                    tmp[0] = cast(uint)tri.vertIndex[0];
                    tmp[1] = cast(uint)tri.vertIndex[1];
                    tmp[2] = cast(uint)tri.vertIndex[2];
                    writeInts(tmp.ptr, 3);
                    // ulong sharedVertIndex[3];
                    tmp[0] = cast(uint)tri.sharedVertIndex[0];
                    tmp[1] = cast(uint)tri.sharedVertIndex[1];
                    tmp[2] = cast(uint)tri.sharedVertIndex[2];
                    writeInts(tmp.ptr, 3);
                    // float normal[4];
                    writeFloats(fni.ptr, 4);
                    
                }
                // Write the groups
                foreach (ref edgeGroup; edgeData.edgeGroups)
                {
                    writeChunkHeader(MeshChunkID.M_EDGE_GROUP, calcEdgeGroupSize(edgeGroup));
                    // ulong vertexSet
                    uint vertexSet = cast(uint)(edgeGroup.vertexSet);
                    writeInts(&vertexSet, 1);
                    // ulong numEdges
                    count = cast(uint)(edgeGroup.edges.length);
                    writeInts(&count, 1);
                    // Edge* edgeList
                    // Iterate rather than writing en-masse to allow endian conversion
                    foreach (ref edge; edgeGroup.edges)
                    {
                        uint[2] tmp;
                        // ulong  triIndex[2]
                        tmp[0] = cast(uint)edge.triIndex[0];
                        tmp[1] = cast(uint)edge.triIndex[1];
                        writeInts(tmp.ptr, 2);
                        // ulong  vertIndex[2]
                        tmp[0] = cast(uint)edge.vertIndex[0];
                        tmp[1] = cast(uint)edge.vertIndex[1];
                        writeInts(tmp.ptr, 2);
                        // ulong  sharedVertIndex[2]
                        tmp[0] = cast(uint)edge.sharedVertIndex[0];
                        tmp[1] = cast(uint)edge.sharedVertIndex[1];
                        writeInts(tmp.ptr, 2);
                        // bool degenerate
                        writeBools(&(edge.degenerate), 1);
                    }
                    
                }
                
            }
            
        }
    }
}

/** Class for providing backwards-compatibility for loading version 1.2 of the .mesh format. 
 This is a LEGACY FORMAT that pre-dates version Ogre 1.0
 */
class MeshSerializerImpl_v1_2 : MeshSerializerImpl_v1_3
{
public:
    this()
    {
        // Version number
        mVersion = "[MeshSerializer_v1.20]";
    }
    
    ~this() {}
protected:
    override void readMesh(DataStream stream, ref Mesh pMesh, ref MeshSerializerListener listener)
    {
        super.readMesh(stream, pMesh, listener);
        // Always automatically build edge lists for this version
        pMesh.mAutoBuildEdgeLists = true;
        
    }
    
    override void readGeometry(DataStream stream, ref Mesh pMesh, ref VertexData dest)
    {
        ushort bindIdx = 0;
        
        dest.vertexStart = 0;
        
        uint vertexCount = 0;
        readInts(stream, &vertexCount, 1);
        dest.vertexCount = vertexCount;
        
        // Vertex buffers
        
        readGeometryPositions(bindIdx, stream, pMesh, dest);
        ++bindIdx;
        
        // Find optional geometry streams
        if (!stream.eof())
        {
            ushort streamID = readChunk(stream);
            ushort texCoordSet = 0;
            
            while(!stream.eof() &&
                  (streamID == MeshChunkID.M_GEOMETRY_NORMALS ||
             streamID == MeshChunkID.M_GEOMETRY_COLOURS ||
             streamID == MeshChunkID.M_GEOMETRY_TEXCOORDS ))
            {
                switch (streamID)
                {
                    case MeshChunkID.M_GEOMETRY_NORMALS:
                        readGeometryNormals(bindIdx++, stream, pMesh, dest);
                        break;
                    case MeshChunkID.M_GEOMETRY_COLOURS:
                        readGeometryColours(bindIdx++, stream, pMesh, dest);
                        break;
                    case MeshChunkID.M_GEOMETRY_TEXCOORDS:
                        readGeometryTexCoords(bindIdx++, stream, pMesh, dest, texCoordSet++);
                        break;
                    default:
                        break;
                }
                // Get next stream
                if (!stream.eof())
                {
                    streamID = readChunk(stream);
                }
            }
            if (!stream.eof())
            {
                // Backpedal back to start of non-submesh stream
                stream.skip(-MSTREAM_OVERHEAD_SIZE);
            }
        }
    }
    
    void readGeometryPositions(ushort bindIdx, DataStream stream, 
                               ref Mesh pMesh, ref VertexData dest)
    {
        float *pFloat = null;
        SharedPtr!HardwareVertexBuffer vbuf;
        // float* pVertices (x, y, z order x numVertices)
        dest.vertexDeclaration.addElement(bindIdx, 0, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_POSITION);
        vbuf = HardwareBufferManager.getSingleton().createVertexBuffer(
            dest.vertexDeclaration.getVertexSize(bindIdx),
            dest.vertexCount,
            pMesh.mVertexBufferUsage,
            pMesh.mVertexBufferShadowBuffer);
        pFloat = cast(float*)(
            vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
        readFloats(stream, pFloat, dest.vertexCount * 3);
        vbuf.get().unlock();
        dest.vertexBufferBinding.setBinding(bindIdx, vbuf);
    }
    
    void readGeometryNormals(ushort bindIdx, DataStream stream, 
                             ref Mesh pMesh, ref VertexData dest)
    {
        float *pFloat = null;
        SharedPtr!HardwareVertexBuffer vbuf;
        // float* pNormals (x, y, z order x numVertices)
        dest.vertexDeclaration.addElement(bindIdx, 0, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_NORMAL);
        vbuf = HardwareBufferManager.getSingleton().createVertexBuffer(
            dest.vertexDeclaration.getVertexSize(bindIdx),
            dest.vertexCount,
            pMesh.mVertexBufferUsage,
            pMesh.mVertexBufferShadowBuffer);
        pFloat = cast(float*)(
            vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
        readFloats(stream, pFloat, dest.vertexCount * 3);
        vbuf.get().unlock();
        dest.vertexBufferBinding.setBinding(bindIdx, vbuf);
    }
    
    void readGeometryColours(ushort bindIdx, DataStream stream, 
                             ref Mesh pMesh, ref VertexData dest)
    {
        RGBA* pRGBA = null;
        SharedPtr!HardwareVertexBuffer vbuf;
        // ulong* pColours (RGBA 8888 format x numVertices)
        dest.vertexDeclaration.addElement(bindIdx, 0, VertexElementType.VET_COLOUR, VertexElementSemantic.VES_DIFFUSE);
        vbuf = HardwareBufferManager.getSingleton().createVertexBuffer(
            dest.vertexDeclaration.getVertexSize(bindIdx),
            dest.vertexCount,
            pMesh.mVertexBufferUsage,
            pMesh.mVertexBufferShadowBuffer);
        pRGBA = cast(RGBA*)(
            vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
        readInts(stream, pRGBA, dest.vertexCount);
        vbuf.get().unlock();
        dest.vertexBufferBinding.setBinding(bindIdx, vbuf);
    }
    
    void readGeometryTexCoords(ushort bindIdx, DataStream stream, 
                               ref Mesh pMesh, ref VertexData dest, ushort texCoordSet)
    {
        float *pFloat = null;
        SharedPtr!HardwareVertexBuffer vbuf;
        // ushort dimensions    (1 for 1D, 2 for 2D, 3 for 3D)
        ushort dim;
        readShorts(stream, &dim, 1);
        // float* pTexCoords  (u [v] [w] order, dimensions x numVertices)
        dest.vertexDeclaration.addElement(
            bindIdx,
            0,
            VertexElement.multiplyTypeCount(VertexElementType.VET_FLOAT1, dim),
            VertexElementSemantic.VES_TEXTURE_COORDINATES,
            texCoordSet);
        vbuf = HardwareBufferManager.getSingleton().createVertexBuffer(
            dest.vertexDeclaration.getVertexSize(bindIdx),
            dest.vertexCount,
            pMesh.mVertexBufferUsage,
            pMesh.mVertexBufferShadowBuffer);
        pFloat = cast(float*)(
            vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
        readFloats(stream, pFloat, dest.vertexCount * dim);
        vbuf.get().unlock();
        dest.vertexBufferBinding.setBinding(bindIdx, vbuf);
    }
}

/** Class for providing backwards-compatibility for loading version 1.1 of the .mesh format. 
 This is a LEGACY FORMAT that pre-dates version Ogre 1.0
 */
class MeshSerializerImpl_v1_1 : MeshSerializerImpl_v1_2
{
public:
    this()
    {
        // Version number
        mVersion = "[MeshSerializer_v1.10]";
    }
    ~this() {}
protected:
    override void readGeometryTexCoords(ushort bindIdx, DataStream stream, 
                                        ref Mesh pMesh, ref VertexData dest, ushort texCoordSet)
    {
        float *pFloat = null;
        SharedPtr!HardwareVertexBuffer vbuf;
        // ushort dimensions    (1 for 1D, 2 for 2D, 3 for 3D)
        ushort dim;
        readShorts(stream, &dim, 1);
        // float* pTexCoords  (u [v] [w] order, dimensions x numVertices)
        dest.vertexDeclaration.addElement(
            bindIdx,
            0,
            VertexElement.multiplyTypeCount(VertexElementType.VET_FLOAT1, dim),
            VertexElementSemantic.VES_TEXTURE_COORDINATES,
            texCoordSet);
        vbuf = HardwareBufferManager.getSingleton().createVertexBuffer(
            dest.vertexDeclaration.getVertexSize(bindIdx),
            dest.vertexCount,
            pMesh.getVertexBufferUsage(),
            pMesh.isVertexBufferShadowed());
        pFloat = cast(float*)(
            vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
        readFloats(stream, pFloat, dest.vertexCount * dim);
        
        // Adjust individual v values to (1 - v)
        if (dim == 2)
        {
            for (size_t i = 0; i < dest.vertexCount; ++i)
            {
                ++pFloat; // skip u
                *pFloat = 1.0f - *pFloat; // v = 1 - v
                ++pFloat;
            }
            
        }
        vbuf.get().unlock();
        dest.vertexBufferBinding.setBinding(bindIdx, vbuf);
    }
}
/** @} */
/** @} */
