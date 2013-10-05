module ogre.materials.externaltexturesource;
import ogre.general.log;
import ogre.general.generals;
import ogre.general.common;
import ogre.exception;
import ogre.resources.resourcegroupmanager;
import ogre.strings;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Materials
 *  @{
 */
/** Enum for type of texture play mode */
enum eTexturePlayMode
{
    TextureEffectPause = 0,         /// Video starts out paused
    TextureEffectPlay_ASAP = 1,     /// Video starts playing as soon as possible
    TextureEffectPlay_Looping = 2   /// Video Plays Instantly && Loops
}

/** IMPORTANT: **Plugins must override default dictionary name!** 
 Base class that texture plugins derive from. Any specific 
 requirements that the plugin needs to have defined before 
 texture/material creation must be define using the stringinterface
 before calling create defined texture... or it will fail, though, it 
 is up to the plugin to report errors to the log file, or raise an 
 exception if need be. */
class ExternalTextureSource : StringInterface
{
    mixin StringInterfaceTmpl;

public:
    /** Constructor */
    this()
    {
        mInputFileName = "None";
        mDictionaryName = "NotAssigned";
        mUpdateEveryFrame = false;
        mFramesPerSecond = 24;
        mMode = eTexturePlayMode.TextureEffectPause;
    }
    /** Virtual destructor */
    ~this() {}
    
    //------------------------------------------------------------------------------//
    /* Command objects for specifying some base features                            */
    /* Any Plugins wishing to add more specific params to "ExternalTextureSourcePlugins"*/
    /* dictionary, feel free to do so, that's why this is here                      */
    static class CmdInputFileName : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return (cast(ExternalTextureSource)target).getInputName();
        }
        void doSet(Object target,string val)
        {
            (cast(ExternalTextureSource)target).setInputName( val );
        }
    }
    static class CmdFPS : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ExternalTextureSource)target).getFPS() );
        }
        void doSet(Object target,string val)
        {
            (cast(ExternalTextureSource)target).setFPS(std.conv.to!int(val));
        }
    }
    static class CmdPlayMode : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            eTexturePlayMode eMode = (cast(ExternalTextureSource)target).getPlayMode();
            string val;
            
            switch(eMode)
            {
                case eTexturePlayMode.TextureEffectPlay_ASAP:
                    val = "play";
                    break;
                case eTexturePlayMode.TextureEffectPlay_Looping: 
                    val = "loop";
                    break;
                case eTexturePlayMode.TextureEffectPause:
                    val = "pause";
                    break;
                default: 
                    val = "error"; 
                    break;
            }
            
            return val;
        }
        void doSet(Object target,string val)
        {
            eTexturePlayMode eMode = eTexturePlayMode.TextureEffectPause;
            
            if( val == "play" )
                eMode = eTexturePlayMode.TextureEffectPlay_ASAP;
            if( val == "loop" )
                eMode = eTexturePlayMode.TextureEffectPlay_Looping;
            if( val == "pause" )
                eMode = eTexturePlayMode.TextureEffectPause;
            
            (cast(ExternalTextureSource)target).setPlayMode( eMode );
        }
    }
    static class CmdTecPassState : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            int t = 0, p = 0, s = 0;
            
            (cast(ExternalTextureSource)target).getTextureTecPassStateLevel(t, p, s);
            
            string ret = std.conv.text(t, " ", p, " ", s);
            
            return ret;         
        }
        void doSet(Object target,string val)
        {
            int t = 0, p = 0, s = 0;
            
            string[] vecparams = StringUtil.split(val, " \t");
            
            if( vecparams.length == 3 )
            {
                t = std.conv.to!int( vecparams[0] );
                p = std.conv.to!int( vecparams[1] );
                s = std.conv.to!int( vecparams[2] );
            }
            else
            {
                LogManager.getSingleton().logMessage("Texture controller had problems extracting technique, pass, and state level... Default to 0, 0, 0");
                t = p = s = 0;
            }
            
            (cast(ExternalTextureSource)target).setTextureTecPassStateLevel(t,p,s);
        }
    }
    //--------------------------------------------------------//
    //Base Functions that work with Command string Interface... Or can be called
    //manually to create video through code 
    
    /// Sets an input file name - if needed by plugin
    void setInputName( string sIN ) { mInputFileName = sIN; }
    /// Gets currently set input file name
    string getInputName( ){ return mInputFileName; }
    /// Sets the frames per second - plugin may or may not use this
    void setFPS( int iFPS ) { mFramesPerSecond = iFPS; }
    /// Gets currently set frames per second
    int getFPS( ){ return mFramesPerSecond; }
    /// Sets a play mode
    void setPlayMode( eTexturePlayMode eMode )  { mMode = eMode; }
    /// Gets currently set play mode
    eTexturePlayMode getPlayMode(){ return mMode; }
    
    /// Used for attaching texture to Technique, State, and texture unit layer
    void setTextureTecPassStateLevel( int t, int p, int s ) 
    { mTechniqueLevel = t;mPassLevel = p;mStateLevel = s; }
    /// Get currently selected Texture attribs.
    void getTextureTecPassStateLevel( ref int t, ref int p, ref int s )
    {t = mTechniqueLevel;   p = mPassLevel; s = mStateLevel;}
    
    /** Call from derived classes to ensure the dictionary is setup */
    void addBaseParams()
    {
        if( mDictionaryName == "NotAssigned" )
            throw new FileNotFoundError(
                "Plugin " ~ mPluginName ~ 
                " needs to override default mDictionaryName", 
                "ExternalTextureSource.addBaseParams");
        
        //Create Dictionary Here
        if (createParamDictionary( mDictionaryName ))
        {
            ParamDictionary dict = getParamDictionary();
            
            dict.addParameter(new ParameterDef("filename", 
                                               "A source for the texture effect (only certain plugins require this)"
                                               , ParameterType.PT_STRING),
                              msCmdInputFile);
            dict.addParameter(new ParameterDef("frames_per_second", 
                                               "How fast should playback be (only certain plugins use this)"
                                               , ParameterType.PT_INT),
                              msCmdFramesPerSecond);
            dict.addParameter(new ParameterDef("play_mode", 
                                               "How the playback starts(only certain plugins use this)"
                                               , ParameterType.PT_STRING),
                              msCmdPlayMode);
            dict.addParameter(new ParameterDef("set_T_P_S", 
                                               "Set the technique, pass, and state level of this texture_unit (eg. 0 0 0 )"
                                               , ParameterType.PT_STRING),
                              msCmdTecPassState);
        }
    }
    
    /** Returns the string name of this Plugin (as set by the Plugin)*/
   string getPluginStringName(){ return mPluginName; }
    /** Returns dictionary name */
   string getDictionaryStringName(){ return mDictionaryName; }
    
    //Pure virtual functions that plugins must Override
    /** Call this function from manager to init system */
    abstract bool initialise();
    /** Shuts down Plugin */
    abstract void shutDown();
    
    /** Creates a texture into an already defined material or one that is created new
     (it's up to plugin to use a material or create one)
     Before calling, ensure that needed params have been defined via the stringInterface
     or regular methods */
    abstract void createDefinedTexture(string sMaterialName,
                                      string groupName = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME);
    /** What this destroys is dependent on the plugin... See specific plugin
     doc to know what is all destroyed (normally, plugins will destroy only
     what they created, or used directly - ie. just texture unit) */
    abstract void destroyAdvancedTexture(string sTextureName,
                                        string groupName = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME);
    
protected:
    static CmdInputFileName msCmdInputFile;     /// Command for setting input file name
    static CmdFPS msCmdFramesPerSecond;         /// Command for setting frames per second
    static CmdPlayMode msCmdPlayMode;           /// Command for setting play mode
    static CmdTecPassState msCmdTecPassState;   /// Command for setting the technique, pass, & state level
    
    static this()
    {
        msCmdInputFile = new CmdInputFileName;
        msCmdFramesPerSecond = new CmdFPS;
        msCmdPlayMode = new CmdPlayMode;
        msCmdTecPassState = new CmdTecPassState;
    }
    
    /// string Name of this Plugin
    string mPluginName;
    
    //------ Vars used for setting/getting dictionary stuff -----------//
    eTexturePlayMode mMode;
    
    string mInputFileName;
    
    bool mUpdateEveryFrame;
    
    int mFramesPerSecond,
        mTechniqueLevel,
            mPassLevel, 
            mStateLevel;
    //------------------------------------------------------------------//
    
protected:
    /** The string name of the dictionary name - each plugin
     must override default name */
    string mDictionaryName;
}
/** @} */
/** @} */