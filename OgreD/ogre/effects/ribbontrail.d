module ogre.effects.ribbontrail;

//import std.container;
import std.algorithm;

import ogre.effects.billboardchain;
import ogre.scene.node;
import ogre.exception;
import ogre.general.colourvalue;
import ogre.compat;
import ogre.general.controller;
import ogre.scene.movableobject;
import ogre.general.common;
import ogre.general.controllermanager;
import ogre.math.vector;
import ogre.math.maths;


/** Controller value for pass frame time to RibbonTrail
        */
//private 
class TimeControllerValue : ControllerValue!Real
{
protected:
    RibbonTrail mTrail;
public:
    this(ref RibbonTrail r) { mTrail = r; }
    
    override Real getValue(){ return 0; }// not a source 
    override void setValue(Real value) { mTrail._timeUpdate(value); }
}

/** Subclass of BillboardChain which automatically leaves a trail behind
        one or more Node instances.
    @remarks
        An instance of this class will watch one or more Node instances, and
        automatically generate a trail behind them as they move. Because this
        class can monitor multiple modes, it generates its own geometry in 
        world space and thus, even though it has to be attached to a SceneNode
        to be visible, changing the position of the scene node it is attached to
        makes no difference to the geometry rendered.
    @par
        The 'head' element grows smoothly in size until it reaches the required size,
        then a new element is added. If the segment is full, the tail element
        shrinks by the same proportion as the head grows before disappearing.
    @par
        Elements can be faded out on a time basis, either by altering their colour
        or altering their alpha. The width can also alter over time.
    @par
        'v' texture coordinates are fixed at 0.0 if used, meaning that you can
        use a 1D texture to 'smear' a colour pattern along the ribbon if you wish.
        The 'u' coordinates are by default (0.0, 1.0), but you can alter this 
        using setOtherTexCoordRange if you wish.
    */
class RibbonTrail : BillboardChain, Node.Listener
{
public:
    /** Constructor (don't use directly, use factory) 
        @param name The name to give this object
        @param maxElements The maximum number of elements per chain
        @param numberOfChains The number of separate chain segments contained in this object,
            ie the maximum number of nodes that can have trails attached
        @param useTextureCoords If true, use texture coordinates from the chain elements
        @param useVertexColours If true, use vertex colours from the chain elements (must
            be true if you intend to use fading)
        */
    this(string name, size_t maxElements = 20, size_t numberOfChains = 1, 
                bool useTextureCoords = true, bool useVertexColours = true)
    {
        super(name, maxElements, 0, useTextureCoords, useVertexColours, true);
        mFadeController = null;
        setTrailLength(100);
        setNumberOfChains(numberOfChains);
        mTimeControllerValue = ControllerValueRealPtr(new TimeControllerValue(this));
        
        // use V as varying texture coord, so we can use 1D textures to 'smear'
        setTextureCoordDirection(TexCoordDirection.TCD_V);
    }
    /// destructor
    ~this()
    {
        // Detach listeners
        foreach (i; mNodeList)
        {
            i.setListener(null);
        }
        
        if (mFadeController)
        {
            // destroy controller
            ControllerManager.getSingleton().destroyController(mFadeController);
        }
        
    }
    
    //typedef vector<Node*>::type NodeList;
    //typedef ConstVectorIterator<NodeList> NodeIterator;
    alias Node[] NodeList;
    
    /** Add a node to be tracked.
        @param n The node that will be tracked.
        */
    void addNode(ref Node n)
    {
        if (mNodeList.length == mChainCount)
        {
            throw new InvalidParamsError(
                        mName ~ " cannot monitor any more nodes, chain count exceeded",
                        "RibbonTrail.addNode");
        }
        if (n.getListener())
        {
            throw new InvalidParamsError(
                        mName ~ " cannot monitor node " ~ n.getName() ~ " since it already has a listener.",
                        "RibbonTrail.addNode");
        }
        
        // get chain index
        size_t chainIndex = mFreeChains[$-1];
        mFreeChains.length--;
        mNodeToChainSegment.insert(chainIndex);
        mNodeToSegMap[n] = chainIndex;
        
        // initialise the chain
        resetTrail(chainIndex, n);
        
        mNodeList.insert(n);
        n.setListener(this);
        
    }

