module ogre.materials.material;

//import std.container;
import ogre.compat;
import ogre.resources.resource;
import ogre.resources.resourcemanager;
import ogre.lod.lodstrategy;
import ogre.scene.renderable;
import ogre.general.colourvalue;
import ogre.general.generals;
import ogre.lod.lodstrategymanager;
import ogre.materials.blendmode;
import ogre.materials.materialmanager;
import ogre.general.log;
import ogre.sharedptr;

/** \addtogroup Core
*  @{
*/
/** \addtogroup Materials
*  @{
*/


/** Class encapsulates rendering properties of an object.
@remarks
Ogre's material class encapsulates ALL aspects of the visual appearance,
of an object. It also includes other flags which 
might not be traditionally thought of as material properties such as 
culling modes and depth buffer settings, but these affect the 
appearance of the rendered object and are convenient to attach to the 
material since it keeps all the settings in one place. This is 
different to Direct3D which treats a material as just the colour 
components (diffuse, specular) and not texture maps etc. An Ogre 
Material can be thought of as equivalent to a 'Shader'.
@par
A Material can be rendered in multiple different ways depending on the
hardware available. You may configure a Material to use high-complexity
fragment shaders, but these won't work on every card; Therefore a Technique
is an approach to creating the visual effect you are looking for. You are advised
to create fallback techniques with lower hardware requirements if you decide to
use advanced features. In addition, you also might want lower-detail techniques
for distant geometry.
@par
Each technique can be made up of multiple passes. A fixed-function pass
may combine multiple texture layers using multitexrtuing, but Ogre can 
break that into multiple passes automatically if the active card cannot
handle that many simultaneous textures. Programmable passes, however, cannot
be split down automatically, so if the active graphics card cannot handle the
technique which contains these passes, OGRE will try to find another technique
which the card can do. If, at the end of the day, the card cannot handle any of the
techniques which are listed for the material, the engine will render the 
geometry plain white, which should alert you to the problem.
@par
Ogre comes configured with a number of default settings for a newly 
created material. These can be changed if you wish by retrieving the 
default material settings through 
SceneManager.getDefaultMaterialSettings. Any changes you make to the 
Material returned from this method will apply to any materials created 
from this point onward.
*/
class Material : Resource
{
    //To be friends, might need to move to same module
    //friend class SceneManager;
    //friend class MaterialManager;
    
public:
    /// distance list used to specify LOD
    alias Real[] LodValueList;
    //typedef ConstVectorIterator<LodValueList> LodValueIterator;
protected:
    
    
    /** Internal method which sets the material up from the default settings.
    */
    void applyDefaults()
    {
        SharedPtr!Material defaults = MaterialManager.getSingleton().getDefaultSettings();
        debug(STDERR) std.stdio.stderr.writeln("Material.applyDefaults:", !defaults.isNull());
        if (!defaults.isNull())
        {
            // save name & handle
            string savedName = mName;
            string savedGroup = mGroup;
            ResourceHandle savedHandle = mHandle;
            ManualResourceLoader savedLoader = mLoader;
            bool savedManual = mIsManual;
            this.copyFrom(defaults.getAs()); //or opAssign?
            // restore name & handle
            mName = savedName;
            mHandle = savedHandle;
            mGroup = savedGroup;
            mLoader = savedLoader;
            mIsManual = savedManual;
        }
        mCompilationRequired = true;
    }
    
    alias Technique[] Techniques;
    /// All techniques, supported and unsupported
    Techniques mTechniques;
    /// Supported techniques of any sort
    Techniques mSupportedTechniques;
    //alias Technique[ushort] LodTechniques; //std.map allows multiple same key entries?
    alias Technique[ushort] LodTechniques;
    alias LodTechniques[ushort] BestTechniquesBySchemeList;
    /** Map of scheme . list of LOD techniques. 
        Current scheme is set on MaterialManager,
        and can be set per Viewport for auto activation.
    */
    BestTechniquesBySchemeList mBestTechniquesBySchemeList;
    
    LodValueList mUserLodValues;
    LodValueList mLodValues;
    LodStrategy mLodStrategy;
    bool mReceiveShadows;
    bool mTransparencyCastsShadows;
    /// Does this material require compilation?
    bool mCompilationRequired;
    /// Text description of why any techniques are not supported
    string mUnsupportedReasons;
    
