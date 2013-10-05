module ogre.effects.compositor;

//import std.container;
import std.array;
import std.string: replace;


import ogre.exception;
import ogre.sharedptr;
import ogre.compat;
import ogre.image.images;
import ogre.general.colourvalue;
import ogre.general.common;
import ogre.math.vector;
import ogre.math.matrix;
import ogre.scene.camera;
import ogre.scene.rectangle2d;
import ogre.materials.technique;
import ogre.materials.material;
import ogre.scene.scenemanager;
import ogre.effects.compositiontechnique;
import ogre.effects.compositiontargetpass;
import ogre.effects.compositionpass;
import ogre.general.log;
import ogre.resources.resourcegroupmanager;
import ogre.resources.texturemanager;
import ogre.general.root;
import ogre.effects.compositormanager;
import ogre.materials.materialmanager;
import ogre.materials.pass;
import ogre.resources.texture;
import ogre.rendersystem.viewport;
import ogre.resources.resource;
import ogre.resources.resourcemanager;
import ogre.rendersystem.rendertarget;
import ogre.rendersystem.rendertexture;
import ogre.rendersystem.renderqueue;
import ogre.rendersystem.rendersystem;
import ogre.rendersystem.rendertargetlistener;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Effects
 *  @{
 */
/** Class representing a Compositor object. Compositors provide the means 
 to flexibly "composite" the final rendering result from multiple scene renders
 and intermediate operations like rendering fullscreen quads. This makes 
 it possible to apply postfilter effects, HDRI postprocessing, and shadow 
 effects to a Viewport.
 */
class Compositor: Resource
{
public:
    this(ResourceManager creator,string name, ResourceHandle handle,
         string group, bool isManual = false, ManualResourceLoader loader = null)
    {
        super(creator, name, handle, group, isManual, loader);
        mCompilationRequired = true;
    }

    ~this()
    {
        removeAllTechniques();
        // have to call this here reather than in Resource destructor
        // since calling methods in base destructors causes crash
        unload(); 
    }
    
    /// Data types for internal lists
    //typedef vector<CompositionTechnique *>.type Techniques;
    //typedef VectorIterator<Techniques> TechniqueIterator;
    alias CompositionTechnique[] Techniques;

    /** Create a new technique, and return a pointer to it.
     */
    CompositionTechnique createTechnique()
    {
        CompositionTechnique t = new CompositionTechnique(this);
        mTechniques.insert(t);
        mCompilationRequired = true;
        return t;
    }
    
    /** Remove a technique. It will also be destroyed.
     */
    void removeTechnique(size_t index)
    {
        assert (index < mTechniques.length, "Index out of bounds.");
        auto i = mTechniques[index];
        destroy(i);
        mTechniques.removeFromArrayIdx(index);
        mSupportedTechniques.clear();
        mCompilationRequired = true;
    }
    
    /** Get a technique.
     */
    CompositionTechnique getTechnique(size_t index)
    {
        assert (index < mTechniques.length, "Index out of bounds.");
        return mTechniques[index];
    }
    
    /** Get the number of techniques.
     */
    size_t getNumTechniques()
    {
        return mTechniques.length;
    }
    
    /** Remove all techniques
     */
    void removeAllTechniques()
    {
        foreach (i; mTechniques)
        {
            destroy(i);
        }
        mTechniques.clear();
        mSupportedTechniques.clear();
        mCompilationRequired = true;
    }
    
    /* * Get an iterator over the Techniques in this compositor. */
    //TechniqueIterator getTechniqueIterator();

    Techniques getTechniques()
    {
        return mTechniques;
    }

    /** Get a supported technique.
     @remarks
     The supported technique list is only available after this compositor has been compiled,
     which typically happens on loading it. Theore, if this method returns
     an empty list, try calling Compositor.load.
     */
    CompositionTechnique getSupportedTechnique(size_t index)
    {
        assert (index < mSupportedTechniques.length, "Index out of bounds.");
        return mSupportedTechniques[index];
    }
    
    /** Get the number of supported techniques.
     @remarks
     The supported technique list is only available after this compositor has been compiled,
     which typically happens on loading it. Therefore, if this method returns
     an empty list, try calling Compositor.load.
     */
    size_t getNumSupportedTechniques()
    {
        return mSupportedTechniques.length;
    }
    
    /** Gets an iterator over all the Techniques which are supported by the current card. 
     @remarks
     The supported technique list is only available after this compositor has been compiled,
     which typically happens on loading it. Therefore, if this method returns
     an empty list, try calling Compositor.load.
     */
    //TechniqueIterator getSupportedTechniqueIterator();
    Techniques getSupportedTechniques()
    {
        return mSupportedTechniques;
    }
    
    /** Get a pointer to a supported technique for a given scheme. 
     @remarks
     If there is no specific supported technique with this scheme name, 
     then the first supported technique with no specific scheme will be returned.
     @param schemeName The scheme name you are looking for. Blank means to 
     look for techniques with no scheme associated
     */
    CompositionTechnique getSupportedTechnique(string schemeName = null)
    {
        foreach(i; mSupportedTechniques)
        {
            if (i.getSchemeName() == schemeName)
            {
                return i;
            }
        }
        
        // didn't find a matching one
        foreach(i; mSupportedTechniques)
        {
            if (i.getSchemeName() is null)
            {
                return i;
            }
        }
        return null;
    }
    
    /** Get the instance name for a global texture.
     @param name The name of the texture in the original compositor definition
     @param mrtIndex If name identifies a MRT, which texture attachment to retrieve
     @return The instance name for the texture, corresponds to a real texture
     */
    string getTextureInstanceName(string name, size_t mrtIndex)
    {
        return getTextureInstance(name, mrtIndex).get().getName();
    }
    
    /** Get the instance of a global texture.
     @param name The name of the texture in the original compositor definition
     @param mrtIndex If name identifies a MRT, which texture attachment to retrieve
     @return The texture pointer, corresponds to a real texture
     */
    SharedPtr!Texture getTextureInstance(string name, size_t mrtIndex)
    {
        //Try simple texture
        auto i = name in mGlobalTextures;
        if(i !is null)
        {
            return *i;
        }
        //Try MRT
        string mrtName = getMRTTexLocalName(name, mrtIndex);
        i = mrtName in mGlobalTextures;
        if(i !is null)
        {
            return *i;
        }
        
        throw new InvalidParamsError("Non-existent global texture name", 
                                     "Compositor.getTextureInstance");
    }
    
    /** Get the render target for a given render texture name. 
     @remarks
     You can use this to add listeners etc, but do not use it to update the
     targets manually or any other modifications, the compositor instance 
     is in charge of this.
     */
    RenderTarget getRenderTarget(string name)
    {
        // try simple texture
        auto i = name in mGlobalTextures;
        if(i !is null)
            return i.getAs().getBuffer().get().getRenderTarget();
        
        // try MRTs
        auto mi = name in mGlobalMRTs;
        if (mi !is null)
            return *mi;
        else
            throw new InvalidParamsError("Non-existent global texture name", 
                                         "Compositor.getRenderTarget");
    }

    /// Util method for assigning a local texture name to a MRT attachment
    string getMRTTexLocalName(string baseName, size_t attachment)
    {
        return std.conv.text(baseName, "/", attachment);
    }

protected:
    /// @copydoc Resource.loadImpl
    override void loadImpl()
    {
        // compile if required
        if (mCompilationRequired)
            compile();
        
        createGlobalTextures();
    }
    
    /// @copydoc Resource.unloadImpl
    override void unloadImpl()
    {
        freeGlobalTextures();
    }
    /// @copydoc Resource.calculateSize
    override size_t calculateSize()
    {
        return 0;
    }
    
    /** Check supportedness of techniques.
     */
    void compile()
    {
        /// Sift out supported techniques
        mSupportedTechniques.clear();
        
        // Try looking for exact technique support with no texture fallback
        foreach (i; mTechniques)
        {
            // Look for exact texture support first
            if(i.isSupported(false))
            {
                mSupportedTechniques.insert(i);
            }
        }
        
        if (mSupportedTechniques.empty())
        {
            // Check again, being more lenient with textures
            foreach (i; mTechniques)
            {
                // Allow texture support with degraded pixel format
                if(i.isSupported(true))
                {
                    mSupportedTechniques.insert(i);
                }
            }
        }
        
        mCompilationRequired = false;
    }
private:
    Techniques mTechniques;
    Techniques mSupportedTechniques;
    
    /// Compilation required
    /// This is set if the techniques change and the supportedness of techniques has to be
    /// re-evaluated.
    bool mCompilationRequired;
    
    /** Create global rendertextures.
     */
    void createGlobalTextures()
    {
        static size_t dummyCounter = 0;
        if (mSupportedTechniques.empty())
            return;
        
        //To make sure that we are consistent, it is demanded that all composition
        //techniques define the same set of global textures.
        
        //typedef std::set<string> stringSet;
        //stringSet globalTextureNames;
        string[] globalTextureNames;
        
        //Initialize global textures from first supported technique
        CompositionTechnique firstTechnique = mSupportedTechniques[0];
        
        auto texDefIt = firstTechnique.getTextureDefinitions();
        //while (texDefIt.hasMoreElements()) 
        foreach(def; texDefIt)
        {
            //CompositionTechnique.TextureDefinition* def = texDefIt.getNext();
            if (def._scope == CompositionTechnique.TextureScope.TS_GLOBAL) 
            {
                //Check that this is a legit global texture
                if (!def.refCompName.empty()) 
                {
                    throw new InvalidStateError(
                        "Global compositor texture definition can not be a reference",
                        "Compositor.createGlobalTextures");
                }
                if (def.width == 0 || def.height == 0) 
                {
                    throw new InvalidStateError(
                        "Global compositor texture definition must have absolute size",
                        "Compositor.createGlobalTextures");
                }
                if (def.pooled) 
                {
                    LogManager.getSingleton().logMessage(
                        "Pooling global compositor textures has no effect");
                }
                globalTextureNames.insert(def.name);
                
                //TODO GSOC : Heavy copy-pasting from CompositorInstance. How to we solve it?
                
                /// Make the texture
                RenderTarget rendTarget;
                if (def.formatList.length > 1)
                {
                    string MRTbaseName = std.conv.text("c", dummyCounter++, "/", mName, "/", def.name);
                    MultiRenderTarget mrt = 
                        Root.getSingleton().getRenderSystem().createMultiRenderTarget(MRTbaseName);
                    mGlobalMRTs[def.name] = mrt;
                    
                    // create and bind individual surfaces
                    size_t atch = 0;
                    foreach (p; def.formatList)
                    {
                        string texname = MRTbaseName ~ "/" ~ std.conv.to!string(atch);
                        SharedPtr!Texture tex = TextureManager.getSingleton().createManual(
                            texname, 
                            ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME, TextureType.TEX_TYPE_2D, 
                            cast(uint)def.width, cast(uint)def.height, 0, p, TextureUsage.TU_RENDERTARGET, null, 
                            def.hwGammaWrite && !PixelUtil.isFloatingPoint(p), def.fsaa); 
                        
                        RenderTexture rt = tex.getAs().getBuffer().get().getRenderTarget();
                        rt.setAutoUpdated(false);
                        mrt.bindSurface(atch, rt);
                        
                        // Also add to local textures so we can look up
                        string mrtLocalName = getMRTTexLocalName(def.name, atch);
                        mGlobalTextures[mrtLocalName] = tex;
                        ++atch;
                    }
                    
                    rendTarget = mrt;
                }
                else
                {
                    string texName =  std.conv.text("c", dummyCounter++, "/", mName, "/", def.name);
                    
                    // space in the name mixup the cegui in the compositor demo
                    // this is an auto generated name - so no spaces can't hurt us.
                    texName = texName.replace(" ", "_" );
                    
                    SharedPtr!Texture tex = TextureManager.getSingleton().createManual(
                        texName, 
                        ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME, TextureType.TEX_TYPE_2D, 
                        cast(uint)def.width, cast(uint)def.height, 0, def.formatList[0], TextureUsage.TU_RENDERTARGET, null,
                        def.hwGammaWrite && !PixelUtil.isFloatingPoint(def.formatList[0]), def.fsaa); 
                    
                    
                    rendTarget = tex.getAs().getBuffer().get().getRenderTarget();
                    mGlobalTextures[def.name] = tex;
                }
                
                //Set DepthBuffer pool for sharing
                rendTarget.setDepthBufferPool( def.depthBufferId );
            }
        }
        
        //Validate that all other supported techniques expose the same set of global textures.
        for (size_t i=1; i<mSupportedTechniques.length; i++)
        {
            CompositionTechnique technique = mSupportedTechniques[i];
            bool isConsistent = true;
            size_t numGlobals = 0;
            texDefIt = technique.getTextureDefinitions();
            //while (texDefIt.hasMoreElements()) 
            foreach(texDef; texDefIt)
            {
                //CompositionTechnique.TextureDefinition texDef = texDefIt.getNext();
                if (texDef._scope == CompositionTechnique.TextureScope.TS_GLOBAL) 
                {
                    if (!globalTextureNames.inArray(texDef.name))
                    {
                        isConsistent = false;
                        break;
                    }
                    numGlobals++;
                }
            }
            if (numGlobals != globalTextureNames.length)
                isConsistent = false;
            
            if (!isConsistent) 
            {
                throw new InvalidStateError(
                    "Different composition techniques define different global textures",
                    "Compositor.createGlobalTextures");
            }
            
        }
        
    }
    
    /** Destroy global rendertextures.
     */
    void freeGlobalTextures()//TODO iterator invalidation? shouldn't crash, just takes longer
    {
        foreach (k,v; mGlobalTextures)
        {
            TextureManager.getSingleton().remove(v.get().getName());
        }

        mGlobalTextures.clear();

        foreach (k,v; mGlobalMRTs)
        {
            // remove MRT
            Root.getSingleton().getRenderSystem().destroyRenderTarget(v.getName());
        }
        mGlobalMRTs.clear();
        
    }

    //TODO GSOC : These typedefs are duplicated from CompositorInstance. Solve?
    /// Map from name.local texture
    //typedef map<string,SharedPtr!Texture>::type GlobalTextureMap;
    alias SharedPtr!Texture[string] GlobalTextureMap;
    GlobalTextureMap mGlobalTextures;
    /// Store a list of MRTs we've created
    //typedef map<string,MultiRenderTarget*>::type GlobalMRTMap;
    alias MultiRenderTarget[string] GlobalMRTMap;
    GlobalMRTMap mGlobalMRTs;
}

//alias SharedPtr!Compositor CompositorPtr;

enum /*size_t error*/ RENDER_QUEUE_COUNT = RenderQueueGroupID.RENDER_QUEUE_MAX+1;       

/** An instance of a Compositor object for one Viewport. It is part of the CompositorChain
 for a Viewport.
 */
class CompositorInstance //: public CompositorInstAlloc
{
public:
    this(CompositionTechnique technique, CompositorChain chain)
    {
        mCompositor = technique.getParent();
        mTechnique = technique;
        mChain = chain;
        mEnabled = false;
        mAlive = false;

        mEnabled = false;
        string logicName = mTechnique.getCompositorLogicName();
        if (!logicName.empty())
        {
            CompositorManager.getSingleton().
                getCompositorLogic(logicName).compositorInstanceCreated(this);
        }
    }
    ~this()
    {
        string logicName = mTechnique.getCompositorLogicName();
        if (!logicName.empty())
        {
            CompositorManager.getSingleton().
                getCompositorLogic(logicName).compositorInstanceDestroyed(this);
        }
        
        freeResources(false, true);
    }
    /** Provides an interface to "listen in" to to render system operations executed by this 
     CompositorInstance.
     */
    interface Listener
    {
        /** Notification of when a render target operation involving a material (like
         rendering a quad) is compiled, so that miscellaneous parameters that are different
         per Compositor instance can be set up.
         @param pass_id
         Pass identifier within Compositor instance, this is specified 
         by the user by CompositionPass.setIdentifier().
         @param mat
         Material, this may be changed at will and will only affect
         the current instance of the Compositor, not the global material
         it was cloned from.
         */
        void notifyMaterialSetup(uint pass_id, SharedPtr!Material mat);
        
        /** Notification before a render target operation involving a material (like
         rendering a quad), so that material parameters can be varied.
         @param pass_id
         Pass identifier within Compositor instance, this is specified 
         by the user by CompositionPass.setIdentifier().
         @param mat
         Material, this may be changed at will and will only affect
         the current instance of the Compositor, not the global material
         it was cloned from.
         */
        void notifyMaterialRender(uint pass_id, SharedPtr!Material mat);
        
        /** Notification after resources have been created (or recreated).
         @param forResizeOnly
         Was the creation because the viewport was resized?
         */
        void notifyResourcesCreated(bool forResizeOnly);   
    }

    /** Specific render system operation. A render target operation does special operations
     between render queues like rendering a quad, clearing the frame buffer or 
     setting stencil state.
     */
    interface RenderSystemOperation //: public CompositorInstAlloc
    {
        /// Set state to SceneManager and RenderSystem
        void execute(SceneManager sm, RenderSystem rs);
    }

    //typedef map<int, SharedPtr!Material>::type QuadMaterialMap;
    //typedef std::pair<int, RenderSystemOperation*> RenderSystemOpPair;
    //typedef vector<RenderSystemOpPair>::type RenderSystemOpPairs;

    alias SharedPtr!Material[int] QuadMaterialMap;
    alias pair!(int, RenderSystemOperation) RenderSystemOpPair;
    alias RenderSystemOpPair[] RenderSystemOpPairs;

    /** Operation setup for a RenderTarget (collected).
     */
    static class TargetOperation
    {
    public:
        this()
        { 
        }
        this(RenderTarget inTarget)
        { 
            target = inTarget;
            currentQueueGroupID = 0;
            visibilityMask = 0xFFFFFFFF;
            lodBias = 1.0f;
            onlyInitial = false;
            hasBeenRendered = false;
            findVisibleObjects = false;
            materialScheme = MaterialManager.DEFAULT_SCHEME_NAME;
            shadowsEnabled = true;
        }
        /// Target
        RenderTarget target;
        
        /// Current group ID
        int currentQueueGroupID;
        
        /// RenderSystem operations to queue into the scene manager, by uint8
        RenderSystemOpPairs renderSystemOperations;
        
        /// Scene visibility mask
        /// If this is 0, the scene is not rendered at all
        uint visibilityMask;
        
        /// LOD offset. This is multiplied with the camera LOD offset
        /// 1.0 is default, lower means lower detail, higher means higher detail
        float lodBias;
        
        /** A set of render queues to either include or exclude certain render queues.
         */
        //typedef std::bitset<RenderQueueGroupID.RENDER_QUEUE_COUNT> RenderQueueBitSet;
        //alias Bitset!RENDER_QUEUE_COUNT RenderQueueBitSet;
        alias Bitset!106 RenderQueueBitSet; //FIXME CTFE error with RENDER_QUEUE_COUNT?
        
        /// Which renderqueues to render from scene
        RenderQueueBitSet renderQueues;
        //Bitset!RENDER_QUEUE_COUNT renderQueues;
        
        /** @see CompositionTargetPass::mOnlyInitial
         */
        bool onlyInitial;
        /** "Has been rendered" flag; used in combination with
         onlyInitial to determine whether to skip this target operation.
         */
        bool hasBeenRendered;
        /** Whether this op needs to find visible scene objects or not 
         */
        bool findVisibleObjects;
        /** Which material scheme this op will use */
        string materialScheme;
        /** Whether shadows will be enabled */
        bool shadowsEnabled;
    }

    //typedef vector<TargetOperation>::type CompiledState;
    alias TargetOperation[] CompiledState;
    
    /** Set enabled flag. The compositor instance will only render if it is
     enabled, otherwise it is pass-through. Resources are only created if
     they weren't alive when enabling.
     */
    void setEnabled(bool value)
    {
        if (mEnabled != value)
        {
            mEnabled = value;
            
            //Probably first time enabling, create resources.
            if( mEnabled && !mAlive )
                setAlive( true );
            
            /// Notify chain state needs recompile.
            mChain._markDirty();
        }
    }
    
    /** Get enabled flag.
     */
    bool getEnabled(){ return mEnabled; }
    
    /** Set alive/active flag. The compositor instance will create resources when alive,
     and destroy them when inactive.
     @remarks
     Killing an instance means also disabling it: setAlive(false) implies
     setEnabled(false)
     */
    void setAlive(bool value)
    {
        if (mAlive != value)
        {
            mAlive = value;
            
            // Create of free resource.
            if (value)
            {
                createResources(false);
            }
            else
            {
                freeResources(false, true);
                setEnabled(false);
            }
            
            /// Notify chain state needs recompile.
            mChain._markDirty();
        }
    }
    
    /** Get alive flag.
     */
    bool getAlive(){ return mAlive; }
    
    /** Get the instance name for a local texture.
     @note It is only valid to call this when local textures have been loaded, 
     which in practice means that the compositor instance is active. Calling
     it at other times will cause an exception. Note that since textures
     are cleaned up aggressively, this name is not guaranteed to stay the
     same if you disable and re-enable the compositor instance.
     @param name
     The name of the texture in the original compositor definition.
     @param mrtIndex
     If name identifies a MRT, which texture attachment to retrieve.
     @return
     The instance name for the texture, corresponds to a real texture.
     */
    string getTextureInstanceName(string name, size_t mrtIndex)
    {
        return getSourceForTex(name, mrtIndex);
    }
    
    /** Get the instance of a local texture.
     @note Textures are only valid when local textures have been loaded, 
     which in practice means that the compositor instance is active. Calling
     this method at other times will return null pointers. Note that since textures
     are cleaned up aggressively, this pointer is not guaranteed to stay the
     same if you disable and re-enable the compositor instance.
     @param name
     The name of the texture in the original compositor definition.
     @param mrtIndex
     If name identifies a MRT, which texture attachment to retrieve.
     @return
     The texture pointer, corresponds to a real texture.
     */
    SharedPtr!Texture getTextureInstance(string name, size_t mrtIndex)
    {
        // try simple textures first
        auto i = name in mLocalTextures;
        if(i !is null)
        {
            return *i;
        }
        
        // try MRTs - texture (rather than target)
        i = getMRTTexLocalName(name, mrtIndex) in mLocalTextures;
        if (i !is null)
        {
            return *i;
        }
        
        // not present
        return SharedPtr!Texture();
        
    }
    
    /** Get the render target for a given render texture name. 
     @remarks
     You can use this to add listeners etc, but do not use it to update the
     targets manually or any other modifications, the compositor instance 
     is in charge of this.
     */
    RenderTarget getRenderTarget(string name)
    {
        return getTargetForTex(name);
    }
    
    
    /** Recursively collect target states (except for final Pass).
     @param compiledState
     This vector will contain a list of TargetOperation objects.
     */
    void _compileTargetOperations(CompiledState compiledState)
    {
        /// Collect targets of previous state
        if(mPreviousInstance)
            mPreviousInstance._compileTargetOperations(compiledState);
        /// Texture targets
        auto it = mTechnique.getTargetPasses();
        foreach(target; it)
        {
            //CompositionTargetPass *target = it.getNext();
            
            auto ts = new TargetOperation(getTargetForTex(target.getOutputName()));
            /// Set "only initial" flag, visibilityMask and lodBias according to CompositionTargetPass.
            ts.onlyInitial = target.getOnlyInitial();
            ts.visibilityMask = target.getVisibilityMask();
            ts.lodBias = target.getLodBias();
            ts.shadowsEnabled = target.getShadowsEnabled();
            ts.materialScheme = target.getMaterialScheme();
            /// Check for input mode previous
            if(target.getInputMode() == CompositionTargetPass.InputMode.IM_PREVIOUS)
            {
                /// Collect target state for previous compositor
                /// The TargetOperation for the final target is collected separately as it is merged
                /// with later operations
                mPreviousInstance._compileOutputOperation(ts);
            }
            /// Collect passes of our own target
            collectPasses(ts, target);
            compiledState.insert(ts);
        }
    }
    
    /** Compile the final (output) operation. This is done separately because this
     is combined with the input in chained filters.
     */
    void _compileOutputOperation(TargetOperation finalState)
    {
        /// Final target
        CompositionTargetPass tpass = mTechnique.getOutputTargetPass();
        
        /// Logical-and together the visibilityMask, and multiply the lodBias
        finalState.visibilityMask &= tpass.getVisibilityMask();
        finalState.lodBias *= tpass.getLodBias();
        finalState.materialScheme = tpass.getMaterialScheme();
        finalState.shadowsEnabled = tpass.getShadowsEnabled();
        
        if(tpass.getInputMode() == CompositionTargetPass.InputMode.IM_PREVIOUS)
        {
            /// Collect target state for previous compositor
            /// The TargetOperation for the final target is collected separately as it is merged
            /// with later operations
            mPreviousInstance._compileOutputOperation(finalState);
        }
        /// Collect passes
        collectPasses(finalState, tpass);
    }
    
    /** Get Compositor of which this is an instance
     */
    Compositor getCompositor()
    {
        return mCompositor;
    }
    
    /** Get CompositionTechnique used by this instance
     */
    CompositionTechnique getTechnique()
    {
        return mTechnique;
    }
    
    /** Change the technique we're using to render this compositor. 
     @param tech
     The technique to use (must be supported and from the same Compositor)
     @param reuseTextures
     If textures have already been created for the current
     technique, whether to try to re-use them if sizes & formats match.
     */
    void setTechnique(CompositionTechnique tech, bool reuseTextures = true)
    {
        if (mTechnique != tech)
        {
            if (reuseTextures)
            {
                // make sure we store all (shared) textures in use in our reserve pool
                // this will ensure they don't get destroyed as unreferenced
                // so they're ready to use again later
                auto it = mTechnique.getTextureDefinitions();
                CompositorManager.UniqueTextureSet assignedTextures;
                foreach(def; it)
                {
                    //CompositionTechnique::TextureDefinition *def = it.getNext();
                    if (def.pooled)
                    {
                        auto i = def.name in mLocalTextures;
                        if (i !is null)
                        {
                            // overwriting duplicates is fine, we only want one entry per def
                            mReserveTextures[def] = *i;
                        }
                        
                    }
                }
            }
            // replace technique
            mTechnique = tech;
            
            if (mAlive)
            {
                // free up resources, but keep reserves if reusing
                freeResources(false, !reuseTextures);
                createResources(false);
                /// Notify chain state needs recompile.
                mChain._markDirty();
            }
            
        }
    }
    
    /** Pick a technique to use to render this compositor based on a scheme. 
     @remarks
     If there is no specific supported technique with this scheme name, 
     then the first supported technique with no specific scheme will be used.
     @see CompositionTechnique::setSchemeName
     @param schemeName
     The scheme to use 
     @param reuseTextures
     If textures have already been created for the current
     technique, whether to try to re-use them if sizes & formats match.
     Note that for this feature to be of benefit, the textures must have been created
     with the 'pooled' option enabled.
     */
    void setScheme(string schemeName, bool reuseTextures = true)
    {
        CompositionTechnique tech = mCompositor.getSupportedTechnique(schemeName);
        if (tech)
        {
            setTechnique(tech, reuseTextures);
        }
    }
    
    /// Returns the name of the scheme this compositor is using.
    string getScheme(){ return mTechnique ? mTechnique.getSchemeName() : null; }
    
    /** Notify this instance that the primary surface has been resized. 
     @remarks
     This will allow the instance to recreate its resources that 
     are dependent on the size. 
     */
    void notifyResized()
    {
        freeResources(true, true);
        createResources(true);
    }
    
    /** Get Chain that this instance is part of
     */
    CompositorChain getChain()
    {
        return mChain;
    }
    
    /** Add a listener. Listeners provide an interface to "listen in" to to render system 
     operations executed by this CompositorInstance so that materials can be 
     programmatically set up.
     @see CompositorInstance::Listener
     */
    void addListener(Listener l)
    {
        mListeners.insert(l);
    }

    /** Remove a listener.
     @see CompositorInstance::Listener
     */
    void removeListener(Listener l)
    {
        mListeners.removeFromArray(l);
    }
    
    /** Notify listeners of a material compilation.
     */
    void _fireNotifyMaterialSetup(uint pass_id, SharedPtr!Material mat)
    {
        foreach(i; mListeners)
            i.notifyMaterialSetup(pass_id, mat);
    }
    
    /** Notify listeners of a material render.
     */
    void _fireNotifyMaterialRender(uint pass_id, SharedPtr!Material mat)
    {
        foreach(i; mListeners)
            i.notifyMaterialRender(pass_id, mat);
    }
    
    /** Notify listeners of a material render.
     */
    void _fireNotifyResourcesCreated(bool forResizeOnly)
    {
        foreach(i; mListeners)
            i.notifyResourcesCreated(forResizeOnly);
    }

private:
    /// Compositor of which this is an instance.
    Compositor mCompositor;
    /// Composition technique used by this instance.
    CompositionTechnique mTechnique;
    /// Composition chain of which this instance is part.
    CompositorChain mChain;
    /// Is this instance enabled?
    bool mEnabled;
    /// Is this instance allocating resources?
    bool mAlive;
    /// Map from name.local texture.
    //typedef map<string,SharedPtr!Texture>::type LocalTextureMap;
    alias SharedPtr!Texture[string] LocalTextureMap;
    LocalTextureMap mLocalTextures;
    /// Store a list of MRTs we've created.
    //typedef map<string,MultiRenderTarget*>::type LocalMRTMap;
    alias MultiRenderTarget[string] LocalMRTMap;
    LocalMRTMap mLocalMRTs;
    //typedef map<CompositionTechnique::TextureDefinition*, SharedPtr!Texture>::type ReserveTextureMap;
    alias SharedPtr!Texture[CompositionTechnique.TextureDefinition] ReserveTextureMap;
    /** Textures that are not currently in use, but that we want to keep for now,
     for example if we switch techniques but want to keep all textures available
     in case we switch back. 
     */
    ReserveTextureMap mReserveTextures;
    
    /// Vector of listeners.
    //typedef vector<Listener*>::type Listeners;
    alias Listener[] Listeners;
    Listeners mListeners;
    
    /// Previous instance (set by chain).
    CompositorInstance mPreviousInstance;
    
    /** Collect rendering passes. Here, passes are converted into render target operations
     and queued with queueRenderSystemOp.
     */
    void collectPasses(TargetOperation finalState, CompositionTargetPass target)
    {
        /// Here, passes are converted into render target operations
        Pass targetpass;
        Technique srctech;
        SharedPtr!Material mat, srcmat;
        
        auto it = target.getPasses();
        foreach(pass; it)
        {
            //CompositionPass *pass = it.getNext();
            final switch(pass.getType())
            {
                case CompositionPass.PassType.PT_CLEAR:
                    queueRenderSystemOp(finalState, new RSClearOperation(
                    pass.getClearBuffers(),
                    pass.getClearColour(),
                    pass.getClearDepth(),
                    cast(ushort)pass.getClearStencil()
                    ));
                    break;
                case CompositionPass.PassType.PT_STENCIL:
                    queueRenderSystemOp(finalState, new RSStencilOperation(
                    pass.getStencilCheck(),pass.getStencilFunc(), pass.getStencilRefValue(),
                    pass.getStencilMask(), pass.getStencilFailOp(), pass.getStencilDepthFailOp(),
                    pass.getStencilPassOp(), pass.getStencilTwoSidedOperation()
                    ));
                    break;
                case CompositionPass.PassType.PT_RENDERSCENE: 
                {
                    if(pass.getFirstRenderQueue() < finalState.currentQueueGroupID)
                    {
                        /// Mismatch -- warn user
                        /// XXX We could support repeating the last queue, with some effort
                        LogManager.getSingleton().logMessage("Warning in compilation of Compositor "
                                                             ~mCompositor.getName()~": Attempt to render queue "~
                                                             std.conv.to!string(pass.getFirstRenderQueue())~" before "~
                                                             std.conv.to!string(finalState.currentQueueGroupID));
                    }
                    
                    RSSetSchemeOperation setSchemeOperation;
                    if (pass.getMaterialScheme() !is null)
                    {
                        //Add the triggers that will set the scheme and restore it each frame
                        finalState.currentQueueGroupID = pass.getFirstRenderQueue();
                        setSchemeOperation = new RSSetSchemeOperation(pass.getMaterialScheme());
                        queueRenderSystemOp(finalState, setSchemeOperation);
                    }
                    
                    /// Add render queues
                    for(int x=pass.getFirstRenderQueue(); x<=pass.getLastRenderQueue(); ++x)
                    {
                        assert(x>=0);
                        finalState.renderQueues.set(x);
                    }
                    finalState.currentQueueGroupID = pass.getLastRenderQueue()+1;
                    
                    if (setSchemeOperation !is null)
                    {
                        //Restoring the scheme after the queues have been rendered
                        queueRenderSystemOp(finalState, 
                                            new RSRestoreSchemeOperation(setSchemeOperation));
                    }
                    
                    finalState.findVisibleObjects = true;
                    
                    break;
                }
                case CompositionPass.PassType.PT_RENDERQUAD: {
                    srcmat = pass.getMaterial();
                    if(srcmat.isNull())
                    {
                        /// No material -- warn user
                        LogManager.getSingleton().logMessage("Warning in compilation of Compositor "
                                                             ~ mCompositor.getName() ~
                                                             ": No material defined for composition pass");
                        break;
                    }
                    srcmat.get().load();
                    if(srcmat.getAs().getNumSupportedTechniques()==0)  
                    {
                        /// No supported techniques -- warn user
                        LogManager.getSingleton().logMessage("Warning in compilation of Compositor "
                                                             ~mCompositor.getName() ~ 
                                                             ": material " ~ srcmat.get().getName() ~ " has no supported techniques");
                        break;
                    }
                    srctech = srcmat.getAs().getBestTechnique(0);
                    /// Create local material
                    SharedPtr!Material localMat = createLocalMaterial(srcmat.get().getName());
                    /// Copy and adapt passes from source material
                    auto i = srctech.getPasses();
                    foreach(srcpass; i)
                    {
                        //Pass *srcpass = i.getNext();
                        /// Create new target pass
                        targetpass = localMat.getAs().getTechnique(0).createPass();
                        //(*targetpass) = (*srcpass); //FIXME some copy/paste voodoo juju going on here
                        targetpass.copyFrom(srcpass);

                        /// Set up inputs
                        for(size_t x=0; x<pass.getNumInputs(); ++x)
                        {
                            CompositionPass.InputTex inp = pass.getInput(x);
                            if(!inp.name.empty())
                            {
                                if(x < targetpass.getNumTextureUnitStates())
                                {
                                    targetpass.getTextureUnitState(cast(ushort)x).setTextureName(getSourceForTex(inp.name, inp.mrtIndex));
                                } 
                                else
                                {
                                    /// Texture unit not there
                                    LogManager.getSingleton().logMessage("Warning in compilation of Compositor "
                                                                         ~ mCompositor.getName() ~ ": material " 
                                                                         ~ srcmat.get().getName() ~ " texture unit "
                                                                         ~ std.conv.to!string(x) ~ " out of bounds");
                                }
                            }
                        }
                    }
                    
                    RSQuadOperation rsQuadOperation = new RSQuadOperation(this,pass.getIdentifier(),localMat);
                    Real left,top,right,bottom;
                    if (pass.getQuadCorners(left,top,right,bottom))
                        rsQuadOperation.setQuadCorners(left,top,right,bottom);
                    rsQuadOperation.setQuadFarCorners(pass.getQuadFarCorners(), pass.getQuadFarCornersViewSpace());
                    
                    queueRenderSystemOp(finalState,rsQuadOperation);
                }
                    break;
                case CompositionPass.PassType.PT_RENDERCUSTOM:
                    RenderSystemOperation customOperation = CompositorManager.getSingleton().
                        getCustomCompositionPass(pass.getCustomType()).createOperation(this, pass);
                    queueRenderSystemOp(finalState, customOperation);
                    break;
            }
        }
    }
    
    /** Create a local dummy material with one technique but no passes.
     The material is detached from the Material Manager to make sure it is destroyed
     when going out of scope.
     */
    SharedPtr!Material createLocalMaterial(string srcName)
    {
        static size_t dummyCounter = 0;
        SharedPtr!Material mat = 
            cast(SharedPtr!Material)MaterialManager.getSingleton().create(
                std.conv.text("c", dummyCounter, "/", srcName),
                ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME
                );
        ++dummyCounter;
        /// This is safe, as we hold a private reference
        /// XXX does not compile due to SharedPtr!Resource conversion :
        ///     MaterialManager::getSingleton().remove(mat);
        MaterialManager.getSingleton().remove(mat.get().getName());
        /// Remove all passes from first technique
        mat.getAs().getTechnique(0).removeAllPasses();
        return mat;
    }
    
    /** Create local rendertextures and other resources. Builds mLocalTextures.
     */
    void createResources(bool forResizeOnly)
    {
        static size_t dummyCounter = 0;
        /// Create temporary textures
        /// In principle, temporary textures could be shared between multiple viewports
        /// (CompositorChains). This will save a lot of memory in case more viewports
        /// are composited.
        auto it = mTechnique.getTextureDefinitions();
        CompositorManager.UniqueTextureSet assignedTextures;
        foreach(def; it)
        {
            //CompositionTechnique::TextureDefinition *def = it.getNext();
            
            if (!def.refCompName.empty()) {
                //This is a reference, isn't created in this compositor
                continue;
            }
            
            RenderTarget rendTarget;
            if (def._scope == CompositionTechnique.TextureScope.TS_GLOBAL)
            {
                //This is a global texture, just link the created resources from the parent
                Compositor parentComp = mTechnique.getParent();
                if (def.formatList.length > 1) 
                {
                    size_t atch = 0;
                    foreach (p; def.formatList)
                    {
                        SharedPtr!Texture tex = parentComp.getTextureInstance(def.name, atch);
                        mLocalTextures[getMRTTexLocalName(def.name, atch)] = tex;
                        ++atch;
                    }
                    MultiRenderTarget mrt = cast(MultiRenderTarget)(parentComp.getRenderTarget(def.name));
                    mLocalMRTs[def.name] = mrt;
                    rendTarget = mrt;
                } 
                else 
                {
                    SharedPtr!Texture tex = parentComp.getTextureInstance(def.name, 0);
                    mLocalTextures[def.name] = tex;
                    rendTarget = tex.getAs().getBuffer().get().getRenderTarget();
                }
                
            } 
            else 
            {
                /// Determine width and height
                size_t width = def.width;
                size_t height = def.height;
                uint fsaa = 0;
                string fsaaHint;
                bool hwGamma = false;
                
                // Skip this one if we're only (re)creating for a resize & it's not derived
                // from the target size
                if (forResizeOnly && width != 0 && height != 0)
                    continue;
                
                deriveTextureRenderTargetOptions(def.name, hwGamma, fsaa, fsaaHint);
                
                if(width == 0)
                    width = cast(size_t)(cast(float)(mChain.getViewport().getActualWidth()) * def.widthFactor);
                if(height == 0)
                    height = cast(size_t)(cast(float)(mChain.getViewport().getActualHeight()) * def.heightFactor);
                
                // determine options as a combination of selected options and possible options
                if (!def.fsaa)
                {
                    fsaa = 0;
                    fsaaHint = null;
                }
                hwGamma = hwGamma || def.hwGammaWrite;
                
                /// Make the tetxure
                if (def.formatList.length > 1)
                {
                    string MRTbaseName = std.conv.text("c", dummyCounter++, "/", def.name, "/", 
                                                       mChain.getViewport().getTarget().getName());
                    MultiRenderTarget mrt = 
                        Root.getSingleton().getRenderSystem().createMultiRenderTarget(MRTbaseName);
                    mLocalMRTs[def.name] = mrt;
                    
                    // create and bind individual surfaces
                    size_t atch = 0;
                    foreach (p; def.formatList)
                    {
                        
                        string texname = std.conv.text(MRTbaseName, "/", atch);
                        string mrtLocalName = getMRTTexLocalName(def.name, atch);
                        SharedPtr!Texture tex;
                        if (def.pooled)
                        {
                            // get / create pooled texture
                            tex = CompositorManager.getSingleton().getPooledTexture(texname,
                                                                                    mrtLocalName, 
                                                                                    width, height, p, fsaa, fsaaHint,  
                                                                                    hwGamma && !PixelUtil.isFloatingPoint(p), 
                                                                                    assignedTextures, this, def._scope);
                        }
                        else
                        {
                            tex = TextureManager.getSingleton().createManual(
                                texname, 
                                ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME, TextureType.TEX_TYPE_2D, 
                                cast(uint)width, cast(uint)height, 0, p, TextureUsage.TU_RENDERTARGET, null, 
                                hwGamma && !PixelUtil.isFloatingPoint(p), fsaa, fsaaHint ); 
                        }
                        
                        RenderTexture rt = tex.getAs().getBuffer().get().getRenderTarget();
                        rt.setAutoUpdated(false);
                        mrt.bindSurface(atch, rt);
                        
                        // Also add to local textures so we can look up
                        mLocalTextures[mrtLocalName] = tex;
                        ++atch;
                    }
                    
                    rendTarget = mrt;
                }
                else
                {
                    string texName =  std.conv.text("c", dummyCounter++, "/", def.name, "/",
                                                    mChain.getViewport().getTarget().getName());
                    
                    // space in the name mixup the cegui in the compositor demo
                    // this is an auto generated name - so no spaces can't hart us.
                    texName = texName.replace(" ", "_" );
                    
                    SharedPtr!Texture tex;
                    if (def.pooled)
                    {
                        // get / create pooled texture
                        tex = CompositorManager.getSingleton().getPooledTexture(texName, 
                                                                                def.name, width, height, def.formatList[0], fsaa, fsaaHint,
                                                                                hwGamma && !PixelUtil.isFloatingPoint(def.formatList[0]), assignedTextures, 
                                                                                this, def._scope);
                    }
                    else
                    {
                        tex = TextureManager.getSingleton().createManual(
                            texName, 
                            ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME, TextureType.TEX_TYPE_2D, 
                            cast(uint)width, cast(uint)height, 0, def.formatList[0], TextureUsage.TU_RENDERTARGET, null,
                            hwGamma && !PixelUtil.isFloatingPoint(def.formatList[0]), fsaa, fsaaHint); 
                    }
                    
                    rendTarget = tex.getAs().getBuffer().get().getRenderTarget();
                    mLocalTextures[def.name] = tex;
                }
            }
            
            //Set DepthBuffer pool for sharing
            rendTarget.setDepthBufferPool( def.depthBufferId );
            
            /// Set up viewport over entire texture
            rendTarget.setAutoUpdated( false );
            
            // We may be sharing / reusing this texture, so test before adding viewport
            if (rendTarget.getNumViewports() == 0)
            {
                Viewport v;
                Camera camera = mChain.getViewport().getCamera();
                if (!camera)
                {
                    v = rendTarget.addViewport( camera );
                }
                else
                {
                    // Save last viewport and current aspect ratio
                    Viewport oldViewport = camera.getViewport();
                    Real aspectRatio = camera.getAspectRatio();
                    
                    v = rendTarget.addViewport( camera );
                    
                    // Should restore aspect ratio, in case of auto aspect ratio
                    // enabled, it'll changed when add new viewport.
                    camera.setAspectRatio(aspectRatio);
                    // Should restore last viewport, i.e. never disturb user code
                    // which might based on that.
                    camera._notifyViewport(oldViewport);
                }
                
                v.setClearEveryFrame( false );
                v.setOverlaysEnabled( false );
                v.setBackgroundColour( ColourValue( 0, 0, 0, 0 ) );
            }
        }
        
        _fireNotifyResourcesCreated(forResizeOnly);
    }
    
    /** Destroy local rendertextures and other resources.
     */
    void freeResources(bool forResizeOnly, bool clearReserveTextures)
    {
        // Remove temporary textures 
        // We only remove those that are not shared, shared textures are dealt with
        // based on their reference count.
        // We can also only free textures which are derived from the target size, if
        // required (saves some time & memory thrashing / fragmentation on resize)
        
        auto it = mTechnique.getTextureDefinitions();
        CompositorManager.UniqueTextureSet assignedTextures;
        foreach(def; it)
        {
            //CompositionTechnique::TextureDefinition *def = it.getNext();
            
            if (!def.refCompName.empty())
            {
                //This is a reference, isn't created here
                continue;
            }
            
            // potentially only remove this one if based on size
            if (!forResizeOnly || def.width == 0 || def.height == 0)
            {
                size_t subSurf = def.formatList.length;
                
                // Potentially many surfaces
                for (size_t s = 0; s < subSurf; ++s)
                {
                    string texName = subSurf > 1 ? getMRTTexLocalName(def.name, s)
                        : def.name;
                    
                    auto i = texName in mLocalTextures;
                    if (i !is null)
                    {
                        if (!def.pooled && def._scope != CompositionTechnique.TextureScope.TS_GLOBAL)
                        {
                            // remove myself from central only if not pooled and not global
                            TextureManager.getSingleton().remove(i.get().getName());
                        }
                        
                        // remove from local
                        // reserves are potentially cleared later
                        mLocalTextures.remove(texName);
                        
                    }
                    
                } // subSurf
                
                if (subSurf > 1)
                {
                    auto mrti = def.name in mLocalMRTs;
                    if (mrti !is null)
                    {
                        if (def._scope != CompositionTechnique.TextureScope.TS_GLOBAL) 
                        {
                            // remove MRT if not global
                            Root.getSingleton().getRenderSystem().destroyRenderTarget(mrti.getName());
                        }
                        
                        mLocalMRTs.remove(def.name);
                    }
                    
                }
                
            } // not for resize or width/height 0
        }
        
        if (clearReserveTextures)
        {
            if (forResizeOnly)
            {
                // just remove the ones which would be affected by a resize
                foreach (k; mReserveTextures.keys)
                {
                    //auto v = mReserveTextures[k];
                    if (k.width == 0 || k.height == 0)
                    {
                        mReserveTextures.remove(k);
                    }
                }
            }
            else
            {
                // clear all
                mReserveTextures.clear();
            }
        }
        
        // Now we tell the central list of textures to check if its unreferenced, 
        // and to remove if necessary. Anything shared that was left in the reserve textures
        // will not be released here
        CompositorManager.getSingleton().freePooledTextures(true);
    }
    
    /** Get RenderTarget for a named local texture.
     */
    RenderTarget getTargetForTex(string name)
    {
        // try simple texture
        auto i = name in mLocalTextures;
        if(i !is null)
            return i.getAs().getBuffer().get().getRenderTarget();
        
        // try MRTs
        auto mi = name in mLocalMRTs;
        if (mi !is null)
            return *mi;
        
        //Try reference : Find the instance and check if it is before us
        auto texDef = mTechnique.getTextureDefinition(name);
        if (texDef !is null && !texDef.refCompName.empty()) 
        {
            //This TextureDefinition is reference.
            //Since referenced TD's have no info except name we have to find original TD
            
            CompositionTechnique.TextureDefinition refTexDef;
            
            //Try chain first
            if(mChain)
            {
                CompositorInstance refCompInst = mChain.getCompositor(texDef.refCompName);
                if(refCompInst)
                {
                    refTexDef = refCompInst.getCompositor().getSupportedTechnique(
                        refCompInst.getScheme()).getTextureDefinition(texDef.refTexName);
                    // if the texture with the reference name can not be found, try the name
                    if (refTexDef is null)
                    {
                        refTexDef = refCompInst.getCompositor().getSupportedTechnique(
                            refCompInst.getScheme()).getTextureDefinition(name);
                    }
                }
                else
                {
                    throw new ItemNotFoundError("Referencing non-existent compositor",
                                                "CompositorInstance.getTargetForTex");
                }
            }
            
            if(refTexDef is null)
            {
                //Still NULL. Try global search.
                SharedPtr!Compositor refComp = CompositorManager.getSingleton().getByName(texDef.refCompName);
                if(!refComp.isNull())
                {
                    refTexDef = refComp.getAs().getSupportedTechnique().getTextureDefinition(name);
                }
            }
            
            if(refTexDef is null)
            {
                //Still NULL
                throw new ItemNotFoundError("Referencing non-existent compositor texture",
                                            "CompositorInstance.getTargetForTex");
            }
            
            switch(refTexDef._scope) 
            {
                case CompositionTechnique.TextureScope.TS_CHAIN:
                {
                    //Find the instance and check if it is before us
                    CompositorInstance refCompInst;
                    auto it = mChain.getCompositors();
                    bool beforeMe = true;
                    foreach(nextCompInst; it)
                    {
                        if (nextCompInst.getCompositor().getName() == texDef.refCompName)
                        {
                            refCompInst = nextCompInst;
                            break;
                        }
                        if (nextCompInst == this)
                        {
                            //We encountered ourselves while searching for the compositor -
                            //we are earlier in the chain.
                            beforeMe = false;
                        }
                    }
                    
                    if (refCompInst is null || !refCompInst.getEnabled()) 
                    {
                        throw new InvalidStateError("Referencing inactive compositor texture",
                                                    "CompositorInstance.getTargetForTex");
                    }
                    if (!beforeMe)
                    {
                        throw new InvalidStateError("Referencing compositor that is later in the chain",
                                                    "CompositorInstance.getTargetForTex");
                    }
                    return refCompInst.getRenderTarget(texDef.refTexName);
                }
                case CompositionTechnique.TextureScope.TS_GLOBAL:
                {
                    //Chain and global case - the referenced compositor will know how to handle
                    SharedPtr!Compositor refComp = CompositorManager.getSingleton().getByName(texDef.refCompName);
                    if(refComp.isNull())
                    {
                        throw new ItemNotFoundError("Referencing non-existent compositor",
                                                    "CompositorInstance.getTargetForTex");
                    }
                    return refComp.getAs().getRenderTarget(texDef.refTexName);
                }
                case CompositionTechnique.TextureScope.TS_LOCAL:
                default:
                    throw new InvalidParamsError("Referencing local compositor texture",
                                                 "CompositorInstance.getTargetForTex");
            }
        }
        
        throw new InvalidParamsError("Non-existent local texture name", 
                                     "CompositorInstance.getTargetForTex");
        
    }
    
    /** Get source texture name for a named local texture.
     @param name
     The local name of the texture as given to it in the compositor.
     @param mrtIndex
     For MRTs, which attached surface to retrieve.
     */
    string getSourceForTex(string name, size_t mrtIndex = 0)
    {
        auto texDef = mTechnique.getTextureDefinition(name);
        if(texDef is null)
        {
            throw new ItemNotFoundError("Referencing non-existent TextureDefinition",
                                        "CompositorInstance.getSourceForTex");
        }
        
        //Check if texture definition is reference
        if(!texDef.refCompName.empty())
        {
            //This TextureDefinition is reference.
            //Since referenced TD's have no info except name we have to find original TD
            
            CompositionTechnique.TextureDefinition refTexDef;
            
            //Try chain first
            if(mChain)
            {
                CompositorInstance refCompInst = mChain.getCompositor(texDef.refCompName);
                if(refCompInst)
                {
                    refTexDef = refCompInst.getCompositor().
                        getSupportedTechnique(refCompInst.getScheme()).getTextureDefinition(texDef.refTexName);
                }
                else
                {
                    throw new ItemNotFoundError("Referencing non-existent compositor",
                                                "CompositorInstance.getSourceForTex");
                }
            }
            
            if(texDef is null)
            {
                //Still NULL. Try global search.
                SharedPtr!Compositor refComp = CompositorManager.getSingleton().getByName(texDef.refCompName);
                if(!refComp.isNull())
                {
                    refTexDef = refComp.getAs().getSupportedTechnique().getTextureDefinition(texDef.refTexName);
                }
            }
            
            if(texDef is null)
            {
                //Still NULL
                throw new ItemNotFoundError("Referencing non-existent compositor texture",
                                            "CompositorInstance.getSourceForTex");
            }
            
            switch(refTexDef._scope)
            {
                case CompositionTechnique.TextureScope.TS_CHAIN:
                {
                    //Find the instance and check if it is before us
                    CompositorInstance refCompInst;
                    auto it = mChain.getCompositors();
                    bool beforeMe = true;
                    foreach(nextCompInst; it)
                    {
                        if (nextCompInst.getCompositor().getName() == texDef.refCompName)
                        {
                            refCompInst = nextCompInst;
                            break;
                        }
                        if (nextCompInst == this)
                        {
                            //We encountered ourselves while searching for the compositor -
                            //we are earlier in the chain.
                            beforeMe = false;
                        }
                    }
                    
                    if (refCompInst is null || !refCompInst.getEnabled()) 
                    {
                        throw new InvalidStateError("Referencing inactive compositor texture",
                                                    "CompositorInstance.getSourceForTex");
                    }
                    if (!beforeMe)
                    {
                        throw new InvalidStateError("Referencing compositor that is later in the chain",
                                                    "CompositorInstance.getSourceForTex");
                    }
                    return refCompInst.getTextureInstanceName(texDef.refTexName, mrtIndex);
                }
                case CompositionTechnique.TextureScope.TS_GLOBAL:
                {
                    //Chain and global case - the referenced compositor will know how to handle
                    SharedPtr!Compositor refComp = CompositorManager.getSingleton().getByName(texDef.refCompName);
                    if(refComp.isNull())
                    {
                        throw new ItemNotFoundError("Referencing non-existent compositor",
                                                    "CompositorInstance.getSourceForTex");
                    }
                    return refComp.getAs().getTextureInstanceName(texDef.refTexName, mrtIndex);
                }
                case CompositionTechnique.TextureScope.TS_LOCAL:
                default:
                    throw new InvalidStateError("Referencing local compositor texture",
                                                "CompositorInstance.getSourceForTex");
            }
            
        } // End of handling texture references
        
        if (texDef.formatList.length == 1) 
        {
            //This is a simple texture
            auto i = name in mLocalTextures;
            if(i !is null)
            {
                return i.get().getName();
            }
        }
        else
        {
            // try MRTs - texture (rather than target)
            auto i = getMRTTexLocalName(name, mrtIndex) in mLocalTextures;
            if (i !is null)
            {
                return i.get().getName();
            }
        }
        
        throw new InvalidStateError("Non-existent local texture name", 
                                    "CompositorInstance.getSourceForTex");
    }

    /** Queue a render system operation.
     @return
     Destination pass.
     */
    void queueRenderSystemOp(TargetOperation finalState, RenderSystemOperation op)
    {
        /// Store operation for current QueueGroup ID
        finalState.renderSystemOperations.insert(RenderSystemOpPair(finalState.currentQueueGroupID, op));
        /// Tell parent for deletion
        mChain._queuedOperation(op);
    }
    
    /// Util method for assigning a local texture name to a MRT attachment
    string getMRTTexLocalName(string baseName, size_t attachment)
    {
        return std.conv.text(baseName, "/", attachment);
    }
    
    /** Search for options like AA and hardware gamma which we may want to 
     inherit from the main render target to which we're attached. 
     */
    void deriveTextureRenderTargetOptions(string texname, 
                                          ref bool hwGammaWrite, ref uint fsaa, ref string fsaaHint)
    {
        // search for passes on this texture def that either include a render_scene
        // or use input previous
        bool renderingScene = false;
        
        auto it = mTechnique.getTargetPasses();
        foreach(tp; it)
        {
            if (tp.getOutputName() == texname)
            {
                if (tp.getInputMode() == CompositionTargetPass.InputMode.IM_PREVIOUS)
                {
                    // this may be rendering the scene implicitly
                    // Can't check mPreviousInstance against mChain._getOriginalSceneCompositor()
                    // at this time, so check the position
                    auto instit = mChain.getCompositors();
                    renderingScene = true;
                    foreach(inst; instit)
                    {
                        if (inst == this)
                            break;
                        else if (inst.getEnabled())
                        {
                            // nope, we have another compositor before us, this will
                            // be doing the AA
                            renderingScene = false;
                        }
                    }
                    if (renderingScene)
                        break;
                }
                else
                {
                    // look for a render_scene pass
                    auto pit = tp.getPasses();
                    foreach(pass; pit)
                    {
                        if (pass.getType() == CompositionPass.PassType.PT_RENDERSCENE)
                        {
                            renderingScene = true;
                            break;
                        }
                    }
                }
                
            }
        }
        
        if (renderingScene)
        {
            // Ok, inherit settings from target
            RenderTarget target = mChain.getViewport().getTarget();
            hwGammaWrite = target.isHardwareGammaEnabled();
            fsaa = target.getFSAA();
            fsaaHint = target.getFSAAHint();
        }
        else
        {
            hwGammaWrite = false;
            fsaa = 0;
            fsaaHint = null;
        }
        
    }
    
    /// Notify this instance that the primary viewport's camera has changed.
    void notifyCameraChanged(Camera camera)
    {
        // update local texture's viewports.
        foreach(k,v; mLocalTextures)
        {
            RenderTexture target = v.getAs().getBuffer().get().getRenderTarget();
            // skip target that has no viewport (this means texture is under MRT)
            if (target.getNumViewports() == 1)
            {
                target.getViewport(0).setCamera(camera);
            }
        }
        
        // update MRT's viewports.
        foreach(k, target; mLocalMRTs)
        {
            target.getViewport(0).setCamera(camera);
        }
    }
    //friend class CompositorChain;
}

/** Clear framebuffer RenderSystem operation
 */
class RSClearOperation: CompositorInstance.RenderSystemOperation
{
public:
    this(uint inBuffers, ColourValue inColour, Real inDepth, ushort inStencil)
    {
        buffers = inBuffers;
        colour = inColour;
        depth = inDepth;
        stencil = inStencil;
    }
    /// Which buffers to clear (FrameBufferType)
    uint buffers;
    /// Colour to clear in case FBT_COLOUR is set
    ColourValue colour;
    /// Depth to set in case FBT_DEPTH is set
    Real depth;
    /// Stencil value to set in case FBT_STENCIL is set
    ushort stencil;
    
    void execute(SceneManager sm, RenderSystem rs)
    {
        rs.clearFrameBuffer(buffers, colour, depth, stencil);
    }
}

/** "Set stencil state" RenderSystem operation
 */
class RSStencilOperation: CompositorInstance.RenderSystemOperation
{
public:
    this(bool inStencilCheck, CompareFunction inFunc, uint inRefValue, uint inMask,
         StencilOperation inStencilFailOp, StencilOperation inDepthFailOp, StencilOperation inPassOp,
         bool inTwoSidedOperation)
    {
        stencilCheck = inStencilCheck;
        func = inFunc;
        refValue = inRefValue;
        mask = inMask;
        stencilFailOp = inStencilFailOp;
        depthFailOp = inDepthFailOp;
        passOp = inPassOp;
        twoSidedOperation = inTwoSidedOperation;
    }
    bool stencilCheck;
    CompareFunction func; 
    uint refValue;
    uint mask;
    StencilOperation stencilFailOp;
    StencilOperation depthFailOp;
    StencilOperation passOp;
    bool twoSidedOperation;
    
    void execute(SceneManager sm, RenderSystem rs)
    {
        rs.setStencilCheckEnabled(stencilCheck);
        rs.setStencilBufferParams(func, refValue, mask, 0xFFFFFFFF, stencilFailOp, depthFailOp, passOp, twoSidedOperation);
    }
}

/** "Render quad" RenderSystem operation
 */
class RSQuadOperation: CompositorInstance.RenderSystemOperation
{
public:
    this(CompositorInstance inInstance, uint inPass_id, SharedPtr!Material inMat)
    {
        mat = inMat;
        instance = inInstance;
        pass_id = inPass_id;
        mQuadCornerModified = false;
        mQuadFarCorners = false;
        mQuadFarCornersViewSpace = false;
        mQuadLeft = -1;
        mQuadTop = 1;
        mQuadRight = 1;
        mQuadBottom = -1;

        mat.get().load();
        instance._fireNotifyMaterialSetup(pass_id, mat);
        technique = mat.getAs().getTechnique(0);
        assert(technique);
    }
    SharedPtr!Material mat;
    Technique technique;
    CompositorInstance instance;
    uint pass_id;
    
    bool mQuadCornerModified, mQuadFarCorners, mQuadFarCornersViewSpace;
    Real mQuadLeft;
    Real mQuadTop;
    Real mQuadRight;
    Real mQuadBottom;
    
    void setQuadCorners(Real left,Real top,Real right,Real bottom)
    {
        mQuadLeft = left;
        mQuadTop = top;
        mQuadRight = right;
        mQuadBottom = bottom;
        mQuadCornerModified=true;
    }
    
    void setQuadFarCorners(bool farCorners, bool farCornersViewSpace)
    {
        mQuadFarCorners = farCorners;
        mQuadFarCornersViewSpace = farCornersViewSpace;
    }
    
    void execute(SceneManager sm, RenderSystem rs)
    {
        // Fire listener
        instance._fireNotifyMaterialRender(pass_id, mat);
        
        Viewport vp = rs._getViewport();
        Rectangle2D rect = cast(Rectangle2D)CompositorManager.getSingleton()._getTexturedRectangle2D();
        
        if (mQuadCornerModified)
        {
            // insure positions are using peculiar render system offsets 
            Real hOffset = rs.getHorizontalTexelOffset() / (0.5f * vp.getActualWidth());
            Real vOffset = rs.getVerticalTexelOffset() / (0.5f * vp.getActualHeight());
            rect.setCorners(mQuadLeft + hOffset, mQuadTop - vOffset, mQuadRight + hOffset, mQuadBottom - vOffset);
        }
        
        if(mQuadFarCorners)
        {
            Vector3[] corners = vp.getCamera().getWorldSpaceCorners();
            if(mQuadFarCornersViewSpace)
            {
                Matrix4 viewMat = vp.getCamera().getViewMatrix(true);
                rect.setNormals(viewMat*corners[5], viewMat*corners[6], viewMat*corners[4], viewMat*corners[7]);
            }
            else
            {
                rect.setNormals(corners[5], corners[6], corners[4], corners[7]);
            }
        }
        
        // Queue passes from mat
        auto passes = technique.getPasses();
        foreach(pass; passes)
        {
            sm._injectRenderWithPass(
                pass, 
                rect,
                false // don't allow replacement of shadow passes
                );
        }
    }
}

/** "Set material scheme" RenderSystem operation
 */
class RSSetSchemeOperation: CompositorInstance.RenderSystemOperation
{
public:
    this(string schemeName)
    {
        mPreviousLateResolving = false;
        mSchemeName = schemeName;
    }
    
    string mPreviousScheme;
    bool mPreviousLateResolving;
    
    string mSchemeName;
    
    void execute(SceneManager sm, RenderSystem rs)
    {
        MaterialManager matMgr = MaterialManager.getSingleton();
        mPreviousScheme = matMgr.getActiveScheme();
        matMgr.setActiveScheme(mSchemeName);
        
        mPreviousLateResolving = sm.isLateMaterialResolving();
        sm.setLateMaterialResolving(true);
    }
    
    string getPreviousScheme(){ return mPreviousScheme; }
    bool getPreviousLateResolving(){ return mPreviousLateResolving; }
}

/** Restore the settings changed by the set scheme operation */
class RSRestoreSchemeOperation: CompositorInstance.RenderSystemOperation
{
public:
    this(RSSetSchemeOperation setOperation)
    {
        mSetOperation = setOperation;
    }
    
    RSSetSchemeOperation mSetOperation;
    
    void execute(SceneManager sm, RenderSystem rs)
    {
        MaterialManager.getSingleton().setActiveScheme(mSetOperation.getPreviousScheme());
        sm.setLateMaterialResolving(mSetOperation.getPreviousLateResolving());
    }
}


/** \addtogroup Core
    *  @{
    */
/** \addtogroup Effects
    *  @{
    */
/** Chain of compositor effects applying to one viewport.
    */
class CompositorChain : RenderTargetListener, Viewport.Listener //, public CompositorInstAlloc
{
public:
    this(Viewport vp)
    {
        mViewport = vp;
        mOriginalScene = null;
        mDirty = true;
        mAnyCompositorsEnabled = false;
        
        assert(vp);
        mOldClearEveryFrameBuffers = vp.getClearBuffers();
        vp.addListener(this);
        
        createOriginalScene();
        vp.getTarget().addListener(this);
    }
    /** Another gcc warning here, which is no problem because RenderTargetListener is never used
            to delete an object.
        */
    ~this()
    {
        destroyResources();
    }
    
    /// Data types
    //typedef vector<CompositorInstance*>::type Instances;
    //typedef VectorIterator<Instances> InstanceIterator;
    alias CompositorInstance[] Instances;
    /// Identifier for "last" compositor in chain.
    enum size_t LAST = cast(size_t)-1;
    /// Identifier for best technique.
    enum size_t BEST = 0;
    
    /** Apply a compositor. Initially, the filter is enabled.
        @param filter
            Filter to apply.
        @param addPosition
            Position in filter chain to insert this filter at; defaults to the end (last applied filter).
        @param scheme
            Scheme to use (blank means default).
        */
    CompositorInstance addCompositor(SharedPtr!Compositor filter, size_t addPosition=LAST,string scheme = null)
    {
        filter.getAs().touch();
        CompositionTechnique tech = filter.getAs().getSupportedTechnique(scheme);
        if(!tech)
        {
            /// Warn user
            LogManager.getSingleton().logMessage(
                "CompositorChain: Compositor " ~ filter.get().getName() ~ " has no supported techniques.", LML_CRITICAL
                );
            return null;
        }
        CompositorInstance t = new CompositorInstance(tech, this);
        
        if(addPosition == LAST)
            addPosition = mInstances.length;
        else
            assert(addPosition <= mInstances.length, "Index out of bounds.");
        
        if(mInstances.length == 0 || mInstances.length == addPosition)
            mInstances.insert(t);
        else
            mInstances.insertBeforeIdx(addPosition, t);
        
        mDirty = true;
        mAnyCompositorsEnabled = true;
        return t;
    }
    
    /** Remove a compositor.
        @param position
            Position in filter chain of filter to remove; defaults to the end (last applied filter)
        */
    void removeCompositor(size_t pos=LAST)
    {
        assert (pos < mInstances.length, "Index out of bounds.");
        auto i = mInstances[pos];
        destroy(i);
        mInstances.removeFromArrayIdx(pos);
        
        mDirty = true;
    }
    
    /** Get the number of compositors.
        */
    size_t getNumCompositors()
    {
        return mInstances.length;
    }
    
    /** Remove all compositors.
        */
    void removeAllCompositors()
    {
        foreach (i; mInstances)
        {
            destroy(i);
        }
        mInstances.clear();
        
        mDirty = true;
    }
    
    /** Get compositor instance by position.
        */
    CompositorInstance getCompositor(size_t index)
    {
        assert (index < mInstances.length, "Index out of bounds.");
        return mInstances[index];
    }
    
    /** Get compositor instance by name. Returns null if not found.
        */
    CompositorInstance getCompositor(string name)
    {
        foreach (it; mInstances) 
        {
            if (it.getCompositor().getName() == name) 
            {
                return it;
            }
        }
        return null;
    }
    
    /** Get the original scene compositor instance for this chain (internal use). 
        */
    CompositorInstance _getOriginalSceneCompositor() { return mOriginalScene; }
    
    /** Get an iterator over the compositor instances. The first compositor in this list is applied first, the last one is applied last.
        */
    //InstanceIterator getCompositors();
    Instances getCompositors()
    {
        return mInstances;
    }
    
    /** Enable or disable a compositor, by position. Disabling a compositor stops it from rendering
            but does not free any resources. This can be more efficient than using removeCompositor and 
            addCompositor in cases the filter is switched on and off a lot.
        @param position
            Position in filter chain of filter
        */
    void setCompositorEnabled(size_t position, bool state)
    {
        CompositorInstance inst = getCompositor(position);
        if (!state && inst.getEnabled())
        {
            // If we're disabling a 'middle' compositor in a chain, we have to be
            // caref ul about textures which might have been shared by non-adjacent
            // instances which have now become adjacent. 
            CompositorInstance nextInstance = getNextInstance(inst, true);
            if (nextInstance)
            {
                auto tpit = nextInstance.getTechnique().getTargetPasses();
                foreach(tp; tpit)
                {
                    if (tp.getInputMode() == CompositionTargetPass.InputMode.IM_PREVIOUS)
                    {
                        if (nextInstance.getTechnique().getTextureDefinition(tp.getOutputName()).pooled)
                        {
                            // recreate
                            nextInstance.freeResources(false, true);
                            nextInstance.createResources(false);
                        }
                    }
                    
                }
            }
            
        }
        inst.setEnabled(state);
    }
    
    
    void viewportAdded(RenderTargetViewportEvent evt){}
    void viewportRemoved(RenderTargetViewportEvent evt){}
    
    /** @see RenderTargetListener::preRenderTargetUpdate */
    void preRenderTargetUpdate(RenderTargetEvent evt)
    {
        /// Compile if state is dirty
        if(mDirty)
            _compile();
        
        // Do nothing if no compositors enabled
        if (!mAnyCompositorsEnabled)
        {
            return;
        }
        
        
        /// Update dependent render targets; this is done in the preRenderTarget 
        /// and not the preViewportUpdate for a reason: at this time, the
        /// target Rendertarget will not yet have been set as current. 
        /// ( RenderSystem::setViewport(...) ) if it would have been, the rendering
        /// order would be screwed up and problems would arise with copying rendertextures.
        Camera cam = mViewport.getCamera();
        if (cam)
        {
            cam.getSceneManager()._setActiveCompositorChain(this);
        }
        
        /// Iterate over compiled state
        foreach(i; mCompiledState)
        {
            /// Skip if this is a target that should only be initialised initially
            if(i.onlyInitial && i.hasBeenRendered)
                continue;
            i.hasBeenRendered = true;
            /// Setup and render
            preTargetOperation(i, i.target.getViewport(0), cam);
            i.target.update();
            postTargetOperation(i, i.target.getViewport(0), cam);
        }
    }
    
    /** @see RenderTargetListener::postRenderTargetUpdate */
    void postRenderTargetUpdate(RenderTargetEvent evt)
    {
        Camera cam = mViewport.getCamera();
        if (cam)
        {
            cam.getSceneManager()._setActiveCompositorChain(null);
        }
    }
    
    /** @see RenderTargetListener::preViewportUpdate */
    void preViewportUpdate(RenderTargetViewportEvent evt)
    {
        // Only set up if there is at least one compositor enabled, and it's this viewport
        if(evt.source != mViewport || !mAnyCompositorsEnabled)
            return;
        
        // set original scene details from viewport
        CompositionPass pass = mOriginalScene.getTechnique().getOutputTargetPass().getPass(0);
        CompositionTargetPass passParent = pass.getParent();
        if (pass.getClearBuffers() != mViewport.getClearBuffers() ||
            pass.getClearColour() != mViewport.getBackgroundColour() ||
            pass.getClearDepth() != mViewport.getDepthClear() ||
            passParent.getVisibilityMask() != mViewport.getVisibilityMask() ||
            passParent.getMaterialScheme() != mViewport.getMaterialScheme() ||
            passParent.getShadowsEnabled() != mViewport.getShadowsEnabled())
        {
            // recompile if viewport settings are different
            pass.setClearBuffers(mViewport.getClearBuffers());
            pass.setClearColour(mViewport.getBackgroundColour());
            pass.setClearDepth(mViewport.getDepthClear());
            passParent.setVisibilityMask(mViewport.getVisibilityMask());
            passParent.setMaterialScheme(mViewport.getMaterialScheme());
            passParent.setShadowsEnabled(mViewport.getShadowsEnabled());
            _compile();
        }
        
        Camera cam = mViewport.getCamera();
        if (cam)
        {
            /// Prepare for output operation
            preTargetOperation(mOutputOperation, mViewport, cam);
        }
    }
    
    /** @see RenderTargetListener::postViewportUpdate */
    void postViewportUpdate(RenderTargetViewportEvent evt)
    {
        // Only tidy up if there is at least one compositor enabled, and it's this viewport
        if(evt.source != mViewport || !mAnyCompositorsEnabled)
            return;
        
        Camera cam = mViewport.getCamera();
        postTargetOperation(mOutputOperation, mViewport, cam);
    }
    
    /** @see Viewport::Listener::viewportCameraChanged */
    void viewportCameraChanged(Viewport viewport)
    {
        Camera camera = viewport.getCamera();
        size_t count = mInstances.length;
        for (size_t i = 0; i < count; ++i) //TODO foreach loop
        {
            mInstances[i].notifyCameraChanged(camera);
        }
    }
    
    /** @see Viewport::Listener::viewportDimensionsChanged */
    void viewportDimensionsChanged(Viewport viewport)
    {
        size_t count = mInstances.length;
        for (size_t i = 0; i < count; ++i) //TODO foreach loop
        {
            mInstances[i].notifyResized();
        }
    }
    
    /** @see Viewport::Listener::viewportDestroyed */
    void viewportDestroyed(Viewport viewport)
    {
        // this chain is now orphaned. tell compositor manager to delete it.
        CompositorManager.getSingleton().removeCompositorChain(viewport);
    }
    
    /** Mark state as dirty, and to be recompiled next frame.
        */
    void _markDirty()
    {
        mDirty = true;
    }
    
    /** Get viewport that is the target of this chain
        */
    Viewport getViewport()
    {
        return mViewport;
    }
    
    /** Remove a compositor by pointer. This is internally used by CompositionTechnique to
            "weak" remove any instanced of a deleted technique.
        */
    void _removeInstance(CompositorInstance i)
    {
        mInstances.removeFromArray(i);
        destroy(i);
    }
    
    /** Internal method for registering a queued operation for deletion later **/
    void _queuedOperation(CompositorInstance.RenderSystemOperation op)
    {
        mRenderSystemOperations.insert(op);
    }
    
    /** Compile this Composition chain into a series of RenderTarget operations.
        */
    void _compile()
    {
        // remove original scene if it has the wrong material scheme
        if( mOriginalSceneScheme != mViewport.getMaterialScheme() )
        {
            destroyOriginalScene();
            createOriginalScene();
        }
        
        clearCompiledState();
        
        bool compositorsEnabled = false;
        
        // force default scheme so materials for compositor quads will determined correctly
        MaterialManager matMgr = MaterialManager.getSingleton();
        string prevMaterialScheme = matMgr.getActiveScheme();
        matMgr.setActiveScheme(MaterialManager.DEFAULT_SCHEME_NAME);
        
        /// Set previous CompositorInstance for each compositor in the list
        CompositorInstance lastComposition = mOriginalScene;
        mOriginalScene.mPreviousInstance = null;
        CompositionPass pass = mOriginalScene.getTechnique().getOutputTargetPass().getPass(0);
        pass.setClearBuffers(mViewport.getClearBuffers());
        pass.setClearColour(mViewport.getBackgroundColour());
        pass.setClearDepth(mViewport.getDepthClear());
        foreach(i; mInstances)
        {
            if(i.getEnabled())
            {
                compositorsEnabled = true;
                i.mPreviousInstance = lastComposition;
                lastComposition = i;
            }
        }
        
        
        /// Compile misc targets
        lastComposition._compileTargetOperations(mCompiledState);
        
        /// Final target viewport (0)
        mOutputOperation.renderSystemOperations.clear();
        lastComposition._compileOutputOperation(mOutputOperation);
        
        // Deal with viewport settings
        if (compositorsEnabled != mAnyCompositorsEnabled)
        {
            mAnyCompositorsEnabled = compositorsEnabled;
            if (mAnyCompositorsEnabled)
            {
                // Save old viewport clearing options
                mOldClearEveryFrameBuffers = mViewport.getClearBuffers();
                // Don't clear anything every frame since we have our own clear ops
                mViewport.setClearEveryFrame(false);
            }
            else
            {
                // Reset clearing options
                mViewport.setClearEveryFrame(mOldClearEveryFrameBuffers > 0, 
                                             mOldClearEveryFrameBuffers);
            }
        }
        
        // restore material scheme
        matMgr.setActiveScheme(prevMaterialScheme);
        
        
        mDirty = false;
    }
    
    /** Get the previous instance in this chain to the one specified. 
        */
    CompositorInstance getPreviousInstance(CompositorInstance curr, bool activeOnly = true)
    {
        bool found = false;
        foreach_reverse(i; mInstances)
        {
            if (found)
            {
                if (i.getEnabled() || !activeOnly)
                    return i;
            }
            else if(i == curr)
            {
                found = true;
            }
        }
        
        return null;
    }
    /** Get the next instance in this chain to the one specified. 
        */
    CompositorInstance getNextInstance(CompositorInstance curr, bool activeOnly = true)
    {
        bool found = false;
        foreach(i; mInstances)
        {
            if (found)
            {
                if (i.getEnabled() || !activeOnly)
                    return i;
            }
            else if(i == curr)
            {
                found = true;
            }
        }
        
        return null;
    }
    
protected:
    /// Viewport affected by this CompositorChain
    Viewport mViewport;
    
    /** Plainly renders the scene; implicit first compositor in the chain.
        */
    CompositorInstance mOriginalScene;
    
    /// Postfilter instances in this chain
    Instances mInstances;
    
    /// State needs recompile
    bool mDirty;
    /// Any compositors enabled?
    bool mAnyCompositorsEnabled;
    
    string mOriginalSceneScheme;
    
    /// Compiled state (updated with _compile)
    CompositorInstance.CompiledState mCompiledState;
    CompositorInstance.TargetOperation mOutputOperation;
    /// Render System operations queued by last compile, these are created by this
    /// instance thus managed and deleted by it. The list is cleared with 
    /// clearCompilationState()
    //typedef vector<CompositorInstance::RenderSystemOperation*>::type RenderSystemOperations;
    alias CompositorInstance.RenderSystemOperation[] RenderSystemOperations;
    RenderSystemOperations mRenderSystemOperations;
    
    /** Clear compiled state */
    void clearCompiledState()
    {
        foreach (i; mRenderSystemOperations)
        {
            destroy(i);
        }
        mRenderSystemOperations.clear();
        
        /// Clear compiled state
        mCompiledState.clear();
        mOutputOperation = new CompositorInstance.TargetOperation(null);
        
    }
    /** Prepare a viewport, the camera and the scene for a rendering operation
        */
    void preTargetOperation(CompositorInstance.TargetOperation op, Viewport vp, Camera cam)
    {
        if (cam)
        {
            SceneManager sm = cam.getSceneManager();
            /// Set up render target listener
            mOurListener.setOperation(op, sm, sm.getDestinationRenderSystem());
            mOurListener.notifyViewport(vp);
            /// Register it
            sm.addRenderQueueListener(mOurListener);
            /// Set whether we find visibles
            mOldFindVisibleObjects = sm.getFindVisibleObjects();
            sm.setFindVisibleObjects(op.findVisibleObjects);
            /// Set LOD bias level
            mOldLodBias = cam.getLodBias();
            cam.setLodBias(cam.getLodBias() * op.lodBias);
        }
        
        // Set the visibility mask
        mOldVisibilityMask = vp.getVisibilityMask();
        vp.setVisibilityMask(op.visibilityMask);
        /// Set material scheme 
        mOldMaterialScheme = vp.getMaterialScheme();
        vp.setMaterialScheme(op.materialScheme);
        /// Set shadows enabled
        mOldShadowsEnabled = vp.getShadowsEnabled();
        vp.setShadowsEnabled(op.shadowsEnabled);
        /// XXX TODO
        //vp.setClearEveryFrame( true );
        //vp.setOverlaysEnabled( false );
        //vp.setBackgroundColour( op.clearColour );
    }
    
    /** Restore a viewport, the camera and the scene after a rendering operation
        */
    void postTargetOperation(CompositorInstance.TargetOperation op, Viewport vp, Camera cam)
    {
        if (cam)
        {
            SceneManager sm = cam.getSceneManager();
            /// Unregister our listener
            sm.removeRenderQueueListener(mOurListener);
            /// Restore default scene and camera settings
            sm.setFindVisibleObjects(mOldFindVisibleObjects);
            cam.setLodBias(mOldLodBias);
        }
        
        vp.setVisibilityMask(mOldVisibilityMask);
        vp.setMaterialScheme(mOldMaterialScheme);
        vp.setShadowsEnabled(mOldShadowsEnabled);
    }
    
    void createOriginalScene()
    {
        /// Create "default" compositor
        /** Compositor that is used to implicitly represent the original
        render in the chain. This is an identity compositor with only an output pass:
        compositor Ogre/Scene
        {
            technique
            {
                target_output
                {
                    pass clear
                    {
                        /// Clear frame
                    }
                    pass render_scene
                    {
                        visibility_mask FFFFFFFF
                        render_queues SKIES_EARLY SKIES_LATE
                    }
                }
            }
        };
        */
        
        // If two viewports use the same scheme but differ in settings like visibility masks, shadows, etc we don't
        // want compositors to share their technique.  Otherwise both compositors will have to recompile every time they
        // render.  Thus we generate a unique compositor per viewport.
        string compName = std.conv.text("Ogre/Scene/", mViewport);
        
        mOriginalSceneScheme = mViewport.getMaterialScheme();
        SharedPtr!Compositor scene = CompositorManager.getSingleton().getByName(compName, ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME);
        if (scene.isNull())
        {
            scene = CompositorManager.getSingleton().create(compName, ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME);
            CompositionTechnique t = scene.getAs().createTechnique();
            t.setSchemeName(null);
            CompositionTargetPass tp = t.getOutputTargetPass();
            tp.setVisibilityMask(0xFFFFFFFF);
            {
                CompositionPass pass = tp.createPass();
                pass.setType(CompositionPass.PassType.PT_CLEAR);
            }
            {
                CompositionPass pass = tp.createPass();
                pass.setType(CompositionPass.PassType.PT_RENDERSCENE);
                /// Render everything, including skies
                pass.setFirstRenderQueue(RenderQueueGroupID.RENDER_QUEUE_BACKGROUND);
                pass.setLastRenderQueue(RenderQueueGroupID.RENDER_QUEUE_SKIES_LATE);
            }
            
            
            /// Create base "original scene" compositor
            scene = CompositorManager.getSingleton().load(compName,
                                                          ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME);
            
            
            
        }
        mOriginalScene = new CompositorInstance(scene.getAs().getSupportedTechnique(), this);
    }
    
    void destroyOriginalScene()
    {
        /// Destroy "original scene" compositor instance
        if (mOriginalScene)
        {
            destroy(mOriginalScene);
            mOriginalScene = null;
        }
    }
    
    /// destroy internal resources
    void destroyResources()
    {
        clearCompiledState();
        
        if (mViewport)
        {
            mViewport.getTarget().removeListener(this);
            mViewport.removeListener(this);
            removeAllCompositors();
            destroyOriginalScene();
            
            mViewport = null;
        }
    }
    
    /** Render queue listener used to set up rendering events. */
    class RQListener : RenderQueueListener
    {
    public:
        void preRenderQueues(){}
        void postRenderQueues(){}
        
        /** @copydoc RenderQueueListener::renderQueueStarted
            */
        void renderQueueStarted(ubyte queueGroupId,string invocation, ref bool skipThisQueue)
        {
            // Skip when not matching viewport
            // shadows update is nested within main viewport update
            if (mSceneManager.getCurrentViewport() != mViewport)
                return;
            
            flushUpTo(queueGroupId);
            /// If no one wants to render this queue, skip it
            /// Don't skip the OVERLAY queue because that's handled separately
            if(!mOperation.renderQueues.test(queueGroupId) && queueGroupId!=RenderQueueGroupID.RENDER_QUEUE_OVERLAY)
            {
                skipThisQueue = true;
            }
        }
        
        /** @copydoc RenderQueueListener::renderQueueEnded
            */
        void renderQueueEnded(ubyte queueGroupId,string invocation, ref bool repeatThisInvocation)
        {
            
        }
        
        /** Set current operation and target. */
        void setOperation(CompositorInstance.TargetOperation op, SceneManager sm, RenderSystem rs)
        {
            mOperation = op;
            mSceneManager = sm;
            mRenderSystem = rs;
            // No iterators in D like that
            //currentOp = op.renderSystemOperations[0];
            //lastOp = op.renderSystemOperations[$-1];
            mOps = op.renderSystemOperations; //XXX Getting whole array instead of iterators
        }
        
        /** Notify current destination viewport. */
        void notifyViewport(Viewport vp) { mViewport = vp; }
        
        /** Flush remaining render system operations. */
        void flushUpTo(ubyte id)
        {
            /// Process all RenderSystemOperations up to and including render queue id.
            /// Including, because the operations for RenderQueueGroup x should be executed
            /// at the beginning of the RenderQueueGroup render for x.
            //while(currentOp != lastOp && currentOp.first <= id)
            foreach(currentOp; mOps)
            {
                if(currentOp.first > id) break;
                currentOp.second.execute(mSceneManager, mRenderSystem);
                //++currentOp;
            }
        }
    private:
        CompositorInstance.TargetOperation mOperation;
        SceneManager mSceneManager;
        RenderSystem mRenderSystem;
        Viewport mViewport;
        //CompositorInstance.RenderSystemOpPair currentOp, lastOp;
        CompositorInstance.RenderSystemOpPairs mOps;
    }
    
    RQListener mOurListener;
    /// Old viewport settings
    uint mOldClearEveryFrameBuffers;
    /// Store old scene visibility mask
    uint mOldVisibilityMask;
    /// Store old find visible objects
    bool mOldFindVisibleObjects;
    /// Store old camera LOD bias
    float mOldLodBias;
    /// Store old viewport material scheme
    string mOldMaterialScheme;
    /// Store old shadows enabled flag
    bool mOldShadowsEnabled;
    
}

/** @} */
/** @} */