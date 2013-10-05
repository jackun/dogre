module ogre.resources.progressivemeshgenerator;
import std.algorithm;
import ogre.compat;
import ogre.resources.mesh;
import ogre.math.vector;
import ogre.rendersystem.hardware;
import ogre.rendersystem.vertex;

enum NEVER_COLLAPSE_COST = Real.max;
enum UNINITIALIZED_COLLAPSE_COST = Real.infinity;

class ProgressiveMeshGeneratorBase
{
public:
    /**
     * @brief Generates the Lod levels for a mesh.
     * 
     * @param lodConfig Specification of the requested Lod levels.
     */
    abstract void generateLodLevels(LodConfig lodConfig);
    
    /**
     * @brief Generates the Lod levels for a mesh without configuring it.
     *
     * @param mesh Generate the Lod for this mesh.
     */
    void generateAutoconfiguredLodLevels(MeshPtr mesh)
    {
        LodConfig lodConfig;
        getAutoconfig(mesh, lodConfig);
        generateLodLevels(lodConfig);
    }
    
    /**
     * @brief Fills Lod Config with a config, which works on any mesh.
     *
     * @param inMesh Optimize for this mesh.
     * @param outLodConfig Lod configuration storing the output.
     */
    void getAutoconfig(MeshPtr inMesh, ref LodConfig outLodConfig)
    {
        outLodConfig.mesh = inMesh;
        outLodConfig.strategy = PixelCountLodStrategy.getSingleton();
        LodLevel lodLevel;
        lodLevel.reductionMethod = LodLevel.VRM_COLLAPSE_COST;
        Real radius = inMesh.getBoundingSphereRadius();
        for (int i = 2; i < 6; i++) {
            Real i4 = cast(Real) (i * i * i * i);
            Real i5 = i4 * cast(Real) i;
            // Distance = pixel count
            // Constant: zoom of the Lod. This could be scaled based on resolution.
            //     Higher constant means first Lod is nearer to camera. Smaller constant means the first Lod is further away from camera.
            // i4: The stretching. Normally you want to have more Lods in the near, then in far away.
            //     i4 means distance is divided by 16=(2*2*2*2), 81, 256, 625=(5*5*5*5).
            //     if 16 would be smaller, the first Lod would be nearer. if 625 would be bigger, the last Lod would be further awaay.
            // if you increase 16 and decrease 625, first and Last Lod distance would be smaller.
            lodLevel.distance = 3388608.0f / i4;
            
            // reductionValue = collapse cost
            // Radius: Edges are multiplied by the length, when calculating collapse cost. So as a base value we use radius, which should help in balancing collapse cost to any mesh size.
            // The constant and i5 are playing together. 1/(1/100k*i5)
            // You need to determine the quality of nearest Lod and the furthest away first.
            // I have chosen 1/(1/100k*(2^5)) = 3125 for nearest Lod and 1/(1/100k*(5^5)) = 32 for nearest Lod.
            // if you divide radius by a bigger number, it means smaller reduction. So radius/3125 is very small reduction for nearest Lod.
            // if you divide radius by a smaller number, it means bigger reduction. So radius/32 means aggressive reduction for furthest away lod.
            // current values: 3125, 411, 97, 32
            lodLevel.reductionValue = radius / 100000.0f * i5;
            outLodConfig.levels ~= lodLevel;
        }
    }
    
    ~this() { }
}

/**
 * @brief Improved version of ProgressiveMesh.
 */
class ProgressiveMeshGenerator : ProgressiveMeshGeneratorBase
{
public:
    
    this()
    {
        //mUniqueVertexSet((UniqueVertexSet::size_type) 0, (const UniqueVertexSet::hasher&) PMVertexHash(this));
        mMesh = null;
        mMeshBoundingSphereRadius = 0.0f;
        mCollapseCostLimit = NEVER_COLLAPSE_COST;
        
        assert(NEVER_COLLAPSE_COST < UNINITIALIZED_COLLAPSE_COST && NEVER_COLLAPSE_COST != UNINITIALIZED_COLLAPSE_COST, "");
    }
    
    ~this(){}
    
