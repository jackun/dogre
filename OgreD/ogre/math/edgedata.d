module ogre.math.edgedata;

import ogre.compat;
import ogre.math.vector;
import ogre.math.maths;
import ogre.rendersystem.renderoperation;
import ogre.rendersystem.vertex;
import ogre.rendersystem.hardware;
import ogre.general.log;
import ogre.math.optimisedutil;
import ogre.exception;
import ogre.sharedptr;


/** \addtogroup Core
 *  @{
 */
/** \addtogroup Math
 *  @{
 */

/** This class contains the information required to describe the edge connectivity of a
 given set of vertices and indexes. 
 @remarks 
 This information is built using the EdgeListBuilder class. Note that for a given mesh,
 which can be made up of multiple submeshes, there are separate edge lists for when 
 */
class EdgeData// : public EdgeDataAlloc
{
public:
    
    this()
    {
        isClosed = false;
    }
    
    /** Basic triangle structure. */
    struct Triangle {
        /** The set of indexes this triangle came from (NB it is possible that the triangles on 
         one side of an edge are using a different vertex buffer from those on the other side.) */
        size_t indexSet; 
        /** The vertex set these vertices came from. */
        size_t vertexSet;
        size_t[3] vertIndex;/// Vertex indexes, relative to the original buffer
        size_t[3] sharedVertIndex; /// Vertex indexes, relative to a shared vertex buffer with 
        // duplicates eliminated (this buffer is not exposed)
        
        //Triangle() :indexSet(0), vertexSet(0) {}
    }
    
    /** Edge data. */
    struct Edge {
        /** The indexes of the 2 tris attached, note that tri 0 is the one where the 
         indexes run _anti_ clockwise along the edge. Indexes must be
         reversed for tri 1. */
        size_t[2] triIndex;
        /** The vertex indices for this edge. Note that both vertices will be in the vertex
         set as specified in 'vertexSet', which will also be the same as tri 0 */
        size_t[2] vertIndex;
        /** Vertex indices as used in the shared vertex list, not exposed. */
        size_t[2] sharedVertIndex;
        /** Indicates if this is a degenerate edge, ie it does not have 2 triangles */
        bool degenerate;
    }
    
    // Array of 4D vector of triangle face normal, which is unit vector orthogonal
    // to the triangles, plus distance from origin.
    // Use aligned policy here because we are intended to use in SIMD optimised routines .
    //typedef std.vector<Vector4, STLAllocator<Vector4, CategorisedAlignAllocPolicy<MEMCATEGORY_GEOMETRY> > > TriangleFaceNormalList;
    //alias Array!Vector4 TriangleFaceNormalList;
    alias Vector4[] TriangleFaceNormalList;
    
    // Working vector used when calculating the silhouette.
    // Use std.vector<char> instead of std.vector<bool> which might implemented
    // similar bit-fields causing loss performance.
    //typedef vector<char>::type TriangleLightFacingList;
    //alias Array!ubyte TriangleLightFacingList;
    alias ubyte[] TriangleLightFacingList;
    
    //typedef vector<Triangle>::type TriangleList;
    //typedef vector<Edge>::type EdgeList;
    //alias Array!Triangle TriangleList;
    alias Triangle[] TriangleList;
    //alias Array!Edge EdgeList;
    alias Edge[] EdgeList;
    
    /** A group of edges sharing the same vertex data. */
    struct EdgeGroup
    {
        /** The vertex set index that contains the vertices for this edge group. */
        size_t vertexSet;
        /** Pointer to vertex data used by this edge group. */
        //
        VertexData vertexData;
        /** Index to main triangles array, indicate the first triangle of this edge
         group, and all triangles of this edge group are stored continuous in
         main triangles array.
         */
        size_t triStart;
        /** Number triangles of this edge group. */
        size_t triCount;
        /** The edges themselves. */
        EdgeList edges;
        
    }
    
    //typedef vector<EdgeGroup>::type EdgeGroupList;
    //alias Array!EdgeGroup EdgeGroupList;
    alias EdgeGroup[] EdgeGroupList;
    
