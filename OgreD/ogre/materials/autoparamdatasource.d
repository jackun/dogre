module ogre.materials.autoparamdatasource;
import std.math;

import ogre.math.matrix;
import ogre.math.vector;
import ogre.compat;
import ogre.config;
import ogre.general.colourvalue;
import ogre.math.frustum;
import ogre.rendersystem.rendersystem;
import ogre.rendersystem.viewport;
import ogre.rendersystem.rendertarget;
import ogre.general.root;
import ogre.math.angles;
import ogre.math.quaternion;
import ogre.resources.texture;
import ogre.general.controllermanager;
import ogre.scene.light;
import ogre.scene.camera;
import ogre.scene.renderable;
import ogre.materials.pass;
import ogre.scene.scenenode;
import ogre.math.maths;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Materials
 *  @{
 */


Matrix4 PROJECTIONCLIPSPACE2DTOIMAGESPACE_PERSPECTIVE = Matrix4 (
    0.5,    0,    0,  0.5, 
    0,   -0.5,    0,  0.5, 
    0,      0,    1,    0,
    0,      0,    0,    1);

/** This utility class is used to hold the information used to generate the matrices
 and other information required to automatically populate GpuProgramParameters.
 @remarks
 This class exercises a lazy-update scheme in order to avoid having to update all
 the information a GpuProgramParameters class could possibly want all the time. 
 It relies on the SceneManager to update it when the base data has changed, and
 will calculate concatenated matrices etc only when required, passing back precalculated
 matrices when they are requested more than once when the underlying information has
 not altered.
 */
class AutoParamDataSource //: public SceneMgtAlloc
{
protected:
    Light getLight(size_t index)
    {
        // If outside light range, return a blank light to ensure zeroised for program
        if (/*mCurrentLightList &&*/ index < mCurrentLightList.length)
        {
            //return *((*mCurrentLightList)[index]);
            return mCurrentLightList[index];
        }
        else
        {
            return mBlankLight;
        }        
    }
    
    Matrix4[256] mWorldMatrix;
    size_t mWorldMatrixCount;
    Matrix4[] mWorldMatrixArray;
    Matrix4 mWorldViewMatrix;
    Matrix4 mViewProjMatrix;
    Matrix4 mWorldViewProjMatrix;
    Matrix4 mInverseWorldMatrix;
    Matrix4 mInverseWorldViewMatrix;
    Matrix4 mInverseViewMatrix;
    Matrix4 mInverseTransposeWorldMatrix;
    Matrix4 mInverseTransposeWorldViewMatrix;
    Vector4 mCameraPosition;
    Vector4 mCameraPositionObjectSpace;
    Matrix4[OGRE_MAX_SIMULTANEOUS_LIGHTS] mTextureViewProjMatrix;
    Matrix4[OGRE_MAX_SIMULTANEOUS_LIGHTS] mTextureWorldViewProjMatrix;
    Matrix4[OGRE_MAX_SIMULTANEOUS_LIGHTS] mSpotlightViewProjMatrix;
    Matrix4[OGRE_MAX_SIMULTANEOUS_LIGHTS] mSpotlightWorldViewProjMatrix;
    Vector4[OGRE_MAX_SIMULTANEOUS_LIGHTS] mShadowCamDepthRanges;
    Matrix4 mViewMatrix;
    Matrix4 mProjectionMatrix;
    Real mDirLightExtrusionDistance;
    Vector4 mLodCameraPosition;
    Vector4 mLodCameraPositionObjectSpace;
    
    bool mWorldMatrixDirty;
    bool mViewMatrixDirty;
    bool mProjMatrixDirty;
    bool mWorldViewMatrixDirty;
    bool mViewProjMatrixDirty;
    bool mWorldViewProjMatrixDirty;
    bool mInverseWorldMatrixDirty;
    bool mInverseWorldViewMatrixDirty;
    bool mInverseViewMatrixDirty;
    bool mInverseTransposeWorldMatrixDirty;
    bool mInverseTransposeWorldViewMatrixDirty;
    bool mCameraPositionDirty;
    bool mCameraPositionObjectSpaceDirty;
    bool[OGRE_MAX_SIMULTANEOUS_LIGHTS] mTextureViewProjMatrixDirty;
    bool[OGRE_MAX_SIMULTANEOUS_LIGHTS] mTextureWorldViewProjMatrixDirty;
    bool[OGRE_MAX_SIMULTANEOUS_LIGHTS] mSpotlightViewProjMatrixDirty;
    bool[OGRE_MAX_SIMULTANEOUS_LIGHTS] mSpotlightWorldViewProjMatrixDirty;
    bool[OGRE_MAX_SIMULTANEOUS_LIGHTS] mShadowCamDepthRangesDirty;
    ColourValue mAmbientLight;
    ColourValue mFogColour;
    Vector4 mFogParams;
    int mPassNumber;
    Vector4 mSceneDepthRange;
    bool mSceneDepthRangeDirty;
    bool mLodCameraPositionDirty;
    bool mLodCameraPositionObjectSpaceDirty;
    
    Renderable mCurrentRenderable;
    Camera mCurrentCamera;
    bool mCameraRelativeRendering;
    Vector3 mCameraRelativePosition;
    LightList mCurrentLightList;
    Frustum[OGRE_MAX_SIMULTANEOUS_LIGHTS] mCurrentTextureProjector;
    RenderTarget mCurrentRenderTarget;
    Viewport mCurrentViewport;
    SceneManager mCurrentSceneManager;
    VisibleObjectsBoundsInfo mMainCamBoundsInfo;
    Pass mCurrentPass;
    
    Light mBlankLight;
public:
    this()
    {
        mWorldMatrixDirty = true;
        mViewMatrixDirty = true;
        mProjMatrixDirty = true;
        mWorldViewMatrixDirty = true;
        mViewProjMatrixDirty = true;
        mWorldViewProjMatrixDirty = true;
        mInverseWorldMatrixDirty = true;
        mInverseWorldViewMatrixDirty = true;
        mInverseViewMatrixDirty = true;
        mInverseTransposeWorldMatrixDirty = true;
        mInverseTransposeWorldViewMatrixDirty = true;
        mCameraPositionDirty = true;
        mCameraPositionObjectSpaceDirty = true;
        mSceneDepthRangeDirty = true;
        mLodCameraPositionDirty = true;
        mLodCameraPositionObjectSpaceDirty = true;
        mCameraRelativeRendering = false;
        /*mCurrentRenderable = 0;
         mCurrentCamera = 0;
         mCurrentLightList = 0;
         mCurrentRenderTarget = 0;
         mCurrentViewport = 0;
         mCurrentSceneManager = 0;
         mMainCamBoundsInfo = 0;
         mCurrentPass = 0;*/
        mBlankLight = new Light;
        mBlankLight.setDiffuseColour(ColourValue.Black);
        mBlankLight.setSpecularColour(ColourValue.Black);
        mBlankLight.setAttenuation(0,1,0,0);
        for(size_t i = 0; i < OGRE_MAX_SIMULTANEOUS_LIGHTS; ++i)
        {
            mTextureViewProjMatrixDirty[i] = true;
            mTextureWorldViewProjMatrixDirty[i] = true;
            mSpotlightViewProjMatrixDirty[i] = true;
            mSpotlightWorldViewProjMatrixDirty[i] = true;
            mCurrentTextureProjector[i] = null;
            mShadowCamDepthRangesDirty[i] = false;
        }
        
    }
    
    ~this(){}
    
    /** Updates the current renderable */
    void setCurrentRenderable(Renderable rend)
    {
        mCurrentRenderable = rend;
        mWorldMatrixDirty = true;
        mViewMatrixDirty = true;
        mProjMatrixDirty = true;
        mWorldViewMatrixDirty = true;
        mViewProjMatrixDirty = true;
        mWorldViewProjMatrixDirty = true;
        mInverseWorldMatrixDirty = true;
        mInverseViewMatrixDirty = true;
        mInverseWorldViewMatrixDirty = true;
        mInverseTransposeWorldMatrixDirty = true;
        mInverseTransposeWorldViewMatrixDirty = true;
        mCameraPositionObjectSpaceDirty = true;
        mLodCameraPositionObjectSpaceDirty = true;
        for(size_t i = 0; i < OGRE_MAX_SIMULTANEOUS_LIGHTS; ++i)
        {
            mTextureWorldViewProjMatrixDirty[i] = true;
            mSpotlightWorldViewProjMatrixDirty[i] = true;
        }
        
    }
    
    /** Sets the world matrices, avoid query from renderable again */
    void setWorldMatrices(Matrix4[] m, size_t count)
    {
        mWorldMatrixArray = m;
        mWorldMatrixCount = count;
        mWorldMatrixDirty = false;
    }
    
    /** Updates the current camera */
    void setCurrentCamera(Camera cam, bool useCameraRelative)
    {
        mCurrentCamera = cam;
        mCameraRelativeRendering = useCameraRelative;
        mCameraRelativePosition = cam.getDerivedPosition();
        mViewMatrixDirty = true;
        mProjMatrixDirty = true;
        mWorldViewMatrixDirty = true;
        mViewProjMatrixDirty = true;
        mWorldViewProjMatrixDirty = true;
        mInverseViewMatrixDirty = true;
        mInverseWorldViewMatrixDirty = true;
        mInverseTransposeWorldViewMatrixDirty = true;
        mCameraPositionObjectSpaceDirty = true;
        mCameraPositionDirty = true;
        mLodCameraPositionObjectSpaceDirty = true;
        mLodCameraPositionDirty = true;
    }
    
    /** Sets the light list that should be used, and it's base index from the global list */
    void setCurrentLightList(LightList ll)
    {
        mCurrentLightList = ll;
        for(size_t i = 0; i < ll.length && i < OGRE_MAX_SIMULTANEOUS_LIGHTS; ++i)
        {
            mSpotlightViewProjMatrixDirty[i] = true;
            mSpotlightWorldViewProjMatrixDirty[i] = true;
        }
        
    }
    
    /** Sets the current texture projector for a index */
    void setTextureProjector(Frustum frust, size_t index = 0)
    {
        if (index < OGRE_MAX_SIMULTANEOUS_LIGHTS)
        {
            mCurrentTextureProjector[index] = frust;
            mTextureViewProjMatrixDirty[index] = true;
            mTextureWorldViewProjMatrixDirty[index] = true;
            mShadowCamDepthRangesDirty[index] = true;
        }
        
    }
    
    /** Sets the current render target */
    void setCurrentRenderTarget(RenderTarget target)
    {
        mCurrentRenderTarget = target;
    }
    /** Sets the current viewport */
    void setCurrentViewport(Viewport viewport)
    {
        mCurrentViewport = viewport;
    }
    /** Sets the shadow extrusion distance to be used for point lights. */
    void setShadowDirLightExtrusionDistance(Real dist)
    {
        mDirLightExtrusionDistance = dist;
    }
    /** Sets the main camera's scene bounding information */
    void setMainCamBoundsInfo(ref VisibleObjectsBoundsInfo info)
    {
        mMainCamBoundsInfo = info;
        mSceneDepthRangeDirty = true;
    }
    
    /** Set the current scene manager for enquiring on demand */
    void setCurrentSceneManager(SceneManager sm)
    {
        mCurrentSceneManager = sm;
    }
    
    /** Sets the current pass */
    void setCurrentPass(Pass pass)
    {
        mCurrentPass = pass;
    }
    
    
    
    ref Matrix4 getWorldMatrix()
    {
        if (mWorldMatrixDirty)
        {
            mWorldMatrixArray = mWorldMatrix;
            //FIXME fixme? Matrix4[256] to Matrix4[] and back
            Matrix4[] tmp;
            mCurrentRenderable.getWorldTransforms(tmp);
            mWorldMatrix[0..tmp.length] = tmp;

            mWorldMatrixCount = mCurrentRenderable.getNumWorldTransforms();
            if (mCameraRelativeRendering)
            {
                for (size_t i = 0; i < mWorldMatrixCount; ++i)
                {
                    mWorldMatrix[i].setTrans(mWorldMatrix[i].getTrans() - mCameraRelativePosition);
                }
            }
            mWorldMatrixDirty = false;
        }
        return mWorldMatrixArray[0];
    }
    
    ref Matrix4[] getWorldMatrixArray()
    {
        // trigger derivation
        getWorldMatrix();
        return mWorldMatrixArray;
    }
    
    size_t getWorldMatrixCount()
    {
        // trigger derivation
        getWorldMatrix();
        return mWorldMatrixCount;
    }
    
    ref Matrix4 getViewMatrix()
    {
        if (mViewMatrixDirty)
        {
            if (mCurrentRenderable && mCurrentRenderable.getUseIdentityView())
                mViewMatrix = Matrix4.IDENTITY;
            else
            {
                mViewMatrix = mCurrentCamera.getViewMatrix(true);
                if (mCameraRelativeRendering)
                {
                    mViewMatrix.setTrans(Vector3.ZERO);
                }
                
            }
            mViewMatrixDirty = false;
        }
        return mViewMatrix;
    }
    
    ref Matrix4 getViewProjectionMatrix()
    {
        if (mViewProjMatrixDirty)
        {
            mViewProjMatrix = getProjectionMatrix() * getViewMatrix();
            mViewProjMatrixDirty = false;
        }
        return mViewProjMatrix;
    }
    
    ref Matrix4 getProjectionMatrix()
    {
        if (mProjMatrixDirty)
        {
            // NB use API-independent projection matrix since GPU programs
            // bypass the API-specific handedness and use right-handed coords
            if (mCurrentRenderable && mCurrentRenderable.getUseIdentityProjection())
            {
                // Use identity projection matrix, still need to take RS depth into account.
                RenderSystem rs = Root.getSingleton().getRenderSystem();
                rs._convertProjectionMatrix(Matrix4.IDENTITY, mProjectionMatrix, true);
            }
            else
            {
                mProjectionMatrix = mCurrentCamera.getProjectionMatrixWithRSDepth();
            }
            if (mCurrentRenderTarget && mCurrentRenderTarget.requiresTextureFlipping())
            {
                // Because we're not using setProjectionMatrix, this needs to be done here
                // Invert transformed y
                mProjectionMatrix[1, 0] = -mProjectionMatrix[1][0];
                mProjectionMatrix[1, 1] = -mProjectionMatrix[1][1];
                mProjectionMatrix[1, 2] = -mProjectionMatrix[1][2];
                mProjectionMatrix[1, 3] = -mProjectionMatrix[1][3];
            }
            mProjMatrixDirty = false;
        }
        return mProjectionMatrix;
    }
    
    ref Matrix4 getWorldViewProjMatrix()
    {
        if (mWorldViewProjMatrixDirty)
        {
            mWorldViewProjMatrix = getProjectionMatrix() * getWorldViewMatrix();
            mWorldViewProjMatrixDirty = false;
        }
        return mWorldViewProjMatrix;
    }
    
    ref Matrix4 getWorldViewMatrix()
    {
        if (mWorldViewMatrixDirty)
        {
            mWorldViewMatrix = getViewMatrix().concatenateAffine(getWorldMatrix());
            mWorldViewMatrixDirty = false;
        }
        return mWorldViewMatrix;
    }
    
    ref Matrix4 getInverseWorldMatrix()
    {
        if (mInverseWorldMatrixDirty)
        {
            mInverseWorldMatrix = getWorldMatrix().inverseAffine();
            mInverseWorldMatrixDirty = false;
        }
        return mInverseWorldMatrix;
    }
    
    ref Matrix4 getInverseWorldViewMatrix()
    {
        if (mInverseWorldViewMatrixDirty)
        {
            mInverseWorldViewMatrix = getWorldViewMatrix().inverseAffine();
            mInverseWorldViewMatrixDirty = false;
        }
        return mInverseWorldViewMatrix;
    }
    
    ref Matrix4 getInverseViewMatrix()
    {
        if (mInverseViewMatrixDirty)
        {
            mInverseViewMatrix = getViewMatrix().inverseAffine();
            mInverseViewMatrixDirty = false;
        }
        return mInverseViewMatrix;
    }
    
    ref Matrix4 getInverseTransposeWorldMatrix()
    {
        if (mInverseTransposeWorldMatrixDirty)
        {
            mInverseTransposeWorldMatrix = getInverseWorldMatrix().transpose();
            mInverseTransposeWorldMatrixDirty = false;
        }
        return mInverseTransposeWorldMatrix;
    }
    
    ref Matrix4 getInverseTransposeWorldViewMatrix()
    {
        if (mInverseTransposeWorldViewMatrixDirty)
        {
            mInverseTransposeWorldViewMatrix = getInverseWorldViewMatrix().transpose();
            mInverseTransposeWorldViewMatrixDirty = false;
        }
        return mInverseTransposeWorldViewMatrix;
    }
    
    Vector4 getCameraPosition()
    {
        if(mCameraPositionDirty)
        {
            Vector3 vec3 = mCurrentCamera.getDerivedPosition();
            if (mCameraRelativeRendering)
            {
                vec3 -= mCameraRelativePosition;
            }
            mCameraPosition[0] = vec3[0];
            mCameraPosition[1] = vec3[1];
            mCameraPosition[2] = vec3[2];
            mCameraPosition[3] = 1.0;
            mCameraPositionDirty = false;
        }
        return mCameraPosition;
    }
    
    Vector4 getCameraPositionObjectSpace()
    {
        if (mCameraPositionObjectSpaceDirty)
        {
            if (mCameraRelativeRendering)
            {
                mCameraPositionObjectSpace = 
                    getInverseWorldMatrix().transformAffine(Vector3.ZERO);
            }
            else
            {
                mCameraPositionObjectSpace = 
                    getInverseWorldMatrix().transformAffine(mCurrentCamera.getDerivedPosition());
            }
            mCameraPositionObjectSpaceDirty = false;
        }
        return mCameraPositionObjectSpace;
    }
    
    Vector4 getLodCameraPosition()
    {
        if(mLodCameraPositionDirty)
        {
            Vector3 vec3 = mCurrentCamera.getLodCamera().getDerivedPosition();
            if (mCameraRelativeRendering)
            {
                vec3 -= mCameraRelativePosition;
            }
            mLodCameraPosition[0] = vec3[0];
            mLodCameraPosition[1] = vec3[1];
            mLodCameraPosition[2] = vec3[2];
            mLodCameraPosition[3] = 1.0;
            mLodCameraPositionDirty = false;
        }
        return mLodCameraPosition;
    }
    
    Vector4 getLodCameraPositionObjectSpace()
    {
        if (mLodCameraPositionObjectSpaceDirty)
        {
            if (mCameraRelativeRendering)
            {
                mLodCameraPositionObjectSpace = 
                    getInverseWorldMatrix().transformAffine(mCurrentCamera.getLodCamera().getDerivedPosition()
                                                            - mCameraRelativePosition);
            }
            else
            {
                mLodCameraPositionObjectSpace = 
                    getInverseWorldMatrix().transformAffine(mCurrentCamera.getLodCamera().getDerivedPosition());
            }
            mLodCameraPositionObjectSpaceDirty = false;
        }
        return mLodCameraPositionObjectSpace;
    }
    
    bool hasLightList(){ return mCurrentLightList.length != 0; }
    
    /** Get the light which is 'index'th closest to the current object */
    float getLightNumber(size_t index)
    {
        return cast(float)(getLight(index)._getIndexInFrame());
    }
    
    float getLightCount()
    {
        return cast(float)(mCurrentLightList.length);
    }
    
    float getLightCastsShadows(size_t index)
    {
        return getLight(index).getCastShadows() ? 1.0f : 0.0f;
    }
    
    ColourValue getLightDiffuseColour(size_t index)
    {
        return getLight(index).getDiffuseColour();
    }
    
    ColourValue getLightSpecularColour(size_t index)
    {
        return getLight(index).getSpecularColour();
    }
    
    ColourValue getLightDiffuseColourWithPower(size_t index)
    {
        Light l = getLight(index);
        auto scaled = l.getDiffuseColour();
        Real power = l.getPowerScale();
        // scale, but not alpha
        scaled.r *= power;
        scaled.g *= power;
        scaled.b *= power;
        return scaled;
    }
    
    ColourValue getLightSpecularColourWithPower(size_t index)
    {
        Light l = getLight(index);
        ColourValue scaled = l.getSpecularColour();
        Real power = l.getPowerScale();
        // scale, but not alpha
        scaled.r *= power;
        scaled.g *= power;
        scaled.b *= power;
        return scaled;
    }
    
    Vector3 getLightPosition(size_t index)
    {
        return getLight(index).getDerivedPosition(true);
    }
    
    Vector4 getLightAs4DVector(size_t index)
    {
        return getLight(index).getAs4DVector(true);
    }
    
    Vector3 getLightDirection(size_t index)
    {
        return getLight(index).getDerivedDirection();
    }
    
    Real getLightPowerScale(size_t index)
    {
        return getLight(index).getPowerScale();
    }
    
    Vector4 getLightAttenuation(size_t index)
    {
        // range,, linear, quad
        Light l = getLight(index);
        return Vector4(l.getAttenuationRange(),
                       l.getAttenuationConstant(),
                       l.getAttenuationLinear(),
                       l.getAttenuationQuadric());
    }
    
    Vector4 getSpotlightParams(size_t index)
    {
        // inner, outer, fallof, isSpot
        Light l = getLight(index);
        if (l.getType() == Light.LightTypes.LT_SPOTLIGHT)
        {
            return Vector4(Math.Cos(l.getSpotlightInnerAngle().valueRadians() * 0.5f),
                           Math.Cos(l.getSpotlightOuterAngle().valueRadians() * 0.5f),
                           l.getSpotlightFalloff(),
                           1.0);
        }
        else
        {
            // Use safe values which result in no change to point & dir light calcs
            // The spot factor applied to the usual lighting calc is 
            // pow((dot(spotDir, lightDir) - y) / (x - y), z)
            // Therefore if we set z to 0.0f then the factor will always be 1
            // since pow(anything, 0) == 1
            // However we also need to ensure we don't overflow because of the division
            // Therefore set x = 1 and y = 0 so divisor doesn't change scale
            return Vector4(1.0, 0.0, 0.0, 1.0); // since the main op is pow(.., vec4.z), this will result in 1.0
        }
    }
    
    void setAmbientLightColour(ColourValue ambient)
    {
        mAmbientLight = ambient;
    }
    
    ColourValue getAmbientLightColour()
    {
        return mAmbientLight;
    }
    
    ColourValue getSurfaceAmbientColour()
    {
        return mCurrentPass.getAmbient();
    }
    
    ColourValue getSurfaceDiffuseColour()
    {
        return mCurrentPass.getDiffuse();
    }
    
    ColourValue getSurfaceSpecularColour()
    {
        return mCurrentPass.getSpecular();
    }
    
    ColourValue getSurfaceEmissiveColour()
    {
        return mCurrentPass.getSelfIllumination();
    }
    
    Real getSurfaceShininess()
    {
        return mCurrentPass.getShininess();
    }
    
    Real getSurfaceAlphaRejectionValue() const
    {
        return cast(Real)(mCurrentPass.getAlphaRejectValue()) / 255.0f;
    }
    
    ColourValue getDerivedAmbientLightColour()
    {
        return getAmbientLightColour() * getSurfaceAmbientColour();
    }
    
    ColourValue getDerivedSceneColour()
    {
        ColourValue result = getDerivedAmbientLightColour() + getSurfaceEmissiveColour();
        result.a = getSurfaceDiffuseColour().a;
        return result;
    }
    
    void setFog(FogMode mode,ColourValue colour, Real expDensity, Real linearStart, Real linearEnd)
    {
        //()mode; // ignored
        mFogColour = colour;
        mFogParams.x = expDensity;
        mFogParams.y = linearStart;
        mFogParams.z = linearEnd;
        mFogParams.w = linearEnd != linearStart ? 1 / (linearEnd - linearStart) : 0;
    }
    
    ColourValue getFogColour()
    {
        return mFogColour;
    }
    
    Vector4 getFogParams()
    {
        return mFogParams;
    }
    
    Matrix4 getTextureViewProjMatrix(size_t index)
    {
        if (index < OGRE_MAX_SIMULTANEOUS_LIGHTS)
        {
            if (mTextureViewProjMatrixDirty[index] && mCurrentTextureProjector[index])
            {
                if (mCameraRelativeRendering)
                {
                    // World positions are now going to be relative to the camera position
                    // so we need to alter the projector view matrix to compensate
                    Matrix4 viewMatrix;
                    mCurrentTextureProjector[index].calcViewMatrixRelative(
                        mCurrentCamera.getDerivedPosition(), viewMatrix);
                    mTextureViewProjMatrix[index] = 
                        PROJECTIONCLIPSPACE2DTOIMAGESPACE_PERSPECTIVE * 
                            mCurrentTextureProjector[index].getProjectionMatrixWithRSDepth() * 
                            viewMatrix;
                }
                else
                {
                    mTextureViewProjMatrix[index] = 
                        PROJECTIONCLIPSPACE2DTOIMAGESPACE_PERSPECTIVE * 
                            mCurrentTextureProjector[index].getProjectionMatrixWithRSDepth() * 
                            mCurrentTextureProjector[index].getViewMatrix();
                }
                mTextureViewProjMatrixDirty[index] = false;
            }
            return mTextureViewProjMatrix[index];
        }
        else
            return Matrix4.IDENTITY;
    }
    
    Matrix4 getTextureWorldViewProjMatrix(size_t index)
    {
        if (index < OGRE_MAX_SIMULTANEOUS_LIGHTS)
        {
            if (mTextureWorldViewProjMatrixDirty[index] && mCurrentTextureProjector[index])
            {
                mTextureWorldViewProjMatrix[index] = 
                    getTextureViewProjMatrix(index) * getWorldMatrix();
                mTextureWorldViewProjMatrixDirty[index] = false;
            }
            return mTextureWorldViewProjMatrix[index];
        }
        else
            return Matrix4.IDENTITY;
    }
    
    Matrix4 getSpotlightViewProjMatrix(size_t index)
    {
        if (index < OGRE_MAX_SIMULTANEOUS_LIGHTS)
        {
            Light l = getLight(index);
            
            if (l != mBlankLight && 
                l.getType() == Light.LightTypes.LT_SPOTLIGHT &&
                mSpotlightViewProjMatrixDirty[index])
            {
                auto frust = new Frustum;
                auto dummyNode = new SceneNode(null);
                dummyNode.attachObject(frust);
                
                frust.setProjectionType(ProjectionType.PT_PERSPECTIVE);
                frust.setFOVy(l.getSpotlightOuterAngle());
                frust.setAspectRatio(1.0f);
                // set near clip the same as main camera, since they are likely
                // to both reflect the nature of the scene
                frust.setNearClipDistance(mCurrentCamera.getNearClipDistance());
                // Calculate position, which same as spotlight position, in camera-relative coords if required
                dummyNode.setPosition(l.getDerivedPosition(true));
                // Calculate direction, which same as spotlight direction
                Vector3 dir = - l.getDerivedDirection(); // backwards since point down -z
                dir.normalise();
                Vector3 up = Vector3.UNIT_Y;
                // Check it's not coincident with dir
                if (Math.Abs(up.dotProduct(dir)) >= 1.0f)
                {
                    // Use camera up
                    up = Vector3.UNIT_Z;
                }
                // cross twice to rederive, only direction is unaltered
                Vector3 left = dir.crossProduct(up);
                left.normalise();
                up = dir.crossProduct(left);
                up.normalise();
                // Derive quaternion from axes
                Quaternion q;
                q.FromAxes(left, up, dir);
                dummyNode.setOrientation(q);
                
                // The view matrix here already includes camera-relative changes if necessary
                // since they are built into the frustum position
                mSpotlightViewProjMatrix[index] = 
                    PROJECTIONCLIPSPACE2DTOIMAGESPACE_PERSPECTIVE * 
                        frust.getProjectionMatrixWithRSDepth() * 
                        frust.getViewMatrix();
                
                mSpotlightViewProjMatrixDirty[index] = false;
            }
            return mSpotlightViewProjMatrix[index];
        }
        else
            return Matrix4.IDENTITY;
    }
    
    Matrix4 getSpotlightWorldViewProjMatrix(size_t index)
    {
        if (index < OGRE_MAX_SIMULTANEOUS_LIGHTS)
        {
            Light l = getLight(index);
            
            if (l != mBlankLight && 
                l.getType() == Light.LightTypes.LT_SPOTLIGHT &&
                mSpotlightWorldViewProjMatrixDirty[index])
            {
                mSpotlightWorldViewProjMatrix[index] = 
                    getSpotlightViewProjMatrix(index) * getWorldMatrix();
                mSpotlightWorldViewProjMatrixDirty[index] = false;
            }
            return mSpotlightWorldViewProjMatrix[index];
        }
        else
            return Matrix4.IDENTITY;
    }
    
    Matrix4 getTextureTransformMatrix(size_t index)
    {
        // make sure the current pass is set
        assert(mCurrentPass, "current pass is NULL!");
        // check if there is a texture unit with the given index in the current pass
        if(index < mCurrentPass.getNumTextureUnitStates())
        {
            // texture unit existent, return its currently set transform
            return mCurrentPass.getTextureUnitState(cast(ushort)(index)).getTextureTransform();
        }
        else
        {
            // no such texture unit, return unity
            return Matrix4.IDENTITY;
        }
    }
    
    ref RenderTarget getCurrentRenderTarget()
    {
        return mCurrentRenderTarget;
    }
    
    ref Renderable getCurrentRenderable()
    {
        return mCurrentRenderable;
    }
    
    ref Pass getCurrentPass()
    {
        return mCurrentPass;
    }
    
    Vector4 getTextureSize(size_t index)
    {
        Vector4 size = Vector4(1,1,1,1);
        
        if (index < mCurrentPass.getNumTextureUnitStates())
        {
            SharedPtr!Texture tex = mCurrentPass.getTextureUnitState(
                cast(ushort)(index))._getTexturePtr();
            if (!tex.isNull())
            {
                size.x = cast(Real)(tex.getAs().getWidth());
                size.y = cast(Real)(tex.getAs().getHeight());
                size.z = cast(Real)(tex.getAs().getDepth());
            }
        }
        
        return size;
    }
    
    Vector4 getInverseTextureSize(size_t index)
    {
        Vector4 size = getTextureSize(index);
        return 1 / size;
    }
    
    Vector4 getPackedTextureSize(size_t index)
    {
        Vector4 size = getTextureSize(index);
        return Vector4(size.x, size.y, 1 / size.x, 1 / size.y);
    }
    
    Real getShadowExtrusionDistance()
    {
        Light l = getLight(0); // only ever applies to one light at once
        if (l.getType() == Light.LightTypes.LT_DIRECTIONAL)
        {
            // use constant
            return mDirLightExtrusionDistance;
        }
        else
        {
            // Calculate based on object space light distance
            // compared to light attenuation range
            Vector3 objPos = getInverseWorldMatrix().transformAffine(l.getDerivedPosition(true));
            return l.getAttenuationRange() - objPos.length();
        }
    }
    
    Vector4 getSceneDepthRange()
    {
        static Vector4 dummy = Vector4(0, 100000, 100000, 1/100000);
        
        if (mSceneDepthRangeDirty)
        {
            // calculate depth information
            Real depthRange = mMainCamBoundsInfo.maxDistanceInFrustum - mMainCamBoundsInfo.minDistanceInFrustum;
            if (depthRange > Real.epsilon)
            {
                mSceneDepthRange = Vector4(
                    mMainCamBoundsInfo.minDistanceInFrustum,
                    mMainCamBoundsInfo.maxDistanceInFrustum,
                    depthRange,
                    1.0f / depthRange);
            }
            else
            {
                mSceneDepthRange = dummy;
            }
            mSceneDepthRangeDirty = false;
        }
        
        return mSceneDepthRange;
        
    }
    
    Vector4 getShadowSceneDepthRange(size_t index)
    {
        static Vector4 dummy = Vector4(0, 100000, 100000, 1/100000);
        
        if (!mCurrentSceneManager.isShadowTechniqueTextureBased())
            return dummy;
        
        if (index < OGRE_MAX_SIMULTANEOUS_LIGHTS)
        {
            if (mShadowCamDepthRangesDirty[index] && mCurrentTextureProjector[index])
            {
                VisibleObjectsBoundsInfo info = 
                    mCurrentSceneManager.getVisibleObjectsBoundsInfo(cast(Camera)mCurrentTextureProjector[index]);
                
                Real depthRange = info.maxDistanceInFrustum - info.minDistanceInFrustum;
                if (depthRange > Real.epsilon)
                {
                    mShadowCamDepthRanges[index] = Vector4(
                        info.minDistanceInFrustum,
                        info.maxDistanceInFrustum,
                        depthRange,
                        1.0f / depthRange);
                }
                else
                {
                    mShadowCamDepthRanges[index] = dummy;
                }
                
                mShadowCamDepthRangesDirty[index] = false;
            }
            return mShadowCamDepthRanges[index];
        }
        else
            return dummy;
    }
    
    ColourValue getShadowColour()
    {
        return mCurrentSceneManager.getShadowColour();
    }
    
    Matrix4 getInverseViewProjMatrix()
    {
        return this.getViewProjectionMatrix().inverse();
    }
    
    Matrix4 getInverseTransposeViewProjMatrix()
    {
        return this.getInverseViewProjMatrix().transpose();
    }
    
    Matrix4 getTransposeViewProjMatrix()
    {
        return this.getViewProjectionMatrix().transpose();
    }
    
    Matrix4 getTransposeViewMatrix()
    {
        return this.getViewMatrix().transpose();
    }
    
    Matrix4 getInverseTransposeViewMatrix()
    {
        return this.getInverseViewMatrix().transpose();
    }
    
    Matrix4 getTransposeProjectionMatrix()
    {
        return this.getProjectionMatrix().transpose();
    }
    
    Matrix4 getInverseProjectionMatrix()
    {
        return this.getProjectionMatrix().inverse();
    }
    
    Matrix4 getInverseTransposeProjectionMatrix()
    {
        return this.getInverseProjectionMatrix().transpose();
    }
    
    Matrix4 getTransposeWorldViewProjMatrix()
    {
        return this.getWorldViewProjMatrix().transpose();
    }
    
    Matrix4 getInverseWorldViewProjMatrix()
    {
        return this.getWorldViewProjMatrix().inverse();
    }
    
    Matrix4 getInverseTransposeWorldViewProjMatrix()
    {
        return this.getInverseWorldViewProjMatrix().transpose();
    }
    
    Matrix4 getTransposeWorldViewMatrix()
    {
        return this.getWorldViewMatrix().transpose();
    }
    
    Matrix4 getTransposeWorldMatrix()
    {
        return this.getWorldMatrix().transpose();
    }
    
    Real getTime()
    {
        return ControllerManager.getSingleton().getElapsedTime();
    }
    
    Real getTime_0_X(Real x)
    {
        return fmod(this.getTime(), x);
    }
    
    Real getCosTime_0_X(Real x)
    { 
        return cos(this.getTime_0_X(x)); 
    }
    
    Real getSinTime_0_X(Real x)
    { 
        return sin(this.getTime_0_X(x)); 
    }
    
    Real getTanTime_0_X(Real x)
    { 
        return tan(this.getTime_0_X(x)); 
    }
    
    Vector4 getTime_0_X_packed(Real x)
    {
        Real t = this.getTime_0_X(x);
        return Vector4(t, sin(t), cos(t), tan(t));
    }
    
    Real getTime_0_1(Real x)
    { 
        return this.getTime_0_X(x)/x; 
    }
    
    Real getCosTime_0_1(Real x)
    { 
        return cos(this.getTime_0_1(x)); 
    }
    
    Real getSinTime_0_1(Real x)
    { 
        return sin(this.getTime_0_1(x)); 
    }
    
    Real getTanTime_0_1(Real x)
    { 
        return tan(this.getTime_0_1(x)); 
    }
    
    Vector4 getTime_0_1_packed(Real x)
    {
        Real t = this.getTime_0_1(x);
        return Vector4(t, sin(t), cos(t), tan(t));
    }
    
    Real getTime_0_2Pi(Real x)
    { 
        return this.getTime_0_X(x)/x*2*Math.PI; 
    }
    
    Real getCosTime_0_2Pi(Real x)
    { 
        return cos(this.getTime_0_2Pi(x)); 
    }
    
    Real getSinTime_0_2Pi(Real x)
    { 
        return sin(this.getTime_0_2Pi(x)); 
    }
    
    Real getTanTime_0_2Pi(Real x)
    { 
        return tan(this.getTime_0_2Pi(x)); 
    }
    
    Vector4 getTime_0_2Pi_packed(Real x)
    {
        Real t = this.getTime_0_2Pi(x);
        return Vector4(t, sin(t), cos(t), tan(t));
    }
    
    Real getFrameTime()
    {
        return ControllerManager.getSingleton().getFrameTimeSource().get().getValue();
    }
    
    Real getFPS()
    {
        return mCurrentRenderTarget.getLastFPS();
    }
    
    Real getViewportWidth()
    { 
        return cast(Real)(mCurrentViewport.getActualWidth()); 
    }
    
    Real getViewportHeight()
    { 
        return cast(Real)(mCurrentViewport.getActualHeight()); 
    }
    
    Real getInverseViewportWidth()
    { 
        return 1.0f/mCurrentViewport.getActualWidth(); 
    }
    
    Real getInverseViewportHeight()
    { 
        return 1.0f/mCurrentViewport.getActualHeight(); 
    }
    
    Vector3 getViewDirection()
    {
        return mCurrentCamera.getDerivedDirection();
    }
    
    Vector3 getViewSideVector()
    { 
        return mCurrentCamera.getDerivedRight();
    }
    
    Vector3 getViewUpVector()
    { 
        return mCurrentCamera.getDerivedUp();
    }
    
    Real getFOV()
    { 
        return mCurrentCamera.getFOVy().valueRadians(); 
    }
    
    Real getNearClipDistance()
    { 
        return mCurrentCamera.getNearClipDistance(); 
    }
    
    Real getFarClipDistance()
    { 
        return mCurrentCamera.getFarClipDistance(); 
    }
    
    int getPassNumber()
    {
        return mPassNumber;
    }
    
    void setPassNumber(int passNumber)
    {
        mPassNumber = passNumber;
    }
    
    void incPassNumber()
    {
        ++mPassNumber;
    }
    
    void updateLightCustomGpuParameter(GpuProgramParameters.AutoConstantEntry constantEntry, ref GpuProgramParameters params)
    {
        ushort lightIndex = cast(ushort)(constantEntry.data & 0xFFFF),
            paramIndex = cast(ushort)((constantEntry.data >> 16) & 0xFFFF);
        if(/*mCurrentLightList &&*/ lightIndex < mCurrentLightList.length)
        {
            Light light = getLight(lightIndex);
            light._updateCustomGpuParameter(paramIndex, constantEntry, params);
        }
    }
}

/** @} */
/** @} */