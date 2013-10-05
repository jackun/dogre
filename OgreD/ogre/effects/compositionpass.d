module ogre.effects.compositionpass;

import ogre.compat;
import ogre.config;
import ogre.general.colourvalue;
import ogre.effects.compositiontargetpass;
import ogre.materials.material;
import ogre.general.common;
import ogre.materials.materialmanager;
import ogre.rendersystem.rendersystem;
import ogre.rendersystem.renderqueue;
import ogre.sharedptr;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Effects
    *  @{
    */
/** Object representing one pass or operation in a composition sequence. This provides a 
        method to conveniently interleave RenderSystem commands between Render Queues.
     */
class CompositionPass //: public CompositorInstAlloc
{
public:
    this(ref CompositionTargetPass parent)
    {
        mParent = parent;
        mType = PassType.PT_RENDERQUAD;
        mIdentifier = 0;
        mFirstRenderQueue = RenderQueueGroupID.RENDER_QUEUE_BACKGROUND;
        mLastRenderQueue = RenderQueueGroupID.RENDER_QUEUE_SKIES_LATE;
        mMaterialScheme = null;
        mClearBuffers = FrameBufferType.FBT_COLOUR|FrameBufferType.FBT_DEPTH;
        mClearColour = ColourValue(0.0,0.0,0.0,0.0);
        mClearDepth = 1.0f;
        mClearStencil = 0;
        mStencilCheck = false;
        mStencilFunc = CompareFunction.CMPF_ALWAYS_PASS;
        mStencilRefValue = 0;
        mStencilMask = 0xFFFFFFFF;
        mStencilFailOp = StencilOperation.SOP_KEEP;
        mStencilDepthFailOp = StencilOperation.SOP_KEEP;
        mStencilPassOp = StencilOperation.SOP_KEEP;
        mStencilTwoSidedOperation = false;
        mQuadCornerModified = false;
        mQuadLeft = -1;
        mQuadTop = 1;
        mQuadRight = 1;
        mQuadBottom = -1;
        mQuadFarCorners = false;
        mQuadFarCornersViewSpace = false;
    }
    ~this() {}
    
    /** Enumeration that enumerates the various composition pass types.
        */
    enum PassType
    {
        PT_CLEAR,           // Clear target to one colour
        PT_STENCIL,         // Set stencil operation
        PT_RENDERSCENE,     // Render the scene or part of it
        PT_RENDERQUAD,      // Render a full screen quad
        PT_RENDERCUSTOM     // Render a custom sequence
    }
    
    /** Set the type of composition pass */
    void setType(PassType type)
    {
        mType = type;
    }
    /** Get the type of composition pass */
    PassType getType()
    {
        return mType;
    }
    
    /** Set an identifier for this pass. This identifier can be used to
            "listen in" on this pass with an CompositorInstance::Listener. 
        */
    void setIdentifier(uint id)
    {
        mIdentifier = id;
    }
    /** Get the identifier for this pass */
    uint getIdentifier()
    {
        return mIdentifier;
    }
    
    /** Set the material used by this pass
            @note applies when PassType is RENDERQUAD 
        */
    void setMaterial(SharedPtr!Material mat)
    {
        mMaterial = mat;
    }
    /** Set the material used by this pass 
            @note applies when PassType is RENDERQUAD 
        */
    void setMaterialName(string name)
    {
        mMaterial = MaterialManager.getSingleton().getByName(name);
    }
    /** Get the material used by this pass 
            @note applies when PassType is RENDERQUAD 
        */
    ref SharedPtr!Material getMaterial()
    {
        return mMaterial;
    }
    /** Set the first render queue to be rendered in this pass (inclusive) 
            @note applies when PassType is RENDERSCENE
        */
    void setFirstRenderQueue(ubyte id)
    {
        mFirstRenderQueue = id;
    }
    /** Get the first render queue to be rendered in this pass (inclusive) 
            @note applies when PassType is RENDERSCENE
        */
    ubyte getFirstRenderQueue()
    {
        return mFirstRenderQueue;
    }
    /** Set the last render queue to be rendered in this pass (inclusive) 
            @note applies when PassType is RENDERSCENE
        */
    void setLastRenderQueue(ubyte id)
    {
        mLastRenderQueue = id;
    }
    /** Get the last render queue to be rendered in this pass (inclusive) 
            @note applies when PassType is RENDERSCENE
        */
    ubyte getLastRenderQueue()
    {
        return mLastRenderQueue;
    }
    
    /** Set the material scheme used by this pass.
        @remarks
            Only applicable to passes that render the scene.
            @see Technique::setScheme.
        */
    void setMaterialScheme(string schemeName)
    {
        mMaterialScheme = schemeName;
    }
    /** Get the material scheme used by this pass.
        @remarks
            Only applicable to passes that render the scene.
            @see Technique::setScheme.
        */
   string getMaterialScheme()
    {
        return mMaterialScheme;
    }
    
    /** Would be nice to have for RENDERSCENE:
            flags to:
                exclude transparents
                override material (at least -- color)
        */
    
    /** Set the viewport clear buffers  (defaults to FBT_COLOUR|FBT_DEPTH)
            @param val is a combination of FBT_COLOUR, FBT_DEPTH, FBT_STENCIL.
            @note applies when PassType is CLEAR
        */
    void setClearBuffers(uint val)
    {
        mClearBuffers = val;
    }
    /** Get the viewport clear buffers.
            @note applies when PassType is CLEAR
        */
    uint getClearBuffers()
    {
        return mClearBuffers;
    }
    /** Set the viewport clear colour (defaults to 0,0,0,0) 
            @note applies when PassType is CLEAR
         */
    void setClearColour(ColourValue val)
    {
        mClearColour = val;
    }
    /** Get the viewport clear colour (defaults to 0,0,0,0) 
            @note applies when PassType is CLEAR
         */
   ColourValue getClearColour()
    {
        return mClearColour;
    }
    /** Set the viewport clear depth (defaults to 1.0) 
            @note applies when PassType is CLEAR
        */
    void setClearDepth(Real depth)
    {
        mClearDepth = depth;
    }
    /** Get the viewport clear depth (defaults to 1.0) 
            @note applies when PassType is CLEAR
        */
    Real getClearDepth()
    {
        return mClearDepth;
    }
    /** Set the viewport clear stencil value (defaults to 0) 
            @note applies when PassType is CLEAR
        */
    void setClearStencil(uint value)
    {
        mClearStencil = value;
    }
    /** Get the viewport clear stencil value (defaults to 0) 
            @note applies when PassType is CLEAR
        */
    uint getClearStencil()
    {
        return mClearStencil;
    }
    
    /** Set stencil check on or off.
            @note applies when PassType is STENCIL
        */
    void setStencilCheck(bool value)
    {
        mStencilCheck = value;
    }
    /** Get stencil check enable.
            @note applies when PassType is STENCIL
        */
    bool getStencilCheck()
    {
        return mStencilCheck;
    }
    /** Set stencil compare function.
            @note applies when PassType is STENCIL
        */
    void setStencilFunc(CompareFunction value)
    {
        mStencilFunc = value;
    }
    /** Get stencil compare function.
            @note applies when PassType is STENCIL
        */
    CompareFunction getStencilFunc()
    {
        return mStencilFunc;
    }
    /** Set stencil reference value.
            @note applies when PassType is STENCIL
        */
    void setStencilRefValue(uint value)
    {
        mStencilRefValue = value;
    }
    /** Get stencil reference value.
            @note applies when PassType is STENCIL
        */
    uint getStencilRefValue()
    {
        return mStencilRefValue;
    }
    /** Set stencil mask.
            @note applies when PassType is STENCIL
        */
    void setStencilMask(uint value)
    {
        mStencilMask = value;
    }
    /** Get stencil mask.
            @note applies when PassType is STENCIL
        */
    uint getStencilMask()
    {
        return mStencilMask;
    }
    /** Set stencil fail operation.
            @note applies when PassType is STENCIL
        */
    void setStencilFailOp(StencilOperation value)
    {
        mStencilFailOp = value;
    }
    /** Get stencil fail operation.
            @note applies when PassType is STENCIL
        */
    StencilOperation getStencilFailOp()
    {
        return mStencilFailOp;
    }
    /** Set stencil depth fail operation.
            @note applies when PassType is STENCIL
        */
    void setStencilDepthFailOp(StencilOperation value)
    {
        mStencilDepthFailOp = value;
    }
    /** Get stencil depth fail operation.
            @note applies when PassType is STENCIL
        */
    StencilOperation getStencilDepthFailOp()
    {
        return mStencilDepthFailOp;
    }
    /** Set stencil pass operation.
            @note applies when PassType is STENCIL
        */
    void setStencilPassOp(StencilOperation value)
    {
        mStencilPassOp = value;
    }
    /** Get stencil pass operation.
            @note applies when PassType is STENCIL
        */
    StencilOperation getStencilPassOp()
    {
        return mStencilPassOp;
    }
    /** Set two sided stencil operation.
            @note applies when PassType is STENCIL
        */
    void setStencilTwoSidedOperation(bool value)
    {
        mStencilTwoSidedOperation = value;
    }
    /** Get two sided stencil operation.
            @note applies when PassType is STENCIL
        */
    bool getStencilTwoSidedOperation()
    {
        return mStencilTwoSidedOperation;
    }
    
    /// Inputs (for material used for rendering the quad)
    struct InputTex
    {
        /// Name (local) of the input texture (empty == no input)
        string name = null;
        /// MRT surface index if applicable
        size_t mrtIndex = 0;
        this(string _name, size_t _mrtIndex = 0)
        {
            name = _name;
            mrtIndex= _mrtIndex;
        }
    }
    
    /** Set an input local texture. An empty string clears the input.
            @param id    Input to set. Must be in 0..OGRE_MAX_TEXTURE_LAYERS-1
            @param input Which texture to bind to this input. An empty string clears the input.
            @param mrtIndex Which surface of an MRT to retrieve
            @note applies when PassType is RENDERQUAD 
        */
    void setInput(size_t id,string input=null, size_t mrtIndex=0)
    {
        assert(id < OGRE_MAX_TEXTURE_LAYERS);
        mInputs[id] = InputTex(input, mrtIndex);
    }
    
    /** Get the value of an input.
            @param id    Input to get. Must be in 0..OGRE_MAX_TEXTURE_LAYERS-1.
            @note applies when PassType is RENDERQUAD 
        */
   InputTex getInput(size_t id)
    {
        assert(id < OGRE_MAX_TEXTURE_LAYERS);
        return mInputs[id];
    }
    
    /** Get the number of inputs used.
            @note applies when PassType is RENDERQUAD 
        */
    size_t getNumInputs()
    {
        size_t count = 0;
        for(size_t x=0; x<OGRE_MAX_TEXTURE_LAYERS; ++x)
        {
            if(mInputs[x].name !is null)
                count = x+1;
        }
        return count;
    }
    
    /** Clear all inputs.
            @note applies when PassType is RENDERQUAD 
        */
    void clearAllInputs()
    {
        for(size_t x=0; x<OGRE_MAX_TEXTURE_LAYERS; ++x)
        {
            mInputs[x].name.clear();
        }
    }
    /** Get parent object 
            @note applies when PassType is RENDERQUAD 
        */
    ref CompositionTargetPass getParent()
    {
        return mParent;
    }
    
    /** Determine if this target pass is supported on the current rendering device. 
         */
    bool _isSupported()
    {
        // A pass is supported if material referenced have a supported technique
        
        if (mType == PassType.PT_RENDERQUAD)
        {
            if (mMaterial.isNull())
            {
                return false;
            }
            
            mMaterial.getAs().compile();
            if (mMaterial.getAs().getNumSupportedTechniques() == 0)
            {
                return false;
            }
        }
        
        return true;
    }
    /** Set quad normalised positions [-1;1]x[-1;1]
            @note applies when PassType is RENDERQUAD
         */
    void setQuadCorners(Real left,Real top,Real right,Real bottom)
    {
        mQuadCornerModified=true;
        mQuadLeft = left;
        mQuadTop = top;
        mQuadRight = right;
        mQuadBottom = bottom;
    }
    
    /** Get quad normalised positions [-1;1]x[-1;1]
            @note applies when PassType is RENDERQUAD 
         */
    bool getQuadCorners(ref Real left,ref Real top,ref Real right,ref Real bottom)
    {
        left = mQuadLeft;
        top = mQuadTop;
        right = mQuadRight;
        bottom = mQuadBottom;
        return mQuadCornerModified;
    }

    /** Sets the use of camera frustum far corners provided in the quad's normals
            @note applies when PassType is RENDERQUAD 
        */
    void setQuadFarCorners(bool farCorners, bool farCornersViewSpace)
    {
        mQuadFarCorners = farCorners;
        mQuadFarCornersViewSpace = farCornersViewSpace;
    }
    
    /** Returns true if camera frustum far corners are provided in the quad.
            @note applies when PassType is RENDERQUAD 
        */
    bool getQuadFarCorners()
    {
        return mQuadFarCorners;
    }
    
    /** Returns true if the far corners provided in the quad are in view space
            @note applies when PassType is RENDERQUAD 
        */
    bool getQuadFarCornersViewSpace()
    {
        return mQuadFarCornersViewSpace;
    }
    
    /** Set the type name of this custom composition pass.
            @note applies when PassType is RENDERCUSTOM
            @see CompositorManager::registerCustomCompositionPass
        */
    void setCustomType(string customType)
    {
        mCustomType = customType;
    }
    
    /** Get the type name of this custom composition pass.
            @note applies when PassType is RENDERCUSTOM
            @see CompositorManager::registerCustomCompositionPass
        */
   string getCustomType()
    {
        return mCustomType;
    }
    
private:
    /// Parent technique
    CompositionTargetPass mParent;
    /// Type of composition pass
    PassType mType;
    /// Identifier for this pass
    uint mIdentifier;
    /// Material used for rendering
    SharedPtr!Material mMaterial;
    /// [first,last] render queue to render this pass (in case of PT_RENDERSCENE)
    ubyte mFirstRenderQueue;
    ubyte mLastRenderQueue;
    /// Material scheme name
    string mMaterialScheme;
    /// Clear buffers (in case of PT_CLEAR)
    uint mClearBuffers;
    /// Clear colour (in case of PT_CLEAR)
    ColourValue mClearColour;
    /// Clear depth (in case of PT_CLEAR)
    Real mClearDepth;
    /// Clear stencil value (in case of PT_CLEAR)
    uint mClearStencil;
    /// Inputs (for material used for rendering the quad)
    /// An empty string signifies that no input is used
    InputTex[OGRE_MAX_TEXTURE_LAYERS] mInputs;
    /// Stencil operation parameters
    bool mStencilCheck;
    CompareFunction mStencilFunc; 
    uint mStencilRefValue;
    uint mStencilMask;
    StencilOperation mStencilFailOp;
    StencilOperation mStencilDepthFailOp;
    StencilOperation mStencilPassOp;
    bool mStencilTwoSidedOperation;
    
    /// true if quad should not cover whole screen
    bool mQuadCornerModified;
    /// quad positions in normalised coordinates [-1;1]x[-1;1] (in case of PT_RENDERQUAD)
    Real mQuadLeft;
    Real mQuadTop;
    Real mQuadRight;
    Real mQuadBottom;
    
    bool mQuadFarCorners, mQuadFarCornersViewSpace;
    //The type name of the custom composition pass.
    string mCustomType;
}
/** @} */
/** @} */