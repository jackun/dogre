module ogre.scene.shadowcaster;

private
{
    //import std.container;
}

import ogre.sharedptr;
import ogre.math.axisalignedbox;
import ogre.compat;
import ogre.rendersystem.hardware;
import ogre.math.angles;
import ogre.math.matrix;
import ogre.general.common;
import ogre.math.vector;
import ogre.materials.gpuprogram;
import ogre.general.common;
import ogre.math.optimisedutil;
import ogre.math.edgedata;
import ogre.general.generals;
import ogre.general.root;
import ogre.scene.light;
import ogre.scene.renderable;
import ogre.rendersystem.vertex;
import ogre.general.log;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Scene
 *  @{
 */
/** Class which represents the renderable aspects of a set of shadow volume faces. 
 @remarks
 Note that for casters comprised of more than one set of vertex buffers (e.g. SubMeshes each
 using their own geometry), it will take more than one ShadowRenderable to render the 
 shadow volume. Therefore for shadow caster geometry, it is best to stick to one set of
 vertex buffers (not necessarily one buffer, but the positions for the entire geometry 
 should come from one buffer if possible)
 */
class ShadowRenderable : Renderable //, public ShadowDataAlloc
{
    mixin Renderable.Renderable_Impl!();
    mixin Renderable.Renderable_Any_Impl!();
    
protected:
    SharedPtr!Material mMaterial;
    RenderOperation mRenderOp;
    ShadowRenderable mLightCap; /// Used only if isLightCapSeparate == true
public:
    this() 
    { 
        //RenderableInit();
        //mMaterial();
        //mLightCap = 0;
    }
    ~this() { destroy(mLightCap); DestroyRenderable(); }
    /** Set the material to be used by the shadow, should be set by the caller 
     before adding to a render queue
     */
    void setMaterial(SharedPtr!Material mat) { mMaterial = mat; }
    /// @copydoc Renderable.getMaterial
    SharedPtr!Material getMaterial(){ return mMaterial; }
    /// @copydoc Renderable.getRenderOperation
    void getRenderOperation(ref RenderOperation op) { op = mRenderOp; }
    /// Get the internal render operation for set up.
    ref RenderOperation getRenderOperationForUpdate() {return mRenderOp;}
    /// @copydoc Renderable.getWorldTransforms
    abstract void getWorldTransforms(ref Matrix4[] xform);
    /// @copydoc Renderable.getSquaredViewDepth
    Real getSquaredViewDepth(Camera c){ return 0; /* not used */}
    /// @copydoc Renderable.getLights.
    LightList getLights()
    {
        // return empty
        static LightList ll;
        return ll;
    }
    /** Does this renderable require a separate light cap?
     @remarks
     If possible, the light cap (when required) should be contained in the
     usual geometry of the shadow renderable. However, if for some reason
     the normal depth function (less than) could cause artefacts, then a
     separate light cap with a depth function of 'always fail' can be used 
     instead. The primary example of this is when there are floating point
     inaccuracies caused by calculating the shadow geometry separately from
     the real geometry. 
     */
    bool isLightCapSeparate(){ return mLightCap !is null; }
    
    /// Get the light cap version of this renderable.
    ref ShadowRenderable getLightCapRenderable() { return mLightCap; }
    /// Should this ShadowRenderable be treated as visible?
    bool isVisible(){ return true; }
    
    /** This function informs the shadow renderable that the global index buffer
     from the SceneManager has been updated. As all shadow use this buffer their pointer 
     must be updated as well.
     @param indexBuffer
     Pointer to the new index buffer.
     */
    abstract void rebindIndexBuffer(SharedPtr!HardwareIndexBuffer* indexBuffer);
    
}

/** A set of flags that can be used to influence ShadowRenderable creation. */
enum ShadowRenderableFlags
{
    /// For shadow volume techniques only, generate a light cap on the volume.
    SRF_INCLUDE_LIGHT_CAP = 0x00000001,
    /// For shadow volume techniques only, generate a dark cap on the volume.
    SRF_INCLUDE_DARK_CAP  = 0x00000002,
    /// For shadow volume techniques only, indicates volume is extruded to infinity.
    SRF_EXTRUDE_TO_INFINITY  = 0x00000004
}

/** This class defines the interface that must be implemented by shadow casters.
 */
class ShadowCaster
{
public:
    ~this() { }
    /** Returns whether or not this object currently casts a shadow. */
    abstract bool getCastShadows();
    
    /** Returns details of the edges which might be used to determine a silhouette. */
    abstract EdgeData getEdgeList();
    /** Returns whether the object has a valid edge list. */
    abstract bool hasEdgeList();
    
    /** Get the world bounding box of the caster. */
    AxisAlignedBox getWorldBoundingBox(bool derive = false);
    /** Gets the world space bounding box of the light cap. */
    AxisAlignedBox getLightCapBounds();
    /** Gets the world space bounding box of the dark cap, as extruded using the light provided. */
    AxisAlignedBox getDarkCapBounds(Light light, Real dirLightExtrusionDist);
    
    //typedef vector<ShadowRenderable*>.type ShadowRenderableList;
    //typedef VectorIterator<ShadowRenderableList> ShadowRenderableListIterator;
    
    alias ShadowRenderable[] ShadowRenderableList;
    
    /** Gets an iterator over the renderables required to render the shadow volume. 
     @remarks
     Shadowable geometry should ideally be designed such that there is only one
     ShadowRenderable required to render the the shadow; however this is not a necessary
     limitation and it can be exceeded if required.
     @param shadowTechnique
     The technique being used to generate the shadow.
     @param light
     The light to generate the shadow from.
     @param indexBuffer
     The index buffer to build the renderables into, 
     the current contents are assumed to be disposable.
     @param _extrudeVertices
     If @c true, this means this class should extrude
     the vertices of the back of the volume in software. If false, it
     will not be done (a vertex program is assumed).
     @param extrusionDistance
     The distance to extrude the shadow volume.
     @param flags
     Technique-specific flags, see ShadowRenderableFlags.
     */
    abstract ShadowRenderableList getShadowVolumeRenderables(
        ShadowTechnique shadowTechnique, ref Light light, 
        SharedPtr!HardwareIndexBuffer* indexBuffer, 
        bool _extrudeVertices, Real extrusionDistance, ulong flags = 0 );
    
    /** Utility method for extruding vertices based on a light. 
     @remarks
     Unfortunately, because D3D cannot handle homogeneous (4D) position
     coordinates in the fixed-function pipeline (GL can, but we have to
     be cross-API), when we extrude in software we cannot extrude to 
     infinity the way we do in the vertex program (by setting w to
     0.0f). Therefore we extrude by a fixed distance, which may cause 
     some problems with larger scenes. Luckily better hardware (ie
     vertex programs) can fix this.
     @param vertexBuffer
     The vertex buffer containing ONLY xyz position
     values, which must be originalVertexCount * 2 * 3 floats long.
     @param originalVertexCount
     The count of the original number of
     vertices, i.e. the number in the mesh, not counting the doubling
     which has already been done (by VertexData.prepareForShadowVolume)
     to provide the extruded area of the buffer.
     @param lightPos
     4D light position in object space, when w=0.0f this
     represents a directional light.
     @param extrudeDist
     The distance to extrude.
     */
    static void extrudeVertices(SharedPtr!HardwareVertexBuffer vertexBuffer, 
                                size_t originalVertexCount, ref Vector4 lightPos, Real extrudeDist)
    {
        assert (vertexBuffer.get().getVertexSize() == float.sizeof * 3
                , "Position buffer should contain only positions!");
        
        // Extrude the first area of the buffer into the second area
        // Lock the entire buffer for writing, even though we'll only be
        // updating the latter because you can't have 2 locks on the same
        // buffer
        float* pSrc = cast(float*)(vertexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_NORMAL));
        
        // TODO: We should add extra (ununsed) vertices ensure source and
        // destination buffer have same alignment for slight performance gain.
        float* pDest = pSrc + originalVertexCount * 3;
        
        OptimisedUtil.getImplementation().extrudeVertices(
            lightPos, extrudeDist,
            pSrc, pDest, originalVertexCount);
        
        vertexBuffer.get().unlock();
        
    }
    
    /** Get the distance to extrude for a point/spot light. */
    abstract Real getPointExtrusionDistance(ref Light l);//;
protected:
    /// Helper method for calculating extrusion distance.
    Real getExtrusionDistance(Vector3 objectPos, ref Light light)
    {
        Vector3 diff = objectPos - light.getDerivedPosition();
        return light.getAttenuationRange() - diff.length();
    }
    /** Tells the caster to perform the tasks necessary to update the 
     edge data's light listing. Can be overridden if the subclass needs 
     to do additional things. 
     @param edgeData
     The edge information to update.
     @param lightPos
     4D vector representing the light, a directional light has w=0.0.
     */
    void updateEdgeListLightFacing(ref EdgeData edgeData, 
                                   ref Vector4 lightPos)
    {
        edgeData.updateTriangleLightFacing(lightPos);
    }
    
    /** Generates the indexes required to render a shadow volume into the 
     index buffer which is passed in, and updates shadow renderables
     to use it.
     @param edgeData
     The edge information to use.
     @param indexBuffer
     The buffer into which to write data into; current 
     contents are assumed to be discardable.
     @param light
     The light, mainly for type info as silhouette calculations
     should already have been done in updateEdgeListLightFacing
     @param shadowRenderables
     A list of shadow renderables which has 
     already beenructed but will need populating with details of
     the index ranges to be used.
     @param flags
     Additional controller flags, see ShadowRenderableFlags.
     */
    void generateShadowVolume(ref EdgeData edgeData, 
                              SharedPtr!HardwareIndexBuffer* indexBuffer, ref Light light,
                              ref ShadowRenderableList shadowRenderables, ulong flags)
    {
        // Edge groups should be 1:1 with shadow renderables
        assert(edgeData.edgeGroups.length == shadowRenderables.length);
        
        Light.LightTypes lightType = light.getType();
        
        // Whether to use the McGuire method, a triangle fan covering all silhouette
        // This won't work properly with multiple separate edge groups (should be one fan per group, not implemented)
        // or when light position is inside light cap bound as extrusion could be in opposite directions
        // and McGuire cap could intersect near clip plane of camera frustum without being noticed.
        bool useMcGuire = edgeData.edgeGroups.length <= 1 && 
            (lightType == Light.LightTypes.LT_DIRECTIONAL || !getLightCapBounds().contains(light.getDerivedPosition()));
        
        // pre-count the size of index data we need since it makes a big perf difference
        // to GL in particular if we lock a smaller area of the index buffer
        size_t preCountIndexes = 0;
        
        //ShadowRenderableList.const_iterator si;
        //si = shadowRenderables.begin();
        foreach (eg; edgeData.edgeGroups[] /++si+/)
        {
            //EdgeData.EdgeGroup& eg = *egi;
            bool  firstDarkCapTri = true;
            
            foreach (edge; eg.edges)
            {
                
                // Silhouette edge, when two tris has opposite light facing, or
                // degenerate edge where only tri 1 is valid and the tri light facing
                char lightFacing = edgeData.triangleLightFacings[edge.triIndex[0]];
                if ((edge.degenerate && lightFacing) ||
                    (!edge.degenerate && (lightFacing != edgeData.triangleLightFacings[edge.triIndex[1]])))
                {
                    
                    preCountIndexes += 3;
                    
                    // Are we extruding to infinity?
                    if (!(lightType == Light.LightTypes.LT_DIRECTIONAL &&
                          flags & ShadowRenderableFlags.SRF_EXTRUDE_TO_INFINITY))
                    {
                        preCountIndexes += 3;
                    }
                    
                    if(useMcGuire)
                    {
                        // Do dark cap tri
                        // Use McGuire et al method, a triangle fan covering all silhouette
                        // edges and one point (taken from the initial tri)
                        if (flags & ShadowRenderableFlags.SRF_INCLUDE_DARK_CAP)
                        {
                            if (firstDarkCapTri)
                            {
                                firstDarkCapTri = false;
                            }
                            else
                            {
                                preCountIndexes += 3;
                            }
                        }
                    }
                }
                
            }
            
            if(useMcGuire)
            {
                // Do light cap
                if (flags & ShadowRenderableFlags.SRF_INCLUDE_LIGHT_CAP) 
                {
                    // Iterate over the triangles which are using this vertex set
                    foreach (i; eg.triStart .. eg.triStart+eg.triCount)
                    {
                        auto ti = edgeData.triangles[i];
                        assert(ti.vertexSet == eg.vertexSet);
                        // Check it's light facing
                        if ( /* i < edgeData.triangleLightFacings.length && */
                            edgeData.triangleLightFacings[i])
                        {
                            preCountIndexes += 3;
                        }
                    }
                    
                }
            }
            else
            {
                // Do both caps
                int increment = ((flags & ShadowRenderableFlags.SRF_INCLUDE_DARK_CAP) ? 3 : 0) + ((flags & ShadowRenderableFlags.SRF_INCLUDE_LIGHT_CAP) ? 3 : 0);
                if(increment != 0)
                {
                    // Iterate over the triangles which are using this vertex set
                    foreach (i; eg.triStart .. eg.triStart+eg.triCount)
                    {
                        auto ti = edgeData.triangles[i];
                        assert(ti.vertexSet == eg.vertexSet);
                        // Check it's light facing
                        if (edgeData.triangleLightFacings[i])
                            preCountIndexes += increment;
                    }
                }
            }
        }
        // End pre-count
        
        //Check if index buffer is to small 
        if (preCountIndexes > indexBuffer.get().getNumIndexes())
        {
            LogManager.getSingleton().logMessage(LML_CRITICAL, 
                                                 "Warning: shadow index buffer size to small. Auto increasing buffer size to" ~ 
                                                 std.conv.to!string(ushort.sizeof * preCountIndexes));
            
            SceneManager pManager = Root.getSingleton()._getCurrentSceneManager();
            if (pManager)
            {
                pManager.setShadowIndexBufferSize(preCountIndexes);
            }
            
            //Check that the index buffer size has actually increased
            if (preCountIndexes > indexBuffer.get().getNumIndexes())
            {
                //increasing index buffer size has failed
                throw new InvalidParamsError(
                    "Lock request out of bounds.",
                    "ShadowCaster.generateShadowVolume");
            }
        }
        
        // Lock index buffer for writing, just enough length as we need
        ushort* pIdx = cast(ushort*)(indexBuffer.get().lock(0, ushort.sizeof * preCountIndexes, 
                                                      HardwareBuffer.LockOptions.HBL_DISCARD));
        size_t numIndices = 0;
        
        // Iterate over the groups and form renderables for each based on their
        // lightFacing
        int sidx = 0; //shadowRenderables.begin();
        foreach (eg; edgeData.edgeGroups)
        {
            auto si = shadowRenderables[sidx];
            // Initialise the index start for this shadow renderable
            IndexData indexData = si.getRenderOperationForUpdate().indexData;
            
            if (indexData.indexBuffer != (*indexBuffer))
            {
                //FIXME passing pointers arround?
                si.rebindIndexBuffer(indexBuffer);
                indexData = si.getRenderOperationForUpdate().indexData;
            }
            
            indexData.indexStart = numIndices;
            // original number of verts (without extruded copy)
            size_t originalVertexCount = eg.vertexData.vertexCount;
            bool  firstDarkCapTri = true;
            ushort darkCapStart = 0;
            
            foreach (edge; eg.edges)
            {
                // Silhouette edge, when two tris has opposite light facing, or
                // degenerate edge where only tri 1 is valid and the tri light facing
                ubyte lightFacing = edgeData.triangleLightFacings[edge.triIndex[0]];
                if ((edge.degenerate && lightFacing) ||
                    (!edge.degenerate && (lightFacing != edgeData.triangleLightFacings[edge.triIndex[1]])))
                {
                    size_t v0 = edge.vertIndex[0];
                    size_t v1 = edge.vertIndex[1];
                    if (!lightFacing)
                    {
                        // Inverse edge indexes when t1 is light away
                        std.algorithm.swap(v0, v1);
                    }
                    
                    /* Note edge(v0, v1) run anticlockwise along the edge from
                     the light facing tri so to point shadow volume tris outward,
                     light cap indexes have to be backwards

                     We emit 2 tris if light is a point light, 1 if light 
                     is directional, because directional lights cause all
                     points to converge to a single point at infinity.

                     First side tri = near1, near0, far0
                     Second tri = far0, far1, near1

                     'far' indexes are 'near' index + originalVertexCount
                     because 'far' verts are in the second half of the 
                     buffer
                     */
                    assert(v1 < 65536 && v0 < 65536 && (v0 + originalVertexCount) < 65536 ,
                           "Vertex count exceeds 16-bit index limit!");
                    *pIdx++ = cast(ushort)(v1);
                    *pIdx++ = cast(ushort)(v0);
                    *pIdx++ = cast(ushort)(v0 + originalVertexCount);
                    numIndices += 3;
                    
                    // Are we extruding to infinity?
                    if (!(lightType == Light.LightTypes.LT_DIRECTIONAL &&
                          flags & ShadowRenderableFlags.SRF_EXTRUDE_TO_INFINITY))
                    {
                        // additional tri to make quad
                        *pIdx++ = cast(ushort)(v0 + originalVertexCount);
                        *pIdx++ = cast(ushort)(v1 + originalVertexCount);
                        *pIdx++ = cast(ushort)(v1);
                        numIndices += 3;
                    }
                    
                    if(useMcGuire)
                    {
                        // Do dark cap tri
                        // Use McGuire et al method, a triangle fan covering all silhouette
                        // edges and one point (taken from the initial tri)
                        if (flags & ShadowRenderableFlags.SRF_INCLUDE_DARK_CAP)
                        {
                            if (firstDarkCapTri)
                            {
                                darkCapStart = cast(ushort)(v0 + originalVertexCount);
                                firstDarkCapTri = false;
                            }
                            else
                            {
                                *pIdx++ = darkCapStart;
                                *pIdx++ = cast(ushort)(v1 + originalVertexCount);
                                *pIdx++ = cast(ushort)(v0 + originalVertexCount);
                                numIndices += 3;
                            }
                            
                        }
                    }
                }
                
            }
            
            if(!useMcGuire)
            {
                // Do dark cap
                if (flags & ShadowRenderableFlags.SRF_INCLUDE_DARK_CAP) 
                {
                    // Iterate over the triangles which are using this vertex set
                    foreach (i; eg.triStart .. eg.triStart+eg.triCount)
                    {
                        EdgeData.Triangle t = edgeData.triangles[i];
                        assert(t.vertexSet == eg.vertexSet);
                        // Check it's light facing
                        if (edgeData.triangleLightFacings[i])
                        {
                            assert(t.vertIndex[0] < 65536 && t.vertIndex[1] < 65536 &&
                                   t.vertIndex[2] < 65536 ,
                                   "16-bit index limit exceeded!");
                            *pIdx++ = cast(ushort)(t.vertIndex[1] + originalVertexCount);
                            *pIdx++ = cast(ushort)(t.vertIndex[0] + originalVertexCount);
                            *pIdx++ = cast(ushort)(t.vertIndex[2] + originalVertexCount);
                            numIndices += 3;
                        }
                    }
                    
                }
            }
            
            // Do light cap
            if (flags & ShadowRenderableFlags.SRF_INCLUDE_LIGHT_CAP) 
            {
                // separate light cap?
                if (si.isLightCapSeparate())
                {
                    // update index count for this shadow renderable
                    indexData.indexCount = numIndices - indexData.indexStart;
                    
                    // get light cap index data for update
                    indexData = si.getLightCapRenderable().getRenderOperationForUpdate().indexData;
                    // start indexes after the current total
                    indexData.indexStart = numIndices;
                }
                
                // Iterate over the triangles which are using this vertex set
                foreach (i; eg.triStart .. eg.triStart+eg.triCount)
                {
                    EdgeData.Triangle t = edgeData.triangles[i];
                    assert(t.vertexSet == eg.vertexSet);
                    // Check it's light facing
                    if (edgeData.triangleLightFacings[i])
                    {
                        assert(t.vertIndex[0] < 65536 && t.vertIndex[1] < 65536 &&
                               t.vertIndex[2] < 65536 ,
                               "16-bit index limit exceeded!");
                        *pIdx++ = cast(ushort)(t.vertIndex[0]);
                        *pIdx++ = cast(ushort)(t.vertIndex[1]);
                        *pIdx++ = cast(ushort)(t.vertIndex[2]);
                        numIndices += 3;
                    }
                }
                
            }
            
            // update index count for current index data (either this shadow renderable or its light cap)
            indexData.indexCount = numIndices - indexData.indexStart;
            sidx++;
        }
        
        
        // Unlock index buffer
        indexBuffer.get().unlock();
        
        // In debug mode, check we didn't overrun the index buffer
        assert(numIndices == preCountIndexes);
        assert(numIndices <= indexBuffer.get().getNumIndexes() ,
               "Index buffer overrun while generating shadow volume!! " ~
               "You must increase the size of the shadow index buffer.");
        
    }
    /** Utility method for extruding a bounding box. 
     @param box
     Original bounding box, will be updated in-place.
     @param lightPos
     4D light position in object space, when w=0.0f this
     represents a directional light.
     @param extrudeDist
     The distance to extrude.
     */
    void extrudeBounds(out AxisAlignedBox box,Vector4 light, 
                       Real extrudeDist)
    {
        Vector3 extrusionDir;
        
        if (light.w == 0)
        {
            // Parallel projection guarantees min/max relationship remains the same
            extrusionDir.x = -light.x;
            extrusionDir.y = -light.y;
            extrusionDir.z = -light.z;
            extrusionDir.normalise();
            extrusionDir *= extrudeDist;
            box.setExtents(box.getMinimum() + extrusionDir, 
                           box.getMaximum() + extrusionDir);
        }
        else
        {
            Vector3 oldMin, oldMax, currentCorner;
            // Getting the original values
            oldMin = box.getMinimum();
            oldMax = box.getMaximum();
            // Starting the box again with a null content
            box.setNull();
            
            // merging all the extruded corners
            
            // 0 : min min min
            currentCorner = oldMin;
            extrusionDir.x = currentCorner.x - light.x;
            extrusionDir.y = currentCorner.y - light.y;
            extrusionDir.z = currentCorner.z - light.z;
            box.merge(currentCorner + extrudeDist * extrusionDir.normalisedCopy());
            
            // 6 : min min max
            // only z has changed
            currentCorner.z = oldMax.z;
            extrusionDir.z = currentCorner.z - light.z;
            box.merge(currentCorner + extrudeDist * extrusionDir.normalisedCopy());
            
            // 5 : min max max
            currentCorner.y = oldMax.y;
            extrusionDir.y = currentCorner.y - light.y;
            box.merge(currentCorner + extrudeDist * extrusionDir.normalisedCopy());
            
            // 1 : min max min
            currentCorner.z = oldMin.z;
            extrusionDir.z = currentCorner.z - light.z;
            box.merge(currentCorner + extrudeDist * extrusionDir.normalisedCopy());
            
            // 2 : max max min
            currentCorner.x = oldMax.x;
            extrusionDir.x = currentCorner.x - light.x;
            box.merge(currentCorner + extrudeDist * extrusionDir.normalisedCopy());
            
            // 4 : max max max
            currentCorner.z = oldMax.z;
            extrusionDir.z = currentCorner.z - light.z;
            box.merge(currentCorner + extrudeDist * extrusionDir.normalisedCopy());
            
            // 7 : max min max
            currentCorner.y = oldMin.y;
            extrusionDir.y = currentCorner.y - light.y;
            box.merge(currentCorner + extrudeDist * extrusionDir.normalisedCopy());
            
            // 3 : max min min
            currentCorner.z = oldMin.z;
            extrusionDir.z = currentCorner.z - light.z;
            box.merge(currentCorner + extrudeDist * extrusionDir.normalisedCopy());
            
        }
        
    }
    
    
}
/** @} */
/** @} */
