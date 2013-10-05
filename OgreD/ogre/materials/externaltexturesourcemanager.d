module ogre.materials.externaltexturesourcemanager;
import ogre.resources.resourcegroupmanager;
import ogre.singleton;
import ogre.general.log;
import ogre.materials.externaltexturesource;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Materials
 *  @{
 */
/** 
 Singleton Class which handles the registering and control of texture plugins. The plugins
 will be mostly controlled via a string interface. */
class ExternalTextureSourceManager //: public ResourceAlloc
{
    mixin Singleton!ExternalTextureSourceManager;
public:
    /** Constructor */
    this()
    {
        //mCurrExternalTextureSource = 0;
    }
    /** Destructor */
    ~this()
    {
        mTextureSystems.clear();
    }
    
    /** Sets active plugin (ie. "video", "effect", "generic", etc..) */
    void setCurrentPlugIn(string sTexturePlugInType )
    {
        foreach(k, v; mTextureSystems)
        {
            if( k == sTexturePlugInType )
            {
                mCurrExternalTextureSource = v;
                mCurrExternalTextureSource.initialise();   //Now call overridden Init function
                return;
            }
        }
        mCurrExternalTextureSource = null;
        LogManager.getSingleton().logMessage( "ExternalTextureSourceManager.SetCurrentPlugIn(ENUM) failed setting texture plugin ");
    }
    
    /** Returns currently selected plugin, may be null if none selected */
    ExternalTextureSource getCurrentPlugIn(){ return mCurrExternalTextureSource; }
    
    /** Calls the destroy method of all registered plugins... 
     Only the owner plugin should perform the destroy action. */
    void destroyAdvancedTexture(string sTextureName,
                                string groupName = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME)
    {
        foreach(k, v; mTextureSystems)
        {
            //Broadcast to every registered System... Only the true one will destroy texture
            v.destroyAdvancedTexture( sTextureName, groupName );
        }
    }
    
    /** Returns the plugin which registered itself with a specific name 
     (eg. "video"), or null if specified plugin not found */
    ExternalTextureSource getExternalTextureSource(string sTexturePlugInType )
    {
        foreach(k,v; mTextureSystems)
        {
            if( k == sTexturePlugInType )
                return v;
        }
        return null;
    }
    
    /** Called from plugin to register itself */
    void setExternalTextureSource(string sTexturePlugInType, ref ExternalTextureSource pTextureSystem)
    {
        LogManager.getSingleton().logMessage("Registering Texture Controller: Type = "
                                             ~ sTexturePlugInType ~ " Name = " ~ pTextureSystem.getPluginStringName());

        foreach(k,v; mTextureSystems)
        {
            if( k == sTexturePlugInType )
            {
                LogManager.getSingleton().logMessage("Shutting Down Texture Controller: " 
                                                     ~ v.getPluginStringName() 
                                                     ~ " To be replaced by: "
                                                     ~ pTextureSystem.getPluginStringName());
                
                v.shutDown();              //Only one plugIn of Sent Type can be registered at a time
                                           //so shut down old plugin before starting new plugin
                //v = pTextureSystem;

                // **Moved this line b/c Rendersystem needs to be selected before things
                // such as framelistners can be added
                // pTextureSystem->Initialise();
                return;
            }
        }
        mTextureSystems[sTexturePlugInType] = pTextureSystem;   //If we got here then add it to map
    }
protected:
    //The current texture controller selected
    ExternalTextureSource mCurrExternalTextureSource;
    
    // Collection of loaded texture System PlugIns, keyed by registered type
    //typedef map< String, ExternalTextureSource*>::type TextureSystemList;
    alias ExternalTextureSource[string] TextureSystemList;
    TextureSystemList mTextureSystems;
}
/** @} */
/** @} */