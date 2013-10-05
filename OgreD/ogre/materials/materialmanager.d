module ogre.materials.materialmanager;

import std.algorithm;
import std.range;
//import std.container;

import ogre.singleton;
import ogre.materials.technique;
import ogre.materials.material;
import ogre.scene.renderable;
import ogre.resources.resource;
import ogre.resources.datastream;
import ogre.resources.resourcemanager;
import ogre.resources.resourcegroupmanager;
import ogre.general.common;
import ogre.compat;
import ogre.lod.lodstrategymanager;
import ogre.general.scriptcompiler;
import ogre.materials.materialserializer;
import ogre.sharedptr;


/** \addtogroup Core
    *  @{
    */
/** \addtogroup Materials
    *  @{
    */
/** Class for managing Material settings for Ogre.
        @remarks
            Materials control the eventual surface rendering properties of geometry. This class
            manages the library of materials, dealing with programmatic registrations and lookups,
            as well as loading predefined Material settings from scripts.
        @par
            When loaded from a script, a Material is in an 'unloaded' state and only stores the settings
            required. It does not at that stage load any textures. This is because the material settings may be
            loaded 'en masse' from bulk material script files, but only a subset will actually be required.
        @par
            Because this is a subclass of ResourceManager, any files loaded will be searched for in any path or
            archive added to the resource paths/archives. See ResourceManager for details.
        @par
            For a definition of the material script format, see the Tutorials/MaterialScript.html file.
    */
final class MaterialManager : ResourceManager
{
    mixin Singleton!MaterialManager;
public:
    /** Listener on any general material events.
        @see MaterialManager::addListener
        */
    interface Listener
    {
        /** Called if a technique for a given scheme is not found within a material,
                allows the application to specify a Technique instance manually.
            @remarks
                Material schemes allow you to switch wholesale between families of 
                techniques on a material. However they require you to define those
                schemes on the materials up-front, which might not be possible or
                desirable for all materials, particular if, for example, you wanted
                a simple way to replace all materials with another using a scheme.
            @par
                This callback allows you to handle the case where a scheme is requested
                but the material doesn't have an entry for it. You can return a
                Technique pointer from this method to specify the material technique
                you'd like to be applied instead, which can be from another material
                entirely (and probably will be). Note that it is critical that you
                only return a Technique that is supported on this hardware; there are
                utility methods like Material::getBestTechnique to help you with this.
            @param schemeIndex The index of the scheme that was requested - all 
                schemes have a unique index when created that does not alter. 
            @param schemeName The friendly name of the scheme being requested
            @param originalMaterial The material that is being processed, that 
                didn't have a specific technique for this scheme
            @param lodIndex The material level-of-detail that was being asked for, 
                in case you need to use it to determine a technique.
            @param rend Pointer to the Renderable that is requesting this technique
                to be used, so this may influence your choice of Technique. May be
                null if the technique isn't being requested in that context.
            @return A pointer to the technique to be used, or NULL if you wish to
                use the default technique for this material
            */
        Technique handleSchemeNotFound(ushort schemeIndex, 
                                           string schemeName, Material originalMaterial, ushort lodIndex, 
                                           Renderable rend);
        
    }
    
protected:
    
    /// Default Texture filtering - minification
    FilterOptions mDefaultMinFilter;
    /// Default Texture filtering - magnification
    FilterOptions mDefaultMagFilter;
    /// Default Texture filtering - mipmapping
    FilterOptions mDefaultMipFilter;
    /// Default Texture filtering - comparison
    FilterOptions mDefaultCompare;
    
    bool            mDefaultCompareEnabled;
    CompareFunction mDefaultCompareFunction;
    
    /// Default Texture anisotropy
    uint mDefaultMaxAniso;
    /// Serializer - Hold instance per thread if necessary
    //OGRE_THREAD_POINTER(MaterialSerializer, mSerializer);
    MaterialSerializer mSerializer; //TODO OGRE_THREAD_POINTER? TLS?
    /// Default settings
    SharedPtr!Material mDefaultSettings;
    /// Overridden from ResourceManager
    override Resource createImpl(string name, ResourceHandle handle, 
                                 string group, bool isManual, ManualResourceLoader loader, 
                                 NameValuePairList createParams)
    {
        debug(STDERR) std.stdio.stderr.writeln("Creating material: ", name);
        return new Material(this, name, handle, group, isManual, loader);
    }
    
