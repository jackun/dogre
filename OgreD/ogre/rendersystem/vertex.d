module ogre.rendersystem.vertex;

import core.stdc.string;

//import std.container;
import std.algorithm;
import ogre.rendersystem.hardware;
import ogre.general.colourvalue;
import ogre.compat;
import ogre.config;
import ogre.exception;
import ogre.general.root;
import ogre.rendersystem.rendersystem;
import ogre.sharedptr;

/// Vertex element semantics, used to identify the meaning of vertex buffer contents
enum VertexElementSemantic {
    /// Position, 3 reals per vertex
    VES_POSITION = 1,
    /// Blending weights
    VES_BLEND_WEIGHTS = 2,
    /// Blending indices
    VES_BLEND_INDICES = 3,
    /// Normal, 3 reals per vertex
    VES_NORMAL = 4,
    /// Diffuse colours
    VES_DIFFUSE = 5,
    /// Specular colours
    VES_SPECULAR = 6,
    /// Texture coordinates
    VES_TEXTURE_COORDINATES = 7,
    /// Binormal (Y axis if normal is Z)
    VES_BINORMAL = 8,
    /// Tangent (X axis if normal is Z)
    VES_TANGENT = 9,
    /// The  number of VertexElementSemantic elements (note - the first value VES_POSITION is 1)
    VES_COUNT = 9
}

/// Vertex element type, used to identify the base types of the vertex contents
enum VertexElementType
{
    VET_FLOAT1 = 0,
    VET_FLOAT2 = 1,
    VET_FLOAT3 = 2,
    VET_FLOAT4 = 3,
    /// alias to more specific colour type - use the current rendersystem's colour packing
    VET_COLOUR = 4,
    VET_SHORT1 = 5,
    VET_SHORT2 = 6,
    VET_SHORT3 = 7,
    VET_SHORT4 = 8,
    VET_UBYTE4 = 9,
    /// D3D style compact colour
    VET_COLOUR_ARGB = 10,
    /// GL style compact colour
    VET_COLOUR_ABGR = 11,
    VET_DOUBLE1 = 12,
    VET_DOUBLE2 = 13,
    VET_DOUBLE3 = 14,
    VET_DOUBLE4 = 15,
    VET_USHORT1 = 16,
    VET_USHORT2 = 17,
    VET_USHORT3 = 18,
    VET_USHORT4 = 19,      
    VET_INT1 = 20,
    VET_INT2 = 21,
    VET_INT3 = 22,
    VET_INT4 = 23,
    VET_UINT1 = 24,
    VET_UINT2 = 25,
    VET_UINT3 = 26,
    VET_UINT4 = 27
}

/** Summary class collecting together index data source information. */
class IndexData// : public IndexDataAlloc
{
protected:
    /// Protected copy constructor, to prevent misuse
    this(IndexData rhs){} /* do nothing, should not use */
    /// Protected operator=, to prevent misuse
    //TODO class opAssign overload is illegal
    //IndexData opAssign(IndexData rhs){ assert(0); } /* do not use */
public:
    this()
    {
        indexCount = 0;
        indexStart = 0;
        
    }
    ~this()
    {
    }
    /// pointer to the HardwareIndexBuffer to use, must be specified if useIndexes = true
    SharedPtr!HardwareIndexBuffer indexBuffer;
    
    /// index in the buffer to start from for this operation
    size_t indexStart;
    
    /// The number of indexes to use from the buffer
    size_t indexCount;
    
    /** Clones this index data, potentially including replicating the index buffer.
     @param copyData Whether to create new buffers too or just reference the existing ones
     @param mgr If supplied, the buffer manager through which copies should be made
     @remarks The caller is expected to delete the returned pointer when finished
     */
    IndexData clone(bool copyData = true, /+ref+/ HardwareBufferManagerBase mgr = null)//ref can't be null
    {
        HardwareBufferManagerBase pManager = mgr ? mgr : HardwareBufferManager.getSingleton();
        auto dest = new IndexData();
        if (indexBuffer.get())
        {
            if (copyData)
            {
                dest.indexBuffer = pManager.createIndexBuffer(indexBuffer.get().getType(), indexBuffer.get().getNumIndexes(),
                                                              indexBuffer.get().getUsage(), indexBuffer.get().hasShadowBuffer());
                dest.indexBuffer.get().copyData(indexBuffer.get(), 0, 0, indexBuffer.get().getSizeInBytes(), true);
            }
            else
            {
                dest.indexBuffer = indexBuffer;
            }
        }
        dest.indexCount = indexCount;
        dest.indexStart = indexStart;
        return dest;
    }
    
    /** Re-order the indexes in this index data structure to be more
     vertex cache friendly; that is to re-use the same vertices as close
     together as possible.
     @remarks
     Can only be used for index data which consists of triangle lists.
     It would in fact be pointless to use it on triangle strips or fans
     in any case.
     */
    void optimiseVertexCacheTriList()
    {
        if (indexBuffer.get().isLocked()) return;
        
        void *buffer = indexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_NORMAL);

        Triangle[] tmp16;//temp array for ushorts
        Triangle* triangles;
        uint *dest;
        
        size_t nIndexes = indexCount;
        size_t nTriangles = nIndexes / 3;
        size_t i, j;
        ushort *source = null;
        
        if (indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_16BIT)
        {
            tmp16 = new Triangle[nTriangles];//OGRE_ALLOC_T(Triangle, nTriangles, MEMCATEGORY_GEOMETRY);
            triangles = tmp16.ptr;
            source = cast(ushort *)buffer;
            dest = cast(uint *)triangles;
            for (i = 0; i < nIndexes; ++i) dest[i] = source[i];
        }
        else
            triangles = cast(Triangle*)buffer;
            
        
        // sort triangles based on shared edges
        uint[] destlist = new uint[nTriangles];//OGRE_ALLOC_T(uint, nTriangles, MEMCATEGORY_GEOMETRY);
        ubyte[] visited = new ubyte[nTriangles];//OGRE_ALLOC_T(ubyte, nTriangles, MEMCATEGORY_GEOMETRY);
        
        for (i = 0; i < nTriangles; ++i) visited[i] = 0;
        
        uint start = 0, ti = 0, destcount = 0;
        
        bool found = false;
        for (i = 0; i < nTriangles; ++i)
        {
            if (found)
                found = false;
            else
            {
                while (visited[start++]){}
                ti = start - 1;
            }
            
            destlist[destcount++] = ti;
            visited[ti] = 1;
            
            for (j = start; j < nTriangles; ++j)
            {
                if (visited[j]) continue;
                
                if (triangles[ti].sharesEdge(triangles[j]))
                {
                    found = true;
                    ti = cast(uint)(j);
                    break;
                }
            }
        }
        
        if (indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_16BIT)
        {
            // reorder the indexbuffer
            j = 0;
            for (i = 0; i < nTriangles; ++i)
            {
                Triangle t = triangles[destlist[i]];
                if(source)
                {
                    source[j++] = cast(ushort)t.a;
                    source[j++] = cast(ushort)t.b;
                    source[j++] = cast(ushort)t.c;
                }
            }
            //OGRE_FREE(triangles, MEMCATEGORY_GEOMETRY);
            triangles = null;
            destroy(tmp16);
        }
        else
        {
            uint[] reflist = new uint[nTriangles];//OGRE_ALLOC_T(uint, nTriangles, MEMCATEGORY_GEOMETRY);
            
            // fill the referencebuffer
            for (i = 0; i < nTriangles; ++i)
                reflist[destlist[i]] = cast(uint)(i);
            
            // reorder the indexbuffer
            for (i = 0; i < nTriangles; ++i)
            {
                j = destlist[i];
                if (i == j) continue; // do not move triangle
                
                // swap triangles
                
                Triangle t = triangles[i];
                triangles[i] = triangles[j];
                triangles[j] = t;
                
                // change reference
                destlist[reflist[i]] = cast(uint)(j);
                // destlist[i] = i; // not needed, it will not be used
            }
            
            //OGRE_FREE(reflist, MEMCATEGORY_GEOMETRY);
            destroy(reflist);
        }
        
        destroy(destlist);
        destroy(visited);
        
        indexBuffer.get().unlock();
    }
    
    // Local Utility class for vertex cache optimizer
    struct Triangle
    {
    public:
        enum EdgeMatchType {
            AB, BC, CA, ANY, NONE
        }
        
        uint a, b, c;
        
        this( uint ta, uint tb, uint tc )
        {
            a = ta; b = tb; c = tc;
        }
        
        this( uint t[3] )
        {
            a = t[0]; b = t[1]; c = t[2];
        }
        
        this( ref Triangle t )
        {
            a = t.a; b = t.b; c = t.c;
        }
        
        bool sharesEdge(Triangle t)
        {
            return( (a == t.a && b == t.c) ||
                   (a == t.b && b == t.a) ||
                   (a == t.c && b == t.b) ||
                   (b == t.a && c == t.c) ||
                   (b == t.b && c == t.a) ||
                   (b == t.c && c == t.b) ||
                   (c == t.a && a == t.c) ||
                   (c == t.b && a == t.a) ||
                   (c == t.c && a == t.b) );
        }
        
        bool sharesEdge(uint ea,uint eb, ref Triangle t)
        {
            return( (ea == t.a && eb == t.c) ||
                   (ea == t.b && eb == t.a) ||
                   (ea == t.c && eb == t.b) );
        }
        
        bool sharesEdge(EdgeMatchType edge, ref Triangle t)
        {
            if (edge == EdgeMatchType.AB)
                return sharesEdge(a, b, t);
            else if (edge == EdgeMatchType.BC)
                return sharesEdge(b, c, t);
            else if (edge == EdgeMatchType.CA)
                return sharesEdge(c, a, t);
            else
                return (edge == EdgeMatchType.ANY) == sharesEdge(t);
        }
        
        EdgeMatchType endoSharedEdge(Triangle t)
        {
            if (sharesEdge(a, b, t)) return EdgeMatchType.AB;
            if (sharesEdge(b, c, t)) return EdgeMatchType.BC;
            if (sharesEdge(c, a, t)) return EdgeMatchType.CA;
            return EdgeMatchType.NONE;
        }
        
        EdgeMatchType exoSharedEdge(Triangle t)
        {
            return t.endoSharedEdge(this);
        }
        
        void shiftClockwise()
        {
            uint t = a;
            a = c;
            c = b;
            b = t;
        }
        
        void shiftCounterClockwise()
        {
            uint t = a;
            a = b;
            b = c;
            c = t;
        }
    }
    
}

