module ogre.math.optimisedutil;

import ogre.math.matrix;
import ogre.compat;
import ogre.math.vector;
import ogre.math.angles;
import ogre.math.edgedata;
import ogre.math.maths;
import ogre.sharedptr;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Math
 *  @{
 */
/** Utility class for provides optimised functions.
 @note
 This class are supposed used by internal engine only.
 */
class OptimisedUtil
{
private:
    /// Privated copy constructor, to prevent misuse
    //this(OptimisedUtil rhs); /* do nothing, should not use */
    /// Privated operator=, to prevent misuse
    //OptimisedUtil& operator=(OptimisedUtil& rhs); /* do not use */
    
protected:
    /// Store a pointer to the implementation
    static OptimisedUtil msImplementation;

    static this()
    {
        msImplementation = _detectImplementation();
    }

    
    /// Detect best implementation based on run-time environment
    static OptimisedUtil _detectImplementation()
    {
        //
        // Some speed test results (averaged number of CPU timestamp (RDTSC) per-function call):
        //
        //   Dagon SkeletonAnimation sample - softwareVertexSkinning:
        //
        //                                      Pentium 4 3.0G HT       Athlon XP 2500+     Athlon 64 X2 Dual Core 3800+
        //
        //      Shared Buffers, General C       763677                  462903              473038
        //      Shared Buffers, Unrolled SSE    210030 *best*           369762              228328 *best*
        //      Shared Buffers, General SSE     286202                  352412 *best*       302796
        //
        //      Separated Buffers, General C    762640                  464840              478740
        //      Separated Buffers, Unrolled SSE 219222 *best*           287992 *best*       238770 *best*
        //      Separated Buffers, General SSE  290129                  341614              307262
        //
        //      PosOnly, General C              388663                  257350              262831
        //      PosOnly, Unrolled SSE           139814 *best*           200323 *best*       168995 *best*
        //      PosOnly, General SSE            172693                  213704              175447
        //
        //   Another my own test scene - softwareVertexSkinning:
        //
        //                                      Pentium P4 3.0G HT      Athlon XP 2500+
        //
        //      Shared Buffers, General C       74527                   -
        //      Shared Buffers, Unrolled SSE    22743 *best*            -
        //      Shared Buffers, General SSE     28527                   -
        //
        //
        // Note that speed test appears unaligned load/store instructor version
        // loss performance 5%-10% than aligned load/store version, even if both
        // of them access to aligned data. Thus, we should use aligned load/store
        // as soon as possible.
        //
        //
        // We are pick up the implementation based on test results above.
        //
        /*
         version(__DO_PROFILE__)
         {
         {
         static OptimisedUtilProfiler msOptimisedUtilProfiler;
         return &msOptimisedUtilProfiler;
         }
         }
         else   // !__DO_PROFILE__
         {
         version(__OGRE_HAVE_SSE)
         {
         if (PlatformInformation.getCpuFeatures() & PlatformInformation.CPU_FEATURE_SSE)
         {
         return _getOptimisedUtilSSE();
         }
         else
         //#elif __OGRE_HAVE_VFP
         //        if (PlatformInformation::getCpuFeatures() & PlatformInformation::CPU_FEATURE_VFP)
         //        {
         //            return _getOptimisedUtilVFP();
         //        }
         //        else
         //#elif __OGRE_HAVE_NEON
         //        if (PlatformInformation::getCpuFeatures() & PlatformInformation::CPU_FEATURE_NEON)
         //        {
         //            return _getOptimisedUtilNEON();
         //        }
         //        else

         } // __OGRE_HAVE_SSE
         {
         version(__OGRE_HAVE_DIRECTXMATH)
         return _getOptimisedUtilDirectXMath();
         else // __OGRE_HAVE_DIRECTXMATH
         return _getOptimisedUtilGeneral();
         }
         
         }// __DO_PROFILE__
         */
        return _getOptimisedUtilGeneral();
    }
    
public:
    // Default constructor
    this() {}
    // Destructor
    ~this() {}
    
    /** Gets the implementation of this class.
     @note
     Don't cache the pointer returned by this function, it'll change due
     run-time environment detection to pick up the best implementation.
     */
    ref static OptimisedUtil getImplementation() { return msImplementation; }
    
    /** Performs software vertex skinning.
     @param srcPosPtr Pointer to source position buffer.
     @param destPosPtr Pointer to destination position buffer.
     @param srcNormPtr Pointer to source normal buffer, if NULL,
     means blend position only.
     @param destNormPtr Pointer to destination normal buffer, it's
     ignored if srcNormPtr is NULL.
     @param blendWeightPtr Pointer to blend weight buffer.
     @param blendIndexPtr Pointer to blend index buffer.
     @param blendMatrices An array of pointer of blend matrix, the matrix
     must be aligned to SIMD alignment, but not necessary for the array
     itself.
     @param srcPosStride The stride of source position in bytes.
     @param destPosStride The stride of destination position in bytes.
     @param srcNormStride The stride of source normal in bytes,
     it's ignored if srcNormPtr is NULL.
     @param destNormStride The stride of destination normal in bytes,
     it's ignored if srcNormPtr is NULL.
     @param blendWeightStride The stride of blend weight buffer in bytes.
     @param blendIndexStride The stride of blend index buffer in bytes.
     @param numWeightsPerVertex Number of blend weights per-vertex, as well
     as for blend indices.
     @param numVertices Number of vertices to blend.
     */
    abstract void softwareVertexSkinning(
        float *srcPosPtr, float *destPosPtr,
        float *srcNormPtr, float *destNormPtr,
        float *blendWeightPtr,ubyte* blendIndexPtr,
        Matrix4[] blendMatrices,
        size_t srcPosStride, size_t destPosStride,
        size_t srcNormStride, size_t destNormStride,
        size_t blendWeightStride, size_t blendIndexStride,
        size_t numWeightsPerVertex,
        size_t numVertices);
    
    /** Performs a software vertex morph, of the kind used for
     morph animation although it can be used for other purposes. 
     @remarks
     This function will linearly interpolate positions between two
     source buffers, into a third buffer.
     @param t Parametric distance between the start and end positions
     @param srcPos1 Pointer to buffer for the start positions
     @param srcPos2 Pointer to buffer for the end positions
     @param dstPos Pointer to buffer for the destination positions
     @param pos1VSize, pos2VSize, dstVSize Vertex sizes in bytes of each of the 3 buffers referenced
     @param numVertices Number of vertices to morph, which agree with
     the number in start, end and destination buffer. Bear in mind
     three floating-point values per vertex
     */
    abstract void softwareVertexMorph(
        Real t,
        float *srcPos1,float *srcPos2,
        float *dstPos,
        size_t pos1VSize, size_t pos2VSize, size_t dstVSize, 
        size_t numVertices,
        bool morphNormals);
    
    /** Concatenate an affine matrix to an array of affine matrices.
     @note
     An affine matrix is a 4x4 matrix with row 3 equal to (0, 0, 0, 1),
     e.g. no projective coefficients.
     @param baseMatrix The matrix used as first operand.
     @param srcMatrices An array of matrix used as second operand.
     @param dstMatrices An array of matrix to store matrix concatenate results.
     @param numMatrices Number of matrices in the array.
     */
    abstract void concatenateAffineMatrices(
        Matrix4 baseMatrix,
        ref Matrix4[] srcMatrices,
        ref Matrix4[] dstMatrices,
        size_t numMatrices);
    
    /** Calculate the face normals for the triangles based on position
     information.
     @param positions Pointer to position information, which packed in
     (x, y, z) format, indexing by vertex index in the triangle. No
     alignment requests.
     @param triangles The triangles need to calculate face normal, the vertex
     positions is indexed by vertex index to position information.
     @param faceNormals The array of Vector4 used to store triangles face normal,
     Must be aligned to SIMD alignment.
     @param numTriangles Number of triangles to calculate face normal.
     */
    abstract void calculateFaceNormals(
        float *positions,
        EdgeData.Triangle *triangles,
        Vector4 *faceNormals,
        size_t numTriangles);
    
    /** Calculate the light facing state of the triangle's face normals
     @remarks
     This is normally the first stage of calculating a silhouette, i.e.
     establishing which tris are facing the light and which are facing
     away.
     @param lightPos 4D position of the light in object space, note that
     for directional lights (which have no position), the w component
     is 0 and the x/y/z position are the direction.
     @param faceNormals An array of face normals for the triangles, the face
     normal are unit vector orthogonal to the triangles, plus distance
     from origin. This array must be aligned to SIMD alignment.
     @param lightFacings An array of flags for store light facing state
     results, the result flag is true if corresponding face normal facing
     the light, false otherwise. This array no alignment requires.
     @param numFaces Number of face normals to calculate.
     */
    abstract void calculateLightFacing(
        Vector4 lightPos,
        ref Vector4[] faceNormals,
        ref ubyte[] lightFacings,
        size_t numFaces);
    
    /** Extruding vertices by a fixed distance based on light position.
     @param lightPos 4D light position, when w=0.0f this represents a
     directional light, otherwise, w must be equal to 1.0f, which
     represents a point light.
     @param extrudeDist The distance to extrude.
     @param srcPositions Pointer to source vertex's position buffer, which
     the position is a 3D vector packed in xyz format. No SIMD alignment
     requirement but loss performance for unaligned data.
     @param destPositions Pointer to destination vertex's position buffer,
     which the position is a 3D vector packed in xyz format. No SIMD
     alignment requirement but loss performance for unaligned data.
     @param numVertices Number of vertices need to extruding, which agree
     with source and destination buffers.
     */
    abstract void extrudeVertices(
        Vector4 lightPos,
        Real extrudeDist,
        float* srcPositions,
        float* destPositions,
        size_t numVertices);
}

/** Returns raw offseted of the given pointer.
 @note
 The offset are in bytes, no matter what type of the pointer.
 */
static T* rawOffsetPointer(T)(T* ptr, ptrdiff_t offset)
{
    return cast(T*)(cast(ubyte*)(ptr) + offset);
}

/** Advance the pointer with raw offset.
 @note
 The offset are in bytes, no matter what type of the pointer.
 */
static void advanceRawPointer(T)(ref T* ptr, ptrdiff_t offset)
{
    ptr = rawOffsetPointer(ptr, offset);
}


/** General implementation of OptimisedUtil.
 @note
 Don't use this class directly, use OptimisedUtil instead.
 */
class OptimisedUtilGeneral : OptimisedUtil
{
    override void softwareVertexSkinning(
        float *pSrcPos, float *pDestPos,
        float *pSrcNorm, float *pDestNorm,
        float *pBlendWeight, ubyte* pBlendIndex,
        Matrix4[] blendMatrices,
        size_t srcPosStride, size_t destPosStride,
        size_t srcNormStride, size_t destNormStride,
        size_t blendWeightStride, size_t blendIndexStride,
        size_t numWeightsPerVertex,
        size_t numVertices)
    {
        // Source vectors
        Vector3 sourceVec = Vector3.ZERO, sourceNorm = Vector3.ZERO;
        // Accumulation vectors
        Vector3 accumVecPos, accumVecNorm;
        
        // Loop per vertex
        for (size_t vertIdx = 0; vertIdx < numVertices; ++vertIdx)
        {
            // Load source vertex elements
            sourceVec.x = pSrcPos[0];
            sourceVec.y = pSrcPos[1];
            sourceVec.z = pSrcPos[2];
            
            if (pSrcNorm)
            {
                sourceNorm.x = pSrcNorm[0];
                sourceNorm.y = pSrcNorm[1];
                sourceNorm.z = pSrcNorm[2];
            }
            
            // Load accumulators
            accumVecPos = Vector3.ZERO;
            accumVecNorm = Vector3.ZERO;
            
            // Loop per blend weight
            //
            // Note: Don't change "unsigned short" here!!! If use "size_t" instead,
            // VC7.1 unroll this loop to four blend weights pre-iteration, and then
            // loss performance 10% in this function. Ok, this give a hint that we
            // should unroll this loop manually for better performance, will do that
            // later.
            //
            for (short blendIdx = 0; blendIdx < numWeightsPerVertex; ++blendIdx)
            {
                // Blend by multiplying source by blend matrix and scaling by weight
                // Add to accumulator
                // NB weights must be normalised!!
                Real weight = pBlendWeight[blendIdx];
                if (weight)
                {
                    // Blend position, use 3x4 matrix
                    Matrix4 mat = blendMatrices[pBlendIndex[blendIdx]];
                    accumVecPos.x +=
                        (mat[0][0] * sourceVec.x +
                         mat[0][1] * sourceVec.y +
                         mat[0][2] * sourceVec.z +
                         mat[0][3])
                            * weight;
                    accumVecPos.y +=
                        (mat[1][0] * sourceVec.x +
                         mat[1][1] * sourceVec.y +
                         mat[1][2] * sourceVec.z +
                         mat[1][3])
                            * weight;
                    accumVecPos.z +=
                        (mat[2][0] * sourceVec.x +
                         mat[2][1] * sourceVec.y +
                         mat[2][2] * sourceVec.z +
                         mat[2][3])
                            * weight;
                    if (pSrcNorm)
                    {
                        // Blend normal
                        // We should blend by inverse transpose here, but because we're assuming the 3x3
                        // aspect of the matrix is orthogonal (no non-uniform scaling), the inverse transpose
                        // is equal to the main 3x3 matrix
                        // Note because it's a normal we just extract the rotational part, saves us renormalising here
                        accumVecNorm.x +=
                            (mat[0][0] * sourceNorm.x +
                             mat[0][1] * sourceNorm.y +
                             mat[0][2] * sourceNorm.z)
                                * weight;
                        accumVecNorm.y +=
                            (mat[1][0] * sourceNorm.x +
                             mat[1][1] * sourceNorm.y +
                             mat[1][2] * sourceNorm.z)
                                * weight;
                        accumVecNorm.z +=
                            (mat[2][0] * sourceNorm.x +
                             mat[2][1] * sourceNorm.y +
                             mat[2][2] * sourceNorm.z)
                                * weight;
                    }
                }
            }
            
            // Stored blended vertex in hardware buffer
            pDestPos[0] = accumVecPos.x;
            pDestPos[1] = accumVecPos.y;
            pDestPos[2] = accumVecPos.z;
            
            // Stored blended vertex in temp buffer
            if (pSrcNorm)
            {
                // Normalise
                accumVecNorm.normalise();
                pDestNorm[0] = accumVecNorm.x;
                pDestNorm[1] = accumVecNorm.y;
                pDestNorm[2] = accumVecNorm.z;
                // Advance pointers
                advanceRawPointer(pSrcNorm, srcNormStride);
                advanceRawPointer(pDestNorm, destNormStride);
            }
            
            // Advance pointers
            advanceRawPointer(pSrcPos, srcPosStride);
            advanceRawPointer(pDestPos, destPosStride);
            advanceRawPointer(pBlendWeight, blendWeightStride);
            advanceRawPointer(pBlendIndex, blendIndexStride);
        }
    }

    override void concatenateAffineMatrices(
        Matrix4 baseMatrix,
        ref Matrix4[] pSrcMat,
        ref Matrix4[] d,//pDstMat,
        size_t numMatrices)
    {
        Matrix4 m = baseMatrix;
        
        for (size_t i = 0; i < numMatrices; ++i)
        {
            Matrix4 s = pSrcMat[i];
            //Matrix4* d = &pDstMat[i];
            
            // TODO: Promote following code to Matrix4 class.
            
            d[i][0, 0] = m[0, 0] * s[0, 0] + m[0, 1] * s[1, 0] + m[0, 2] * s[2, 0];
            d[i][0, 1] = m[0, 0] * s[0, 1] + m[0, 1] * s[1, 1] + m[0, 2] * s[2, 1];
            d[i][0, 2] = m[0, 0] * s[0, 2] + m[0, 1] * s[1, 2] + m[0, 2] * s[2, 2];
            d[i][0, 3] = m[0, 0] * s[0, 3] + m[0, 1] * s[1, 3] + m[0, 2] * s[2, 3] + m[0, 3];
            
            d[i][1, 0] = m[1, 0] * s[0, 0] + m[1, 1] * s[1, 0] + m[1, 2] * s[2, 0];
            d[i][1, 1] = m[1, 0] * s[0, 1] + m[1, 1] * s[1, 1] + m[1, 2] * s[2, 1];
            d[i][1, 2] = m[1, 0] * s[0, 2] + m[1, 1] * s[1, 2] + m[1, 2] * s[2, 2];
            d[i][1, 3] = m[1, 0] * s[0, 3] + m[1, 1] * s[1, 3] + m[1, 2] * s[2, 3] + m[1, 3];
            
            d[i][2, 0] = m[2, 0] * s[0, 0] + m[2, 1] * s[1, 0] + m[2, 2] * s[2, 0];
            d[i][2, 1] = m[2, 0] * s[0, 1] + m[2, 1] * s[1, 1] + m[2, 2] * s[2, 1];
            d[i][2, 2] = m[2, 0] * s[0, 2] + m[2, 1] * s[1, 2] + m[2, 2] * s[2, 2];
            d[i][2, 3] = m[2, 0] * s[0, 3] + m[2, 1] * s[1, 3] + m[2, 2] * s[2, 3] + m[2, 3];
            
            d[i][3, 0] = 0;
            d[i][3, 1] = 0;
            d[i][3, 2] = 0;
            d[i][3, 3] = 1;
            
            //++pSrcMat;
            //++pDstMat;
        }
    }

    override void softwareVertexMorph(
        Real t,
        float *pSrc1, float *pSrc2,
        float *pDst,
        size_t pos1VSize, size_t pos2VSize, size_t dstVSize,
        size_t numVertices,
        bool morphNormals)
    {
        size_t src1Skip = pos1VSize/float.sizeof - 3 - (morphNormals ? 3 : 0);
        size_t src2Skip = pos2VSize/float.sizeof - 3 - (morphNormals ? 3 : 0);
        size_t dstSkip = dstVSize/float.sizeof - 3 - (morphNormals ? 3 : 0);
        
        Vector3 nlerpNormal;
        for (size_t i = 0; i < numVertices; ++i)
        {
            // x
            *pDst++ = *pSrc1 + t * (*pSrc2 - *pSrc1) ;
            ++pSrc1; ++pSrc2;
            // y
            *pDst++ = *pSrc1 + t * (*pSrc2 - *pSrc1) ;
            ++pSrc1; ++pSrc2;
            // z
            *pDst++ = *pSrc1 + t * (*pSrc2 - *pSrc1) ;
            ++pSrc1; ++pSrc2;
            
            if (morphNormals)
            {
                // normals must be in the same buffer as pos
                // perform an nlerp
                // we don't have enough information for a spherical interp
                nlerpNormal.x = *pSrc1 + t * (*pSrc2 - *pSrc1);
                ++pSrc1; ++pSrc2;
                nlerpNormal.y = *pSrc1 + t * (*pSrc2 - *pSrc1);
                ++pSrc1; ++pSrc2;
                nlerpNormal.z = *pSrc1 + t * (*pSrc2 - *pSrc1);
                ++pSrc1; ++pSrc2;
                nlerpNormal.normalise();
                *pDst++ = nlerpNormal.x;
                *pDst++ = nlerpNormal.y;                
                *pDst++ = nlerpNormal.z;                
            }
            
            pSrc1 += src1Skip;
            pSrc2 += src2Skip;
            pDst += dstSkip;
            
        }
    }

    override void calculateFaceNormals(
        float *positions,
        EdgeData.Triangle *triangles,
        Vector4 *faceNormals,
        size_t numTriangles)
    {
        for ( ; numTriangles; --numTriangles)
        {
            EdgeData.Triangle t = *triangles++;
            size_t offset;
            
            offset = t.vertIndex[0] * 3;
            auto v1 = Vector3(positions[offset+0], positions[offset+1], positions[offset+2]);
            
            offset = t.vertIndex[1] * 3;
            auto v2 = Vector3(positions[offset+0], positions[offset+1], positions[offset+2]);
            
            offset = t.vertIndex[2] * 3;
            auto v3 = Vector3(positions[offset+0], positions[offset+1], positions[offset+2]);
            
            *faceNormals++ = Math.calculateFaceNormalWithoutNormalize(v1, v2, v3);
        }
    }

    override void calculateLightFacing(
        Vector4 lightPos,
        ref Vector4[] faceNormals,
        ref ubyte[] lightFacings,
        size_t numFaces)
    {
        for (size_t i = 0; i < numFaces; ++i)
        {
            lightFacings[i] = (lightPos.dotProduct(faceNormals[i]) > 0);
        }
    }

    override void extrudeVertices(
        Vector4 lightPos,
        Real extrudeDist,
        float* pSrcPos,
        float* pDestPos,
        size_t numVertices)
    {
        if (lightPos.w == 0.0f)
        {
            // Directional light, extrusion is along light direction
            
            auto extrusionDir = Vector3(
                -lightPos.x,
                -lightPos.y,
                -lightPos.z);
            extrusionDir.normalise();
            extrusionDir *= extrudeDist;
            
            for (size_t vert = 0; vert < numVertices; ++vert)
            {
                *pDestPos++ = *pSrcPos++ + extrusionDir.x;
                *pDestPos++ = *pSrcPos++ + extrusionDir.y;
                *pDestPos++ = *pSrcPos++ + extrusionDir.z;
            }
        }
        else
        {
            // Point light, calculate extrusionDir for every vertex
            assert(lightPos.w == 1.0f);
            
            for (size_t vert = 0; vert < numVertices; ++vert)
            {
                auto extrusionDir = Vector3(
                    pSrcPos[0] - lightPos.x,
                    pSrcPos[1] - lightPos.y,
                    pSrcPos[2] - lightPos.z);
                extrusionDir.normalise();
                extrusionDir *= extrudeDist;
                
                *pDestPos++ = *pSrcPos++ + extrusionDir.x;
                *pDestPos++ = *pSrcPos++ + extrusionDir.y;
                *pDestPos++ = *pSrcPos++ + extrusionDir.z;
            }
        }
    }
}

OptimisedUtil _getOptimisedUtilGeneral()
{
    static OptimisedUtilGeneral msOptimisedUtilGeneral;
    if(msOptimisedUtilGeneral is null)
        msOptimisedUtilGeneral = new OptimisedUtilGeneral;
    return msOptimisedUtilGeneral;
}

/** @} */
/** @} */