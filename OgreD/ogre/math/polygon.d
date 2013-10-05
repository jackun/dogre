module ogre.math.polygon;
import ogre.math.vector;
import ogre.math.maths;
import ogre.compat;
import std.math;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Math
    *  @{
    */
/** The class represents a polygon in 3D space.
    @remarks
        It is made up of 3 or more vertices in a single plane, listed in 
        counter-clockwise order.
    */
class Polygon
{
    alias Object.opEquals opEquals;   
public:
    //typedef vector<Vector3>::type               VertexList;
    alias Vector3[] VertexList;
    
    //typedef multimap<Vector3, Vector3>::type    EdgeMap;
    //typedef std::pair< Vector3, Vector3>        Edge;
    //alias Vector3[][]               EdgeMap;
    alias pair!(Vector3, Vector3) Edge;
    alias Edge[]                  EdgeMap;
    
protected:
    VertexList      mVertexList;
    //mutable 
    Vector3 mNormal;
    //mutable 
    bool    mIsNormalSet = false;

    /** Updates the normal.
        */
    void updateNormal()// const;
    {
        assert( getVertexCount() >= 3, "Insufficient vertex count!" );
        
        if (mIsNormalSet)
            return;
        
        // vertex order is ccw
        Vector3 a = getVertex( 0 );
        Vector3 b = getVertex( 1 );
        Vector3 c = getVertex( 2 );
        
        // used method: Newell
        mNormal.x = 0.5f * ( (a.y - b.y) * (a.z + b.z) +
                            (b.y - c.y) * (b.z + c.z) + 
                            (c.y - a.y) * (c.z + a.z));
        
        mNormal.y = 0.5f * ( (a.z - b.z) * (a.x + b.x) +
                            (b.z - c.z) * (b.x + c.x) + 
                            (c.z - a.z) * (c.x + a.x));
        
        mNormal.z = 0.5f * ( (a.x - b.x) * (a.y + b.y) +
                            (b.x - c.x) * (b.y + c.y) + 
                            (c.x - a.x) * (c.y + a.y));
        
        mNormal.normalise();
        
        mIsNormalSet = true;
        
    }
    
    
public:
    this()
    {
        // reserve space for 6 vertices to reduce allocation cost
        mVertexList.length = 6;
        mNormal = Vector3.ZERO;
    }
    ~this() {}

    this( Polygon cpy )
    {
        copyFrom(cpy);
    }

    void copyFrom( Polygon cpy )
    {
        mVertexList = cpy.mVertexList.dup; //TODO dup? value types get COW-ed? Objects need to be duped?
        mNormal = cpy.mNormal;
        mIsNormalSet = cpy.mIsNormalSet;
    }

    /** Inserts a vertex at a specific position.
        @note Vertices must be coplanar.
        */
    void insertVertex(Vector3 vdata, size_t vertexIndex)
    {
        // TODO: optional: check planarity
        assert(vertexIndex <= getVertexCount(), "Insert position out of range" );
        mVertexList.insertBeforeIdx(vertexIndex, vdata);//TODO vertexIndex+1?
        
    }

    /** Inserts a vertex at the end of the polygon.
        @note Vertices must be coplanar.
        */
    void insertVertex(Vector3 vdata)
    {
        mVertexList.insert(vdata);
    }
    
    /** Returns a vertex.
        */
    Vector3 getVertex(size_t vertex) //const;
    {
        assert(vertex < getVertexCount(), "Search position out of range");
        return mVertexList[vertex];
    }
    
    /** Sets a specific vertex of a polygon.
        @note Vertices must be coplanar.
        */
    void setVertex(Vector3 vdata, size_t vertexIndex)
    {
        // TODO: optional: check planarity
        assert(vertexIndex < getVertexCount(), "Search position out of range" );
        
        // set new vertex
        mVertexList[ vertexIndex ] = vdata;
    }
    
    /** Removes duplicate vertices from a polygon.
        */
    void removeDuplicates()
    {
        for ( size_t i = 0; i < getVertexCount(); ++i )
        {
            Vector3 a = getVertex( i );
            Vector3 b = getVertex( (i + 1)%getVertexCount() );
            
            if (a.positionEquals(b))
            {
                deleteVertex(i);
                --i;
            }
        }
    }
    
    /** Vertex count.
        */
    size_t getVertexCount() //const;
    {
        return mVertexList.length;
    }
    
    /** Returns the polygon normal.
        */
    Vector3 getNormal()// const;
    {
        assert( getVertexCount() >= 3, "Insufficient vertex count!" );
        
        updateNormal();
        
        return mNormal;
    }
    
    /** Deletes a specific vertex.
        */
    void deleteVertex(size_t vertex)
    {
        assert( vertex < getVertexCount(), "Search position out of range" );

        mVertexList.removeFromArrayIdx( vertex );
    }
    
    /** Determines if a point is inside the polygon.
        @remarks
            A point is inside a polygon if it is both on the polygon's plane, 
            and within the polygon's bounds. Polygons are assumed to be convex
            and planar.
        */
    bool isPointInside(Vector3 point) //const;
    {
        // sum the angles 
        Real anglesum = 0;
        size_t n = getVertexCount();
        for (size_t i = 0; i < n; i++) 
        {
            Vector3 p1 = getVertex(i);
            Vector3 p2 = getVertex((i + 1) % n);
            
            Vector3 v1 = p1 - point;
            Vector3 v2 = p2 - point;
            
            Real len1 = v1.length();
            Real len2 = v2.length();
            
            if (Math.RealEqual(len1 * len2, 0.0f, 1e-4f))
            {
                // We are on a vertex so consider this inside
                return true; 
            }
            else
            {
                Real costheta = v1.dotProduct(v2) / (len1 * len2);
                anglesum += acos(costheta);
            }
        }
        
        // result should be 2*PI if point is inside poly
        return Math.RealEqual(anglesum, Math.TWO_PI, 1e-4f);
        
    }

    
    /** Stores the edges of the polygon in ccw order.
            The vertices are copied so the user has to take the 
            deletion into account.
        */
    void storeEdges(ref EdgeMap edgeMap)// const;
    {
        //OgreAssert( edgeMap != NULL, "EdgeMap ptr is NULL" );
        
        size_t vertexCount = getVertexCount();
        
        for ( size_t i = 0; i < vertexCount; ++i )
        {
            edgeMap.insert( Edge( getVertex( i ), getVertex( ( i + 1 ) % vertexCount ) ) );
        }
    }
    
    /** Resets the object.
        */
    void reset()
    {
        // could use swap() to free memory here, but assume most may be reused so avoid realloc
        mVertexList.clear();
        
        mIsNormalSet = false;
    }
    
    /** Determines if the current object is equal to the compared one.
        */
    bool opEquals (Polygon rhs)// const;
    {
        if ( getVertexCount() != rhs.getVertexCount() )
            return false;
        
        // Compare vertices. They may differ in its starting position.
        // find start
        size_t start = 0;
        bool foundStart = false;
        for (size_t i = 0; i < getVertexCount(); ++i )
        {   
            if (getVertex(0).positionEquals(rhs.getVertex(i)))
            {
                start = i;
                foundStart = true;
                break;
            }
        }
        
        if (!foundStart)
            return false;
        
        for (size_t i = 0; i < getVertexCount(); ++i )
        {
            Vector3 vA = getVertex( i );
            Vector3 vB = rhs.getVertex( ( i + start) % getVertexCount() );
            
            if (!vA.positionEquals(vB))
                return false;
        }
        
        return true;
    }
        
    /** Prints out the polygon data.
        */
    override string toString()
    {
        string str =  std.conv.text("NUM VERTICES: ", getVertexCount(), "\n");
        
        for (size_t j = 0; j < getVertexCount(); ++j )
        {
            str ~= std.conv.text("VERTEX ", j, ": ", getVertex( j ), "\n");
        }
        
        return str;
    }
    
}
/** @} */
/** @} */