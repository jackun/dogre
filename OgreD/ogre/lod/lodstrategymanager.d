module ogre.lod.lodstrategymanager;
import ogre.singleton;
import ogre.lod.lodstrategy;
import ogre.lod.distancelodstrategy;
import ogre.lod.pixelcountlodstrategy;
import ogre.exception;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup LOD
    *  @{
    */
/** Manager for lod strategies. */
final class LodStrategyManager //: public LodAlloc
{
    mixin Singleton!LodStrategyManager;

    /** Map of strategies. */
    //typedef map<String, LodStrategy *>::type StrategyMap;
    alias LodStrategy[string] StrategyMap;
    
    /** Internal map of strategies. */
    StrategyMap mStrategies;
    
    /** Default strategy. */
    LodStrategy mDefaultStrategy;
    
public:
    /** Default constructor. */
    this()
    {
        // Add default (distance) strategy
        LodStrategy distanceStrategy = DistanceLodStrategy.getSingleton();
        addStrategy(distanceStrategy);
        
        // Add new pixel-count strategy
        LodStrategy pixelCountStrategy = PixelCountLodStrategy.getSingleton();
        addStrategy(pixelCountStrategy);
        
        // Set the default strategy
        setDefaultStrategy(distanceStrategy);
    }
    
    /** Destructor. */
    ~this()
    {
        // Destroy all strategies and clear the map
        removeAllStrategies();
    }
    
    /** Add a strategy to the manager. */
    void addStrategy(LodStrategy strategy)
    {
        // Check for invalid strategy name
        if (strategy.getName() == "default")
            throw new InvalidParamsError("Lod strategy name must not be \"default\".", 
                                         "LodStrategyManager.addStrategy");
        
        // Insert the strategy into the map with its name as the key
        mStrategies[strategy.getName()] = strategy;
    }
    
    /** Remove a strategy from the manager with a specified name.
        @remarks
            The removed strategy is returned so the user can control
            how it is destroyed.
        */
    LodStrategy removeStrategy(string name)
    {
        // Find strategy with specified name
        auto it = name in mStrategies;
        
        // If not found, return null
        if (it is null)
            return null;
        
        // Otherwise, erase the strategy from the map
        mStrategies.remove(name);
        
        // Return the strategy that was removed
        return *it;
    }
    
    /** Remove and delete all strategies from the manager.
        @remarks
            All strategies are deleted.  If finer control is required
            over strategy destruction, use removeStrategy.
        */
    void removeAllStrategies()
    {
        // Get beginning iterator
        foreach (k, ref v; mStrategies)
        {
            destroy(v);
        }
        mStrategies.clear();
    }
    
    /** Get the strategy with the specified name. */
    LodStrategy getStrategy(string name)
    {
        // If name is "default", return the default strategy instead of performing a lookup
        if (name == "default")
            return getDefaultStrategy();
        
        // Find strategy with specified name
        auto it = name in mStrategies;
        
        // If not found, return null
        if (it is null)
            return null;
        
        // Otherwise, return the strategy
        return *it;
    }
    
    /** Set the default strategy. */
    void setDefaultStrategy(LodStrategy strategy)
    {
        mDefaultStrategy = strategy;
    }
    
    /** Set the default strategy by name. */
    void setDefaultStrategy(string name)
    {
        // Lookup by name and set default strategy
        setDefaultStrategy(getStrategy(name));
    }

    /** Get the current default strategy. */
    LodStrategy getDefaultStrategy()
    {
        return mDefaultStrategy;
    }
    
    /** Get an iterator for all contained strategies. */
    //MapIterator<StrategyMap> getIterator(){   // Construct map iterator from strategy map and return
    //   return MapIterator<StrategyMap>(mStrategies);}

    StrategyMap getLodStrategies()
    {
        return mStrategies;
    }
}
/** @} */
/** @} */
