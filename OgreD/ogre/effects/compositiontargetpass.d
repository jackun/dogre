module ogre.effects.compositiontargetpass;
//import std.container;

import ogre.compat;
import ogre.effects.compositiontechnique;
import ogre.effects.compositionpass;
import ogre.general.root;
import ogre.materials.materialmanager;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Effects
    *  @{
    */
/** Object representing one render to a RenderTarget or Viewport in the Ogre Composition
        framework.
     */
class CompositionTargetPass //: public CompositorInstAlloc
{
public:
    this(ref CompositionTechnique parent)
    {
        mParent = parent;
        mInputMode = InputMode.IM_NONE;
        mOnlyInitial = false;
        mVisibilityMask = 0xFFFFFFFF;
        mLodBias = 1.0f;
        mMaterialScheme = MaterialManager.DEFAULT_SCHEME_NAME;
        mShadowsEnabled = true;

        if (Root.getSingleton().getRenderSystem())
        {
            mMaterialScheme = Root.getSingleton().getRenderSystem()._getDefaultViewportMaterialScheme();
        }
    }
    ~this()
    {
        removeAllPasses();
    }
    
    /** Input mode of a TargetPass
        */
    enum InputMode
    {
        IM_NONE,        // No input
        IM_PREVIOUS     // Output of previous Composition in chain
    }
    //typedef vector<CompositionPass *>::type Passes;
    //typedef VectorIterator<Passes> PassIterator;
    alias CompositionPass[] Passes;
    /** Set input mode of this TargetPass
        */
    void setInputMode(InputMode mode)
    {
        mInputMode = mode;
    }
    /** Get input mode */
    InputMode getInputMode()
    {
        return mInputMode;
    }
    
    /** Set output local texture name */
    void setOutputName(string _out)
    {
        mOutputName = _out;
    }
    /** Get output local texture name */
   string getOutputName()
    {
        return mOutputName;
    }
    
    /** Set "only initial" flag. This makes that this target pass is only executed initially 
            after the effect has been enabled.
        */
    void setOnlyInitial(bool value)
    {
        mOnlyInitial = value;
    }
    /** Get "only initial" flag.
        */
    bool getOnlyInitial()
    {
        return mOnlyInitial;
    }
    
    /** Set the scene visibility mask used by this pass 
        */
    void setVisibilityMask(uint mask)
    {
        mVisibilityMask = mask;
    }
    /** Get the scene visibility mask used by this pass 
        */
    uint getVisibilityMask()
    {
        return mVisibilityMask;
    }
    
    /** Set the material scheme used by this target pass.
        @remarks
            Only applicable to targets that render the scene as
            one of their passes.
            @see Technique::setScheme.
        */
    void setMaterialScheme(string schemeName)
    {
        mMaterialScheme = schemeName;
    }
    /** Get the material scheme used by this target pass.
        @remarks
            Only applicable to targets that render the scene as
            one of their passes.
            @see Technique::setScheme.
        */
   string getMaterialScheme()
    {
        return mMaterialScheme;
    }
    
    /** Set whether shadows are enabled in this target pass.
        @remarks
            Only applicable to targets that render the scene as
            one of their passes.
        */
    void setShadowsEnabled(bool enabled)
    {
        mShadowsEnabled = enabled;
    }
    /** Get whether shadows are enabled in this target pass.
        @remarks
            Only applicable to targets that render the scene as
            one of their passes.
        */
    bool getShadowsEnabled()
    {
        return mShadowsEnabled;
    }
    /** Set the scene LOD bias used by this pass. The default is 1.0,
            everything below that means lower quality, higher means higher quality.
        */
    void setLodBias(float bias)
    {
        mLodBias = bias;
    }
    /** Get the scene LOD bias used by this pass 
        */
    float getLodBias()
    {
        return mLodBias;
    }
    
    /** Create a new pass, and return a pointer to it.
        */
    //TODO ref?
    CompositionPass createPass()
    {
        CompositionPass t = new CompositionPass(this);
        mPasses.insert(t);
        return t;
    }
    /** Remove a pass. It will also be destroyed.
        */
    void removePass(size_t idx)
    {
        assert (idx < mPasses.length, "Index out of bounds.");
        auto i = mPasses[idx];
        destroy (i);
        mPasses.removeFromArrayIdx(idx);
    }
    /** Get a pass.
        */
    ref CompositionPass getPass(size_t idx)
    {
        assert (idx < mPasses.length, "Index out of bounds.");
        return mPasses[idx];
    }
    /** Get the number of passes.
        */
    size_t getNumPasses()
    {
        return mPasses.length;
    }
    
    /** Remove all passes
        */
    void removeAllPasses()
    {
        foreach (i; mPasses)
        {
            destroy (i);
        }
        mPasses.clear();
    }
    
    /** Get an iterator over the Passes in this TargetPass. */
    //PassIterator getPassIterator();
    ref Passes getPasses()
    {
        return mPasses;
    }
    /** Get parent object */
    ref CompositionTechnique getParent()
    {
        return mParent;
    }
    
    /** Determine if this target pass is supported on the current rendering device. 
         */
    bool _isSupported()
    {
        // A target pass is supported if all passes are supported
        foreach(pass; mPasses)
        {
            if (!pass._isSupported())
            {
                return false;
            }
        }
        
        return true;
    }
    
private:
    /// Parent technique
    CompositionTechnique mParent;
    /// Input name
    InputMode mInputMode;
    /// (local) output texture
    string mOutputName;
    /// Passes
    Passes mPasses;
    /// This target pass is only executed initially after the effect
    /// has been enabled.
    bool mOnlyInitial;
    /// Visibility mask for this render
    uint mVisibilityMask;
    /// LOD bias of this render
    float mLodBias;
    /// Material scheme name
    string mMaterialScheme;
    /// Shadows option
    bool mShadowsEnabled;
}

/** @} */
/** @} */