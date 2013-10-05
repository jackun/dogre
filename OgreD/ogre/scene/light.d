module ogre.scene.light;

import ogre.compat;
import ogre.general.colourvalue;
import ogre.math.maths;
import ogre.math.angles;
import ogre.math.axisalignedbox;
import ogre.math.plane;
import ogre.animation.animable;
import ogre.scene.shadowcamera;
import ogre.math.sphere;
import ogre.rendersystem.renderqueue;
import ogre.math.frustum;
import ogre.math.quaternion;
import ogre.strings;
import ogre.scene.movableobject;
import ogre.math.vector;
import ogre.scene.node;
import ogre.scene.camera;
import ogre.scene.renderable;

/** Representation of a dynamic light source in the scene.
 @remarks
 Lights are added to the scene like any other object. They contain various
 parameters like type, position, attenuation (how light intensity fades with
 distance), colour etc.
 @par
 The defaults when a light is created is pure white diffuse light, with no
 attenuation (does not decrease with distance) and a range of 1000 world units.
 @par
 Lights are created by using the SceneManager.createLight method. They can subsequently be
 added to a SceneNode if required to allow them to move relative to a node in the scene. A light attached
 to a SceneNode is assumed to have a base position of (0,0,0) and a direction of (0,0,1) before modification
 by the SceneNode's own orientation. If not attached to a SceneNode,
 the light's position and direction is as set using setPosition and setDirection.
 @par
 Remember also that dynamic lights rely on modifying the colour of vertices based on the position of
 the light compared to an object's vertex normals. Dynamic lighting will only look good if the
 object being lit has a fair level of tessellation and the normals are properly set. This is particularly
 true for the spotlight which will only look right on highly tessellated models. In the future OGRE may be
 extended for certain scene types so an alternative to the standard dynamic lighting may be used, such
 as dynamic lightmaps.
 */
class Light : MovableObject
{
public:
    /// Temp tag used for sorting
    Real tempSquareDist;
    /// internal method for calculating current squared distance from some world position
    void _calcTempSquareDist(Vector3 worldPos)
    {
        if (mLightType == LightTypes.LT_DIRECTIONAL)
        {
            tempSquareDist = 0;
        }
        else
        {
            tempSquareDist = 
                (worldPos - getDerivedPosition()).squaredLength();
        }
        
    }
    
    /// Defines the type of light
    enum LightTypes
    {
        /// Point light sources give off light equally in all directions, so require only position not direction
        LT_POINT = 0,
        /// Directional lights simulate parallel light beams from a distant source, hence have direction but no position
        LT_DIRECTIONAL = 1,
        /// Spotlights simulate a cone of light from a source so require position and direction, plus extra values for falloff
        LT_SPOTLIGHT = 2
    }
    
    /** Default consructor (for Python mainly).
     */
    this()
    {
        mLightType = LightTypes.LT_POINT;
        mPosition = Vector3.ZERO;
        mDiffuse = ColourValue.White;
        mSpecular = ColourValue.Black;
        mDirection = Vector3.UNIT_Z;
        mSpotOuter = Degree (40.0f);
        mSpotInner = Degree (30.0f);
        mSpotFalloff = 1.0f;
        mSpotNearClip = 0.0f;
        mRange = 100000;
        mAttenuationConst = 1.0f;
        mAttenuationLinear = 0.0f;
        mAttenuationQuad = 0.0f;
        mPowerScale = 1.0f;
        mIndexInFrame = 0;
        mOwnShadowFarDist = false;
        mShadowFarDist = 0;
        mShadowFarDistSquared = 0;
        mShadowNearClipDist = -1;
        mShadowFarClipDist = -1;
        mDerivedPosition = Vector3.ZERO;
        mDerivedDirection = Vector3.UNIT_Z;
        mDerivedCamRelativePosition = Vector3.ZERO;
        mDerivedCamRelativeDirty = false;
        //mCameraToBeRetiveTo = null;
        mDerivedTransformDirty = false;
        //TODO mCustomShadowCameraSetup()
        mCustomShadowCameraSetup = new DefaultShadowCameraSetup();
        
        //mMinPixelSize should always be zero for lights otherwise lights will disapear
        mMinPixelSize = 0;
    }
    
    /** Normal constructor. Should not be called directly, but rather the SceneManager.createLight method should be used.
     */
    this(string name)
    {
        super(name);
        //this(); // Error multiple ctor calls :(
        mLightType = LightTypes.LT_POINT;
        mPosition = Vector3.ZERO;
        mDiffuse = ColourValue.White;
        mSpecular = ColourValue.Black;
        mDirection = Vector3.UNIT_Z;
        mSpotOuter = Degree (40.0f);
        mSpotInner = Degree (30.0f);
        mSpotFalloff = 1.0f;
        mSpotNearClip = 0.0f;
        mRange = 100000;
        mAttenuationConst = 1.0f;
        mAttenuationLinear = 0.0f;
        mAttenuationQuad = 0.0f;
        mPowerScale = 1.0f;
        mIndexInFrame = 0;
        mOwnShadowFarDist = false;
        mShadowFarDist = 0;
        mShadowFarDistSquared = 0;
        mShadowNearClipDist = -1;
        mShadowFarClipDist = -1;
        mDerivedPosition = Vector3.ZERO;
        mDerivedDirection = Vector3.UNIT_Z;
        mDerivedCamRelativePosition = Vector3.ZERO;
        mDerivedCamRelativeDirty = false;
        //mCameraToBeRelativeTo = null;
        mDerivedTransformDirty = false;
        //TODO mCustomShadowCameraSetup()
        mCustomShadowCameraSetup = new DefaultShadowCameraSetup;
        
        //mMinPixelSize should always be zero for lights otherwise lights will disapear
        mMinPixelSize = 0;
    }
    
    /** Standard destructor.
     */
    ~this(){}
    
    /** Sets the type of light - see LightTypes for more info.
     */
    void setType(LightTypes type)
    {
        mLightType = type;
    }
    
    /** Returns the light type.
     */
    LightTypes getType()
    {
        return mLightType;
    }
    