/** This class declares the usage of a single vertex buffer as a component
 of a complete VertexDeclaration.
 @remarks
 Several vertex buffers can be used to supply the input geometry for a
 rendering operation, and in each case a vertex buffer can be used in
 different ways for different operations; the buffer itself does not
 define the semantics (position, normal etc), the VertexElement
 class does.
 */
class VertexElement// : public VertexDataAlloc
{
    alias Object.opEquals opEquals;
protected:
    /// The source vertex buffer, as bound to an index using VertexBufferBinding
    ushort mSource;
    /// The offset in the buffer that this element starts at
    size_t mOffset;
    /// The type of element
    VertexElementType mType;
    /// The meaning of the element
    VertexElementSemantic mSemantic;
    /// Index of the item, only applicable for some elements like texture coords
    ushort mIndex;
public:
    /// Constructor, should not be called directly, only needed because of list
    this() {}
    /// Constructor, should not be called directly, call VertexDeclaration.addElement
    this(ushort source, size_t offset, VertexElementType theType,
         VertexElementSemantic semantic, ushort index = 0)
    {
        mSource = source;
        mOffset = offset;
        mType = theType;
        mSemantic = semantic;
        mIndex = index;
    }
    /// Gets the vertex buffer index from where this element draws it's values
    ushort getSource() const { return mSource; }
    /// Gets the offset into the buffer where this element starts
    size_t getOffset() const{ return mOffset; }
    /// Gets the data format of this element
    VertexElementType getType() const { return mType; }
    /// Gets the meaning of this element
    VertexElementSemantic getSemantic() const { return mSemantic; }
    /// Gets the index of this element, only applicable for repeating elements
    ushort getIndex() const { return mIndex; }
    /// Gets the size of this element in bytes
    size_t getSize(){ return getTypeSize(mType); }
    /// Utility method for helping to calculate offsets
    static size_t getTypeSize(VertexElementType etype)
    {
        final switch(etype)
        {
            case VertexElementType.VET_COLOUR:
            case VertexElementType.VET_COLOUR_ABGR:
            case VertexElementType.VET_COLOUR_ARGB:
                return RGBA.sizeof;
            case VertexElementType.VET_FLOAT1:
                return float.sizeof;
            case VertexElementType.VET_FLOAT2:
                return float.sizeof*2;
            case VertexElementType.VET_FLOAT3:
                return float.sizeof*3;
            case VertexElementType.VET_FLOAT4:
                return float.sizeof*4;
            case VertexElementType.VET_DOUBLE1:
                return double.sizeof;
            case VertexElementType.VET_DOUBLE2:
                return double.sizeof*2;
            case VertexElementType.VET_DOUBLE3:
                return double.sizeof*3;
            case VertexElementType.VET_DOUBLE4:
                return double.sizeof*4;
            case VertexElementType.VET_SHORT1:
                return short.sizeof;
            case VertexElementType.VET_SHORT2:
                return short.sizeof*2;
            case VertexElementType.VET_SHORT3:
                return short.sizeof*3;
            case VertexElementType.VET_SHORT4:
                return short.sizeof*4;
            case VertexElementType.VET_USHORT1:
                return ushort.sizeof;
            case VertexElementType.VET_USHORT2:
                return ushort.sizeof*2;
            case VertexElementType.VET_USHORT3:
                return ushort.sizeof*3;
            case VertexElementType.VET_USHORT4:
                return ushort.sizeof*4;
            case VertexElementType.VET_INT1:
                return int.sizeof;
            case VertexElementType.VET_INT2:
                return int.sizeof*2;
            case VertexElementType.VET_INT3:
                return int.sizeof*3;
            case VertexElementType.VET_INT4:
                return int.sizeof*4;
            case VertexElementType.VET_UINT1:
                return uint.sizeof;
            case VertexElementType.VET_UINT2:
                return uint.sizeof*2;
            case VertexElementType.VET_UINT3:
                return uint.sizeof*3;
            case VertexElementType.VET_UINT4:
                return uint.sizeof*4;
            case VertexElementType.VET_UBYTE4:
                return ubyte.sizeof*4;
        }
        return 0;
    }
    /// Utility method which returns the count of values in a given type
    static ushort getTypeCount(VertexElementType etype)
    {
        final switch (etype)
        {
            case VertexElementType.VET_COLOUR:
            case VertexElementType.VET_COLOUR_ABGR:
            case VertexElementType.VET_COLOUR_ARGB:
            case VertexElementType.VET_FLOAT1:
            case VertexElementType.VET_SHORT1:
            case VertexElementType.VET_USHORT1:
            case VertexElementType.VET_UINT1:
            case VertexElementType.VET_INT1:
            case VertexElementType.VET_DOUBLE1:
                return 1;
            case VertexElementType.VET_FLOAT2:
            case VertexElementType.VET_SHORT2:
            case VertexElementType.VET_USHORT2:
            case VertexElementType.VET_UINT2:
            case VertexElementType.VET_INT2:
            case VertexElementType.VET_DOUBLE2:
                return 2;
            case VertexElementType.VET_FLOAT3:
            case VertexElementType.VET_SHORT3:
            case VertexElementType.VET_USHORT3:
            case VertexElementType.VET_UINT3:
            case VertexElementType.VET_INT3:
            case VertexElementType.VET_DOUBLE3:
                return 3;
            case VertexElementType.VET_FLOAT4:
            case VertexElementType.VET_SHORT4:
            case VertexElementType.VET_USHORT4:
            case VertexElementType.VET_UINT4:
            case VertexElementType.VET_INT4:
            case VertexElementType.VET_DOUBLE4:
            case VertexElementType.VET_UBYTE4:
                return 4;
        }
        throw new InvalidParamsError( "Invalid type",
                                     "VertexElement.getTypeCount");
    }
    /** Simple converter function which will turn a single-value type into a
     multi-value type based on a parameter.
     */
    static VertexElementType multiplyTypeCount(VertexElementType baseType, ushort count)
    {
        switch (baseType)
        {
            case VertexElementType.VET_FLOAT1:
                switch(count)
                {
                    case 1:
                        return VertexElementType.VET_FLOAT1;
                    case 2:
                        return VertexElementType.VET_FLOAT2;
                    case 3:
                        return VertexElementType.VET_FLOAT3;
                    case 4:
                        return VertexElementType.VET_FLOAT4;
                    default:
                        break;
                }
                break;
            case VertexElementType.VET_SHORT1:
                switch(count)
                {
                    case 1:
                        return VertexElementType.VET_SHORT1;
                    case 2:
                        return VertexElementType.VET_SHORT2;
                    case 3:
                        return VertexElementType.VET_SHORT3;
                    case 4:
                        return VertexElementType.VET_SHORT4;
                    default:
                        break;
                }
                break;
            default:
                break;
        }
        throw new InvalidParamsError( "Invalid base type",
                                     "VertexElement.multiplyTypeCount");
    }
    /** Simple converter function which will a type into it's single-value
     equivalent - makes switches on type easier.
     */
    static VertexElementType getBaseType(VertexElementType multiType)
    {
        final switch (multiType)
        {
            case VertexElementType.VET_FLOAT1:
            case VertexElementType.VET_FLOAT2:
            case VertexElementType.VET_FLOAT3:
            case VertexElementType.VET_FLOAT4:
                return VertexElementType.VET_FLOAT1;
            case VertexElementType.VET_DOUBLE1:
            case VertexElementType.VET_DOUBLE2:
            case VertexElementType.VET_DOUBLE3:
            case VertexElementType.VET_DOUBLE4:
                return VertexElementType.VET_DOUBLE1;
            case VertexElementType.VET_INT1:
            case VertexElementType.VET_INT2:
            case VertexElementType.VET_INT3:
            case VertexElementType.VET_INT4:
                return VertexElementType.VET_INT1;
            case VertexElementType.VET_UINT1:
            case VertexElementType.VET_UINT2:
            case VertexElementType.VET_UINT3:
            case VertexElementType.VET_UINT4:
                return VertexElementType.VET_UINT1;
            case VertexElementType.VET_COLOUR:
                return VertexElementType.VET_COLOUR;
            case VertexElementType.VET_COLOUR_ABGR:
                return VertexElementType.VET_COLOUR_ABGR;
            case VertexElementType.VET_COLOUR_ARGB:
                return VertexElementType.VET_COLOUR_ARGB;
            case VertexElementType.VET_SHORT1:
            case VertexElementType.VET_SHORT2:
            case VertexElementType.VET_SHORT3:
            case VertexElementType.VET_SHORT4:
                return VertexElementType.VET_SHORT1;
            case VertexElementType.VET_USHORT1:
            case VertexElementType.VET_USHORT2:
            case VertexElementType.VET_USHORT3:
            case VertexElementType.VET_USHORT4:
                return VertexElementType.VET_USHORT1;
            case VertexElementType.VET_UBYTE4:
                return VertexElementType.VET_UBYTE4;
        }
        // To keep compiler happy
        return VertexElementType.VET_FLOAT1;
    }
    