    /** Main triangles array, stores all triangles of this edge list. Note that
     triangles are grouping against edge group.
     */
    TriangleList triangles;
    /** All triangle face normals. It should be 1:1 with triangles. */
    TriangleFaceNormalList triangleFaceNormals;
    /** Triangle light facing states. It should be 1:1 with triangles. */
    TriangleLightFacingList triangleLightFacings;
    /** All edge groups of this edge list. */
    EdgeGroupList edgeGroups;
    /** Flag indicate the mesh is manifold. */
    bool isClosed;
    
    
    /** Calculate the light facing state of the triangles in this edge list
     @remarks
     This is normally the first stage of calculating a silhouette, i.e.
     establishing which tris are facing the light and which are facing
     away. This state is stored in the 'triangleLightFacings'.
     @param lightPos 4D position of the light in object space, note that 
     for directional lights (which have no position), the w component
     is 0 and the x/y/z position are the direction.
     */
    void updateTriangleLightFacing(Vector4 lightPos)
    {
        // Triangle face normals should be 1:1 with light facing flags
        assert(triangleFaceNormals.length == triangleLightFacings.length);
        
        // Use optimised util to determine if triangle's face normal are light facing
        if(triangleFaceNormals.length)
        {
            OptimisedUtil.getImplementation().calculateLightFacing(
                lightPos,
                triangleFaceNormals,
                triangleLightFacings,
                triangleLightFacings.length);
        }
    }
    
    /** Updates the face normals for this edge list based on (changed)
     position information, useful for animated objects. 
     @param vertexSet The vertex set we are updating
     @param positionBuffer The updated position buffer, must contain ONLY xyz
     */
    void updateFaceNormals(size_t vertexSet, ref /*const*/ SharedPtr!HardwareVertexBuffer positionBuffer)
    {
        assert (positionBuffer.get().getVertexSize() == float.sizeof * 3
                , "Position buffer should contain only positions!");
        
        // Triangle face normals should be 1:1 with triangles
        assert(triangleFaceNormals.length == triangles.length);
        
        // Lock buffer for reading
        float* pVert = cast(float*)(positionBuffer.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
        
        // Calculate triangles which are using this vertex set
        EdgeData.EdgeGroup eg = edgeGroups[vertexSet];
        if (eg.triCount != 0) 
        {
            OptimisedUtil.getImplementation().calculateFaceNormals(
                pVert,
                &triangles[eg.triStart],
                &triangleFaceNormals[eg.triStart],
                eg.triCount);
        }
        
        // unlock the buffer
        positionBuffer.get().unlock();
    }
    
    
    
    // Debugging method
    void log(ref Log l)
    {
        l.logMessage("Edge Data");
        l.logMessage("---------");
        size_t num = 0;
        foreach (t; triangles)
        {
            l.logMessage(
                std.conv.text("Triangle ", num, " = {indexSet=", t.indexSet, " vertexSet=", 
                          t.vertexSet, ", v0=", t.vertIndex[0], ", v1=", t.vertIndex[1], ", v2=",
                          t.vertIndex[2],"}")
                ); 
            num++;
        }
        
        foreach (i; edgeGroups)
        {
            num = 0;
            l.logMessage("Edge Group vertexSet=" ~ std.conv.to!string(i.vertexSet));
            foreach (e; i.edges)
            {
                l.logMessage(
                    std.conv.text("Edge ", num, " = {\n  tri0=", 
                              e.triIndex[0], ", \n  tri1=", 
                              e.triIndex[1], ", \n  v0=",
                              e.vertIndex[0], ", \n  v1=",
                              e.vertIndex[1], ", \n  degenerate=",
                              e.degenerate, " \n}")
                    );
                num++;
            }
        }
    }
    
}

/** General utility class for building edge lists for geometry.
 @remarks
 You can add multiple sets of vertex and index data to build and edge list. 
 Edges will be built between the various sets as well as within sets; this allows 
 you to use a model which is built from multiple SubMeshes each using 
 separate index and (optionally) vertex data and still get the same connectivity 
 information. It's important to note that the indexes for the edge will berained
 to a single vertex buffer though (this is required in order to render the edge).
 */
class EdgeListBuilder 
{
public:
    
    this()
    {
        //: mEdgeData(0)
    }
    