    /** Sets the colour of the diffuse light given off by this source.
     @remarks
     Material objects have ambient, diffuse and specular values which indicate how much of each type of
     light an object reflects. This value denotes the amount and colour of this type of light the light
     exudes into the scene. The actual appearance of objects is a combination of the two.
     @par
     Diffuse light simulates the typical light emanating from light sources and affects the base colour
     of objects together with ambient light.
     */
    void setDiffuseColour(Real red, Real green, Real blue)
    {
        mDiffuse.r = red;
        mDiffuse.b = blue;
        mDiffuse.g = green;
    }
    
    /** Sets the colour of the diffuse light given off by this source.
     @remarks
     Material objects have ambient, diffuse and specular values which indicate how much of each type of
     light an object reflects. This value denotes the amount and colour of this type of light the light
     exudes into the scene. The actual appearance of objects is a combination of the two.
     @par
     Diffuse light simulates the typical light emanating from light sources and affects the base colour
     of objects together with ambient light.
     */
    void setDiffuseColour(ColourValue colour)
    {
        mDiffuse = colour;
    }
    
    /** Returns the colour of the diffuse light given off by this light source (see setDiffuseColour for more info).
     */
    ColourValue getDiffuseColour()
    {
        return mDiffuse;
    }
    
    /** Sets the colour of the specular light given off by this source.
     @remarks
     Material objects have ambient, diffuse and specular values which indicate how much of each type of
     light an object reflects. This value denotes the amount and colour of this type of light the light
     exudes into the scene. The actual appearance of objects is a combination of the two.
     @par
     Specular light affects the appearance of shiny highlights on objects, and is also dependent on the
     'shininess' Material value.
     */
    void setSpecularColour(Real red, Real green, Real blue)
    {
        mSpecular.r = red;
        mSpecular.b = blue;
        mSpecular.g = green;
    }
    
    /** Sets the colour of the specular light given off by this source.
     @remarks
     Material objects have ambient, diffuse and specular values which indicate how much of each type of
     light an object reflects. This value denotes the amount and colour of this type of light the light
     exudes into the scene. The actual appearance of objects is a combination of the two.
     @par
     Specular light affects the appearance of shiny highlights on objects, and is also dependent on the
     'shininess' Material value.
     */
    void setSpecularColour(ColourValue colour)
    {
        mSpecular = colour;
    }
    
    /** Returns the colour of specular light given off by this light source.
     */
    ColourValue getSpecularColour()
    {
        return mSpecular;
    }
    
    /** Sets the attenuation parameters of the light source i.e. how it diminishes with distance.
     @remarks
     Lights normally get fainter the further they are away. Also, each light is given a maximum range
     beyond which it cannot affect any objects.
     @par
     Light attenuation is not applicable to directional lights since they have an infinite range and
     ant intensity.
     @par
     This follows a standard attenuation approach - see any good 3D text for the details of what they mean
     since i don't have room here!
     @param range
     The absolute upper range of the light in world units.
     @param constant
     The constant factor in the attenuation formula: 1.0 means never attenuate, 0.0 is complete attenuation.
     @param linear
     The linear factor in the attenuation formula: 1 means attenuate evenly over the distance.
     @param quadratic
     The quadratic factor in the attenuation formula: adds a curvature to the attenuation formula.
     */
    void setAttenuation(Real range, Real constant, Real linear, Real quadratic)
    {
        mRange = range;
        mAttenuationConst = constant;
        mAttenuationLinear = linear;
        mAttenuationQuad = quadratic;
    }
    
    /** Returns the absolute upper range of the light.
     */
    Real getAttenuationRange()
    {
        return mRange;
    }
    
    /** Returns the constant factor in the attenuation formula.
     */
    Real getAttenuationConstant()
    {
        return mAttenuationConst;
    }
    
    /** Returns the linear factor in the attenuation formula.
     */
    Real getAttenuationLinear()
    {
        return mAttenuationLinear;
    }
    
    /** Returns the quadric factor in the attenuation formula.
     */
    Real getAttenuationQuadric()
    {
        return mAttenuationQuad;
    }
    
    /** Sets the position of the light.
     @remarks
     Applicable to point lights and spotlights only.
     @note
     This will be overridden if the light is attached to a SceneNode.
     */
    void setPosition(Real x, Real y, Real z)
    {
        mPosition.x = x;
        mPosition.y = y;
        mPosition.z = z;
        mDerivedTransformDirty = true;
    }
    
    /** Sets the position of the light.
     @remarks
     Applicable to point lights and spotlights only.
     @note
     This will be overridden if the light is attached to a SceneNode.
     */
    void setPosition(Vector3 vec)
    {
        mPosition = vec;
        mDerivedTransformDirty = true;
    }
    
    /** Returns the position of the light.
     @note
     Applicable to point lights and spotlights only.
     */
    Vector3 getPosition()
    {
        return mPosition;
    }
    
    /** Sets the direction in which a light points.
     @remarks
     Applicable only to the spotlight and directional light types.
     @note
     This will be overridden if the light is attached to a SceneNode.
     */
    void setDirection(Real x, Real y, Real z)
    {
        mDirection.x = x;
        mDirection.y = y;
        mDirection.z = z;
        mDerivedTransformDirty = true;
    }
    
    /** Sets the direction in which a light points.
     @remarks
     Applicable only to the spotlight and directional light types.
     @note
     This will be overridden if the light is attached to a SceneNode.
     */
    void setDirection(Vector3 vec)
    {
        mDirection = vec;
        mDerivedTransformDirty = true;
    }
    
    /** Returns the light's direction.
     @remarks
     Applicable only to the spotlight and directional light types.
     */
    ref Vector3 getDirection()
    {
        return mDirection;
    }
    
    /** Sets the range of a spotlight, i.e. the angle of the inner and outer cones
     and the rate of falloff between them.
     @param innerAngle
     Angle covered by the bright inner cone
     @note
     The inner cone applicable only to Direct3D, it'll always treat as zero in OpenGL.
     @param outerAngle
     Angle covered by the outer cone
     @param falloff
     The rate of falloff between the inner and outer cones. 1.0 means a linear falloff,
     less means slower falloff, higher means faster falloff.
     */
    void setSpotlightRange(Radian innerAngle, ref Radian outerAngle, Real falloff = 1.0)
    {
        mSpotInner = innerAngle;
        mSpotOuter = outerAngle;
        mSpotFalloff = falloff;
    }
    
