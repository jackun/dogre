module ogre.lod.patchmesh;
import ogre.resources.mesh;
import ogre.rendersystem.vertex;
import ogre.resources.resourcemanager;
import ogre.rendersystem.hardware;
import ogre.lod.patchsurface;
import ogre.resources.resource;
import ogre.compat;
import ogre.sharedptr;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup LOD
    *  @{
    */
/** Patch specialisation of Mesh. 
    @remarks
        Instances of this class should be created by calling MeshManager::createBezierPatch.
    */
class PatchMesh : Mesh
{
protected:
    /// Internal surface definition
    PatchSurface mSurface;
    /// Vertex declaration, cloned from the input
    VertexDeclaration mDeclaration;
public:
    /// Constructor
    this(ResourceManager creator,string name, ResourceHandle handle,
             string group)
    {
        super(creator, name, handle, group, false, null);
    }

    /// Update the mesh with new control points positions.
    void update(void* controlPointBuffer, size_t width, size_t height, 
                size_t uMaxSubdivisionLevel, size_t vMaxSubdivisionLevel, 
                PatchSurface.VisibleSide visibleSide)
    {
        mSurface.defineSurface(controlPointBuffer, mDeclaration, width, height, PatchSurface.PatchSurfaceType.PST_BEZIER, 
                               uMaxSubdivisionLevel, vMaxSubdivisionLevel, visibleSide);
        SubMesh sm = this.getSubMesh(0);
        VertexData vertex_data = sm.useSharedVertices ? this.sharedVertexData : sm.vertexData;
        //
        VertexElement posElem = vertex_data.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
        SharedPtr!HardwareVertexBuffer vbuf = vertex_data.vertexBufferBinding.getBuffer(posElem.getSource());
        
        // Build patch with new control points
        mSurface.build(vbuf, 0, sm.indexData.indexBuffer, 0);
    }

    /// Define the patch, as defined in MeshManager::createBezierPatch
    void define(void* controlPointBuffer, 
                ref VertexDeclaration declaration, size_t width, size_t height,
                size_t uMaxSubdivisionLevel = PatchSurface.AUTO_LEVEL, 
                size_t vMaxSubdivisionLevel = PatchSurface.AUTO_LEVEL,
                PatchSurface.VisibleSide visibleSide = PatchSurface.VisibleSide.VS_FRONT,
                HardwareBuffer.Usage vbUsage = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, 
                HardwareBuffer.Usage ibUsage = HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY,
                bool vbUseShadow = false, bool ibUseShadow = false)
    {
        mVertexBufferUsage = vbUsage;
        mVertexBufferShadowBuffer = vbUseShadow;
        mIndexBufferUsage = ibUsage;
        mIndexBufferShadowBuffer = ibUseShadow;
        
        // Init patch builder
        // define the surface
        // NB clone the declaration to make it independent
        mDeclaration = declaration.clone();
        mSurface.defineSurface(controlPointBuffer, mDeclaration, width, height, 
                               PatchSurface.PatchSurfaceType.PST_BEZIER, uMaxSubdivisionLevel, vMaxSubdivisionLevel, 
                               visibleSide);
        
    }
    
    /* Sets the current subdivision level as a proportion of full detail.
        @param factor Subdivision factor as a value from 0 (control points only) to 1 (maximum
            subdivision). */
    void setSubdivision(Real factor)
    {
        mSurface.setSubdivisionFactor(factor);
        SubMesh sm = this.getSubMesh(0);
        sm.indexData.indexCount = mSurface.getCurrentIndexCount();
        
    }
protected:
    /// Overridden from Resource
    override void loadImpl()
    {
        SubMesh sm = this.createSubMesh();
        sm.vertexData = new VertexData();
        sm.useSharedVertices = false;
        
        // Set up vertex buffer
        sm.vertexData.vertexStart = 0;
        sm.vertexData.vertexCount = mSurface.getRequiredVertexCount();
        sm.vertexData.vertexDeclaration = mDeclaration;
        SharedPtr!HardwareVertexBuffer vbuf = HardwareBufferManager.getSingleton().
            createVertexBuffer(
                mDeclaration.getVertexSize(0), 
                sm.vertexData.vertexCount, 
                mVertexBufferUsage, 
                mVertexBufferShadowBuffer);
        sm.vertexData.vertexBufferBinding.setBinding(0, vbuf);
        
        // Set up index buffer
        sm.indexData.indexStart = 0;
        sm.indexData.indexCount = mSurface.getRequiredIndexCount();
        sm.indexData.indexBuffer = HardwareBufferManager.getSingleton().
            createIndexBuffer(
                HardwareIndexBuffer.IndexType.IT_16BIT, // only 16-bit indexes supported, patches shouldn't be bigger than that
                sm.indexData.indexCount,
                mIndexBufferUsage, 
                mIndexBufferShadowBuffer);
        
        // Build patch
        mSurface.build(vbuf, 0, sm.indexData.indexBuffer, 0);
        
        // Set bounds
        this._setBounds(mSurface.getBounds(), true);
        this._setBoundingSphereRadius(mSurface.getBoundingSphereRadius());
        
    }
    /// Overridden from Resource - do nothing (no disk caching)
    override void prepareImpl() {}
    
}

/** Again, point in using SharedPtr??? Alias to PatchMesh for now. */
//alias SharedPtr!PatchMesh PatchMeshPtr;
//alias PatchMesh SharedPtr!PatchMesh;

/** @} */
/** @} */