    /** Insert a supported technique into the local collections. */
    void insertSupportedTechnique(ref Technique t)
    {
        mSupportedTechniques.insert(t);
        // get scheme
        ushort schemeIndex = t._getSchemeIndex();
        auto i = schemeIndex in mBestTechniquesBySchemeList;
        LodTechniques* lodtechs;
        if (i is null)
        {
            //lodtechs = new_T(LodTechniques, MEMCATEGORY_RESOURCE);
            mBestTechniquesBySchemeList[schemeIndex] = null;
            lodtechs = &mBestTechniquesBySchemeList[schemeIndex];
        }
        else
        {
            lodtechs = i;
        }
        
        // Insert won't replace if supported technique for this scheme/lod is
        // already there, which is what we want
        if ( (t.getLodIndex() in (*lodtechs)) is null)
            (*lodtechs)[t.getLodIndex()] = t;
        
    }
    
    /** Clear the best technique list.
    */
    void clearBestTechniqueList()
    {
        foreach (i; mBestTechniquesBySchemeList)
        {
            destroy(i);
        }
        mBestTechniquesBySchemeList.clear();
    }
    
    /** Overridden from Resource.
    */
    override void prepareImpl()
    {
        // compile if required
        if (mCompilationRequired)
            compile();
        
        // Load all supported techniques
        foreach (i; mSupportedTechniques)
        {
            i._prepare();
        }
    }
    
    /** Overridden from Resource.
    */
    override void unprepareImpl()
    {
        // Load all supported techniques
        foreach (i; mSupportedTechniques)
        {
            i._unprepare();
        }
    }
    
    /** Overridden from Resource.
    */
    override void loadImpl()
    {
        
        // Load all supported techniques
        foreach (i; mSupportedTechniques)
        {
            i._load();
        }
        
    }
    
    /** Unloads the material, frees resources etc.
    @see
    Resource
    */
    override void unloadImpl()
    {
        // Unload all supported techniques
        foreach (i; mSupportedTechniques)
        {
            i._unload();
        }
    }
    
    /// @copydoc Resource.calculateSize
    override size_t calculateSize() //const
    {
        size_t memSize = 0;
        
        // Tally up techniques
        foreach (i; mTechniques)
        {
            memSize += i.calculateSize();
        }
        
        memSize += bool.sizeof * 3;
        memSize += mUnsupportedReasons.length * char.sizeof;
        memSize += LodStrategy.sizeof;
        
        memSize += Resource.calculateSize();
        
        return memSize;
    }
    
public:
    
    /** Constructor - use resource manager's create method rather than this.
    */
    this(ResourceManager creator,string name, ResourceHandle handle,
        string group, bool isManual = false, ManualResourceLoader loader = null)
    {
        super(creator, name, handle, group, isManual, loader);
        mReceiveShadows = true;
        mTransparencyCastsShadows = false;
        mCompilationRequired = true;
        // Override isManual, not applicable for Material (we always want to call loadImpl)
        if(isManual)
        {
            mIsManual = false;
            LogManager.getSingleton().logMessage("Material " ~ name ~ 
                                                 " was requested with isManual=true, but this is not applicable " 
                                                 "for materials; the flag has been reset to false");
        }
        
        // Initialise to default strategy
        mLodStrategy = LodStrategyManager.getSingleton().getDefaultStrategy();
        
        mLodValues.insert(0.0f);
        
        applyDefaults();
        
        /* For consistency with stringInterface, but we don't add any parameters here
        That's because the Resource implementation of StringInterface is to
        list all the options that need to be set before loading, of which 
        we have none as such. Full details can be set through scripts.
        */ 
        createParamDictionary("Material");
    }
    