    /** Returns the angle covered by the spotlights inner cone.
     */
    ref Radian getSpotlightInnerAngle()
    {
        return mSpotInner;
    }
    
    /** Returns the angle covered by the spotlights outer cone.
     */
    ref Radian getSpotlightOuterAngle()
    {
        return mSpotOuter;
    }
    
    /** Returns the falloff between the inner and outer cones of the spotlight.
     */
    Real getSpotlightFalloff()
    {
        return mSpotFalloff;
    }
    
    /** Sets the angle covered by the spotlights inner cone.
     */
    void setSpotlightInnerAngle(Radian val)
    {
        mSpotInner = val;
    }
    
    /** Sets the angle covered by the spotlights outer cone.
     */
    void setSpotlightOuterAngle(Radian val)
    {
        mSpotOuter = val;
    }
    
    /** Sets the falloff between the inner and outer cones of the spotlight.
     */
    void setSpotlightFalloff(Real val)
    {
        mSpotFalloff = val;
    }
    
    /** Set the near clip plane distance to be used by spotlights that use light
     clipping, allowing you to render spots as if they start from further
     down their frustum. 
     @param nearClip
     The near distance.
     */
    void setSpotlightNearClipDistance(Real nearClip) { mSpotNearClip = nearClip; }
    
    /** Get the near clip plane distance to be used by spotlights that use light
     clipping.
     */
    Real getSpotlightNearClipDistance(){ return mSpotNearClip; }
    
    /** Set a scaling factor to indicate the relative power of a light.
     @remarks
     This factor is only useful in High Dynamic Range (HDR) rendering.
     You can bind it to a shader variable to take it into account,
     @see GpuProgramParameters
     @param power
     The power rating of this light, default is 1.0.
     */
    void setPowerScale(Real power)
    {
        mPowerScale = power;
    }
    
    /** Set the scaling factor which indicates the relative power of a 
     light.
     */
    Real getPowerScale()
    {
        return mPowerScale;
    }
    
    /** @copydoc MovableObject._notifyAttached */
    override void _notifyAttached(Node parent, bool isTagPoint = false)
    {
        mDerivedTransformDirty = true;
        
        super._notifyAttached(parent, isTagPoint);
    }
    
    /** @copydoc MovableObject._notifyMoved */
    override void _notifyMoved()
    {
        mDerivedTransformDirty = true;
        
        super._notifyMoved();
    }
    
    /** @copydoc MovableObject.getBoundingBox */
    override AxisAlignedBox getBoundingBox()
    {
        // Null, lights are not visible
        static AxisAlignedBox box;
        return box;
    }
    
    /** @copydoc MovableObject._updateRenderQueue */
    override void _updateRenderQueue(RenderQueue queue)
    {
        // Do nothing
    }
    
    /** @copydoc MovableObject.getMovableType */
    override string getMovableType()
    {
        return LightFactory.FACTORY_TYPE_NAME;
    }
    
    /** Retrieves the position of the light including any transform from nodes it is attached to. 
     @param cameraRelativeIfSet If set to true, returns data in camera-relative units if that's been set up (render use)
     */
    Vector3 getDerivedPosition(bool cameraRelativeIfSet = false)
    {
        update();
        if (cameraRelativeIfSet && mCameraToBeRelativeTo)
        {
            return mDerivedCamRelativePosition;
        }
        else
        {
            return mDerivedPosition;
        }
    }
    
    /** Retrieves the direction of the light including any transform from nodes it is attached to. */
    Vector3 getDerivedDirection()
    {
        update();
        return mDerivedDirection;
    }
    
    /** @copydoc MovableObject.setVisible.
     @remarks
     Although lights themselves are not 'visible', setting a light to invisible
     means it no longer affects the scene.
     */
    /*void setVisible(bool visible)
     {
     super.setVisible(visible);
     }*/
    
    /** @copydoc MovableObject.getBoundingRadius */
    override Real getBoundingRadius(){ return 0; /* not visible */ }
    
    /** Gets the details of this light as a 4D vector.
     @remarks
     Getting details of a light as a 4D vector can be useful for
     doing general calculations between different light types; for
     example the vector can represent both position lights (w=1.0f)
     and directional lights (w=0.0f) and be used in the same 
     calculations.
     @param cameraRelativeIfSet
     If set to @c true, returns data in camera-relative units if that's been set up (render use).
     */
    Vector4 getAs4DVector(bool cameraRelativeIfSet = false)
    {
        Vector4 ret;
        if (mLightType == LightTypes.LT_DIRECTIONAL)
        {
            ret = -(getDerivedDirection()); // negate direction as 'position'
            ret.w = 0.0; // infinite distance
        }   
        else
        {
            ret = getDerivedPosition(cameraRelativeIfSet);
            ret.w = 1.0;
        }
        return ret;
    }
    