    /// @copydoc ProgressiveMeshGeneratorBase::generateLodLevels
    override void generateLodLevels(LodConfig lodConfig)
    {
        debug
        {   
            // Do not call this with empty Lod.
            assert(!lodConfig.levels.empty(), "");
            
            // Too many lod levels.
            assert(lodConfig.levels.length <= 0xffff, "");
            
            // Lod distances needs to be sorted.
            Mesh.LodValueList values;
            foreach (i; lodConfig.levels) {
                values ~= i.distance;
            }
            lodConfig.strategy.assertSorted(values);
        }
        mMesh = lodConfig.mesh;
        mMeshBoundingSphereRadius = mMesh.getBoundingSphereRadius();
        mMesh.removeLodLevels();
        tuneContainerSize();
        initialize(); // Load vertices and triangles
        computeCosts(); // Calculate all collapse costs

        debug assertValidMesh();
        
        computeLods(lodConfig);
        
        mMesh.get()._configureMeshLodUsage(lodConfig);
    }
    
protected:
    
    alias PMVertex[] VertexList;
    alias PMTriangle[] TriangleList;
    alias HashSet!(PMVertex*, PMVertexHash, PMVertexEqual) UniqueVertexSet;
    alias PMVertex*[][Real] CollapseCostHeap;
    alias PMVertex*[] VertexLookupList;
    
    alias VectorSet!(PMEdge, 8) VEdges;
    alias VectorSet!(PMTriangle*, 7) VTriangles;
    
    alias PMCollapsedEdge[] CollapsedEdges;
    alias PMIndexBufferInfo[] IndexBufferInfoList;
    
    // Hash function for UniqueVertexSet.
    struct PMVertexHash {
        ProgressiveMeshGenerator mGen;
        
        //PMVertexHash() { assert(0); }
        this(ProgressiveMeshGenerator gen) { mGen = gen; }
        size_t opCall (PMVertex v)// const;
        {
            // Stretch the values to an integer grid.
            Real stretch = cast(Real)0x7fffffff / mGen.mMeshBoundingSphereRadius;
            int hash = cast(int)(v.position.x * stretch);
            hash ^= cast(int)(v.position.y * stretch) * 0x100;
            hash ^= cast(int)(v.position.z * stretch) * 0x10000;
            return cast(size_t)hash;
        }
    }
    
    // Equality function for UniqueVertexSet.
    struct PMVertexEqual {
        bool opCall (PMVertex lhs, PMVertex rhs)// const
        {
            return lhs.position == rhs.position;
        }
    }
    
    // Directed edge
    struct PMEdge {
        PMVertex* dst;
        Real collapseCost;
        int refCount;
        
        this(PMVertex* destination)
        {
            dst = destination;
            debug collapseCost = UNINITIALIZED_COLLAPSE_COST;
            refCount = 0;
        }
        
        bool opEquals (auto ref const PMEdge oth) const
        {
            return dst == oth.dst;
        }
        
        //PMEdge opAssign (const PMEdge& b);
        
        int opCmp(ref const PMEdge oth) const
        {
            return dst - oth.dst;
        }
    }
    
    struct PMVertex {
        Vector3 position;
        VEdges edges;
        VTriangles triangles; /// Triangle ID set, which are using this vertex.
        
        PMVertex* collapseTo;
        bool seam;
        //CollapseCostHeap::iterator costHeapPosition; /// Iterator pointing to the position in the mCollapseCostSet, which allows fast remove.
        PMVertex*[] *costHeapPosition;
    }
    
    struct PMTriangle {
        PMVertex*[3] vertex;
        Vector3 normal;
        bool isRemoved;
        ushort submeshID; /// ID of the submesh. Usable with mMesh.getSubMesh() function.
        uint[3] vertexID; /// Vertex ID in the buffer associated with the submeshID.
        
        void computeNormal()
        {
            // Cross-product 2 edges
            Vector3 e1 = vertex[1].position - vertex[0].position;
            Vector3 e2 = vertex[2].position - vertex[1].position;
            
            normal = e1.crossProduct(e2);
            normal.normalise();
        }
        
        bool hasVertex(const PMVertex* v) const
        {
            return (v == vertex[0] || v == vertex[1] || v == vertex[2]);
        }
        