    ~this() {}
    /** Add a set of vertex geometry data to the edge builder. 
     @remarks
     You must add at least one set of vertex data to the builder before invoking the
     build method.
     */
    void addVertexData(ref /*const*/ VertexData vertexData)
    {
        if (vertexData.vertexStart != 0)
        {
            throw new InvalidParamsError(
                "The base vertex index of the vertex data must be zero for build edge list.",
                "EdgeListBuilder.addVertexData");
        }
        
        mVertexDataList.insert(vertexData);
    }
    /** Add a set of index geometry data to the edge builder. 
     @remarks
     You must add at least one set of index data to the builder before invoking the
     build method.
     @param indexData The index information which describes the triangles.
     @param vertexSet The vertex data set this index data ref ers to; you only need to alter this
     if you have added multiple sets of vertices
     @param opType The operation type used to render these indexes. Only triangle types
     are supported (no point or line types)
     */
    void addIndexData(ref /*const*/ IndexData indexData, size_t vertexSet = 0, 
                      RenderOperation.OperationType opType = RenderOperation.OperationType.OT_TRIANGLE_LIST)
    {
        if (opType != RenderOperation.OperationType.OT_TRIANGLE_LIST &&
            opType != RenderOperation.OperationType.OT_TRIANGLE_FAN &&
            opType != RenderOperation.OperationType.OT_TRIANGLE_STRIP)
        {
            throw new InvalidParamsError(
                "Only triangle list, fan and strip are supported to build edge list.",
                "EdgeListBuilder.addIndexData");
        }
        
        Geometry geometry;
        geometry.indexData = indexData;
        geometry.vertexSet = vertexSet;
        geometry.opType = opType;
        geometry.indexSet = mGeometryList.length;
        mGeometryList.insert(geometry);
    }
    
    /** Builds the edge information based on the information built up so far.
     @remarks
     The caller takes responsibility for deleting the returned structure.
     */
    ref EdgeData build()
    {
        /* Ok, here's the algorithm:
         For each set of indices in turn
         For each set of 3 indexes
         Create a new Triangle entry in the list
         For each vertex referenced by the tri indexes
         Get the position of the vertex as a Vector3 from the correct vertex buffer
         Attempt to locate this position in the existing common vertex set
         If not found
         Create a new common vertex entry in the list
         End If
         Populate the original vertex index and common vertex index 
         Next vertex
         Connect to existing edge(v1, v0) or create a new edge(v0, v1)
         Connect to existing edge(v2, v1) or create a new edge(v1, v2)
         Connect to existing edge(v0, v2) or create a new edge(v2, v0)
         Next set of 3 indexes
         Next index set

         Note that all edges 'belong' to the index set which originally caused them
         to be created, which also means that the 2 vertices on the edge are both ref erencing the 
         vertex buffer which this index set uses.
         */
        
        
        /* 
         There is a major consideration: 'What is a common vertex'? This is a
         crucial decision, since to form a completely close hull, you need to treat
         vertices which are not physically the same as equivalent. This is because
         there will be 'seams' in the model, where discrepancies in vertex components
         other than position (such as normals or texture coordinates) will mean
         that there are 2 vertices in the same place, and we MUST 'weld' them
         into a single common vertex in order to have a closed hull. Just looking
         at the unique vertex indices is not enough, since these seams would render
         the hull invalid.

         So, we look for positions which are the same across vertices, and treat 
         those as as single vertex for our edge calculation. However, this has
         it's own problems. There are OTHER vertices which may have a common 
         position that should not be welded. Imagine 2 cubes touching along one
         single edge. The common vertices on that edge, if welded, will cause 
         an ambiguous hull, since the edge will have 4 triangles attached to it,
         whilst a manifold mesh should only have 2 triangles attached to each edge.
         This is a problem.

         We deal with this with allow welded multiple pairs of edges. Using this
         techniques, we can build a individual hull even if the model which has a
         potentially ambiguous hull. This is feasible, because in the case of
         multiple hulls existing, each hull can cast same shadow in any situation.
         Notice: For stencil shadow, we intent to build a valid shadow volume for
         the mesh, not the valid hull for the mesh.
         */
        
        // Sort the geometries in the order of vertex set, so we can grouping
        // triangles by vertex set easy.
        std.algorithm.sort!geometryLess(mGeometryList);
        // Initialize edge data
        mEdgeData = new EdgeData();
        // resize the edge group list to equal the number of vertex sets
        //TODO std::vector.resize()
        mEdgeData.edgeGroups.length = mVertexDataList.length;
        // Initialise edge group data
        for (ushort vSet = 0; vSet < mVertexDataList.length; ++vSet)
        {
            mEdgeData.edgeGroups[vSet].vertexSet = vSet;
            mEdgeData.edgeGroups[vSet].vertexData = mVertexDataList[vSet];
            mEdgeData.edgeGroups[vSet].triStart = 0;
            mEdgeData.edgeGroups[vSet].triCount = 0;
        }
        
        // Build triangles and edge list
        
        foreach (i; mGeometryList)
        {
            buildTrianglesEdges(i);
        }
        
        // Allocate memory for light facing calculate
        //TODO std::vector.resize()
        mEdgeData.triangleLightFacings.length = mEdgeData.triangles.length;
        
        // Record closed, ie the mesh is manifold
        mEdgeData.isClosed = mEdgeMap.emptyAA();
        
        return mEdgeData;
    }
    
