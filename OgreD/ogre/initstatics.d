module ogre.initstatics;
import ogre.rendersystem.rendersystem;
import ogre.materials.gpuprogram;
import ogre.materials.pass;
import ogre.general.generals;
import ogre.scene.node;


class InitStatics
{
    __gshared bool initialized = false;
    static this()
    {
        staticThis();
    }
    
    //Also inited from ogre.general.root.Root
    static void staticThis()
    {
        synchronized(InitStatics.classinfo)
        {
            if(initialized) return;
            initialized = true;
            //RenderSystem.staticThis();
            StringInterface.Dict.staticThis();
            GpuProgram.staticThis();
            Node.staticThis();
            Pass.staticThis();
        }
    }
}

