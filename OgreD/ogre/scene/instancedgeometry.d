module ogre.scene.instancedgeometry;

//import std.container;
import std.array : empty;
import core.stdc.string : memcpy;

import ogre.compat;
import ogre.resources.mesh;
import ogre.math.vector;
import ogre.math.quaternion;
import ogre.scene.staticgeometry;
import ogre.math.axisalignedbox;
import ogre.exception;
import ogre.math.angles;
import ogre.general.generals;
import ogre.animation.animations;
import ogre.math.matrix;
import ogre.general.common;
import ogre.lod.lodstrategy;
import ogre.rendersystem.vertex;
import ogre.scene.simplerenderable;
import ogre.rendersystem.hardware;
import ogre.materials.material;
import ogre.materials.technique;
import ogre.scene.camera;
import ogre.scene.renderable;
import ogre.scene.skeletoninstance;
import ogre.rendersystem.renderqueue;
import ogre.scene.movableobject;
import ogre.scene.scenenode;
import ogre.scene.entity;
import ogre.materials.materialmanager;
import ogre.math.maths;
import ogre.general.log;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Scene
 *  @{
 */

enum BatchInstance_RANGE = 1024;
enum BatchInstance_HALF_RANGE = 512;
enum BatchInstance_MAX_INDEX = 511;
enum BatchInstance_MIN_INDEX = -512;


/** Pre-transforms and batches up meshes for efficient use as instanced geometry
 in a scene
 @remarks
 Shader instancing allows to save both memory and draw calls. While 
 StaticGeometry stores 500 times the same object in a batch to display 500 
 objects, this shader instancing implementation stores only 80 times the object, 
 and then re-uses the vertex data with different shader parameter.
 Although you save memory, you make more draw call. However, you still 
 make less draw calls than if you were rendering each object independently.
 Plus, you can move the batched objects independently of one another which 
 you cannot do with StaticGeometry.
 @par
 Therefore it is important when you are rendering a lot of geometry to 
 batch things up into as few rendering calls as possible. This
 class allows you to build a batched object from a series of entities 
 in order to benefit from this behaviour.
 Batching has implications of it's own though:
 @li Batched geometry cannot be subdivided; that means that the whole
 group will be displayed, or none of it will. This obivously has
 culling issues.
 @li A single material must apply for each batch. In fact this class 
 allows you to use multiple materials, but you should be aware that 
 internally this means that there is one batch per material. 
 Therefore you won't gain as much benefit from the batching if you 
 use many different materials; try to keep the number down.
 @par
 The bounding box information is computed with object position only. 
 It doesn't take account of the object orientation. 
 @par
 The LOD settings of both the Mesh and the Materials used in 
 constructing this instanced geometry will be respected. This means that 
 if you use meshes/materials which have LOD, batches in the distance 
 will have a lower polygon count or material detail to those in the 
 foreground. Since each mesh might have different LOD distances, during 
 build the furthest distance at each LOD level from all meshes  
 in that BatchInstance is used. This means all the LOD levels change at the 
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
 @par
 You should notruct instances of this class directly; instead, call 
 SceneManager::createInstancedGeometry, which gives the SceneManager the 
 option of providing you with a specialised version of this class if it
 wishes, and also handles the memory management for you like other 
 classes.
 @note
 Warning: this class only works with indexed triangle lists at the moment,
 do not pass it triangle strips, fans or lines / points, or unindexed geometry.
 */
class InstancedGeometry //: public BatchedGeometryAlloc
{
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
    class OptimisedSubMeshGeometry //: public BatchedGeometryAlloc
    {
    public:
        this(){}
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
        SubMeshLodGeometryLinkList geometryLodList;
        string materialName;
        Vector3 position;
        Quaternion orientation;
        Vector3 scale;
        /// Pre-transformed world AABB 
        AxisAlignedBox worldBounds;
        uint ID;
    }
    //typedef vector<QueuedSubMesh*>::type QueuedSubMeshList;
    //typedef vector<String>::type QueuedSubMeshOriginList;
    alias QueuedSubMesh[] QueuedSubMeshList;
    alias string[] QueuedSubMeshOriginList;
    /// Structure recording a queued geometry for low level builds
    struct QueuedGeometry //: public BatchedGeometryAlloc
    {
        SubMeshLodGeometryLink geometry;
        Vector3 position;
        Quaternion orientation;
        Vector3 scale;
        uint ID;
    }
    //typedef vector<QueuedGeometry*>::type QueuedGeometryList;
    alias QueuedGeometry[] QueuedGeometryList;
    
    /** A GeometryBucket is a the lowest level bucket where geometry with 
     the same vertex & index format is stored. It also acts as the 
     renderable.
     */
    class GeometryBucket : SimpleRenderable
    {
    protected:
        
        /// Geometry which has been queued up pre-build (not for deallocation)
        QueuedGeometryList mQueuedGeometry;
        /// Pointer to the Batch
        InstancedGeometry mBatch;
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
        /// Index of the Texcoord where the index is stored
        ushort mTexCoordIndex;
        AxisAlignedBox mAABB;
        
        void copyIndexes(T)(T* src, ref T* dst, size_t count, size_t indexOffset)
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
        
        void _initGeometryBucket(VertexData vData, ref IndexData iData)
        {
            mBatch=mParent.getParent().getParent().getParent();
            if(!mBatch.getBaseSkeleton().isNull())
                setCustomParameter(0,Vector4(mBatch.getBaseSkeleton().getAs().getNumBones(),0,0,0));
            //mRenderOperation=new RenderOperation();
            // Clone the structure from the example
            mVertexData = vData.clone(false);
            
            mRenderOp.useIndexes = true;
            mRenderOp.indexData = new IndexData();
            
            mRenderOp.indexData.indexCount = 0;
            mRenderOp.indexData.indexStart = 0;
            mRenderOp.vertexData = new VertexData();
            mRenderOp.vertexData.vertexCount = 0;
            
            // VertexData constructor creates vertexDeclaration; must release to avoid 
            // memory leak
            HardwareBufferManager.getSingleton().destroyVertexDeclaration(mRenderOp.vertexData.vertexDeclaration);
            mRenderOp.vertexData.vertexDeclaration = vData.vertexDeclaration.clone();
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
            
            
            size_t offset=0;    
            ushort texCoordOffset=0;
            ushort texCoordSource=0;
            
            VertexElement elem=mRenderOp.vertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_TEXTURE_COORDINATES);
            
            if (elem !is null)
            {
                texCoordSource=elem.getSource();
            }
            for(ushort i=0;i<mRenderOp.vertexData.vertexDeclaration.getElementCount();i++)
            {
                if(mRenderOp.vertexData.vertexDeclaration.getElement(i).getSemantic() == VertexElementSemantic.VES_TEXTURE_COORDINATES)
                {
                    texCoordOffset++;
                }
                if(texCoordSource==mRenderOp.vertexData.vertexDeclaration.getElement(i).getSource())
                {
                    offset+= VertexElement.getTypeSize(
                        mRenderOp.vertexData.vertexDeclaration.getElement(i).getType());
                }       
            }
            
            mRenderOp.vertexData.vertexDeclaration.addElement(texCoordSource, offset, VertexElementType.VET_FLOAT1, 
                                                              VertexElementSemantic.VES_TEXTURE_COORDINATES, texCoordOffset);
            mTexCoordIndex = texCoordOffset;
            
        }
        void _initGeometryBucket(ref GeometryBucket bucket)
        {
            
            mBatch=mParent.getParent().getParent().getParent();
            if(!mBatch.getBaseSkeleton().isNull())
                setCustomParameter(0,Vector4(mBatch.getBaseSkeleton().getAs().getNumBones(),0,0,0));
            bucket.getRenderOperation(mRenderOp);
            mVertexData=mRenderOp.vertexData;
            mIndexData=mRenderOp.indexData;
            setBoundingBox(AxisAlignedBox(-10000,-10000,-10000,
                                          10000,10000,10000));
            
        }
        
    public:
        this(ref MaterialBucket parent,string formatString, 
             ref VertexData vData, ref IndexData iData)

        {
            mParent = parent;
            mFormatString = formatString;
            //mVertexData = 0;
            //mIndexData = 0;
            _initGeometryBucket(vData, iData);
        }

        this(string name, ref MaterialBucket parent,string formatString, 
             ref VertexData vData, ref IndexData iData)
        {
            super(name);
            mParent = parent;
            mFormatString = formatString;
            //mVertexData = 0;
            //mIndexData = 0;
            _initGeometryBucket(vData, iData);
        }

        this(ref MaterialBucket parent,string formatString, ref GeometryBucket bucket)
        {
            mParent = parent;
            mFormatString = formatString;
            //mVertexData = 0;
            //mIndexData = 0;
            _initGeometryBucket(bucket);
        }

        this(string name, ref MaterialBucket parent,string formatString, ref GeometryBucket bucket)
        {
            super(name);
            mParent = parent;
            mFormatString = formatString;
            //mVertexData = 0;
            //mIndexData = 0;
            _initGeometryBucket(bucket);
        }

        ~this() {}

        ref MaterialBucket getParent() { return mParent; }
        override Real getBoundingRadius()
        {
            return 1;
        }
        /// Get the vertex data for this geometry 
        ref VertexData getVertexData(){ return mVertexData; }
        /// Get the index data for this geometry 
        ref IndexData getIndexData(){ return mIndexData; }
        /// @copydoc Renderable::getMaterial
        override SharedPtr!Material getMaterial()
        {
            return mParent.getMaterial();
        }

        override Technique getTechnique()
        {
            return mParent.getCurrentTechnique();
        }

        //TODO getWorldTransforms, probably use dynamic array
        override void getWorldTransforms(ref Matrix4[] xform)
        {
            // Should be the identity transform, but lets allow transformation of the
            // nodes the BatchInstances are attached to for kicks
            if(mBatch.getBaseSkeleton().isNull())
            {
                //BatchInstance::ObjectsMap::iterator it,itbegin,itend,newit;
                auto instMap=mParent.getParent().getParent().getInstancesMap();
                //auto itend=mParent.getParent().getParent().getInstancesMap().end();
                
                if( mParent.getParent().getParent().getParent().getProvideWorldInverses() )
                {
                    // For shaders that use normal maps on instanced geometry objects,
                    // we can pass the world transform inverse matrices alongwith with
                    // the world matrices. This reduces our usable geometry limit by
                    // half in each instance.
                    foreach (k,v; instMap)
                    {
                        //*xform = v.mTransformation;
                        //*(xform+1) = xform.inverse();
                        //xform+=2;
                        xform.insertOrReplace(v.mTransformation);
                        xform.insertOrReplace(v.mTransformation.inverse());
                    }
                }
                else
                {
                    foreach (k,v; instMap)
                    {
                        xform.insertOrReplace(v.mTransformation);
                    }
                }
            }
            else
            {
                //BatchInstance::ObjectsMap::iterator it,itbegin,itend,newit;
                auto instMap=mParent.getParent().getParent().getInstancesMap();
                //itend=mParent.getParent().getParent().getInstancesMap().end();
                
                foreach (k,v; instMap)
                {
                    
                    if( mParent.getParent().getParent().getParent().getProvideWorldInverses() )
                    {
                        for(int i=0;i<v.mNumBoneMatrices;++i)
                        {
                            xform.insertOrReplace(v.mBoneWorldMatrices[i]);
                            xform.insertOrReplace(v.mBoneWorldMatrices[i].inverse());
                        }
                    }
                    else
                    {
                        for(int i=0;i<v.mNumBoneMatrices;++i)
                        {
                            xform.insertOrReplace(v.mBoneWorldMatrices[i]);
                        }
                    }
                }
                
            }
            
        }

        override ushort getNumWorldTransforms()
        {
            bool bSendInverseXfrm = mParent.getParent().getParent().getParent().getProvideWorldInverses();
            
            if(mBatch.getBaseSkeleton().isNull())
            {
                BatchInstance batch=mParent.getParent().getParent();
                return cast(ushort)(batch.getInstancesMap().length * (bSendInverseXfrm ? 2 : 1));
            }
            else
            {
                BatchInstance batch=mParent.getParent().getParent();
                return cast(ushort)(
                    mBatch.getBaseSkeleton().getAs().getNumBones()*batch.getInstancesMap().length * (bSendInverseXfrm ? 2 : 1));
            }
        }

        Real getSquaredViewDepth(Camera cam)
        {
            BatchInstance batchInstance = mParent.getParent().getParent();
            if (cam == batchInstance.mCamera)
                return batchInstance.mSquaredViewDepth;
            else
                return batchInstance.getParentNode().getSquaredViewDepth(cam.getLodCamera());
        }

        override LightList getLights()
        {
            return mParent.getParent().getParent().getLights();
        }

        override bool getCastsShadows()
        {
            return mParent.getParent().getParent().getCastShadows();
        }

        string getFormatString()
        {
            return mFormatString;
        }

        /** Try to assign geometry to this bucket.
         @return false if there is no room left in this bucket
         */
        bool assign(ref QueuedGeometry qgeom)
        {
            // Do we have enough space?
            if (mRenderOp.vertexData.vertexCount + qgeom.geometry.vertexData.vertexCount
                > mMaxVertexIndex)
            {
                return false;
            }
            
            mQueuedGeometry.insert(qgeom);
            mRenderOp.vertexData.vertexCount += qgeom.geometry.vertexData.vertexCount;
            mRenderOp.indexData.indexCount += qgeom.geometry.indexData.indexCount;
            
            return true;
        }

        /// Build
        void build()
        {
            // Ok, here's where we transfer the vertices and indexes to the shared
            // buffers
            // Shortcuts
            VertexDeclaration dcl = mRenderOp.vertexData.vertexDeclaration;
            VertexBufferBinding binds =mVertexData.vertexBufferBinding;
            
            // create index buffer, and lock
            mRenderOp.indexData.indexBuffer = HardwareBufferManager.getSingleton()
                .createIndexBuffer(mIndexType, mRenderOp.indexData.indexCount,
                                   HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY);
            uint* p32Dest = null;
            ushort* p16Dest = null;
            
            if (mIndexType == HardwareIndexBuffer.IndexType.IT_32BIT)
            {
                p32Dest = cast(uint*)(
                    mRenderOp.indexData.indexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
            }
            else
            {
                p16Dest = cast(ushort*)(
                    mRenderOp.indexData.indexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
            }
            
            // create all vertex buffers, and lock
            ushort b;
            //ushort posBufferIdx = dcl.findElementBySemantic(VES_POSITION).getSource();
            
            //vector<ubyte*>::type destBufferLocks;
            ubyte*[] destBufferLocks;
            //vector<VertexDeclaration::VertexElementList>::type bufferElements;
            VertexDeclaration.VertexElementList[] bufferElements;
            
            for (b = 0; b < binds.getBufferCount(); ++b)
            {
                
                size_t vertexCount = mRenderOp.vertexData.vertexCount;
                
                SharedPtr!HardwareVertexBuffer vbuf =
                    HardwareBufferManager.getSingleton().createVertexBuffer(
                        dcl.getVertexSize(b),
                        vertexCount,
                        HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY);
                binds.setBinding(b, vbuf);
                ubyte* pLock = cast(ubyte*)(
                    vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
                destBufferLocks ~= pLock;
                // Pre-cache vertex elements per buffer
                bufferElements.insert(dcl.findElementsBySource(b));
                mRenderOp.vertexData.vertexBufferBinding.setBinding(b,vbuf);
            }
            
            
            // Iterate over the geometry items
            size_t indexOffset = 0;

            // to generate the boundingBox
            Real Xmin,Ymin,Zmin,Xmax,Ymax,Zmax; 
            Xmin=0;
            Ymin=0;
            Zmin=0;
            Xmax=0;
            Ymax=0;
            Zmax=0;
            QueuedGeometry precGeom = mQueuedGeometry[0];
            ushort index=0;
            if( mParent.getLastIndex()!=0)
                index = cast(ushort)(mParent.getLastIndex() + 1);
            
            foreach (geom; mQueuedGeometry)
            {
                if(precGeom.ID!=geom.ID)
                    index++;
                
                //create  a new instanced object
                InstancedObject instancedObject = mParent.getParent().getParent().isInstancedObjectPresent(index);
                if(instancedObject is null)
                {
                    if(mBatch.getBaseSkeleton().isNull())
                    {
                        instancedObject= new InstancedObject(index);
                    }
                    else
                    {
                        instancedObject= new InstancedObject(index,mBatch.getBaseSkeletonInstance(),
                                                             mBatch.getBaseAnimationState());
                    }
                    mParent.getParent().getParent().addInstancedObject(index,instancedObject);
                    
                }
                instancedObject.addBucketToList(this);
                
                
                
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
                    ubyte* pSrcBase = cast(ubyte*)(
                        srcBuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
                    // Get buffer lock pointer, we'll update this later
                    ubyte* pDstBase = destBufferLocks[b];
                    size_t bufInc = srcBuf.get().getVertexSize();
                    
                    // Iterate over vertices
                    float* pSrcReal, pDstReal;
                    Vector3 tmp;
                    
                    
                    
                    for (size_t v = 0; v < srcVData.vertexCount; ++v)
                    {
                        //to know if the current buffer is the one with the buffer or not
                        bool isTheBufferWithIndex=false;
                        // Iterate over vertex elements
                        VertexDeclaration.VertexElementList elems =
                            bufferElements[b];
                        
                        foreach (elem; elems)
                        {
                            elem.baseVertexPointerToElement(pSrcBase, &pSrcReal);
                            elem.baseVertexPointerToElement(pDstBase, &pDstReal);
                            if(elem.getSemantic()==VertexElementSemantic.VES_TEXTURE_COORDINATES && elem.getIndex()==mTexCoordIndex)
                            {
                                isTheBufferWithIndex=true;
                                *pDstReal++ = cast(float)index;
                            }
                            else
                            {
                                switch (elem.getSemantic())
                                {
                                    case VertexElementSemantic.VES_POSITION:
                                        tmp.x = pSrcReal[0];
                                        tmp.y = pSrcReal[1];
                                        tmp.z = pSrcReal[2];
                                        if(tmp.x<Xmin)
                                            Xmin = tmp.x;
                                        if(tmp.y<Ymin)
                                            Ymin = tmp.y;
                                        if(tmp.z<Zmin)
                                            Zmin = tmp.z;
                                        if(tmp.x>Xmax)
                                            Xmax = tmp.x;
                                        if(tmp.y>Ymax)
                                            Ymax = tmp.y;
                                        if(tmp.z>Zmax)
                                            Zmax = tmp.z;
                                    default:
                                        // just raw copy
                                        memcpy(pDstReal, pSrcReal,
                                               VertexElement.getTypeSize(elem.getType()));
                                        break;
                                }
                                
                            }
                            
                            
                        }
                        if (isTheBufferWithIndex)
                            pDstBase += bufInc+4;
                        else
                            pDstBase += bufInc;
                        pSrcBase += bufInc;
                        
                    }
                    
                    // Update pointer
                    destBufferLocks[b] = pDstBase;
                    srcBuf.get().unlock();
                    
                    
                }
                indexOffset += geom.geometry.vertexData.vertexCount;
                
                
                precGeom=geom;
                
            }
            mParent.setLastIndex(index);
            // Unlock everything
            mRenderOp.indexData.indexBuffer.get().unlock();
            for (b = 0; b < binds.getBufferCount(); ++b)
            {
                binds.getBuffer(b).get().unlock();
            }
            
            destroy(mVertexData);
            destroy(mIndexData);
            
            mVertexData=mRenderOp.vertexData;
            mIndexData=mRenderOp.indexData;
            mBatch.getRenderOperationVector().insert(mRenderOp);
            setBoundingBox(AxisAlignedBox(Xmin,Ymin,Zmin,Xmax,Ymax,Zmax));
            mAABB=AxisAlignedBox(Xmin,Ymin,Zmin,Xmax,Ymax,Zmax);
            
        }
        /// Dump contents for diagnostics
        void dump(ref Log.Stream of)
        {
            of << "Geometry Bucket" << of.endl;
            of << "---------------" << of.endl;
            of << "Format string: " << mFormatString << of.endl;
            of << "Geometry items: " << mQueuedGeometry.length << of.endl;
            of << "---------------" << of.endl;
            
        }
        /// Return the BoundingBox information. Useful when cloning the batch instance.
        ref AxisAlignedBox getAABB(){return mAABB;}
        /// @copydoc MovableObject::visitRenderables
        override void visitRenderables(Renderable.Visitor visitor, bool debugRenderables)
        {
            visitor.visit(this, mParent.getParent().getLod(), false);
        }
        
    }

    

    class InstancedObject //: public BatchedGeometryAlloc
    {
        //friend class GeometryBucket;
    public:
        enum TransformSpace
        {
            /// Transform is relative to the local space
            TS_LOCAL,
            /// Transform is relative to the space of the parent node
            TS_PARENT,
            /// Transform is relative to world space
            TS_WORLD
        }
        /// list of Geometry Buckets that contains the instanced object
        //typedef vector<GeometryBucket*>::type GeometryBucketList;
        alias GeometryBucket[] GeometryBucketList;
    protected:
        GeometryBucketList mGeometryBucketList;
        ushort mIndex;
        Matrix4  mTransformation;
        Quaternion mOrientation;
        Vector3 mScale;
        Vector3 mPosition;
        SkeletonInstance mSkeletonInstance;
        /// Cached bone matrices, including any world transform
        Matrix4[] mBoneWorldMatrices;
        /// Cached bone matrices in skeleton local space
        Matrix4[] mBoneMatrices;
        /// State of animation for animable meshes
        AnimationStateSet mAnimationState;
        ushort mNumBoneMatrices;
        /// Records the last frame in which animation was updated
        ulong mFrameAnimationLastUpdated;
    public:
        this(ushort index)
        {
            mIndex = index;
            mTransformation = Matrix4.ZERO;
            mOrientation = Quaternion.IDENTITY;
            mScale = Vector3.UNIT_SCALE;
            mPosition = Vector3.ZERO;
            mSkeletonInstance = null;
            mBoneWorldMatrices = null;
            mBoneMatrices = null;
            mAnimationState = null;
            mNumBoneMatrices = 0;
            mFrameAnimationLastUpdated = ulong.max;

        }
        this(ushort index,SkeletonInstance skeleton, AnimationStateSet animations)
        {
            mIndex = index;
            mTransformation = Matrix4.ZERO;
            mOrientation = Quaternion.IDENTITY;
            mScale = Vector3.UNIT_SCALE;
            mPosition = Vector3.ZERO;
            mSkeletonInstance = skeleton;
            mBoneWorldMatrices = null;
            mBoneMatrices = null;
            mAnimationState = null;
            mNumBoneMatrices = 0;
            mFrameAnimationLastUpdated = ulong.max;

            mSkeletonInstance.load();
            
            mAnimationState = new AnimationStateSet();
            mNumBoneMatrices = mSkeletonInstance.getNumBones();
            mBoneMatrices = new Matrix4[mNumBoneMatrices];

            foreach(anim; animations.getAnimationStates())
            {
                mAnimationState.createAnimationState(anim.getAnimationName(),
                                                     anim.getTimePosition(),
                                                     anim.getLength(),
                                                     anim.getWeight());
            }
        }

        ~this()
        {
            mGeometryBucketList.clear();
            destroy(mAnimationState);
            destroy(mBoneMatrices);
            destroy(mBoneWorldMatrices);
        }

        void setPosition( Vector3  position)
        {
            mPosition=position;
            needUpdate();
            BatchInstance parentBatchInstance = mGeometryBucketList[0].getParent().getParent().getParent();
            parentBatchInstance.updateBoundingBox();
            
        }

        Vector3 getPosition()
        {
            return mPosition;
        }

        void yaw(Radian angle)
        {
            Quaternion q;
            q.FromAngleAxis(angle,Vector3.UNIT_Y);
            rotate(q);
        }

        void pitch(Radian angle)
        {
            Quaternion q;
            q.FromAngleAxis(angle,Vector3.UNIT_X);
            rotate(q);
        }

        void roll(Radian angle)
        {
            Quaternion q;
            q.FromAngleAxis(angle,Vector3.UNIT_Z);
            rotate(q);
        }

        void rotate(Quaternion q)
        {
            mOrientation = mOrientation * q;
            needUpdate();
        }

        void setScale(Vector3 scale)
        {
            mScale=scale;
            needUpdate();
        }

        Vector3 getScale()
        {
            return mScale;
        }

        void setOrientation(Quaternion q)
        {   
            mOrientation = q;
            needUpdate();
        }

        void setPositionAndOrientation(Vector3 p,Quaternion q)
        {   
            mPosition = p;
            mOrientation = q;
            needUpdate();
            BatchInstance parentBatchInstance=mGeometryBucketList[0].getParent().getParent().getParent();
            parentBatchInstance.updateBoundingBox();
        }

        Quaternion getOrientation()
        {
            return mOrientation;
        }

        void addBucketToList(ref GeometryBucket bucket)
        {
            mGeometryBucketList.insert(bucket);
        }

        void needUpdate()
        {
            mTransformation.makeTransform(
                mPosition,
                mScale,
                mOrientation);
        }

        ref GeometryBucketList getGeometryBucketList(){return mGeometryBucketList;}

        void translate(Matrix3 axes,Vector3 move)
        {
            Vector3 derived = axes * move;
            translate(derived);
        }

        void translate(Vector3 d)
        {
            mPosition += d;
            needUpdate();
        }

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

        void updateAnimation()
        {
            
            if(mSkeletonInstance)
            {
                mSkeletonInstance.setAnimationState(mAnimationState);
                mSkeletonInstance._getBoneMatrices(mBoneMatrices);
                
                // Allocate bone world matrices on demand, for better memory footprint
                // when using software animation.
                if (!mBoneWorldMatrices)
                {
                    mBoneWorldMatrices = new Matrix4[mNumBoneMatrices];
                }
                
                for (ushort i = 0; i < mNumBoneMatrices; ++i)
                {
                    mBoneWorldMatrices[i] =  mTransformation * mBoneMatrices[i];   
                }   
            }
        }

        ref AnimationState getAnimationState(string name)
        {
            if (!mAnimationState)
            {
                throw new ItemNotFoundError("Object is not animated",
                                            "InstancedGeometry.InstancedObject.getAnimationState");
            }
            //      AnimationStateIterator it=mAnimationState.getAnimationStateIterator();
            //      while (it.hasMoreElements())
            //      {
            //          AnimationState*anim= it.getNext();
            //
            //          
            //      }
            return mAnimationState.getAnimationState(name);
        }

        ref SkeletonInstance getSkeletonInstance(){return mSkeletonInstance;}
        
    }
    /** A MaterialBucket is a collection of smaller buckets with the same 
     Material (and implicitly the same LOD). */
    class MaterialBucket //: public BatchedGeometryAlloc
    {
    public:
        /// list of Geometry Buckets in this BatchInstance
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
        int mLastIndex;
        /// list of Geometry Buckets in this BatchInstance
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

            foreach (elem; elemList)
            {
                str ~= std.conv.text(elem.getSource(), "|", 
                                     elem.getSource(), "|", 
                                     elem.getSemantic(), "|", 
                                     elem.getType(), "|");
            }
            
            return str;
            
        }

        
    public:
        this(ref LODBucket parent,string materialName)
        {
            mParent = parent;
            mMaterialName = materialName;
            mTechnique = null;
            mLastIndex = 0;
            mMaterial = MaterialManager.getSingleton().getByName(mMaterialName);
        }

        ~this()
        {
            // delete
            foreach (i; mGeometryBucketList)
            {
                destroy(i);
            }
            mGeometryBucketList.clear();
            // no need to delete queued meshes, these are managed in InstancedGeometry
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
                auto gbucket = new GeometryBucket(this, formatString,
                                                  qgeom.geometry.vertexData, qgeom.geometry.indexData);
                // Add to main list
                mGeometryBucketList.insert(gbucket);
                // Also index in 'current' list
                mCurrentGeometryMap[formatString] = gbucket;
                if (!gbucket.assign(qgeom))
                {
                    throw new InternalError(
                        "Somehow we couldn't fit the requested geometry even in a " ~
                        "brand new GeometryBucket!! Must be a bug, please report.",
                        "InstancedGeometry.MaterialBucket.assign");
                }
            }
        }
        /// Build
        void build()
        {
            mTechnique = null;
            mMaterial = MaterialManager.getSingleton().getByName(mMaterialName);
            if (mMaterial.isNull())
            {
                throw new ItemNotFoundError(
                    "Material '" ~ mMaterialName ~ "' not found.",
                    "InstancedGeometry.MaterialBucket.build");
            }
            mMaterial.getAs().load();
            // tell the geometry buckets to build
            
            foreach (i; mGeometryBucketList)
            {
                i.build();
            }
        }
        /// Add children to the render queue
        void addRenderables(ref RenderQueue queue, ubyte group, 
                            Real lodValue)
        {
            // Get batch instance
            BatchInstance batchInstance = mParent.getParent();
            
            // Get material lod strategy
            auto materialLodStrategy = mMaterial.getAs().getLodStrategy();
            
            // If material strategy doesn't match, recompute lod value with correct strategy
            if (materialLodStrategy != batchInstance.mLodStrategy)
                lodValue = materialLodStrategy.getValue(batchInstance, batchInstance.mCamera);
            
            // Determine the current material technique
            mTechnique = mMaterial.getAs().getBestTechnique(mMaterial.getAs().getLodIndex(lodValue));
            
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
        /*GeometryIterator getGeometryIterator()
         {
         return GeometryIterator(
         mGeometryBucketList.begin(), mGeometryBucketList.end());
         }*/

        // See below
        /*ref GeometryBucketList getGeometryBucketList()
         {
         return mGeometryBucketList;
         }*/

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

        //TODO C++ function, there was no function body in cpp.
        /// Return the geometry map
        ref CurrentGeometryMap getMaterialBucketMap()
        {
            return mCurrentGeometryMap;
        }
        //TODO C++ function, there was no function body in cpp.
        /// Return the geometry list
        ref GeometryBucketList getGeometryBucketList()
        {
            return mGeometryBucketList;
        }
        
        /// fill in the map and the list
        void updateContainers(ref GeometryBucket bucket,string format)
        {
            mCurrentGeometryMap[format] = bucket;
            mGeometryBucketList.insert(bucket);
        }

        void setLastIndex(int index) { mLastIndex = index; }
        int getLastIndex() { return mLastIndex; }
        void setMaterial(string name)
        {
            mMaterial = MaterialManager.getSingleton().getByName(name);
        }

        void visitRenderables(Renderable.Visitor visitor, bool debugRenderables)
        {
            foreach (i; mGeometryBucketList)
            {
                i.visitRenderables(visitor, debugRenderables);
            }
        }

    }
    /** A LODBucket is a collection of smaller buckets with the same LOD. 
     @remarks
     LOD ref ers to Mesh LOD here. Material LOD can change separately
     at the next bucket down from this.
     */
    class LODBucket //: public BatchedGeometryAlloc
    {
    public:
        /// Lookup of Material Buckets in this BatchInstance
        //typedef map<String, MaterialBucket*>::type MaterialBucketMap;
        alias MaterialBucket[string] MaterialBucketMap;
    protected:
        /// Pointer to parent BatchInstance
        BatchInstance mParent;
        /// LOD level (0 == full LOD)
        ushort mLod;
        /// lod value at which this LOD starts to apply (squared)
        Real mLodValue;
        /// Lookup of Material Buckets in this BatchInstance
        MaterialBucketMap mMaterialBucketMap;
        /// Geometry queued for a single LOD (deallocated here)
        QueuedGeometryList mQueuedGeometryList;
    public:
        this(ref BatchInstance parent, ushort lod, Real lodValue)
        {
            mParent = parent;
            mLod = lod;
            mLodValue = lodValue;
        }

        ~this()
        {
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
            // no need to delete queued meshes, these are managed in InstancedGeometry
        }
        BatchInstance getParent() { return mParent; }
        /// Get the lod index
        ushort getLod(){ return mLod; }
        /// Get the lod value
        Real getLodValue(){ return mLodValue; }
        /// Assign a queued submesh to this bucket, using specified mesh LOD
        void assign(ref QueuedSubMesh qmesh, ushort atLod)
        {
            QueuedGeometry _q;
            mQueuedGeometryList.insert(_q);
            QueuedGeometry* q = &mQueuedGeometryList[$-1];
            q.position = qmesh.position;
            q.orientation = qmesh.orientation;
            q.scale = qmesh.scale;
            q.ID = qmesh.ID;
            if (qmesh.geometryLodList.length > atLod)
            {
                // This submesh has enough lods, use the right one
                q.geometry = qmesh.geometryLodList[atLod];
            }
            else
            {
                // Not enough lods, use the lowest one we have
                q.geometry =
                    qmesh.geometryLodList[qmesh.geometryLodList.length - 1];
            }
            // Locate a material bucket
            MaterialBucket mbucket;
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
        void build()
        {
            // Just pass this on to child buckets
            
            foreach (k,v; mMaterialBucketMap)
            {
                v.build();
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
        /*MaterialIterator getMaterialIterator()
         {
         return MaterialIterator(
         mMaterialBucketMap.begin(), mMaterialBucketMap.end());
         }*/

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
            of << "------------------" << of.Flush();
            
        }
        /// fill the map
        void updateContainers(ref MaterialBucket bucket, string name )
        {
            mMaterialBucketMap[name] = bucket;
        }
        void visitRenderables(Renderable.Visitor visitor, bool debugRenderables)
        {
            foreach (k,v; mMaterialBucketMap)
            {
                v.visitRenderables(visitor, debugRenderables);
            }
        }
        
    }
    /** The details of a topological BatchInstance which is the highest level of
     partitioning for this class.
     @remarks
     The size & shape of BatchInstances entirely depends on the SceneManager
     specific implementation. It is a MovableObject since it will be
     attached to a node based on the local centre - in practice it
     won't actually move (although in theory it could).
     */
    class BatchInstance : MovableObject
    {
        //friend class MaterialBucket;
    public:
        
        
        /// list of LOD Buckets in this BatchInstance
        //typedef vector<LODBucket*>::type LODBucketList;
        //typedef map<unsigned short, InstancedObject*>::type ObjectsMap;
        //typedef MapIterator<ObjectsMap> InstancedObjectIterator;

        alias LODBucket[] LODBucketList;
        alias InstancedObject[ushort] ObjectsMap;
    protected:
        
        /// Parent static geometry
        InstancedGeometry mParent;
        /// Scene manager link
        SceneManager mSceneMgr;
        /// Scene node
        SceneNode mNode;
        /// Local list of queued meshes (not used for deallocation)
        QueuedSubMeshList mQueuedSubMeshes;
        /// Unique identifier for the BatchInstance
        uint mBatchInstanceID;
        
        ObjectsMap mInstancesMap;
    public:
        /// Lod values as built up - use the max at each level
        Mesh.LodValueList mLodValues;
        /// Local AABB relative to BatchInstance centre
        AxisAlignedBox mAABB;
        /// Local bounding radius
        Real mBoundingRadius;
        /// The current lod level, as determined from the last camera
        ushort mCurrentLod;
        /// Current lod value, passed on to do material lod later
        Real mLodValue;
        /// Current camera, passed on to do material lod later
        Camera mCamera;
        /// Cached squared view depth value to avoid recalculation by GeometryBucket
        Real mSquaredViewDepth;
    protected:
        /// List of LOD buckets         
        LODBucketList mLodBucketList;
        /// Lod strategy reference
        LodStrategy mLodStrategy;
        
    public:
        this(ref InstancedGeometry parent,string name, ref SceneManager mgr, 
             uint BatchInstanceID)
        {
            super(name);
            mParent = parent;
            mSceneMgr = mgr;
            mBatchInstanceID = BatchInstanceID;
            mBoundingRadius= 0.0f;
            //Null automagically anyway
            //mNode = null;
            //mCurrentLod = null;
            //mLodStrategy = null;
        }
        ~this()
        {
            if (mNode)
            {
                mNode.getParentSceneNode().removeChild(mNode);
                mSceneMgr.destroySceneNode(mNode.getName());
                mNode = null;
            }
            // delete
            foreach (i; mLodBucketList)
            {
                destroy(i);
            }
            mLodBucketList.clear();
            
            foreach(k,v; mInstancesMap)
            {
                destroy(v);
            }
            mInstancesMap.clear();
            // no need to delete queued meshes, these are managed in InstancedGeometry
        }

        // more fields can be added in subclasses
        ref InstancedGeometry getParent(){ return mParent;}

        /// Assign a queued mesh to this BatchInstance, read for final build
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
                    throw new InvalidParamsError( "Lod strategies do not match",
                                                 "InstancedGeometry.InstancedObject.assign");
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
                MeshLodUsage meshLod = qmesh.submesh.parent.getLodLevel(lod);
                mLodValues[lod] = std.algorithm.max(mLodValues[lod], meshLod.value);
            }
            
            // update bounds
            // Transform world bounds relative to our centre
            auto localBounds = AxisAlignedBox(
                qmesh.worldBounds.getMinimum() ,
                qmesh.worldBounds.getMaximum());
            mAABB.merge(localBounds);
            mBoundingRadius = Math.boundingRadiusFromAABB(mAABB);
            
        }
        /// Build this BatchInstance
        void build()
        {
            // Create a node
            mNode = mSceneMgr.getRootSceneNode().createChildSceneNode(mName);
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
                lodBucket.build();
            }   
        }
        /// Get the BatchInstance ID of this BatchInstance
        uint getID(){ return mBatchInstanceID; }
        /// Get the centre point of the BatchInstance
        //         Vector3& getCentre(){ return mCentre; }
        override string getMovableType()
        {
            static string sType = "InstancedGeometry";
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

        void  setBoundingBox(AxisAlignedBox box)
        {
            mAABB = box;
        }

        override Real getBoundingRadius()
        {
            return mBoundingRadius;
        }

        override void _updateRenderQueue(RenderQueue queue)
        {
            //we parse the Instanced Object map to update the animations.
            foreach (k,v; mInstancesMap)
            {
                v.updateAnimation();
            }
            mLodBucketList[mCurrentLod].addRenderables(queue, mRenderQueueID,
                                                       mLodValue);
        }

        override bool isVisible()
        {
            return mVisible && !mBeyondFarDistance;
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
        
        //  uint getTypeFlags();
        
        //typedef VectorIterator<LODBucketList> LODIterator;
        /// Get an iterator over the LODs in this BatchInstance
        /*LODIterator getLODIterator()
         {
         return LODIterator(mLodBucketList.begin(), mLodBucketList.end());
         }*/

        ref LODBucketList getLODBucketList()
        {
            return mLodBucketList;
        }

        /// Shared set of lights for all GeometryBuckets
        LightList getLights()
        {
            return queryLights();
        }
        
        /// update the bounding box of the BatchInstance according to the positions of the objects
        void updateBoundingBox()
        {
            AxisAlignedBox aabb;
            
            //Get the first GeometryBucket to get the aabb
            //LODIterator lodIterator = getLODIterator();
            if( !mLodBucketList.empty() )
            {           
                LODBucket lod = mLodBucketList[0];
                auto matIt = lod.getMaterialBucketMap();
                if( !matIt.emptyAA())
                {                   
                    MaterialBucket mat = matIt[matIt.keysAA[0]]; //TODO MaterialBucket
                    auto geomIt = mat.getGeometryBucketList();
                    if( !geomIt.empty() )
                    {
                        GeometryBucket geom = geomIt[0]; //TODO GeometryBucket
                        aabb = geom.getAABB();
                    }
                }
            }

            InstancedObject obj;
            Vector3 vMin = Vector3.ZERO;
            Vector3 vMax = Vector3.ZERO;
            if( !mInstancesMap.emptyAA() )
            {
                obj = mInstancesMap[mInstancesMap.keysAA[0]];
                vMin = obj.getPosition() + aabb.getMinimum();
                vMax = obj.getPosition() + aabb.getMaximum();
            }
            
            foreach( k,v; mInstancesMap)
            {
                Vector3 position = v.getPosition();
                Vector3 scale    = v.getScale();
                
                vMin.x = std.algorithm.min( vMin.x, position.x + aabb.getMinimum().x * scale.x );
                vMin.y = std.algorithm.min( vMin.y, position.y + aabb.getMinimum().y * scale.y );
                vMin.z = std.algorithm.min( vMin.z, position.z + aabb.getMinimum().z * scale.z );
                
                vMax.x = std.algorithm.max( vMax.x, position.x + aabb.getMaximum().x * scale.x );
                vMax.y = std.algorithm.max( vMax.y, position.y + aabb.getMaximum().y * scale.y );
                vMax.z = std.algorithm.max( vMax.z, position.z + aabb.getMaximum().z * scale.z );
            }
            
            aabb.setExtents( vMin, vMax );
            
            //Now apply the bounding box
            //lodIterator = getLODIterator();
            //while( lodIterator.hasMoreElements() )
            foreach(lod; mLodBucketList)
            {   
                foreach (k, mat; lod.getMaterialBucketMap())
                {
                    foreach( geom; mat.getGeometryBucketList())
                    {
                        geom.setBoundingBox( aabb );
                        this.mNode._updateBounds();
                        mAABB = aabb;
                    }
                }
            }
        }
        
        /// Dump contents for diagnostics
        void dump(ref Log.Stream of)
        {
            of << "BatchInstance " << mBatchInstanceID << of.endl;
            of << "--------------------------" << of.endl;
            of << "Local AABB: " << mAABB << of.endl;
            of << "Bounding radius: " << mBoundingRadius << of.endl;
            of << "Number of LODs: " << mLodBucketList.length << of.endl;
            
            foreach (i; mLodBucketList)
            {
                i.dump(of);
            }
            of << "--------------------------" << of.Flush();
        }
        /// fill in the list 
        void updateContainers(ref LODBucket bucket )
        {
            mLodBucketList.insert(bucket);
        }
        /// attach the BatchInstance to the scene
        void attachToScene()
        {
            
            mNode = mSceneMgr.getRootSceneNode().createChildSceneNode(mName/*,mCentre*/);
            mNode.attachObject(this);
        }

        void addInstancedObject(ushort index, ref InstancedObject object)
        {
            mInstancesMap[index] = object;
        }

        InstancedObject isInstancedObjectPresent(ushort index)
        {
            if ((index in mInstancesMap) !is null)
                return mInstancesMap[index];
            else return null;
        }

        /*InstancedObjectIterator getObjectIterator()
         {
         return InstancedObjectIterator(mInstancesMap.begin(), mInstancesMap.end());
         }*/

        /*ObjectsMap getInstancesMap()
         {
         return mInstancesMap;
         }*/

        ref SceneNode getSceneNode(){return mNode;}
        ref ObjectsMap getInstancesMap(){return  mInstancesMap;}
        /// change the shader used to render the batch instance
        
    }
    /** Indexed BatchInstance map based on packed x/y/z BatchInstance index, 10 bits for
     each axis.
     */
    //typedef map<uint, BatchInstance*>::type BatchInstanceMap;
    alias BatchInstance[uint] BatchInstanceMap;
    /** Simple vectors where are stored all the renderoperations of the Batch.
     This vector is used when we want to delete the batch, in order to delete only one time each
     render operation.

     */
    //typedef vector<RenderOperation*>::type RenderOperationVector;
    alias RenderOperation[] RenderOperationVector;
protected:
    // General state & settings
    SceneManager mOwner;
    string mName;
    bool mBuilt;
    Real mUpperDistance;
    Real mSquaredUpperDistance;
    bool mCastShadows;
    Vector3 mBatchInstanceDimensions;
    Vector3 mHalfBatchInstanceDimensions;
    Vector3 mOrigin;
    bool mVisible;
    /// Flags to indicate whether the World Transform Inverse matrices are passed to the shaders
    bool mProvideWorldInverses;
    /// The render queue to use when rendering this object
    ubyte mRenderQueueID;
    /// Flags whether the RenderQueue's default should be used.
    bool mRenderQueueIDSet;
    /// number of objects in the batch
    uint mObjectCount;
    QueuedSubMeshList mQueuedSubMeshes;
    BatchInstance mInstancedGeometryInstance;
    /**this is just a pointer to the base skeleton that will be used for each animated object in the batches
     This pointer has a value only during the creation of the InstancedGeometry
     */
    SharedPtr!Skeleton mBaseSkeleton;
    SkeletonInstance mSkeletonInstance;
    /**This is the main animation state. All "objects" in the batch will use an instance of this animation
     state
     */
    AnimationStateSet mAnimationState;
    /// List of geometry which has been optimised for SubMesh use
    /// This is the primary storage used for cleaning up later
    OptimisedSubMeshGeometryList mOptimisedSubMeshGeometryList;
    
    /** Cached links from SubMeshes to (potentially optimised) geometry
     This is not used for deletion since the lookup may reference
     original vertex data
     */
    SubMeshGeometryLookup mSubMeshGeometryLookup;
    
    /// Map of BatchInstances
    BatchInstanceMap mBatchInstanceMap;
    /** This vector stores all the renderOperation used in the batch. 
     See the type definition for more details.
     */
    RenderOperationVector mRenderOps;
    /** method for getting a BatchInstance most suitable for the
     passed in bounds. Can be overridden by subclasses.
     */
    BatchInstance getBatchInstance(AxisAlignedBox bounds, bool autoCreate)
    {
        if (bounds.isNull())
            return null;
        
        // Get the BatchInstance which has the largest overlapping volume
        Vector3 min = bounds.getMinimum();
        Vector3 max = bounds.getMaximum();
        
        // Get the min and max BatchInstance indexes
        ushort minx, miny, minz;
        ushort maxx, maxy, maxz;
        getBatchInstanceIndexes(min, minx, miny, minz);
        getBatchInstanceIndexes(max, maxx, maxy, maxz);
        Real maxVolume = 0.0f;
        ushort finalx =0 , finaly = 0, finalz = 0;
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
        
        return getBatchInstance(finalx, finaly, finalz, autoCreate);
    }

    /** Get the BatchInstance within which a point lies */
    BatchInstance getBatchInstance(Vector3 point, bool autoCreate)
    {
        ushort x, y, z;
        getBatchInstanceIndexes(point, x, y, z);
        return getBatchInstance(x, y, z, autoCreate);
    }

    /** Get the BatchInstance using indexes */
    BatchInstance getBatchInstance(ushort x, ushort y, ushort z, bool autoCreate)
    {
        uint index = packIndex(x, y, z);
        BatchInstance ret = getBatchInstance(index);
        if (!ret && autoCreate)
        {
            // Make a name
            string str = std.conv.text(mName, ":", index);
            // Calculate the BatchInstance centre
            auto centre = Vector3(0,0,0);// = getBatchInstanceCentre(x, y, z);
            ret = new BatchInstance(this, str, mOwner, index/*, centre*/);
            mOwner.injectMovableObject(ret);
            ret.setVisible(mVisible);
            ret.setCastShadows(mCastShadows);
            if (mRenderQueueIDSet)
            {
                ret.setRenderQueueGroup(mRenderQueueID);
            }
            mBatchInstanceMap[index] = ret;
        }
        return ret;
    }

    /** Get the BatchInstance using a packed index, returns null if it doesn't exist. */
    BatchInstance getBatchInstance(uint index)
    {
        auto i = index in mBatchInstanceMap;
        if (i !is null)
        {
            return *i;
        }
        else
        {
            return null;
        }
        
    }
    /** Get the BatchInstance indexes for a point.
     */
    void getBatchInstanceIndexes(Vector3 point, 
                                 ref ushort x, ref ushort y, ref ushort z)
    {
        // Scale the point into multiples of BatchInstance and adjust for origin
        Vector3 scaledPoint = (point - mOrigin) / mBatchInstanceDimensions;
        
        // Round down to 'bottom left' point which represents the cell index
        int ix = Math.IFloor(scaledPoint.x);
        int iy = Math.IFloor(scaledPoint.y);
        int iz = Math.IFloor(scaledPoint.z);
        
        // Check bounds
        if (ix < BatchInstance_MIN_INDEX || ix > BatchInstance_MAX_INDEX
            || iy < BatchInstance_MIN_INDEX || iy > BatchInstance_MAX_INDEX
            || iz < BatchInstance_MIN_INDEX || iz > BatchInstance_MAX_INDEX)
        {
            throw new InvalidParamsError(
                "Point out of bounds",
                "InstancedGeometry.getBatchInstanceIndexes");
        }
        // Adjust for the fact that we use unsigned values for simplicity
        // (requires less faffing about for negatives give 10-bit packing
        x = cast(ushort)(ix + BatchInstance_HALF_RANGE);
        y = cast(ushort)(iy + BatchInstance_HALF_RANGE);
        z = cast(ushort)(iz + BatchInstance_HALF_RANGE);
    }

    /** get the first BatchInstance or create on if it does not exists.
     */
    ref BatchInstance getInstancedGeometryInstance()
    {
        if (!mInstancedGeometryInstance)
        {
            uint index = 0;
            // Make a name
            string str = std.conv.text(mName, ":", index);
            
            mInstancedGeometryInstance = new BatchInstance(this, str, mOwner, index);
            mOwner.injectMovableObject(mInstancedGeometryInstance);
            mInstancedGeometryInstance.setVisible(mVisible);
            mInstancedGeometryInstance.setCastShadows(mCastShadows);
            if (mRenderQueueIDSet)
            {
                mInstancedGeometryInstance.setRenderQueueGroup(mRenderQueueID);
            }
            mBatchInstanceMap[index] = mInstancedGeometryInstance;
            
            
        }
        return mInstancedGeometryInstance;
    }
    /** Pack 3 indexes into a single index value
     */
    uint packIndex(ushort x, ushort y, ushort z)
    {
        return x + (y << 10) + (z << 20);
    }
    /** Get the volume intersection for an indexed BatchInstance with some bounds.
     */
    Real getVolumeIntersection(AxisAlignedBox box,  
                               ushort x, ushort y, ushort z)
    {
        // Get bounds of indexed BatchInstance
        AxisAlignedBox BatchInstanceBounds = getBatchInstanceBounds(x, y, z);
        AxisAlignedBox intersectBox = BatchInstanceBounds.intersection(box);
        // return a 'volume' which ignores zero dimensions
        // since we only use this for relative comparisons of the same bounds
        // this will still be internally consistent
        Vector3 boxdiff = box.getMaximum() - box.getMinimum();
        Vector3 intersectDiff = intersectBox.getMaximum() - intersectBox.getMinimum();
        
        return (boxdiff.x == 0 ? 1 : intersectDiff.x) *
            (boxdiff.y == 0 ? 1 : intersectDiff.y) *
                (boxdiff.z == 0 ? 1 : intersectDiff.z);
    }
    /** Get the bounds of an indexed BatchInstance.
     */
    AxisAlignedBox getBatchInstanceBounds(ushort x, ushort y, ushort z)
    {
        auto min = Vector3(
            (cast(Real)x - BatchInstance_HALF_RANGE) * mBatchInstanceDimensions.x + mOrigin.x,
            (cast(Real)y - BatchInstance_HALF_RANGE) * mBatchInstanceDimensions.y + mOrigin.y,
            (cast(Real)z - BatchInstance_HALF_RANGE) * mBatchInstanceDimensions.z + mOrigin.z
            );
        Vector3 max = min + mBatchInstanceDimensions;
        return AxisAlignedBox(min, max);
    }
    /** Get the centre of an indexed BatchInstance.
     */
    Vector3 getBatchInstanceCentre(ushort x, ushort y, ushort z)
    {
        return Vector3(
            (cast(Real)x - BatchInstance_HALF_RANGE) * mBatchInstanceDimensions.x + mOrigin.x
            + mHalfBatchInstanceDimensions.x,
            (cast(Real)y - BatchInstance_HALF_RANGE) * mBatchInstanceDimensions.y + mOrigin.y
            + mHalfBatchInstanceDimensions.y,
            (cast(Real)z - BatchInstance_HALF_RANGE) * mBatchInstanceDimensions.z + mOrigin.z
            + mHalfBatchInstanceDimensions.z
            );
    }
    /** Calculate world bounds from a set of vertex data. */
    AxisAlignedBox calculateBounds(ref VertexData vertexData, 
                                   ref Vector3 position, ref Quaternion orientation, 
                                   ref Vector3 scale)
    {
        VertexElement posElem =
            vertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
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
    ref SubMeshLodGeometryLinkList determineGeometry(ref SubMesh sm)
    {
        // First, determine if we've already seen this submesh before
        auto i = sm in mSubMeshGeometryLookup;
        if (i !is null)
        {
            return mSubMeshGeometryLookup[sm];
        }

        mSubMeshGeometryLookup[sm] = null;
        // Otherwise, we have to create a new one
        SubMeshLodGeometryLinkList* lodList = &mSubMeshGeometryLookup[sm];

        ushort numLods = sm.parent.isLodManual() ? 1 : sm.parent.getNumLodLevels();
        //lodList.resize(numLods); //TODO std::vector resize

        for (ushort lod = 0; lod < numLods; ++lod)
        {
            //SubMeshLodGeometryLink& geomLink = (*lodList)[lod];
            SubMeshLodGeometryLink geomLink;
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
                    splitGeometry(sm.vertexData,
                                  lodIndexData, geomLink);
                }
            }
            assert (geomLink.vertexData.vertexStart == 0,
                    "Cannot use vertexStart > 0 on indexed geometry due to " ~
                    "rendersystem incompatibilities - see the docs!");
            (*lodList).insert(geomLink);
        }
        
        
        return mSubMeshGeometryLookup[sm];
    }
    /** Split some shared geometry into dedicated geometry. */
    void splitGeometry(ref VertexData vd, ref IndexData id, 
                       ref SubMeshLodGeometryLink targetGeomLink)
    {
        // Firstly we need to scan to see how many vertices are being used
        // and while we're at it, build the remap we can use later
        bool use32bitIndexes = id.indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_32BIT;
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
        
        size_t numvbufs = vd.vertexBufferBinding.getBufferCount();
        // Copy buffers from old to new
        for (ushort b = 0; b < numvbufs; ++b)
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
                id.indexStart, id.indexCount * id.indexBuffer.get().getIndexSize(), 
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
                id.indexStart, id.indexCount * id.indexBuffer.get().getIndexSize(), 
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
    void buildIndexRemap(T)(T* pBuffer, size_t numIndexes, ref IndexRemap remap)
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
    void remapIndexes(T)(T* src, T* dst, ref IndexRemap remap, 
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
    /// Constructor; do not use directly (@see SceneManager::createInstancedGeometry)
    this(ref SceneManager owner,string name)
    {
        mOwner = owner;
        mName = name;
        mBuilt = false;
        mUpperDistance = 0.0f;
        mSquaredUpperDistance = 0.0f;
        mCastShadows = false;
        mBatchInstanceDimensions = Vector3(1000,1000,1000);
        mHalfBatchInstanceDimensions = Vector3(500,500,500);
        mOrigin = Vector3(0,0,0);
        mVisible = true;
        mProvideWorldInverses = false;
        mRenderQueueID = RenderQueueGroupID.RENDER_QUEUE_MAIN;
        mRenderQueueIDSet = false;
        mObjectCount = 0;
        mInstancedGeometryInstance = null;
        mSkeletonInstance = null;
        mBaseSkeleton.setNull();
    }
    /// Destructor
    ~this()
    {
        reset();
        if(mSkeletonInstance)
            destroy(mSkeletonInstance);
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
     this InstancedGeometry if you like. The Entity passed in is simply 
     used as a definition.
     @note Must be called before 'build'.
     @note All added entities must use the same lod strategy.
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
                "WARNING (InstancedGeometry): Manual LOD is not supported. " ~
                "Using only highest LOD level for mesh " ~ msh.getAs().getName());
        }
        
        //get the skeleton of the entity, if that's not already done
        if(!ent.getMesh().getAs().getSkeleton().isNull()&&mBaseSkeleton.isNull())
        {
            mBaseSkeleton = ent.getMesh().getAs().getSkeleton();
            mSkeletonInstance = new SkeletonInstance(mBaseSkeleton);
            mSkeletonInstance.load();
            mAnimationState = ent.getAllAnimationStates();
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
            q.ID = mObjectCount;
            // Determine the bounds based on the highest LOD
            q.worldBounds = calculateBounds(
                q.geometryLodList[0].vertexData,
                position, orientation, scale);
            
            mQueuedSubMeshes.insert(q);
        }
        mObjectCount++;
        
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
     @note All added entities must use the same lod strategy.
     @param node Pointer to the node to use to provide a set of Entity 
     templates
     */
    void addSceneNode(SceneNode node)
    {
        auto obji = node.getAttachedObjects();
        foreach(mobj; obji)
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
        foreach(node; node.getChildren())
        {
            SceneNode newNode = cast(SceneNode)(node);
            // Add this subnode and its children...
            addSceneNode( newNode );
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
        
        // Firstly allocate meshes to BatchInstances
        foreach (qsm; mQueuedSubMeshes)
        {
            //BatchInstance* BatchInstance = getBatchInstance(qsm.worldBounds, true);
            BatchInstance batchInstance = getInstancedGeometryInstance();
            batchInstance.assign(qsm);
        }
        
        // Now tell each BatchInstance to build itself
        foreach (k,v; mBatchInstanceMap)
        {
            v.build();
        }
    }
    /** Add a new batch instance
     @remarks
     This method add a new instance of the whole batch, by creating a new 
     BatchInstance, containing new lod buckets, material buckets and geometry buckets.
     The new geometry buckets will use the same buffers as the base bucket.
     @note
     no note
     */
    void addBatchInstance()
    {
        //BatchInstanceIterator regIt = getBatchInstanceIterator(); //mBatchInstanceMap
        BatchInstance lastBatchInstance = null;
        foreach(_,b; mBatchInstanceMap)
        {
            lastBatchInstance = b;
        }
        
        if(!lastBatchInstance)
            throw new ItemNotFoundError("No batch instance found",
                                        "InstancedGeometry.addBatchInstance");
        
        uint index = (lastBatchInstance) ? lastBatchInstance.getID()+1 : 0;
        //create a new BatchInstance
        
        BatchInstance ret = new BatchInstance(this, std.conv.text(mName, ":", index),
                                              mOwner, index);
        
        ret.attachToScene();
        
        mOwner.injectMovableObject(ret);
        ret.setVisible(mVisible);
        ret.setCastShadows(mCastShadows);
        mBatchInstanceMap[index] = ret;
        
        if (mRenderQueueIDSet)
        {
            ret.setRenderQueueGroup(mRenderQueueID);
        }
        
        size_t numLod = lastBatchInstance.mLodValues.length;
        //ret.mLodValues.resize(numLod); //XXX std::vector resize
        ret.mLodValues.length = numLod;
        for (ushort lod = 0; lod < numLod; lod++)
        {
            ret.mLodValues[lod] =
                lastBatchInstance.mLodValues[lod];
        }
        
        
        
        // update bounds
        auto box = AxisAlignedBox(lastBatchInstance.mAABB.getMinimum(), lastBatchInstance.mAABB.getMaximum());
        ret.mAABB.merge(box);
        
        ret.mBoundingRadius = lastBatchInstance.mBoundingRadius ;
        //now create  news instanced objects
        //InstancedObject obj;
        foreach(k, obj; lastBatchInstance.getInstancesMap())
        {
            InstancedObject instancedObject = ret.isInstancedObjectPresent(k);
            if(instancedObject is null)
            {
                if(mBaseSkeleton.isNull())
                {
                    instancedObject = new InstancedObject(k);
                }
                else
                {
                    instancedObject = new InstancedObject(k, mSkeletonInstance, mAnimationState);
                }
                ret.addInstancedObject(k, instancedObject);
            }
            
        }
        
        
        
        //BatchInstance::LODIterator lodIterator = lastBatchInstance.getLODIterator();
        auto lods = lastBatchInstance.getLODBucketList();
        //parse all the lod buckets of the BatchInstance
        foreach(lod; lods)
        {
            //create a new lod bucket for the new BatchInstance
            LODBucket lodBucket= new LODBucket(ret, lod.getLod(), lod.getLodValue());
            
            //add the lod bucket to the BatchInstance list
            ret.updateContainers(lodBucket);

            //parse all the material buckets of the lod bucket
            foreach(k, mat; lod.getMaterialBucketMap())
            {
                //create a new material bucket
                string materialName = mat.getMaterialName();
                MaterialBucket matBucket = new MaterialBucket(lodBucket, materialName);
                
                //add the material bucket to the lod buckets list and map
                lodBucket.updateContainers(matBucket, materialName);

                //parse all the geometry buckets of the material bucket
                foreach(geom; mat.getGeometryBucketList())
                {
                    //create a new geometry bucket 
                    GeometryBucket geomBucket = new GeometryBucket(matBucket, geom.getFormatString(), geom);
                    
                    //update the material bucket map of the material bucket
                    matBucket.updateContainers(geomBucket, geomBucket.getFormatString());
                    
                    //copy bounding informations
                    geomBucket.getAABB() = geom.getAABB();//TODO Unless dmd ctfe-d in tests, this seems to work
                    geomBucket.setBoundingBox( geom.getBoundingBox());
                    //now setups the news InstancedObjects.
                    foreach(k,obj; ret.getInstancesMap())
                    {
                        //get the destination IntanciedObject
                        //InstancedObject*obj=objIt.second;

                        //check if the bucket is not already in the list
                        auto findIt = std.algorithm.find(obj.getGeometryBucketList(), geomBucket);
                        if(findIt.empty)
                            obj.addBucketToList(geomBucket);
                    }
                    
                    
                }   
            }
        }
    }
    /** Destroys all the built geometry state (reverse of build). 
     @remarks
     You can call build() again after this and it will pick up all the
     same entities / nodes you queued last time.
     */
    void _destroy()
    {
        foreach(it; mRenderOps)
        {
            destroy(it.vertexData);
            destroy(it.indexData);
        }

        mRenderOps.clear();
        
        // delete the BatchInstances
        foreach (k, ref v; mBatchInstanceMap)
        {
            mOwner.extractMovableObject(v);
            destroy(v);
        }
        mBatchInstanceMap.clear();
        mInstancedGeometryInstance = null;
    }
    
    /** Clears any of the entities / nodes added to this geometry and 
     destroys anything which has already been built.
     */
    void reset()
    {
        _destroy();
        
        foreach (i; mQueuedSubMeshes)
        {
            destroy(i);
        }
        mQueuedSubMeshes.clear();
        // Delete precached geoemtry lists
        foreach (l; mSubMeshGeometryLookup)
        {
            destroy(l);
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
        // tell any existing BatchInstances
        foreach (k,v; mBatchInstanceMap)
        {
            v.setVisible(visible);
        }
    }
    
    /** Are the batches visible? */
    bool isVisible(){ return mVisible; }
    
    /** Sets whether this geometry should cast shadows.
     @remarks
     No matter what the settings on the original entities,
     the InstancedGeometry class defaults to not casting shadows. 
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
        // tell any existing BatchInstances
        foreach (k,v; mBatchInstanceMap)
        {
            v.setCastShadows(castShadows);
        }
    }
    /// Will the geometry from this object cast shadows?
    bool getCastShadows() { return mCastShadows; }
    
    /** Sets the size of a single BatchInstance of geometry.
     @remarks
     This method allows you to configure the physical world size of 
     each BatchInstance, so you can balance culling against batch size. Entities
     will be fitted within the batch they most closely fit, and the 
     eventual bounds of each batch may well be slightly larger than this
     if they overlap a little. The default is Vector3(1000, 1000, 1000).
     @note Must be called before 'build'.
     @param size Vector3 expressing the 3D size of each BatchInstance.
     */
    void setBatchInstanceDimensions(Vector3 size) { 
        mBatchInstanceDimensions = size; 
        mHalfBatchInstanceDimensions = size * 0.5;
    }
    /** Gets the size of a single batch of geometry. */
    Vector3 getBatchInstanceDimensions(){ return mBatchInstanceDimensions; }
    /** Sets the origin of the geometry.
     @remarks
     This method allows you to configure the world centre of the geometry,
     thus the place which all BatchInstances surround. You probably don't need 
     to mess with this unless you have a seriously large world, since the
     default set up can handle an area 1024 * mBatchInstanceDimensions, and 
     the sparseness of population is no issue when it comes to rendering.
     The default is Vector3(0,0,0).
     @note Must be called before 'build'.
     @param origin Vector3 expressing the 3D origin of the geometry.
     */
    void setOrigin(Vector3 origin) { mOrigin = origin; }
    /** Gets the origin of this geometry. */
    Vector3 getOrigin(){ return mOrigin; }
    
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
        // tell any existing BatchInstances
        foreach (k,v; mBatchInstanceMap)
        {
            v.setRenderQueueGroup(queueID);
        }
    }
    
    /** Gets the queue group for this entity, see setRenderQueueGroup for full details. */
    ubyte getRenderQueueGroup()
    {
        return mRenderQueueID;
    }
    /// Iterator for iterating over contained BatchInstances
    //typedef MapIterator<BatchInstanceMap> BatchInstanceIterator;
    /// Get an iterator over the BatchInstances in this geometry
    //BatchInstanceIterator getBatchInstanceIterator();

    BatchInstanceMap getBatchInstanceMap()
    {
        return mBatchInstanceMap;
    }

    /// get the mRenderOps vector.
    ref RenderOperationVector getRenderOperationVector() { return mRenderOps; }

    /// @copydoc MovableObject::visitRenderables
    void visitRenderables(Renderable.Visitor visitor, 
                          bool debugRenderables = false)
    {
        foreach (k,v; mBatchInstanceMap)
        {
            v.visitRenderables(visitor, debugRenderables);
        }
    }
    
    /** Dump the contents of this InstancedGeometry to a file for diagnostic
     purposes.
     */
    void dump(string filename)//TODO dump into a stream
    {
        //std::ofstream of(filename.c_str());
        auto log = new Log(filename, false, false);
        auto of = log.stream();

        of << "Static Geometry Report for " << mName << of.endl;
        of << "-------------------------------------------------" << of.endl;
        of << "Number of queued submeshes: " << mQueuedSubMeshes.length << of.endl;
        of << "Number of BatchInstances: " << mBatchInstanceMap.length << of.endl;
        of << "BatchInstance dimensions: " << mBatchInstanceDimensions << of.endl;
        of << "Origin: " << mOrigin << of.endl;
        of << "Max distance: " << mUpperDistance << of.endl;
        of << "Casts shadows?: " << mCastShadows << of.endl;
        of << of.endl;
        foreach (k,v; mBatchInstanceMap)
        {
            v.dump(of);
        }
        of << "-------------------------------------------------" << of.Flush();

        //Explicitly flush stream first, then get rid of Log.
        destroy(of);
        destroy(log);
    }
    /**
     @remarks
     Return the skeletonInstance that will be used 
     */
    ref SkeletonInstance getBaseSkeletonInstance(){return mSkeletonInstance;}
    /**
     @remarks
     Return the skeleton that is shared by all instanced objects.
     */
    SharedPtr!Skeleton getBaseSkeleton(){return mBaseSkeleton;}
    /**
     @remarks
     Return the animation state that will be cloned each time an InstancedObject is made
     */
    ref AnimationStateSet getBaseAnimationState(){return mAnimationState;}
    /**
     @remarks
     return the total number of object that are in all the batches
     */
    uint getObjectCount(){return mObjectCount;}
    
    /**
     @remarks
     Allows World Transform Inverse matrices to be passed as shader constants along with the world
     transform matrix list. Reduces the number of usable geometries in an instance to 40 instead of 80.
     The inverse matrices are interleaved with the world matrices at n+1.
     */
    void setProvideWorldInverses(bool flag)
    {
        mProvideWorldInverses = flag;
    }
    
    /**
     @remarks
     Returns the toggle state indicating whether the World Transform INVERSE matrices would
     be passed to the shaders.
     */
    bool getProvideWorldInverses(){ return mProvideWorldInverses; }
}

/** @} */
/** @} */