    /// Debugging method
    void log(ref Log l)
    {
        l.logMessage("EdgeListBuilder Log");
        l.logMessage("-------------------");
        l.logMessage("Number of vertex sets: " ~ std.conv.to!string(mVertexDataList.length));
        l.logMessage("Number of index sets: " ~ std.conv.to!string(mGeometryList.length));
        
        size_t i, j;
        // Log original vertex data
        for(i = 0; i < mVertexDataList.length; ++i)
        {
            VertexData vData = mVertexDataList[i];
            l.logMessage(".");
            l.logMessage(std.conv.text("Original vertex set ", i, " - vertex count ", vData.vertexCount));
            VertexElement posElem = vData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
            SharedPtr!HardwareVertexBuffer vbuf = 
                vData.vertexBufferBinding.getBuffer(posElem.getSource());
            // lock the buffer for reading
            ubyte* pBaseVertex = cast(ubyte*)(
                vbuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
            float* pFloat;
            for (j = 0; j < vData.vertexCount; ++j)
            {
                posElem.baseVertexPointerToElement(pBaseVertex, &pFloat);
                l.logMessage(std.conv.text("Vertex ", j,
                                           ": (", pFloat[0],
                                           ", ", pFloat[1],
                                           ", ", pFloat[2], ")"));
                pBaseVertex += vbuf.get().getVertexSize();
            }
            vbuf.get().unlock();
        }
        
        // Log original index data
        for(i = 0; i < mGeometryList.length; i++)
        {
            IndexData iData = mGeometryList[i].indexData;
            l.logMessage(".");
            l.logMessage(std.conv.text("Original triangle set ", mGeometryList[i].indexSet, 
                                       " - index count ", iData.indexCount, 
                                       " - vertex set ", mGeometryList[i].vertexSet, 
                                       " - operationType ",mGeometryList[i].opType));
            // Get the indexes ready for reading
            ushort* p16Idx = null;
            uint* p32Idx = null;
            
            if (iData.indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_32BIT)
            {
                p32Idx = cast(uint*)(
                    iData.indexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
            }
            else
            {
                p16Idx = cast(ushort*)(
                    iData.indexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
            }
            
            for (j = 0; j < iData.indexCount;  )
            {
                if (iData.indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_32BIT)
                {
                    if (mGeometryList[i].opType == RenderOperation.OperationType.OT_TRIANGLE_LIST
                        || j == 0)
                    {
                        uint n1 = *p32Idx++;
                        uint n2 = *p32Idx++;
                        uint n3 = *p32Idx++;
                        l.logMessage(std.conv.text("Triangle ", j,
                                                   ": (", n1,
                                                   ", ", n2,
                                                   ", ", n3, ")"));
                        j += 3;
                    }
                    else
                    {
                        l.logMessage(std.conv.text("Triangle ",j,
                                                   ": (", *p32Idx++, ")"));
                        j++;
                    }
                }
                else
                {
                    if (mGeometryList[i].opType == RenderOperation.OperationType.OT_TRIANGLE_LIST
                        || j == 0)
                    {
                        ushort n1 = *p16Idx++;
                        ushort n2 = *p16Idx++;
                        ushort n3 = *p16Idx++;
                        l.logMessage(std.conv.text("Index ", j, ": (", n1, ", ", n2, 
                                                   ", ", n3, ")"));
                        j += 3;
                    }
                    else
                    {
                        l.logMessage(std.conv.text("Triangle ",j,
                                                   ": (", *p16Idx++, ")"));
                        j++;
                    }
                }
                
                
            }
            
            iData.indexBuffer.get().unlock();
            
            
            // Log common vertex list
            l.logMessage(".");
            l.logMessage("Common vertex list - vertex count " ~ 
                         std.conv.to!string(mVertices.length));
            for (i = 0; i < mVertices.length; ++i)
            {
                CommonVertex c = mVertices[i];
                l.logMessage("Common vertex " ~ std.conv.to!string(i) ~
                             ": (vertexSet=" ~ std.conv.to!string(c.vertexSet) ~
                             ", originalIndex=" ~ std.conv.to!string(c.originalIndex) ~
                             ", position=" ~ std.conv.to!string(c.position));
            }
        }
        
    }
    
protected:
    
    /** A vertex can actually represent several vertices in the final model, because
     vertices along texture seams etc will have been duplicated. In order to properly
     evaluate the surface properties, a single common vertex is used for these duplicates,
     and the faces hold the detail of the duplicated vertices.
     */
    struct CommonVertex {
        Vector3  position;  // location of point in euclidean space
        size_t index;       // place of vertex in common vertex list
        size_t vertexSet;   // The vertex set this came from
        size_t indexSet;    // The index set this was referenced (first) from
        size_t originalIndex; // place of vertex in original vertex set
    }
    /** A set of indexed geometry data */
    struct Geometry {
        size_t vertexSet;           // The vertex data set this geometry data ref ers to
        size_t indexSet;            // The index data set this geometry data ref ers to
        //
        IndexData indexData; // The index information which describes the triangles.
        RenderOperation.OperationType opType;  // The operation type used to render this geometry
    }
    
    /** Comparator for sorting geometries by vertex set */
    static bool geometryLess (/*ref*/ Geometry a, /*ref*/ Geometry b)//
    {
        if (a.vertexSet < b.vertexSet) return true;
        if (a.vertexSet > b.vertexSet) return false;
        return a.indexSet < b.indexSet;
    }
    /** Comparator for unique vertex list */
    static bool vectorLess (/*ref*/ Vector3 a, /*ref*/ Vector3 b) //const
    {
        if (a.x < b.x) return true;
        if (a.x > b.x) return false;
        if (a.y < b.y) return true;
        if (a.y > b.y) return false;
        return a.z < b.z;
    }
    
    //typedef vector<VertexData*>::type VertexDataList;
    //typedef vector<Geometry>::type GeometryList;
    //typedef vector<CommonVertex>::type CommonVertexList;
    
    alias VertexData[] VertexDataList;
    alias Geometry[] GeometryList;
    alias CommonVertex[] CommonVertexList;
    
    GeometryList mGeometryList;
    VertexDataList mVertexDataList;
    CommonVertexList mVertices;
    EdgeData mEdgeData;
    /// Map for identifying common vertices
    //typedef map<Vector3, size_t, vectorLess>::type CommonVertexMap;
    alias size_t[Vector3] CommonVertexMap;
    CommonVertexMap mCommonVertexMap;
    /** Edge map, used to connect edges. Note we allow many triangles on an edge,
     after connected an existing edge, we will remove it and never used again.
     */
    //typedef multimap< std::pair<size_t, size_t>, std::pair<size_t, size_t> >::type EdgeMap;
    alias pair!(size_t, size_t)[pair!(size_t, size_t)] EdgeMap;
    EdgeMap mEdgeMap;
    
    void buildTrianglesEdges(ref /*const*/ Geometry geometry)
    {
        size_t indexSet = geometry.indexSet;
        size_t vertexSet = geometry.vertexSet;
        IndexData indexData = geometry.indexData;
        RenderOperation.OperationType opType = geometry.opType;
        
        size_t iterations;
        
        switch (opType)
        {
            case RenderOperation.OperationType.OT_TRIANGLE_LIST:
                iterations = indexData.indexCount / 3;
                break;
            case RenderOperation.OperationType.OT_TRIANGLE_FAN:
            case RenderOperation.OperationType.OT_TRIANGLE_STRIP:
                iterations = indexData.indexCount - 2;
                break;
            default:
                return; // Just in case
        }
        
        // The edge group now we are dealing with.
        EdgeData.EdgeGroup eg = mEdgeData.edgeGroups[vertexSet];
        
        // locate position element & the buffer to go with it
        VertexData vertexData = mVertexDataList[vertexSet];
        VertexElement posElem = vertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
        SharedPtr!HardwareVertexBuffer vbuf = 
            vertexData.vertexBufferBinding.getBuffer(posElem.getSource());
        // lock the buffer for reading
        ubyte* pBaseVertex = cast(ubyte*)(
            vbuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
        
        // Get the indexes ready for reading
        bool idx32bit = (indexData.indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_32BIT);
        size_t indexSize = idx32bit ? uint.sizeof : ushort.sizeof;
        /*#if defined(_MSC_VER) && _MSC_VER <= 1300
         // NB: Can't use un-named union with VS.NET 2002 when /RTC1 compile flag enabled.
         void* pIndex = indexData.indexBuffer.lock(HardwareBuffer.LockOptions.HBL_READ_ONLY);
         pIndex = static_cast<void*>(
         static_cast<char*>(pIndex) + indexData.indexStart * indexSize);
         ushort* p16Idx = cast(ushort*)(pIndex);
         uint* p32Idx = cast(uint*)(pIndex);
         #else*/
        union U {
            void* pIndex;
            ushort* p16Idx;
            uint* p32Idx;
        }
        U _pIndex;

        _pIndex.pIndex = indexData.indexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY);
        _pIndex.pIndex = cast(void*)(cast(ubyte*)(_pIndex.pIndex) + indexData.indexStart * indexSize);
        //#endif
        
        // Iterate over all the groups of 3 indexes
        uint index[3];
        // Get the triangle start, if we have more than one index set then this
        // will not be zero
        size_t triangleIndex = mEdgeData.triangles.length;
        // If it's first time dealing with the edge group, setup triStart for it.
        // Note that we are assume geometries sorted by vertex set.
        if (!eg.triCount)
        {
            eg.triStart = triangleIndex;
        }
        // Pre-reserve memory for less thrashing
        mEdgeData.triangles.length = (triangleIndex + iterations);
        mEdgeData.triangleFaceNormals.length = (triangleIndex + iterations);
        for (size_t t = 0; t < iterations; ++t)
        {
            EdgeData.Triangle tri;
            tri.indexSet = indexSet;
            tri.vertexSet = vertexSet;
            
            if (opType == RenderOperation.OperationType.OT_TRIANGLE_LIST || t == 0)
            {
                // Standard 3-index read for tri list or first tri in strip / fan
                if (idx32bit)
                {
                    index[0] = _pIndex.p32Idx[0];
                    index[1] = _pIndex.p32Idx[1];
                    index[2] = _pIndex.p32Idx[2];
                    _pIndex.p32Idx += 3;
                }
                else
                {
                    index[0] = _pIndex.p16Idx[0];
                    index[1] = _pIndex.p16Idx[1];
                    index[2] = _pIndex.p16Idx[2];
                    _pIndex.p16Idx += 3;
                }
            }
            else
            {
                // Strips are formed from last 2 indexes plus the current one for
                // triangles after the first.
                // For fans, all the triangles share the first vertex, plus last
                // one index and the current one for triangles after the first.
                // We also make sure that all the triangles are process in the
                // _anti_ clockwise orientation
                index[(opType == RenderOperation.OperationType.OT_TRIANGLE_STRIP) && (t & 1) ? 0 : 1] = index[2];
                // Read for the last tri index
                if (idx32bit)
                    index[2] = *_pIndex.p32Idx++;
                else
                    index[2] = *_pIndex.p16Idx++;
            }
            
            Vector3 v[3];
            for (size_t i = 0; i < 3; ++i)
            {
                // Populate tri original vertex index
                tri.vertIndex[i] = index[i];
                
                // Retrieve the vertex position
                ubyte* pVertex = pBaseVertex + (index[i] * vbuf.get().getVertexSize());
                float* pFloat;
                posElem.baseVertexPointerToElement(pVertex, &pFloat);
                v[i].x = *pFloat++;
                v[i].y = *pFloat++;
                v[i].z = *pFloat++;
                // find this vertex in the existing vertex map, or create it
                tri.sharedVertIndex[i] = 
                    findOrCreateCommonVertex(v[i], vertexSet, indexSet, index[i]);
            }
            
            // Ignore degenerate triangle
            if (tri.sharedVertIndex[0] != tri.sharedVertIndex[1] &&
                tri.sharedVertIndex[1] != tri.sharedVertIndex[2] &&
                tri.sharedVertIndex[2] != tri.sharedVertIndex[0])
            {
                // Calculate triangle normal (NB will require recalculation for 
                // skeletally animated meshes)
                mEdgeData.triangleFaceNormals ~= (
                    Math.calculateFaceNormalWithoutNormalize(v[0], v[1], v[2]));
                // Add triangle to list
                mEdgeData.triangles ~= (tri);
                // Connect or create edges from common list
                connectOrCreateEdge(vertexSet, triangleIndex, 
                                    tri.vertIndex[0], tri.vertIndex[1], 
                                    tri.sharedVertIndex[0], tri.sharedVertIndex[1]);
                connectOrCreateEdge(vertexSet, triangleIndex, 
                                    tri.vertIndex[1], tri.vertIndex[2], 
                                    tri.sharedVertIndex[1], tri.sharedVertIndex[2]);
                connectOrCreateEdge(vertexSet, triangleIndex, 
                                    tri.vertIndex[2], tri.vertIndex[0], 
                                    tri.sharedVertIndex[2], tri.sharedVertIndex[0]);
                ++triangleIndex;
            }
        }
        
        // Update triCount for the edge group. Note that we are assume
        // geometries sorted by vertex set.
        eg.triCount = triangleIndex - eg.triStart;
        
        indexData.indexBuffer.get().unlock();
        vbuf.get().unlock();
    }
    
    /// Finds an existing common vertex, or inserts a new one
    size_t findOrCreateCommonVertex(Vector3 vec, size_t vertexSet, 
                                    size_t indexSet, size_t originalIndex)
    {
        // Because the algorithm doesn't care about manifold or not, we just identifying
        // the common vertex by EXACT same position.
        // Hint: We can use quantize method for welding almost same position vertex fastest.
        auto ptr = vec in mCommonVertexMap;
        //std.pair<CommonVertexMap.iterator, bool> inserted =
        //    mCommonVertexMap.insert(CommonVertexMap.value_type(vec, mVertices.length));
        
        if (ptr !is null)
        {
            // Already existing, return old one
            return *ptr; //.second;
        }
        else
            mCommonVertexMap[vec] = mVertices.length; //???
        
        // Not found, insert
        CommonVertex newCommon;
        newCommon.index = mVertices.length;
        newCommon.position = vec;
        newCommon.vertexSet = vertexSet;
        newCommon.indexSet = indexSet;
        newCommon.originalIndex = originalIndex;
        mVertices.insert(newCommon);
        return newCommon.index;
    }
    /// Connect existing edge or create a new edge - utility method during building
    void connectOrCreateEdge(size_t vertexSet, size_t triangleIndex, size_t vertIndex0, size_t vertIndex1, 
                             size_t sharedVertIndex0, size_t sharedVertIndex1)
    {
        // Find the existing edge (should be reversed order) on shared vertices
        //auto emi = mEdgeMap.find(pair!(size_t, size_t)(sharedVertIndex1, sharedVertIndex0));
        auto key = pair!(size_t, size_t)(sharedVertIndex1, sharedVertIndex0);
        auto emi = key in mEdgeMap;

        if (emi !is null)
        {
            // The edge already exist, connect it
            EdgeData.Edge e = mEdgeData.edgeGroups[emi.first].edges[emi.second];
            // update with second side
            e.triIndex[1] = triangleIndex;
            e.degenerate = false;
            
            // Remove from the edge map, so we never supplied to connect edge again
            mEdgeMap.remove(key);
        }
        else
        {
            // Not found, create new edge
            mEdgeMap[pair!(size_t, size_t)(sharedVertIndex0, sharedVertIndex1)] = 
                pair!(size_t, size_t)(vertexSet, mEdgeData.edgeGroups[vertexSet].edges.length);
            EdgeData.Edge e;
            e.degenerate = true; // initialise as degenerate
            
            // Set only first tri, the other will be completed in connect existing edge
            e.triIndex[0] = triangleIndex;
            e.triIndex[1] = cast(size_t)(~0);
            e.sharedVertIndex[0] = sharedVertIndex0;
            e.sharedVertIndex[1] = sharedVertIndex1;
            e.vertIndex[0] = vertIndex0;
            e.vertIndex[1] = vertIndex1;
            mEdgeData.edgeGroups[vertexSet].edges ~= (e);
        }
    }
}
/** @} */
/** @} */
