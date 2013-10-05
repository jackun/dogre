module ogre.scene.manualobject;

private
{
    import core.stdc.string : memcpy;
    //import std.container;
    import std.array;
}

import ogre.sharedptr;
import ogre.math.axisalignedbox;
import ogre.general.colourvalue;
import ogre.general.common;
import ogre.compat;
import ogre.config;
import ogre.exception;
import ogre.materials.gpuprogram;
import ogre.rendersystem.hardware;
import ogre.math.edgedata;
import ogre.resources.mesh;
import ogre.math.vector;
import ogre.math.matrix;
import ogre.scene.movableobject;
import ogre.rendersystem.renderoperation;
import ogre.resources.resourcegroupmanager;
import ogre.rendersystem.renderqueue;
import ogre.scene.light;
import ogre.scene.renderable;
import ogre.scene.shadowcaster;
import ogre.rendersystem.vertex;
import ogre.resources.meshmanager;
import ogre.materials.pass;
import ogre.materials.materialmanager;
import ogre.scene.node;
import ogre.general.root;
import ogre.math.maths;
import ogre.general.log;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Scene
    *  @{
    */

enum TEMP_INITIAL_SIZE = 50;
enum TEMP_VERTEXSIZE_GUESS = float.sizeof * 12;
enum TEMP_INITIAL_VERTEX_SIZE = TEMP_VERTEXSIZE_GUESS * TEMP_INITIAL_SIZE;
enum TEMP_INITIAL_INDEX_SIZE  = uint.sizeof * TEMP_INITIAL_SIZE;

/** Class providing a much simplified interface to generating manual
        objects with custom geometry.
    @remarks
        Building one-off geometry objects manually usually requires getting
        down and dirty with the vertex buffer and vertex declaration API, 
        which some people find a steep learning curve. This class gives you 
        a simpler interface specifically for the purpose of building a 
        3D object simply and quickly. Note that if you intend to instance your
        object you will still need to become familiar with the Mesh class. 
    @par
        This class draws heavily on the interface for OpenGL 
        immediate-mode (glBegin, glVertex, glNormal etc), since this
        is generally well-liked by people. There are a couple of differences
        in the results though - internally this class still builds hardware 
        buffers which can be re-used, so you can render the resulting object
        multiple times without re-issuing all the same commands again. 
        Secondly, the rendering is not immediate, it is still queued just like
        all OGRE objects. This makes this object more efficient than the 
        equivalent GL immediate-mode commands, so it's feasible to use it for
        large objects if you really want to.
    @par
        Toruct some geometry with this object:
          -# If you know roughly how many vertices (and indices, if you use them)
             you're going to submit, call estimateVertexCount and estimateIndexCount.
             This is not essential but will make the process more efficient by saving
             memory reallocations.
          -# Call begin() to begin entering data
          -# For each vertex, call position(), normal(), textureCoord(), colour()
             to define your vertex data. Note that each time you call position()
             you start a new vertex. Note that the first vertex defines the 
             components of the vertex - you can't add more after that. For example
             if you didn't call normal() in the first vertex, you cannot call it
             in any others. You ought to call the same combination of methods per
             vertex.
          -# If you want to define triangles (or lines/points) by indexing into the vertex list, 
             you can call index() as many times as you need to define them.
             If you don't do this, the class will assume you want triangles drawn
             directly as defined by the vertex list, i.e. non-indexed geometry. Note
             that stencil shadows are only supported on indexed geometry, and that
             indexed geometry is a little faster; so you should try to use it.
          -# Call end() to finish entering data.
          -# Optionally repeat the begin-end cycle if you want more geometry 
            using different rendering operation types, or different materials
        After calling end(), the class will organise the data for that section
        internally and make it ready to render with. Like any other 
        MovableObject you should attach the object to a SceneNode to make it 
        visible. Other aspects like the relative render order can be controlled
        using standard MovableObject methods like setRenderQueueGroup.
    @par
        You can also use beginUpdate() to alter the geometry later on if you wish.
        If you do this, you should call setDynamic(true) before your first call 
        to begin(), and also consider using estimateVertexCount / estimateIndexCount
        if your geometry is going to be growing, to avoid buffer recreation during
        growth.
    @par
        Note that like all OGRE geometry, triangles should be specified in 
        anti-clockwise winding order (whether you're doing it with just
        vertices, or using indexes too). That is to say that the front of the
        face is the one where the vertices are listed in anti-clockwise order.
    */
class ManualObject : MovableObject
{
public:
    this(string name)
    {
        super(name);
        mDynamic = false;
        mCurrentSection = null;
        mFirstVertex = true;
        mTempVertexPending = false;
        mTempVertexBuffer = null;
        mTempVertexSize = TEMP_INITIAL_VERTEX_SIZE;
        mTempIndexBuffer = null;
        mTempIndexSize = TEMP_INITIAL_INDEX_SIZE;
        mDeclSize = 0;
        mEstVertexCount = 0;
        mEstIndexCount = 0;
        mTexCoordIndex = 0;
        mRadius = 0;
        mAnyIndexed = false;
        mEdgeList = null;
        mUseIdentityProjection = false;
        mUseIdentityView = false;
        mKeepDeclarationOrder = false;
    }

    ~this()
    {
        clear();
    }

    /** Completely clear the contents of the object.
        @remarks
            Clearing the contents of this object and rebuilding from scratch
            is not the optimal way to manage dynamic vertex data, since the 
            buffers are recreated. If you want to keep the same structure but
            update the content within that structure, use beginUpdate() instead 
            of clear() begin(). However if you do want to modify the structure 
            from time to time you can do so by clearing and re-specifying the data.
        */
    void clear()
    {
        resetTempAreas();
        foreach (i; mSectionList)
        {
            destroy(i);
        }
        mSectionList.clear();
        mRadius = 0;
        mAABB.setNull();
        destroy(mEdgeList);
        //mEdgeList = null;
        mAnyIndexed = false;
        foreach (s; mShadowRenderables)
        {
            destroy(s);
        }
        mShadowRenderables.clear();        
    }
    
    /** Estimate the number of vertices ahead of time.
        @remarks
            Calling this helps to avoid memory reallocation when you define
            vertices. Also very handy when using beginUpdate() to manage dynamic
            data - you can make the vertex buffers a little larger than their
            initial needs to allow for growth later with this method.
        */
    void estimateVertexCount(size_t vcount)
    {
        resizeTempVertexBufferIfNeeded(vcount);
        mEstVertexCount = vcount;
    }
    
    /** Estimate the number of indices ahead of time.
        @remarks
            Calling this helps to avoid memory reallocation when you define
            indices. Also very handy when using beginUpdate() to manage dynamic
            data - you can make the index buffer a little larger than the
            initial need to allow for growth later with this method.
        */
    void estimateIndexCount(size_t icount)
    {
        resizeTempIndexBufferIfNeeded(icount);
        mEstIndexCount = icount;
    }
    
    /** Start defining a part of the object.
        @remarks
            Each time you call this method, you start a new section of the
            object with its own material and potentially its own type of
            rendering operation (triangles, points or lines for example).
        @param materialName The name of the material to render this part of the
            object with.
        @param opType The type of operation to use to render. 
        */
    void begin(string materialName,
               RenderOperation.OperationType opType = RenderOperation.OperationType.OT_TRIANGLE_LIST, 
               string groupName = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME)
    {
        if (mCurrentSection)
        {
            throw new InvalidParamsError(
                        "You cannot call begin() again until after you call end()",
                        "ManualObject.begin");
        }
        // Check that a valid material was provided
        MaterialPtr material = MaterialManager.getSingleton().getByName(materialName, groupName);
        
        if( material.isNull() )
        {
            LogManager.getSingleton().logMessage("Can't assign material " ~ materialName ~
                                                  " to the ManualObject " ~ mName ~ " because this "
                                                  "Material does not exist. Have you forgotten to define it in a "
                                                  ".material script?");
            
            material = MaterialManager.getSingleton().getByName("BaseWhite");
            
            if (material.isNull())
            {
                throw new InternalError("Can't assign default material "
                                        "to the ManualObject " ~ mName ~ ". Did "
                                        "you forget to call MaterialManager.initialise()?",
                                        "ManualObject.begin");
            }
        }
        
        mCurrentSection = new ManualObjectSection(this, materialName, opType, groupName);
        mCurrentUpdating = false;
        mCurrentSection.setUseIdentityProjection(mUseIdentityProjection);
        mCurrentSection.setUseIdentityView(mUseIdentityView);
        mSectionList.insert(mCurrentSection);
        mFirstVertex = true;
        mDeclSize = 0;
        mTexCoordIndex = 0;
    }
    
    /** Use before defining geometry to indicate that you intend to update the
            geometry regularly and want the internal structure to reflect that.
        */
    void setDynamic(bool dyn) { mDynamic = dyn; }
    /** Gets whether this object is marked as dynamic */
    bool getDynamic(){ return mDynamic; }
    
    /** Start the definition of an update to a part of the object.
        @remarks
            Using this method, you can update an existing section of the object
            efficiently. You do not have the option of changing the operation type
            obviously, since it must match the one that was used before. 
        @note If your sections are changing size, particularly growing, use
            estimateVertexCount and estimateIndexCount to pre-size the buffers a little
            larger than the initial needs to avoid buffer reconstruction.
        @param sectionIndex The index of the section you want to update. The first
            call to begin() would have created section 0, the second section 1, etc.
        */
    void beginUpdate(size_t sectionIndex)
    {
        if (mCurrentSection)
        {
            throw new InvalidParamsError(
                        "You cannot call begin() again until after you call end()",
                        "ManualObject.beginUpdate");
        }
        if (sectionIndex >= mSectionList.length)
        {
            throw new InvalidParamsError(
                        "Invalid section index - out of range.",
                        "ManualObject.beginUpdate");
        }
        mCurrentSection = mSectionList[sectionIndex];
        mCurrentUpdating = true;
        mFirstVertex = true;
        mTexCoordIndex = 0;
        // reset vertex & index count
        RenderOperation rop = mCurrentSection.getRenderOperation();
        rop.vertexData.vertexCount = 0;
        if (rop.indexData)
            rop.indexData.indexCount = 0;
        rop.useIndexes = false;
        mDeclSize = rop.vertexData.vertexDeclaration.getVertexSize(0);
    }
    /** Add a vertex position, starting a new vertex at the same time. 
        @remarks A vertex position is slightly special among the other vertex data
            methods like normal() and textureCoord(), since calling it indicates
            the start of a new vertex. All other vertex data methods you call 
            after this are assumed to be adding more information (like normals or
            texture coordinates) to the last vertex started with position().
        */
    void position(Vector3 pos)
    {
        position(pos.x, pos.y, pos.z);
    }

    /// @copydoc ManualObject.position(Vector3&)
    void position(Real x, Real y, Real z)
    {
        if (!mCurrentSection)
        {
            throw new InvalidParamsError(
                        "You must call begin() before this method",
                        "ManualObject,position");
        }
        if (mTempVertexPending)
        {
            // bake current vertex
            copyTempVertexToBuffer();
            mFirstVertex = false;
        }
        
        if (mFirstVertex && !mCurrentUpdating)
        {
            // defining declaration
            mCurrentSection.getRenderOperation().vertexData.vertexDeclaration
                .addElement(0, mDeclSize, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_POSITION);
            mDeclSize += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
        }
        
        mTempVertex.position.x = x;
        mTempVertex.position.y = y;
        mTempVertex.position.z = z;
        
        // update bounds
        mAABB.merge(mTempVertex.position);
        mRadius = std.algorithm.max(mRadius, mTempVertex.position.length());
        
        // reset current texture coord
        mTexCoordIndex = 0;
        
        mTempVertexPending = true;
    }
    
    /** Add a vertex normal to the current vertex.
        @remarks
            Vertex normals are most often used for dynamic lighting, and 
            their components should be normalised.
        */
    void normal(Vector3 norm)
    {
        normal(norm.x, norm.y, norm.z);
    }

    /// @copydoc ManualObject.normal(Vector3&)
    void normal(Real x, Real y, Real z)
    {
        if (!mCurrentSection)
        {
            throw new InvalidParamsError(
                        "You must call begin() before this method",
                        "ManualObject.normal");
        }
        if (mFirstVertex && !mCurrentUpdating)
        {
            // defining declaration
            mCurrentSection.getRenderOperation().vertexData.vertexDeclaration
                .addElement(0, mDeclSize, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_NORMAL);
            mDeclSize += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
        }
        mTempVertex.normal.x = x;
        mTempVertex.normal.y = y;
        mTempVertex.normal.z = z;
    }
    
    /** Add a vertex tangent to the current vertex.
        @remarks
            Vertex tangents are most often used for dynamic lighting, and 
            their components should be normalised. 
            Also, using tangent() you enable VES_TANGENT vertex semantic, which is not
            supported on old non-SM2 cards.
        */
    void tangent(Vector3 tan)
    {
        tangent(tan.x, tan.y, tan.z);
    }

    /// @copydoc ManualObject.tangent(Vector3&)
    void tangent(Real x, Real y, Real z)
    {
        if (!mCurrentSection)
        {
            throw new InvalidParamsError(
                        "You must call begin() before this method",
                        "ManualObject.tangent");
        }
        if (mFirstVertex && !mCurrentUpdating)
        {
            // defining declaration
            mCurrentSection.getRenderOperation().vertexData.vertexDeclaration
                .addElement(0, mDeclSize, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_TANGENT);
            mDeclSize += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
        }
        mTempVertex.tangent.x = x;
        mTempVertex.tangent.y = y;
        mTempVertex.tangent.z = z;
    }
    
    /** Add a texture coordinate to the current vertex.
        @remarks
            You can call this method multiple times between position() calls
            to add multiple texture coordinates to a vertex. Each one can have
            between 1 and 3 dimensions, depending on your needs, although 2 is
            most common. There are several versions of this method for the 
            variations in number of dimensions.
        */
    void textureCoord(Real u)
    {
        if (!mCurrentSection)
        {
        throw new InvalidParamsError(
                        "You must call begin() before this method",
                        "ManualObject.textureCoord");
        }
        if (mFirstVertex && !mCurrentUpdating)
        {
            // defining declaration
            mCurrentSection.getRenderOperation().vertexData.vertexDeclaration
                .addElement(0, mDeclSize, VertexElementType.VET_FLOAT1, VertexElementSemantic.VES_TEXTURE_COORDINATES, mTexCoordIndex);
            mDeclSize += VertexElement.getTypeSize(VertexElementType.VET_FLOAT1);
        }
        mTempVertex.texCoordDims[mTexCoordIndex] = 1;
        mTempVertex.texCoord[mTexCoordIndex].x = u;
        
        ++mTexCoordIndex;
        
    }

    /// @copydoc ManualObject.textureCoord(Real)
    void textureCoord(Real u, Real v)
    {
        if (!mCurrentSection)
        {
            throw new InvalidParamsError(
                        "You must call begin() before this method",
                        "ManualObject.textureCoord");
        }
        if (mFirstVertex && !mCurrentUpdating)
        {
            // defining declaration
            mCurrentSection.getRenderOperation().vertexData.vertexDeclaration
                .addElement(0, mDeclSize, VertexElementType.VET_FLOAT2, VertexElementSemantic.VES_TEXTURE_COORDINATES, mTexCoordIndex);
            mDeclSize += VertexElement.getTypeSize(VertexElementType.VET_FLOAT2);
        }
        mTempVertex.texCoordDims[mTexCoordIndex] = 2;
        mTempVertex.texCoord[mTexCoordIndex].x = u;
        mTempVertex.texCoord[mTexCoordIndex].y = v;
        
        ++mTexCoordIndex;
    }
    /// @copydoc ManualObject.textureCoord(Real)
    void textureCoord(Real u, Real v, Real w)
    {
        if (!mCurrentSection)
        {
            throw new InvalidParamsError(
                        "You must call begin() before this method",
                        "ManualObject.textureCoord");
        }
        if (mFirstVertex && !mCurrentUpdating)
        {
            // defining declaration
            mCurrentSection.getRenderOperation().vertexData.vertexDeclaration
                .addElement(0, mDeclSize, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_TEXTURE_COORDINATES, mTexCoordIndex);
            mDeclSize += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
        }
        mTempVertex.texCoordDims[mTexCoordIndex] = 3;
        mTempVertex.texCoord[mTexCoordIndex].x = u;
        mTempVertex.texCoord[mTexCoordIndex].y = v;
        mTempVertex.texCoord[mTexCoordIndex].z = w;
        
        ++mTexCoordIndex;
    }

    /// @copydoc ManualObject.textureCoord(Real)
    void textureCoord(Real x, Real y, Real z, Real w)
    {
        if (!mCurrentSection)
        {
            throw new InvalidParamsError(
                        "You must call begin() before this method",
                        "ManualObject.textureCoord");
        }
        if (mFirstVertex && !mCurrentUpdating)
        {
            // defining declaration
            mCurrentSection.getRenderOperation().vertexData.vertexDeclaration
                .addElement(0, mDeclSize, VertexElementType.VET_FLOAT4, VertexElementSemantic.VES_TEXTURE_COORDINATES, mTexCoordIndex);
            mDeclSize += VertexElement.getTypeSize(VertexElementType.VET_FLOAT4);
        }
        mTempVertex.texCoordDims[mTexCoordIndex] = 4;
        mTempVertex.texCoord[mTexCoordIndex].x = x;
        mTempVertex.texCoord[mTexCoordIndex].y = y;
        mTempVertex.texCoord[mTexCoordIndex].z = z;
        mTempVertex.texCoord[mTexCoordIndex].w = w;
        
        ++mTexCoordIndex;
    }

    /// @copydoc ManualObject.textureCoord(Real)
    void textureCoord(Vector2 uv)
    {
        textureCoord(uv.x, uv.y);
    }
    /// @copydoc ManualObject.textureCoord(Real)
    void textureCoord(Vector3 uvw)
    {
        textureCoord(uvw.x, uvw.y, uvw.z);
    }
    /// @copydoc ManualObject.textureCoord(Real)
    void textureCoord(Vector4 xyzw)
    {
        textureCoord(xyzw.x, xyzw.y, xyzw.z, xyzw.w);
    }
    
    /** Add a vertex colour to a vertex.
        */
    void colour(ColourValue col)
    {
        colour(col.r, col.g, col.b, col.a);
    }
    /** Add a vertex colour to a vertex.
        @param r,g,b,a Colour components expressed as floating point numbers from 0-1
        */
    void colour(Real r, Real g, Real b, Real a = 1.0f)
    {
        if (!mCurrentSection)
        {
            throw new InvalidParamsError(
                        "You must call begin() before this method",
                        "ManualObject.colour");
        }
        if (mFirstVertex && !mCurrentUpdating)
        {
            // defining declaration
            mCurrentSection.getRenderOperation().vertexData.vertexDeclaration
                .addElement(0, mDeclSize, VertexElementType.VET_COLOUR, VertexElementSemantic.VES_DIFFUSE);
            mDeclSize += VertexElement.getTypeSize(VertexElementType.VET_COLOUR);
        }
        mTempVertex.colour.r = r;
        mTempVertex.colour.g = g;
        mTempVertex.colour.b = b;
        mTempVertex.colour.a = a;
        
    }
    
    /** Add a vertex index toruct faces / lines / points via indexing
            rather than just by a simple list of vertices. 
        @remarks
            You will have to call this 3 times for each face for a triangle list, 
            or use the alternative 3-parameter version. Other operation types
            require different numbers of indexes, @see RenderOperation.OperationType.
        @note
            32-bit indexes are not supported on all cards and will only be used
            when required, if an index is > 65535.
        @param idx A vertex index from 0 to 4294967295. 
        */
    void index(uint idx)
    {
        if (!mCurrentSection)
        {
            throw new InvalidParamsError(
                        "You must call begin() before this method",
                        "ManualObject.index");
        }
        mAnyIndexed = true;
        if (idx >= 65536)
            mCurrentSection.set32BitIndices(true);
        
        // make sure we have index data
        RenderOperation rop = mCurrentSection.getRenderOperation();
        if (!rop.indexData)
        {
            rop.indexData = new IndexData();
            rop.indexData.indexCount = 0;
        }
        rop.useIndexes = true;
        resizeTempIndexBufferIfNeeded(++rop.indexData.indexCount);
        
        mTempIndexBuffer[rop.indexData.indexCount - 1] = idx;
    }
    /** Add a set of 3 vertex indices toruct a triangle; this is a
            shortcut to calling index() 3 times. It is only valid for triangle 
            lists.
        @note
            32-bit indexes are not supported on all cards and will only be used
            when required, if an index is > 65535.
        @param i1, i2, i3 3 vertex indices from 0 to 4294967295 defining a face. 
        */
    void triangle(uint i1, uint i2, uint i3)
    {
        if (!mCurrentSection)
        {
            throw new InvalidParamsError(
                        "You must call begin() before this method",
                        "ManualObject.index");
        }
        if (mCurrentSection.getRenderOperation().operationType !=
            RenderOperation.OperationType.OT_TRIANGLE_LIST)
        {
            throw new InvalidParamsError(
                        "This method is only valid on triangle lists",
                        "ManualObject.index");
        }
        
        index(i1);
        index(i2);
        index(i3);
    }
    /** Add a set of 4 vertex indices toruct a quad (out of 2 
            triangles); this is a shortcut to calling index() 6 times, 
            or triangle() twice. It's only valid for triangle list operations.
        @note
            32-bit indexes are not supported on all cards and will only be used
            when required, if an index is > 65535.
        @param i1, i2, i3, i4 4 vertex indices from 0 to 4294967295 defining a quad. 
        */
    void quad(uint i1, uint i2, uint i3, uint i4)
    {
        // first tri
        triangle(i1, i2, i3);
        // second tri
        triangle(i3, i4, i1);
    }
    
    /// Get the number of vertices in the section currently being defined (returns 0 if no section is in progress).
    size_t getCurrentVertexCount()
    {
        if (!mCurrentSection)
            return 0;
        
        RenderOperation rop = mCurrentSection.getRenderOperation();
        
        // There's an unfinished vertex being defined, so include it in count
        if (mTempVertexPending)
            return rop.vertexData.vertexCount + 1;
        else
            return rop.vertexData.vertexCount;
        
    }
    
    /// Get the number of indices in the section currently being defined (returns 0 if no section is in progress).
    size_t getCurrentIndexCount()
    {
        if (!mCurrentSection)
            return 0;
        
        RenderOperation rop = mCurrentSection.getRenderOperation();
        if (rop.indexData)
            return rop.indexData.indexCount;
        else
            return 0;
        
    }
    
    /** Finish defining the object and compile the final renderable version. 
        @note
            Will return a pointer to the finished section or NULL if the section was discarded (i.e. has zero vertices/indices).
        */
    ManualObjectSection end()
    {
        if (!mCurrentSection)
        {
            throw new InvalidParamsError(
                        "You cannot call end() until after you call begin()",
                        "ManualObject.end");
        }
        if (mTempVertexPending)
        {
            // bake current vertex
            copyTempVertexToBuffer();
        }
        
        // pointer that will be returned
        ManualObjectSection result;
        
        RenderOperation rop = mCurrentSection.getRenderOperation();
        // Check for empty content
        if (rop.vertexData.vertexCount == 0 ||
            (rop.useIndexes && rop.indexData.indexCount == 0))
        {
            // You're wasting my time sonny
            if (mCurrentUpdating)
            {
                // Can't just undo / remove since may be in the middle
                // Just allow counts to be 0, will not be issued to renderer
                
                // return the finished section (though it has zero vertices)
                result = mCurrentSection;
            }
            else
            {
                // First creation, can really undo
                // Has already been added to section list end, so remove
                mSectionList.popBack();
                destroy(mCurrentSection);
                
            }
        }
        else // not an empty section
        {
            
            // Bake the real buffers
            SharedPtr!HardwareVertexBuffer vbuf;
            // Check buffer sizes
            bool vbufNeedsCreating = true;
            bool ibufNeedsCreating = rop.useIndexes;
            // Work out if we require 16 or 32-bit index buffers
            HardwareIndexBuffer.IndexType indexType = mCurrentSection.get32BitIndices()?  
                HardwareIndexBuffer.IndexType.IT_32BIT : HardwareIndexBuffer.IndexType.IT_16BIT;
            if (mCurrentUpdating)
            {
                // May be able to reuse buffers, check sizes
                vbuf = rop.vertexData.vertexBufferBinding.getBuffer(0);
                if (vbuf.get().getNumVertices() >= rop.vertexData.vertexCount)
                    vbufNeedsCreating = false;
                
                if (rop.useIndexes)
                {
                    if ((rop.indexData.indexBuffer.get().getNumIndexes() >= rop.indexData.indexCount) &&
                        (indexType == rop.indexData.indexBuffer.get().getType()))
                        ibufNeedsCreating = false;
                }
                
            }
            if (vbufNeedsCreating)
            {
                // Make the vertex buffer larger if estimated vertex count higher
                // to allow for user-configured growth area
                size_t vertexCount = std.algorithm.max(rop.vertexData.vertexCount, 
                                              mEstVertexCount);
                vbuf =
                    HardwareBufferManager.getSingleton().createVertexBuffer(
                        mDeclSize,
                        vertexCount,
                        mDynamic? HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY : 
                        HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY);
                rop.vertexData.vertexBufferBinding.setBinding(0, vbuf);
            }
            if (ibufNeedsCreating)
            {
                // Make the index buffer larger if estimated index count higher
                // to allow for user-configured growth area
                size_t indexCount = std.algorithm.max(rop.indexData.indexCount, 
                                             mEstIndexCount);
                rop.indexData.indexBuffer =
                    HardwareBufferManager.getSingleton().createIndexBuffer(
                        indexType,
                        indexCount,
                        mDynamic? HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY : 
                        HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY);
            }
            // Write vertex data
            vbuf.get().writeData(
                0, rop.vertexData.vertexCount * vbuf.get().getVertexSize(), 
                mTempVertexBuffer.ptr, true);
            // Write index data
            if(rop.useIndexes)
            {
                if (HardwareIndexBuffer.IndexType.IT_32BIT == indexType)
                {
                    // direct copy from the mTempIndexBuffer
                    rop.indexData.indexBuffer.get().writeData(
                        0, 
                        rop.indexData.indexCount 
                        * rop.indexData.indexBuffer.get().getIndexSize(),
                        mTempIndexBuffer.ptr, true);
                }
                else //(HardwareIndexBuffer.IndexType.IT_16BIT == indexType)
                {
                    ushort* pIdx = cast(ushort*)(rop.indexData.indexBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
                    uint*   pSrc = mTempIndexBuffer.ptr;
                    for (size_t i = 0; i < rop.indexData.indexCount; i++)
                    {
                        *pIdx++ = cast(ushort)(*pSrc++);
                    }
                    rop.indexData.indexBuffer.get().unlock();
                    
                }
            }
            
            // return the finished section
            result = mCurrentSection;
            
        } // empty section check
        
        mCurrentSection = null;
        resetTempAreas();
        
        // Tell parent if present
        if (mParentNode)
        {
            mParentNode.needUpdate();
        }
        
        // will return the finished section or NULL if
        // the section was empty (i.e. zero vertices/indices)
        return result;
    }
    
    /** Alter the material for a subsection of this object after it has been
            specified.
        @remarks
            You specify the material to use on a section of this object during the
            call to begin(), however if you want to change the material afterwards
            you can do so by calling this method.
        @param subIndex The index of the subsection to alter
        @param name The name of the new material to use
        */
    void setMaterialName(size_t idx,string name,string group = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME)
    {
        if (idx >= mSectionList.length)
        {
            throw new InvalidParamsError(
                        "Index out of bounds!",
                        "ManualObject.setMaterialName");
        }
        
        mSectionList[idx].setMaterialName(name, group);
        
    }
    /** Convert this object to a Mesh. 
        @remarks
            After you've finished building this object, you may convert it to 
            a Mesh if you want in order to be able to create many instances of
            it in the world (via Entity). This is optional, since this instance
            can be directly attached to a SceneNode itself, but of course only
            one instance of it can exist that way. 
        @note Only objects which use indexed geometry may be converted to a mesh.
        @param meshName The name to give the mesh
        @param groupName The resource group to create the mesh in
        */
    SharedPtr!Mesh convertToMesh(string meshName, 
                                 string groupName = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME)
    {
        if (mCurrentSection)
        {
            throw new InvalidParamsError(
                        "You cannot call convertToMesh() whilst you are in the middle of "
                        "defining the object; call end() first.",
                        "ManualObject.convertToMesh");
        }
        if (mSectionList.empty())
        {
            throw new InvalidParamsError(
                        "No data defined to convert to a mesh.",
                        "ManualObject.convertToMesh");
        }
        SharedPtr!Mesh m = MeshManager.getSingleton().createManual(meshName, groupName);
        
        foreach (sec; mSectionList)
        {
            RenderOperation rop = sec.getRenderOperation();
            SubMesh sm = m.getAs().createSubMesh();
            sm.useSharedVertices = false;
            sm.operationType = rop.operationType;
            sm.setMaterialName(sec.getMaterialName(), groupName);
            // Copy vertex data; replicate buffers too
            sm.vertexData = rop.vertexData.clone(true);
            // Copy index data; replicate buffers too; delete the default, old one to avoid memory leaks
            
            // check if index data is present
            if (rop.indexData)
            {
                // Copy index data; replicate buffers too; delete the default, old one to avoid memory leaks
                destroy(sm.indexData);
                sm.indexData = rop.indexData.clone(true);
            }
        }
        // update bounds
        m.getAs()._setBounds(mAABB);
        m.getAs()._setBoundingSphereRadius(mRadius);
        
        m.get().load();
        
        return m;
        
        
    }
    
    /** Sets whether or not to use an 'identity' projection.
        @remarks
            Usually ManualObjects will use a projection matrix as determined
            by the active camera. However, if they want they can cancel this out
            and use an identity projection, which effectively projects in 2D using
            a {-1, 1} view space. Useful for overlay rendering. Normally you don't
            need to change this. The default is false.
        @see ManualObject.getUseIdentityProjection
        */
    void setUseIdentityProjection(bool useIdentityProjection)
    {
        // Set existing
        foreach (i; mSectionList)
        {
            i.setUseIdentityProjection(useIdentityProjection);
        }
        
        // Save setting for future sections
        mUseIdentityProjection = useIdentityProjection;
    }
    
    /** Returns whether or not to use an 'identity' projection.
        @remarks
            Usually ManualObjects will use a projection matrix as determined
            by the active camera. However, if they want they can cancel this out
            and use an identity projection, which effectively projects in 2D using
            a {-1, 1} view space. Useful for overlay rendering. Normally you don't
            need to change this.
        @see ManualObject.setUseIdentityProjection
        */
    bool getUseIdentityProjection(){ return mUseIdentityProjection; }
    
    /** Sets whether or not to use an 'identity' view.
        @remarks
            Usually ManualObjects will use a view matrix as determined
            by the active camera. However, if they want they can cancel this out
            and use an identity matrix, which means all geometry is assumed
            to be relative to camera space already. Useful for overlay rendering. 
            Normally you don't need to change this. The default is false.
        @see ManualObject.getUseIdentityView
        */
    void setUseIdentityView(bool useIdentityView)
    {
        // Set existing
        foreach (i; mSectionList)
        {
            i.setUseIdentityView(useIdentityView);
        }
        
        // Save setting for future sections
        mUseIdentityView = useIdentityView;
    }
    
    /** Returns whether or not to use an 'identity' view.
        @remarks
            Usually ManualObjects will use a view matrix as determined
            by the active camera. However, if they want they can cancel this out
            and use an identity matrix, which means all geometry is assumed
            to be relative to camera space already. Useful for overlay rendering. 
            Normally you don't need to change this.
        @see ManualObject.setUseIdentityView
        */
    bool getUseIdentityView(){ return mUseIdentityView; }
    
    /** Sets the bounding box.
            @remarks Call this after having finished creating sections to modify the
                bounding box. E.g. if you're using ManualObject to create 2D overlays
                you can call things function to set an infinite bounding box so that
                the object always stays visible when attached.
            @see ManualObject.setUseIdentityProjection, ManualObject.setUseIdentityView,
                AxisAlignedBox.setInfinite */
    void setBoundingBox(AxisAlignedBox box) { mAABB = box; }
    
    /** Gets a pointer to a ManualObjectSection, i.e. a part of a ManualObject.
        */
    ref ManualObjectSection getSection(uint index)
    {
        if (index >= mSectionList.length)
            throw new InvalidParamsError(
                        "Index out of bounds.",
                        "ManualObject.getSection");
        return mSectionList[index];
    }
    
    /** Retrieves the number of ManualObjectSection objects making up this ManualObject.
        */
    uint getNumSections()
    {
        return cast(uint)( mSectionList.length );
    }

    /** Sets whether or not to keep the original declaration order when 
            queuing the renderables.
        @remarks
            This overrides the default behavior of the rendering queue, 
            specifically stating the desired order of rendering. Might result in a 
            performance loss, but lets the user to have more direct control when 
            creating geometry through this class.
        @param keepOrder Whether to keep the declaration order or not.
        */
    void setKeepDeclarationOrder(bool keepOrder) { mKeepDeclarationOrder = keepOrder; }
    
    /** Gets whether or not the declaration order is to be kept or not.
        @return A flag indication if the declaration order will be kept when 
            queuing the renderables.
        */
    bool getKeepDeclarationOrder(){ return mKeepDeclarationOrder; }
    // MovableObject overrides
    
    /** @copydoc MovableObject.getMovableType. */
    override string getMovableType()
    {
        return ManualObjectFactory.FACTORY_TYPE_NAME;
    }
    /** @copydoc MovableObject.getBoundingBox. */
    override AxisAlignedBox getBoundingBox()
    {
        return mAABB;
    }

    /** @copydoc MovableObject.getBoundingRadius. */
    override Real getBoundingRadius()
    {
        return mRadius;
    }

    /** @copydoc MovableObject._updateRenderQueue. */
    override void _updateRenderQueue(RenderQueue queue)
    {
        // To be used when order of creation must be kept while rendering
        ushort priority = queue.getDefaultRenderablePriority();
        
        foreach (i; mSectionList)
        {
            // Skip empty sections (only happens if non-empty first, then updated)
            RenderOperation rop = i.getRenderOperation();
            if (rop.vertexData.vertexCount == 0 ||
                (rop.useIndexes && rop.indexData.indexCount == 0))
                continue;
            
            if (mRenderQueuePrioritySet)
            {
                assert(mRenderQueueIDSet == true);
                queue.addRenderable(i, mRenderQueueID, mRenderQueuePriority);
            }
            else if (mRenderQueueIDSet)
                queue.addRenderable(i, mRenderQueueID, mKeepDeclarationOrder ? priority++ : queue.getDefaultRenderablePriority());
            else
                queue.addRenderable(i, queue.getDefaultQueueGroup(), mKeepDeclarationOrder ? priority++ : queue.getDefaultRenderablePriority());
        }
    }

    /** Implement this method to enable stencil shadows. */
    override EdgeData getEdgeList()
    {
        // Build on demand
        if (!mEdgeList && mAnyIndexed)
        {
            EdgeListBuilder eb;
            size_t vertexSet = 0;
            bool anyBuilt = false;
            foreach (i; mSectionList)
            {
                RenderOperation rop = i.getRenderOperation();
                // Only indexed triangle geometry supported for stencil shadows
                if (rop.useIndexes && rop.indexData.indexCount != 0 && 
                    (rop.operationType == RenderOperation.OperationType.OT_TRIANGLE_FAN ||
                 rop.operationType == RenderOperation.OperationType.OT_TRIANGLE_LIST ||
                 rop.operationType == RenderOperation.OperationType.OT_TRIANGLE_STRIP))
                {
                    eb.addVertexData(rop.vertexData);
                    eb.addIndexData(rop.indexData, vertexSet++);
                    anyBuilt = true;
                }
            }
            
            if (anyBuilt)
                mEdgeList = eb.build();
            
        }
        return mEdgeList;
    }

    /** Overridden member from ShadowCaster. */
    override bool hasEdgeList()
    {
        return getEdgeList() !is null;
    }

    /** Implement this method to enable stencil shadows. */
    override ShadowRenderableList getShadowVolumeRenderables(
        ShadowTechnique shadowTechnique, ref Light light, 
        SharedPtr!HardwareIndexBuffer* indexBuffer, 
        bool extrude, Real extrusionDist, ulong flags = 0)
    {
        assert(indexBuffer, "Only external index buffers are supported right now");       
        
        EdgeData edgeList = getEdgeList();
        if (edgeList is null)
        {
            return mShadowRenderables;
        }
        
        // Calculate the object space light details
        Vector4 lightPos = light.getAs4DVector();
        Matrix4 world2Obj = mParentNode._getFullTransform().inverseAffine();
        lightPos = world2Obj.transformAffine(lightPos);
        Matrix3 world2Obj3x3;
        world2Obj.extract3x3Matrix(world2Obj3x3);
        extrusionDist *= Math.Sqrt(std.algorithm.min(std.algorithm.min(world2Obj3x3.GetColumn(0).squaredLength(), world2Obj3x3.GetColumn(1).squaredLength()), world2Obj3x3.GetColumn(2).squaredLength()));
        
        // Init shadow renderable list if required (only allow indexed)
        bool init = mShadowRenderables.empty() && mAnyIndexed;

        if (init) //TODO std::vector.resize
            mShadowRenderables.length = edgeList.edgeGroups.length;

        //What they were before, if you wonder wtf is going on here
        //EdgeData::EdgeGroupList::iterator egi;
        //ShadowRenderableList::iterator si, siend;
        //SectionList::iterator seci;
        //siend = mShadowRenderables.end();
        //egi = edgeList.edgeGroups.begin();
        //seci = mSectionList.begin();

        ManualObjectSectionShadowRenderable esr;

        //for (si = mShadowRenderables.begin(); si != siend; ++seci)
        for(size_t si = 0; si < mShadowRenderables.length; si++)
        {
            auto sec = mSectionList[si];
            auto sr = mShadowRenderables[si];
            auto eg = edgeList.edgeGroups[si];

            // Skip non-indexed geometry
            if (!sec.getRenderOperation().useIndexes)
            {
                continue;
            }
            
            if (init)
            {
                // Create a new renderable, create a separate light cap if
                // we're using a vertex program (either for this model, or
                // for extruding the shadow volume) since otherwise we can
                // get depth-fighting on the light cap
                SharedPtr!Material mat = sec.getMaterial();
                mat.get().load();
                bool vertexProgram = false;
                Technique t = mat.getAs().getBestTechnique(0, sec);
                for (ushort p = 0; p < t.getNumPasses(); ++p)
                {
                    Pass pass = t.getPass(p);
                    if (pass.hasVertexProgram())
                    {
                        vertexProgram = true;
                        break;
                    }
                }
                mShadowRenderables[si] = new ManualObjectSectionShadowRenderable(this, *indexBuffer,
                                                                   eg.vertexData, vertexProgram || !extrude);
            }
            // Get shadow renderable
            esr = cast(ManualObjectSectionShadowRenderable)mShadowRenderables[si];
            SharedPtr!HardwareVertexBuffer esrPositionBuffer = esr.getPositionBuffer();
            // Extrude vertices in software if required
            if (extrude)
            {
                extrudeVertices(esrPositionBuffer,
                                eg.vertexData.vertexCount,
                                lightPos, extrusionDist);
                
            }
            
            //++si;
            //++egi;
        }
        // Calc triangle light facing
        updateEdgeListLightFacing(edgeList, lightPos);
        
        // Generate indexes and update renderables
        generateShadowVolume(edgeList, indexBuffer, light,
                             mShadowRenderables, flags);
        
        
        //return ShadowRenderableListIterator(
            //mShadowRenderables.begin(), mShadowRenderables.end());
        return mShadowRenderables;
        
    }
    
    
    /// Built, renderable section of geometry
    class ManualObjectSection : Renderable //, public MovableAlloc
    {
        mixin Renderable.Renderable_Impl!();
        mixin Renderable.Renderable_Any_Impl;
    protected:
        ManualObject mParent;
        string mMaterialName;
        string mGroupName;
        //mutable 
        SharedPtr!Material mMaterial;
        RenderOperation mRenderOperation;
        bool m32BitIndices;
        
        
    public:
        this(ref ManualObject parent,string materialName,
                            RenderOperation.OperationType opType,string groupName = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME)
        {
            mParent = parent;
            mMaterialName = materialName;
            mGroupName = groupName;
            m32BitIndices = false;

            mRenderOperation.operationType = opType;
            // default to no indexes unless we're told
            mRenderOperation.useIndexes = false;
            mRenderOperation.useGlobalInstancingVertexBufferIsAvailable = false;
            mRenderOperation.vertexData = new VertexData();
            mRenderOperation.vertexData.vertexCount = 0;
            
        }

        ~this()
        {
            destroy(mRenderOperation.vertexData);
            destroy(mRenderOperation.indexData); // ok to delete 0 (?)
        }
        
        /// Retrieve render operation for manipulation
        ref RenderOperation getRenderOperation()
        {
            return mRenderOperation;
        }

        /// Retrieve the material name in use
       string getMaterialName(){ return mMaterialName; }
        /// Retrieve the material group in use
       string getMaterialGroup(){ return mGroupName; }
        /// update the material name in use
        void setMaterialName(string name,string groupName = ResourceGroupManager.AUTODETECT_RESOURCE_GROUP_NAME )
        {
            if (mMaterialName != name || mGroupName != groupName)
            {
                mMaterialName = name;
                mGroupName = groupName;
                mMaterial.setNull();
            }
        }
        /// Set whether we need 32-bit indices
        void set32BitIndices(bool n32) { m32BitIndices = n32; }
        /// Get whether we need 32-bit indices
        bool get32BitIndices(){ return m32BitIndices; }
        
        // Renderable overrides
        /** @copydoc Renderable.getMaterial. */
        override SharedPtr!Material getMaterial()
        {
            if (mMaterial.isNull())
            {
                // Load from default group. If user wants to use alternate groups,
                // they can define it and preload
                mMaterial = MaterialManager.getSingleton().load(mMaterialName, mGroupName);
            }
            return mMaterial;
        }
        /** @copydoc Renderable.getRenderOperation. */
        void getRenderOperation(ref RenderOperation op)
        {
            // direct copy
            op = mRenderOperation;
        }
        /** @copydoc Renderable.getWorldTransforms. */
        void getWorldTransforms(ref Matrix4[] xform)
        {
            xform.insertOrReplace(mParent._getParentNodeFullTransform());
        }
        /** @copydoc Renderable.getSquaredViewDepth. */
        Real getSquaredViewDepth(Camera cam)
        {
            Node n = mParent.getParentNode();
            assert(n);
            return n.getSquaredViewDepth(cam);
        }
        /** @copydoc Renderable.getLights. */
        LightList getLights()
        {
            return mParent.queryLights();
        }

    }

    /** Nested class to allow shadows. */
    class ManualObjectSectionShadowRenderable : ShadowRenderable
    {
    protected:
        ManualObject mParent;
        // Shared link to position buffer
        SharedPtr!HardwareVertexBuffer mPositionBuffer;
        // Shared link to w-coord buffer (optional)
        SharedPtr!HardwareVertexBuffer mWBuffer;
        
    public:
        this(ref ManualObject parent, 
            SharedPtr!HardwareIndexBuffer indexBuffer, ref VertexData vertexData, 
            bool createSeparateLightCap, bool isLightCap = false)
        {
            mParent = parent;

            // Initialise render op
            mRenderOp.indexData = new IndexData();
            mRenderOp.indexData.indexBuffer = indexBuffer;
            mRenderOp.indexData.indexStart = 0;
            // index start and count are sorted out later
            
            // Create vertex data which just references position component (and 2 component)
            mRenderOp.vertexData = new VertexData();
            // Map in position data
            mRenderOp.vertexData.vertexDeclaration.addElement(0,0,VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_POSITION);
            ushort origPosBind =
                vertexData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION).getSource();
            mPositionBuffer = vertexData.vertexBufferBinding.getBuffer(origPosBind);
            mRenderOp.vertexData.vertexBufferBinding.setBinding(0, mPositionBuffer);
            // Map in w-coord buffer (if present)
            if(!vertexData.hardwareShadowVolWBuffer.isNull())
            {
                mRenderOp.vertexData.vertexDeclaration.addElement(1,0,VertexElementType.VET_FLOAT1, VertexElementSemantic.VES_TEXTURE_COORDINATES, 0);
                mWBuffer = vertexData.hardwareShadowVolWBuffer;
                mRenderOp.vertexData.vertexBufferBinding.setBinding(1, mWBuffer);
            }
            // Use same vertex start as input
            mRenderOp.vertexData.vertexStart = vertexData.vertexStart;
            
            if (isLightCap)
            {
                // Use original vertex count, no extrusion
                mRenderOp.vertexData.vertexCount = vertexData.vertexCount;
            }
            else
            {
                // Vertex count must take into account the doubling of the buffer,
                // because second half of the buffer is the extruded copy
                mRenderOp.vertexData.vertexCount =
                    vertexData.vertexCount * 2;
                if (createSeparateLightCap)
                {
                    // Create child light cap
                    mLightCap = new ManualObjectSectionShadowRenderable(parent,
                                                         indexBuffer, vertexData, false, true);
                }
            }
        }

        ~this()
        {
            destroy(mRenderOp.indexData);
            destroy(mRenderOp.vertexData);
        }

        /// Overridden from ShadowRenderable
        override void getWorldTransforms(ref Matrix4[] xform)
        {
            // pretransformed
            xform.insertOrReplace(mParent._getParentNodeFullTransform());
        }

        SharedPtr!HardwareVertexBuffer getPositionBuffer() { return mPositionBuffer; }
        SharedPtr!HardwareVertexBuffer getWBuffer() { return mWBuffer; }
        /// Overridden from ShadowRenderable
        override void rebindIndexBuffer(SharedPtr!HardwareIndexBuffer* indexBuffer)
        {
            mRenderOp.indexData.indexBuffer = *indexBuffer;
            if (mLightCap) mLightCap.rebindIndexBuffer(indexBuffer);
        }
    }
    
    //typedef vector<ManualObjectSection*>::type SectionList;
    alias ManualObjectSection[] SectionList;
    
    /// @copydoc MovableObject.visitRenderables
    override void visitRenderables(Renderable.Visitor visitor, 
                          bool debugRenderables = false)
    {
        foreach (i; mSectionList)
        {
            visitor.visit(i, 0, false);
        }
    }
    
    
protected:
    /// Dynamic?
    bool mDynamic;
    /// List of subsections
    SectionList mSectionList;
    /// Current section
    ManualObjectSection mCurrentSection;
    /// Are we updating?
    bool mCurrentUpdating;
    /// Temporary vertex structure
    struct TempVertex
    {
        Vector3 position;
        Vector3 normal;
        Vector3 tangent;
        Vector4[OGRE_MAX_TEXTURE_COORD_SETS] texCoord;
        ushort[OGRE_MAX_TEXTURE_COORD_SETS] texCoordDims;
        ColourValue colour;
    }

    /// Temp storage
    TempVertex mTempVertex;
    /// First vertex indicator
    bool mFirstVertex;
    /// Temp vertex data to copy?
    bool mTempVertexPending;
    /// System-memory buffer whilst we establish the size required
    ubyte[] mTempVertexBuffer;
    /// System memory allocation size, in bytes
    size_t mTempVertexSize;
    /// System-memory buffer whilst we establish the size required
    uint[] mTempIndexBuffer;
    /// System memory allocation size, in bytes
    size_t mTempIndexSize;
    /// Current declaration vertex size
    size_t mDeclSize;
    /// Estimated vertex count
    size_t mEstVertexCount;
    /// Estimated index count
    size_t mEstIndexCount;
    /// Current texture coordinate
    ushort mTexCoordIndex;
    /// Bounding box
    AxisAlignedBox mAABB;
    /// Bounding sphere
    Real mRadius;
    /// Any indexed geometry on any sections?
    bool mAnyIndexed;
    /// Edge list, used if stencil shadow casting is enabled 
    EdgeData mEdgeList;
    /// List of shadow renderables
    ShadowRenderableList mShadowRenderables;
    /// Whether to use identity projection for sections
    bool mUseIdentityProjection;
    /// Whether to use identity view for sections
    bool mUseIdentityView;
    /// Keep declaration order or let the queue optimize it
    bool mKeepDeclarationOrder;
    
    
    /// Delete temp buffers and reset init counts
    void resetTempAreas()
    {
        destroy(mTempVertexBuffer);
        destroy(mTempIndexBuffer);
        //mTempVertexBuffer = null;
        //mTempIndexBuffer = null;
        mTempVertexSize = TEMP_INITIAL_VERTEX_SIZE;
        mTempIndexSize = TEMP_INITIAL_INDEX_SIZE;
    }
    /// Resize the temp vertex buffer?
    void resizeTempVertexBufferIfNeeded(size_t numVerts)
    {
        // Calculate byte size
        // Use decl if we know it by now, otherwise default size to pos/norm/texcoord*2
        size_t newSize;
        if (!mFirstVertex)
        {
            newSize = mDeclSize * numVerts;
        }
        else
        {
            // estimate - size checks will deal for subsequent verts
            newSize = TEMP_VERTEXSIZE_GUESS * numVerts;
        }
        if (newSize > mTempVertexSize || !mTempVertexBuffer)
        {
            if (!mTempVertexBuffer)
            {
                // init
                newSize = mTempVertexSize;
            }
            else
            {
                // increase to at least double current
                newSize = std.algorithm.max(newSize, mTempVertexSize*2);
            }
            // copy old data
            ubyte[] tmp = mTempVertexBuffer;
            mTempVertexBuffer = new ubyte[newSize];
            if (tmp)
            {
                memcpy(mTempVertexBuffer.ptr, tmp.ptr, mTempVertexSize);
                // delete old buffer
                destroy(tmp);
            }
            mTempVertexSize = newSize;
        }
    }
    /// Resize the temp index buffer?
    void resizeTempIndexBufferIfNeeded(size_t numInds)
    {
        size_t newSize = numInds * uint.sizeof;
        if (newSize > mTempIndexSize || !mTempIndexBuffer)
        {
            if (!mTempIndexBuffer)
            {
                // init
                newSize = mTempIndexSize;
            }
            else
            {
                // increase to at least double current
                newSize = std.algorithm.max(newSize, mTempIndexSize*2);
            }
            numInds = newSize / uint.sizeof;
            uint[] tmp = mTempIndexBuffer;
            mTempIndexBuffer = new uint[numInds];
            if (tmp)
            {
                memcpy(mTempIndexBuffer.ptr, tmp.ptr, mTempIndexSize);
                destroy(tmp);
            }
            mTempIndexSize = newSize;
        }
        
    }
    
    /// Copy current temp vertex into buffer
    void copyTempVertexToBuffer()
    {
        mTempVertexPending = false;
        RenderOperation rop = mCurrentSection.getRenderOperation();
        if (rop.vertexData.vertexCount == 0 && !mCurrentUpdating)
        {
            // first vertex, autoorganise decl
            VertexDeclaration oldDcl = rop.vertexData.vertexDeclaration;
            rop.vertexData.vertexDeclaration =
                oldDcl.getAutoOrganisedDeclaration(false, false, false);
            HardwareBufferManager.getSingleton().destroyVertexDeclaration(oldDcl);
        }
        resizeTempVertexBufferIfNeeded(++rop.vertexData.vertexCount);
        
        // get base pointer
        ubyte* pBase = mTempVertexBuffer.ptr + (mDeclSize * (rop.vertexData.vertexCount-1));
       VertexDeclaration.VertexElementList elemList =
            rop.vertexData.vertexDeclaration.getElements();

        foreach (elem; elemList)
        {
            float* pFloat = null;
            RGBA* pRGBA = null;
            switch(elem.getType())
            {
                case VertexElementType.VET_FLOAT1:
                case VertexElementType.VET_FLOAT2:
                case VertexElementType.VET_FLOAT3:
                case VertexElementType.VET_FLOAT4:
                    elem.baseVertexPointerToElement(pBase, &pFloat);
                    break;
                case VertexElementType.VET_COLOUR:
                case VertexElementType.VET_COLOUR_ABGR:
                case VertexElementType.VET_COLOUR_ARGB:
                    elem.baseVertexPointerToElement(pBase, &pRGBA);
                    break;
                default:
                    // nop ?
                    break;
            }
            
            
            RenderSystem rs;
            ushort dims;
            switch(elem.getSemantic())
            {
                case VertexElementSemantic.VES_POSITION:
                    *pFloat++ = mTempVertex.position.x;
                    *pFloat++ = mTempVertex.position.y;
                    *pFloat++ = mTempVertex.position.z;
                    break;
                case VertexElementSemantic.VES_NORMAL:
                    *pFloat++ = mTempVertex.normal.x;
                    *pFloat++ = mTempVertex.normal.y;
                    *pFloat++ = mTempVertex.normal.z;
                    break;
                case VertexElementSemantic.VES_TANGENT:
                    *pFloat++ = mTempVertex.tangent.x;
                    *pFloat++ = mTempVertex.tangent.y;
                    *pFloat++ = mTempVertex.tangent.z;
                    break;
                case VertexElementSemantic.VES_TEXTURE_COORDINATES:
                    dims = VertexElement.getTypeCount(elem.getType());
                    for (ushort t = 0; t < dims; ++t)
                        *pFloat++ = mTempVertex.texCoord[elem.getIndex()][t];
                    break;
                case VertexElementSemantic.VES_DIFFUSE:
                    rs = Root.getSingleton().getRenderSystem();
                    if (rs)
                    {
                        rs.convertColourValue(mTempVertex.colour, pRGBA++);
                    }
                    else
                    {
                        switch(elem.getType())
                        {
                            case VertexElementType.VET_COLOUR_ABGR:
                                *pRGBA++ = mTempVertex.colour.getAsABGR();
                                break;
                            case VertexElementType.VET_COLOUR_ARGB:
                                *pRGBA++ = mTempVertex.colour.getAsARGB();
                                break;
                            default:
                                *pRGBA++ = mTempVertex.colour.getAsRGBA();
                        }
                    }
                    
                default:
                    // nop ?
                    break;
            }
            
        }
        
    }
    
}


/** Factory object for creating ManualObject instances */
class ManualObjectFactory : MovableObjectFactory
{
protected:
    override MovableObject createInstanceImpl(string name, NameValuePairList params)
    {
        return new ManualObject(name);
    }
public:
    this() {}
    ~this() {}
    
    immutable static string FACTORY_TYPE_NAME = "ManualObject";
    
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