    /** Remove tracking on a given node. */
    void removeNode(ref Node n)
    {
        //auto i = mNodeList[].find(n);
        auto i = mNodeList.countUntil(n);
        if (i > -1)
        {
            size_t chainIndex = mNodeToChainSegment[i];
            super.clearChain(chainIndex);
            // mark as free now
            mFreeChains.insert(chainIndex);
            n.setListener(null);
            mNodeList.removeFromArrayIdx(i);
            mNodeToChainSegment.removeFromArrayIdx(i);
            mNodeToSegMap.remove(n);
        }
    }

    /** Get an iterator over the nodes which are being tracked. */
    //NodeIterator getNodeIterator();
    ref NodeList getNodeList()
    {
        return mNodeList;
    }

    /** Get the chain index for a given Node being tracked. */
    size_t getChainIndexForNode(Node n)
    {
        auto i = n in mNodeToSegMap;
        if (i is null)
        {
            throw new ItemNotFoundError(
                        "This node is not being tracked", "RibbonTrail.getChainIndexForNode");
        }
        return *i;
    }
    
    /** Set the length of the trail. 
        @remarks
            This sets the length of the trail, in world units. It also sets how
            far apart each segment will be, ie length / max_elements. 
        @param len The length of the trail in world units
        */
    void setTrailLength(Real len)
    {
        mTrailLength = len;
        mElemLength = mTrailLength / mMaxElementsPerChain;
        mSquaredElemLength = mElemLength * mElemLength;
    }

    /** Get the length of the trail. */
    Real getTrailLength(){ return mTrailLength; }
    
    /** @copydoc BillboardChain::setMaxChainElements */
    override void setMaxChainElements(size_t maxElements)
    {
        super.setMaxChainElements(maxElements);
        mElemLength = mTrailLength / mMaxElementsPerChain;
        mSquaredElemLength = mElemLength * mElemLength;
        
        resetAllTrails();
    }

    /** @copydoc BillboardChain::setNumberOfChains */
    override void setNumberOfChains(size_t numChains)
    {
        if (numChains < mNodeList.length)
        {
            throw new InvalidParamsError(
                        "Can't shrink the number of chains less than number of tracking nodes",
                        "RibbonTrail.setNumberOfChains");
        }
        
        size_t oldChains = getNumberOfChains();
        
        super.setNumberOfChains(numChains);
        //TODO resize
        mInitialColour.length = numChains;
        mInitialColour[] = ColourValue.White;
        mDeltaColour.length = numChains;
        mDeltaColour[] = ColourValue.ZERO;
        mInitialWidth.length = numChains;
        mInitialWidth[] = 10;
        mDeltaWidth.length = numChains;
        //mDeltaWidth[] = 0;
        
        if (oldChains > numChains)
        {
            // remove free chains
            for(size_t i = 0; i < mFreeChains.length; /* nothing */)
            {
                if (mFreeChains[i] >= numChains)
                    mFreeChains.removeFromArrayIdx(i);
                else
                    i++;
            }
        }
        else if (oldChains < numChains)
        {
            // add new chains, at front to preserve previous ordering (pop_back)
            for (size_t i = oldChains; i < numChains; ++i)
                mFreeChains.insertBeforeIdx(0, i);
        }
        resetAllTrails();
    }

    /** @copydoc BillboardChain::clearChain */
    override void clearChain(size_t chainIndex)
    {
        super.clearChain(chainIndex);
        
        // Reset if we are tracking for this chain
        //auto i = mNodeToChainSegment[].find(chainIndex);
        auto i = mNodeToChainSegment[].countUntil(chainIndex);
        if (i > -1)
        {
            //size_t nodeIndex = std::distance(mNodeToChainSegment.begin(), i);
            resetTrail(mNodeToChainSegment[i], mNodeList[i]);
        }
    }
    
    /** Set the starting ribbon colour for a given segment. 
        @param chainIndex The index of the chain
        @param col The initial colour
        @note
            Only used if this instance is using vertex colours.
        */
    void setInitialColour(size_t chainIndex,ColourValue col)
    {
        setInitialColour(chainIndex, col.r, col.g, col.b, col.a);
    }
    /** Set the starting ribbon colour. 
        @param chainIndex The index of the chain
        @param r,b,g,a The initial colour
        @note
            Only used if this instance is using vertex colours.
        */
    void setInitialColour(size_t chainIndex, Real r, Real g, Real b, Real a = 1.0)
    {
        if (chainIndex >= mChainCount)
        {
            throw new InvalidParamsError(
                        "chainIndex out of bounds", "RibbonTrail.setInitialColour");
        }
        mInitialColour[chainIndex].r = r;
        mInitialColour[chainIndex].g = g;
        mInitialColour[chainIndex].b = b;
        mInitialColour[chainIndex].a = a;
    }

