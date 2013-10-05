module ogre.general.controller;

import ogre.compat;
import ogre.exception;

/** \addtogroup Core
*  @{
*/
/** \addtogroup General
*  @{
*/


/** Subclasses of this class are responsible for performing a function on an input value for a Controller.
    @remarks
        This abstract class provides the interface that needs to be supported for a custom function which
        can be 'plugged in' to a Controller instance, which controls some object value based on an input value.
        For example, the WaveControllerFunction class provided by Ogre allows you to use various waveforms to
        translate an input value to an output value.
    @par
        You are free to create your own subclasses in order to define any function you wish.
*/
class ControllerFunction(T)
{
protected:
    /// If true, function will add input values together and wrap at 1.0 before evaluating
    bool mDeltaInput;
    T mDeltaCount;

    /** Gets the input value as adjusted by any delta.
    */
    T getAdjustedInput(T input)
    {
        if (mDeltaInput)
        {
            mDeltaCount += input;
            // Wrap
            while (mDeltaCount >= 1.0)
                mDeltaCount -= 1.0;
            while (mDeltaCount < 0.0)
                mDeltaCount += 1.0;

            return mDeltaCount;
        }
        else
        {
            return input;
        }
    }

public:
    /** Constructor.
        @param
            deltaInput If true, signifies that the input will be a delta value such that the function should
            add it to an internal counter before calculating the output.
    */
    this(bool deltaInput)
    {
        mDeltaInput = deltaInput;
        mDeltaCount = 0;
    }

    ~this() {}

    abstract T calculate(T sourceValue) ;
    /*{
        throw new NotImplementedError();
    }*/
}


/** Can either be used as an input or output value.
 * @note Converted from c++ class to D interface.
*/
//interface ControllerValue(T) //FIXME Linking problems
class ControllerValue(T)
{

public:
    abstract T getValue();
    abstract void setValue(T value);
}

/** Instances of this class 'control' the value of another object in the system.
    @remarks
        Controller classes are used to manage the values of object automatically based
        on the value of some input. For example, a Controller could animate a texture
        by controlling the current frame of the texture based on time, or a different Controller
        could change the colour of a material used for a spaceship shield mesh based on the remaining
        shield power level of the ship.
    @par
        The Controller is an intentionally abstract concept - it can generate values
        based on input and a function, which can either be one of the standard ones
        supplied, or a function can be 'plugged in' for custom behaviour - see the ControllerFunction class for details.
        Both the input and output values are via ControllerValue objects, meaning that any value can be both
        input and output of the controller.
    @par
        Whilst this is very flexible, it can be a little bit confusing so to make it simpler the most often used
        controller setups are available by calling methods on the ControllerManager object.
    @see
        ControllerFunction

*/
class Controller(T)
{
protected:
    /** @todo SharedPtrs */
    /// Source value
    ControllerValue!T mSource;
    /// Destination value
    ControllerValue!T mDest;
    /// Function
    ControllerFunction!T mFunc;
    /// Controller is enabled or not
    bool mEnabled;


public:

    /** Usual constructor.
        @remarks
            Requires source and destination values, and a function object. None of these are destroyed
            with the Controller when it is deleted (they can be shared) so you must delete these as appropriate.
     * @todo Uh, ref s and, cant have a pie and eat it too.
    */
    this(/+ref+/ ControllerValue!T src, 
        /+ref+/ ControllerValue!T dest, /+ref+/ ControllerFunction!T func)
    {
        mEnabled = true;
        mSource = src;
        mDest = dest;
        mFunc = func;
    }

    /** Default d-tor.
    */
    ~this() {}


    /// Sets the input controller value
    void setSource(ref /+const+/ ControllerValue!T src)
    {
        mSource = src;
    }
    /// Gets the input controller value
    ControllerValue!T getSource()
    {
        return mSource;
    }
    /// Sets the output controller value
    void setDestination(ref /+const+/ ControllerValue!T dest)
    {
        mDest = dest;
    }

    /// Gets the output controller value
    ref ControllerValue!T getDestination()
    {
        return mDest;
    }

    /// Returns true if this controller is currently enabled
    bool getEnabled()
    {
        return mEnabled;
    }

    /// Sets whether this controller is enabled
    void setEnabled(bool enabled)
    {
        mEnabled = enabled;
    }

    /** Sets the function object to be used by this controller.
    */
    void setFunction(ref /+const+/ ControllerFunction!T func)
    {
        mFunc = func;
    }

    /** Returns a pointer to the function object used by this controller.
    */
    ref ControllerFunction!T getFunction()
    {
        return mFunc;
    }

    /** Tells this controller to map it's input controller value
        to it's output controller value, via the controller function. 
    @remarks
        This method is called automatically every frame by ControllerManager.
    */
    void update()
    {
        if(mEnabled)
            mDest.setValue(mFunc.calculate(mSource.getValue()));
    }

}

/** @} */
/** @} */

/*unittest
{
    class SimpleFunction(T): ControllerFunction!T
    {
        this(bool d){super(d);}
        override T calculate(T s)
        {
            return s*2;
        }
    }

    class SimpleValue(T): ControllerValue!T
    {
        T x;
        override void setValue(T i)
        {
            x = i;
        }
        override T getValue()
        {
            return x;
        }
    }
    auto ctrl = new SimpleFunction!int(false);
    auto src = new SimpleValue!int();
    src.setValue(2);
    auto to = new SimpleValue!int();
    to.setValue(45);
    auto c = new Controller!int(src,to,ctrl); //Doesn't like ref ???
    //c.update();//Not implemented
}*/

//FIXME Fix linking errors 8-O
alias ControllerFunction!Real ControllerFunctionReal;
alias Controller!Real ControllerReal;
