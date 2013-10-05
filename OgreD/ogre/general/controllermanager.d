module ogre.general.controllermanager;

//import std.container;
import std.algorithm;
import std.range;

import ogre.sharedptr;
import ogre.general.controller;
import ogre.compat;
import ogre.materials.textureunitstate;
import ogre.general.common;
import ogre.materials.gpuprogram;
import ogre.singleton;
import ogre.general.predefinedcontrollers;
import ogre.general.root;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup General
    *  @{
    */

//typedef SharedPtr< ControllerValue<Real> > ControllerValueRealPtr;
//typedef SharedPtr< ControllerFunction<Real> > ControllerFunctionRealPtr;

//NO //alias ControllerValueRealPtr ControllerValueRealPtr;
//NO //alias ControllerFunctionRealPtr ControllerFunctionRealPtr;

/** Class for managing Controller instances.
    @remarks
        This class is responsible to keeping tabs on all the Controller instances registered
        and updating them when requested. It also provides a number of convenience methods
        for creating commonly used controllers (such as texture animators).
    */
class ControllerManager //: public ControllerAlloc
{
    mixin Singleton!ControllerManager;

protected:
    //typedef set<Controller!Real>::type ControllerList;
    alias Controller!(Real)[] ControllerList;
    ControllerList mControllers;
    
    /// Global predefined controller
    ControllerValueRealPtr mFrameTimeController;
    
    /// Global predefined controller
    ControllerFunctionRealPtr mPassthroughFunction;
    
    // Last frame number updated
    ulong mLastFrameNumber;
    
public:
    this()
    {
        mFrameTimeController = ControllerValueRealPtr(new FrameTimeControllerValue());
        mPassthroughFunction = ControllerFunctionRealPtr(new PassthroughControllerFunction());
        mLastFrameNumber = 0;
    }

    ~this()
    {
        clearControllers();
    }
    
    /** Creates a new controller and registers it with the manager.
        */
    Controller!Real createController(ControllerValueRealPtr src,
                                     ref ControllerValueRealPtr dest, 
                                     ref ControllerFunctionRealPtr func)
    {
        auto c = new Controller!Real(src.get(), dest.get(), func.get());
        
        mControllers.insert(c);
        return c;
    }
    
    /** Creates a new controller use frame time source and passthrough controller function.
        */
    Controller!Real createFrameTimePassthroughController(
        ref ControllerValueRealPtr dest)
    {
        return createController(getFrameTimeSource(), dest, getPassthroughControllerFunction());
    }
    
    /** Destroys all the controllers in existence.
        */
    void clearControllers()
    {
        foreach (ci; mControllers)
        {
            destroy(ci);
        }
        mControllers.clear();
    }
    
    /** Updates all the registered controllers.
        */
    void updateAllControllers()
    {
        // Only update once per frame
        ulong thisFrameNumber = Root.getSingleton().getNextFrameNumber();
        if (thisFrameNumber != mLastFrameNumber)
        {
            foreach (ci; mControllers)
            {
                ci.update();
            }
            mLastFrameNumber = thisFrameNumber;
        }
    }
    
    
    /** Returns a ControllerValue which provides the time since the last frame as a control value source.
        @remarks
            A common source value to use to feed into a controller is the time since the last frame. This method
            returns a pointer to a common source value which provides this information.
        @par
            Remember the value will only be up to date after the RenderSystem::beginFrame method is called.
        @see
            RenderSystem::beginFrame
        */
    ref ControllerValueRealPtr getFrameTimeSource()
    {
        return mFrameTimeController;
    }
    
    /** Retrieve a simple passthrough controller function. */
    ref ControllerFunctionRealPtr getPassthroughControllerFunction()
    {
        return mPassthroughFunction;
    }

    /** Creates a texture layer animator controller.
        @remarks
            This helper method creates the Controller, ControllerValue and ControllerFunction classes required
            to animate a texture.
        @param layer
            TextureUnitState object to animate
        @param sequenceTime
            The amount of time in seconds it will take to loop through all the frames.
        */
    Controller!Real createTextureAnimator(ref TextureUnitState layer, Real sequenceTime)
    {
        //TODO any point for using SharedPtr in D?
        auto texVal = ControllerValueRealPtr(new TextureFrameControllerValue(layer));
        auto animFunc = ControllerFunctionRealPtr(new AnimationControllerFunction(sequenceTime));
        
        return createController(mFrameTimeController, texVal, animFunc);
    }
    
    /** Creates a basic time-based texture uv coordinate modifier designed for creating scrolling textures.
        @remarks
            This simple method allows you to easily create constant-speed uv scrolling textures. If you want to 
            specify different speed values for horizontal and vertical scroll, use the specific methods
            ControllerManager::createTextureUScroller and ControllerManager::createTextureVScroller.
            If you want more control, look up the ControllerManager::createTextureWaveTransformer 
            for more complex wave-based scrollers / stretchers / rotators.
        @param layer
            The texture layer to animate.
        @param speed
            Speed of horizontal (u-coord) and vertical (v-coord) scroll, in complete wraps per second.
        */
    Controller!Real createTextureUVScroller(ref TextureUnitState layer, Real speed)
    {
        Controller!Real ret;
        
        if (speed != 0)
        {
            auto val = ControllerValueRealPtr(new TexCoordModifierControllerValue(layer, true, true));
            auto func = ControllerFunctionRealPtr(new ScaleControllerFunction(-speed, true));
            
            // We do both scrolls with a single controller
            //val.bind(new TexCoordModifierControllerValue(layer, true, true));
            // Create function: use -speed since we're altering texture coords so they have reverse effect
            //func.bind(new ScaleControllerFunction(-speed, true));
            ret = createController(mFrameTimeController, val, func);
        }
        
        return ret;
    }
    
    /** Creates a basic time-based texture u coordinate modifier designed for creating scrolling textures.
        @remarks
            This simple method allows you to easily create constant-speed u scrolling textures. If you want more
            control, look up the ControllerManager::createTextureWaveTransformer for more complex wave-based
            scrollers / stretchers / rotators.
        @param layer
            The texture layer to animate.
        @param uSpeed
            Speed of horizontal (u-coord) scroll, in complete wraps per second.
        */
    Controller!Real createTextureUScroller(ref TextureUnitState layer, Real uSpeed)
    {
        Controller!Real ret;
        
        if (uSpeed != 0)
        {
            auto uVal = ControllerValueRealPtr(new TexCoordModifierControllerValue(layer, true));
            auto uFunc = ControllerFunctionRealPtr(new ScaleControllerFunction(-uSpeed, true));
            
            //uVal.bind(new TexCoordModifierControllerValue(layer, true));
            // Create function: use -speed since we're altering texture coords so they have reverse effect
            //uFunc.bind(new ScaleControllerFunction(-uSpeed, true));
            ret = createController(mFrameTimeController, uVal, uFunc);
        }
        
        return ret;
    }
    
    /** Creates a basic time-based texture v coordinate modifier designed for creating scrolling textures.
        @remarks
            This simple method allows you to easily create constant-speed v scrolling textures. If you want more
            control, look up the ControllerManager::createTextureWaveTransformer for more complex wave-based
            scrollers / stretchers / rotators.
        @param layer
            The texture layer to animate.
        @param vSpeed
            Speed of vertical (v-coord) scroll, in complete wraps per second.
        */
    Controller!Real createTextureVScroller(ref TextureUnitState layer, Real vSpeed)
    {
        Controller!Real ret;
        
        if (vSpeed != 0)
        {
            auto vVal = ControllerValueRealPtr(new TexCoordModifierControllerValue(layer, false, true));
            auto vFunc = ControllerFunctionRealPtr(new ScaleControllerFunction(-vSpeed, true));
            
            // Set up a second controller for v scroll
            //vVal.bind(new TexCoordModifierControllerValue(layer, false, true));
            // Create function: use -speed since we're altering texture coords so they have reverse effect
            //vFunc.bind(new ScaleControllerFunction(-vSpeed, true));
            ret = createController(mFrameTimeController, vVal, vFunc);
        }
        
        return ret;
    }
    
    /** Creates a basic time-based texture coordinate modifier designed for creating rotating textures.
        @return
            This simple method allows you to easily create constant-speed rotating textures. If you want more
            control, look up the ControllerManager::createTextureWaveTransformer for more complex wave-based
            scrollers / stretchers / rotators.
        @param layer
            The texture layer to rotate.
        @param speed
            Speed of rotation, in complete anticlockwise revolutions per second.
        */
    Controller!Real createTextureRotater(ref TextureUnitState layer, Real speed)
    {
        auto val = ControllerValueRealPtr(new TexCoordModifierControllerValue(layer, false, false, false, false, true));
        auto func = ControllerFunctionRealPtr(new ScaleControllerFunction(-speed, true));
        
        // Target value is texture coord rotation
        //val.bind(new TexCoordModifierControllerValue(layer, false, false, false, false, true));
        // Function is simple scale (seconds * speed)
        // Use -speed since altering texture coords has the reverse visible effect
        //func.bind(new ScaleControllerFunction(-speed, true));
        
        return createController(mFrameTimeController, val, func);
        
    }
    
    /** Creates a very flexible time-based texture transformation which can alter the scale, position or
            rotation of a texture based on a wave function.
        @param layer
            The texture layer to affect.
        @param ttype
            The type of transform, either translate (scroll), scale (stretch) or rotate (spin).
        @param waveType
            The shape of the wave, see WaveformType enum for details.
        @param base
            The base value of the output.
        @param frequency
            The speed of the wave in cycles per second.
        @param phase
            The offset of the start of the wave, e.g. 0.5 to start half-way through the wave.
        @param amplitude
            Scales the output so that instead of lying within 0..1 it lies within 0..1*amplitude for exaggerated effects.
        */
    Controller!Real createTextureWaveTransformer(ref TextureUnitState layer, TextureUnitState.TextureTransformType ttype,
                                                   WaveformType waveType, Real base = 0, Real frequency = 1, Real phase = 0, Real amplitude = 1)
    {
        ControllerValueRealPtr val;
        ControllerFunctionRealPtr func;
        
        final switch (ttype)
        {
            case TextureUnitState.TextureTransformType.TT_TRANSLATE_U:
                // Target value is a u scroll
                val = ControllerValueRealPtr(new TexCoordModifierControllerValue(layer, true));
                break;
            case TextureUnitState.TextureTransformType.TT_TRANSLATE_V:
                // Target value is a v scroll
                val = ControllerValueRealPtr(new TexCoordModifierControllerValue(layer, false, true));
                break;
            case TextureUnitState.TextureTransformType.TT_SCALE_U:
                // Target value is a u scale
                val = ControllerValueRealPtr(new TexCoordModifierControllerValue(layer, false, false, true));
                break;
            case TextureUnitState.TextureTransformType.TT_SCALE_V:
                // Target value is a v scale
                val = ControllerValueRealPtr(new TexCoordModifierControllerValue(layer, false, false, false, true));
                break;
            case TextureUnitState.TextureTransformType.TT_ROTATE:
                // Target value is texture coord rotation
                val = ControllerValueRealPtr(new TexCoordModifierControllerValue(layer, false, false, false, false, true));
                break;
        }
        // Create new wave function for alterations
        func = ControllerFunctionRealPtr(new WaveformControllerFunction(waveType, base, frequency, phase, amplitude, true));
        
        return createController(mFrameTimeController, val, func);
    }
    
    /** Creates a controller for passing a frame time value through to a vertex / fragment program parameter.
        @remarks
            The destination parameter is expected to be a float, and the '.x' attribute will be populated
            with the appropriately scaled time value.
        @param params
            The parameters to update.
        @param paramIndex
            The index of the parameter to update; if you want a named parameter, then
            retrieve the index beforehand using GpuProgramParameters::getParamIndex.
        @param timeFactor
            The factor by which to adjust the time elapsed by before passing it to the program.
        */
    Controller!Real createGpuProgramTimerParam(GpuProgramParametersPtr params, size_t paramIndex,
                                                 Real timeFactor = 1.0f)
    {
        auto val = ControllerValueRealPtr(new FloatGpuParameterControllerValue(params, paramIndex));
        auto func = ControllerFunctionRealPtr(new ScaleControllerFunction(timeFactor, true));
        
        //val.bind(new FloatGpuParameterControllerValue(params, paramIndex));
        //func.bind(new ScaleControllerFunction(timeFactor, true));
        
        return createController(mFrameTimeController, val, func);
        
    }
    
    /** Removes & destroys the controller passed in as a pointer.
        */
    void destroyController(Controller!Real controller)
    {
        mControllers.removeFromArray(controller);
        destroy(controller);
    }
    
    /** Return relative speed of time as perceived by time based controllers.
        @remarks
            See setTimeFactor for full information on the meaning of this value.
        */
    Real getTimeFactor()
    {
        return (cast(FrameTimeControllerValue)mFrameTimeController.get()).getTimeFactor();
    }
    
    /** Set the relative speed to update frame time based controllers.
        @remarks
            Normally any controllers which use time as an input (FrameTimeController) are updated
            automatically in line with the real passage of time. This method allows you to change
            that, so that controllers are told that the time is passing slower or faster than it
            actually is. Use this to globally speed up / slow down the effect of time-based controllers.
        @param tf
            The virtual speed of time (1.0 is real time).
        */
    void setTimeFactor(Real tf)
    {
        (cast(FrameTimeControllerValue)mFrameTimeController.get()).setTimeFactor(tf);
    }
    
    /** Gets the constant that is added to time lapsed between each frame.
        @remarks
            See setFrameDelay for full information on the meaning of this value.
        */
    Real getFrameDelay()
    {
        return (cast(FrameTimeControllerValue)mFrameTimeController.get()).getFrameDelay();
    }
    
    /** Sets a constant frame rate.
        @remarks
            This function is useful when rendering a sequence to
            files that should create a film clip with constant frame
            rate.
            It will ensure that scrolling textures and animations
            move at a constant frame rate.
        @param fd
            The delay in seconds wanted between each frame 
            (1.0f / 25.0f means a seconds worth of animation is done 
            in 25 frames).
        */
    void setFrameDelay(Real fd)
    {
        (cast(FrameTimeControllerValue)mFrameTimeController.get()).setFrameDelay(fd);
    }
    
    /** Return the elapsed time.
        @remarks
            See setElapsedTime for full information on the meaning of this value.
        */
    Real getElapsedTime()
    {
        return (cast(FrameTimeControllerValue)mFrameTimeController.get()).getElapsedTime();
    }
    
    /** Set the elapsed time.
        @remarks
            Normally elapsed time accumulated all frames time (which speed relative to time
            factor) since the rendering loop started. This method allows your to change that to
            special time, so some elapsed-time-based globally effect is repeatable.
        @param elapsedTime
            The new elapsed time.
        */
    void setElapsedTime(Real elapsedTime)
    {
        (cast(FrameTimeControllerValue)mFrameTimeController.get()).setElapsedTime(elapsedTime);
    }

}

/** @} */
/** @} */