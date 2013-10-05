module ogre.math.frustum;

import ogre.math.axisalignedbox;
import ogre.compat;
import ogre.config;
import ogre.math.maths;
import ogre.math.angles;
import ogre.math.matrix;
import ogre.math.vector;
import ogre.math.quaternion;
import ogre.math.plane;
import ogre.math.sphere;
import ogre.general.common;
import ogre.general.root;
import ogre.rendersystem.vertex;
import ogre.scene.movableobject;
import ogre.scene.renderable;
import ogre.scene.movableplane;
import ogre.rendersystem.renderqueue;
import ogre.rendersystem.hardware;
import ogre.materials.materialmanager;
import ogre.sharedptr;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Math
 *  @{
 */
/** Specifies orientation mode.
 */
enum OrientationMode
{
    OR_DEGREE_0       = 0,
    OR_DEGREE_90      = 1,
    OR_DEGREE_180     = 2,
    OR_DEGREE_270     = 3,
    
    OR_PORTRAIT       = OR_DEGREE_0,
    OR_LANDSCAPERIGHT = OR_DEGREE_90,
    OR_LANDSCAPELEFT  = OR_DEGREE_270
}

/** Specifies perspective (realistic) or orthographic (architectural) projection.
 */
enum ProjectionType
{
    PT_ORTHOGRAPHIC,
    PT_PERSPECTIVE
}

/** Worldspace clipping planes.
 */
enum FrustumPlane
{
    FRUSTUM_PLANE_NEAR   = 0,
    FRUSTUM_PLANE_FAR    = 1,
    FRUSTUM_PLANE_LEFT   = 2,
    FRUSTUM_PLANE_RIGHT  = 3,
    FRUSTUM_PLANE_TOP    = 4,
    FRUSTUM_PLANE_BOTTOM = 5
}

/** A frustum represents a pyramid, capped at the near and far end which is
 used to represent either a visible area or a projection area. Can be used
 for a number of applications.
 */
class Frustum : MovableObject, Renderable
{
    mixin Renderable.Renderable_Impl!();
    //FIXME Little clashing with Renderable interface and MovableObject
    mixin Renderable.Renderable_Any_Impl;
    
protected:
    /// Orthographic or perspective?
    ProjectionType mProjType;
    
    /// y-direction field-of-view (default 45)
    Radian mFOVy;
    /// Far clip distance - default 10000
    Real mFarDist;
    /// Near clip distance - default 100
    Real mNearDist;
    /// x/y viewport ratio - default 1.3333
    Real mAspect;
    /// Ortho height size (world units)
    Real mOrthoHeight;
    /// Off-axis frustum center offset - default (0.0, 0.0)
    Vector2 mFrustumOffset;
    /// Focal length of frustum (for stereo rendering, defaults to 1.0)
    Real mFocalLength;
    
    /// The 6 main clipping planes
    //mutable 
    Plane[6] mFrustumPlanes;
    
    /// Stored versions of parent orientation / position
    //mutable 
    Quaternion mLastParentOrientation;
    //mutable 
    Vector3 mLastParentPosition;
    
    /// Pre-calced projection matrix for the specific render system
    //mutable 
    Matrix4 mProjMatrixRS;
    /// Pre-calced standard projection matrix but with render system depth range
    //mutable 
    Matrix4 mProjMatrixRSDepth;
    /// Pre-calced standard projection matrix
    //mutable 
    Matrix4 mProjMatrix;
    /// Pre-calced view matrix
    //mutable 
    Matrix4 mViewMatrix;
    /// Something's changed in the frustum shape?
    //mutable 
    bool mRecalcFrustum;
    /// Something re the view pos has changed
    //mutable 
    bool mRecalcView;
    /// Something re the frustum planes has changed
    //mutable 
    bool mRecalcFrustumPlanes;
    /// Something re the world space corners has changed
    //mutable 
    bool mRecalcWorldSpaceCorners;
    /// Something re the vertex data has changed
    //mutable 
    bool mRecalcVertexData;
    /// Are we using a custom view matrix?
    bool mCustomViewMatrix;
    /// Are we using a custom projection matrix?
    bool mCustomProjMatrix;
    /// Have the frustum extents been manually set?
    bool mFrustumExtentsManuallySet;
    /// Frustum extents
    //mutable 
    Real mLeft, mRight, mTop, mBottom;
    /// Frustum orientation mode
    //mutable 
    OrientationMode mOrientationMode;
    
    // Internal functions for calcs
    void calcProjectionParameters(ref Real left, ref Real right, ref Real bottom, ref Real top)
    { 
        if (mCustomProjMatrix)
        {
            // Convert clipspace corners to camera space
            Matrix4 invProj = mProjMatrix.inverse();
            auto topLeft = Vector3(-0.5f, 0.5f, 0.0f);
            auto bottomRight = Vector3(0.5f, -0.5f, 0.0f);
            
            topLeft = invProj * topLeft;
            bottomRight = invProj * bottomRight;
            
            left = topLeft.x;
            top = topLeft.y;
            right = bottomRight.x;
            bottom = bottomRight.y;
            
        }
        else
        {
            if (mFrustumExtentsManuallySet)
            {
                left = mLeft;
                right = mRight;
                top = mTop;
                bottom = mBottom;
            }
            // Calculate general projection parameters
            else if (mProjType == ProjectionType.PT_PERSPECTIVE)
            {
                Radian thetaY = mFOVy * 0.5f;
                Real tanThetaY = Math.Tan(thetaY);
                Real tanThetaX = tanThetaY * mAspect;
                
                Real nearFocal = mNearDist / mFocalLength;
                Real nearOffsetX = mFrustumOffset.x * nearFocal;
                Real nearOffsetY = mFrustumOffset.y * nearFocal;
                Real half_w = tanThetaX * mNearDist;
                Real half_h = tanThetaY * mNearDist;
                
                left   = - half_w + nearOffsetX;
                right  = + half_w + nearOffsetX;
                bottom = - half_h + nearOffsetY;
                top    = + half_h + nearOffsetY;
                
                mLeft = left;
                mRight = right;
                mTop = top;
                mBottom = bottom;
            }
            else
            {
                // Unknown how to apply frustum offset to orthographic camera, just ignore here
                Real half_w = getOrthoWindowWidth() * 0.5f;
                Real half_h = getOrthoWindowHeight() * 0.5f;
                
                left   = - half_w;
                right  = + half_w;
                bottom = - half_h;
                top    = + half_h;
                
                mLeft = left;
                mRight = right;
                mTop = top;
                mBottom = bottom;
            }
            
        }
    }
    /// Update frustum if out of date
    void updateFrustum()
    {
        if (isFrustumOutOfDate())
        {
            updateFrustumImpl();
        }
    }
    
    /// Update view if out of date
    void updateView()
    {
        if (isViewOutOfDate())
        {
            updateViewImpl();
        }
    }
    /// Implementation of updateFrustum (called if out of date)
    void updateFrustumImpl()
    {
        // Common calcs
        Real left, right, bottom, top;

        static if(OGRE_NO_VIEWPORT_ORIENTATIONMODE) 
        {
            calcProjectionParameters(left, right, bottom, top);
        }
        else
        {
            if (mOrientationMode != OrientationMode.OR_PORTRAIT)
                calcProjectionParameters(bottom, top, left, right);
            else
                calcProjectionParameters(left, right, bottom, top);
        }

        if (!mCustomProjMatrix)
        {
            
            // The code below will dealing with general projection 
            // parameters, similar glFrustum and glOrtho.
            // Doesn't optimise manually except division operator, so the 
            // code more self-explaining.
            
            Real inv_w = 1 / (right - left);
            Real inv_h = 1 / (top - bottom);
            Real inv_d = 1 / (mFarDist - mNearDist);
            
            // Recalc if frustum params changed
            if (mProjType == ProjectionType.PT_PERSPECTIVE)
            {
                // Calc matrix elements
                Real A = 2 * mNearDist * inv_w;
                Real B = 2 * mNearDist * inv_h;
                Real C = (right + left) * inv_w;
                Real D = (top + bottom) * inv_h;
                Real q, qn;
                if (mFarDist == 0)
                {
                    // Infinite far plane
                    q = Frustum.INFINITE_FAR_PLANE_ADJUST - 1;
                    qn = mNearDist * (Frustum.INFINITE_FAR_PLANE_ADJUST - 2);
                }
                else
                {
                    q = - (mFarDist + mNearDist) * inv_d;
                    qn = -2 * (mFarDist * mNearDist) * inv_d;
                }
                
                // NB: This creates 'uniform' perspective projection matrix,
                // which depth range [-1,1], right-handed rules
                //
                // [ A   0   C   0  ]
                // [ 0   B   D   0  ]
                // [ 0   0   q   qn ]
                // [ 0   0   -1  0  ]
                //
                // A = 2 * near / (right - left)
                // B = 2 * near / (top - bottom)
                // C = (right + left) / (right - left)
                // D = (top + bottom) / (top - bottom)
                // q = - (far + near) / (far - near)
                // qn = - 2 * (far * near) / (far - near)
                
                mProjMatrix = Matrix4.ZERO;
                mProjMatrix[0, 0] = A;
                mProjMatrix[0, 2] = C;
                mProjMatrix[1, 1] = B;
                mProjMatrix[1, 2] = D;
                mProjMatrix[2, 2] = q;
                mProjMatrix[2, 3] = qn;
                mProjMatrix[3, 2] = -1;
                
                if (mObliqueDepthProjection)
                {
                    // Translate the plane into view space
                    
                    // Don't use getViewMatrix here, incase overrided by 
                    // camera and return a cull frustum view matrix
                    updateView();
                    Plane plane = mViewMatrix * mObliqueProjPlane;
                    
                    // Thanks to Eric Lenyel for posting this calculation 
                    // at www.terathon.com
                    
                    // Calculate the clip-space corner point opposite the 
                    // clipping plane
                    // as (sgn(clipPlane.x), sgn(clipPlane.y), 1, 1) and
                    // transform it into camera space by multiplying it
                    // by the inverse of the projection matrix
                    
                    /* generalised version
                     Vector4 q = matrix.inverse() * 
                     Vector4(Math.Sign(plane.normal.x), 
                     Math.Sign(plane.normal.y), 1.0f, 1.0f);
                     */
                    Vector4 qVec;
                    qVec.x = (Math.Sign(plane.normal.x) + mProjMatrix[0, 2]) / mProjMatrix[0, 0];
                    qVec.y = (Math.Sign(plane.normal.y) + mProjMatrix[1, 2]) / mProjMatrix[1, 1];
                    qVec.z = -1;
                    qVec.w = (1 + mProjMatrix[2, 2]) / mProjMatrix[2, 3];
                    
                    // Calculate the scaled plane vector
                    auto clipPlane4d = Vector4(plane.normal.x, plane.normal.y, plane.normal.z, plane.d);
                    Vector4 c = clipPlane4d * (2 / (clipPlane4d.dotProduct(qVec)));
                    
                    // Replace the third row of the projection matrix
                    mProjMatrix[2, 0] = c.x;
                    mProjMatrix[2, 1] = c.y;
                    mProjMatrix[2, 2] = c.z + 1;
                    mProjMatrix[2, 3] = c.w; 
                }
            } // perspective
            else if (mProjType == ProjectionType.PT_ORTHOGRAPHIC)
            {
                Real A = 2 * inv_w;
                Real B = 2 * inv_h;
                Real C = - (right + left) * inv_w;
                Real D = - (top + bottom) * inv_h;
                Real q, qn;
                if (mFarDist == 0)
                {
                    // Can not do infinite far plane here, avoid divided zero only
                    q = - Frustum.INFINITE_FAR_PLANE_ADJUST / mNearDist;
                    qn = - Frustum.INFINITE_FAR_PLANE_ADJUST - 1;
                }
                else
                {
                    q = - 2 * inv_d;
                    qn = - (mFarDist + mNearDist)  * inv_d;
                }
                
                // NB: This creates 'uniform' orthographic projection matrix,
                // which depth range [-1,1], right-handed rules
                //
                // [ A   0   0   C  ]
                // [ 0   B   0   D  ]
                // [ 0   0   q   qn ]
                // [ 0   0   0   1  ]
                //
                // A = 2 * / (right - left)
                // B = 2 * / (top - bottom)
                // C = - (right + left) / (right - left)
                // D = - (top + bottom) / (top - bottom)
                // q = - 2 / (far - near)
                // qn = - (far + near) / (far - near)
                
                mProjMatrix = Matrix4.ZERO;
                mProjMatrix[0, 0] = A;
                mProjMatrix[0, 3] = C;
                mProjMatrix[1, 1] = B;
                mProjMatrix[1, 3] = D;
                mProjMatrix[2, 2] = q;
                mProjMatrix[2, 3] = qn;
                mProjMatrix[3, 3] = 1;
            } // ortho            
        } // !mCustomProjMatrix
        
        version (OGRE_NO_VIEWPORT_ORIENTATIONMODE) 
        {
            // Nothing
        }
        else
        {
            // Deal with orientation mode
            //FIXME No opMul for Matrix4 * Quaternion
            //mProjMatrix = mProjMatrix * Quaternion(Radian(Degree(mOrientationMode * 90f)), Vector3.UNIT_Z);
        }
        
        RenderSystem renderSystem = Root.getSingleton().getRenderSystem();
        // API specific
        renderSystem._convertProjectionMatrix(mProjMatrix, mProjMatrixRS);
        // API specific for Gpu Programs
        renderSystem._convertProjectionMatrix(mProjMatrix, mProjMatrixRSDepth, true);
        
        
        // Calculate bounding box (local)
        // Box is from 0, down -Z, max dimensions as determined from far plane
        // If infinite view frustum just pick a far value
        Real farDist = (mFarDist == 0) ? 100000 : mFarDist;
        // Near plane bounds
        auto min = Vector3(left, bottom, -farDist);
        auto max = Vector3(right, top, 0);
        
        if (mCustomProjMatrix)
        {
            // Some custom projection matrices can have unusual inverted settings
            // So make sure the AABB is the right way around to start with
            Vector3 tmp = min;
            min.makeFloor(max);
            max.makeCeil(tmp);
        }
        
        if (mProjType == ProjectionType.PT_PERSPECTIVE)
        {
            // Merge with far plane bounds
            Real radio = farDist / mNearDist;
            min.makeFloor(Vector3(left * radio, bottom * radio, -farDist));
            max.makeCeil(Vector3(right * radio, top * radio, 0));
        }
        mBoundingBox.setExtents(min, max);
        
        mRecalcFrustum = false;
        
        // Signal to update frustum clipping planes
        mRecalcFrustumPlanes = true;
    }
    /// Implementation of updateView (called if out of date)
    void updateViewImpl()
    {
        // ----------------------
        // Update the view matrix
        // ----------------------
        
        // Get orientation from quaternion
        debug(STDERR) std.stdio.stderr.writeln("Frustum.updateViewImpl");
        if (!mCustomViewMatrix)
        {
            Matrix3 rot;
            Quaternion orientation = getOrientationForViewUpdate();
            Vector3 position = getPositionForViewUpdate();
            
            mViewMatrix = Math.makeViewMatrix(position, orientation, mReflect? &mReflectMatrix : null);
        }
        
        mRecalcView = false;
        
        // Signal to update frustum clipping planes
        mRecalcFrustumPlanes = true;
        // Signal to update world space corners
        mRecalcWorldSpaceCorners = true;
        // Signal to update frustum if oblique plane enabled,
        // since plane needs to be in view space
        if (mObliqueDepthProjection)
        {
            mRecalcFrustum = true;
        }
    }
    
    void updateFrustumPlanes()
    {
        updateView();
        updateFrustum();
        
        if (mRecalcFrustumPlanes)
        {
            updateFrustumPlanesImpl();
        }
    }
    /// Implementation of updateFrustumPlanes (called if out of date)
    void updateFrustumPlanesImpl()
    {
        // -------------------------
        // Update the frustum planes
        // -------------------------
        Matrix4 combo = mProjMatrix * mViewMatrix;
        
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_LEFT].normal.x = combo[3, 0] + combo[0, 0];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_LEFT].normal.y = combo[3, 1] + combo[0, 1];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_LEFT].normal.z = combo[3, 2] + combo[0, 2];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_LEFT].d = combo[3, 3] + combo[0, 3];
        
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_RIGHT].normal.x = combo[3, 0] - combo[0, 0];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_RIGHT].normal.y = combo[3, 1] - combo[0, 1];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_RIGHT].normal.z = combo[3, 2] - combo[0, 2];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_RIGHT].d = combo[3, 3] - combo[0, 3];
        
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_TOP].normal.x = combo[3, 0] - combo[1, 0];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_TOP].normal.y = combo[3, 1] - combo[1, 1];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_TOP].normal.z = combo[3, 2] - combo[1, 2];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_TOP].d = combo[3, 3] - combo[1, 3];
        
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_BOTTOM].normal.x = combo[3, 0] + combo[1, 0];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_BOTTOM].normal.y = combo[3, 1] + combo[1, 1];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_BOTTOM].normal.z = combo[3, 2] + combo[1, 2];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_BOTTOM].d = combo[3, 3] + combo[1, 3];
        
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_NEAR].normal.x = combo[3, 0] + combo[2, 0];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_NEAR].normal.y = combo[3, 1] + combo[2, 1];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_NEAR].normal.z = combo[3, 2] + combo[2, 2];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_NEAR].d = combo[3, 3] + combo[2, 3];
        
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_FAR].normal.x = combo[3, 0] - combo[2, 0];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_FAR].normal.y = combo[3, 1] - combo[2, 1];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_FAR].normal.z = combo[3, 2] - combo[2, 2];
        mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_FAR].d = combo[3, 3] - combo[2, 3];
        
        // Renormalise any normals which were not unit length
        for(int i=0; i<6; i++ ) 
        {
            Real length = mFrustumPlanes[i].normal.normalise();
            mFrustumPlanes[i].d /= length;
        }
        
        mRecalcFrustumPlanes = false;
    }
    void updateWorldSpaceCorners()
    {
        updateView();
        
        if (mRecalcWorldSpaceCorners)
        {
            updateWorldSpaceCornersImpl();
        }
        
    }
    /// Implementation of updateWorldSpaceCorners (called if out of date)
    void updateWorldSpaceCornersImpl()
    {
        Matrix4 eyeToWorld = mViewMatrix.inverseAffine();
        
        // Note: Even though we can dealing with general projection matrix here,
        //       but because it's incompatibly with infinite far plane, thus, we
        //       still need to working with projection parameters.
        
        // Calc near plane corners
        Real nearLeft, nearRight, nearBottom, nearTop;
        calcProjectionParameters(nearLeft, nearRight, nearBottom, nearTop);
        
        // Treat infinite fardist as some arbitrary far value
        Real farDist = (mFarDist == 0) ? 100000 : mFarDist;
        
        // Calc far palne corners
        Real radio = mProjType == ProjectionType.PT_PERSPECTIVE ? farDist / mNearDist : 1;
        Real farLeft = nearLeft * radio;
        Real farRight = nearRight * radio;
        Real farBottom = nearBottom * radio;
        Real farTop = nearTop * radio;
        
        // near
        mWorldSpaceCorners[0] = eyeToWorld.transformAffine(Vector3(nearRight, nearTop,    -mNearDist));
        mWorldSpaceCorners[1] = eyeToWorld.transformAffine(Vector3(nearLeft,  nearTop,    -mNearDist));
        mWorldSpaceCorners[2] = eyeToWorld.transformAffine(Vector3(nearLeft,  nearBottom, -mNearDist));
        mWorldSpaceCorners[3] = eyeToWorld.transformAffine(Vector3(nearRight, nearBottom, -mNearDist));
        // far
        mWorldSpaceCorners[4] = eyeToWorld.transformAffine(Vector3(farRight,  farTop,     -farDist));
        mWorldSpaceCorners[5] = eyeToWorld.transformAffine(Vector3(farLeft,   farTop,     -farDist));
        mWorldSpaceCorners[6] = eyeToWorld.transformAffine(Vector3(farLeft,   farBottom,  -farDist));
        mWorldSpaceCorners[7] = eyeToWorld.transformAffine(Vector3(farRight,  farBottom,  -farDist));
        
        
        mRecalcWorldSpaceCorners = false;
    }
    
    void updateVertexData()
    {
        if (mRecalcVertexData)
        {
            if (mVertexData.vertexBufferBinding.getBufferCount() <= 0)
            {
                // Initialise vertex & index data
                mVertexData.vertexDeclaration.addElement(0, 0, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_POSITION);
                mVertexData.vertexCount = 32;
                mVertexData.vertexStart = 0;
                mVertexData.vertexBufferBinding.setBinding( 0,
                                                           HardwareBufferManager.getSingleton().createVertexBuffer(
                    (float.sizeof)*3, 32, HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY) );
            }
            
            // Note: Even though we can dealing with general projection matrix here,
            //       but because it's incompatibly with infinite far plane, thus, we
            //       still need to working with projection parameters.
            
            // Calc near plane corners
            Real vpLeft, vpRight, vpBottom, vpTop;
            calcProjectionParameters(vpLeft, vpRight, vpBottom, vpTop);
            
            // Treat infinite fardist as some arbitrary far value
            Real farDist = (mFarDist == 0) ? 100000 : mFarDist;
            
            // Calc far plane corners
            Real radio = mProjType == ProjectionType.PT_PERSPECTIVE ? farDist / mNearDist : 1;
            Real farLeft = vpLeft * radio;
            Real farRight = vpRight * radio;
            Real farBottom = vpBottom * radio;
            Real farTop = vpTop * radio;
            
            // Calculate vertex positions (local)
            // 0 is the origin
            // 1, 2, 3, 4 are the points on the near plane, top left first, clockwise
            // 5, 6, 7, 8 are the points on the far plane, top left first, clockwise
            SharedPtr!HardwareVertexBuffer vbuf = mVertexData.vertexBufferBinding.getBuffer(0);
            float* pFloat = cast(float*)(vbuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
            
            // near plane (remember frustum is going in -Z direction)
            *pFloat++ = vpLeft;  *pFloat++ = vpTop;    *pFloat++ = -mNearDist;
            *pFloat++ = vpRight; *pFloat++ = vpTop;    *pFloat++ = -mNearDist;
            
            *pFloat++ = vpRight; *pFloat++ = vpTop;    *pFloat++ = -mNearDist;
            *pFloat++ = vpRight; *pFloat++ = vpBottom; *pFloat++ = -mNearDist;
            
            *pFloat++ = vpRight; *pFloat++ = vpBottom; *pFloat++ = -mNearDist;
            *pFloat++ = vpLeft;  *pFloat++ = vpBottom; *pFloat++ = -mNearDist;
            
            *pFloat++ = vpLeft;  *pFloat++ = vpBottom; *pFloat++ = -mNearDist;
            *pFloat++ = vpLeft;  *pFloat++ = vpTop;    *pFloat++ = -mNearDist;
            
            // far plane (remember frustum is going in -Z direction)
            *pFloat++ = farLeft;  *pFloat++ = farTop;    *pFloat++ = -farDist;
            *pFloat++ = farRight; *pFloat++ = farTop;    *pFloat++ = -farDist;
            
            *pFloat++ = farRight; *pFloat++ = farTop;    *pFloat++ = -farDist;
            *pFloat++ = farRight; *pFloat++ = farBottom; *pFloat++ = -farDist;
            
            *pFloat++ = farRight; *pFloat++ = farBottom; *pFloat++ = -farDist;
            *pFloat++ = farLeft;  *pFloat++ = farBottom; *pFloat++ = -farDist;
            
            *pFloat++ = farLeft;  *pFloat++ = farBottom; *pFloat++ = -farDist;
            *pFloat++ = farLeft;  *pFloat++ = farTop;    *pFloat++ = -farDist;
            
            // Sides of the pyramid
            *pFloat++ = 0.0f;    *pFloat++ = 0.0f;   *pFloat++ = 0.0f;
            *pFloat++ = vpLeft;  *pFloat++ = vpTop;  *pFloat++ = -mNearDist;
            
            *pFloat++ = 0.0f;    *pFloat++ = 0.0f;   *pFloat++ = 0.0f;
            *pFloat++ = vpRight; *pFloat++ = vpTop;    *pFloat++ = -mNearDist;
            
            *pFloat++ = 0.0f;    *pFloat++ = 0.0f;   *pFloat++ = 0.0f;
            *pFloat++ = vpRight; *pFloat++ = vpBottom; *pFloat++ = -mNearDist;
            
            *pFloat++ = 0.0f;    *pFloat++ = 0.0f;   *pFloat++ = 0.0f;
            *pFloat++ = vpLeft;  *pFloat++ = vpBottom; *pFloat++ = -mNearDist;
            
            // Sides of the box
            
            *pFloat++ = vpLeft;  *pFloat++ = vpTop;  *pFloat++ = -mNearDist;
            *pFloat++ = farLeft;  *pFloat++ = farTop;  *pFloat++ = -farDist;
            
            *pFloat++ = vpRight; *pFloat++ = vpTop;    *pFloat++ = -mNearDist;
            *pFloat++ = farRight; *pFloat++ = farTop;    *pFloat++ = -farDist;
            
            *pFloat++ = vpRight; *pFloat++ = vpBottom; *pFloat++ = -mNearDist;
            *pFloat++ = farRight; *pFloat++ = farBottom; *pFloat++ = -farDist;
            
            *pFloat++ = vpLeft;  *pFloat++ = vpBottom; *pFloat++ = -mNearDist;
            *pFloat++ = farLeft;  *pFloat++ = farBottom; *pFloat++ = -farDist;
            
            
            vbuf.get().unlock();
            
            mRecalcVertexData = false;
        }
    }
    
    bool isViewOutOfDate() //const
    {
        // Attached to node?
        if (mParentNode)
        {
            if (mRecalcView ||
                mParentNode._getDerivedOrientation() != mLastParentOrientation ||
                mParentNode._getDerivedPosition() != mLastParentPosition)
            {
                // Ok, we're out of date with SceneNode we're attached to
                mLastParentOrientation = mParentNode._getDerivedOrientation();
                mLastParentPosition = mParentNode._getDerivedPosition();
                mRecalcView = true;
            }
        }
        // Deriving reflection from linked plane?
        if (mLinkedReflectPlane && 
            !(mLastLinkedReflectionPlane == mLinkedReflectPlane._getDerivedPlane()))
        {
            mReflectPlane = mLinkedReflectPlane._getDerivedPlane();
            mReflectMatrix = Math.buildReflectionMatrix(mReflectPlane);
            mLastLinkedReflectionPlane = mLinkedReflectPlane._getDerivedPlane();
            mRecalcView = true;
        }
        
        return mRecalcView;
    }
    
    bool isFrustumOutOfDate()
    {
        // Deriving custom near plane from linked plane?
        if (mObliqueDepthProjection)
        {
            // Out of date when view out of data since plane needs to be in view space
            if (isViewOutOfDate())
            {
                mRecalcFrustum = true;
            }
            // Update derived plane
            if (mLinkedObliqueProjPlane && 
                !(mLastLinkedObliqueProjPlane == mLinkedObliqueProjPlane._getDerivedPlane()))
            {
                mObliqueProjPlane = mLinkedObliqueProjPlane._getDerivedPlane();
                mLastLinkedObliqueProjPlane = mObliqueProjPlane;
                mRecalcFrustum = true;
            }
        }
        
        return mRecalcFrustum;
    }
    
    /// Signal to update frustum information.
    void invalidateFrustum()//
    {
        mRecalcFrustum = true;
        mRecalcFrustumPlanes = true;
        mRecalcWorldSpaceCorners = true;
        mRecalcVertexData = true;
    }
    
    /// Signal to update view information.
    void invalidateView()//
    {
        mRecalcView = true;
        mRecalcFrustumPlanes = true;
        mRecalcWorldSpaceCorners = true;
    }
    
    /// Shared class-level name for Movable type
    static string msMovableType;
    
    //mutable 
    AxisAlignedBox mBoundingBox;
    //mutable 
    VertexData mVertexData;
    
    SharedPtr!Material mMaterial;
    //mutable 
    Vector3[8] mWorldSpaceCorners;
    
    /// Is this frustum to act as a reflection of itself?
    bool mReflect;
    /// Derived reflection matrix
    //mutable 
    Matrix4 mReflectMatrix;
    /// Fixed reflection plane
    //mutable 
    Plane mReflectPlane;
    /// Pointer to a reflection plane (automatically updated)
    //const
    MovablePlane mLinkedReflectPlane;
    /// Record of the last world-space reflection plane info used
    //mutable 
    IPlane mLastLinkedReflectionPlane;
    
    /// Is this frustum using an oblique depth projection?
    bool mObliqueDepthProjection;
    /// Fixed oblique projection plane
    //mutable 
    Plane mObliqueProjPlane;
    /// Pointer to oblique projection plane (automatically updated)
    //
    MovablePlane mLinkedObliqueProjPlane;
    /// Record of the last world-space oblique depth projection plane info used
    //mutable 
    Plane mLastLinkedObliqueProjPlane;
    
public:
    
    /// Named constructor
    this(string name = "")
    {
        mProjType = ProjectionType.PT_PERSPECTIVE;
        mFOVy = Radian (Math.PI/4.0f);
        mFarDist = 100000.0f;
        mNearDist = 100.0f;
        mAspect = 1.33333333333333f;
        mOrthoHeight = 1000;
        mFrustumOffset = Vector2.ZERO;
        mFocalLength = 1.0f;
        mLastParentOrientation = Quaternion.IDENTITY;
        mLastParentPosition = Vector3.ZERO;
        mRecalcFrustum = true;
        mRecalcView = true;
        mRecalcFrustumPlanes = true;
        mRecalcWorldSpaceCorners = true;
        mRecalcVertexData = true;
        mCustomViewMatrix = false;
        mCustomProjMatrix = false;
        mFrustumExtentsManuallySet = false;
        mOrientationMode = OrientationMode.OR_DEGREE_0;
        mReflect = false;
        mLinkedReflectPlane = null;
        mObliqueDepthProjection = false;
        mLinkedObliqueProjPlane = null;
        
        // Initialise material
        mMaterial = MaterialManager.getSingleton().getByName("BaseWhiteNoLighting");
        
        // Alter superclass members
        mVisible = false;
        //mParentNode = null;
        mName = name;
        
        mLastLinkedReflectionPlane = new Plane;
        mLastLinkedObliqueProjPlane = new Plane;
        mLastLinkedReflectionPlane.Normal = Vector3.ZERO;
        mLastLinkedObliqueProjPlane.normal = Vector3.ZERO;
        
        //TODO Plane: struct to class so init here
        foreach(f; 0..mFrustumPlanes.length)
            mFrustumPlanes[f] = new Plane;
            
        updateView();
        updateFrustum();
    }
    
    ~this() {DestroyRenderable();}
    /** Sets the Y-dimension Field Of View (FOV) of the frustum.
     @remarks
     Field Of View (FOV) is the angle made between the frustum's position, and the edges
     of the 'screen' onto which the scene is projected. High values (90+ degrees) result in a wide-angle,
     fish-eye kind of view, low values (30- degrees) in a stretched, telescopic kind of view. Typical values
     are between 45 and 60 degrees.
     @par
     This value represents the VERTICAL field-of-view. The horizontal field of view is calculated from
     this depending on the dimensions of the viewport (they will only be the same if the viewport is square).
     @note
     Setting the FOV overrides the value supplied for frustum.setNearClipPlane.
     */
    void setFOVy(Radian fovy)
    {
        mFOVy = fovy;
        invalidateFrustum();
    }
    
    /** Retrieves the frustums Y-dimension Field Of View (FOV).
     */
    Radian getFOVy()
    {
        return mFOVy;
    }
    
    /** Sets the position of the near clipping plane.
     @remarks
     The position of the near clipping plane is the distance from the frustums position to the screen
     on which the world is projected. The near plane distance, combined with the field-of-view and the
     aspect ratio, determines the size of the viewport through which the world is viewed (in world
     co-ordinates). Note that this world viewport is different to a screen viewport, which has it's
     dimensions expressed in pixels. The frustums viewport should have the same aspect ratio as the
     screen viewport it renders into to avoid distortion.
     @param nearDist
     The distance to the near clipping plane from the frustum in world coordinates.
     */
    void setNearClipDistance(Real nearDist)
    {
        if (nearDist <= 0)
            throw new InvalidParamsError("Near clip distance must be greater than zero.",
                                         "Frustum.setNearClipDistance");
        mNearDist = nearDist;
        invalidateFrustum();
    }
    
    /** Sets the position of the near clipping plane.
     */
    Real getNearClipDistance()
    {
        return mNearDist;
    }
    
    /** Sets the distance to the far clipping plane.
     @remarks
     The view frustum is a pyramid created from the frustum position and the edges of the viewport.
     This method sets the distance for the far end of that pyramid. 
     Different applications need different values: e.g. a flight sim
     needs a much further far clipping plane than a first-person 
     shooter. An important point here is that the larger the ratio 
     between near and far clipping planes, the lower the accuracy of
     the Z-buffer used to depth-cue pixels. This is because the
     Z-range is limited to the size of the Z buffer (16 or 32-bit) 
     and the max values must be spread over the gap between near and
     far clip planes. As it happens, you can affect the accuracy far 
     more by altering the near distance rather than the far distance, 
     but keep this in mind.
     @param farDist
     The distance to the far clipping plane from the frustum in 
     world coordinates.If you specify 0, this means an infinite view
     distance which is useful especially when projecting shadows; but
     be caref ul not to use a near distance too close.
     */
    void setFarClipDistance(Real farDist)
    {
        mFarDist = farDist;
        invalidateFrustum();
    }
    
    /** Retrieves the distance from the frustum to the far clipping plane.
     */
    Real getFarClipDistance()
    {
        return mFarDist;
    }
    
    /** Sets the aspect ratio for the frustum viewport.
     @remarks
     The ratio between the x and y dimensions of the rectangular area visible through the frustum
     is known as aspect ratio: aspect = width / height .
     @par
     The default for most fullscreen windows is 1.3333 - this is also assumed by Ogre unless you
     use this method to state otherwise.
     */
    void setAspectRatio(Real ratio)
    {
        mAspect = ratio;
        invalidateFrustum();
    }
    
    /** Retreives the current aspect ratio.
     */
    Real getAspectRatio()
    {
        return mAspect;
    }
    
    /** Sets frustum offsets, used in stereo rendering.
     @remarks
     You can set both horizontal and vertical plane offsets of "eye"; in
     stereo rendering frustum is moved in horizontal plane. To be able to
     render from two "eyes" you'll need two cameras rendering on two
     RenderTargets.
     @par
     The frustum offsets is in world coordinates, and default to (0, 0) - no offsets.
     @param offset
     The horizontal and vertical plane offsets.
     */
    void setFrustumOffset(Vector2 offset)
    {
        mFrustumOffset = offset;
        invalidateFrustum();
    }
    
    /** Sets frustum offsets, used in stereo rendering.
     @remarks
     You can set both horizontal and vertical plane offsets of "eye"; in
     stereo rendering frustum is moved in horizontal plane. To be able to
     render from two "eyes" you'll need two cameras rendering on two
     RenderTargets.
     @par
     The frustum offsets is in world coordinates, and default to (0, 0) - no offsets.
     @param horizontal
     The horizontal plane offset.
     @param vertical
     The vertical plane offset.
     */
    void setFrustumOffset(Real horizontal = 0.0, Real vertical = 0.0)
    {
        setFrustumOffset(Vector2(horizontal, vertical));
    }
    
    /** Retrieves the frustum offsets.
     */
    ref Vector2 getFrustumOffset()
    {
        return mFrustumOffset;
    }
    
    /** Sets frustum focal length (used in stereo rendering).
     @param focalLength
     The distance to the focal plane from the frustum in world coordinates.
     */
    void setFocalLength(Real focalLength = 1.0)
    {
        if (focalLength <= 0)
        {
            throw new InvalidParamsError(
                "Focal length must be greater than zero.",
                "Frustum.setFocalLength");
        }
        
        mFocalLength = focalLength;
        invalidateFrustum();
    }
    
    /** Returns focal length of frustum.
     */
    Real getFocalLength()
    {
        return mFocalLength;
    }
    
    /** Manually set the extents of the frustum.
     @param left, right, top, bottom The position where the side clip planes intersect
     the near clip plane, in eye space
     */
    void setFrustumExtents(Real left, Real right, Real top, Real bottom)
    {
        mFrustumExtentsManuallySet = true;
        mLeft = left;
        mRight = right;
        mTop = top;
        mBottom = bottom;
        
        invalidateFrustum();
    }
    /** Reset the frustum extents to be automatically derived from other params. */
    void resetFrustumExtents()
    {
        mFrustumExtentsManuallySet = false;
        invalidateFrustum();
    }
    /** Get the extents of the frustum in view space. */
    void getFrustumExtents(ref Real outleft, ref Real outright, ref Real outtop, ref Real outbottom)
    {
        updateFrustum();
        outleft = mLeft;
        outright = mRight;
        outtop = mTop;
        outbottom = mBottom;
    }
    
    
    /** Gets the projection matrix for this frustum adjusted for the current
     rendersystem specifics (may be right or left-handed, depth range
     may vary).
     @remarks
     This method retrieves the rendering-API dependent version of the projection
     matrix. If you want a 'typical' projection matrix then use 
     getProjectionMatrix.
     */
    ref Matrix4 getProjectionMatrixRS()
    {
        
        updateFrustum();
        
        return mProjMatrixRS;
    }
    /** Gets the depth-adjusted projection matrix for the current rendersystem,
     but one which still conforms to right-hand rules.
     @remarks
     This differs from the rendering-API dependent getProjectionMatrix
     in that it always returns a right-handed projection matrix result 
     no matter what rendering API is being used - this is required for
     vertex and fragment programs for example. However, the resulting depth
     range may still vary between render systems since D3D uses [0,1] and 
     GL uses [-1,1], and the range must be kept the same between programmable
     and fixed-function pipelines.
     */
    ref Matrix4 getProjectionMatrixWithRSDepth()
    {
        
        updateFrustum();
        
        return mProjMatrixRSDepth;
    }
    /** Gets the normal projection matrix for this frustum, ie the 
     projection matrix which conforms to standard right-handed rules and
     uses depth range [-1,+1].
     @remarks
     This differs from the rendering-API dependent getProjectionMatrixRS
     in that it always returns a right-handed projection matrix with depth
     range [-1,+1], result no matter what rendering API is being used - this
     is required for some uniform algebra for example.
     */
    Matrix4 getProjectionMatrix()
    {
        
        updateFrustum();
        
        return mProjMatrix;
    }

    /// FIXME updateFrustum() is not called
    Matrix4 getProjectionMatrix() const
    {
        //updateFrustum();
        return mProjMatrix;
    }
    
    /** Gets the view matrix for this frustum. Mainly for use by OGRE internally.
     */
    Matrix4 getViewMatrix()
    {
        updateView();
        return mViewMatrix;
    }

    /// FIXME updateView(); is not called
    Matrix4 getViewMatrix() const
    {
        //updateView();
        return mViewMatrix;
    }
    
    /** Calculate a view matrix for this frustum, relative to a potentially dynamic point. 
     Mainly for use by OGRE internally when using camera-relative rendering
     for frustums that are not the centre (e.g. texture projection)
     */
    void calcViewMatrixRelative(Vector3 relPos, ref Matrix4 matToUpdate) const
    {
        Matrix4 matTrans = Matrix4.IDENTITY;
        matTrans.setTrans(relPos);
        matToUpdate = getViewMatrix() * matTrans;
        
    }
    
    /** Set whether to use a custom view matrix on this frustum.
     @remarks
     This is an advanced method which allows you to manually set
     the view matrix on this frustum, rather than having it calculate
     itself based on it's position and orientation. 
     @note
     After enabling a custom view matrix, the frustum will no longer
     update on its own based on position / orientation changes. You 
     are completely responsible for keeping the view matrix up to date.
     The custom matrix will be returned from getViewMatrix.
     @param enable If @c true, the custom view matrix passed as the second 
     parameter will be used in preference to an auto calculated one. If
     false, the frustum will revert to auto calculating the view matrix.
     @param viewMatrix The custom view matrix to use, the matrix must be an
     affine matrix.
     @see Frustum.setCustomProjectionMatrix, Matrix4.isAffine
     */
    void setCustomViewMatrix(bool enable, 
                             Matrix4 viewMatrix = Matrix4.IDENTITY)
    {
        mCustomViewMatrix = enable;
        if (enable)
        {
            assert(viewMatrix.isAffine());
            mViewMatrix = viewMatrix;
        }
        invalidateView();
    }
    
    /// Returns whether a custom view matrix is in use
    bool isCustomViewMatrixEnabled()
    { return mCustomViewMatrix; }
    
    /** Set whether to use a custom projection matrix on this frustum.
     @remarks
     This is an advanced method which allows you to manually set
     the projection matrix on this frustum, rather than having it 
     calculate itself based on it's position and orientation. 
     @note
     After enabling a custom projection matrix, the frustum will no 
     longer update on its own based on field of view and near / far
     distance changes. You are completely responsible for keeping the 
     projection matrix up to date if those values change. The custom 
     matrix will be returned from getProjectionMatrix and derivative
     functions.
     @param enable
     If @c true, the custom projection matrix passed as the 
     second parameter will be used in preference to an auto calculated 
     one. If @c false, the frustum will revert to auto calculating the 
     projection matrix.
     @param projectionMatrix
     The custom view matrix to use.
     @see Frustum.setCustomViewMatrix
     */
    void setCustomProjectionMatrix(bool enable, 
                                   Matrix4 projectionMatrix = Matrix4.IDENTITY)
    {
        mCustomProjMatrix = enable;
        if (enable)
        {
            mProjMatrix = projectionMatrix;
        }
        invalidateFrustum();
    }
    /// Returns whether a custom projection matrix is in use
    bool isCustomProjectionMatrixEnabled()
    { return mCustomProjMatrix; }
    
    /** Retrieves the clipping planes of the frustum (world space).
     @remarks
     The clipping planes are ordered as declared in enumerate constants FrustumPlane.
     */
    ref Plane[6] getFrustumPlanes()
    {
        // Make any pending updates to the calculated frustum planes
        updateFrustumPlanes();
        
        return mFrustumPlanes;
    }
    
    /** Retrieves a specified plane of the frustum (world space).
     @remarks
     Gets a reference to one of the planes which make up the frustum frustum, e.g. for clipping purposes.
     */
    ref Plane getFrustumPlane( ushort plane )
    {
        // Make any pending updates to the calculated frustum planes
        updateFrustumPlanes();
        
        return mFrustumPlanes[plane];
        
    }
    
    /** Tests whether the given container is visible in the Frustum.
     @param bound
     Bounding box to be checked (world space).
     @param culledBy
     Optional pointer to an int which will be filled by the plane number which culled
     the box if the result was @c false;
     @return
     If the box was visible, @c true is returned.
     @par
     Otherwise, @c false is returned.
     */
    bool isVisible(AxisAlignedBox bound, FrustumPlane* culledBy/*= FrustumPlane.FRUSTUM_PLANE_NEAR*/)
    {
        // Null boxes always invisible
        if (bound.isNull()) return false;
        
        // Infinite boxes always visible
        if (bound.isInfinite()) return true;
        
        // Make any pending updates to the calculated frustum planes
        updateFrustumPlanes();
        
        // Get centre of the box
        Vector3 centre = bound.getCenter();
        // Get the half-size of the box
        Vector3 halfSize = bound.getHalfSize();
        
        // For each plane, see if all points are on the negative side
        // If so, object is not visible
        for (int plane = 0; plane < 6; ++plane)
        {
            // Skip far plane if infinite view frustum
            if (plane == FrustumPlane.FRUSTUM_PLANE_FAR && mFarDist == 0)
                continue;
            
            Plane.Side side = mFrustumPlanes[plane].getSide(centre, halfSize);
            if (side == Plane.Side.NEGATIVE_SIDE)
            {
                // ALL corners on negative side Therefore out of view
                if (culledBy)
                    *culledBy = cast(FrustumPlane)plane;
                return false;
            }
            
        }
        
        return true;
    }
    
    /** Tests whether the given container is visible in the Frustum.
     @param bound
     Bounding sphere to be checked (world space).
     @param culledBy
     Optional pointer to an int which will be filled by the plane number which culled
     the box if the result was @c false;
     @return
     If the sphere was visible, @c true is returned.
     @par
     Otherwise, @c false is returned.
     */
    bool isVisible(Sphere sphere, FrustumPlane* culledBy /*= FrustumPlane.FRUSTUM_PLANE_NEAR*/)
    {
        // Make any pending updates to the calculated frustum planes
        updateFrustumPlanes();
        // For each plane, see if sphere is on negative side
        // If so, object is not visible
        for (int plane = 0; plane < 6; ++plane)
        {
            // Skip far plane if infinite view frustum
            if (plane == FrustumPlane.FRUSTUM_PLANE_FAR && mFarDist == 0)
                continue;
            
            // If the distance from sphere center to plane is negative, and 'more negative' 
            // than the radius of the sphere, sphere is outside frustum
            if (mFrustumPlanes[plane].getDistance(sphere.getCenter()) < -sphere.getRadius())
            {
                // ALL corners on negative side Therefore out of view
                if (culledBy)
                    *culledBy = cast(FrustumPlane)plane;
                return false;
            }
            
        }
        
        return true;
    }
    
    /** Tests whether the given vertex is visible in the Frustum.
     @param vert
     Vertex to be checked (world space).
     @param culledBy
     Optional pointer to an int which will be filled by the plane number which culled
     the box if the result was @c false;
     @return
     If the sphere was visible, @c true is returned.
     @par
     Otherwise, @c false is returned.
     */
    bool isVisible(Vector3 vert, FrustumPlane *culledBy /*= FrustumPlane.FRUSTUM_PLANE_NEAR*/)
    {
        // Make any pending updates to the calculated frustum planes
        updateFrustumPlanes();
        
        // For each plane, see if all points are on the negative side
        // If so, object is not visible
        for (int plane = 0; plane < 6; ++plane)
        {
            // Skip far plane if infinite view frustum
            if (plane == FrustumPlane.FRUSTUM_PLANE_FAR && mFarDist == 0)
                continue;
            
            if (mFrustumPlanes[plane].getSide(vert) == Plane.Side.NEGATIVE_SIDE)
            {
                // ALL corners on negative side Therefore out of view
                if (culledBy)
                    *culledBy = cast(FrustumPlane)plane;
                return false;
            }
            
        }
        
        return true;
    }
    
    /// Overridden from MovableObject.getTypeFlags
    override uint getTypeFlags()
    {
        return SceneManager.FRUSTUM_TYPE_MASK;
    }
    
    /** Overridden from MovableObject */
    override AxisAlignedBox getBoundingBox()
    {
        return mBoundingBox;
    }
    
    /** Overridden from MovableObject */
    override Real getBoundingRadius()
    {
        return (mFarDist == 0)? 100000 : mFarDist;
    }
    
    /** Overridden from MovableObject */
    override void _updateRenderQueue(RenderQueue queue)
    {
        if (mDebugDisplay)
        {
            // Add self 
            queue.addRenderable(this);
        }
    }
    
    /** Overridden from MovableObject */
    override string getMovableType()
    {
        return msMovableType;
    }
    
    /** Overridden from MovableObject */
    override void _notifyCurrentCamera(Camera cam)
    {
        // Make sure bounding box up-to-date
        updateFrustum();
        
        MovableObject._notifyCurrentCamera(cam);
    }
    
    /** Overridden from Renderable */
    SharedPtr!Material getMaterial()
    {
        return mMaterial;
    }
    
    /** Overridden from Renderable */
    void getRenderOperation(ref RenderOperation op)
    {
        updateVertexData();
        op.operationType = RenderOperation.OperationType.OT_LINE_LIST;
        op.useIndexes = false;
        op.useGlobalInstancingVertexBufferIsAvailable = false;
        op.vertexData = mVertexData;
    }
    
    /** Overridden from Renderable */
    void getWorldTransforms(ref Matrix4[] xform)
    {
        if (mParentNode)
            xform.insertOrReplace(mParentNode._getFullTransform());
        else
            xform.insertOrReplace(cast(Matrix4)Matrix4.IDENTITY); //TODO to mutable
    }
    
    /** Overridden from Renderable */
    override Real getSquaredViewDepth(Camera cam)
    {
        // Calc from centre
        if (mParentNode)
            return (cam.getDerivedPosition() 
                    - mParentNode._getDerivedPosition()).squaredLength();
        else
            return 0;
    }
    
    /** Overridden from Renderable */
    override LightList getLights()
    {
        // N/A
        //OGRE_DEFINE_STATIC_LOCAL(LightList, ll, ());
        //        static LightList ll;
        static LightList ll;
        return ll;
    }
    
    /** Gets the world space corners of the frustum.
     @remarks
     The corners are ordered as follows: top-right near, 
     top-left near, bottom-left near, bottom-right near, 
     top-right far, top-left far, bottom-left far, bottom-right far.
     */
    ref Vector3[8] getWorldSpaceCorners()
    {
        updateWorldSpaceCorners();
        
        return mWorldSpaceCorners;
    }
    
    /** Sets the type of projection to use (orthographic or perspective). Default is perspective.
     */
    void setProjectionType(ProjectionType pt)
    {
        mProjType = pt;
        invalidateFrustum();
    }
    
    /** Retrieves info on the type of projection used (orthographic or perspective).
     */
    ProjectionType getProjectionType()
    {
        return mProjType;
    }
    
    /** Sets the orthographic window settings, for use with orthographic rendering only. 
     @note Calling this method will recalculate the aspect ratio, use 
     setOrthoWindowHeight or setOrthoWindowWidth alone if you wish to 
     preserve the aspect ratio but just fit one or other dimension to a 
     particular size.
     @param w
     The width of the view window in world units.
     @param h
     The height of the view window in world units.
     */
    void setOrthoWindow(Real w, Real h)
    {
        mOrthoHeight = h;
        mAspect = w / h;
        invalidateFrustum();
    }
    /** Sets the orthographic window height, for use with orthographic rendering only. 
     @note The width of the window will be calculated from the aspect ratio. 
     @param h
     The height of the view window in world units.
     */
    void setOrthoWindowHeight(Real h)
    {
        mOrthoHeight = h;
        invalidateFrustum();
    }
    /** Sets the orthographic window width, for use with orthographic rendering only. 
     @note The height of the window will be calculated from the aspect ratio. 
     @param w
     The width of the view window in world units.
     */
    void setOrthoWindowWidth(Real w)
    {
        mOrthoHeight = w / mAspect;
        invalidateFrustum();
    }
    /** Gets the orthographic window height, for use with orthographic rendering only. 
     */
    Real getOrthoWindowHeight()
    {
        return mOrthoHeight;
    }
    /** Gets the orthographic window width, for use with orthographic rendering only. 
     @note This is calculated from the orthographic height and the aspect ratio
     */
    Real getOrthoWindowWidth()
    {
        return mOrthoHeight * mAspect;  
    }
    
    /** Modifies this frustum so it always renders from the reflection of itself through the
     plane specified.
     @remarks
     This is obviously useful for performing planar reflections. 
     */
    void enableReflection(Plane p)
    {
        mReflect = true;
        mReflectPlane = p;
        mLinkedReflectPlane = null;
        mReflectMatrix = Math.buildReflectionMatrix(p);
        invalidateView();
        
    }
    /** Modifies this frustum so it always renders from the reflection of itself through the
     plane specified. Note that this version of the method links to a plane
     so that changes to it are picked up automatically. It is important that
     this plane continues to exist whilst this object does; do not destroy
     the plane before the frustum.
     @remarks
     This is obviously useful for performing planar reflections. 
     */
    void enableReflection(MovablePlane p)
    {
        mReflect = true;
        mLinkedReflectPlane = p;
        mReflectPlane = mLinkedReflectPlane._getDerivedPlane();
        mReflectMatrix = Math.buildReflectionMatrix(mReflectPlane);
        mLastLinkedReflectionPlane = mLinkedReflectPlane._getDerivedPlane();
        invalidateView();
    }
    
    /** Disables reflection modification previously turned on with enableReflection */
    void disableReflection()
    {
        mReflect = false;
        mLinkedReflectPlane = null;
        mLastLinkedReflectionPlane.Normal = Vector3.ZERO;
        invalidateView();
    }
    
    /// Returns whether this frustum is being reflected
    bool isReflected(){ return mReflect; }
    /// Returns the reflection matrix of the frustum if appropriate
    ref Matrix4 getReflectionMatrix(){ return mReflectMatrix; }
    /// Returns the reflection plane of the frustum if appropriate
    ref Plane getReflectionPlane(){ return mReflectPlane; }
    
    /** Project a sphere onto the near plane and get the bounding rectangle. 
     @param sphere The world-space sphere to project.
     @param left
     Pointers to destination values, these will be completed with 
     the normalised device coordinates (in the range {-1,1}).
     @param top
     Pointers to destination values, these will be completed with 
     the normalised device coordinates (in the range {-1,1}).
     @param right
     Pointers to destination values, these will be completed with 
     the normalised device coordinates (in the range {-1,1}).
     @param bottom
     Pointers to destination values, these will be completed with 
     the normalised device coordinates (in the range {-1,1}).
     @return @c true if the sphere was projected to a subset of the near plane,
     @c false if the entire near plane was contained.
     */
    bool projectSphere(Sphere sphere, 
                       ref Real left, ref Real top, ref Real right, ref Real bottom)
    {
        // See http://www.gamasutra.com/features/20021011/lengyel_06.htm
        // Transform light position into camera space
        
        updateView();
        Vector3 eyeSpacePos = mViewMatrix.transformAffine(sphere.getCenter());
        
        // initialise
        left = bottom = -1.0f;
        right = top = 1.0f;
        
        if (eyeSpacePos.z < 0)
        {
            updateFrustum();
            Matrix4 projMatrix = getProjectionMatrix();
            Real r = sphere.getRadius();
            Real rsq = r * r;
            
            // early-exit
            if (eyeSpacePos.squaredLength() <= rsq)
                return false;
            
            Real Lxz = Math.Sqr(eyeSpacePos.x) + Math.Sqr(eyeSpacePos.z);
            Real Lyz = Math.Sqr(eyeSpacePos.y) + Math.Sqr(eyeSpacePos.z);
            
            // Find the tangent planes to the sphere
            // XZ first
            // calculate quadratic discriminant: b*b - 4ac
            // x = Nx
            // a = Lx^2 + Lz^2
            // b = -2rLx
            // c = r^2 - Lz^2
            Real a = Lxz;
            Real b = -2.0f * r * eyeSpacePos.x;
            Real c = rsq - Math.Sqr(eyeSpacePos.z);
            Real D = b*b - 4.0f*a*c;
            
            // two roots?
            if (D > 0)
            {
                Real sqrootD = Math.Sqrt(D);
                // solve the quadratic to get the components of the normal
                Real Nx0 = (-b + sqrootD) / (2 * a);
                Real Nx1 = (-b - sqrootD) / (2 * a);
                
                // Derive Z from this
                Real Nz0 = (r - Nx0 * eyeSpacePos.x) / eyeSpacePos.z;
                Real Nz1 = (r - Nx1 * eyeSpacePos.x) / eyeSpacePos.z;
                
                // Get the point of tangency
                // Only consider points of tangency in front of the camera
                Real Pz0 = (Lxz - rsq) / (eyeSpacePos.z - ((Nz0 / Nx0) * eyeSpacePos.x));
                if (Pz0 < 0)
                {
                    // Project point onto near plane in worldspace
                    Real nearx0 = (Nz0 * mNearDist) / Nx0;
                    // now we need to map this to viewport coords
                    // use projection matrix since that will take into account all factors
                    Vector3 relx0 = projMatrix * Vector3(nearx0, 0, -mNearDist);
                    
                    // find out whether this is a left side or right side
                    Real Px0 = -(Pz0 * Nz0) / Nx0;
                    if (Px0 > eyeSpacePos.x)
                    {
                        right = std.algorithm.min(right, relx0.x);
                    }
                    else
                    {
                        left = std.algorithm.max(left, relx0.x);
                    }
                }
                Real Pz1 = (Lxz - rsq) / (eyeSpacePos.z - ((Nz1 / Nx1) * eyeSpacePos.x));
                if (Pz1 < 0)
                {
                    // Project point onto near plane in worldspace
                    Real nearx1 = (Nz1 * mNearDist) / Nx1;
                    // now we need to map this to viewport coords
                    // use projection matrix since that will take into account all factors
                    Vector3 relx1 = projMatrix * Vector3(nearx1, 0, -mNearDist);
                    
                    // find out whether this is a left side or right side
                    Real Px1 = -(Pz1 * Nz1) / Nx1;
                    if (Px1 > eyeSpacePos.x)
                    {
                        right = std.algorithm.min(right, relx1.x);
                    }
                    else
                    {
                        left = std.algorithm.max(left, relx1.x);
                    }
                }
            }
            
            
            // Now YZ 
            // calculate quadratic discriminant: b*b - 4ac
            // x = Ny
            // a = Ly^2 + Lz^2
            // b = -2rLy
            // c = r^2 - Lz^2
            a = Lyz;
            b = -2.0f * r * eyeSpacePos.y;
            c = rsq - Math.Sqr(eyeSpacePos.z);
            D = b*b - 4.0f*a*c;
            
            // two roots?
            if (D > 0)
            {
                Real sqrootD = Math.Sqrt(D);
                // solve the quadratic to get the components of the normal
                Real Ny0 = (-b + sqrootD) / (2 * a);
                Real Ny1 = (-b - sqrootD) / (2 * a);
                
                // Derive Z from this
                Real Nz0 = (r - Ny0 * eyeSpacePos.y) / eyeSpacePos.z;
                Real Nz1 = (r - Ny1 * eyeSpacePos.y) / eyeSpacePos.z;
                
                // Get the point of tangency
                // Only consider points of tangency in front of the camera
                Real Pz0 = (Lyz - rsq) / (eyeSpacePos.z - ((Nz0 / Ny0) * eyeSpacePos.y));
                if (Pz0 < 0)
                {
                    // Project point onto near plane in worldspace
                    Real neary0 = (Nz0 * mNearDist) / Ny0;
                    // now we need to map this to viewport coords
                    // use projection matriy since that will take into account all factors
                    Vector3 rely0 = projMatrix * Vector3(0, neary0, -mNearDist);
                    
                    // find out whether this is a top side or bottom side
                    Real Py0 = -(Pz0 * Nz0) / Ny0;
                    if (Py0 > eyeSpacePos.y)
                    {
                        top = std.algorithm.min(top, rely0.y);
                    }
                    else
                    {
                        bottom = std.algorithm.max(bottom, rely0.y);
                    }
                }
                Real Pz1 = (Lyz - rsq) / (eyeSpacePos.z - ((Nz1 / Ny1) * eyeSpacePos.y));
                if (Pz1 < 0)
                {
                    // Project point onto near plane in worldspace
                    Real neary1 = (Nz1 * mNearDist) / Ny1;
                    // now we need to map this to viewport coords
                    // use projection matriy since that will take into account all factors
                    Vector3 rely1 = projMatrix * Vector3(0, neary1, -mNearDist);
                    
                    // find out whether this is a top side or bottom side
                    Real Py1 = -(Pz1 * Nz1) / Ny1;
                    if (Py1 > eyeSpacePos.y)
                    {
                        top = std.algorithm.min(top, rely1.y);
                    }
                    else
                    {
                        bottom = std.algorithm.max(bottom, rely1.y);
                    }
                }
            }
        }
        
        return (left != -1.0f) || (top != 1.0f) || (right != 1.0f) || (bottom != -1.0f);
        
    }
    
    
    /** Links the frustum to a custom near clip plane, which can be used
     to clip geometry in a custom manner without using user clip planes.
     @remarks
     There are several applications for clipping a scene arbitrarily by
     a single plane; the most common is when rendering a reflection to 
     a texture, and you only want to render geometry that is above the 
     water plane (to do otherwise results in artefacts). Whilst it is
     possible to use user clip planes, they are not supported on all
     cards, and sometimes are not hardware accelerated when they are
     available. Instead, where a single clip plane is involved, this
     technique uses a 'fudging' of the near clip plane, which is 
     available and fast on all hardware, to perform as the arbitrary
     clip plane. This does change the shape of the frustum, leading 
     to some depth buffer loss of precision, but for many of the uses of
     this technique that is not an issue.
     @par 
     This version of the method links to a plane, rather than requiring
     a by-value plane definition, and Therefore you can 
     make changes to the plane (e.g. by moving / rotating the node it is
     attached to) and they will automatically affect this object.
     @note This technique only works for perspective projection.
     @param plane
     The plane to link to to perform the clipping. This plane
     must continue to exist while the camera is linked to it; do not
     destroy it before the frustum. 
     */
    void enableCustomNearClipPlane(MovablePlane plane)
    {
        mObliqueDepthProjection = true;
        mLinkedObliqueProjPlane = plane;
        mObliqueProjPlane = plane._getDerivedPlane();
        invalidateFrustum();
    }
    /** Links the frustum to a custom near clip plane, which can be used
     to clip geometry in a custom manner without using user clip planes.
     @remarks
     There are several applications for clipping a scene arbitrarily by
     a single plane; the most common is when rendering a reflection to  
     a texture, and you only want to render geometry that is above the 
     water plane (to do otherwise results in artefacts). Whilst it is
     possible to use user clip planes, they are not supported on all
     cards, and sometimes are not hardware accelerated when they are
     available. Instead, where a single clip plane is involved, this
     technique uses a 'fudging' of the near clip plane, which is 
     available and fast on all hardware, to perform as the arbitrary
     clip plane. This does change the shape of the frustum, leading 
     to some depth buffer loss of precision, but for many of the uses of
     this technique that is not an issue.
     @note This technique only works for perspective projection.
     @param plane
     The plane to link to to perform the clipping. This plane
     must continue to exist while the camera is linked to it; do not
     destroy it before the frustum. 
     */
    void enableCustomNearClipPlane(Plane plane)
    {
        mObliqueDepthProjection = true;
        mLinkedObliqueProjPlane = null;
        mObliqueProjPlane = plane;
        invalidateFrustum();
    }
    /** Disables any custom near clip plane. */
    void disableCustomNearClipPlane()
    {
        mObliqueDepthProjection = false;
        mLinkedObliqueProjPlane = null;
        invalidateFrustum();
    }
    /** Is a custom near clip plane in use? */
    bool isCustomNearClipPlaneEnabled()
    { return mObliqueDepthProjection; }
    
    /// @copydoc MovableObject.visitRenderables
    override void visitRenderables(Renderable.Visitor visitor, 
                                   bool debugRenderables = false)
    {
        // Only displayed in debug
        if (debugRenderables)
        {
            visitor.visit(this, 0, true);
        }
        
    }
    
    /// Small constant used to reduce far plane projection to avoid inaccuracies
    enum Real INFINITE_FAR_PLANE_ADJUST = 0.00001;
    
    /** Get the derived position of this frustum. */
    Vector3 getPositionForViewUpdate()
    {
        return mLastParentPosition;
    }
    /** Get the derived orientation of this frustum. */
    Quaternion getOrientationForViewUpdate()
    {
        return mLastParentOrientation;
    }
    
    /** Gets a world-space list of planes enclosing the frustum.
     */
    PlaneBoundedVolume getPlaneBoundedVolume()
    {
        updateFrustumPlanes();
        
        PlaneBoundedVolume volume;
        volume.planes.insert(mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_NEAR]);
        volume.planes.insert(mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_FAR]);
        volume.planes.insert(mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_BOTTOM]);
        volume.planes.insert(mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_TOP]);
        volume.planes.insert(mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_LEFT]);
        volume.planes.insert(mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_RIGHT]);
        return volume;
    }
    /** Set the orientation mode of the frustum. Default is OR_DEGREE_0
     @remarks
     Setting the orientation of a frustum is only supported on
     iOS at this time.  An exception is thrown on other platforms.
     */
    void setOrientationMode(OrientationMode orientationMode)
    {
        static if(OGRE_NO_VIEWPORT_ORIENTATIONMODE) {
            throw new NotImplementedError(
                "Setting Frustrum orientation mode is not supported",
                "Frustum.setOrientationMode");
        }
        mOrientationMode = orientationMode;
        invalidateFrustum();
    }
    
    /** Get the orientation mode of the frustum.
     @remarks
     Getting the orientation of a frustum is only supported on
     iOS at this time.  An exception is thrown on other platforms.
     */
    OrientationMode getOrientationMode()
    {
        version (OGRE_NO_VIEWPORT_ORIENTATIONMODE) {
            throw new NotImplementedError(
                "Getting Frustrum orientation mode is not supported",
                "Frustum.getOrientationMode");
        }
        return mOrientationMode;
    }
    
}

/** @} */
/** @} */