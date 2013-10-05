module ogregl.plugin;
import ogre.general.plugin;
import ogregl.rendersystem;
import ogre.general.root;

enum string sPluginName = "GL RenderSystem";

/** Plugin instance for GL Manager */
class GLPlugin : Plugin
{
public:
    this() {}
    
    
    /// @copydoc Plugin::getName
    const string getName() const
    {
        return sPluginName;
    }
    
    /// @copydoc Plugin::install
    void install()
    {
        mRenderSystem = new GLRenderSystem();
        
        Root.getSingleton().addRenderSystem(mRenderSystem);
    }
    
    /// @copydoc Plugin::initialise
    void initialise()
    {
        // nothing to do
    }
    
    /// @copydoc Plugin::shutdown
    void shutdown()
    {
        // nothing to do
    }
    
    /// @copydoc Plugin::uninstall
    void uninstall()
    {
        destroy(mRenderSystem);
        mRenderSystem = null;
    }

protected:
    GLRenderSystem mRenderSystem;
}