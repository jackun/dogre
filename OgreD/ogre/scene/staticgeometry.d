module ogre.scene.staticgeometry;

import core.stdc.string : memcpy;
//import std.container;
import std.array;
import ogre.compat;
import ogre.exception;
import ogre.general.common;
import ogre.general.generals;
import ogre.general.root;
import ogre.lod.lodstrategy;
import ogre.materials.materialmanager;
import ogre.materials.pass;
import ogre.math.axisalignedbox;
import ogre.math.edgedata;
import ogre.math.maths;
import ogre.math.matrix;
import ogre.math.quaternion;
import ogre.math.vector;
import ogre.rendersystem.hardware;
import ogre.rendersystem.renderqueue;
import ogre.rendersystem.vertex;
import ogre.resources.mesh;
import ogre.scene.entity;
import ogre.scene.light;
import ogre.scene.movableobject;
import ogre.scene.renderable;
import ogre.scene.scenenode;
import ogre.scene.shadowcaster;
import ogre.general.log;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Scene
 *  @{
 */
/** Pre-transforms and batches up meshes for efficient use as static
 geometry in a scene.
 @remarks
 Modern graphics cards (GPUs) prefer to receive geometry in large
 batches. It is orders of magnitude faster to render 10 batches
 of 10,000 triangles than it is to render 10,000 batches of 10 
 triangles, even though both result in the same number of on-screen
 triangles.
 @par
 Therefore it is important when you are rendering a lot of geometry to 
 batch things up into as few rendering calls as possible. This
 class allows you to build a batched object from a series of entities 
 in order to benefit from this behaviour.
 Batching has implications of it's own though:
 @li Batched geometry cannot be subdivided; that means that the whole
 group will be displayed, or none of it will. This obivously has
 culling issues.
 @li A single world transform must apply to the entire batch. Therefore
 once you have batched things, you can't move them around relative to
 each other. That's why this class is most useful when dealing with 
 static geometry (hence the name). In addition, geometry is 
 effectively duplicated, so if you add 3 entities based on the same 
 mesh in different positions, they will use 3 times the geometry 
 space than the movable version (which re-uses the same geometry). 
 So you trade memory and flexibility of movement for pure speed when
 using this class.
 @li A single material must apply for each batch. In fact this class 
 allows you to use multiple materials, but you should be aware that 
 internally this means that there is one batch per material. 
 Therefore you won't gain as much benefit from the batching if you 
 use many different materials; try to keep the number down.
 @par
 In order to retain some sort of culling, this class will batch up 
 meshes in localised regions. The size and shape of these blocks is
 controlled by the SceneManager whichructs this object, since it
 makes sense to batch things up in the most appropriate way given the 
 existing partitioning of the scene. 
 @par
 The LOD settings of both the Mesh and the Materials used in 
 constructing this static geometry will be respected. This means that 
 if you use meshes/materials which have LOD, batches in the distance 
 will have a lower polygon count or material detail to those in the 
 foreground. Since each mesh might have different LOD distances, during 
 build the furthest distance at each LOD level from all meshes  
 in that region is used. This means all the LOD levels change at the 
 same time, but at the furthest distance of any of them (so quality is 
 not degraded). Be aware that using Mesh LOD in this class will 
 further increase the memory required. Only generated LOD
 is supported for meshes.
 @par
 There are 2 ways you can add geometry to this class; you can add
 Entity objects directly with predetermined positions, scales and 
 orientations, or you can add an entire SceneNode and it's subtree, 
 including all the objects attached to it. Once you've added everything
 you need to, you have to call build() the fix the geometry in place. 
 @note
 This class is not a replacement for world geometry (@see 
 SceneManager::setWorldGeometry). The single most efficient way to 
 render large amounts of static geometry is to use a SceneManager which 
 is specialised for dealing with that particular world structure. 
 However, this class does provide you with a good 'halfway house'
 between generalised movable geometry (Entity) which works with all 
 SceneManagers but isn't efficient when using very large numbers, and 
 highly specialised world geometry which is extremely fast but not 
 generic and typically requires custom world editors.
 @par
 You should notruct instances of this class directly; instead, cal 
 SceneManager::createStaticGeometry, which gives the SceneManager the 
 option of providing you with a specialised version of this class if it
 wishes, and also handles the memory management for you like other 
 classes.
 @note
 Warning: this class only works with indexed triangle lists at the moment,
 do not pass it triangle strips, fans or lines / points, or unindexed geometry.
 */
class StaticGeometry //: public BatchedGeometryAlloc
{
    enum REGION_RANGE = 1024;
    enum REGION_HALF_RANGE = 512;
    enum REGION_MAX_INDEX  = 511;
    enum REGION_MIN_INDEX  = -512;

public:
    /** Struct holding geometry optimised per SubMesh / lod level, ready
     for copying to instances. 
     @remarks
     Since we're going to be duplicating geometry lots of times, it's
     far more important that we don't have redundant vertex data. If a 
     SubMesh uses shared geometry, or we're looking at a lower LOD, not
     all the vertices are being referenced by faces on that submesh.
     Therefore to duplicate them, potentially hundreds or even thousands
     of times, would be extremely wasteful. Therefore, if a SubMesh at
     a given LOD has wastage, we create an optimised version of it's
     geometry which is ready for copying with no wastage.
     */
    static class OptimisedSubMeshGeometry //: public BatchedGeometryAlloc
    {
    public:
        this() 
        { 
            //vertexData = 0; indexData = 0; 
        }
        ~this() 
        {
            destroy(vertexData);
            destroy(indexData);
        }
        VertexData vertexData;
        IndexData indexData;
    }

    //typedef list<OptimisedSubMeshGeometry*>::type OptimisedSubMeshGeometryList;
    alias OptimisedSubMeshGeometry[] OptimisedSubMeshGeometryList;
    /// Saved link between SubMesh at a LOD and vertex/index data
    /// May point to original or optimised geometry
    struct SubMeshLodGeometryLink
    {
        VertexData vertexData;
        IndexData indexData;
    }

    //typedef vector<SubMeshLodGeometryLink>::type SubMeshLodGeometryLinkList;
    //typedef map<SubMesh*, SubMeshLodGeometryLinkList*>::type SubMeshGeometryLookup;
    alias SubMeshLodGeometryLink[] SubMeshLodGeometryLinkList;
    alias SubMeshLodGeometryLinkList[SubMesh] SubMeshGeometryLookup;

    /// Structure recording a queued submesh for the build
    struct QueuedSubMesh //: public BatchedGeometryAlloc
    {
        SubMesh submesh;
        /// Link to LOD list of geometry, potentially optimised
        SubMeshLodGeometryLinkList* geometryLodList;
        string materialName;
        Vector3 position;
        Quaternion orientation;
        Vector3 scale;
        /// Pre-transformed world AABB 
        AxisAlignedBox worldBounds;
    }

    //typedef vector<QueuedSubMesh*>::type QueuedSubMeshList;
    alias QueuedSubMesh[] QueuedSubMeshList;
    /// Structure recording a queued geometry for low level builds
    struct QueuedGeometry //: public BatchedGeometryAlloc
    {
        SubMeshLodGeometryLink geometry;
        Vector3 position;
        Quaternion orientation;
        Vector3 scale;
    }
    //typedef vector<QueuedGeometry*>::type QueuedGeometryList;
    alias QueuedGeometry[] QueuedGeometryList;

    /** A GeometryBucket is a the lowest level bucket where geometry with 
     the same vertex & index format is stored. It also acts as the 
     renderable.
     */
    static class GeometryBucket : Renderable //,  public BatchedGeometryAlloc
    {
        mixin Renderable.Renderable_Impl;
        mixin Renderable.Renderable_Any_Impl;
    protected:
        /// Geometry which has been queued up pre-build (not for deallocation)
        QueuedGeometryList mQueuedGeometry;
        /// Pointer to parent bucket
        MaterialBucket mParent;
        /// String identifying the vertex / index format
        string mFormatString;
        /// Vertex information, includes current number of vertices
        /// committed to be a part of this bucket
        VertexData mVertexData;
        /// Index information, includes index type which limits the max
        /// number of vertices which are allowed in one bucket
        IndexData mIndexData;
        /// Size of indexes
        HardwareIndexBuffer.IndexType mIndexType;
        /// Maximum vertex indexable
        size_t mMaxVertexIndex;

        void copyIndexes(T)(T* src, T* dst, size_t count, size_t indexOffset)
        {
            if (indexOffset == 0)
            {
                memcpy(dst, src, T.sizeof * count);
            }
            else
            {
                while(count--)
                {
                    *dst++ = cast(T)(*src++ + indexOffset);
                }
            }
        }
    public:
        this(ref MaterialBucket parent,string formatString, 
             ref VertexData vData, ref IndexData iData)
        {
            mParent = parent;
            mFormatString = formatString;

            // Clone the structure from the example
            mVertexData = vData.clone(false);
            mIndexData = iData.clone(false);
            mVertexData.vertexCount = 0;
            mVertexData.vertexStart = 0;
            mIndexData.indexCount = 0;
            mIndexData.indexStart = 0;
            mIndexType = iData.indexBuffer.get().getType();
            // Derive the max vertices
            if (mIndexType == HardwareIndexBuffer.IndexType.IT_32BIT)
            {
                mMaxVertexIndex = 0xFFFFFFFF;
            }
            else
            {
                mMaxVertexIndex = 0xFFFF;
            }
            
            // Check to see if we have blend indices / blend weights
            // remove them if so, they can try to blend non-existent bones!
            VertexElement blendIndices =
                mVertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_BLEND_INDICES);
            VertexElement blendWeights =
                mVertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_BLEND_WEIGHTS);
            if (blendIndices && blendWeights)
            {
                assert(blendIndices.getSource() == blendWeights.getSource(),
                       "Blend indices and weights should be in the same buffer");
                // Get the source
                ushort source = blendIndices.getSource();
                assert(blendIndices.getSize() + blendWeights.getSize() ==
                       mVertexData.vertexBufferBinding.getBuffer(source).get().getVertexSize(),
                       "Blend indices and blend buffers should have buffer to themselves!");
                // Unset the buffer
                mVertexData.vertexBufferBinding.unsetBinding(source);
                // Remove the elements
                mVertexData.vertexDeclaration.removeElement(VertexElementSemantic.VES_BLEND_INDICES);
                mVertexData.vertexDeclaration.removeElement(VertexElementSemantic.VES_BLEND_WEIGHTS);
                // Close gaps in bindings for effective and safely
                mVertexData.closeGapsInBindings();
            }
        }

        ~this()
        {
            destroy(mVertexData);
            destroy(mIndexData);
        }

        ref MaterialBucket getParent() { return mParent; }
        /// Get the vertex data for this geometry 
        ref VertexData getVertexData(){ return mVertexData; }
        /// Get the index data for this geometry 
        ref IndexData getIndexData(){ return mIndexData; }
        /// @copydoc Renderable::getMaterial
        SharedPtr!Material getMaterial()
        {
            return mParent.getMaterial();
        }
        Technique getTechnique()
        {
            return mParent.getCurrentTechnique();
        }
        void getRenderOperation(ref RenderOperation op)
        {
            op.indexData = mIndexData;
            op.operationType = RenderOperation.OperationType.OT_TRIANGLE_LIST;
            op.srcRenderable = this;
            op.useIndexes = true;
            op.vertexData = mVertexData;
        }
        void getWorldTransforms(ref Matrix4[] xform)
        {
            // Should be the identity transform, but lets allow transformation of the
            // nodes the regions are attached to for kicks
            xform.insertOrReplace(mParent.getParent().getParent()._getParentNodeFullTransform());
        }
        Real getSquaredViewDepth(Camera cam)
        {
            Region region = mParent.getParent().getParent();
            if (cam == region.mCamera)
                return region.mSquaredViewDepth;
            else
                return region.getParentNode().getSquaredViewDepth(cam.getLodCamera());
        }
        LightList getLights()
        {
            return mParent.getParent().getParent().queryLights();
        }
        bool getCastsShadows()
        {
            return mParent.getParent().getParent().getCastShadows();
        }
        
        /** Try to assign geometry to this bucket.
         @return false if there is no room left in this bucket
         */
        bool assign(ref QueuedGeometry qgeom)
        {
            // Do we have enough space?
            // -2 first to avoid overflow (-1 to adjust count to index, -1 to ensure
            // no overflow at 32 bits and use >= instead of >)
            if ((mVertexData.vertexCount - 2 + qgeom.geometry.vertexData.vertexCount)
                >= mMaxVertexIndex)
            {
                return false;
            }
            
            mQueuedGeometry.insert(qgeom);
            mVertexData.vertexCount += qgeom.geometry.vertexData.vertexCount;
            mIndexData.indexCount += qgeom.geometry.indexData.indexCount;
            
            return true;
        }
        /// Build
        void build(bool stencilShadows)
        {
            // Ok, here's where we transfer the vertices and indexes to the shared
            // buffers
            // Shortcuts
            VertexDeclaration dcl = mVertexData.vertexDeclaration;
            VertexBufferBinding binds = mVertexData.vertexBufferBinding;
            
            // create index buffer, and lock
            mIndexData.indexBuffer = HardwareBufferManager.getSingleton()
                .createIndexBuffer(mIndexType, mIndexData.indexCount,
                                   HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY);
            uint* p32Dest = null;
            ushort* p16Dest = null;
            if (mIndexType == HardwareIndexBuffer.IndexType.IT_32BIT)
            {
                p32Dest = cast(uint*)(
                    mIndexData.indexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
            }
            else
            {
                p16Dest = cast(ushort*)(
                    mIndexData.indexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
            }
            // create all vertex buffers, and lock
            ushort b;
            ushort posBufferIdx = dcl.findElementBySemantic(VertexElementSemantic.VES_POSITION).getSource();
            
            ubyte*[] destBufferLocks;
            //vector<VertexDeclaration::VertexElementList>::type bufferElements;
            VertexDeclaration.VertexElementList[] bufferElements;
            for (b = 0; b < binds.getBufferCount(); ++b)
            {
                size_t vertexCount = mVertexData.vertexCount;
                // Need to double the vertex count for the position buffer
                // if we're doing stencil shadows
                if (stencilShadows && b == posBufferIdx)
                {
                    vertexCount = vertexCount * 2;
                    assert(vertexCount <= mMaxVertexIndex,
                           "Index range exceeded when using stencil shadows, consider "
                           "reducing your region size or reducing poly count");
                }
                SharedPtr!HardwareVertexBuffer vbuf =
                    HardwareBufferManager.getSingleton().createVertexBuffer(
                        dcl.getVertexSize(b),
                        vertexCount,
                        HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY);
                binds.setBinding(b, vbuf);
                ubyte* pLock = cast(ubyte*)(vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
                destBufferLocks ~= pLock;
                // Pre-cache vertex elements per buffer
                bufferElements.insert(dcl.findElementsBySource(b));
            }
            
            
            // Iterate over the geometry items
            size_t indexOffset = 0;
            Vector3 regionCentre = mParent.getParent().getParent().getCentre();
            foreach (geom; mQueuedGeometry)
            {
                // Copy indexes across with offset
                IndexData srcIdxData = geom.geometry.indexData;
                if (mIndexType == HardwareIndexBuffer.IndexType.IT_32BIT)
                {
                    // Lock source indexes
                    uint* pSrc = cast(uint*)(
                        srcIdxData.indexBuffer.get().lock(
                        srcIdxData.indexStart, 
                        srcIdxData.indexCount * srcIdxData.indexBuffer.get().getIndexSize(),
                        HardwareBuffer.LockOptions.HBL_READ_ONLY));
                    
                    copyIndexes(pSrc, p32Dest, srcIdxData.indexCount, indexOffset);
                    p32Dest += srcIdxData.indexCount;
                    srcIdxData.indexBuffer.get().unlock();
                }
                else
                {
                    // Lock source indexes
                    ushort* pSrc = cast(ushort*)(
                        srcIdxData.indexBuffer.get().lock(
                        srcIdxData.indexStart, 
                        srcIdxData.indexCount * srcIdxData.indexBuffer.get().getIndexSize(),
                        HardwareBuffer.LockOptions.HBL_READ_ONLY));
                    
                    copyIndexes(pSrc, p16Dest, srcIdxData.indexCount, indexOffset);
                    p16Dest += srcIdxData.indexCount;
                    srcIdxData.indexBuffer.get().unlock();
                }
                
                // Now deal with vertex buffers
                // we can rely on buffer counts / formats being the same
                VertexData srcVData = geom.geometry.vertexData;
                VertexBufferBinding srcBinds = srcVData.vertexBufferBinding;
                for (b = 0; b < binds.getBufferCount(); ++b)
                {
                    // lock source
                    SharedPtr!HardwareVertexBuffer srcBuf =
                        srcBinds.getBuffer(b);
                    ubyte* pSrcBase = cast(ubyte*)(srcBuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
                    // Get buffer lock pointer, we'll update this later
                    ubyte* pDstBase = destBufferLocks[b];
                    size_t bufInc = srcBuf.get().getVertexSize();
                    
                    // Iterate over vertices
                    float* pSrcReal, pDstReal;
                    Vector3 tmp;
                    for (size_t v = 0; v < srcVData.vertexCount; ++v)
                    {
                        // Iterate over vertex elements
                        auto elems = bufferElements[b];

                        foreach (elem; elems)
                        {
                            elem.baseVertexPointerToElement(pSrcBase, &pSrcReal);
                            elem.baseVertexPointerToElement(pDstBase, &pDstReal);
                            switch (elem.getSemantic())
                            {
                                case VertexElementSemantic.VES_POSITION:
                                    tmp.x = *pSrcReal++;
                                    tmp.y = *pSrcReal++;
                                    tmp.z = *pSrcReal++;
                                    // transform
                                    tmp = (geom.orientation * (tmp * geom.scale)) +
                                        geom.position;
                                    // Adjust for region centre
                                    tmp -= regionCentre;
                                    *pDstReal++ = tmp.x;
                                    *pDstReal++ = tmp.y;
                                    *pDstReal++ = tmp.z;
                                    break;
                                case VertexElementSemantic.VES_NORMAL:
                                case VertexElementSemantic.VES_TANGENT:
                                case VertexElementSemantic.VES_BINORMAL:
                                    tmp.x = *pSrcReal++;
                                    tmp.y = *pSrcReal++;
                                    tmp.z = *pSrcReal++;
                                    // scale (invert)
                                    tmp = tmp / geom.scale;
                                    tmp.normalise();
                                    // rotation
                                    tmp = geom.orientation * tmp;
                                    *pDstReal++ = tmp.x;
                                    *pDstReal++ = tmp.y;
                                    *pDstReal++ = tmp.z;
                                    // copy parity for tangent.
                                    if (elem.getType() == VertexElementType.VET_FLOAT4)
                                        *pDstReal = *pSrcReal;
                                    break;
                                default:
                                    // just raw copy
                                    memcpy(pDstReal, pSrcReal,
                                           VertexElement.getTypeSize(elem.getType()));
                                    break;
                            }
                            
                        }
                        
                        // Increment both pointers
                        pDstBase += bufInc;
                        pSrcBase += bufInc;
                        
                    }
                    
                    // Update pointer
                    destBufferLocks[b] = pDstBase;
                    srcBuf.get().unlock();
                }
                
                indexOffset += geom.geometry.vertexData.vertexCount;
            }
            
            // Unlock everything
            mIndexData.indexBuffer.get().unlock();
            for (b = 0; b < binds.getBufferCount(); ++b)
            {
                binds.getBuffer(b).get().unlock();
            }
            
            // If we're dealing with stencil shadows, copy the position data from
            // the early half of the buffer to the latter part
            if (stencilShadows)
            {
                SharedPtr!HardwareVertexBuffer buf = binds.getBuffer(posBufferIdx);
                void* pSrc = buf.get().lock(HardwareBuffer.LockOptions.HBL_NORMAL);
                // Point dest at second half (remember vertexcount is original count)
                void* pDest = cast(ubyte*)(pSrc) +
                    buf.get().getVertexSize() * mVertexData.vertexCount;
                memcpy(pDest, pSrc, buf.get().getVertexSize() * mVertexData.vertexCount);
                buf.get().unlock();
                
                // Also set up hardware W buffer if appropriate
                RenderSystem rend = Root.getSingleton().getRenderSystem();
                if (rend && rend.getCapabilities().hasCapability(Capabilities.RSC_VERTEX_PROGRAM))
                {
                    buf = HardwareBufferManager.getSingleton().createVertexBuffer(
                        float.sizeof, mVertexData.vertexCount * 2,
                        HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, false);
                    // Fill the first half with 1.0, second half with 0.0
                    float *pW = cast(float*)(buf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
                    size_t v;
                    for (v = 0; v < mVertexData.vertexCount; ++v)
                    {
                        *pW++ = 1.0f;
                    }
                    for (v = 0; v < mVertexData.vertexCount; ++v)
                    {
                        *pW++ = 0.0f;
                    }
                    buf.get().unlock();
                    mVertexData.hardwareShadowVolWBuffer = buf;
                }
            }
            
        }
        /// Dump contents for diagnostics
        //void dump(std::ofstream& of);
        void dump(ref Log.Stream of)
        {
            of << "Geometry Bucket" << of.endl;
            of << "---------------" << of.endl;
            of << "Format string: " << mFormatString << of.endl;
            of << "Geometry items: " << mQueuedGeometry.length << of.endl;
            of << "Vertex count: " << mVertexData.vertexCount << of.endl;
            of << "Index count: " << mIndexData.indexCount << of.endl;
            of << "---------------" << of.Flush();
            
        }
    }
    /** A MaterialBucket is a collection of smaller buckets with the same 
     Material (and implicitly the same LOD). */
    static class MaterialBucket //: public BatchedGeometryAlloc
    {
    public:
        /// list of Geometry Buckets in this region
        //typedef vector<GeometryBucket*>::type GeometryBucketList;
        alias GeometryBucket[] GeometryBucketList;
    protected:
        /// Pointer to parent LODBucket
        LODBucket mParent;
        /// Material being used
        string mMaterialName;
        /// Pointer to material being used
        SharedPtr!Material mMaterial;
        /// Active technique
        Technique mTechnique;
        
        /// list of Geometry Buckets in this region
        GeometryBucketList mGeometryBucketList;
        // index to current Geometry Buckets for a given geometry format
        //typedef map<String, GeometryBucket*>::type CurrentGeometryMap;
        alias GeometryBucket[string] CurrentGeometryMap;
        CurrentGeometryMap mCurrentGeometryMap;
        /// Get a packed string identifying the geometry format
        string getGeometryFormatString(ref SubMeshLodGeometryLink geom)
        {
            // Formulate an identifying string for the geometry format
            // Must take into account the vertex declaration and the index type
            // Format is (all lines separated by '|'):
            // Index type
            // Vertex element (repeating)
            //   source
            //   semantic
            //   type
            string str = std.conv.text(geom.indexData.indexBuffer.get().getType(), "|");

            auto elemList = geom.vertexData.vertexDeclaration.getElements();

            //XXX String concatenation
            foreach (elem; elemList)
            {
                str ~= std.conv.text(elem.getSource(), "|", elem.getSource(), "|", 
                                     elem.getSemantic(), "|", elem.getType(), "|");
            }
            
            return str;
            
        }
        
    public:
        this(ref LODBucket parent,string materialName)
        {
            mParent = parent;
            mMaterialName = materialName;
            //mTechnique = null;
        }
        ~this()
        {
            // delete
            foreach (i; mGeometryBucketList)
            {
                destroy(i);
            }
            mGeometryBucketList.clear();
            
            // no need to delete queued meshes, these are managed in StaticGeometry
        }

        ref LODBucket getParent() { return mParent; }
        /// Get the material name
        string getMaterialName(){ return mMaterialName; }
        /// Assign geometry to this bucket
        void assign(ref QueuedGeometry qgeom)
        {
            // Look up any current geometry
            string formatString = getGeometryFormatString(qgeom.geometry);
            auto gi = formatString in mCurrentGeometryMap;
            bool newBucket = true;
            if (gi !is null)
            {
                // Found existing geometry, try to assign
                newBucket = !gi.assign(qgeom);
                // Note that this bucket will be replaced as the 'current'
                // for this format string below since it's out of space
            }
            // Do we need to create a new one?
            if (newBucket)
            {
                GeometryBucket gbucket = new GeometryBucket(this, formatString,
                                                            qgeom.geometry.vertexData, qgeom.geometry.indexData);
                // Add to main list
                mGeometryBucketList.insert(gbucket);
                // Also index in 'current' list
                mCurrentGeometryMap[formatString] = gbucket;
                if (!gbucket.assign(qgeom))
                {
                    throw new InternalError(
                        "Somehow we couldn't fit the requested geometry even in a "
                        "brand new GeometryBucket!! Must be a bug, please report.",
                        "StaticGeometry.MaterialBucket.assign");
                }
            }
        }
        /// Build
        void build(bool stencilShadows)
        {
            mTechnique = null;
            mMaterial = MaterialManager.getSingleton().getByName(mMaterialName);
            if (mMaterial.isNull())
            {
                throw new ItemNotFoundError(
                    "Material '" ~ mMaterialName ~ "' not found.",
                    "StaticGeometry.MaterialBucket.build");
            }
            mMaterial.getAs().load();
            // tell the geometry buckets to build
            foreach (i; mGeometryBucketList)
            {
                i.build(stencilShadows);
            }
        }

        /// Add children to the render queue
        void addRenderables(ref RenderQueue queue, ubyte group, 
                            Real lodValue)
        {
            // Get region
            Region region = mParent.getParent();
            
            // Get material lod strategy
            LodStrategy materialLodStrategy = mMaterial.getAs().getLodStrategy();
            
            // If material strategy doesn't match, recompute lod value with correct strategy
            if (materialLodStrategy != region.mLodStrategy)
                lodValue = materialLodStrategy.getValue(region, region.mCamera);
            
            // Determine the current material technique
            mTechnique = mMaterial.getAs().getBestTechnique(
                mMaterial.getAs().getLodIndex(lodValue));

            foreach (i; mGeometryBucketList)
            {
                queue.addRenderable(i, group);
            }
            
        }
        /// Get the material for this bucket
        ref SharedPtr!Material getMaterial(){ return mMaterial; }
        /// Iterator over geometry
        //typedef VectorIterator<GeometryBucketList> GeometryIterator;
        /// Get an iterator over the contained geometry
        //GeometryIterator getGeometryIterator()
        //{
        //    return GeometryIterator(
        //        mGeometryBucketList.begin(), mGeometryBucketList.end());
        //}

        GeometryBucketList getGeometryBucketList()
        {
            return mGeometryBucketList;
        }

        /// Get the current Technique
        ref Technique getCurrentTechnique(){ return mTechnique; }
        /// Dump contents for diagnostics
        void dump(ref Log.Stream of)
        {
            of << "Material Bucket " << mMaterialName << of.endl;
            of << "--------------------------------------------------" << of.endl;
            of << "Geometry buckets: " << mGeometryBucketList.length << of.endl;
            foreach (i; mGeometryBucketList)
            {
                i.dump(of);
            }
            of << "--------------------------------------------------" << of.Flush();
            
        }

        void visitRenderables(Renderable.Visitor visitor, bool debugRenderables)
        {
            foreach (i; mGeometryBucketList)
            {
                visitor.visit(i, mParent.getLod(), false);
            }
            
        }
    }
    /** A LODBucket is a collection of smaller buckets with the same LOD. 
     @remarks
     LOD ref ers to Mesh LOD here. Material LOD can change separately
     at the next bucket down from this.
     */
    static class LODBucket //: public BatchedGeometryAlloc
    {
    public:
        /// Lookup of Material Buckets in this region
        //typedef map<String, MaterialBucket*>::type MaterialBucketMap;
        alias MaterialBucket[string] MaterialBucketMap;
    protected:
        /** Nested class to allow shadows. */
        class LODShadowRenderable : ShadowRenderable
        {
        protected:
            LODBucket mParent;
            // Shared link to position buffer
            SharedPtr!HardwareVertexBuffer mPositionBuffer;
            // Shared link to w-coord buffer (optional)
            SharedPtr!HardwareVertexBuffer mWBuffer;
            
        public:
            this(ref LODBucket parent, 
                 SharedPtr!HardwareIndexBuffer indexBuffer, ref VertexData vertexData, 
                 bool createSeparateLightCap, bool isLightCap = false)
            {
                mParent = parent;
                // Initialise render op
                mRenderOp.indexData = new IndexData();
                mRenderOp.indexData.indexBuffer = indexBuffer;
                mRenderOp.indexData.indexStart = 0;
                // index start and count are sorted out later
                
                // Create vertex data which just references position component (and 2 component)
                mRenderOp.vertexData = new VertexData();
                // Map in position data
                mRenderOp.vertexData.vertexDeclaration.addElement(0,0,VertexElementType.VET_FLOAT3,VertexElementSemantic.VES_POSITION);
                ushort origPosBind =
                    vertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION).getSource();
                mPositionBuffer = vertexData.vertexBufferBinding.getBuffer(origPosBind);
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
                        // Create child light cap
                        mLightCap = new LODShadowRenderable(parent,
                                                            indexBuffer, vertexData, false, true);
                    }
                }
            }
            ~this()
            {
                destroy(mRenderOp.indexData);
                destroy(mRenderOp.vertexData);
            }
            /// Overridden from ShadowRenderable
            override void getWorldTransforms(ref Matrix4[] xform)
            {
                // pretransformed
                xform.insertOrReplace(mParent.getParent()._getParentNodeFullTransform());
            }
            SharedPtr!HardwareVertexBuffer getPositionBuffer() { return mPositionBuffer; }
            SharedPtr!HardwareVertexBuffer getWBuffer() { return mWBuffer; }
            /// Overridden from ShadowRenderable
            override void rebindIndexBuffer(SharedPtr!HardwareIndexBuffer* indexBuffer)
            {
                mRenderOp.indexData.indexBuffer = *indexBuffer;
                if (mLightCap) mLightCap.rebindIndexBuffer(indexBuffer);
            }
            
        }
        /// Pointer to parent region
        Region mParent;
        /// LOD level (0 == full LOD)
        ushort mLod;
        /// lod value at which this LOD starts to apply (squared)
        Real mLodValue;
        /// Lookup of Material Buckets in this region
        MaterialBucketMap mMaterialBucketMap;
        /// Geometry queued for a single LOD (deallocated here)
        QueuedGeometryList mQueuedGeometryList;
        /// Edge list, used if stencil shadow casting is enabled 
        EdgeData mEdgeList;
        /// Is a vertex program in use somewhere in this group?
        bool mVertexProgramInUse;
        /// List of shadow renderables
        ShadowCaster.ShadowRenderableList mShadowRenderables;
    public:
        this(ref Region parent, ushort lod, Real lodValue)
        {
            mParent = parent;
            mLod = lod;
            mLodValue = lodValue;
            //mEdgeList = 0;
            mVertexProgramInUse = false;
        }

        ~this()
        {
            destroy(mEdgeList);
            foreach (s; mShadowRenderables)
            {
                destroy(s);
            }
            mShadowRenderables.clear();
            // delete
            foreach (k,v; mMaterialBucketMap)
            {
                destroy(v);
            }
            mMaterialBucketMap.clear();
            foreach(qi; mQueuedGeometryList)
            {
                destroy(qi);
            }
            mQueuedGeometryList.clear();
            
            // no need to delete queued meshes, these are managed in StaticGeometry
        }

        ref Region getParent() { return mParent; }

        /// Get the lod index
        ushort getLod(){ return mLod; }

        /// Get the lod value
        Real getLodValue(){ return mLodValue; }

        /// Assign a queued submesh to this bucket, using specified mesh LOD
        void assign(ref QueuedSubMesh qmesh, ushort atLod)
        {
            //TODO struct ref
            QueuedGeometry _q;// = new QueuedGeometry();
            mQueuedGeometryList.insert(_q);
            QueuedGeometry* q = &mQueuedGeometryList[$-1];
            q.position = qmesh.position;
            q.orientation = qmesh.orientation;
            q.scale = qmesh.scale;
            if (qmesh.geometryLodList.length > atLod)
            {
                // This submesh has enough lods, use the right one
                q.geometry = (*qmesh.geometryLodList)[atLod];
            }
            else
            {
                // Not enough lods, use the lowest one we have
                q.geometry =
                    (*qmesh.geometryLodList)[qmesh.geometryLodList.length - 1];
            }
            // Locate a material bucket
            MaterialBucket mbucket = null;
            auto m = qmesh.materialName in mMaterialBucketMap;
            if (m !is null)
            {
                mbucket = *m;
            }
            else
            {
                mbucket = new MaterialBucket(this, qmesh.materialName);
                mMaterialBucketMap[qmesh.materialName] = mbucket;
            }
            mbucket.assign(*q);
        }
        /// Build
        void build(bool stencilShadows)
        {
            
            EdgeListBuilder eb;
            size_t vertexSet = 0;
            
            // Just pass this on to child buckets
            foreach (k,mat; mMaterialBucketMap)
            {
                mat.build(stencilShadows);
                
                if (stencilShadows)
                {
                    auto geomIt = mat.getGeometryBucketList();
                    // Check if we have vertex programs here
                    Technique t = mat.getMaterial().getAs().getBestTechnique();
                    if (t)
                    {
                        Pass p = t.getPass(0);
                        if (p)
                        {
                            if (p.hasVertexProgram())
                            {
                                mVertexProgramInUse = true;
                            }
                        }
                    }
                    
                    //while (geomIt.hasMoreElements())
                    foreach(geom; geomIt)
                    {
                        // Check we're dealing with 16-bit indexes here
                        // Since stencil shadows can only deal with 16-bit
                        // More than that and stencil is probably too CPU-heavy
                        // in any case
                        assert(geom.getIndexData().indexBuffer.get().getType()
                               == HardwareIndexBuffer.IndexType.IT_16BIT,
                               "Only 16-bit indexes allowed when using stencil shadows");
                        eb.addVertexData(geom.getVertexData());
                        eb.addIndexData(geom.getIndexData(), vertexSet++);
                    }
                    
                }
            }
            
            if (stencilShadows)
            {
                mEdgeList = eb.build();
            }
        }

        /// Add children to the render queue
        void addRenderables(ref RenderQueue queue, ubyte group, 
                            Real lodValue)
        {
            // Just pass this on to child buckets
            foreach (k,v; mMaterialBucketMap)
            {
                v.addRenderables(queue, group, lodValue);
            }
        }
        /// Iterator over the materials in this LOD
        //typedef MapIterator<MaterialBucketMap> MaterialIterator;
        /// Get an iterator over the materials in this LOD
        //MaterialIterator getMaterialIterator();
        MaterialBucketMap getMaterialBucketMap()
        {
            return mMaterialBucketMap;
        }

        /// Dump contents for diagnostics
        void dump(ref Log.Stream of)
        {
            of << "LOD Bucket " << mLod << of.endl;
            of << "------------------" << of.endl;
            of << "Lod Value: " << mLodValue << of.endl;
            of << "Number of Materials: " << mMaterialBucketMap.length << of.endl;
            foreach (k,v; mMaterialBucketMap)
            {
                v.dump(of);
            }
            of << "------------------" << of.endl;

        }
        void visitRenderables(Renderable.Visitor visitor, bool debugRenderables)
        {
            foreach (k,v; mMaterialBucketMap)
            {
                v.visitRenderables(visitor, debugRenderables);
            }
            
        }
        EdgeData getEdgeList(){ return mEdgeList; }
        ref ShadowCaster.ShadowRenderableList getShadowRenderableList() { return mShadowRenderables; }
        bool isVertexProgramInUse(){ return mVertexProgramInUse; }

        void updateShadowRenderables(
            ShadowTechnique shadowTechnique, ref Vector4 lightPos, 
            SharedPtr!HardwareIndexBuffer* indexBuffer, 
            bool extrude, Real extrusionDistance, ulong flags = 0 )
        {
            assert(indexBuffer !is null, "Only external index buffers are supported right now");
            assert(indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_16BIT,
                   "Only 16-bit indexes supported for now");
            
            // We need to search the edge list for silhouette edges
            if (!mEdgeList)
            {
                throw new InvalidParamsError(
                    "You enabled stencil shadows after the buid process!",
                    "StaticGeometry.LODBucket.getShadowVolumeRenderableIterator");
            }
            
            // Init shadow renderable list if required
            bool init = mShadowRenderables.empty();

            LODShadowRenderable esr;
            //TODO mShadowRenderables init, use it like this?
            if (init)
                //mShadowRenderables.resize(mEdgeList.edgeGroups.length);
                mShadowRenderables.length = mEdgeList.edgeGroups.length;
            
            //bool updatedSharedGeomNormals = false;

            foreach(si; 0 .. mShadowRenderables.length)
            {
                auto s = mShadowRenderables[si];
                auto egi = mEdgeList.edgeGroups[si];
                if (init)
                {
                    // Create a new renderable, create a separate light cap if
                    // we're using a vertex program (either for this model, or
                    // for extruding the shadow volume) since otherwise we can
                    // get depth-fighting on the light cap
                    
                    mShadowRenderables[si] = new LODShadowRenderable(this, *indexBuffer,
                                                                         egi.vertexData, mVertexProgramInUse || !extrude);
                    s = mShadowRenderables[si];
                }
                // Get shadow renderable
                esr = cast(LODShadowRenderable)(s);
                SharedPtr!HardwareVertexBuffer esrPositionBuffer = esr.getPositionBuffer();
                // Extrude vertices in software if required
                if (extrude)
                {
                    mParent.extrudeVertices(esrPositionBuffer,
                                            egi.vertexData.vertexCount,
                                            lightPos, extrusionDistance);
                    
                }
                //egi++;
            }
            
        }
        
    }
    /** The details of a topological region which is the highest level of
     partitioning for this class.
     @remarks
     The size & shape of regions entirely depends on the SceneManager
     specific implementation. It is a MovableObject since it will be
     attached to a node based on the local centre - in practice it
     won't actually move (although in theory it could).
     */
    class Region : MovableObject
    {
        //friend class MaterialBucket;
        //friend class GeometryBucket;
    public:
        /// list of LOD Buckets in this region
        //typedef vector<LODBucket*>::type LODBucketList;
        alias LODBucket[] LODBucketList;
    protected:
        /// Parent static geometry
        StaticGeometry mParent;
        /// Scene manager link
        SceneManager mSceneMgr;
        /// Scene node
        SceneNode mNode;
        /// Local list of queued meshes (not used for deallocation)
        QueuedSubMeshList mQueuedSubMeshes;
        /// Unique identifier for the region
        uint mRegionID;
        /// Center of the region
        Vector3 mCentre;
        /// Lod values as built up - use the max at each level
        Mesh.LodValueList mLodValues;
        /// Local AABB relative to region centre
        AxisAlignedBox mAABB;
        /// Local bounding radius
        Real mBoundingRadius;
        /// The current lod level, as determined from the last camera
        ushort mCurrentLod;
        /// Current lod value, passed on to do material lod later
        Real mLodValue;
        /// List of LOD buckets         
        LODBucketList mLodBucketList;
        /// List of lights for this region
        //mutable 
        LightList mLightList;
        /// The last frame that this light list was updated in
        //mutable 
        ulong mLightListUpdated;
        /// Lod strategy reference
        //
        LodStrategy mLodStrategy;
        /// Current camera
        Camera mCamera;
        /// Cached squared view depth value to avoid recalculation by GeometryBucket
        Real mSquaredViewDepth;
        
    public:
        this(ref StaticGeometry parent,string name, ref SceneManager mgr, 
             uint regionID, ref Vector3 centre)
        {
            super(name);
            mParent = parent;
            mSceneMgr = mgr;
            //mNode = 0;
            mRegionID = regionID;
            mCentre = centre;
            mBoundingRadius = 0.0f;
            mCurrentLod = 0;
            //mLodStrategy = 0;
        }

        ~this()
        {
            if (mNode)
            {
                mNode.getParentSceneNode().removeChild(mNode);
                mSceneMgr.destroySceneNode(mNode.getName());
                //mNode = 0;
            }
            // delete
            foreach (i; mLodBucketList)
            {
                destroy(i);
            }
            mLodBucketList.clear();
            
            // no need to delete queued meshes, these are managed in StaticGeometry
            
        }
        // more fields can be added in subclasses
        ref StaticGeometry getParent(){ return mParent;}
        /// Assign a queued mesh to this region, read for final build
        void assign(ref QueuedSubMesh qmesh)
        {
            mQueuedSubMeshes.insert(qmesh);
            
            // Set/check lod strategy
            LodStrategy lodStrategy = qmesh.submesh.parent.getLodStrategy();
            if (mLodStrategy is null)
            {
                mLodStrategy = lodStrategy;
                
                // First LOD mandatory, and always from base lod value
                mLodValues.insert(mLodStrategy.getBaseValue());
            }
            else
            {
                if (mLodStrategy != lodStrategy)
                    throw new InvalidParamsError("Lod strategies do not match",
                                                 "StaticGeometry.Region.assign");
            }
            
            // update lod values
            ushort lodLevels = qmesh.submesh.parent.getNumLodLevels();
            assert(qmesh.geometryLodList.length == lodLevels);
            
            while(mLodValues.length < lodLevels)
            {
                mLodValues.insert(0.0f);
            }
            // Make sure LOD levels are max of all at the requested level
            for (ushort lod = 1; lod < lodLevels; ++lod)
            {
                MeshLodUsage meshLod =
                    qmesh.submesh.parent.getLodLevel(lod);
                mLodValues[lod] = std.algorithm.max(mLodValues[lod],
                                                    meshLod.value);
            }
            
            // update bounds
            // Transform world bounds relative to our centre
            auto localBounds = AxisAlignedBox(
                qmesh.worldBounds.getMinimum() - mCentre,
                qmesh.worldBounds.getMaximum() - mCentre);
            mAABB.merge(localBounds);
            mBoundingRadius = Math.boundingRadiusFromAABB(mAABB);
            
        }
        /// Build this region
        void build(bool stencilShadows)
        {
            // Create a node
            mNode = mSceneMgr.getRootSceneNode().createChildSceneNode(mName, mCentre);
            mNode.attachObject(this);
            // We need to create enough LOD buckets to deal with the highest LOD
            // we encountered in all the meshes queued
            for (ushort lod = 0; lod < mLodValues.length; ++lod)
            {
                auto lodBucket = new LODBucket(this, lod, mLodValues[lod]);
                mLodBucketList.insert(lodBucket);
                // Now iterate over the meshes and assign to LODs
                // LOD bucket will pick the right LOD to use
                foreach (qi; mQueuedSubMeshes)
                {
                    lodBucket.assign(qi, lod);
                }
                // now build
                lodBucket.build(stencilShadows);
            }
        }
        /// Get the region ID of this region
        uint getID(){ return mRegionID; }
        /// Get the centre point of the region
        Vector3 getCentre(){ return mCentre; }
        override string getMovableType()
        {
            static string sType = "StaticGeometry";
            return sType;
        }

        override void _notifyCurrentCamera(Camera cam)
        {
            // Set camera
            mCamera = cam;
            
            // Cache squared view depth for use by GeometryBucket
            mSquaredViewDepth = mParentNode.getSquaredViewDepth(cam.getLodCamera());
            
            // No lod strategy set yet, skip (this indicates that there are no submeshes)
            if (mLodStrategy is null)
                return;
            
            // Sanity check
            assert(!mLodValues.empty());
            
            // Calculate lod value
            Real lodValue = mLodStrategy.getValue(this, cam);
            
            // Store lod value for this strategy
            mLodValue = lodValue;
            
            // Get lod index
            mCurrentLod = mLodStrategy.getIndex(lodValue, mLodValues);
        }

        override AxisAlignedBox getBoundingBox()
        {
            return mAABB;
        }

        override Real getBoundingRadius()
        {
            return mBoundingRadius;
        }

        override void _updateRenderQueue(RenderQueue queue)
        {
            mLodBucketList[mCurrentLod].addRenderables(queue, mRenderQueueID,
                                                       mLodValue);
        }
        /// @copydoc MovableObject::visitRenderables
        override void visitRenderables(Renderable.Visitor visitor, 
                                       bool debugRenderables = false)
        {
            foreach (i; mLodBucketList)
            {
                i.visitRenderables(visitor, debugRenderables);
            }
            
        }

        override bool isVisible()
        {
            if(!mVisible || mBeyondFarDistance)
                return false;
            
            auto sm = Root.getSingleton()._getCurrentSceneManager();
            if (sm && !(mVisibilityFlags & sm._getCombinedVisibilityMask()))
                return false;
            
            return true;
        }

        override uint getTypeFlags()
        {
            return SceneManager.STATICGEOMETRY_TYPE_MASK;
        }
        
        //typedef VectorIterator<LODBucketList> LODIterator;
        /// Get an iterator over the LODs in this region
        //LODIterator getLODIterator()
        //{
        //    return LODIterator(mLodBucketList.begin(), mLodBucketList.end());
        //}

        LODBucketList getLODBucketList()
        {
            return mLodBucketList;
        }

        /// @copydoc ShadowCaster::getShadowVolumeRenderableIterator
        //ShadowRenderableListIterator getShadowVolumeRenderableIterator(
        override ShadowRenderableList getShadowVolumeRenderables(
            ShadowTechnique shadowTechnique, ref Light light, 
            SharedPtr!HardwareIndexBuffer* indexBuffer, 
            bool extrude, Real extrusionDistance, ulong flags = 0 )
        {
            // Calculate the object space light details
            Vector4 lightPos = light.getAs4DVector();
            Matrix4 world2Obj = mParentNode._getFullTransform().inverseAffine();
            lightPos = world2Obj.transformAffine(lightPos);
            Matrix3 world2Obj3x3;
            world2Obj.extract3x3Matrix(world2Obj3x3);
            extrusionDistance *= Math.Sqrt(std.algorithm.min(std.algorithm.min(world2Obj3x3.GetColumn(0).squaredLength(), world2Obj3x3.GetColumn(1).squaredLength()), world2Obj3x3.GetColumn(2).squaredLength()));
            
            // per-LOD shadow lists & edge data
            mLodBucketList[mCurrentLod].updateShadowRenderables(
                shadowTechnique, lightPos, indexBuffer, extrude, extrusionDistance, flags);
            
            EdgeData edgeList = mLodBucketList[mCurrentLod].getEdgeList();
            ShadowRenderableList shadowRendList = mLodBucketList[mCurrentLod].getShadowRenderableList();
            
            // Calc triangle light facing
            updateEdgeListLightFacing(edgeList, lightPos);
            
            // Generate indexes and update renderables
            generateShadowVolume(edgeList, indexBuffer, light,
                                 shadowRendList, flags);

            return shadowRendList;
        }

        /// Overridden from MovableObject
        override EdgeData getEdgeList()
        {
            return mLodBucketList[mCurrentLod].getEdgeList();
        }

        /** Overridden member from ShadowCaster. */
        override bool hasEdgeList()
        {
            return getEdgeList() !is null;
        }
        
        /// Dump contents for diagnostics
        void dump(ref Log.Stream of)
        {
            of << "Region " << mRegionID << of.endl;
            of << "--------------------------" << of.endl;
            of << "Centre: " << mCentre << of.endl;
            of << "Local AABB: " << mAABB << of.endl;
            of << "Bounding radius: " << mBoundingRadius << of.endl;
            of << "Number of LODs: " << mLodBucketList.length << of.endl;
            
            foreach (i; mLodBucketList)
            {
                i.dump(of);
            }
            of << "--------------------------" << of.Flush();
        }
        
    }
    /** Indexed region map based on packed x/y/z region index, 10 bits for
     each axis.
     @remarks
     Regions are indexed 0-1023 in all axes, where for example region 
     0 in the x axis begins at mOrigin.x + (mRegionDimensions.x * -512), 
     and region 1023 ends at mOrigin + (mRegionDimensions.x * 512).
     */
    //typedef map<uint32, Region*>::type RegionMap;
    alias Region[uint] RegionMap;
protected:
    // General state & settings
    SceneManager mOwner;
    string mName;
    bool mBuilt;
    Real mUpperDistance;
    Real mSquaredUpperDistance;
    bool mCastShadows;
    Vector3 mRegionDimensions;
    Vector3 mHalfRegionDimensions;
    Vector3 mOrigin;
    bool mVisible;
    /// The render queue to use when rendering this object
    ubyte mRenderQueueID;
    /// Flags whether the RenderQueue's default should be used.
    bool mRenderQueueIDSet;
    /// Stores the visibility flags for the regions
    uint mVisibilityFlags;
    
    QueuedSubMeshList mQueuedSubMeshes;
    
    /// List of geometry which has been optimised for SubMesh use
    /// This is the primary storage used for cleaning up later
    OptimisedSubMeshGeometryList mOptimisedSubMeshGeometryList;
    
    /** Cached links from SubMeshes to (potentially optimised) geometry
     This is not used for deletion since the lookup may reference
     original vertex data
     */
    SubMeshGeometryLookup mSubMeshGeometryLookup;
    
    /// Map of regions
    RegionMap mRegionMap;
    
    /** Virtual method for getting a region most suitable for the
     passed in bounds. Can be overridden by subclasses.
     */
    Region getRegion(AxisAlignedBox bounds, bool autoCreate)
    {
        if (bounds.isNull())
            return null;
        
        // Get the region which has the largest overlapping volume
        Vector3 min = bounds.getMinimum();
        Vector3 max = bounds.getMaximum();
        
        // Get the min and max region indexes
        ushort minx, miny, minz;
        ushort maxx, maxy, maxz;
        getRegionIndexes(min, minx, miny, minz);
        getRegionIndexes(max, maxx, maxy, maxz);
        Real maxVolume = 0.0f;
        ushort finalx = 0, finaly = 0, finalz = 0;
        for (ushort x = minx; x <= maxx; ++x)
        {
            for (ushort y = miny; y <= maxy; ++y)
            {
                for (ushort z = minz; z <= maxz; ++z)
                {
                    Real vol = getVolumeIntersection(bounds, x, y, z);
                    if (vol > maxVolume)
                    {
                        maxVolume = vol;
                        finalx = x;
                        finaly = y;
                        finalz = z;
                    }
                    
                }
            }
        }
        
        assert(maxVolume > 0.0f,
               "Static geometry: Problem determining closest volume match!");
        
        return getRegion(finalx, finaly, finalz, autoCreate);
        
    }
    /** Get the region within which a point lies */
    Region getRegion(Vector3 point, bool autoCreate)
    {
        ushort x, y, z;
        getRegionIndexes(point, x, y, z);
        return getRegion(x, y, z, autoCreate);
    }

    /** Get the region using indexes */
    Region getRegion(ushort x, ushort y, ushort z, bool autoCreate)
    {
        uint index = packIndex(x, y, z);
        Region ret = getRegion(index);
        if (!ret && autoCreate)
        {
            // Make a name
            string str = std.conv.text(mName, ":", index);
            // Calculate the region centre
            Vector3 centre = getRegionCentre(x, y, z);
            ret = new Region(this, str, mOwner, index, centre);
            mOwner.injectMovableObject(ret);
            ret.setVisible(mVisible);
            ret.setCastShadows(mCastShadows);
            if (mRenderQueueIDSet)
            {
                ret.setRenderQueueGroup(mRenderQueueID);
            }
            mRegionMap[index] = ret;
        }
        return ret;
    }

    /** Get the region using a packed index, returns null if it doesn't exist. */
    Region getRegion(uint index)
    {
        auto i = index in mRegionMap;
        if (i !is null)
        {
            return *i;
        }
        else
        {
            return null;
        }
    }
    /** Get the region indexes for a point.
     */
    void getRegionIndexes(Vector3 point, 
                          ref ushort x, ref ushort y, ref ushort z)
    {
        // Scale the point into multiples of region and adjust for origin
        Vector3 scaledPoint = (point - mOrigin) / mRegionDimensions;
        
        // Round down to 'bottom left' point which represents the cell index
        int ix = Math.IFloor(scaledPoint.x);
        int iy = Math.IFloor(scaledPoint.y);
        int iz = Math.IFloor(scaledPoint.z);
        
        // Check bounds
        if (ix < REGION_MIN_INDEX || ix > REGION_MAX_INDEX
            || iy < REGION_MIN_INDEX || iy > REGION_MAX_INDEX
            || iz < REGION_MIN_INDEX || iz > REGION_MAX_INDEX)
        {
            throw new InvalidParamsError(
                "Point out of bounds",
                "StaticGeometry.getRegionIndexes");
        }
        // Adjust for the fact that we use unsigned values for simplicity
        // (requires less faffing about for negatives give 10-bit packing
        x = cast(ushort)(ix + REGION_HALF_RANGE);
        y = cast(ushort)(iy + REGION_HALF_RANGE);
        z = cast(ushort)(iz + REGION_HALF_RANGE);
        
        
    }
    /** Pack 3 indexes into a single index value
     */
    uint packIndex(ushort x, ushort y, ushort z)
    {
        return x + (y << 10) + (z << 20);
    }
    /** Get the volume intersection for an indexed region with some bounds.
     */
    Real getVolumeIntersection(AxisAlignedBox box,  
                               ushort x, ushort y, ushort z)
    {
        // Get bounds of indexed region
        AxisAlignedBox regionBounds = getRegionBounds(x, y, z);
        AxisAlignedBox intersectBox = regionBounds.intersection(box);
        // return a 'volume' which ignores zero dimensions
        // since we only use this for relative comparisons of the same bounds
        // this will still be internally consistent
        Vector3 boxdiff = box.getMaximum() - box.getMinimum();
        Vector3 intersectDiff = intersectBox.getMaximum() - intersectBox.getMinimum();
        
        return (boxdiff.x == 0 ? 1 : intersectDiff.x) *
            (boxdiff.y == 0 ? 1 : intersectDiff.y) *
                (boxdiff.z == 0 ? 1 : intersectDiff.z);
        
    }
    /** Get the bounds of an indexed region.
     */
    AxisAlignedBox getRegionBounds(ushort x, ushort y, ushort z)
    {
        auto min = Vector3(
            (cast(Real)x - REGION_HALF_RANGE) * mRegionDimensions.x + mOrigin.x,
            (cast(Real)y - REGION_HALF_RANGE) * mRegionDimensions.y + mOrigin.y,
            (cast(Real)z - REGION_HALF_RANGE) * mRegionDimensions.z + mOrigin.z
            );
        Vector3 max = min + mRegionDimensions;
        return AxisAlignedBox(min, max);
    }
    /** Get the centre of an indexed region.
     */
    Vector3 getRegionCentre(ushort x, ushort y, ushort z)
    {
        return Vector3(
            (cast(Real)x - REGION_HALF_RANGE) * mRegionDimensions.x + mOrigin.x
            + mHalfRegionDimensions.x,
            (cast(Real)y - REGION_HALF_RANGE) * mRegionDimensions.y + mOrigin.y
            + mHalfRegionDimensions.y,
            (cast(Real)z - REGION_HALF_RANGE) * mRegionDimensions.z + mOrigin.z
            + mHalfRegionDimensions.z
            );
    }
    /** Calculate world bounds from a set of vertex data. */
    AxisAlignedBox calculateBounds(ref VertexData vertexData, 
                                   ref Vector3 position, ref Quaternion orientation, 
                                   ref Vector3 scale)
    {
        VertexElement posElem =
            vertexData.vertexDeclaration.findElementBySemantic(
                VertexElementSemantic.VES_POSITION);
        SharedPtr!HardwareVertexBuffer vbuf =
            vertexData.vertexBufferBinding.getBuffer(posElem.getSource());
        ubyte* vertex = cast(ubyte*)(vbuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
        float* pFloat;
        
        Vector3 min = Vector3.ZERO, max = Vector3.UNIT_SCALE;
        bool first = true;
        
        for(size_t j = 0; j < vertexData.vertexCount; ++j, vertex += vbuf.get().getVertexSize())
        {
            posElem.baseVertexPointerToElement(vertex, &pFloat);
            
            Vector3 pt;
            
            pt.x = (*pFloat++);
            pt.y = (*pFloat++);
            pt.z = (*pFloat++);
            // Transform to world (scale, rotate, translate)
            pt = (orientation * (pt * scale)) + position;
            if (first)
            {
                min = max = pt;
                first = false;
            }
            else
            {
                min.makeFloor(pt);
                max.makeCeil(pt);
            }
            
        }
        vbuf.get().unlock();
        return AxisAlignedBox(min, max);
    }
    /** Look up or calculate the geometry data to use for this SubMesh */
    SubMeshLodGeometryLinkList* determineGeometry(ref SubMesh sm)
    {
        // First, determine if we've already seen this submesh before
        auto i = sm in mSubMeshGeometryLookup;
        if (i !is null)
        {
            return i;
        }
        // Otherwise, we have to create a new one
        mSubMeshGeometryLookup[sm] = null;
        SubMeshLodGeometryLinkList *lodList = &mSubMeshGeometryLookup[sm];// = new SubMeshLodGeometryLinkList;

        ushort numLods = sm.parent.isLodManual() ? 1 : sm.parent.getNumLodLevels();
        lodList.length = numLods;//TODO vector resize

        for (ushort lod = 0; lod < numLods; ++lod)
        {
            //SubMeshLodGeometryLink& geomLink = (*lodList)[lod];
            SubMeshLodGeometryLink *geomLink = &(*lodList)[lod]; //new SubMeshLodGeometryLink;
            IndexData lodIndexData;
            if (lod == 0)
            {
                lodIndexData = sm.indexData;
            }
            else
            {
                lodIndexData = sm.mLodFaceList[lod - 1];
            }
            // Can use the original mesh geometry?
            if (sm.useSharedVertices)
            {
                if (sm.parent.getNumSubMeshes() == 1)
                {
                    // Ok, this is actually our own anyway
                    geomLink.vertexData = sm.parent.sharedVertexData;
                    geomLink.indexData = lodIndexData;
                }
                else
                {
                    // We have to split it
                    splitGeometry(sm.parent.sharedVertexData,
                                  lodIndexData, geomLink);
                }
            }
            else
            {
                if (lod == 0)
                {
                    // Ok, we can use the existing geometry; should be in full
                    // use by just this SubMesh
                    geomLink.vertexData = sm.vertexData;
                    geomLink.indexData = sm.indexData;
                }
                else
                {
                    // We have to split it
                    splitGeometry(sm.vertexData, lodIndexData, geomLink);
                }
            }
            assert (geomLink.vertexData.vertexStart == 0,
                    "Cannot use vertexStart > 0 on indexed geometry due to "
                    "rendersystem incompatibilities - see the docs!");

            //lodList.insert(geomLink);
        }
        
        
        return lodList;
    }
    /** Split some shared geometry into dedicated geometry. */
    void splitGeometry(ref VertexData vd, ref IndexData id, 
                       SubMeshLodGeometryLink* targetGeomLink)
    {
        // Firstly we need to scan to see how many vertices are being used
        // and while we're at it, build the remap we can use later
        bool use32bitIndexes =
            id.indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_32BIT;
        ushort *p16;
        uint *p32;
        IndexRemap indexRemap;
        if (use32bitIndexes)
        {
            p32 = cast(uint*)(id.indexBuffer.get().lock(
                id.indexStart, 
                id.indexCount * id.indexBuffer.get().getIndexSize(), 
                HardwareBuffer.LockOptions.HBL_READ_ONLY));
            buildIndexRemap(p32, id.indexCount, indexRemap);
            id.indexBuffer.get().unlock();
        }
        else
        {
            p16 = cast(ushort*)(id.indexBuffer.get().lock(
                id.indexStart, 
                id.indexCount * id.indexBuffer.get().getIndexSize(), 
                HardwareBuffer.LockOptions.HBL_READ_ONLY));
            buildIndexRemap(p16, id.indexCount, indexRemap);
            id.indexBuffer.get().unlock();
        }
        if (indexRemap.lengthAA == vd.vertexCount)
        {
            // ha, complete usage after all
            targetGeomLink.vertexData = vd;
            targetGeomLink.indexData = id;
            return;
        }
        
        
        // Create the new vertex data records
        targetGeomLink.vertexData = vd.clone(false);
        // Convenience
        VertexData newvd = targetGeomLink.vertexData;
        //IndexData* newid = targetGeomLink.indexData;
        // Update the vertex count
        newvd.vertexCount = indexRemap.lengthAA;
        
        ushort numvbufs = cast(ushort)vd.vertexBufferBinding.getBufferCount();
        // Copy buffers from old to new
        foreach (ushort b; 0..numvbufs)
        {
            // Lock old buffer
            SharedPtr!HardwareVertexBuffer oldBuf =
                vd.vertexBufferBinding.getBuffer(b);
            // Create new buffer
            SharedPtr!HardwareVertexBuffer newBuf =
                HardwareBufferManager.getSingleton().createVertexBuffer(
                    oldBuf.get().getVertexSize(),
                    indexRemap.lengthAA,
                    HardwareBuffer.Usage.HBU_STATIC);
            // rebind
            newvd.vertexBufferBinding.setBinding(b, newBuf);
            
            // Copy all the elements of the buffer across, by iterating over
            // the IndexRemap which describes how to move the old vertices
            // to the new ones. By nature of the map the remap is in order of
            // indexes in the old buffer, but note that we're not guaranteed to
            // address every vertex (which is kinda why we're here)
            ubyte* pSrcBase = cast(ubyte*)(
                oldBuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
            ubyte* pDstBase = cast(ubyte*)(
                newBuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
            size_t vertexSize = oldBuf.get().getVertexSize();
            // Buffers should be the same size
            assert (vertexSize == newBuf.get().getVertexSize());
            
            foreach (k,v; indexRemap)
            {
                assert (k < oldBuf.get().getNumVertices());
                assert (v < newBuf.get().getNumVertices());
                
                ubyte* pSrc = pSrcBase + k * vertexSize;
                ubyte* pDst = pDstBase + v * vertexSize;
                memcpy(pDst, pSrc, vertexSize);
            }
            // unlock
            oldBuf.get().unlock();
            newBuf.get().unlock();
            
        }
        
        // Now create a new index buffer
        SharedPtr!HardwareIndexBuffer ibuf =
            HardwareBufferManager.getSingleton().createIndexBuffer(
                id.indexBuffer.get().getType(), id.indexCount,
                HardwareBuffer.Usage.HBU_STATIC);
        
        if (use32bitIndexes)
        {
            uint *pSrc32, pDst32;
            pSrc32 = cast(uint*)(id.indexBuffer.get().lock(
                id.indexStart, 
                id.indexCount * id.indexBuffer.get().getIndexSize(), 
                HardwareBuffer.LockOptions.HBL_READ_ONLY));
            pDst32 = cast(uint*)(ibuf.get().lock(
                HardwareBuffer.LockOptions.HBL_DISCARD));
            remapIndexes(pSrc32, pDst32, indexRemap, id.indexCount);
            id.indexBuffer.get().unlock();
            ibuf.get().unlock();
        }
        else
        {
            ushort *pSrc16, pDst16;
            pSrc16 = cast(ushort*)(id.indexBuffer.get().lock(
                id.indexStart, 
                id.indexCount * id.indexBuffer.get().getIndexSize(), 
                HardwareBuffer.LockOptions.HBL_READ_ONLY));
            pDst16 = cast(ushort*)(ibuf.get().lock(
                HardwareBuffer.LockOptions.HBL_DISCARD));
            remapIndexes(pSrc16, pDst16, indexRemap, id.indexCount);
            id.indexBuffer.get().unlock();
            ibuf.get().unlock();
        }
        
        targetGeomLink.indexData = new IndexData();
        targetGeomLink.indexData.indexStart = 0;
        targetGeomLink.indexData.indexCount = id.indexCount;
        targetGeomLink.indexData.indexBuffer = ibuf;
        
        // Store optimised geometry for deallocation later
        OptimisedSubMeshGeometry optGeom = new OptimisedSubMeshGeometry();
        optGeom.indexData = targetGeomLink.indexData;
        optGeom.vertexData = targetGeomLink.vertexData;
        mOptimisedSubMeshGeometryList.insert(optGeom);
    }
    
    //typedef map<size_t, size_t>::type IndexRemap;
    alias size_t[size_t] IndexRemap;
    /** Method for figuring out which vertices are used by an index buffer
     and calculating a remap lookup for a vertex buffer just containing
     those vertices. 
     */
    void buildIndexRemap(T)(ref T* pBuffer, size_t numIndexes, ref IndexRemap remap)
    {
        remap.clear();
        for (size_t i = 0; i < numIndexes; ++i)
        {
            // use insert since duplicates are silently discarded
            remap[*pBuffer++] = remap.lengthAA;
            // this will have mapped oldindex . new index IF oldindex
            // wasn't already there
        }
    }
    /** Method for altering indexes based on a remap. */
    void remapIndexes(T)(T* src, ref T* dst, ref IndexRemap remap, 
                         size_t numIndexes)
    {
        for (size_t i = 0; i < numIndexes; ++i)
        {
            // look up original and map to target
            auto ix = *src++ in remap;
            assert(ix !is null);
            *dst++ = cast(T)(*ix);
        }
    }
    
public:
    /// Constructor; do not use directly (@see SceneManager::createStaticGeometry)
    this(ref SceneManager owner,string name)
    {
        mOwner = owner;
        mName = name;
        mBuilt = false;
        mUpperDistance = 0.0f;
        mSquaredUpperDistance = 0.0f;
        mCastShadows = false;
        mRegionDimensions = Vector3(1000,1000,1000);
        mHalfRegionDimensions = Vector3(500,500,500);
        mOrigin = Vector3(0,0,0);
        mVisible = true;
        mRenderQueueID = RenderQueueGroupID.RENDER_QUEUE_MAIN;
        mRenderQueueIDSet = false;
        mVisibilityFlags = MovableObject.getDefaultVisibilityFlags();
    }
    /// Destructor
    ~this()
    {
        reset();
    }
    
    /// Get the name of this object
    string getName(){ return mName; }
    /** Adds an Entity to the static geometry.
     @remarks
     This method takes an existing Entity and adds its details to the 
     list of elements to include when building. Note that the Entity
     itself is not copied or referenced in this method; an Entity is 
     passed simply so that you can change the materials of attached 
     SubEntity objects if you want. You can add the same Entity 
     instance multiple times with different material settings 
     completely safely, and destroy the Entity before destroying 
     this StaticGeometry if you like. The Entity passed in is simply 
     used as a definition.
     @note Must be called before 'build'.
     @param ent The Entity to use as a definition (the Mesh and Materials 
     referenced will be recorded for the build call).
     @param position The world position at which to add this Entity
     @param orientation The world orientation at which to add this Entity
     @param scale The scale at which to add this entity
     */
    void addEntity(Entity ent, Vector3 position,
                   Quaternion orientation = Quaternion.IDENTITY, 
                   Vector3 scale = Vector3.UNIT_SCALE)
    {
        SharedPtr!Mesh msh = ent.getMesh();
        // Validate
        if (msh.getAs().isLodManual())
        {
            LogManager.getSingleton().logMessage(
                "WARNING (StaticGeometry): Manual LOD is not supported. "
                "Using only highest LOD level for mesh " ~ msh.getAs().getName());
        }
        
        AxisAlignedBox sharedWorldBounds;
        // queue this entities submeshes and choice of material
        // also build the lists of geometry to be used for the source of lods
        for (uint i = 0; i < ent.getNumSubEntities(); ++i)
        {
            SubEntity se = ent.getSubEntity(i);
            QueuedSubMesh q;// = new QueuedSubMesh();
            
            // Get the geometry for this SubMesh
            q.submesh = se.getSubMesh();
            q.geometryLodList = determineGeometry(q.submesh);
            q.materialName = se.getMaterialName();
            q.orientation = orientation;
            q.position = position;
            q.scale = scale;
            // Determine the bounds based on the highest LOD
            q.worldBounds = calculateBounds(
                (*q.geometryLodList)[0].vertexData,
                position, orientation, scale);
            
            mQueuedSubMeshes.insert(q);
        }
    }
    
    /** Adds all the Entity objects attached to a SceneNode and all it's
     children to the static geometry.
     @remarks
     This method performs just like addEntity, except it adds all the 
     entities attached to an entire sub-tree to the geometry. 
     The position / orientation / scale parameters are taken from the
     node structure instead of being specified manually. 
     @note
     The SceneNode you pass in will not be automatically detached from 
     it's parent, so if you have this node already attached to the scene
     graph, you will need to remove it if you wish to avoid the overhead
     of rendering <i>both</i> the original objects and their new static
     versions! We don't do this for you incase you are preparing this 
     in advance and so don't want the originals detached yet. 
     @note Must be called before 'build'.
     @param node Pointer to the node to use to provide a set of Entity 
     templates
     */
    void addSceneNode(SceneNode node)
    {
        foreach(k, mobj; node.getAttachedObjects())
        {
            if (mobj.getMovableType() == "Entity")
            {
                addEntity(cast(Entity)mobj,
                          node._getDerivedPosition(),
                          node._getDerivedOrientation(),
                          node._getDerivedScale());
            }
        }
        // Iterate through all the child-nodes
        foreach(k, node; node.getChildren())
        {
            auto subNode = cast(SceneNode)node;
            // Add this subnode and its children...
            addSceneNode( subNode );
        }
    }
    
    /** Build the geometry. 
     @remarks
     Based on all the entities which have been added, and the batching 
     options which have been set, this methodructs the batched 
     geometry structures required. The batches are added to the scene 
     and will be rendered unless you specifically hide them.
     @note
     Once you have called this method, you can no longer add any more 
     entities.
     */
    void build()
    {
        // Make sure there's nothing from previous builds
        _destroy();
        
        // Firstly allocate meshes to regions
        foreach (qsm; mQueuedSubMeshes)
        {
            Region region = getRegion(qsm.worldBounds, true);
            region.assign(qsm);
        }
        bool stencilShadows = false;
        if (mCastShadows && mOwner.isShadowTechniqueStencilBased())
        {
            stencilShadows = true;
        }
        
        // Now tell each region to build itself
        foreach (k,v; mRegionMap)
        {
            v.build(stencilShadows);
            
            // Set the visibility flags on these regions
            v.setVisibilityFlags(mVisibilityFlags);
        }
    }
    
    /** Destroys all the built geometry state (reverse of build). 
     @remarks
     You can call build() again after this and it will pick up all the
     same entities / nodes you queued last time.
     */
    void _destroy()
    {
        // delete the regions
        foreach (k,v; mRegionMap)
        {
            mOwner.extractMovableObject(v);
            destroy(v);
        }
        mRegionMap.clear();
    }
    
    /** Clears any of the entities / nodes added to this geometry and 
     destroys anything which has already been built.
     */
    void reset()
    {
        _destroy();
        //foreach (i; mQueuedSubMeshes)
        //{
        //    destory(i); //TODO Cannot destroy structs
        //}
        mQueuedSubMeshes.clear();
        // Delete precached geometry lists
        foreach (k,v; mSubMeshGeometryLookup)
        {
            destroy(v);
        }
        mSubMeshGeometryLookup.clear();
        // Delete optimised geometry
        foreach (o; mOptimisedSubMeshGeometryList)
        {
            destroy(o);
        }
        mOptimisedSubMeshGeometryList.clear();
        
    }
    
    /** Sets the distance at which batches are no longer rendered.
     @remarks
     This lets you turn off batches at a given distance. This can be 
     useful for things like detail meshes (grass, foliage etc) and could
     be combined with a shader which fades the geometry out beforehand 
     to lessen the effect.
     @param dist Distance beyond which the batches will not be rendered 
     (the default is 0, which means batches are always rendered).
     */
    void setRenderingDistance(Real dist) { 
        mUpperDistance = dist; 
        mSquaredUpperDistance = mUpperDistance * mUpperDistance;
    }
    
    /** Gets the distance at which batches are no longer rendered. */
    Real getRenderingDistance(){ return mUpperDistance; }
    
    /** Gets the squared distance at which batches are no longer rendered. */
    Real getSquaredRenderingDistance()
    { return mSquaredUpperDistance; }
    
    /** Hides or shows all the batches. */
    void setVisible(bool visible)
    {
        mVisible = visible;
        // tell any existing regions
        foreach (k,v; mRegionMap)
        {
            v.setVisible(visible);
        }
    }
    
    /** Are the batches visible? */
    bool isVisible(){ return mVisible; }
    
    /** Sets whether this geometry should cast shadows.
     @remarks
     No matter what the settings on the original entities,
     the StaticGeometry class defaults to not casting shadows. 
     This is because, being static, unless you have moving lights
     you'd be better to use precalculated shadows of some sort.
     However, if you need them, you can enable them using this
     method. If the SceneManager is set up to use stencil shadows,
     edge lists will be copied from the underlying meshes on build.
     It is essential that all meshes support stencil shadows in this
     case.
     @note If you intend to use stencil shadows, you must set this to 
     true before calling 'build' as well as making sure you set the
     scene's shadow type (that should always be the first thing you do
     anyway). You can turn shadows off temporarily but they can never 
     be turned on if they were not at the time of the build. 
     */
    void setCastShadows(bool castShadows)
    {
        mCastShadows = castShadows;
        // tell any existing regions
        foreach (k,v; mRegionMap)
        {
            v.setCastShadows(castShadows);
        }
        
    }
    /// Will the geometry from this object cast shadows?
    bool getCastShadows() { return mCastShadows; }
    
    /** Sets the size of a single region of geometry.
     @remarks
     This method allows you to configure the physical world size of 
     each region, so you can balance culling against batch size. Entities
     will be fitted within the batch they most closely fit, and the 
     eventual bounds of each batch may well be slightly larger than this
     if they overlap a little. The default is Vector3(1000, 1000, 1000).
     @note Must be called before 'build'.
     @param size Vector3 expressing the 3D size of each region.
     */
    void setRegionDimensions(Vector3 size) { 
        mRegionDimensions = size; 
        mHalfRegionDimensions = size * 0.5;
    }
    /** Gets the size of a single batch of geometry. */
    Vector3 getRegionDimensions(){ return mRegionDimensions; }
    /** Sets the origin of the geometry.
     @remarks
     This method allows you to configure the world centre of the geometry,
     thus the place which all regions surround. You probably don't need 
     to mess with this unless you have a seriously large world, since the
     default set up can handle an area 1024 * mRegionDimensions, and 
     the sparseness of population is no issue when it comes to rendering.
     The default is Vector3(0,0,0).
     @note Must be called before 'build'.
     @param origin Vector3 expressing the 3D origin of the geometry.
     */
    void setOrigin(Vector3 origin) { mOrigin = origin; }
    /** Gets the origin of this geometry. */
    Vector3 getOrigin(){ return mOrigin; }
    
    /// Sets the visibility flags of all the regions at once
    void setVisibilityFlags(uint flags)
    {
        mVisibilityFlags = flags;
        foreach (k,v; mRegionMap)
        {
            v.setVisibilityFlags(flags);
        }
    }

    /// Returns the visibility flags of the regions
    uint getVisibilityFlags()
    {
        if(mRegionMap.emptyAA())
            return MovableObject.getDefaultVisibilityFlags();
        
        auto ri = mRegionMap[mRegionMap.keysAA[0]];
        return ri.getVisibilityFlags();
    }
    
    /** Sets the render queue group this object will be rendered through.
     @remarks
     Render queues are grouped to allow you to more tightly control the ordering
     of rendered objects. If you do not call this method, all  objects default
     to the default queue (RenderQueue::getDefaultQueueGroup), which is fine for 
     most objects. You may want to alter this if you want to perform more complex
     rendering.
     @par
     See RenderQueue for more details.
     @param queueID Enumerated value of the queue group to use.
     */
    void setRenderQueueGroup(ubyte queueID)
    {
        assert(queueID <= RenderQueueGroupID.RENDER_QUEUE_MAX, "Render queue out of range!");
        mRenderQueueIDSet = true;
        mRenderQueueID = queueID;
        // tell any existing regions
        foreach (k,v; mRegionMap)
        {
            v.setRenderQueueGroup(queueID);
        }
    }
    
    /** Gets the queue group for this entity, see setRenderQueueGroup for full details. */
    ubyte getRenderQueueGroup()
    {
        return mRenderQueueID;
    }
    /// @copydoc MovableObject::visitRenderables
    void visitRenderables(Renderable.Visitor visitor, 
                          bool debugRenderables = false)
    {
        foreach (k,v; mRegionMap)
        {
            v.visitRenderables(visitor, debugRenderables);
        }
    }
    
    /// Iterator for iterating over contained regions
    //typedef MapIterator<RegionMap> RegionIterator;
    /// Get an iterator over the regions in this geometry
    //RegionIterator getRegionIterator();
    RegionMap getRegionMap()
    {
        return mRegionMap;
    }
    
    /** Dump the contents of this StaticGeometry to a file for diagnostic
     purposes.
     */
    void dump(string filename)
    {
        //TODO Maybe Datastream as stream. Using Log.Stream for now.
        //std::ofstream of(filename.c_str());
        Log log = new Log(filename, false, false);
        auto of = log.stream();
        of << "Static Geometry Report for " << mName << of.endl;
        of << "-------------------------------------------------" << of.endl;
        of << "Number of queued submeshes: " << mQueuedSubMeshes.length << of.endl;
        of << "Number of regions: " << mRegionMap.length << of.endl;
        of << "Region dimensions: " << mRegionDimensions << of.endl;
        of << "Origin: " << mOrigin << of.endl;
        of << "Max distance: " << mUpperDistance << of.endl;
        of << "Casts shadows?: " << mCastShadows << of.endl;
        of << of.endl;
        foreach (k,v; mRegionMap)
        {
            v.dump(of);
        }
        of << "-------------------------------------------------" << of.Flush();
        destroy(log);
    }
    
}
/** @} */
/** @} */