    /** Get the starting ribbon colour. */
   ColourValue getInitialColour(size_t chainIndex)
    {
        if (chainIndex >= mChainCount)
        {
            throw new InvalidParamsError(
                        "chainIndex out of bounds", "RibbonTrail.getInitialColour");
        }
        return mInitialColour[chainIndex];
    }
    
    /** Enables / disables fading the trail using colour. 
        @param chainIndex The index of the chain
        @param valuePerSecond The amount to subtract from colour each second
        */
    void setColourChange(size_t chainIndex,ColourValue valuePerSecond)
    {
        setColourChange(chainIndex, 
                        valuePerSecond.r, valuePerSecond.g, valuePerSecond.b, valuePerSecond.a);
    }

    /** Enables / disables fading the trail using colour. 
        @param chainIndex The index of the chain
        @param r,g,b,a The amount to subtract from each colour channel per second
        */
    void setColourChange(size_t chainIndex, Real r, Real g, Real b, Real a)
    {
        if (chainIndex >= mChainCount)
        {
            throw new InvalidParamsError(
                        "chainIndex out of bounds", "RibbonTrail.setColourChange");
        }
        mDeltaColour[chainIndex].r = r;
        mDeltaColour[chainIndex].g = g;
        mDeltaColour[chainIndex].b = b;
        mDeltaColour[chainIndex].a = a;
        
        manageController();
        
    }
    
    /** Get the per-second fading amount */
   ColourValue getColourChange(size_t chainIndex)
    {
        if (chainIndex >= mChainCount)
        {
            throw new InvalidParamsError(
                        "chainIndex out of bounds", "RibbonTrail.getColourChange");
        }
        return mDeltaColour[chainIndex];
    }


    /** Set the starting ribbon width in world units. 
        @param chainIndex The index of the chain
        @param width The initial width of the ribbon
        */
    void setInitialWidth(size_t chainIndex, Real width)
    {
        if (chainIndex >= mChainCount)
        {
            throw new InvalidParamsError(
                        "chainIndex out of bounds", "RibbonTrail.setInitialWidth");
        }
        mInitialWidth[chainIndex] = width;
    }

    /** Get the starting ribbon width in world units. */
    Real getInitialWidth(size_t chainIndex)
    {
        if (chainIndex >= mChainCount)
        {
            throw new InvalidParamsError(
                        "chainIndex out of bounds", "RibbonTrail.getInitialWidth");
        }
        return mInitialWidth[chainIndex];
    }
    
    /** Set the change in ribbon width per second. 
        @param chainIndex The index of the chain
        @param widthDeltaPerSecond The amount the width will reduce by per second
        */
    void setWidthChange(size_t chainIndex, Real widthDeltaPerSecond)
    {
        if (chainIndex >= mChainCount)
        {
            throw new InvalidParamsError(
                        "chainIndex out of bounds", "RibbonTrail.setWidthChange");
        }
        mDeltaWidth[chainIndex] = widthDeltaPerSecond;
        manageController();
    }

    /** Get the change in ribbon width per second. */
    Real getWidthChange(size_t chainIndex)
    {
        if (chainIndex >= mChainCount)
        {
            throw new InvalidParamsError(
                        "chainIndex out of bounds", "RibbonTrail.getWidthChange");
        }
        return mDeltaWidth[chainIndex];
        
    }

    
    void nodeAttached(Node n){}
    void nodeDetached(Node n){}

    /// @see Node::Listener::nodeUpdated
    void nodeUpdated(Node node)
    {
        size_t chainIndex = getChainIndexForNode(node);
        updateTrail(chainIndex, node);
    }
    /// @see Node::Listener::nodeDestroyed
    void nodeDestroyed(Node node)
    {
        removeNode(node);
    }
    