    /** Internal method for calculating the 'near clip volume', which is
     the volume formed between the near clip rectangle of the 
     camera and the light.
     @remarks
     This volume is a pyramid for a point/spot light and
     a cuboid for a directional light. It can used to detect whether
     an object could be casting a shadow on the viewport. Note that
     the reference returned is to a shared volume which will be 
     reused across calls to this method.
     */
    PlaneBoundedVolume _getNearClipVolume(Camera cam)
    {
        // First check if the light is close to the near plane, since
        // in this case we have to build a degenerate clip volume
        mNearClipVolume.planes.clear();
        mNearClipVolume.outside = Plane.Side.NEGATIVE_SIDE;
        
        Real n = cam.getNearClipDistance();
        // Homogenous position
        Vector4 lightPos = getAs4DVector();
        // 3D version (not the same as _getDerivedPosition, is -direction for
        // directional lights)
        Vector3 lightPos3 = Vector3(lightPos.x, lightPos.y, lightPos.z);
        
        // Get eye-space light position
        // use 4D vector so directional lights still work
        Vector4 eyeSpaceLight = cam.getViewMatrix() * lightPos;
        // Find distance to light, project onto -Z axis
        Real d = eyeSpaceLight.dotProduct(Vector4(0, 0, -1, -n) );
        
        float THRESHOLD = 1e-6;
        
        if (d > THRESHOLD || d < -THRESHOLD)
        {
            // light is not too close to the near plane
            // First find the worldspace positions of the corners of the viewport
            Vector3[] corner = cam.getWorldSpaceCorners();
            int winding = (d < 0) ^ cam.isReflected() ? +1 : -1;
            // Iterate over world points and form side planes
            Vector3 normal;
            Vector3 lightDir;
            for (uint i = 0; i < 4; ++i)
            {
                // Figure out light dir
                lightDir = lightPos3 - (corner[i] * lightPos.w);
                // Cross with anticlockwise corner, Therefore normal points in
                normal = (corner[i] - corner[(i+winding)%4])
                    .crossProduct(lightDir);
                normal.normalise();
                mNearClipVolume.planes.insert(new Plane(normal, corner[i]));
            }
            
            // Now do the near plane plane
            normal = cam.getFrustumPlane(FrustumPlane.FRUSTUM_PLANE_NEAR).normal;
            if (d < 0)
            {
                // Behind near plane
                normal = -normal;
            }
            Vector3 cameraPos = cam.getDerivedPosition();
            mNearClipVolume.planes.insert(new Plane(normal, cameraPos));
            
            // Finally, for a point/spot light we can add a sixth plane
            // This prevents false positives from behind the light
            if (mLightType != LightTypes.LT_DIRECTIONAL)
            {
                // Direction from light perpendicular to near plane
                mNearClipVolume.planes.insert(new Plane(-normal, lightPos3));
            }
        }
        else
        {
            // light is close to being on the near plane
            // degenerate volume including the entire scene 
            // we will always require light / dark caps
            mNearClipVolume.planes.insert(new Plane(Vector3.UNIT_Z, -n));
            mNearClipVolume.planes.insert(new Plane(-Vector3.UNIT_Z, n));
        }
        
        return mNearClipVolume;
    }
    
    /** Internal method for calculating the clip volumes outside of the 
     frustum which can be used to determine which objects are casting
     shadow on the frustum as a whole. 
     @remarks
     Each of the volumes is a pyramid for a point/spot light and
     a cuboid for a directional light. 
     */
    PlaneBoundedVolumeList _getFrustumClipVolumes(Camera cam)
    {
        
        // Homogenous light position
        Vector4 lightPos = getAs4DVector();
        // 3D version (not the same as _getDerivedPosition, is -direction for
        // directional lights)
        Vector3 lightPos3 = Vector3(lightPos.x, lightPos.y, lightPos.z);
        
        Vector3[4] clockwiseVerts;
        
        // Get worldspace frustum corners
        Vector3[] corners = cam.getWorldSpaceCorners();
        int windingPt0 = cam.isReflected() ? 1 : 0;
        int windingPt1 = cam.isReflected() ? 0 : 1;
        
        bool infiniteViewDistance = (cam.getFarClipDistance() == 0);
        
        Vector3[4] notSoFarCorners;
        if(infiniteViewDistance)
        {
            Vector3 camPosition = cam.getRealPosition();
            notSoFarCorners[0] = corners[0] + corners[0] - camPosition;
            notSoFarCorners[1] = corners[1] + corners[1] - camPosition;
            notSoFarCorners[2] = corners[2] + corners[2] - camPosition;
            notSoFarCorners[3] = corners[3] + corners[3] - camPosition;
        }
        
        mFrustumClipVolumes.clear();
        foreach (ushort n; 0..6)
        {
            // Skip far plane if infinite view frustum
            if (infiniteViewDistance && n == FrustumPlane.FRUSTUM_PLANE_FAR)
                continue;
            
            Plane plane = cam.getFrustumPlane(n);
            auto planeVec = Vector4(plane.Normal().x, plane.Normal().y, plane.Normal().z, plane.d);
            // planes face inwards, we need to know if light is on negative side
            Real d = planeVec.dotProduct(lightPos);
            if (d < -1e-06)
            {
                // Ok, this is a valid one
                // clockwise verts mean we can cross-product and always get normals
                // facing into the volume we create
                
                mFrustumClipVolumes.insert(new PlaneBoundedVolume());
                PlaneBoundedVolume vol = mFrustumClipVolumes[$-1];
                final switch(n)
                {
                    case (FrustumPlane.FRUSTUM_PLANE_NEAR):
                        clockwiseVerts[0] = corners[3];
                        clockwiseVerts[1] = corners[2];
                        clockwiseVerts[2] = corners[1];
                        clockwiseVerts[3] = corners[0];
                        break;
                    case (FrustumPlane.FRUSTUM_PLANE_FAR):
                        clockwiseVerts[0] = corners[7];
                        clockwiseVerts[1] = corners[6];
                        clockwiseVerts[2] = corners[5];
                        clockwiseVerts[3] = corners[4];
                        break;
                    case (FrustumPlane.FRUSTUM_PLANE_LEFT):
                        clockwiseVerts[0] = infiniteViewDistance ? notSoFarCorners[1] : corners[5];
                        clockwiseVerts[1] = corners[1];
                        clockwiseVerts[2] = corners[2];
                        clockwiseVerts[3] = infiniteViewDistance ? notSoFarCorners[2] : corners[6];
                        break;
                    case (FrustumPlane.FRUSTUM_PLANE_RIGHT):
                        clockwiseVerts[0] = infiniteViewDistance ? notSoFarCorners[3] : corners[7];
                        clockwiseVerts[1] = corners[3];
                        clockwiseVerts[2] = corners[0];
                        clockwiseVerts[3] = infiniteViewDistance ? notSoFarCorners[0] : corners[4];
                        break;
                    case (FrustumPlane.FRUSTUM_PLANE_TOP):
                        clockwiseVerts[0] = infiniteViewDistance ? notSoFarCorners[0] : corners[4];
                        clockwiseVerts[1] = corners[0];
                        clockwiseVerts[2] = corners[1];
                        clockwiseVerts[3] = infiniteViewDistance ? notSoFarCorners[1] : corners[5];
                        break;
                    case (FrustumPlane.FRUSTUM_PLANE_BOTTOM):
                        clockwiseVerts[0] = infiniteViewDistance ? notSoFarCorners[2] : corners[6];
                        clockwiseVerts[1] = corners[2];
                        clockwiseVerts[2] = corners[3];
                        clockwiseVerts[3] = infiniteViewDistance ? notSoFarCorners[3] : corners[7];
                        break;
                }
                
                // Build a volume
                // Iterate over world points and form side planes
                Vector3 normal;
                Vector3 lightDir;
                uint infiniteViewDistanceInt = infiniteViewDistance ? 1 : 0;
                for (uint i = 0; i < 4 - infiniteViewDistanceInt; ++i)
                {
                    // Figure out light dir
                    lightDir = lightPos3 - (clockwiseVerts[i] * lightPos.w);
                    Vector3 edgeDir = *(clockwiseVerts[(i+windingPt1)%4]) - *(clockwiseVerts[(i+windingPt0)%4]);
                    // Cross with anticlockwise corner, Therefore normal points in
                    normal = edgeDir.crossProduct(lightDir);
                    normal.normalise();
                    vol.planes.insert(new Plane(normal, clockwiseVerts[i]));
                }
                
                // Now do the near plane (this is the plane of the side we're 
                // talking about, with the normal inverted (d is already interpreted as -ve)
                vol.planes.insert( new Plane(-plane.normal, plane.d) );
                
                // Finally, for a point/spot light we can add a sixth plane
                // This prevents false positives from behind the light
                if (mLightType != LightTypes.LT_DIRECTIONAL)
                {
                    // re-use our own plane normal
                    vol.planes.insert(new Plane(plane.Normal, lightPos3));
                }
            }
        }
        
        return mFrustumClipVolumes;
    }
    
