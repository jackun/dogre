module ogre.materials.technique;

//import std.container;
import std.array;
import std.string;
import ogre.compat;
import ogre.config;
import ogre.scene.userobjectbindings;
import ogre.rendersystem.rendersystem;
import ogre.general.colourvalue;
import ogre.general.common;
import ogre.general.root;
import ogre.resources.texture;
import ogre.materials.pass;
import ogre.materials.material;
import ogre.materials.blendmode;
import ogre.materials.materialmanager;
import ogre.sharedptr;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Materials
 *  @{
 */

/** Class representing an approach to rendering this particular Material. 
 @remarks
 Ogre will attempt to use the best technique supported by the active hardware, 
 unless you specifically request a lower detail technique (say for distant
 rendering).
 */
class Technique// : public TechniqueAlloc
{
protected:
    // illumination pass state type
    enum IlluminationPassesState
    {
        IPS_COMPILE_DISABLED = -1,
        IPS_NOT_COMPILED = 0,
        IPS_COMPILED = 1
    }
    
    //typedef vector<Pass*>.type Passes;
    alias Pass[] Passes;
    /// List of primary passes
    Passes mPasses;
    /// List of derived passes, categorised into IlluminationStage (ordered)
    IlluminationPassList mIlluminationPasses;
    Material mParent; // raw pointer since we don't want child to stop parent's destruction
    bool mIsSupported;
    IlluminationPassesState mIlluminationPassesCompilationPhase;
    /// LOD level
    ushort mLodIndex;
    /** Scheme index, derived from scheme name but the names are held on
     MaterialManager, for speed an index is used here.
     */
    ushort mSchemeIndex;
    string mName; // optional name for the technique
    
    /// Internal method for clearing illumination pass list
    void clearIlluminationPasses()
    {
        foreach (i; mIlluminationPasses)
        {
            if (i.destroyOnShutdown)
            {
                i.pass.queueForDeletion();
            }
            destroy(i); // delete, but GC complains
        }
        mIlluminationPasses.clear();
    }
    
    /// Internal method - check for manually assigned illumination passes
    bool checkManuallyOrganisedIlluminationPasses()
    {
        // first check whether all passes have manually assigned illumination
        foreach (i; mPasses)
        {
            if (i.getIlluminationStage() == IlluminationStage.IS_UNKNOWN)
                return false;
        }
        
        // ok, all manually controlled, so just use that
        foreach (i; mPasses)
        {
            auto iPass = new IlluminationPass();
            iPass.destroyOnShutdown = false;
            iPass.originalPass = iPass.pass = i;
            iPass.stage = i.getIlluminationStage();
            mIlluminationPasses.insert(*iPass);
        }
        
        return true;
    }
    
    
    /** When casting shadow, if not using default Ogre shadow casting material, or 
     * nor using fixed function casting, mShadowCasterMaterial let you customize per material
     * shadow caster behavior
     */
    SharedPtr!Material mShadowCasterMaterial;
    /** When casting shadow, if not using default Ogre shadow casting material, or 
     * nor using fixed function casting, mShadowCasterMaterial let you customize per material
     * shadow caster behavior.There only material name is stored so that it can be loaded once all file parsed in a resource group.
     */
    string mShadowCasterMaterialName;
    /** When receiving shadow, if not using default Ogre shadow receiving material, or 
     * nor using fixed function texture projection receiving, mShadowReceiverMaterial let you customize per material
     * shadow caster behavior
     */
    SharedPtr!Material mShadowReceiverMaterial;
    /** When receiving shadow, if not using default Ogre shadow receiving material, or 
     * nor using fixed function texture projection receiving, mShadowReceiverMaterial let you customize per material
     * shadow caster behavior. There only material name is stored so that it can be loaded once all file parsed in a resource group.
     */
    string mShadowReceiverMaterialName; 
    
    // User objects binding.
    UserObjectBindings  mUserObjectBindings;
    
public:
    /** Directive used to manually control technique support based on the
     inclusion or exclusion of some factor.
     */
    alias uint IncludeOrExclude;
    enum : IncludeOrExclude
    {
        /// Inclusive - only support if present
        INCLUDE = 0,
        /// Exclusive - do not support if present
        EXCLUDE = 1
    }
    /// Rule controlling whether technique is deemed supported based on GPU vendor
    struct GPUVendorRule
    {
        GPUVendor vendor = GPUVendor.GPU_UNKNOWN;
        IncludeOrExclude includeOrExclude = EXCLUDE;
        
        this(GPUVendor v, IncludeOrExclude ie)
        {
            vendor = v;
            includeOrExclude = ie;
        }
    }
    /// Rule controlling whether technique is deemed supported based on GPU device name
    struct GPUDeviceNameRule
    {
        string devicePattern;
        IncludeOrExclude includeOrExclude = EXCLUDE;
        bool caseSensitive = false;
        
        this(string pattern, IncludeOrExclude ie, bool caseSen)
        {
            devicePattern = pattern;
            includeOrExclude = ie;
            caseSensitive = caseSen;
        }
        
    }
    //typedef vector<GPUVendorRule>.type GPUVendorRuleList;
    //typedef vector<GPUDeviceNameRule>.type GPUDeviceNameRuleList;
    alias GPUVendorRule[]     GPUVendorRuleList;
    alias GPUDeviceNameRule[] GPUDeviceNameRuleList;
protected:
    GPUVendorRuleList mGPUVendorRules;
    GPUDeviceNameRuleList mGPUDeviceNameRules;
public:
    /// Constructor
    this(Material parent)
    {
        mParent = parent;
        mIsSupported = false;
        mIlluminationPassesCompilationPhase = IlluminationPassesState.IPS_NOT_COMPILED;
        mLodIndex = 0;
        mSchemeIndex = 0;
    }
    /// Copy constructor
    this(Material parent, ref Technique oth)
    {
        mParent = parent;
        mLodIndex = 0;
        mSchemeIndex = 0;
        //this = oth; //illegal opAssign overload
        this.copyFrom(oth);
    }
    ~this()
    {
        //FIXME GC bugs in and deletes these beforehand?
        //removeAllPasses();
        //clearIlluminationPasses();
    }
    /** Indicates if this technique is supported by the current graphics card.
     @remarks
     This will only be correct after the Technique has been compiled, which is
     usually done from Material.compile.
     */
    bool isSupported()
    {
        return mIsSupported;
    }
    
    size_t calculateSize() //const
    {
        size_t memSize = 0;
        
        // Tally up passes
        foreach (i; mPasses)
        {
            memSize += i.calculateSize();
        }
        return memSize;
    }
    
    /** Internal compilation method; see Material.compile. 
     @return Any information explaining problems with the compile.
     */
    string _compile(bool autoManageTextureUnits)
    {
        //StringUtil.StrStreamType errors;
        string errors;
        
        mIsSupported = checkGPURules(errors);
        if (mIsSupported)
        {
            mIsSupported = checkHardwareSupport(autoManageTextureUnits, errors);
        }
        
        // Compile for categorised illumination on demand
        clearIlluminationPasses();
        mIlluminationPassesCompilationPhase = IlluminationPassesState.IPS_NOT_COMPILED;
        
        return errors; //.str();
        
    }
    /// Internal method for checking GPU vendor / device rules
    bool checkGPURules(ref string errors)
    {
        auto caps = Root.getSingleton().getRenderSystem().getCapabilities();
        
        string includeRules;
        bool includeRulesPresent = false;
        bool includeRuleMatched = false;
        
        // Check vendors first
        foreach (i; mGPUVendorRules)
        {
            if (i.includeOrExclude == INCLUDE)
            {
                includeRulesPresent = true;
                includeRules ~= caps.vendorToString(i.vendor) ~ " ";
                if (i.vendor == caps.getVendor())
                    includeRuleMatched = true;
            }
            else // EXCLUDE
            {
                if (i.vendor == caps.getVendor())
                {
                    errors ~= "Excluded GPU vendor: " ~ caps.vendorToString(i.vendor) ~ "\n";
                    return false;
                }
                
            }
        }
        
        if (includeRulesPresent && !includeRuleMatched)
        {
            errors ~= "Failed to match GPU vendor: " ~ includeRules ~ "\n";
            return false;
        }
        
        // now check device names
        includeRules = "";
        includeRulesPresent = false;
        includeRuleMatched = false;
        
        foreach (i; mGPUDeviceNameRules)
        {
            if (i.includeOrExclude == INCLUDE)
            {
                includeRulesPresent = true;
                includeRules ~= i.devicePattern ~ " ";
                //if (StringUtil.match(caps.getDeviceName(), i.devicePattern, i.caseSensitive))
                if(i.caseSensitive)
                    includeRuleMatched = (caps.getDeviceName() == i.devicePattern);
                else
                    includeRuleMatched = (caps.getDeviceName().toLower() == i.devicePattern.toLower());
            }
            else // EXCLUDE
            {
                //if (StringUtil.match(caps.getDeviceName(), i.devicePattern, i.caseSensitive))
                if((i.caseSensitive && caps.getDeviceName() == i.devicePattern) ||
                   ( !i.caseSensitive && caps.getDeviceName().toLower() == i.devicePattern.toLower()))
                {
                    errors ~= "Excluded GPU device: " ~ i.devicePattern ~ "\n";
                    return false;
                }
                
            }
        }
        
        if (includeRulesPresent && !includeRuleMatched)
        {
            errors ~= "Failed to match GPU device: " ~ includeRules ~ "\n";
            return false;
        }
        
        // passed
        return true;
    }
    
    /// Internal method for checking hardware support
    bool checkHardwareSupport(bool autoManageTextureUnits, ref string compileErrors)
    {
        // Go through each pass, checking requirements
        ushort passNum = 0;
        auto caps = Root.getSingleton().getRenderSystem().getCapabilities();
        ushort numTexUnits = caps.getNumTextureUnits();

        for (size_t i = 0; i<mPasses.length; i++)
        {
            Pass currPass = mPasses[i];
        //foreach (currPass; mPasses)
        //{
            // Adjust pass index
            currPass._notifyIndex(passNum);
            // Check for advanced blending operation support
            if((currPass.getSceneBlendingOperation() != SceneBlendOperation.SBO_ADD || 
                currPass.getSceneBlendingOperationAlpha() != SceneBlendOperation.SBO_ADD) && 
               !caps.hasCapability(Capabilities.RSC_ADVANCED_BLEND_OPERATIONS))
            {
                return false;       
            }
            // Check texture unit requirements
            size_t numTexUnitsRequested = currPass.getNumTextureUnitStates();
            // Don't trust getNumTextureUnits for programmable
            if(!currPass.hasFragmentProgram())
            {
                static if(OGRE_PRETEND_TEXTURE_UNITS) // && OGRE_PRETEND_TEXTURE_UNITS > 0
                {
                    if (OGRE_PRETEND_TEXTURE_UNITS_COUNT > 0 && numTexUnits > OGRE_PRETEND_TEXTURE_UNITS)
                        numTexUnits = OGRE_PRETEND_TEXTURE_UNITS_COUNT;
                }
                
                if (numTexUnitsRequested > numTexUnits)
                {
                    if (!autoManageTextureUnits)
                    {
                        // The user disabled auto pass split
                        compileErrors ~= "Pass " ~ std.conv.to!string(passNum) ~
                            ": Too many texture units for the current hardware and no splitting allowed.\n";
                        
                        return false;
                    }
                    else if (currPass.hasVertexProgram())
                    {
                        // Can't do this one, and can't split a programmable pass
                        compileErrors ~= "Pass " ~ std.conv.to!string(passNum) ~
                            ": Too many texture units for the current hardware and "
                                ~ "cannot split programmable passes.\n";
                        return false;
                    }
                }
            }
            if (currPass.hasComputeProgram()) //TODO Can i has compile error reason too?
            {
                // Check fragment program version
                if (!currPass.getComputeProgram().getAs().isSupported())
                {
                    // Can't do this one
                    compileErrors ~= "Pass " ~ std.conv.to!string(passNum) ~ 
                        ": Compute program " ~ currPass.getComputeProgram().get().getName()
                            ~ " cannot be used - ";
                    if (currPass.getComputeProgram().getAs().hasCompileError())
                        compileErrors ~= "compile error.\n";
                    else
                        compileErrors ~= "not supported.\n";
                    
                    return false;
                }
            }
            if (currPass.hasVertexProgram())
            {
                // Check vertex program version
                if (!currPass.getVertexProgram().getAs().isSupported() )
                {
                    // Can't do this one
                    compileErrors ~= "Pass " ~ std.conv.to!string(passNum) ~ 
                        ": Vertex program " ~ currPass.getVertexProgram().getAs().getName()
                            ~ " cannot be used - ";
                    if (currPass.getVertexProgram().getAs().hasCompileError())
                        compileErrors ~= "compile error.\n";
                    else
                        compileErrors ~= "not supported.\n";
                    
                    return false;
                }
            }
            if (currPass.hasTesselationHullProgram())
            {
                // Check tesselation control program version
                if (!currPass.getTesselationHullProgram().getAs().isSupported() )
                {
                    // Can't do this one
                    compileErrors ~= "Pass " ~ std.conv.to!string(passNum) ~
                        ": Tesselation Hull program " ~ currPass.getTesselationHullProgram().get().getName()
                            ~ " cannot be used - ";
                    if (currPass.getTesselationHullProgram().getAs().hasCompileError())
                        compileErrors ~= "compile error.\n";
                    else
                        compileErrors ~= "not supported.\n";
                    
                    return false;
                }
            }
            if (currPass.hasTesselationDomainProgram())
            {
                // Check tesselation control program version
                if (!currPass.getTesselationDomainProgram().getAs().isSupported() )
                {
                    // Can't do this one
                    compileErrors ~= "Pass " ~ std.conv.to!string(passNum) ~
                        ": Tesselation Domain program " ~ currPass.getTesselationDomainProgram().get().getName()
                            ~ " cannot be used - ";
                    if (currPass.getTesselationDomainProgram().getAs().hasCompileError())
                        compileErrors ~= "compile error.\n";
                    else
                        compileErrors ~= "not supported.\n";
                    
                    return false;
                }
            }
            if (currPass.hasGeometryProgram())
            {
                // Check geometry program version
                if (!currPass.getGeometryProgram().getAs().isSupported() )
                {
                    // Can't do this one
                    compileErrors ~= "Pass " ~ std.conv.to!string(passNum) ~ 
                        ": Geometry program " ~ currPass.getGeometryProgram().get().getName()
                            ~ " cannot be used - ";
                    if (currPass.getGeometryProgram().getAs().hasCompileError())
                        compileErrors ~= "compile error.\n";
                    else
                        compileErrors ~= "not supported.\n";
                    
                    return false;
                }
            }
            if (currPass.hasFragmentProgram())
            {
                // Check fragment program version
                if (!currPass.getFragmentProgram().getAs().isSupported())
                {
                    // Can't do this one
                    compileErrors ~= "Pass " ~ std.conv.to!string(passNum) ~ 
                        ": Fragment program " ~ currPass.getFragmentProgram().getAs().getName()
                            ~ " cannot be used - ";
                    if (currPass.getFragmentProgram().getAs().hasCompileError())
                        compileErrors ~= "compile error.\n";
                    else
                        compileErrors ~= "not supported.\n";
                    
                    return false;
                }
            }
            else
            {
                // Check a few fixed-function options in texture layers
                auto texi = currPass.getTextureUnitStates();
                size_t texUnit = 0;
                //while (texi.hasMoreElements())
                foreach (tex; texi)
                {
                    // Any Cube textures? NB we make the assumption that any
                    // card capable of running fragment programs can support
                    // cubic textures, which has to be true, surely?
                    if (tex.is3D() && !caps.hasCapability(Capabilities.RSC_CUBEMAPPING))
                    {
                        // Fail
                        compileErrors ~= "Pass " ~ std.conv.to!string(passNum) ~
                            " Tex " ~ std.conv.to!string(texUnit) ~
                                ": Cube maps not supported by current environment.\n";
                        return false;
                    }
                    // Any 3D textures? NB we make the assumption that any
                    // card capable of running fragment programs can support
                    // 3D textures, which has to be true, surely?
                    if (((tex.getTextureType() == TextureType.TEX_TYPE_3D) || 
                         (tex.getTextureType() == TextureType.TEX_TYPE_2D_ARRAY)) && 
                        !caps.hasCapability(Capabilities.RSC_TEXTURE_3D))
                    {
                        // Fail
                        compileErrors ~= "Pass " ~ std.conv.to!string(passNum) ~
                            " Tex " ~ std.conv.to!string(texUnit) ~
                                ": Volume textures not supported by current environment.\n";
                        return false;
                    }
                    // Any Dot3 blending?
                    if (tex.getColourBlendMode().operation == LayerBlendOperationEx.LBX_DOTPRODUCT &&
                        !caps.hasCapability(Capabilities.RSC_DOT3))
                    {
                        // Fail
                        compileErrors ~= "Pass " ~ std.conv.to!string(passNum) ~
                            " Tex " ~ std.conv.to!string(texUnit) ~
                                ": DOT3 blending not supported by current environment.\n";
                        return false;
                    }
                    ++texUnit;
                }
                
                // We're ok on operations, now we need to check # texture units
                if (!currPass.hasFragmentProgram())
                {
                    // Keep splitting this pass so long as units requested > gpu units
                    while (numTexUnitsRequested > numTexUnits)
                    {
                        // chop this pass into many passes
                        currPass = currPass._split(numTexUnits);
                        numTexUnitsRequested = currPass.getNumTextureUnitStates();
                        // Advance pass number
                        ++passNum;
                        // Reset iterator
                        //i = mPasses.begin() + passNum;
                        // Move the new pass to the right place (will have been created
                        // at the end, may be other passes in between)
                        assert(mPasses[$-1] == currPass);
                        //std.copy_backward(i, (mPasses.end()-1), mPasses.end());

                        //FIXME Do copy_backward. What is this for?
                        foreach_reverse(p; mPasses[passNum..$-1])
                            mPasses ~= p;
                        //*i = currPass;
                        mPasses[i] = currPass;
                        // Adjust pass index
                        currPass._notifyIndex(passNum);
                    }
                }
            }
            
            passNum++;
        }
        // If we got this far, we're ok
        return true;
    }
    /** Internal method for splitting the passes into illumination passes. 
     * @todo D version has same logics still?
     */        
    void _compileIlluminationPasses()
    {
        clearIlluminationPasses();
        
        if (!checkManuallyOrganisedIlluminationPasses())
        {
            // Build based on our own heuristics
            
            //Passes.iterator i, iend;
            int i = 0;
            
            IlluminationStage iStage = IlluminationStage.IS_AMBIENT;
            
            bool haveAmbient = false;
            while (i < mPasses.length)
            {
                IlluminationPass* iPass;
                Pass p = mPasses[i];
                final switch(iStage)
                {
                    case IlluminationStage.IS_AMBIENT:
                        // Keep looking for ambient only
                        if (p.isAmbientOnly())
                        {
                            // Add this pass wholesale
                            iPass = new IlluminationPass();
                            iPass.destroyOnShutdown = false;
                            iPass.originalPass = iPass.pass = p;
                            iPass.stage = iStage;
                            mIlluminationPasses.insert(*iPass);
                            haveAmbient = true;
                            // progress to next pass
                            ++i;
                        }
                        else
                        {
                            // Split off any ambient part
                            if (p.getAmbient() != ColourValue.Black ||
                                p.getSelfIllumination() != ColourValue.Black ||
                                p.getAlphaRejectFunction() != CompareFunction.CMPF_ALWAYS_PASS)
                            {
                                // Copy existing pass
                                Pass newPass = new Pass(this, p.getIndex(), p);
                                if (newPass.getAlphaRejectFunction() != CompareFunction.CMPF_ALWAYS_PASS)
                                {
                                    // Alpha rejection passes must retain their transparency, so
                                    // we allow the texture units, but override the colour functions
                                    //Pass.TextureUnitStateIterator tusi = newPass.getTextureUnitStateIterator();
                                    auto tusi = newPass.getTextureUnitStates();
                                    foreach (tus; tusi)
                                    {
                                        tus.setColourOperationEx(LayerBlendOperationEx.LBX_SOURCE1, LayerBlendSource.LBS_CURRENT);
                                    }
                                }
                                else
                                {
                                    // Remove any texture units
                                    newPass.removeAllTextureUnitStates();
                                }
                                // Remove any fragment program
                                if (newPass.hasFragmentProgram())
                                    newPass.setFragmentProgram("");
                                // We have to leave vertex program alone (if any) and
                                // just trust that the author is using light bindings, which
                                // we will ensure there are none in the ambient pass
                                newPass.setDiffuse(0, 0, 0, newPass.getDiffuse().a);  // Preserving alpha
                                newPass.setSpecular(ColourValue.Black);
                                
                                // Calculate hash value for new pass, because we are compiling
                                // illumination passes on demand, which will loss hash calculate
                                // before it add to render queue first time.
                                newPass._recalculateHash();
                                
                                iPass = new IlluminationPass();
                                iPass.destroyOnShutdown = true;
                                iPass.originalPass = p;
                                iPass.pass = newPass;
                                iPass.stage = iStage;
                                
                                mIlluminationPasses.insert(*iPass);
                                haveAmbient = true;
                                
                            }
                            
                            if (!haveAmbient)
                            {
                                // Make up a new basic pass
                                Pass newPass = new Pass(this, p.getIndex());
                                newPass.setAmbient(ColourValue.Black);
                                newPass.setDiffuse(ColourValue.Black);
                                
                                // Calculate hash value for new pass, because we are compiling
                                // illumination passes on demand, which will loss hash calculate
                                // before it add to render queue first time.
                                newPass._recalculateHash();
                                
                                iPass = new IlluminationPass();
                                iPass.destroyOnShutdown = true;
                                iPass.originalPass = p;
                                iPass.pass = newPass;
                                iPass.stage = iStage;
                                mIlluminationPasses.insert(*iPass);
                                haveAmbient = true;
                            }
                            // This means we're done with ambients, progress to per-light
                            iStage = IlluminationStage.IS_PER_LIGHT;
                        }
                        break;
                    case IlluminationStage.IS_PER_LIGHT:
                        if (p.getIteratePerLight())
                        {
                            // If this is per-light already, use it directly
                            iPass = new IlluminationPass();
                            iPass.destroyOnShutdown = false;
                            iPass.originalPass = iPass.pass = p;
                            iPass.stage = iStage;
                            mIlluminationPasses.insert(*iPass);
                            // progress to next pass
                            ++i;
                        }
                        else
                        {
                            // Split off per-light details (can only be done for one)
                            if (p.getLightingEnabled() &&
                                (p.getDiffuse() != ColourValue.Black ||
                             p.getSpecular() != ColourValue.Black))
                            {
                                // Copy existing pass
                                Pass newPass = new Pass(this, p.getIndex(), p);
                                if (newPass.getAlphaRejectFunction() != CompareFunction.CMPF_ALWAYS_PASS)
                                {
                                    // Alpha rejection passes must retain their transparency, so
                                    // we allow the texture units, but override the colour functions
                                    //Pass.TextureUnitStateIterator tusi = newPass.getTextureUnitStateIterator();
                                    auto tusi = newPass.getTextureUnitStates();
                                    foreach (tus; tusi)
                                    {
                                        tus.setColourOperationEx(LayerBlendOperationEx.LBX_SOURCE1, LayerBlendSource.LBS_CURRENT);
                                    }
                                }
                                else
                                {
                                    // remove texture units
                                    newPass.removeAllTextureUnitStates();
                                }
                                // remove fragment programs
                                if (newPass.hasFragmentProgram())
                                    newPass.setFragmentProgram("");
                                // Cannot remove vertex program, have to assume that
                                // it will process diffuse lights, ambient will be turned off
                                newPass.setAmbient(ColourValue.Black);
                                newPass.setSelfIllumination(ColourValue.Black);
                                // must be additive
                                newPass.setSceneBlending(SceneBlendFactor.SBF_ONE, SceneBlendFactor.SBF_ONE);
                                
                                // Calculate hash value for new pass, because we are compiling
                                // illumination passes on demand, which will loss hash calculate
                                // before it add to render queue first time.
                                newPass._recalculateHash();
                                
                                iPass = new IlluminationPass();
                                iPass.destroyOnShutdown = true;
                                iPass.originalPass = p;
                                iPass.pass = newPass;
                                iPass.stage = iStage;
                                
                                mIlluminationPasses.insert(*iPass);
                                
                            }
                            // This means the end of per-light passes
                            iStage = IlluminationStage.IS_DECAL;
                        }
                        break;
                    case IlluminationStage.IS_DECAL:
                        // We just want a 'lighting off' pass to finish off
                        // and only if there are texture units
                        if (p.getNumTextureUnitStates() > 0)
                        {
                            if (!p.getLightingEnabled())
                            {
                                // we assume this pass already combines as required with the scene
                                iPass = new IlluminationPass();
                                iPass.destroyOnShutdown = false;
                                iPass.originalPass = iPass.pass = p;
                                iPass.stage = iStage;
                                mIlluminationPasses.insert(*iPass);
                            }
                            else
                            {
                                // Copy the pass and tweak away the lighting parts
                                Pass newPass = new Pass(this, p.getIndex(), p);
                                newPass.setAmbient(ColourValue.Black);
                                newPass.setDiffuse(0, 0, 0, newPass.getDiffuse().a);  // Preserving alpha
                                newPass.setSpecular(ColourValue.Black);
                                newPass.setSelfIllumination(ColourValue.Black);
                                newPass.setLightingEnabled(false);
                                newPass.setIteratePerLight(false, false);
                                // modulate
                                newPass.setSceneBlending(SceneBlendFactor.SBF_DEST_COLOUR, SceneBlendFactor.SBF_ZERO);
                                
                                // Calculate hash value for new pass, because we are compiling
                                // illumination passes on demand, which will loss hash calculate
                                // before it add to render queue first time.
                                newPass._recalculateHash();
                                
                                // NB there is nothing we can do about vertex & fragment
                                // programs here, so people will just have to make their
                                // programs friendly-like if they want to use this technique
                                iPass = new IlluminationPass();
                                iPass.destroyOnShutdown = true;
                                iPass.originalPass = p;
                                iPass.pass = newPass;
                                iPass.stage = iStage;
                                mIlluminationPasses.insert(*iPass);
                                
                            }
                        }
                        ++i; // always increment on decal, since nothing more to do with this pass
                        
                        break;
                    case IlluminationStage.IS_UNKNOWN:
                        break;
                }
            }
        }
        
    }
    
    /** Creates a new Pass for this Technique.
     @remarks
     A Pass is a single rendering pass, i.e. a single draw of the given material.
     Note that if you create a pass without a fragment program, during compilation of the
     material the pass may be split into multiple passes if the graphics card cannot
     handle the number of texture units requested. For passes with fragment programs, however, 
     the number of passes you create will never be altered, so you have to make sure 
     that you create an alternative fallback Technique for if a card does not have 
     enough facilities for what you're asking for.
     */
    Pass createPass()
    {
        auto newPass = new Pass(this, cast(ushort)(mPasses.length));
        mPasses.insert(newPass);
        debug(STDERR) std.stdio.stderr.writeln(this.mName," Technique.createPass: ", mPasses);
        return newPass;
    }
    /** Retrieves the Pass with the given index. */
    ref Pass getPass(ushort index)
    {
        //assert(index < mPasses.length && "Index out of bounds");
        return mPasses[index];
    }
    /** Retrieves the Pass matching name.
     Returns 0 if name match is not found.
     */
    Pass getPass(string name)
    {
        Pass foundPass = null; //TODO Reffing null . compile error?
        
        // iterate through techniques to find a match
        foreach(i; mPasses)
        {
            if ( i.getName() == name )
            {
                foundPass = i;
                break;
            }
        }
        
        return foundPass;
    }
    /** Retrieves the number of passes. */
    ushort getNumPasses()
    {
        return cast(ushort)(mPasses.length);
    }
    /** Removes the Pass with the given index. */
    void removePass(ushort index)
    {
        //assert(index < mPasses.length && "Index out of bounds"); // RangeError anyway
        //Passes.iterator i = mPasses.begin() + index;
        auto i = mPasses[index];
        i.queueForDeletion();
        mPasses.removeFromArrayIdx(index);
        // Adjust passes index
        //for (; i != mPasses.end(); ++i, ++index)
        for (; index < mPasses.length; index++)
        {
            mPasses[index]._notifyIndex(index);
        }
    }
    
    /** Removes all Passes from this Technique. */
    void removeAllPasses()
    {
        foreach (i; mPasses)
        {
            i.queueForDeletion();
        }
        mPasses.clear();
    }
    /** Move a pass from source index to destination index.
     If successful then returns true.
     * @todo Check linearRemove and insertAfter.
     */
    bool movePass(ushort sourceIndex,ushort destinationIndex)
    {
        bool moveSuccessful = false;
        
        // don't move the pass if source == destination
        if (sourceIndex == destinationIndex) return true;
        
        if( (sourceIndex < mPasses.length) && (destinationIndex < mPasses.length))
        {
            //Passes.iterator i = mPasses.begin() + sourceIndex;
            //Passes.iterator DestinationIterator = mPasses.begin() + destinationIndex;
            
            Pass pass = mPasses[sourceIndex];
            mPasses.removeFromArrayIdx(sourceIndex);
            
            //i = mPasses.begin() + destinationIndex;
            
            mPasses.insertBeforeIdx(destinationIndex+1, pass);
            
            // Adjust passes index
            ushort beginIndex, endIndex;
            if (destinationIndex > sourceIndex)
            {
                beginIndex = sourceIndex;
                endIndex = destinationIndex;
            }
            else
            {
                beginIndex = destinationIndex;
                endIndex = sourceIndex;
            }
            for (ushort index = beginIndex; index <= endIndex; ++index)
            {
                mPasses[index]._notifyIndex(index);
            }
            moveSuccessful = true;
        }
        
        return moveSuccessful;
    }
    
    //typedef VectorIterator<Passes> PassIterator;
    /** Gets an iterator over the passes in this Technique. */
    //PassIterator getPassIterator();
    ref Passes getPasses()
    {
        return mPasses;
    }

    //typedef VectorIterator<IlluminationPassList> IlluminationPassIterator;
    /** Gets an iterator over the illumination-stage categorised passes. */
    //IlluminationPassIterator getIlluminationPassIterator();
    IlluminationPassList getIlluminationPasses()
    {
        return mIlluminationPasses;
    }
    /// Gets the parent Material
    Material getParent(){ return mParent; }
    
    /** Overloaded operator to copy on Technique to another. */
    //Technique& operator=(Technique& rhs);
    void copyFrom(Technique rhs)
    {
        mName = rhs.mName;
        this.mIsSupported = rhs.mIsSupported;
        this.mLodIndex = rhs.mLodIndex;
        this.mSchemeIndex = rhs.mSchemeIndex;
        this.mShadowCasterMaterial = rhs.mShadowCasterMaterial;
        this.mShadowCasterMaterialName = rhs.mShadowCasterMaterialName;
        this.mShadowReceiverMaterial = rhs.mShadowReceiverMaterial;
        this.mShadowReceiverMaterialName = rhs.mShadowReceiverMaterialName;
        this.mGPUVendorRules = rhs.mGPUVendorRules;
        this.mGPUDeviceNameRules = rhs.mGPUDeviceNameRules;
        
        // copy passes
        removeAllPasses();
        
        foreach (i; rhs.mPasses)
        {
            Pass p = new Pass(this, i.getIndex(), i);
            mPasses.insert(p);
        }
        // Compile for categorised illumination on demand
        clearIlluminationPasses();
        mIlluminationPassesCompilationPhase = IlluminationPassesState.IPS_NOT_COMPILED;
        //return this;
    }
    
    /// Gets the resource group of the ultimate parent Material
    string getResourceGroup()
    {
        return mParent.getGroup();
    }
    
    /** Returns true if this Technique involves transparency. 
     @remarks
     This basically boils down to whether the first pass
     has a scene blending factor. Even if the other passes 
     do not, the base colour, including parts of the original 
     scene, may be used for blending, Therefore we have to treat
     the whole Technique as transparent.
     */
    bool isTransparent()
    {
        if (mPasses.empty())
        {
            return false;
        }
        else
        {
            // Base decision on the transparency of the first pass
            return mPasses[0].isTransparent();
        }
    }
    
    /** Returns true if this Technique has transparent sorting enabled. 
     @remarks
     This basically boils down to whether the first pass
     has transparent sorting enabled or not
     */
    bool isTransparentSortingEnabled()
    {
        if (mPasses.empty())
        {
            return true;
        }
        else
        {
            // Base decision on the transparency of the first pass
            return mPasses[0].getTransparentSortingEnabled();
        }
    }
    
    /** Returns true if this Technique has transparent sorting forced. 
     @remarks
     This basically boils down to whether the first pass
     has transparent sorting forced or not
     */
    bool isTransparentSortingForced()
    {
        if (mPasses.empty())
        {
            return false;
        }
        else
        {
            // Base decision on the first pass
            return mPasses[0].getTransparentSortingForced();
        }
    }
    
    /** Internal prepare method, derived from call to Material.prepare. */
    void _prepare()
    {
        assert (mIsSupported , "This technique is not supported");
        // Load each pass
        foreach (i; mPasses)
        {
            i._prepare();
        }
        
        foreach (il; mIlluminationPasses)
        {
            if(il.pass != il.originalPass)
                il.pass._prepare();
        }
    }
    
    /** Internal unprepare method, derived from call to Material.unprepare. */
    void _unprepare()
    {
        // Unload each pass
        foreach (i; mPasses)
        {
            i._unprepare();
        }
    }
    
    /** Internal load method, derived from call to Material.load. */
    void _load()
    {
        assert (mIsSupported , "This technique is not supported");
        // Load each pass
        foreach (i; mPasses)
        {
            i._load();
        }
        
        foreach (il; mIlluminationPasses)
        {
            if(il.pass != il.originalPass)
                il.pass._load();
        }
        
        if (!mShadowCasterMaterial.isNull())
        {
            mShadowCasterMaterial.get().load();
        }
        else if (!mShadowCasterMaterialName.empty())
        {
            // in case we could not get material as it wasn't yet parsed/existent at that time.
            mShadowCasterMaterial = MaterialManager.getSingleton().getByName(mShadowCasterMaterialName);
            if (!mShadowCasterMaterial.isNull())
                mShadowCasterMaterial.get().load();
        }
        if (!mShadowReceiverMaterial.isNull())
        {
            mShadowReceiverMaterial.get().load();
        }
        else if (!mShadowReceiverMaterialName.empty())
        {
            // in case we could not get material as it wasn't yet parsed/existent at that time.
            mShadowReceiverMaterial = MaterialManager.getSingleton().getByName(mShadowReceiverMaterialName);
            if (!mShadowReceiverMaterial.isNull())
                mShadowReceiverMaterial.get().load();
        }
    }
    /** Internal unload method, derived from call to Material.unload. */
    void _unload()
    {
        // Unload each pass
        foreach (i; mPasses)
        {
            i._unload();
        }   
    }
    
    // Is this loaded?
    bool isLoaded()
    {
        // Only supported technique will be loaded
        return mParent.isLoaded() && mIsSupported;
    }
    
    /** Tells the technique that it needs recompilation. */
    void _notifyNeedsRecompile()
    {
        // Disable require to recompile when splitting illumination passes
        if (mIlluminationPassesCompilationPhase != IlluminationPassesState.IPS_COMPILE_DISABLED)
        {
            mParent._notifyNeedsRecompile();
        }
    }
    
    
    /** return this material specific  shadow casting specific material
     */
    SharedPtr!Material getShadowCasterMaterial()
    { 
        return mShadowCasterMaterial; 
    }
    /** set this material specific  shadow casting specific material
     */
    void setShadowCasterMaterial(SharedPtr!Material val)
    { 
        if (val.isNull())
        {
            mShadowCasterMaterial.setNull();
            mShadowCasterMaterialName.clear();
        }
        else
        {
            mShadowCasterMaterial = val; 
            mShadowCasterMaterialName = val.get().getName();
        }
    }
    /** set this material specific  shadow casting specific material
     */
    void setShadowCasterMaterial(string name)
    { 
        mShadowCasterMaterialName = name;
        mShadowCasterMaterial = MaterialManager.getSingleton().getByName(name); 
    }

    /** return this material specific shadow receiving specific material
     */
    SharedPtr!Material getShadowReceiverMaterial()
    { 
        return mShadowReceiverMaterial; 
    }
    
    /** set this material specific  shadow receiving specific material
     */
    void setShadowReceiverMaterial(SharedPtr!Material val)
    { 
        if (val.isNull())
        {
            mShadowReceiverMaterial.setNull();
            mShadowReceiverMaterialName.clear();
        }
        else
        {
            mShadowReceiverMaterial = val; 
            mShadowReceiverMaterialName = val.get().getName();
        }
    }
    /** set this material specific  shadow receiving specific material
     */
    void setShadowReceiverMaterial(string name)
    { 
        mShadowReceiverMaterialName = name;
        mShadowReceiverMaterial = MaterialManager.getSingleton().getByName(name); 
    }
    
    // -------------------------------------------------------------------------------
    // The following methods are to make migration from previous versions simpler
    // and to make code easier to write when dealing with simple materials
    // They set the properties which have been moved to Pass for all Techniques and all Passes
    
    /** Sets the point size properties for every Pass in this Technique.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setPointSize
     */
    void setPointSize(Real ps)
    {
        foreach (i; mPasses)
        {
            i.setPointSize(ps);
        }
        
    }
    
    /** Sets the ambient colour reflectance properties for every Pass in every Technique.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setAmbient
     */
    void setAmbient(Real red, Real green, Real blue)
    {
        setAmbient(ColourValue(red, green, blue));
    }
    
    /** Sets the ambient colour reflectance properties for every Pass in every Technique.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setAmbient
     */
    void setAmbient(ColourValue ambient)
    {
        foreach (i; mPasses)
        {
            i.setAmbient(ambient);
        }
    }
    
    /** Sets the diffuse colour reflectance properties of every Pass in every Technique.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setDiffuse
     */
    void setDiffuse(Real red, Real green, Real blue, Real alpha)
    {
        foreach (i; mPasses)
        {
            i.setDiffuse(red, green, blue, alpha);
        }
    }
    
    /** Sets the diffuse colour reflectance properties of every Pass in every Technique.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setDiffuse
     */
    void setDiffuse(ColourValue diffuse)
    {
        setDiffuse(diffuse.r, diffuse.g, diffuse.b, diffuse.a);
    }
    
    /** Sets the specular colour reflectance properties of every Pass in every Technique.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setSpecular
     */
    void setSpecular(Real red, Real green, Real blue, Real alpha)
    {
        foreach (i; mPasses)
        {
            i.setSpecular(red, green, blue, alpha);
        }
    }
    
    /** Sets the specular colour reflectance properties of every Pass in every Technique.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setSpecular
     */
    void setSpecular(ColourValue specular)
    {
        setSpecular(specular.r, specular.g, specular.b, specular.a);
    }
    
    /** Sets the shininess properties of every Pass in every Technique.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setShininess
     */
    void setShininess(Real val)
    {
        foreach (i; mPasses)
        {
            i.setShininess(val);
        }
    }
    
    /** Sets the amount of self-illumination of every Pass in every Technique.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setSelfIllumination
     */
    void setSelfIllumination(Real red, Real green, Real blue)
    {
        setSelfIllumination(ColourValue(red, green, blue));
    }
    
    /** Sets the amount of self-illumination of every Pass in every Technique.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setSelfIllumination
     */
    void setSelfIllumination(ColourValue selfIllum)
    {
        foreach (i; mPasses)
        {
            i.setSelfIllumination(selfIllum);
        }
    }
    
    /** Sets whether or not each Pass renders with depth-buffer checking on or not.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setDepthCheckEnabled
     */
    void setDepthCheckEnabled(bool enabled)
    {
        foreach (i; mPasses)
        {
            i.setDepthCheckEnabled(enabled);
        }
    }
    
    /** Sets whether or not each Pass renders with depth-buffer writing on or not.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setDepthWriteEnabled
     */
    void setDepthWriteEnabled(bool enabled)
    {
        foreach (i; mPasses)
        {
            i.setDepthWriteEnabled(enabled);
        }
    }
    
    /** Sets the function used to compare depth values when depth checking is on.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setDepthFunction
     */
    void setDepthFunction( CompareFunction func )
    {
        foreach (i; mPasses)
        {
            i.setDepthFunction(func);
        }
    }
    
    /** Sets whether or not colour buffer writing is enabled for each Pass.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setColourWriteEnabled
     */
    void setColourWriteEnabled(bool enabled)
    {
        foreach (i; mPasses)
        {
            i.setColourWriteEnabled(enabled);
        }
    }
    
    /** Sets the culling mode for each pass  based on the 'vertex winding'.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setCullingMode
     */
    void setCullingMode( CullingMode mode )
    {
        foreach (i; mPasses)
        {
            i.setCullingMode(mode);
        }
    }
    
    /** Sets the manual culling mode, performed by CPU rather than hardware.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setManualCullingMode
     */
    void setManualCullingMode( ManualCullingMode mode )
    {
        foreach (i; mPasses)
        {
            i.setManualCullingMode(mode);
        }
    }
    
    /** Sets whether or not dynamic lighting is enabled for every Pass.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setLightingEnabled
     */
    void setLightingEnabled(bool enabled)
    {
        foreach (i; mPasses)
        {
            i.setLightingEnabled(enabled);
        }
    }
    
    /** Sets the type of light shading required
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setShadingMode
     */
    void setShadingMode( ShadeOptions mode )
    {
        foreach (i; mPasses)
        {
            i.setShadingMode(mode);
        }
    }
    
    /** Sets the fogging mode applied to each pass.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setFog
     */
    void setFog(
        bool overrideScene,
        FogMode mode = FogMode.FOG_NONE,
        ColourValue colour = ColourValue.White,
        Real expDensity = 0.001, Real linearStart = 0.0, Real linearEnd = 1.0 )
    {
        foreach (i; mPasses)
        {
            i.setFog(overrideScene, mode, colour, expDensity, linearStart, linearEnd);
        }
    }
    
    /** Sets the depth bias to be used for each Pass.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setDepthBias
     */
    void setDepthBias(float constantBias, float slopeScaleBias)
    {
        foreach (i; mPasses)
        {
            i.setDepthBias(constantBias, slopeScaleBias);
        }
    }
    
    /** Set texture filtering for every texture unit in every Pass
     @note
     This property actually exists on the TextureUnitState class
     For simplicity, this method allows you to set these properties for 
     every current TeextureUnitState, If you need more precision, retrieve the  
     Pass and TextureUnitState instances and set the property there.
     @see TextureUnitState.setTextureFiltering
     */
    void setTextureFiltering(TextureFilterOptions filterType)
    {
        foreach (i; mPasses)
        {
            i.setTextureFiltering(filterType);
        }
    }
    /** Sets the anisotropy level to be used for all textures.
     @note
     This property has been moved to the TextureUnitState class, which is accessible via the 
     Technique and Pass. For simplicity, this method allows you to set these properties for 
     every current TeextureUnitState, If you need more precision, retrieve the Technique, 
     Pass and TextureUnitState instances and set the property there.
     @see TextureUnitState.setTextureAnisotropy
     */
    void setTextureAnisotropy(uint maxAniso)
    {
        foreach (i; mPasses)
        {
            i.setTextureAnisotropy(maxAniso);
        }
    }
    
    /** Sets the kind of blending every pass has with the existing contents of the scene.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setSceneBlending
     */
    void setSceneBlending(SceneBlendType sbt )
    {
        foreach (i; mPasses)
        {
            i.setSceneBlending(sbt);
        }
    }
    /** Sets the kind of blending every pass has with the existing contents of the scene, using individual factors both color and alpha channels
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setSeparateSceneBlending
     */
    void setSeparateSceneBlending(SceneBlendType sbt,SceneBlendType sbta )
    {
        foreach (i; mPasses)
        {
            i.setSeparateSceneBlending(sbt, sbta);
        }
    }
    
    /** Allows very fine control of blending every Pass with the existing contents of the scene.
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setSceneBlending
     */
    void setSceneBlending(SceneBlendFactor sourceFactor,SceneBlendFactor destFactor)
    {
        foreach (i; mPasses)
        {
            i.setSceneBlending(sourceFactor, destFactor);
        }
    }
    
    /** Allows very fine control of blending every Pass with the existing contents of the scene, using individual factors both color and alpha channels
     @note
     This property actually exists on the Pass class. For simplicity, this method allows 
     you to set these properties for every current Pass within this Technique. If 
     you need more precision, retrieve the Pass instance and set the
     property there.
     @see Pass.setSeparateSceneBlending
     */
    void setSeparateSceneBlending(SceneBlendFactor sourceFactor,SceneBlendFactor destFactor,SceneBlendFactor sourceFactorAlpha,SceneBlendFactor destFactorAlpha)
    {
        foreach (i; mPasses)
        {
            i.setSeparateSceneBlending(sourceFactor, destFactor, sourceFactorAlpha, destFactorAlpha);
        }
    }
    
    /** Assigns a level-of-detail (LOD) index to this Technique.
     @remarks
     As noted previously, as well as providing fallback support for various
     graphics cards, multiple Technique objects can also be used to implement
     material LOD, where the detail of the material diminishes with distance to 
     save rendering power.
     @par
     By default, all Techniques have a LOD index of 0, which means they are the highest
     level of detail. Increasing LOD indexes are lower levels of detail. You can 
     assign more than one Technique to the same LOD index, meaning that the best 
     Technique that is supported at that LOD index is used. 
     @par
     You should not leave gaps in the LOD sequence; Ogre will allow you to do this
     and will continue to function as if the LODs were sequential, but it will 
     confuse matters.
     */
    void setLodIndex(ushort index)
    {
        mLodIndex = index;
        _notifyNeedsRecompile();
    }
    /** Gets the level-of-detail index assigned to this Technique. */
    ushort getLodIndex(){ return mLodIndex; }
    
    /** Set the 'scheme name' for this technique. 
     @remarks
     Material schemes are used to control top-level switching from one
     set of techniques to another. For example, you might use this to 
     define 'high', 'medium' and 'low' complexity levels on materials
     to allow a user to pick a performance / quality ratio. Another
     possibility is that you have a fully HDR-enabled pipeline for top
     machines, rendering all objects using unclamped shaders, and a 
     simpler pipeline for others; this can be implemented using 
     schemes.
     @par
     Every technique belongs to a scheme - if you don't specify one, the
     Technique belongs to the scheme called 'Default', which is also the
     scheme used to render by default. The active scheme is set one of
     two ways - either by calling Viewport.setMaterialScheme, or
     by manually calling MaterialManager.setActiveScheme.
     */
    void setSchemeName(string schemeName)
    {
        mSchemeIndex = MaterialManager.getSingleton()._getSchemeIndex(schemeName);
        _notifyNeedsRecompile();
    }
    /** Returns the scheme to which this technique is assigned.
     @see Technique.setSchemeName
     */
    string getSchemeName()
    {
        return MaterialManager.getSingleton()._getSchemeName(mSchemeIndex);
    }
    
    /// Internal method for getting the scheme index
    ushort _getSchemeIndex()
    {
        return mSchemeIndex;
    }
    
    /** Is depth writing going to occur on this technique? */
    bool isDepthWriteEnabled()
    {
        if (mPasses.empty())
        {
            return false;
        }
        else
        {
            // Base decision on the depth settings of the first pass
            return mPasses[0].getDepthWriteEnabled();
        }
    }
    
    /** Is depth checking going to occur on this technique? */
    bool isDepthCheckEnabled()
    {
        if (mPasses.empty())
        {
            return false;
        }
        else
        {
            // Base decision on the depth settings of the first pass
            return mPasses[0].getDepthCheckEnabled();
        }
    }
    
    /** Exists colour writing disabled pass on this technique? */
    bool hasColourWriteDisabled()
    {
        if (mPasses.empty())
        {
            return true;
        }
        else
        {
            // Base decision on the colour write settings of the first pass
            return !mPasses[0].getColourWriteEnabled();
        }
    }
    
    /** Set the name of the technique.
     @remarks
     The use of technique name is optional.  Its useful in material scripts where a material could inherit
     from another material and only want to modify a particular technique.
     */
    void setName(string name)
    {
        mName = name;
    }
    /// Gets the name of the technique
    string getName(){ return mName; }
    
    /** Applies texture names to Texture Unit State with matching texture name aliases.
     All passes, and Texture Unit States within the technique are checked.
     If matching texture aliases are found then true is returned.

     @param
     aliasList is a map container of texture alias, texture name pairs
     @param
     apply set true to apply the texture aliases else just test to see if texture alias matches are found.
     @return
     True if matching texture aliases were found in the Technique.
     */
    bool applyTextureAliases(AliasTextureNamePairList aliasList,bool apply = true)
    {
        // iterate through passes and apply texture alias
        bool testResult = false;
        
        foreach(i; mPasses)
        {
            if (i.applyTextureAliases(aliasList, apply))
                testResult = true;
        }
        
        return testResult;
    }
    
    
    /** Add a rule which manually influences the support for this technique based
     on a GPU vendor.
     @remarks
     You can use this facility to manually control whether a technique is
     considered supported, based on a GPU vendor. You can add inclusive
     or exclusive rules, and you can add as many of each as you like. If
     at least one inclusive rule is added, a technique is considered 
     unsupported if it does not match any of those inclusive rules. If exclusive rules are
     added, the technique is considered unsupported if it matches any of
     those inclusive rules. 
     @note
     Any rule for the same vendor will be removed before adding this one.
     @param vendor The GPU vendor
     @param includeOrExclude Whether this is an inclusive or exclusive rule
     */
    void addGPUVendorRule(GPUVendor vendor, IncludeOrExclude includeOrExclude)
    {
        addGPUVendorRule(GPUVendorRule(vendor, includeOrExclude));
    }
    /** Add a rule which manually influences the support for this technique based
     on a GPU vendor.
     @remarks
     You can use this facility to manually control whether a technique is
     considered supported, based on a GPU vendor. You can add inclusive
     or exclusive rules, and you can add as many of each as you like. If
     at least one inclusive rule is added, a technique is considered 
     unsupported if it does not match any of those inclusive rules. If exclusive rules are
     added, the technique is considered unsupported if it matches any of
     those inclusive rules. 
     @note
     Any rule for the same vendor will be removed before adding this one.
     */
    void addGPUVendorRule(GPUVendorRule rule)
    {
        // remove duplicates
        removeGPUVendorRule(rule.vendor);
        mGPUVendorRules.insert(rule);
    }
    
    /** Removes a matching vendor rule.
     @see addGPUVendorRule
     */
    void removeGPUVendorRule(GPUVendor vendor)
    {
        for (int i = 0; i < mGPUVendorRules.length; )
        {
            auto r = mGPUVendorRules[i];
            if (r.vendor == vendor)
                mGPUVendorRules.removeFromArrayIdx(i);
            else
                ++i;
        }
    }
    
    //typedef ConstVectorIterator<GPUVendorRuleList> GPUVendorRuleIterator;
    /// Get an iterator over the currently registered vendor rules.
    //GPUVendorRuleIterator getGPUVendorRuleIterator();
    
    GPUVendorRuleList getGPUVendorRules()
    {
        return mGPUVendorRules;
    }
    
    /** Add a rule which manually influences the support for this technique based
     on a pattern that matches a GPU device name (e.g. '*8800*').
     @remarks
     You can use this facility to manually control whether a technique is
     considered supported, based on a GPU device name pattern. You can add inclusive
     or exclusive rules, and you can add as many of each as you like. If
     at least one inclusive rule is added, a technique is considered 
     unsupported if it does not match any of those inclusive rules. If exclusive rules are
     added, the technique is considered unsupported if it matches any of
     those inclusive rules. The pattern you supply can include wildcard
     characters ('*') if you only want to match part of the device name.
     @note
     Any rule for the same device pattern will be removed before adding this one.
     @param devicePattern The GPU vendor
     @param includeOrExclude Whether this is an inclusive or exclusive rule
     @param caseSensitive Whether the match is case sensitive or not
     */
    void addGPUDeviceNameRule(string devicePattern, IncludeOrExclude includeOrExclude, bool caseSensitive = false)
    {
        addGPUDeviceNameRule(GPUDeviceNameRule(devicePattern, includeOrExclude, caseSensitive));
    }
    /** Add a rule which manually influences the support for this technique based
     on a pattern that matches a GPU device name (e.g. '*8800*').
     @remarks
     You can use this facility to manually control whether a technique is
     considered supported, based on a GPU device name pattern. You can add inclusive
     or exclusive rules, and you can add as many of each as you like. If
     at least one inclusive rule is added, a technique is considered 
     unsupported if it does not match any of those inclusive rules. If exclusive rules are
     added, the technique is considered unsupported if it matches any of
     those inclusive rules. The pattern you supply can include wildcard
     characters ('*') if you only want to match part of the device name.
     @note
     Any rule for the same device pattern will be removed before adding this one.
     */
    void addGPUDeviceNameRule(GPUDeviceNameRule rule)
    {
        // remove duplicates
        removeGPUDeviceNameRule(rule.devicePattern);
        mGPUDeviceNameRules.insert(rule);
    }
    /** Removes a matching device name rule.
     @see addGPUDeviceNameRule
     */
    void removeGPUDeviceNameRule(string devicePattern)
    {
        //foreach (i; mGPUDeviceNameRules)
        for (int i = 0; i < mGPUDeviceNameRules.length; )
        {
            auto r = mGPUDeviceNameRules[i];
            if (r.devicePattern == devicePattern)
                mGPUDeviceNameRules.removeFromArrayIdx(i);
            else
                ++i;
        }
    }
    
    //typedef ConstVectorIterator<GPUDeviceNameRuleList> GPUDeviceNameRuleIterator;
    /// Get an iterator over the currently registered device name rules.
    //GPUDeviceNameRuleIterator getGPUDeviceNameRuleIterator();
    GPUDeviceNameRuleList getGPUDeviceNameRules()
    {
        return mGPUDeviceNameRules;
    }
    
    /** Return an instance of user objects binding associated with this class.
     You can use it to associate one or more custom objects with this class instance.
     @see UserObjectBindings.setUserAny.
     */
    ref UserObjectBindings getUserObjectBindings() { return mUserObjectBindings; }
    
    /** Return an instance of user objects binding associated with this class.
     You can use it to associate one or more custom objects with this class instance.
     @see UserObjectBindings.setUserAny.        
     */
    ref const(UserObjectBindings) getUserObjectBindings() const { return mUserObjectBindings; }
    
}

/** @} */
/** @} */