        uint getVertexID(const PMVertex* v) const
        {
            for (int i = 0; i < 3; i++) {
                if (vertex[i] == v) {
                    return vertexID[i];
                }
            }
            assert(0, "");
            return 0;
        }
        
        bool isMalformed()
        {
            return vertex[0] == vertex[1] || vertex[0] == vertex[2] || vertex[1] == vertex[2];
        }
    }
    
    struct PMIndexBufferInfo {
        size_t indexSize;
        size_t indexCount;
    }
    
    union IndexBufferPointer {
        ushort* pshort;
        uint* pint;
    }
    
    struct PMCollapsedEdge {
        uint srcID;
        uint dstID;
        ushort submeshID;
    }
    
    VertexLookupList mSharedVertexLookup;
    VertexLookupList mVertexLookup;
    VertexList mVertexList;
    TriangleList mTriangleList;
    UniqueVertexSet mUniqueVertexSet;
    CollapseCostHeap mCollapseCostHeap;
    CollapsedEdges tmpCollapsedEdges; // Tmp container used in collapse().
    IndexBufferInfoList mIndexBufferInfoList;
    
    MeshPtr mMesh;
    
    /**
     * @brief The name of the mesh being processed.
     *
     * This is separate from mMesh in order to allow for access from background threads.
     */
    debug string mMeshName;
    Real mMeshBoundingSphereRadius;
    Real mCollapseCostLimit;
    
    size_t calcLodVertexCount(const LodLevel lodConfig)
    {
        size_t uniqueVertices = mVertexList.length;
        switch (lodConfig.reductionMethod) {
            case LodLevel.VRM_PROPORTIONAL:
                mCollapseCostLimit = NEVER_COLLAPSE_COST;
                return uniqueVertices - cast(size_t)(cast(Real)uniqueVertices * lodConfig.reductionValue);
                
            case LodLevel.VRM_CONSTANT:
            {
                mCollapseCostLimit = NEVER_COLLAPSE_COST;
                size_t reduction = cast(size_t) lodConfig.reductionValue;
                if (reduction < uniqueVertices) {
                    return uniqueVertices - reduction;
                } else {
                    return 0;
                }
            }
                
            case LodLevel.VRM_COLLAPSE_COST:
                mCollapseCostLimit = lodConfig.reductionValue;
                return 0;
                
            default:
                assert(0, "");
                return uniqueVertices;
        }
    }
    
    void tuneContainerSize()
    {
        // Get Vertex count for container tuning.
        bool sharedVerticesAdded = false;
        size_t vertexCount = 0;
        size_t vertexLookupSize = 0;
        size_t sharedVertexLookupSize = 0;
        ushort submeshCount = mMesh.getNumSubMeshes();
        for (ushort i = 0; i < submeshCount; i++) {
            SubMesh submesh = mMesh.getSubMesh(i);
            if (!submesh.useSharedVertices) {
                size_t count = submesh.vertexData.vertexCount;
                vertexLookupSize = std.algorithm.max(vertexLookupSize, count);
                vertexCount += count;
            } else if (!sharedVerticesAdded) {
                sharedVerticesAdded = true;
                sharedVertexLookupSize = mMesh.sharedVertexData.vertexCount;
                vertexCount += sharedVertexLookupSize;
            }
        }
        
        // Tune containers:
        mUniqueVertexSet.rehash(4 * vertexCount); // less then 0.25 item/bucket for low collision rate
        
        // There are less triangles then 2 * vertexCount. Except if there are bunch of triangles,
        // where all vertices have the same position, but that would not make much sense.
        mTriangleList.length = 2 * vertexCount;
        
        mVertexList.length = vertexCount;
        mSharedVertexLookup.length = sharedVertexLookupSize;
        mVertexLookup.length = vertexLookupSize;
        mIndexBufferInfoList.length = submeshCount;
    }
    