    /// Scheme name . index. Never shrinks! Should be pretty static anyway
    //typedef map<string, ushort>::type SchemeMap;
    alias ushort[string] SchemeMap;
    /// List of material schemes
    SchemeMap mSchemes;
    /// Current material scheme
    string mActiveSchemeName;
    /// Current material scheme
    ushort mActiveSchemeIndex;
    
    /// The list of per-scheme (and general) material listeners
    //typedef list<Listener*>::type ListenerList;
    //typedef std::map<String, ListenerList> ListenerMap;
    alias Listener[] ListenerList;
    //TODO If Array is not a pointer, segfaults will be had. Created in addListener
    alias ListenerList[string] ListenerMap;
    ListenerMap mListenerMap;
    
public:
    /// Default material scheme
    static string DEFAULT_SCHEME_NAME = "Default";
    
    /** Default constructor.
        */
    this()
    {
        //OGRE_THREAD_POINTER_INIT(mSerializer)
        mDefaultMinFilter = FilterOptions.FO_LINEAR;
        mDefaultMagFilter = FilterOptions.FO_LINEAR;
        mDefaultMipFilter = FilterOptions.FO_POINT;
        mDefaultCompareEnabled  = false;
        mDefaultCompareFunction = CompareFunction.CMPF_GREATER_EQUAL;
        
        mDefaultMaxAniso = 1;
        
        // Create primary thread copies of script compiler / serializer
        // other copies for other threads may also be instantiated
        //OGRE_THREAD_POINTER_SET(mSerializer, OGRE_NEW MaterialSerializer());
        mSerializer = new MaterialSerializer();
        //mDefaultSettings = SharedPtr!Material();
        
        // Loading order
        mLoadOrder = 100.0f;
        // Scripting is supported by this manager
        
        // Resource type
        mResourceType = "Material";
        
        // Register with resource group manager
        ResourceGroupManager.getSingleton()._registerResourceManager(mResourceType, this);
        //Making materialserializer work for now
        /*mScriptPatterns ~= "*.material";
        mLoadOrder = 91.0f;
        ResourceGroupManager.getSingleton()._registerScriptLoader(this);*/
        
        // Default scheme
        mActiveSchemeIndex = 0;
        mActiveSchemeName = DEFAULT_SCHEME_NAME;
        mSchemes[mActiveSchemeName] = 0;
        
    }
    
    /** Default destructor.
        */
    ~this()
    {
        mDefaultSettings.setNull();
        // Resources cleared by superclass
        // Unregister with resource group manager
        ResourceGroupManager.getSingleton()._unregisterResourceManager(mResourceType);
        ResourceGroupManager.getSingleton()._unregisterScriptLoader(this);
        
        // delete primary thread instances directly, other threads will delete
        // theirs automatically when the threads end.
        //OGRE_THREAD_POINTER_DELETE(mSerializer);
        //destroy(mSerializer);
    }
    
    /** Initialises the material manager, which also triggers it to 
         * parse all available .program and .material scripts. */
    void initialise()
    {
        // Set up default material - don't use name contructor as we want to avoid applying defaults
        auto mat = create("DefaultSettings", ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME);
        mDefaultSettings = mat;
        // Add a single technique and pass, non-programmable
        mDefaultSettings.getAs().createTechnique().createPass();
        
        // Set the default lod strategy
        mDefaultSettings.getAs().setLodStrategy(LodStrategyManager.getSingleton().getDefaultStrategy());
        
        // Set up a lit base white material
        SharedPtr!Material bw = create("BaseWhite", ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME);
        
        // Set up an unlit base white material
        SharedPtr!Material baseWhiteNoLighting = create("BaseWhiteNoLighting",
                                                 ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME);
        baseWhiteNoLighting.getAs().setLightingEnabled(false);
        
    }