    /// Override to return specific type flag
    override uint getTypeFlags()
    {
        return SceneManager.LIGHT_TYPE_MASK;
    }
    
    /// @copydoc AnimableObject.createAnimableValue
    override SharedPtr!AnimableValue createAnimableValue(string valueName)
    {
        if (valueName == "diffuseColour")
        {
            return SharedPtr!AnimableValue(
                new LightDiffuseColourValue(this));
        }
        else if(valueName == "specularColour")
        {
            return SharedPtr!AnimableValue(
                new LightSpecularColourValue(this));
        }
        else if (valueName == "attenuation")
        {
            return SharedPtr!AnimableValue(
                new LightAttenuationValue(this));
        }
        else if (valueName == "spotlightInner")
        {
            return SharedPtr!AnimableValue(
                new LightSpotlightInnerValue(this));
        }
        else if (valueName == "spotlightOuter")
        {
            return SharedPtr!AnimableValue(
                new LightSpotlightOuterValue(this));
        }
        else if (valueName == "spotlightFalloff")
        {
            return SharedPtr!AnimableValue(
                new LightSpotlightFalloffValue(this));
        }
        else
        {
            return super.createAnimableValue(valueName);
        }
    }
    
    /** Set this light to use a custom shadow camera when rendering texture shadows.
     @remarks
     This changes the shadow camera setup for just this light,  you can set
     the shadow camera setup globally using SceneManager.setShadowCameraSetup
     @see ShadowCameraSetup
     */
    void setCustomShadowCameraSetup(ShadowCameraSetup customShadowSetup)
    {
        mCustomShadowCameraSetup = customShadowSetup;
    }
    
    /** Reset the shadow camera setup to the default. 
     @see ShadowCameraSetup
     */
    void resetCustomShadowCameraSetup()
    {
        mCustomShadowCameraSetup = null;
    }
    
    /** Return a pointer to the custom shadow camera setup (null means use SceneManager global version). */
    ref ShadowCameraSetup getCustomShadowCameraSetup()
    {
        return mCustomShadowCameraSetup;
    }
    
    /// @copydoc MovableObject.visitRenderables
    override void visitRenderables(Renderable.Visitor visitor, 
                                   bool debugRenderables = false)
    {
        // nothing to render
    }
    
    /** Gets the index at which this light is in the current render. 
     @remarks
     Lights will be present in the in a list for every renderable,
     detected and sorted appropriately, and sometimes it's useful to know 
     what position in that list a given light occupies. This can vary 
     from frame to frame (and object to object) so you should not use this
     value unless you're sure the context is correct.
     */
    size_t _getIndexInFrame(){ return mIndexInFrame; }
    void _notifyIndexInFrame(size_t i) { mIndexInFrame = i; }
    
    /** Sets the maximum distance away from the camera that shadows
     by this light will be visible.
     @remarks
     Shadow techniques can be expensive, Therefore it is a good idea
     to limit them to being rendered close to the camera if possible,
     and to skip the expense of rendering shadows for distance objects.
     This method allows you to set the distance at which shadows will no
     longer be rendered.
     @note
     Each shadow technique can interpret this subtely differently.
     For example, one technique may use this to eliminate casters,
     another might use it to attenuate the shadows themselves.
     You should tweak this value to suit your chosen shadow technique
     and scene setup.
     */
    void setShadowFarDistance(Real distance)
    {
        mOwnShadowFarDist = true;
        mShadowFarDist = distance;
        mShadowFarDistSquared = distance * distance;
    }
    /** Tells the light to use the shadow far distance of the SceneManager
     */
    void resetShadowFarDistance()
    {
        mOwnShadowFarDist = false;
    }
    /** Gets the maximum distance away from the camera that shadows
     by this light will be visible.
     */
    Real getShadowFarDistance()
    {
        if (mOwnShadowFarDist)
            return mShadowFarDist;
        else
            return mManager.getShadowFarDistance ();
    }
    Real getShadowFarDistanceSquared()
    {
        if (mOwnShadowFarDist)
            return mShadowFarDistSquared;
        else
            return mManager.getShadowFarDistanceSquared ();
    }
    
    /** Set the near clip plane distance to be used by the shadow camera, if
     this light casts texture shadows.
     @param nearClip
     The distance, or -1 to use the main camera setting.
     */
    void setShadowNearClipDistance(Real nearClip) { mShadowNearClipDist = nearClip; }
    
    /** Get the near clip plane distance to be used by the shadow camera, if
     this light casts texture shadows.
     @remarks
     May be zero if the light doesn't have it's own near distance set;
     use _deriveShadowNearDistance for a version guaranteed to give a result.
     */
    Real getShadowNearClipDistance(){ return mShadowNearClipDist; }
    
    /** Derive a shadow camera near distance from either the light, or
     from the main camera if the light doesn't have its own setting.
     */
    Real _deriveShadowNearClipDistance(Camera maincam)
    {
        if (mShadowNearClipDist > 0)
            return mShadowNearClipDist;
        else
            return maincam.getNearClipDistance();
    }
    