    ~this()
    {
        removeAllTechniques();
        // have to call this here reather than in Resource destructor
        // since calling methods in base destructors causes crash
        unload(); 
    }
    /** Assignment operator to allow easy copying between materials.
    */
    //illegal for class
    //ref Material opAssign( ref Material rhs )
    Material copyFrom( Material rhs )
    {
        mName = rhs.mName;
        mGroup = rhs.mGroup;
        mCreator = rhs.mCreator;
        mIsManual = rhs.mIsManual;
        mLoader = rhs.mLoader;
        mHandle = rhs.mHandle;
        mSize = rhs.mSize;
        mReceiveShadows = rhs.mReceiveShadows;
        mTransparencyCastsShadows = rhs.mTransparencyCastsShadows;
        
        mLoadingState = rhs.mLoadingState;
        mIsBackgroundLoaded = rhs.mIsBackgroundLoaded;
        
        // Copy Techniques
        this.removeAllTechniques();
        
        foreach(i; rhs.mTechniques)
        {
            auto t = this.createTechnique();
            t.copyFrom(i);
            if (i.isSupported())
            //if (i.isSupported())//FIXME Which Technique.isSupported(), t or i? Probably i
            {
                insertSupportedTechnique(t);
            }
        }
        
        // Also copy LOD information
        mUserLodValues = rhs.mUserLodValues;
        mLodValues = rhs.mLodValues;
        mLodStrategy = rhs.mLodStrategy;
        mCompilationRequired = rhs.mCompilationRequired;
        // illumination passes are not compiled right away so
        // mIsLoaded state should still be the same as the original material
        assert(isLoaded() == rhs.isLoaded());
        
        return this;
    }
    
    /** Determines if the material has any transparency with the rest of the scene (derived from 
        whether any Techniques say they involve transparency).
    */
    bool isTransparent()
    {
        // Check each technique
        foreach (i; mTechniques)
        {
            if ( i.isTransparent() )
                return true;
        }
        return false;
    }
    
    /** Sets whether objects using this material will receive shadows.
    @remarks
        This method allows a material to opt out of receiving shadows, if
        it would otherwise do so. Shadows will not be cast on any objects
        unless the scene is set up to support shadows 
        (@see SceneManager.setShadowTechnique), and not all techniques cast
        shadows on all objects. In any case, if you have a need to prevent
        shadows being received by material, this is the method you call to
        do it.
    @note 
        Transparent materials never receive shadows despite this setting. 
        The default is to receive shadows.
    */
    void setReceiveShadows(bool enabled) { mReceiveShadows = enabled; }
    /** Returns whether or not objects using this material will receive shadows. */
    bool getReceiveShadows(){ return mReceiveShadows; }
    
    /** Sets whether objects using this material be classified as opaque to the shadow caster system.
    @remarks
    This method allows a material to cast a shadow, even if it is transparent.
    By default, transparent materials neither cast nor receive shadows. Shadows
    will not be cast on any objects unless the scene is set up to support shadows 
    (@see SceneManager.setShadowTechnique), and not all techniques cast
    shadows on all objects.
    */
    void setTransparencyCastsShadows(bool enabled) { mTransparencyCastsShadows = enabled; }
    /** Returns whether or not objects using this material be classified as opaque to the shadow caster system. */
    bool getTransparencyCastsShadows(){ return mTransparencyCastsShadows; }
    
    /** Creates a new Technique for this Material.
    @remarks
        A Technique is a single way of rendering geometry in order to achieve the effect
        you are intending in a material. There are many reason why you would want more than
        one - the main one being to handle variable graphics card abilities; you might have
        one technique which is impressive but only runs on 4th-generation graphics cards, 
        for example. In this case you will want to create at least one fallback Technique.
        OGRE will work out which Techniques a card can support and pick the best one.
    @par
        If multiple Techniques are available, the order in which they are created is 
        important - the engine will consider lower-indexed Techniques to be preferable
        to higher-indexed Techniques, ie when asked for the 'best' technique it will
        return the first one in the technique list which is supported by the hardware.
    */
    Technique createTechnique()
    {
        debug(STDERR) std.stdio.stderr.writeln("Material.createTechnique:", mTechniques.length);
        auto t = new Technique(this);
        mTechniques.insert(t);
        mCompilationRequired = true;
        return t;
    }
    
    /** Gets the indexed technique. */
    Technique getTechnique(ushort index)
    {
        //assert (index < mTechniques.length, "Index out of bounds.");
        return mTechniques[index];
    }
    /** searches for the named technique.
        Return 0 if technique with name is not found
    */
    Technique getTechnique(string name)
    {
        // iterate through techniques to find a match
        foreach(t; mTechniques)
        {
            if ( t.getName() == name )
            {
                return t;
            }
        }
        
        return null;
    }
    /** Retrieves the number of techniques. */
    ushort getNumTechniques()
    {
        return cast(ushort)(mTechniques.length);
    }
    /** Removes the technique at the given index. */        
    void removeTechnique(ushort index)
    {
        //assert (index < mTechniques.length && "Index out of bounds.");
        destroy(mTechniques[index]);
        mTechniques.removeFromArrayIdx(index);
        mSupportedTechniques.clear();
        clearBestTechniqueList();
        mCompilationRequired = true;
    }
    /** Removes all the techniques in this Material. */
    void removeAllTechniques()
    {
        foreach (i; mTechniques)
        {
            destroy(i);
        }
        mTechniques.clear();
        mSupportedTechniques.clear();
        clearBestTechniqueList();
        mCompilationRequired = true;
    }
    

