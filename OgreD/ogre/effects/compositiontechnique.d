module ogre.effects.compositiontechnique;

//import std.container;
import std.array;
import ogre.compat;
import ogre.image.pixelformat;
import ogre.image.images;
import ogre.resources.texture;
import ogre.rendersystem.rendersystem;
import ogre.effects.compositor;
import ogre.effects.compositiontargetpass;
import ogre.resources.texturemanager;
import ogre.general.root;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Effects
    *  @{
    */
/** Base composition technique, can be subclassed in plugins.
     */
class CompositionTechnique //: public CompositorInstAlloc
{
public:
    this(ref Compositor parent)
    {
        mParent = parent;
        mOutputTarget = new CompositionTargetPass(this);
    }

    ~this()
    {
        removeAllTextureDefinitions();
        removeAllTargetPasses();
        destroy(mOutputTarget);
    }
    
    //The scope of a texture defined by the compositor
    enum TextureScope { 
        //Local texture - only available to the compositor passes in this technique
        TS_LOCAL, 
        //Chain texture - available to the other compositors in the chain
        TS_CHAIN, 
        //Global texture - available to everyone in every scope
        TS_GLOBAL 
    }
    
    /// Local texture definition
    class TextureDefinition //: public CompositorInstAlloc
    {
    public:
        string name;
        //Texture definition being a reference is determined by these two fields not being empty.
        string refCompName; //If a reference, the name of the compositor being referenced
        string refTexName;  //If a reference, the name of the texture in the compositor being referenced
        size_t width;       // 0 means adapt to target width
        size_t height;      // 0 means adapt to target height
        float widthFactor;  // multiple of target width to use (if width = 0)
        float heightFactor; // multiple of target height to use (if height = 0)
        PixelFormatList formatList; // more than one means MRT
        bool fsaa;          // FSAA enabled; true = determine from main target (if render_scene), false = disable
        bool hwGammaWrite;  // Do sRGB gamma correction on write (only 8-bit per channel formats) 
        ushort depthBufferId;//Depth Buffer's pool ID. (unrelated to "pool" variable below)
        bool pooled;        // whether to use pooled textures for this one
        TextureScope _scope; // Which scope has access to this texture
        
        this() 
        {
            width = 0; height = 0; widthFactor = 1.0f; heightFactor = 1.0f;
            fsaa = true; hwGammaWrite = false; depthBufferId = 1; pooled = false; 
            _scope = TextureScope.TS_LOCAL;
        }
    }
    /// Typedefs for several iterators
    //typedef vector<CompositionTargetPass *>::type TargetPasses;
    //typedef VectorIterator<TargetPasses> TargetPassIterator;
    //typedef vector<TextureDefinition*>::type TextureDefinitions;
    //typedef VectorIterator<Textur eDefinitions> TextureDefinitionIterator;
    alias CompositionTargetPass[] TargetPasses;
    alias TextureDefinition[]     TextureDefinitions;
    /** Create a new local texture definition, and return a pointer to it.
            @param name     Name of the local texture
        */
    //TODO can be ref'ed?
    TextureDefinition createTextureDefinition(string name)
    {
        TextureDefinition t = new TextureDefinition();
        t.name = name;
        mTextureDefinitions.insert(t);
        return t;
    }
    
    /** Remove and destroy a local texture definition.
        */
    void removeTextureDefinition(size_t idx)
    {
        assert (idx < mTextureDefinitions.length, "Index out of bounds.");
        auto i = mTextureDefinitions[idx];
        destroy (i);
        mTextureDefinitions.removeFromArrayIdx(idx);
    }
    
    /** Get a local texture definition.
        */
    ref TextureDefinition getTextureDefinition(size_t idx)
    {
        assert (idx < mTextureDefinitions.length, "Index out of bounds.");
        return mTextureDefinitions[idx];
    }
    
    /** Get a local texture definition with a specific name.
        */
    TextureDefinition getTextureDefinition(string name)
    {
        foreach (i; mTextureDefinitions)
        {
            if (i.name == name)
                return i;
        }
        return null;
    }
    
    /** Get the number of local texture definitions.
        */
    size_t getNumTextureDefinitions()
    {
        return mTextureDefinitions.length;
    }
    
    /** Remove all Texture Definitions
        */
    void removeAllTextureDefinitions()
    {
        foreach (i; mTextureDefinitions)
        {
            destroy (i);
        }
        mTextureDefinitions.clear();
    }
    
    /** Get an iterator over the TextureDefinitions in this Technique. */
    //TextureDefinitionIterator getTextureDefinitionIterator(void);
    ref TextureDefinitions getTextureDefinitions()
    {
        return mTextureDefinitions;
    }
    
    /** Create a new target pass, and return a pointer to it.
        */
    //TODO can be ref'ed?
    CompositionTargetPass createTargetPass()
    {
        CompositionTargetPass t = new CompositionTargetPass(this);
        mTargetPasses.insert(t);
        return t;
    }
    
    /** Remove a target pass. It will also be destroyed.
        */
    void removeTargetPass(size_t idx)
    {
        assert (idx < mTargetPasses.length, "Index out of bounds.");
        auto i = mTargetPasses[idx];
        destroy (i);
        mTargetPasses.removeFromArrayIdx(idx);
    }
    
    /** Get a target pass.
        */
    ref CompositionTargetPass getTargetPass(size_t idx)
    {
        assert (idx < mTargetPasses.length, "Index out of bounds.");
        return mTargetPasses[idx];
    }
    
    /** Get the number of target passes.
        */
    size_t getNumTargetPasses()
    {
        return mTargetPasses.length;
    }
    
    /** Remove all target passes.
        */
    void removeAllTargetPasses()
    {
        foreach (i; mTargetPasses)
        {
            destroy (i);
        }
        mTargetPasses.clear();
    }
    
    /** Get an iterator over the TargetPasses in this Technique. */
    //TargetPassIterator getTargetPassIterator(void);
    ref TargetPasses getTargetPasses()
    {
        return mTargetPasses;
    }
    
    /** Get output (final) target pass
         */
    ref CompositionTargetPass getOutputTargetPass()
    {
        return mOutputTarget;
    }
    
    /** Determine if this technique is supported on the current rendering device. 
        @param allowTextureDegradation True to accept a reduction in texture depth
         */
    bool isSupported(bool allowTextureDegradation)
    {
        // A technique is supported if all materials referenced have a supported
        // technique, and the intermediate texture formats requested are supported
        // Material support is a cast-iron requirement, but if no texture formats 
        // are directly supported we can let the rendersystem create the closest 
        // match for the least demanding technique
        
        
        // Check output target pass is supported
        if (!mOutputTarget._isSupported())
        {
            return false;
        }
        
        // Check all target passes is supported
        foreach (targetPass; mTargetPasses)
        {
            if (!targetPass._isSupported())
            {
                return false;
            }
        }

        TextureManager texMgr = TextureManager.getSingleton();
        foreach (td; mTextureDefinitions)
        {
            // Firstly check MRTs
            if (td.formatList.length > 
                Root.getSingleton().getRenderSystem().getCapabilities().getNumMultiRenderTargets())
            {
                return false;
            }
            
            
            foreach (pfi; td.formatList)
            {
                
                // Check whether equivalent supported
                if(allowTextureDegradation)
                {
                    // Don't care about exact format so long as something is supported
                    if(texMgr.getNativeFormat(TextureType.TEX_TYPE_2D, pfi, TextureUsage.TU_RENDERTARGET) == PixelFormat.PF_UNKNOWN)
                    {
                        return false;
                    }
                }
                else
                {
                    // Need a format which is the same number of bits to pass
                    if (!texMgr.isEquivalentFormatSupported(TextureType.TEX_TYPE_2D, pfi, TextureUsage.TU_RENDERTARGET))
                    {
                        return false;
                    }
                }
            }
            
            //Check all render targets have same number of bits
            if( !Root.getSingleton().getRenderSystem().getCapabilities().
               hasCapability( Capabilities.RSC_MRT_DIFFERENT_BIT_DEPTHS ) && !td.formatList.empty() )
            {
                PixelFormat nativeFormat = texMgr.getNativeFormat( TextureType.TEX_TYPE_2D, td.formatList.front(),
                                                                  TextureUsage.TU_RENDERTARGET );
                size_t nativeBits = PixelUtil.getNumElemBits( nativeFormat );
                foreach( pfi; td.formatList[1..$])
                {
                    PixelFormat nativeTmp = texMgr.getNativeFormat( TextureType.TEX_TYPE_2D, pfi, TextureUsage.TU_RENDERTARGET );
                    if( PixelUtil.getNumElemBits( nativeTmp ) != nativeBits )
                    {
                        return false;
                    }
                }
            }
        }
        
        // Must be ok
        return true;
    }
    
    /** Assign a scheme name to this technique, used to switch between 
            multiple techniques by choice rather than for hardware compatibility.
        */
    void setSchemeName(string schemeName)
    {
        mSchemeName = schemeName;
    }
    /** Get the scheme name assigned to this technique. */
   string getSchemeName(){ return mSchemeName; }
    
    /** Set the name of the compositor logic assigned to this technique.
            Instances of this technique will be auto-coupled with the matching logic.
        */
    void setCompositorLogicName(string compositorLogicName) 
    { mCompositorLogicName = compositorLogicName; }
    /** Get the compositor logic name assigned to this technique */
   string getCompositorLogicName(){ return mCompositorLogicName; }
    
    /** Get parent object */
    ref Compositor getParent()
    {
        return mParent;
    }
private:
    /// Parent compositor
    Compositor mParent;
    /// Local texture definitions
    TextureDefinitions mTextureDefinitions;
    
    /// Intermediate target passes
    TargetPasses mTargetPasses;
    /// Output target pass (can be only one)
    CompositionTargetPass mOutputTarget;  
    
    /// Optional scheme name
    string mSchemeName;
    
    /// Optional compositor logic name
    string mCompositorLogicName;
    
}
/** @} */
/** @} */