    /** Utility method for converting colour from
     one packed 32-bit colour type to another.
     @param srcType The source type
     @param dstType The destination type
     @param ptr Read / write value to change
     */
    static void convertColourValue(VertexElementType srcType,
                                   VertexElementType dstType, ref uint ptr)
    {
        if (srcType == dstType)
            return;
        
        // Conversion between ARGB and ABGR is always a case of flipping R/B
        ptr =
            ((ptr&0x00FF0000)>>16)|((ptr&0x000000FF)<<16)|(ptr&0xFF00FF00);
    }
    
    /** Utility method for converting colour to
     a packed 32-bit colour type.
     @param src source colour
     @param dst The destination type
     */
    static uint convertColourValue(ColourValue src,
                                   VertexElementType dst)
    {
        switch(dst)
        {
            case VertexElementType.VET_COLOUR_ARGB:
                return src.getAsARGB();
            case VertexElementType.VET_COLOUR_ABGR:
                return src.getAsABGR();
            default:
                version(Windows) //we want Win32 && WinRT
                    return src.getAsARGB();
                else
                    return src.getAsABGR();
        }
    }
    
    /** Utility method to get the most appropriate packed colour vertex element format. */
    static VertexElementType getBestColourVertexElementType()
    {
        // Use the current render system to determine if possible
        if (Root.getSingleton() && Root.getSingleton().getRenderSystem())
        {
            return Root.getSingleton().getRenderSystem().getColourVertexElementType();
        }
        else
        {
            // We can't know the specific type right now, so pick a type
            // based on platform
            version(Windows)
                return VertexElementType.VET_COLOUR_ARGB; // prefer D3D format on windows
            else
                return VertexElementType.VET_COLOUR_ABGR; // prefer GL format on everything else
            
        }
    }
    
    bool opEquals (VertexElement rhs)
    {
        if (mType != rhs.mType ||
            mIndex != rhs.mIndex ||
            mOffset != rhs.mOffset ||
            mSemantic != rhs.mSemantic ||
            mSource != rhs.mSource)
            return false;
        else
            return true;
        
    }
    /** Adjusts a pointer to the base of a vertex to point at this element.
     @remarks
     This variant is for void pointers, passed as a parameter because we can't
     rely on covariant return types.
     @param pBase Pointer to the start of a vertex in this buffer.
     @param pElem Pointer to a pointer which will be set to the start of this element.
     */
    void baseVertexPointerToElement(void* pBase, void** pElem)
    {
        // The only way we can do this is to cast to char* in order to use byte offset
        // then cast back to void*.
        *pElem = cast(void*)(cast(ubyte*)(pBase) + mOffset);
    }
    /** Adjusts a pointer to the base of a vertex to point at this element.
     @remarks
     This variant is for float pointers, passed as a parameter because we can't
     rely on covariant return types.
     @param pBase Pointer to the start of a vertex in this buffer.
     @param pElem Pointer to a pointer which will be set to the start of this element.
     */
    void baseVertexPointerToElement(void* pBase, float** pElem)
    {
        // The only way we can do this is to cast to char* in order to use byte offset
        // then cast back to float*. However we have to go via void* because casting
        // directly is not allowed
        *pElem = cast(float*)(cast(void*)(cast(ubyte*)(pBase) + mOffset));
    }
    
    /** Adjusts a pointer to the base of a vertex to point at this element.
     @remarks
     This variant is for RGBA pointers, passed as a parameter because we can't
     rely on covariant return types.
     @param pBase Pointer to the start of a vertex in this buffer.
     @param pElem Pointer to a pointer which will be set to the start of this element.
     */
    void baseVertexPointerToElement(void* pBase, RGBA** pElem)
    {
        *pElem = cast(RGBA*)(cast(void*)(cast(ubyte*)(pBase) + mOffset));
    }
    /** Adjusts a pointer to the base of a vertex to point at this element.
     @remarks
     This variant is for char pointers, passed as a parameter because we can't
     rely on covariant return types.
     @param pBase Pointer to the start of a vertex in this buffer.
     @param pElem Pointer to a pointer which will be set to the start of this element.
     */
    void baseVertexPointerToElement(void* pBase, ubyte** pElem)
    {
        *pElem = cast(ubyte*)(pBase) + mOffset;
    }
    
    /** Adjusts a pointer to the base of a vertex to point at this element.
     @remarks
     This variant is for ushort pointers, passed as a parameter because we can't
     rely on covariant return types.
     @param pBase Pointer to the start of a vertex in this buffer.
     @param pElem Pointer to a pointer which will be set to the start of this element.
     */
    void baseVertexPointerToElement(void* pBase, ushort** pElem)
    {
        *pElem = cast(ushort*)(cast(void*)(cast(ubyte*)(pBase) + mOffset));
    }
    
    
}
/** This class declares the format of a set of vertex inputs, which
 can be issued to the rendering API through a RenderOperation.
 @remarks
 You should be aware that the ordering and structure of the
 VertexDeclaration can be very important on DirectX with older
 cards,so if you want to maintain maximum compatibility with
 all render systems and all cards you should be caref ul to follow these
 rules:<ol>
 <li>VertexElements should be added in the following order, and the order of the
 elements within a shared buffer should be as follows:
 position, blending weights, normals, diffuse colours, specular colours,
 texture coordinates (in order, with no gaps)</li>
 <li>You must not have unused gaps in your buffers which are not referenced
 by any VertexElement</li>
 <li>You must not cause the buffer & offset settings of 2 VertexElements to overlap</li>
 </ol>
 Whilst GL and more modern graphics cards in D3D will allow you to defy these rules,
 sticking to them will ensure that your buffers have the maximum compatibility.
 @par
 Like the other classes in this functional area, these declarations should be created and
 destroyed using the HardwareBufferManager.
 */
class VertexDeclaration// : public VertexDataAlloc
{
    alias Object.opEquals opEquals;

public:
    /// Defines the list of vertex elements that makes up this declaration
    //typedef list<VertexElement>::type VertexElementList;
    
    /// or DList ?
    alias VertexElement[] VertexElementList;
    /// Sort routine for vertex elements
    static bool vertexElementLess(VertexElement e1,VertexElement e2)
    {
        // Sort by source first
        if (e1.getSource() < e2.getSource())
        {
            return true;
        }
        else if (e1.getSource() == e2.getSource())
        {
            // Use ordering of semantics to sort
            if (e1.getSemantic() < e2.getSemantic())
            {
                return true;
            }
            else if (e1.getSemantic() == e2.getSemantic())
            {
                // Use index to sort
                if (e1.getIndex() < e2.getIndex())
                {
                    return true;
                }
            }
        }
        return false;
    }
protected:
    VertexElementList mElementList;
    
    bool _find(VertexElement ei, VertexElementSemantic semantic, ushort index)
    {
        return (ei.getSemantic() == semantic && ei.getIndex() == index);
    }
    
public:
    /// Standard constructor, not you should use HardwareBufferManager.createVertexDeclaration
    this(){}
    ~this(){}
    
    /** Get the number of elements in the declaration. */
    size_t getElementCount(){ return mElementList.length; }
    /** Gets read-only access to the list of vertex elements. */
    VertexElementList getElements()
    {
        return mElementList;
    }

    const(VertexElementList) getElements() const
    {
        return mElementList;
    }

    /** Get a single element. */
    VertexElement getElement(ushort index)
    {
        return mElementList[index];
    }
    
    /** Sorts the elements in this list to be compatible with the maximum
     number of rendering APIs / graphics cards.
     @remarks
     Older graphics cards require vertex data to be presented in a more
     rigid way, as defined in the main documentation for this class. As well
     as the ordering being important, where shared source buffers are used, the
     declaration must list all the elements for each source in turn.
     */
    void sort()
    {
        std.algorithm.sort!(VertexDeclaration.vertexElementLess)(mElementList);
    }
    
    /** Remove any gaps in the source buffer list used by this declaration.
     @remarks
     This is useful if you've modified a declaration and want to remove
     any gaps in the list of buffers being used. Note, however, that if this
     declaration is already being used with a VertexBufferBinding, you will
     need to alter that too. This method is mainly useful when reorganising
     buffers based on an altered declaration.
     @note
     This will cause the vertex declaration to be re-sorted.
     */
    void closeGapsInSource()
    {
        if (!mElementList.length)
            return;
        
        // Sort first
        sort();
        
        ushort targetIdx = 0;
        ushort lastIdx = getElement(0).getSource();
        ushort c = 0;
        //foreach (c, elem; mElementList[].array()) //.array() does new allocation
        foreach (elem; mElementList)
        {
            if (lastIdx != elem.getSource())
            {
                targetIdx++;
                lastIdx = elem.getSource();
            }
            if (targetIdx != elem.getSource())
            {
                modifyElement(c, targetIdx, elem.getOffset(), elem.getType(),
                              elem.getSemantic(), elem.getIndex());
            }
            c++;
        }
        
    }
    
