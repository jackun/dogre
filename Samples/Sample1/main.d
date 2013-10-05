module main;
import core.thread;
import core.time;
import ogre.general.root;
import ogre.general.plugin;
import ogregl.plugin;

import std.stdio;
import ogre.general.framelistener;
import ogre.rendersystem.windoweventutilities;
import ogre.scene.scenenode;
import ogre.scene.scenemanager;
import ogre.scene.entity;
import ogre.math.vector;
import ogre.rendersystem.viewport;
import ogre.math.angles;
import ogre.scene.camera;
import ogre.general.colourvalue;
import ogre.general.common;
import ogre.resources.resourcegroupmanager;
import ogre.rendersystem.renderqueue;
import ogre.rendersystem.rendersystem;
import ogre.scene.light;
import ogre.materials.materialmanager;
import ogre.materials.material;
import ogre.materials.pass;
import ogre.materials.textureunitstate;
import ogre.materials.blendmode;
import ogre.materials.gpuprogram;
import ogregl.gpuprogrammanager;
import ogre.resources.highlevelgpuprogram;
import ogre.rendersystem.renderwindow;

SceneManager mSM;

string code = `
    !!ARBfp1.0
    # cgc version 3.1.0013, build date Apr 24 2012
    # command line args: -oglsl -strict -glslWerror -profile arbfp1
    # source file: test.frag
    #vendor NVIDIA Corporation
    #version 3.1.0.13
    #profile arbfp1
    #program main
    #semantic texMap
    #var float4 gl_FragColor : $vout.COLOR : COL : -1 : 1
    #var sampler2D texMap :  : texunit 0 : -1 : 1
    #var float4 colour :  :  : -1 : 0
    #var float4 uv : $vin.TEX0 : TEX0 : -1 : 1
    #const c[0] = 1
        PARAM c[1] = { { 1 } };
        TEMP R0;
        TEX R0, fragment.texcoord[0], texture[0], 2D;
        ADD result.color, -R0, c[0].x;
        END
    # 2 instructions, 1 R-regs
`;

class AppListener : FrameListener, WindowEventListener
{
    float passedTime = 0f; //'cause nan
    bool frameStarted(FrameEvent evt){return true;}
    bool frameRenderingQueued(FrameEvent evt)
    {
        if(Root.getSingleton().getAutoCreatedWindow().isClosed())
            return false;
        
        SceneNode n = mSM.getSceneNode("TEST");
        auto r = Radian(0.3)*evt.timeSinceLastFrame;
        //writeln("Rot: ", r, " , ", evt.timeSinceLastFrame);
        n.yaw(r);
        
        passedTime += evt.timeSinceLastFrame;
        if(passedTime >= 1){
            
            writeln("FPS: ", mSM.getCurrentViewport().getTarget().getLastFPS(), ", ", passedTime);
            passedTime = 0;
        }
        return true;
    }
    bool frameEnded(FrameEvent evt){return true;}
    
    //--------------------------------------------------
    
    void windowMoved(RenderWindow rw){}
    void windowResized(RenderWindow rw){}
    bool windowClosing(RenderWindow rw)
    { 
        writeln("closing");
        Root.getSingleton().queueEndRendering(true);
        return true; 
    }
    void windowClosed(RenderWindow rw){}
    void windowFocusChange(RenderWindow rw){}
}