    //typedef VectorIterator<Techniques> TechniqueIterator;
    /** Get an iterator over the Techniques in this Material. */
    //TechniqueIterator getTechniqueIterator()
    //{
    //    return TechniqueIterator(mTechniques.begin(), mTechniques.end());
    //}
    ref Techniques getTechniques()
    {
        return mTechniques;
    }

    /** Gets an iterator over all the Techniques which are supported by the current card. 
    @remarks
        The supported technique list is only available after this material has been compiled,
        which typically happens on loading the material. Therefore, if this method returns
        an empty list, try calling Material.load.
    */
    //TechniqueIterator getSupportedTechniqueIterator()
    //{
    //    return TechniqueIterator(mSupportedTechniques.begin(), mSupportedTechniques.end());
    //}

    ref Techniques getSupportedTechniques()
    {
        return mSupportedTechniques;
    }

    /** Gets the indexed supported technique. */
    Technique getSupportedTechnique(ushort index)
    {
        //assert (index < mSupportedTechniques.length && "Index out of bounds.");
        return mSupportedTechniques[index];
    }
    /** Retrieves the number of supported techniques. */
    ushort getNumSupportedTechniques()
    {
        return cast(ushort)(mSupportedTechniques.length);
    }
    /** Gets a string explaining why any techniques are not supported. */
    string getUnsupportedTechniquesExplanation(){ return mUnsupportedReasons; }
    
    /** Gets the number of levels-of-detail this material has in the 
        given scheme, based on Technique.setLodIndex. 
    @remarks
        Note that this will not be up to date until the material has been compiled.
    */
    ushort getNumLodLevels(ushort schemeIndex)
    {
        // Safety check - empty list?
        if (mBestTechniquesBySchemeList.emptyAA())
            return 0;
        
        auto i = schemeIndex in mBestTechniquesBySchemeList;
        if (i is null)
        {
            // get the first item, will be 0 (the default) if default
            // scheme techniques exist, otherwise the earliest defined
            i = &mBestTechniquesBySchemeList[0];
        }
        
        return cast(ushort)((*i).length);
    }
    /** Gets the number of levels-of-detail this material has in the 
        given scheme, based on Technique.setLodIndex. 
    @remarks
        Note that this will not be up to date until the material has been compiled.
    */
    ushort getNumLodLevels(string schemeName)
    {
        return getNumLodLevels(
            MaterialManager.getSingleton()._getSchemeIndex(schemeName));
    }
    