    /** Generates a new VertexDeclaration for optimal usage based on the current
     vertex declaration, which can be used with VertexData.reorganiseBuffers later
     if you wish, or simply used as a template.
     @remarks
     Different buffer organisations and buffer usages will be returned
     depending on the parameters passed to this method.
     @param skeletalAnimation Whether this vertex data is going to be
     skeletally animated
     @param vertexAnimation Whether this vertex data is going to be vertex animated
     @param vertexAnimationNormals Whether vertex data animation is going to include normals animation
     */
    VertexDeclaration getAutoOrganisedDeclaration(bool skeletalAnimation,
                                                      bool vertexAnimation, bool vertexAnimationNormals)
    {
        VertexDeclaration newDecl = this.clone();
        // Set all sources to the same buffer (for now)
        auto elems = newDecl.getElements();
        
        ushort c = 0;
        foreach (elem; elems)
        {
            // Set source & offset to 0 for now, before sort
            newDecl.modifyElement(c, 0, 0, elem.getType(), elem.getSemantic(), elem.getIndex());
            c++;
        }
        newDecl.sort();
        // Now sort out proper buffer assignments and offsets
        size_t offset = 0;
        c = 0;
        ushort buffer = 0;
        alias VertexElementSemantic VES;
        auto prevSemantic = VES.VES_POSITION;
        
        foreach (elem; elems)
        {
            bool splitWithPrev = false;
            bool splitWithNext = false;
            switch (elem.getSemantic())
            {
                case VES.VES_POSITION:
                    // Split positions if vertex animated with only positions
                    // group with normals otherwise
                    splitWithPrev = false;
                    splitWithNext = vertexAnimation && !vertexAnimationNormals;
                    break;
                case VES.VES_NORMAL:
                    // Normals can't share with blend weights/indices
                    splitWithPrev = (prevSemantic == VES.VES_BLEND_WEIGHTS || prevSemantic == VES.VES_BLEND_INDICES);
                    // All animated meshes have to split after normal
                    splitWithNext = (skeletalAnimation || (vertexAnimation && vertexAnimationNormals));
                    break;
                case VES.VES_BLEND_WEIGHTS:
                    // Blend weights/indices can be sharing with their own buffer only
                    splitWithPrev = true;
                    break;
                case VES.VES_BLEND_INDICES:
                    // Blend weights/indices can be sharing with their own buffer only
                    splitWithNext = true;
                    break;
                default:
                case VES.VES_DIFFUSE:
                case VES.VES_SPECULAR:
                case VES.VES_TEXTURE_COORDINATES:
                case VES.VES_BINORMAL:
                case VES.VES_TANGENT:
                    // Make sure position is separate if animated & there were no normals
                    splitWithPrev = prevSemantic == VES.VES_POSITION &&
                        (skeletalAnimation || vertexAnimation);
                    break;
            }
            
            if (splitWithPrev && offset)
            {
                ++buffer;
                offset = 0;
            }
            
            prevSemantic = elem.getSemantic();
            newDecl.modifyElement(c, buffer, offset,
                                  elem.getType(), elem.getSemantic(), elem.getIndex());
            
            if (splitWithNext)
            {
                ++buffer;
                offset = 0;
            }
            else
            {
                offset += elem.getSize();
            }
            
            c++;
        }
        
        return newDecl;
        
        
    }
    
    /** Gets the index of the highest source value referenced by this declaration. */
    ushort getMaxSource()
    {
        ushort ret = 0;
        foreach (i; mElementList)
        {
            if (i.getSource() > ret)
            {
                ret = i.getSource();
            }
            
        }
        return ret;
    }
    
    
    
    /** Adds a new VertexElement to this declaration.
     @remarks
     This method adds a single element (positions, normals etc) to the end of the
     vertex declaration. <b>Please read the information in VertexDeclaration about
     the importance of ordering and structure for compatibility with older D3D drivers</b>.
     @param source The binding index of HardwareVertexBuffer which will provide the source for this element.
     See VertexBufferBinding for full information.
     @param offset The offset in bytes where this element is located in the buffer
     @param theType The data format of the element (3 floats, a colour etc)
     @param semantic The meaning of the data (position, normal, diffuse colour etc)
     @param index Optional index for multi-input elements like texture coordinates
     @return A reference to the VertexElement added.
     */
    ref VertexElement addElement(ushort source, size_t offset, VertexElementType theType,
                                 VertexElementSemantic semantic, ushort index = 0)
    {
        // Refine colour type to a specific type
        if (theType == VertexElementType.VET_COLOUR)
        {
            theType = VertexElement.getBestColourVertexElementType();
        }
        mElementList.insert(
            new VertexElement(source, offset, theType, semantic, index)
            );
        return mElementList[$-1];
    }
    
    /** Inserts a new VertexElement at a given position in this declaration.
     @remarks
     This method adds a single element (positions, normals etc) at a given position in this
     vertex declaration. <b>Please read the information in VertexDeclaration about
     the importance of ordering and structure for compatibility with older D3D drivers</b>.
     @param source The binding index of HardwareVertexBuffer which will provide the source for this element.
     See VertexBufferBinding for full information.
     @param offset The offset in bytes where this element is located in the buffer
     @param theType The data format of the element (3 floats, a colour etc)
     @param semantic The meaning of the data (position, normal, diffuse colour etc)
     @param index Optional index for multi-input elements like texture coordinates
     @return A reference to the VertexElement added.
     */
    ref VertexElement insertElement(ushort atPosition,
                                    ushort source, size_t offset, VertexElementType theType,
                                    VertexElementSemantic semantic, ushort index = 0)
    {
        if (atPosition >= mElementList.length)
        {
            return addElement(source, offset, theType, semantic, index);
        }
        
        //VertexElementList.iterator i = mElementList.begin();
        //for (ushort n = 0; n < atPosition; ++n)
        //    ++i;
        
        mElementList.insertBeforeIdx(atPosition+1,
                                     new VertexElement(source, offset, theType, semantic, index));
        return mElementList[atPosition];
        
    }
    
    /** Remove the element at the given index from this declaration.
     @todo Explicit delete?*/
    void removeElement(ushort elem_index)
    {
        //assert(elem_index < mElementList.length, "Index out of bounds"); //Array throws RangeError anyway
        //VertexElementList.iterator i = mElementList.begin();
        //for (ushort n = 0; n < elem_index; ++n)
        //    ++i;
        
        //destroy(mElementList[elem_index]);
        //if(mElementList.length) //ok, hit assert
        mElementList.removeFromArrayIdx(elem_index);
    }
    
    
    /** Remove the element with the given semantic and usage index.
     @remarks
     In this case 'index' means the usage index for repeating elements such
     as texture coordinates. For other elements this will always be 0 and does
     not ref er to the index in the vector.
     * @todo Explicit delete?
     */
    void removeElement(VertexElementSemantic semantic, ushort index = 0)
    {
        //foreach (ei; mElementList)
        //ldc2 linker cannot find this, ughh
        /*bool _find(VertexElement ei)
        {
            return (ei.getSemantic() == semantic && ei.getIndex() == index);
        }*/

        //auto r = mElementList.find!_find();
        VertexElement el = null;
        foreach(e; mElementList)
        {
            if(_find(e, semantic, index))
            {
                el = e;
                break;
            }
        }
            
        //if(r.length)
        if(el !is null)
            mElementList.removeFromArray(el);
    }
    
    /** Remove all elements. */
    void removeAllElements()
    {
        mElementList.clear();
    }
    
    /** Modify an element in-place, params as addElement.
     @remarks
     <b>Please read the information in VertexDeclaration about
     the importance of ordering and structure for compatibility with older D3D drivers</b>.
     */
    void modifyElement(ushort elem_index, ushort source, size_t offset, VertexElementType theType,
                       VertexElementSemantic semantic, ushort index = 0)
    {
        //assert(elem_index < mElementList.size() && "Index out of bounds");
        //VertexElementList.iterator i = mElementList.begin();
        //std.advance(i, elem_index);
        mElementList[elem_index] = new VertexElement(source, offset, theType, semantic, index);
    }
    
    /** Finds a VertexElement with the given semantic, and index if there is more than
     one element with the same semantic.
     @remarks
     If the element is not found, this method returns null.
     */
    VertexElement findElementBySemantic(VertexElementSemantic sem, ushort index = 0)
    {
        foreach (ei; mElementList)
        {
            if (ei.getSemantic() == sem && ei.getIndex() == index)
            {
                return ei;
            }
        }
        return null;
    }
    
    /** Based on the current elements, gets the size of the vertex for a given buffer source.
     @param source The buffer binding index for which to get the vertex size.
     * @todo This comment is in wrong place?
     */
    
    /** Gets a list of elements which use a given source.
     @remarks
     Note that the list of elements is returned by value Therefore is separate from
     the declaration as soon as this method returns.
     */
    VertexElementList findElementsBySource(ushort source)
    {
        //auto retList = VertexElementList();
        VertexElementList retList;
        foreach (ei; mElementList)
        {
            if (ei.getSource() == source)
            {
                retList.insert(ei);
            }
        }
        return retList;
        
    }
    
    /** Gets the vertex size defined by this declaration for a given source. */
    size_t getVertexSize(ushort source)
    {
        size_t sz = 0;
        
        foreach (i; mElementList)
        {
            if (i.getSource() == source)
            {
                sz += i.getSize();
                
            }
        }
        return sz;
    }
    
    /** Return the index of the next free texture coordinate set which may be added
     to this declaration.
     */
    ushort getNextFreeTextureCoordinate()
    {
        ushort texCoord = 0;
        foreach (el; mElementList)
        {
            if (el.getSemantic() == VertexElementSemantic.VES_TEXTURE_COORDINATES)
            {
                ++texCoord;
            }
        }
        return texCoord;
    }
    
    /** Clones this declaration.
     @param mgr Optional HardwareBufferManager to use for creating the clone
     (if null, use the current default).
     */
    VertexDeclaration clone(HardwareBufferManagerBase mgr = null)
    {
        auto pManager = mgr ? mgr : HardwareBufferManager.getSingleton();
        auto ret = pManager.createVertexDeclaration();
        
        foreach (i; mElementList)
        {
            ret.addElement(i.getSource(), i.getOffset(), i.getType(), i.getSemantic(), i.getIndex());
        }
        return ret;
    }
    
    //bool opEquals (const VertexDeclaration rhs) const
    //{
    //    return opEquals(rhs);
    //}
    
    /** @todo Array opEquals is used so we don't have to iterate over elements in here? */
    bool opEquals (VertexDeclaration rhs)
    {
        if (mElementList.length != rhs.mElementList.length)
            return false;
        
        return mElementList == rhs.mElementList; //Array opEquals?
        /*for (i = mElementList.begin(); i != iend && rhsi != rhsiend; ++i, ++rhsi)
         {
         if ( !(*i == *rhsi) )
         return false;
         }

         return true;
         */
    }
    /*bool operator!= (VertexDeclaration& rhs)
     {
     return !(*this == rhs);
     }*/
    
}