    /** @see ScriptLoader::parseScript
        */
    override void parseScript(DataStream stream,string groupName)
    {
        //ScriptCompilerManager.getSingleton().parseScript(stream, groupName);
        mSerializer.parseScript(stream, groupName);
    }
    
    /** Sets the default texture filtering to be used for loaded textures, for when textures are
            loaded automatically (e.g. by Material class) or when 'load' is called with the default
            parameters by the application.
            @note
                The default value is TFO_BILINEAR.
        */
    void setDefaultTextureFiltering(TextureFilterOptions fo)
    {
        final switch (fo)
        {
            case TextureFilterOptions.TFO_NONE:
                setDefaultTextureFiltering(FilterOptions.FO_POINT, FilterOptions.FO_POINT, FilterOptions.FO_NONE);
                break;
            case TextureFilterOptions.TFO_BILINEAR:
                setDefaultTextureFiltering(FilterOptions.FO_LINEAR, FilterOptions.FO_LINEAR, FilterOptions.FO_POINT);
                break;
            case TextureFilterOptions.TFO_TRILINEAR:
                setDefaultTextureFiltering(FilterOptions.FO_LINEAR, FilterOptions.FO_LINEAR, FilterOptions.FO_LINEAR);
                break;
            case TextureFilterOptions.TFO_ANISOTROPIC:
                setDefaultTextureFiltering(FilterOptions.FO_ANISOTROPIC, FilterOptions.FO_ANISOTROPIC, FilterOptions.FO_LINEAR);
                break;
        }
    }
    /** Sets the default texture filtering to be used for loaded textures, for when textures are
            loaded automatically (e.g. by Material class) or when 'load' is called with the default
            parameters by the application.
        */
    void setDefaultTextureFiltering(FilterType ftype, FilterOptions opts)
    {
        final switch (ftype)
        {
            case FilterType.FT_MIN:
                mDefaultMinFilter = opts;
                break;
            case FilterType.FT_MAG:
                mDefaultMagFilter = opts;
                break;
            case FilterType.FT_MIP:
                mDefaultMipFilter = opts;
                break;
        }
    }
    /** Sets the default texture filtering to be used for loaded textures, for when textures are
            loaded automatically (e.g. by Material class) or when 'load' is called with the default
            parameters by the application.
        */
    void setDefaultTextureFiltering(FilterOptions minFilter, FilterOptions magFilter, FilterOptions mipFilter)
    {
        mDefaultMinFilter = minFilter;
        mDefaultMagFilter = magFilter;
        mDefaultMipFilter = mipFilter;
    }
    
    /// Get the default texture filtering
    FilterOptions getDefaultTextureFiltering(FilterType ftype)
    {
        final switch (ftype)
        {
            case FilterType.FT_MIN:
                return mDefaultMinFilter;
            case FilterType.FT_MAG:
                return mDefaultMagFilter;
            case FilterType.FT_MIP:
                return mDefaultMipFilter;
        }
        // to keep compiler happy
        return mDefaultMinFilter;
    }
    
    /** Sets the default anisotropy level to be used for loaded textures, for when textures are
            loaded automatically (e.g. by Material class) or when 'load' is called with the default
            parameters by the application.
            @note
                The default value is 1 (no anisotropy).
        */
    void setDefaultAnisotropy(uint maxAniso)
    {
        mDefaultMaxAniso = maxAniso;
    }
    /// Get the default maxAnisotropy
    uint getDefaultAnisotropy()
    {
        return mDefaultMaxAniso;
    }
    