    /// Perform any fading / width delta required; internal method
    void _timeUpdate(Real time)
    {
        // Apply all segment effects
        for (size_t s = 0; s < mChainSegmentList.length; ++s)
        {
            ChainSegment seg = mChainSegmentList[s];
            if (seg.head != SEGMENT_EMPTY && seg.head != seg.tail)
            {
                
                for(size_t e = seg.head + 1;; ++e) // until break
                {
                    e = e % mMaxElementsPerChain;
                    
                    Element elem = mChainElementList[seg.start + e];
                    elem.width = elem.width - (time * mDeltaWidth[s]);
                    elem.width = std.algorithm.max(0.0f, elem.width);
                    elem.colour = elem.colour - (mDeltaColour[s] * time);
                    elem.colour.saturate();
                    
                    if (e == seg.tail)
                        break;
                }
            }
        }
        mVertexContentDirty = true;
    }
    
    /** Overridden from MovableObject */
    override string getMovableType()
    {
        return RibbonTrailFactory.FACTORY_TYPE_NAME;
    }
    
protected:
    /// List of nodes being trailed
    NodeList mNodeList;
    /// Mapping of nodes to chain segments
    //typedef vector<size_t>::type IndexVector;
    alias size_t[] IndexVector;
    /// Ordered like mNodeList, contains chain index
    IndexVector mNodeToChainSegment;
    // chains not in use
    IndexVector mFreeChains;
    
    // fast lookup node.chain index
    // we use positional map too because that can be useful
    //typedef map<Node*, size_t>::type NodeToChainSegmentMap;
    alias size_t[Node] NodeToChainSegmentMap;
    NodeToChainSegmentMap mNodeToSegMap;
    
    /// Total length of trail in world units
    Real mTrailLength;
    /// length of each element
    Real mElemLength;
    /// Squared length of each element
    Real mSquaredElemLength;
    //typedef vector<ColourValue>::type ColourValueList;
    //typedef vector<Real>::type RealList;
    alias ColourValue[] ColourValueList;
    alias Real[] RealList;
    /// Initial colour of the ribbon
    ColourValueList mInitialColour;
    /// fade amount per second
    ColourValueList mDeltaColour;
    /// Initial width of the ribbon
    RealList mInitialWidth;
    /// Delta width of the ribbon
    RealList mDeltaWidth;
    /// controller used to hook up frame time to fader
    Controller!Real mFadeController;
    /// controller value for hooking up frame time to fader
    ControllerValueRealPtr mTimeControllerValue;
    
    /// Manage updates to the time controller
    void manageController()
    {
        bool needController = false;
        for (size_t i = 0; i < mChainCount; ++i)
        {
            if (mDeltaWidth[i] != 0 || mDeltaColour[i] != ColourValue.ZERO)
            {
                needController = true;
                break;
            }
        }
        if (!mFadeController && needController)
        {
            // Set up fading via frame time controller
            ControllerManager mgr = ControllerManager.getSingleton();
            mFadeController = mgr.createFrameTimePassthroughController(mTimeControllerValue);
        }
        else if (mFadeController && !needController)
        {
            // destroy controller
            ControllerManager.getSingleton().destroyController(mFadeController);
            mFadeController = null;
        }
        
    }
    /// Node has changed position, update
    void updateTrail(size_t index, ref Node node)
    {
        // Repeat this entire process if chain is stretched beyond its natural length
        bool done = false;
        while (!done)
        {
            // Node has changed somehow, we're only interested in the derived position
            ChainSegment seg = mChainSegmentList[index];
            Element headElem = mChainElementList[seg.start + seg.head];
            size_t nextElemIdx = seg.head + 1;
            // wrap
            if (nextElemIdx == mMaxElementsPerChain)
                nextElemIdx = 0;
            Element nextElem = mChainElementList[seg.start + nextElemIdx];
            
            // Vary the head elem, but bake new version if that exceeds element len
            Vector3 newPos = node._getDerivedPosition();
            if (mParentNode)
            {
                // Transform position to ourself space
                newPos = mParentNode._getDerivedOrientation().UnitInverse() *
                    (newPos - mParentNode._getDerivedPosition()) / mParentNode._getDerivedScale();
            }
            Vector3 diff = newPos - nextElem.position;
            Real sqlen = diff.squaredLength();
            if (sqlen >= mSquaredElemLength)
            {
                // Move existing head to mElemLength
                Vector3 scaledDiff = diff * (mElemLength / Math.Sqrt(sqlen));
                headElem.position = nextElem.position + scaledDiff;
                // Add a new element to be the new head
                auto newElem = new Element( newPos, mInitialWidth[index], 0.0f,
                                mInitialColour[index], node._getDerivedOrientation() );
                addChainElement(index, newElem);
                // alter diff to represent new head size
                diff = newPos - headElem.position;
                // check whether another step is needed or not
                if (diff.squaredLength() <= mSquaredElemLength)   
                    done = true;
                
            }
            else
            {
                // Extend existing head
                headElem.position = newPos;
                done = true;
            }
            
            // Is this segment full?
            if ((seg.tail + 1) % mMaxElementsPerChain == seg.head)
            {
                // If so, shrink tail gradually to match head extension
                Element tailElem = mChainElementList[seg.start + seg.tail];
                size_t preTailIdx;
                if (seg.tail == 0)
                    preTailIdx = mMaxElementsPerChain - 1;
                else
                    preTailIdx = seg.tail - 1;
                Element preTailElem = mChainElementList[seg.start + preTailIdx];
                
                // Measure tail diff from pretail to tail
                Vector3 taildiff = tailElem.position - preTailElem.position;
                Real taillen = taildiff.length();
                if (taillen > 1e-06)
                {
                    Real tailsize = mElemLength - diff.length();
                    taildiff *= tailsize / taillen;
                    tailElem.position = preTailElem.position + taildiff;
                }
                
            }
        } // end while
        
        
        mBoundsDirty = true;
        // Need to dirty the parent node, but can't do it using needUpdate() here 
        // since we're in the middle of the scene graph update (node listener), 
        // so re-entrant calls don't work. Queue.
        if (mParentNode)
        {
            Node.queueNeedUpdate(getParentSceneNode());
        }
        
    }