/** Records the state of all the vertex buffer bindings required to provide a vertex declaration
 with the input data it needs for the vertex elements.
 @remarks
 Why do we have this binding list rather than just have VertexElement ref erring to the
 vertex buffers direct? Well, in the underlying APIs, binding the vertex buffers to an
 index (or 'stream') is the way that vertex data is linked, so this structure better
 reflects the realities of that. In addition, by separating the vertex declaration from
 the list of vertex buffer bindings, it becomes possible to reuse bindings between declarations
 and vice versa, giving opportunities to reduce the state changes required to perform rendering.
 @par
 Like the other classes in this functional area, these binding maps should be created and
 destroyed using the HardwareBufferManager.
 */
class VertexBufferBinding// : public VertexDataAlloc
{
public:
    /// Defines the vertex buffer bindings used as source for vertex declarations
    //typedef map<ushort, SharedPtr!HardwareVertexBuffer>::type VertexBufferBindingMap;
    alias SharedPtr!HardwareVertexBuffer[ushort] VertexBufferBindingMap;
protected:
    VertexBufferBindingMap mBindingMap;
    ushort mHighIndex = 0;
public:
    /// Constructor, should not be called direct, use HardwareBufferManager.createVertexBufferBinding
    this()
    {
        //mHighIndex = 0;
    }
    ~this() { unsetAllBindings(); }
    
    /** Set a binding, associating a vertex buffer with a given index.
     @remarks
     If the index is already associated with a vertex buffer,
     the association will be replaced. This may cause the old buffer
     to be destroyed if nothing else is ref erring to it.
     You should assign bindings from 0 and not leave gaps, although you can
     bind them in any order.
     */
    void setBinding(ushort index, SharedPtr!HardwareVertexBuffer buffer)
    {
        // NB will replace any existing buffer ptr at this index, and will thus cause
        // reference count to decrement on that buffer (possibly destroying it)
        //debug(STDERR) std.stdio.stderr.writeln("VertexBufferBinding.setBinding@", buffer._refCounted._store ," ref:", buffer._refCounted.refCount);
        mBindingMap[index] = buffer;
        mHighIndex = std.algorithm.max(mHighIndex, cast(ushort)(index+1));
    }
    
    /** Removes an existing binding.
     * @todo Explicit delete?
     */
    void unsetBinding(ushort index)
    {
        auto i = index in mBindingMap;
        if (i is null)
        {
            throw new ItemNotFoundError(
                "Cannot find buffer binding for index " ~ std.conv.to!string(index),
                "VertexBufferBinding.unsetBinding");
        }
        //destroy(mBindingMap[index]);
        mBindingMap.remove(index);
    }
    
    /** Removes all the bindings. */
    void unsetAllBindings()
    {
        mBindingMap.clear();
        mHighIndex = 0;
    }
    
    /// Gets a read-only version of the buffer bindings
    /*ref const(VertexBufferBindingMap) getBindings() const
    {
        return mBindingMap;
    }*/

    ref VertexBufferBindingMap getBindings()
    {
        return mBindingMap;
    }
    
    /// Gets the buffer bound to the given source index
    /*const(SharedPtr!HardwareVertexBuffer) getBuffer(ushort index) const
    {
        auto i = index in mBindingMap;//'in' gives a pointer
        if (i is null)
        {
            throw new ItemNotFoundError( "No buffer is bound to that index.",
                                        "VertexBufferBinding.getBuffer");
        }
        return *i;
    }*/

    SharedPtr!HardwareVertexBuffer getBuffer(ushort index)
    {
        auto i = index in mBindingMap;//'in' gives a pointer
        if (i is null)
        {
            throw new ItemNotFoundError( "No buffer is bound to that index.",
                                        "VertexBufferBinding.getBuffer");
        }
        debug(STDERR) std.stdio.stderr.writeln("VertexBufferBinding.getBuffer: ");
        debug(STDERR) if(i !is null) 
        {
            SharedPtr!HardwareVertexBuffer buf = *i;
            std.stdio.stderr.writeln("\t", 
                //buf._refCounted._store,
                " isNull:", buf.isNull() );
        }
        return *i;
    }

    /// Gets whether a buffer is bound to the given source index
    bool isBufferBound(ushort index) //const
    {
        return (index in mBindingMap) !is null;
    }
    
    size_t getBufferCount(){ return mBindingMap.length; }
    
    /** Gets the highest index which has already been set, plus 1.
     @remarks
     This is to assist in binding the vertex buffers such that there are
     not gaps in the list.
     */
    ushort getNextIndex(){ return mHighIndex++; }
    
    /** Gets the last bound index.
     */
    ushort getLastBoundIndex()
    {
        return mBindingMap.emptyAA() ? 0 : cast(ushort)(sort(mBindingMap.keys).back + 1);
    }
    
    //typedef map<ushort, ushort>::type BindingIndexMap;
    alias ushort[ushort] BindingIndexMap;
    
    /** Check whether any gaps in the bindings.
     */
    bool hasGaps()
    {
        if (mBindingMap.length == 0)
            return false;
        //if (mBindingMap.rbegin().first + 1 == cast(int) mBindingMap.size())
        ///TODO Enough to just sort mBindingMap keys?
        // SortedRange.back
        if (sort(mBindingMap.keys).back + 1 == mBindingMap.length)
            return false;
        return true;
    }
    
    /** Remove any gaps in the bindings.
     @remarks
     This is useful if you've removed vertex buffer from this vertex buffer
     bindings and want to remove any gaps in the bindings. Note, however,
     that if this bindings is already being used with a VertexDeclaration,
     you will need to alter that too. This method is mainly useful when
     reorganising buffers manually.
     @param
     bindingIndexMap To be retrieve the binding index map that used to
     translation old index to new index; will be cleared by this method
     before fill-in.
     */
    void closeGaps(ref BindingIndexMap bindingIndexMap)
    {
        bindingIndexMap.clear();
        
        VertexBufferBindingMap newBindingMap;
        
        ushort targetIndex = 0;
        foreach (k, v; mBindingMap)
        {
            bindingIndexMap[k] = targetIndex;
            newBindingMap[targetIndex] = v;
            targetIndex++;
        }
        
        std.algorithm.swap(mBindingMap, newBindingMap);
        mHighIndex = targetIndex;
    }
    
    /// Returns true if has an element that is instance data
    bool getHasInstanceData() //const
    {
        foreach (k, v; mBindingMap)
        {
            if ( v.get().getIsInstanceData() )
            {
                return true;
            }
        }
        return false;
    }
    
    
}

/// Define a list of usage flags
//typedef vector<HardwareBuffer.Usage>::type BufferUsageList;
alias HardwareBuffer.Usage[] BufferUsageList;


/** Summary class collecting together vertex source information. */
class VertexData// : public VertexDataAlloc
{
private:
    /// Protected copy constructor, to prevent misuse
    //VertexData(VertexData& rhs); /* do nothing, should not use */
    /// Protected operator=, to prevent misuse
    //VertexData& operator=(VertexData& rhs); /* do not use */
    
    HardwareBufferManagerBase mMgr;
public:
    /** Constructor.
     @note
     This constructor creates the VertexDeclaration and VertexBufferBinding
     automatically, and arranges for their deletion afterwards.
     @param mgr Optional HardwareBufferManager from which to create resources
     */
    this(HardwareBufferManagerBase mgr = null)
    {
        mMgr = mgr ? mgr : HardwareBufferManager.getSingleton();
        vertexBufferBinding = mMgr.createVertexBufferBinding();
        vertexDeclaration = mMgr.createVertexDeclaration();
        mDeleteDclBinding = true;
        vertexCount = 0;
        vertexStart = 0;
        hwAnimDataItemsUsed = 0;
    }
    /** Constructor.
     @note
     This constructor receives the VertexDeclaration and VertexBufferBinding
     from the caller, and as such does not arrange for their deletion afterwards,
     the caller remains responsible for that.
     @param dcl The VertexDeclaration to use
     @param bind The VertexBufferBinding to use
     */
    this(ref VertexDeclaration dcl, ref VertexBufferBinding bind)
    {
        // this is a fallback rather than actively used
        mMgr = HardwareBufferManager.getSingleton();
        vertexDeclaration = dcl;
        vertexBufferBinding = bind;
        mDeleteDclBinding = false;
        vertexCount = 0;
        vertexStart = 0;
        hwAnimDataItemsUsed = 0;
    }
    
    ~this()
    {
        if (mDeleteDclBinding)
        {
            mMgr.destroyVertexBufferBinding(vertexBufferBinding);
            mMgr.destroyVertexDeclaration(vertexDeclaration);
        }
    }
    
    /** Declaration of the vertex to be used in this operation.
     @remarks Note that this is created for you on construction.
     */
    VertexDeclaration vertexDeclaration;
    /** The vertex buffer bindings to be used.
     @remarks Note that this is created for you on construction.
     */
    VertexBufferBinding vertexBufferBinding;
    /// Whether this class should delete the declaration and binding
    bool mDeleteDclBinding;
    /// The base vertex index to start from
    size_t vertexStart;
    /// The number of vertices used in this operation
    size_t vertexCount;
    
    
    /// Struct used to hold hardware morph / pose vertex data information
    struct HardwareAnimationData
    {
        ushort targetBufferIndex;
        Real parametric;
    }
    //typedef vector<HardwareAnimationData>::type HardwareAnimationDataList;
    alias HardwareAnimationData[] HardwareAnimationDataList;
    /// VertexElements used for hardware morph / pose animation
    HardwareAnimationDataList hwAnimationDataList;
    /// Number of hardware animation data items used
    size_t hwAnimDataItemsUsed;
    