void main(string[] args)
{
    // Prints "Hello World" string in console
    writeln("Hello World!");
    
    try
    {
        
        Root mRoot = Root.getSingleton();
        mRoot.initSubSystems();
        GLPlugin mPlugin = new GLPlugin();
        mPlugin.install(); //init Root before this
        
        mSM = mRoot.createSceneManager(SceneType.ST_GENERIC);
        
        if(mRoot.showConfigDialog())
        {
            mRoot.saveConfig();
            mRoot.initialise(true, "OgreD Sample 1");
            auto rs = mRoot.getRenderSystem();
            writeln(rs is null); 
            auto caps = rs.getCapabilities();
            writeln("MRTT count: ", caps.getNumMultiRenderTargets());
            writeln("VBO: ", caps.hasCapability(Capabilities.RSC_VBO));
            
            ResourceGroupManager resman = ResourceGroupManager.getSingleton();
            resman.addResourceLocation("../../../ogre/Samples/Media/materials/programs/GLSL150", "FileSystem", ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME, true);
            //resman.addResourceLocation("../../../ogre/Samples/Media/materials", "FileSystem", ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME, true);
            //resman.addResourceLocation("../../../ogre/Samples/Media/materials/programs", "FileSystem");
            resman.addResourceLocation("../../../ogre/Samples/Media/materials/textures", "FileSystem");
            resman.addResourceLocation("../../../ogre/Samples/Media/models", "FileSystem");
            resman.addResourceLocation(".", "FileSystem");
            resman.initialiseAllResourceGroups();
            
            writeln("GpuPrgManager: ", GpuProgramManager.getSingleton());
            SharedPtr!GpuProgram gpuprg = GpuProgramManager.getSingleton().
                createProgramFromString("test_frag", 
                                        "General", code, 
                                        GpuProgramType.GPT_FRAGMENT_PROGRAM, "arbfp1");
            //HighLevelGpuProgramManager.getSingleton().
            //        createProgram("test.frag","General","glsl",GpuProgramType.GPT_FRAGMENT_PROGRAM);
            
            
            if(false)
            {
                string[] mats = ["Ogre/Eyes","Ogre/Skin","Ogre/Earring","Ogre/Tusks"];
                //Generate materials by hand
                foreach(i; mats)
                {
                    SharedPtr!Material myMat = MaterialManager.getSingleton().create(i, ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME);
                    
                    Pass p = myMat.getTechnique(0).createPass();
                    
                    switch(i)
                    {
                        case "Ogre/Eyes":
                            p.setAmbient(1,0.4,0.4);
                            p.setDiffuse(1,0.7,0,1);
                            p.setEmissive(0.3,0.1,0);
                            break;
                        case "Ogre/Skin":
                            p.setDiffuse(0,0.7,0.1,1);
                            p.createTextureUnitState("GreenSkin.jpg").
                                setTextureAddressingMode(TextureUnitState.TAM_MIRROR);
                            p.setFragmentProgram("test_frag");
                            break;
                        case "Ogre/Earring":
                            p.setAmbient(0.7,0.7,0);
                            p.setDiffuse(0.7,0.7,0,1);
                            auto tu = p.createTextureUnitState("spheremap.png");
                            tu.setColourOperationEx(LayerBlendOperationEx.LBX_ADD);
                            tu.setEnvironmentMap(true, TextureUnitState.EnvMapType.ENV_CURVED);
                            break;
                        case "Ogre/Tusks":
                            p.setAmbient(0.7,0.7,0.6);
                            p.createTextureUnitState("tusk.jpg").setTextureScale(0.2,0.2);
                            
                            break;
                        default: break;
                    }
                }
            }
            
            //
            auto l = new AppListener;
            mRoot.addFrameListener(l);
            Light lt = mSM.createLight();
            lt.setType(Light.LightTypes.LT_DIRECTIONAL);
            
            SceneNode ln = mSM.getRootSceneNode().createChildSceneNode("LIGHT0");
            ln.attachObject(lt);
            ln.setPosition(0,10,0);
            
            //Entity mov = mSM.createEntity("TestEntity", SceneManager.PrefabType.PT_SPHERE);
            Entity mov = mSM.createEntity("TestEntity", "ogrehead.mesh");
            //foreach(i; 0..mov.getNumSubEntities())
            //    mov.getSubEntity(i).setMaterialName("MyMaterial");
            
            SceneNode node = mSM.getRootSceneNode().createChildSceneNode("TEST");
            node.attachObject(mov);
            node.setPosition(Vector3(0,0,190));
            node.yaw(Radian(Degree(120)));
            mov.setVisible(true);
            //mov.setCastShadows(true);
            
            writeln("Sub entities:", mov.getNumSubEntities());
            writeln(node._getDerivedPosition());
            
            Camera cam = mSM.createCamera("Cameraaaa");
            cam.setNearClipDistance(0.5);
            cam.setFarClipDistance(10000);
            
            SceneNode camNode = mSM.getRootSceneNode().createChildSceneNode("CAM");
            camNode.attachObject(cam);
            camNode.setPosition(0,0,0);
            cam.lookAt(Vector3(0,0,150));
            //cam.setPolygonMode(PolygonMode.PM_WIREFRAME);
            //mSM.showBoundingBoxes(true);
            
            Viewport vp = mRoot.getAutoCreatedWindow().addViewport(cam);
            mRoot.getAutoCreatedWindow().setVisible(true);
            vp.setBackgroundColour(ColourValue(0.01,0.35,0.7,1));
            
            /*foreach(i; 0..15)
             {
             writeln("******** FRAME ",i," **********");
             mRoot.renderOneFrame();                
             Thread.sleep( dur!("msecs")( 200 ) );
             }*/
            mRoot.startRendering();
            writeln("Done, quitting...");
            destroy(mRoot);//.shutdown();
        }
    }catch(Exception e)
    {
        writeln("Exception:");
        writeln(e);
        writeln(e.msg, e.line, e.file);
        
    }
    
    
    //mPlugin.uninstall();
    //mRoot.shutdown();
    // Lets the user press <Return> before program returns
    //stdin.readln();
}