    /** Set the far clip plane distance to be used by the shadow camera, if
     this light casts texture shadows.
     @remarks
     This is different from the 'shadow far distance', which is
     always measured from the main camera. This distance is the far clip plane
     of the light camera.
     @param farClip
     The distance, or -1 to use the main camera setting.
     */
    void setShadowFarClipDistance(Real farClip) { mShadowFarClipDist = farClip; }
    
    /** Get the far clip plane distance to be used by the shadow camera, if
     this light casts texture shadows.
     @remarks
     May be zero if the light doesn't have it's own far distance set;
     use _deriveShadowfarDistance for a version guaranteed to give a result.
     */
    Real getShadowFarClipDistance(){ return mShadowFarClipDist; }
    
    /** Derive a shadow camera far distance from either the light, or
     from the main camera if the light doesn't have its own setting.
     */
    Real _deriveShadowFarClipDistance(Camera maincam)
    {
        if (mShadowFarClipDist >= 0)
            return mShadowFarClipDist;
        else
        {
            if (mLightType == LightTypes.LT_DIRECTIONAL)
                return 0;
            else
                return mRange;
        }
    }
    
    /// Set the camera which this light should be relative to, for camera-relative rendering
    void _setCameraRelative(ref Camera cam)
    {
        mCameraToBeRelativeTo = cam;
        mDerivedCamRelativeDirty = true;
    }

    void _setCameraRelative(Camera cam)
    {
        mCameraToBeRelativeTo = cam;
        mDerivedCamRelativeDirty = true;
    }
    
    /** Sets a custom parameter for this Light, which may be used to 
     drive calculations for this specific Renderable, like GPU program parameters.
     @remarks
     Calling this method simply associates a numeric index with a 4-dimensional
     value for this specific Light. This is most useful if the material
     which this Renderable uses a vertex or fragment program, and has an 
     ACT_LIGHT_CUSTOM parameter entry. This parameter entry can ref er to the
     index you specify as part of this call, thereby mapping a custom
     parameter for this renderable to a program parameter.
     @param index
     The index with which to associate the value. Note that this
     does not have to start at 0, and can include gaps. It also has no direct
     correlation with a GPU program parameter index - the mapping between the
     two is performed by the ACT_LIGHT_CUSTOM entry, if that is used.
     @param value
     The value to associate.
     */
    void setCustomParameter(ushort index, Vector4 value)
    {
        mCustomParameters[index] = value;
    }
    
    /** Gets the custom value associated with this Light at the given index.
     @param index
     @see setCustomParameter for full details.
     */
    ref Vector4 getCustomParameter(ushort index)
    {
        auto i = index in mCustomParameters;
        if (i !is null)
        {
            return *i;
        }
        else
        {
            throw new ItemNotFoundError(
                "Parameter at the given index was not found.",
                "Light.getCustomParameter");
        }
    }
    
    /** Update a custom GpuProgramParameters constant which is derived from 
     information only this Light knows.
     @remarks
     This method allows a Light to map in a custom GPU program parameter
     based on it's own data. This is represented by a GPU auto parameter
     of ACT_LIGHT_CUSTOM, and to allow there to be more than one of these per
     Light, the 'data' field on the auto parameter will identify
     which parameter is being updated and on which light. The implementation 
     of this method must identify the parameter being updated, and call a 'setConstant' 
     method on the passed in GpuProgramParameters object.
     @par
     You do not need to override this method if you're using the standard
     sets of data associated with the Renderable as provided by setCustomParameter
     and getCustomParameter. By default, the implementation will map from the
     value indexed by the 'constantEntry.data' parameter to a value previously
     set by setCustomParameter. But custom Renderables are free to override
     this if they want, in any case.
     @param paramIndex
     The index of the constant being updated
     @param constantEntry
     The auto constant entry from the program parameters
     @param params
     The parameters object which this method should call to 
     set the updated parameters.
     */
    void _updateCustomGpuParameter(ushort paramIndex, 
                                   ref GpuProgramParameters.AutoConstantEntry constantEntry, 
                                   ref GpuProgramParameters params)
    {
        auto i = paramIndex in mCustomParameters;
        if (i !is null)
        {
            params._writeRawConstant(constantEntry.physicalIndex, *i, 
                                     constantEntry.elementCount);
        }
    }
    
    /** Check whether a sphere is included in the lighted area of the light 
     @note 
     The function trades accuracy for efficiency. As a result you may get
     false-positives (The function should not return any false-negatives).
     */
    bool isInLightRange(Sphere sphere)
    {
        bool isIntersect = true;
        //directional light always intersects (check only spotlight and point)
        if (mLightType != LightTypes.LT_DIRECTIONAL)
        {
            //Check that the sphere is within the sphere of the light
            isIntersect = sphere.intersects(Sphere(mDerivedPosition, mRange));
            //If this is a spotlight, check that the sphere is within the cone of the spot light
            if ((isIntersect) && (mLightType == LightTypes.LT_SPOTLIGHT))
            {
                //check first check of the sphere surrounds the position of the light
                //(this covers the case where the center of the sphere is behind the position of the light
                // something which is not covered in the next test).
                isIntersect = sphere.intersects(mDerivedPosition);
                //if not test cones
                if (!isIntersect)
                {
                    //Calculate the cone that exists between the sphere and the center position of the light
                    Vector3 lightSphereConeDirection = sphere.getCenter() - mDerivedPosition;
                    Radian halfLightSphereConeAngle = Math.ASin(sphere.getRadius() / lightSphereConeDirection.length());
                    
                    //Check that the light cone and the light-position-to-sphere cone intersect)
                    Radian angleBetweenConeDirections = lightSphereConeDirection.angleBetween(mDerivedDirection);
                    isIntersect = angleBetweenConeDirections <=  halfLightSphereConeAngle + mSpotOuter * 0.5;
                }
            }
        }
        return isIntersect;
    }
    