    /** Returns a pointer to the default Material settings.
            @remarks
                Ogre comes configured with a set of defaults for newly created
                materials. If you wish to have a different set of defaults,
                simply call this method and change the returned Material's
                settings. All materials created from then on will be configured
                with the new defaults you have specified.
            @par
                The default settings begin as a single Technique with a single, non-programmable Pass:
                <ul>
                <li>ambient = ColourValue::White</li>
                <li>diffuse = ColourValue::White</li>
                <li>specular = ColourValue::Black</li>
                <li>emmissive = ColourValue::Black</li>
                <li>shininess = 0</li>
                <li>No texture unit settings (& hence no textures)</li>
                <li>SourceBlendFactor = SBF_ONE</li>
                <li>DestBlendFactor = SBF_ZERO (no blend, replace with new
                  colour)</li>
                <li>Depth buffer checking on</li>
                <li>Depth buffer writing on</li>
                <li>Depth buffer comparison function = CMPF_LESS_EQUAL</li>
                <li>Colour buffer writing on for all channels</li>
                <li>Culling mode = CULL_CLOCKWISE</li>
                <li>Ambient lighting = ColourValue(0.5, 0.5, 0.5) (mid-grey)</li>
                <li>Dynamic lighting enabled</li>
                <li>Gourad shading mode</li>
                <li>Bilinear texture filtering</li>
                </ul>
        */
    SharedPtr!Material getDefaultSettings(){ return mDefaultSettings; }
    
    /** Internal method - returns index for a given material scheme name.
        @see Technique::setSchemeName
        */
    ushort _getSchemeIndex(string schemeName)
    {
        ushort ret = 0;
        auto i = schemeName in mSchemes;
        if (i !is null)
        {
            ret = *i;
        }
        else
        {
            // Create new
            ret = cast(ushort)(mSchemes.length);
            mSchemes[schemeName] = ret;
        }
        return ret;
        
    }
    /** Internal method - returns name for a given material scheme index.
        @see Technique::setSchemeName
        */
   string _getSchemeName(ushort index)
    {
        foreach (k,v; mSchemes)
        {
            if (v == index)
                return k;
        }
        return DEFAULT_SCHEME_NAME;
    }

    /** Internal method - returns the active scheme index.
        @see Technique::setSchemeName
        */
    ushort _getActiveSchemeIndex()
    {
        return mActiveSchemeIndex;
    }
    
    /** Returns the name of the active material scheme. 
        @see Technique::setSchemeName
        */
   string getActiveScheme()
    {
        return mActiveSchemeName;
    }
    
    /** Sets the name of the active material scheme. 
        @see Technique::setSchemeName
        */
    void setActiveScheme(string schemeName)
    {
        if (mActiveSchemeName != schemeName)
        {   
            // Allow the creation of new scheme indexes on demand
            // even if they're not specified in any Technique
            mActiveSchemeIndex = _getSchemeIndex(schemeName);
            mActiveSchemeName = schemeName;
        }
    }
    
    /** 
        Add a listener to handle material events. 
        If schemeName is supplied, the listener will only receive events for that certain scheme.
        */
    void addListener(Listener l, string schemeName = "") //using empty string as default
    {
        if ((schemeName in mListenerMap) is null)
        {
            mListenerMap[schemeName] = null;
        }
        mListenerMap[schemeName].insert(l);
    }
    
    /** 
        Remove a listener handling material events. 
        If the listener was added with a custom scheme name, it needs to be supplied here as well.
        */
    void removeListener(Listener l, string schemeName = "")
    {
        //mListenerMap[schemeName].remove(l);
        //TODO check or throw out of range?
        mListenerMap[schemeName].removeFromArray(l);
    }
    
    /// Internal method for sorting out missing technique for a scheme
    Technique _arbitrateMissingTechniqueForActiveScheme(
        Material mat, ushort lodIndex, Renderable rend)
    {
        //First, check the scheme specific listeners
        auto it = mActiveSchemeName in mListenerMap;
        if (it !is null) 
        {
            ListenerList listenerList = *it;
            foreach (i; listenerList)
            {
                Technique t = i.handleSchemeNotFound(mActiveSchemeIndex, 
                                                     mActiveSchemeName, mat, lodIndex, rend);
                if (t)
                    return t;
            }
        }
        
        //If no success, check generic listeners
        it = "" in mListenerMap;
        if (it !is null) 
        {
            ListenerList listenerList = *it;
            foreach (i; listenerList)
            {
                Technique t = i.handleSchemeNotFound(mActiveSchemeIndex, 
                                                     mActiveSchemeName, mat, lodIndex, rend);
                if (t)
                    return t;
            }
        }
        
        
        return null;
        
    }
    
}
/** @} */
/** @} */