module ogre.lod.patchsurface;

//import std.container;
import std.algorithm;
import std.array;

import ogre.rendersystem.vertex;
import ogre.math.vector;
import ogre.math.angles;
import ogre.compat;
import ogre.math.axisalignedbox;
import ogre.rendersystem.hardware;
import ogre.exception;
import ogre.math.maths;
import ogre.general.colourvalue;
import ogre.sharedptr;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup LOD
 *  @{
 */

auto LEVEL_WIDTH(T)(T lvl) 
{
    return ((1 << (lvl+1)) + 1);
}

/** A surface which is defined by curves of some kind to form a patch, e.g. a Bezier patch.
 @remarks
 This object will take a list of control points with various assorted data, and will
 subdivide it into a patch mesh. Currently only Bezier curves are supported for defining
 the surface, but other techniques such as NURBS would follow the same basic approach.
 */
class PatchSurface //: public PatchAlloc
{
public:
    this()
    {
        mType = PatchSurfaceType.PST_BEZIER;
    }

    ~this() {}
    
    enum PatchSurfaceType
    {
        /// A patch defined by a set of bezier curves
        PST_BEZIER
    }
    
    /// Constant for indicating automatic determination of subdivision level for patches
    enum
    {
        AUTO_LEVEL = -1
    }
    
    enum VisibleSide {
        /// The side from which u goes right and v goes up (as in texture coords)
        VS_FRONT,
        /// The side from which u goes right and v goes down (reverse of texture coords)
        VS_BACK,
        /// Both sides are visible - warning this creates 2x the number of triangles and adds extra overhead for calculating normals
        VS_BOTH
    }
    /** Sets up the surface by defining it's control points, type and initial subdivision level.
     @remarks
     This method initialises the surface by passing it a set of control points. The type of curves to be used
     are also defined here, although the only supported option currently is a bezier patch. You can also
     specify a global subdivision level here if you like, although it is recommended that the parameter
     is left as AUTO_LEVEL, which means the system decides how much subdivision is required (based on the
     curvature of the surface)
     @param
     controlPointBuffer A pointer to a buffer containing the vertex data which defines control points 
     of the curves rather than actual vertices. Note that you are expected to provide not
     just position information, but potentially normals and texture coordinates too. The
     format of the buffer is defined in the VertexDeclaration parameter
     @param
     declaration VertexDeclaration describing the contents of the buffer. 
     Note this declaration must _only_ draw on buffer source 0!
     @param
     width Specifies the width of the patch in control points.
     @param
     height Specifies the height of the patch in control points. 
     @param
     pType The type of surface - currently only PST_BEZIER is supported
     @param
     uMaxSubdivisionLevel,vMaxSubdivisionLevel If you want to manually set the top level of subdivision, 
     do it here, otherwise let the system decide.
     @param
     visibleSide Determines which side of the patch (or both) triangles are generated for.
     */
    void defineSurface(void* controlPointBuffer, 
                       ref VertexDeclaration declaration, size_t width, size_t height,
                       PatchSurfaceType pType = PatchSurfaceType.PST_BEZIER, 
                       size_t uMaxSubdivisionLevel = AUTO_LEVEL, size_t vMaxSubdivisionLevel = AUTO_LEVEL,
                       VisibleSide visibleSide = VisibleSide.VS_FRONT)
    {
        if (height == 0 || width == 0)
            return; // Do nothing - garbage
        
        mType = pType;
        mCtlWidth = width;
        mCtlHeight = height;
        mCtlCount = width * height;
        mControlPointBuffer = controlPointBuffer;
        mDeclaration = declaration;
        
        // Copy positions into Vector3 vector
        mVecCtlPoints.clear();
        VertexElement elem = declaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
        size_t vertSize = declaration.getVertexSize(0);
        ubyte *pVert = cast(ubyte*)(controlPointBuffer);
        float* pFloat;
        for (size_t i = 0; i < mCtlCount; ++i)
        {
            elem.baseVertexPointerToElement(cast(void*)pVert, &pFloat);
            mVecCtlPoints.insert(Vector3(pFloat[0], pFloat[1], pFloat[2]));
            pVert += vertSize;
        }
        
        mVSide = visibleSide;
        
        // Determine max level
        // Initialise to 100% detail
        mSubdivisionFactor = 1.0f;
        if (uMaxSubdivisionLevel == cast(size_t)AUTO_LEVEL)
        {
            mULevel = mMaxULevel = getAutoULevel();
        }
        else
        {
            mULevel = mMaxULevel = uMaxSubdivisionLevel;
        }
        
        if (vMaxSubdivisionLevel == cast(size_t)AUTO_LEVEL)
        {
            mVLevel = mMaxVLevel = getAutoVLevel();
        }
        else
        {
            mVLevel = mMaxVLevel = vMaxSubdivisionLevel;
        }
        
        
        
        // Derive mesh width / height
        mMeshWidth  = (LEVEL_WIDTH(mMaxULevel)-1) * ((mCtlWidth-1)/2) + 1;
        mMeshHeight = (LEVEL_WIDTH(mMaxVLevel)-1) * ((mCtlHeight-1)/2) + 1;
        
        
        // Calculate number of required vertices / indexes at max resolution
        mRequiredVertexCount = mMeshWidth * mMeshHeight;
        int iterations = (mVSide == VisibleSide.VS_BOTH)? 2 : 1;
        mRequiredIndexCount = (mMeshWidth-1) * (mMeshHeight-1) * 2 * iterations * 3;
        
        // Calculate bounds based on control points
        //vector<Vector3>::type::const_iterator ctli;
        Vector3 min = Vector3.ZERO, max = Vector3.UNIT_SCALE;
        Real maxSqRadius = 0;
        bool first = true;
        foreach (ctli; mVecCtlPoints)
        {
            if (first)
            {
                min = max = ctli;
                maxSqRadius = ctli.squaredLength();
                first = false;
            }
            else
            {
                min.makeFloor(ctli);
                max.makeCeil(ctli);
                maxSqRadius = std.algorithm.max(ctli.squaredLength(), maxSqRadius);
                
            }
        }
        mAABB.setExtents(min, max);
        mBoundingSphere = Math.Sqrt(maxSqRadius);
        
    }
    
    /** Based on a previous call to defineSurface, establishes the number of vertices required
     to hold this patch at the maximum detail level. 
     @remarks This is useful when you wish to build the patch into external vertex / index buffers.

     */
    size_t getRequiredVertexCount()
    {
        return mRequiredVertexCount;
    }
    /** Based on a previous call to defineSurface, establishes the number of indexes required
     to hold this patch at the maximum detail level. 
     @remarks This is useful when you wish to build the patch into external vertex / index buffers.

     */
    size_t getRequiredIndexCount()
    {
        return mRequiredIndexCount;
    }
    
    /** Gets the current index count based on the current subdivision level. */
    size_t getCurrentIndexCount()
    {
        return mCurrIndexCount;
    }

    /// Returns the index offset used by this buffer to write data into the buffer
    size_t getIndexOffset(){ return mIndexOffset; }
    /// Returns the vertex offset used by this buffer to write data into the buffer
    size_t getVertexOffset(){ return mVertexOffset; }
    
    
    /** Gets the bounds of this patch, only valid after calling defineSurface. */
    AxisAlignedBox getBounds()
    {
        return mAABB;
    }

    /** Gets the radius of the bounding sphere for this patch, only valid after defineSurface 
     has been called. */
    Real getBoundingSphereRadius()
    {
        return mBoundingSphere;
    }

    /** Tells the system to build the mesh relating to the surface into externally created
     buffers.
     @remarks
     The VertexDeclaration of the vertex buffer must be identical to the one passed into
     defineSurface.  In addition, there must be enough space in the buffer to 
     accommodate the patch at full detail level; you should call getRequiredVertexCount
     and getRequiredIndexCount to determine this. This method does not create an internal
     mesh for this patch and so getMesh will return null if you call it after building the
     patch this way.
     @param destVertexBuffer The destination vertex buffer in which to build the patch.
     @param vertexStart The offset at which to start writing vertices for this patch
     @param destIndexBuffer The destination index buffer in which to build the patch.
     @param vertexStart The offset at which to start writing indexes for this patch

     */
    void build(SharedPtr!HardwareVertexBuffer destVertexBuffer, size_t vertexStart,
               SharedPtr!HardwareIndexBuffer destIndexBuffer, size_t indexStart)
    {
        
        if (mVecCtlPoints.empty())
            return;
        
        mVertexBuffer = destVertexBuffer;
        mVertexOffset = vertexStart;
        mIndexBuffer = destIndexBuffer;
        mIndexOffset = indexStart;
        
        // Lock just the region we are interested in 
        void* lockedBuffer = mVertexBuffer.get().lock(
            mVertexOffset * mDeclaration.getVertexSize(0), 
            mRequiredVertexCount * mDeclaration.getVertexSize(0),
            HardwareBuffer.LockOptions.HBL_NO_OVERWRITE);
        
        distributeControlPoints(lockedBuffer);
        
        // Subdivide the curve to the MAX :)
        // Do u direction first, so need to step over v levels not done yet
        size_t vStep = 1 << mMaxVLevel;
        size_t uStep = 1 << mMaxULevel;
        
        size_t v, u;
        for (v = 0; v < mMeshHeight; v += vStep)
        {
            // subdivide this row in u
            subdivideCurve(lockedBuffer, v*mMeshWidth, uStep, mMeshWidth / uStep, mULevel);
        }
        
        // Now subdivide in v direction, this time all the u direction points are there so no step
        for (u = 0; u < mMeshWidth; ++u)
        {
            subdivideCurve(lockedBuffer, u, vStep*mMeshWidth, mMeshHeight / vStep, mVLevel);
        }
        
        
        mVertexBuffer.get().unlock();
        
        // Make triangles from mesh at this current level of detail
        makeTriangles();
        
    }
    
    /** Alters the level of subdivision for this surface.
     @remarks
     This method changes the proportionate detail level of the patch; since
     the U and V directions can have different subdivision levels, this method
     takes a single Real value where 0 is the minimum detail (the control points)
     and 1 is the maximum detail level as supplied to the original call to 
     defineSurface.
     */
    void setSubdivisionFactor(Real factor)
    {
        assert(factor >= 0.0f && factor <= 1.0f);
        
        mSubdivisionFactor = factor;
        mULevel = cast(size_t)(factor * mMaxULevel);
        mVLevel = cast(size_t)(factor * mMaxVLevel);
        
        makeTriangles();
    }
    
    /** Gets the current level of subdivision. */
    Real getSubdivisionFactor()
    {
        return mSubdivisionFactor;
    }
    
    void* getControlPointBuffer()
    {
        return mControlPointBuffer;
    }
    /** Convenience method for telling the patch that the control points have been 
     deleted, since once the patch has been built they are not required. */
    void notifyControlPointBufferDeallocated() { 
        mControlPointBuffer = null;
    }
protected:
    /// Vertex declaration describing the control point buffer
    VertexDeclaration mDeclaration;
    /// Buffer containing the system-memory control points
    void* mControlPointBuffer;
    /// Type of surface
    PatchSurfaceType mType;
    /// Width in control points
    size_t mCtlWidth;
    /// Height in control points
    size_t mCtlHeight;
    /// TotalNumber of control points
    size_t mCtlCount;
    /// U-direction subdivision level
    size_t mULevel;
    /// V-direction subdivision level
    size_t mVLevel;
    /// Max subdivision level
    size_t mMaxULevel;
    size_t mMaxVLevel;
    /// Width of the subdivided mesh (big enough for max level)
    size_t mMeshWidth;
    /// Height of the subdivided mesh (big enough for max level)
    size_t mMeshHeight;
    /// Which side is visible
    VisibleSide mVSide;
    
    Real mSubdivisionFactor;
    
    Vector3[] mVecCtlPoints;
    
    /** Internal method for finding the subdivision level given 3 control points.
     */
    size_t findLevel( ref Vector3 a, ref Vector3 b, ref Vector3 c)
    {
        // Derived from work by Bart Sekura in rogl
        // Apart from I think I fixed a bug - see below
        // I also commented the code, the only thing wrong with rogl is almost no comments!!
        
        size_t max_levels = 5;
        float subdiv = 10;
        size_t level;
        
        float test=subdiv*subdiv;
        Vector3 s,t,d;
        for(level=0; level<max_levels-1; level++)
        {
            // Subdivide the 2 lines
            s = a.midPoint(b);
            t = b.midPoint(c);
            // Find the midpoint between the 2 midpoints
            c = s.midPoint(t);
            // Get the vector between this subdivided midpoint and the middle point of the original line
            d = c - b;
            // Find the squared length, and break when small enough
            if(d.dotProduct(d) < test) {
                break;
            }
            b=a; 
        }
        
        return level;
        
    }
    
    void distributeControlPoints(void* lockedBuffer)
    {
        // Insert original control points into expanded mesh
        size_t uStep = 1 << mULevel;
        size_t vStep = 1 << mVLevel;
        
        
        void* pSrc = mControlPointBuffer;
        size_t vertexSize = mDeclaration.getVertexSize(0);
        float* pSrcReal, pDestReal;
        RGBA* pSrcRGBA, pDestRGBA;
        void* pDest;
        VertexElement elemPos = mDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
        VertexElement elemNorm = mDeclaration.findElementBySemantic(VertexElementSemantic.VES_NORMAL);
        VertexElement elemTex0 = mDeclaration.findElementBySemantic(VertexElementSemantic.VES_TEXTURE_COORDINATES, 0);
        VertexElement elemTex1 = mDeclaration.findElementBySemantic(VertexElementSemantic.VES_TEXTURE_COORDINATES, 1);
        VertexElement elemDiffuse = mDeclaration.findElementBySemantic(VertexElementSemantic.VES_DIFFUSE);
        for (size_t v = 0; v < mMeshHeight; v += vStep)
        {
            // set dest by v from base
            pDest = cast(void*)(
                cast(ubyte*)(lockedBuffer) + (vertexSize * mMeshWidth * v));
            for (size_t u = 0; u < mMeshWidth; u += uStep)
            {
                
                // Copy Position
                elemPos.baseVertexPointerToElement(pSrc, &pSrcReal);
                elemPos.baseVertexPointerToElement(pDest, &pDestReal);
                *pDestReal++ = *pSrcReal++;
                *pDestReal++ = *pSrcReal++;
                *pDestReal++ = *pSrcReal++;
                
                // Copy Normals
                if (elemNorm)
                {
                    elemNorm.baseVertexPointerToElement(pSrc, &pSrcReal);
                    elemNorm.baseVertexPointerToElement(pDest, &pDestReal);
                    *pDestReal++ = *pSrcReal++;
                    *pDestReal++ = *pSrcReal++;
                    *pDestReal++ = *pSrcReal++;
                }
                
                // Copy Diffuse
                if (elemDiffuse)
                {
                    elemDiffuse.baseVertexPointerToElement(pSrc, &pSrcRGBA);
                    elemDiffuse.baseVertexPointerToElement(pDest, &pDestRGBA);
                    *pDestRGBA++ = *pSrcRGBA++;
                }
                
                // Copy texture coords
                if (elemTex0)
                {
                    elemTex0.baseVertexPointerToElement(pSrc, &pSrcReal);
                    elemTex0.baseVertexPointerToElement(pDest, &pDestReal);
                    for (size_t dim = 0; dim < VertexElement.getTypeCount(elemTex0.getType()); ++dim)
                        *pDestReal++ = *pSrcReal++;
                }
                if (elemTex1)
                {
                    elemTex1.baseVertexPointerToElement(pSrc, &pSrcReal);
                    elemTex1.baseVertexPointerToElement(pDest, &pDestReal);
                    for (size_t dim = 0; dim < VertexElement.getTypeCount(elemTex1.getType()); ++dim)
                        *pDestReal++ = *pSrcReal++;
                }
                
                // Increment source by one vertex
                pSrc = cast(void*)(cast(ubyte*)(pSrc) + vertexSize);
                // Increment dest by 1 vertex * uStep
                pDest = cast(void*)(cast(ubyte*)(pDest) + (vertexSize * uStep));
            } // u
        } // v
        
        
    }

    void subdivideCurve(void* lockedBuffer, size_t startIdx, size_t stepSize, size_t numSteps, size_t iterations)
    {
        // Subdivides a curve within a sparsely populated buffer (gaps are already there to be interpolated into)
        size_t leftIdx, rightIdx, destIdx, halfStep, maxIdx;
        bool firstSegment;
        
        maxIdx = startIdx + (numSteps * stepSize);
        size_t step = stepSize;
        
        while(iterations--)
        {
            halfStep = step / 2;
            leftIdx = startIdx;
            destIdx = leftIdx + halfStep;
            rightIdx = leftIdx + step;
            firstSegment = true;
            while (leftIdx < maxIdx)
            {
                // Interpolate
                interpolateVertexData(lockedBuffer, leftIdx, rightIdx, destIdx);
                
                // If 2nd or more segment, interpolate current left between current and last mid points
                if (!firstSegment)
                {
                    interpolateVertexData(lockedBuffer, leftIdx - halfStep, leftIdx + halfStep, leftIdx);
                }
                // Next segment
                leftIdx = rightIdx;
                destIdx = leftIdx + halfStep;
                rightIdx = leftIdx + step;
                firstSegment = false;
            }
            
            step = halfStep;
        }
    }

    void interpolateVertexData(void* lockedBuffer, size_t leftIndex, size_t rightIndex, size_t destIndex)
    {
        size_t vertexSize = mDeclaration.getVertexSize(0);
        VertexElement elemPos = mDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
        VertexElement elemNorm = mDeclaration.findElementBySemantic(VertexElementSemantic.VES_NORMAL);
        VertexElement elemDiffuse = mDeclaration.findElementBySemantic(VertexElementSemantic.VES_DIFFUSE);
        VertexElement elemTex0 = mDeclaration.findElementBySemantic(VertexElementSemantic.VES_TEXTURE_COORDINATES, 0);
        VertexElement elemTex1 = mDeclaration.findElementBySemantic(VertexElementSemantic.VES_TEXTURE_COORDINATES, 1);
        
        float* pDestReal, pLeftReal, pRightReal;
        ubyte *pDestChar, pLeftChar, pRightChar;
        ubyte *pDest, pLeft, pRight;
        
        // Set up pointers & interpolate
        pDest = cast(ubyte*)(lockedBuffer) + (vertexSize * destIndex);
        pLeft = cast(ubyte*)(lockedBuffer) + (vertexSize * leftIndex);
        pRight = cast(ubyte*)(lockedBuffer) + (vertexSize * rightIndex);
        
        // Position
        elemPos.baseVertexPointerToElement(pDest, &pDestReal);
        elemPos.baseVertexPointerToElement(pLeft, &pLeftReal);
        elemPos.baseVertexPointerToElement(pRight, &pRightReal);
        
        *pDestReal++ = (*pLeftReal++ + *pRightReal++) * 0.5f;
        *pDestReal++ = (*pLeftReal++ + *pRightReal++) * 0.5f;
        *pDestReal++ = (*pLeftReal++ + *pRightReal++) * 0.5f;
        
        if (elemNorm)
        {
            elemNorm.baseVertexPointerToElement(pDest, &pDestReal);
            elemNorm.baseVertexPointerToElement(pLeft, &pLeftReal);
            elemNorm.baseVertexPointerToElement(pRight, &pRightReal);
            Vector3 norm;
            norm.x = (*pLeftReal++ + *pRightReal++) * 0.5f;
            norm.y = (*pLeftReal++ + *pRightReal++) * 0.5f;
            norm.z = (*pLeftReal++ + *pRightReal++) * 0.5f;
            norm.normalise();
            
            *pDestReal++ = norm.x;
            *pDestReal++ = norm.y;
            *pDestReal++ = norm.z;
        }
        if (elemDiffuse)
        {
            // Blend each byte individually
            elemDiffuse.baseVertexPointerToElement(pDest, &pDestChar);
            elemDiffuse.baseVertexPointerToElement(pLeft, &pLeftChar);
            elemDiffuse.baseVertexPointerToElement(pRight, &pRightChar);
            // 4 bytes to RGBA
            *pDestChar++ = cast(ubyte)(((*pLeftChar++) + (*pRightChar++)) * 0.5);
            *pDestChar++ = cast(ubyte)(((*pLeftChar++) + (*pRightChar++)) * 0.5);
            *pDestChar++ = cast(ubyte)(((*pLeftChar++) + (*pRightChar++)) * 0.5);
            *pDestChar++ = cast(ubyte)(((*pLeftChar++) + (*pRightChar++)) * 0.5);
        }
        if (elemTex0)
        {
            elemTex0.baseVertexPointerToElement(pDest, &pDestReal);
            elemTex0.baseVertexPointerToElement(pLeft, &pLeftReal);
            elemTex0.baseVertexPointerToElement(pRight, &pRightReal);
            
            for (size_t dim = 0; dim < VertexElement.getTypeCount(elemTex0.getType()); ++dim)
                *pDestReal++ = ((*pLeftReal++) + (*pRightReal++)) * 0.5f;
        }
        if (elemTex1)
        {
            elemTex1.baseVertexPointerToElement(pDest, &pDestReal);
            elemTex1.baseVertexPointerToElement(pLeft, &pLeftReal);
            elemTex1.baseVertexPointerToElement(pRight, &pRightReal);
            
            for (size_t dim = 0; dim < VertexElement.getTypeCount(elemTex1.getType()); ++dim)
                *pDestReal++ = ((*pLeftReal++) + (*pRightReal++)) * 0.5f;
        }
    }

    void makeTriangles()
    {
        // Our vertex buffer is subdivided to the highest level, we need to generate tris
        // which step over the vertices we don't need for this level of detail.
        
        // Calculate steps
        int vStep = 1 << (mMaxVLevel - mVLevel);
        int uStep = 1 << (mMaxULevel - mULevel);
        size_t currWidth = (LEVEL_WIDTH(mULevel)-1) * ((mCtlWidth-1)/2) + 1;
        size_t currHeight = (LEVEL_WIDTH(mVLevel)-1) * ((mCtlHeight-1)/2) + 1;
        
        bool use32bitindexes = (mIndexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_32BIT);
        
        // The mesh is built, just make a list of indexes to spit out the triangles
        int vInc, uInc;
        
        size_t vCount, uCount, v, u, iterations;
        
        if (mVSide == VisibleSide.VS_BOTH)
        {
            iterations = 2;
            vInc = vStep;
            v = 0; // Start with front
        }
        else
        {
            iterations = 1;
            if (mVSide == VisibleSide.VS_FRONT)
            {
                vInc = vStep;
                v = 0;
            }
            else
            {
                vInc = -vStep;
                v = mMeshHeight - 1;
            }
        }
        
        // Calc num indexes
        mCurrIndexCount = (currWidth - 1) * (currHeight - 1) * 6 * iterations;
        
        size_t v1, v2, v3;
        // Lock just the section of the buffer we need
        ushort* p16 = null;
        uint* p32 = null;
        if (use32bitindexes)
        {
            p32 = cast(uint*)(
                mIndexBuffer.get().lock(
                mIndexOffset * uint.sizeof, 
                mRequiredIndexCount * uint.sizeof, 
                HardwareBuffer.LockOptions.HBL_NO_OVERWRITE));
        }
        else
        {
            p16 = cast(ushort*)(
                mIndexBuffer.get().lock(
                mIndexOffset * ushort.sizeof, 
                mRequiredIndexCount * ushort.sizeof, 
                HardwareBuffer.LockOptions.HBL_NO_OVERWRITE));
        }
        
        while (iterations--)
        {
            // Make tris in a zigzag pattern (compatible with strips)
            u = 0;
            uInc = uStep; // Start with moving +u
            
            vCount = currHeight - 1;
            while (vCount--)
            {
                uCount = currWidth - 1;
                while (uCount--)
                {
                    // First Tri in cell
                    // -----------------
                    v1 = ((v + vInc) * mMeshWidth) + u;
                    v2 = (v * mMeshWidth) + u;
                    v3 = ((v + vInc) * mMeshWidth) + (u + uInc);
                    // Output indexes
                    if (use32bitindexes)
                    {
                        *p32++ = cast(uint)(v1);
                        *p32++ = cast(uint)(v2);
                        *p32++ = cast(uint)(v3);
                    }
                    else
                    {
                        *p16++ = cast(ushort)(v1);
                        *p16++ = cast(ushort)(v2);
                        *p16++ = cast(ushort)(v3);
                    }
                    // Second Tri in cell
                    // ------------------
                    v1 = ((v + vInc) * mMeshWidth) + (u + uInc);
                    v2 = (v * mMeshWidth) + u;
                    v3 = (v * mMeshWidth) + (u + uInc);
                    // Output indexes
                    if (use32bitindexes)
                    {
                        *p32++ = cast(uint)(v1);
                        *p32++ = cast(uint)(v2);
                        *p32++ = cast(uint)(v3);
                    }
                    else
                    {
                        *p16++ = cast(ushort)(v1);
                        *p16++ = cast(ushort)(v2);
                        *p16++ = cast(ushort)(v3);
                    }
                    
                    // Next column
                    u += uInc;
                }
                // Next row
                v += vInc;
                u = 0;
                
                
            }
            
            // Reverse vInc for double sided
            v = mMeshHeight - 1;
            vInc = -vInc;
            
        }
        
        mIndexBuffer.get().unlock();
        
        
    }
    
    size_t getAutoULevel(bool forMax = false)
    {
        // determine levels
        // Derived from work by Bart Sekura in Rogl
        Vector3 a,b,c;
        size_t u,v;
        bool found=false;
        // Find u level
        for(v = 0; v < mCtlHeight; v++) {
            for(u = 0; u < mCtlWidth-1; u += 2) {
                a = mVecCtlPoints[v * mCtlWidth + u];
                b = mVecCtlPoints[v * mCtlWidth + u+1];
                c = mVecCtlPoints[v * mCtlWidth + u+2];
                if(a!=c) {
                    found=true;
                    break;
                }
            }
            if(found) break;
        }
        if(!found) {
            throw new InternalError("Can't find suitable control points for determining U subdivision level",
                                    "PatchSurface.getAutoULevel");
        }
        
        return findLevel(a,b,c);
        
    }
    size_t getAutoVLevel(bool forMax = false)
    {
        Vector3 a,b,c;
        size_t u,v;
        bool found=false;
        for(u = 0; u < mCtlWidth; u++) {
            for(v = 0; v < mCtlHeight-1; v += 2) {
                a = mVecCtlPoints[v * mCtlWidth + u];
                b = mVecCtlPoints[(v+1) * mCtlWidth + u];
                c = mVecCtlPoints[(v+2) * mCtlWidth + u];
                if(a!=c) {
                    found=true;
                    break;
                }
            }
            if(found) break;
        }
        if(!found) {
            throw new InternalError("Can't find suitable control points for determining V subdivision level",
                                    "PatchSurface.getAutoVLevel");
        }
        
        return findLevel(a,b,c);
        
    }
    
    SharedPtr!HardwareVertexBuffer mVertexBuffer;
    SharedPtr!HardwareIndexBuffer mIndexBuffer;
    size_t mVertexOffset;
    size_t mIndexOffset;
    size_t mRequiredVertexCount;
    size_t mRequiredIndexCount;
    size_t mCurrIndexCount;
    
    AxisAlignedBox mAABB;
    Real mBoundingSphere;

}

/** @} */
/** @} */