    /// Reset the tracked chain to initial state
    void resetTrail(size_t index, ref Node node)
    {
        assert(index < mChainCount, "index < mChainCount");
        
        ChainSegment seg = mChainSegmentList[index];
        // set up this segment
        seg.head = seg.tail = SEGMENT_EMPTY;
        // Create new element, v coord is always 0.0f
        // need to convert to take parent node's position into account
        Vector3 position = node._getDerivedPosition();
        if (mParentNode)
        {
            position = mParentNode._getDerivedOrientation().Inverse() 
                * (position - mParentNode._getDerivedPosition()) 
                    / mParentNode._getDerivedScale();
        }
        auto e = new Element(position,
                  mInitialWidth[index], 0.0f, mInitialColour[index], node._getDerivedOrientation());
        // Add the start position
        addChainElement(index, e);
        // Add another on the same spot, this will extend
        addChainElement(index, e);
    }

    /// Reset all tracked chains to initial state
    void resetAllTrails()
    {
        for (size_t i = 0; i < mNodeList.length; ++i)
        {
            resetTrail(i, mNodeList[i]);
        }
    }
    
}


/** Factory object for creating RibbonTrail instances */
class RibbonTrailFactory : MovableObjectFactory
{
protected:
    override MovableObject createInstanceImpl(string name, NameValuePairList params)
    {
        size_t maxElements = 20;
        size_t numberOfChains = 1;
        bool useTex = true;
        bool useCol = true;
        // optional params
        if (!params.emptyAA)
        {
            auto ni = "maxElements" in params;
            if (ni !is null)
            {
                maxElements = std.conv.to!size_t(*ni);
            }
            ni = "numberOfChains" in params;
            if (ni !is null)
            {
                numberOfChains = std.conv.to!size_t(*ni);
            }
            ni = "useTextureCoords" in params;
            if (ni !is null)
            {
                useTex = std.conv.to!bool(*ni);
            }
            ni = "useVertexColours" in params;
            if (ni !is null)
            {
                useCol = std.conv.to!bool(*ni);
            }
            
        }
        
        return new RibbonTrail(name, maxElements, numberOfChains, useTex, useCol);
        
    }
public:
    this() {}
    ~this() {}
    
    immutable static string FACTORY_TYPE_NAME = "RibbonTrail";
    
    override string getType()
    {
        return FACTORY_TYPE_NAME;
    }

    override void destroyInstance( ref MovableObject obj)
    {
        destroy(obj);
    }   
}
/** @} */
/** @} */