    /** Gets the best supported technique. 
    @remarks
        This method returns the lowest-index supported Technique in this material
        (since lower-indexed Techniques are considered to be better than higher-indexed
        ones).
    @par
        The best supported technique is only available after this material has been compiled,
        which typically happens on loading the material. Therefore, if this method returns
        NULL, try calling Material.load.
    @param lodIndex The material lod index to use
    @param rend Optional parameter specifying the Renderable that is requesting
        this technique. Only used if no valid technique for the active material 
        scheme is found, at which point it is passed to 
        MaterialManager.Listener.handleSchemeNotFound as information.
    */
    Technique getBestTechnique(ushort lodIndex = 0, /+ref+/Renderable rend = null)
    {
        if (mSupportedTechniques.emptyAA())
        {
            return null;
        }
        else
        {
            Technique ret = null;
            MaterialManager matMgr = MaterialManager.getSingleton();
            // get scheme
            auto si = matMgr._getActiveSchemeIndex() in mBestTechniquesBySchemeList; // 'in' gives a ptr
            // scheme not found?
            if (si is null)
            {
                // listener specified alternative technique available?
                ret = matMgr._arbitrateMissingTechniqueForActiveScheme(this, lodIndex, rend);
                if (ret)
                    return ret;
                
                // Nope, use default
                // get the first item, will be 0 (the default) if default
                // scheme techniques exist, otherwise the earliest defined
                si = &mBestTechniquesBySchemeList[0];
            }
            
            // get LOD
            auto li = lodIndex in (*si);
            // LOD not found? 
            if (li is null)
            {
                // Use the next LOD level up
                //for (LodTechniques.reverse_iterator rli = si.second.rbegin(); 
                //    rli != si.second.rend(); ++rli)
                //for(size_t i = si.length; i > 0; i--)
                foreach_reverse(ushort i; 0..cast(ushort)si.length)
                {
                    if ((*si)[i].getLodIndex() < lodIndex)
                    {
                        ret = (*si)[i];
                        break;
                    }
                    
                }
                if (!ret)
                {
                    // shouldn't ever hit this really, unless user defines no LOD 0
                    // pick the first LOD we have (must be at least one to have a scheme entry)
                    ret = (*si)[si.keys[0]];
                }
                
            }
            else
            {
                // LOD found
                ret = *li;
            }
            
            return ret;
            
        }
    }
    
    
    /** Creates a new copy of this material with the same settings but a new name.
    @param newName The name for the cloned material
    @param changeGroup If true, the resource group of the clone is changed
    @param newGroup Only required if changeGroup is true; the new group to assign
    */
    SharedPtr!Material clone(string newName, bool changeGroup = false, 
                     string newGroup = "")
    {
        SharedPtr!Material newMat;
        if (changeGroup)
        {
            newMat = MaterialManager.getSingleton().create(newName, newGroup);
        }
        else
        {
            newMat = MaterialManager.getSingleton().create(newName, mGroup);
        }
        
        
        // Keep handle (see below, copy overrides everything)
        ResourceHandle newHandle = newMat.get().getHandle();
        // Assign values from this
        newMat.getAs().copyFrom(this); //TODO Has opAssign?
        // Restore new group if required, will have been overridden by operator
        if (changeGroup)
        {
            newMat.getAs().mGroup = newGroup;
        }
        
        // Correct the name & handle, they get copied too
        newMat.getAs().mName = newName;
        newMat.getAs().mHandle = newHandle;
        
        return newMat;
    }
    
    /** Copies the details of this material into another, preserving the target's handle and name
    (unlike operator=) but copying everything else.
    @param mat Weak reference to material which will receive this material's settings.
    */
    void copyDetailsTo(ref SharedPtr!Material mat)
    {
        // Keep handle (see below, copy overrides everything)
        ResourceHandle savedHandle = mat.getAs().mHandle;
        string savedName = mat.getAs().mName;
        string savedGroup = mat.getAs().mGroup;
        ManualResourceLoader savedLoader = mat.getAs().mLoader;
        bool savedManual = mat.getAs().mIsManual;
        // Assign values from this
        mat.getAs().copyFrom(this); //TODO Has opAssign?
        // Correct the name & handle, they get copied too
        mat.getAs().mName = savedName;
        mat.getAs().mHandle = savedHandle;
        mat.getAs().mGroup = savedGroup;
        mat.getAs().mIsManual = savedManual;
        mat.getAs().mLoader = savedLoader;
        
    }
    
    /** 'Compiles' this Material.
    @remarks
        Compiling a material involves determining which Techniques are supported on the
        card on which OGRE is currently running, and for fixed-function Passes within those
        Techniques, splitting the passes down where they contain more TextureUnitState 
        instances than the current card has texture units.
    @par
        This process is automatically done when the Material is loaded, but may be
        repeated if you make some procedural changes.
    @param
        autoManageTextureUnits If true, when a fixed function pass has too many TextureUnitState
            entries than the card has texture units, the Pass in question will be split into
            more than one Pass in order to emulate the Pass. If you set this to false and
            this situation arises, an Exception will be thrown.
    */
    void compile(bool autoManageTextureUnits = true)
    {
        // Compile each technique, then add it to the list of supported techniques
        mSupportedTechniques.clear();
        clearBestTechniqueList();
        mUnsupportedReasons.clear();
        
        
        size_t techNo = 0;
        foreach (i; mTechniques)
        {
            string compileMessages = i._compile(autoManageTextureUnits);
            if ( i.isSupported() )
            {
                insertSupportedTechnique(i);
            }
            else
            {
                // Log informational
                string str = std.conv.text("Material ", mName, " Technique ", techNo);
                if (!i.getName())
                    str ~= "(" ~ i.getName() ~ ")";
                str ~= " is not supported. " ~ compileMessages;
                LogManager.getSingleton().logMessage(str, LML_TRIVIAL);
                mUnsupportedReasons ~= compileMessages;
            }
            techNo++;
        }
        
        mCompilationRequired = false;
        
        // Did we find any?
        if (mSupportedTechniques.emptyAA())
        {
            LogManager.getSingleton().stream()
                << "WARNING: material " << mName << " has no supportable "
                    << "Techniques and will be blank. Explanation: \n" << mUnsupportedReasons;
        }
    }
    
