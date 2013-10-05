module ogre.resources.meshmanager;

import ogre.resources.resourcemanager;
import ogre.resources.resource;
import ogre.singleton;
import ogre.rendersystem.hardware;
import ogre.general.common;
import ogre.resources.mesh;
import ogre.math.plane;
import ogre.compat;
import ogre.math.vector;
import ogre.exception;
import ogre.math.quaternion;
import ogre.rendersystem.vertex;
import ogre.math.matrix;
import ogre.math.angles;
import ogre.math.axisalignedbox;
import ogre.lod.patchmesh;
import ogre.lod.patchsurface;
import ogre.resources.meshserializer;
import ogre.resources.resourcegroupmanager;
import ogre.math.maths;
import ogre.resources.prefabfactory;
import ogre.sharedptr;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Resources
    *  @{
    */
/** Handles the management of mesh resources.
        @remarks
            This class deals with the runtime management of
            mesh data; like other resource managers it handles
            the creation of resources (in this case mesh data),
            working within a fixed memory budget.
    */
final class MeshManager: ResourceManager, ManualResourceLoader
{
    alias Object.opEquals opEquals;
    alias ResourceManager.createOrRetrieve createOrRetrieve;
    mixin Singleton!MeshManager;
    mixin ManualResourceLoader.Impl;

public:
    this()
    {
        mBoundsPaddingFactor = 0.01;
        //mListener = 0;
        mPrepAllMeshesForShadowVolumes = false;
        
        mLoadOrder = 350.0f;
        mResourceType = "Mesh";
        
        ResourceGroupManager.getSingleton()._registerResourceManager(mResourceType, this);
        
    }
    ~this()
    {
        ResourceGroupManager.getSingleton()._unregisterResourceManager(mResourceType);
    }
    
    /** Initialises the manager, only to be called by OGRE internally. */
    void _initialise()
    {
        // Create pref ab objects
        createPrefabPlane();
        createPrefabCube();
        createPrefabSphere();
    }
    
    /** Create a new mesh, or retrieve an existing one with the same
            name if it already exists.
            @param vertexBufferUsage The usage flags with which the vertex buffer(s)
                will be created
            @param indexBufferUsage The usage flags with which the index buffer(s) created for 
                this mesh will be created with.
            @param vertexBufferShadowed If true, the vertex buffers will be shadowed by system memory 
                copies for faster read access
            @param indexBufferShadowed If true, the index buffers will be shadowed by system memory 
                copies for faster read access
        @see ResourceManager::createOrRetrieve
        */
    ResourceCreateOrRetrieveResult createOrRetrieve(
        string name,
        string group,
        bool isManual = false, ManualResourceLoader loader = null,
        NameValuePairList params = NameValuePairList.init,
        HardwareBuffer.Usage vertexBufferUsage = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, 
        HardwareBuffer.Usage indexBufferUsage = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, 
        bool vertexBufferShadowed = true, bool indexBufferShadowed = true)
    {
        ResourceCreateOrRetrieveResult res = super.createOrRetrieve(name,group,isManual,loader,params);
        SharedPtr!Mesh pMesh = res.first;
        // Was it created?
        if (res.second)
        {
            pMesh.getAs().setVertexBufferPolicy(vertexBufferUsage, vertexBufferShadowed);
            pMesh.getAs().setIndexBufferPolicy(indexBufferUsage, indexBufferShadowed);
        }
        return res;
        
    }
    
    /** Prepares a mesh for loading from a file.  This does the IO in advance of the call to load().
            @note
                If the model has already been created (prepared or loaded), the existing instance
                will be returned.
            @remarks
                Ogre loads model files from it's own proprietary
                format called .mesh. This is because having a single file
                format is better for runtime performance, and we also have
                control over pre-processed data (such as
                collision boxes, LOD reductions etc).
            @param filename The name of the .mesh file
            @param groupName The name of the resource group to assign the mesh to 
            @param vertexBufferUsage The usage flags with which the vertex buffer(s)
                will be created
            @param indexBufferUsage The usage flags with which the index buffer(s) created for 
                this mesh will be created with.
            @param vertexBufferShadowed If true, the vertex buffers will be shadowed by system memory 
                copies for faster read access
            @param indexBufferShadowed If true, the index buffers will be shadowed by system memory 
                copies for faster read access
        */
    SharedPtr!Mesh prepare( string filename, string groupName,
                    HardwareBuffer.Usage vertexBufferUsage = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, 
                    HardwareBuffer.Usage indexBufferUsage = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, 
                    bool vertexBufferShadowed = true, bool indexBufferShadowed = true)
    {
        SharedPtr!Mesh pMesh = createOrRetrieve(filename,groupName,false,null,null,
                                         vertexBufferUsage,indexBufferUsage,
                                         vertexBufferShadowed,indexBufferShadowed).first;
        pMesh.getAs().prepare();
        return pMesh;
    }
    
    /** Loads a mesh from a file, making it immediately available for use.
            @note
                If the model has already been created (prepared or loaded), the existing instance
                will be returned.
            @remarks
                Ogre loads model files from it's own proprietary
                format called .mesh. This is because having a single file
                format is better for runtime performance, and we also have
                control over pre-processed data (such as
                collision boxes, LOD reductions etc).
            @param filename The name of the .mesh file
            @param groupName The name of the resource group to assign the mesh to 
            @param vertexBufferUsage The usage flags with which the vertex buffer(s)
                will be created
            @param indexBufferUsage The usage flags with which the index buffer(s) created for 
                this mesh will be created with.
            @param vertexBufferShadowed If true, the vertex buffers will be shadowed by system memory 
                copies for faster read access
            @param indexBufferShadowed If true, the index buffers will be shadowed by system memory 
                copies for faster read access
        */
    SharedPtr!Mesh load( string filename, string groupName,
                 HardwareBuffer.Usage vertexBufferUsage = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, 
                 HardwareBuffer.Usage indexBufferUsage = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, 
                 bool vertexBufferShadowed = true, bool indexBufferShadowed = true)
    {
        SharedPtr!Mesh pMesh = createOrRetrieve(filename,groupName,false,null,null,
                                         vertexBufferUsage,indexBufferUsage,
                                         vertexBufferShadowed,indexBufferShadowed).first;
        pMesh.get().load();
        return pMesh;
    }
    
    
    /** Creates a new Mesh specifically for manual definition rather
            than loading from an object file. 
        @remarks
            Note that once you've defined your mesh, you must call Mesh::_setBounds and
            Mesh::_setBoundingRadius in order to define the bounds of your mesh. In previous
            versions of OGRE you could call Mesh::_updateBounds, but OGRE's support of 
            write-only vertex buffers makes this no longer appropriate.
        @param name The name to give the new mesh
        @param groupName The name of the resource group to assign the mesh to 
        @param loader ManualResourceLoader which will be called to load this mesh
            when the time comes. It is recommended that you populate this field
            in order that the mesh can be rebuilt should the need arise
        */
    SharedPtr!Mesh createManual( string name, string groupName, 
                         ManualResourceLoader loader = null)
    {
        // Don't try to get existing, create should fail if already exists
        return cast(SharedPtr!Mesh)create(name, groupName, true, loader);
    }
    
    /** Creates a basic plane, by default majoring on the x/y axes facing positive Z.
            @param
                name The name to give the resulting mesh
            @param 
                groupName The name of the resource group to assign the mesh to 
            @param
                plane The orientation of the plane and distance from the origin
            @param
                width The width of the plane in world coordinates
            @param
                height The height of the plane in world coordinates
            @param
                xsegments The number of segments to the plane in the x direction
            @param
                ysegments The number of segments to the plane in the y direction
            @param
                normals If true, normals are created perpendicular to the plane
            @param
                numTexCoordSets The number of 2D texture coordinate sets created - by default the corners
                are created to be the corner of the texture.
            @param
                uTile The number of times the texture should be repeated in the u direction
            @param
                vTile The number of times the texture should be repeated in the v direction
            @param
                upVector The 'Up' direction of the plane texture coordinates.
            @param
                vertexBufferUsage The usage flag with which the vertex buffer for this plane will be created
            @param
                indexBufferUsage The usage flag with which the index buffer for this plane will be created
            @param
                vertexShadowBuffer If this flag is set to true, the vertex buffer will be created 
                with a system memory shadow buffer,
                allowing you to read it back more efficiently than if it is in hardware
            @param
                indexShadowBuffer If this flag is set to true, the index buffer will be 
                created with a system memory shadow buffer,
                allowing you to read it back more efficiently than if it is in hardware
        */
    SharedPtr!Mesh createPlane(
        string name, string groupName,Plane plane,
        Real width, Real height,
        int xsegments = 1, int ysegments = 1,
        bool normals = true, ushort numTexCoordSets = 1,
        Real uTile = 1.0f, Real vTile = 1.0f,Vector3 upVector = Vector3.UNIT_Y,
        HardwareBuffer.Usage vertexBufferUsage = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, 
        HardwareBuffer.Usage indexBufferUsage = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY,
        bool vertexShadowBuffer = true, bool indexShadowBuffer = true)
    {
        // Create manual mesh which calls back self to load
        SharedPtr!Mesh pMesh = createManual(name, groupName, this);
        // Planes can never be manifold
        pMesh.getAs().setAutoBuildEdgeLists(false);
        // store parameters
        MeshBuildParams params;
        params.type = MeshBuildType.MBT_PLANE;
        params.plane = plane;
        params.width = width;
        params.height = height;
        params.xsegments = xsegments;
        params.ysegments = ysegments;
        params.normals = normals;
        params.numTexCoordSets = numTexCoordSets;
        params.xTile = uTile;
        params.yTile = vTile;
        params.upVector = upVector;
        params.vertexBufferUsage = vertexBufferUsage;
        params.indexBufferUsage = indexBufferUsage;
        params.vertexShadowBuffer = vertexShadowBuffer;
        params.indexShadowBuffer = indexShadowBuffer;
        mMeshBuildParams[pMesh.getPointer()] = params;
        
        // to preserve previous behaviour, load immediately
        pMesh.get().load();
        
        return pMesh;
    }
    
    
    /** Creates a plane, which because of it's texture coordinates looks like a curved
            surface, useful for skies in a skybox. 
            @param name
                The name to give the resulting mesh
            @param groupName
                The name of the resource group to assign the mesh to 
            @param plane
                The orientation of the plane and distance from the origin
            @param width
                The width of the plane in world coordinates
            @param height
                The height of the plane in world coordinates
            @param curvature
                The curvature of the plane. Good values are
                between 2 and 65. Higher values are more curved leading to
                a smoother effect, lower values are less curved meaning
                more distortion at the horizons but a better distance effect.
            @param xsegments
                The number of segments to the plane in the x direction
            @param ysegments
                The number of segments to the plane in the y direction
            @param normals
                If true, normals are created perpendicular to the plane
            @param numTexCoordSets
                The number of 2D texture coordinate sets created - by default the corners
                are created to be the corner of the texture.
            @param uTile
                The number of times the texture should be repeated in the u direction
            @param vTile
                The number of times the texture should be repeated in the v direction
            @param upVector
                The 'Up' direction of the plane.
            @param orientation
                The orientation of the overall sphere that's used to create the illusion
            @param vertexBufferUsage
                The usage flag with which the vertex buffer for this plane will be created
            @param indexBufferUsage
                The usage flag with which the index buffer for this plane will be created
            @param vertexShadowBuffer
                If this flag is set to true, the vertex buffer will be created 
                with a system memory shadow buffer,
                allowing you to read it back more efficiently than if it is in hardware
            @param indexShadowBuffer
                If this flag is set to true, the index buffer will be 
                created with a system memory shadow buffer,
                allowing you to read it back more efficiently than if it is in hardware
            @param ySegmentsToKeep The number of segments from the top of the dome
                downwards to keep. -1 keeps all of them. This can save fillrate if
                you cannot see much of the sky lower down.
        */
    SharedPtr!Mesh createCurvedIllusionPlane(
        string name, string groupName,Plane plane,
        Real width, Real height, Real curvature,
        int xsegments = 1, int ysegments = 1,
        bool normals = true, ushort numTexCoordSets = 1,
        Real uTile = 1.0f, Real vTile = 1.0f,Vector3 upVector = Vector3.UNIT_Y,
       Quaternion orientation = Quaternion.IDENTITY,
        HardwareBuffer.Usage vertexBufferUsage = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, 
        HardwareBuffer.Usage indexBufferUsage = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY,
        bool vertexShadowBuffer = true, bool indexShadowBuffer = true, 
        int ySegmentsToKeep = -1)
    {
        // Create manual mesh which calls back self to load
        SharedPtr!Mesh pMesh = createManual(name, groupName, this);
        // Planes can never be manifold
        pMesh.getAs().setAutoBuildEdgeLists(false);
        // store parameters
        MeshBuildParams params;
        params.type = MeshBuildType.MBT_CURVED_ILLUSION_PLANE;
        params.plane = plane;
        params.width = width;
        params.height = height;
        params.curvature = curvature;
        params.xsegments = xsegments;
        params.ysegments = ysegments;
        params.normals = normals;
        params.numTexCoordSets = numTexCoordSets;
        params.xTile = uTile;
        params.yTile = vTile;
        params.upVector = upVector;
        params.orientation = orientation;
        params.vertexBufferUsage = vertexBufferUsage;
        params.indexBufferUsage = indexBufferUsage;
        params.vertexShadowBuffer = vertexShadowBuffer;
        params.indexShadowBuffer = indexShadowBuffer;
        params.ySegmentsToKeep = ySegmentsToKeep;
        mMeshBuildParams[pMesh.getPointer()] = params;
        
        // to preserve previous behaviour, load immediately
        pMesh.get().load();
        
        return pMesh;
    }
    
    /** Creates a genuinely curved plane, by default majoring on the x/y axes facing positive Z.
            @param name
                The name to give the resulting mesh
            @param groupName
                The name of the resource group to assign the mesh to 
            @param plane
                The orientation of the plane and distance from the origin
            @param width
                The width of the plane in world coordinates
            @param height
                The height of the plane in world coordinates
            @param bow
                The amount of 'bow' in the curved plane.  (Could also be considered the depth.)
            @param xsegments
                The number of segments to the plane in the x direction
            @param ysegments
                The number of segments to the plane in the y direction
            @param normals
                If true, normals are created perpendicular to the plane
            @param numTexCoordSets
                The number of 2D texture coordinate sets created - by default the corners
                are created to be the corner of the texture.
            @param uTile
                The number of times the texture should be repeated in the u direction
            @param vTile
                The number of times the texture should be repeated in the v direction
            @param upVector
                The 'Up' direction of the plane.
            @param vertexBufferUsage
                The usage flag with which the vertex buffer for this plane will be created
            @param indexBufferUsage
                The usage flag with which the index buffer for this plane will be created
            @param vertexShadowBuffer
                If this flag is set to true, the vertex buffer will be created 
                with a system memory shadow buffer,
                allowing you to read it back more efficiently than if it is in hardware
            @param indexShadowBuffer
                If this flag is set to true, the index buffer will be 
                created with a system memory shadow buffer,
                allowing you to read it back more efficiently than if it is in hardware
        */
    SharedPtr!Mesh createCurvedPlane( 
                              string name, string groupName,Plane plane, 
                              Real width, Real height, Real bow = 0.5f, 
                              int xsegments = 1, int ysegments = 1,
                              bool normals = false, ushort numTexCoordSets = 1, 
                              Real uTile = 1.0f, Real vTile = 1.0f,Vector3 upVector = Vector3.UNIT_Y,
                              HardwareBuffer.Usage vertexBufferUsage = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, 
                              HardwareBuffer.Usage indexBufferUsage = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY,
                              bool vertexShadowBuffer = true, bool indexShadowBuffer = true)
    {
        // Create manual mesh which calls back self to load
        SharedPtr!Mesh pMesh = createManual(name, groupName, this);
        // Planes can never be manifold
        pMesh.getAs().setAutoBuildEdgeLists(false);
        // store parameters
        MeshBuildParams params;
        params.type = MeshBuildType.MBT_CURVED_PLANE;
        params.plane = plane;
        params.width = width;
        params.height = height;
        params.curvature = bow;
        params.xsegments = xsegments;
        params.ysegments = ysegments;
        params.normals = normals;
        params.numTexCoordSets = numTexCoordSets;
        params.xTile = uTile;
        params.yTile = vTile;
        params.upVector = upVector;
        params.vertexBufferUsage = vertexBufferUsage;
        params.indexBufferUsage = indexBufferUsage;
        params.vertexShadowBuffer = vertexShadowBuffer;
        params.indexShadowBuffer = indexShadowBuffer;
        mMeshBuildParams[pMesh.getPointer()] = params;
        
        // to preserve previous behaviour, load immediately
        pMesh.get().load();
        
        return pMesh;
        
    }
    
    /** Creates a Bezier patch based on an array of control vertices.
            @param name
                The name to give the newly created mesh. 
            @param groupName
                The name of the resource group to assign the mesh to 
            @param controlPointBuffer
                A pointer to a buffer containing the vertex data which defines control points 
                of the curves rather than actual vertices. Note that you are expected to provide not
                just position information, but potentially normals and texture coordinates too. The
                format of the buffer is defined in the VertexDeclaration parameter
            @param declaration
                VertexDeclaration describing the contents of the buffer. 
                Note this declaration must _only_ draw on buffer source 0!
            @param width
                Specifies the width of the patch in control points.
                Note this parameter must greater than or equal to 3.
            @param height
                Specifies the height of the patch in control points. 
                Note this parameter must greater than or equal to 3.
            @param uMaxSubdivisionLevel, vMaxSubdivisionLevel 
                If you want to manually set the top level of subdivision, 
                do it here, otherwise let the system decide.
            @param visibleSide 
                Determines which side of the patch (or both) triangles are generated for.
            @param vbUsage
                Vertex buffer usage flags. Recommend the default since vertex buffer should be static.
            @param ibUsage
                Index buffer usage flags. Recommend the default since index buffer should 
                be dynamic to change levels but not readable.
            @param vbUseShadow
                Flag to determine if a shadow buffer is generated for the vertex buffer. See
                HardwareBuffer for full details.
            @param ibUseShadow
                Flag to determine if a shadow buffer is generated for the index buffer. See
                HardwareBuffer for full details.
        */
    SharedPtr!PatchMesh createBezierPatch(
        string name, string groupName, void* controlPointBuffer, 
        ref VertexDeclaration declaration, size_t width, size_t height,
        size_t uMaxSubdivisionLevel = PatchSurface.AUTO_LEVEL, 
        size_t vMaxSubdivisionLevel = PatchSurface.AUTO_LEVEL,
        PatchSurface.VisibleSide visibleSide = PatchSurface.VisibleSide.VS_FRONT,
        HardwareBuffer.Usage vbUsage = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, 
        HardwareBuffer.Usage ibUsage = HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY,
        bool vbUseShadow = true, bool ibUseShadow = true)
    {
        if (width < 3 || height < 3)
        {
            throw new InvalidParamsError(
                        "Bezier patch require at least 3x3 control points",
                        "MeshManager.createBezierPatch");
        }
        
        SharedPtr!Mesh pMesh = getByName(name);
        if (!pMesh.isNull())
        {
            throw new DuplicateItemError("A mesh called " ~ name ~ " already exists!", 
                                         "MeshManager.createBezierPatch");
        }
        PatchMesh pm = new PatchMesh(this, name, getNextHandle(), groupName);
        pm.define(controlPointBuffer, declaration, width, height,
                   uMaxSubdivisionLevel, vMaxSubdivisionLevel, visibleSide, vbUsage, ibUsage,
                   vbUseShadow, ibUseShadow);
        pm.load();
        auto res = SharedPtr!PatchMesh(pm);
        addImpl(cast(SharedPtr!Resource)res);
        
        return res;
    }
    
    /** Tells the mesh manager that all future meshes should prepare themselves for
            shadow volumes on loading.
        */
    void setPrepareAllMeshesForShadowVolumes(bool enable)
    {
        mPrepAllMeshesForShadowVolumes = enable;
    }
    /** Retrieves whether all Meshes should prepare themselves for shadow volumes. */
    bool getPrepareAllMeshesForShadowVolumes()
    {
        return mPrepAllMeshesForShadowVolumes;
    }

    
    /** Gets the factor by which the bounding box of an entity is padded.
            Default is 0.01
        */
    Real getBoundsPaddingFactor()
    {
        return mBoundsPaddingFactor;
    }
    
    /** Sets the factor by which the bounding box of an entity is padded
        */
    void setBoundsPaddingFactor(Real paddingFactor)
    {
        mBoundsPaddingFactor = paddingFactor;
    }
    
    /** Sets the listener used to control mesh loading through the serializer.
        */
    void setListener(ref MeshSerializerListener listener)
    {
        mListener = listener;
    }
    
    /** Gets the listener used to control mesh loading through the serializer.
        */
    ref MeshSerializerListener getListener()
    {
        return mListener;
    }
    
    /** @see ManualResourceLoader::loadResource */
    void loadResource(ref Resource res)
    {
        Mesh msh = cast(Mesh)(res);
        
        // attempt to create a pref ab mesh
        bool createdPrefab = PrefabFactory.createPrefab(msh);
        
        // the mesh was not a pref ab..
        if(!createdPrefab)
        {
            // Find build parameters
            auto ibld = res in mMeshBuildParams;
            if (ibld is null)
            {
                throw new ItemNotFoundError(
                            "Cannot find build parameters for " ~ res.getName(),
                            "MeshManager.loadResource");
            }
            MeshBuildParams params = *ibld;
            
            switch(params.type)
            {
                case MeshBuildType.MBT_PLANE:
                    loadManualPlane(msh, params);
                    break;
                case MeshBuildType.MBT_CURVED_ILLUSION_PLANE:
                    loadManualCurvedIllusionPlane(msh, params);
                    break;
                case MeshBuildType.MBT_CURVED_PLANE:
                    loadManualCurvedPlane(msh, params);
                    break;
                default:
                    throw new ItemNotFoundError(
                                "Unknown build parameters for " ~ res.getName(),
                                "MeshManager.loadResource");
            }
        }
        
        //FIXME Casting removes reffing?
        //res = msh;
        debug(STDERR) std.stdio.stderr.writeln("MeshManager.loadResource :", res);
    }
    
protected:
    /// @copydoc ResourceManager::createImpl
    override Resource createImpl(string name, ResourceHandle handle, 
                                 string group, bool isManual, ManualResourceLoader loader, 
                                 NameValuePairList createParams)
    {
        // no use for createParams here
        return new Mesh(this, name, handle, group, isManual, loader);
    }
    
    /** Utility method for tessellating 2D meshes.
        */
    void tesselate2DMesh(SubMesh pSub, uint meshWidth, uint meshHeight, 
                         bool doubleSided = false, 
                         HardwareBuffer.Usage indexBufferUsage = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY,
                         bool indexSysMem = false)
    {
        // The mesh is built, just make a list of indexes to spit out the triangles
        uint vInc, uInc, v, u, iterations;
        uint vCount, uCount;
        
        if (doubleSided)
        {
            iterations = 2;
            vInc = 1;
            v = 0; // Start with front
        }
        else
        {
            iterations = 1;
            vInc = 1;
            v = 0;
        }
        
        // Allocate memory for faces
        // Num faces, width*height*2 (2 tris per square), index count is * 3 on top
        pSub.indexData.indexCount = (meshWidth-1) * (meshHeight-1) * 2 * iterations * 3;
        pSub.indexData.indexBuffer = HardwareBufferManager.getSingleton().
            createIndexBuffer(HardwareIndexBuffer.IndexType.IT_16BIT,
                              pSub.indexData.indexCount, indexBufferUsage, indexSysMem);
        
        uint v1, v2, v3;
        //bool firstTri = true;
        SharedPtr!HardwareIndexBuffer ibuf = pSub.indexData.indexBuffer;
        // Lock the whole buffer
        ushort* pIndexes = cast(ushort*)( ibuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD) );
        
        while (iterations--)
        {
            // Make tris in a zigzag pattern (compatible with strips)
            u = 0;
            uInc = 1; // Start with moving +u
            
            vCount = meshHeight - 1;
            while (vCount--)
            {
                uCount = meshWidth - 1;
                while (uCount--)
                {
                    // First Tri in cell
                    // -----------------
                    v1 = ((v + vInc) * meshWidth) + u;
                    v2 = (v * meshWidth) + u;
                    v3 = ((v + vInc) * meshWidth) + (u + uInc);
                    // Output indexes
                    *pIndexes++ = cast(ushort)v1;
                    *pIndexes++ = cast(ushort)v2;
                    *pIndexes++ = cast(ushort)v3;
                    // Second Tri in cell
                    // ------------------
                    v1 = ((v + vInc) * meshWidth) + (u + uInc);
                    v2 = (v * meshWidth) + u;
                    v3 = (v * meshWidth) + (u + uInc);
                    // Output indexes
                    *pIndexes++ = cast(ushort)v1;
                    *pIndexes++ = cast(ushort)v2;
                    *pIndexes++ = cast(ushort)v3;
                    
                    // Next column
                    u += uInc;
                }
                // Next row
                v += vInc;
                u = 0;
                
                
            }
            
            // Reverse vInc for double sided
            v = meshHeight - 1;
            vInc = -vInc;
            
        }
        // Unlock
        ibuf.get().unlock();
        
    }
    
    void createPrefabPlane()
    {
        SharedPtr!Mesh msh = create(
            "Prefab_Plane", 
            ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME, 
            true, // manually loaded
            this);
        // Planes can never be manifold
        msh.getAs().setAutoBuildEdgeLists(false);
        // to preserve previous behaviour, load immediately
        msh.getAs().load();
    }

    void createPrefabCube()
    {
        SharedPtr!Mesh msh = create(
            "Prefab_Cube", 
            ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME, 
            true, // manually loaded
            this);
        
        // to preserve previous behaviour, load immediately
        msh.getAs().load();
    }

    void createPrefabSphere()
    {
        SharedPtr!Mesh msh = create(
            "Prefab_Sphere", 
            ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME, 
            true, // manually loaded
            this);
        
        // to preserve previous behaviour, load immediately
        msh.getAs().load();
    }
    
    /** Enum identifying the types of manual mesh built by this manager */
    enum MeshBuildType
    {
        MBT_PLANE,
        MBT_CURVED_ILLUSION_PLANE,
        MBT_CURVED_PLANE
    }
    /** Saved parameters used to (re)build a manual mesh built by this class */
    struct MeshBuildParams
    {
        MeshBuildType type;
        Plane plane;
        Real width;
        Real height;
        Real curvature;
        int xsegments;
        int ysegments;
        bool normals;
        ushort numTexCoordSets;
        Real xTile;
        Real yTile;
        Vector3 upVector;
        Quaternion orientation;
        HardwareBuffer.Usage vertexBufferUsage;
        HardwareBuffer.Usage indexBufferUsage;
        bool vertexShadowBuffer;
        bool indexShadowBuffer;
        int ySegmentsToKeep;
    }
    /** Map from resource pointer to parameter set */
    //typedef map<Resource*, MeshBuildParams>::type MeshBuildParamsMap;
    alias MeshBuildParams[Resource] MeshBuildParamsMap;
    MeshBuildParamsMap mMeshBuildParams;
    
    /** Utility method for manual loading a plane */
    void loadManualPlane(ref Mesh pMesh, ref MeshBuildParams params)
    {
        if ((params.xsegments + 1) * (params.ysegments + 1) > 65536)
            throw new InvalidParamsError(
                "Plane tesselation is too high, must generate max 65536 vertices", 
                "MeshManager.loadManualPlane");
        SubMesh pSub = pMesh.createSubMesh();
        
        // Set up vertex data
        // Use a single shared buffer
        pMesh.sharedVertexData = new VertexData();
        VertexData vertexData = pMesh.sharedVertexData;
        // Set up Vertex Declaration
        VertexDeclaration vertexDecl = vertexData.vertexDeclaration;
        size_t currOffset = 0;
        // We always need positions
        vertexDecl.addElement(0, currOffset, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_POSITION);
        currOffset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
        // Optional normals
        if(params.normals)
        {
            vertexDecl.addElement(0, currOffset, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_NORMAL);
            currOffset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
        }
        
        for (ushort i = 0; i < params.numTexCoordSets; ++i)
        {
            // Assumes 2D texture coords
            vertexDecl.addElement(0, currOffset, VertexElementType.VET_FLOAT2, VertexElementSemantic.VES_TEXTURE_COORDINATES, i);
            currOffset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT2);
        }
        
        vertexData.vertexCount = (params.xsegments + 1) * (params.ysegments + 1);
        
        // Allocate vertex buffer
        SharedPtr!HardwareVertexBuffer vbuf = 
            HardwareBufferManager.getSingleton().
                createVertexBuffer(vertexDecl.getVertexSize(0), vertexData.vertexCount,
                                   params.vertexBufferUsage, params.vertexShadowBuffer);
        //debug(STDERR) std.stdio.stderr.writeln("MeshManager.loadManualPlane ref:", vbuf._refCounted.refCount);
        // Set up the binding (one source only)
        //VertexBufferBinding binding = vertexData.vertexBufferBinding;
        vertexData.vertexBufferBinding.setBinding(0, vbuf);
        //debug(STDERR) std.stdio.stderr.writeln("MeshManager.loadManualPlane after binding ref:", vbuf._refCounted.refCount);
        
        // Work out the transform required
        // Default orientation of plane is normal along +z, distance 0
        Matrix4 xlate, xform, rot;
        Matrix3 rot3;
        xlate = rot = Matrix4.IDENTITY;
        // Determine axes
        Vector3 zAxis, yAxis, xAxis;
        zAxis = params.plane.normal;
        zAxis.normalise();
        yAxis = params.upVector;
        yAxis.normalise();
        xAxis = yAxis.crossProduct(zAxis);
        if (xAxis.length() == 0)
        {
            //upVector must be wrong
            throw new InvalidParamsError("The upVector you supplied is parallel to the plane normal, so is not valid.",
                        "MeshManager.createPlane");
        }
        
        rot3.FromAxes(xAxis, yAxis, zAxis);
        rot = rot3;
        
        // Set up standard transform from origin
        xlate.setTrans(params.plane.normal * -params.plane.d);
        
        // concatenate
        xform = xlate * rot;
        
        // Generate vertex data
        // Lock the whole buffer
        float* pReal = cast(float*)( vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD) );
        Real xSpace = params.width / params.xsegments;
        Real ySpace = params.height / params.ysegments;
        Real halfWidth = params.width / 2;
        Real halfHeight = params.height / 2;
        Real xTex = (1.0f * params.xTile) / params.xsegments;
        Real yTex = (1.0f * params.yTile) / params.ysegments;
        Vector3 vec;
        Vector3 min = Vector3.ZERO, max = Vector3.UNIT_SCALE;
        Real maxSquaredLength = 0;
        bool firstTime = true;
        
        for (int y = 0; y < params.ysegments + 1; ++y)
        {
            for (int x = 0; x < params.xsegments + 1; ++x)
            {
                // Work out centered on origin
                vec.x = (x * xSpace) - halfWidth;
                vec.y = (y * ySpace) - halfHeight;
                vec.z = 0.0f;
                // Transform by orientation and distance
                vec = xform.transformAffine(vec);
                // Assign to geometry
                *pReal++ = vec.x;
                *pReal++ = vec.y;
                *pReal++ = vec.z;
                
                // Build bounds as we go
                if (firstTime)
                {
                    min = vec;
                    max = vec;
                    maxSquaredLength = vec.squaredLength();
                    firstTime = false;
                }
                else
                {
                    min.makeFloor(vec);
                    max.makeCeil(vec);
                    maxSquaredLength = std.algorithm.max(maxSquaredLength, vec.squaredLength());
                }
                
                if (params.normals)
                {
                    // Default normal is along unit Z
                    vec = Vector3.UNIT_Z;
                    // Rotate
                    vec = rot.transformAffine(vec);
                    
                    *pReal++ = vec.x;
                    *pReal++ = vec.y;
                    *pReal++ = vec.z;
                }
                
                for (ushort i = 0; i < params.numTexCoordSets; ++i)
                {
                    *pReal++ = x * xTex;
                    *pReal++ = 1 - (y * yTex);
                }
                
                
            } // x
        } // y
        
        // Unlock
        vbuf.get().unlock();
        // Generate face list
        pSub.useSharedVertices = true;
        tesselate2DMesh(pSub, params.xsegments + 1, params.ysegments + 1, false, 
                        params.indexBufferUsage, params.indexShadowBuffer);
        
        pMesh._setBounds(AxisAlignedBox(min, max), true);
        pMesh._setBoundingSphereRadius(Math.Sqrt(maxSquaredLength));
    }

    /** Utility method for manual loading a curved plane */
    void loadManualCurvedPlane(ref Mesh pMesh, ref MeshBuildParams params)
    {
        if ((params.xsegments + 1) * (params.ysegments + 1) > 65536)
            throw new InvalidParamsError(
                "Plane tesselation is too high, must generate max 65536 vertices", 
                "MeshManager.loadManualCurvedPlane");
        SubMesh pSub = pMesh.createSubMesh();
        
        // Set options
        pMesh.sharedVertexData = new VertexData();
        pMesh.sharedVertexData.vertexStart = 0;
        VertexBufferBinding bind = pMesh.sharedVertexData.vertexBufferBinding;
        VertexDeclaration decl = pMesh.sharedVertexData.vertexDeclaration;
        
        pMesh.sharedVertexData.vertexCount = (params.xsegments + 1) * (params.ysegments + 1);
        
        size_t offset = 0;
        decl.addElement(0, offset, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_POSITION);
        offset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
        if (params.normals)
        {
            decl.addElement(0, 0, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_NORMAL);
            offset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
        }
        
        for (ushort i = 0; i < params.numTexCoordSets; ++i)
        {
            decl.addElement(0, offset, VertexElementType.VET_FLOAT2, VertexElementSemantic.VES_TEXTURE_COORDINATES, i);
            offset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT2);
        }
        
        
        // Allocate memory
        SharedPtr!HardwareVertexBuffer vbuf = 
            HardwareBufferManager.getSingleton().createVertexBuffer(
                offset, 
                pMesh.sharedVertexData.vertexCount, 
                params.vertexBufferUsage, 
                params.vertexShadowBuffer);
        bind.setBinding(0, vbuf);
        
        // Work out the transform required
        // Default orientation of plane is normal along +z, distance 0
        Matrix4 xlate, xform, rot;
        Matrix3 rot3;
        xlate = rot = Matrix4.IDENTITY;
        // Determine axes
        Vector3 zAxis, yAxis, xAxis;
        zAxis = params.plane.normal;
        zAxis.normalise();
        yAxis = params.upVector;
        yAxis.normalise();
        xAxis = yAxis.crossProduct(zAxis);
        if (xAxis.length() == 0)
        {
            //upVector must be wrong
            throw new InvalidParamsError("The upVector you supplied is parallel to the plane normal, so is not valid.",
                        "MeshManager.createPlane");
        }
        
        rot3.FromAxes(xAxis, yAxis, zAxis);
        rot = rot3;
        
        // Set up standard transform from origin
        xlate.setTrans(params.plane.normal * -params.plane.d);
        
        // concatenate
        xform = xlate * rot;
        
        // Generate vertex data
        float* pFloat = cast(float*)(vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD)); 
        Real xSpace = params.width / params.xsegments;
        Real ySpace = params.height / params.ysegments;
        Real halfWidth = params.width / 2;
        Real halfHeight = params.height / 2;
        Real xTex = (1.0f * params.xTile) / params.xsegments;
        Real yTex = (1.0f * params.yTile) / params.ysegments;
        Vector3 vec;
        
        Vector3 min = Vector3.ZERO, max = Vector3.UNIT_SCALE;
        Real maxSqLen = 0;
        bool first = true;
        
        Real diff_x, diff_y, dist;
        
        for (int y = 0; y < params.ysegments + 1; ++y)
        {
            for (int x = 0; x < params.xsegments + 1; ++x)
            {
                // Work out centered on origin
                vec.x = (x * xSpace) - halfWidth;
                vec.y = (y * ySpace) - halfHeight;
                
                // Here's where curved plane is different from standard plane.  Amazing, I know.
                diff_x = (x - ((params.xsegments) / 2)) / cast(Real)((params.xsegments));
                diff_y = (y - ((params.ysegments) / 2)) / cast(Real)((params.ysegments));
                dist = Math.Sqrt(diff_x*diff_x + diff_y * diff_y );
                vec.z = (-std.math.sin((1-dist) * (Math.PI/2)) * params.curvature) + params.curvature;
                
                // Transform by orientation and distance
                Vector3 pos = xform.transformAffine(vec);
                // Assign to geometry
                *pFloat++ = pos.x;
                *pFloat++ = pos.y;
                *pFloat++ = pos.z;
                
                // Record bounds
                if (first)
                {
                    min = max = vec;
                    maxSqLen = vec.squaredLength();
                    first = false;
                }
                else
                {
                    min.makeFloor(vec);
                    max.makeCeil(vec);
                    maxSqLen = std.algorithm.max(maxSqLen, vec.squaredLength());
                }
                
                if (params.normals)
                {
                    // This part is kinda 'wrong' for curved planes... but curved planes are
                    //   very valuable outside sky planes, which don't typically need normals
                    //   so I'm not going to mess with it for now. 
                    
                    // Default normal is along unit Z
                    //vec = Vector3.UNIT_Z;
                    // Rotate
                    vec = rot.transformAffine(vec);
                    vec.normalise();
                    
                    *pFloat++ = vec.x;
                    *pFloat++ = vec.y;
                    *pFloat++ = vec.z;
                }
                
                for (ushort i = 0; i < params.numTexCoordSets; ++i)
                {
                    *pFloat++ = x * xTex;
                    *pFloat++ = 1 - (y * yTex);
                }
                
            } // x
        } // y
        vbuf.get().unlock();
        
        // Generate face list
        tesselate2DMesh(pSub, params.xsegments + 1, params.ysegments + 1, 
                        false, params.indexBufferUsage, params.indexShadowBuffer);
        
        pMesh._setBounds(AxisAlignedBox(min, max), true);
        pMesh._setBoundingSphereRadius(Math.Sqrt(maxSqLen));
        
    }

    /** Utility method for manual loading a curved illusion plane */
    void loadManualCurvedIllusionPlane(ref Mesh pMesh, ref MeshBuildParams params)
    {
        if (params.ySegmentsToKeep == -1) params.ySegmentsToKeep = params.ysegments;
        
        if ((params.xsegments + 1) * (params.ySegmentsToKeep + 1) > 65536)
            throw new InvalidParamsError(
                "Plane tesselation is too high, must generate max 65536 vertices", 
                "MeshManager.loadManualCurvedIllusionPlane");
        SubMesh pSub = pMesh.createSubMesh();
        
        
        // Set up vertex data
        // Use a single shared buffer
        pMesh.sharedVertexData = new VertexData();
        VertexData vertexData = pMesh.sharedVertexData;
        // Set up Vertex Declaration
        VertexDeclaration vertexDecl = vertexData.vertexDeclaration;
        size_t currOffset = 0;
        // We always need positions
        vertexDecl.addElement(0, currOffset, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_POSITION);
        currOffset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
        // Optional normals
        if(params.normals)
        {
            vertexDecl.addElement(0, currOffset, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_NORMAL);
            currOffset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
        }
        
        for (ushort i = 0; i < params.numTexCoordSets; ++i)
        {
            // Assumes 2D texture coords
            vertexDecl.addElement(0, currOffset, VertexElementType.VET_FLOAT2, VertexElementSemantic.VES_TEXTURE_COORDINATES, i);
            currOffset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT2);
        }
        
        vertexData.vertexCount = (params.xsegments + 1) * (params.ySegmentsToKeep + 1);
        
        // Allocate vertex buffer
        SharedPtr!HardwareVertexBuffer vbuf = 
            HardwareBufferManager.getSingleton().
                createVertexBuffer(vertexDecl.getVertexSize(0), vertexData.vertexCount,
                                   params.vertexBufferUsage, params.vertexShadowBuffer);
        
        // Set up the binding (one source only)
        VertexBufferBinding binding = vertexData.vertexBufferBinding;
        binding.setBinding(0, vbuf);
        
        // Work out the transform required
        // Default orientation of plane is normal along +z, distance 0
        Matrix4 xlate, xform, rot;
        Matrix3 rot3;
        xlate = rot = Matrix4.IDENTITY;
        // Determine axes
        Vector3 zAxis, yAxis, xAxis;
        zAxis = params.plane.normal;
        zAxis.normalise();
        yAxis = params.upVector;
        yAxis.normalise();
        xAxis = yAxis.crossProduct(zAxis);
        if (xAxis.length() == 0)
        {
            //upVector must be wrong
            throw new InvalidParamsError("The upVector you supplied is parallel to the plane normal, so is not valid.",
                        "MeshManager.createPlane");
        }
        
        rot3.FromAxes(xAxis, yAxis, zAxis);
        rot = rot3;
        
        // Set up standard transform from origin
        xlate.setTrans(params.plane.normal * -params.plane.d);
        
        // concatenate
        xform = xlate * rot;
        
        // Generate vertex data
        // Imagine a large sphere with the camera located near the top
        // The lower the curvature, the larger the sphere
        // Use the angle from viewer to the points on the plane
        // Credit to Aftershock for the general approach
        Real camPos;      // Camera position relative to sphere center
        
        // Derive sphere radius
        Vector3 vertPos;  // position relative to camera
        Real sphDist;      // Distance from camera to sphere along box vertex vector
        // Vector3 camToSph; // camera position to sphere
        Real sphereRadius;// Sphere radius
        // Actual values irrelevant, it's the relation between sphere radius and camera position that's important
       Real SPHERE_RAD = 100.0;
       Real CAM_DIST = 5.0;
        
        sphereRadius = SPHERE_RAD - params.curvature;
        camPos = sphereRadius - CAM_DIST;
        
        // Lock the whole buffer
        float* pFloat = cast(float*)( vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD) );
        Real xSpace = params.width / params.xsegments;
        Real ySpace = params.height / params.ysegments;
        Real halfWidth = params.width / 2;
        Real halfHeight = params.height / 2;
        Vector3 vec, norm;
        Vector3 min = Vector3.ZERO, max = Vector3.UNIT_SCALE;
        Real maxSquaredLength = 0;
        bool firstTime = true;
        
        for (int y = params.ysegments - params.ySegmentsToKeep; y < params.ysegments + 1; ++y)
        {
            for (int x = 0; x < params.xsegments + 1; ++x)
            {
                // Work out centered on origin
                vec.x = (x * xSpace) - halfWidth;
                vec.y = (y * ySpace) - halfHeight;
                vec.z = 0.0f;
                // Transform by orientation and distance
                vec = xform.transformAffine(vec);
                // Assign to geometry
                *pFloat++ = vec.x;
                *pFloat++ = vec.y;
                *pFloat++ = vec.z;
                
                // Build bounds as we go
                if (firstTime)
                {
                    min = vec;
                    max = vec;
                    maxSquaredLength = vec.squaredLength();
                    firstTime = false;
                }
                else
                {
                    min.makeFloor(vec);
                    max.makeCeil(vec);
                    maxSquaredLength = std.algorithm.max(maxSquaredLength, vec.squaredLength());
                }
                
                if (params.normals)
                {
                    // Default normal is along unit Z
                    norm = Vector3.UNIT_Z;
                    // Rotate
                    norm = params.orientation * norm;
                    
                    *pFloat++ = norm.x;
                    *pFloat++ = norm.y;
                    *pFloat++ = norm.z;
                }
                
                // Generate texture coords
                // Normalise position
                // modify by orientation to return +y up
                vec = params.orientation.Inverse() * vec;
                vec.normalise();
                // Find distance to sphere
                sphDist = Math.Sqrt(camPos*camPos * (vec.y*vec.y-1.0f) + sphereRadius*sphereRadius) - camPos*vec.y;
                
                vec.x *= sphDist;
                vec.z *= sphDist;
                
                // Use x and y on sphere as texture coordinates, tiled
                Real s = vec.x * (0.01f * params.xTile);
                Real t = 1.0f - (vec.z * (0.01f * params.yTile));
                for (ushort i = 0; i < params.numTexCoordSets; ++i)
                {
                    *pFloat++ = s;
                    *pFloat++ = t;
                }
                
                
            } // x
        } // y
        
        // Unlock
        vbuf.get().unlock();
        // Generate face list
        pSub.useSharedVertices = true;
        tesselate2DMesh(pSub, params.xsegments + 1, params.ySegmentsToKeep + 1, false, 
                        params.indexBufferUsage, params.indexShadowBuffer);
        
        pMesh._setBounds(AxisAlignedBox(min, max), true);
        pMesh._setBoundingSphereRadius(Math.Sqrt(maxSquaredLength));
    }
    
    bool mPrepAllMeshesForShadowVolumes;
    
    //the factor by which the bounding box of an entity is padded   
    Real mBoundsPaddingFactor;
    
    // The listener to pass to serializers
    MeshSerializerListener mListener;
}

/** @} */
/** @} */