    /** Clones this vertex data, potentially including replicating any vertex buffers.
     @param copyData Whether to create new vertex buffers too or just reference the existing ones
     @param mgr If supplied, the buffer manager through which copies should be made
     @remarks The caller is expected to delete the returned pointer when ready
     */
    VertexData clone(bool copyData = true, /+ref+/ HardwareBufferManagerBase mgr = null)
    {
        HardwareBufferManagerBase pManager = mgr ? mgr : mMgr;
        
        auto dest = new VertexData(mgr);
        
        // Copy vertex buffers in turn
        VertexBufferBinding.VertexBufferBindingMap bindings = this.vertexBufferBinding.getBindings();
        
        foreach (k, srcbuf; bindings)
        {
            //SharedPtr!HardwareVertexBuffer srcbuf = vbi.second;
            SharedPtr!HardwareVertexBuffer dstBuf;
            if (copyData)
            {
                // create new buffer with the same settings
                dstBuf = pManager.createVertexBuffer(
                    srcbuf.get().getVertexSize(), srcbuf.get().getNumVertices(), srcbuf.get().getUsage(),
                    srcbuf.get().hasShadowBuffer());
                
                // copy data
                dstBuf.get().copyData(srcbuf.get(), 0, 0, srcbuf.get().getSizeInBytes(), true);
            }
            else
            {
                // don't copy, point at existing buffer
                dstBuf = srcbuf;
            }
            
            // Copy binding
            dest.vertexBufferBinding.setBinding(k /+vbi.first+/, dstBuf);
        }
        
        // Basic vertex info
        dest.vertexStart = this.vertexStart;
        dest.vertexCount = this.vertexCount;
        // Copy elements
        auto elems = this.vertexDeclaration.getElements();
        
        foreach (ei; elems)
        {
            dest.vertexDeclaration.addElement(
                ei.getSource(),
                ei.getOffset(),
                ei.getType(),
                ei.getSemantic(),
                ei.getIndex() );
        }
        
        // Copy reference to hardware shadow buffer, no matter whether copy data or not
        dest.hardwareShadowVolWBuffer = hardwareShadowVolWBuffer;
        
        // copy anim data
        dest.hwAnimationDataList = hwAnimationDataList;
        dest.hwAnimDataItemsUsed = hwAnimDataItemsUsed;
        
        
        return dest;
    }
    