    // -------------------------------------------------------------------------------
    // The following methods are to make migration from previous versions simpler
    // and to make code easier to write when dealing with simple materials
    // They set the properties which have been moved to Pass for all Techniques and all Passes
    
    /** Sets the point size properties for every Pass in every Technique.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setPointSize
    */
    void setPointSize(Real ps)
    {
        foreach (i; mTechniques)
        {
            i.setPointSize(ps);
        }
        
    }
    
    /** Sets the ambient colour reflectance properties for every Pass in every Technique.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setAmbient
    */
    void setAmbient(Real red, Real green, Real blue)
    {
        setAmbient(ColourValue(red, green, blue));
    }
    
    /** Sets the ambient colour reflectance properties for every Pass in every Technique.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setAmbient
    */
    void setAmbient(ColourValue ambient)
    {
        foreach (i; mTechniques)
        {
            i.setAmbient(ambient);
        }
    }
    
    /** Sets the diffuse colour reflectance properties of every Pass in every Technique.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setDiffuse
    */
    void setDiffuse(Real red, Real green, Real blue, Real alpha)
    {
        foreach (i; mTechniques)
        {
            i.setDiffuse(red, green, blue, alpha);
        }
    }
    
    /** Sets the diffuse colour reflectance properties of every Pass in every Technique.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setDiffuse
    */
    void setDiffuse(ColourValue diffuse)
    {
        setDiffuse(diffuse.r, diffuse.g, diffuse.b, diffuse.a);
    }
    
    /** Sets the specular colour reflectance properties of every Pass in every Technique.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setSpecular
    */
    void setSpecular(Real red, Real green, Real blue, Real alpha)
    {
        foreach (i; mTechniques)
        {
            i.setSpecular(red, green, blue, alpha);
        }
    }
    
    /** Sets the specular colour reflectance properties of every Pass in every Technique.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setSpecular
    */
    void setSpecular(ColourValue specular)
    {
        setSpecular(specular.r, specular.g, specular.b, specular.a);
    }
    
    /** Sets the shininess properties of every Pass in every Technique.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setShininess
    */
    void setShininess(Real val)
    {
        foreach (i; mTechniques)
        {
            i.setShininess(val);
        }
    }
    
    /** Sets the amount of self-illumination of every Pass in every Technique.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setSelfIllumination
    */
    void setSelfIllumination(Real red, Real green, Real blue)
    {
        setSelfIllumination(ColourValue(red, green, blue));   
    }
    
    /** Sets the amount of self-illumination of every Pass in every Technique.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setSelfIllumination
    */
    void setSelfIllumination(ColourValue selfIllum)
    {
        foreach (i; mTechniques)
        {
            i.setSelfIllumination(selfIllum);
        }
    }
    
    /** Sets whether or not each Pass renders with depth-buffer checking on or not.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setDepthCheckEnabled
    */
    void setDepthCheckEnabled(bool enabled)
    {
        foreach (i; mTechniques)
        {
            i.setDepthCheckEnabled(enabled);
        }
    }
    
    /** Sets whether or not each Pass renders with depth-buffer writing on or not.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setDepthWriteEnabled
    */
    void setDepthWriteEnabled(bool enabled)
    {
        foreach (i; mTechniques)
        {
            i.setDepthWriteEnabled(enabled);
        }
    }
    
    /** Sets the function used to compare depth values when depth checking is on.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setDepthFunction
    */
    void setDepthFunction( CompareFunction func )
    {
        foreach (i; mTechniques)
        {
            i.setDepthFunction(func);
        }
    }
    
    /** Sets whether or not colour buffer writing is enabled for each Pass.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setColourWriteEnabled
    */
    void setColourWriteEnabled(bool enabled)
    {
        foreach (i; mTechniques)
        {
            i.setColourWriteEnabled(enabled);
        }
    }
    
    /** Sets the culling mode for each pass  based on the 'vertex winding'.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setCullingMode
    */
    void setCullingMode( CullingMode mode )
    {
        foreach (i; mTechniques)
        {
            i.setCullingMode(mode);
        }
    }
    