    /** Check whether a bounding box is included in the lighted area of the light
     @note 
     The function trades accuracy for efficiency. As a result you may get
     false-positives (The function should not return any false-negatives).
     */
    bool isInLightRange(AxisAlignedBox container)
    {
        bool isIntersect = true;
        //Check the 2 simple / obvious situations. Light is directional or light source is inside the container
        if ((mLightType != LightTypes.LT_DIRECTIONAL) && (container.intersects(mDerivedPosition) == false))
        {
            //Check that the container is within the sphere of the light
            isIntersect = Math.intersects(Sphere(mDerivedPosition, mRange),container);
            //If this is a spotlight, do a more specific check
            if ((isIntersect) && (mLightType == LightTypes.LT_SPOTLIGHT) && (mSpotOuter.valueRadians() <= Math.PI))
            {
                //Create a rough bounding box around the light and check if
                Quaternion localToWorld = Vector3.NEGATIVE_UNIT_Z.getRotationTo(mDerivedDirection);
                
                Real boxOffset = Math.Sin(mSpotOuter * 0.5) * mRange;
                AxisAlignedBox lightBoxBound;
                lightBoxBound.merge(Vector3.ZERO);
                lightBoxBound.merge(localToWorld * Vector3(boxOffset, boxOffset, -mRange));
                lightBoxBound.merge(localToWorld * Vector3(-boxOffset, boxOffset, -mRange));
                lightBoxBound.merge(localToWorld * Vector3(-boxOffset, -boxOffset, -mRange));
                lightBoxBound.merge(localToWorld * Vector3(boxOffset, -boxOffset, -mRange));
                lightBoxBound.setMaximum(lightBoxBound.getMaximum() + mDerivedPosition);
                lightBoxBound.setMinimum(lightBoxBound.getMinimum() + mDerivedPosition);
                isIntersect = lightBoxBound.intersects(container);
                
                //If the bounding box check succeeded do one more test
                if (isIntersect)
                {
                    //Check intersection again with the bounding sphere of the container
                    //Helpful for when the light is at an angle near one of the vertexes of the bounding box
                    isIntersect = isInLightRange(Sphere(container.getCenter(), 
                                                        container.getHalfSize().length()));
                }
            }
        }
        return isIntersect;
    }
    
protected:
    /// Internal method for synchronising with parent node (if any)
    void update()
    {
        if (mDerivedTransformDirty)
        {
            if (mParentNode)
            {
                // Ok, update with SceneNode we're attached to
                Quaternion parentOrientation = mParentNode._getDerivedOrientation();
                Vector3 parentPosition = mParentNode._getDerivedPosition();
                mDerivedDirection = parentOrientation * mDirection;
                mDerivedPosition = (parentOrientation * mPosition) + parentPosition;
            }
            else
            {
                mDerivedPosition = mPosition;
                mDerivedDirection = mDirection;
            }
            
            mDerivedTransformDirty = false;
            //if the position has been updated we must update also the relative position
            mDerivedCamRelativeDirty = true;
        }
        if (mCameraToBeRelativeTo && mDerivedCamRelativeDirty)
        {
            mDerivedCamRelativePosition = mDerivedPosition - mCameraToBeRelativeTo.getDerivedPosition();
            mDerivedCamRelativeDirty = false;
        }
    }
    
    /// @copydoc AnimableObject.getAnimableDictionaryName
    override string getAnimableDictionaryName()
    {
        return LightFactory.FACTORY_TYPE_NAME;
    }
    
    /// @copydoc AnimableObject.initialiseAnimableDictionary
    override void initialiseAnimableDictionary(ref StringVector vec)
    {
        vec.insert("diffuseColour");
        vec.insert("specularColour");
        vec.insert("attenuation");
        vec.insert("spotlightInner");
        vec.insert("spotlightOuter");
        vec.insert("spotlightFalloff");
        
    }
    
    LightTypes mLightType;
    Vector3 mPosition;
    ColourValue mDiffuse;
    ColourValue mSpecular;
    
    Vector3 mDirection;
    
    Radian mSpotOuter;
    Radian mSpotInner;
    Real mSpotFalloff;
    Real mSpotNearClip;
    Real mRange;
    Real mAttenuationConst;
    Real mAttenuationLinear;
    Real mAttenuationQuad;
    Real mPowerScale;
    size_t mIndexInFrame;
    bool mOwnShadowFarDist;
    Real mShadowFarDist;
    Real mShadowFarDistSquared;
    
    Real mShadowNearClipDist;
    Real mShadowFarClipDist;
    
    
    //mutable 
    Vector3 mDerivedPosition;
    //mutable 
    Vector3 mDerivedDirection;
    // Slightly hacky but unless we separate observed light render state from main Light...
    //mutable 
    Vector3 mDerivedCamRelativePosition;
    //mutable 
    bool mDerivedCamRelativeDirty;
    Camera mCameraToBeRelativeTo;
    
    /// Shared class-level name for Movable type.
    static string msMovableType;
    
    //mutable 
    PlaneBoundedVolume mNearClipVolume;
    //mutable 
    PlaneBoundedVolumeList mFrustumClipVolumes;
    /// Is the derived transform dirty?
    //mutable 
    bool mDerivedTransformDirty;
    
    /// Pointer to a custom shadow camera setup.
    //mutable 
    ShadowCameraSetup/+Ptr+/ mCustomShadowCameraSetup;
    
    //typedef map<ushort, Vector4>.type CustomParameterMap;
    alias Vector4[ushort] CustomParameterMap;
    /// Stores the custom parameters for the light.
    CustomParameterMap mCustomParameters;
}

