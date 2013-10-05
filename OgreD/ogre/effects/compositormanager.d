module ogre.effects.compositormanager;
//import std.container;
import std.algorithm;
import std.array;

import ogre.resources.resourcemanager;
import ogre.singleton;
import ogre.resources.datastream;
import ogre.general.scriptcompiler;
import ogre.rendersystem.viewport;
import ogre.scene.rectangle2d;
import ogre.effects.compositor;
import ogre.resources.texture;
import ogre.image.pixelformat;
import ogre.image.images;
import ogre.compat;
import ogre.rendersystem.hardware;
import ogre.rendersystem.rendersystem;
import ogre.general.root;
import ogre.effects.compositiontechnique;
import ogre.exception;
import ogre.resources.texturemanager;
import ogre.resources.resourcegroupmanager;
import ogre.effects.compositiontargetpass;
import ogre.resources.resource;
import ogre.general.common;
import ogre.scene.renderable;
import ogre.effects.compositorlogic;
import ogre.effects.customcompositionpass;
import ogre.sharedptr;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Effects
 *  @{
 */
/** Class for managing Compositor settings for Ogre. Compositors provide the means
 to flexibly "composite" the final rendering result from multiple scene renders
 and intermediate operations like rendering fullscreen quads. This makes
 it possible to apply postfilter effects, HDRI postprocessing, and shadow
 effects to a Viewport.
 @par
 When loaded from a script, a Compositor is in an 'unloaded' state and only stores the settings
 required. It does not at that stage load any textures. This is because the material settings may be
 loaded 'en masse' from bulk material script files, but only a subset will actually be required.
 @par
 Because this is a subclass of ResourceManager, any files loaded will be searched for in any path or
 archive added to the resource paths/archives. See ResourceManager for details.
 */
class CompositorManager : ResourceManager
{
    mixin Singleton!CompositorManager;
public:
    this()
    {
        //mRectangle = null;
        initialise();
        
        // Loading order (just after materials)
        mLoadOrder = 110.0f;
        
        // Resource type
        mResourceType = "Compositor";
        
        // Register with resource group manager
        ResourceGroupManager.getSingleton()._registerResourceManager(mResourceType, this);
    }

    ~this()
    {
        freeChains();
        freePooledTextures(false);
        destroy(mRectangle);
        
        // Resources cleared by superclass
        // Unregister with resource group manager
        ResourceGroupManager.getSingleton()._unregisterResourceManager(mResourceType);
        ResourceGroupManager.getSingleton()._unregisterScriptLoader(this);
    }
    
    /// Overridden from ResourceManager
    override Resource createImpl(string name, ResourceHandle handle,
                       string group, bool isManual, ManualResourceLoader loader,
                       NameValuePairList params)
    {
        return new Compositor(this, name, handle, group, isManual, loader);
    }
    
    /** Initialises the Compositor manager, which also triggers it to
     parse all available .compositor scripts. */
    void initialise() {}
    
    /** @see ScriptLoader::parseScript
     */
    override void parseScript(DataStream stream,string groupName)
    {
        ScriptCompilerManager.getSingleton().parseScript(stream, groupName);
    }
    
    /** Get the compositor chain for a Viewport. If there is none yet, a new
     compositor chain is registered.
     XXX We need a _notifyViewportRemoved to find out when this viewport disappears,
     so we can destroy its chain as well.
     */
    CompositorChain getCompositorChain(ref Viewport vp)
    {
        auto i = vp in mChains;
        if(i !is null)
        {
            return *i;
        }
        else
        {
            CompositorChain chain = new CompositorChain(vp);
            mChains[vp] = chain;
            return chain;
        }
    }
    
    /** Returns whether exists compositor chain for a viewport.
     */
    bool hasCompositorChain(ref Viewport vp)
    {
        return (vp in mChains) !is null;
    }
    
    /** Remove the compositor chain from a viewport if exists.
     */
    void removeCompositorChain(ref Viewport vp)
    {
        auto i = vp in mChains;
        if (i !is null)
        {
            destroy(*i);
            mChains.remove(vp);
        }
    }
    
    /** Add a compositor to a viewport. By default, it is added to end of the chain,
     after the other compositors.
     @param vp           Viewport to modify
     @param compositor   The name of the compositor to apply
     @param addPosition  At which position to add, defaults to the end (-1).
     @return pointer to instance, or 0 if it failed.
     */
    CompositorInstance addCompositor(ref Viewport vp,string compositor, int addPosition=-1)
    {
        SharedPtr!Compositor comp = getByName(compositor);
        if(comp.isNull())
            return null;
        CompositorChain chain = getCompositorChain(vp);
        return chain.addCompositor(comp, addPosition==-1 ? CompositorChain.LAST : cast(size_t)addPosition);
    }
    
    /** Remove a compositor from a viewport
     */
    void removeCompositor(ref Viewport vp,string compositor)
    {
        CompositorChain chain = getCompositorChain(vp);
        foreach(pos; 0..chain.getNumCompositors())
        {
            CompositorInstance instance = chain.getCompositor(pos);
            if(instance.getCompositor().getName() == compositor)
            {
                chain.removeCompositor(pos);
                break;
            }
        }
    }
    
    /** Set the state of a compositor on a viewport to enabled or disabled.
     Disabling a compositor stops it from rendering but does not free any resources.
     This can be more efficient than using removeCompositor and addCompositor in cases
     the filter is switched on and off a lot.
     */
    void setCompositorEnabled(ref Viewport vp,string compositor, bool value)
    {
        CompositorChain chain = getCompositorChain(vp);
        foreach(pos; 0..chain.getNumCompositors())
        {
            CompositorInstance instance = chain.getCompositor(pos);
            if(instance.getCompositor().getName() == compositor)
            {
                chain.setCompositorEnabled(pos, value);
                break;
            }
        }
    }
    
    /** Get a textured fullscreen 2D rectangle, for internal use.
     */
    Renderable _getTexturedRectangle2D()
    {
        if(!mRectangle)
        {
            /// 2D rectangle, to use for render_quad passes
            mRectangle = new Rectangle2D(true, HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY_DISCARDABLE);
        }
        RenderSystem rs = Root.getSingleton().getRenderSystem();
        Viewport vp = rs._getViewport();
        Real hOffset = rs.getHorizontalTexelOffset() / (0.5f * vp.getActualWidth());
        Real vOffset = rs.getVerticalTexelOffset() / (0.5f * vp.getActualHeight());
        mRectangle.setCorners(-1 + hOffset, 1 - vOffset, 1 + hOffset, -1 - vOffset);
        return mRectangle;
    }
    
    /** Overridden from ResourceManager since we have to clean up chains too. */
    override void removeAll()
    {
        freeChains();
        super.removeAll();
    }
    
    /** Internal method for forcing all active compositors to recreate their resources. */
    void _reconstructAllCompositorResources()
    {
        // In order to deal with shared resources, we have to disable *all* compositors
        // first, that way shared resources will get freed
        CompositorInstance[] instancesToReenable;

        foreach (k, chain; mChains)
        {
            foreach(inst; chain.getCompositors())
            {
                if (inst.getEnabled())
                {
                    inst.setEnabled(false);
                    instancesToReenable ~= inst;
                }
            }
        }
        
        //UVs are lost, and will never be reconstructed unless we do them again, now
        if( mRectangle )
            mRectangle.setDefaultUVs();
        
        foreach (i; instancesToReenable)
        {
            i.setEnabled(true);
        }
    }
    
    //typedef set<Texture*>::type UniqueTextureSet;
    alias Texture[] UniqueTextureSet;
    
    /** Utility function to get an existing pooled texture matching a given
     definition, or creating one if one doesn't exist. It also takes into
     account whether a pooled texture has already been supplied to this
     same requester already, in which case it won't give the same texture
     twice (this is important for example if you request 2 ping-pong textures, 
     you don't want to get the same texture for both requests!
     */
    SharedPtr!Texture getPooledTexture(string name,string localName, 
                                    size_t w, size_t h, 
                                    PixelFormat f, uint aa,string aaHint, bool srgb, 
                                    ref UniqueTextureSet texturesAlreadyAssigned, 
                                    ref CompositorInstance inst, CompositionTechnique.TextureScope _scope)
    {
        if (_scope == CompositionTechnique.TextureScope.TS_GLOBAL) 
        {
            throw new InvalidParamsError(
                "Global scope texture can not be pooled.",
                "CompositorManager.getPooledTexture");
        }
        
        auto def = TextureDef(w, h, f, aa, aaHint, srgb);
        
        if (_scope == CompositionTechnique.TextureScope.TS_CHAIN)
        {
            StringPair pair = pair!(string,string)(inst.getCompositor().getName(), localName);
            TextureDefMap defMap = mChainTexturesByDef[pair];
            auto it = def in defMap;
            if (it !is null)
            {
                return *it;
            }
            // ok, we need to create a new one
            SharedPtr!Texture newTex = TextureManager.getSingleton().createManual(
                name, 
                ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME, TextureType.TEX_TYPE_2D, 
                cast(uint)w, cast(uint)h, 0, f, TextureUsage.TU_RENDERTARGET, null,
                srgb, aa, aaHint);
            defMap[def] = newTex;
            return defMap[def];
        }
        
        auto i = def in mTexturesByDef;
        if (i is null)
        {
            TextureList texList; // = OGRE_NEW_T(TextureList, MEMCATEGORY_GENERAL);
            mTexturesByDef[def] = texList;
            i = &mTexturesByDef[def];
        }
        CompositorInstance previous = inst.getChain().getPreviousInstance(inst);
        CompositorInstance next = inst.getChain().getNextInstance(inst);
        
        SharedPtr!Texture ret;
        TextureList texList = *i;
        // iterate over the existing textures and check if we can re-use
        foreach (tex; texList)
        {
            // check not already used
            if (texturesAlreadyAssigned.find(tex).empty)
            {
                bool allowReuse = true;
                // ok, we didn't use this one already
                // however, there is an edge case where if we re-use a texture
                // which has an 'input previous' pass, and it is chained from another
                // compositor, we can end up trying to use the same texture for both
                // so, never allow a texture with an input previous pass to be 
                // shared with its immediate predecessor in the chain
                if (isInputPreviousTarget(inst, localName))
                {
                    // Check whether this is also an input to the output target of previous
                    // can't use CompositorInstance::mPreviousInstance, only set up
                    // during compile
                    if (previous && isInputToOutputTarget(previous, tex))
                        allowReuse = false;
                }
                // now check the other way around since we don't know what order they're bound in
                if (isInputToOutputTarget(inst, localName))
                {
                    
                    if (next && isInputPreviousTarget(next, tex))
                        allowReuse = false;
                }
                
                if (allowReuse)
                {
                    ret = tex;
                    break;
                }
                
            }
        }
        
        if (ret.isNull())
        {
            // ok, we need to create a new one
            ret = TextureManager.getSingleton().createManual(
                name, 
                ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME, TextureType.TEX_TYPE_2D, 
                cast(uint)w, cast(uint)h, 0, f, TextureUsage.TU_RENDERTARGET, null,
                srgb, aa, aaHint); 
            
            texList.insert(ret);
            
        }
        
        // record that we used this one in the requester's list
        texturesAlreadyAssigned.insert(ret.getAs());
        
        
        return ret;
    }
    
    /** Free pooled textures from the shared pool (compositor instances still 
     using them will keep them in memory though). 
     */
    void freePooledTextures(bool onlyIfUnreferenced = true)
    {
        if (onlyIfUnreferenced)
        {
            foreach (k,texList; mTexturesByDef)
            {
                for (size_t j = 0; j < texList.length;)
                {
                    auto t = texList[j];
                    // if the resource system, plus this class, are the only ones to have a reference..
                    // NOTE: any material references will stop this texture getting freed (e.g. compositor demo)
                    // until this routine is called again after the material no longer references the texture
                    //FIXME SharedPtr used. useCount() is probably not RESOURCE_SYSTEM_NUM_REFERENCE_COUNTS + 1
                    if (t.useCount() == ResourceGroupManager.RESOURCE_SYSTEM_NUM_REFERENCE_COUNTS + 1)
                    {
                        TextureManager.getSingleton().remove(t.get().getHandle());
                        //j = texList.erase(j);
                        texList.removeFromArrayIdx(j);
                    }
                    else
                        ++j;
                }
            }
            foreach (k, texMap; mChainTexturesByDef)
            {
                foreach (j; texMap.keys)
                {
                    SharedPtr!Texture tex = texMap[j];
                    //FIXME SharedPtr used. useCount() is probably not RESOURCE_SYSTEM_NUM_REFERENCE_COUNTS + 1
                    if (tex.useCount() == ResourceGroupManager.RESOURCE_SYSTEM_NUM_REFERENCE_COUNTS + 1)
                    {
                        TextureManager.getSingleton().remove(tex.getAs().getHandle());
                        //texMap.erase(j++);
                        texMap.remove(j);
                    }
                    //else
                    //    ++j;
                }
            }
        }
        else
        {
            // destroy all
            foreach (k, list; mTexturesByDef)
            {
                //OGRE_DELETE_T(i.second, TextureList, MEMCATEGORY_GENERAL);
                destroy(list);
            }
            mTexturesByDef.clear();
            mChainTexturesByDef.clear();
        }
        
    }
    
    /** Register a compositor logic for listening in to expecting composition
     techniques.
     */
    void registerCompositorLogic(string name, ref CompositorLogic logic)
    {   
        if (name is null || name.empty) 
        {
            throw new InvalidParamsError(
                "Compositor logic name must not be empty.",
                "CompositorManager.registerCompositorLogic");
        }
        if ((name in mCompositorLogics) !is null)
        {
            throw new DuplicateItemError(
                "Compositor logic '" ~ name ~ "' already exists.",
                "CompositorManager.registerCompositorLogic");
        }
        mCompositorLogics[name] = logic;
    }
    
    /** Removes a listener for compositor logic registered with registerCompositorLogic
     */
    void unregisterCompositorLogic(string name)
    {
        auto itor = name in mCompositorLogics;
        if( itor is null )
        {
            //TODO remove() can ignore missing items though (?)
            throw new ItemNotFoundError(
                "Compositor logic '" ~ name ~ "' not registered.",
                "CompositorManager.unregisterCompositorLogic");
        }
        
        mCompositorLogics.remove( name );
    }
    
    /** Get a compositor logic by its name
     */
    ref CompositorLogic getCompositorLogic(string name)
    {
        auto it = name in mCompositorLogics;
        if (it is null)
        {
            throw new ItemNotFoundError(
                "Compositor logic '" ~ name ~ "' not registered.",
                "CompositorManager.getCompositorLogic");
        }
        return *it; //mCompositorLogics[name];
    }
    
    /** Register a custom composition pass.
     */
    void registerCustomCompositionPass(string name, ref CustomCompositionPass customPass)
    {   
        if (name is null || name.empty)
        {
            throw new InvalidParamsError(
                "Custom composition pass name must not be empty.",
                "CompositorManager.registerCustomCompositionPass");
        }
        if ((name in mCustomCompositionPasses) !is null)
        {
            throw new DuplicateItemError(
                "Custom composition pass  '" ~ name ~ "' already exists.",
                "CompositorManager.registerCustomCompositionPass");
        }
        mCustomCompositionPasses[name] = customPass;
    }
    
    /** Get a custom composition pass by its name 
     */
    ref CustomCompositionPass getCustomCompositionPass(string name)
    {
        auto it = name in mCustomCompositionPasses;
        if (it is null)
        {
            throw new ItemNotFoundError(
                        "Custom composition pass '" ~ name ~ "' not registered.",
                        "CompositorManager.getCustomCompositionPass");
        }
        return *it; //mCustomCompositionPasses[name];
    }

private:
    //typedef map<Viewport*, CompositorChain*>::type Chains;
    alias CompositorChain[Viewport] Chains;
    Chains mChains;
    
    /** Clear composition chains for all viewports
     */
    void freeChains()
    {
        foreach(k,v; mChains)
        {
            destroy(v);
        }
        mChains.clear();
    }
    
    Rectangle2D mRectangle;
    
    /// List of instances
    //typedef vector<CompositorInstance *>::type Instances;
    alias CompositorInstance[] Instances;
    Instances mInstances;
    
    /// Map of registered compositor logics
    //typedef map<String, CompositorLogic*>::type CompositorLogicMap;
    alias CompositorLogic[string] CompositorLogicMap;
    CompositorLogicMap mCompositorLogics;
    
    /// Map of registered custom composition passes
    //typedef map<String, CustomCompositionPass*>::type CustomCompositionPassMap;
    alias CustomCompositionPass[string] CustomCompositionPassMap;
    CustomCompositionPassMap mCustomCompositionPasses;
    
    //typedef vector<SharedPtr!Texture>::type TextureList;
    //typedef VectorIterator<TextureList> TextureIterator;
    alias SharedPtr!(Texture)[] TextureList;
    
    struct TextureDef
    {
        size_t width, height;
        PixelFormat format;
        uint fsaa;
        string fsaaHint;
        bool sRGBwrite;
        
        this(size_t w, size_t h, PixelFormat f, uint aa,string aaHint, bool srgb)
        {
            width = w;
            height = h;
            format = f;
            fsaa = aa;
            fsaaHint = aaHint;
            sRGBwrite = srgb;
        }
    }

    struct TextureDefLess
    {
        bool opCall(TextureDef x,TextureDef y)
        {
            if (x.format < y.format)
                return true;
            else if (x.format == y.format)
            {
                if (x.width < y.width)
                    return true;
                else if (x.width == y.width)
                {
                    if (x.height < y.height)
                        return true;
                    else if (x.height == y.height)
                    {
                        if (x.fsaa < y.fsaa)
                            return true;
                        else if (x.fsaa == y.fsaa)
                        {
                            if (x.fsaaHint < y.fsaaHint)
                                return true;
                            else if (x.fsaaHint == y.fsaaHint)
                            {
                                if (!x.sRGBwrite && y.sRGBwrite)
                                    return true;
                            }
                            
                        }
                    }
                }
            }
            return false;
        }
    }

    //typedef map<TextureDef, TextureList*, TextureDefLess>::type TexturesByDef;
    //TODO TextureDefLess sorting
    alias TextureList[TextureDef] TexturesByDef;
    TexturesByDef mTexturesByDef;
    
    //typedef std::pair<String, String> StringPair;
    alias pair!(string, string) StringPair;
    //typedef map<TextureDef, SharedPtr!Texture, TextureDefLess>::type TextureDefMap;
    //TODO TextureDefLess sorting
    alias SharedPtr!Texture[TextureDef] TextureDefMap;
    //typedef std::map<StringPair, TextureDefMap> ChainTexturesByDef;
    alias TextureDefMap[StringPair] ChainTexturesByDef;
    
    ChainTexturesByDef mChainTexturesByDef;
    
    bool isInputPreviousTarget(ref CompositorInstance inst,string localName)
    {
        auto tpit = inst.getTechnique().getTargetPasses();
        foreach(tp; tpit)
        {
            if (tp.getInputMode() == CompositionTargetPass.InputMode.IM_PREVIOUS &&
                tp.getOutputName() == localName)
            {
                return true;
            }
            
        }
        
        return false;
        
    }

    bool isInputPreviousTarget(ref CompositorInstance inst, ref SharedPtr!Texture tex)
    {
        auto tpit = inst.getTechnique().getTargetPasses();
        foreach(tp; tpit)
        {
            if (tp.getInputMode() == CompositionTargetPass.InputMode.IM_PREVIOUS)
            {
                // Don't have to worry about an MRT, because no MRT can be input previous
                SharedPtr!Texture t = inst.getTextureInstance(tp.getOutputName(), 0);
                if (!t.isNull() && t.get() == tex.getAs())
                    return true;
            }
        }

        return false;

    }

    bool isInputToOutputTarget(ref CompositorInstance inst,string localName)
    {
        CompositionTargetPass tp = inst.getTechnique().getOutputTargetPass();
        auto pit = tp.getPasses();
        
        foreach(p; pit)
        {
            for (size_t i = 0; i < p.getNumInputs(); ++i)
            {
                if (p.getInput(i).name == localName)
                    return true;
            }
        }
        
        return false;
    }

    bool isInputToOutputTarget(ref CompositorInstance inst, SharedPtr!Texture tex)
    {
        CompositionTargetPass tp = inst.getTechnique().getOutputTargetPass();
        auto pit = tp.getPasses();
        
        foreach(p; pit)
        {
            for (size_t i = 0; i < p.getNumInputs(); ++i)
            {
                SharedPtr!Texture t = inst.getTextureInstance(p.getInput(i).name, 0);
                if (!t.isNull() && t.get() == tex.getAs())
                    return true;
            }
        }
        
        return false;
        
    }
    
}
/** @} */
/** @} */