    /** Sets the manual culling mode, performed by CPU rather than hardware.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setManualCullingMode
    */
    void setManualCullingMode( ManualCullingMode mode )
    {
        foreach (i; mTechniques)
        {
            i.setManualCullingMode(mode);
        }
    }
    
    /** Sets whether or not dynamic lighting is enabled for every Pass.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setLightingEnabled
    */
    void setLightingEnabled(bool enabled)
    {
        foreach (i; mTechniques)
        {
            i.setLightingEnabled(enabled);
        }
    }
    
    /** Sets the type of light shading required
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setShadingMode
    */
    void setShadingMode( ShadeOptions mode )
    {
        foreach (i; mTechniques)
        {
            i.setShadingMode(mode);
        }
    }
    
    /** Sets the fogging mode applied to each pass.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setFog
    */
    void setFog(
        bool overrideScene,
        FogMode mode = FogMode.FOG_NONE,
       ColourValue colour = ColourValue.White,
        Real expDensity = 0.001, Real linearStart = 0.0, Real linearEnd = 1.0 )
    {
        foreach (i; mTechniques)
        {
            i.setFog(overrideScene, mode, colour, expDensity, linearStart, linearEnd);
        }
    }
    
    /** Sets the depth bias to be used for each Pass.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setDepthBias
    */
    void setDepthBias(float constantBias, float slopeScaleBias)
    {
        foreach (i; mTechniques)
        {
            i.setDepthBias(constantBias, slopeScaleBias);
        }
    }
    