    void addVertexData(VertexData vertexData, bool useSharedVertexLookup)
    {
        if ((useSharedVertexLookup && !mSharedVertexLookup.empty())) { // We already loaded the shared vertex buffer.
            return;
        }
        assert(vertexData.vertexCount != 0, "");
        
        // Locate position element and the buffer to go with it.
        VertexElement elem = vertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
        
        // Only float supported.
        assert(elem.getSize() == 12, "");
        
        HardwareVertexBufferPtr vbuf = vertexData.vertexBufferBinding.getBuffer(elem.getSource());
        
        // Lock the buffer for reading.
        ubyte* vStart = cast(ubyte*)(vbuf.lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
        ubyte* vertex = vStart;
        int vSize = vbuf.getVertexSize();
        ubyte* vEnd = vertex + vertexData.vertexCount * vSize;
        
        VertexLookupList& lookup = useSharedVertexLookup ? mSharedVertexLookup : mVertexLookup;
        lookup.clear();
        
        // Loop through all vertices and insert them to the Unordered Map.
        for (; vertex < vEnd; vertex += vSize) {
            float* pFloat;
            elem.baseVertexPointerToElement(vertex, &pFloat);
            mVertexList ~= PMVertex();
            PMVertex* v = &mVertexList[$-1];
            v.position.x = pFloat[0];
            v.position.y = pFloat[1];
            v.position.z = pFloat[2];
            //pair!(UniqueVertexSet::iterator, bool) ret;
            ret = mUniqueVertexSet.insert(v);
            if (!ret.second) {
                // Vertex position already exists.
                mVertexList.popBack();
                v = *ret.first; // Point to the existing vertex.
                v.seam = true;
            } else {

                // Needed for an assert, don't remove it.
                debug v.costHeapPosition = null;//mCollapseCostHeap.end();
                v.seam = false;
            }
            lookup ~= v;
        }
        vbuf.unlock();
    }
    
    
    void addIndexDataImpl(IndexType)(IndexType iPos, /*const*/ IndexType iEnd, VertexLookupList lookup, ushort submeshID)
    {
        
        // Loop through all triangles and connect them to the vertices.
        for (; iPos < iEnd; iPos += 3) {
            // It should never reallocate or every pointer will be invalid.
            OgreAssert(mTriangleList.capacity() > mTriangleList.length, "");
            mTriangleList ~= PMTriangle();
            PMTriangle* tri = &mTriangleList[$-1];
            tri.isRemoved = false;
            tri.submeshID = submeshID;
            for (int i = 0; i < 3; i++) {
                // Invalid index: Index is bigger then vertex buffer size.
                assert(iPos[i] < lookup.length, "");
                tri.vertexID[i] = iPos[i];
                tri.vertex[i] = lookup[iPos[i]];
            }
            if (tri.isMalformed()) {
                debug {
                    string str = text("In ", mMeshName, " malformed triangle found with ID: ", getTriangleID(tri), ". \n");
                    str ~= printTriangle(tri, true);
                    str ~= "It will be excluded from Lod level calculations.\n";
                    LogManager.getSingleton().stream() << str;
                }
                tri.isRemoved = true;
                mIndexBufferInfoList[tri.submeshID].indexCount -= 3;
                continue;
            }
            tri.computeNormal();
            addTriangleToEdges(tri);
        }
    }
    
    void addIndexData(IndexData indexData, bool useSharedVertexLookup, ushort submeshID)
    {
        HardwareIndexBufferPtr ibuf = indexData.indexBuffer;
        size_t isize = ibuf.getIndexSize();
        mIndexBufferInfoList[submeshID].indexSize = isize;
        mIndexBufferInfoList[submeshID].indexCount = indexData.indexCount;
        if (indexData.indexCount == 0) {
            // Locking a zero length buffer on linux with nvidia cards fails.
            return;
        }
        VertexLookupList lookup = useSharedVertexLookup ? mSharedVertexLookup : mVertexLookup;
        
        // Lock the buffer for reading.
        ubyte* iStart = cast(ubyte*)(ibuf.lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
        ubyte* iEnd = iStart + ibuf.getSizeInBytes();
        if (isize == ushort.sizeof) {
            addIndexDataImpl(cast(ushort*) iStart, cast(ushort*) iEnd, lookup, submeshID);
        } else {
            // Unsupported index size.
            assert(isize == uint.sizeof, "");
            addIndexDataImpl(cast(uint*) iStart, cast(uint*) iEnd, lookup, submeshID);
        }
        ibuf.unlock();
    }
    
    void computeCosts()
    {
        mCollapseCostHeap.clear();
        foreach(it; mVertexList){
            if (!it.edges.empty()) {
                
                computeVertexCollapseCost(&it);
            } else {
                debug
                {
                    LogManager.getSingleton().stream() << "In " << mMeshName << " never used vertex found with ID: " << mCollapseCostHeap.length << ". "
                        << "Vertex position: ("
                            << it.position.x << ", "
                            << it.position.y << ", "
                            << it.position.z << ") "
                            << "It will be excluded from Lod level calculations.\n";
                }
            }
        }
    }
    
    bool isBorderVertex(ref const PMVertex vertex) const
    {
        foreach(it; vertex.edges)
        if (it.refCount == 1) {
            return true;
        }
        return false;
    }
    
    /*PMEdge* getPointer(VEdges::iterator it)
     {
     return &*it;
     }*/
    
    void computeVertexCollapseCost(PMVertex vertex)
    {
        Real collapseCost = UNINITIALIZED_COLLAPSE_COST;
        assert(!vertex.edges.empty(), "");
        //VEdges::iterator it = vertex.edges.begin();
        foreach (it; vertex.edges) {
            it.collapseCost = computeEdgeCollapseCost(vertex, it);
            if (collapseCost > it.collapseCost) {
                collapseCost = it.collapseCost;
                vertex.collapseTo = it.dst;
            }
        }
        assert(collapseCost != UNINITIALIZED_COLLAPSE_COST, "");
        //FIXME
        //vertex.costHeapPosition = mCollapseCostHeap.insert(std::make_pair(collapseCost, vertex));
        mCollapseCostHeap.insert(collapseCost, vertex);
        
    }
    
    Real computeEdgeCollapseCost(PMVertex* src, PMEdge* dstEdge)
    {
        // This is based on Ogre's collapse cost calculation algorithm.
        // 65% of the time is spent in this function!
        
        PMVertex* dst = dstEdge.dst;
        
        version(PM_WORST_QUALITY)
        {
            //nothing
        }
        else //#ifndef
        {
            // 30% speedup if disabled.
            
            // Degenerate case check
            // Are we going to invert a face normal of one of the neighbouring faces?
            // Can occur when we have a very small remaining edge and collapse crosses it
            // Look for a face normal changing by > 90 degrees
            {
                foreach (triangle; src.triangles) {
                    // Ignore the deleted faces (those including src & dest)
                    if (!triangle.hasVertex(dst)) {
                        // Test the new face normal
                        PMVertex* pv0, pv1, pv2;
                        
                        // Replace src with dest wherever it is
                        pv0 = (triangle.vertex[0] == src) ? dst : triangle.vertex[0];
                        pv1 = (triangle.vertex[1] == src) ? dst : triangle.vertex[1];
                        pv2 = (triangle.vertex[2] == src) ? dst : triangle.vertex[2];
                        
                        // Cross-product 2 edges
                        Vector3 e1 = pv1.position - pv0.position;
                        Vector3 e2 = pv2.position - pv1.position;
                        
                        Vector3 newNormal = e1.crossProduct(e2);
                        
                        // Dot old and new face normal
                        // If < 0 then more than 90 degree difference
                        if (newNormal.dotProduct(triangle.normal) < 0.0f) {
                            // Don't do it!
                            return NEVER_COLLAPSE_COST;
                        }
                    }
                }
            }
        }//version(PM_WORST_QUALITY)
        
        Real cost;
        
        // Special cases
        // If we're looking at a border vertex
        if (isBorderVertex(src)) {
            if (dstEdge.refCount > 1) {
                // src is on a border, but the src-dest edge has more than one tri on it
                // So it must be collapsing inwards
                // Mark as very high-value cost
                // curvature = 1.0f;
                cost = 1.0f;
            } else {
                // Collapsing ALONG a border
                // We can't use curvature to measure the effect on the model
                // Instead, see what effect it has on 'pulling' the other border edges
                // The more colinear, the less effect it will have
                // So measure the 'kinkiness' (for want of a better term)
                
                // Find the only triangle using this edge.
                // PMTriangle* triangle = findSideTriangle(src, dst);
                
                cost = -1.0f;
                Vector3 collapseEdge = src.position - dst.position;
                collapseEdge.normalise();
                foreach (it; src.edges) {
                    PMVertex* neighbor = it.dst;
                    if (neighbor != dst && it.refCount == 1) {
                        Vector3 otherBorderEdge = src.position - neighbor.position;
                        otherBorderEdge.normalise();
                        // This time, the nearer the dot is to -1, the better, because that means
                        // the edges are opposite each other, therefore less kinkiness
                        // Scale into [0..1]
                        Real kinkiness = otherBorderEdge.dotProduct(collapseEdge);
                        cost = std.algorithm.max(cost, kinkiness);
                    }
                }
                cost = (1.002f + cost) * 0.5f;
            }
        } else { // not a border
            
            // Standard inner vertex
            // Calculate curvature
            // use the triangle facing most away from the sides
            // to determine our curvature term
            // Iterate over src's faces again
            cost = 1.0f;
            
            foreach (it; src.triangles) {
                Real mincurv = -1.0f; // curve for face i and closer side to it
                PMTriangle* triangle = *it;
                //VTriangles::iterator it2 = src.triangles.begin();
                foreach (it2; src.triangles) {
                    PMTriangle* triangle2 = *it2;
                    if (triangle2.hasVertex(dst)) {
                        
                        // Dot product of face normal gives a good delta angle
                        Real dotprod = triangle.normal.dotProduct(triangle2.normal);
                        // NB we do (1-..) to invert curvature where 1 is high curvature [0..1]
                        // Whilst dot product is high when angle difference is low
                        mincurv = std.algorithm.max(mincurv, dotprod);
                    }
                }
                cost = std.algorithm.min(cost, mincurv);
            }
            cost = (1.002f - cost) * 0.5f;
        }
        
        // check for texture seam ripping and multiple submeshes
        if (src.seam) {
            if (!dst.seam) {
                cost = std.algorithm.max(cost, cast(Real)0.05f);
                cost *= 64;
            } else {
                version(PM_BEST_QUALITY)
                {
                    int seamNeighbors = 0;
                    PMVertex* otherSeam;
                    foreach (it; src.edges) {
                        PMVertex* neighbor = it.dst;
                        if(neighbor.seam) {
                            seamNeighbors++;
                            if(neighbor != dst){
                                otherSeam = neighbor;
                            }
                        }
                    }
                    if(seamNeighbors != 2 || (seamNeighbors == 2 && dst.edges.has(PMEdge(otherSeam)))) {
                        cost = std.algorithm.max(cost, cast(Real)0.05f);
                        cost *= 64;
                    } else {
                        cost = std.algorithm.max(cost, cast(Real)0.005f);
                        cost *= 8;
                    }
                } else {
                    cost = std.algorithm.max(cost, cast(Real)0.005f);
                    cost *= 8;
                }
                
            }
        }
        
        assert(cost >= 0, "");
        return cost * src.position.distance(dst.position);
    }
    
    void bakeLods()
    {
        
        ushort submeshCount = mMesh.getNumSubMeshes();
        IndexBufferPointer[] indexBuffer = new IndexBufferPointer[submeshCount];
        
        // Create buffers.
        for (ushort i = 0; i < submeshCount; i++) {
            SubMesh.LODFaceList lods = mMesh.getSubMesh(i).mLodFaceList;
            int indexCount = mIndexBufferInfoList[i].indexCount;
            assert(indexCount >= 0, "");
            lods ~= new IndexData();
            lods.back().indexStart = 0;
            
            if (indexCount == 0) {
                //If the index is empty we need to create a "dummy" triangle, just to keep the index buffer from being empty.
                //The main reason for this is that the OpenGL render system will crash with a segfault unless the index has some values.
                //This should hopefully be removed with future versions of Ogre. The most preferred solution would be to add the
                //ability for a submesh to be excluded from rendering for a given LOD (which isn't possible currently 2012-12-09).
                lods.back().indexCount = 3;
            } else {
                lods.back().indexCount = indexCount;
            }
            
            lods.back().indexBuffer = HardwareBufferManager.getSingleton().createIndexBuffer(
                mIndexBufferInfoList[i].indexSize == 2 ?
            HardwareIndexBuffer.IndexType.IT_16BIT : HardwareIndexBuffer.IndexType.IT_32BIT,
            lods.back().indexCount, HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, false);
            
            indexBuffer.get()[i].pshort =
                cast(ushort*)(lods.back().indexBuffer.lock(0, lods.back().indexBuffer.getSizeInBytes(),
                                                           HardwareBuffer.LockOptions.HBL_DISCARD));
            
            //Check if we should fill it with a "dummy" triangle.
            if (indexCount == 0) {
                memset(indexBuffer.get()[i].pshort, 0, 3 * mIndexBufferInfoList[i].indexSize);
            }
        }
        
        // Fill buffers.
        size_t triangleCount = mTriangleList.size();
        for (size_t i = 0; i < triangleCount; i++) {
            if (!mTriangleList[i].isRemoved) {
                OgreAssert(mIndexBufferInfoList[mTriangleList[i].submeshID].indexCount != 0, "");
                if (mIndexBufferInfoList[mTriangleList[i].submeshID].indexSize == 2) {
                    for (int m = 0; m < 3; m++) {
                        *(indexBuffer.get()[mTriangleList[i].submeshID].pshort++) =
                            cast(ushort)(mTriangleList[i].vertexID[m]);
                    }
                } else {
                    for (int m = 0; m < 3; m++) {
                        *(indexBuffer.get()[mTriangleList[i].submeshID].pint++) =
                            cast(uint)(mTriangleList[i].vertexID[m]);
                    }
                }
            }
        }
        
        // Close buffers.
        foreach (ushort i; 0..submeshCount) {
            SubMesh.LODFaceList lods = mMesh.getSubMesh(i).mLodFaceList;
            lods.back().indexBuffer.unlock();
        }
    }
    
    void collapse(PMVertex* vertex)
    {
        PMVertex* dst = src.collapseTo;
        static if (OGRE_DEBUG_MODE)
        {
            assertValidVertex(dst);
            assertValidVertex(src);
        }
        assert(src.costHeapPosition.first != NEVER_COLLAPSE_COST, "");
        assert(src.costHeapPosition.first != UNINITIALIZED_COLLAPSE_COST, "");
        assert(!src.edges.empty(), "");
        assert(!src.triangles.empty(), "");
        assert(!src.edges.find(PMEdge(dst)).empty(), "");
        
        // It may have vertexIDs and triangles from different submeshes(different vertex buffers),
        // so we need to connect them correctly based on deleted triangle's edge.
        // mCollapsedEdgeIDs will be used, when looking up the connections for replacement.
        tmpCollapsedEdges.clear();
        //VTriangles::iterator it = src.triangles.begin();
        //VTriangles::iterator itEnd = src.triangles.end();
        foreach (triangle; src.triangles) {
            //PMTriangle* triangle = *it;
            if (triangle.hasVertex(dst)) {
                // Remove a triangle
                // Tasks:
                // 1. Add it to the collapsed edges list.
                // 2. Reduce index count for the Lods, which will not have this triangle.
                // 3. Mark as removed, so it will not be added in upcoming Lod levels.
                // 4. Remove references/pointers to this triangle.
                
                // 1. task
                uint srcID = triangle.getVertexID(src);
                if (!hasSrcID(srcID, triangle.submeshID)) {
                    tmpCollapsedEdges.insertBack(PMCollapsedEdge());
                    tmpCollapsedEdges.back().srcID = srcID;
                    tmpCollapsedEdges.back().dstID = triangle.getVertexID(dst);
                    tmpCollapsedEdges.back().submeshID = triangle.submeshID;
                }
                
                // 2. task
                mIndexBufferInfoList[triangle.submeshID].indexCount -= 3;
                
                // 3. task
                triangle.isRemoved = true;
                
                // 4. task
                removeTriangleFromEdges(triangle, src);
            }
        }
        assert(tmpCollapsedEdges.length, "");
        assert(dst.edges.find(PMEdge(src)).empty, "");
        
        //it = src.triangles.begin();
        foreach (triangle; src.triangles) {
            //PMTriangle* triangle = *it;
            if (!triangle.hasVertex(dst)) {
                // Replace a triangle
                // Tasks:
                // 1. Determine the edge which we will move along. (we need to modify single vertex only)
                // 2. Move along the selected edge.
                
                // 1. task
                uint srcID = triangle.getVertexID(src);
                size_t id = findDstID(srcID, triangle.submeshID);
                if (id == size_t.max) {
                    // Not found any edge to move along.
                    // Destroy the triangle.
                    triangle.isRemoved = true;
                    mIndexBufferInfoList[triangle.submeshID].indexCount -= 3;
                    removeTriangleFromEdges(triangle, src);
                    continue;
                }
                uint dstID = tmpCollapsedEdges[id].dstID;
                
                // 2. task
                replaceVertexID(triangle, srcID, dstID, dst);
                
                static if(PM_BEST_QUALITY)
                    triangle.computeNormal();
            }
        }
        
        dst.seam |= src.seam; // Inherit seam property
        
        static if(!PM_BEST_QUALITY)
        {
            foreach (it3; src.edges) {
                updateVertexCollapseCost(it3.dst);
            }
        }else{
            // TODO: Find out why is this needed. assertOutdatedCollapseCost() fails on some
            // rare situations without this. For example goblin.mesh fails.
            alias SmallVector!(PMVertex*, 64) UpdatableList;
            UpdatableList updatable;
            foreach (it3; src.edges) {
                updatable.insertBack(it3.dst);
                foreach (it4; it3.dst.edges) {
                    updatable.insertBack(it4.dst);
                }
            }
            
            // Remove duplicates.
            //UpdatableList::iterator it5 = updatable.begin();
            //UpdatableList::iterator it5End = updatable.end();
            updatable = std.algorithm.sort(updatable);
            updatable = std.algorithm.uniq(updatable);
            
            foreach (it5; updatable) {
                updateVertexCollapseCost(*it5);
            }
            static if (OGRE_DEBUG_MODE){
                //it3 = src.edges.begin();
                foreach (it3; src.edges) {
                    assertOutdatedCollapseCost(it3.dst);
                }
                //it3 = dst.edges.begin();
                foreach (it3; dst.edges) {
                    assertOutdatedCollapseCost(it3.dst);
                }
                assertOutdatedCollapseCost(dst);
            } // ifndef NDEBUG
        } // ifndef PM_BEST_QUALITY
        mCollapseCostHeap.erase(src.costHeapPosition); // Remove src from collapse costs.
        src.edges.clear(); // Free memory
        src.triangles.clear(); // Free memory
        static if (OGRE_DEBUG_MODE){
            src.costHeapPosition = mCollapseCostHeap.end();
            assertValidVertex(dst);
        }
    }

    void initialize();
    void computeLods(LodConfig& lodConfigs);
    void updateVertexCollapseCost(PMVertex* src);
    
    bool hasSrcID(uint srcID, ushort submeshID);
    size_t findDstID(uint srcID, ushort submeshID);
    void replaceVertexID(PMTriangle* triangle, uint oldID, uint newID, PMVertex* dst);
    
#ifndef NDEBUG
    void assertValidVertex(PMVertex* v);
    void assertValidMesh();
    void assertOutdatedCollapseCost(PMVertex* vertex);
#endif // ifndef NDEBUG
    
    void addTriangleToEdges(PMTriangle* triangle);
    void removeTriangleFromEdges(PMTriangle* triangle, PMVertex* skip = NULL);
    void addEdge(PMVertex* v, const PMEdge& edge);
    void removeEdge(PMVertex* v, const PMEdge& edge);
    void printTriangle(PMTriangle* triangle, stringstream& str);
    PMTriangle* findSideTriangle(const PMVertex* v1, const PMVertex* v2);
    bool isDuplicateTriangle(PMTriangle* triangle, PMTriangle* triangle2);
    PMTriangle* isDuplicateTriangle(PMTriangle* triangle);
    int getTriangleID(PMTriangle* triangle);
    void cleanupMemory();
};