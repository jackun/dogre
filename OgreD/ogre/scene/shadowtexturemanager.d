module ogre.scene.shadowtexturemanager;
//import std.container;
import std.algorithm;
import std.range;

import ogre.compat;
import ogre.singleton;
import ogre.image.pixelformat;
import ogre.image.images;
import ogre.resources.texture;
import ogre.resources.texturemanager;
import ogre.rendersystem.hardware;
import ogre.resources.resourcegroupmanager;

//typedef vector<SharedPtr!Texture>::type ShadowTextureList;
alias SharedPtr!Texture[] ShadowTextureList;

/** Structure containing the configuration for one shadow texture. */
struct ShadowTextureConfig
{
    uint width = 512;
    uint height = 512;
    PixelFormat format = PixelFormat.PF_X8R8G8B8;
    uint fsaa = 0;
    ushort depthBufferPoolId = 1;
    
    //ShadowTextureConfig()
    //: width(512), height(512), format(PF_X8R8G8B8), fsaa(0), depthBufferPoolId(1) {}
}

//typedef vector<ShadowTextureConfig>::type ShadowTextureConfigList;
//alias Array!ShadowTextureConfig ShadowTextureConfigList;
alias ShadowTextureConfig[] ShadowTextureConfigList;
//typedef ConstVectorIterator<ShadowTextureConfigList> ConstShadowTextureConfigIterator;

//bool operator== (ShadowTextureConfig& lhs,ShadowTextureConfig& rhs );
//bool operator!= (ShadowTextureConfig& lhs,ShadowTextureConfig& rhs );


/** Class to manage the available shadow textures which may be shared between
 many SceneManager instances if formats agree.
 @remarks
 The management of the list of shadow textures has been separated out into
 a dedicated class to enable the clean management of shadow textures
 across many scene manager instances. Where multiple scene managers are
 used with shadow textures, the configuration of those shadows may or may
 not be consistent - if it is, it is good to centrally manage the textures
 so that creation and destruction responsibility is clear.
 */
final class ShadowTextureManager //: public ShadowDataAlloc
{
    mixin Singleton!ShadowTextureManager;
    
protected:
    ShadowTextureList mTextureList;
    ShadowTextureList mNullTextureList;
    size_t mCount;
    
public:
    this() { mCount = 0; }
    ~this() { clear(); }
    
    /** Populate an incoming list with shadow texture references as requested
     in the configuration list.
     */
    void getShadowTextures(ShadowTextureConfigList configList,
                           ref ShadowTextureList listToPopulate)
    {
        listToPopulate.clear();
        
        //set<Texture*>::type usedTextures;
        Texture[] usedTextures;
        
        foreach (config; configList)
        {
            bool found = false;
            foreach (tex; mTextureList)
            {
                // Skip if already used this one
                if (usedTextures.inArray(tex.getAs()))
                    continue;
                
                if (config.width == tex.getAs().getWidth() && config.height == tex.getAs().getHeight()
                    && config.format == tex.getAs().getFormat() && config.fsaa == tex.getAs().getFSAA())
                {
                    // Ok, a match
                    listToPopulate.insert(tex);
                    usedTextures.insert(tex.getAs());
                    found = true;
                    break;
                }
            }
            if (!found)
            {
                // Create a new texture
                immutable static string baseName = "Ogre/ShadowTexture";
                string targName = std.conv.text(baseName, mCount++);
                SharedPtr!Texture shadowTex = TextureManager.getSingleton().createManual(
                    targName, 
                    ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME, 
                    TextureType.TEX_TYPE_2D, config.width, config.height, 0, config.format, 
                    TextureUsage.TU_RENDERTARGET, null, false, config.fsaa);
                // Ensure texture loaded
                shadowTex.get().load();
                listToPopulate.insert(shadowTex);
                usedTextures.insert(shadowTex.getAs());
                mTextureList.insert(shadowTex);
            }
        }
        
    }
    
    /** Get an appropriately defined 'null' texture, i.e. one which will always
     result in no shadows.
     */
    SharedPtr!Texture getNullShadowTexture(PixelFormat format)
    {
        foreach (tex; mNullTextureList)
        {
            if (format == tex.getAs().getFormat())
            {
                // Ok, a match
                return tex;
            }
        }
        
        // not found, create a new one
        // A 1x1 texture of the correct format, not a render target
        immutable static string baseName = "Ogre/ShadowTextureNull";
        string targName = std.conv.text(baseName, mCount++);
        SharedPtr!Texture shadowTex = TextureManager.getSingleton().createManual(
            targName, 
            ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME, 
            TextureType.TEX_TYPE_2D, 1, 1, 0, format, TextureUsage.TU_STATIC_WRITE_ONLY);
        mNullTextureList.insert(shadowTex);
        
        // lock & populate the texture based on format
        shadowTex.getAs().getBuffer().get().lock(HardwareBuffer.LockOptions.HBL_DISCARD);
        PixelBox box = shadowTex.getAs().getBuffer().get().getCurrentLock();
        
        // set high-values across all bytes of the format 
        PixelUtil.packColour( 1.0f, 1.0f, 1.0f, 1.0f, format, box.data );
        
        shadowTex.getAs().getBuffer().get().unlock();
        
        return shadowTex;
        
    }
    
    /** Remove any shadow textures that are no longer being referenced.
     @remarks
     This should be called fairly regularly since references may take a 
     little while to disappear in some cases (if referenced by materials)
     */
    void clearUnused()
    {
        for (uint k=0; k < mTextureList.length;)
        {
            auto t = mTextureList[k];
            // Unreferenced if only this reference and the resource system
            // Any cached shadow textures should be re-bound each frame dropping
            // any old references
            if (t.useCount() == ResourceGroupManager.RESOURCE_SYSTEM_NUM_REFERENCE_COUNTS + 1)
            {
                TextureManager.getSingleton().remove(t.get().getHandle());
                mTextureList.removeFromArrayIdx(k);
            }
            else
                k++;
        }
        
        for (uint k=0; k < mNullTextureList.length;)
        {
            auto t = mNullTextureList[k];
            // Unreferenced if only this reference and the resource system
            // Any cached shadow textures should be re-bound each frame dropping
            // any old references
            if (t.useCount() == ResourceGroupManager.RESOURCE_SYSTEM_NUM_REFERENCE_COUNTS + 1)
            {
                TextureManager.getSingleton().remove(t.get().getHandle());
                mNullTextureList.removeFromArrayIdx(k);
            }
            else
                k++;
        }
        
    }
    /** Dereference all the shadow textures kept in this class and remove them
     from TextureManager; note that it is up to the SceneManagers to clear 
     their local references.
     */
    void clear()
    {
        foreach (i; mTextureList)//TODO safe foreach?
        {
            TextureManager.getSingleton().remove(i.get().getHandle());
        }
        mTextureList.clear();
        
    }
}