    /** Set texture filtering for every texture unit in every Technique and Pass
    @note
        This property has been moved to the TextureUnitState class, which is accessible via the 
        Technique and Pass. For simplicity, this method allows you to set these properties for 
        every current TeextureUnitState, If you need more precision, retrieve the Technique, 
        Pass and TextureUnitState instances and set the property there.
    @see TextureUnitState.setTextureFiltering
    */
    void setTextureFiltering(TextureFilterOptions filterType)
    {
        foreach (i; mTechniques)
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
    void setTextureAnisotropy(int maxAniso)
    {
        foreach (i; mTechniques)
        {
            i.setTextureAnisotropy(maxAniso);
        }
    }
    
    /** Sets the kind of blending every pass has with the existing contents of the scene.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setSceneBlending
    */
    void setSceneBlending(SceneBlendType sbt )
    {
        foreach (i; mTechniques)
        {
            i.setSceneBlending(sbt);
        }
    }
    
    /** Sets the kind of blending every pass has with the existing contents of the scene, using individual factors for color and alpha channels
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setSeparateSceneBlending
    */
    void setSeparateSceneBlending(SceneBlendType sbt,SceneBlendType sbta )
    {
        foreach (i; mTechniques)
        {
            i.setSeparateSceneBlending(sbt, sbta);
        }
    }
    
    /** Allows very fine control of blending every Pass with the existing contents of the scene.
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setSceneBlending
    */
    void setSceneBlending(SceneBlendFactor sourceFactor,SceneBlendFactor destFactor)
    {
        foreach (i; mTechniques)
        {
            i.setSceneBlending(sourceFactor, destFactor);
        }
    }
    
    /** Allows very fine control of blending every Pass with the existing contents of the scene, using individual factors for color and alpha channels
    @note
        This property has been moved to the Pass class, which is accessible via the 
        Technique. For simplicity, this method allows you to set these properties for 
        every current Technique, and for every current Pass within those Techniques. If 
        you need more precision, retrieve the Technique and Pass instances and set the
        property there.
    @see Pass.setSeparateSceneBlending
    */
    void setSeparateSceneBlending(SceneBlendFactor sourceFactor,SceneBlendFactor destFactor,SceneBlendFactor sourceFactorAlpha,SceneBlendFactor destFactorAlpha)
    {
        foreach (i; mTechniques)
        {
            i.setSeparateSceneBlending(sourceFactor, destFactor, sourceFactorAlpha, destFactorAlpha);
        }
    }
    
    /** Tells the material that it needs recompilation. */
    void _notifyNeedsRecompile()
    {
        mCompilationRequired = true;
        // Also need to unload to ensure we loaded any new items
        if (isLoaded()) // needed to stop this being called in 'loading' state
            unload();
    }
    
    /** Sets the distance at which level-of-detail (LOD) levels come into effect.
    @remarks
        You should only use this if you have assigned LOD indexes to the Technique
        instances attached to this Material. If you have done so, you should call this
        method to determine the distance at which the lowe levels of detail kick in.
        The decision about what distance is actually used is a combination of this
        and the LOD bias applied to both the current Camera and the current Entity.
    @param lodValues A vector of Reals which indicate the lod value at which to 
        switch to lower details. They are listed in LOD index order, starting at index
        1 (ie the first level down from the highest level 0, which automatically applies
        from a value of 0). These are 'user values', before being potentially 
        transformed by the strategy, so for the distance strategy this is an
        unsquared distance for example.
    */
    void setLodLevels(LodValueList lodValues)
    {
        // First, clear and add single zero entry
        mLodValues.clear();
        mUserLodValues.clear();
        mUserLodValues.insert(0f);
        mLodValues.insert(mLodStrategy.getBaseValue());
        foreach (i; lodValues)
        {
            mUserLodValues.insert(i);
            if (mLodStrategy)
                mLodValues.insert(mLodStrategy.transformUserValue(i));
        }
        
    }
    
    auto ref getLodValues()
    {
        return mLodValues;
    }
    /** Gets an iterator over the list of values transformed by the LodStrategy at which each LOD comes into effect. 
    @remarks
        Note that the iterator returned from this method is not totally analogous to 
        the one passed in by calling setLodLevels - the list includes a zero
        entry at the start (since the highest LOD starts at value 0). Also, the
        values returned are after being transformed by LodStrategy.transformUserValue.
    */
    /*LodValueIterator getLodValueIterator()
    {
        return LodValueIterator(mLodValues.begin(), mLodValues.end());
    }*/
    
    /** Gets an iterator over the user-defined list of values which are internally transfomed by the LodStrategy. 
    @remarks
        Note that the iterator returned from this method is not totally analogous to 
        the one passed in by calling setLodLevels - the list includes a zero
        entry at the start (since the highest LOD starts at value 0). Also, the
        values returned are after being transformed by LodStrategy.transformUserValue.
    */
    /*LodValueIterator getUserLodValueIterator()
    {
        return LodValueIterator(mUserLodValues.begin(), mUserLodValues.end());
    }*/
    
    LodValueList getUserLodValues()
    {
        return mUserLodValues;
    }
    
    /** Gets the LOD index to use at the given value. 
    @note The value passed in is the 'transformed' value. If you are dealing with
    an original source value (e.g. distance), use LodStrategy.transformUserValue
    to turn this into a lookup value.
    */
    ushort getLodIndex(Real value)
    {
        return mLodStrategy.getIndex(value, mLodValues);
    }
    
    /** Get lod strategy used by this material. */
    ref LodStrategy getLodStrategy()
    {
        return mLodStrategy;
    }
    /** Set the lod strategy used by this material. */
    void setLodStrategy(LodStrategy lodStrategy)
    {
        mLodStrategy = lodStrategy;
        
        assert(mLodValues.length);
        mLodValues[0] = mLodStrategy.getBaseValue();
        
        // Re-transform all user lod values (starting at index 1, no need to transform base value)
        for (size_t i = 1; i < mUserLodValues.length; ++i)
            mLodValues[i] = mLodStrategy.transformUserValue(mUserLodValues[i]);
    }
    
    /** @copydoc Resource.touch
    */
    override void touch() 
    { 
        if (mCompilationRequired) 
            compile();
        // call superclass
        super.touch();
    }
    
    /** Applies texture names to Texture Unit State with matching texture name aliases.
        All techniques, passes, and Texture Unit States within the material are checked.
        If matching texture aliases are found then true is returned.

    @param
        aliasList is a map container of texture alias, texture name pairs
    @param
        apply set true to apply the texture aliases else just test to see if texture alias matches are found.
    @return
        True if matching texture aliases were found in the material.
    */
    bool applyTextureAliases(AliasTextureNamePairList aliasList,bool apply = true)
    {
        bool testResult = false;
        
        foreach (i; mTechniques)
        {
            if (i.applyTextureAliases(aliasList, apply))
                testResult = true;
        }
        
        return testResult;
    }
    
    /** Gets the compilation status of the material.
    @return True if the material needs recompilation.
    */
    bool getCompilationRequired()
    {
        return mCompilationRequired;
    }
    
    
}

//alias SharedPtr!Material SharedPtr!Material;
//alias Material SharedPtr!Material;

/** @} */
/** @} */