/** Factory object for creating Light instances. */
class LightFactory : MovableObjectFactory
{
protected:
    override MovableObject createInstanceImpl(string name, NameValuePairList params)
    {
        Light light = new Light(name);
        
        if(!params.emptyAA())
        {
            //NameValuePairList.const_iterator ni;
            
            // Setting the light type first before any property specific to a certain light type
            string *ni;
            if ((ni = ("type" in params)) !is null)
            {
                if ((*ni) == "point")
                    light.setType(Light.LightTypes.LT_POINT);
                else if ((*ni) == "directional")
                    light.setType(Light.LightTypes.LT_DIRECTIONAL);
                else if ((*ni) == "spotlight")
                    light.setType(Light.LightTypes.LT_SPOTLIGHT);
                else
                    throw new InvalidParamsError(
                        "Invalid light type '" ~ *ni ~ "'.",
                        "LightFactory.createInstance");
            }
            
            // Common properties
            if ((ni = "position" in params) !is null)
                light.setPosition(StringConverter.parseVector3(*ni));
            
            if ((ni = "direction" in params) !is null)
                light.setDirection(StringConverter.parseVector3(*ni));
            
            if ((ni = "diffuseColour" in params) !is null)
                light.setDiffuseColour(StringConverter.parseColourValue(*ni));
            
            if ((ni = "specularColour" in params) !is null)
                light.setSpecularColour(StringConverter.parseColourValue(*ni));
            
            if ((ni = "attenuation" in params) !is null)
            {
                Vector4 attenuation = StringConverter.parseVector4(*ni);
                light.setAttenuation(attenuation.x, attenuation.y, attenuation.z, attenuation.w);
            }
            
            if ((ni = "castShadows" in params) !is null)
                light.setCastShadows(StringConverter.parse!bool(*ni));
            
            if ((ni = "visible" in params) !is null)
                light.setVisible(StringConverter.parse!bool(*ni));
            
            if ((ni = "powerScale" in params) !is null)
                light.setPowerScale(std.conv.to!real(*ni));
            
            if ((ni = "shadowFarDistance" in params) !is null)
                light.setShadowFarDistance(std.conv.to!real(*ni));
            
            
            // Spotlight properties
            if ((ni = "spotlightInner" in params) !is null)
                light.setSpotlightInnerAngle(StringConverter.parseAngle(*ni, Radian(0)));
            
            if ((ni = "spotlightOuter" in params) !is null)
                light.setSpotlightOuterAngle(StringConverter.parseAngle(*ni, Radian(0)));
            
            if ((ni = "spotlightFalloff" in params) !is null)
                light.setSpotlightFalloff(std.conv.to!real(*ni));
        }
        
        return light;
    }
public:
    this() {}
    ~this() {}
    
    immutable static string FACTORY_TYPE_NAME = "Light";
    
    override string getType()
    {
        return FACTORY_TYPE_NAME;
    }
    
    override void destroyInstance(ref MovableObject obj)
    {
        destroy(obj);
    }
    
}

class LightDiffuseColourValue : AnimableValue
{
    alias AnimableValue.setValue setValue;
    alias AnimableValue.applyDeltaValue applyDeltaValue;
protected:
    Light mLight;
public:
    this(ref Light l) 
    { super(ValueType.COLOUR); mLight = l; }
    override void setValue(ColourValue val)
    {
        mLight.setDiffuseColour(val);
    }
    override void applyDeltaValue(ColourValue val)
    {
        super.setValue(mLight.getDiffuseColour() + val);
    }
    override void setCurrentStateAsBaseValue()
    {
        super.setAsBaseValue(mLight.getDiffuseColour());
    }
    
}
//-----------------------------------------------------------------------
class LightSpecularColourValue : AnimableValue
{
    alias AnimableValue.setValue setValue;
    alias AnimableValue.applyDeltaValue applyDeltaValue;
protected:
    Light mLight;
public:
    this(ref Light l) 
    { super(ValueType.COLOUR); mLight = l; }
    override void setValue(ColourValue val)
    {
        mLight.setSpecularColour(val);
    }
    override void applyDeltaValue(ColourValue val)
    {
        super.setValue(mLight.getSpecularColour() + val);
    }
    override void setCurrentStateAsBaseValue()
    {
        super.setAsBaseValue(mLight.getSpecularColour());
    }
    
}
//-----------------------------------------------------------------------
class LightAttenuationValue : AnimableValue
{
    alias AnimableValue.setValue setValue;
    alias AnimableValue.applyDeltaValue applyDeltaValue;
protected:
    Light mLight;
public:
    this(ref Light l)
    { super(ValueType.VECTOR4); mLight = l; }
    override void setValue(Vector4 val)
    {
        mLight.setAttenuation(val.x, val.y, val.z, val.w);
    }
    override void applyDeltaValue(Vector4 val)
    {
        super.setValue(mLight.getAs4DVector() + val);
    }
    override void setCurrentStateAsBaseValue()
    {
        super.setAsBaseValue(mLight.getAs4DVector());
    }
    
}
//-----------------------------------------------------------------------
class LightSpotlightInnerValue : AnimableValue
{
    alias AnimableValue.setValue setValue;
    alias AnimableValue.applyDeltaValue applyDeltaValue;
protected:
    Light mLight;
public:
    this(ref Light l) 
    { super(ValueType.REAL); mLight = l; }
    override void setValue(Real val)
    {
        mLight.setSpotlightInnerAngle(Radian(val));
    }
    override void applyDeltaValue(Real val)
    {
        super.setValue(mLight.getSpotlightInnerAngle().valueRadians() + val);
    }
    override void setCurrentStateAsBaseValue()
    {
        super.setAsBaseValue(mLight.getSpotlightInnerAngle().valueRadians());
    }
    
}
//-----------------------------------------------------------------------
class LightSpotlightOuterValue : AnimableValue
{
    alias AnimableValue.setValue setValue;
    alias AnimableValue.applyDeltaValue applyDeltaValue;
protected:
    Light mLight;
public:
    this(ref Light l) 
    { super(ValueType.REAL); mLight = l; }
    override void setValue(Real val)
    {
        mLight.setSpotlightOuterAngle(Radian(val));
    }
    override void applyDeltaValue(Real val)
    {
        super.setValue(mLight.getSpotlightOuterAngle().valueRadians() + val);
    }
    override void setCurrentStateAsBaseValue()
    {
        super.setAsBaseValue(mLight.getSpotlightOuterAngle().valueRadians());
    }
    
}
//-----------------------------------------------------------------------
class LightSpotlightFalloffValue : AnimableValue
{
    alias AnimableValue.setValue setValue;
    alias AnimableValue.applyDeltaValue applyDeltaValue;
protected:
    Light mLight;
public:
    this(ref Light l) 
    { super(ValueType.REAL); mLight = l; }
    override void setValue(Real val)
    {
        mLight.setSpotlightFalloff(val);
    }
    override void applyDeltaValue(Real val)
    {
        super.setValue(mLight.getSpotlightFalloff() + val);
    }
    override void setCurrentStateAsBaseValue()
    {
        super.setAsBaseValue(mLight.getSpotlightFalloff());
    }
}
