module ogre.scene.scenemanager;
debug import std.stdio;
import core.sync.mutex;
import std.algorithm;
import std.array;

import ogre.animation.animations;
import ogre.math.axisalignedbox;
import ogre.general.colourvalue;
import ogre.general.common;
import ogre.compat;
import ogre.config;
import ogre.exception;
import ogre.math.frustum;
import ogre.rendersystem.hardware;
import ogre.scene.instancedgeometry;
import ogre.scene.instancemanager;
import ogre.lod.lodstrategy;
import ogre.math.matrix;
import ogre.resources.mesh;
import ogre.math.plane;
import ogre.math.quaternion;
import ogre.scene.shadowcamera;
import ogre.singleton;
import ogre.math.sphere;
import ogre.scene.staticgeometry;
import ogre.math.vector;
import ogre.scene.manualobject;
import ogre.resources.datastream;
import ogre.math.ray;
import ogre.image.pixelformat;
import ogre.image.images;
import ogre.scene.instancedentity;
import ogre.resources.texture;
import ogre.resources.meshmanager;
import ogre.resources.texturemanager;
import ogre.scene.shadowvolumeextrudeprogram;
import ogre.general.root;
import ogre.spotshadowfadepng;
import ogre.general.profiler;
import ogre.general.controllermanager;
import ogre.animation.animable;
import ogre.general.generals;
import ogre.scene.camera;
import ogre.rendersystem.rendersystem;
import ogre.materials.material;
import ogre.scene.light;
import ogre.rendersystem.viewport;
import ogre.rendersystem.renderqueuesortinggrouping;
import ogre.materials.pass;
import ogre.scene.renderable;
import ogre.scene.scenenode;
import ogre.rendersystem.renderqueue;
import ogre.scene.entity;
import ogre.scene.movableobject;
import ogre.materials.autoparamdatasource;
import ogre.effects.compositor;
import ogre.scene.rectangle2d;
import ogre.scene.shadowtexturemanager;
import ogre.scene.shadowcaster;
import ogre.scene.scenequery;
import ogre.resources.resourcegroupmanager;
import ogre.effects.billboardchain;
import ogre.effects.ribbontrail;
import ogre.effects.particlesystem;
import ogre.effects.billboard;
import ogre.materials.blendmode;
import ogre.materials.textureunitstate;
import ogre.materials.materialmanager;
import ogre.rendersystem.rendertexture;
import ogre.scene.node;
import ogre.effects.particlesystemmanager;
import ogre.rendersystem.rendertarget;
import ogre.math.maths;
import ogre.general.log;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Scene
 *  @{
 */

/** Structure for holding a position & orientation pair. */
struct ViewPoint
{
    Vector3 position;
    Quaternion orientation;
}

/** Structure collecting together information about the visible objects
 that have been discovered in a scene.
 */
struct VisibleObjectsBoundsInfo
{
    /// The axis-aligned bounds of the visible objects
    AxisAlignedBox aabb;
    /// The axis-aligned bounds of the visible shadow receiver objects
    AxisAlignedBox receiverAabb;
    /// The closest a visible object is to the camera
    Real minDistance = Real.infinity;
    /// The farthest a visible objects is from the camera
    Real maxDistance = 0;
    /// The closest a object in the frustum regardless of visibility / shadow caster flags
    Real minDistanceInFrustum = Real.infinity;
    /// The farthest object in the frustum regardless of visibility / shadow caster flags
    Real maxDistanceInFrustum = 0;
    
    void reset()
    {
        aabb.setNull();
        receiverAabb.setNull();
        minDistance = minDistanceInFrustum = Real.infinity;
        maxDistance = maxDistanceInFrustum = 0;
    }

    void merge(AxisAlignedBox boxBounds, Sphere sphereBounds, 
               Camera cam, bool receiver=true)
    {
        aabb.merge(boxBounds);
        if (receiver)
            receiverAabb.merge(boxBounds);
        // use view matrix to determine distance, works with custom view matrices
        Vector3 vsSpherePos = cam.getViewMatrix(true) * sphereBounds.getCenter();
        Real camDistToCenter = vsSpherePos.length();
        minDistance = std.algorithm.min(minDistance, std.algorithm.max(0, camDistToCenter - sphereBounds.getRadius()));
        maxDistance = std.algorithm.max(maxDistance, camDistToCenter + sphereBounds.getRadius());
        minDistanceInFrustum = std.algorithm.min(minDistanceInFrustum, std.algorithm.max(0, camDistToCenter - sphereBounds.getRadius()));
        maxDistanceInFrustum = std.algorithm.max(maxDistanceInFrustum, camDistToCenter + sphereBounds.getRadius());
    }
    /** Merge an object that is not being rendered because it's not a shadow caster, 
     but is a shadow receiver so should be included in the range.
     */
    void mergeNonRenderedButInFrustum(AxisAlignedBox boxBounds, 
                                      Sphere sphereBounds, Camera cam)
    {
        // use view matrix to determine distance, works with custom view matrices
        Vector3 vsSpherePos = cam.getViewMatrix(true) * sphereBounds.getCenter();
        Real camDistToCenter = vsSpherePos.length();
        minDistanceInFrustum = std.algorithm.min(minDistanceInFrustum, std.algorithm.max(0, camDistToCenter - sphereBounds.getRadius()));
        maxDistanceInFrustum = std.algorithm.max(maxDistanceInFrustum, camDistToCenter + sphereBounds.getRadius());
        
    }
    
}

/** Manages the organisation and rendering of a 'scene' i.e. a collection 
 of objects and potentially world geometry.
 @remarks
 This class defines the interface and the basic behaviour of a 
 'Scene Manager'. A SceneManager organises the culling and rendering of
 the scene, in conjunction with the RenderQueue. This class is designed 
 to be extended through subclassing in order to provide more specialised
 scene organisation structures for particular needs. The default 
 SceneManager culls based on a hierarchy of node bounding boxes, other
 implementations can use an octree (@see OctreeSceneManager), a BSP
 tree (@see BspSceneManager), and many other options. New SceneManager
 implementations can be added at runtime by plugins, see 
 SceneManagerEnumerator for the interfaces for adding new SceneManager
 types.
 @par
 There is a distinction between 'objects' (which subclass MovableObject, 
 and are movable, discrete objects in the world), and 'world geometry',
 which is large, generally static geometry. World geometry tends to 
 influence the SceneManager organisational structure (e.g. lots of indoor
 static geometry might result in a spatial tree structure) and as such
 world geometry is generally tied to a given SceneManager implementation,
 whilst MovableObject instances can be used with any SceneManager.
 Subclasses are free to define world geometry however they please.
 @par
 Multiple SceneManager instances can exist at one time, each one with 
 a distinct scene. Which SceneManager is used to render a scene is
 dependent on the Camera, which will always call back the SceneManager
 which created it to render the scene. 
 */
class SceneManager //: public SceneMgtAlloc
{
public:
    /// Query type mask which will be used for world geometry @see SceneQuery
    enum uint WORLD_GEOMETRY_TYPE_MASK = 0x80000000;
    /// Query type mask which will be used for entities @see SceneQuery
    enum uint ENTITY_TYPE_MASK = 0x40000000;
    /// Query type mask which will be used for effects like billboardsets / particle systems @see SceneQuery
    enum uint FX_TYPE_MASK = 0x20000000;
    /// Query type mask which will be used for StaticGeometry  @see SceneQuery
    enum uint STATICGEOMETRY_TYPE_MASK = 0x10000000;
    /// Query type mask which will be used for lights  @see SceneQuery
    enum uint LIGHT_TYPE_MASK = 0x08000000;
    /// Query type mask which will be used for frusta and cameras @see SceneQuery
    enum uint FRUSTUM_TYPE_MASK = 0x04000000;
    /// User type mask limit
    enum uint USER_TYPE_MASK_LIMIT = FRUSTUM_TYPE_MASK;

    /** Comparator for material map, for sorting materials into render order (e.g. transparent last).
     */
    bool materialLess(Material x,Material y)
    {
        // If x transparent and y not, x > y (since x has to overlap y)
        if (x.isTransparent() && !y.isTransparent())
        {
            return false;
        }
        // If y is transparent and x not, x < y
        else if (!x.isTransparent() && y.isTransparent())
        {
            return true;
        }
        else
        {
            // Otherwise don't care (both transparent or both solid)
            // Just arbitrarily use pointer
            return &x < &y;
        }
        
    }

    /// Comparator for sorting lights relative to a point
    static bool lightLess(Light a,Light b)
    {
        return a.tempSquareDist < b.tempSquareDist;
    }
    
    /// Describes the stage of rendering when performing complex illumination
    enum IlluminationRenderStage
    {
        /// No special illumination stage
        IRS_NONE,
        /// Render to texture stage, used for texture based shadows
        IRS_RENDER_TO_TEXTURE,
        /// Render from shadow texture to receivers stage
        IRS_RENDER_RECEIVER_PASS
    }
    
    /** Enumeration of the possible modes allowed for processing the special case
     render queue list.
     @see SceneManager::setSpecialCaseRenderQueueMode
     */
    enum SpecialCaseRenderQueueMode
    {
        /// Render only the queues in the special case list
        SCRQM_INCLUDE,
        /// Render all except the queues in the special case list
        SCRQM_EXCLUDE
    }
    
    struct SkyDomeGenParameters
    {
        Real skyDomeCurvature;
        Real skyDomeTiling;
        Real skyDomeDistance;
        int skyDomeXSegments; 
        int skyDomeYSegments;
        int skyDomeYSegments_keep;
    }
    
    struct SkyPlaneGenParameters
    {
        Real skyPlaneScale;
        Real skyPlaneTiling; 
        Real skyPlaneBow; 
        int skyPlaneXSegments; 
        int skyPlaneYSegments; 
    }
    
    struct SkyBoxGenParameters
    {
        Real skyBoxDistance;
    }
    
    /** Class that allows listening in on the various stages of SceneManager
     processing, so that custom behaviour can be implemented from outside.
     */
    interface Listener
    {
        template Listener_Impl()
        {
            void preUpdateSceneGraph(SceneManager source, Camera camera){}
            void postUpdateSceneGraph(SceneManager source, Camera camera){}
            void preFindVisibleObjects(SceneManager source, 
                                       IlluminationRenderStage irs, Viewport v){}
            void postFindVisibleObjects(SceneManager source, 
                                        IlluminationRenderStage irs, Viewport v){}
            void shadowTexturesUpdated(size_t numberOfShadowTextures){}
            void shadowTextureCasterPreViewProj(Light light, 
                                                Camera camera, size_t iteration){}
            void shadowTextureReceiverPreViewProj(Light light, 
                                                  Frustum frustum){}
            bool sortLightsAffectingFrustum(LightList lightList){ return false; }
            void sceneManagerDestroyed(SceneManager source){}
        }
        /** Called prior to updating the scene graph in this SceneManager.
         @remarks
         This is called before updating the scene graph for a camera.
         @param source The SceneManager instance raising this event.
         @param camera The camera being updated.
         */
        void preUpdateSceneGraph(SceneManager source, Camera camera);
        
        /** Called after updating the scene graph in this SceneManager.
         @remarks
         This is called after updating the scene graph for a camera.
         @param source The SceneManager instance raising this event.
         @param camera The camera being updated.
         */
        void postUpdateSceneGraph(SceneManager source, Camera camera);
        
        /** Called prior to searching for visible objects in this SceneManager.
         @remarks
         Note that the render queue at this stage will be full of the last
         render's contents and will be cleared after this method is called.
         @param source The SceneManager instance raising this event.
         @param irs The stage of illumination being dealt with. IlluminationRenderStage.IRS_NONE for 
         a regular render, IlluminationRenderStage.IRS_RENDER_TO_TEXTURE for a shadow caster render.
         @param v The viewport being updated. You can get the camera from here.
         */
        void preFindVisibleObjects(SceneManager source, 
                                   IlluminationRenderStage irs, Viewport v);
        
        /** Called after searching for visible objects in this SceneManager.
         @remarks
         Note that the render queue at this stage will be full of the current
         scenes contents, ready for rendering. You may manually add renderables
         to this queue if you wish.
         @param source The SceneManager instance raising this event.
         @param irs The stage of illumination being dealt with. IlluminationRenderStage.IRS_NONE for 
         a regular render, IlluminationRenderStage.IRS_RENDER_TO_TEXTURE for a shadow caster render.
         @param v The viewport being updated. You can get the camera from here.
         */
        void postFindVisibleObjects(SceneManager source, 
                                    IlluminationRenderStage irs, Viewport v);
        
        /** Event raised after all shadow textures have been rendered into for 
         all queues / targets but before any other geometry has been rendered
         (including main scene geometry and any additional shadow receiver 
         passes). 
         @remarks
         This callback is useful for those that wish to perform some 
         additional processing on shadow textures before they are used to 
         render shadows. For example you could perform some filtering by 
         rendering the existing shadow textures into another alternative 
         shadow texture with a shader.]
         @note
         This event will only be fired when texture shadows are in use.
         @param numberOfShadowTextures The number of shadow textures in use
         */
        void shadowTexturesUpdated(size_t numberOfShadowTextures);
        
        /** This event occurs just before the view & projection matrices are
         set for rendering into a shadow texture.
         @remarks
         You can use this event hook to perform some custom processing,
         such as altering the camera being used for rendering the light's
         view, including setting custom view & projection matrices if you
         want to perform an advanced shadow technique.
         @note
         This event will only be fired when texture shadows are in use.
         @param light Pointer to the light for which shadows are being rendered
         @param camera Pointer to the camera being used to render
         @param iteration For lights that use multiple shadow textures, the iteration number
         */
        void shadowTextureCasterPreViewProj(Light light, 
                                            Camera camera, size_t iteration);
        
        /** This event occurs just before the view & projection matrices are
         set for re-rendering a shadow receiver.
         @remarks
         You can use this event hook to perform some custom processing,
         such as altering the projection frustum being used for rendering 
         the shadow onto the receiver to perform an advanced shadow 
         technique.
         @note
         This event will only be fired when texture shadows are in use.
         @param light Pointer to the light for which shadows are being rendered
         @param frustum Pointer to the projection frustum being used to project
         the shadow texture
         */
        void shadowTextureReceiverPreViewProj(Light light, 
                                              Frustum frustum);
        
        /** Hook to allow the listener to override the ordering of lights for
         the entire frustum.
         @remarks
         Whilst ordinarily lights are sorted per rendered object 
         (@see MovableObject::queryLights), texture shadows adds another issue
         in that, given there is a finite number of shadow textures, we must
         choose which lights to render texture shadows from based on the entire
         frustum. These lights should always be listed first in every objects
         own list, followed by any other lights which will not cast texture 
         shadows (either because they have shadow casting off, or there aren't
         enough shadow textures to service them).
         @par
         This hook allows you to override the detailed ordering of the lights
         per frustum. The default ordering is shadow casters first (which you 
         must also respect if you override this method), and ordered
         by distance from the camera within those 2 groups. Obviously the closest
         lights with shadow casting enabled will be listed first. Only lights 
         within the range of the frustum will be in the list.
         @param lightList The list of lights within range of the frustum which you
         may sort.
         @return true if you sorted the list, false otherwise.
         */
        bool sortLightsAffectingFrustum(LightList lightList);
        
        /** Event notifying the listener of the SceneManager's destruction. */
        void sceneManagerDestroyed(SceneManager source);
    }
    
    /** Inner helper class to implement the visitor pattern for rendering objects
     in a queue. 
     */
    class SceneMgrQueuedRenderableVisitor : QueuedRenderableVisitor
    {
    protected:
        /// Pass that was actually used at the grouping level
        //
        Pass mUsedPass;
    public:
        this() { transparentShadowCastersMode = false;}
        ~this() {}
        
        void visit(Renderable r)
        {
            // Give SM a chance to eliminate
            if (targetSceneMgr.validateRenderableForRendering(mUsedPass, r))
            {
                // Render a single object, this will set up auto params if required
                targetSceneMgr.renderSingleObject(r, mUsedPass, scissoring, autoLights, manualLightList);
            }
        }
        
        bool visit(Pass p)
        {
            // Give SM a chance to eliminate this pass
            if (!targetSceneMgr.validatePassForRendering(p))
                return false;
            
            // Set pass, store the actual one used
            mUsedPass = targetSceneMgr._setPass(p);
            
            
            return true;
        }
        
        void visit(RenderablePass rp)
        {
            // Skip this one if we're in transparency cast shadows mode & it doesn't
            // Don't need to implement this one in the other visit methods since
            // transparents are never grouped, always sorted
            if (transparentShadowCastersMode && 
                !rp.pass.getParent().getParent().getTransparencyCastsShadows())
                return;
            
            // Give SM a chance to eliminate
            if (targetSceneMgr.validateRenderableForRendering(rp.pass, rp.renderable))
            {
                mUsedPass = targetSceneMgr._setPass(rp.pass);
                targetSceneMgr.renderSingleObject(rp.renderable, mUsedPass, scissoring, 
                                                  autoLights, manualLightList);
            }
        }
        
        /// Target SM to send renderables to
        SceneManager targetSceneMgr;
        /// Are we in transparent shadow caster mode?
        bool transparentShadowCastersMode;
        /// Automatic light handling?
        bool autoLights;
        /// Manual light list
        //
        LightList manualLightList;
        /// Scissoring if requested?
        bool scissoring;
        
    }
    /// Allow visitor helper to access protected methods
    //friend class SceneMgrQueuedRenderableVisitor;
    
protected:
    
    /// Subclasses can override this to ensure their specialised SceneNode is used.
    SceneNode createSceneNodeImpl()
    {
        return new SceneNode(this);
    }
    
    /// Subclasses can override this to ensure their specialised SceneNode is used.
    SceneNode createSceneNodeImpl(string name)
    {
        return new SceneNode(this, name);
    }
    
    /// Instance name
    string mName;
    
    /// Queue of objects for rendering
    RenderQueue mRenderQueue;
    bool mLastRenderQueueInvocationCustom;
    
    /// Current ambient light, cached for RenderSystem
    ColourValue mAmbientLight;
    
    /// The rendering system to send the scene to
    RenderSystem mDestRenderSystem;
    
    //typedef map<string, Camera* >::type CameraList;
    alias Camera[string] CameraList;
    
    /** Central list of cameras - for easy memory management and lookup.
     */
    CameraList mCameras;
    
    //typedef map<string, StaticGeometry* >::type StaticGeometryList;
    alias StaticGeometry[string] StaticGeometryList;
    StaticGeometryList mStaticGeometryList;
    //typedef map<string, InstancedGeometry* >::type InstancedGeometryList;
    alias InstancedGeometry[string] InstancedGeometryList;
    InstancedGeometryList mInstancedGeometryList;
    
    //typedef map<string, InstanceManager*>::type InstanceManagerMap;
    alias InstanceManager[string] InstanceManagerMap;
    InstanceManagerMap  mInstanceManagerMap;
    
    //typedef map<string, SceneNode*>::type SceneNodeList;
    alias SceneNode[string] SceneNodeList;
    
    /** Central list of SceneNodes - for easy memory management.
     @note
     Note that this list is used only for memory management; the structure of the scene
     is held using the hierarchy of SceneNodes starting with the root node. However you
     can look up nodes this way.
     */
    SceneNodeList mSceneNodes;
    
    /// Camera in progress
    Camera mCameraInProgress;
    /// Current Viewport
    Viewport mCurrentViewport;
    
    /// Root scene node
    SceneNode mSceneRoot;
    
    /// Autotracking scene nodes
    //typedef set<SceneNode*>::type AutoTrackingSceneNodes;
    alias SceneNode[]  AutoTrackingSceneNodes;
    AutoTrackingSceneNodes mAutoTrackingSceneNodes;
    
    // Sky params
    // Sky plane
    Entity mSkyPlaneEntity;
    Entity[5] mSkyDomeEntity;
    ManualObject mSkyBoxObj;
    
    SceneNode mSkyPlaneNode;
    SceneNode mSkyDomeNode;
    SceneNode mSkyBoxNode;
    
    // Sky plane
    bool mSkyPlaneEnabled;
    ubyte mSkyPlaneRenderQueue;
    Plane mSkyPlane;
    SkyPlaneGenParameters mSkyPlaneGenParameters;
    // Sky box
    bool mSkyBoxEnabled;
    ubyte mSkyBoxRenderQueue;
    Quaternion mSkyBoxOrientation;
    SkyBoxGenParameters mSkyBoxGenParameters;
    // Sky dome
    bool mSkyDomeEnabled;
    ubyte mSkyDomeRenderQueue;
    Quaternion mSkyDomeOrientation;
    SkyDomeGenParameters mSkyDomeGenParameters;
    
    // Fog
    FogMode mFogMode;
    ColourValue mFogColour;
    Real mFogStart;
    Real mFogEnd;
    Real mFogDensity;
    
    //typedef set<ubyte>::type SpecialCaseRenderQueueList;
    alias ubyte[] SpecialCaseRenderQueueList;
    SpecialCaseRenderQueueList mSpecialCaseQueueList;
    SpecialCaseRenderQueueMode mSpecialCaseQueueMode;
    ubyte mWorldGeometryRenderQueue;
    
    ulong mLastFrameNumber;
    Matrix4[256] mTempXform;
    bool mResetIdentityView;
    bool mResetIdentityProj;
    
    bool mNormaliseNormalsOnScale;
    bool mFlipCullingOnNegativeScale;
    CullingMode mPassCullingMode;
    
protected:
    
    /** Visible objects bounding box list.
     @remarks
     Holds an ABB for each camera that contains the physical extends of the visible
     scene elements by each camera. The map is crucial for shadow algorithms which
     have a focus step to limit the shadow sample distribution to only valid visible
     scene elements.
     */
    //typedef map<Camera*, VisibleObjectsBoundsInfo>::type CamVisibleObjectsMap;
    alias VisibleObjectsBoundsInfo[Camera] CamVisibleObjectsMap;
    CamVisibleObjectsMap mCamVisibleObjectsMap; 
    
    /** ShadowCamera to light mapping */
    //typedef map<Camera*,Light* >::type ShadowCamLightMapping;
    alias Light[Camera] ShadowCamLightMapping;
    ShadowCamLightMapping mShadowCamLightMapping;
    
    /// Array defining shadow count per light type.
    size_t[3] mShadowTextureCountPerType;
    
    /// Array defining shadow texture index in light list.
    //vector<size_t>::type mShadowTextureIndexLightList;
    size_t[] mShadowTextureIndexLightList;
    
    /// Cached light information, used to tracking light's changes
    struct LightInfo
    {
        Light light;       // Just a pointer for comparison, the light might destroyed for some reason
        int type;           // Use int instead of Light.LightTypes to avoid header file dependence
        Real range;         // Sets to zero if directional light
        Vector3 position;   // Sets to zero if directional light
        uint lightMask;   // Light mask
        
        bool opEquals (LightInfo rhs)
        {
            return light == rhs.light && type == rhs.type &&
                range == rhs.range && position == rhs.position && lightMask == rhs.lightMask;
        }
    }
    
    //typedef vector<LightInfo>::type LightInfoList;
    alias LightInfo[] LightInfoList;
    
    LightList mLightsAffectingFrustum;
    LightInfoList mCachedLightInfos;
    LightInfoList mTestLightInfos; // potentially new list
    ulong mLightsDirtyCounter;
    LightList mShadowTextureCurrentCasterLightList;
    
    //typedef map<string, MovableObject*>::type MovableObjectMap;
    //alias MovableObject[string] MovableObjectMap;
    /// Simple structure to hold MovableObject map and a mutex to go with it.
    struct MovableObjectCollection
    {
        //MovableObjectMap map;
        MovableObject[string] map;
        //OGRE_MUTEX(mutex)
        Mutex mLock;
    }
    //typedef map<string, MovableObjectCollection*>::type MovableObjectCollectionMap;
    alias MovableObjectCollection*[string] MovableObjectCollectionMap;
    MovableObjectCollectionMap mMovableObjectCollectionMap;
    NameGenerator mMovableNameGenerator;
    /** Gets the movable object collection for the given type name.
     @remarks
        This method create new collection if the collection does not exist.
     */
    MovableObjectCollection *getMovableObjectCollection(string typeName)
    {
        // lock collection mutex
        synchronized(mMovableObjectCollectionMapMutex)
        {
            auto i = typeName in mMovableObjectCollectionMap;
            if (i is null)
            {
                // MovableObjectCollection has AA, but compiles here without 'new'.
                // Test file complains about 'map' needing 'this'. Ah?
                // create
                MovableObjectCollection *newCollection = new MovableObjectCollection;
                newCollection.mLock = new Mutex;
                mMovableObjectCollectionMap[typeName] = newCollection;
                //return newCollection;
                return mMovableObjectCollectionMap[typeName];
            }
            else
            {
                return *i;
            }
        }
    }
    /** Gets the movable object collection for the given type name.
     @remarks
     This method throw exception if the collection does not exist.
     */
    //auto ref MovableObjectCollection getMovableObjectCollection(string typeName);
    
    /// Mutex over the collection of MovableObject types
    Mutex mMovableObjectCollectionMapMutex;
    
    /** Internal method for initialising the render queue.
     @remarks
     Subclasses can use this to install their own RenderQueue implementation.
     */
    void initRenderQueue()
    {
        mRenderQueue = new RenderQueue();
        // init render queues that do not need shadows
        mRenderQueue.getQueueGroup(RenderQueueGroupID.RENDER_QUEUE_BACKGROUND).setShadowsEnabled(false);
        mRenderQueue.getQueueGroup(RenderQueueGroupID.RENDER_QUEUE_OVERLAY).setShadowsEnabled(false);
        mRenderQueue.getQueueGroup(RenderQueueGroupID.RENDER_QUEUE_SKIES_EARLY).setShadowsEnabled(false);
        mRenderQueue.getQueueGroup(RenderQueueGroupID.RENDER_QUEUE_SKIES_LATE).setShadowsEnabled(false);
    }
    /// A pass designed to let us render shadow colour on white for texture shadows
    Pass mShadowCasterPlainBlackPass;
    /// A pass designed to let us render shadow receivers for texture shadows
    Pass mShadowReceiverPass;
    /** Internal method for turning a regular pass into a shadow caster pass.
     @remarks
     This is only used for texture shadows, basically we're trying to
     ensure that objects are rendered solid black.
     This method will usually return the standard solid black pass for
     all fixed function passes, but will merge in a vertex program
     and fudge the AutoParamDataSource to set black lighting for
     passes with vertex programs. 
     */
    //
    Pass deriveShadowCasterPass(/*const*/ Pass pass)
    {
        if (isShadowTechniqueTextureBased())
        {
            Pass retPass;
            if (pass.getParent().getShadowCasterMaterial().isNull())
            {
                return pass.getParent().getShadowCasterMaterial().getAs().getBestTechnique().getPass(0); 
            }
            else 
            {
                retPass = mShadowTextureCustomCasterPass ? 
                    mShadowTextureCustomCasterPass : mShadowCasterPlainBlackPass;
            }
            
            
            // Special case alpha-blended passes
            if ((pass.getSourceBlendFactor() == SceneBlendFactor.SBF_SOURCE_ALPHA && 
                 pass.getDestBlendFactor() == SceneBlendFactor.SBF_ONE_MINUS_SOURCE_ALPHA) 
                || pass.getAlphaRejectFunction() != CompareFunction.CMPF_ALWAYS_PASS)
            {
                // Alpha blended passes must retain their transparency
                retPass.setAlphaRejectSettings(pass.getAlphaRejectFunction(), 
                                               pass.getAlphaRejectValue());
                retPass.setSceneBlending(pass.getSourceBlendFactor(), pass.getDestBlendFactor());
                retPass.getParent().getParent().setTransparencyCastsShadows(true);
                
                // So we allow the texture units, but override the colour functions
                // Copy texture state, shift up one since 0 is shadow texture
                ushort origPassTUCount = pass.getNumTextureUnitStates();
                foreach (ushort t; 0..origPassTUCount)
                {
                    TextureUnitState tex;
                    if (retPass.getNumTextureUnitStates() <= t)
                    {
                        tex = retPass.createTextureUnitState();
                    }
                    else
                    {
                        tex = retPass.getTextureUnitState(t);
                    }
                    // FIXME TextureUnitState: copy base state
                    //(*tex) = *(pass.getTextureUnitState(t));
                    
                    tex._copy(pass.getTextureUnitState(t)); //FIXME copy base state. No doubt this has a logic error somewhere
                    
                    // override colour function
                    tex.setColourOperationEx(LayerBlendOperationEx.LBX_SOURCE1, LayerBlendSource.LBS_MANUAL, LayerBlendSource.LBS_CURRENT,
                                             isShadowTechniqueAdditive()? ColourValue.Black : mShadowColour);
                    
                }
                // Remove any extras
                while (retPass.getNumTextureUnitStates() > origPassTUCount)
                {
                    retPass.removeTextureUnitState(origPassTUCount);
                }
                
            }
            else
            {
                // reset
                retPass.setSceneBlending(SceneBlendType.SBT_REPLACE);
                retPass.setAlphaRejectFunction(CompareFunction.CMPF_ALWAYS_PASS);
                while (retPass.getNumTextureUnitStates() > 0)
                {
                    retPass.removeTextureUnitState(0);
                }
            }
            
            // Propagate culling modes
            retPass.setCullingMode(pass.getCullingMode());
            retPass.setManualCullingMode(pass.getManualCullingMode());
            
            
            // Does incoming pass have a custom shadow caster program?
            if (pass.getShadowCasterVertexProgramName() !is null)
            {
                // Have to merge the shadow caster vertex program in
                retPass.setVertexProgram(
                    pass.getShadowCasterVertexProgramName(), false);
                //
                GpuProgram prg = retPass.getVertexProgram().getAs();
                // Load this program if not done already
                if (!prg.isLoaded())
                    prg.load();
                // Copy params
                retPass.setVertexProgramParameters(
                    pass.getShadowCasterVertexProgramParameters());
                // Also have to hack the light autoparams, that is done later
            }
            else 
            {
                if (retPass == mShadowTextureCustomCasterPass)
                {
                    // reset vp?
                    if (mShadowTextureCustomCasterPass.getVertexProgramName() !=
                        mShadowTextureCustomCasterVertexProgram)
                    {
                        mShadowTextureCustomCasterPass.setVertexProgram(
                            mShadowTextureCustomCasterVertexProgram, false);
                        if(mShadowTextureCustomCasterPass.hasVertexProgram())
                        {
                            mShadowTextureCustomCasterPass.setVertexProgramParameters(
                                mShadowTextureCustomCasterVPParams);
                            
                        }
                        
                    }
                    
                }
                else
                {
                    // Standard shadow caster pass, reset to no vp
                    retPass.setVertexProgram(null);
                }
            }
            
            if (pass.getShadowCasterFragmentProgramName() !is null)
            {
                // Have to merge the shadow caster fragment program in
                retPass.setFragmentProgram(
                    pass.getShadowCasterFragmentProgramName(), false);
                //
                GpuProgram prg = retPass.getFragmentProgram().getAs();
                // Load this program if not done already
                if (!prg.isLoaded())
                    prg.load();
                // Copy params
                retPass.setFragmentProgramParameters(
                    pass.getShadowCasterFragmentProgramParameters());
                // Also have to hack the light autoparams, that is done later
            }
            else 
            {
                if (retPass == mShadowTextureCustomCasterPass)
                {
                    // reset fp?
                    if (mShadowTextureCustomCasterPass.getFragmentProgramName() !=
                        mShadowTextureCustomCasterFragmentProgram)
                    {
                        mShadowTextureCustomCasterPass.setFragmentProgram(
                            mShadowTextureCustomCasterFragmentProgram, false);
                        if(mShadowTextureCustomCasterPass.hasFragmentProgram())
                        {
                            mShadowTextureCustomCasterPass.setFragmentProgramParameters(
                                mShadowTextureCustomCasterFPParams);
                        }
                    }
                }
                else
                {
                    // Standard shadow caster pass, reset to no fp
                    retPass.setFragmentProgram(null);
                }
            }
            
            // handle the case where there is no fixed pipeline support
            retPass.getParent().getParent().compile();
            Technique btech = retPass.getParent().getParent().getBestTechnique();
            if( btech )
            {
                retPass = btech.getPass(0);
            }
            
            return retPass;
        }
        else
        {
            return pass;
        }
        
    }
    /** Internal method for turning a regular pass into a shadow receiver pass.
     @remarks
     This is only used for texture shadows, basically we're trying to
     ensure that objects are rendered with a projective texture.
     This method will usually return a standard single-texture pass for
     all fixed function passes, but will merge in a vertex program
     for passes with vertex programs. 
     */
    Pass deriveShadowReceiverPass(/*const*/ Pass pass)
    {
        
        if (isShadowTechniqueTextureBased())
        {
            Pass retPass;
            if (!pass.getParent().getShadowReceiverMaterial().isNull())
            {
                return retPass = pass.getParent().getShadowReceiverMaterial().getAs().getBestTechnique().getPass(0); 
            }
            else
            {
                retPass = mShadowTextureCustomReceiverPass ? 
                    mShadowTextureCustomReceiverPass : mShadowReceiverPass;
            }
            
            // Does incoming pass have a custom shadow receiver program?
            if (pass.getShadowReceiverVertexProgramName() !is null)
            {
                // Have to merge the shadow receiver vertex program in
                retPass.setVertexProgram(
                    pass.getShadowReceiverVertexProgramName(), false);
                //
                GpuProgram prg = retPass.getVertexProgram().getAs();
                // Load this program if not done already
                if (!prg.isLoaded())
                    prg.load();
                // Copy params
                retPass.setVertexProgramParameters(
                    pass.getShadowReceiverVertexProgramParameters());
                // Also have to hack the light autoparams, that is done later
            }
            else 
            {
                if (retPass == mShadowTextureCustomReceiverPass)
                {
                    // reset vp?
                    if (mShadowTextureCustomReceiverPass.getVertexProgramName() !=
                        mShadowTextureCustomReceiverVertexProgram)
                    {
                        mShadowTextureCustomReceiverPass.setVertexProgram(
                            mShadowTextureCustomReceiverVertexProgram, false);
                        if(mShadowTextureCustomReceiverPass.hasVertexProgram())
                        {
                            mShadowTextureCustomReceiverPass.setVertexProgramParameters(
                                mShadowTextureCustomReceiverVPParams);
                            
                        }
                        
                    }
                    
                }
                else
                {
                    // Standard shadow receiver pass, reset to no vp
                    retPass.setVertexProgram(null);
                }
            }
            
            ushort keepTUCount;
            // If additive, need lighting parameters & standard programs
            if (isShadowTechniqueAdditive())
            {
                retPass.setLightingEnabled(true);
                retPass.setAmbient(pass.getAmbient());
                retPass.setSelfIllumination(pass.getSelfIllumination());
                retPass.setDiffuse(pass.getDiffuse());
                retPass.setSpecular(pass.getSpecular());
                retPass.setShininess(pass.getShininess());
                retPass.setIteratePerLight(pass.getIteratePerLight(), 
                                           pass.getRunOnlyForOneLightType(), pass.getOnlyLightType());
                retPass.setLightMask(pass.getLightMask());
                
                // We need to keep alpha rejection settings
                retPass.setAlphaRejectSettings(pass.getAlphaRejectFunction(),
                                               pass.getAlphaRejectValue());
                // Copy texture state, shift up one since 0 is shadow texture
                ushort origPassTUCount = pass.getNumTextureUnitStates();
                foreach (ushort t; 0..origPassTUCount)
                {
                    ushort targetIndex = cast(ushort)(t+1);
                    TextureUnitState tex;
                    if (retPass.getNumTextureUnitStates() <= targetIndex)
                    {
                        tex = retPass.createTextureUnitState();
                    }
                    else
                    {
                        tex = retPass.getTextureUnitState(targetIndex);
                    }
                    //FIXME base copy
                    //(*tex) = *(pass.getTextureUnitState(t));
                    tex._copy((cast(Pass)pass).getTextureUnitState(t));
                    // If programmable, have to adjust the texcoord sets too
                    // D3D insists that texcoordsets match tex unit in programmable mode
                    if (retPass.hasVertexProgram())
                        tex.setTextureCoordSet(targetIndex);
                }
                keepTUCount = cast(ushort)(origPassTUCount + 1);
            }// additive lighting
            else
            {
                // need to keep spotlight fade etc
                keepTUCount = retPass.getNumTextureUnitStates();
            }
            
            
            // Will also need fragment programs since this is a complex light setup
            if (pass.getShadowReceiverFragmentProgramName() !is null)
            {
                // Have to merge the shadow receiver vertex program in
                retPass.setFragmentProgram(
                    pass.getShadowReceiverFragmentProgramName(), false);
                //
                GpuProgram prg = retPass.getFragmentProgram().getAs();
                // Load this program if not done already
                if (!prg.isLoaded())
                    prg.load();
                // Copy params
                retPass.setFragmentProgramParameters(
                    pass.getShadowReceiverFragmentProgramParameters());
                
                // Did we bind a shadow vertex program?
                if (pass.hasVertexProgram() && !retPass.hasVertexProgram())
                {
                    // We didn't bind a receiver-specific program, so bind the original
                    retPass.setVertexProgram(pass.getVertexProgramName(), false);
                    //
                    GpuProgram prog = retPass.getVertexProgram().getAs();
                    // Load this program if required
                    if (!prog.isLoaded())
                        prog.load();
                    // Copy params
                    retPass.setVertexProgramParameters(
                        pass.getVertexProgramParameters());
                    
                }
            }
            else 
            {
                // Reset any merged fragment programs from last time
                if (retPass == mShadowTextureCustomReceiverPass)
                {
                    // reset fp?
                    if (mShadowTextureCustomReceiverPass.getFragmentProgramName() !=
                        mShadowTextureCustomReceiverFragmentProgram)
                    {
                        mShadowTextureCustomReceiverPass.setFragmentProgram(
                            mShadowTextureCustomReceiverFragmentProgram, false);
                        if(mShadowTextureCustomReceiverPass.hasFragmentProgram())
                        {
                            mShadowTextureCustomReceiverPass.setFragmentProgramParameters(
                                mShadowTextureCustomReceiverFPParams);
                            
                        }
                        
                    }
                    
                }
                else
                {
                    // Standard shadow receiver pass, reset to no fp
                    retPass.setFragmentProgram(null);
                }
                
            }
            
            // Remove any extra texture units
            while (retPass.getNumTextureUnitStates() > keepTUCount)
            {
                retPass.removeTextureUnitState(keepTUCount);
            }
            
            retPass._load();
            
            // handle the case where there is no fixed pipeline support
            retPass.getParent().getParent().compile();
            Technique btech = retPass.getParent().getParent().getBestTechnique();
            if( btech )
            {
                retPass = btech.getPass(0);
            }
            
            return retPass;
        }
        else
        {
            return pass;
        }
        
    }
    
    /** Internal method to validate whether a Pass should be allowed to render.
     @remarks
     Called just before a pass is about to be used for rendering a group to
     allow the SceneManager to omit it if required. A return value of false
     skips this pass. 
     */
    bool validatePassForRendering(Pass pass)
    {
        // Bypass if we're doing a texture shadow render and 
        // this pass is after the first (only 1 pass needed for shadow texture render, and 
        // one pass for shadow texture receive for modulative technique)
        // Also bypass if passes above the first if render state changes are
        // suppressed since we're not actually using this pass data anyway
        if (!mSuppressShadows && mCurrentViewport.getShadowsEnabled() &&
            ((isShadowTechniqueModulative() && mIlluminationStage == IlluminationRenderStage.IRS_RENDER_RECEIVER_PASS)
         || mIlluminationStage == IlluminationRenderStage.IRS_RENDER_TO_TEXTURE || mSuppressRenderStateChanges) && 
            pass.getIndex() > 0)
        {
            return false;
        }
        
        // If using late material resolving, check if there is a pass with the same index
        // as this one in the 'late' material. If not, skip.
        if (isLateMaterialResolving())
        {
            Technique lateTech = pass.getParent().getParent().getBestTechnique();
            if (lateTech.getNumPasses() <= pass.getIndex())
            {
                return false;
            }
        }
        
        return true;
    }
    
    /** Internal method to validate whether a Renderable should be allowed to render.
     @remarks
     Called just before a pass is about to be used for rendering a Renderable to
     allow the SceneManager to omit it if required. A return value of false
     skips it. 
     */
    bool validateRenderableForRendering(Pass pass, Renderable rend)
    {
        // Skip this renderable if we're doing modulative texture shadows, it casts shadows
        // and we're doing the render receivers pass and we're not self-shadowing
        // also if pass number > 0
        if (!mSuppressShadows && mCurrentViewport.getShadowsEnabled() &&
            isShadowTechniqueTextureBased())
        {
            if (mIlluminationStage == IlluminationRenderStage.IRS_RENDER_RECEIVER_PASS && 
                rend.getCastsShadows() && !mShadowTextureSelfShadow)
            {
                return false;
            }
            // Some duplication here with validatePassForRendering, for transparents
            if (((isShadowTechniqueModulative() && mIlluminationStage == IlluminationRenderStage.IRS_RENDER_RECEIVER_PASS)
                 || mIlluminationStage == IlluminationRenderStage.IRS_RENDER_TO_TEXTURE || mSuppressRenderStateChanges) && 
                pass.getIndex() > 0)
            {
                return false;
            }
        }
        
        return true;
        
    }
    
    enum BoxPlane
    {
        BP_FRONT = 0,
        BP_BACK = 1,
        BP_LEFT = 2,
        BP_RIGHT = 3,
        BP_UP = 4,
        BP_DOWN = 5
    }
    
    /* Internal utility method for creating the planes of a skybox.
     */
    SharedPtr!Mesh createSkyboxPlane(
        BoxPlane bp,
        Real distance,
        Quaternion orientation,
        string groupName)
    {
        Plane plane;
        string meshName;
        Vector3 up;
        
        meshName = mName ~ "SkyBoxPlane_";
        // Set up plane equation
        plane.d = distance;
        switch(bp)
        {
            case BoxPlane.BP_FRONT:
                plane.normal = Vector3.UNIT_Z;
                up = Vector3.UNIT_Y;
                meshName ~= "Front";
                break;
            case BoxPlane.BP_BACK:
                plane.normal = -Vector3.UNIT_Z;
                up = Vector3.UNIT_Y;
                meshName ~= "Back";
                break;
            case BoxPlane.BP_LEFT:
                plane.normal = Vector3.UNIT_X;
                up = Vector3.UNIT_Y;
                meshName ~= "Left";
                break;
            case BoxPlane.BP_RIGHT:
                plane.normal = -Vector3.UNIT_X;
                up = Vector3.UNIT_Y;
                meshName ~= "Right";
                break;
            case BoxPlane.BP_UP:
                plane.normal = -Vector3.UNIT_Y;
                up = Vector3.UNIT_Z;
                meshName ~= "Up";
                break;
            case BoxPlane.BP_DOWN:
                plane.normal = Vector3.UNIT_Y;
                up = -Vector3.UNIT_Z;
                meshName ~= "Down";
                break;
            default:
                assert(false);
        }
        // Modify by orientation
        plane.normal = orientation * plane.normal;
        up = orientation * up;
        
        
        // Check to see if existing plane
        MeshManager mm = MeshManager.getSingleton();
        SharedPtr!Mesh planeMesh = mm.getByName(meshName, groupName);
        if(!planeMesh.isNull())
        {
            // destroy existing
            mm.remove(planeMesh.get().getHandle());
        }
        // Create new
        Real planeSize = distance * 2;
        int BOX_SEGMENTS = 1;
        planeMesh = mm.createPlane(meshName, groupName, plane, planeSize, planeSize, 
                                   BOX_SEGMENTS, BOX_SEGMENTS, false, 1, 1, 1, up);
        
        //planeMesh._dumpContents(meshName);
        
        return planeMesh;
        
    }
    
    /* Internal utility method for creating the planes of a skydome.
     */
    SharedPtr!Mesh createSkydomePlane(
        BoxPlane bp,
        Real curvature, Real tiling, Real distance,
        Quaternion orientation,
        int xsegments, int ysegments, int ySegmentsToKeep, 
        string groupName)
    {
        
        Plane plane;
        string meshName;
        Vector3 up;
        
        meshName = mName ~ "SkyDomePlane_";
        // Set up plane equation
        plane.d = distance;
        final switch(bp)
        {
            case BoxPlane.BP_FRONT:
                plane.normal = Vector3.UNIT_Z;
                up = Vector3.UNIT_Y;
                meshName ~= "Front";
                break;
            case BoxPlane.BP_BACK:
                plane.normal = -Vector3.UNIT_Z;
                up = Vector3.UNIT_Y;
                meshName ~= "Back";
                break;
            case BoxPlane.BP_LEFT:
                plane.normal = Vector3.UNIT_X;
                up = Vector3.UNIT_Y;
                meshName ~= "Left";
                break;
            case BoxPlane.BP_RIGHT:
                plane.normal = -Vector3.UNIT_X;
                up = Vector3.UNIT_Y;
                meshName ~= "Right";
                break;
            case BoxPlane.BP_UP:
                plane.normal = -Vector3.UNIT_Y;
                up = Vector3.UNIT_Z;
                meshName ~= "Up";
                break;
            case BoxPlane.BP_DOWN:
                // no down
                return SharedPtr!Mesh();
        }
        // Modify by orientation
        plane.normal = orientation * plane.normal;
        up = orientation * up;
        
        // Check to see if existing plane
        MeshManager mm = MeshManager.getSingleton();
        SharedPtr!Mesh planeMesh = mm.getByName(meshName, groupName);
        if(!planeMesh.isNull())
        {
            // destroy existing
            mm.remove(planeMesh.get().getHandle());
        }
        // Create new
        Real planeSize = distance * 2;
        planeMesh = mm.createCurvedIllusionPlane(meshName, groupName, plane, 
                                                 planeSize, planeSize, curvature, 
                                                 xsegments, ysegments, false, 1, tiling, tiling, up, 
                                                 orientation, HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY, 
                                                 HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, 
                                                 false, false, ySegmentsToKeep);
        
        //planeMesh._dumpContents(meshName);
        
        return planeMesh;
        
    }
    
    // Flag indicating whether SceneNodes will be rendered as a set of 3 axes
    bool mDisplayNodes;
    
    /// Storage of animations, lookup by name
    //typedef map<string, Animation*>::type AnimationList;
    alias Animation[string] AnimationList;
    AnimationList mAnimationsList;
    Mutex mAnimationsListMutex;
    AnimationStateSet mAnimationStates;
    
    
    /** Internal method used by _renderSingleObject to deal with renderables
     which override the camera's own view / projection materices. */
    void useRenderableViewProjMode(Renderable pRend, bool fixedFunction)
    {
        // Check view matrix
        bool useIdentityView = pRend.getUseIdentityView();
        if (useIdentityView)
        {
            // Using identity view now, change it
            if (fixedFunction)
                setViewMatrix(Matrix4.IDENTITY);
            mGpuParamsDirty |= GpuParamVariability.GPV_GLOBAL;
            mResetIdentityView = true;
        }
        
        bool useIdentityProj = pRend.getUseIdentityProjection();
        if (useIdentityProj)
        {
            // Use identity projection matrix, still need to take RS depth into account.
            if (fixedFunction)
            {
                Matrix4 mat;
                mDestRenderSystem._convertProjectionMatrix(Matrix4.IDENTITY, mat);
                mDestRenderSystem._setProjectionMatrix(mat);
            }
            mGpuParamsDirty |= GpuParamVariability.GPV_GLOBAL;
            
            mResetIdentityProj = true;
        }
    }
    
    /** Internal method used by _renderSingleObject to deal with renderables
     which override the camera's own view / projection matrices. */
    void resetViewProjMode(bool fixedFunction)
    {
        if (mResetIdentityView)
        {
            // Coming back to normal from identity view
            if (fixedFunction)
                setViewMatrix(mCachedViewMatrix);
            mGpuParamsDirty |= GpuParamVariability.GPV_GLOBAL;
            
            mResetIdentityView = false;
        }
        
        if (mResetIdentityProj)
        {
            // Coming back from flat projection
            if (fixedFunction)
                mDestRenderSystem._setProjectionMatrix(mCameraInProgress.getProjectionMatrixRS());
            mGpuParamsDirty |= GpuParamVariability.GPV_GLOBAL;
            
            mResetIdentityProj = false;
        }
    }
    
    //typedef vector<RenderQueueListener*>::type RenderQueueListenerList;
    alias RenderQueueListener[] RenderQueueListenerList;
    RenderQueueListenerList mRenderQueueListeners;
    
    //typedef vector<RenderObjectListener*>::type RenderObjectListenerList;
    alias RenderObjectListener[] RenderObjectListenerList;
    RenderObjectListenerList mRenderObjectListeners;
    //typedef vector<Listener*>::type ListenerList;
    alias Listener[] ListenerList;
    ListenerList mListeners;
    /// Internal method for firing the queue start event
    void firePreRenderQueues()
    {
        foreach (l;mRenderQueueListeners)
        {
            l.preRenderQueues();
        }
    }
    /// Internal method for firing the queue end event
    void firePostRenderQueues()
    {
        foreach (l;mRenderQueueListeners)
        {
            l.postRenderQueues();
        }
    }
    /// Internal method for firing the queue start event, returns true if queue is to be skipped
    bool fireRenderQueueStarted(ubyte id, string invocation)
    {
        bool skip = false;
        foreach (l;mRenderQueueListeners)
        {
            l.renderQueueStarted(id, invocation, skip);
        }
        return skip;
    }
    /// Internal method for firing the queue end event, returns true if queue is to be repeated
    bool fireRenderQueueEnded(ubyte id, string invocation)
    {
        bool repeat = false;
        foreach (l;mRenderQueueListeners)
        {
            l.renderQueueStarted(id, invocation, repeat);
        }
        return repeat;
    }
    /// Internal method for firing when rendering a single object.
    void fireRenderSingleObject(Renderable rend, Pass pass, AutoParamDataSource source, 
                                LightList pLightList, bool suppressRenderStateChanges)
    {
        foreach (l; mRenderObjectListeners)
        {
            l.notifyRenderSingleObject(rend, pass, source, pLightList, suppressRenderStateChanges);
        }
    }
    
    /// Internal method for firing the texture shadows updated event
    void fireShadowTexturesUpdated(size_t numberOfShadowTextures)
    {
        ListenerList listenersCopy = mListeners.dup;
        
        foreach (l; listenersCopy)
        {
            l.shadowTexturesUpdated(numberOfShadowTextures);
        }
    }
    
    /// Internal method for firing the pre caster texture shadows event
    void fireShadowTexturesPreCaster(Light light, Camera camera, size_t iteration)
    {
        ListenerList listenersCopy = mListeners.dup;
        foreach (l; listenersCopy)
        {
            l.shadowTextureCasterPreViewProj(light, camera, iteration);
        }
    }
    
    /// Internal method for firing the pre receiver texture shadows event
    void fireShadowTexturesPreReceiver(Light light, Frustum f)
    {
        ListenerList listenersCopy = mListeners.dup;
        foreach (l; listenersCopy)
        {
            l.shadowTextureReceiverPreViewProj(light, f);
        }
    }
    /// Internal method for firing pre update scene graph event
    void firePreUpdateSceneGraph(Camera camera)
    {
        ListenerList listenersCopy = mListeners.dup;
        foreach (l; listenersCopy)
        {
            l.preUpdateSceneGraph(this, camera);
        }
    }
    /// Internal method for firing post update scene graph event
    void firePostUpdateSceneGraph(Camera camera)
    {
        ListenerList listenersCopy = mListeners.dup;
        foreach (l; listenersCopy)
        {
            l.postUpdateSceneGraph(this, camera);
        }
    }
    /// Internal method for firing find visible objects event
    void firePreFindVisibleObjects(Viewport v)
    {
        ListenerList listenersCopy = mListeners.dup;
        foreach (l; listenersCopy)
        {
            l.preFindVisibleObjects(this, mIlluminationStage, v);
        }
    }
    /// Internal method for firing find visible objects event
    void firePostFindVisibleObjects(Viewport v)
    {
        ListenerList listenersCopy = mListeners.dup;
        foreach (l; listenersCopy)
        {
            l.postFindVisibleObjects(this, mIlluminationStage, v);
        }
    }
    /// Internal method for firing destruction event
    void fireSceneManagerDestroyed()
    {
        ListenerList listenersCopy = mListeners.dup;
        foreach (l; listenersCopy)
        {
            l.sceneManagerDestroyed(this);
        }
    }
    /** Internal method for setting the destination viewport for the next render. */
    void setViewport(Viewport vp)
    {
        mCurrentViewport = vp;
        // Set viewport in render system
        mDestRenderSystem._setViewport(vp);
        // Set the active material scheme for this viewport
        MaterialManager.getSingleton().setActiveScheme(vp.getMaterialScheme());
    }
    
    /** Flag that indicates if all of the scene node's bounding boxes should be shown as a wireframe. */
    bool mShowBoundingBoxes;      
    
    /** Internal method for rendering all objects using the default queue sequence. */
    void renderVisibleObjectsDefaultSequence()
    {
        firePreRenderQueues();
        
        // Render each separate queue
        auto queueIt = getRenderQueue()._getQueueGroups();
        debug(STDERR) std.stdio.stderr.writeln("renderVisibleObjectsDefaultSequence:", queueIt);
        // NB only queues which have been created are rendered, no time is wasted
        //   parsing through non-existent queues (even though there are 10 available)
        
        //while (queueIt.hasMoreElements())
        foreach (qId, pGroup; queueIt)
        {
            //debug(STDERR) std.stdio.stderr.writeln("\t:", qId, ",", pGroup.getPriorityMap());
            // Skip this one if not to be processed
            if (!isRenderQueueToBeProcessed(qId))
                continue;
            
            
            bool repeatQueue = false;
            do // for repeating queues
            {
                // Fire queue started event
                if (fireRenderQueueStarted(qId, 
                                           mIlluminationStage == IlluminationRenderStage.IRS_RENDER_TO_TEXTURE ? 
                                           RenderQueueInvocation.RENDER_QUEUE_INVOCATION_SHADOWS : 
                                           ""))
                {
                    // Someone requested we skip this queue
                    break;
                }
                
                _renderQueueGroupObjects(pGroup, QueuedRenderableCollection.OrganisationMode.OM_PASS_GROUP);
                
                // Fire queue ended event
                if (fireRenderQueueEnded(qId, 
                                         mIlluminationStage == IlluminationRenderStage.IRS_RENDER_TO_TEXTURE ? 
                                         RenderQueueInvocation.RENDER_QUEUE_INVOCATION_SHADOWS : 
                                         ""))
                {
                    // Someone requested we repeat this queue
                    repeatQueue = true;
                }
                else
                {
                    repeatQueue = false;
                }
            } while (repeatQueue);
            
        } // for each queue group
        
        firePostRenderQueues();
        
    }
    /** Internal method for rendering all objects using a custom queue sequence. */
    void renderVisibleObjectsCustomSequence(RenderQueueInvocationSequence seq)
    {
        firePreRenderQueues();
        debug(STDERR) std.stdio.stderr.writeln("renderVisibleObjectsCustomSequence:", seq.getList());
        //auto invocationIt = seq.iterator();
        //while (invocationIt.hasMoreElements())
        foreach(invocation; seq.getList())
        {
            //RenderQueueInvocation* invocation = invocationIt.getNext();
            ubyte qId = invocation.getRenderQueueGroupID();
            // Skip this one if not to be processed
            if (!isRenderQueueToBeProcessed(qId))
                continue;
            
            
            bool repeatQueue = false;
            string invocationName = invocation.getInvocationName();
            RenderQueueGroup queueGroup = getRenderQueue().getQueueGroup(qId);
            do // for repeating queues
            {
                // Fire queue started event
                if (fireRenderQueueStarted(qId, invocationName))
                {
                    // Someone requested we skip this queue
                    break;
                }
                
                // Invoke it
                invocation.invoke(queueGroup, this);
                
                // Fire queue ended event
                if (fireRenderQueueEnded(qId, invocationName))
                {
                    // Someone requested we repeat this queue
                    repeatQueue = true;
                }
                else
                {
                    repeatQueue = false;
                }
            } while (repeatQueue);
            
            
        }
        
        firePostRenderQueues();
    }
    /** Internal method for preparing the render queue for use with each render. */
    void prepareRenderQueue()
    {
        RenderQueue q = getRenderQueue();
        // Clear the render queue
        q.clear(Root.getSingleton().getRemoveRenderQueueStructuresOnClear());
        
        // Prep the ordering options
        
        // If we're using a custom render squence, define based on that
        RenderQueueInvocationSequence seq = 
            mCurrentViewport._getRenderQueueInvocationSequence();
        if (seq)
        {
            // Iterate once to crate / reset all
            //RenderQueueInvocationIterator invokeIt = seq.iterator();
            //while (invokeIt.hasMoreElements())
            foreach(invocation; seq.getList())
            {
                RenderQueueGroup group = 
                    q.getQueueGroup(invocation.getRenderQueueGroupID());
                group.resetOrganisationModes();
            }
            // Iterate again to build up options (may be more than one)
            foreach(invocation; seq.getList())
            {
                RenderQueueGroup group = 
                    q.getQueueGroup(invocation.getRenderQueueGroupID());
                group.addOrganisationMode(invocation.getSolidsOrganisation());
                // also set splitting options
                updateRenderQueueGroupSplitOptions(group, invocation.getSuppressShadows(), 
                                                   invocation.getSuppressRenderStateChanges());
            }
            
            mLastRenderQueueInvocationCustom = true;
        }
        else
        {
            if (mLastRenderQueueInvocationCustom)
            {
                // We need this here to reset if coming out of a render queue sequence, 
                // but doing it resets any specialised settings set globally per render queue 
                // so only do it when necessary - it's nice to allow people to set the organisation
                // mode manually for example
                
                // Default all the queue groups that are there, new ones will be created
                // with defaults too
                foreach(g; q._getQueueGroups())
                {
                    g.defaultOrganisationMode();
                }
            }
            
            // Global split options
            updateRenderQueueSplitOptions();
            
            mLastRenderQueueInvocationCustom = false;
        }
        
    }
    
    
    /** Internal utility method for rendering a single object. 
     @remarks
     Assumes that the pass has already been set up.
     @param rend The renderable to issue to the pipeline
     @param pass The pass which is being used
     @param lightScissoringClipping If true, passes that have the getLightScissorEnabled
     and/or getLightClipPlanesEnabled flags will cause calculation and setting of 
     scissor rectangle and user clip planes. 
     @param doLightIteration If true, this method will issue the renderable to
     the pipeline possibly multiple times, if the pass indicates it should be
     done once per light
     @param manualLightList Only applicable if doLightIteration is false, this
     method allows you to pass in a previously determined set of lights
     which will be used for a single render of this object.
     */
    void renderSingleObject(Renderable rend,Pass pass, 
                            bool lightScissoringClipping, bool doLightIteration, 
                            LightList manualLightList = LightList.init)
    {
        ushort numMatrices;
        RenderOperation ro = new RenderOperation;
        debug(STDERR) std.stdio.stderr.writeln("SM.renderSingleObject: ", rend);
        //TODO profiling
        mixin(OgreProfileBeginGPUEvent("Material: \" ~ pass.getParent().getParent().getName() ~ \""));
        
        ro.srcRenderable = rend;
        
        GpuProgram vprog = pass.hasVertexProgram() ? pass.getVertexProgram().getAs() : null;
        
        bool passTransformState = true;
        
        if (vprog !is null)
        {
            passTransformState = vprog.getPassTransformStates();
        }
        
        // Set world transformation
        numMatrices = rend.getNumWorldTransforms();
        
        if (numMatrices > 0)
        {
            Matrix4[] t = mTempXform;
            rend.getWorldTransforms(t);
            
            if (mCameraRelativeRendering && !rend.getUseIdentityView())
            {
                foreach (ushort i; 0..numMatrices)
                {
                    mTempXform[i].setTrans(mTempXform[i].getTrans() - mCameraRelativePosition);
                }
            }
            
            if (passTransformState)
            {
                if (numMatrices > 1)
                {
                    mDestRenderSystem._setWorldMatrices(mTempXform, numMatrices);
                }
                else
                {
                    mDestRenderSystem._setWorldMatrix(mTempXform[0]);
                }
            }
        }
        // Issue view / projection changes if any
        useRenderableViewProjMode(rend, passTransformState);
        
        // mark per-object params as dirty
        mGpuParamsDirty |= GpuParamVariability.GPV_PER_OBJECT;
        
        if (!mSuppressRenderStateChanges)
        {
            bool passSurfaceAndLightParams = true;
            
            if (pass.isProgrammable())
            {
                // Tell auto params object about the renderable change
                mAutoParamDataSource.setCurrentRenderable(rend);
                // Tell auto params object about the world matrices, eliminated query from renderable again
                mAutoParamDataSource.setWorldMatrices(mTempXform, numMatrices);
                if (vprog !is null)
                {
                    passSurfaceAndLightParams = vprog.getPassSurfaceAndLightStates();
                }
            }
            
            // Reissue any texture gen settings which are dependent on view matrix
            Pass.TextureUnitStates texIter = cast(Pass.TextureUnitStates)pass.getTextureUnitStates();
            size_t unit = 0;
            foreach(pTex; texIter)
            {
                if (pTex.hasViewRelativeTextureCoordinateGeneration())
                {
                    mDestRenderSystem._setTextureUnitSettings(unit, pTex);
                }
                ++unit;
            }
            
            // Sort out normalisation
            // Assume first world matrix representative - shaders that use multiple
            // matrices should control renormalisation themselves
            if ((pass.getNormaliseNormals() || mNormaliseNormalsOnScale)
                && mTempXform[0].hasScale())
                mDestRenderSystem.setNormaliseNormals(true);
            else
                mDestRenderSystem.setNormaliseNormals(false);
            
            // Sort out negative scaling
            // Assume first world matrix representative 
            if (mFlipCullingOnNegativeScale)
            {
                CullingMode cullMode = mPassCullingMode;
                
                if (mTempXform[0].hasNegativeScale())
                {
                    switch(mPassCullingMode)
                    {
                        case CullingMode.CULL_CLOCKWISE:
                            cullMode = CullingMode.CULL_ANTICLOCKWISE;
                            break;
                        case CullingMode.CULL_ANTICLOCKWISE:
                            cullMode = CullingMode.CULL_CLOCKWISE;
                            break;
                        case CullingMode.CULL_NONE:
                            break;
                        default:
                            assert(0);
                    }
                }
                
                // this also copes with returning from negative scale in previous render op
                // for same pass
                if (cullMode != mDestRenderSystem._getCullingMode())
                    mDestRenderSystem._setCullingMode(cullMode);
            }
            
            // Set up the solid / wireframe override
            // Precedence is Camera, Object, Material
            // Camera might not override object if not overrideable
            PolygonMode reqMode = pass.getPolygonMode();
            if (pass.getPolygonModeOverrideable() && rend.getPolygonModeOverrideable())
            {
                PolygonMode camPolyMode = mCameraInProgress.getPolygonMode();
                // check camera detial only when render detail is overridable
                if (reqMode > camPolyMode)
                {
                    // only downgrade detail; if cam says wireframe we don't go up to solid
                    reqMode = camPolyMode;
                }
            }
            mDestRenderSystem._setPolygonMode(reqMode);
            
            if (doLightIteration)
            {
                // Create local light list for faster light iteration setup
                static LightList localLightList;
                
                
                // Here's where we issue the rendering operation to the render system
                // Note that we may do this once per light, therefore it's in a loop
                // and the light parameters are updated once per traversal through the
                // loop
                //
                LightList rendLightList = rend.getLights();
                
                bool iteratePerLight = pass.getIteratePerLight();
                
                // deliberately unsigned in case start light exceeds number of lights
                // in which case this pass would be skipped
                int lightsLeft = 1;
                if (iteratePerLight)
                {
                    lightsLeft = cast(int)(rendLightList.length) - pass.getStartLight();
                    // Don't allow total light count for all iterations to exceed max per pass
                    if (lightsLeft > cast(int)(pass.getMaxSimultaneousLights()))
                    {
                        lightsLeft = cast(int)(pass.getMaxSimultaneousLights());
                    }
                }
                
                
                //
                LightList pLightListToUse;
                // Start counting from the start light
                size_t lightIndex = pass.getStartLight();
                size_t depthInc = 0;
                
                while (lightsLeft > 0)
                {
                    // Determine light list to use
                    if (iteratePerLight)
                    {
                        // Starting shadow texture index.
                        size_t shadowTexIndex = mShadowTextures.length;
                        if (mShadowTextureIndexLightList.length > lightIndex)
                            shadowTexIndex = mShadowTextureIndexLightList[lightIndex];
                        
                        localLightList.length = pass.getLightCountPerIteration();// TODO .reserve(), Why not just insert/insert?
                        
                        //LightList::iterator destit = localLightList.begin();
                        int destit = 0;
                        ushort numShadowTextureLights = 0;
                        for (; destit < localLightList.length 
                             && lightIndex < rendLightList.length; 
                             ++lightIndex, --lightsLeft)
                        {
                            Light currLight = rendLightList[lightIndex];
                            
                            // Check whether we need to filter this one out
                            if ((pass.getRunOnlyForOneLightType() && 
                                 pass.getOnlyLightType() != currLight.getType()) ||
                                (pass.getLightMask() & currLight.getLightMask()) == 0)
                            {
                                // Skip
                                // Also skip shadow texture(s)
                                if (isShadowTechniqueTextureBased())
                                {
                                    shadowTexIndex += mShadowTextureCountPerType[currLight.getType()];
                                }
                                continue;
                            }
                            
                            localLightList[destit++] = currLight;
                            
                            // potentially need to update content_type shadow texunit
                            // corresponding to this light
                            if (isShadowTechniqueTextureBased())
                            {
                                size_t textureCountPerLight = mShadowTextureCountPerType[currLight.getType()];
                                for (size_t j = 0; j < textureCountPerLight && shadowTexIndex < mShadowTextures.length; ++j)
                                {
                                    // link the numShadowTextureLights'th shadow texture unit
                                    ushort tuindex = 
                                        pass._getTextureUnitWithContentTypeIndex(
                                            TextureUnitState.ContentType.CONTENT_SHADOW, numShadowTextureLights);
                                    if (tuindex > pass.getNumTextureUnitStates()) break;
                                    
                                    // I know, nasty_cast
                                    TextureUnitState tu = 
                                        cast(TextureUnitState)(
                                            pass.getTextureUnitState(tuindex));
                                    //
                                    SharedPtr!Texture shadowTex = mShadowTextures[shadowTexIndex];
                                    tu._setTexturePtr(shadowTex);
                                    Camera cam = shadowTex.getAs().getBuffer().get().getRenderTarget().getViewport(0).getCamera();

                                    tu.setProjectiveTexturing(!pass.hasVertexProgram(), cam);
                                    mAutoParamDataSource.setTextureProjector(cam, numShadowTextureLights);

                                    ++numShadowTextureLights;
                                    ++shadowTexIndex;
                                    // Have to set TU on rendersystem right now, although
                                    // autoparams will be set later
                                    mDestRenderSystem._setTextureUnitSettings(tuindex, tu);
                                }
                            }
                            
                            
                            
                        }
                        // Did we run out of lights before slots? e.g. 5 lights, 2 per iteration
                        if (destit < localLightList.length)
                        {
                            //localLightList.erase(destit, localLightList.end());
                            //localLightList.removeFromArray(localLightList[destit..$]);
                            localLightList.length = destit;
                            lightsLeft = 0;
                        }
                        pLightListToUse = localLightList;
                        
                        // deal with the case where we found no lights
                        // since this is light iteration, we shouldn't render at all
                        if (pLightListToUse.empty())
                            return;
                        
                    }
                    else // !iterate per light
                    {
                        // Use complete light list potentially adjusted by start light
                        if (pass.getStartLight() || pass.getMaxSimultaneousLights() != OGRE_MAX_SIMULTANEOUS_LIGHTS || 
                            pass.getLightMask() != 0xFFFFFFFF)
                        {
                            // out of lights?
                            // skip manual 2nd lighting passes onwards if we run out of lights, but never the first one
                            if (pass.getStartLight() > 0 &&
                                pass.getStartLight() >= rendLightList.length)
                            {
                                break;
                            }
                            else
                            {
                                localLightList.clear();
                                //LightList::const_iterator copyStart = rendLightList.begin();
                                //std::advance(copyStart, pass.getStartLight());
                                // Clamp lights to copy to avoid overrunning the end of the list
                                size_t lightsCopied = 0, lightsToCopy = std.algorithm.min(
                                    pass.getMaxSimultaneousLights(), 
                                    rendLightList.length - pass.getStartLight());
                                
                                //localLightList.insert(localLightList.begin(), 
                                //  copyStart, copyEnd);
                                
                                // Copy lights over
                                foreach(light; rendLightList[pass.getStartLight() .. $])
                                {
                                    if( lightsCopied >= lightsToCopy) break;
                                    if((pass.getLightMask() & light.getLightMask()) != 0)
                                    {
                                        localLightList.insert(light);
                                        lightsCopied++;
                                    }
                                }
                                
                                pLightListToUse = localLightList;
                            }
                        }
                        else
                        {
                            pLightListToUse = rendLightList;
                        }
                        lightsLeft = 0;
                    }
                    
                    fireRenderSingleObject(rend, pass, mAutoParamDataSource, pLightListToUse, mSuppressRenderStateChanges);
                    
                    // Do we need to update GPU program parameters?
                    if (pass.isProgrammable())
                    {
                        useLightsGpuProgram(pass, pLightListToUse);
                    }
                    // Do we need to update light states? 
                    // Only do this if fixed-function vertex lighting applies
                    if (pass.getLightingEnabled() && passSurfaceAndLightParams)
                    {
                        useLights(pLightListToUse, pass.getMaxSimultaneousLights());
                    }
                    // optional light scissoring & clipping
                    ClipResult scissored = ClipResult.CLIPPED_NONE;
                    ClipResult clipped = ClipResult.CLIPPED_NONE;
                    if (lightScissoringClipping && 
                        (pass.getLightScissoringEnabled() || pass.getLightClipPlanesEnabled()))
                    {
                        // if there's no lights hitting the scene, then we might as 
                        // well stop since clipping cannot include anything
                        if (pLightListToUse.empty())
                            continue;
                        
                        if (pass.getLightScissoringEnabled())
                            scissored = buildAndSetScissor(pLightListToUse, mCameraInProgress);
                        
                        if (pass.getLightClipPlanesEnabled())
                            clipped = buildAndSetLightClip(pLightListToUse);
                        
                        if (scissored == ClipResult.CLIPPED_ALL || clipped == ClipResult.CLIPPED_ALL)
                            continue;
                    }
                    // issue the render op      
                    // nfz: check for gpu_multipass
                    mDestRenderSystem.setCurrentPassIterationCount(pass.getPassIterationCount());
                    // We might need to update the depth bias each iteration
                    if (pass.getIterationDepthBias() != 0.0f)
                    {
                        float depthBiasBase = pass.getDepthBiasConstant() + 
                            pass.getIterationDepthBias() * depthInc;
                        // depthInc deals with light iteration 
                        
                        // Note that we have to set the depth bias here even if the depthInc
                        // is zero (in which case you would think there is no change from
                        // what was set in _setPass(). The reason is that if there are
                        // multiple Renderables with this Pass, we won't go through _setPass
                        // again at the start of the iteration for the next Renderable
                        // because of Pass state grouping. So set it always
                        
                        // Set modified depth bias right away
                        mDestRenderSystem._setDepthBias(depthBiasBase, pass.getDepthBiasSlopeScale());
                        
                        // Set to increment internally too if rendersystem iterates
                        mDestRenderSystem.setDeriveDepthBias(true, 
                                                             depthBiasBase, pass.getIterationDepthBias(), 
                                                             pass.getDepthBiasSlopeScale());
                    }
                    else
                    {
                        mDestRenderSystem.setDeriveDepthBias(false);
                    }
                    depthInc += pass.getPassIterationCount();
                    
                    // Finalise GPU parameter bindings
                    updateGpuProgramParameters(pass);
                    
                    rend.getRenderOperation(ro);
                    
                    if (rend.preRender(this, mDestRenderSystem))
                        mDestRenderSystem._render(ro);
                    rend.postRender(this, mDestRenderSystem);
                    
                    if (scissored == ClipResult.CLIPPED_SOME)
                        resetScissor();
                    if (clipped == ClipResult.CLIPPED_SOME)
                        resetLightClip();
                } // possibly iterate per light
            }
            else // no automatic light processing
            {
                // Even if manually driving lights, check light type passes
                bool skipBecauseOfLightType = false;
                if (pass.getRunOnlyForOneLightType())
                {
                    if ( //!manualLightList ||
                        (manualLightList.length == 1 && 
                     (cast(LightList)manualLightList)[0].getType() != pass.getOnlyLightType()))
                    {
                        skipBecauseOfLightType = true;
                    }
                }
                
                if (!skipBecauseOfLightType)
                {
                    fireRenderSingleObject(rend, pass, mAutoParamDataSource, manualLightList, mSuppressRenderStateChanges);
                    // Do we need to update GPU program parameters?
                    if (pass.isProgrammable())
                    {
                        // Do we have a manual light list?
                        if (manualLightList.length)
                        {
                            useLightsGpuProgram(pass, manualLightList);
                        }
                        
                    }
                    
                    // Use manual lights if present, and not using vertex programs that don't use fixed pipeline
                    if (manualLightList.length && 
                        pass.getLightingEnabled() && passSurfaceAndLightParams)
                    {
                        useLights(manualLightList, pass.getMaxSimultaneousLights());
                    }
                    
                    // optional light scissoring
                    ClipResult scissored = ClipResult.CLIPPED_NONE;
                    ClipResult clipped = ClipResult.CLIPPED_NONE;
                    if (lightScissoringClipping && manualLightList.length && pass.getLightScissoringEnabled())
                    {
                        scissored = buildAndSetScissor(manualLightList, mCameraInProgress);
                    }
                    if (lightScissoringClipping && manualLightList.length && pass.getLightClipPlanesEnabled())
                    {
                        clipped = buildAndSetLightClip(manualLightList);
                    }
                    
                    // don't bother rendering if clipped / scissored entirely
                    if (scissored != ClipResult.CLIPPED_ALL && clipped != ClipResult.CLIPPED_ALL)
                    {
                        // issue the render op      
                        // nfz: set up multipass rendering
                        mDestRenderSystem.setCurrentPassIterationCount(pass.getPassIterationCount());
                        // Finalise GPU parameter bindings
                        updateGpuProgramParameters(pass);
                        
                        rend.getRenderOperation(ro);
                        
                        if (rend.preRender(this, mDestRenderSystem))
                            mDestRenderSystem._render(ro);
                        rend.postRender(this, mDestRenderSystem);
                    }
                    if (scissored == ClipResult.CLIPPED_SOME)
                        resetScissor();
                    if (clipped == ClipResult.CLIPPED_SOME)
                        resetLightClip();
                    
                } // !skipBecauseOfLightType
            }
            
        }
        else // mSuppressRenderStateChanges
        {
            fireRenderSingleObject(rend, pass, mAutoParamDataSource, LightList.init, mSuppressRenderStateChanges);
            // Just render
            mDestRenderSystem.setCurrentPassIterationCount(1);
            if (rend.preRender(this, mDestRenderSystem))
            {
                rend.getRenderOperation(ro);
                try
                {
                    mDestRenderSystem._render(ro);
                }
                catch (RenderingApiError e)
                {
                    throw new RenderingApiError(
                                "Exception when rendering material: " ~ pass.getParent().getParent().getName() ~
                                "\nOriginal Exception description: " ~ e.msg ~ "\n" ,
                                "SceneManager.renderSingleObject");
                    
                }
            }
            rend.postRender(this, mDestRenderSystem);
        }
        
        // Reset view / projection changes if any
        resetViewProjMode(passTransformState);
        //XamarinStudio/MonoDevelop fails at rendering escaped quote :S
        mixin(OgreProfileEndGPUEvent("Material: \" ~ pass.getParent().getParent().getName() ~ \""));
    }
    
    /** Internal method for creating the AutoParamDataSource instance. */
    AutoParamDataSource createAutoParamDataSource()
    {
        return new AutoParamDataSource();
    }
    
    /// Utility class for calculating automatic parameters for gpu programs
    AutoParamDataSource mAutoParamDataSource;
    
    CompositorChain mActiveCompositorChain;
    bool mLateMaterialResolving;
    
    ShadowTechnique mShadowTechnique;
    bool mDebugShadows;
    ColourValue mShadowColour;
    Pass mShadowDebugPass;
    Pass mShadowStencilPass;
    Pass mShadowModulativePass;
    bool mShadowMaterialInitDone;
    SharedPtr!HardwareIndexBuffer mShadowIndexBuffer;
    size_t mShadowIndexBufferSize;
    Rectangle2D mFullScreenQuad;
    Real mShadowDirLightExtrudeDist;
    IlluminationRenderStage mIlluminationStage;
    ShadowTextureConfigList mShadowTextureConfigList;
    bool mShadowTextureConfigDirty;
    ShadowTextureList mShadowTextures;
    SharedPtr!Texture mNullShadowTexture;
    //typedef vector<Camera*>::type ShadowTextureCameraList;
    alias Camera[] ShadowTextureCameraList;
    ShadowTextureCameraList mShadowTextureCameras;
    SharedPtr!Texture mCurrentShadowTexture;
    bool mShadowUseInfiniteFarPlane;
    bool mShadowCasterRenderBackFaces;
    bool mShadowAdditiveLightClip;
    /// Struct for cacheing light clipping information for re-use in a frame
    struct LightClippingInfo
    {
        RealRect scissorRect;
        PlaneList clipPlanes;
        bool scissorValid = false;
        ulong clipPlanesValid = 0;
    }
    //typedef map<Light*, LightClippingInfo>::type LightClippingInfoMap;
    alias LightClippingInfo[Light] LightClippingInfoMap;
    LightClippingInfoMap mLightClippingInfoMap;
    ulong mLightClippingInfoMapFrameNumber;
    
    /// default shadow camera setup
    ShadowCameraSetupPtr mDefaultShadowCameraSetup;
    
    /** Default sorting routine which sorts lights which cast shadows
     to the front of a list, sub-sorting by distance.
     @remarks
     Since shadow textures are generated from lights based on the
     frustum rather than individual objects, a shadow and camera-wise sort is
     required to pick the best lights near the start of the list. Up to 
     the number of shadow textures will be generated from this.
     */
    static bool lightsForShadowTextureLess(Light l1, Light l2)//;
    {
        if (l1 == l2)
            return false;
        
        // sort shadow casting lights ahead of non-shadow casting
        if (l1.getCastShadows() != l2.getCastShadows())
        {
            return l1.getCastShadows();
        }
        
        // otherwise sort by distance (directional lights will have 0 here)
        return l1.tempSquareDist < l2.tempSquareDist;
        
    }
    
    /** Internal method for locating a list of lights which could be affecting the frustum. 
     @remarks
     Custom scene managers are encouraged to override this method to make use of their
     scene partitioning scheme to more efficiently locate lights, and to eliminate lights
     which may be occluded by word geometry.
     */
    void findLightsAffectingFrustum(Camera camera)
    {
        // Basic iteration for this SM
        debug(STDERR) std.stdio.stderr.writeln("findLightsAffectingFrustum: ");
        MovableObjectCollection* lights =
            getMovableObjectCollection(LightFactory.FACTORY_TYPE_NAME);
        
        synchronized((*lights).mLock)
        {
            //OGRE_LOCK_MUTEX(lights.mutex)
            
            // Pre-allocate memory
            mTestLightInfos.clear();
            //TODO No. Maybe reserve() has some point?
            //mTestLightInfos.length = (*lights).map.lengthAA;
            
            //MovableObjectIterator it(lights.map.begin(), lights.map.end());
            
            //while(it.hasMoreElements())
            foreach(k, it; (*lights).map)
            {
                Light l = cast(Light)(it);
                debug(STDERR) std.stdio.stderr.writeln("\tlight: ",l);
                
                if (mCameraRelativeRendering)
                    l._setCameraRelative(mCameraInProgress);
                else
                    l._setCameraRelative(null);
                
                if (l.isVisible())
                {
                    LightInfo lightInfo;
                    lightInfo.light = l;
                    lightInfo.type = l.getType();
                    lightInfo.lightMask = l.getLightMask();
                    if (lightInfo.type == Light.LightTypes.LT_DIRECTIONAL)
                    {
                        // Always visible
                        lightInfo.position = Vector3.ZERO;
                        lightInfo.range = 0;
                        mTestLightInfos.insert(lightInfo);
                    }
                    else
                    {
                        // NB treating spotlight as point for simplicity
                        // Just see if the lights attenuation range is within the frustum
                        lightInfo.range = l.getAttenuationRange();
                        lightInfo.position = l.getDerivedPosition();
                        auto sphere = Sphere(lightInfo.position, lightInfo.range);
                        if (camera.isVisible(sphere,null))
                        {
                            mTestLightInfos.insert(lightInfo);
                        }
                    }
                }
            }
        } // release lock on lights collection
        
        // Update lights affecting frustum if changed
        if (!std.algorithm.equal(mCachedLightInfos[], mTestLightInfos))
        {
            mLightsAffectingFrustum.length = mTestLightInfos.length;
            
            debug(STDERR) std.stdio.stderr.writeln("\tforeach: ", mTestLightInfos);
            //LightList::iterator j = mLightsAffectingFrustum.begin();
            int j = 0;
            foreach (i; mTestLightInfos)
            {
                
                mLightsAffectingFrustum[j] = i.light;
                debug(STDERR) std.stdio.stderr.writeln("\t",j, " = ", mLightsAffectingFrustum[j]);
                // add cam distance for sorting if texture shadows
                if (isShadowTechniqueTextureBased())
                {
                    mLightsAffectingFrustum[j]._calcTempSquareDist(camera.getDerivedPosition());
                }
                j++;
            }
            
            // Sort the lights if using texture shadows, since the first 'n' will be
            // used to generate shadow textures and we should pick the most appropriate
            if (isShadowTechniqueTextureBased())
            {
                // Allow a Listener to override light sorting
                // Reverse iterate so last takes precedence
                bool overridden = false;
                ListenerList listenersCopy = mListeners.dup;
                foreach_reverse (ri; listenersCopy)
                {
                    overridden = ri.sortLightsAffectingFrustum(mLightsAffectingFrustum);
                    if (overridden)
                        break;
                }
                if (!overridden)
                {
                    // default sort (stable to preserve directional light ordering
                    //std::stable_sort(
                    std.algorithm.sort!lightsForShadowTextureLess(mLightsAffectingFrustum[]);
                }
                
            }
            
            // Use swap instead of copy operator for efficiently
            //mCachedLightInfos.swap(mTestLightInfos);
            std.algorithm.swap(mCachedLightInfos, mTestLightInfos); //TODO Swapping
            //mCachedLightInfos = mTestLightInfos.dup;
            
            // notify light dirty, so all movable objects will re-populate
            // their light list next time
            _notifyLightsDirty();
        }
        
    }
    
    /// Internal method for setting up materials for shadows
    void initShadowVolumeMaterials()
    {
        /* This should have been set in the SceneManager constructor, but if you
         created the SceneManager BEFORE the Root object, you will need to call
         SceneManager::_setDestinationRenderSystem manually.
         */
        assert( mDestRenderSystem !is null );
        
        if (mShadowMaterialInitDone)
            return;
        
        if (!mShadowDebugPass)
        {
            SharedPtr!Material matDebug = 
                cast(SharedPtr!Material)MaterialManager.getSingleton().getByName("Ogre/Debug/ShadowVolumes");
            if (matDebug.isNull())
            {
                // Create
                matDebug = MaterialManager.getSingleton().create(
                    "Ogre/Debug/ShadowVolumes", 
                    ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME);
                mShadowDebugPass = matDebug.getAs().getTechnique(0).getPass(0);
                mShadowDebugPass.setSceneBlending(SceneBlendType.SBT_ADD); 
                mShadowDebugPass.setLightingEnabled(false);
                mShadowDebugPass.setDepthWriteEnabled(false);
                TextureUnitState t = mShadowDebugPass.createTextureUnitState();
                t.setColourOperationEx(LayerBlendOperationEx.LBX_MODULATE, LayerBlendSource.LBS_MANUAL, LayerBlendSource.LBS_CURRENT, 
                                       ColourValue(0.7, 0.0, 0.2));
                mShadowDebugPass.setCullingMode(CullingMode.CULL_NONE);
                
                if (mDestRenderSystem.getCapabilities().hasCapability(
                    Capabilities.RSC_VERTEX_PROGRAM))
                {
                    ShadowVolumeExtrudeProgram.initialise();
                    
                    // Enable the (infinite) point light extruder for now, just to get some params
                    mShadowDebugPass.setVertexProgram(
                        ShadowVolumeExtrudeProgram.programNames[ShadowVolumeExtrudeProgram.Programs.POINT_LIGHT]);
                    mShadowDebugPass.setFragmentProgram(ShadowVolumeExtrudeProgram.frgProgramName);               
                    mInfiniteExtrusionParams = 
                        mShadowDebugPass.getVertexProgramParameters();
                    mInfiniteExtrusionParams.get().setAutoConstant(0, 
                                                                   GpuProgramParameters.AutoConstantType.ACT_WORLDVIEWPROJ_MATRIX);
                    mInfiniteExtrusionParams.get().setAutoConstant(4, 
                                                                   GpuProgramParameters.AutoConstantType.ACT_LIGHT_POSITION_OBJECT_SPACE);
                    // Note ignored extra parameter - for compatibility with finite extrusion vertex program
                    mInfiniteExtrusionParams.get().setAutoConstant(5, 
                                                                   GpuProgramParameters.AutoConstantType.ACT_SHADOW_EXTRUSION_DISTANCE);
                }   
                matDebug.getAs().compile();
                
            }
            else
            {
                mShadowDebugPass = matDebug.getAs().getTechnique(0).getPass(0);
                
                if (mDestRenderSystem.getCapabilities().hasCapability(Capabilities.RSC_VERTEX_PROGRAM))
                {
                    mInfiniteExtrusionParams = mShadowDebugPass.getVertexProgramParameters();
                }
            }
        }
        
        if (!mShadowStencilPass)
        {
            
            SharedPtr!Material matStencil = MaterialManager.getSingleton().getByName(
                "Ogre/StencilShadowVolumes");
            if (matStencil.isNull())
            {
                // Init
                matStencil = MaterialManager.getSingleton().create(
                    "Ogre/StencilShadowVolumes",
                    ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME);
                mShadowStencilPass = matStencil.getAs().getTechnique(0).getPass(0);
                
                if (mDestRenderSystem.getCapabilities().hasCapability(
                    Capabilities.RSC_VERTEX_PROGRAM))
                {
                    
                    // Enable the finite point light extruder for now, just to get some params
                    mShadowStencilPass.setVertexProgram(
                        ShadowVolumeExtrudeProgram.programNames[ShadowVolumeExtrudeProgram.Programs.POINT_LIGHT_FINITE]);
                    mShadowStencilPass.setFragmentProgram(ShadowVolumeExtrudeProgram.frgProgramName);             
                    mFiniteExtrusionParams = 
                        mShadowStencilPass.getVertexProgramParameters();
                    mFiniteExtrusionParams.get().setAutoConstant(0, 
                                                                 GpuProgramParameters.AutoConstantType.ACT_WORLDVIEWPROJ_MATRIX);
                    mFiniteExtrusionParams.get().setAutoConstant(4, 
                                                                 GpuProgramParameters.AutoConstantType.ACT_LIGHT_POSITION_OBJECT_SPACE);
                    // Note extra parameter
                    mFiniteExtrusionParams.get().setAutoConstant(5, 
                                                                 GpuProgramParameters.AutoConstantType.ACT_SHADOW_EXTRUSION_DISTANCE);
                }
                matStencil.getAs().compile();
                // Nothing else, we don't use this like a 'real' pass anyway,
                // it's more of a placeholder
            }
            else
            {
                mShadowStencilPass = matStencil.getAs().getTechnique(0).getPass(0);
                
                if (mDestRenderSystem.getCapabilities().hasCapability(Capabilities.RSC_VERTEX_PROGRAM))
                {
                    mFiniteExtrusionParams = mShadowStencilPass.getVertexProgramParameters();
                }
            }
        }
        
        
        
        
        if (!mShadowModulativePass)
        {
            
            SharedPtr!Material matModStencil = MaterialManager.getSingleton().getByName(
                "Ogre/StencilShadowModulationPass");
            if (matModStencil.isNull())
            {
                // Init
                matModStencil = MaterialManager.getSingleton().create(
                    "Ogre/StencilShadowModulationPass",
                    ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME);
                mShadowModulativePass = matModStencil.getAs().getTechnique(0).getPass(0);
                mShadowModulativePass.setSceneBlending(SceneBlendFactor.SBF_DEST_COLOUR, SceneBlendFactor.SBF_ZERO); 
                mShadowModulativePass.setLightingEnabled(false);
                mShadowModulativePass.setDepthWriteEnabled(false);
                mShadowModulativePass.setDepthCheckEnabled(false);
                TextureUnitState t = mShadowModulativePass.createTextureUnitState();
                t.setColourOperationEx(LayerBlendOperationEx.LBX_MODULATE, LayerBlendSource.LBS_MANUAL, 
                                       LayerBlendSource.LBS_CURRENT, 
                                       mShadowColour);
                mShadowModulativePass.setCullingMode(CullingMode.CULL_NONE);
            }
            else
            {
                mShadowModulativePass = matModStencil.getAs().getTechnique(0).getPass(0);
            }
        }
        
        // Also init full screen quad while we're at it
        if (!mFullScreenQuad)
        {
            mFullScreenQuad = new Rectangle2D();
            mFullScreenQuad.setCorners(-1,1,1,-1);
        }
        
        // Also init shadow caster material for texture shadows
        if (!mShadowCasterPlainBlackPass)
        {
            SharedPtr!Material matPlainBlack = MaterialManager.getSingleton().getByName(
                "Ogre/TextureShadowCaster");
            if (matPlainBlack.isNull())
            {
                matPlainBlack = MaterialManager.getSingleton().create(
                    "Ogre/TextureShadowCaster",
                    ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME);
                mShadowCasterPlainBlackPass = matPlainBlack.getAs().getTechnique(0).getPass(0);
                // Lighting has to be on, because we need shadow coloured objects
                // Note that because we can't predict vertex programs, we'll have to
                // bind light values to those, and so we bind White to ambient
                // reflectance, and we'll set the ambient colour to the shadow colour
                mShadowCasterPlainBlackPass.setAmbient(ColourValue.White);
                mShadowCasterPlainBlackPass.setDiffuse(ColourValue.Black);
                mShadowCasterPlainBlackPass.setSelfIllumination(ColourValue.Black);
                mShadowCasterPlainBlackPass.setSpecular(ColourValue.Black);
                // Override fog
                mShadowCasterPlainBlackPass.setFog(true, FogMode.FOG_NONE);
                // no textures or anything else, we will bind vertex programs
                // every so often though
            }
            else
            {
                mShadowCasterPlainBlackPass = matPlainBlack.getAs().getTechnique(0).getPass(0);
            }
        }
        
        if (!mShadowReceiverPass)
        {
            SharedPtr!Material matShadRec = MaterialManager.getSingleton().getByName(
                "Ogre/TextureShadowReceiver");
            if (matShadRec.isNull())            
            {
                matShadRec = MaterialManager.getSingleton().create(
                    "Ogre/TextureShadowReceiver",
                    ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME);
                mShadowReceiverPass = matShadRec.getAs().getTechnique(0).getPass(0);
                // Don't set lighting and blending modes here, depends on additive / modulative
                TextureUnitState t = mShadowReceiverPass.createTextureUnitState();
                t.setTextureAddressingMode(TextureUnitState.TAM_CLAMP);
            }
            else
            {
                mShadowReceiverPass = matShadRec.getAs().getTechnique(0).getPass(0);
            }
        }
        
        // Set up spot shadow fade texture (loaded from code data block)
        SharedPtr!Texture spotShadowFadeTex = 
            cast(SharedPtr!Texture)TextureManager.getSingleton().getByName("spot_shadow_fade.png");
        if (spotShadowFadeTex.isNull())
        {
            // Load the manual buffer into an image (don't destroy memory!
            //TODO immutable SPOT_SHADOW_FADE_PNG to mutable
            auto stream = new MemoryDataStream(cast(ubyte[])SPOT_SHADOW_FADE_PNG, /*SPOT_SHADOW_FADE_PNG_SIZE,*/ false);
            auto img = new Image;
            img.load(stream, "png");
            spotShadowFadeTex = 
                TextureManager.getSingleton().loadImage(
                    "spot_shadow_fade.png", ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME, 
                    img, TextureType.TEX_TYPE_2D);
        }
        
        mShadowMaterialInitDone = true;
    }
    
    /// Internal method for creating shadow textures (texture-based shadows)
    void ensureShadowTexturesCreated()
    {
        if (mShadowTextureConfigDirty)
        {
            destroyShadowTextures();
            ShadowTextureManager.getSingleton().getShadowTextures(
                mShadowTextureConfigList, mShadowTextures);
            
            // clear shadow cam - light mapping
            mShadowCamLightMapping.clear();
            
            //Used to get the depth buffer ID setting for each RTT
            size_t __i = 0;
            
            // Recreate shadow textures
            foreach (shadowTex; mShadowTextures) 
            {
                
                // Camera names are local to SM 
                string camName = shadowTex.get().getName() ~ "Cam";
                // Material names are global to SM, make specific
                string matName = shadowTex.get().getName() ~ "Mat" ~ getName();
                
                RenderTexture shadowRTT = shadowTex.getAs().getBuffer().get().getRenderTarget();
                
                //Set appropriate depth buffer
                shadowRTT.setDepthBufferPool( mShadowTextureConfigList[__i].depthBufferPoolId );
                
                // Create camera for this texture, but note that we have to rebind
                // in prepareShadowTextures to coexist with multiple SMs
                Camera cam = createCamera(camName);
                cam.setAspectRatio(cast(Real)shadowTex.getAs().getWidth() / cast(Real)shadowTex.getAs().getHeight());
                mShadowTextureCameras.insert(cam);
                
                // Create a viewport, if not there already
                if (shadowRTT.getNumViewports() == 0)
                {
                    // Note camera assignment is transient when multiple SMs
                    Viewport v = shadowRTT.addViewport(cam);
                    v.setClearEveryFrame(true);
                    // remove overlays
                    v.setOverlaysEnabled(false);
                }
                
                // Don't update automatically - we'll do it when required
                shadowRTT.setAutoUpdated(false);
                
                // Also create corresponding Material used for rendering this shadow
                SharedPtr!Material mat = MaterialManager.getSingleton().getByName(matName);
                if (mat.isNull())
                {
                    mat = MaterialManager.getSingleton().create(
                        matName, ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME);
                }
                Pass p = mat.getAs().getTechnique(0).getPass(0);
                if (p.getNumTextureUnitStates() != 1 ||
                    p.getTextureUnitState(0)._getTexturePtr(0) != shadowTex)
                {
                    mat.getAs().getTechnique(0).getPass(0).removeAllTextureUnitStates();
                    // create texture unit referring to render target texture
                    TextureUnitState texUnit = 
                        p.createTextureUnitState(shadowTex.get().getName());
                    // set projective based on camera
                    texUnit.setProjectiveTexturing(!p.hasVertexProgram(), cam);
                    // clamp to border colour
                    texUnit.setTextureAddressingMode(TextureUnitState.TAM_BORDER);
                    texUnit.setTextureBorderColour(ColourValue.White);
                    mat.getAs().touch();
                    
                }
                
                // insert dummy camera-light combination
                mShadowCamLightMapping[cam] = null;
                
                // Get null shadow texture
                if (mShadowTextureConfigList.empty())
                {
                    mNullShadowTexture.setNull();
                }
                else
                {
                    mNullShadowTexture = 
                        ShadowTextureManager.getSingleton().getNullShadowTexture(
                            mShadowTextureConfigList[0].format);
                }
                
                ++__i;
            }
            mShadowTextureConfigDirty = false;
        }
        
    }
    
    /// Internal method for destroying shadow textures (texture-based shadows)
    void destroyShadowTextures()
    {
        foreach (shadowTex; mShadowTextures)
        {
            // Cleanup material that references this texture
            string matName = shadowTex.get().getName() ~ "Mat" ~ getName();
            SharedPtr!Material mat = MaterialManager.getSingleton().getByName(matName);
            if (!mat.isNull())
            {
                // manually clear TUS to ensure texture ref released
                mat.getAs().getTechnique(0).getPass(0).removeAllTextureUnitStates();
                MaterialManager.getSingleton().remove(mat.get().getHandle());
            }
            
        }
        
        foreach (c; mShadowTextureCameras)
        {
            // Always destroy camera since they are local to this SM
            destroyCamera(c);
        }
        mShadowTextures.clear();
        mShadowTextureCameras.clear();
        
        // Will destroy if no other scene managers referencing
        ShadowTextureManager.getSingleton().clearUnused();
        
        mShadowTextureConfigDirty = true;
        
    }
    
    //typedef vector<InstanceManager*>::type      InstanceManagerVec;
    alias InstanceManager[]      InstanceManagerVec;
    InstanceManagerVec mDirtyInstanceManagers;
    InstanceManagerVec mDirtyInstanceMgrsTmp;
    
    /** Updates all instance managaers with dirty instance batches. @see _addDirtyInstanceManager */
    void updateDirtyInstanceManagers()
    {
        //Copy all dirty mgrs to a temporary buffer to iterate through them. We need this because
        //if two InstancedEntities from different managers belong to the same SceneNode, one of the
        //managers may have been tagged as dirty while the other wasn't, and _addDirtyInstanceManager
        //will get called while iterating through them. The "while" loop will update all mgrs until
        //no one is dirty anymore (i.e. A makes B aware it's dirty, B makes C aware it's dirty)
        //mDirtyInstanceMgrsTmp isn't a local variable to prevent allocs & deallocs every frame.
        //mDirtyInstanceMgrsTmp.insert( mDirtyInstanceMgrsTmp.end(), mDirtyInstanceManagers.begin(),
        //                             mDirtyInstanceManagers.end() );
        //mDirtyInstanceManagers.clear();
        
        mDirtyInstanceMgrsTmp.insert(mDirtyInstanceManagers);
        mDirtyInstanceManagers.clear();
        
        while( !mDirtyInstanceMgrsTmp.empty() )
        {
            foreach(i; mDirtyInstanceMgrsTmp)
            {
                i._updateDirtyBatches();
            }
            
            //Clear temp buffer
            mDirtyInstanceMgrsTmp.clear();
            
            //Do it again?
            mDirtyInstanceMgrsTmp.insert(mDirtyInstanceManagers);
            mDirtyInstanceManagers.clear();
        }
    }
    
public:
    /// Method for preparing shadow textures ready for use in a regular render
    /// Do not call manually unless before frame start or rendering is paused
    /// If lightList is not supplied, will render all lights in frustum
    void prepareShadowTextures(Camera cam, Viewport vp, LightList lightList = LightList.init)
    {
        // create shadow textures if needed
        ensureShadowTexturesCreated();
        
        // Set the illumination stage, prevents recursive calls
        IlluminationRenderStage savedStage = mIlluminationStage;
        mIlluminationStage = IlluminationRenderStage.IRS_RENDER_TO_TEXTURE;
        
        if (!lightList.length)
            lightList = mLightsAffectingFrustum;
        
        try
        {
            
            // Determine far shadow distance
            Real shadowDist = mDefaultShadowFarDist;
            if (!shadowDist)
            {
                // need a shadow distance, make one up
                shadowDist = cam.getNearClipDistance() * 300;
            }
            Real shadowOffset = shadowDist * mShadowTextureOffset;
            // Precalculate fading info
            Real shadowEnd = shadowDist + shadowOffset;
            Real fadeStart = shadowEnd * mShadowTextureFadeStart;
            Real fadeEnd = shadowEnd * mShadowTextureFadeEnd;
            // Additive lighting should not use fogging, since it will overbrighten; use border clamp
            if (!isShadowTechniqueAdditive())
            {
                // set fogging to hide the shadow edge 
                mShadowReceiverPass.setFog(true, FogMode.FOG_LINEAR, ColourValue.White, 
                                           0, fadeStart, fadeEnd);
            }
            else
            {
                // disable fogging explicitly
                mShadowReceiverPass.setFog(true, FogMode.FOG_NONE);
            }
            
            // Iterate over the lights we've found, max out at the limit of light textures
            // Note that the light sorting must now place shadow casting lights at the
            // start of the light list, therefore we do not need to deal with potential
            // mismatches in the light<.shadow texture list any more
            
            //ci = mShadowTextureCameras.begin();
            size_t ci = 0, si = 0;
            mShadowTextureIndexLightList.clear();
            size_t shadowTextureIndex = 0;
            //for (i = lightList.begin(), si = mShadowTextures.begin();
            //     i != iend && si != siend; ++i)
            foreach(light; lightList)
            {
                if(si >= mShadowTextures.length) break;
                
                // skip light if shadows are disabled
                if (!light.getCastShadows())
                    continue;
                
                if (mShadowTextureCurrentCasterLightList.empty())
                    mShadowTextureCurrentCasterLightList.insert(light);
                else
                    mShadowTextureCurrentCasterLightList[0] = light;
                
                
                // texture iteration per light.
                size_t textureCountPerLight = mShadowTextureCountPerType[light.getType()];
                for (size_t j = 0; j < textureCountPerLight && si < mShadowTextures.length; ++j)
                {
                    SharedPtr!Texture shadowTex = mShadowTextures[si];
                    RenderTarget shadowRTT = shadowTex.getAs().getBuffer().get().getRenderTarget();
                    Viewport shadowView = shadowRTT.getViewport(0);
                    Camera texCam = mShadowTextureCameras[ci];
                    // rebind camera, incase another SM in use which has switched to its cam
                    shadowView.setCamera(texCam);
                    
                    // Associate main view camera as LOD camera
                    texCam.setLodCamera(cam);
                    // set base
                    if (light.getType() != Light.LightTypes.LT_POINT)
                        texCam.setDirection(light.getDerivedDirection());
                    if (light.getType() != Light.LightTypes.LT_DIRECTIONAL)
                        texCam.setPosition(light.getDerivedPosition());
                    
                    // Use the material scheme of the main viewport 
                    // This is required to pick up the correct shadow_caster_material and similar properties.
                    shadowView.setMaterialScheme(vp.getMaterialScheme());
                    
                    // update shadow cam - light mapping
                    auto camLightIt = texCam in mShadowCamLightMapping;
                    assert(camLightIt !is null);
                    *camLightIt = light; //mShadowCamLightMapping[texCam] = light; //either way
                    
                    if (light.getCustomShadowCameraSetup() is null)//.isNull())
                        mDefaultShadowCameraSetup.getShadowCamera(this, cam, vp, light, texCam, j);
                    else
                        light.getCustomShadowCameraSetup().getShadowCamera(this, cam, vp, light, texCam, j);
                    
                    // Setup background colour
                    shadowView.setBackgroundColour(ColourValue.White);
                    
                    // Fire shadow caster update, callee can alter camera settings
                    fireShadowTexturesPreCaster(light, texCam, j);
                    
                    // Update target
                    shadowRTT.update();
                    
                    ++si; // next shadow texture
                    ++ci; // next camera
                }
                
                // set the first shadow texture index for this light.
                mShadowTextureIndexLightList.insert(shadowTextureIndex);
                shadowTextureIndex += textureCountPerLight;
            }
        }
        //TODO do in finally{} because it is not C++ Standard specifiedruct but is in D
        /*catch (Exception e)
         {
         // we must reset the illumination stage if an exception occurs
         mIlluminationStage = savedStage;
         throw e;
         }*/
        finally
        {
            // Set the illumination stage, prevents recursive calls
            mIlluminationStage = savedStage;
        }
        
        fireShadowTexturesUpdated(
            std.algorithm.min(lightList.length, mShadowTextures.length));
        
        ShadowTextureManager.getSingleton().clearUnused();
        
    }
    
    //A render context, used to store internal data for pausing/resuming rendering
    struct RenderContext
    {
        RenderQueue renderQueue;
        Viewport    viewport;
        Camera      camera;
        CompositorChain activeChain;
        RenderSystem.RenderSystemContext rsContext;
    }
    
    /** Pause rendering of the frame. This has to be called when inside a renderScene call
     (Usually using a listener of some sort)
     */
    RenderContext _pauseRendering()
    {
        RenderContext context;// = new RenderContext;
        context.renderQueue = mRenderQueue;
        context.viewport    = mCurrentViewport;
        context.camera      = mCameraInProgress;
        context.activeChain = _getActiveCompositorChain();
        
        context.rsContext = mDestRenderSystem._pauseFrame();
        mRenderQueue = null;
        return context;
    }
    /** Resume rendering of the frame. This has to be called after a _pauseRendering call
     @param context The rendring context, as returned by the _pauseRendering call
     */
    void _resumeRendering(RenderContext context)
    {
        if (mRenderQueue !is null) 
        {
            destroy(mRenderQueue);
        }
        mRenderQueue = context.renderQueue;
        _setActiveCompositorChain(context.activeChain);
        Viewport vp   = context.viewport;
        Camera camera = context.camera;
        
        // Tell params about viewport
        mAutoParamDataSource.setCurrentViewport(vp);
        // Set the viewport - this is deliberately after the shadow texture update
        setViewport(vp);
        
        // Tell params about camera
        mAutoParamDataSource.setCurrentCamera(camera, mCameraRelativeRendering);
        // Set autoparams for finite dir light extrusion
        mAutoParamDataSource.setShadowDirLightExtrusionDistance(mShadowDirLightExtrudeDist);
        
        // Tell params about current ambient light
        mAutoParamDataSource.setAmbientLightColour(mAmbientLight);
        // Tell rendersystem
        mDestRenderSystem.setAmbientLight(mAmbientLight.r, mAmbientLight.g, mAmbientLight.b);
        
        // Tell params about render target
        mAutoParamDataSource.setCurrentRenderTarget(vp.getTarget());
        
        
        // Set camera window clipping planes (if any)
        if (mDestRenderSystem.getCapabilities().hasCapability(Capabilities.RSC_USER_CLIP_PLANES))
        {
            mDestRenderSystem.resetClipPlanes();
            if (camera.isWindowSet())  
            {
                mDestRenderSystem.setClipPlanes(camera.getWindowPlanes());
            }
        }
        mCameraInProgress = context.camera;
        mDestRenderSystem._resumeFrame(context.rsContext);
        
        // Set rasterisation mode
        mDestRenderSystem._setPolygonMode(mCameraInProgress.getPolygonMode());
        
        // Set initial camera state
        mDestRenderSystem._setProjectionMatrix(mCameraInProgress.getProjectionMatrixRS());
        
        mCachedViewMatrix = mCameraInProgress.getViewMatrix(true);
        
        if (mCameraRelativeRendering)
        {
            mCachedViewMatrix.setTrans(Vector3.ZERO);
            mCameraRelativePosition = mCameraInProgress.getDerivedPosition();
        }
        mDestRenderSystem._setTextureProjectionRelativeTo(mCameraRelativeRendering, mCameraInProgress.getDerivedPosition());
        
        
        setViewMatrix(mCachedViewMatrix);
        destroy(context);
    }
    
protected:
    /** Internal method for rendering all the objects for a given light into the 
     stencil buffer.
     @param light The light source
     @param cam The camera being viewed from
     @param calcScissor Whether the method should set up any scissor state, or
     false if that's already been done
     */
    void renderShadowVolumesToStencil(/*const*/ Light light, Camera camera, 
                                      bool calcScissor)
    {
        // Get the shadow caster list
        //
        ShadowCasterList casters = cast(ShadowCasterList)findShadowCastersForLight(light, camera);
        // Check there are some shadow casters to render
        if (casters.empty())
        {
            // No casters, just do nothing
            return;
        }
        
        // Add light to internal list for use in render call
        LightList lightList;
        //_cast is forgiveable here since we pass this
        lightList.insert(light);
        
        // Set up scissor test (point & spot lights only)
        ClipResult scissored = ClipResult.CLIPPED_NONE;
        if (calcScissor)
        {
            scissored = buildAndSetScissor(lightList, camera);
            if (scissored == ClipResult.CLIPPED_ALL)
                return; // nothing to do
        }
        
        mDestRenderSystem.unbindGpuProgram(GpuProgramType.GPT_FRAGMENT_PROGRAM);
        
        // Can we do a 2-sided stencil?
        bool stencil2sided = false;
        if (mDestRenderSystem.getCapabilities().hasCapability(Capabilities.RSC_TWO_SIDED_STENCIL) && 
            mDestRenderSystem.getCapabilities().hasCapability(Capabilities.RSC_STENCIL_WRAP))
        {
            // enable
            stencil2sided = true;
        }
        
        // Do we have access to vertex programs?
        bool extrudeInSoftware = true;
        bool finiteExtrude = !mShadowUseInfiniteFarPlane || 
            !mDestRenderSystem.getCapabilities().hasCapability(Capabilities.RSC_INFINITE_FAR_PLANE);
        if (mDestRenderSystem.getCapabilities().hasCapability(Capabilities.RSC_VERTEX_PROGRAM))
        {
            extrudeInSoftware = false;
            // attach the appropriate extrusion vertex program
            // Note we never unset it because support for vertex programs isant
            mShadowStencilPass.setVertexProgram(
                ShadowVolumeExtrudeProgram.getProgramName(light.getType(), finiteExtrude, false)
                , false);
            mShadowStencilPass.setFragmentProgram(ShadowVolumeExtrudeProgram.frgProgramName);
            // Set params
            if (finiteExtrude)
            {
                mShadowStencilPass.setVertexProgramParameters(mFiniteExtrusionParams);
            }
            else
            {
                mShadowStencilPass.setVertexProgramParameters(mInfiniteExtrusionParams);
            }
            if (mDebugShadows)
            {
                mShadowDebugPass.setVertexProgram(
                    ShadowVolumeExtrudeProgram.getProgramName(light.getType(), finiteExtrude, true)
                    , false);
                mShadowDebugPass.setFragmentProgram(ShadowVolumeExtrudeProgram.frgProgramName);
                
                
                // Set params
                if (finiteExtrude)
                {
                    mShadowDebugPass.setVertexProgramParameters(mFiniteExtrusionParams);
                }
                else
                {
                    mShadowDebugPass.setVertexProgramParameters(mInfiniteExtrusionParams);
                }
            }
            
            bindGpuProgram(mShadowStencilPass.getVertexProgram().getAs()._getBindingDelegate());
            if (ShadowVolumeExtrudeProgram.frgProgramName !is null) //TODO "" is not null, so probably use of .length is better?
            {
                bindGpuProgram(mShadowStencilPass.getFragmentProgram().getAs()._getBindingDelegate());
            }
            
        }
        else
        {
            mDestRenderSystem.unbindGpuProgram(GpuProgramType.GPT_VERTEX_PROGRAM);
        }
        
        // Turn off colour writing and depth writing
        mDestRenderSystem._setColourBufferWriteEnabled(false, false, false, false);
        mDestRenderSystem._disableTextureUnitsFrom(0);
        mDestRenderSystem._setDepthBufferParams(true, false, CompareFunction.CMPF_LESS);
        mDestRenderSystem.setStencilCheckEnabled(true);
        
        // Calculate extrusion distance
        // Use direction light extrusion distance now, just form optimize code
        // generate a little, point/spot light will up to date later
        Real extrudeDist = mShadowDirLightExtrudeDist;
        
        // Figure out the near clip volume
        //
        PlaneBoundedVolume nearClipVol = light._getNearClipVolume(camera);
        
        // Now iterate over the casters and render
        foreach (caster; casters)
        {
            bool zfailAlgo = camera.isCustomNearClipPlaneEnabled();
            ulong flags = 0;
            
            if (light.getType() != Light.LightTypes.LT_DIRECTIONAL)
            {
                extrudeDist = caster.getPointExtrusionDistance(light); 
            }
            
            Real darkCapExtrudeDist = extrudeDist;
            if (!extrudeInSoftware && !finiteExtrude)
            {
                // hardware extrusion, to infinity (and beyond!)
                flags |= ShadowRenderableFlags.SRF_EXTRUDE_TO_INFINITY;
                darkCapExtrudeDist = mShadowDirLightExtrudeDist;
            }
            
            // Determine whether zfail is required
            if (zfailAlgo || nearClipVol.intersects(caster.getWorldBoundingBox()))
            {
                // We use zfail for this object only because zfail
                // compatible with zpass algorithm
                zfailAlgo = true;
                // We need to include the light and / or dark cap
                // But only if they will be visible
                if(camera.isVisible(caster.getLightCapBounds(), null))
                {
                    flags |= ShadowRenderableFlags.SRF_INCLUDE_LIGHT_CAP;
                }
                // zfail needs dark cap 
                // UNLESS directional lights using hardware extrusion to infinity
                // since that extrudes to a single point
                if(!((flags & ShadowRenderableFlags.SRF_EXTRUDE_TO_INFINITY) && 
                     light.getType() == Light.LightTypes.LT_DIRECTIONAL) &&
                   camera.isVisible(caster.getDarkCapBounds(light, darkCapExtrudeDist), null))
                {
                    flags |= ShadowRenderableFlags.SRF_INCLUDE_DARK_CAP;
                }
            }
            else
            {
                // In zpass we need a dark cap if
                // 1: infinite extrusion on point/spotlight sources in modulative shadows
                //    mode, since otherwise in areas where there is no depth (skybox)
                //    the infinitely projected volume will leave a dark band
                // 2: finite extrusion on any light source since glancing angles
                //    can peek through the end and shadow objects behind incorrectly
                if ((flags & ShadowRenderableFlags.SRF_EXTRUDE_TO_INFINITY) && 
                    light.getType() != Light.LightTypes.LT_DIRECTIONAL && 
                    isShadowTechniqueModulative() && 
                    camera.isVisible(caster.getDarkCapBounds(light, darkCapExtrudeDist), null))
                {
                    flags |= ShadowRenderableFlags.SRF_INCLUDE_DARK_CAP;
                }
                else if (!(flags & ShadowRenderableFlags.SRF_EXTRUDE_TO_INFINITY) && 
                         camera.isVisible(caster.getDarkCapBounds(light, darkCapExtrudeDist), null))
                {
                    flags |= ShadowRenderableFlags.SRF_INCLUDE_DARK_CAP;
                }
                
            }
            
            // Get shadow renderables
            auto iShadowRenderables =
                caster.getShadowVolumeRenderables(mShadowTechnique,
                                                  light, &mShadowIndexBuffer, extrudeInSoftware, 
                                                  extrudeDist, flags);
            
            // Render a shadow volume here
            //  - if we have 2-sided stencil, one render with no culling
            //  - otherwise, 2 renders, one with each culling method and invert the ops
            setShadowVolumeStencilState(false, zfailAlgo, stencil2sided);
            renderShadowVolumeObjects(iShadowRenderables, mShadowStencilPass, lightList, flags,
                                      false, zfailAlgo, stencil2sided);
            if (!stencil2sided)
            {
                // Second pass
                setShadowVolumeStencilState(true, zfailAlgo, false);
                renderShadowVolumeObjects(iShadowRenderables, mShadowStencilPass, lightList, flags,
                                          true, zfailAlgo, false);
            }
            
            // Do we need to render a debug shadow marker?
            if (mDebugShadows)
            {
                // reset stencil & colour ops
                mDestRenderSystem.setStencilBufferParams();
                mShadowDebugPass.getTextureUnitState(0).
                    setColourOperationEx(LayerBlendOperationEx.LBX_MODULATE, LayerBlendSource.LBS_MANUAL, LayerBlendSource.LBS_CURRENT,
                                         zfailAlgo ? ColourValue(0.7, 0.0, 0.2) : ColourValue(0.0, 0.7, 0.2));
                _setPass(mShadowDebugPass);
                renderShadowVolumeObjects(iShadowRenderables, mShadowDebugPass, lightList, flags,
                                          true, false, false);
                mDestRenderSystem._setColourBufferWriteEnabled(false, false, false, false);
                mDestRenderSystem._setDepthBufferFunction(CompareFunction.CMPF_LESS);
            }
        }
        
        // revert colour write state
        mDestRenderSystem._setColourBufferWriteEnabled(true, true, true, true);
        // revert depth state
        mDestRenderSystem._setDepthBufferParams();
        
        mDestRenderSystem.setStencilCheckEnabled(false);
        
        mDestRenderSystem.unbindGpuProgram(GpuProgramType.GPT_VERTEX_PROGRAM);
        
        if (scissored == ClipResult.CLIPPED_SOME)
        {
            // disable scissor test
            resetScissor();
        }
        
    }
    /** Internal utility method for setting stencil state for rendering shadow volumes. 
     @param secondpass Is this the second pass?
     @param zfail Should we be using the zfail method?
     @param twosided Should we use a 2-sided stencil?
     */
    void setShadowVolumeStencilState(bool secondpass, bool zfail, bool twosided)
    {
        // Determinate the best stencil operation
        StencilOperation incrOp, decrOp;
        if (mDestRenderSystem.getCapabilities().hasCapability(Capabilities.RSC_STENCIL_WRAP))
        {
            incrOp = StencilOperation.SOP_INCREMENT_WRAP;
            decrOp = StencilOperation.SOP_DECREMENT_WRAP;
        }
        else
        {
            incrOp = StencilOperation.SOP_INCREMENT;
            decrOp = StencilOperation.SOP_DECREMENT;
        }
        
        // First pass, do front faces if zpass
        // Second pass, do back faces if zpass
        // Invert if zfail
        // this is to ensure we always increment before decrement
        // When two-sided stencil, always pass front face stencil
        // operation parameters and the inverse of them will happen
        // for back faces
        if ( !twosided && ((secondpass || zfail) && !(secondpass && zfail)) )
        {
            mPassCullingMode = twosided? CullingMode.CULL_NONE : CullingMode.CULL_ANTICLOCKWISE;
            mDestRenderSystem.setStencilBufferParams(
                CompareFunction.CMPF_ALWAYS_PASS, // always pass stencil check
                0, // no ref value (no compare)
                0xFFFFFFFF, // no compare mask
                0xFFFFFFFF, // no write mask
                StencilOperation.SOP_KEEP, // stencil test will never fail
                zfail ? incrOp : StencilOperation.SOP_KEEP, // back face depth fail
                zfail ? StencilOperation.SOP_KEEP : decrOp, // back face pass
                twosided
                );
        }
        else
        {
            mPassCullingMode = twosided? CullingMode.CULL_NONE : CullingMode.CULL_CLOCKWISE;
            mDestRenderSystem.setStencilBufferParams(
                CompareFunction.CMPF_ALWAYS_PASS, // always pass stencil check
                0, // no ref value (no compare)
                0xFFFFFFFF, // no compare mask
                0xFFFFFFFF, // no write mask
                StencilOperation.SOP_KEEP, // stencil test will never fail
                zfail ? decrOp : StencilOperation.SOP_KEEP, // front face depth fail
                zfail ? StencilOperation.SOP_KEEP : incrOp, // front face pass
                twosided
                );
        }
        mDestRenderSystem._setCullingMode(mPassCullingMode);
        
    }
    
    /** Render a set of shadow renderables. */
    void renderShadowVolumeObjects(ShadowCaster.ShadowRenderableList iShadowRenderables,
                                   Pass pass, LightList manualLightList, ulong flags,
                                   bool secondpass, bool zfail, bool twosided)
    {
        // ----- SHADOW VOLUME LOOP -----
        // Render all shadow renderables with same stencil operations
        foreach(sr; iShadowRenderables)
        {
            // omit hidden renderables
            if (sr.isVisible())
            {
                // render volume, including dark and (maybe) light caps
                renderSingleObject(sr, pass, false, false, manualLightList);
                
                // optionally render separate light cap
                if (sr.isLightCapSeparate() && (flags & ShadowRenderableFlags.SRF_INCLUDE_LIGHT_CAP))
                {
                    ShadowRenderable lightCap = sr.getLightCapRenderable();
                    assert(lightCap , "Shadow renderable is missing a separate light cap renderable!");
                    
                    // We must take care with light caps when we could 'see' the back facing
                    // triangles directly:
                    //   1. The front facing light caps must render as always fail depth
                    //      check to avoid 'depth fighting'.
                    //   2. The back facing light caps must use normal depth function to
                    //      avoid break the standard depth check
                    //
                    // TODO:
                    //   1. Separate light caps rendering doesn't need for the 'closed'
                    //      mesh that never touch the near plane, because in this instance,
                    //      we couldn't 'see' any back facing triangles directly. The
                    //      'closed' mesh must determinate by edge list builder.
                    //   2. There still exists 'depth fighting' bug with coplane triangles
                    //      that has opposite facing. This usually occur when use two side
                    //      material in the modeling tools and the model exporting tools
                    //      exporting double triangles to represent this model. This bug
                    //      can't fixed in GPU only, there must has extra work on edge list
                    //      builder and shadow volume generater to fix it.
                    //
                    if (twosided)
                    {
                        // select back facing light caps to render
                        mDestRenderSystem._setCullingMode(CullingMode.CULL_ANTICLOCKWISE);
                        mPassCullingMode = CullingMode.CULL_ANTICLOCKWISE;
                        // use normal depth function for back facing light caps
                        renderSingleObject(lightCap, pass, false, false, manualLightList);
                        
                        // select front facing light caps to render
                        mDestRenderSystem._setCullingMode(CullingMode.CULL_CLOCKWISE);
                        mPassCullingMode = CullingMode.CULL_CLOCKWISE;
                        // must always fail depth check for front facing light caps
                        mDestRenderSystem._setDepthBufferFunction(CompareFunction.CMPF_ALWAYS_FAIL);
                        renderSingleObject(lightCap, pass, false, false, manualLightList);
                        
                        // reset depth function
                        mDestRenderSystem._setDepthBufferFunction(CompareFunction.CMPF_LESS);
                        // reset culling mode
                        mDestRenderSystem._setCullingMode(CullingMode.CULL_NONE);
                        mPassCullingMode = CullingMode.CULL_NONE;
                    }
                    else if ((secondpass || zfail) && !(secondpass && zfail))
                    {
                        // use normal depth function for back facing light caps
                        renderSingleObject(lightCap, pass, false, false, manualLightList);
                    }
                    else
                    {
                        // must always fail depth check for front facing light caps
                        mDestRenderSystem._setDepthBufferFunction(CompareFunction.CMPF_ALWAYS_FAIL);
                        renderSingleObject(lightCap, pass, false, false, manualLightList);
                        
                        // reset depth function
                        mDestRenderSystem._setDepthBufferFunction(CompareFunction.CMPF_LESS);
                    }
                }
            }
        }
    }
    
    //typedef vector<ShadowCaster*>::type ShadowCasterList;
    alias ShadowCaster[] ShadowCasterList;
    ShadowCasterList mShadowCasterList;
    SphereSceneQuery mShadowCasterSphereQuery;
    AxisAlignedBoxSceneQuery mShadowCasterAABBQuery;
    Real mDefaultShadowFarDist;
    Real mDefaultShadowFarDistSquared;
    Real mShadowTextureOffset; // proportion of texture offset in view direction e.g. 0.4
    Real mShadowTextureFadeStart; // as a proportion e.g. 0.6
    Real mShadowTextureFadeEnd; // as a proportion e.g. 0.9
    bool mShadowTextureSelfShadow;
    Pass mShadowTextureCustomCasterPass;
    Pass mShadowTextureCustomReceiverPass;
    string mShadowTextureCustomCasterVertexProgram;
    string mShadowTextureCustomCasterFragmentProgram;
    string mShadowTextureCustomReceiverVertexProgram;
    string mShadowTextureCustomReceiverFragmentProgram;
    SharedPtr!GpuProgramParameters mShadowTextureCustomCasterVPParams;
    SharedPtr!GpuProgramParameters mShadowTextureCustomCasterFPParams;
    SharedPtr!GpuProgramParameters mShadowTextureCustomReceiverVPParams;
    SharedPtr!GpuProgramParameters mShadowTextureCustomReceiverFPParams;
    
    /// Visibility mask used to show / hide objects
    uint mVisibilityMask;
    bool mFindVisibleObjects;
    
    /// Suppress render state changes?
    bool mSuppressRenderStateChanges;
    /// Suppress shadows?
    bool mSuppressShadows;
    
    
    SharedPtr!GpuProgramParameters mInfiniteExtrusionParams;
    SharedPtr!GpuProgramParameters mFiniteExtrusionParams;
    
    /// Inner class to use as callback for shadow caster scene query
    class ShadowCasterSceneQueryListener : SceneQueryListener//, public SceneMgtAlloc
    {
    protected:
        SceneManager mSceneMgr;
        ShadowCasterList mCasterList;
        bool mIsLightInFrustum;
        PlaneBoundedVolumeList mLightClipVolumeList;
        Camera mCamera;
        Light mLight;
        Real mFarDistSquared;
    public:
        this(SceneManager sm)
        {
            mSceneMgr = sm;
            //mCasterList = 0;
            mIsLightInFrustum = false;
            //mLightClipVolumeList = 0;
            //mCamera = 0;
        }
        // Prepare the listener for use with a set of parameters  
        void prepare(bool lightInFrustum, 
                     PlaneBoundedVolumeList lightClipVolumes, 
                     Light light,Camera cam, ShadowCasterList casterList, 
                     Real farDistSquared) 
        {
            mCasterList = casterList;
            mIsLightInFrustum = lightInFrustum;
            mLightClipVolumeList = lightClipVolumes;
            mCamera = cast(Camera)cam;
            mLight = cast(Light)light;
            mFarDistSquared = farDistSquared;
        }
        
        bool queryResult(MovableObject object)
        {
            if (object.getCastShadows() && object.isVisible() && 
                mSceneMgr.isRenderQueueToBeProcessed(object.getRenderQueueGroup()) &&
                // objects need an edge list to cast shadows (shadow volumes only)
                ((mSceneMgr.getShadowTechnique() & ShadowTechnique.SHADOWDETAILTYPE_TEXTURE) ||
             ((mSceneMgr.getShadowTechnique() & ShadowTechnique.SHADOWDETAILTYPE_STENCIL) && object.hasEdgeList())
             )
                )
            {
                if (mFarDistSquared)
                {
                    // Check object is within the shadow far distance
                    Vector3 toObj = object.getParentNode()._getDerivedPosition() 
                        - mCamera.getDerivedPosition();
                    Real radius = object.getWorldBoundingSphere().getRadius();
                    Real dist =  toObj.squaredLength();
                    if (dist - (radius * radius) > mFarDistSquared)
                    {
                        // skip, beyond max range
                        return true;
                    }
                }
                
                // If the object is in the frustum, we can always see the shadow
                if (mCamera.isVisible(object.getWorldBoundingBox(), null))
                {
                    mCasterList.insert(object);
                    return true;
                }
                
                // Otherwise, object can only be casting a shadow into our view if
                // the light is outside the frustum (or it's a directional light, 
                // which are always outside), and the object is intersecting
                // on of the volumes formed between the edges of the frustum and the
                // light
                if (!mIsLightInFrustum || mLight.getType() == Light.LightTypes.LT_DIRECTIONAL)
                {
                    // Iterate over volumes
                    foreach (i; mLightClipVolumeList)
                    {
                        if (i.intersects(object.getWorldBoundingBox()))
                        {
                            mCasterList.insert(object);
                            return true;
                        }
                        
                    }
                    
                }
            }
            return true;
        }
        
        bool queryResult(SceneQuery.WorldFragment fragment)
        {
            // don't deal with world geometry
            return true;
        }
    }
    
    ShadowCasterSceneQueryListener mShadowCasterQueryListener;
    
    /** Internal method for locating a list of shadow casters which 
     could be affecting the frustum for a given light. 
     @remarks
     Custom scene managers are encouraged to override this method to add optimisations, 
     and to add their own custom shadow casters (perhaps for world geometry)
     */
    ShadowCasterList findShadowCastersForLight(Light light, 
                                                   Camera camera)
    {
        mShadowCasterList.clear();
        
        if (light.getType() == Light.LightTypes.LT_DIRECTIONAL)
        {
            // Basic AABB query encompassing the frustum and the extrusion of it
            AxisAlignedBox aabb;
            Vector3[] corners = camera.getWorldSpaceCorners();
            Vector3 min, max;
            Vector3 extrude = light.getDerivedDirection() * -mShadowDirLightExtrudeDist;
            // do first corner
            min = max = corners[0];
            min.makeFloor(corners[0] + extrude);
            max.makeCeil(corners[0] + extrude);
            for (size_t c = 1; c < 8; ++c)
            {
                min.makeFloor(corners[c]);
                max.makeCeil(corners[c]);
                min.makeFloor(corners[c] + extrude);
                max.makeCeil(corners[c] + extrude);
            }
            aabb.setExtents(min, max);
            
            if (!mShadowCasterAABBQuery)
                mShadowCasterAABBQuery = createAABBQuery(aabb);
            else
                mShadowCasterAABBQuery.setBox(aabb);
            // Execute, use callback
            mShadowCasterQueryListener.prepare(false, 
                                               light._getFrustumClipVolumes(camera), 
                                               light, 
                                               camera, mShadowCasterList, light.getShadowFarDistanceSquared());
            mShadowCasterAABBQuery.execute(mShadowCasterQueryListener);
            
            
        }
        else
        {
            auto s = Sphere(light.getDerivedPosition(), light.getAttenuationRange());
            // eliminate early if camera cannot see light sphere
            if (camera.isVisible(s, null))
            {
                if (!mShadowCasterSphereQuery)
                    mShadowCasterSphereQuery = createSphereQuery(s);
                else
                    mShadowCasterSphereQuery.setSphere(s);
                
                // Determine if light is inside or outside the frustum
                bool lightInFrustum = camera.isVisible(light.getDerivedPosition(), null);
                //
                PlaneBoundedVolumeList volList;
                if (!lightInFrustum)
                {
                    // Only worth building an external volume list if
                    // light is outside the frustum
                    volList = light._getFrustumClipVolumes(camera);
                }
                
                // Execute, use callback
                mShadowCasterQueryListener.prepare(lightInFrustum, 
                                                   volList, light, camera, mShadowCasterList, light.getShadowFarDistanceSquared());
                mShadowCasterSphereQuery.execute(mShadowCasterQueryListener);
                
            }
            
        }
        
        
        return mShadowCasterList;
    }
    /** Render a group in the ordinary way */
    void renderBasicQueueGroupObjects(RenderQueueGroup pGroup, 
                                      QueuedRenderableCollection.OrganisationMode om)
    {
        // Basic render loop
        // Iterate through priorities
        auto groupIt = pGroup.getPriorityMap();
        debug(STDERR) std.stdio.stderr.writeln("renderBasicQueueGroupObjects:", groupIt);
        foreach(k, pPriorityGrp; groupIt)
        {
            debug(STDERR) std.stdio.stderr.writeln("\t", k, "=", pPriorityGrp.getSolidsBasic().mGrouped);
            // Sort the queue first
            pPriorityGrp.sort(mCameraInProgress);
            
            // Do solids
            renderObjects(pPriorityGrp.getSolidsBasic(), om, true, true);
            // Do unsorted transparents
            renderObjects(pPriorityGrp.getTransparentsUnsorted(), om, true, true);
            // Do transparents (always descending)
            renderObjects(pPriorityGrp.getTransparents(), 
                          QueuedRenderableCollection.OrganisationMode.OM_SORT_DESCENDING, true, true);
            
            
        }// for each priority
    }
    /** Render a group with the added complexity of additive stencil shadows. */
    void renderAdditiveStencilShadowedQueueGroupObjects(RenderQueueGroup pGroup, 
                                                        QueuedRenderableCollection.OrganisationMode om)
    {
        auto groupIt = pGroup.getPriorityMap();
        LightList lightList;
        
        foreach(k, pPriorityGrp; groupIt)
        {
            // Sort the queue first
            pPriorityGrp.sort(mCameraInProgress);
            
            // Clear light list
            lightList.clear();
            
            // Render all the ambient passes first, no light iteration, no lights
            renderObjects(pPriorityGrp.getSolidsBasic(), om, false, false, lightList);
            // Also render any objects which have receive shadows disabled
            renderObjects(pPriorityGrp.getSolidsNoShadowReceive(), om, true, true);
            
            
            // Now iterate per light
            // Iterate over lights, render all volumes to stencil
            
            foreach (l; mLightsAffectingFrustum)
            {
                // Set light state
                if (lightList.empty())
                    lightList.insert(l);
                else
                    lightList[0] = l;
                
                // set up scissor, will cover shadow vol and regular light rendering
                ClipResult scissored = buildAndSetScissor(lightList, mCameraInProgress);
                ClipResult clipped = ClipResult.CLIPPED_NONE;
                if (mShadowAdditiveLightClip)
                    clipped = buildAndSetLightClip(lightList);
                
                // skip light if scissored / clipped entirely
                if (scissored == ClipResult.CLIPPED_ALL || clipped == ClipResult.CLIPPED_ALL)
                    continue;
                
                if (l.getCastShadows())
                {
                    // Clear stencil
                    mDestRenderSystem.clearFrameBuffer(FrameBufferType.FBT_STENCIL);
                    renderShadowVolumesToStencil(l, mCameraInProgress, false);
                    // turn stencil check on
                    mDestRenderSystem.setStencilCheckEnabled(true);
                    // NB we render where the stencil is equal to zero to render lit areas
                    mDestRenderSystem.setStencilBufferParams(CompareFunction.CMPF_EQUAL, 0);
                }
                
                // render lighting passes for this light
                renderObjects(pPriorityGrp.getSolidsDiffuseSpecular(), om, false, false, lightList);
                
                // Reset stencil params
                mDestRenderSystem.setStencilBufferParams();
                mDestRenderSystem.setStencilCheckEnabled(false);
                mDestRenderSystem._setDepthBufferParams();
                
                if (scissored == ClipResult.CLIPPED_SOME)
                    resetScissor();
                if (clipped == ClipResult.CLIPPED_SOME)
                    resetLightClip();
                
            }// for each light
            
            
            // Now render decal passes, no need to set lights as lighting will be disabled
            renderObjects(pPriorityGrp.getSolidsDecal(), om, false, false);
            
            
        }// for each priority
        
        // Iterate again - variable name changed to appease gcc.
        auto groupIt2 = pGroup.getPriorityMap();
        foreach(k, pPriorityGrp; groupIt2)
        {
            // Do unsorted transparents
            renderObjects(pPriorityGrp.getTransparentsUnsorted(), om, true, true);
            // Do transparents (always descending sort)
            renderObjects(pPriorityGrp.getTransparents(), 
                          QueuedRenderableCollection.OrganisationMode.OM_SORT_DESCENDING, true, true);
            
        }// for each priority
        
        
    }

    /** Render a group with the added complexity of modulative stencil shadows. */
    void renderModulativeStencilShadowedQueueGroupObjects(RenderQueueGroup pGroup, 
                                                          QueuedRenderableCollection.OrganisationMode om)
    {
        /* For each light, we need to render all the solids from each group, 
         then do the modulative shadows, then render the transparents from
         each group.
         Now, this means we are going to reorder things more, but that it required
         if the shadows are to look correct. The overall order is preserved anyway,
         it's just that all the transparents are at the end instead of them being
         interleaved as in the normal rendering loop. 
         */
        // Iterate through priorities
        auto groupIt = pGroup.getPriorityMap();
        
        foreach(k, pPriorityGrp; groupIt)
        {
            // Sort the queue first
            pPriorityGrp.sort(mCameraInProgress);
            
            // Do (shadowable) solids
            renderObjects(pPriorityGrp.getSolidsBasic(), om, true, true);
        }
        
        
        // Iterate over lights, render all volumes to stencil
        foreach (l; mLightsAffectingFrustum)
        {
            if (l.getCastShadows())
            {
                // Clear stencil
                mDestRenderSystem.clearFrameBuffer(FrameBufferType.FBT_STENCIL);
                renderShadowVolumesToStencil(l, mCameraInProgress, true);
                // render full-screen shadow modulator for all lights
                _setPass(mShadowModulativePass);
                // turn stencil check on
                mDestRenderSystem.setStencilCheckEnabled(true);
                // NB we render where the stencil is not equal to zero to render shadows, not lit areas
                mDestRenderSystem.setStencilBufferParams(CompareFunction.CMPF_NOT_EQUAL, 0);
                renderSingleObject(mFullScreenQuad, mShadowModulativePass, false, false);
                // Reset stencil params
                mDestRenderSystem.setStencilBufferParams();
                mDestRenderSystem.setStencilCheckEnabled(false);
                mDestRenderSystem._setDepthBufferParams();
            }
            
        }// for each light
        
        // Iterate again - variable name changed to appease gcc.
        auto groupIt2 = pGroup.getPriorityMap();
        foreach(k, pPriorityGrp; groupIt2)
        {
            // Do non-shadowable solids
            renderObjects(pPriorityGrp.getSolidsNoShadowReceive(), om, true, true);
            
        }// for each priority
        
        
        // Iterate again - variable name changed to appease gcc.
        auto groupIt3 = pGroup.getPriorityMap();
        foreach(k, pPriorityGrp; groupIt3)
        {
            // Do unsorted transparents
            renderObjects(pPriorityGrp.getTransparentsUnsorted(), om, true, true);
            // Do transparents (always descending sort)
            renderObjects(pPriorityGrp.getTransparents(), 
                          QueuedRenderableCollection.OrganisationMode.OM_SORT_DESCENDING, true, true);
            
        }// for each priority
        
    }
    
    /** Render a group rendering only shadow casters. */
    void renderTextureShadowCasterQueueGroupObjects(RenderQueueGroup pGroup, 
                                                    QueuedRenderableCollection.OrganisationMode om)
    {
        // This is like the basic group render, except we skip all transparents
        // and we also render any non-shadowed objects
        // Note that non-shadow casters will have already been eliminated during
        // _findVisibleObjects
        
        // Iterate through priorities
        auto groupIt = pGroup.getPriorityMap();
        
        // Override auto param ambient to force vertex programs and fixed function to 
        if (isShadowTechniqueAdditive())
        {
            // Use simple black / white mask if additive
            mAutoParamDataSource.setAmbientLightColour(ColourValue.Black);
            mDestRenderSystem.setAmbientLight(0, 0, 0);
        }
        else
        {
            // Use shadow colour as caster colour if modulative
            mAutoParamDataSource.setAmbientLightColour(mShadowColour);
            mDestRenderSystem.setAmbientLight(mShadowColour.r, mShadowColour.g, mShadowColour.b);
        }
        
        foreach (k, pPriorityGrp; groupIt)
        {
            // Sort the queue first
            pPriorityGrp.sort(mCameraInProgress);
            
            // Do solids, override light list incase any vertex programs use them
            renderObjects(pPriorityGrp.getSolidsBasic(), om, false, false, mShadowTextureCurrentCasterLightList);
            renderObjects(pPriorityGrp.getSolidsNoShadowReceive(), om, false, false, mShadowTextureCurrentCasterLightList);
            // Do unsorted transparents that cast shadows
            renderObjects(pPriorityGrp.getTransparentsUnsorted(), om, false, false, mShadowTextureCurrentCasterLightList);
            // Do transparents that cast shadows
            renderTransparentShadowCasterObjects(
                pPriorityGrp.getTransparents(), 
                QueuedRenderableCollection.OrganisationMode.OM_SORT_DESCENDING, 
                false, false, mShadowTextureCurrentCasterLightList);
            
            
        }// for each priority
        
        // reset ambient light
        mAutoParamDataSource.setAmbientLightColour(mAmbientLight);
        mDestRenderSystem.setAmbientLight(mAmbientLight.r, mAmbientLight.g, mAmbientLight.b);
    }
    
    /** Render a group rendering only shadow receivers. */
    void renderTextureShadowReceiverQueueGroupObjects(RenderQueueGroup pGroup, 
                                                      QueuedRenderableCollection.OrganisationMode om)
    {
        static LightList nullLightList;
        
        // Iterate through priorities
        auto groupIt = pGroup.getPriorityMap();
        
        // Override auto param ambient to force vertex programs to go full-bright
        mAutoParamDataSource.setAmbientLightColour(ColourValue.White);
        mDestRenderSystem.setAmbientLight(1, 1, 1);
        
        foreach (k, pPriorityGrp; groupIt)
        {
            // Do solids, override light list incase any vertex programs use them
            renderObjects(pPriorityGrp.getSolidsBasic(), om, false, false, nullLightList);
            
            // Don't render transparents or passes which have shadow receipt disabled
            
        }// for each priority
        
        // reset ambient
        mAutoParamDataSource.setAmbientLightColour(mAmbientLight);
        mDestRenderSystem.setAmbientLight(mAmbientLight.r, mAmbientLight.g, mAmbientLight.b);
        
    }
    
    /** Render a group with the added complexity of modulative texture shadows. */
    void renderModulativeTextureShadowedQueueGroupObjects(RenderQueueGroup pGroup, 
                                                          QueuedRenderableCollection.OrganisationMode om)
    {
        /* For each light, we need to render all the solids from each group, 
         then do the modulative shadows, then render the transparents from
         each group.
         Now, this means we are going to reorder things more, but that it required
         if the shadows are to look correct. The overall order is preserved anyway,
         it's just that all the transparents are at the end instead of them being
         interleaved as in the normal rendering loop. 
         */
        // Iterate through priorities
        auto groupIt = pGroup.getPriorityMap();
        
        foreach (k, pPriorityGrp; groupIt)
        {
            // Sort the queue first
            pPriorityGrp.sort(mCameraInProgress);
            
            // Do solids
            renderObjects(pPriorityGrp.getSolidsBasic(), om, true, true);
            renderObjects(pPriorityGrp.getSolidsNoShadowReceive(), om, true, true);
        }
        
        
        // Iterate over lights, render received shadows
        // only perform this if we're in the 'normal' render stage, to avoid
        // doing it during the render to texture
        if (mIlluminationStage == IlluminationRenderStage.IRS_NONE)
        {
            mIlluminationStage = IlluminationRenderStage.IRS_RENDER_RECEIVER_PASS;
            
            //LightList::iterator i, iend;
            //ShadowTextureList::iterator si, siend; //mShadowTextures
            size_t si = 0;
            
            foreach (l; mLightsAffectingFrustum)
                //foreach (l, si; zip(mLightsAffectingFrustum[], mShadowTextures) )
            {
                if(si>=mShadowTextures.length) break; //TODO
                if (!l.getCastShadows())
                    continue;
                
                // Store current shadow texture
                mCurrentShadowTexture = mShadowTextures[si];//.getPointer();
                // Get camera for current shadow texture
                Camera cam = mCurrentShadowTexture.getAs().getBuffer().get().getRenderTarget().getViewport(0).getCamera();
                // Hook up receiver texture
                Pass targetPass = mShadowTextureCustomReceiverPass ?
                    mShadowTextureCustomReceiverPass : mShadowReceiverPass;
                targetPass.getTextureUnitState(0).setTextureName(
                    mCurrentShadowTexture.get().getName());
                // Hook up projection frustum if fixed-function, but also need to
                // disable it explicitly for program pipeline.
                TextureUnitState texUnit = targetPass.getTextureUnitState(0);
                texUnit.setProjectiveTexturing(!targetPass.hasVertexProgram(), cam);
                // clamp to border colour in case this is a custom material
                texUnit.setTextureAddressingMode(TextureUnitState.TAM_BORDER);
                texUnit.setTextureBorderColour(ColourValue.White);
                
                mAutoParamDataSource.setTextureProjector(cam, 0);
                // if this light is a spotlight, we need to add the spot fader layer
                // BUT not if using a custom projection matrix, since then it will be
                // inappropriately shaped most likely
                if (l.getType() == Light.LightTypes.LT_SPOTLIGHT && !cam.isCustomProjectionMatrixEnabled())
                {
                    // remove all TUs except 0 & 1 
                    // (only an issue if additive shadows have been used)
                    while(targetPass.getNumTextureUnitStates() > 2)
                        targetPass.removeTextureUnitState(2);
                    
                    // Add spot fader if not present already
                    if (targetPass.getNumTextureUnitStates() == 2 && 
                        targetPass.getTextureUnitState(1).getTextureName() == 
                        "spot_shadow_fade.png")
                    {
                        // Just set 
                        TextureUnitState t = 
                            targetPass.getTextureUnitState(1);
                        t.setProjectiveTexturing(!targetPass.hasVertexProgram(), cam);
                    }
                    else
                    {
                        // Remove any non-conforming spot layers
                        while(targetPass.getNumTextureUnitStates() > 1)
                            targetPass.removeTextureUnitState(1);
                        
                        TextureUnitState t = 
                            targetPass.createTextureUnitState("spot_shadow_fade.png");
                        t.setProjectiveTexturing(!targetPass.hasVertexProgram(), cam);
                        t.setColourOperation(LayerBlendOperation.LBO_ADD);
                        t.setTextureAddressingMode(TextureUnitState.TAM_CLAMP);
                    }
                }
                else 
                {
                    // remove all TUs except 0 including spot
                    while(targetPass.getNumTextureUnitStates() > 1)
                        targetPass.removeTextureUnitState(1);
                    
                }
                // Set lighting / blending modes
                targetPass.setSceneBlending(SceneBlendFactor.SBF_DEST_COLOUR, SceneBlendFactor.SBF_ZERO);
                targetPass.setLightingEnabled(false);
                
                targetPass._load();
                
                // Fire pre-receiver event
                fireShadowTexturesPreReceiver(l, cam);
                
                renderTextureShadowReceiverQueueGroupObjects(pGroup, om);
                
                ++si;
                
            }// for each light
            
            mIlluminationStage = IlluminationRenderStage.IRS_NONE;
            
        }
        
        // Iterate again - variable name changed to appease gcc.
        auto groupIt3 = pGroup.getPriorityMap();
        foreach (k, pPriorityGrp; groupIt3)
        {
            // Do unsorted transparents
            renderObjects(pPriorityGrp.getTransparentsUnsorted(), om, true, true);
            // Do transparents (always descending)
            renderObjects(pPriorityGrp.getTransparents(), 
                          QueuedRenderableCollection.OrganisationMode.OM_SORT_DESCENDING, true, true);
            
        }// for each priority
        
    }
    
    /** Render a group with additive texture shadows. */
    void renderAdditiveTextureShadowedQueueGroupObjects(RenderQueueGroup pGroup, 
                                                        QueuedRenderableCollection.OrganisationMode om)
    {
        auto groupIt = pGroup.getPriorityMap();
        LightList lightList;
        
        foreach (k, pPriorityGrp; groupIt)
        {
            // Sort the queue first
            pPriorityGrp.sort(mCameraInProgress);
            
            // Clear light list
            lightList.clear();
            
            // Render all the ambient passes first, no light iteration, no lights
            renderObjects(pPriorityGrp.getSolidsBasic(), om, false, false, lightList);
            // Also render any objects which have receive shadows disabled
            renderObjects(pPriorityGrp.getSolidsNoShadowReceive(), om, true, true);
            
            
            // only perform this next part if we're in the 'normal' render stage, to avoid
            // doing it during the render to texture
            if (mIlluminationStage == IlluminationRenderStage.IRS_NONE)
            {
                // Iterate over lights, render masked
                //si = mShadowTextures.begin();
                size_t si = 0, siend = mShadowTextures.length;
                
                foreach (l; mLightsAffectingFrustum)
                {
                    if (l.getCastShadows() && si < siend)
                    {
                        // Store current shadow texture
                        mCurrentShadowTexture = mShadowTextures[si]; //.getPointer();
                        // Get camera for current shadow texture
                        Camera cam = mCurrentShadowTexture.getAs().getBuffer().get().getRenderTarget().getViewport(0).getCamera();
                        // Hook up receiver texture
                        Pass targetPass = mShadowTextureCustomReceiverPass ?
                            mShadowTextureCustomReceiverPass : mShadowReceiverPass;
                        targetPass.getTextureUnitState(0).setTextureName(
                            mCurrentShadowTexture.get().getName());
                        // Hook up projection frustum if fixed-function, but also need to
                        // disable it explicitly for program pipeline.
                        TextureUnitState texUnit = targetPass.getTextureUnitState(0);
                        texUnit.setProjectiveTexturing(!targetPass.hasVertexProgram(), cam);
                        // clamp to border colour in case this is a custom material
                        texUnit.setTextureAddressingMode(TextureUnitState.TAM_BORDER);
                        texUnit.setTextureBorderColour(ColourValue.White);
                        mAutoParamDataSource.setTextureProjector(cam, 0);
                        // Remove any spot fader layer
                        if (targetPass.getNumTextureUnitStates() > 1 && 
                            targetPass.getTextureUnitState(1).getTextureName() 
                            == "spot_shadow_fade.png")
                        {
                            // remove spot fader layer (should only be there if
                            // we previously used modulative shadows)
                            targetPass.removeTextureUnitState(1);
                        }
                        // Set lighting / blending modes
                        targetPass.setSceneBlending(SceneBlendFactor.SBF_ONE, SceneBlendFactor.SBF_ONE);
                        targetPass.setLightingEnabled(true);
                        targetPass._load();
                        
                        // increment shadow texture since used
                        ++si;
                        
                        mIlluminationStage = IlluminationRenderStage.IRS_RENDER_RECEIVER_PASS;
                        
                    }
                    else
                    {
                        mIlluminationStage = IlluminationRenderStage.IRS_NONE;
                        
                    }
                    
                    // render lighting passes for this light
                    if (lightList.empty())
                        lightList.insert(l);
                    else
                        lightList[0] = l;
                    
                    // set up light scissoring, always useful in additive modes
                    ClipResult scissored = buildAndSetScissor(lightList, mCameraInProgress);
                    ClipResult clipped = ClipResult.CLIPPED_NONE;
                    if(mShadowAdditiveLightClip)
                        clipped = buildAndSetLightClip(lightList);
                    // skip if entirely clipped
                    if(scissored == ClipResult.CLIPPED_ALL || clipped == ClipResult.CLIPPED_ALL)
                        continue;
                    
                    renderObjects(pPriorityGrp.getSolidsDiffuseSpecular(), om, false, false, lightList);
                    if (scissored == ClipResult.CLIPPED_SOME)
                        resetScissor();
                    if (clipped == ClipResult.CLIPPED_SOME)
                        resetLightClip();
                    
                }// for each light
                
                mIlluminationStage = IlluminationRenderStage.IRS_NONE;
                
                // Now render decal passes, no need to set lights as lighting will be disabled
                renderObjects(pPriorityGrp.getSolidsDecal(), om, false, false);
                
            }
            
            
        }// for each priority
        
        // Iterate again - variable name changed to appease gcc.
        auto groupIt2 = pGroup.getPriorityMap();
        foreach (k, pPriorityGrp; groupIt2)
        {
            // Do unsorted transparents
            renderObjects(pPriorityGrp.getTransparentsUnsorted(), om, true, true);
            // Do transparents (always descending sort)
            renderObjects(pPriorityGrp.getTransparents(), 
                          QueuedRenderableCollection.OrganisationMode.OM_SORT_DESCENDING, true, true);
            
        }// for each priority
        
    }
    
    /** Render a set of objects, see renderSingleObject for param definitions */
    void renderObjects(QueuedRenderableCollection objs, 
                       QueuedRenderableCollection.OrganisationMode om, bool lightScissoringClipping,
                       bool doLightIteration, LightList manualLightList = LightList.init)
    {
        debug(STDERR) std.stdio.stderr.writeln("ScMgr.renderObjects: ", om);
        mActiveQueuedRenderableVisitor.autoLights = doLightIteration;
        mActiveQueuedRenderableVisitor.manualLightList = manualLightList;
        mActiveQueuedRenderableVisitor.transparentShadowCastersMode = false;
        mActiveQueuedRenderableVisitor.scissoring = lightScissoringClipping;
        // Use visitor
        objs.acceptVisitor(mActiveQueuedRenderableVisitor, om);
    }
    
    /** Render those objects in the transparent pass list which have shadow casting forced on
     @remarks
     This function is intended to be used to render the shadows of transparent objects which have
     transparency_casts_shadows set to 'on' in their material
     */
    void renderTransparentShadowCasterObjects(QueuedRenderableCollection objs, 
                                              QueuedRenderableCollection.OrganisationMode om, bool lightScissoringClipping,
                                              bool doLightIteration, 
                                              LightList manualLightList = LightList.init)
    {
        mActiveQueuedRenderableVisitor.transparentShadowCastersMode = true;
        mActiveQueuedRenderableVisitor.autoLights = doLightIteration;
        mActiveQueuedRenderableVisitor.manualLightList = manualLightList;
        mActiveQueuedRenderableVisitor.scissoring = lightScissoringClipping;
        
        // Sort descending (transparency)
        objs.acceptVisitor(mActiveQueuedRenderableVisitor, 
                           QueuedRenderableCollection.OrganisationMode.OM_SORT_DESCENDING);
        
        mActiveQueuedRenderableVisitor.transparentShadowCastersMode = false;
    }
    
    /** Update the state of the global render queue splitting based on a shadow
     option change. */
    void updateRenderQueueSplitOptions()
    {
        if (isShadowTechniqueStencilBased())
        {
            // Casters can always be receivers
            getRenderQueue().setShadowCastersCannotBeReceivers(false);
        }
        else // texture based
        {
            getRenderQueue().setShadowCastersCannotBeReceivers(!mShadowTextureSelfShadow);
        }
        
        if (isShadowTechniqueAdditive() && !isShadowTechniqueIntegrated()
            && mCurrentViewport.getShadowsEnabled())
        {
            // Additive lighting, we need to split everything by illumination stage
            getRenderQueue().setSplitPassesByLightingType(true);
        }
        else
        {
            getRenderQueue().setSplitPassesByLightingType(false);
        }
        
        if (isShadowTechniqueInUse() && mCurrentViewport.getShadowsEnabled()
            && !isShadowTechniqueIntegrated())
        {
            // Tell render queue to split off non-shadowable materials
            getRenderQueue().setSplitNoShadowPasses(true);
        }
        else
        {
            getRenderQueue().setSplitNoShadowPasses(false);
        }
        
        
    }
    
    /** Update the state of the render queue group splitting based on a shadow
     option change. */
    void updateRenderQueueGroupSplitOptions(RenderQueueGroup group, 
                                            bool suppressShadows, bool suppressRenderState)
    {
        if (isShadowTechniqueStencilBased())
        {
            // Casters can always be receivers
            group.setShadowCastersCannotBeReceivers(false);
        }
        else if (isShadowTechniqueTextureBased()) 
        {
            group.setShadowCastersCannotBeReceivers(!mShadowTextureSelfShadow);
        }
        
        if (!suppressShadows && mCurrentViewport.getShadowsEnabled() &&
            isShadowTechniqueAdditive() && !isShadowTechniqueIntegrated())
        {
            // Additive lighting, we need to split everything by illumination stage
            group.setSplitPassesByLightingType(true);
        }
        else
        {
            group.setSplitPassesByLightingType(false);
        }
        
        if (!suppressShadows && mCurrentViewport.getShadowsEnabled() 
            && isShadowTechniqueInUse())
        {
            // Tell render queue to split off non-shadowable materials
            group.setSplitNoShadowPasses(true);
        }
        else
        {
            group.setSplitNoShadowPasses(false);
        }
        
        
    }
    
    /// Set up a scissor rectangle from a group of lights
    ClipResult buildAndSetScissor(LightList ll, Camera cam)
    {
        if (!mDestRenderSystem.getCapabilities().hasCapability(Capabilities.RSC_SCISSOR_TEST))
            return ClipResult.CLIPPED_NONE;
        
        RealRect finalRect;
        // init (inverted since we want to grow from nothing)
        finalRect.left = finalRect.bottom = 1.0f;
        finalRect.right = finalRect.top = -1.0f;
        
        foreach (l; ll)
        {
            // a directional light is being used, no scissoring can be done, period.
            if (l.getType() == Light.LightTypes.LT_DIRECTIONAL)
                return ClipResult.CLIPPED_NONE;
            
            RealRect scissorRect = getLightScissorRect(l, cam);
            
            // merge with final
            finalRect.left = std.algorithm.min(finalRect.left, scissorRect.left);
            finalRect.bottom = std.algorithm.min(finalRect.bottom, scissorRect.bottom);
            finalRect.right= std.algorithm.max(finalRect.right, scissorRect.right);
            finalRect.top = std.algorithm.max(finalRect.top, scissorRect.top);
            
            
        }
        
        if (finalRect.left >= 1.0f || finalRect.right <= -1.0f ||
            finalRect.top <= -1.0f || finalRect.bottom >= 1.0f)
        {
            // rect was offscreen
            return ClipResult.CLIPPED_ALL;
        }
        
        // Some scissoring?
        if (finalRect.left > -1.0f || finalRect.right < 1.0f || 
            finalRect.bottom > -1.0f || finalRect.top < 1.0f)
        {
            // Turn normalised device coordinates into pixels
            int iLeft, iTop, iWidth, iHeight;
            mCurrentViewport.getActualDimensions(iLeft, iTop, iWidth, iHeight);
            size_t szLeft, szRight, szTop, szBottom;
            
            szLeft  = cast(size_t)(iLeft + ((finalRect.left + 1) * 0.5 * iWidth));
            szRight = cast(size_t)(iLeft + ((finalRect.right + 1) * 0.5 * iWidth));
            szTop   = cast(size_t)(iTop  + ((-finalRect.top + 1) * 0.5 * iHeight));
            szBottom = cast(size_t)(iTop + ((-finalRect.bottom + 1) * 0.5 * iHeight));
            
            mDestRenderSystem.setScissorTest(true, szLeft, szTop, szRight, szBottom);
            
            return ClipResult.CLIPPED_SOME;
        }
        else
            return ClipResult.CLIPPED_NONE;
        
    }
    
    /// Update a scissor rectangle from a single light
    void buildScissor(Light light, Camera cam, ref RealRect rect)
    {
        // Project the sphere onto the camera
        auto sphere = Sphere(light.getDerivedPosition(), light.getAttenuationRange());
        cam.projectSphere(sphere, rect.left, rect.top, rect.right, rect.bottom);
    }
    
    void resetScissor()
    {
        if (!mDestRenderSystem.getCapabilities().hasCapability(Capabilities.RSC_SCISSOR_TEST))
            return;
        
        mDestRenderSystem.setScissorTest(false);
    }
    
    /// Build a set of user clip planes from a single non-directional light
    /// Build a set of user clip planes from a single non-directional light
    ClipResult buildAndSetLightClip(LightList ll)
    {
        if (!mDestRenderSystem.getCapabilities().hasCapability(Capabilities.RSC_USER_CLIP_PLANES))
            return ClipResult.CLIPPED_NONE;
        
        Light clipBase;
        foreach (i; ll)
        {
            // a directional light is being used, no clipping can be done, period.
            if (i.getType() == Light.LightTypes.LT_DIRECTIONAL)
                return ClipResult.CLIPPED_NONE;
            
            if (clipBase)
            {
                // we already have a clip base, so we had more than one light
                // in this list we could clip by, so clip none
                return ClipResult.CLIPPED_NONE;
            }
            clipBase = i;
        }
        
        if (clipBase)
        {
            PlaneList clipPlanes = getLightClippingPlanes(clipBase);
            
            mDestRenderSystem.setClipPlanes(clipPlanes);
            return ClipResult.CLIPPED_SOME;
        }
        else
        {
            // Can only get here if no non-directional lights from which to clip from
            // ie list must be empty
            return ClipResult.CLIPPED_ALL;
        }
        
        
    }
    
    void buildLightClip(Light l, ref PlaneList planes)
    {
        if (!mDestRenderSystem.getCapabilities().hasCapability(Capabilities.RSC_USER_CLIP_PLANES))
            return;
        
        planes.clear();
        
        Vector3 pos = l.getDerivedPosition();
        Real r = l.getAttenuationRange();
        switch(l.getType())
        {
            case Light.LightTypes.LT_POINT:
            {
                planes.insert(new Plane(Vector3.UNIT_X, pos + Vector3(-r, 0, 0)));
                planes.insert(new Plane(Vector3.NEGATIVE_UNIT_X, pos + Vector3(r, 0, 0)));
                planes.insert(new Plane(Vector3.UNIT_Y, pos + Vector3(0, -r, 0)));
                planes.insert(new Plane(Vector3.NEGATIVE_UNIT_Y, pos + Vector3(0, r, 0)));
                planes.insert(new Plane(Vector3.UNIT_Z, pos + Vector3(0, 0, -r)));
                planes.insert(new Plane(Vector3.NEGATIVE_UNIT_Z, pos + Vector3(0, 0, r)));
            }
                break;
            case Light.LightTypes.LT_SPOTLIGHT:
            {
                Vector3 dir = l.getDerivedDirection();
                // near & far planes
                planes.insert(new Plane(dir, pos + dir * l.getSpotlightNearClipDistance()));
                planes.insert(new Plane(-dir, pos + dir * r));
                // 4 sides of pyramids
                // derive orientation
                Vector3 up = Vector3.UNIT_Y;
                // Check it's not coincident with dir
                if (Math.Abs(up.dotProduct(dir)) >= 1.0f)
                {
                    up = Vector3.UNIT_Z;
                }
                // cross twice to rederive, only direction is unaltered
                Vector3 right = dir.crossProduct(up);
                right.normalise();
                up = right.crossProduct(dir);
                up.normalise();
                // Derive quaternion from axes (negate dir since -Z)
                Quaternion q;
                q.FromAxes(right, up, -dir);
                
                // derive pyramid corner vectors in world orientation
                Vector3 tl, tr, bl, br;
                Real d = Math.Tan(l.getSpotlightOuterAngle() * 0.5) * r;
                tl = q * Vector3(-d, d, -r);
                tr = q * Vector3(d, d, -r);
                bl = q * Vector3(-d, -d, -r);
                br = q * Vector3(d, -d, -r);
                
                // use cross product to derive normals, pass through light world pos
                // top
                planes.insert(new Plane(tl.crossProduct(tr).normalisedCopy(), pos));
                // right
                planes.insert(new Plane(tr.crossProduct(br).normalisedCopy(), pos));
                // bottom
                planes.insert(new Plane(br.crossProduct(bl).normalisedCopy(), pos));
                // left
                planes.insert(new Plane(bl.crossProduct(tl).normalisedCopy(), pos));
                
            }
                break;
            default:
                // do nothing
                break;
        }
        
    }
    
    void resetLightClip()
    {
        if (!mDestRenderSystem.getCapabilities().hasCapability(Capabilities.RSC_USER_CLIP_PLANES))
            return;
        
        mDestRenderSystem.resetClipPlanes();
    }
    
    void checkCachedLightClippingInfo()
    {
        ulong frame = Root.getSingleton().getNextFrameNumber();
        if (frame != mLightClippingInfoMapFrameNumber)
        {
            // reset cached clip information
            mLightClippingInfoMap.clear();
            mLightClippingInfoMapFrameNumber = frame;
        }
    }
    
    /// The active renderable visitor class - subclasses could override this
    SceneMgrQueuedRenderableVisitor mActiveQueuedRenderableVisitor;
    /// Storage for default renderable visitor
    SceneMgrQueuedRenderableVisitor mDefaultQueuedRenderableVisitor;
    
    /// Whether to use camera-relative rendering
    bool mCameraRelativeRendering;
    Matrix4 mCachedViewMatrix;
    Vector3 mCameraRelativePosition;
    
    /// Last light sets
    uint mLastLightHash;
    ushort mLastLightLimit;
    uint mLastLightHashGpuProgram;
    /// Gpu params that need rebinding (mask of GpuParamVariability)
    ushort mGpuParamsDirty;
    
    void useLights(LightList lights, ushort limit)
    {
        // only call the rendersystem if light list has changed
        if (lights.getHash() != mLastLightHash || limit != mLastLightLimit)
        {
            mDestRenderSystem._useLights(lights, limit);
            mLastLightHash = lights.getHash();
            mLastLightLimit = limit;
        }
    }
    
    void setViewMatrix(Matrix4 m)
    {
        mDestRenderSystem._setViewMatrix(m);
        if (mDestRenderSystem.areFixedFunctionLightsInViewSpace())
        {
            // reset light hash if we've got lights already set
            mLastLightHash = mLastLightHash ? 0 : mLastLightHash;
        }
    }
    
    void useLightsGpuProgram(Pass pass, LightList lights)
    {
        // only call the rendersystem if light list has changed
        if (lights.getHash() != mLastLightHashGpuProgram)
        {
            // Update any automatic gpu params for lights
            // Other bits of information will have to be looked up
            mAutoParamDataSource.setCurrentLightList(lights);
            mGpuParamsDirty |= GpuParamVariability.GPV_LIGHTS;
            
            mLastLightHashGpuProgram = lights.getHash();
            
        }
    }
    
    void bindGpuProgram(GpuProgram prog)
    {
        // need to dirty the light hash, and paarams that need resetting, since program params will have been invalidated
        // Use 1 to guarantee changing it (using 0 could result in no change if list is empty)
        // Hash == 1 is almost impossible to achieve otherwise
        mLastLightHashGpuProgram = 1;
        mGpuParamsDirty = cast(ushort)GpuParamVariability.GPV_ALL;
        mDestRenderSystem.bindGpuProgram(prog);
    }
    
    void updateGpuProgramParameters(Pass pass)
    {
        if (pass.isProgrammable())
        {
            
            if (!mGpuParamsDirty)
                return;
            
            if (mGpuParamsDirty)
                pass._updateAutoParams(mAutoParamDataSource, mGpuParamsDirty);
            
            if (pass.hasVertexProgram())
            {
                mDestRenderSystem.bindGpuProgramParameters(GpuProgramType.GPT_VERTEX_PROGRAM, 
                                                           pass.getVertexProgramParameters(), mGpuParamsDirty);
            }
            
            if (pass.hasGeometryProgram())
            {
                mDestRenderSystem.bindGpuProgramParameters(GpuProgramType.GPT_GEOMETRY_PROGRAM,
                                                           pass.getGeometryProgramParameters(), mGpuParamsDirty);
            }
            
            if (pass.hasFragmentProgram())
            {
                mDestRenderSystem.bindGpuProgramParameters(GpuProgramType.GPT_FRAGMENT_PROGRAM, 
                                                           pass.getFragmentProgramParameters(), mGpuParamsDirty);
            }
            
            if (pass.hasTesselationHullProgram())
            {
                mDestRenderSystem.bindGpuProgramParameters(GpuProgramType.GPT_HULL_PROGRAM, 
                                                           pass.getTesselationHullProgramParameters(), mGpuParamsDirty);
            }
            
            if (pass.hasTesselationHullProgram())
            {
                mDestRenderSystem.bindGpuProgramParameters(GpuProgramType.GPT_DOMAIN_PROGRAM, 
                                                           pass.getTesselationDomainProgramParameters(), mGpuParamsDirty);
            }
            
            mGpuParamsDirty = 0;
        }
        
    }
    
    
    
    
    
    
    
    
    /// Set of registered lod listeners
    //typedef set<LodListener*>::type LodListenerSet;
    alias LodListener[] LodListenerSet;
    LodListenerSet mLodListeners;
    
    /// List of movable object lod changed events
    //typedef vector<MovableObjectLodChangedEvent>::type MovableObjectLodChangedEventList;
    alias MovableObjectLodChangedEvent[] MovableObjectLodChangedEventList;
    MovableObjectLodChangedEventList mMovableObjectLodChangedEvents;
    
    /// List of entity mesh lod changed events
    //typedef vector<EntityMeshLodChangedEvent>::type EntityMeshLodChangedEventList;
    alias EntityMeshLodChangedEvent[] EntityMeshLodChangedEventList;
    EntityMeshLodChangedEventList mEntityMeshLodChangedEvents;
    
    /// List of entity material lod changed events
    //typedef vector<EntityMaterialLodChangedEvent>::type EntityMaterialLodChangedEventList;
    alias EntityMaterialLodChangedEvent[] EntityMaterialLodChangedEventList;
    EntityMaterialLodChangedEventList mEntityMaterialLodChangedEvents;
    
public:
    /** Constructor.
     */
    this(string instanceName)
    {
        mMovableObjectCollectionMapMutex = new Mutex;
        mAnimationsListMutex = new Mutex;
        sceneGraphMutex = new Mutex;
        mAnimationStates = new AnimationStateSet;
        
        mName = instanceName;
        //mRenderQueue = 0;
        mLastRenderQueueInvocationCustom = false;
        mAmbientLight = ColourValue.Black;
        //mCurrentViewport = 0;
        //mSceneRoot = 0;
        //mSkyPlaneEntity = 0;
        //mSkyBoxObj = 0;
        //mSkyPlaneNode = 0;
        //mSkyDomeNode = 0;
        //mSkyBoxNode = 0;
        mSkyPlaneEnabled = false;
        mSkyBoxEnabled = false;
        mSkyDomeEnabled = false;
        mFogMode = FogMode.FOG_NONE;
        //mFogColour = ;
        mFogStart = 0;
        mFogEnd = 0;
        mFogDensity = 0;
        mSpecialCaseQueueMode = SpecialCaseRenderQueueMode.SCRQM_EXCLUDE;
        mWorldGeometryRenderQueue = RenderQueueGroupID.RENDER_QUEUE_WORLD_GEOMETRY_1;
        mLastFrameNumber = 0;
        mResetIdentityView = false;
        mResetIdentityProj = false;
        mNormaliseNormalsOnScale = true;
        mFlipCullingOnNegativeScale = true;
        mLightsDirtyCounter = 0;
        mMovableNameGenerator = new NameGenerator("Ogre/MO");
        //mShadowCasterPlainBlackPass = 0;
        //mShadowReceiverPass = 0;
        mDisplayNodes = false;
        mShowBoundingBoxes = false;
        //mActiveCompositorChain = 0;
        mLateMaterialResolving = false;
        mShadowTechnique = ShadowTechnique.SHADOWTYPE_NONE;
        mDebugShadows = false;
        mShadowColour = ColourValue (0.25, 0.25, 0.25);
        //mShadowDebugPass = 0;
        //mShadowStencilPass = 0;
        //mShadowModulativePass = 0;
        mShadowMaterialInitDone = false;
        mShadowIndexBufferSize = 51200;
        //mFullScreenQuad = 0;
        mShadowDirLightExtrudeDist = 10000;
        mIlluminationStage = IlluminationRenderStage.IRS_NONE;
        mShadowTextureConfigDirty = true;
        mShadowUseInfiniteFarPlane = true;
        mShadowCasterRenderBackFaces = true;
        mShadowAdditiveLightClip = false;
        mLightClippingInfoMapFrameNumber = 999;
        //mShadowCasterSphereQuery = 0;
        //mShadowCasterAABBQuery = 0;
        mDefaultShadowFarDist = 0;
        mDefaultShadowFarDistSquared = 0;
        mShadowTextureOffset = 0.6;
        mShadowTextureFadeStart = 0.7;
        mShadowTextureFadeEnd = 0.9;
        mShadowTextureSelfShadow = false;
        //mShadowTextureCustomCasterPass = 0;
        //mShadowTextureCustomReceiverPass = 0;
        mVisibilityMask = 0xFFFFFFFF;
        mFindVisibleObjects = true;
        mSuppressRenderStateChanges = false;
        mSuppressShadows = false;
        mCameraRelativeRendering = false;
        mLastLightHash = 0;
        mLastLightLimit = 0;
        //mLastLightHashGpuProgram = 0;
        mGpuParamsDirty = GpuParamVariability.GPV_ALL;
        mDefaultQueuedRenderableVisitor = new SceneMgrQueuedRenderableVisitor;

        //TODO D automagically sets it to Entity.init anyway, right?
        // init sky
        //for (size_t i = 0; i < mSkyDomeEntity.length/*5*/; ++i)
        //{
        //    mSkyDomeEntity[i] = null;
        //}
        
        mShadowCasterQueryListener = new ShadowCasterSceneQueryListener(this);
        
        //Root root = Root.getSingleton();
        if (Root.getSingletonPtr())
            _setDestinationRenderSystem(Root.getSingleton().getRenderSystem());
        
        // Setup default queued renderable visitor
        mActiveQueuedRenderableVisitor = mDefaultQueuedRenderableVisitor;
        
        // set up default shadow camera setup
        //mDefaultShadowCameraSetup.bind(new DefaultShadowCameraSetup());
        mDefaultShadowCameraSetup = new DefaultShadowCameraSetup();
        
        // init shadow texture config
        setShadowTextureCount(1);
        
        // init shadow texture count per type.
        mShadowTextureCountPerType[Light.LightTypes.LT_POINT] = 1;
        mShadowTextureCountPerType[Light.LightTypes.LT_DIRECTIONAL] = 1;
        mShadowTextureCountPerType[Light.LightTypes.LT_SPOTLIGHT] = 1;
        
        // create the auto param data source instance
        mAutoParamDataSource = createAutoParamDataSource();
        
    }
    
    /** Default destructor.
     */
    ~this()
    {
        fireSceneManagerDestroyed();
        destroyShadowTextures();
        clearScene();
        destroyAllCameras();
        
        // clear down movable object collection map
        synchronized(mMovableObjectCollectionMapMutex)
        {
            //OGRE_LOCK_MUTEX(mMovableObjectCollectionMapMutex)
            foreach (k,v; mMovableObjectCollectionMap)
            {
                destroy(v);
            }
            mMovableObjectCollectionMap.clear();
        }
        
        destroy(mSkyBoxObj);
        
        destroy(mShadowCasterQueryListener);
        destroy(mSceneRoot);
        destroy(mFullScreenQuad);
        destroy(mShadowCasterSphereQuery);
        destroy(mShadowCasterAABBQuery);
        destroy(mRenderQueue);
        destroy(mAutoParamDataSource);
    }
    
    
    /** Mutex to protect the scene graph from simultaneous access from
     multiple threads.
     @remarks
     If you are updating the scene in a separate thread from the rendering
     thread, then you should lock this mutex before making any changes to 
     the scene graph - that means creating, modifying or deleting a
     scene node, or attaching / detaching objects. It is <b>your</b> 
     responsibility to take out this lock, the detail methods on the nodes
     will not do it for you (for the reasons discussed below).
     @par
     Note that locking this mutex will prevent the scene being rendered until 
     it is unlocked again. therefore you should do this sparingly. Try
     to create any objects you need separately and fully prepare them
     before doing all your scene graph work in one go, thus keeping this
     lock for the shortest time possible.
     @note
     A single global lock is used rather than a per-node lock since 
     it keeps the number of locks required during rendering down to a 
     minimum. Obtaining a lock, even if there is no contention, is not free
     so for performance it is good to do it as little as possible. 
     Since modifying the scene in a separate thread is a fairly
     rare occurrence (relative to rendering), it is better to keep the 
     locking required during rendering lower than to make update locks
     more granular.
     */
    //OGRE_MUTEX(sceneGraphMutex)
    Mutex sceneGraphMutex;
    
    /** Return the instance name of this SceneManager. */
    string getName(){ return mName; }
    
    /** Retrieve the type name of this scene manager.
     @remarks
     This method has to be implemented by subclasses. It should
     return the type name of this SceneManager which agrees with 
     the type name of the SceneManagerFactory which created it.
     */
    abstract string getTypeName();
    
    /** Creates a camera to be managed by this scene manager.
     @remarks
     This camera must be added to the scene at a later time using
     the attachObject method of the SceneNode class.
     @param
     name Name to give the new camera.
     */
    Camera createCamera(string name)
    {
        // Check name not used
        if ((name in mCameras) !is null)
        {
            throw new DuplicateItemError(
                "A camera with the name " ~ name ~ " already exists",
                "SceneManager.createCamera" );
        }
        
        Camera c = new Camera(name, this);
        mCameras[name] = c;
        
        // create visible bounds aab map entry
        mCamVisibleObjectsMap[c] = VisibleObjectsBoundsInfo();
        
        return c;
    }
    
    /** Retrieves a pointer to the named camera.
     @note Throws an exception if the named instance does not exist
     */
    Camera getCamera(string name)
    {
        auto i = name in mCameras;
        if (i is null)
        {
            throw new ItemNotFoundError(
                "Cannot find Camera with name " ~ name,
                "SceneManager.getCamera");
        }
        else
        {
            return *i;
        }
    }

    /** Returns whether a camera with the given name exists.
     */
    bool hasCamera(string name)
    {
        return (name in mCameras) !is null;
    }
    
    /** Removes a camera from the scene.
     @remarks
     This method removes a previously added camera from the scene.
     The camera is deleted so the caller must ensure no references
     to it's previous instance (e.g. in a SceneNode) are used.
     @param
     cam Pointer to the camera to remove
     */
    void destroyCamera(Camera cam)
    {
        destroyCamera(cam.getName());
    }
    
    /** Removes a camera from the scene.
     @remarks
     This method removes an camera from the scene based on the
     camera's name rather than a pointer.
     */
    void destroyCamera(string name)
    {
        // Find in list
        auto i = name in mCameras;
        if (i !is null)
        {
            // Remove visible boundary AAB entry
            auto camVisObjIt = *i in mCamVisibleObjectsMap;
            if ( camVisObjIt !is null )
                mCamVisibleObjectsMap.remove( *i );
            
            // Remove light-shadow cam mapping entry
            auto camLightIt = *i in mShadowCamLightMapping;
            if ( camLightIt !is null )
                mShadowCamLightMapping.remove( *i );
            
            // Notify render system
            mDestRenderSystem._notifyCameraRemoved(*i);
            destroy(*i);
            *i = null;
            mCameras.remove(name);
        }
    }
    
    /** Removes (and destroys) all cameras from the scene.
     @remarks
     Some cameras are internal created to dealing with texture shadow,
     their aren't supposed to destroy outside. So, while you are using
     texture shadow, don't call this method, or you can set the shadow
     technique other than texture-based, which will destroy all internal
     created shadow cameras and textures.
     */
    void destroyAllCameras()
    {
        foreach( k; mCameras.keys)
        {
            auto cam = mCameras[k];//FIXME Just doing foreach over k,v returns garbage if called from dtor (only then?)
            bool dontDelete = false;
            // dont destroy shadow texture cameras here. destroyAllCameras is public
            foreach(camShadowTex; mShadowTextureCameras)
            {
                if( camShadowTex == cam )
                {
                    dontDelete = true;
                    break;
                }
            }
            
            if( dontDelete )    // skip this camera
                //camIt++;
                continue;
            else 
            {
                destroyCamera(cam);
                //camIt = mCameras.begin(); // recreate iterator
            }
        }
        
    }
    
    /** Creates a light for use in the scene.
     @remarks
     Lights can either be in a fixed position and independent of the
     scene graph, or they can be attached to SceneNodes so they derive
     their position from the parent node. Either way, they are created
     using this method so that the SceneManager manages their
     existence.
     @param
     name The name of the new light, to identify it later.
     */
    Light createLight(string name)
    {
        return cast(Light)(
            createMovableObject(name, LightFactory.FACTORY_TYPE_NAME));
    }
    
    /** Creates a light with a generated name. */
    Light createLight()
    {
        string name = mMovableNameGenerator.generate();
        return createLight(name);
    }
    
    /** Returns a pointer to the named Light which has previously been added to the scene.
     @note Throws an exception if the named instance does not exist
     */
    Light getLight(string name)//
    {
        //TODO Not lvalue crap, so use auto l.
        auto l = cast(Light)(getMovableObject(name, LightFactory.FACTORY_TYPE_NAME));
        return l;
    }
    
    /** Returns whether a light with the given name exists.
     */
    bool hasLight(string name)
    {
        return hasMovableObject(name, LightFactory.FACTORY_TYPE_NAME);
    }
    
    /** Retrieve a set of clipping planes for a given light. 
     */
    PlaneList getLightClippingPlanes(Light l)
    {
        checkCachedLightClippingInfo();
        
        // Try to re-use clipping info if already calculated
        LightClippingInfo* ci = l in mLightClippingInfoMap;
        if (ci is null)
        {
            // create new entry
            LightClippingInfo lc;
            mLightClippingInfoMap[l] = lc;
            ci = &mLightClippingInfoMap[l];
        }
        if (!ci.clipPlanesValid)
        {
            buildLightClip(l, ci.clipPlanes);
            ci.clipPlanesValid = true;
        }
        return ci.clipPlanes;
        
    }
    
    /** Retrieve a scissor rectangle for a given light and camera. 
     */
    RealRect getLightScissorRect(Light l, Camera cam)
    {
        checkCachedLightClippingInfo();
        
        // Re-use calculations if possible
        auto ci = l in mLightClippingInfoMap;
        if (ci is null)
        {
            // create new entry
            LightClippingInfo lc;
            mLightClippingInfoMap[l] = lc;
            ci = &mLightClippingInfoMap[l];
        }
        if (!ci.scissorValid)
        {
            
            buildScissor(l, cam, ci.scissorRect);
            ci.scissorValid = true;
        }
        
        return ci.scissorRect;
        
    }
    
    /** Removes the named light from the scene and destroys it.
     @remarks
     Any pointers held to this light after calling this method will be invalid.
     */
    void destroyLight(string name)
    {
        destroyMovableObject(name, LightFactory.FACTORY_TYPE_NAME);
    }
    
    /** Removes the light from the scene and destroys it based on a pointer.
     @remarks
     Any pointers held to this light after calling this method will be invalid.
     */
    void destroyLight(Light light)
    {
        destroyMovableObject(light);
    }
    
    /** Removes and destroys all lights in the scene.
     */
    void destroyAllLights()
    {
        destroyAllMovableObjectsByType(LightFactory.FACTORY_TYPE_NAME);
    }
    
    /** Advance method to increase the lights dirty counter due lights changed.
     @remarks
     Scene manager tracking lights that affecting the frustum, if changes
     detected (the changes includes light list itself and the light's position
     and attenuation range), then increase the lights dirty counter.
     @par
     For some reason, you can call this method to force whole scene objects
     re-populate their light list. But bare in mind, call to this method
     will harm performance, so should avoid if possible.
     */
    void _notifyLightsDirty()
    {
        ++mLightsDirtyCounter;
    }
    
    /** Advance method to gets the lights dirty counter.
     @remarks
     Scene manager tracking lights that affecting the frustum, if changes
     detected (the changes includes light list itself and the light's position
     and attenuation range), then increase the lights dirty counter.
     @par
     When implementing customise lights finding algorithm relied on either
     SceneManager::_getLightsAffectingFrustum or SceneManager::_populateLightList,
     might check this value for sure that the light list are really need to
     re-populate, otherwise, returns cached light list (if exists) for better
     performance.
     */
    ulong _getLightsDirtyCounter(){ return mLightsDirtyCounter; }
    
    /** Get the list of lights which could be affecting the frustum.
     @remarks
     Note that default implementation of this method returns a cached light list,
     which is populated when rendering the scene. So by default the list of lights 
     is only available during scene rendering.
     */
    LightList _getLightsAffectingrustum()
    {
        return mLightsAffectingFrustum;
    }

    
    LightList _getLightsAffectingFrustum()
    {
        return mLightsAffectingFrustum;
    }
    
    /** Populate a light list with an ordered set of the lights which are closest
     to the position specified.
     @remarks
     Note that since directional lights have no position, they are always considered
     closer than any point lights and as such will always take precedence. 
     @par
     Subclasses of the default SceneManager may wish to take into account other issues
     such as possible visibility of the light if that information is included in their
     data structures. This basic scenemanager simply orders by distance, eliminating 
     those lights which are out of range or could not be affecting the frustum (i.e.
     only the lights returned by SceneManager::_getLightsAffectingFrustum are take into
     account).
     @par
     The number of items in the list max exceed the maximum number of lights supported
     by the renderer, but the extraneous ones will never be used. In fact the limit will
     be imposed by Pass.getMaxSimultaneousLights.
     @param position The position at which to evaluate the list of lights
     @param radius The bounding radius to test
     @param destList List to be populated with ordered set of lights; will be cleared by 
     this method before population.
     @param lightMask The mask with which to include / exclude lights
     */
    void _populateLightList(Vector3 position, Real radius, ref LightList destList, uint lightMask = 0xFFFFFFFF)
    {
        // Really basic trawl of the lights, then sort
        // Subclasses could do something smarter
        
        // Pick up the lights that affecting frustum only, which should has been
        // cached, so better than take all lights in the scene into account.
        //
        LightList candidateLights = cast(LightList)_getLightsAffectingFrustum();
        
        // Pre-allocate memory
        destList.clear();
        //destList.reserve(candidateLights.length);
        
        foreach (lt; candidateLights)
        {
            // check whether or not this light is suppose to be taken into consideration for the current light mask set for this operation
            if(!(lt.getLightMask() & lightMask))
                continue; //skip this light
            
            // Calc squared distance
            lt._calcTempSquareDist(position);
            
            if (lt.getType() == Light.LightTypes.LT_DIRECTIONAL)
            {
                // Always included
                destList.insert(lt);
            }
            else
            {
                // only add in-range lights
                if (lt.isInLightRange(Sphere(position,radius)))
                {
                    destList.insert(lt);
                }
            }
        }
        
        // Sort (stable to guarantee ordering on directional lights)
        if (isShadowTechniqueTextureBased())
        {
            // Note that if we're using texture shadows, we actually want to use
            // the first few lights unchanged from the frustum list, matching the
            // texture shadows that were generated
            // Thus we only allow object-relative sorting on the remainder of the list
            if (destList.length > getShadowTextureCount())
            {
                //LightList::iterator start = destList.begin();
                //std::advance(start, getShadowTextureCount());
                std.algorithm.sort!lightLess(destList[getShadowTextureCount() .. $]);
            }
        }
        else
        {
            std.algorithm.sort!lightLess(destList[]);
        }
        
        // Now assign indexes in the list so they can be examined if needed
        size_t lightIndex = 0;
        foreach (li; destList)
        {
            li._notifyIndexInFrame(lightIndex++);
        }
        
    }
    
    /** Populates a light list with an ordered set of the lights which are closest
     to the position of the SceneNode given.
     @remarks
     Note that since directional lights have no position, they are always considered
     closer than any point lights and as such will always take precedence. 
     This overloaded version will take the SceneNode's position and use the second method
     to populate the list.
     @par
     Subclasses of the default SceneManager may wish to take into account other issues
     such as possible visibility of the light if that information is included in their
     data structures. This basic scenemanager simply orders by distance, eliminating 
     those lights which are out of range or could not be affecting the frustum (i.e.
     only the lights returned by SceneManager::_getLightsAffectingFrustum are take into
     account). 
     @par   
     Also note that subclasses of the SceneNode might be used here to provide cached
     scene related data, accelerating the list population (for example light lists for
     SceneNodes could be cached inside subclassed SceneNode objects).
     @par
     The number of items in the list may exceed the maximum number of lights supported
     by the renderer, but the extraneous ones will never be used. In fact the limit will
     be imposed by Pass.getMaxSimultaneousLights.
     @param sn The SceneNode for which to evaluate the list of lights
     @param radius The bounding radius to test
     @param destList List to be populated with ordered set of lights; will be cleared by 
     this method before population.
     @param lightMask The mask with which to include / exclude lights
     */
    void _populateLightList(SceneNode sn, Real radius, ref LightList destList, uint lightMask = 0xFFFFFFFF)
    {
        _populateLightList(sn._getDerivedPosition(), radius, destList, lightMask);
    }
    
    /** Creates an instance of a SceneNode.
     @remarks
     Note that this does not add the SceneNode to the scene hierarchy.
     This method is for convenience, since it allows an instance to
     be created for which the SceneManager is responsible for
     allocating and releasing memory, which is convenient in complex
     scenes.
     @par
     To include the returned SceneNode in the scene, use the addChild
     method of the SceneNode which is to be it's parent.
     @par
     Note that this method takes no parameters, and the node created is unnamed (it is
     actually given a generated name, which you can retrieve if you want).
     If you wish to create a node with a specific name, call the alternative method
     which takes a name parameter.
     */
    SceneNode createSceneNode()
    {
        SceneNode sn = createSceneNodeImpl();
        assert((sn.getName() in mSceneNodes) is null);
        mSceneNodes[sn.getName()] = sn;
        return sn;
    }
    
    /** Creates an instance of a SceneNode with a given name.
     @remarks
     Note that this does not add the SceneNode to the scene hierarchy.
     This method is for convenience, since it allows an instance to
     be created for which the SceneManager is responsible for
     allocating and releasing memory, which is convenient in complex
     scenes.
     @par
     To include the returned SceneNode in the scene, use the addChild
     method of the SceneNode which is to be it's parent.
     @par
     Note that this method takes a name parameter, which makes the node easier to
     retrieve directly again later.
     */
    SceneNode createSceneNode(string name)
    {
        // Check name not used
        if ((name in mSceneNodes) !is null)
        {
            throw new DuplicateItemError(
                "A scene node with the name " ~ name ~ " already exists",
                "SceneManager.createSceneNode" );
        }
        
        SceneNode sn = createSceneNodeImpl(name);
        mSceneNodes[sn.getName()] = sn;
        return sn;
    }
    
    /** Destroys a SceneNode with a given name.
     @remarks
     This allows you to physically delete an individual SceneNode if you want to.
     Note that this is not normally recommended, it's better to allow SceneManager
     to delete the nodes when the scene is cleared.
     */
    void destroySceneNode(string name)
    {
        auto i = name in mSceneNodes;
        
        if (i is null)
        {
            throw new ItemNotFoundError( "SceneNode '" ~ name ~ "' not found.",
                                        "SceneManager.destroySceneNode");
        }
        
        // Find any scene nodes which are tracking this node, and turn them off
        //foreach (n; mAutoTrackingSceneNodes)
        for(size_t j = 0; j < mAutoTrackingSceneNodes.length; )
        {
            auto n = mAutoTrackingSceneNodes[j];
            // Tracking this node
            if (n.getAutoTrackTarget() == *i)
            {
                // turn off, this will notify SceneManager to remove
                n.setAutoTracking(false);
                j++;
            }
            // node is itself a tracker
            else if (n == *i)
            {
                mAutoTrackingSceneNodes.removeFromArray(n);
            }else
                j++;
        }
        
        // detach from parent (don't do this in destructor since bulk destruction
        // behaves differently)
        Node parentNode = i.getParent();
        if (parentNode)
        {
            Node n = *i;
            parentNode.removeChild(n);
        }
        destroy(*i);
        mSceneNodes.remove(name);
    }
    
    /** Destroys a SceneNode.
     @remarks
     This allows you to physically delete an individual SceneNode if you want to.
     Note that this is not normally recommended, it's better to allow SceneManager
     to delete the nodes when the scene is cleared.
     */
    void destroySceneNode(SceneNode sn)
    {
        destroySceneNode(sn.getName());
    }
    /** Gets the SceneNode at the root of the scene hierarchy.
     @remarks
     The entire scene is held as a hierarchy of nodes, which
     allows things like relative transforms, general changes in
     rendering state etc (See the SceneNode class for more info).
     In this basic SceneManager class, the application using
     Ogre is free to structure this hierarchy however it likes,
     since it has no real significance apart from making transforms
     relative to each node (more specialised subclasses will
     provide utility methods for building specific node structures
     e.g. loading a BSP tree).
     @par
     However, in all cases there is only ever one root node of
     the hierarchy, and this method returns a pointer to it.
     */
    SceneNode getRootSceneNode()
    {
        if (!mSceneRoot)
        {
            // Create root scene node
            mSceneRoot = createSceneNodeImpl("Ogre/SceneRoot");
            mSceneRoot._notifyRootNode();
        }
        
        return mSceneRoot;
    }
    
    /** Retrieves a named SceneNode from the scene graph.
     @remarks
     If you chose to name a SceneNode as you created it, or if you
     happened to make a note of the generated name, you can look it
     up wherever it is in the scene graph using this method.
     @note Throws an exception if the named instance does not exist
     */
    SceneNode getSceneNode(string name)//
    {
        auto i = name in mSceneNodes;
        
        if (i is null)
        {
            throw new ItemNotFoundError("SceneNode '" ~ name ~ "' not found.",
                                        "SceneManager.getSceneNode");
        }
        
        return *i;
    }
    
    /** Returns whether a scene node with the given name exists.
     */
    bool hasSceneNode(string name)
    {
        return (name in mSceneNodes) !is null;
    }
    
    /** Create an Entity (instance of a discrete mesh).
     @param
     entityName The name to be given to the entity (must be unique).
     @param
     meshName The name of the Mesh it is to be based on (e.g. 'knot.oof'). The
     mesh will be loaded if it is not already.
     */
    Entity createEntity(string entityName, string meshName, 
                        string groupName = ResourceGroupManager.AUTODETECT_RESOURCE_GROUP_NAME )//
    {
        // delegate to factory implementation
        NameValuePairList params;
        params["mesh"] = meshName;
        params["resourceGroup"] = groupName;
        return cast(Entity)
            createMovableObject(entityName, EntityFactory.FACTORY_TYPE_NAME, 
                                params);
        
    }
    
    /** Create an Entity (instance of a discrete mesh).
     @param
     entityName The name to be given to the entity (must be unique).
     @param
     pMesh The pointer to the Mesh it is to be based on.
     */
    Entity createEntity(string entityName, /*const*/ SharedPtr!Mesh pMesh )
    {
        return createEntity(entityName, pMesh.get().getName(), pMesh.get().getGroup());
    }
    
    /** Create an Entity (instance of a discrete mesh) with an autogenerated name.
     @param
     meshName The name of the Mesh it is to be based on (e.g. 'knot.oof'). The
     mesh will be loaded if it is not already.
     */
    Entity createEntity(string meshName)
    {
        string name = mMovableNameGenerator.generate();
        // note, we can't allow groupName to be passes, it would be ambiguous (2 string params)
        return createEntity(name, meshName, ResourceGroupManager.AUTODETECT_RESOURCE_GROUP_NAME);
    }
    
    /** Create an Entity (instance of a discrete mesh) with an autogenerated name.
     @param
     pMesh The pointer to the Mesh it is to be based on.
     */
    Entity createEntity(/*const*/ SharedPtr!Mesh pMesh)
    {
        string name = mMovableNameGenerator.generate();
        return createEntity(name, pMesh);
    }
    
    /** Prefab shapes available without loading a model.
     @note
     Minimal implementation at present.
     @todo
     Add more prefabs (teapots, teapots!!!)
     */
    enum PrefabType {
        PT_PLANE,
        PT_CUBE,
        PT_SPHERE
    }
    
    /** Create an Entity (instance of a discrete mesh) from a range of prefab shapes.
     @param
     entityName The name to be given to the entity (must be unique).
     @param
     ptype The prefab type.
     */
    Entity createEntity(string entityName, PrefabType ptype)
    {
        switch (ptype)
        {
            case PrefabType.PT_PLANE:
                return createEntity(entityName, "Prefab_Plane");
            case PrefabType.PT_CUBE:
                return createEntity(entityName, "Prefab_Cube");
            case PrefabType.PT_SPHERE:
                return createEntity(entityName, "Prefab_Sphere");
            default:
                break;
        }
        
        throw new ItemNotFoundError(
            "Unknown prefab type for entity " ~ entityName,
            "SceneManager.createEntity");
    }
    
    /** Create an Entity (instance of a discrete mesh) from a range of prefab shapes, generating the name.
     @param ptype The prefab type.
     */
    Entity createEntity(PrefabType ptype)
    {
        string name = mMovableNameGenerator.generate();
        return createEntity(name, ptype);
    }
    
    /** Retrieves a pointer to the named Entity. 
     @note Throws an exception if the named instance does not exist
     */
    Entity getEntity(string meshName)//
    {
        string name = mMovableNameGenerator.generate();
        // note, we can't allow groupName to be passes, it would be ambiguous (2 string params)
        return createEntity(name, meshName, ResourceGroupManager.AUTODETECT_RESOURCE_GROUP_NAME);
    }
    
    /** Returns whether an entity with the given name exists.
     */
    bool hasEntity(string name)
    {
        return hasMovableObject(name, EntityFactory.FACTORY_TYPE_NAME);
    }
    
    /** Removes & destroys an Entity from the SceneManager.
     @warning
     Must only be done if the Entity is not attached
     to a SceneNode. It may be safer to wait to clear the whole
     scene if you are unsure use clearScene.
     @see
     SceneManager::clearScene
     */
    void destroyEntity(Entity ent)
    {
        destroyMovableObject(ent);
    }
    
    /** Removes & destroys an Entity from the SceneManager by name.
     @warning
     Must only be done if the Entity is not attached
     to a SceneNode. It may be safer to wait to clear the whole
     scene if you are unsure use clearScene.
     @see
     SceneManager::clearScene
     */
    void destroyEntity(string name)
    {
        destroyMovableObject(name, EntityFactory.FACTORY_TYPE_NAME);
    }
    
    /** Removes & destroys all Entities.
     @warning
     Again, use caution since no Entity must be referred to
     elsewhere e.g. attached to a SceneNode otherwise a crash
     is likely. Use clearScene if you are unsure (it clears SceneNode
     entries too.)
     @see
     SceneManager::clearScene
     */
    void destroyAllEntities()
    {
        destroyAllMovableObjectsByType(EntityFactory.FACTORY_TYPE_NAME);
    }
    
    /** Create a ManualObject, an object which you populate with geometry
     manually through a GL immediate-mode style interface.
     @param
     name The name to be given to the object (must be unique).
     */
    ManualObject createManualObject(string name)
    {
        return cast(ManualObject)
            createMovableObject(name, ManualObjectFactory.FACTORY_TYPE_NAME);
    }
    
    /** Create a ManualObject, an object which you populate with geometry
     manually through a GL immediate-mode style interface, generating the name.
     */
    ManualObject createManualObject()
    {
        string name = mMovableNameGenerator.generate();
        return createManualObject(name);
    }
    
    /** Retrieves a pointer to the named ManualObject. 
     @note Throws an exception if the named instance does not exist
     */
    ManualObject getManualObject(string name)//
    {
        return cast(ManualObject)
            getMovableObject(name, ManualObjectFactory.FACTORY_TYPE_NAME);
    }
    
    /** Returns whether a manual object with the given name exists.
     */
    bool hasManualObject(string name)
    {
        return hasMovableObject(name, ManualObjectFactory.FACTORY_TYPE_NAME);
    }
    
    /** Removes & destroys a ManualObject from the SceneManager.
     */
    void destroyManualObject(ManualObject obj)
    {
        destroyMovableObject(obj);
    }
    
    /** Removes & destroys a ManualObject from the SceneManager.
     */
    void destroyManualObject(string name)
    {
        destroyMovableObject(name, ManualObjectFactory.FACTORY_TYPE_NAME);
    }
    
    /** Removes & destroys all ManualObjects from the SceneManager.
     */
    void destroyAllManualObjects()
    {
        destroyAllMovableObjectsByType(ManualObjectFactory.FACTORY_TYPE_NAME);
    }
    
    /** Create a BillboardChain, an object which you can use to render
     a linked chain of billboards.
     @param
     name The name to be given to the object (must be unique).
     */
    BillboardChain createBillboardChain(string name)
    {
        return cast(BillboardChain)
            createMovableObject(name, BillboardChainFactory.FACTORY_TYPE_NAME);
    }
    /** Create a BillboardChain, an object which you can use to render
     a linked chain of billboards, with a generated name.
     */
    BillboardChain createBillboardChain()
    {
        string name = mMovableNameGenerator.generate();
        return createBillboardChain(name);
    }
    /** Retrieves a pointer to the named BillboardChain. 
     @note Throws an exception if the named instance does not exist
     */
    BillboardChain getBillboardChain(string name)//
    {
        return cast(BillboardChain)
            getMovableObject(name, BillboardChainFactory.FACTORY_TYPE_NAME);
    }
    
    /** Returns whether a billboard chain with the given name exists.
     */
    bool hasBillboardChain(string name)
    {
        return hasMovableObject(name, BillboardChainFactory.FACTORY_TYPE_NAME);
    }
    
    /** Removes & destroys a BillboardChain from the SceneManager.
     */
    void destroyBillboardChain(BillboardChain obj)
    {
        destroyMovableObject(obj);
    }
    
    /** Removes & destroys a BillboardChain from the SceneManager.
     */
    void destroyBillboardChain(string name)
    {
        destroyMovableObject(name, BillboardChainFactory.FACTORY_TYPE_NAME);
    }
    /** Removes & destroys all BillboardChains from the SceneManager.
     */
    void destroyAllBillboardChains()
    {
        destroyAllMovableObjectsByType(BillboardChainFactory.FACTORY_TYPE_NAME);
    }
    /** Create a RibbonTrail, an object which you can use to render
     a linked chain of billboards which follows one or more nodes.
     @param
     name The name to be given to the object (must be unique).
     */
    RibbonTrail createRibbonTrail(string name)
    {
        return cast(RibbonTrail)
            createMovableObject(name, RibbonTrailFactory.FACTORY_TYPE_NAME);
    }
    /** Create a RibbonTrail, an object which you can use to render
     a linked chain of billboards which follows one or more nodes, generating the name.
     */
    RibbonTrail createRibbonTrail()
    {
        string name = mMovableNameGenerator.generate();
        return createRibbonTrail(name);
    }
    /** Retrieves a pointer to the named RibbonTrail. 
     @note Throws an exception if the named instance does not exist
     */
    RibbonTrail getRibbonTrail(string name)//
    {
        return cast(RibbonTrail)
            getMovableObject(name, RibbonTrailFactory.FACTORY_TYPE_NAME);
    }
    
    /** Returns whether a ribbon trail with the given name exists.
     */
    bool hasRibbonTrail(string name)
    {
        return hasMovableObject(name, RibbonTrailFactory.FACTORY_TYPE_NAME);
    }
    
    /** Removes & destroys a RibbonTrail from the SceneManager.
     */
    void destroyRibbonTrail(RibbonTrail obj)
    {
        destroyMovableObject(obj);
    }
    
    /** Removes & destroys a RibbonTrail from the SceneManager.
     */
    void destroyRibbonTrail(string name)
    {
        destroyMovableObject(name, RibbonTrailFactory.FACTORY_TYPE_NAME);
    }
    /** Removes & destroys all RibbonTrails from the SceneManager.
     */
    void destroyAllRibbonTrails()
    {
        destroyAllMovableObjectsByType(RibbonTrailFactory.FACTORY_TYPE_NAME);
    }
    
    /** Creates a particle system based on a template.
     @remarks
     This method creates a new ParticleSystem instance based on the named template
     (defined through ParticleSystemManager::createTemplate) and returns a 
     pointer to the caller. The caller should not delete this object, it will be freed at system shutdown, 
     or can be released earlier using the destroyParticleSystem method.
     @par
     Each system created from a template takes the template's settings at the time of creation, 
     but is completely separate from the template from there on. 
     @par
     Creating a particle system does not make it a part of the scene. As with other MovableObject
     subclasses, a ParticleSystem is not rendered until it is attached to a SceneNode. 
     @par
     This is probably the more useful particle system creation method since it does not require manual
     setup of the system. Note that the initial quota is based on the template but may be changed later.
     @param 
     name The name to give the new particle system instance.
     @param 
     templateName The name of the template to base the new instance on.
     */
    ParticleSystem createParticleSystem(string name,
                                        string templateName)
    {
        NameValuePairList params;
        params["templateName"] = templateName;
        
        return cast(ParticleSystem)
            createMovableObject(name, ParticleSystemFactory.FACTORY_TYPE_NAME, 
                                params);
    }
    /** Create a blank particle system.
     @remarks
     This method creates a new, blank ParticleSystem instance and returns a pointer to it.
     The caller should not delete this object, it will be freed at system shutdown, or can
     be released earlier using the destroyParticleSystem method.
     @par
     The instance returned from this method won't actually do anything because on creation a
     particle system has no emitters. The caller should manipulate the instance through it's 
     ParticleSystem methods to actually create a real particle effect. 
     @par
     Creating a particle system does not make it a part of the scene. As with other MovableObject
     subclasses, a ParticleSystem is not rendered until it is attached to a SceneNode. 
     @param
     name The name to give the ParticleSystem.
     @param 
     quota The maximum number of particles to allow in this system. 
     @param
     resourceGroup The resource group which will be used to load dependent resources
     */
    ParticleSystem createParticleSystem(string name,
                                        size_t quota = 500, 
                                        string resourceGroup = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME)
    {
        NameValuePairList params;
        params["quota"] = std.conv.to!string(quota);
        params["resourceGroup"] = resourceGroup;
        
        return cast(ParticleSystem)
            createMovableObject(name, ParticleSystemFactory.FACTORY_TYPE_NAME, 
                                params);
    }
    
    /** Create a blank particle system with a generated name.
     @remarks
     This method creates a new, blank ParticleSystem instance and returns a pointer to it.
     The caller should not delete this object, it will be freed at system shutdown, or can
     be released earlier using the destroyParticleSystem method.
     @par
     The instance returned from this method won't actually do anything because on creation a
     particle system has no emitters. The caller should manipulate the instance through it's 
     ParticleSystem methods to actually create a real particle effect. 
     @par
     Creating a particle system does not make it a part of the scene. As with other MovableObject
     subclasses, a ParticleSystem is not rendered until it is attached to a SceneNode. 
     @param 
     quota The maximum number of particles to allow in this system. 
     @param
     resourceGroup The resource group which will be used to load dependent resources
     */
    ParticleSystem createParticleSystem(size_t quota = 500, 
                                        string resourceGroup = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME)
    {
        string name = mMovableNameGenerator.generate();
        return createParticleSystem(name, quota, resourceGroup);
    }
    /** Retrieves a pointer to the named ParticleSystem. 
     @note Throws an exception if the named instance does not exist
     */
    ParticleSystem getParticleSystem(string name) //const
    {
        return cast(ParticleSystem)
            getMovableObject(name, ParticleSystemFactory.FACTORY_TYPE_NAME);
    }
    /** Returns whether a particle system with the given name exists.
     */
    bool hasParticleSystem(string name)
    {
        return hasMovableObject(name, ParticleSystemFactory.FACTORY_TYPE_NAME);
    }
    
    /** Removes & destroys a ParticleSystem from the SceneManager.
     */
    void destroyParticleSystem(ParticleSystem obj)
    {
        destroyMovableObject(obj);
    }
    /** Removes & destroys a ParticleSystem from the SceneManager.
     */
    void destroyParticleSystem(string name)
    {
        destroyMovableObject(name, ParticleSystemFactory.FACTORY_TYPE_NAME);
    }
    /** Removes & destroys all ParticleSystems from the SceneManager.
     */
    void destroyAllParticleSystems()
    {
        destroyAllMovableObjectsByType(ParticleSystemFactory.FACTORY_TYPE_NAME);
    }
    
    /** Empties the entire scene, inluding all SceneNodes, Entities, Lights, 
     BillboardSets etc. Cameras are not deleted at this stage since
     they are still referenced by viewports, which are not destroyed during
     this process.
     */
    void clearScene()
    {
        destroyAllStaticGeometry();
        destroyAllInstanceManagers();
        destroyAllMovableObjects();
        
        // Clear root node of all children
        getRootSceneNode().removeAllChildren();
        getRootSceneNode().detachAllObjects();
        
        // Delete all SceneNodes, except root that is
        foreach (k,v; mSceneNodes)
        {
            destroy(v);
        }
        mSceneNodes.clear();
        mAutoTrackingSceneNodes.clear();
        
        // Clear animations
        destroyAllAnimations();
        
        // Remove sky nodes since they've been deleted
        mSkyBoxNode = mSkyPlaneNode = mSkyDomeNode = null;
        mSkyBoxEnabled = mSkyPlaneEnabled = mSkyDomeEnabled = false; 
        
        // Clear render queue, empty completely
        if (mRenderQueue)
            mRenderQueue.clear(true);
    }
    
    /** Sets the ambient light level to be used for the scene.
     @remarks
     This sets the colour and intensity of the ambient light in the scene, i.e. the
     light which is 'sourceless' and illuminates all objects equally.
     The colour of an object is affected by a combination of the light in the scene,
     and the amount of light that object reflects (in this case based on the Material::ambient
     property).
     @remarks
     By default the ambient light in the scene is ColourValue.Black, i.e. no ambient light. This
     means that any objects rendered with a Material which has lighting enabled (see Material::setLightingEnabled)
     will not be visible unless you have some dynamic lights in your scene.
     */
    void setAmbientLight(ColourValue colour)
    {
        mAmbientLight = colour;
    }
    
    /** Returns the ambient light level to be used for the scene.
     */
    ColourValue getAmbientLight()
    {
        return mAmbientLight;
    }
    
    /** Sets the source of the 'world' geometry, i.e. the large, mainly static geometry
     making up the world e.g. rooms, landscape etc.
     This function can be called before setWorldGeometry in a background thread, do to
     some slow tasks (e.g. IO) that do not involve the backend render system.
     @remarks
     Depending on the type of SceneManager (subclasses will be specialised
     for particular world geometry types) you have requested via the Root or
     SceneManagerEnumerator classes, you can pass a filename to this method and it
     will attempt to load the world-level geometry for use. If you try to load
     an inappropriate type of world data an exception will be thrown. The default
     SceneManager cannot handle any sort of world geometry and so will always
     throw an exception. However subclasses like BspSceneManager can load
     particular types of world geometry e.g. "q3dm1.bsp".

     */
    void prepareWorldGeometry(string filename)
    {
        // This default implementation cannot handle world geometry
        throw new InvalidParamsError(
            "World geometry is not supported by the generic SceneManager.",
            "SceneManager.prepareWorldGeometry");
    }
    
    /** Sets the source of the 'world' geometry, i.e. the large, mainly 
     static geometry making up the world e.g. rooms, landscape etc.
     This function can be called before setWorldGeometry in a background thread, do to
     some slow tasks (e.g. IO) that do not involve the backend render system.
     @remarks
     Depending on the type of SceneManager (subclasses will be 
     specialised for particular world geometry types) you have 
     requested via the Root or SceneManagerEnumerator classes, you 
     can pass a stream to this method and it will attempt to load 
     the world-level geometry for use. If the manager can only 
     handle one input format the typeName parameter is not required.
     The stream passed will be read (and it's state updated). 
     @param stream Data stream containing data to load
     @param typeName string identifying the type of world geometry
     contained in the stream - not required if this manager only 
     supports one type of world geometry.
     */
    void prepareWorldGeometry(DataStream stream, 
                              string typeName = null)
    {
        // This default implementation cannot handle world geometry
        throw new InvalidParamsError(
            "World geometry is not supported by the generic SceneManager.",
            "SceneManager.prepareWorldGeometry");
    }
    
    /** Sets the source of the 'world' geometry, i.e. the large, mainly static geometry
     making up the world e.g. rooms, landscape etc.
     @remarks
     Depending on the type of SceneManager (subclasses will be specialised
     for particular world geometry types) you have requested via the Root or
     SceneManagerEnumerator classes, you can pass a filename to this method and it
     will attempt to load the world-level geometry for use. If you try to load
     an inappropriate type of world data an exception will be thrown. The default
     SceneManager cannot handle any sort of world geometry and so will always
     throw an exception. However subclasses like BspSceneManager can load
     particular types of world geometry e.g. "q3dm1.bsp".
     */
    void setWorldGeometry(string filename)
    {
        // This default implementation cannot handle world geometry
        throw new InvalidParamsError(
            "World geometry is not supported by the generic SceneManager.",
            "SceneManager.setWorldGeometry");
    }
    
    /** Sets the source of the 'world' geometry, i.e. the large, mainly 
     static geometry making up the world e.g. rooms, landscape etc.
     @remarks
     Depending on the type of SceneManager (subclasses will be 
     specialised for particular world geometry types) you have 
     requested via the Root or SceneManagerEnumerator classes, you 
     can pass a stream to this method and it will attempt to load 
     the world-level geometry for use. If the manager can only 
     handle one input format the typeName parameter is not required.
     The stream passed will be read (and it's state updated). 
     @param stream Data stream containing data to load
     @param typeName string identifying the type of world geometry
     contained in the stream - not required if this manager only 
     supports one type of world geometry.
     */
    void setWorldGeometry(DataStream stream, 
                          string typeName = null)
    {
        // This default implementation cannot handle world geometry
        throw new InvalidParamsError(
            "World geometry is not supported by the generic SceneManager.",
            "SceneManager.setWorldGeometry");
    }
    
    /** Estimate the number of loading stages required to load the named
     world geometry. 
     @remarks
     This method should be overridden by SceneManagers that provide
     custom world geometry that can take some time to load. They should
     return from this method a count of the number of stages of progress
     they can report on whilst loading. During real loading (setWorldGeometry),
     they should call ResourceGroupManager._notifyWorldGeometryProgress exactly
     that number of times when loading the geometry for real.
     @note 
     The default is to return 0, ie to not report progress. 
     */
    size_t estimateWorldGeometry(string filename)
    { return 0; }
    
    /** Estimate the number of loading stages required to load the named
     world geometry. 
     @remarks
     Operates just like the version of this method which takes a
     filename, but operates on a stream instead. Note that since the
     stream is updated, you'll need to reset the stream or reopen it
     when it comes to loading it for real.
     @param stream Data stream containing data to load
     @param typeName string identifying the type of world geometry
     contained in the stream - not required if this manager only 
     supports one type of world geometry.
     */      
    size_t estimateWorldGeometry(DataStream stream, 
                                 string typeName = null)
    { return 0; }
    
    /** Asks the SceneManager to provide a suggested viewpoint from which the scene should be viewed.
     @remarks
     Typically this method returns the origin unless a) world geometry has been loaded using
     SceneManager::setWorldGeometry and b) that world geometry has suggested 'start' points.
     If there is more than one viewpoint which the scene manager can suggest, it will always suggest
     the first one unless the random parameter is true.
     @param
     random If true, and there is more than one possible suggestion, a random one will be used. If false
     the same one will always be suggested.
     @return
     On success, true is returned.
     @par
     On failiure, false is returned.
     */
    ViewPoint getSuggestedViewpoint(bool random = false)
    {
        // By default return the origin
        ViewPoint vp;
        vp.position = Vector3.ZERO;
        vp.orientation = Quaternion.IDENTITY;
        return vp;
    }
    
    /** Method for setting a specific option of the Scene Manager. These options are usually
     specific for a certain implemntation of the Scene Manager class, and may (and probably
     will) not exist across different implementations.
     @param
     strKey The name of the option to set
     @param
     pValue A pointer to the value - the size should be calculated by the scene manager
     based on the key
     @return
     On success, true is returned.
     @par
     On failiure, false is returned.
     */
    bool setOption( string strKey,void* pValue )
    { return false; }
    
    /** Method for getting the value of an implementation-specific Scene Manager option.
     @param
     strKey The name of the option
     @param
     pDestValue A pointer to a memory location where the value will
     be copied. Currently, the memory will be allocated by the
     scene manager, but this may change
     @return
     On success, true is returned and pDestValue points to the value of the given
     option.
     @par
     On failiure, false is returned and pDestValue is set to NULL.
     */
    bool getOption( string strKey, void* pDestValue )
    { return false; }
    
    /** Method for verifying wether the scene manager has an implementation-specific
     option.
     @param
     strKey The name of the option to check for.
     @return
     If the scene manager contains the given option, true is returned.
     @remarks
     If it does not, false is returned.
     */
    bool hasOption( string strKey )
    { return false; }
    
    /** Method for getting all possible values for a specific option. When this list is too large
     (i.e. the option expects, for example, a float), the return value will be true, but the
     list will contain just one element whose size will be set to 0.
     Otherwise, the list will be filled with all the possible values the option can
     accept.
     @param
     strKey The name of the option to get the values for.
     @param
     refValueList A reference to a list that will be filled with the available values.
     @return
     On success (the option exists), true is returned.
     @par
     On failure, false is returned.
     */
    bool getOptionValues( string strKey, ref StringVector refValueList )
    { return false; }
    
    /** Method for getting all the implementation-specific options of the scene manager.
     @param
     refKeys A reference to a list that will be filled with all the available options.
     @return
     On success, true is returned. On failiure, false is returned.
     */
    bool getOptionKeys( ref StringVector refKeys )
    { return false; }
    
    /** Internal method for updating the scene graph ie the tree of SceneNode instances managed by this class.
     @remarks
     This must be done before issuing objects to the rendering pipeline, since derived transformations from
     parent nodes are not updated until required. This SceneManager is a basic implementation which simply
     updates all nodes from the root. This ensures the scene is up to date but requires all the nodes
     to be updated even if they are not visible. Subclasses could trim this such that only potentially visible
     nodes are updated.
     */
    void _updateSceneGraph(Camera cam)
    {
        firePreUpdateSceneGraph(cam);
        debug(STDERR) std.stdio.stderr.writeln("SceneManager._updateSceneGraph");
        // Process queued needUpdate calls 
        Node.processQueuedUpdates();
        
        // Cascade down the graph updating transforms & world bounds
        // In this implementation, just update from the root
        // Smarter SceneManager subclasses may choose to update only
        //   certain scene graph branches
        getRootSceneNode()._update(true, false);
        
        firePostUpdateSceneGraph(cam);
    }
    
    /** Internal method which parses the scene to find visible objects to render.
     @remarks
     If you're implementing a custom scene manager, this is the most important method to
     override since it's here you can apply your custom world partitioning scheme. Once you
     have added the appropriate objects to the render queue, you can let the default
     SceneManager objects _renderVisibleObjects handle the actual rendering of the objects
     you pick.
     @par
     Any visible objects will be added to a rendering queue, which is indexed by material in order
     to ensure objects with the same material are rendered together to minimise render state changes.
     */
    void _findVisibleObjects(Camera cam, VisibleObjectsBoundsInfo visibleBounds, bool onlyShadowCasters)
    {
        // Tell nodes to find, cascade down all nodes
        getRootSceneNode()._findVisibleObjects(cam, getRenderQueue(), visibleBounds, true, 
                                               mDisplayNodes, onlyShadowCasters);
    }
    
    /** Internal method for applying animations to scene nodes.
     @remarks
     Uses the internally stored AnimationState objects to apply animation to SceneNodes.
     */
    void _applySceneAnimations()
    {
        // manual lock over states (extended duration required)
        //OGRE_LOCK_MUTEX(mAnimationStates.OGRE_AUTO_MUTEX_NAME)
        synchronized(mAnimationStates.mLock)
        {
            // Iterate twice, once to reset, once to apply, to allow blending
            auto stateIt = mAnimationStates.getEnabledAnimationStates();
            
            foreach (state; stateIt)
            {
                Animation anim = getAnimation(state.getAnimationName());
                
                // Reset any nodes involved
                auto nodeTrackIt = anim.getNodeTracks();
                foreach(t; nodeTrackIt)
                {
                    Node nd = t.getAssociatedNode();
                    if (nd)
                        nd.resetToInitialState();
                }
                
                auto numTrackIt = anim.getNumericTracks();
                foreach(t; numTrackIt)
                {
                    SharedPtr!AnimableValue animPtr = t.getAssociatedAnimable();
                    if (!animPtr.isNull())
                        animPtr.get().resetToBaseValue();
                }
            }
            
            // this should allow blended animations
            stateIt = mAnimationStates.getEnabledAnimationStates();
            foreach (state; stateIt)
            {
                Animation anim = getAnimation(state.getAnimationName());
                // Apply the animation
                anim.apply(state.getTimePosition(), state.getWeight());
            }
        }
    }
    
    /** Sends visible objects found in _findVisibleObjects to the rendering engine.
     */
    void _renderVisibleObjects()
    {
        RenderQueueInvocationSequence invocationSequence = 
            mCurrentViewport._getRenderQueueInvocationSequence();
        // Use custom sequence only if we're not doing the texture shadow render
        // since texture shadow render should not be interfered with by suppressing
        // render state changes for example
        if (invocationSequence && mIlluminationStage != IlluminationRenderStage.IRS_RENDER_TO_TEXTURE)
        {
            renderVisibleObjectsCustomSequence(invocationSequence);
        }
        else
        {
            renderVisibleObjectsDefaultSequence();
        }
    }
    
    /** Prompts the class to send its contents to the renderer.
     @remarks
     This method prompts the scene manager to send the
     contents of the scene it manages to the rendering
     pipeline, possibly preceded by some sorting, culling
     or other scene management tasks. Note that this method is not normally called
     directly by the user application; it is called automatically
     by the Ogre rendering loop.
     @param camera Pointer to a camera from whose viewpoint the scene is to
     be rendered.
     @param vp The target viewport
     @param includeOverlays Whether or not overlay objects should be rendered
     */
    void _renderScene(Camera camera, Viewport vp, bool includeOverlays)
    {
        debug(STDERR) std.stdio.stderr.writeln("SceneManager._renderScene");
        mixin(OgreProfileGroup("_renderScene", ProfileGroupMask.OGREPROF_GENERAL));
        Root.getSingleton()._pushCurrentSceneManager(this);
        mActiveQueuedRenderableVisitor.targetSceneMgr = this;
        mAutoParamDataSource.setCurrentSceneManager(this);
        
        // Also set the internal viewport pointer at this point, for calls that need it
        // However don't call setViewport just yet (see below)
        mCurrentViewport = vp;
        
        // reset light hash so even if light list is the same, we refresh the content every frame
        LightList emptyLightList;
        useLights(emptyLightList, 0);
        
        if (isShadowTechniqueInUse())
        {
            // Prepare shadow materials
            initShadowVolumeMaterials();
        }
        
        // Perform a quick pre-check to see whether we should override far distance
        // When using stencil volumes we have to use infinite far distance
        // to prevent dark caps getting clipped
        if (isShadowTechniqueStencilBased() && 
            camera.getProjectionType() == ProjectionType.PT_PERSPECTIVE &&
            camera.getFarClipDistance() != 0 && 
            mDestRenderSystem.getCapabilities().hasCapability(Capabilities.RSC_INFINITE_FAR_PLANE) && 
            mShadowUseInfiniteFarPlane)
        {
            // infinite far distance
            camera.setFarClipDistance(0);
        }
        
        mCameraInProgress = camera;
        
        
        // Update controllers 
        ControllerManager.getSingleton().updateAllControllers();
        
        // Update the scene, only do this once per frame
        ulong thisFrameNumber = Root.getSingleton().getNextFrameNumber();
        if (thisFrameNumber != mLastFrameNumber)
        {
            // Update animations
            _applySceneAnimations();
            updateDirtyInstanceManagers();
            mLastFrameNumber = thisFrameNumber;
        }
        
        synchronized(sceneGraphMutex)
        {
            // Lock scene graph mutex, no more changes until we're ready to render
            //OGRE_LOCK_MUTEX(sceneGraphMutex)
            
            // Update scene graph for this camera (can happen multiple times per frame)
            {
                mixin(OgreProfileGroup("_updateSceneGraph", ProfileGroupMask.OGREPROF_GENERAL));
                _updateSceneGraph(camera);
                
                // Auto-track nodes
                foreach (atsni; mAutoTrackingSceneNodes)
                {
                    atsni._autoTrack();
                }
                // Auto-track camera if required
                camera._autoTrack();
            }
            
            if (mIlluminationStage != IlluminationRenderStage.IRS_RENDER_TO_TEXTURE && mFindVisibleObjects)
            {
                // Locate any lights which could be affecting the frustum
                findLightsAffectingFrustum(camera);
                
                // Are we using any shadows at all?
                if (isShadowTechniqueInUse() && vp.getShadowsEnabled())
                {
                    // Prepare shadow textures if texture shadow based shadowing
                    // technique in use
                    if (isShadowTechniqueTextureBased())
                    {
                        mixin(OgreProfileGroup("prepareShadowTextures", ProfileGroupMask.OGREPROF_GENERAL));
                        
                        // *******
                        // WARNING
                        // *******
                        // This call will result in re-entrant calls to this method
                        // therefore anything which comes before this is NOT 
                        // guaranteed persistent. Make sure that anything which 
                        // MUST be specific to this camera / target is done 
                        // AFTER THIS POINT
                        prepareShadowTextures(camera, vp);
                        // reset the cameras & viewport because of the re-entrant call
                        mCameraInProgress = camera;
                        mCurrentViewport = vp;
                    }
                }
            }
            
            // Invert vertex winding?
            if (camera.isReflected())
            {
                mDestRenderSystem.setInvertVertexWinding(true);
            }
            else
            {
                mDestRenderSystem.setInvertVertexWinding(false);
            }
            
            // Tell params about viewport
            mAutoParamDataSource.setCurrentViewport(vp);
            // Set the viewport - this is deliberately after the shadow texture update
            setViewport(vp);
            
            // Tell params about camera
            mAutoParamDataSource.setCurrentCamera(camera, mCameraRelativeRendering);
            // Set autoparams for finite dir light extrusion
            mAutoParamDataSource.setShadowDirLightExtrusionDistance(mShadowDirLightExtrudeDist);
            
            // Tell params about current ambient light
            mAutoParamDataSource.setAmbientLightColour(mAmbientLight);
            // Tell rendersystem
            mDestRenderSystem.setAmbientLight(mAmbientLight.r, mAmbientLight.g, mAmbientLight.b);
            
            // Tell params about render target
            mAutoParamDataSource.setCurrentRenderTarget(vp.getTarget());
            
            
            // Set camera window clipping planes (if any)
            if (mDestRenderSystem.getCapabilities().hasCapability(Capabilities.RSC_USER_CLIP_PLANES))
            {
                mDestRenderSystem.resetClipPlanes();
                if (camera.isWindowSet())  
                {
                    mDestRenderSystem.setClipPlanes(camera.getWindowPlanes());
                }
            }
            
            // Prepare render queue for receiving new objects
            {
                mixin(OgreProfileGroup("prepareRenderQueue", ProfileGroupMask.OGREPROF_GENERAL));
                prepareRenderQueue();
            }
            
            if (mFindVisibleObjects)
            {
                mixin(OgreProfileGroup("_findVisibleObjects", ProfileGroupMask.OGREPROF_CULLING));
                
                // Assemble an AAB on the fly which contains the scene elements visible
                // by the camera.
                auto camVisObjIt = camera in mCamVisibleObjectsMap;
                
                assert (camVisObjIt !is null ,
                        "Should never fail to find a visible object bound for a camera, "
                        "did you override SceneManager.createCamera or something?");
                
                // reset the bounds
                camVisObjIt.reset();
                
                // Parse the scene and tag visibles
                firePreFindVisibleObjects(vp);
                _findVisibleObjects(camera, *camVisObjIt,
                                    mIlluminationStage == IlluminationRenderStage.IRS_RENDER_TO_TEXTURE? true : false);
                firePostFindVisibleObjects(vp);
                
                mAutoParamDataSource.setMainCamBoundsInfo(*camVisObjIt);
            }
            // Queue skies, if viewport seems it
            if (vp.getSkiesEnabled() && mFindVisibleObjects && mIlluminationStage != IlluminationRenderStage.IRS_RENDER_TO_TEXTURE)
            {
                _queueSkiesForRendering(camera);
            }
        } // end lock on scene graph mutex
        
        mDestRenderSystem._beginGeometryCount();
        // Clear the viewport if required
        if (mCurrentViewport.getClearEveryFrame())
        {
            mDestRenderSystem.clearFrameBuffer(
                mCurrentViewport.getClearBuffers(), 
                mCurrentViewport.getBackgroundColour(),
                mCurrentViewport.getDepthClear() );
        }        
        // Begin the frame
        mDestRenderSystem._beginFrame();
        
        // Set rasterisation mode
        mDestRenderSystem._setPolygonMode(camera.getPolygonMode());
        
        // Set initial camera state
        mDestRenderSystem._setProjectionMatrix(mCameraInProgress.getProjectionMatrixRS());
        
        mCachedViewMatrix = mCameraInProgress.getViewMatrix(true);
        
        if (mCameraRelativeRendering)
        {
            mCachedViewMatrix.setTrans(Vector3.ZERO);
            mCameraRelativePosition = mCameraInProgress.getDerivedPosition();
        }
        mDestRenderSystem._setTextureProjectionRelativeTo(mCameraRelativeRendering, camera.getDerivedPosition());
        
        
        setViewMatrix(mCachedViewMatrix);
        
        // Render scene content
        {
            mixin(OgreProfileGroup("_renderVisibleObjects", ProfileGroupMask.OGREPROF_RENDERING));
            _renderVisibleObjects();
        }
        
        // End frame
        mDestRenderSystem._endFrame();
        
        // Notify camera of vis faces
        camera._notifyRenderedFaces(mDestRenderSystem._getFaceCount());
        
        // Notify camera of vis batches
        camera._notifyRenderedBatches(mDestRenderSystem._getBatchCount());
        
        Root.getSingleton()._popCurrentSceneManager(this);
        
    }
    
    /** Internal method for queueing the sky objects with the params as 
     previously set through setSkyBox, setSkyPlane and setSkyDome.
     */
    void _queueSkiesForRendering(Camera cam)
    {
        // Update nodes
        // Translate the box by the camera position (constant distance)
        if (mSkyPlaneNode)
        {
            // The plane position relative to the camera has already been set up
            mSkyPlaneNode.setPosition(cam.getDerivedPosition());
        }
        
        if (mSkyBoxNode)
        {
            mSkyBoxNode.setPosition(cam.getDerivedPosition());
        }
        
        if (mSkyDomeNode)
        {
            mSkyDomeNode.setPosition(cam.getDerivedPosition());
        }
        
        if (mSkyPlaneEnabled
            && mSkyPlaneEntity && mSkyPlaneEntity.isVisible()
            && mSkyPlaneEntity.getSubEntity(0) && mSkyPlaneEntity.getSubEntity(0).isVisible())
        {
            getRenderQueue().addRenderable(mSkyPlaneEntity.getSubEntity(0), mSkyPlaneRenderQueue, OGRE_RENDERABLE_DEFAULT_PRIORITY);
        }
        
        if (mSkyBoxEnabled
            && mSkyBoxObj && mSkyBoxObj.isVisible())
        {
            mSkyBoxObj._updateRenderQueue(getRenderQueue());
        }
        
        if (mSkyDomeEnabled)
        {
            for (uint plane = 0; plane < 5; ++plane)
            {
                if (mSkyDomeEntity[plane] && mSkyDomeEntity[plane].isVisible()
                    && mSkyDomeEntity[plane].getSubEntity(0) && mSkyDomeEntity[plane].getSubEntity(0).isVisible())
                {
                    getRenderQueue().addRenderable(
                        mSkyDomeEntity[plane].getSubEntity(0), mSkyDomeRenderQueue, OGRE_RENDERABLE_DEFAULT_PRIORITY);
                }
            }
        }
    }
    
    
    
    /** Notifies the scene manager of its destination render system
     @remarks
     Called automatically by RenderSystem::addSceneManager
     this method simply notifies the manager of the render
     system to which its output must be directed.
     @param
     sys Pointer to the RenderSystem subclass to be used as a render target.
     */
    void _setDestinationRenderSystem(RenderSystem sys)
    {
        mDestRenderSystem = sys;
    }
    
    /** Enables / disables a 'sky plane' i.e. a plane atant
     distance from the camera representing the sky.
     @remarks
     You can create sky planes yourself using the standard mesh and
     entity methods, but this creates a plane which the camera can
     never get closer or further away from - it moves with the camera.
     (NB you could create this effect by creating a world plane which
     was attached to the same SceneNode as the Camera too, but this
     would only apply to a single camera whereas this plane applies to
     any camera using this scene manager).
     @note
     To apply scaling, scrolls etc to the sky texture(s) you
     should use the TextureUnitState class methods.
     @param
     enable True to enable the plane, false to disable it
     @param
     plane Details of the plane, i.e. it's normal and it's
     distance from the camera.
     @param
     materialName The name of the material the plane will use
     @param
     scale The scaling applied to the sky plane - higher values
     mean a bigger sky plane - you may want to tweak this
     depending on the size of plane.d and the other
     characteristics of your scene
     @param
     tiling How many times to tile the texture across the sky.
     Applies to all texture layers. If you need finer control use
     the TextureUnitState texture coordinate transformation methods.
     @param
     drawFirst If true, the plane is drawn before all other
     geometry in the scene, without updating the depth buffer.
     This is the safest rendering method since all other objects
     will always appear in front of the sky. However this is not
     the most efficient way if most of the sky is often occluded
     by other objects. If this is the case, you can set this
     parameter to false meaning it draws <em>after</em> all other
     geometry which can be an optimisation - however you must
     ensure that the plane.d value is large enough that no objects
     will 'poke through' the sky plane when it is rendered.
     @param
     bow If zero, the plane will be completely flat (like previous
     versions.  If above zero, the plane will be curved, allowing
     the sky to appear below camera level.  Curved sky planes are 
     simular to skydomes, but are more compatible with fog.
     @param xsegments, ysegments
     Determines the number of segments the plane will have to it. This
     is most important when you are bowing the plane, but may also be useful
     if you need tesselation on the plane to perform per-vertex effects.
     @param groupName
     The name of the resource group to which to assign the plane mesh.
     */
    
    void setSkyPlane(
        bool enable,
        /*const*/ Plane plane, string materialName, Real scale = 1000,
        Real tiling = 10, bool drawFirst = true, Real bow = 0, 
        int xsegments = 1, int ysegments = 1, 
        string groupName = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME)
    {
        _setSkyPlane(enable, plane, materialName, scale, tiling, 
                     (drawFirst?RenderQueueGroupID.RENDER_QUEUE_SKIES_EARLY: RenderQueueGroupID.RENDER_QUEUE_SKIES_LATE), 
                     bow, xsegments, ysegments, groupName);
    }
    /** Enables / disables a 'sky plane' i.e. a plane atant
     distance from the camera representing the sky.
     @remarks
     You can create sky planes yourself using the standard mesh and
     entity methods, but this creates a plane which the camera can
     never get closer or further away from - it moves with the camera.
     (NB you could create this effect by creating a world plane which
     was attached to the same SceneNode as the Camera too, but this
     would only apply to a single camera whereas this plane applies to
     any camera using this scene manager).
     @note
     To apply scaling, scrolls etc to the sky texture(s) you
     should use the TextureUnitState class methods.
     @param
     enable True to enable the plane, false to disable it
     @param
     plane Details of the plane, i.e. it's normal and it's
     distance from the camera.
     @param
     materialName The name of the material the plane will use
     @param
     scale The scaling applied to the sky plane - higher values
     mean a bigger sky plane - you may want to tweak this
     depending on the size of plane.d and the other
     characteristics of your scene
     @param
     tiling How many times to tile the texture across the sky.
     Applies to all texture layers. If you need finer control use
     the TextureUnitState texture coordinate transformation methods.
     @param
     renderQueue The render queue to use when rendering this object
     @param
     bow If zero, the plane will be completely flat (like previous
     versions.  If above zero, the plane will be curved, allowing
     the sky to appear below camera level.  Curved sky planes are 
     simular to skydomes, but are more compatible with fog.
     @param xsegments, ysegments
     Determines the number of segments the plane will have to it. This
     is most important when you are bowing the plane, but may also be useful
     if you need tesselation on the plane to perform per-vertex effects.
     @param groupName
     The name of the resource group to which to assign the plane mesh.
     */        
    void _setSkyPlane(
        bool enable,
        /*const*/ Plane plane, string materialName, Real scale = 1000,
        Real tiling = 10, ubyte renderQueue = RenderQueueGroupID.RENDER_QUEUE_SKIES_EARLY, Real bow = 0, 
        int xsegments = 1, int ysegments = 1, 
        string groupName = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME)
    {
        if (enable)
        {
            string meshName = mName ~ "SkyPlane";
            mSkyPlane = plane;
            
            SharedPtr!Material m = MaterialManager.getSingleton().getByName(materialName, groupName);
            if (m.isNull())
            {
                throw new InvalidParamsError(
                    "Sky plane material '" ~ materialName ~ "' not found.",
                    "SceneManager.setSkyPlane");
            }
            // Make sure the material doesn't update the depth buffer
            m.getAs().setDepthWriteEnabled(false);
            // Ensure loaded
            m.get().load();
            
            mSkyPlaneRenderQueue = renderQueue;
            
            // Set up the plane
            SharedPtr!Mesh planeMesh = MeshManager.getSingleton().getByName(meshName);
            if (!planeMesh.isNull())
            {
                // Destroy the old one
                MeshManager.getSingleton().remove(planeMesh.get().getHandle());
            }
            
            // Create up vector
            Vector3 up = plane.normal.crossProduct(Vector3.UNIT_X);
            if (up == Vector3.ZERO)
                up = plane.normal.crossProduct(-Vector3.UNIT_Z);
            
            // Create skyplane
            if( bow > 0 )
            {
                // Build a curved skyplane
                planeMesh = MeshManager.getSingleton().createCurvedPlane(
                    meshName, groupName, plane, scale * 100, scale * 100, scale * bow * 100, 
                    xsegments, ysegments, false, 1, tiling, tiling, up);
            }
            else
            {
                planeMesh = MeshManager.getSingleton().createPlane(
                    meshName, groupName, plane, scale * 100, scale * 100, xsegments, ysegments, false, 
                    1, tiling, tiling, up);
            }
            
            // Create entity 
            if (mSkyPlaneEntity)
            {
                // destroy old one, do it by name for speed
                destroyEntity(meshName);
                mSkyPlaneEntity = null;
            }
            // Create, use the same name for mesh and entity
            // manuallyruct as we don't want this to be destroyed on destroyAllMovableObjects
            MovableObjectFactory factory = 
                Root.getSingleton().getMovableObjectFactory(EntityFactory.FACTORY_TYPE_NAME);
            NameValuePairList params;
            params["mesh"] = meshName;
            mSkyPlaneEntity = cast(Entity)factory.createInstance(meshName, this, params);
            mSkyPlaneEntity.setMaterialName(materialName, groupName);
            mSkyPlaneEntity.setCastShadows(false);
            
            MovableObjectCollection* objectMap = getMovableObjectCollection(EntityFactory.FACTORY_TYPE_NAME);
            //DMD can do without 'de-pointering', ldc starts to whine though
            (*objectMap).map[meshName] = mSkyPlaneEntity;
            
            // Create node and attach
            if (!mSkyPlaneNode)
            {
                mSkyPlaneNode = createSceneNode(meshName ~ "Node");
            }
            else
            {
                mSkyPlaneNode.detachAllObjects();
            }
            mSkyPlaneNode.attachObject(cast(MovableObject)mSkyPlaneEntity);
            
        }
        mSkyPlaneEnabled = enable;
        mSkyPlaneGenParameters.skyPlaneBow = bow;
        mSkyPlaneGenParameters.skyPlaneScale = scale;
        mSkyPlaneGenParameters.skyPlaneTiling = tiling;
        mSkyPlaneGenParameters.skyPlaneXSegments = xsegments;
        mSkyPlaneGenParameters.skyPlaneYSegments = ysegments;
    }
    
    /** Enables / disables a 'sky plane' */
    void setSkyPlaneEnabled(bool enable) { mSkyPlaneEnabled = enable; }
    
    /** Return whether a key plane is enabled */
    bool isSkyPlaneEnabled(){ return mSkyPlaneEnabled; }
    
    /** Get the sky plane node, if enabled. */
    SceneNode getSkyPlaneNode(){ return mSkyPlaneNode; }
    
    /** Get the parameters used toruct the SkyPlane, if any **/
    SkyPlaneGenParameters getSkyPlaneGenParameters(){ return mSkyPlaneGenParameters; }
    
    /** Enables / disables a 'sky box' i.e. a 6-sided box atant
     distance from the camera representing the sky.
     @remarks
     You could create a sky box yourself using the standard mesh and
     entity methods, but this creates a plane which the camera can
     never get closer or further away from - it moves with the camera.
     (NB you could create this effect by creating a world box which
     was attached to the same SceneNode as the Camera too, but this
     would only apply to a single camera whereas this skybox applies
     to any camera using this scene manager).
     @par
     The material you use for the skybox can either contain layers
     which are single textures, or they can be cubic textures, i.e.
     made up of 6 images, one for each plane of the cube. See the
     TextureUnitState class for more information.
     @param
     enable True to enable the skybox, false to disable it
     @param
     materialName The name of the material the box will use
     @param
     distance Distance in world coorinates from the camera to
     each plane of the box. The default is normally OK.
     @param
     drawFirst If true, the box is drawn before all other
     geometry in the scene, without updating the depth buffer.
     This is the safest rendering method since all other objects
     will always appear in front of the sky. However this is not
     the most efficient way if most of the sky is often occluded
     by other objects. If this is the case, you can set this
     parameter to false meaning it draws <em>after</em> all other
     geometry which can be an optimisation - however you must
     ensure that the distance value is large enough that no
     objects will 'poke through' the sky box when it is rendered.
     @param
     orientation Optional parameter to specify the orientation
     of the box. By default the 'top' of the box is deemed to be
     in the +y direction, and the 'front' at the -z direction.
     You can use this parameter to rotate the sky if you want.
     @param groupName
     The name of the resource group to which to assign the plane mesh.
     */
    void setSkyBox(
        bool enable, string materialName, Real distance = 5000,
        bool drawFirst = true,Quaternion orientation = Quaternion.IDENTITY,
        string groupName = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME)
    {
        _setSkyBox(enable, materialName, distance, 
                   (drawFirst?RenderQueueGroupID.RENDER_QUEUE_SKIES_EARLY: RenderQueueGroupID.RENDER_QUEUE_SKIES_LATE), 
                   orientation, groupName);
    }
    
    /** Enables / disables a 'sky box' i.e. a 6-sided box atant
     distance from the camera representing the sky.
     @remarks
     You could create a sky box yourself using the standard mesh and
     entity methods, but this creates a plane which the camera can
     never get closer or further away from - it moves with the camera.
     (NB you could create this effect by creating a world box which
     was attached to the same SceneNode as the Camera too, but this
     would only apply to a single camera whereas this skybox applies
     to any camera using this scene manager).
     @par
     The material you use for the skybox can either contain layers
     which are single textures, or they can be cubic textures, i.e.
     made up of 6 images, one for each plane of the cube. See the
     TextureUnitState class for more information.
     @param
     enable True to enable the skybox, false to disable it
     @param
     materialName The name of the material the box will use
     @param
     distance Distance in world coorinates from the camera to
     each plane of the box. The default is normally OK.
     @param
     renderQueue The render queue to use when rendering this object
     @param
     orientation Optional parameter to specify the orientation
     of the box. By default the 'top' of the box is deemed to be
     in the +y direction, and the 'front' at the -z direction.
     You can use this parameter to rotate the sky if you want.
     @param groupName
     The name of the resource group to which to assign the plane mesh.
     */
    void _setSkyBox(
        bool enable, string materialName, Real distance = 5000,
        ubyte renderQueue = RenderQueueGroupID.RENDER_QUEUE_SKIES_EARLY, 
        Quaternion orientation = Quaternion.IDENTITY,
        string groupName = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME)
    {
        if (enable)
        {
            SharedPtr!Material m = MaterialManager.getSingleton().getByName(materialName, groupName);
            if (m.isNull())
            {
                throw new InvalidParamsError(
                    "Sky box material '" ~ materialName ~ "' not found.",
                    "SceneManager.setSkyBox");
            }
            // Ensure loaded
            m.get().load();
            if (!m.getAs().getBestTechnique() || 
                !m.getAs().getBestTechnique().getNumPasses())
            {
                LogManager.getSingleton().logMessage(
                    "Warning, skybox material " ~ materialName ~ " is not supported, defaulting.\n");
                m = MaterialManager.getSingleton().getDefaultSettings();
            }
            
            bool t3d = false;
            Pass pass = m.getAs().getBestTechnique().getPass(0);
            if (pass.getNumTextureUnitStates() > 0 && pass.getTextureUnitState(0).is3D())
                t3d = true;
            
            mSkyBoxRenderQueue = renderQueue;
            
            // Create node 
            if (!mSkyBoxNode)
            {
                mSkyBoxNode = createSceneNode("SkyBoxNode");
            }
            
            // Create object
            if (!mSkyBoxObj)
            {
                mSkyBoxObj = new ManualObject("SkyBox");
                mSkyBoxObj.setCastShadows(false);
                mSkyBoxNode.attachObject(mSkyBoxObj);
            }
            else
            {
                if (!mSkyBoxObj.isAttached())
                {
                    mSkyBoxNode.attachObject(mSkyBoxObj);
                }
                mSkyBoxObj.clear();
            }
            
            mSkyBoxObj.setRenderQueueGroup(mSkyBoxRenderQueue);
            
            if (t3d)
            {
                mSkyBoxObj.begin(materialName);
            }
            
            MaterialManager matMgr = MaterialManager.getSingleton();
            // Set up the box (6 planes)
            for (ushort i = 0; i < 6; ++i)
            {
                Plane plane;
                string meshName;
                Vector3 middle;
                Vector3 up, right;
                
                switch(i)
                {
                    case BoxPlane.BP_FRONT:
                        middle = Vector3(0, 0, -distance);
                        up = Vector3.UNIT_Y * distance;
                        right = Vector3.UNIT_X * distance;
                        break;
                    case BoxPlane.BP_BACK:
                        middle = Vector3(0, 0, distance);
                        up = Vector3.UNIT_Y * distance;
                        right = Vector3.NEGATIVE_UNIT_X * distance;
                        break;
                    case BoxPlane.BP_LEFT:
                        middle = Vector3(-distance, 0, 0);
                        up = Vector3.UNIT_Y * distance;
                        right = Vector3.NEGATIVE_UNIT_Z * distance;
                        break;
                    case BoxPlane.BP_RIGHT:
                        middle = Vector3(distance, 0, 0);
                        up = Vector3.UNIT_Y * distance;
                        right = Vector3.UNIT_Z * distance;
                        break;
                    case BoxPlane.BP_UP:
                        middle = Vector3(0, distance, 0);
                        up = Vector3.UNIT_Z * distance;
                        right = Vector3.UNIT_X * distance;
                        break;
                    case BoxPlane.BP_DOWN:
                        middle = Vector3(0, -distance, 0);
                        up = Vector3.NEGATIVE_UNIT_Z * distance;
                        right = Vector3.UNIT_X * distance;
                        break;
                    default:
                        break;
                }
                // Modify by orientation
                middle = orientation * middle;
                up = orientation * up;
                right = orientation * right;
                
                
                if (t3d)
                {
                    // 3D cubic texture 
                    // Note UVs mirrored front/back
                    // I could save a few vertices here by sharing the corners
                    // since 3D coords will function correctly but it's really not worth
                    // making the code more complicated for the sake of 16 verts
                    // top left
                    Vector3 pos;
                    pos = middle + up - right;
                    mSkyBoxObj.position(pos);
                    mSkyBoxObj.textureCoord(pos.normalisedCopy() * Vector3(1,1,-1));
                    // bottom left
                    pos = middle - up - right;
                    mSkyBoxObj.position(pos);
                    mSkyBoxObj.textureCoord(pos.normalisedCopy() * Vector3(1,1,-1));
                    // bottom right
                    pos = middle - up + right;
                    mSkyBoxObj.position(pos);
                    mSkyBoxObj.textureCoord(pos.normalisedCopy() * Vector3(1,1,-1));
                    // top right
                    pos = middle + up + right;
                    mSkyBoxObj.position(pos);
                    mSkyBoxObj.textureCoord(pos.normalisedCopy() * Vector3(1,1,-1));
                    
                    uint base = i * 4;
                    mSkyBoxObj.quad(base, base+1, base+2, base+3);
                    
                }
                else // !t3d
                {
                    // If we're using 6 separate images, have to create 6 materials, one for each frame
                    // Used to use combined material but now we're using queue we can't split to change frame
                    // This doesn't use much memory because textures aren't duplicated
                    string matName = mName ~ "SkyBoxPlane" ~ std.conv.to!string(i);
                    SharedPtr!Material boxMat = matMgr.getByName(matName, groupName);
                    if (boxMat.isNull())
                    {
                        // Create new by clone
                        boxMat = m.getAs().clone(matName);
                        boxMat.get().load();
                    }
                    else
                    {
                        // Copy over existing
                        m.getAs().copyDetailsTo(boxMat);
                        boxMat.get().load();
                    }
                    // Make sure the material doesn't update the depth buffer
                    boxMat.getAs().setDepthWriteEnabled(false);
                    // Set active frame
                    auto ti = boxMat.getAs().getSupportedTechniques();
                    foreach (tech; ti)
                    {
                        if (tech.getPass(0).getNumTextureUnitStates() > 0)
                        {
                            TextureUnitState t = tech.getPass(0).getTextureUnitState(0);
                            // Also clamp texture, don't wrap (otherwise edges can get filtered)
                            t.setTextureAddressingMode(TextureUnitState.TAM_CLAMP);
                            t.setCurrentFrame(i);
                            
                        }
                    }
                    
                    // section per material
                    mSkyBoxObj.begin(matName, RenderOperation.OperationType.OT_TRIANGLE_LIST, groupName);
                    // top left
                    mSkyBoxObj.position(middle + up - right);
                    mSkyBoxObj.textureCoord(0,0);
                    // bottom left
                    mSkyBoxObj.position(middle - up - right);
                    mSkyBoxObj.textureCoord(0,1);
                    // bottom right
                    mSkyBoxObj.position(middle - up + right);
                    mSkyBoxObj.textureCoord(1,1);
                    // top right
                    mSkyBoxObj.position(middle + up + right);
                    mSkyBoxObj.textureCoord(1,0);
                    
                    mSkyBoxObj.quad(0, 1, 2, 3);
                    
                    mSkyBoxObj.end();
                    
                }
                
            } // for each plane
            
            if (t3d)
            {
                mSkyBoxObj.end();
            }
            
            
        }
        mSkyBoxEnabled = enable;
        mSkyBoxGenParameters.skyBoxDistance = distance;
    }
    
    /** Enables / disables a 'sky box' */
    void setSkyBoxEnabled(bool enable) { mSkyBoxEnabled = enable; }
    
    /** Return whether a skybox is enabled */
    bool isSkyBoxEnabled(){ return mSkyBoxEnabled; }
    
    /** Get the skybox node, if enabled. */
    SceneNode getSkyBoxNode(){ return mSkyBoxNode; }
    
    /** Get the parameters used to generate the current SkyBox, if any */
    SkyBoxGenParameters getSkyBoxGenParameters(){ return mSkyBoxGenParameters; }
    
    /** Enables / disables a 'sky dome' i.e. an illusion of a curved sky.
     @remarks
     A sky dome is actually formed by 5 sides of a cube, but with
     texture coordinates generated such that the surface appears
     curved like a dome. Sky domes are appropriate where you need a
     realistic looking sky where the scene is not going to be
     'fogged', and there is always a 'floor' of some sort to prevent
     the viewer looking below the horizon (the distortion effect below
     the horizon can be pretty horrible, and there is never anyhting
     directly below the viewer). If you need a complete wrap-around
     background, use the setSkyBox method instead. You can actually
     combine a sky box and a sky dome if you want, to give a positional
     backdrop with an overlayed curved cloud layer.
     @par
     Sky domes work well with 2D repeating textures like clouds. You
     can change the apparent 'curvature' of the sky depending on how
     your scene is viewed - lower curvatures are better for 'open'
     scenes like landscapes, whilst higher curvatures are better for
     say FPS levels where you don't see a lot of the sky at once and
     the exaggerated curve looks good.
     @param
     enable True to enable the skydome, false to disable it
     @param
     materialName The name of the material the dome will use
     @param
     curvature The curvature of the dome. Good values are
     between 2 and 65. Higher values are more curved leading to
     a smoother effect, lower values are less curved meaning
     more distortion at the horizons but a better distance effect.
     @param
     tiling How many times to tile the texture(s) across the
     dome.
     @param
     distance Distance in world coorinates from the camera to
     each plane of the box the dome is rendered on. The default
     is normally OK.
     @param
     drawFirst If true, the dome is drawn before all other
     geometry in the scene, without updating the depth buffer.
     This is the safest rendering method since all other objects
     will always appear in front of the sky. However this is not
     the most efficient way if most of the sky is often occluded
     by other objects. If this is the case, you can set this
     parameter to false meaning it draws <em>after</em> all other
     geometry which can be an optimisation - however you must
     ensure that the distance value is large enough that no
     objects will 'poke through' the sky when it is rendered.
     @param
     orientation Optional parameter to specify the orientation
     of the dome. By default the 'top' of the dome is deemed to
     be in the +y direction, and the 'front' at the -z direction.
     You can use this parameter to rotate the sky if you want.
     @param groupName
     The name of the resource group to which to assign the plane mesh.
     */
    void setSkyDome(
        bool enable, string materialName, Real curvature = 10,
        Real tiling = 8, Real distance = 4000, bool drawFirst = true,
        Quaternion orientation = Quaternion.IDENTITY,
        int xsegments = 16, int ysegments = 16, int ySegmentsToKeep = -1,
        string groupName = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME)
    {
        _setSkyDome(enable, materialName, curvature, tiling, distance, 
                    (drawFirst?RenderQueueGroupID.RENDER_QUEUE_SKIES_EARLY: RenderQueueGroupID.RENDER_QUEUE_SKIES_LATE), 
                    orientation, xsegments, ysegments, ySegmentsToKeep, groupName);
    }
    
    /** Enables / disables a 'sky dome' i.e. an illusion of a curved sky.
     @remarks
     A sky dome is actually formed by 5 sides of a cube, but with
     texture coordinates generated such that the surface appears
     curved like a dome. Sky domes are appropriate where you need a
     realistic looking sky where the scene is not going to be
     'fogged', and there is always a 'floor' of some sort to prevent
     the viewer looking below the horizon (the distortion effect below
     the horizon can be pretty horrible, and there is never anyhting
     directly below the viewer). If you need a complete wrap-around
     background, use the setSkyBox method instead. You can actually
     combine a sky box and a sky dome if you want, to give a positional
     backdrop with an overlayed curved cloud layer.
     @par
     Sky domes work well with 2D repeating textures like clouds. You
     can change the apparent 'curvature' of the sky depending on how
     your scene is viewed - lower curvatures are better for 'open'
     scenes like landscapes, whilst higher curvatures are better for
     say FPS levels where you don't see a lot of the sky at once and
     the exaggerated curve looks good.
     @param
     enable True to enable the skydome, false to disable it
     @param
     materialName The name of the material the dome will use
     @param
     curvature The curvature of the dome. Good values are
     between 2 and 65. Higher values are more curved leading to
     a smoother effect, lower values are less curved meaning
     more distortion at the horizons but a better distance effect.
     @param
     tiling How many times to tile the texture(s) across the
     dome.
     @param
     distance Distance in world coorinates from the camera to
     each plane of the box the dome is rendered on. The default
     is normally OK.
     @param
     renderQueue The render queue to use when rendering this object
     @param
     orientation Optional parameter to specify the orientation
     of the dome. By default the 'top' of the dome is deemed to
     be in the +y direction, and the 'front' at the -z direction.
     You can use this parameter to rotate the sky if you want.
     @param groupName
     The name of the resource group to which to assign the plane mesh.
     */        
    void _setSkyDome(
        bool enable, string materialName, Real curvature = 10,
        Real tiling = 8, Real distance = 4000, ubyte renderQueue = RenderQueueGroupID.RENDER_QUEUE_SKIES_EARLY,
        Quaternion orientation = Quaternion.IDENTITY,
        int xsegments = 16, int ysegments = 16, int ySegmentsToKeep = -1,
        string groupName = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME)
    {
        if (enable)
        {
            SharedPtr!Material m = MaterialManager.getSingleton().getByName(materialName, groupName);
            if (m.isNull())
            {
                throw new InvalidParamsError(
                    "Sky dome material '" ~ materialName ~ "' not found.",
                    "SceneManager.setSkyDome");
            }
            // Make sure the material doesn't update the depth buffer
            m.getAs().setDepthWriteEnabled(false);
            // Ensure loaded
            m.get().load();
            
            //mSkyDomeDrawFirst = drawFirst;
            mSkyDomeRenderQueue = renderQueue;
            
            // Create node 
            if (!mSkyDomeNode)
            {
                mSkyDomeNode = createSceneNode("SkyDomeNode");
            }
            else
            {
                mSkyDomeNode.detachAllObjects();
            }
            
            // Set up the dome (5 planes)
            for (int i = 0; i < 5; ++i)
            {
                SharedPtr!Mesh planeMesh = createSkydomePlane(cast(BoxPlane)i, curvature, 
                                                       tiling, distance, orientation, xsegments, ysegments, 
                                                       i!=BoxPlane.BP_UP ? ySegmentsToKeep : -1, groupName);
                
                string entName = "SkyDomePlane" ~ std.conv.to!string(i);
                
                // Create entity 
                if (mSkyDomeEntity[i])
                {
                    // destroy old one, do it by name for speed
                    destroyEntity(entName);
                    mSkyDomeEntity[i] = null;
                }
                //ruct manually so we don't have problems if destroyAllMovableObjects called
                MovableObjectFactory factory = 
                    Root.getSingleton().getMovableObjectFactory(EntityFactory.FACTORY_TYPE_NAME);
                
                NameValuePairList params;
                params["mesh"] = planeMesh.get().getName();
                mSkyDomeEntity[i] = cast(Entity)factory.createInstance(entName, this, params);
                mSkyDomeEntity[i].setMaterialName(m.get().getName(), groupName);
                mSkyDomeEntity[i].setCastShadows(false);
                
                MovableObjectCollection* objectMap = getMovableObjectCollection(EntityFactory.FACTORY_TYPE_NAME);
                (*objectMap).map[entName] = mSkyDomeEntity[i];
                
                // Attach to node
                mSkyDomeNode.attachObject(mSkyDomeEntity[i]);
            } // for each plane
            
        }
        mSkyDomeEnabled = enable;
        mSkyDomeGenParameters.skyDomeCurvature = curvature;
        mSkyDomeGenParameters.skyDomeDistance = distance;
        mSkyDomeGenParameters.skyDomeTiling = tiling;
        mSkyDomeGenParameters.skyDomeXSegments = xsegments;
        mSkyDomeGenParameters.skyDomeYSegments = ysegments;
        mSkyDomeGenParameters.skyDomeYSegments_keep = ySegmentsToKeep;
    }
    
    /** Enables / disables a 'sky dome' */
    void setSkyDomeEnabled(bool enable) { mSkyDomeEnabled = enable; }
    
    /** Return whether a skydome is enabled */
    bool isSkyDomeEnabled(){ return mSkyDomeEnabled; }
    
    /** Get the sky dome node, if enabled. */
    SceneNode getSkyDomeNode(){ return mSkyDomeNode; }
    
    /** Get the parameters used to generate the current SkyDome, if any */
    SkyDomeGenParameters getSkyDomeGenParameters(){ return mSkyDomeGenParameters; }
    
    /** Sets the fogging mode applied to the scene.
     @remarks
     This method sets up the scene-wide fogging effect. These settings
     apply to all geometry rendered, UNLESS the material with which it
     is rendered has it's own fog settings (see Material::setFog).
     @param
     mode Set up the mode of fog as described in the FogMode
     enum, or set to FOG_NONE to turn off.
     @param
     colour The colour of the fog. Either set this to the same
     as your viewport background colour, or to blend in with a
     skydome or skybox.
     @param
     expDensity The density of the fog in FOG_EXP or FOG_EXP2
     mode, as a value between 0 and 1. The default is 0.001. 
     @param
     linearStart Distance in world units at which linear fog starts to
     encroach. Only applicable if mode is
     FOG_LINEAR.
     @param
     linearEnd Distance in world units at which linear fog becomes completely
     opaque. Only applicable if mode is
     FOG_LINEAR.
     */
    void setFog(
        FogMode mode = FogMode.FOG_NONE,ColourValue colour = ColourValue.White,
        Real expDensity = 0.001, Real linearStart = 0.0, Real linearEnd = 1.0)
    {
        mFogMode = mode;
        mFogColour = colour;
        mFogStart = linearStart;
        mFogEnd = linearEnd;
        mFogDensity = expDensity;
    }
    
    /** Returns the fog mode for the scene.
     */
    FogMode getFogMode()
    {
        return mFogMode;
    }
    
    /** Returns the fog colour for the scene.
     */
    ColourValue getFogColour()
    {
        return mFogColour;
    }
    
    /** Returns the fog start distance for the scene.
     */
    Real getFogStart()
    {
        return mFogStart;
    }
    
    /** Returns the fog end distance for the scene.
     */
    Real getFogEnd()
    {
        return mFogEnd;
    }
    
    /** Returns the fog density for the scene.
     */
    Real getFogDensity()
    {
        return mFogDensity;
    }
    
    
    /** Creates a new BillboardSet for use with this scene manager.
     @remarks
     This method creates a new BillboardSet which is registered with
     the SceneManager. The SceneManager will destroy this object when
     it shuts down or when the SceneManager::clearScene method is
     called, so the caller does not have to worry about destroying
     this object (in fact, it definitely should not do this).
     @par
     See the BillboardSet documentations for full details of the
     returned class.
     @param
     name The name to give to this billboard set. Must be unique.
     @param
     poolSize The initial size of the pool of billboards (see BillboardSet for more information)
     @see
     BillboardSet
     */
    BillboardSet createBillboardSet(string name, uint poolSize = 20)
    {
        NameValuePairList params;
        params["poolSize"] = std.conv.to!string(poolSize);
        return cast(BillboardSet)
            createMovableObject(name, BillboardSetFactory.FACTORY_TYPE_NAME, params);
    }
    
    /** Creates a new BillboardSet for use with this scene manager, with a generated name.
     @param
     poolSize The initial size of the pool of billboards (see BillboardSet for more information)
     @see
     BillboardSet
     */
    BillboardSet createBillboardSet(uint poolSize = 20)
    {
        string name = mMovableNameGenerator.generate();
        return createBillboardSet(name, poolSize);
    }
    /** Retrieves a pointer to the named BillboardSet.
     @note Throws an exception if the named instance does not exist
     */
    BillboardSet getBillboardSet(string name) //const
    {
        return cast(BillboardSet)
            getMovableObject(name, BillboardSetFactory.FACTORY_TYPE_NAME);
    }
    /** Returns whether a billboardset with the given name exists.
     */
    bool hasBillboardSet(string name)
    {
        return hasMovableObject(name, BillboardSetFactory.FACTORY_TYPE_NAME);
    }
    
    /** Removes & destroys an BillboardSet from the SceneManager.
     @warning
     Must only be done if the BillboardSet is not attached
     to a SceneNode. It may be safer to wait to clear the whole
     scene. If you are unsure, use clearScene.
     */
    void destroyBillboardSet(BillboardSet set)
    {
        destroyMovableObject(set);
    }
    
    /** Removes & destroys an BillboardSet from the SceneManager by name.
     @warning
     Must only be done if the BillboardSet is not attached
     to a SceneNode. It may be safer to wait to clear the whole
     scene. If you are unsure, use clearScene.
     */
    void destroyBillboardSet(string name)
    {
        destroyMovableObject(name, BillboardSetFactory.FACTORY_TYPE_NAME);
    }
    
    /** Removes & destroys all BillboardSets.
     @warning
     Again, use caution since no BillboardSet must be referred to
     elsewhere e.g. attached to a SceneNode otherwise a crash
     is likely. Use clearScene if you are unsure (it clears SceneNode
     entries too.)
     @see
     SceneManager::clearScene
     */
    void destroyAllBillboardSets()
    {
        destroyAllMovableObjectsByType(BillboardSetFactory.FACTORY_TYPE_NAME);
    }
    
    /** Tells the SceneManager whether it should render the SceneNodes which 
     make up the scene as well as the objects in the scene.
     @remarks
     This method is mainly for debugging purposes. If you set this to 'true',
     each node will be rendered as a set of 3 axes to allow you to easily see
     the orientation of the nodes.
     */
    void setDisplaySceneNodes(bool display)
    {
        mDisplayNodes = display;
    }
    
    /** Returns true if all scene nodes axis are to be displayed */
    bool getDisplaySceneNodes(){return mDisplayNodes;}
    
    /** Creates an animation which can be used to animate scene nodes.
     @remarks
     An animation is a collection of 'tracks' which over time change the position / orientation
     of Node objects. In this case, the animation will likely have tracks to modify the position
     / orientation of SceneNode objects, e.g. to make objects move along a path.
     @par
     You don't need to use an Animation object to move objects around - you can do it yourself
     using the methods of the Node in your FrameListener class. However, when you need relatively
     complex scripted animation, this is the class to use since it will interpolate between
     keyframes for you and generally make the whole process easier to manage.
     @par
     A single animation can affect multiple Node objects (each AnimationTrack affects a single Node).
     In addition, through animation blending a single Node can be affected by multiple animations,
     athough this is more useful when performing skeletal animation (see Skeleton::createAnimation).
     @par
     Note that whilst it uses the same classes, the animations created here are kept separate from the
     skeletal animations of meshes (each Skeleton owns those animations).
     @param name The name of the animation, must be unique within this SceneManager.
     @param length The total length of the animation.
     */
    Animation createAnimation(string name, Real length)
    {
        //OGRE_LOCK_MUTEX(mAnimationsListMutex)
        synchronized(mAnimationsListMutex)
        {
            // Check name not used
            if ((name in mAnimationsList) !is null)
            {
                throw new DuplicateItemError(
                    "An animation with the name " ~ name ~ " already exists",
                    "SceneManager::createAnimation" );
            }
            
            Animation pAnim = new Animation(name, length);
            mAnimationsList[name] = pAnim;
            return pAnim;
        }
    }
    
    /** Looks up an Animation object previously created with createAnimation. 
     @note Throws an exception if the named instance does not exist
     */
    Animation getAnimation(string name)
    {
        //OGRE_LOCK_MUTEX(mAnimationsListMutex)
        synchronized(mAnimationsListMutex)
        {
            auto i = name in mAnimationsList;
            if (i is null)
            {
                throw new ItemNotFoundError(
                    "Cannot find animation with name " ~ name, 
                    "SceneManager.getAnimation");
            }
            return *i;
        }
    }

    /** Returns whether an animation with the given name exists.
     */
    bool hasAnimation(string name)
    {
        //OGRE_LOCK_MUTEX(mAnimationsListMutex)
        synchronized(mAnimationsListMutex)
            return (name in mAnimationsList) !is null;
    }
    
    /** Destroys an Animation. 
     @remarks
     You should ensure that none of your code is referencing this animation objects since the 
     memory will be freed.
     */
    void destroyAnimation(string name)
    {
        //OGRE_LOCK_MUTEX(mAnimationsListMutex)
        synchronized(mAnimationsListMutex)
        {
            // Also destroy any animation states referencing this animation
            mAnimationStates.removeAnimationState(name);
            
            auto i = name in mAnimationsList;
            if (i is null)
            {
                throw new ItemNotFoundError(
                    "Cannot find animation with name " ~ name, 
                    "SceneManager.getAnimation");
            }
            
            // Free memory
            destroy(*i);
            
            mAnimationsList.remove(name);
        }
    }
    
    /** Removes all animations created using this SceneManager. */
    void destroyAllAnimations()
    {
        //OGRE_LOCK_MUTEX(mAnimationsListMutex)
        synchronized(mAnimationsListMutex)
        {
            // Destroy all states too, since they cannot reference destroyed animations
            destroyAllAnimationStates();
            
            foreach (k,v; mAnimationsList)
            {
                // destroy
                destroy(v);
            }
            mAnimationsList.clear();
        }
    }
    
    /** Create an AnimationState object for managing application of animations.
     @remarks
     You can create Animation objects for animating SceneNode obejcts using the
     createAnimation method. However, in order to actually apply those animations
     you have to call methods on Node and Animation in a particular order (namely
     Node::resetToInitialState and Animation::apply). To make this easier and to
     help track the current time position of animations, the AnimationState object
     is provided. </p>
     So if you don't want to control animation application manually, call this method,
     update the returned object as you like every frame and let SceneManager apply 
     the animation state for you.
     @par
     Remember, AnimationState objects are disabled by default at creation time. 
     Turn them on when you want them using their setEnabled method.
     @par
     Note that any SceneNode affected by this automatic animation will have it's state
     reset to it's initial position before application of the animation. Unless specifically
     modified using Node::setInitialState the Node assumes it's initial state is at the
     origin. If you want the base state of the SceneNode to be elsewhere, make your changes
     to the node using the standard transform methods, then call setInitialState to 
     'bake' this reference position into the node.
     @par
     If the target of your animation is to be a generic AnimableValue, you
     should ensure that it has a base value set (unlike nodes this has no
     default). @see AnimableValue::setAsBaseValue.
     @param animName The name of an animation created already with createAnimation.
     */
    AnimationState createAnimationState(string animName)
    {
        // Get animation, this will throw an exception if not found
        Animation anim = getAnimation(animName);
        
        // Create new state
        return mAnimationStates.createAnimationState(animName, 0, anim.getLength());
    }
    
    /** Retrieves animation state as previously created using createAnimationState. 
     @note Throws an exception if the named instance does not exist
     */
    AnimationState getAnimationState(string animName)
    {
        return mAnimationStates.getAnimationState(animName);
    }
    /** Returns whether an animation state with the given name exists.
     */
    bool hasAnimationState(string name)
    {
        return mAnimationStates.hasAnimationState(name);
    }
    
    /** Destroys an AnimationState. 
     @remarks
     You should ensure that none of your code is referencing this animation 
     state object since the memory will be freed.
     */
    void destroyAnimationState(string name)
    {
        mAnimationStates.removeAnimationState(name);
    }
    
    /** Removes all animation states created using this SceneManager. */
    void destroyAllAnimationStates()
    {
        mAnimationStates.removeAllAnimationStates();
    }
    
    /** Manual rendering method, for advanced users only.
     @remarks
     This method allows you to send rendering commands through the pipeline on
     demand, bypassing OGRE's normal world processing. You should only use this if you
     really know what you're doing; OGRE does lots of things for you that you really should
     let it do. However, there are times where it may be useful to have this manual interface,
     for example overlaying something on top of the scene rendered by OGRE.
     @par
     Because this is an instant rendering method, timing is important. The best 
     time to call it is from a RenderTargetListener event handler.
     @par
     Don't call this method a lot, it's designed for rare (1 or 2 times per frame) use. 
     Calling it regularly per frame will cause frame rate drops!
     @param rend A RenderOperation object describing the rendering op
     @param pass The Pass to use for this render
     @param vp Pointer to the viewport to render to, or 0 to use the current viewport
     @param worldMatrix The transform to apply from object to world space
     @param viewMatrix The transform to apply from world to view space
     @param projMatrix The transform to apply from view to screen space
     @param doBeginEndFrame If true, beginFrame() and endFrame() are called, 
     otherwise not. You should leave this as false if you are calling
     this within the main render loop.
     */
    void manualRender(RenderOperation rend, Pass pass, Viewport vp, 
                      Matrix4 worldMatrix, Matrix4 viewMatrix, Matrix4 projMatrix, 
                      bool doBeginEndFrame = false)
    {
        if (vp)
            mDestRenderSystem._setViewport(vp);
        
        if (doBeginEndFrame)
            mDestRenderSystem._beginFrame();
        
        mDestRenderSystem._setWorldMatrix(worldMatrix);
        setViewMatrix(viewMatrix);
        mDestRenderSystem._setProjectionMatrix(projMatrix);
        
        _setPass(pass);
        // Do we need to update GPU program parameters?
        if (pass.isProgrammable())
        {
            if (vp)
            {
                mAutoParamDataSource.setCurrentViewport(vp);
                mAutoParamDataSource.setCurrentRenderTarget(vp.getTarget());
            }
            mAutoParamDataSource.setCurrentSceneManager(this);
            mAutoParamDataSource.setWorldMatrices([worldMatrix], 1);
            auto dummyCam = new Camera(null, null);
            dummyCam.setCustomViewMatrix(true, viewMatrix);
            dummyCam.setCustomProjectionMatrix(true, projMatrix);
            mAutoParamDataSource.setCurrentCamera(dummyCam, false);
            updateGpuProgramParameters(pass);
        }
        mDestRenderSystem._render(rend);
        
        if (doBeginEndFrame)
            mDestRenderSystem._endFrame();
        
    }
    
    /** Manual rendering method for rendering a single object. 
     @remarks
     @param rend The renderable to issue to the pipeline
     @param pass The pass to use
     @param vp Pointer to the viewport to render to, or 0 to use the existing viewport
     @param doBeginEndFrame If true, beginFrame() and endFrame() are called, 
     otherwise not. You should leave this as false if you are calling
     this within the main render loop.
     @param viewMatrix The transform to apply from world to view space
     @param projMatrix The transform to apply from view to screen space
     @param lightScissoringClipping If true, passes that have the getLightScissorEnabled
     and/or getLightClipPlanesEnabled flags will cause calculation and setting of 
     scissor rectangle and user clip planes. 
     @param doLightIteration If true, this method will issue the renderable to
     the pipeline possibly multiple times, if the pass indicates it should be
     done once per light
     @param manualLightList Only applicable if doLightIteration is false, this
     method allows you to pass in a previously determined set of lights
     which will be used for a single render of this object.
     */
    void manualRender(Renderable rend, /*const*/ Pass pass, Viewport vp, 
                      Matrix4 viewMatrix, Matrix4 projMatrix, bool doBeginEndFrame = false, bool lightScissoringClipping = true, 
                      bool doLightIteration = true,LightList manualLightList = LightList.init)
    {
        if (vp)
            mDestRenderSystem._setViewport(vp);
        
        if (doBeginEndFrame)
            mDestRenderSystem._beginFrame();
        
        setViewMatrix(viewMatrix);
        mDestRenderSystem._setProjectionMatrix(projMatrix);
        
        _setPass(pass);
        auto dummyCam = new Camera(null, null);
        dummyCam.setCustomViewMatrix(true, viewMatrix);
        dummyCam.setCustomProjectionMatrix(true, projMatrix);
        // Do we need to update GPU program parameters?
        if (pass.isProgrammable())
        {
            if (vp)
            {
                mAutoParamDataSource.setCurrentViewport(vp);
                mAutoParamDataSource.setCurrentRenderTarget(vp.getTarget());
            }
            mAutoParamDataSource.setCurrentSceneManager(this);
            mAutoParamDataSource.setCurrentCamera(dummyCam, false);
            updateGpuProgramParameters(pass);
        }
        if (vp)
            mCurrentViewport = vp;
        renderSingleObject(rend, pass, lightScissoringClipping, doLightIteration, manualLightList);
        
        
        if (doBeginEndFrame)
            mDestRenderSystem._endFrame();
        
    }
    
    /** Retrieves the internal render queue, for advanced users only.
     @remarks
     The render queue is mainly used internally to manage the scene object 
     rendering queue, it also exports some methods to allow advanced users 
     to configure the behavior of rendering process.
     Most methods provided by RenderQueue are supposed to be used 
     internally only, you should reference to the RenderQueue API for 
     more information. Do not access this directly unless you know what 
     you are doing.
     */
    RenderQueue getRenderQueue()
    {
        if (!mRenderQueue)
        {
            initRenderQueue();
        }
        return mRenderQueue;
    }
    
    /** Registers a new RenderQueueListener which will be notified when render queues
     are processed.
     */
    void addRenderQueueListener(RenderQueueListener newListener)
    {
        mRenderQueueListeners.insert(newListener);
    }
    
    /** Removes a listener previously added with addRenderQueueListener. */
    void removeRenderQueueListener(RenderQueueListener delListener)
    {
        mRenderQueueListeners.removeFromArray(delListener);
    }
    
    /** Registers a new Render Object Listener which will be notified when rendering an object.     
     */
    void addRenderObjectListener(RenderObjectListener newListener)
    {
        mRenderObjectListeners.insert(newListener);
    }
    
    /** Removes a listener previously added with addRenderObjectListener. */
    void removeRenderObjectListener(RenderObjectListener delListener)
    {
        mRenderObjectListeners.removeFromArray(delListener);
    }
    
    /** Adds an item to the 'special case' render queue list.
     @remarks
     Normally all render queues are rendered, in their usual sequence, 
     only varying if a RenderQueueListener nominates for the queue to be 
     repeated or skipped. This method allows you to add a render queue to 
     a 'special case' list, which varies the behaviour. The effect of this
     list depends on the 'mode' in which this list is in, which might be
     to exclude these render queues, or to include them alone (excluding
     all other queues). This allows you to perform broad selective
     rendering without requiring a RenderQueueListener.
     @param qid The identifier of the queue which should be added to the
     special case list. Nothing happens if the queue is already in the list.
     */
    void addSpecialCaseRenderQueue(ubyte qid)
    {
        mSpecialCaseQueueList.insert(qid);
    }
    /** Removes an item to the 'special case' render queue list.
     @see SceneManager::addSpecialCaseRenderQueue
     @param qid The identifier of the queue which should be removed from the
     special case list. Nothing happens if the queue is not in the list.
     */
    void removeSpecialCaseRenderQueue(ubyte qid)
    {
        mSpecialCaseQueueList.removeFromArray(qid);
    }
    /** Clears the 'special case' render queue list.
     @see SceneManager::addSpecialCaseRenderQueue
     */
    void clearSpecialCaseRenderQueues()
    {
        mSpecialCaseQueueList.clear();
    }
    /** Sets the way the special case render queue list is processed.
     @see SceneManager::addSpecialCaseRenderQueue
     @param mode The mode of processing
     */
    void setSpecialCaseRenderQueueMode(SpecialCaseRenderQueueMode mode)
    {
        mSpecialCaseQueueMode = mode;
    }
    /** Gets the way the special case render queue list is processed. */
    SpecialCaseRenderQueueMode getSpecialCaseRenderQueueMode()
    {
        return mSpecialCaseQueueMode;
    }
    /** Returns whether or not the named queue will be rendered based on the
     current 'special case' render queue list and mode.
     @see SceneManager::addSpecialCaseRenderQueue
     @param qid The identifier of the queue which should be tested
     @return true if the queue will be rendered, false otherwise
     */
    bool isRenderQueueToBeProcessed(ubyte qid)
    {
        bool inList = !mSpecialCaseQueueList[].find(qid).empty();
        return (inList && mSpecialCaseQueueMode == SpecialCaseRenderQueueMode.SCRQM_INCLUDE)
            || (!inList && mSpecialCaseQueueMode == SpecialCaseRenderQueueMode.SCRQM_EXCLUDE);
    }
    
    /** Sets the render queue that the world geometry (if any) this SceneManager
     renders will be associated with.
     @remarks
     SceneManagers which provide 'world geometry' should place it in a 
     specialised render queue in order to make it possible to enable / 
     disable it easily using the addSpecialCaseRenderQueue method. Even 
     if the SceneManager does not use the render queues to render the 
     world geometry, it should still pick a queue to represent it's manual
     rendering, and check isRenderQueueToBeProcessed before rendering.
     @note
     Setting this may not affect the actual ordering of rendering the
     world geometry, if the world geometry is being rendered manually
     by the SceneManager. If the SceneManager feeds world geometry into
     the queues, however, the ordering will be affected. 
     */
    void setWorldGeometryRenderQueue(ubyte qid)
    {
        mWorldGeometryRenderQueue = qid;
    }
    /** Gets the render queue that the world geometry (if any) this SceneManager
     renders will be associated with.
     @remarks
     SceneManagers which provide 'world geometry' should place it in a 
     specialised render queue in order to make it possible to enable / 
     disable it easily using the addSpecialCaseRenderQueue method. Even 
     if the SceneManager does not use the render queues to render the 
     world geometry, it should still pick a queue to represent it's manual
     rendering, and check isRenderQueueToBeProcessed before rendering.
     */
    ubyte getWorldGeometryRenderQueue()
    {
        return mWorldGeometryRenderQueue;
    }
    
    /** Allows all bounding boxes of scene nodes to be displayed. */
    void showBoundingBoxes(bool bShow)
    {
        mShowBoundingBoxes = bShow;
    }
    
    /** Returns if all bounding boxes of scene nodes are to be displayed */
    bool getShowBoundingBoxes()
    {
        return mShowBoundingBoxes;
    }
    
    /** Internal method for notifying the manager that a SceneNode is autotracking. */
    void _notifyAutotrackingSceneNode(SceneNode node, bool autoTrack)
    {
        if (autoTrack)
        {
            mAutoTrackingSceneNodes.insert(node);
        }
        else if(mAutoTrackingSceneNodes.length)
        {
            mAutoTrackingSceneNodes.removeFromArray(node);
        }
    }
    
    
    /** Creates an AxisAlignedBoxSceneQuery for this scene manager. 
     @remarks
     This method creates a new instance of a query object for this scene manager, 
     for an axis aligned box region. See SceneQuery and AxisAlignedBoxSceneQuery 
     for full details.
     @par
     The instance returned from this method must be destroyed by calling
     SceneManager::destroyQuery when it is no longer required.
     @param box Details of the box which describes the region for this query.
     @param mask The query mask to apply to this query; can be used to filter out
     certain objects; see SceneQuery for details.
     */
    AxisAlignedBoxSceneQuery
        createAABBQuery(AxisAlignedBox box, uint mask = 0xFFFFFFFF)
    {
        DefaultAxisAlignedBoxSceneQuery q = new DefaultAxisAlignedBoxSceneQuery(this);
        q.setBox(box);
        q.setQueryMask(mask);
        return q;
    }
    /** Creates a SphereSceneQuery for this scene manager. 
     @remarks
     This method creates a new instance of a query object for this scene manager, 
     for a spherical region. See SceneQuery and SphereSceneQuery 
     for full details.
     @par
     The instance returned from this method must be destroyed by calling
     SceneManager::destroyQuery when it is no longer required.
     @param sphere Details of the sphere which describes the region for this query.
     @param mask The query mask to apply to this query; can be used to filter out
     certain objects; see SceneQuery for details.
     */
    SphereSceneQuery 
        createSphereQuery(Sphere sphere, uint mask = 0xFFFFFFFF)
    {
        DefaultSphereSceneQuery q = new DefaultSphereSceneQuery(this);
        q.setSphere(sphere);
        q.setQueryMask(mask);
        return q;
    }
    /** Creates a PlaneBoundedVolumeListSceneQuery for this scene manager. 
     @remarks
     This method creates a new instance of a query object for this scene manager, 
     for a region enclosed by a set of planes (normals pointing inwards). 
     See SceneQuery and PlaneBoundedVolumeListSceneQuery for full details.
     @par
     The instance returned from this method must be destroyed by calling
     SceneManager::destroyQuery when it is no longer required.
     @param volumes Details of the volumes which describe the region for this query.
     @param mask The query mask to apply to this query; can be used to filter out
     certain objects; see SceneQuery for details.
     */
    PlaneBoundedVolumeListSceneQuery
        createPlaneBoundedVolumeQuery(PlaneBoundedVolumeList volumes, uint mask = 0xFFFFFFFF)
    {
        DefaultPlaneBoundedVolumeListSceneQuery q = new DefaultPlaneBoundedVolumeListSceneQuery(this);
        q.setVolumes(volumes);
        q.setQueryMask(mask);
        return q;
    }
    
    
    /** Creates a RaySceneQuery for this scene manager. 
     @remarks
     This method creates a new instance of a query object for this scene manager, 
     looking for objects which fall along a ray. See SceneQuery and RaySceneQuery 
     for full details.
     @par
     The instance returned from this method must be destroyed by calling
     SceneManager::destroyQuery when it is no longer required.
     @param ray Details of the ray which describes the region for this query.
     @param mask The query mask to apply to this query; can be used to filter out
     certain objects; see SceneQuery for details.
     */
    RaySceneQuery
        createRayQuery(Ray ray, uint mask = 0xFFFFFFFF)
    {
        DefaultRaySceneQuery q = new DefaultRaySceneQuery(this);
        q.setRay(ray);
        q.setQueryMask(mask);
        return q;
    }
    
    //PyramidSceneQuery* createPyramidQuery(Pyramid& p, uint mask = 0xFFFFFFFF);
    /** Creates an IntersectionSceneQuery for this scene manager. 
     @remarks
     This method creates a new instance of a query object for locating
     intersecting objects. See SceneQuery and IntersectionSceneQuery
     for full details.
     @par
     The instance returned from this method must be destroyed by calling
     SceneManager::destroyQuery when it is no longer required.
     @param mask The query mask to apply to this query; can be used to filter out
     certain objects; see SceneQuery for details.
     */
    IntersectionSceneQuery
        createIntersectionQuery(uint mask = 0xFFFFFFFF)
    {
        
        DefaultIntersectionSceneQuery q = new DefaultIntersectionSceneQuery(this);
        q.setQueryMask(mask);
        return q;
    }
    
    /** Destroys a scene query of any type. */
    void destroyQuery(SceneQuery query)
    {
        destroy(query);
    }
    
    //typedef MapIterator<CameraList> CameraIterator;
    //typedef MapIterator<AnimationList> AnimationIterator;
    
    /** Returns a specialised MapIterator over all cameras in the scene. 
     */
    /*CameraIterator getCameraIterator() {
     return CameraIterator(mCameras.begin(), mCameras.end());
     }*/
    /** Returns aversion of the camera list. 
     */
    CameraList getCameras(){ return mCameras; }
    /** Returns a specialised MapIterator over all animations in the scene. */
    /*AnimationIterator getAnimationIterator() {
     return AnimationIterator(mAnimationsList.begin(), mAnimationsList.end());
     }*/
    /** Returns aversion of the animation list. 
     */
    AnimationList  getAnimations(){ return mAnimationsList; }
    /** Returns a specialised MapIterator over all animation states in the scene. */
    /*AnimationStateIterator getAnimationStateIterator() {
     return mAnimationStates.getAnimationStateIterator();
     }*/
    
    /** Sets the general shadow technique to be used in this scene.
     @remarks   
     There are multiple ways to generate shadows in a scene, and each has 
     strengths and weaknesses. 
     <ul><li>Stencil-based approaches can be used to 
     draw very long, extreme shadows without loss of precision and the 'additive'
     version can correctly show the shadowing of complex effects like bump mapping
     because they physically exclude the light from those areas. However, the edges
     are very sharp and stencils cannot handle transparency, and they involve a 
     fair amount of CPU work in order to calculate the shadow volumes, especially
     when animated objects are involved.</li>
     <li>Texture-based approaches are good for handling transparency (they can, for
     example, correctly shadow a mesh which uses alpha to represent holes), and they
     require little CPU overhead, and can happily shadow geometry which is deformed
     by a vertex program, unlike stencil shadows. However, they have a fixed precision 
     which can introduce 'jaggies' at long range and have fillrate issues of their own.</li>
     </ul>
     @par
     We support 2 kinds of stencil shadows, and 2 kinds of texture-based shadows, and one
     simple decal approach. The 2 stencil approaches differ in the amount of multipass work 
     that is required - the modulative approach simply 'darkens' areas in shadow after the 
     main render, which is the least expensive, whilst the additive approach has to perform 
     a render per light and adds the cumulative effect, which is more expensive but more 
     accurate. The texture based shadows both work in roughly the same way, the only difference is
     that the shadowmap approach is slightly more accurate, but requires a more recent
     graphics card.
     @par
     Note that because mixing many shadow techniques can cause problems, only one technique
     is supported at once. Also, you should call this method at the start of the 
     scene setup. 
     @param technique The shadowing technique to use for the scene.
     */
    void setShadowTechnique(ShadowTechnique technique)
    {
        mShadowTechnique = technique;
        if (isShadowTechniqueStencilBased())
        {
            // Firstly check that we  have a stencil
            // Otherwise forget it
            if (!mDestRenderSystem.getCapabilities().hasCapability(Capabilities.RSC_HWSTENCIL))
            {
                LogManager.getSingleton().logMessage(
                    "WARNING: Stencil shadows were requested, but this device does not " ~
                    "have a hardware stencil. Shadows disabled.\n");
                mShadowTechnique = ShadowTechnique.SHADOWTYPE_NONE;
            }
            else if (mShadowIndexBuffer.isNull())
            {
                // Create an estimated sized shadow index buffer
                mShadowIndexBuffer = HardwareBufferManager.getSingleton().
                    createIndexBuffer(HardwareIndexBuffer.IndexType.IT_16BIT, 
                                      mShadowIndexBufferSize, 
                                      HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY_DISCARDABLE, 
                                      false);
                // tell all meshes to prepare shadow volumes
                MeshManager.getSingleton().setPrepareAllMeshesForShadowVolumes(true);
            }
        }
        
        if (!isShadowTechniqueTextureBased())
        {
            // Destroy shadow textures to optimise resource usage
            destroyShadowTextures();
        }
        else
        {
            // assure no custom shadow matrix is used accidentally in case we switch
            // from a custom shadow mapping type to a non-custom (uniform shadow mapping)
            for ( size_t i = 0; i < mShadowTextureCameras.length; ++i )
            {
                Camera texCam = mShadowTextureCameras[i];
                
                texCam.setCustomViewMatrix(false);
                texCam.setCustomProjectionMatrix(false);
            }
        }
        
    }
    
    /** Gets the current shadow technique. */
    ShadowTechnique getShadowTechnique(){ return mShadowTechnique; }
    
    /** Enables / disables the rendering of debug information for shadows. */
    void setShowDebugShadows(bool _debug) { mDebugShadows = _debug; }
    /** Are debug shadows shown? */
    bool getShowDebugShadows(){ return mDebugShadows; }
    
    /** Set the colour used to modulate areas in shadow. 
     @remarks This is only applicable for shadow techniques which involve 
     darkening the area in shadow, as opposed to masking out the light. 
     This colour provided is used as a modulative value to darken the
     areas.
     */
    void setShadowColour(ColourValue colour)
    {
        mShadowColour = colour;
        
        // Change shadow material setting only when it's prepared,
        // otherwise, it'll set up while preparing shadow materials.
        if (mShadowModulativePass)
        {
            mShadowModulativePass.getTextureUnitState(0).setColourOperationEx(
                LayerBlendOperationEx.LBX_MODULATE, LayerBlendSource.LBS_MANUAL, 
                LayerBlendSource.LBS_CURRENT, colour);
        }
    }
    
    /** Get the colour used to modulate areas in shadow. 
     @remarks This is only applicable for shadow techniques which involve 
     darkening the area in shadow, as opposed to masking out the light. 
     This colour provided is used as a modulative value to darken the
     areas.
     */
    ColourValue getShadowColour()
    {
        return mShadowColour;
    }
    /** Sets the distance a shadow volume is extruded for a directional light.
     @remarks
     Although directional lights are essentially infinite, there are many
     reasons to limit the shadow extrusion distance to a finite number, 
     not least of which is compatibility with older cards (which do not
     support infinite positions), and shadow caster elimination.
     @par
     The default value is 10,000 world units. This does not apply to
     point lights or spotlights, since they extrude up to their 
     attenuation range.
     */
    void setShadowDirectionalLightExtrusionDistance(Real dist)
    {
        mShadowDirLightExtrudeDist = dist;
    }
    /** Gets the distance a shadow volume is extruded for a directional light.
     */
    Real getShadowDirectionalLightExtrusionDistance()
    {
        return mShadowDirLightExtrudeDist;
    }
    /** Sets the default maximum distance away from the camera that shadows
     will be visible. You have to call this function before you create lights
     or the default distance of zero will be used.
     @remarks
     Shadow techniques can be expensive, therefore it is a good idea
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
        mDefaultShadowFarDist = distance;
        mDefaultShadowFarDistSquared = distance * distance;
    }
    /** Gets the default maximum distance away from the camera that shadows
     will be visible.
     */
    Real getShadowFarDistance()
    { return mDefaultShadowFarDist; }
    Real getShadowFarDistanceSquared()
    { return mDefaultShadowFarDistSquared; }
    
    /** Sets the maximum size of the index buffer used to render shadow
     primitives.
     @remarks
     This method allows you to tweak the size of the index buffer used
     to render shadow primitives (including stencil shadow volumes). The
     default size is 51,200 entries, which is 100k of GPU memory, or
     enough to render approximately 17,000 triangles. You can reduce this
     as long as you do not have any models / world geometry chunks which 
     could require more than the amount you set.
     @par
     The maximum number of triangles required to render a single shadow 
     volume (including light and dark caps when needed) will be 3x the 
     number of edges on the light silhouette, plus the number of 
     light-facing triangles. On average, half the 
     triangles will be facing toward the light, but the number of 
     triangles in the silhouette entirely depends on the mesh - 
     angular meshes will have a higher silhouette tris/mesh tris
     ratio than a smooth mesh. You can estimate the requirements for
     your particular mesh by rendering it alone in a scene with shadows
     enabled and a single light - rotate it or the light and make a note
     of how high the triangle count goes (remembering to subtract the 
     mesh triangle count)
     @param size The number of indexes; divide this by 3 to determine the
     number of triangles.
     */
    void setShadowIndexBufferSize(size_t size)
    {
        if (!mShadowIndexBuffer.isNull() && size != mShadowIndexBufferSize)
        {
            // re-create shadow buffer with new size
            mShadowIndexBuffer = HardwareBufferManager.getSingleton().
                createIndexBuffer(HardwareIndexBuffer.IndexType.IT_16BIT, 
                                  size, 
                                  HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY_DISCARDABLE, 
                                  false);
        }
        mShadowIndexBufferSize = size;
    }
    
    /// Get the size of the shadow index buffer
    size_t getShadowIndexBufferSize()
    { return mShadowIndexBufferSize; }
    /** Set the size of the texture used for all texture-based shadows.
     @remarks
     The larger the shadow texture, the better the detail on 
     texture based shadows, but obviously this takes more memory.
     The default size is 512. Sizes must be a power of 2.
     @note This is the simple form, see setShadowTextureConfig for the more 
     complex form.
     */
    void setShadowTextureSize(ushort size)
    {
        // default all current
        foreach (i; mShadowTextureConfigList)
        {
            if (i.width != size || i.height != size)
            {
                i.width = i.height = size;
                mShadowTextureConfigDirty = true;
            }
        }
        
    }
    
    /** Set the detailed configuration for a shadow texture.
     @param shadowIndex The index of the texture to configure, must be < the
     number of shadow textures setting
     @param width, height The dimensions of the texture
     @param format The pixel format of the texture
     @param fsaa The level of multisampling to use. Ignored if the device does not support it.
     @param depthBufferPoolId The pool # it should query the depth buffers from
     */
    void setShadowTextureConfig(size_t shadowIndex, ushort width, 
                                ushort height, PixelFormat format, ushort fsaa = 0, ushort depthBufferPoolId=1)
    {
        ShadowTextureConfig conf;
        conf.width = width;
        conf.height = height;
        conf.format = format;
        conf.fsaa = fsaa;
        conf.depthBufferPoolId = depthBufferPoolId;
        
        setShadowTextureConfig(shadowIndex, conf);
    }
    /** Set the detailed configuration for a shadow texture.
     @param shadowIndex The index of the texture to configure, must be < the
     number of shadow textures setting
     @param config Configuration structure
     */
    void setShadowTextureConfig(size_t shadowIndex, 
                                ShadowTextureConfig config)
    {
        if (shadowIndex >= mShadowTextureConfigList.length)
        {
            throw new ItemNotFoundError(
                "shadowIndex out of bounds",
                "SceneManager.setShadowTextureConfig");
        }
        mShadowTextureConfigList[shadowIndex] = config;
        
        mShadowTextureConfigDirty = true;
    }
    
    /** Get an iterator over the current shadow texture settings. */
    /*ConstShadowTextureConfigIterator getShadowTextureConfigIterator()
     {
     return ConstShadowTextureConfigIterator(
     mShadowTextureConfigList.begin(), mShadowTextureConfigList.end());
     
     }*/
    
    ShadowTextureConfigList getShadowTextureConfig()
    {
        return mShadowTextureConfigList;
    }
    
    /** Set the pixel format of the textures used for texture-based shadows.
     @remarks
     By default, a colour texture is used (PF_X8R8G8B8) for texture shadows,
     but if you want to use more advanced texture shadow types you can 
     alter this. If you do, you will have to also call
     setShadowTextureCasterMaterial and setShadowTextureReceiverMaterial
     to provide shader-based materials to use these customised shadow
     texture formats.
     @note This is the simple form, see setShadowTextureConfig for the more 
     complex form.
     */
    void setShadowTexturePixelFormat(PixelFormat fmt)
    {
        foreach (i; mShadowTextureConfigList)
        {
            if (i.format != fmt)
            {
                i.format = fmt;
                mShadowTextureConfigDirty = true;
            }
        }
    }
    /** Set the level of multisample AA of the textures used for texture-based shadows.
     @remarks
     By default, the level of multisample AA is zero.
     @note This is the simple form, see setShadowTextureConfig for the more 
     complex form.
     */
    void setShadowTextureFSAA(ushort fsaa)
    {
        foreach (i; mShadowTextureConfigList)
        {
            if (i.fsaa != fsaa)
            {
                i.fsaa = fsaa;
                mShadowTextureConfigDirty = true;
            }
        }
    }
    
    /** Set the number of textures allocated for texture-based shadows.
     @remarks
     The default number of textures assigned to deal with texture based
     shadows is 1; however this means you can only have one light casting
     shadows at the same time. You can increase this number in order to 
     make this more flexible, but be aware of the texture memory it will use.
     */
    void setShadowTextureCount(size_t count)
    {
        // Change size, any new items will need defaults
        if (count != mShadowTextureConfigList.length)
        {
            // if no entries yet, use the defaults
            if (mShadowTextureConfigList.empty() || mShadowTextureConfigList.length > count)
            {
                //ShadowTextureConfig is struct, so just set length
                mShadowTextureConfigList.length = count;
            }
            else 
            {
                // create new instances with the same settings as the last item in the list
                //auto tmp = new ShadowTextureConfig(mShadowTextureConfigList[$-1]);
                //mShadowTextureConfigList.resize(count, *mShadowTextureConfigList.rbegin());
                auto last = mShadowTextureConfigList[$-1];
                size_t oldCount = mShadowTextureConfigList.length;
                foreach(_; oldCount..count) //count > oldCount should be fine
                    mShadowTextureConfigList ~= last;
            }
            mShadowTextureConfigDirty = true;
        }
    }
    /// Get the number of the textures allocated for texture based shadows
    size_t getShadowTextureCount(){return mShadowTextureConfigList.length; }
    
    /** Set the number of shadow textures a light type uses.
     @remarks
     The default for all light types is 1. This means that each light uses only 1 shadow
     texture. Call this if you need more than 1 shadow texture per light, E.G. PSSM. 
     @note
     This feature only works with the Integrated shadow technique.
     Also remember to increase the total number of shadow textures you request
     appropriately (e.g. via setShadowTextureCount)!!
     */
    void setShadowTextureCountPerLightType(Light.LightTypes type, size_t count)
    { mShadowTextureCountPerType[type] = count; }
    /// Get the number of shadow textures is assigned for the given light type.
    size_t getShadowTextureCountPerLightType(Light.LightTypes type)
    {return mShadowTextureCountPerType[type]; }
    
    /** Sets the size and count of textures used in texture-based shadows. 
     @remarks
     @see setShadowTextureSize and setShadowTextureCount for details, this
     method just allows you to change both at once, which can save on 
     reallocation if the textures have already been created.
     @note This is the simple form, see setShadowTextureConfig for the more 
     complex form.
     */
    void setShadowTextureSettings(ushort size, ushort count, 
                                  PixelFormat fmt = PixelFormat.PF_X8R8G8B8, ushort fsaa = 0, ushort depthBufferPoolId=1)
    {
        setShadowTextureCount(count);
        foreach (i; mShadowTextureConfigList)
        {
            if (i.width != size || i.height != size || i.format != fmt || i.fsaa != fsaa)
            {
                i.width = i.height = size;
                i.format = fmt;
                i.fsaa = fsaa;
                i.depthBufferPoolId = depthBufferPoolId;
                mShadowTextureConfigDirty = true;
            }
        }
    }
    
    /** Get a reference to the shadow texture currently in use at the given index.
     @note
     If you change shadow settings, this reference may no longer
     be correct, so be sure not to hold the returned reference over 
     texture shadow configuration changes.
     */
    SharedPtr!Texture getShadowTexture(size_t shadowIndex)
    {
        if (shadowIndex >= mShadowTextureConfigList.length)
        {
            throw new ItemNotFoundError(
                "shadowIndex out of bounds",
                "SceneManager.getShadowTexture");
        }
        ensureShadowTexturesCreated();
        
        return mShadowTextures[shadowIndex];
    }
    
    /** Sets the proportional distance which a texture shadow which is generated from a
     directional light will be offset into the camera view to make best use of texture space.
     @remarks
     When generating a shadow texture from a directional light, an approximation is used
     since it is not possible to render the entire scene to one texture. 
     The texture is projected onto an area centred on the camera, and is
     the shadow far distance * 2 in length (it is square). This wastes
     a lot of texture space outside the frustum though, so this offset allows
     you to move the texture in front of the camera more. However, be aware
     that this can cause a little shadow 'jittering' during rotation, and
     that if you move it too far then you'll start to get artefacts close 
     to the camera. The value is represented as a proportion of the shadow
     far distance, and the default is 0.6.
     */
    void setShadowDirLightTextureOffset(Real offset) { mShadowTextureOffset = offset;}
    /** Gets the proportional distance which a texture shadow which is generated from a
     directional light will be offset into the camera view to make best use of texture space.
     */
    Real getShadowDirLightTextureOffset() { return mShadowTextureOffset; }
    /** Sets the proportional distance at which texture shadows begin to fade out.
     @remarks
     To hide the edges where texture shadows end (in directional lights)
     Ogre will fade out the shadow in the distance. This value is a proportional
     distance of the entire shadow visibility distance at which the shadow
     begins to fade out. The default is 0.7
     */
    void setShadowTextureFadeStart(Real fadeStart) 
    { mShadowTextureFadeStart = fadeStart; }
    /** Sets the proportional distance at which texture shadows finish to fading out.
     @remarks
     To hide the edges where texture shadows end (in directional lights)
     Ogre will fade out the shadow in the distance. This value is a proportional
     distance of the entire shadow visibility distance at which the shadow
     is completely invisible. The default is 0.9.
     */
    void setShadowTextureFadeEnd(Real fadeEnd) 
    { mShadowTextureFadeEnd = fadeEnd; }
    
    /** Sets whether or not texture shadows should attempt to self-shadow.
     @remarks
     The default implementation of texture shadows uses a fixed-function 
     colour texture projection approach for maximum compatibility, and 
     as such cannot support self-shadowing. However, if you decide to 
     implement a more complex shadowing technique using the 
     setShadowTextureCasterMaterial and setShadowTextureReceiverMaterial 
     there is a possibility you may be able to support 
     self-shadowing (e.g by implementing a shader-based shadow map). In 
     this case you might want to enable this option.
     @param selfShadow Whether to attempt self-shadowing with texture shadows
     */
    void setShadowTextureSelfShadow(bool selfShadow)
    { 
        mShadowTextureSelfShadow = selfShadow;
        if (isShadowTechniqueTextureBased())
            getRenderQueue().setShadowCastersCannotBeReceivers(!selfShadow);
    }
    
    /// Gets whether or not texture shadows attempt to self-shadow.
    bool getShadowTextureSelfShadow()
    { return mShadowTextureSelfShadow; }
    /** Sets the default material to use for rendering shadow casters.
     @remarks
     By default shadow casters are rendered into the shadow texture using
     an automatically generated fixed-function pass. This allows basic
     projective texture shadows, but it's possible to use more advanced
     shadow techniques by overriding the caster and receiver materials, for
     example providing vertex and fragment programs to implement shadow
     maps.
     @par
     You can rely on the ambient light in the scene being set to the 
     requested texture shadow colour, if that's useful. 
     @note
     Individual objects may also override the vertex program in
     your default material if their materials include 
     shadow_caster_vertex_program_ref, shadow_receiver_vertex_program_ref
     shadow_caster_material entries, so if you use both make sure they are compatible.           
     @note
     Only a single pass is allowed in your material, although multiple
     techniques may be used for hardware fallback.
     */
    void setShadowTextureCasterMaterial(string name)
    {
        if (name is null)
        {
            mShadowTextureCustomCasterPass = null;
        }
        else
        {
            SharedPtr!Material mat = MaterialManager.getSingleton().getByName(name);
            if (mat.isNull())
            {
                throw new ItemNotFoundError(
                    "Cannot locate material called '" ~ name ~ "'", 
                    "SceneManager.setShadowTextureCasterMaterial");
            }
            mat.get().load();
            if (!mat.getAs().getBestTechnique())
            {
                // unsupported
                mShadowTextureCustomCasterPass = null;
            }
            else
            {
                
                mShadowTextureCustomCasterPass = mat.getAs().getBestTechnique().getPass(0);
                if (mShadowTextureCustomCasterPass.hasVertexProgram())
                {
                    // Save vertex program and params in case we have to swap them out
                    mShadowTextureCustomCasterVertexProgram = 
                        mShadowTextureCustomCasterPass.getVertexProgramName();
                    mShadowTextureCustomCasterVPParams = 
                        mShadowTextureCustomCasterPass.getVertexProgramParameters();
                }
                if (mShadowTextureCustomCasterPass.hasFragmentProgram())
                {
                    // Save fragment program and params in case we have to swap them out
                    mShadowTextureCustomCasterFragmentProgram = 
                        mShadowTextureCustomCasterPass.getFragmentProgramName();
                    mShadowTextureCustomCasterFPParams = 
                        mShadowTextureCustomCasterPass.getFragmentProgramParameters();
                }
            }
        }
    }
    /** Sets the default material to use for rendering shadow receivers.
     @remarks
     By default shadow receivers are rendered as a post-pass using basic
     modulation. This allows basic projective texture shadows, but it's 
     possible to use more advanced shadow techniques by overriding the 
     caster and receiver materials, for example providing vertex and 
     fragment programs to implement shadow maps.
     @par
     You can rely on texture unit 0 containing the shadow texture, and 
     for the unit to be set to use projective texturing from the light 
     (only useful if you're using fixed-function, which is unlikely; 
     otherwise you should rely on the texture_viewproj_matrix auto binding)
     @note
     Individual objects may also override the vertex program in
     your default material if their materials include 
     shadow_caster_vertex_program_ref shadow_receiver_vertex_program_ref
     shadow_receiver_material entries, so if you use both make sure they are compatible.
     @note
     Only a single pass is allowed in your material, although multiple
     techniques may be used for hardware fallback.
     */
    void setShadowTextureReceiverMaterial(string name)
    {
        if (name is null)
        {
            mShadowTextureCustomReceiverPass = null;
        }
        else
        {
            SharedPtr!Material mat = MaterialManager.getSingleton().getByName(name);
            if (mat.isNull())
            {
                throw new ItemNotFoundError(
                    "Cannot locate material called '" ~ name ~ "'", 
                    "SceneManager.setShadowTextureReceiverMaterial");
            }
            mat.get().load();
            if (!mat.getAs().getBestTechnique())
            {
                // unsupported
                mShadowTextureCustomReceiverPass = null;
            }
            else
            {
                
                mShadowTextureCustomReceiverPass = mat.getAs().getBestTechnique().getPass(0);
                if (mShadowTextureCustomReceiverPass.hasVertexProgram())
                {
                    // Save vertex program and params in case we have to swap them out
                    mShadowTextureCustomReceiverVertexProgram = 
                        mShadowTextureCustomReceiverPass.getVertexProgramName();
                    mShadowTextureCustomReceiverVPParams = 
                        mShadowTextureCustomReceiverPass.getVertexProgramParameters();
                }
                else
                {
                    mShadowTextureCustomReceiverVertexProgram = null;
                }
                if (mShadowTextureCustomReceiverPass.hasFragmentProgram())
                {
                    // Save fragment program and params in case we have to swap them out
                    mShadowTextureCustomReceiverFragmentProgram = 
                        mShadowTextureCustomReceiverPass.getFragmentProgramName();
                    mShadowTextureCustomReceiverFPParams = 
                        mShadowTextureCustomReceiverPass.getFragmentProgramParameters();
                }
                else
                {
                    mShadowTextureCustomReceiverFragmentProgram = null;
                }
            }
        }
    }
    
    /** Sets whether or not shadow casters should be rendered into shadow
     textures using their back faces rather than their front faces. 
     @remarks
     Rendering back faces rather than front faces into a shadow texture
     can help minimise depth comparison issues, if you're using depth
     shadowmapping. You will probably still need some biasing but you
     won't need as much. For solid objects the result is the same anyway,
     if you have objects with holes you may want to turn this option off.
     The default is to enable this option.
     */
    void setShadowCasterRenderBackFaces(bool bf) { mShadowCasterRenderBackFaces = bf; }
    
    /** Gets whether or not shadow casters should be rendered into shadow
     textures using their back faces rather than their front faces. 
     */
    bool getShadowCasterRenderBackFaces(){ return mShadowCasterRenderBackFaces; }
    
    /** Set the shadow camera setup to use for all lights which don't have
     their own shadow camera setup.
     @see ShadowCameraSetup
     */
    void setShadowCameraSetup(ShadowCameraSetupPtr shadowSetup)
    {
        mDefaultShadowCameraSetup = shadowSetup;
    }
    
    /** Get the shadow camera setup in use for all lights which don't have
     their own shadow camera setup.
     @see ShadowCameraSetup
     */
    ShadowCameraSetupPtr getShadowCameraSetup()
    {
        return mDefaultShadowCameraSetup;
    }
    
    /** Sets whether we should use an inifinite camera far plane
     when rendering stencil shadows.
     @remarks
     Stencil shadow coherency is very reliant on the shadow volume
     not being clipped by the far plane. If this clipping happens, you
     get a kind of 'negative' shadow effect. The best way to achieve
     coherency is to move the far plane of the camera out to infinity,
     thus preventing the far plane from clipping the shadow volumes.
     When combined with vertex program extrusion of the volume to 
     infinity, which Ogre does when available, this results in very
     robust shadow volumes. For this reason, when you enable stencil 
     shadows, Ogre automatically changes your camera settings to 
     project to infinity if the card supports it. You can disable this
     behaviour if you like by calling this method; although you can 
     never enable infinite projection if the card does not support it.
     @par    
     If you disable infinite projection, or it is not available, 
     you need to be far more careful with your light attenuation /
     directional light extrusion distances to avoid clipping artefacts
     at the far plane.
     @note
     Recent cards will generally support infinite far plane projection.
     However, we have found some cases where they do not, especially
     on Direct3D. There is no standard capability we can check to 
     validate this, so we use some heuristics based on experience:
     <UL>
     <LI>OpenGL always seems to support it no matter what the card</LI>
     <LI>Direct3D on non-vertex program capable systems (including 
     vertex program capable cards on Direct3D7) does not
     support it</LI>
     <LI>Direct3D on GeForce3 and GeForce4 Ti does not seem to support
     infinite projection<LI>
     </UL>
     therefore in the RenderSystem implementation, we may veto the use
     of an infinite far plane based on these heuristics. 
     */
    void setShadowUseInfiniteFarPlane(bool enable) {
        mShadowUseInfiniteFarPlane = enable; }
    
    /** Is there a stencil shadow based shadowing technique in use? */
    bool isShadowTechniqueStencilBased()
    { return (mShadowTechnique & ShadowTechnique.SHADOWDETAILTYPE_STENCIL) != 0; }
    /** Is there a texture shadow based shadowing technique in use? */
    bool isShadowTechniqueTextureBased()
    { return (mShadowTechnique & ShadowTechnique.SHADOWDETAILTYPE_TEXTURE) != 0; }
    /** Is there a modulative shadowing technique in use? */
    bool isShadowTechniqueModulative()
    { return (mShadowTechnique & ShadowTechnique.SHADOWDETAILTYPE_MODULATIVE) != 0; }
    /** Is there an additive shadowing technique in use? */
    bool isShadowTechniqueAdditive()
    { return (mShadowTechnique & ShadowTechnique.SHADOWDETAILTYPE_ADDITIVE) != 0; }
    /** Is the shadow technique integrated into primary materials? */
    bool isShadowTechniqueIntegrated()
    { return (mShadowTechnique & ShadowTechnique.SHADOWDETAILTYPE_INTEGRATED) != 0; }
    /** Is there any shadowing technique in use? */
    bool isShadowTechniqueInUse()
    { return mShadowTechnique != ShadowTechnique.SHADOWTYPE_NONE; }
    /** Sets whether when using a built-in additive shadow mode, user clip
     planes should be used to restrict light rendering.
     */
    void setShadowUseLightClipPlanes(bool enabled) { mShadowAdditiveLightClip = enabled; }
    /** Gets whether when using a built-in additive shadow mode, user clip
     planes should be used to restrict light rendering.
     */
    bool getShadowUseLightClipPlanes(){ return mShadowAdditiveLightClip; }
    
    /** Sets the active compositor chain of the current scene being rendered.
     @note CompositorChain does this automatically, no need to call manually.
     */
    void _setActiveCompositorChain(CompositorChain chain) { mActiveCompositorChain = chain; }
    
    /** Sets whether to use late material resolving or not. If set, materials will be resolved
     from the materials at the pass-setting stage and not at the render queue building stage.
     This is useful when the active material scheme during the render queue building stage
     is different from the one during the rendering stage.
     */
    void setLateMaterialResolving(bool isLate) { mLateMaterialResolving = isLate; }
    
    /** Gets whether using late material resolving or not.
     @see setLateMaterialResolving */
    bool isLateMaterialResolving(){ return mLateMaterialResolving; }
    
    /** Gets the active compositor chain of the current scene being rendered */
    CompositorChain _getActiveCompositorChain(){ return mActiveCompositorChain; }
    
    /** Add a listener which will get called back on scene manager events.
     */
    void addListener(Listener newListener)
    {
        mListeners.insert(newListener);
    }
    /** Remove a listener
     */
    void removeListener(Listener delListener)
    {
        mListeners.removeFromArray(delListener);
    }
    
    /** Creates a StaticGeometry instance suitable for use with this
     SceneManager.
     @remarks
     StaticGeometry is a way of batching up geometry into a more 
     efficient form at the expense of being able to move it. Please 
     read the StaticGeometry class documentation for full information.
     @param name The name to give the new object
     @return The new StaticGeometry instance
     */
    StaticGeometry createStaticGeometry(string name)
    {
        // Check not existing
        if ((name in mStaticGeometryList) !is null)
        {
            throw new DuplicateItemError(
                "StaticGeometry with name '" ~ name ~ "' already exists!", 
                "SceneManager.createStaticGeometry");
        }
        StaticGeometry ret = new StaticGeometry(this, name);
        mStaticGeometryList[name] = ret;
        return ret;
    }
    /** Retrieve a previously created StaticGeometry instance. 
     @note Throws an exception if the named instance does not exist
     */
    StaticGeometry getStaticGeometry(string name)
    {
        auto i = name in mStaticGeometryList;
        if (i is null)
        {
            throw new ItemNotFoundError(
                "StaticGeometry with name '" ~ name ~ "' not found", 
                "SceneManager.createStaticGeometry");
        }
        return *i;
    }
    /** Returns whether a static geometry instance with the given name exists. */
    bool hasStaticGeometry(string name)
    {
        return (name in mStaticGeometryList) !is null;
    }
    /** Remove & destroy a StaticGeometry instance. */
    void destroyStaticGeometry(StaticGeometry geom)
    {
        destroyStaticGeometry(geom.getName());
    }
    /** Remove & destroy a StaticGeometry instance. */
    void destroyStaticGeometry(string name)
    {
        auto i = name in mStaticGeometryList;
        if (i !is null)
        {
            destroy(*i);
            mStaticGeometryList.remove(name);
        }
        
    }
    /** Remove & destroy all StaticGeometry instances. */
    void destroyAllStaticGeometry()
    {
        foreach (k,v; mStaticGeometryList)
        {
            destroy(v);
        }
        mStaticGeometryList.clear();
    }
    
    /** Creates a InstancedGeometry instance suitable for use with this
     SceneManager.
     @remarks
     InstancedGeometry is a way of batching up geometry into a more 
     efficient form, and still be able to move it. Please 
     read the InstancedGeometry class documentation for full information.
     @param name The name to give the new object
     @return The new InstancedGeometry instance
     */
    InstancedGeometry createInstancedGeometry(string name)
    {
        // Check not existing
        if ( (name in mInstancedGeometryList) !is null)
        {
            throw new DuplicateItemError(
                "InstancedGeometry with name '" ~ name ~ "' already exists!", 
                "SceneManager.createInstancedGeometry");
        }
        InstancedGeometry ret = new InstancedGeometry(this, name);
        mInstancedGeometryList[name] = ret;
        return ret;
    }
    /** Retrieve a previously created InstancedGeometry instance. */
    InstancedGeometry getInstancedGeometry(string name)
    {
        auto i = name in mInstancedGeometryList;
        if (i is null)
        {
            throw new ItemNotFoundError(
                "InstancedGeometry with name '" ~ name ~ "' not found", 
                "SceneManager.createInstancedGeometry");
        }
        return *i;
    }
    /** Remove & destroy a InstancedGeometry instance. */
    void destroyInstancedGeometry(InstancedGeometry geom)
    {
        destroyInstancedGeometry(geom.getName());
    }
    /** Remove & destroy a InstancedGeometry instance. */
    void destroyInstancedGeometry(string name)
    {
        auto i = name in mInstancedGeometryList;
        if (i !is null)
        {
            destroy(*i);
            mInstancedGeometryList.remove(name);
        }
        
    }
    /** Remove & destroy all InstancedGeometry instances. */
    void destroyAllInstancedGeometry()
    {
        foreach (k,v; mInstancedGeometryList)
        {
            destroy(v);
        }
        mInstancedGeometryList.clear();
    }
    
    /** Creates an InstanceManager interface to create & manipulate instanced entities
     You need to call this function at least once before start calling createInstancedEntity
     to build up an instance based on the given mesh.
     @remarks
     Instancing is a way of batching up geometry into a much more 
     efficient form, but with some limitations, and still be able to move & animate it.
     Please @see InstanceManager class documentation for full information.
     @param customName Custom name for referencing. Must be unique
     @param meshName The mesh name the instances will be based upon
     @param groupName The resource name where the mesh lives
     @param technique Technique to use, which may be shader based, or hardware based.
     @param numInstancesPerBatch Suggested number of instances per batch. The actual number
     may end up being lower if the technique doesn't support having so many. It can't be zero
     @param flags @see InstanceManagerFlags
     @param subMeshIdx InstanceManager only supports using one submesh from the base mesh. This parameter
     says which submesh to pick (must be <= Mesh.getNumSubMeshes())
     @return The new InstanceManager instance
     */
    InstanceManager createInstanceManager( string customName, string meshName,
                                          string groupName,
                                          InstanceManager.InstancingTechnique technique,
                                          size_t numInstancesPerBatch, ushort flags=0,
                                          ushort subMeshIdx=0 )
    {
        if ((customName in mInstanceManagerMap) !is null)
        {
            throw new DuplicateItemError(
                "InstancedManager with name '" ~ customName ~ "' already exists!", 
                "SceneManager.createInstanceManager");
        }
        
        InstanceManager retVal = new InstanceManager( customName, this, meshName, groupName, technique,
                                                     flags, numInstancesPerBatch, subMeshIdx );
        
        mInstanceManagerMap[customName] = retVal;
        return retVal;
    }
    
    /** Retrieves an existing InstanceManager by it's name.
     @note Throws an exception if the named InstanceManager does not exist
     */
    InstanceManager getInstanceManager( string managerName )
    {
        auto ptr = managerName in mInstanceManagerMap;
        
        if (ptr is null)
        {
            throw new ItemNotFoundError(
                "InstancedManager with name '" ~ managerName ~ "' not found", 
                "SceneManager.getInstanceManager");
        }
        
        return *ptr;
    }
    
    /** Returns whether an InstanceManager with the given name exists. */
    bool hasInstanceManager( string managerName )
    {
        auto ptr = managerName in mInstanceManagerMap;
        return ptr !is null;
    }
    
    /** Destroys an InstanceManager <b>if</b> it was created with createInstanceManager()
     @remarks
     Be sure you don't have any InstancedEntity referenced somewhere which was created with
     this manager, since it will become a dangling pointer.
     @param name Name of the manager to remove
     */
    void destroyInstanceManager( string name )
    {
        //The manager we're trying to destroy might have been scheduled for updating
        //while we haven't yet rendered a frame. Update now to avoid a dangling ptr
        updateDirtyInstanceManagers();
        
        auto i = name in mInstanceManagerMap;
        if (i !is null)
        {
            destroy(*i);
            mInstanceManagerMap.remove(name);
        }
    }
    void destroyInstanceManager( InstanceManager instanceManager )
    {
        destroyInstanceManager( instanceManager.getName() );
    }
    
    void destroyAllInstanceManagers()
    {
        foreach(k,v; mInstanceManagerMap)
        {
            destroy(v);
        }
        
        mInstanceManagerMap.clear();
        mDirtyInstanceManagers.clear();
    }
    
    /** @see InstanceManager.getMaxOrBestNumInstancesPerBatch
     @remarks
     If you've already created an InstanceManager, you can call it's
     getMaxOrBestNumInstancesPerBatch() function directly.
     Another (not recommended) way to know if the technique is unsupported is by creating
     an InstanceManager and use createInstancedEntity, which will return null pointer.
     The input parameter "numInstancesPerBatch" is a suggested value when using IM_VTFBESTFIT
     flag (in that case it should be non-zero)
     @return
     The ideal (or maximum, depending on flags) number of instances per batch for
     the given technique. Zero if technique is unsupported or errors were spotted
     */
    size_t getNumInstancesPerBatch( string meshName, string groupName,
                                   string materialName,
                                   InstanceManager.InstancingTechnique technique,
                                   size_t numInstancesPerBatch, ushort flags=0,
                                   ushort subMeshIdx=0 )
    {
        auto tmpMgr = new InstanceManager( "TmpInstanceManager", this, meshName, groupName,
                                          technique, flags, numInstancesPerBatch, subMeshIdx );
        
        return tmpMgr.getMaxOrBestNumInstancesPerBatch( materialName, numInstancesPerBatch, flags );
    }
    
    /** Creates an InstancedEntity based on an existing InstanceManager (@see createInstanceManager)
     @remarks
     * Return value may be null if the InstanceManger technique isn't supported
     * Try to keep the number of entities with different materials <b>to a minimum</b>
     * For more information @see InstancedManager @see InstancedBatch, @see InstancedEntity
     * Alternatively you can call InstancedManager::createInstanceEntity using the returned
     pointer from createInstanceManager
     @param materialName Material name 
     @param managerName Name of the instance manager
     @return An InstancedEntity ready to be attached to a SceneNode
     */
    InstancedEntity createInstancedEntity( string materialName,
                                          string managerName )
    {
        auto ptr = managerName in mInstanceManagerMap;
        
        if (ptr is null)
        {
            throw new ItemNotFoundError(
                "InstancedManager with name '" ~ managerName ~ "' not found", 
                "SceneManager.createInstanceEntity");
        }
        
        return ptr.createInstancedEntity( materialName );
    }
    
    /** Removes an InstancedEntity, @see SceneManager::createInstancedEntity &
     @see InstanceBatch::removeInstancedEntity
     @param instancedEntity Instance to remove
     */
    void destroyInstancedEntity( InstancedEntity instancedEntity )
    {
        instancedEntity._getOwner().removeInstancedEntity( instancedEntity );
    }
    
    /** Called by an InstanceManager when it has at least one InstanceBatch that needs their bounds
     to be updated for proper culling
     @param dirtyManager The manager with dirty batches to update
     */
    void _addDirtyInstanceManager( InstanceManager dirtyManager )
    {
        mDirtyInstanceManagers.insert( dirtyManager );
    }
    
    /** Create a movable object of the type specified.
     @remarks
     This is the generalised form of MovableObject creation where you can
     create a MovableObject of any specialised type generically, including
     any new types registered using plugins.
     @param name The name to give the object. Must be unique within type.
     @param typeName The type of object to create
     @param params Optional name/value pair list to give extra parameters to
     the created object.
     */
    MovableObject createMovableObject(string name, 
                                      string typeName, NameValuePairList params = NameValuePairList.init)//
    {
        // Nasty hack to make generalised Camera functions work without breaking add-on SMs
        if (typeName == "Camera")
        {
            return createCamera(name);
        }
        MovableObjectFactory factory = 
            Root.getSingleton().getMovableObjectFactory(typeName);
        // Check for duplicate names
        MovableObjectCollection* objectMap = getMovableObjectCollection(typeName);
        
        synchronized((*objectMap).mLock)
        {
            //OGRE_LOCK_MUTEX(objectMap.mutex)
            
            if ((name in (*objectMap).map) !is null)
            {
                throw new DuplicateItemError(
                    "An object of type '" ~ typeName ~ "' with name '" ~ name
                    ~ "' already exists.", 
                    "SceneManager.createMovableObject");
            }
            
            MovableObject newObj = factory.createInstance(name, this, params);
            (*objectMap).map[name] = newObj;
            return newObj;
        }
        
    }
    
    /** Create a movable object of the type specified without a name.
     @remarks
     This is the generalised form of MovableObject creation where you can
     create a MovableObject of any specialised type generically, including
     any new types registered using plugins. The name is generated automatically.
     @param typeName The type of object to create
     @param params Optional name/value pair list to give extra parameters to
     the created object.
     */
    MovableObject createMovableObject(string typeName, NameValuePairList params = null)
    {
        string name = mMovableNameGenerator.generate();
        return createMovableObject(name, typeName, params);
    }
    
    /** Destroys a MovableObject with the name specified, of the type specified.
     @remarks
     The MovableObject will automatically detach itself from any nodes
     on destruction.
     */
    void destroyMovableObject(string name, string typeName)
    {
        // Nasty hack to make generalised Camera functions work without breaking add-on SMs
        if (typeName == "Camera")
        {
            destroyCamera(name);
            return;
        }
        MovableObjectCollection* objectMap = getMovableObjectCollection(typeName);
        MovableObjectFactory factory = 
            Root.getSingleton().getMovableObjectFactory(typeName);
        
        synchronized((*objectMap).mLock)
        {
            //OGRE_LOCK_MUTEX(objectMap.mutex)
            
            auto mi = name in (*objectMap).map;
            if (mi !is null)
            {
                factory.destroyInstance(*mi);
                (*objectMap).map.remove(name);
            }
        }
    }
    
    /** Destroys a MovableObject.
     @remarks
     The MovableObject will automatically detach itself from any nodes
     on destruction.
     */
    void destroyMovableObject(MovableObject m)
    {
        destroyMovableObject(m.getName(), m.getMovableType());
    }
    
    /** Destroy all MovableObjects of a given type. */
    void destroyAllMovableObjectsByType(string typeName)
    {
        // Nasty hack to make generalised Camera functions work without breaking add-on SMs
        if (typeName == "Camera")
        {
            destroyAllCameras();
            return;
        }
        MovableObjectCollection* objectMap = getMovableObjectCollection(typeName);
        MovableObjectFactory factory = 
            Root.getSingleton().getMovableObjectFactory(typeName);
        
        synchronized((*objectMap).mLock)
        {
            //OGRE_LOCK_MUTEX(objectMap.mutex)
            foreach (k,v; (*objectMap).map)
            {
                // Only destroy our own
                if (v._getManager() == this)
                {
                    factory.destroyInstance(v);
                }
            }
            (*objectMap).map.clear();
        }
    }
    
    /** Destroy all MovableObjects. */
    void destroyAllMovableObjects()
    {
        // Lock collection mutex
        //OGRE_LOCK_MUTEX(mMovableObjectCollectionMapMutex)
        synchronized(mMovableObjectCollectionMapMutex)
        {
            foreach(k,coll; mMovableObjectCollectionMap)
            {
                // lock map mutex
                //OGRE_LOCK_MUTEX(coll.mutex)
                synchronized(coll.mLock)
                {
                    if (Root.getSingleton().hasMovableObjectFactory(k))
                    {
                        // Only destroy if we have a factory instance; otherwise must be injected
                        MovableObjectFactory factory = 
                            Root.getSingleton().getMovableObjectFactory(k);
                        
                        foreach (kk,vv; coll.map)
                        {
                            if (vv._getManager() == this)
                            {
                                factory.destroyInstance(vv);
                            }
                        }
                    }
                    coll.map.clear();
                }
            }
        }
    }
    
    /** Get a reference to a previously created MovableObject. 
     @note Throws an exception if the named instance does not exist
     */
    MovableObject getMovableObject(string name, string typeName)//
    {
        // Nasty hack to make generalised Camera functions work without breaking add-on SMs
        if (typeName == "Camera")
        {
            return getCamera(name);
        }
        
        //
        MovableObjectCollection* objectMap = getMovableObjectCollection(typeName);
        
        synchronized((*objectMap).mLock)
        {
            //OGRE_LOCK_MUTEX(objectMap.mutex)
            auto mi = name in (*objectMap).map;
            if (mi is null)
            {
                throw new ItemNotFoundError(
                    "Object named '" ~ name ~ "' does not exist.", 
                    "SceneManager.getMovableObject");
            }
            return *mi;
        }
        
    }
    
    /** Returns whether a movable object instance with the given name exists. */
    bool hasMovableObject(string name, string typeName)
    {
        // Nasty hack to make generalised Camera functions work without breaking add-on SMs
        if (typeName == "Camera")
        {
            return hasCamera(name);
        }
        //OGRE_LOCK_MUTEX(mMovableObjectCollectionMapMutex)
        synchronized(mMovableObjectCollectionMapMutex)
        {
            
            auto i = typeName in mMovableObjectCollectionMap;
            if (i is null)
                return false;
            
            synchronized((*i).mLock)
            {
                //OGRE_LOCK_MUTEX(i.second.mutex)
                return ((name in (*i).map) !is null);
            }
        }
    }
    
    //typedef MapIterator<MovableObjectMap> MovableObjectIterator;
    /** Get an iterator over all MovableObect instances of a given type. 
     @note
     The iterator returned from this method is not thread safe, do not use this
     if you are creating or deleting objects of this type in another thread.
     */
    /*MovableObjectIterator getMovableObjectIterator(string typeName)
     {
     MovableObjectCollection* objectMap = getMovableObjectCollection(typeName);
     // Iterator not thread safe! Warned in header.
     return MovableObjectIterator(objectMap.map.begin(), objectMap.map.end());
     }*/
    
    MovableObject[string] getMovableObjects(string typeName)
    {
        MovableObjectCollection* objectMap = getMovableObjectCollection(typeName);
        // Iterator not thread safe! Warned in header.
        return (*objectMap).map; //TODO Make a thread-safe type?
    }
    
    /** Inject a MovableObject instance created externally.
     @remarks
     This method 'injects' a MovableObject instance created externally into
     the MovableObject instance registry held in the SceneManager. You
     might want to use this if you have a MovableObject which you don't
     want to register a factory for; for example a MovableObject which 
     cannot be generallyructed by clients. 
     @note
     It is important that the MovableObject has a unique name for the type,
     and that its getMovableType() method returns a proper type name.
     */
    void injectMovableObject(MovableObject m)
    {
        MovableObjectCollection* objectMap = getMovableObjectCollection(m.getMovableType());
        {
            //OGRE_LOCK_MUTEX(objectMap.mutex)
            synchronized((*objectMap).mLock)
                (*objectMap).map[m.getName()] = m;
        }
    }
    /** Extract a previously injected MovableObject.
     @remarks
     Essentially this does the same as destroyMovableObject, but only
     removes the instance from the internal lists, it does not attempt
     to destroy it.
     */
    void extractMovableObject(string name, string typeName)
    {
        MovableObjectCollection* objectMap = getMovableObjectCollection(typeName);
        {
            //OGRE_LOCK_MUTEX(objectMap.mutex)
            synchronized((*objectMap).mLock)
            {
                auto mi = name in (*objectMap).map;
                if (mi !is null)
                {
                    // no delete
                    (*objectMap).map.remove(name);
                }
            }
        }
        
    }
    /** Extract a previously injected MovableObject.
     @remarks
     Essentially this does the same as destroyMovableObject, but only
     removes the instance from the internal lists, it does not attempt
     to destroy it.
     */
    void extractMovableObject(MovableObject m)
    {
        extractMovableObject(m.getName(), m.getMovableType());
    }
    /** Extract all injected MovableObjects of a given type.
     @remarks
     Essentially this does the same as destroyAllMovableObjectsByType, 
     but only removes the instances from the internal lists, it does not 
     attempt to destroy them.
     */
    void extractAllMovableObjectsByType(string typeName)
    {
        MovableObjectCollection* objectMap = getMovableObjectCollection(typeName);
        {
            //OGRE_LOCK_MUTEX(objectMap.mutex)
            // no deletion
            synchronized((*objectMap).mLock)
                (*objectMap).map.clear();
        }
    }
    
    /** Sets a mask which is bitwise 'and'ed with objects own visibility masks
     to determine if the object is visible.
     @remarks
     Note that this is combined with any per-viewport visibility mask
     through an 'and' operation. @see Viewport::setVisibilityMask
     */
    void setVisibilityMask(uint vmask) { mVisibilityMask = vmask; }
    
    /** Gets a mask which is bitwise 'and'ed with objects own visibility masks
     to determine if the object is visible.
     */
    uint getVisibilityMask() { return mVisibilityMask; }
    
    /** Internal method for getting the combination between the global visibility
     mask and the per-viewport visibility mask.
     */
    uint _getCombinedVisibilityMask()
    {
        return mCurrentViewport ?
            mCurrentViewport.getVisibilityMask() & mVisibilityMask : mVisibilityMask;
    }
    
    /** Sets whether the SceneManager should search for visible objects, or
     whether they are being manually handled.
     @remarks
     This is an advanced function, you should not use this unless you know
     what you are doing.
     */
    void setFindVisibleObjects(bool find) { mFindVisibleObjects = find; }
    
    /** Gets whether the SceneManager should search for visible objects, or
     whether they are being manually handled.
     */
    bool getFindVisibleObjects() { return mFindVisibleObjects; }
    
    /** Set whether to automatically normalise normals on objects whenever they
     are scaled.
     @remarks
     Scaling can distort normals so the default behaviour is to compensate
     for this, but it has a cost. If you would prefer to manually manage 
     this, set this option to 'false' and use Pass::setNormaliseNormals
     only when needed.
     */
    void setNormaliseNormalsOnScale(bool n) { mNormaliseNormalsOnScale = n; }
    
    /** Get whether to automatically normalise normals on objects whenever they
     are scaled.
     */
    bool getNormaliseNormalsOnScale(){ return mNormaliseNormalsOnScale; }
    
    /** Set whether to automatically flip the culling mode on objects whenever they
     are negatively scaled.
     @remarks
     Negativelyl scaling an object has the effect of flipping the triangles, 
     so the culling mode should probably be inverted to deal with this. 
     If you would prefer to manually manage this, set this option to 'false' 
     and use different materials with Pass::setCullingMode set manually as needed.
     */
    void setFlipCullingOnNegativeScale(bool n) { mFlipCullingOnNegativeScale = n; }
    
    /** Get whether to automatically flip the culling mode on objects whenever they
     are negatively scaled.
     */
    bool getFlipCullingOnNegativeScale(){ return mFlipCullingOnNegativeScale; }
    
    /** Render something as if it came from the current queue.
     @param pass     Material pass to use for setting up this quad.
     @param rend     Renderable to render
     @param shadowDerivation Whether passes should be replaced with shadow caster / receiver passes
     */
    void _injectRenderWithPass(Pass pass, Renderable rend, bool shadowDerivation = true,
                               bool doLightIteration = false,LightList manualLightList = LightList.init)
    {
        // render something as if it came from the current queue
        Pass usedPass = _setPass(pass, false, shadowDerivation);
        renderSingleObject(rend, usedPass, false, doLightIteration, manualLightList);
    }
    
    /** Indicates to the SceneManager whether it should suppress changing
     the RenderSystem states when rendering objects.
     @remarks
     This method allows you to tell the SceneManager not to change any
     RenderSystem state until you tell it to. This method is only 
     intended for advanced use, don't use it if you're unsure of the 
     effect. The only RenderSystems calls made are to set the world 
     matrix for each object (note - view an projection matrices are NOT
     SET - they are under your control) and to render the object; it is up to 
     the caller to do everything else, including enabling any vertex / 
     fragment programs and updating their parameter state, and binding
     parameters to the RenderSystem.
     @note
     Calling this implicitly disables shadow processing since no shadows
     can be rendered without changing state.
     @param suppress If true, no RenderSystem state changes will be issued
     until this method is called again with a parameter of false.
     */
    void _suppressRenderStateChanges(bool suppress)
    {
        mSuppressRenderStateChanges = suppress;
    }
    
    /** Are render state changes suppressed? 
     @see _suppressRenderStateChanges
     */
    bool _areRenderStateChangesSuppressed()
    { return mSuppressRenderStateChanges; }
    
    /** Internal method for setting up the renderstate for a rendering pass.
     @param pass The Pass details to set.
     @param evenIfSuppressed Sets the pass details even if render state
     changes are suppressed; if you are using this to manually set state
     when render state changes are suppressed, you should set this to 
     true.
     @param shadowDerivation If false, disables the derivation of shadow
     passes from original passes
     @return
     A Pass object that was used instead of the one passed in, can
     happen when rendering shadow passes
     */
    Pass _setPass(/*const*/ Pass pass, 
                      bool evenIfSuppressed = false, bool shadowDerivation = true)
    {
        //If using late material resolving, swap now.
        if (isLateMaterialResolving()) 
        {
            Technique lateTech = pass.getParent().getParent().getBestTechnique();
            if (lateTech.getNumPasses() > pass.getIndex())
            {
                pass = lateTech.getPass(pass.getIndex());
            }
            else
            {
                pass = lateTech.getPass(0);
            }
            //Should we warn or throw an exception if an illegal state was achieved?
        }
        
        if (!mSuppressRenderStateChanges || evenIfSuppressed)
        {
            if (mIlluminationStage == IlluminationRenderStage.IRS_RENDER_TO_TEXTURE && shadowDerivation)
            {
                // Derive a special shadow caster pass from this one
                pass = deriveShadowCasterPass(pass);
            }
            else if (mIlluminationStage == IlluminationRenderStage.IRS_RENDER_RECEIVER_PASS && shadowDerivation)
            {
                pass = deriveShadowReceiverPass(pass);
            }
            
            // Tell params about current pass
            mAutoParamDataSource.setCurrentPass(pass);
            
            bool passSurfaceAndLightParams = true;
            bool passFogParams = true;
            
            if (pass.hasVertexProgram())
            {
                bindGpuProgram(pass.getVertexProgram().getAs()._getBindingDelegate());
                // bind parameters later 
                // does the vertex program want surface and light params passed to rendersystem?
                passSurfaceAndLightParams = pass.getVertexProgram().getAs().getPassSurfaceAndLightStates();
            }
            else
            {
                // Unbind program?
                if (mDestRenderSystem.isGpuProgramBound(GpuProgramType.GPT_VERTEX_PROGRAM))
                {
                    mDestRenderSystem.unbindGpuProgram(GpuProgramType.GPT_VERTEX_PROGRAM);
                }
                // Set fixed-function vertex parameters
            }
            
            if (pass.hasGeometryProgram())
            {
                bindGpuProgram(pass.getGeometryProgram().getAs()._getBindingDelegate());
                // bind parameters later 
            }
            else
            {
                // Unbind program?
                if (mDestRenderSystem.isGpuProgramBound(GpuProgramType.GPT_GEOMETRY_PROGRAM))
                {
                    mDestRenderSystem.unbindGpuProgram(GpuProgramType.GPT_GEOMETRY_PROGRAM);
                }
                // Set fixed-function vertex parameters
            }
            if (pass.hasTesselationHullProgram())
            {
                bindGpuProgram(pass.getTesselationHullProgram().getAs()._getBindingDelegate());
                // bind parameters later
            }
            else
            {
                // Unbind program?
                if (mDestRenderSystem.isGpuProgramBound(GpuProgramType.GPT_HULL_PROGRAM))
                {
                    mDestRenderSystem.unbindGpuProgram(GpuProgramType.GPT_HULL_PROGRAM);
                }
                // Set fixed-function tesselation control parameters
            }
            
            if (pass.hasTesselationDomainProgram())
            {
                bindGpuProgram(pass.getTesselationDomainProgram().getAs()._getBindingDelegate());
                // bind parameters later
            }
            else
            {
                // Unbind program?
                if (mDestRenderSystem.isGpuProgramBound(GpuProgramType.GPT_DOMAIN_PROGRAM))
                {
                    mDestRenderSystem.unbindGpuProgram(GpuProgramType.GPT_DOMAIN_PROGRAM);
                }
                // Set fixed-function tesselation evaluation parameters
            }
            
            
            if (passSurfaceAndLightParams)
            {
                // Set surface reflectance properties, only valid if lighting is enabled
                if (pass.getLightingEnabled())
                {
                    mDestRenderSystem._setSurfaceParams( 
                                                        pass.getAmbient(), 
                                                        pass.getDiffuse(), 
                                                        pass.getSpecular(), 
                                                        pass.getSelfIllumination(), 
                                                        pass.getShininess(),
                                                        pass.getVertexColourTracking() );
                }
                
                // Dynamic lighting enabled?
                mDestRenderSystem.setLightingEnabled(pass.getLightingEnabled());
            }
            
            // Using a fragment program?
            if (pass.hasFragmentProgram())
            {
                bindGpuProgram(pass.getFragmentProgram().getAs()._getBindingDelegate());
                // bind parameters later 
                passFogParams = pass.getFragmentProgram().getAs().getPassFogStates();
            }
            else
            {
                // Unbind program?
                if (mDestRenderSystem.isGpuProgramBound(GpuProgramType.GPT_FRAGMENT_PROGRAM))
                {
                    mDestRenderSystem.unbindGpuProgram(GpuProgramType.GPT_FRAGMENT_PROGRAM);
                }
                
                // Set fixed-function fragment settings
            }
            
            if (passFogParams)
            {
                // New fog params can either be from scene or from material
                FogMode newFogMode;
                ColourValue newFogColour;
                Real newFogStart, newFogEnd, newFogDensity;
                if (pass.getFogOverride())
                {
                    // New fog params from material
                    newFogMode = pass.getFogMode();
                    newFogColour = pass.getFogColour();
                    newFogStart = pass.getFogStart();
                    newFogEnd = pass.getFogEnd();
                    newFogDensity = pass.getFogDensity();
                }
                else
                {
                    // New fog params from scene
                    newFogMode = mFogMode;
                    newFogColour = mFogColour;
                    newFogStart = mFogStart;
                    newFogEnd = mFogEnd;
                    newFogDensity = mFogDensity;
                }
                
                /* In D3D, it applies to shaders prior
                 to version vs_3_0 and ps_3_0. And in OGL, it applies to "ARB_fog_XXX" in
                 fragment program, and in other ways, them maybe access by gpu program via
                 "state.fog.XXX".
                 */
                mDestRenderSystem._setFog(
                    newFogMode, newFogColour, newFogDensity, newFogStart, newFogEnd);
            }
            // Tell params about ORIGINAL fog
            // Need to be able to override fixed function fog, but still have
            // original fog parameters available to a shader than chooses to use
            mAutoParamDataSource.setFog(
                mFogMode, mFogColour, mFogDensity, mFogStart, mFogEnd);
            
            // The rest of the settings are the same no matter whether we use programs or not
            
            // Set scene blending
            if ( pass.hasSeparateSceneBlending( ) )
            {
                mDestRenderSystem._setSeparateSceneBlending(
                    pass.getSourceBlendFactor(), pass.getDestBlendFactor(),
                    pass.getSourceBlendFactorAlpha(), pass.getDestBlendFactorAlpha(),
                    pass.getSceneBlendingOperation(), 
                    pass.hasSeparateSceneBlendingOperations() ? pass.getSceneBlendingOperation() : pass.getSceneBlendingOperationAlpha() );
            }
            else
            {
                if(pass.hasSeparateSceneBlendingOperations( ) )
                {
                    mDestRenderSystem._setSeparateSceneBlending(
                        pass.getSourceBlendFactor(), pass.getDestBlendFactor(),
                        pass.getSourceBlendFactor(), pass.getDestBlendFactor(),
                        pass.getSceneBlendingOperation(), pass.getSceneBlendingOperationAlpha() );
                }
                else
                {
                    mDestRenderSystem._setSceneBlending(
                        pass.getSourceBlendFactor(), pass.getDestBlendFactor(), pass.getSceneBlendingOperation() );
                }
            }
            
            // Set point parameters
            mDestRenderSystem._setPointParameters(
                pass.getPointSize(),
                pass.isPointAttenuationEnabled(), 
                pass.getPointAttenuationConstant(), 
                pass.getPointAttenuationLinear(), 
                pass.getPointAttenuationQuadratic(), 
                pass.getPointMinSize(), 
                pass.getPointMaxSize());
            
            if (mDestRenderSystem.getCapabilities().hasCapability(Capabilities.RSC_POINT_SPRITES))
                mDestRenderSystem._setPointSpritesEnabled(pass.getPointSpritesEnabled());
            
            // Texture unit settings
            
            auto texIter =  pass.getTextureUnitStates();
            size_t unit = 0;
            // Reset the shadow texture index for each pass
            size_t startLightIndex = pass.getStartLight();
            size_t shadowTexUnitIndex = 0;
            size_t shadowTexIndex = mShadowTextures.length;
            if (mShadowTextureIndexLightList.length > startLightIndex)
                shadowTexIndex = mShadowTextureIndexLightList[startLightIndex];
            foreach(pTex; texIter)
            {
                if (!pass.getIteratePerLight() && 
                    isShadowTechniqueTextureBased() && 
                    pTex.getContentType() == TextureUnitState.ContentType.CONTENT_SHADOW)
                {
                    // Need to bind the correct shadow texture, based on the start light
                    // Even though the light list can change per object, our restrictions
                    // say that when texture shadows are enabled, the lights up to the
                    // number of texture shadows will be fixed for all objects
                    // to match the shadow textures that have been generated
                    // see Listener::sortLightsAffectingFrustum and
                    // MovableObject::Listener::objectQueryLights
                    // Note that light iteration throws the indexes out so we don't bind here
                    // if that's the case, we have to bind when lights are iterated
                    // in renderSingleObject
                    
                    SharedPtr!Texture shadowTex;
                    if (shadowTexIndex < mShadowTextures.length)
                    {
                        shadowTex = getShadowTexture(shadowTexIndex);
                        // Hook up projection frustum
                        Camera cam = shadowTex.getAs().getBuffer().get().getRenderTarget().getViewport(0).getCamera();
                        // Enable projective texturing if fixed-function, but also need to
                        // disable it explicitly for program pipeline.
                        pTex.setProjectiveTexturing(!pass.hasVertexProgram(), cam);
                        mAutoParamDataSource.setTextureProjector(cam, shadowTexUnitIndex);
                    }
                    else
                    {
                        // Use fallback 'null' shadow texture
                        // no projection since all uniform colour anyway
                        shadowTex = mNullShadowTexture;
                        pTex.setProjectiveTexturing(false);
                        mAutoParamDataSource.setTextureProjector(null, shadowTexUnitIndex);
                        
                    }
                    pTex._setTexturePtr(shadowTex);
                    
                    ++shadowTexIndex;
                    ++shadowTexUnitIndex;
                }
                else if (mIlluminationStage == IlluminationRenderStage.IRS_NONE && pass.hasVertexProgram())
                {
                    // Manually set texture projector for shaders if present
                    // This won't get set any other way if using manual projection
                    auto effi = pTex.getEffects()[TextureUnitState.TextureEffectType.ET_PROJECTIVE_TEXTURE];
                    if (effi !is null)
                    {
                        //TODO Which effect? Hmm fcking multimap
                        mAutoParamDataSource.setTextureProjector(effi[0].frustum, unit);
                    }
                }
                if (pTex.getContentType() == TextureUnitState.ContentType.CONTENT_COMPOSITOR)
                {
                    CompositorChain currentChain = _getActiveCompositorChain();
                    if (!currentChain)
                    {
                        throw new InvalidStateError(
                            "A pass that wishes to reference a compositor texture " ~
                            "attempted to render in a pipeline without a compositor",
                            "SceneManager._setPass");
                    }
                    CompositorInstance refComp = currentChain.getCompositor(pTex.getReferencedCompositorName());
                    if (refComp is null)
                    {
                        throw new ItemNotFoundError(
                            "Invalid compositor content_type compositor name",
                            "SceneManager._setPass");
                    }
                    SharedPtr!Texture refTex = refComp.getTextureInstance(
                        pTex.getReferencedTextureName(), pTex.getReferencedMRTIndex());
                    if (refTex.isNull())
                    {
                        throw new ItemNotFoundError(
                            "Invalid compositor content_type texture name",
                            "SceneManager._setPass");
                    }
                    pTex._setTexturePtr(refTex);
                }
                mDestRenderSystem._setTextureUnitSettings(unit, pTex);
                ++unit;
            }
            // Disable remaining texture units
            mDestRenderSystem._disableTextureUnitsFrom(pass.getNumTextureUnitStates());
            
            // Set up non-texture related material settings
            // Depth buffer settings
            mDestRenderSystem._setDepthBufferFunction(pass.getDepthFunction());
            mDestRenderSystem._setDepthBufferCheckEnabled(pass.getDepthCheckEnabled());
            mDestRenderSystem._setDepthBufferWriteEnabled(pass.getDepthWriteEnabled());
            mDestRenderSystem._setDepthBias(pass.getDepthBiasConstant(), 
                                            pass.getDepthBiasSlopeScale());
            // Alpha-reject settings
            mDestRenderSystem._setAlphaRejectSettings(
                pass.getAlphaRejectFunction(), pass.getAlphaRejectValue(), pass.isAlphaToCoverageEnabled());
            // Set colour write mode
            // Right now we only use on/off, not per-channel
            bool colWrite = pass.getColourWriteEnabled();
            mDestRenderSystem._setColourBufferWriteEnabled(colWrite, colWrite, colWrite, colWrite);
            // Culling mode
            if (isShadowTechniqueTextureBased() 
                && mIlluminationStage == IlluminationRenderStage.IRS_RENDER_TO_TEXTURE
                && mShadowCasterRenderBackFaces
                && pass.getCullingMode() == CullingMode.CULL_CLOCKWISE)
            {
                // render back faces into shadow caster, can help with depth comparison
                mPassCullingMode = CullingMode.CULL_ANTICLOCKWISE;
            }
            else
            {
                mPassCullingMode = pass.getCullingMode();
            }
            mDestRenderSystem._setCullingMode(mPassCullingMode);
            
            // Shading
            mDestRenderSystem.setShadingType(pass.getShadingMode());
            // Polygon mode
            mDestRenderSystem._setPolygonMode(pass.getPolygonMode());
            
            // set pass number
            mAutoParamDataSource.setPassNumber( pass.getIndex() );
            
            // mark global params as dirty
            mGpuParamsDirty |= GpuParamVariability.GPV_GLOBAL;
            
        }
        
        return pass;
    }
    
    /** Method to allow you to mark gpu parameters as dirty, causing them to 
     be updated according to the mask that you set when updateGpuProgramParameters is
     next called. Only really useful if you're controlling parameter state in 
     inner rendering loop callbacks.
     @param mask Some combination of GpuParamVariability which is bitwise OR'ed with the
     current dirty state.
     */
    void _markGpuParamsDirty(ushort mask)
    {
        mGpuParamsDirty |= mask;
    }
    
    
    /** Indicates to the SceneManager whether it should suppress the 
     active shadow rendering technique until told otherwise.
     @remarks
     This is a temporary alternative to setShadowTechnique to suppress
     the rendering of shadows and forcing all processing down the 
     standard rendering path. This is intended for internal use only.
     @param suppress If true, no shadow rendering will occur until this
     method is called again with a parameter of false.
     */
    void _suppressShadows(bool suppress)
    {
        mSuppressShadows = suppress;
    }
    
    /** Are shadows suppressed? 
     @see _suppressShadows
     */
    bool _areShadowsSuppressed()
    { return mSuppressShadows; }
    
    /** Render the objects in a given queue group 
     @remarks You should only call this from a RenderQueueInvocation implementation
     */
    void _renderQueueGroupObjects(RenderQueueGroup pGroup, 
                                  QueuedRenderableCollection.OrganisationMode om)
    {
        bool doShadows = 
            pGroup.getShadowsEnabled() && 
                mCurrentViewport.getShadowsEnabled() && 
                !mSuppressShadows && !mSuppressRenderStateChanges;
        debug(STDERR) std.stdio.stderr.writeln("SceneManager._renderQueueGroupObjects:", pGroup.getPriorityMap());
        if (doShadows && mShadowTechnique == ShadowTechnique.SHADOWTYPE_STENCIL_ADDITIVE)
        {
            // Additive stencil shadows in use
            renderAdditiveStencilShadowedQueueGroupObjects(pGroup, om);
        }
        else if (doShadows && mShadowTechnique == ShadowTechnique.SHADOWTYPE_STENCIL_MODULATIVE)
        {
            // Modulative stencil shadows in use
            renderModulativeStencilShadowedQueueGroupObjects(pGroup, om);
        }
        else if (isShadowTechniqueTextureBased())
        {
            // Modulative texture shadows in use
            if (mIlluminationStage == IlluminationRenderStage.IRS_RENDER_TO_TEXTURE)
            {
                // Shadow caster pass
                if (mCurrentViewport.getShadowsEnabled() &&
                    !mSuppressShadows && !mSuppressRenderStateChanges)
                {
                    renderTextureShadowCasterQueueGroupObjects(pGroup, om);
                }
            }
            else
            {
                // Ordinary + receiver pass
                if (doShadows && !isShadowTechniqueIntegrated())
                {
                    // Receiver pass(es)
                    if (isShadowTechniqueAdditive())
                    {
                        // Auto-additive
                        renderAdditiveTextureShadowedQueueGroupObjects(pGroup, om);
                    }
                    else
                    {
                        // Modulative
                        renderModulativeTextureShadowedQueueGroupObjects(pGroup, om);
                    }
                }
                else
                    renderBasicQueueGroupObjects(pGroup, om);
            }
        }
        else
        {
            // No shadows, ordinary pass
            renderBasicQueueGroupObjects(pGroup, om);
        }
        
    }
    
    /** Advanced method for supplying an alternative visitor, used for parsing the
     render queues and sending the results to the renderer.
     @remarks
     You can use this method to insert your own implementation of the 
     QueuedRenderableVisitor interface, which receives calls as the queued
     renderables are parsed in a given order (determined by RenderQueueInvocationSequence)
     and are sent to the renderer. If you provide your own implementation of
     this visitor, you are responsible for either calling the rendersystem, 
     or passing the calls on to the base class implementation.
     @note
     Ownership is not taken of this pointer, you are still required to 
     delete it yourself once you're finished.
     @param visitor Your implementation of SceneMgrQueuedRenderableVisitor. 
     If you pass 0, the default implementation will be used.
     */
    void setQueuedRenderableVisitor(SceneMgrQueuedRenderableVisitor visitor)
    {
        if (visitor)
            mActiveQueuedRenderableVisitor = visitor;
        else
            mActiveQueuedRenderableVisitor = mDefaultQueuedRenderableVisitor;
    }
    
    /** Gets the current visitor object which processes queued renderables. */
    SceneMgrQueuedRenderableVisitor getQueuedRenderableVisitor()//
    {
        return mActiveQueuedRenderableVisitor;
    }
    
    
    /** Get the rendersystem subclass to which the output of this Scene Manager
     gets sent
     */
    RenderSystem getDestinationRenderSystem()
    {
        return mDestRenderSystem;
    }
    
    /** Gets the current viewport being rendered (advanced use only, only 
     valid during viewport update. */
    Viewport getCurrentViewport() //
    { return mCurrentViewport; }
    
    /** Returns a visibility boundary box for a specific camera. */
    VisibleObjectsBoundsInfo getVisibleObjectsBoundsInfo(/*const*/ Camera cam)
    {
        static VisibleObjectsBoundsInfo nullBox;
        
        auto camVisObjIt = cam in mCamVisibleObjectsMap;
        
        if ( camVisObjIt is null )
            return nullBox;
        else
            return *camVisObjIt;
    }
    
    /**  Returns the shadow caster AAB for a specific light-camera combination */
    VisibleObjectsBoundsInfo getShadowCasterBoundsInfo(Light light, size_t iteration = 0)
    {
        static VisibleObjectsBoundsInfo nullBox;
        
        // find light
        uint foundCount = 0;
        foreach (k,v; mShadowCamLightMapping)
        {
            if ( v == light )
            {
                if (foundCount == iteration)
                {
                    // search the camera-aab list for the texture cam
                    auto camIt = k in mCamVisibleObjectsMap;
                    
                    if ( camIt is null )
                    {
                        return nullBox;
                    }
                    else
                    {
                        return *camIt;
                    }
                }
                else
                {
                    // multiple shadow textures per light, keep searching
                    ++foundCount;
                }
            }
        }
        
        // AAB not available
        return nullBox;
    }
    
    /** Set whether to use camera-relative co-ordinates when rendering, ie
     to always place the camera at the origin and move the world around it.
     @remarks
     This is a technique to alleviate some of the precision issues associated with 
     rendering far from the origin, where single-precision floats as used in most
     GPUs begin to lose their precision. Instead of including the camera
     translation in the view matrix, it only includes the rotation, and
     the world matrices of objects must be expressed relative to this.
     @note
     If you need this option, you will probably also need to enable double-precision
     mode in Ogre (OGRE_DOUBLE_PRECISION), since even though this will 
     alleviate the rendering precision, the source camera and object positions will still 
     suffer from precision issues leading to jerky movement. 
     */
    void setCameraRelativeRendering(bool rel) { mCameraRelativeRendering = rel; }
    
    /** Get whether to use camera-relative co-ordinates when rendering, ie
     to always place the camera at the origin and move the world around it.
     */
    bool getCameraRelativeRendering(){ return mCameraRelativeRendering; }
    
    
    /** Add a level of detail listener. */
    void addLodListener(LodListener listener)
    {
        mLodListeners.insert(listener);
    }
    
    /**
     Remove a level of detail listener.
     @remarks
     Do not call from inside an LodListener callback method.
     */
    void removeLodListener(LodListener listener)
    {
        mLodListeners.removeFromArray(listener);
    }
    
    /** Notify that a movable object lod change event has occurred. */
    void _notifyMovableObjectLodChanged(MovableObjectLodChangedEvent evt)
    {
        // Notify listeners and determine if event needs to be queued
        bool queueEvent = false;
        foreach (it; mLodListeners)
        {
            if (it.prequeueMovableObjectLodChanged(evt))
                queueEvent = true;
        }
        
        // Push event onto queue if requested
        if (queueEvent)
            mMovableObjectLodChangedEvents.insert(evt);
    }
    
    /** Notify that an entity mesh lod change event has occurred. */
    void _notifyEntityMeshLodChanged(EntityMeshLodChangedEvent evt)
    {
        // Notify listeners and determine if event needs to be queued
        bool queueEvent = false;
        foreach (it; mLodListeners)
        {
            if (it.prequeueEntityMeshLodChanged(evt))
                queueEvent = true;
        }
        
        // Push event onto queue if requested
        if (queueEvent)
            mEntityMeshLodChangedEvents.insert(evt);
    }
    
    /** Notify that an entity material lod change event has occurred. */
    void _notifyEntityMaterialLodChanged(EntityMaterialLodChangedEvent evt)
    {
        // Notify listeners and determine if event needs to be queued
        bool queueEvent = false;
        foreach (it; mLodListeners)
        {
            if (it.prequeueEntityMaterialLodChanged(evt))
                queueEvent = true;
        }
        
        // Push event onto queue if requested
        if (queueEvent)
            mEntityMaterialLodChangedEvents.insert(evt);
    }
    
    /** Handle lod events. */
    void _handleLodEvents()
    {
        // Handle events with each listener
        foreach (it; mLodListeners)
        {
            foreach (jt; mMovableObjectLodChangedEvents)
                it.postqueueMovableObjectLodChanged(jt);
            
            foreach (jt; mEntityMeshLodChangedEvents)
                it.postqueueEntityMeshLodChanged(jt);
            
            foreach (jt; mEntityMaterialLodChangedEvents)
                it.postqueueEntityMaterialLodChanged(jt);
        }
        
        // Clear event queues
        mMovableObjectLodChangedEvents.clear();
        mEntityMeshLodChangedEvents.clear();
        mEntityMaterialLodChangedEvents.clear();
    }
    
    IlluminationRenderStage _getCurrentRenderStage() {return mIlluminationStage;}
}

/** Default implementation of IntersectionSceneQuery. */
class DefaultIntersectionSceneQuery : IntersectionSceneQuery
{
public:
    this(SceneManager creator)
    {
        super(creator);
        // No world geometry results supported
        mSupportedWorldFragments.insert(SceneQuery.WorldFragmentType.WFT_NONE);
    }
    ~this() {}
    
    /** See IntersectionSceneQuery. */
    override void execute(IntersectionSceneQueryListener listener)
    {
        // Iterate over all movable types
        auto factIt = Root.getSingleton().getMovableObjectFactories();
        foreach(_,fact; factIt)
        {
            auto objItA = mParentSceneMgr.getMovableObjects(fact.getType());
            
            foreach (_,a; objItA)
            {
                // skip entire section if type doesn't match
                if (!(a.getTypeFlags() & mQueryTypeMask))
                    break;
                
                // Skip if a does not pass the mask
                if (!(a.getQueryFlags() & mQueryMask) ||
                    !a.isInScene())
                    continue;
                
                // Check against later objects in the same group
                //auto objItB = objItA;
                foreach (_,b; objItA)
                {
                    // Apply mask to b (both must pass)
                    if ((b.getQueryFlags() & mQueryMask) && 
                        b.isInScene())
                    {
                        AxisAlignedBox box1 = a.getWorldBoundingBox();
                        AxisAlignedBox box2 = b.getWorldBoundingBox();
                        
                        if (box1.intersects(box2))
                        {
                            if (!listener.queryResult(a, b)) return;
                        }
                    }
                }
                // Check  against later groups
                //auto factItLater = factIt;
                foreach (_,factLater; factIt)
                {
                    auto objItC = mParentSceneMgr.getMovableObjects(factLater.getType());
                    foreach (_,c; objItC)
                    {
                        // skip entire section if type doesn't match
                        if (!(c.getTypeFlags() & mQueryTypeMask))
                            break;
                        
                        // Apply mask to c (both must pass)
                        if ((c.getQueryFlags() & mQueryMask) &&
                            c.isInScene())
                        {
                            AxisAlignedBox box1 = a.getWorldBoundingBox();
                            AxisAlignedBox box2 = c.getWorldBoundingBox();
                            
                            if (box1.intersects(box2))
                            {
                                if (!listener.queryResult(a, c)) return;
                            }
                        }
                    }
                    
                }
                
            }
            
            
        }
        
    }
}

/** Default implementation of RaySceneQuery. */
class DefaultRaySceneQuery : RaySceneQuery
{
public:
    this(SceneManager creator)
    {
        super(creator);
        // No world geometry results supported
        mSupportedWorldFragments.insert(SceneQuery.WorldFragmentType.WFT_NONE);
    }
    ~this() {}
    
    /** See RayScenQuery. */
    override void execute(RaySceneQueryListener listener)
    {
        // Note that because we have no scene partitioning, we actually
        // perform a complete scene search even if restricted results are
        // requested; smarter scene manager queries can utilise the paritioning 
        // of the scene in order to reduce the number of intersection tests 
        // required to fulfil the query
        
        // Iterate over all movable types
        auto factIt = Root.getSingleton().getMovableObjectFactories();
        foreach(_,fact; factIt)
        {
            auto objItA = mParentSceneMgr.getMovableObjects(fact.getType());
            foreach (_,a; objItA)
            {
                // skip whole group if type doesn't match
                if (!(a.getTypeFlags() & mQueryTypeMask))
                    break;
                
                if( (a.getQueryFlags() & mQueryMask) &&
                   a.isInScene())
                {
                    // Do ray / box test
                    pair!(bool, Real) result =
                        mRay.intersects(a.getWorldBoundingBox());
                    
                    if (result.first)
                    {
                        if (!listener.queryResult(a, result.second)) return;
                    }
                }
            }
        }
        
    }
}

/** Default implementation of SphereSceneQuery. */
class DefaultSphereSceneQuery : SphereSceneQuery
{
public:
    this(SceneManager creator)
    {
        super(creator);
        // No world geometry results supported
        mSupportedWorldFragments.insert(SceneQuery.WorldFragmentType.WFT_NONE);
    }
    ~this() {}
    
    /** See SceneQuery. */
    override void execute(SceneQueryListener listener)
    {
        Sphere testSphere;
        
        // Iterate over all movable types
        auto factIt = Root.getSingleton().getMovableObjectFactories();
        foreach(_,fact; factIt)
        {
            auto objItA = mParentSceneMgr.getMovableObjects(fact.getType());
            foreach (_,a; objItA)
            {
                // skip whole group if type doesn't match
                if (!(a.getTypeFlags() & mQueryTypeMask))
                    break;
                // Skip unattached
                if (!a.isInScene() || 
                    !(a.getQueryFlags() & mQueryMask))
                    continue;
                
                // Do sphere / sphere test
                testSphere.setCenter(a.getParentNode()._getDerivedPosition());
                testSphere.setRadius(a.getBoundingRadius());
                if (mSphere.intersects(testSphere))
                {
                    if (!listener.queryResult(a)) return;
                }
            }
        }
    }
}

/** Default implementation of PlaneBoundedVolumeListSceneQuery. */
class DefaultPlaneBoundedVolumeListSceneQuery : PlaneBoundedVolumeListSceneQuery
{
public:
    this(SceneManager creator)
    {
        super(creator);
        // No world geometry results supported
        mSupportedWorldFragments.insert(SceneQuery.WorldFragmentType.WFT_NONE);
    }
    ~this() {}
    
    /** See SceneQuery. */
    override void execute(SceneQueryListener listener)
    {
        // Iterate over all movable types
        auto factIt = Root.getSingleton().getMovableObjectFactories();
        foreach(_,fact; factIt)
        {
            auto objItA = mParentSceneMgr.getMovableObjects(fact.getType());
            foreach (_,a; objItA)
            {
                // skip whole group if type doesn't match
                if (!(a.getTypeFlags() & mQueryTypeMask))
                    break;
                
                foreach (vol; mVolumes)
                {
                    // Do AABB / plane volume test
                    if ((a.getQueryFlags() & mQueryMask) && 
                        a.isInScene() && 
                        vol.intersects(a.getWorldBoundingBox()))
                    {
                        if (!listener.queryResult(a)) return;
                        break;
                    }
                }
            }
        }
    }
}

/** Default implementation of AxisAlignedBoxSceneQuery. */
class DefaultAxisAlignedBoxSceneQuery : AxisAlignedBoxSceneQuery
{
public:
    this(SceneManager creator)
    {
        super(creator);
        // No world geometry results supported
        mSupportedWorldFragments.insert(SceneQuery.WorldFragmentType.WFT_NONE);
    }
    ~this() {}
    
    /** See RayScenQuery. */
    override void execute(SceneQueryListener listener)
    {
        // Iterate over all movable types
        auto factIt = Root.getSingleton().getMovableObjectFactories();
        foreach(fact; factIt)
        {
            auto objItA = mParentSceneMgr.getMovableObjects(fact.getType());
            foreach (_,a; objItA)
            {
                // skip whole group if type doesn't match
                if (!(a.getTypeFlags() & mQueryTypeMask))
                    break;
                
                if ((a.getQueryFlags() & mQueryMask) && 
                    a.isInScene() &&
                    mAABB.intersects(a.getWorldBoundingBox()))
                {
                    if (!listener.queryResult(a)) return;
                }
            }
        }
    }
}


/// Bitmask containing scene types
alias ushort SceneTypeMask;

/** Classification of a scene to allow a decision of what type of
 SceenManager to provide back to the application.
 */
enum SceneType
{
    ST_GENERIC = 1,
    ST_EXTERIOR_CLOSE = 2,
    ST_EXTERIOR_FAR = 4,
    ST_EXTERIOR_REAL_FAR = 8,
    ST_INTERIOR = 16
}

/** Structure containing information about a scene manager. */
struct SceneManagerMetaData
{
    /// A globally unique string identifying the scene manager type
    string typeName;
    /// A text description of the scene manager
    string description;
    /// A mask describing which sorts of scenes this manager can handle
    SceneTypeMask sceneTypeMask;
    /// Flag indicating whether world geometry is supported
    bool worldGeometrySupported;
}



/** Class which will create instances of a given SceneManager. */
class SceneManagerFactory //: public SceneMgtAlloc
{
protected:
    //mutable 
    SceneManagerMetaData mMetaData;
    //mutable 
    bool mMetaDataInit;
    /// Internal method to initialise the metadata, must be implemented
    abstract void initMetaData();//;
public:
    this() { mMetaDataInit = true; }
    ~this() {}
    /** Get information about the SceneManager type created by this factory. */
    SceneManagerMetaData getMetaData()
    {
        if (mMetaDataInit)
        {
            initMetaData();
            mMetaDataInit = false;
        }
        return mMetaData; 
    }
    /** Create a new instance of a SceneManager.
     @remarks
     Don't call directly, use SceneManagerEnumerator::createSceneManager.
     */
    abstract SceneManager createInstance(string instanceName);
    /** Destroy an instance of a SceneManager. */
    abstract void destroyInstance(SceneManager instance);
    
}


/// Factory for default scene manager
class DefaultSceneManagerFactory : SceneManagerFactory
{
protected:
    override void initMetaData()//
    {
        mMetaData.typeName = FACTORY_TYPE_NAME;
        mMetaData.description = "The default scene manager";
        mMetaData.sceneTypeMask = SceneType.ST_GENERIC;
        mMetaData.worldGeometrySupported = false;
    }
    
public:
    this() {}
    ~this() {}
    /// Factory type name
    immutable static string FACTORY_TYPE_NAME = "DefaultSceneManager";
    override SceneManager createInstance(string instanceName)
    {
        return new DefaultSceneManager(instanceName);
    }
    override void destroyInstance(SceneManager instance)
    {
        destroy(instance);
    }
}

/// Default scene manager
class DefaultSceneManager : SceneManager
{
public:
    this(string name)
    {
        super(name);
    }
    ~this() {}
    override string getTypeName() const
    {
        return DefaultSceneManagerFactory.FACTORY_TYPE_NAME;
    }
}

/** Enumerates the SceneManager classes available to applications.
 @remarks
 As described in the SceneManager class, SceneManagers are responsible
 for organising the scene and issuing rendering commands to the
 RenderSystem. Certain scene types can benefit from different
 rendering approaches, and it is intended that subclasses will
 be created to special case this.
 @par
 In order to give applications easy access to these implementations,
 this class has a number of methods to create or retrieve a SceneManager
 which is appropriate to the scene type. 
 @par
 SceneManagers are created by SceneManagerFactory instances. New factories
 for new types of SceneManager can be registered with this class to make
 them available to clients.
 @par
 Note that you can still plug in your own custom SceneManager without
 using a factory, should you choose, it's just not as flexible that way.
 Just instantiate your own SceneManager manually and use it directly.
 */
final class SceneManagerEnumerator //: public SceneMgtAlloc
{
    mixin Singleton!SceneManagerEnumerator;
    
public:
    /// Scene manager instances, indexed by instance name
    //typedef map<String, SceneManager*>::type Instances;
    alias SceneManager[string] Instances;
    /// List of available scene manager types as meta data
    //typedef vector<SceneManagerMetaData*>::type MetaDataList;
    alias SceneManagerMetaData[] MetaDataList;
private:
    /// Scene manager factories
    //typedef list<SceneManagerFactory*>::type Factories;
    alias SceneManagerFactory[] Factories;
    Factories mFactories;
    Instances mInstances;
    /// Stored separately to allow iteration
    MetaDataList mMetaDataList;
    /// Factory for default scene manager
    DefaultSceneManagerFactory mDefaultFactory;
    /// Count of creations for auto-naming
    ulong mInstanceCreateCount;
    /// Currently assigned render system
    RenderSystem mCurrentRenderSystem;
    
    
public:
    this()
    {
        mInstanceCreateCount = 0;
        mCurrentRenderSystem = null;
        //TODO init DefaultSceneManagerFactory??
        mDefaultFactory = new DefaultSceneManagerFactory;
        addFactory(mDefaultFactory);
        
    }
    ~this()
    {
        // Destroy all remaining instances
        // Really should have shutdown and unregistered by now, but catch here in case
        //Instances instancesCopy = mInstances.dup;
        foreach (k; mInstances.keys)// Safer .remove()
        {
            //TODO Does destroyInstance remove from mInstances too?
            //if((k in mInstances) is null) continue;
            //auto v = mInstances[k];
            // destroy instances
            foreach(f; mFactories)
            {
                if (f.getMetaData().typeName == mInstances[k].getTypeName())
                {
                    f.destroyInstance(mInstances[k]);
                    mInstances[k] = null;
                    mInstances.remove(k);
                    break;
                }
            }
            
        }
        mInstances.clear();
        
    }
    
    /** Register a new SceneManagerFactory. 
     @remarks
     Plugins should call this to register as new SceneManager providers.
     */
    void addFactory(SceneManagerFactory fact)
    {
        mFactories.insert(fact);
        // add to metadata
        mMetaDataList.insert(fact.getMetaData());
        // Log
        LogManager.getSingleton().logMessage("SceneManagerFactory for type '" ~
                                             fact.getMetaData().typeName ~ "' registered.");
    }
    
    /** Remove a SceneManagerFactory. 
     */
    void removeFactory(SceneManagerFactory fact)
    {
        // destroy all instances for this factory
        foreach (k; mInstances.keys)
        {
            auto instance = mInstances[k];
            if (instance.getTypeName() == fact.getMetaData().typeName)
            {
                fact.destroyInstance(instance);
                mInstances.remove(k);
            }
        }
        // remove from metadata
        //foreach (m; mMetaDataList)
        bool _findMeta(SceneManagerMetaData m)
        {
            return (m == fact.getMetaData());
        }
        auto r = mMetaDataList.find!_findMeta();
        if(r.length)
            mMetaDataList.removeFromArray(r[0]);
        
        mFactories.removeFromArray(fact);
    }
    
    /** Get more information about a given type of SceneManager.
     @remarks
     The metadata returned tells you a few things about a given type 
     of SceneManager, which can be created using a factory that has been
     registered already. 
     @param typeName The type name of the SceneManager you want to enquire on.
     If you don't know the typeName already, you can iterate over the 
     metadata for all types using getMetaDataIterator.
     */
    SceneManagerMetaData getMetaData(string typeName)
    {
        foreach (i; mMetaDataList)
        {
            if (typeName == i.typeName)
            {
                return i;
            }
        }
        
        throw new ItemNotFoundError(
            "No metadata found for scene manager of type '" ~ typeName ~ "'",
            "SceneManagerEnumerator.createSceneManager");
        
    }
    
    //typedef ConstVectorIterator<MetaDataList> MetaDataIterator;
    /** Iterate over all types of SceneManager available for construction, 
     providing some information about each one.
     */
    /*MetaDataIterator getMetaDataIterator()
     {
     return MetaDataIterator(mMetaDataList.begin(), mMetaDataList.end());
     
     }*/
    
    MetaDataList getMetaDataList()//
    {
        return mMetaDataList;
    }
    
    /** Create a SceneManager instance of a given type.
     @remarks
     You can use this method to create a SceneManager instance of a 
     given specific type. You may know this type already, or you may
     have discovered it by looking at the results from getMetaDataIterator.
     @note
     This method throws an exception if the named type is not found.
     @param typeName String identifying a unique SceneManager type
     @param instanceName Optional name to given the new instance that is
     created. If you leave this blank, an auto name will be assigned.
     */
    SceneManager createSceneManager(string typeName, 
                                    string instanceName = null)
    {
        if ((instanceName in mInstances) !is null)
        {
            throw new DuplicateItemError(
                "SceneManager instance called '" ~ instanceName ~ "' already exists",
                "SceneManagerEnumerator.createSceneManager");
        }
        
        SceneManager inst = null;
        foreach(i; mFactories)
        {
            if (i.getMetaData().typeName == typeName)
            {
                if (instanceName is null)
                {
                    // generate a name
                    string s = std.conv.text("SceneManagerInstance", ++mInstanceCreateCount);
                    inst = i.createInstance(s);
                }
                else
                {
                    inst = i.createInstance(instanceName);
                }
                break;
            }
        }
        
        if (!inst)
        {
            // Error!
            throw new ItemNotFoundError( 
                                        "No factory found for scene manager of type '" ~ typeName ~ "'",
                                        "SceneManagerEnumerator.createSceneManager");
        }
        
        /// assign rs if already configured
        if (mCurrentRenderSystem)
            inst._setDestinationRenderSystem(mCurrentRenderSystem);
        
        mInstances[inst.getName()] = inst;
        
        return inst;
        
        
    }
    
    /** Create a SceneManager instance based on scene type support.
     @remarks
     Creates an instance of a SceneManager which supports the scene types
     identified in the parameter. If more than one type of SceneManager 
     has been registered as handling that combination of scene types, 
     in instance of the last one registered is returned.
     @note This method always succeeds, if a specific scene manager is not
     found, the default implementation is always returned.
     @param typeMask A mask containing one or more SceneType flags
     @param instanceName Optional name to given the new instance that is
     created. If you leave this blank, an auto name will be assigned.
     */
    SceneManager createSceneManager(SceneTypeMask typeMask, 
                                    string instanceName = null)
    {
        if ((instanceName in mInstances) !is null)
        {
            throw new DuplicateItemError(
                "SceneManager instance called '" ~ instanceName ~ "' already exists",
                "SceneManagerEnumerator.createSceneManager");
        }
        
        SceneManager inst = null;
        string name = instanceName;
        if (name is null)
        {
            // generate a name
            name = std.conv.text("SceneManagerInstance", ++mInstanceCreateCount);
        }
        
        // Iterate backwards to find the matching factory registered last
        foreach_reverse(i; mFactories)
        {
            if (i.getMetaData().sceneTypeMask & typeMask)
            {
                inst = i.createInstance(name);
                break;
            }
        }
        
        // use default factory if none
        if (!inst)
            inst = mDefaultFactory.createInstance(name);
        
        /// assign rs if already configured
        if (mCurrentRenderSystem)
            inst._setDestinationRenderSystem(mCurrentRenderSystem);
        
        mInstances[inst.getName()] = inst;
        
        return inst;
        
    }
    
    /** Destroy an instance of a SceneManager. */
    void destroySceneManager(SceneManager sm)
    {
        // Erase instance from map
        mInstances.remove(sm.getName());
        
        // Find factory to destroy
        foreach(i; mFactories)
        {
            if (i.getMetaData().typeName == sm.getTypeName())
            {
                i.destroyInstance(sm);
                break;
            }
        }
        
    }
    
    /** Get an existing SceneManager instance that has already been created,
     identified by the instance name.
     @param instanceName The name of the instance to retrieve.
     */
    SceneManager getSceneManager(string instanceName)
    {
        auto i = instanceName in mInstances;
        if(i !is null)
        {
            return *i;
        }
        else
        {
            throw new ItemNotFoundError(
                "SceneManager instance with name '" ~ instanceName ~ "' not found.",
                "SceneManagerEnumerator.getSceneManager");
        }
        
    }
    
    /** Identify if a SceneManager instance already exists.
     @param instanceName The name of the instance to retrieve.
     */
    bool hasSceneManager(string instanceName)
    {
        return (instanceName in mInstances) !is null;
    }
    
    //typedef MapIterator<Instances> SceneManagerIterator;
    /** Get an iterator over all the existing SceneManager instances. */
    /*SceneManagerIterator getSceneManagerIterator()
     {
     return SceneManagerIterator(mInstances.begin(), mInstances.end());
     
     }*/
    
    Instances getSceneManagers()
    {
        return mInstances; //TODO, dup etc.?
    }
    
    /** Notifies all SceneManagers of the destination rendering system.
     */
    void setRenderSystem(RenderSystem rs)
    {
        mCurrentRenderSystem = rs;
        
        foreach (k,v; mInstances)
        {
            v._setDestinationRenderSystem(rs);
        }
        
    }
    
    /// Utility method to control shutdown of the managers
    void shutdownAll()
    {
        foreach (k,v; mInstances)
        {
            // shutdown instances (clear scene)
            v.clearScene();
        }
    }
    
    /** Override standard Singleton retrieval.
     @remarks
     Why do we do this? Well, it's because the Singleton
     implementation is in a .h file, which means it gets compiled
     into anybody who includes it. This is needed for the
     Singleton template to work, but we actually only want it
     compiled into the implementation of the class based on the
     Singleton, not all of them. If we don't change this, we get
     link errors when trying to use the Singleton-based class from
     an outside dll.
     @par
     This method just delegates to the template version anyway,
     but the implementation stays in this single compilation unit,
     preventing link errors.
     */
    //static SceneManagerEnumerator& getSingleton();
    /** Override standard Singleton retrieval.
     @remarks
     Why do we do this? Well, it's because the Singleton
     implementation is in a .h file, which means it gets compiled
     into anybody who includes it. This is needed for the
     Singleton template to work, but we actually only want it
     compiled into the implementation of the class based on the
     Singleton, not all of them. If we don't change this, we get
     link errors when trying to use the Singleton-based class from
     an outside dll.
     @par
     This method just delegates to the template version anyway,
     but the implementation stays in this single compilation unit,
     preventing link errors.
     */
    //static SceneManagerEnumerator* getSingletonPtr();
    
}


/** Abstract interface which classes must implement if they wish to receive
 events from the scene manager when single object is about to be rendered. 
 */
interface RenderObjectListener
{
    /** Event raised when render single object started.
     @remarks
     This method is called by the SceneManager.
     @param rend
     The renderable that is going to be rendered.
     @param pass
     The pass which was set.
     @param source
     The auto parameter source used within this render call.
     @param pLightList
     The light list in use.
     @param suppressRenderStateChanges
     True if render state changes should be suppressed.
     */
    void notifyRenderSingleObject(Renderable rend, Pass pass, AutoParamDataSource source, 
                                  LightList pLightList, bool suppressRenderStateChanges);
}

/*@}*/
/*@}*/