    /** Modifies the vertex data to be suitable for use for rendering shadow geometry.
     @remarks
     Preparing vertex data to generate a shadow volume involves firstly ensuring that the
     vertex buffer containing the positions is a standalone vertex buffer,
     with no other components in it. This method will Therefore break apart any existing
     vertex buffers if position is sharing a vertex buffer.
     Secondly, it will double the size of this vertex buffer so that there are 2 copies of
     the position data for the mesh. The first half is used for the original, and the second
     half is used for the 'extruded' version. The vertex count used to render will remain
     the same though, so as not to add any overhead to regular rendering of the object.
     Both copies of the position are required in one buffer because shadow volumes stretch
     from the original mesh to the extruded version.
     @par
     It's important to appreciate that this method can fundamentally change the structure of your
     vertex buffers, although in reality they will be new buffers. As it happens, if other
     objects are using the original buffers then they will be unaffected because the reference
     counting will keep them intact. However, if you have made any assumptions about the
     structure of the vertex data in the buffers of this object, you may have to rethink them.
     */
    void prepareForShadowVolume()
    {
        /* NOTE
         I would dearly, dearly love to just use a 4D position buffer in order to
         store the extra 'w' value I need to differentiate between extruded and
         non-extruded sections of the buffer, so that vertex programs could use that.
         Hey, it works fine for GL. However, D3D9 in it's infinite stupidity, does not
         support 4d position vertices in the fixed-function pipeline. If you use them,
         you just see nothing. Since we can't know whether the application is going to use
         fixed function or vertex programs, we have to stick to 3d position vertices and
         store the 'w' in a separate 1D texture coordinate buffer, which is only used
         when rendering the shadow.
         */
        
        // Upfront, lets check whether we have vertex program capability
        auto rend = Root.getSingleton().getRenderSystem();
        bool useVertexPrograms = false;
        if (rend && rend.getCapabilities().hasCapability(Capabilities.RSC_VERTEX_PROGRAM))
        {
            useVertexPrograms = true;
        }
        
        
        // Look for a position element
        auto posElem = vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
        if (posElem)
        {
            size_t v;
            ushort posOldSource = posElem.getSource();
            
            SharedPtr!HardwareVertexBuffer vbuf = vertexBufferBinding.getBuffer(posOldSource);
            bool wasSharedBuffer = false;
            // Are there other elements in the buffer except for the position?
            if (vbuf.get().getVertexSize() > posElem.getSize())
            {
                // We need to create another buffer to contain the remaining elements
                // Most drivers don't like gaps in the declaration, and in any case it's waste
                wasSharedBuffer = true;
            }
            SharedPtr!HardwareVertexBuffer newPosBuffer, newRemainderBuffer;
            if (wasSharedBuffer)
            {
                newRemainderBuffer = vbuf.get().getManager().createVertexBuffer(
                    vbuf.get().getVertexSize() - posElem.getSize(), vbuf.get().getNumVertices(), vbuf.get().getUsage(),
                    vbuf.get().hasShadowBuffer());
            }
            // Allocate new position buffer, will be FLOAT3 and 2x the size
            size_t oldVertexCount = vbuf.get().getNumVertices();
            size_t newVertexCount = oldVertexCount * 2;
            newPosBuffer = vbuf.get().getManager().createVertexBuffer(
                VertexElement.getTypeSize(VertexElementType.VET_FLOAT3), newVertexCount, vbuf.get().getUsage(),
                vbuf.get().hasShadowBuffer());
            
            // Iterate over the old buffer, copying the appropriate elements and initialising the rest
            float* pSrc;
            ubyte *pBaseSrc = cast(ubyte*)(vbuf.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY));
            // Point first destination pointer at the start of the new position buffer,
            // the other one half way along
            float *pDest = cast(float*)(newPosBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
            float* pDest2 = pDest + oldVertexCount * 3;
            
            // Precalculate any dimensions of vertex areas outside the position
            size_t prePosVertexSize = 0, postPosVertexSize, postPosVertexOffset;
            ubyte *pBaseDestRem = null;
            if (wasSharedBuffer)
            {
                pBaseDestRem = cast(ubyte*)(newRemainderBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
                prePosVertexSize = posElem.getOffset();
                postPosVertexOffset = prePosVertexSize + posElem.getSize();
                postPosVertexSize = vbuf.get().getVertexSize() - postPosVertexOffset;
                // the 2 separate bits together should be the same size as the remainder buffer vertex
                assert (newRemainderBuffer.get().getVertexSize() == prePosVertexSize + postPosVertexSize);
                
                // Iterate over the vertices
                for (v = 0; v < oldVertexCount; ++v)
                {
                    // Copy position, into both buffers
                    posElem.baseVertexPointerToElement(pBaseSrc, &pSrc);
                    *pDest++ = *pDest2++ = *pSrc++;
                    *pDest++ = *pDest2++ = *pSrc++;
                    *pDest++ = *pDest2++ = *pSrc++;
                    
                    // now deal with any other elements
                    // Basically we just memcpy the vertex excluding the position
                    if (prePosVertexSize > 0)
                        memcpy(pBaseDestRem, pBaseSrc, prePosVertexSize);
                    if (postPosVertexSize > 0)
                        memcpy(pBaseDestRem + prePosVertexSize,
                               pBaseSrc + postPosVertexOffset, postPosVertexSize);
                    pBaseDestRem += newRemainderBuffer.get().getVertexSize();
                    
                    pBaseSrc += vbuf.get().getVertexSize();
                    
                } // next vertex
            }
            else
            {
                // Unshared buffer, can block copy the whole thing
                core.stdc.string.memcpy(pDest, pBaseSrc, vbuf.get().getSizeInBytes());
                core.stdc.string.memcpy(pDest2, pBaseSrc, vbuf.get().getSizeInBytes());
            }
            
            vbuf.get().unlock();
            newPosBuffer.get().unlock();
            if (wasSharedBuffer)
                newRemainderBuffer.get().unlock();
            
            // At this stage, he original vertex buffer is going to be destroyed
            // So we should force the deallocation of any temporary copies
            vbuf.get().getManager()._forceReleaseBufferCopies(vbuf);
            
            if (useVertexPrograms)
            {
                // Now it's time to set up the w buffer
                hardwareShadowVolWBuffer = vbuf.get().getManager().createVertexBuffer(
                    float.sizeof, newVertexCount, HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, false);
                // Fill the first half with 1.0, second half with 0.0
                pDest = cast(float*)(
                    hardwareShadowVolWBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
                for (v = 0; v < oldVertexCount; ++v)
                {
                    *pDest++ = 1.0f;
                }
                for (v = 0; v < oldVertexCount; ++v)
                {
                    *pDest++ = 0.0f;
                }
                hardwareShadowVolWBuffer.get().unlock();
            }
            
            ushort newPosBufferSource;
            if (wasSharedBuffer)
            {
                // Get the a new buffer binding index
                newPosBufferSource= vertexBufferBinding.getNextIndex();
                // Re-bind the old index to the remainder buffer
                vertexBufferBinding.setBinding(posOldSource, newRemainderBuffer);
            }
            else
            {
                // We can just re-use the same source idex for the new position buffer
                newPosBufferSource = posOldSource;
            }
            // Bind the new position buffer
            vertexBufferBinding.setBinding(newPosBufferSource, newPosBuffer);
            
            // Now, alter the vertex declaration to change the position source
            // and the offsets of elements using the same buffer
            
            ushort idx;
            foreach(elemi; vertexDeclaration.getElements())
                //for(idx = 0; elemi != elemiend; ++elemi, ++idx)
            {
                if (elemi == posElem)
                {
                    // Modify position to point at new position buffer
                    vertexDeclaration.modifyElement(
                        idx,
                        newPosBufferSource, // new source buffer
                        0, // no offset now
                        VertexElementType.VET_FLOAT3,
                        VertexElementSemantic.VES_POSITION);
                }
                else if (wasSharedBuffer &&
                         elemi.getSource() == posOldSource &&
                         elemi.getOffset() > prePosVertexSize )
                {
                    // This element came after position, remove the position's
                    // size
                    vertexDeclaration.modifyElement(
                        idx,
                        posOldSource, // same old source
                        elemi.getOffset() - posElem.getSize(), // less offset now
                        elemi.getType(),
                        elemi.getSemantic(),
                        elemi.getIndex());
                    
                }
                idx++;
            }
            
            
            // Note that we don't change vertexCount, because the other buffer(s) are still the same
            // size after all
            
            
        }
    }
    
    /** Additional shadow volume vertex buffer storage.
     @remarks
     This additional buffer is only used where we have prepared this VertexData for
     use in shadow volume constructor, and where the current render system supports
     vertex programs. This buffer contains the 'w' vertex position component which will
     be used by that program to differentiate between extruded and non-extruded vertices.
     This 'w' component cannot be included in the original position buffer because
     DirectX does not allow 4-component positions in the fixed-function pipeline, and the original
     position buffer must still be usable for fixed-function rendering.
     @par
     Note that we don't store any vertex declaration or vertex buffer binding here because this
     can be reused in the shadow algorithm.
     */
    SharedPtr!HardwareVertexBuffer hardwareShadowVolWBuffer;
    
    
    /** Reorganises the data in the vertex buffers according to the
     new vertex declaration passed in. Note that new vertex buffers
     are created and written to, so if the buffers being referenced
     by this vertex data object are also used by others, then the
     original buffers will not be damaged by this operation.
     Once this operation has completed, the new declaration
     passed in will overwrite the current one.
     @param newDeclaration The vertex declaration which will be used
     for the reorganised buffer state. Note that the new declaration
     must not include any elements which do not already exist in the
     current declaration; you can drop elements by
     excluding them from the declaration if you wish, however.
     @param bufferUsage Vector of usage flags which indicate the usage options
     for each new vertex buffer created. The indexes of the entries must correspond
     to the buffer binding values referenced in the declaration.
     @param mgr Optional pointer to the manager to use to create new declarations
     and buffers etc. If not supplied, the HardwareBufferManager singleton will be used
     */
    void reorganiseBuffers(ref VertexDeclaration newDeclaration, ref BufferUsageList bufferUsages,
                           ref HardwareBufferManagerBase mgr /+= null+/)
    {
        HardwareBufferManagerBase pManager = mgr ? mgr : mMgr;
        // Firstly, close up any gaps in the buffer sources which might have arisen
        newDeclaration.closeGapsInSource();
        
        // Build up a list of both old and new elements in each buffer
        ushort  buf = 0;
        void*[]  oldBufferLocks;
        size_t[] oldBufferVertexSizes;
        void*[]  newBufferLocks;
        size_t[] newBufferVertexSizes;
        VertexBufferBinding newBinding = pManager.createVertexBufferBinding();
        //const
        VertexBufferBinding.VertexBufferBindingMap oldBindingMap = vertexBufferBinding.getBindings();
        //VertexBufferBinding.VertexBufferBindingMap.const_iterator itBinding;
        auto keys = sort(oldBindingMap.keys);

        // Pre-allocate old buffer locks
        if (!oldBindingMap.length)
        {
            size_t count = keys[$-1] + 1;//TODO Getting count, wtf
            oldBufferLocks.length = count;
            oldBufferVertexSizes.length = count;
        }
        // Lock all the old buffers for reading
        foreach (k,v; oldBindingMap)
        {
            assert(v.get().getNumVertices() >= vertexCount);
            
            oldBufferVertexSizes[k] = v.get().getVertexSize();
            oldBufferLocks[k] = v.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY);
        }
        
        // Create new buffers and lock all for writing
        buf = 0;
        while (newDeclaration.findElementsBySource(buf).length)
        {
            size_t vertexSize = newDeclaration.getVertexSize(buf);
            
            SharedPtr!HardwareVertexBuffer vbuf =
                pManager.createVertexBuffer(
                    vertexSize,
                    vertexCount,
                    bufferUsages[buf]);
            newBinding.setBinding(buf, vbuf);
            
            newBufferVertexSizes.insert(vertexSize);
            newBufferLocks.insert(
                vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
            buf++;
        }
        
        // Map from new to old elements
        alias VertexElement[VertexElement] NewToOldElementMap;
        NewToOldElementMap newToOldElementMap;
        VertexDeclaration.VertexElementList newElemList = newDeclaration.getElements();
        
        foreach (ei; newElemList)
        {
            // Find corresponding old element
            VertexElement oldElem =
                vertexDeclaration.findElementBySemantic(
                    ei.getSemantic(), ei.getIndex());
            if (!oldElem)
            {
                // Error, cannot create new elements with this method
                throw new ItemNotFoundError(
                    "Element not found in old vertex declaration",
                    "VertexData.reorganiseBuffers");
            }
            newToOldElementMap[ei] = oldElem;
        }
        // Now iterate over the new buffers, pulling data out of the old ones
        // For each vertex
        for (size_t v = 0; v < vertexCount; ++v)
        {
            // For each (new) element
            foreach (newElem; newElemList)
            {
                auto noi = newElem in newToOldElementMap;//pointer
                VertexElement oldElem = *noi;
                ushort oldBufferNo = oldElem.getSource();
                ushort newBufferNo = newElem.getSource();
                void* pSrcBase = cast(void*)(
                    cast(ubyte*)(oldBufferLocks[oldBufferNo])
                    + v * oldBufferVertexSizes[oldBufferNo]);
                void* pDstBase = cast(void*)(
                    cast(ubyte*)(newBufferLocks[newBufferNo])
                    + v * newBufferVertexSizes[newBufferNo]);
                void *pSrc;
                void *pDst;
                oldElem.baseVertexPointerToElement(pSrcBase, &pSrc);
                newElem.baseVertexPointerToElement(pDstBase, &pDst);
                
                core.stdc.string.memcpy(pDst, pSrc, newElem.getSize());
                
            }
        }
        
        // Unlock all buffers
        foreach (itBinding; oldBindingMap)
        {
            itBinding.get().unlock();
        }
        for (buf = 0; buf < newBinding.getBufferCount(); ++buf)
        {
            newBinding.getBuffer(buf).get().unlock();
        }
        
        // Delete old binding & declaration
        if (mDeleteDclBinding)
        {
            pManager.destroyVertexBufferBinding(vertexBufferBinding);
            pManager.destroyVertexDeclaration(vertexDeclaration);
        }
        
        // Assign new binding and declaration
        vertexDeclaration = newDeclaration;
        vertexBufferBinding = newBinding;
        // after this is complete, new manager should be used
        mMgr = pManager;
        mDeleteDclBinding = true; // because we created these through a manager
        
    }
    
    /** Reorganises the data in the vertex buffers according to the
     new vertex declaration passed in. Note that new vertex buffers
     are created and written to, so if the buffers being referenced
     by this vertex data object are also used by others, then the
     original buffers will not be damaged by this operation.
     Once this operation has completed, the new declaration
     passed in will overwrite the current one.
     This version of the method derives the buffer usages from the existing
     buffers, by using the 'most flexible' usage from the equivalent sources.
     @param newDeclaration The vertex declaration which will be used
     for the reorganised buffer state. Note that the new delcaration
     must not include any elements which do not already exist in the
     current declaration; you can drop elements by
     excluding them from the declaration if you wish, however.
     @param mgr Optional pointer to the manager to use to create new declarations
     and buffers etc. If not supplied, the HardwareBufferManager singleton will be used
     */
    void reorganiseBuffers(ref VertexDeclaration newDeclaration, /+ref+/ HardwareBufferManagerBase mgr = null) //ref cant be null
    {
        // Derive the buffer usages from looking at where the source has come
        // from
        BufferUsageList usages;
        for (ushort b = 0; b <= newDeclaration.getMaxSource(); ++b)
        {
            VertexDeclaration.VertexElementList destElems = newDeclaration.findElementsBySource(b);
            // Initialise with most restrictive version
            // (not really a usable option, but these flags will be removed)
            HardwareBuffer.Usage _final = cast(HardwareBuffer.Usage)(
                HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY | HardwareBuffer.Usage.HBU_DISCARDABLE);
            
            foreach (ref destelem; destElems)
            {
                // get source
                VertexElement srcelem =
                    vertexDeclaration.findElementBySemantic(
                        destelem.getSemantic(), destelem.getIndex());
                // get buffer
                SharedPtr!HardwareVertexBuffer srcbuf =
                    vertexBufferBinding.getBuffer(srcelem.getSource());
                // improve flexibility only
                if (srcbuf.get().getUsage() & HardwareBuffer.Usage.HBU_DYNAMIC)
                {
                    // remove static
                    _final = cast(HardwareBuffer.Usage)(
                        _final & ~HardwareBuffer.Usage.HBU_STATIC);
                    // add dynamic
                    _final = cast(HardwareBuffer.Usage)(
                        _final | HardwareBuffer.Usage.HBU_DYNAMIC);
                }
                if (!(srcbuf.get().getUsage() & HardwareBuffer.Usage.HBU_WRITE_ONLY))
                {
                    // remove write only
                    _final = cast(HardwareBuffer.Usage)(
                        _final & ~HardwareBuffer.Usage.HBU_WRITE_ONLY);
                }
                if (!(srcbuf.get().getUsage() & HardwareBuffer.Usage.HBU_DISCARDABLE))
                {
                    // remove discardable
                    _final = cast(HardwareBuffer.Usage)(
                        _final & ~HardwareBuffer.Usage.HBU_DISCARDABLE);
                }
                
            }
            usages.insert(_final);
        }
        // Call specific method
        reorganiseBuffers(newDeclaration, usages, mgr);
        
    }
    
    /** Remove any gaps in the vertex buffer bindings.
     @remarks
     This is useful if you've removed elements and buffers from this vertex
     data and want to remove any gaps in the vertex buffer bindings. This
     method is mainly useful when reorganising vertex data manually.
     @note
     This will cause binding index of the elements in the vertex declaration
     to be altered to new binding index.
     */
    void closeGapsInBindings()
    {
        if (!vertexBufferBinding.hasGaps())
            return;
        
        // Check for error first
        VertexDeclaration.VertexElementList allelems =
            vertexDeclaration.getElements();
        
        foreach (elem; allelems)
        {
            if (!vertexBufferBinding.isBufferBound(elem.getSource()))
            {
                throw new ItemNotFoundError(
                    "No buffer is bound to that element source.",
                    "VertexData.closeGapsInBindings");
            }
        }
        
        // Close gaps in the vertex buffer bindings
        VertexBufferBinding.BindingIndexMap bindingIndexMap;
        vertexBufferBinding.closeGaps(bindingIndexMap);
        
        // Modify vertex elements to reference to new buffer index
        ushort elemIndex = 0;
        foreach (elem; allelems)
        {
            auto it = elem.getSource() in bindingIndexMap;
            assert(it !is null);
            ushort targetSource = *it;//.second;
            if (elem.getSource() != targetSource)
            {
                vertexDeclaration.modifyElement(elemIndex,
                                                targetSource, elem.getOffset(), elem.getType(),
                                                elem.getSemantic(), elem.getIndex());
            }
            elemIndex++;
        }
    }
    
    /** Remove all vertex buffers that never used by the vertex declaration.
     @remarks
     This is useful if you've removed elements from the vertex declaration
     and want to unreference buffers that never used any more. This method
     is mainly useful when reorganising vertex data manually.
     @note
     This also remove any gaps in the vertex buffer bindings.
     */
    void removeUnusedBuffers()
    {
        ushort[] usedBuffers;
        
        // Collect used buffers
        auto allelems = vertexDeclaration.getElements();
        
        foreach (elem; allelems)
        {
            usedBuffers.insert(elem.getSource());
        }
        
        // Unset unused buffer bindings
        ushort count = vertexBufferBinding.getLastBoundIndex();
        for (ushort index = 0; index < count; ++index)
        {
            if (usedBuffers.inArray(index) &&
                vertexBufferBinding.isBufferBound(index))
            {
                vertexBufferBinding.unsetBinding(index);
            }
        }
        
        // Close gaps
        closeGapsInBindings();
    }
    
    /** Convert all packed colour values (VertexElementType.VET_COLOUR_*) in buffers used to
     another type.
     @param srcType The source colour type to assume if the ambiguous VertexElementType.VET_COLOUR
     is encountered.
     @param destType The destination colour type, must be VertexElementType.VET_COLOUR_ABGR or
     VertexElementType.VET_COLOUR_ARGB.
     */
    void convertPackedColour(VertexElementType srcType, VertexElementType destType)
    {
        if (destType != VertexElementType.VET_COLOUR_ABGR && destType != VertexElementType.VET_COLOUR_ARGB)
        {
            throw new InvalidParamsError(
                "Invalid destType parameter", "VertexData.convertPackedColour");
        }
        if (srcType != VertexElementType.VET_COLOUR_ABGR && srcType != VertexElementType.VET_COLOUR_ARGB)
        {
            throw new InvalidParamsError(
                "Invalid srcType parameter", "VertexData.convertPackedColour");
        }
        
        auto bindMap = vertexBufferBinding.getBindings();
        
        foreach (k, bind; bindMap)
        {
            auto elems = vertexDeclaration.findElementsBySource(k);
            bool conversionNeeded = false;
            
            foreach (elem; elems)
            {
                if (elem.getType() == VertexElementType.VET_COLOUR ||
                    ((elem.getType() == VertexElementType.VET_COLOUR_ABGR || elem.getType() == VertexElementType.VET_COLOUR_ARGB)
                 && elem.getType() != destType))
                {
                    conversionNeeded = true;
                }
            }
            
            if (conversionNeeded)
            {
                void* pBase = bind.get().lock(HardwareBuffer.LockOptions.HBL_NORMAL);
                
                for (size_t v = 0; v < bind.get().getNumVertices(); ++v)
                {
                    
                    foreach (elem; elems)
                    {
                        VertexElementType currType = (elem.getType() == VertexElementType.VET_COLOUR) ?
                            srcType : elem.getType();
                        if (elem.getType() == VertexElementType.VET_COLOUR ||
                            ((elem.getType() == VertexElementType.VET_COLOUR_ABGR || elem.getType() == VertexElementType.VET_COLOUR_ARGB)
                         && elem.getType() != destType))
                        {
                            uint* pRGBA;
                            elem.baseVertexPointerToElement(pBase, &pRGBA);
                            VertexElement.convertColourValue(currType, destType, *pRGBA);
                        }
                    }
                    pBase = cast(void*)(
                        cast(byte*)(pBase) + bind.get().getVertexSize());
                }
                bind.get().unlock();
                
                // Modify the elements to reflect the changed type
                auto allelems = vertexDeclaration.getElements();
                
                ushort elemIndex = 0;
                foreach (elem; allelems)
                {
                    if (elem.getType() == VertexElementType.VET_COLOUR ||
                        ((elem.getType() == VertexElementType.VET_COLOUR_ABGR || elem.getType() == VertexElementType.VET_COLOUR_ARGB)
                     && elem.getType() != destType))
                    {
                        vertexDeclaration.modifyElement(elemIndex,
                                                        elem.getSource(), elem.getOffset(), destType,
                                                        elem.getSemantic(), elem.getIndex());
                    }
                    elemIndex++;
                }
                
            }
            
            
        } // each buffer
        
        
    }
    
    
    /** Allocate elements to serve a holder of morph / pose target data
     for hardware morphing / pose blending.
     @remarks
     This method will allocate the given number of 3D texture coordinate
     sets for use as a morph target or target pose offset (3D position).
     These elements will be saved in hwAnimationDataList.
     It will also assume that the source of these new elements will be new
     buffers which are not bound at this time, so will start the sources to
     1 higher than the current highest binding source. The caller is
     expected to bind these new buffers when appropriate. For morph animation
     the original position buffer will be the 'from' keyframe data, whilst
     for pose animation it will be the original vertex data.
     If normals are animated, then twice the number of 3D texture coordinates are required
     @return The number of sets that were supported
     */
    ushort allocateHardwareAnimationElements(ushort count, bool animateNormals)
    {
        // Find first free texture coord set
        ushort texCoord = vertexDeclaration.getNextFreeTextureCoordinate();
        ushort freeCount = cast(ushort)(OGRE_MAX_TEXTURE_COORD_SETS - texCoord);
        if (animateNormals)
            // we need 2x the texture coords, round down
            freeCount /= 2;
        
        ushort supportedCount = std.algorithm.min(freeCount, count);
        
        // Increase to correct size
        for (size_t c = hwAnimationDataList.length; c < supportedCount; ++c)
        {
            // Create a new 3D texture coordinate set
            HardwareAnimationData data;
            data.targetBufferIndex = vertexBufferBinding.getNextIndex();
            vertexDeclaration.addElement(data.targetBufferIndex, 0, VertexElementType.VET_FLOAT3, 
                                         VertexElementSemantic.VES_TEXTURE_COORDINATES, texCoord++);
            if (animateNormals)
                vertexDeclaration.addElement(data.targetBufferIndex, float.sizeof*3, VertexElementType.VET_FLOAT3, 
                                             VertexElementSemantic.VES_TEXTURE_COORDINATES, texCoord++);
            
            hwAnimationDataList.insert(data);
            // Vertex buffer will not be bound yet, we expect this to be done by the
            // caller when it becomes appropriate (e.g. through a VertexAnimationTrack)
        }
        
        return supportedCount;
    }
    
    
}

/** Vertex cache profiler.
 @remarks
 Utility class for evaluating the effectiveness of the use of the vertex
 cache by a given index buffer.
 */
class VertexCacheProfiler// : public BufferAlloc
{
public:
    enum CacheType {
        FIFO, LRU
    }
    
    this(uint cachesize = 16, CacheType cachetype = CacheType.FIFO )
    {
        size = cachesize; tail = 0; buffersize = 0;
        hit = 0; miss = 0;
        cache = new uint[size];//OGRE_ALLOC_T(uint, size, MEMCATEGORY_GEOMETRY);
    }
    
    ~this()
    {
        //OGRE_FREE(cache, MEMCATEGORY_GEOMETRY);
        destroy(cache); //or just gc this?
    }
    
    void profile(SharedPtr!HardwareIndexBuffer indexBuffer)
    {
        if (indexBuffer.get().isLocked()) return;
        
        ushort *shortbuffer = cast(ushort *)indexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY);
        
        if (indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_16BIT)
            for (uint i = 0; i < indexBuffer.get().getNumIndexes(); ++i)
                inCache(shortbuffer[i]);
        else
        {
            uint *buffer = cast(uint *)shortbuffer;
            for (uint i = 0; i < indexBuffer.get().getNumIndexes(); ++i)
                inCache(buffer[i]);
        }
        
        indexBuffer.get().unlock();
    }

    void reset() { hit = 0; miss = 0; tail = 0; buffersize = 0; }
    void flush() { tail = 0; buffersize = 0; }
    
    uint getHits() { return hit; }
    uint getMisses() { return miss; }
    uint getSize() { return size; }
private:
    uint size;
    uint[] cache;
    
    uint tail, buffersize;
    uint hit, miss;
    
    bool inCache(uint index)
    {
        for (uint i = 0; i < buffersize; ++i)
        {
            if (index == cache[i])
            {
                hit++;
                return true;
            }
        }
        
        miss++;
        cache[tail++] = index;
        tail %= size;
        
        if (buffersize < size) buffersize++;
        
        return false;
    }
}
