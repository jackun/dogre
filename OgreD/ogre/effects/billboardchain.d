module ogre.effects.billboardchain;

//import std.container;

import ogre.scene.movableobject;
import ogre.scene.renderable;
import ogre.compat;
import ogre.general.colourvalue;
import ogre.math.quaternion;
import ogre.math.axisalignedbox;
import ogre.materials.material;
import ogre.scene.camera;
import ogre.rendersystem.vertex;
import ogre.rendersystem.renderoperation;
import ogre.rendersystem.viewport;
import ogre.math.matrix;
import ogre.resources.resourcegroupmanager;
import ogre.rendersystem.renderqueue;
import ogre.materials.materialmanager;
import ogre.general.log;
import ogre.rendersystem.hardware;
import ogre.general.root;
import ogre.math.angles;
import ogre.math.maths;
public import ogre.sharedptr;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Effects
 *  @{
 */

/** Allows the rendering of a chain of connected billboards.
 @remarks
 A billboard chain operates much like a traditional billboard, i.e. its
 segments always face the camera; the difference being that instead of
 a set of disconnected quads, the elements in this class are connected
 together in a chain which must always stay in a continuous strip. This
 kind of effect is useful for creating effects such as trails, beams,
 lightning effects, etc.
 @par
 A single instance of this class can actually render multiple separate
 chain segments in a single render operation, provided they all use the
 same material. To clarify the terminology: a 'segment' is a separate 
 sub-part of the chain with its own start and end (called the 'head'
 and the 'tail'. An 'element' is a single position / colour / texcoord
 entry in a segment. You can add items to the head of a chain, and 
 remove them from the tail, very efficiently. Each segment has a max
 size, and if adding an element to the segment would exceed this size, 
 the tail element is automatically removed and re-used as the new item
 on the head.
 @par
 This class has no auto-updating features to do things like alter the
 colour of the elements or to automatically add / remove elements over
 time - you have to do all this yourself as a user of the class. 
 Subclasses can however be used to provide this kind of behaviour 
 automatically. @see RibbonTrail
 */
class BillboardChain : MovableObject, Renderable
{
    mixin Renderable.Renderable_Impl;
    mixin Renderable.Renderable_Any_Impl;

public:
    
    /** Contains the data of an element of the BillboardChain.
     */
    class Element
    {
        
    public:
        
        this() {}
        
        this(Vector3 _position,
             Real _width,
             Real _texCoord,
             ColourValue _colour,
             Quaternion _orientation)
        {
            position = _position;
            width = _width;
            texCoord = _texCoord;
            colour = _colour;
            orientation = _orientation;
        }
        
        Vector3 position;
        Real width;
        /// U or V texture coord depending on options
        Real texCoord;
        ColourValue colour;
        
        //Only used when mFaceCamera == false
        Quaternion orientation;
    }
    //typedef vector<Element>::type ElementList;
    alias Element[] ElementList;
    
    /** Constructor (don't use directly, use factory) 
     @param name The name to give this object
     @param maxElements The maximum number of elements per chain
     @param numberOfChains The number of separate chain segments contained in this object
     @param useTextureCoords If true, use texture coordinates from the chain elements
     @param useVertexColours If true, use vertex colours from the chain elements
     @param dynamic If true, buffers are created with the intention of being updated
     */
    this(string name, size_t maxElements = 20, size_t numberOfChains = 1, 
         bool useTextureCoords = true, bool useColours = true, bool dynamic = true)
    {
        super(name);
        mMaxElementsPerChain = maxElements;
        mChainCount = numberOfChains;
        mUseTexCoords = useTextureCoords;
        mUseVertexColour = useColours;
        mDynamic = dynamic;
        mVertexDeclDirty = true;
        mBuffersNeedRecreating = true;
        mBoundsDirty = true;
        mIndexContentDirty = true;
        mVertexContentDirty = true;
        mRadius = 0.0f;
        mTexCoordDir = TexCoordDirection.TCD_U;
        //mVertexCameraUsed = null;
        mFaceCamera = true;
        mNormalBase = Vector3.UNIT_X;

        mVertexData = new VertexData();
        mIndexData = new IndexData();
        
        mOtherTexCoordRange[0] = 0.0f;
        mOtherTexCoordRange[1] = 1.0f;
        
        setupChainContainers();
        
        mVertexData.vertexStart = 0;
        // index data set up later
        // set basic white material
        this.setMaterialName("BaseWhiteNoLighting");
        
    }

    /// destructor
    ~this()
    {
        destroy(mVertexData);
        destroy(mIndexData);
    }
    
    /** Set the maximum number of chain elements per chain 
     */
    void setMaxChainElements(size_t maxElements)
    {
        mMaxElementsPerChain = maxElements;
        setupChainContainers();
        mBuffersNeedRecreating = mIndexContentDirty = mVertexContentDirty = true;
    }
    /** Get the maximum number of chain elements per chain 
     */
    size_t getMaxChainElements(){ return mMaxElementsPerChain; }
    /** Set the number of chain segments (this class can render multiple chains
     at once using the same material). 
     */
    void setNumberOfChains(size_t numChains)
    {
        mChainCount = numChains;
        setupChainContainers();
        mBuffersNeedRecreating = mIndexContentDirty = mVertexContentDirty = true;
    }
    /** Get the number of chain segments (this class can render multiple chains
     at once using the same material). 
     */
    size_t getNumberOfChains(){ return mChainCount; }
    
    /** Sets whether texture coordinate information should be included in the
     final buffers generated.
     @note You must use either texture coordinates or vertex colour since the
     vertices have no normals and without one of these there is no source of
     colour for the vertices.
     */
    void setUseTextureCoords(bool use)
    {
        mUseTexCoords = use;
        mVertexDeclDirty = mBuffersNeedRecreating = true;
        mIndexContentDirty = mVertexContentDirty = true;
    }
    /** Gets whether texture coordinate information should be included in the
     final buffers generated.
     */
    bool getUseTextureCoords(){ return mUseTexCoords; }
    
    /** The direction in which texture coordinates from elements of the
     chain are used.
     */
    enum TexCoordDirection
    {
        /// Tex coord in elements is treated as the 'u' texture coordinate
        TCD_U,
        /// Tex coord in elements is treated as the 'v' texture coordinate
        TCD_V
    }
    /** Sets the direction in which texture coords specified on each element
     are deemed to run along the length of the chain.
     @param dir The direction, default is TCD_U.
     */
    void setTextureCoordDirection(TexCoordDirection dir)
    {
        mTexCoordDir = dir;
        mVertexContentDirty = true;
    }
    /** Gets the direction in which texture coords specified on each element
     are deemed to run.
     */
    TexCoordDirection getTextureCoordDirection() { return mTexCoordDir; }
    
    /** Set the range of the texture coordinates generated across the width of
     the chain elements.
     @param start Start coordinate, default 0.0
     @param end End coordinate, default 1.0
     */
    void setOtherTextureCoordRange(Real start, Real end)
    {
        mOtherTexCoordRange[0] = start;
        mOtherTexCoordRange[1] = end;
        mVertexContentDirty = true;
    }
    /** Get the range of the texture coordinates generated across the width of
     the chain elements.
     */
    Real[] getOtherTextureCoordRange(){ return mOtherTexCoordRange; }
    
    /** Sets whether vertex colour information should be included in the
     final buffers generated.
     @note You must use either texture coordinates or vertex colour since the
     vertices have no normals and without one of these there is no source of
     colour for the vertices.
     */
    void setUseVertexColours(bool use)
    {
        mUseVertexColour = use;
        mVertexDeclDirty = mBuffersNeedRecreating = true;
        mIndexContentDirty = mVertexContentDirty = true;
    }
    /** Gets whether vertex colour information should be included in the
     final buffers generated.
     */
    bool getUseVertexColours(){ return mUseVertexColour; }
    
    /** Sets whether or not the buffers created for this object are suitable
     for dynamic alteration.
     */
    void setDynamic(bool dyn)
    {
        mDynamic = dyn;
        mBuffersNeedRecreating = mIndexContentDirty = mVertexContentDirty = true;
    }
    
    /** Gets whether or not the buffers created for this object are suitable
     for dynamic alteration.
     */
    bool getDynamic(){ return mDynamic; }
    
    /** Add an element to the 'head' of a chain.
     @remarks
     If this causes the number of elements to exceed the maximum elements
     per chain, the last element in the chain (the 'tail') will be removed
     to allow the additional element to be added.
     @param chainIndex The index of the chain
     @param billboardChainElement The details to add
     */
    void addChainElement(size_t chainIndex, 
                         ref Element billboardChainElement)
    {
        
        if (chainIndex >= mChainCount)
        {
            throw new ItemNotFoundError(
                "chainIndex out of bounds",
                "BillboardChain.addChainElement");
        }
        ChainSegment *seg = &mChainSegmentList[chainIndex];
        if (seg.head == SEGMENT_EMPTY)
        {
            // Tail starts at end, head grows backwards
            seg.tail = mMaxElementsPerChain - 1;
            seg.head = seg.tail;
        }
        else
        {
            if (seg.head == 0)
            {
                // Wrap backwards
                seg.head = mMaxElementsPerChain - 1;
            }
            else
            {
                // Just step backward
                --seg.head;
            }
            // Run out of elements?
            if (seg.head == seg.tail)
            {
                // Move tail backwards too, losing the end of the segment and re-using
                // it in the head
                if (seg.tail == 0)
                    seg.tail = mMaxElementsPerChain - 1;
                else
                    --seg.tail;
            }
        }
        
        // Set the details
        mChainElementList[seg.start + seg.head] = billboardChainElement;
        
        mVertexContentDirty = true;
        mIndexContentDirty = true;
        mBoundsDirty = true;
        // tell parent node to update bounds
        if (mParentNode)
            mParentNode.needUpdate();
        
    }

    /** Remove an element from the 'tail' of a chain.
     @param chainIndex The index of the chain
     */
    void removeChainElement(size_t chainIndex)
    {
        if (chainIndex >= mChainCount)
        {
            throw new ItemNotFoundError(
                "chainIndex out of bounds",
                "BillboardChain.removeChainElement");
        }
        ChainSegment* seg = &mChainSegmentList[chainIndex];
        if (seg.head == SEGMENT_EMPTY)
            return; // do nothing, nothing to remove
        
        
        if (seg.tail == seg.head)
        {
            // last item
            seg.head = seg.tail = SEGMENT_EMPTY;
        }
        else if (seg.tail == 0)
        {
            seg.tail = mMaxElementsPerChain - 1;
        }
        else
        {
            --seg.tail;
        }
        
        // we removed an entry so indexes need updating
        mVertexContentDirty = true;
        mIndexContentDirty = true;
        mBoundsDirty = true;
        // tell parent node to update bounds
        if (mParentNode)
            mParentNode.needUpdate();
        
    }
    /** Update the details of an existing chain element.
     @param chainIndex The index of the chain
     @param elementIndex The element index within the chain, measured from 
     the 'head' of the chain
     @param billboardChainElement The details to set
     */
    void updateChainElement(size_t chainIndex, size_t elementIndex, 
                            ref Element billboardChainElement)
    {
        if (chainIndex >= mChainCount)
        {
            throw new ItemNotFoundError(
                "chainIndex out of bounds",
                "BillboardChain.updateChainElement");
        }
        ChainSegment* seg = &mChainSegmentList[chainIndex];
        if (seg.head == SEGMENT_EMPTY)
        {
            throw new ItemNotFoundError(
                "Chain segment is empty",
                "BillboardChain.updateChainElement");
        }
        
        size_t idx = seg.head + elementIndex;
        // adjust for the edge and start
        idx = (idx % mMaxElementsPerChain) + seg.start;
        
        mChainElementList[idx] = billboardChainElement;
        
        mVertexContentDirty = true;
        mBoundsDirty = true;
        // tell parent node to update bounds
        if (mParentNode)
            mParentNode.needUpdate();
        
        
    }
    /** Get the detail of a chain element.
     @param chainIndex The index of the chain
     @param elementIndex The element index within the chain, measured from
     the 'head' of the chain
     */
    ref Element getChainElement(size_t chainIndex, size_t elementIndex)
    {
        
        if (chainIndex >= mChainCount)
        {
            throw new ItemNotFoundError(
                "chainIndex out of bounds",
                "BillboardChain.getChainElement");
        }
        ChainSegment* seg = &mChainSegmentList[chainIndex];
        
        size_t idx = seg.head + elementIndex;
        // adjust for the edge and start
        idx = (idx % mMaxElementsPerChain) + seg.start;
        
        return mChainElementList[idx];
    }
    
    /** Returns the number of chain elements. */
    size_t getNumChainElements(size_t chainIndex)
    {
        if (chainIndex >= mChainCount)
        {
            throw new ItemNotFoundError(
                "chainIndex out of bounds",
                "BillboardChain.getNumChainElements");
        }
        ChainSegment* seg = &mChainSegmentList[chainIndex];
        
        if( seg.tail < seg.head )
        {
            return seg.tail - seg.head + mMaxElementsPerChain + 1;
        }
        else
        {
            return seg.tail - seg.head + 1;
        }
    }
    
    /** Remove all elements of a given chain (but leave the chain intact). */
    void clearChain(size_t chainIndex)
    {
        if (chainIndex >= mChainCount)
        {
            throw new ItemNotFoundError(
                "chainIndex out of bounds",
                "BillboardChain.clearChain");
        }
        ChainSegment* seg = &mChainSegmentList[chainIndex];
        
        // Just reset head & tail
        seg.tail = seg.head = SEGMENT_EMPTY;
        
        // we removed an entry so indexes need updating
        mVertexContentDirty = true;
        mIndexContentDirty = true;
        mBoundsDirty = true;
        // tell parent node to update bounds
        if (mParentNode)
            mParentNode.needUpdate();
        
    }

    /** Remove all elements from all chains (but leave the chains themselves intact). */
    void clearAllChains()
    {
        foreach (i; 0..mChainCount)
        {
            clearChain(i);
        }
    }
    
    /** Sets whether the billboard should always be facing the camera or a custom direction
     set by each point element.
     @remarks
     Billboards facing the camera are useful for smoke trails, light beams, etc by
     simulating a cylinder. However, because of this property, wide trails can cause
     several artefacts unless the head is properly covered.
     Therefore, non-camera-facing billboards are much more convenient for leaving big
     trails of movement from thin objects, for example a sword swing as seen in many
     fighting games.
     @param faceCamera True to be always facing the camera (Default value: True)
     @param normalVector Only used when faceCamera == false. Must be a non-zero vector.
     This vector is the "point of reference" for each point orientation. For example,
     if normalVector is Vector3::UNIT_Z, and the point's orientation is an identity
     matrix, the segment corresponding to that point will be facing towards UNIT_Z
     This vector is internally normalized.
     */
    void setFaceCamera( bool faceCamera,Vector3 normalVector=Vector3.UNIT_X )
    {
        mFaceCamera = faceCamera;
        mNormalBase = normalVector.normalisedCopy();
        mVertexContentDirty = true;
    }
    
    /// Get the material name in use
    string getMaterialName(){ return mMaterialName; }
    /// Set the material name to use for rendering
    void setMaterialName(string name,string groupName = ResourceGroupManager.AUTODETECT_RESOURCE_GROUP_NAME )
    {
        mMaterialName = name;
        mMaterial = MaterialManager.getSingleton().getByName(mMaterialName, groupName);
        
        if (mMaterial.isNull())
        {
            LogManager.getSingleton().logMessage("Can't assign material " ~ name ~
                                                 " to BillboardChain " ~ mName ~ " because this " ~
                                                 "Material does not exist. Have you forgotten to define it in a " ~
                                                 ".material script?");
            mMaterial = MaterialManager.getSingleton().getByName("BaseWhiteNoLighting");
            if (mMaterial.isNull())
            {
                throw new InternalError("Can't assign default material " ~
                                        "to BillboardChain of " ~ mName ~ ". Did " ~
                                        "you forget to call MaterialManager.initialise()?",
                                        "BillboardChain.setMaterialName");
            }
        }
        // Ensure new material loaded (will not load again if already loaded)
        mMaterial.getAs().load();
    }
    
    // Overridden members follow
    override Real getSquaredViewDepth(Camera cam)
    {
        Vector3 min, max, mid, dist;
        min = mAABB.getMinimum();
        max = mAABB.getMaximum();
        mid = ((max - min) * 0.5) + min;
        dist = cam.getDerivedPosition() - mid;
        
        return dist.squaredLength();
    }

    override Real getBoundingRadius()
    {
        return mRadius;
    }

    override AxisAlignedBox getBoundingBox()
    {
        updateBoundingBox();
        return mAABB;
    }

    override SharedPtr!Material getMaterial()
    {
        return mMaterial;
    }

    override string getMovableType()
    {
        return BillboardChainFactory.FACTORY_TYPE_NAME;
    }

    override void _updateRenderQueue(RenderQueue queue)
    {
        updateIndexBuffer();
        
        if (mIndexData.indexCount > 0)
        {
            if (mRenderQueuePrioritySet)
                queue.addRenderable(this, mRenderQueueID, mRenderQueuePriority);
            else if (mRenderQueueIDSet)
                queue.addRenderable(this, mRenderQueueID);
            else
                queue.addRenderable(this);
        }
        
    }

    override void getRenderOperation(ref RenderOperation op)
    {
        op.indexData = mIndexData;
        op.operationType = RenderOperation.OperationType.OT_TRIANGLE_LIST;
        op.srcRenderable = this;
        op.useIndexes = true;
        op.vertexData = mVertexData;
    }

    override bool preRender(SceneManager sm, RenderSystem rsys)
    {
        // Retrieve the current viewport from the scene manager.
        // The viewport is only valid during a viewport update.
        Viewport currentViewport = sm.getCurrentViewport();
        if( !currentViewport )
            return false;
        
        updateVertexBuffer(currentViewport.getCamera());
        return true;
    }

    void getWorldTransforms(ref Matrix4[] xform)
    {
        xform.insertOrReplace(_getParentNodeFullTransform());
    }

    override LightList getLights()
    {
        return queryLights();
    }

    /// @copydoc MovableObject::visitRenderables
    override void visitRenderables(Renderable.Visitor visitor, 
                                   bool debugRenderables = false)
    {
        // only one renderable
        visitor.visit(this, 0, false);
    }
    
    
    
protected:
    
    /// Maximum length of each chain
    size_t mMaxElementsPerChain;
    /// Number of chains
    size_t mChainCount;
    /// Use texture coords?
    bool mUseTexCoords;
    /// Use vertex colour?
    bool mUseVertexColour;
    /// Dynamic use?
    bool mDynamic;
    /// Vertex data
    VertexData mVertexData;
    /// Index data (to allow multiple unconnected chains)
    IndexData mIndexData;
    /// Is the vertex declaration dirty?
    bool mVertexDeclDirty;
    /// Do the buffers need recreating?
    bool mBuffersNeedRecreating;
    /// Do the bounds need redefining?
    //mutable 
    bool mBoundsDirty;
    /// Is the index buffer dirty?
    bool mIndexContentDirty;
    /// Is the vertex buffer dirty?
    bool mVertexContentDirty;
    /// AABB
    //mutable 
    AxisAlignedBox mAABB;
    /// Bounding radius
    //mutable 
    Real mRadius;
    /// Material 
    string mMaterialName;
    SharedPtr!Material mMaterial;
    /// Texture coord direction
    TexCoordDirection mTexCoordDir;
    /// Other texture coord range
    Real[2] mOtherTexCoordRange;
    /// Camera last used to build the vertex buffer
    Camera mVertexCameraUsed;
    /// When true, the billboards always face the camera
    bool mFaceCamera;
    /// Used when mFaceCamera == false; determines the billboard's "normal". i.e.
    /// when the orientation is identity, the billboard is perpendicular to this
    /// vector
    Vector3 mNormalBase;
    
    
    /// The list holding the chain elements
    ElementList mChainElementList;
    
    /** Simple struct defining a chain segment by ref erencing a subset of
     the preallocated buffer (which will be mMaxElementsPerChain * mChainCount
     long), by it's chain index, and a head and tail value which describe
     the current chain. The buffer subset wraps at mMaxElementsPerChain
     so that head and tail can move freely. head and tail are inclusive,
     when the chain is empty head and tail are filled with high-values.
     */
    struct ChainSegment
    {
        /// The start of this chains subset of the buffer
        size_t start;
        /// The 'head' of the chain, relative to start
        size_t head;
        /// The 'tail' of the chain, relative to start
        size_t tail;
    }
    //typedef vector<ChainSegment>::type ChainSegmentList;
    alias ChainSegment[] ChainSegmentList;
    ChainSegmentList mChainSegmentList;
    
    /// Setup the STL collections
    void setupChainContainers()
    {
        // Allocate enough space for everything
        mChainElementList.length = (mChainCount * mMaxElementsPerChain);
        mVertexData.vertexCount = mChainElementList.length * 2;
        
        // Configure chains
        mChainSegmentList.length = (mChainCount);
        for (size_t i = 0; i < mChainCount; ++i)
        {
            ChainSegment* seg = &mChainSegmentList[i];
            seg.start = i * mMaxElementsPerChain;
            seg.tail = seg.head = SEGMENT_EMPTY;   
        }
    }

    /// Setup vertex declaration
    void setupVertexDeclaration()
    {
        if (mVertexDeclDirty)
        {
            VertexDeclaration decl = mVertexData.vertexDeclaration;
            decl.removeAllElements();
            
            size_t offset = 0;
            // Add a description for the buffer of the positions of the vertices
            decl.addElement(0, offset, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_POSITION);
            offset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
            
            if (mUseVertexColour)
            {
                decl.addElement(0, offset, VertexElementType.VET_COLOUR, VertexElementSemantic.VES_DIFFUSE);
                offset += VertexElement.getTypeSize(VertexElementType.VET_COLOUR);
            }
            
            if (mUseTexCoords)
            {
                decl.addElement(0, offset, VertexElementType.VET_FLOAT2, VertexElementSemantic.VES_TEXTURE_COORDINATES);
            }
            
            if (!mUseTexCoords && !mUseVertexColour)
            {
                LogManager.getSingleton().logMessage(
                    "Error - BillboardChain '" ~ mName ~ "' is using neither " ~
                    "texture coordinates or vertex colours; it will not be " ~
                    "visible on some rendering APIs so you should change this " ~
                    "so you use one or the other.");
            }
            mVertexDeclDirty = false;
        }
    }

    // Setup buffers
    void setupBuffers()
    {
        setupVertexDeclaration();
        if (mBuffersNeedRecreating)
        {
            // Create the vertex buffer (always dynamic due to the camera adjust)
            SharedPtr!HardwareVertexBuffer pBuffer =
                HardwareBufferManager.getSingleton().createVertexBuffer(
                    mVertexData.vertexDeclaration.getVertexSize(0),
                    mVertexData.vertexCount,
                    HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY_DISCARDABLE);
            
            // (re)Bind the buffer
            // Any existing buffer will lose its reference count and be destroyed
            mVertexData.vertexBufferBinding.setBinding(0, pBuffer);
            
            mIndexData.indexBuffer =
                HardwareBufferManager.getSingleton().createIndexBuffer(
                    HardwareIndexBuffer.IndexType.IT_16BIT,
                    mChainCount * mMaxElementsPerChain * 6, // max we can use
                    mDynamic? HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY : HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY);
            // NB we don't set the indexCount on IndexData here since we will
            // probably use less than the maximum number of indices
            
            mBuffersNeedRecreating = false;
        }
    }

    /// Update the contents of the vertex buffer
    void updateVertexBuffer(Camera cam)
    {
        setupBuffers();
        
        // The contents of the vertex buffer are correct if they are not dirty
        // and the camera used to build the vertex buffer is still the current 
        // camera.
        if (!mVertexContentDirty && mVertexCameraUsed == cam)
            return;
        
        SharedPtr!HardwareVertexBuffer pBuffer =
            mVertexData.vertexBufferBinding.getBuffer(0);
        void* pBufferStart = pBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD);
        
        Vector3 camPos = cam.getDerivedPosition();
        Vector3 eyePos = mParentNode._getDerivedOrientation().Inverse() *
            (camPos - mParentNode._getDerivedPosition()) / mParentNode._getDerivedScale();
        
        Vector3 chainTangent;
        foreach (segi; 0..mChainSegmentList.length)
        {
            ChainSegment* seg = &mChainSegmentList[segi];
            
            // Skip 0 or 1 element segment counts
            if (seg.head != SEGMENT_EMPTY && seg.head != seg.tail)
            {
                size_t laste = seg.head;
                for (size_t e = seg.head; ; ++e) // until break
                {
                    // Wrap forwards
                    if (e == mMaxElementsPerChain)
                        e = 0;
                    
                    Element* elem = &mChainElementList[e + seg.start];
                    assert (((e + seg.start) * 2) < 65536, "Too many elements!");
                    ushort baseIdx = cast(ushort)((e + seg.start) * 2);
                    
                    // Determine base pointer to vertex #1
                    void* pBase = cast(void*)(
                        (cast(ubyte*)pBufferStart) +
                        pBuffer.get().getVertexSize() * baseIdx);
                    
                    // Get index of next item
                    size_t nexte = e + 1;
                    if (nexte == mMaxElementsPerChain)
                        nexte = 0;
                    
                    if (e == seg.head)
                    {
                        // No laste, use next item
                        chainTangent = mChainElementList[nexte + seg.start].position - elem.position;
                    }
                    else if (e == seg.tail)
                    {
                        // No nexte, use only last item
                        chainTangent = elem.position - mChainElementList[laste + seg.start].position;
                    }
                    else
                    {
                        // A mid position, use tangent across both prev and next
                        chainTangent = mChainElementList[nexte + seg.start].position - mChainElementList[laste + seg.start].position;
                        
                    }
                    
                    Vector3 vP1ToEye;
                    
                    if( mFaceCamera )
                        vP1ToEye = eyePos - elem.position;
                    else
                        vP1ToEye = elem.orientation * mNormalBase;
                    
                    Vector3 vPerpendicular = chainTangent.crossProduct(vP1ToEye);
                    vPerpendicular.normalise();
                    vPerpendicular *= (elem.width * 0.5f);
                    
                    Vector3 pos0 = elem.position - vPerpendicular;
                    Vector3 pos1 = elem.position + vPerpendicular;
                    
                    float* pFloat = cast(float*)(pBase);
                    // pos1
                    *pFloat++ = pos0.x;
                    *pFloat++ = pos0.y;
                    *pFloat++ = pos0.z;
                    
                    pBase = cast(void*)(pFloat);
                    
                    if (mUseVertexColour)
                    {
                        RGBA* pCol = cast(RGBA*)(pBase);
                        Root.getSingleton().convertColourValue(elem.colour, *pCol);
                        pCol++;
                        pBase = cast(void*)(pCol);
                    }
                    
                    if (mUseTexCoords)
                    {
                        pFloat = cast(float*)(pBase);
                        if (mTexCoordDir == TexCoordDirection.TCD_U)
                        {
                            *pFloat++ = elem.texCoord;
                            *pFloat++ = mOtherTexCoordRange[0];
                        }
                        else
                        {
                            *pFloat++ = mOtherTexCoordRange[0];
                            *pFloat++ = elem.texCoord;
                        }
                        pBase = cast(void*)(pFloat);
                    }
                    
                    // pos2
                    pFloat = cast(float*)(pBase);
                    *pFloat++ = pos1.x;
                    *pFloat++ = pos1.y;
                    *pFloat++ = pos1.z;
                    pBase = cast(void*)(pFloat);
                    
                    if (mUseVertexColour)
                    {
                        RGBA* pCol = cast(RGBA*)(pBase);
                        Root.getSingleton().convertColourValue(elem.colour, *pCol);
                        pCol++;
                        pBase = cast(void*)(pCol);
                    }
                    
                    if (mUseTexCoords)
                    {
                        pFloat = cast(float*)(pBase);
                        if (mTexCoordDir == TexCoordDirection.TCD_U)
                        {
                            *pFloat++ = elem.texCoord;
                            *pFloat++ = mOtherTexCoordRange[1];
                        }
                        else
                        {
                            *pFloat++ = mOtherTexCoordRange[1];
                            *pFloat++ = elem.texCoord;
                        }
                    }
                    
                    if (e == seg.tail)
                        break; // last one
                    
                    laste = e;
                    
                } // element
            } // segment valid?
            
        } // each segment
        
        
        
        pBuffer.get().unlock();
        mVertexCameraUsed = cam;
        mVertexContentDirty = false;
        
    }

    /// Update the contents of the index buffer
    void updateIndexBuffer()
    {
        
        setupBuffers();
        if (mIndexContentDirty)
        {
            
            ushort* pShort = cast(ushort*)(
                mIndexData.indexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
            mIndexData.indexCount = 0;
            // indexes
            foreach (segi; 0..mChainSegmentList.length)
            {
                ChainSegment* seg = &mChainSegmentList[segi];
                
                // Skip 0 or 1 element segment counts
                if (seg.head != SEGMENT_EMPTY && seg.head != seg.tail)
                {
                    // Start from head + 1 since it's only useful in pairs
                    size_t laste = seg.head;
                    while(1) // until break
                    {
                        size_t e = laste + 1;
                        // Wrap forwards
                        if (e == mMaxElementsPerChain)
                            e = 0;
                        // indexes of this element are (e * 2) and (e * 2) + 1
                        // indexes of the last element are the same, -2
                        assert (((e + seg.start) * 2) < 65536, "Too many elements!");
                        ushort baseIdx = cast(ushort)((e + seg.start) * 2);
                        ushort lastBaseIdx = cast(ushort)((laste + seg.start) * 2);
                        *pShort++ = lastBaseIdx;
                        *pShort++ = cast(ushort)(lastBaseIdx + 1);
                        *pShort++ = baseIdx;
                        *pShort++ = cast(ushort)(lastBaseIdx + 1);
                        *pShort++ = cast(ushort)(baseIdx + 1);
                        *pShort++ = baseIdx;
                        
                        mIndexData.indexCount += 6;
                        
                        
                        if (e == seg.tail)
                            break; // last one
                        
                        laste = e;
                        
                    }
                }
                
            }
            mIndexData.indexBuffer.get().unlock();
            
            mIndexContentDirty = false;
        }
        
    }

    void updateBoundingBox()
    {
        if (mBoundsDirty)
        {
            mAABB.setNull();
            Vector3 widthVector;
            foreach (segi; 0..mChainSegmentList.length)
            {
                ChainSegment* seg = &mChainSegmentList[segi];
                
                if (seg.head != SEGMENT_EMPTY)
                {
                    
                    for(size_t e = seg.head; ; ++e) // until break
                    {
                        // Wrap forwards
                        if (e == mMaxElementsPerChain)
                            e = 0;
                        
                        Element elem = mChainElementList[seg.start + e];
                        
                        widthVector.x = widthVector.y = widthVector.z = elem.width;
                        mAABB.merge(elem.position - widthVector);
                        mAABB.merge(elem.position + widthVector);
                        
                        if (e == seg.tail)
                            break;
                        
                    }
                }
                
            }
            
            // Set the current radius
            if (mAABB.isNull())
            {
                mRadius = 0.0f;
            }
            else
            {
                mRadius = Math.Sqrt(
                    std.algorithm.max(mAABB.getMinimum().squaredLength(),
                                  mAABB.getMaximum().squaredLength()));
            }
            
            mBoundsDirty = false;
        }
    }
    
    /// Chain segment has no elements
    static size_t SEGMENT_EMPTY = size_t.max;
}


/** Factory object for creating BillboardChain instances */
class BillboardChainFactory : MovableObjectFactory
{
protected:
    override MovableObject createInstanceImpl(string name, NameValuePairList params)
    {
        size_t maxElements = 20;
        size_t numberOfChains = 1;
        bool useTex = true;
        bool useCol = true;
        bool dynamic = true;
        // optional params
        if (!params.emptyAA)
        {
            auto ni = "maxElements" in params;
            if (ni !is null)
            {
                maxElements = std.conv.to!size_t(*ni);
            }
            ni = "numberOfChains" in params;
            if (ni !is null)
            {
                numberOfChains = std.conv.to!size_t(*ni);
            }
            ni = "useTextureCoords" in params;
            if (ni !is null)
            {
                useTex = std.conv.to!bool(*ni);
            }
            ni = "useVertexColours" in params;
            if (ni !is null)
            {
                useCol = std.conv.to!bool(*ni);
            }
            ni = "dynamic" in params;
            if (ni !is null)
            {
                dynamic = std.conv.to!bool(*ni);
            }
            
        }
        
        return new BillboardChain(name, maxElements, numberOfChains, useTex, useCol, dynamic);
        
    }
public:
    this() {}
    ~this() {}
    
    immutable static string FACTORY_TYPE_NAME = "BillboardChain";
    
    override string getType()
    {
        return FACTORY_TYPE_NAME;
    }

    override void destroyInstance( ref MovableObject obj)
    {
        destroy(obj);
    }
}

/** @} */
/** @} */