module ogre.scene.rectangle2d;

import ogre.math.matrix;
import ogre.rendersystem.hardware;
import ogre.compat;
import ogre.rendersystem.vertex;
import ogre.scene.simplerenderable;
import ogre.math.vector;
import ogre.scene.camera;
import ogre.rendersystem.renderoperation;

/** Allows the rendering of a simple 2D rectangle
    This class renders a simple 2D rectangle; this rectangle has no depth and
    Therefore is best used with specific render queue and depth settings,
    like RENDER_QUEUE_BACKGROUND and 'depth_write off' for backdrops, and 
    RENDER_QUEUE_OVERLAY and 'depth_check off' for fullscreen quads.
    */
class Rectangle2D : SimpleRenderable
{
protected:
    enum 
    {   
        POSITION_BINDING = 0,
        NORMAL_BINDING = 1,
        TEXCOORD_BINDING = 2,
    }
    
    /** Override this method to prevent parent transforms (rotation,translation,scale)
        */
    override void getWorldTransforms( ref Matrix4[] xform )
    {
        // return identity matrix to prevent parent transforms
        //TODO immutable to mutable
        xform.insertOrReplace(cast(Matrix4)Matrix4.IDENTITY);
    }
    
    void _initRectangle2D(bool includeTextureCoords, HardwareBuffer.Usage vBufUsage)
    {
        // use identity projection and view matrices
        mUseIdentityProjection = true;
        mUseIdentityView = true;
        
        mRenderOp.vertexData = new VertexData();
        
        mRenderOp.indexData = null;
        mRenderOp.vertexData.vertexCount = 4; 
        mRenderOp.vertexData.vertexStart = 0; 
        mRenderOp.operationType = RenderOperation.OperationType.OT_TRIANGLE_STRIP; 
        mRenderOp.useIndexes = false; 
        mRenderOp.useGlobalInstancingVertexBufferIsAvailable = false;
        
        VertexDeclaration decl = mRenderOp.vertexData.vertexDeclaration;
        VertexBufferBinding bind = mRenderOp.vertexData.vertexBufferBinding;
        
        decl.addElement(POSITION_BINDING, 0, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_POSITION);
        
        
        SharedPtr!HardwareVertexBuffer vbuf = 
            HardwareBufferManager.getSingleton().createVertexBuffer(
                decl.getVertexSize(POSITION_BINDING),
                mRenderOp.vertexData.vertexCount,
                vBufUsage);
        
        // Bind buffer
        bind.setBinding(POSITION_BINDING, vbuf);
        
        decl.addElement(NORMAL_BINDING, 0, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_NORMAL);
        
        vbuf = 
            HardwareBufferManager.getSingleton().createVertexBuffer(
                decl.getVertexSize(NORMAL_BINDING),
                mRenderOp.vertexData.vertexCount,
                vBufUsage);
        
        bind.setBinding(NORMAL_BINDING, vbuf);
        
        float *pNorm = cast(float*)(vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
        *pNorm++ = 0.0f;
        *pNorm++ = 0.0f;
        *pNorm++ = 1.0f;
        
        *pNorm++ = 0.0f;
        *pNorm++ = 0.0f;
        *pNorm++ = 1.0f;
        
        *pNorm++ = 0.0f;
        *pNorm++ = 0.0f;
        *pNorm++ = 1.0f;
        
        *pNorm++ = 0.0f;
        *pNorm++ = 0.0f;
        *pNorm++ = 1.0f;
        
        vbuf.get().unlock();
        
        if (includeTextureCoords)
        {
            decl.addElement(TEXCOORD_BINDING, 0, VertexElementType.VET_FLOAT2, VertexElementSemantic.VES_TEXTURE_COORDINATES);
            
            
            SharedPtr!HardwareVertexBuffer tvbuf = 
                HardwareBufferManager.getSingleton().createVertexBuffer(
                    decl.getVertexSize(TEXCOORD_BINDING),
                    mRenderOp.vertexData.vertexCount,
                    vBufUsage);
            
            // Bind buffer
            bind.setBinding(TEXCOORD_BINDING, tvbuf);
            
            // Set up basic tex coordinates
            setDefaultUVs();
        }
        
        // set basic white material
        this.setMaterial("BaseWhiteNoLighting");
    }
    
    
public:
    
    this(bool includeTextureCoords = false, HardwareBuffer.Usage vBufUsage = HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY)
    {
        _initRectangle2D(includeTextureCoords, vBufUsage);
    }
    
    this(string name, bool includeTextureCoords = false, HardwareBuffer.Usage vBufUsage = HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY)
    {
        super(name);
        _initRectangle2D(includeTextureCoords, vBufUsage);
    }
    
    ~this()
    {
        destroy(mRenderOp.vertexData);
    }
    
    /** Sets the corners of the rectangle, in relative coordinates.
        @param
        left Left position in screen relative coordinates, -1 = left edge, 1.0 = right edge
        @param top Top position in screen relative coordinates, 1 = top edge, -1 = bottom edge
        @param right Right position in screen relative coordinates
        @param bottom Bottom position in screen relative coordinates
        @param updateAABB Tells if you want to recalculate the AABB according to 
        the new corners. If false, the axis aligned bounding box will remain identical.
        */
    void setCorners(Real left, Real top, Real right, Real bottom, bool updateAABB = true)
    {
        SharedPtr!HardwareVertexBuffer vbuf = 
            mRenderOp.vertexData.vertexBufferBinding.getBuffer(POSITION_BINDING);
        float* pFloat = cast(float*)(vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
        
        *pFloat++ = left;
        *pFloat++ = top;
        *pFloat++ = -1;
        
        *pFloat++ = left;
        *pFloat++ = bottom;
        *pFloat++ = -1;
        
        *pFloat++ = right;
        *pFloat++ = top;
        *pFloat++ = -1;
        
        *pFloat++ = right;
        *pFloat++ = bottom;
        *pFloat++ = -1;
        
        vbuf.get().unlock();
        
        if(updateAABB)
        {
            mBox.setExtents(
                std.algorithm.min(left, right), std.algorithm.min(top, bottom), 0,
                std.algorithm.max(left, right), std.algorithm.max(top, bottom), 0);
        }
    }
    
    /** Sets the normals of the rectangle
        */
    void setNormals(Vector3 topLeft, Vector3 bottomLeft, Vector3 topRight, Vector3 bottomRight)
    {
        SharedPtr!HardwareVertexBuffer vbuf = 
            mRenderOp.vertexData.vertexBufferBinding.getBuffer(NORMAL_BINDING);
        float* pFloat = cast(float*)(vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
        
        *pFloat++ = topLeft.x;
        *pFloat++ = topLeft.y;
        *pFloat++ = topLeft.z;
        
        *pFloat++ = bottomLeft.x;
        *pFloat++ = bottomLeft.y;
        *pFloat++ = bottomLeft.z;
        
        *pFloat++ = topRight.x;
        *pFloat++ = topRight.y;
        *pFloat++ = topRight.z;
        
        *pFloat++ = bottomRight.x;
        *pFloat++ = bottomRight.y;
        *pFloat++ = bottomRight.z;
        
        vbuf.get().unlock();
    }
    
    /** Sets the UVs of the rectangle
        @remarks
        Doesn't do anything if the rectangle wasn't built with texture coordinates
        */
    void setUVs(Vector2 topLeft, Vector2 bottomLeft,
                Vector2 topRight, Vector2 bottomRight)
    {
        if( mRenderOp.vertexData.vertexDeclaration.getElementCount() <= TEXCOORD_BINDING )
            return; //Vertex data wasn't built with UV buffer
        
        SharedPtr!HardwareVertexBuffer vbuf = 
            mRenderOp.vertexData.vertexBufferBinding.getBuffer(TEXCOORD_BINDING);
        float* pFloat = cast(float*)(vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
        
        *pFloat++ = topLeft.x;
        *pFloat++ = topLeft.y;
        
        *pFloat++ = bottomLeft.x;
        *pFloat++ = bottomLeft.y;
        
        *pFloat++ = topRight.x;
        *pFloat++ = topRight.y;
        
        *pFloat++ = bottomRight.x;
        *pFloat++ = bottomRight.y;
        
        vbuf.get().unlock();
    }
    
    void setDefaultUVs()
    {
        setUVs( Vector2.ZERO, Vector2.UNIT_Y, Vector2.UNIT_X, Vector2.UNIT_SCALE );
    }
    
    Real getSquaredViewDepth(Camera cam)
    { return 0; }
    
    override Real getBoundingRadius(){ return 0; }
    
}
