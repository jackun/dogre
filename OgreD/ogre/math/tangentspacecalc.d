module ogre.math.tangentspacecalc;
import core.stdc.string: memcpy;
import std.array;
import ogre.compat;
import ogre.rendersystem.renderoperation;
import ogre.exception;
import ogre.math.vector;
import ogre.rendersystem.vertex;
import ogre.rendersystem.hardware;
import ogre.math.angles;
import ogre.general.log;
import ogre.math.maths;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Math
 *  @{
 */
/** Class for calculating a tangent space basis.
 */
class TangentSpaceCalc
{
public:
    this()
    {
        mVData= null;
        mSplitMirrored = false;
        mSplitRotated = false;
        mStoreParityInW = false;
    }
    ~this(){}
    
    alias pair!(size_t, size_t) VertexSplit;
    
    /// Information about a remapped index
    struct IndexRemap
    {
        /// Index data set (can be >0 if more than one index data was added)
        size_t indexSet;
        /// The position in the index buffer that's affected
        size_t faceIndex;
        /// The old and new vertex index
        VertexSplit splitVertex;

        this(size_t i, size_t f, VertexSplit s) 
        {
            indexSet = i;
            faceIndex = f;
            splitVertex = s;
        }
    }
    /** List of indexes that were remapped (split vertices).
     */
    //typedef list<IndexRemap>.type IndexRemapList;
    alias IndexRemap[] IndexRemapList;
    
    //typedef list<VertexSplit>.type VertexSplits;
    alias VertexSplit[] VertexSplits;
    
    /// The result of having built a tangent space basis
    struct Result
    {
        /** A list of vertex indices which were split off into new vertices
         because of mirroring. First item in each pair is the source vertex 
         index, the second value is the split vertex index.
         */
        VertexSplits vertexSplits;
        /** A list of indexes which were affected by splits. You can use this if you have other
         triangle-based data which you will need to alter to match. */
        IndexRemapList indexesRemapped;
    }
    
    /// Reset the calculation object
    void clear()
    {
        mIDataList.clear();
        mOpTypes.clear();
        mVData = null;
    }
    
    /** Set the incoming vertex data (which will be modified) */
    void setVertexData(VertexData v_in)
    {
        mVData = v_in;
    }
    
    /** Add a set of index data that references the vertex data.
     This might be modified if there are vertex splits.
     */
    void addIndexData(IndexData i_in, RenderOperation.OperationType op = RenderOperation.OperationType.OT_TRIANGLE_LIST)
    {
        if (op != RenderOperation.OperationType.OT_TRIANGLE_FAN && 
            op != RenderOperation.OperationType.OT_TRIANGLE_LIST && 
            op != RenderOperation.OperationType.OT_TRIANGLE_STRIP)
        {
            throw new InvalidParamsError(
                "Only indexed triangle (list, strip, fan) render operations are supported.",
                "TangentSpaceCalc.addIndexData");
            
        }
        mIDataList.insert(i_in);
        mOpTypes.insert(op);
    }
    
    /** Sets whether to store tangent space parity in the W of a 4-component tangent or not.
     @remarks
     The default element format to use is VET_FLOAT3 which is enough to accurately 
     deal with tangents that do not involve any texture coordinate mirroring. 
     If you wish to allow UV mirroring in your model, you must enable 4-component
     tangents using this method, and the 'w' co-ordinate will be populated
     with the parity of the triangle (+1 or -1), which will allow you to generate
     the bitangent properly.
     @param enabled true to enable 4-component tangents (default false). If you enable
     this, you will probably also want to enable mirror splitting (see setSplitMirrored), 
     and your shader must understand how to deal with the parity.
     */
    void setStoreParityInW(bool enabled) { mStoreParityInW = enabled; }
    
    /**  Gets whether to store tangent space parity in the W of a 4-component tangent or not. */
    bool getStoreParityInW() { return mStoreParityInW; }
    
    /** Sets whether or not to split vertices when a mirrored tangent space
     transition is detected (matrix parity differs).
     @remarks
     This defaults to 'off' because it's the safest option; tangents will be
     interpolated in all cases even if they don't agree around a vertex, so
     artefacts will be smoothed out. When you're using art assets of 
     unknown quality this can avoid extra seams on the visible surface. 
     However, if your artists are good, they will be hiding texture seams
     in folds of the model and thus you can turn this option on, which will
     prevent the results of those seams from getting smoothed into other
     areas, which is exactly what you want.
     @note This option is automatically disabled if you provide any strip or
     fan based geometry.
     */
    void setSplitMirrored(bool split) { mSplitMirrored = split; }
    
    /** Gets whether or not to split vertices when a mirrored tangent space
     transition is detected.
     */
    bool getSplitMirrored() { return mSplitMirrored; }
    
    /** Sets whether or not to split vertices when tangent space rotates
     more than 90 degrees around a vertex.
     @remarks
     This defaults to 'off' because it's the safest option; tangents will be
     interpolated in all cases even if they don't agree around a vertex, so
     artefacts will be smoothed out. When you're using art assets of 
     unknown quality this can avoid extra seams on the visible surface. 
     However, if your artists are good, they will be hiding texture inconsistencies
     in folds of the model and thus you can turn this option on, which will
     prevent the results of those seams from getting smoothed into other
     areas, which is exactly what you want.
     @note This option is automatically disabled if you provide any strip or
     fan based geometry.
     */
    void setSplitRotated(bool split) { mSplitRotated = split; }
    /** Sets whether or not to split vertices when tangent space rotates
     more than 90 degrees around a vertex.
     */
    bool getSplitRotated() { return mSplitRotated; }
    
    /** Build a tangent space basis from the provided data.
     @remarks
     Only indexed triangle lists are allowed. Strips and fans cannot be
     supported because it may be necessary to split the geometry up to 
     respect deviances in the tangent space basis better.
     @param targetSemantic The semantic to store the tangents in. Defaults to 
     the explicit tangent binding, but note that this is only usable on more
     modern hardware (Shader Model 2), so if you need portability with older
     cards you should change this to a texture coordinate binding instead.
     @param sourceTexCoordSet The texture coordinate index which should be used as the source
     of 2D texture coordinates, with which to calculate the tangents.
     @param index The element index, ie the texture coordinate set which should be used to store the 3D
     coordinates representing a tangent vector per vertex, if targetSemantic is 
     VES_TEXTURE_COORDINATES. If this already exists, it will be overwritten.
     @return
     A structure containing the results of the tangent space build. Vertex data
     will always be modified but it's also possible that the index data
     could be adjusted. This happens when mirroring is used on a mesh, which
     causes the tangent space to be inverted on opposite sides of an edge.
     This is discontinuous, therefore the vertices have to be split along
     this edge, resulting in new vertices.
     */
    Result build(VertexElementSemantic targetSemantic = VertexElementSemantic.VES_TANGENT,
                 ushort sourceTexCoordSet = 0, ushort index = 1)
    {
        Result res;
        
        // Pull out all the vertex components we'll need
        populateVertexArray(sourceTexCoordSet);
        
        // Now process the faces and calculate / add their contributions
        processFaces(res);
        
        // Now normalise & orthogonalise
        normaliseVertices();
        
        // Create new final geometry
        // First extend existing buffers to cope with new vertices
        extendBuffers(res.vertexSplits);
        
        // Alter indexes
        remapIndexes(res);
        
        // Create / identify target & write tangents
        insertTangents(res, targetSemantic, sourceTexCoordSet, index);
        
        return res;
    }
    
    
protected:
    
    VertexData mVData;
    //typedef vector<IndexData*>.type IndexDataList;
    //typedef vector<RenderOperation.OperationType>.type OpTypeList;
    alias IndexData[] IndexDataList;
    alias RenderOperation.OperationType[] OpTypeList;
    IndexDataList mIDataList;
    OpTypeList mOpTypes;
    bool mSplitMirrored;
    bool mSplitRotated;
    bool mStoreParityInW;
    
    
    struct VertexInfo
    {
        Vector3 pos;
        Vector3 norm;
        Vector2 uv;
        Vector3 tangent;// = Vector3.ZERO; //FIXME cant be read compile time, ZERO by default anyway
        Vector3 binormal;// = Vector3.ZERO;
        // Which way the tangent space is oriented (+1 / -1) (set on first time found)
        int parity;
        // What index the opposite parity vertex copy is at (0 if not created yet)
        size_t oppositeParityIndex;
    }

    //typedef vector<VertexInfo>.type VertexInfoArray;
    alias VertexInfo[] VertexInfoArray;
    VertexInfoArray mVertexArray;
    
    void extendBuffers(VertexSplits vertexSplits)
    {
        if (!vertexSplits.empty())
        {
            // ok, need to increase the vertex buffer size, and alter some indexes
            
            // vertex buffers first
            VertexBufferBinding newBindings = HardwareBufferManager.getSingleton().createVertexBufferBinding();
            VertexBufferBinding.VertexBufferBindingMap bindmap = 
                mVData.vertexBufferBinding.getBindings();
            foreach (k, srcbuf; bindmap)
            {
                // Derive vertex count from buffer not vertex data, in case using
                // the vertexStart option in vertex data
                size_t newVertexCount = srcbuf.get().getNumVertices() + vertexSplits.length;
                // Create new buffer & bind
                SharedPtr!HardwareVertexBuffer newBuf = 
                    HardwareBufferManager.getSingleton().createVertexBuffer(
                        srcbuf.get().getVertexSize(), newVertexCount, srcbuf.get().getUsage(), 
                        srcbuf.get().hasShadowBuffer());
                newBindings.setBinding(k, newBuf);
                
                // Copy existing contents (again, entire buffer, not just elements referenced)
                newBuf.get().copyData(srcbuf.get(), 0, 0, srcbuf.get().getNumVertices() * srcbuf.get().getVertexSize(), true);
                
                // Split vertices, read / write from new buffer
                ubyte* pBase = cast(ubyte*)(newBuf.get().lock(HardwareBuffer.LockOptions.HBL_NORMAL));

                foreach (split; vertexSplits)
                {
                    const ubyte* pSrcBase = pBase + split.first * newBuf.get().getVertexSize();
                    ubyte* pDstBase = pBase + split.second * newBuf.get().getVertexSize();
                    memcpy(pDstBase, pSrcBase, newBuf.get().getVertexSize());
                }
                newBuf.get().unlock();
                
            }
            
            // Update vertex data
            // Increase vertex count according to num splits
            mVData.vertexCount += vertexSplits.length;
            // Flip bindings over to new buffers (old buffers released)
            HardwareBufferManager.getSingleton().destroyVertexBufferBinding(mVData.vertexBufferBinding);
            mVData.vertexBufferBinding = newBindings;
            
            // If vertex size requires 32bit index buffer
            if (mVData.vertexCount > 65536)
            {
                for (size_t i = 0; i < mIDataList.length; ++i)
                {
                    // check index size
                    IndexData idata = mIDataList[i];
                    SharedPtr!HardwareIndexBuffer srcbuf = idata.indexBuffer;
                    if (srcbuf.get().getType() == HardwareIndexBuffer.IndexType.IT_16BIT)
                    {
                        size_t indexCount = srcbuf.get().getNumIndexes();
                        
                        // convert index buffer to 32bit.
                        SharedPtr!HardwareIndexBuffer newBuf =
                            HardwareBufferManager.getSingleton().createIndexBuffer(
                                HardwareIndexBuffer.IndexType.IT_32BIT, indexCount,
                                srcbuf.get().getUsage(), srcbuf.get().hasShadowBuffer());
                        
                        ushort* pSrcBase = cast(ushort*)(srcbuf.get().lock(HardwareBuffer.LockOptions.HBL_NORMAL));
                        uint* pBase = cast(uint*)(newBuf.get().lock(HardwareBuffer.LockOptions.HBL_NORMAL));
                        
                        size_t j = 0;
                        while (j < indexCount)
                        {
                            *pBase++ = *pSrcBase++;
                            ++j;
                        }
                        
                        srcbuf.get().unlock();
                        newBuf.get().unlock();
                        
                        // assign new index buffer.
                        idata.indexBuffer = newBuf;
                    }
                }
            }
        }
        
    }

    void insertTangents(Result res,
                        VertexElementSemantic targetSemantic, 
                        ushort sourceTexCoordSet, ushort index)
    {
        // Make a new tangents semantic or find an existing one
        VertexDeclaration vDecl = mVData.vertexDeclaration ;
        VertexBufferBinding vBind = mVData.vertexBufferBinding ;
        
        VertexElement tangentsElem = vDecl.findElementBySemantic(targetSemantic, index);
        bool needsToBeCreated = false;
        VertexElementType tangentsType = mStoreParityInW ? VertexElementType.VET_FLOAT4 : VertexElementType.VET_FLOAT3;
        
        if (!tangentsElem)
        { // no tex coords with index 1
            needsToBeCreated = true ;
        }
        else if (tangentsElem.getType() != tangentsType)
        {
            //  buffer exists, but not 3D
            throw new InvalidParamsError(
                "Target semantic set already exists but is not of the right size, therefore " ~
                "cannot contain tangents. You should delete this existing entry first. ",
                "TangentSpaceCalc.insertTangents");
        }
        
        SharedPtr!HardwareVertexBuffer targetBuffer, origBuffer;
        ubyte* pSrc = null;
        
        if (needsToBeCreated)
        {
            // To be most efficient with our vertex streams,
            // tack the new tangents onto the same buffer as the
            // source texture coord set
            VertexElement prevTexCoordElem =
                mVData.vertexDeclaration.findElementBySemantic(
                    VertexElementSemantic.VES_TEXTURE_COORDINATES, sourceTexCoordSet);
            if (!prevTexCoordElem)
            {
                throw new ItemNotFoundError(
                    "Cannot locate the first texture coordinate element to " ~
                    "which to append the new tangents.", 
                    "MeshorgagniseTangentsBuffer");
            }
            // Find the buffer associated with  this element
            origBuffer = mVData.vertexBufferBinding.getBuffer(
                prevTexCoordElem.getSource());
            // Now create a new buffer, which includes the previous contents
            // plus extra space for the 3D coords
            targetBuffer = HardwareBufferManager.getSingleton().createVertexBuffer(
                origBuffer.get().getVertexSize() + VertexElement.getTypeSize(tangentsType),
                origBuffer.get().getNumVertices(),
                origBuffer.get().getUsage(),
                origBuffer.get().hasShadowBuffer() );
            // Add the new element
            tangentsElem = vDecl.addElement(
                prevTexCoordElem.getSource(),
                origBuffer.get().getVertexSize(),
                tangentsType,
                targetSemantic,
                index);
            // Set up the source pointer
            pSrc = cast(ubyte*)(
                origBuffer.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
            // Rebind the new buffer
            vBind.setBinding(prevTexCoordElem.getSource(), targetBuffer);
        }
        else
        {
            // space already there
            origBuffer = mVData.vertexBufferBinding.getBuffer(
                tangentsElem.getSource());
            targetBuffer = origBuffer;
        }
        
        
        ubyte* pDest = cast(ubyte*)(
            targetBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
        size_t origVertSize = origBuffer.get().getVertexSize();
        size_t newVertSize = targetBuffer.get().getVertexSize();
        for (size_t v = 0; v < origBuffer.get().getNumVertices(); ++v)
        {
            if (needsToBeCreated)
            {
                // Copy original vertex data as well 
                memcpy(pDest, pSrc, origVertSize);
                pSrc += origVertSize;
            }
            // Write in the tangent
            float* pTangent;
            tangentsElem.baseVertexPointerToElement(pDest, &pTangent);
            VertexInfo vertInfo = mVertexArray[v];
            *pTangent++ = vertInfo.tangent.x;
            *pTangent++ = vertInfo.tangent.y;
            *pTangent++ = vertInfo.tangent.z;
            if (mStoreParityInW)
                *pTangent++ = cast(float)vertInfo.parity;
            
            // Next target vertex
            pDest += newVertSize;
            
        }
        targetBuffer.get().unlock();
        
        if (needsToBeCreated)
        {
            origBuffer.get().unlock();
        }
    }
    
    void populateVertexArray(ushort sourceTexCoordSet)
    {
        // Just pull data out into more friendly structures
        VertexDeclaration dcl = mVData.vertexDeclaration;
        VertexBufferBinding bind = mVData.vertexBufferBinding;
        
        // Get the incoming UV element
        VertexElement uvElem = dcl.findElementBySemantic(
            VertexElementSemantic.VES_TEXTURE_COORDINATES, sourceTexCoordSet);
        
        if (!uvElem || uvElem.getType() != VertexElementType.VET_FLOAT2)
        {
            throw new InvalidParamsError(
                "No 2D texture coordinates with selected index, cannot calculate tangents.",
                "TangentSpaceCalc.build");
        }
        
        SharedPtr!HardwareVertexBuffer uvBuf, posBuf, normBuf;
        ubyte* pUvBase, pPosBase, pNormBase;
        size_t uvInc, posInc, normInc;
        
        uvBuf = bind.getBuffer(uvElem.getSource());
        pUvBase = cast(ubyte*)(uvBuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
        uvInc = uvBuf.get().getVertexSize();
        // offset for vertex start
        pUvBase += mVData.vertexStart * uvInc;
        
        // find position
        VertexElement posElem = dcl.findElementBySemantic(VertexElementSemantic.VES_POSITION);
        if (posElem.getSource() == uvElem.getSource())
        {
            pPosBase = pUvBase;
            posInc = uvInc;
        }
        else
        {
            // A different buffer
            posBuf = bind.getBuffer(posElem.getSource());
            pPosBase = cast(ubyte*)(posBuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
            posInc = posBuf.get().getVertexSize();
            // offset for vertex start
            pPosBase += mVData.vertexStart * posInc;
        }
        // find a normal buffer
        VertexElement normElem = dcl.findElementBySemantic(VertexElementSemantic.VES_NORMAL);
        if (!normElem)
            throw new ItemNotFoundError(
                "No vertex normals found", 
                "TangentSpaceCalc.build");
        
        if (normElem.getSource() == uvElem.getSource())
        {
            pNormBase = pUvBase;
            normInc = uvInc;
        }
        else if (normElem.getSource() == posElem.getSource())
        {
            // normals are in the same buffer as position
            // this condition arises when an animated(skeleton) mesh is not built with 
            // an edge list buffer ie no shadows being used.
            pNormBase = pPosBase;
            normInc = posInc;
        }
        else
        {
            // A different buffer
            normBuf = bind.getBuffer(normElem.getSource());
            pNormBase = cast(ubyte*)(normBuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
            normInc = normBuf.get().getVertexSize();
            // offset for vertex start
            pNormBase += mVData.vertexStart * normInc;
        }
        
        // Preinitialise vertex info
        mVertexArray.clear();
        mVertexArray.length = mVData.vertexCount;
        
        float* pFloat;
        VertexInfo* vInfo = mVertexArray.ptr;
        for (size_t v = 0; v < mVData.vertexCount; ++v, ++vInfo)
        {
            posElem.baseVertexPointerToElement(pPosBase, &pFloat);
            vInfo.pos.x = *pFloat++;
            vInfo.pos.y = *pFloat++;
            vInfo.pos.z = *pFloat++;
            pPosBase += posInc;
            
            normElem.baseVertexPointerToElement(pNormBase, &pFloat);
            vInfo.norm.x = *pFloat++;
            vInfo.norm.y = *pFloat++;
            vInfo.norm.z = *pFloat++;
            pNormBase += normInc;
            
            uvElem.baseVertexPointerToElement(pUvBase, &pFloat);
            vInfo.uv.x = *pFloat++;
            vInfo.uv.y = *pFloat++;
            pUvBase += uvInc;
            
            
        }
        
        // unlock buffers
        uvBuf.get().unlock();
        if (!posBuf.isNull())
        {
            posBuf.get().unlock();
        }
        if (!normBuf.isNull())
        {
            normBuf.get().unlock();
        }
        
    }

    void processFaces(Result result)
    {
        // Quick pre-check for triangle strips / fans
        foreach (ot; mOpTypes)
        {
            if (ot != RenderOperation.OperationType.OT_TRIANGLE_LIST)
            {
                // Can't split strips / fans
                setSplitMirrored(false);
                setSplitRotated(false);
            }
        }
        
        for (size_t i = 0; i < mIDataList.length; ++i)
        {
            IndexData i_in = mIDataList[i];
            RenderOperation.OperationType opType = mOpTypes[i];
            
            // Read data from buffers
            ushort *p16 = null;
            uint *p32 = null;
            
            SharedPtr!HardwareIndexBuffer ibuf = i_in.indexBuffer;
            if (ibuf.get().getType() == HardwareIndexBuffer.IndexType.IT_32BIT)
            {
                p32 = cast(uint*)(ibuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
                // offset by index start
                p32 += i_in.indexStart;
            }
            else
            {
                p16 = cast(ushort*)(ibuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
                // offset by index start
                p16 += i_in.indexStart;
            }
            // current triangle
            size_t[3] vertInd = [ 0, 0, 0 ];
            // loop through all faces to calculate the tangents and normals
            size_t faceCount = opType == RenderOperation.OperationType.OT_TRIANGLE_LIST ? 
                i_in.indexCount / 3 : i_in.indexCount - 2;
            for (size_t f = 0; f < faceCount; ++f)
            {
                bool invertOrdering = false;
                // Read 1 or 3 indexes depending on type
                if (f == 0 || opType == RenderOperation.OperationType.OT_TRIANGLE_LIST)
                {
                    vertInd[0] = p32? *p32++ : *p16++;
                    vertInd[1] = p32? *p32++ : *p16++;
                    vertInd[2] = p32? *p32++ : *p16++;
                }
                else if (opType == RenderOperation.OperationType.OT_TRIANGLE_FAN)
                {
                    // Element 0 always remains the same
                    // Element 2 becomes element 1
                    vertInd[1] = vertInd[2];
                    // read new into element 2
                    vertInd[2] = p32? *p32++ : *p16++;
                }
                else if (opType == RenderOperation.OperationType.OT_TRIANGLE_STRIP)
                {
                    // Shunt everything down one, but also invert the ordering on 
                    // odd numbered triangles (== even numbered i's)
                    // we interpret front as anticlockwise all the time but strips alternate
                    if (f & 0x1)
                    {
                        // odd tris (index starts at 3, 5, 7)
                        invertOrdering = true;
                    }
                    vertInd[0] = vertInd[1];
                    vertInd[1] = vertInd[2];            
                    vertInd[2] = p32? *p32++ : *p16++;
                }
                
                // deal with strip inversion of winding
                size_t[3] localVertInd;
                localVertInd[0] = vertInd[0];
                if (invertOrdering)
                {
                    localVertInd[1] = vertInd[2];
                    localVertInd[2] = vertInd[1];
                }
                else
                {
                    localVertInd[1] = vertInd[1];
                    localVertInd[2] = vertInd[2];
                }
                
                
                // For each triangle
                //   Calculate tangent & binormal per triangle
                //   Note these are not normalised, are weighted by UV area
                Vector3 faceTsU, faceTsV, faceNorm;
                calculateFaceTangentSpace(localVertInd, faceTsU, faceTsV, faceNorm);
                
                // Skip invalid UV space triangles
                if (faceTsU.isZeroLength() || faceTsV.isZeroLength())
                    continue;
                
                addFaceTangentSpaceToVertices(i, f, localVertInd, faceTsU, faceTsV, faceNorm, result);
                
            }
            
            
            ibuf.get().unlock();
        }
        
    }

    /// Calculate face tangent space, U and V are weighted by UV area, N is normalised
    void calculateFaceTangentSpace(const size_t[] vertInd, ref Vector3 tsU, ref Vector3 tsV, ref Vector3 tsN)
    {
        VertexInfo v0 = mVertexArray[vertInd[0]];
        VertexInfo v1 = mVertexArray[vertInd[1]];
        VertexInfo v2 = mVertexArray[vertInd[2]];
        Vector2 deltaUV1 = v1.uv - v0.uv;
        Vector2 deltaUV2 = v2.uv - v0.uv;
        Vector3 deltaPos1 = v1.pos - v0.pos;
        Vector3 deltaPos2 = v2.pos - v0.pos;
        
        // face normal
        tsN = deltaPos1.crossProduct(deltaPos2);
        tsN.normalise();
        
        
        Real uvarea = deltaUV1.crossProduct(deltaUV2) * 0.5f;
        if (Math.RealEqual(uvarea, 0.0f))
        {
            // no tangent, null uv area
            tsU = tsV = Vector3.ZERO;
        }
        else
        {
            
            // Normalise by uvarea
            Real a = deltaUV2.y / uvarea;
            Real b = -deltaUV1.y / uvarea;
            Real c = -deltaUV2.x / uvarea;
            Real d = deltaUV1.x / uvarea;
            
            tsU = (deltaPos1 * a) + (deltaPos2 * b);
            tsU.normalise();
            
            tsV = (deltaPos1 * c) + (deltaPos2 * d);
            tsV.normalise();
            
            Real abs_uvarea = Math.Abs(uvarea);
            tsU *= abs_uvarea;
            tsV *= abs_uvarea;
            
            // tangent (tsU) and binormal (tsV) are now weighted by uv area
            
            
        }
        
    }

    Real calculateAngleWeight(size_t vidx0, size_t vidx1, size_t vidx2)
    {
        VertexInfo v0 = mVertexArray[vidx0];
        VertexInfo v1 = mVertexArray[vidx1];
        VertexInfo v2 = mVertexArray[vidx2];
        
        Vector3 diff0 = v1.pos - v0.pos;
        Vector3 diff1 = v2.pos - v1.pos;
        
        // Weight is just the angle - larger == better
        return diff0.angleBetween(diff1).valueRadians();
        
    }

    int calculateParity(Vector3 u, Vector3 v, Vector3 n)
    {
        // Note that this parity is the reverse of what you'd expect - this is
        // because the 'V' texture coordinate is actually left handed
        if (u.crossProduct(v).dotProduct(n) >= 0.0f)
            return -1;
        else
            return 1;
        
    }

    void addFaceTangentSpaceToVertices(size_t indexSet, size_t faceIndex, size_t[] localVertInd, 
                                       Vector3 faceTsU, Vector3 faceTsV, Vector3 faceNorm, ref Result result)
    {
        // Calculate parity for this triangle
        int faceParity = calculateParity(faceTsU, faceTsV, faceNorm);
        // Now add these to each vertex referenced by the face
        for (int v = 0; v < 3; ++v)
        {
            // index 0 is vertex we're calculating, 1 and 2 are the others
            
            // We want to re-weight these by the angle the face makes with the vertex
            // in order to obtain tesselation-independent results
            Real angleWeight = calculateAngleWeight(localVertInd[v], 
                                                    localVertInd[(v+1)%3], localVertInd[(v+2)%3]);
            
            
            VertexInfo* vertex = &(mVertexArray[localVertInd[v]]);
            
            // check parity (0 means not set)
            // Locate parity-version of vertex index, or create if doesn't exist
            // If parity-version of vertex index was different, record alteration
            // in triangle remap
            // in vertex split list
            bool splitVertex = false;
            size_t reusedOppositeParity = 0;
            bool splitBecauseOfParity = false;
            bool newVertex = false;
            if (!vertex.parity)
            {
                // init
                vertex.parity = faceParity;
                newVertex = true;
            }
            if (mSplitMirrored)
            {
                if (!newVertex && faceParity != calculateParity(vertex.tangent, vertex.binormal, vertex.norm))//vertex.parity != faceParity)
                {
                    // Check for existing alternative parity
                    if (vertex.oppositeParityIndex)
                    {
                        // Ok, have already split this vertex because of parity
                        // Use the same one again
                        reusedOppositeParity = vertex.oppositeParityIndex;
                        vertex = &(mVertexArray[reusedOppositeParity]);
                    }
                    else
                    {
                        splitVertex = true;
                        splitBecauseOfParity = true;
                        
                        LogManager.getSingleton().stream(LML_TRIVIAL)
                            << "TSC parity split - Vpar: " << vertex.parity 
                                << " Fpar: " << faceParity
                                << " faceTsU: " << faceTsU
                                << " faceTsV: " << faceTsV
                                << " faceNorm: " << faceNorm
                                << " vertTsU:" << vertex.tangent
                                << " vertTsV:" << vertex.binormal
                                << " vertNorm:" << vertex.norm;
                        
                    }
                }
            }
            
            if (mSplitRotated)
            {
                
                // deal with excessive tangent space rotations as well as mirroring
                // same kind of split behaviour appropriate
                if (!newVertex && !splitVertex)
                {
                    // If more than 90 degrees, split
                    Vector3 uvCurrent = vertex.tangent + vertex.binormal;
                    
                    // project down to the plane (plane normal = face normal)
                    Vector3 vRotHalf = uvCurrent - faceNorm;
                    vRotHalf *= faceNorm.dotProduct(uvCurrent);
                    
                    if ((faceTsU + faceTsV).dotProduct(vRotHalf) < 0.0f)
                    {
                        splitVertex = true;
                    }
                }
            }
            
            if (splitVertex)
            {
                size_t newVertexIndex = mVertexArray.length;
                auto splitInfo = VertexSplit(localVertInd[v], newVertexIndex);
                result.vertexSplits.insert(splitInfo);
                // re-point opposite parity
                if (splitBecauseOfParity)
                {
                    vertex.oppositeParityIndex = newVertexIndex;
                }
                // copy old values but reset tangent space
                VertexInfo locVertex = *vertex;
                locVertex.tangent = Vector3.ZERO;
                locVertex.binormal = Vector3.ZERO;
                locVertex.parity = faceParity;
                mVertexArray.insert(locVertex);
                result.indexesRemapped.insert(IndexRemap(indexSet, faceIndex, splitInfo));
                
                vertex = &(mVertexArray[newVertexIndex]);
                
            }
            else if (reusedOppositeParity)
            {
                // didn't split again, but we do need to record the re-used remapping
                auto splitInfo = VertexSplit(localVertInd[v], reusedOppositeParity);
                result.indexesRemapped.insert(IndexRemap(indexSet, faceIndex, splitInfo));
                
            }
            
            // Add weighted tangent & binormal
            vertex.tangent += (faceTsU * angleWeight);
            vertex.binormal += (faceTsV * angleWeight);
            
            
        }
        
    }

    void normaliseVertices()
    {
        // Just run through our complete (possibly augmented) list of vertices
        // Normalise the tangents & binormals
        foreach (v; mVertexArray)
        {            
            v.tangent.normalise();
            v.binormal.normalise();
            
            // Orthogonalise with the vertex normal since it's currently
            // orthogonal with the face normals, but will be close to ortho
            // Apply Gram-Schmidt orthogonalise
            Vector3 temp = v.tangent;
            v.tangent = temp - (v.norm * v.norm.dotProduct(temp));
            
            temp = v.binormal;
            v.binormal = temp - (v.norm * v.norm.dotProduct(temp));
            
            // renormalize 
            v.tangent.normalise();
            v.binormal.normalise();
            
        }
    }

    //FIXME template and function conflict workaround. compiler bug?
    void remapIndexes(T)(T res) if(is(T: Result))
    {
        for (size_t i = 0; i < mIDataList.length; ++i)
        {
            
            IndexData idata = mIDataList[i];
            // Now do index data
            // no new buffer required, same size but some triangles remapped
            if (idata.indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_32BIT)
            {
                uint* p32 = cast(uint*)(idata.indexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_NORMAL));
                remapIndexes(p32, i, res);
            }
            else
            {
                ushort* p16 = cast(ushort*)(idata.indexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_NORMAL));
                remapIndexes(p16, i, res);
            }
            idata.indexBuffer.get().unlock();
        }
        
    }

    void remapIndexes(T)(T* ibuf, size_t indexSet, Result res)
    {
        foreach (remap; res.indexesRemapped)
        {
            // Note that because this is a vertex split situation, and vertex
            // split is only for some faces, it's not a case of replacing all
            // instances of vertex index A with vertex index B
            // It actually matters which triangle we're talking about, so drive
            // the update from the face index
            
            if (remap.indexSet == indexSet)
            {
                T* pBuf;
                pBuf = ibuf + remap.faceIndex * 3;
                
                for (int v = 0; v < 3; ++v, ++pBuf)
                {
                    if ((*pBuf) == remap.splitVertex.first)
                    {
                        *pBuf = cast(T)remap.splitVertex.second;
                    }
                }
            }
        }
    }
    
    void _remapIndexes(T)(T[] pBuf, size_t indexSet, Result res)
    {
        foreach (remap; res.indexesRemapped)
        {
            // Note that because this is a vertex split situation, and vertex
            // split is only for some faces, it's not a case of replacing all
            // instances of vertex index A with vertex index B
            // It actually matters which triangle we're talking about, so drive
            // the update from the face index
            
            if (remap.indexSet == indexSet)
            {
                auto idx = remap.faceIndex * 3;
                
                for (int v = 0; v < 3; ++v, ++idx)
                {
                    if (pBuf[idx] == remap.splitVertex.first)
                    {
                        pBuf[idx] = cast(T)remap.splitVertex.second;
                    }
                }
            }
        }
    }
}
/** @} */
/** @} */