module ogre.scene.wireboundingbox;

import ogre.compat;
import ogre.math.maths;
import ogre.math.vector;
import ogre.math.axisalignedbox;
import ogre.math.matrix;
import ogre.rendersystem.vertex;
import ogre.rendersystem.hardware;
import ogre.scene.simplerenderable;
import ogre.scene.camera;
import ogre.rendersystem.renderoperation;

//import ogre.scene;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Scene
    *  @{
    */

/** Allows the rendering of a wiref rame bounding box.
        @remarks
            This class builds a wiref rame renderable from a given aabb. A pointer to this class can be
            added to a render queue to display the bounding box of an object.
    */
class WireBoundingBox : SimpleRenderable
{
    //mixin Renderable.Renderable_Any_Impl;
protected:
    enum POSITION_BINDING = 0;
    
    /** Override this method to prevent parent transforms (rotation,translation,scale)
        */
    override void getWorldTransforms( ref Matrix4[] xform )
    {
        // return identity matrix to prevent parent transforms
        xform.insertOrReplace(cast(Matrix4)Matrix4.IDENTITY);
    }
    
    /** Builds the wiref rame line list.
        */
    void setupBoundingBoxVertices(AxisAlignedBox aab)
    {
        
        Vector3 vmax = aab.getMaximum();
        Vector3 vmin = aab.getMinimum();
        
        Real sqLen = std.algorithm.max(vmax.squaredLength(), vmin.squaredLength());
        mRadius = Math.Sqrt(sqLen);
        
        
        
        
        Real maxx = vmax.x;
        Real maxy = vmax.y;
        Real maxz = vmax.z;
        
        Real minx = vmin.x;
        Real miny = vmin.y;
        Real minz = vmin.z;
        
        // fill in the Vertex buffer: 12 lines with 2 endpoints each make up a box
        SharedPtr!HardwareVertexBuffer vbuf =
            mRenderOp.vertexData.vertexBufferBinding.getBuffer(POSITION_BINDING);
        
        float* pPos = cast(float*)vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD);
        
        // line 0
        *pPos++ = minx;
        *pPos++ = miny;
        *pPos++ = minz;
        *pPos++ = maxx;
        *pPos++ = miny;
        *pPos++ = minz;
        // line 1
        *pPos++ = minx;
        *pPos++ = miny;
        *pPos++ = minz;
        *pPos++ = minx;
        *pPos++ = miny;
        *pPos++ = maxz;
        // line 2
        *pPos++ = minx;
        *pPos++ = miny;
        *pPos++ = minz;
        *pPos++ = minx;
        *pPos++ = maxy;
        *pPos++ = minz;
        // line 3
        *pPos++ = minx;
        *pPos++ = maxy;
        *pPos++ = minz;
        *pPos++ = minx;
        *pPos++ = maxy;
        *pPos++ = maxz;
        // line 4
        *pPos++ = minx;
        *pPos++ = maxy;
        *pPos++ = minz;
        *pPos++ = maxx;
        *pPos++ = maxy;
        *pPos++ = minz;
        // line 5
        *pPos++ = maxx;
        *pPos++ = miny;
        *pPos++ = minz;
        *pPos++ = maxx;
        *pPos++ = miny;
        *pPos++ = maxz;
        // line 6
        *pPos++ = maxx;
        *pPos++ = miny;
        *pPos++ = minz;
        *pPos++ = maxx;
        *pPos++ = maxy;
        *pPos++ = minz;
        // line 7
        *pPos++ = minx;
        *pPos++ = maxy;
        *pPos++ = maxz;
        *pPos++ = maxx;
        *pPos++ = maxy;
        *pPos++ = maxz;
        // line 8
        *pPos++ = minx;
        *pPos++ = maxy;
        *pPos++ = maxz;
        *pPos++ = minx;
        *pPos++ = miny;
        *pPos++ = maxz;
        // line 9
        *pPos++ = maxx;
        *pPos++ = maxy;
        *pPos++ = minz;
        *pPos++ = maxx;
        *pPos++ = maxy;
        *pPos++ = maxz;
        // line 10
        *pPos++ = maxx;
        *pPos++ = miny;
        *pPos++ = maxz;
        *pPos++ = maxx;
        *pPos++ = maxy;
        *pPos++ = maxz;
        // line 11
        *pPos++ = minx;
        *pPos++ = miny;
        *pPos++ = maxz;
        *pPos++ = maxx;
        *pPos++ = miny;
        *pPos++ = maxz;
        vbuf.get().unlock();
    }
    
    Real mRadius;
    
    void _initWireBoundingBox()
    {
        mRenderOp.vertexData = new VertexData();
        
        mRenderOp.indexData = null;
        mRenderOp.vertexData.vertexCount = 24; 
        mRenderOp.vertexData.vertexStart = 0; 
        mRenderOp.operationType = RenderOperation.OperationType.OT_LINE_LIST; 
        mRenderOp.useIndexes = false; 
        mRenderOp.useGlobalInstancingVertexBufferIsAvailable = false;
        
        VertexDeclaration decl = mRenderOp.vertexData.vertexDeclaration;
        VertexBufferBinding bind = mRenderOp.vertexData.vertexBufferBinding;
        
        decl.addElement(POSITION_BINDING, 0, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_POSITION);
        
        
        SharedPtr!HardwareVertexBuffer vbuf = 
            HardwareBufferManager.getSingleton().createVertexBuffer(
                decl.getVertexSize(POSITION_BINDING),
                mRenderOp.vertexData.vertexCount,
                HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY);
        
        // Bind buffer
        bind.setBinding(POSITION_BINDING, vbuf);
        
        // set basic white material
        this.setMaterial("BaseWhiteNoLighting");
        
        
        
    }
    
public:
    
    this()
    {
        _initWireBoundingBox();
    }
    
    this(string name)
    {
        super(name);
        _initWireBoundingBox();
    }
    
    ~this()
    {
        destroy(mRenderOp.vertexData);
    }
    
    /** Builds the wiref rame line list.
            @param
                aabb bounding box to build a wiref rame from.
        */
    void setupBoundingBox(AxisAlignedBox aabb)
    {
        // init the vertices to the aabb
        setupBoundingBoxVertices(aabb);
        
        // setup the bounding box of this SimpleRenderable
        setBoundingBox(aabb);
        
    }
    
    Real getSquaredViewDepth(Camera cam)
    {
        Vector3 min, max, mid, dist;
        min = mBox.getMinimum();
        max = mBox.getMaximum();
        mid = ((max - min) * 0.5) + min;
        dist = cam.getDerivedPosition() - mid;
        
        
        return dist.squaredLength();
    }
    
    override Real getBoundingRadius(){ return mRadius; }
    
}
/** @} */
/** @} */