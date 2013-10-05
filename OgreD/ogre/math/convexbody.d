module ogre.math.convexbody;
import core.sync.mutex;
import std.array;
import std.algorithm;

import ogre.compat;
import ogre.config;
import ogre.math.frustum;
import ogre.math.axisalignedbox;
import ogre.math.plane;
import ogre.math.vector;
import ogre.math.polygon;
import ogre.math.ray;
import ogre.general.log;
import ogre.math.angles;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Math
 *  @{
 */
/** Holds a solid representation of a convex body.
 @remarks
 Administers a convex body. All polygons of the body are convex and
 planar. Several operations may be applied, ranging from intersection
 to join where each result it itself a convex body.
 */
class ConvexBody
{
    alias Object.opEquals opEquals;
public:
    //typedef vector< Polygon* >.type    PolygonList;
    alias Polygon[]    PolygonList;
    
protected:
    PolygonList mPolygons;
    
    // Static 'free list' of polygons to save reallocation, shared between all bodies
    static PolygonList msFreePolygons;

    //version (OGRE_THREAD_SUPPORT)
        static Mutex msFreePolygonsMutex;

    static this()
    {
        //version (OGRE_THREAD_SUPPORT)
        msFreePolygonsMutex = new Mutex;
    }

public:
    this()
    {
        // Reserve space for 8 polys, normally 6 faces plus a couple of clips
        mPolygons.length = 8;
    }
    ~this(){ reset(); }

    this( ConvexBody cpy )
    {
        for ( size_t i = 0; i < cpy.getPolygonCount(); ++i )
        {
            Polygon p = allocatePolygon();
            //*p = cpy.getPolygon( i );
            p.copyFrom(cpy.getPolygon( i ));
            mPolygons.insert( p );
        }
    }
    
    /** Build a new polygon representation from a frustum.
     */
    void define(Frustum frustum)
    {
        // ordering of the points:
        // near (0-3), far (4-7); each (top-right, top-left, bottom-left, bottom-right)
        //     5-----4
        //    /|    /|
        //   / |   / |
        //  1-----0  |
        //  |  6--|--7
        //  | /   | /
        //  |/    |/
        //  2-----3
        
        Vector3[] pts = frustum.getWorldSpaceCorners();
        
        /// reset ConvexBody
        reset();
        
        /// update vertices: near, far, left, right, bottom, top; fill in ccw
        Polygon poly;
        
        // near
        poly = allocatePolygon();
        poly.insertVertex( pts[0] );
        poly.insertVertex( pts[1] );
        poly.insertVertex( pts[2] );
        poly.insertVertex( pts[3] );
        mPolygons.insert( poly );
        
        // far
        poly = allocatePolygon();
        poly.insertVertex( pts[5] );
        poly.insertVertex( pts[4] );
        poly.insertVertex( pts[7] );
        poly.insertVertex( pts[6] );
        mPolygons.insert( poly );
        
        // left
        poly = allocatePolygon();
        poly.insertVertex( pts[5] );
        poly.insertVertex( pts[6] );
        poly.insertVertex( pts[2] );
        poly.insertVertex( pts[1] );
        mPolygons.insert( poly ); 
        
        // right
        poly = allocatePolygon();
        poly.insertVertex( pts[4] );
        poly.insertVertex( pts[0] );
        poly.insertVertex( pts[3] );
        poly.insertVertex( pts[7] );
        mPolygons.insert( poly ); 
        
        // bottom
        poly = allocatePolygon();
        poly.insertVertex( pts[6] );
        poly.insertVertex( pts[7] );
        poly.insertVertex( pts[3] );
        poly.insertVertex( pts[2] );
        mPolygons.insert( poly ); 
        
        // top
        poly = allocatePolygon();
        poly.insertVertex( pts[4] );
        poly.insertVertex( pts[5] );
        poly.insertVertex( pts[1] );
        poly.insertVertex( pts[0] );
        mPolygons.insert( poly ); 
    }
    
    /** Build a new polygon representation from an AAB.
     */
    void define(AxisAlignedBox aab)
    {
        // ordering of the AAB points:
        //      1-----2
        //     /|    /|
        //    / |   / |
        //   5-----4  |
        //   |  0--|--3
        //   | /   | /
        //   |/    |/
        //   6-----7
        
        Vector3 min = aab.getMinimum();
        Vector3 max = aab.getMaximum();
        
        Vector3 currentVertex = min;
        
        Polygon poly;
        
        // reset body
        reset();
        
        // far
        poly = allocatePolygon();
        poly.insertVertex( currentVertex ); // 0 
        currentVertex.y = max.y;
        poly.insertVertex( currentVertex ); // 1
        currentVertex.x = max.x;
        poly.insertVertex( currentVertex ); // 2
        currentVertex.y = min.y;
        poly.insertVertex( currentVertex ); // 3
        insertPolygon( poly );
        
        // right
        poly = allocatePolygon();
        poly.insertVertex( currentVertex ); // 3
        currentVertex.y = max.y;
        poly.insertVertex( currentVertex ); // 2
        currentVertex.z = max.z;
        poly.insertVertex( currentVertex ); // 4
        currentVertex.y = min.y;
        poly.insertVertex( currentVertex ); // 7
        insertPolygon( poly ); 
        
        // near
        poly = allocatePolygon();
        poly.insertVertex( currentVertex ); // 7
        currentVertex.y = max.y;
        poly.insertVertex( currentVertex ); // 4
        currentVertex.x = min.x;
        poly.insertVertex( currentVertex ); // 5
        currentVertex.y = min.y;
        poly.insertVertex( currentVertex ); // 6
        insertPolygon( poly );
        
        // left
        poly = allocatePolygon();
        poly.insertVertex( currentVertex ); // 6
        currentVertex.y = max.y;
        poly.insertVertex( currentVertex ); // 5
        currentVertex.z = min.z;
        poly.insertVertex( currentVertex ); // 1
        currentVertex.y = min.y;
        poly.insertVertex( currentVertex ); // 0
        insertPolygon( poly ); 
        
        // bottom
        poly = allocatePolygon();
        poly.insertVertex( currentVertex ); // 0 
        currentVertex.x = max.x;
        poly.insertVertex( currentVertex ); // 3
        currentVertex.z = max.z;
        poly.insertVertex( currentVertex ); // 7 
        currentVertex.x = min.x;
        poly.insertVertex( currentVertex ); // 6
        insertPolygon( poly );
        
        // top
        poly = allocatePolygon();
        currentVertex = max;
        poly.insertVertex( currentVertex ); // 4
        currentVertex.z = min.z;
        poly.insertVertex( currentVertex ); // 2
        currentVertex.x = min.x;
        poly.insertVertex( currentVertex ); // 1
        currentVertex.z = max.z;
        poly.insertVertex( currentVertex ); // 5
        insertPolygon( poly );
        
    }

    /** Clips the body with a frustum. The resulting holes
     are filled with new polygons.
     */
    void clip( Frustum frustum )
    {
        // clip the body with each plane
        for ( ushort i = 0; i < 6; ++i )
        {
            // clip, but keep positive space this time since frustum planes are 
            // the opposite to other cases (facing inwards rather than outwards)
            clip(frustum.getFrustumPlane(i), false);
        }
    }
    
    /** Clips the body with an AAB. The resulting holes
     are filled with new polygons.
     */
    void clip( AxisAlignedBox aab )
    {
        // only process finite boxes
        if (!aab.isFinite())
            return;
        // ordering of the AAB points:
        //      1-----2
        //     /|    /|
        //    / |   / |
        //   5-----4  |
        //   |  0--|--3
        //   | /   | /
        //   |/    |/
        //   6-----7
        
        Vector3 min = aab.getMinimum();
        Vector3 max = aab.getMaximum();
        
        // clip object for each plane of the AAB
        Plane p;
        
        
        // front
        p.redefine(Vector3.UNIT_Z, max);
        clip(p);
        
        // back
        p.redefine(Vector3.NEGATIVE_UNIT_Z, min);
        clip(p);
        
        // left
        p.redefine(Vector3.NEGATIVE_UNIT_X, min);
        clip(p);
        
        // right
        p.redefine(Vector3.UNIT_X, max);
        clip(p);
        
        // bottom
        p.redefine(Vector3.NEGATIVE_UNIT_Y, min);
        clip(p);
        
        // top
        p.redefine(Vector3.UNIT_Y, max);
        clip(p);
        
    }
    
    /** Clips the body with another body.
     */
    void clip(ConvexBody _body)
    {
        if ( this == _body )
            return;
        
        // for each polygon; clip 'this' with each plane of 'body'
        // front vertex representation is ccw
        
        Plane pl;
        
        for ( size_t iPoly = 0; iPoly < _body.getPolygonCount(); ++iPoly )
        {
            Polygon p = _body.getPolygon( iPoly );
            
            assert( p.getVertexCount() >= 3, "A valid polygon must contain at least three vertices." );
            
            // set up plane with first three vertices of the polygon (a polygon is always planar)
            pl = new Plane;
            pl.redefine( p.getVertex( 0 ), p.getVertex( 1 ), p.getVertex( 2 ) );
            
            clip(pl);
        }
    }
    
    /** Clips the object by the positive half space of a plane
     */
    void clip(Plane pl, bool keepNegative = true)
    {
        if ( getPolygonCount() == 0 )
            return;
        
        // current will be used as the reference body
        ConvexBody current = new ConvexBody;
        current.moveDataFromBody(this);
        
        assert( this.getPolygonCount() == 0, "Body not empty!" );
        assert( current.getPolygonCount() != 0, "Body empty!" );
        
        // holds all intersection edges for the different polygons
        Polygon.EdgeMap intersectionEdges;
        
        // clip all polygons by the intersection plane
        // add only valid or intersected polygons to *this
        for ( size_t iPoly = 0; iPoly < current.getPolygonCount(); ++iPoly )
        {
            
            // fetch vertex count and ignore polygons with less than three vertices
            // the polygon is not valid and won't be added
            size_t vertexCount = current.getVertexCount( iPoly );
            if ( vertexCount < 3 )
                continue;
            
            // current polygon
            Polygon p = current.getPolygon( iPoly );
            
            // the polygon to assemble
            Polygon pNew = allocatePolygon();
            
            // the intersection polygon (indeed it's an edge or it's empty)
            Polygon pIntersect = allocatePolygon();
            
            // check if polygons lie inside or outside (or on the plane)
            // for each vertex check where it is situated in regard to the plane
            // three possibilities appear:
            Plane.Side clipSide = keepNegative ? Plane.Side.POSITIVE_SIDE : Plane.Side.NEGATIVE_SIDE;
            // - side is clipSide: vertex will be clipped
            // - side is !clipSide: vertex will be untouched
            // - side is NOSIDE:   vertex will be untouched
            Plane.Side[] side;
            side.length = vertexCount;
            for ( size_t iVertex = 0; iVertex < vertexCount; ++iVertex )
            {
                side[ iVertex ] = pl.getSide( p.getVertex( iVertex ) );
            }
            
            // now we check the side combinations for the current and the next vertex
            // four different combinations exist:
            // - both points inside (or on the plane): keep the second (add it to the body)
            // - both points outside: discard both (don't add them to the body)
            // - first vertex is inside, second is outside: add the intersection point
            // - first vertex is outside, second is inside: add the intersection point, then the second
            for ( size_t iVertex = 0; iVertex < vertexCount; ++iVertex )
            {
                // determine the next vertex
                size_t iNextVertex = ( iVertex + 1 ) % vertexCount;
                
                Vector3 vCurrent = p.getVertex( iVertex );
                Vector3 vNext    = p.getVertex( iNextVertex );
                
                // case 1: both points inside (store next)
                if ( side[ iVertex ]     != clipSide &&     // NEGATIVE or NONE
                    side[ iNextVertex ] != clipSide )      // NEGATIVE or NONE
                {
                    // keep the second
                    pNew.insertVertex( vNext );
                }
                
                // case 3: inside . outside (store intersection)
                else if ( side[ iVertex ]       != clipSide &&
                         side[ iNextVertex ]   == clipSide )
                {
                    // Do an intersection with the plane. We use a ray with a start point and a direction.
                    // The ray is forced to hit the plane with any option available (eigher current or next
                    // is the starting point)
                    
                    // intersect from the outside vertex towards the inside one
                    Vector3 vDirection = vCurrent - vNext;
                    vDirection.normalise();
                    Ray ray = new Ray( vNext, vDirection );
                    pair!(bool, Real) intersect = ray.intersects( pl );
                    
                    // store intersection
                    if ( intersect.first )
                    {
                        // convert distance to vector
                        Vector3 vIntersect = ray.getPoint( intersect.second );  
                        
                        // store intersection
                        pNew.insertVertex( vIntersect );
                        pIntersect.insertVertex( vIntersect );
                    }
                }
                
                // case 4: outside . inside (store intersection, store next)
                else if ( side[ iVertex ]       == clipSide &&
                         side[ iNextVertex ]         != clipSide )
                {
                    // Do an intersection with the plane. We use a ray with a start point and a direction.
                    // The ray is forced to hit the plane with any option available (eigher current or next
                    // is the starting point)
                    
                    // intersect from the outside vertex towards the inside one
                    Vector3 vDirection = vNext - vCurrent;
                    vDirection.normalise();
                    Ray ray = new Ray( vCurrent, vDirection );
                    pair!(bool, Real) intersect = ray.intersects( pl );
                    
                    // store intersection
                    if ( intersect.first )
                    {
                        // convert distance to vector
                        Vector3 vIntersect = ray.getPoint( intersect.second );
                        
                        // store intersection
                        pNew.insertVertex( vIntersect );
                        pIntersect.insertVertex( vIntersect );
                    }
                    
                    pNew.insertVertex( vNext );
                    
                }
                // else:
                // case 2: both outside (do nothing)
                
            }
            
            // insert the polygon only, if at least three vertices are present
            if ( pNew.getVertexCount() >= 3 )
            {
                // in case there are double vertices, remove them
                pNew.removeDuplicates();
                
                // in case there are still at least three vertices, insert the polygon
                if ( pNew.getVertexCount() >= 3 )
                {
                    this.insertPolygon( pNew );
                }
                else
                {
                    // delete pNew because it's empty or invalid
                    freePolygon(pNew);
                    pNew = null;
                }
            }
            else
            {
                // delete pNew because it's empty or invalid
                freePolygon(pNew);
                pNew = null;
            }
            
            // insert intersection polygon only, if there are two vertices present
            if ( pIntersect.getVertexCount() == 2 )
            {
                intersectionEdges.insert( Polygon.Edge( pIntersect.getVertex( 0 ),
                                                        pIntersect.getVertex( 1 ) ) );
            }
            
            // delete intersection polygon
            // vertices were copied (if there were any)
            freePolygon(pIntersect);
            pIntersect = null;
            
            // delete side info
            //OGRE_FREE(side, MEMCATEGORY_SCENE_CONTROL);
            //side = null;
        }
        
        // if the polygon was partially clipped, close it
        // at least three edges are needed for a polygon
        if ( intersectionEdges.length >= 3 )
        {
            Polygon pClosing = allocatePolygon();
            
            // Analyze the intersection list and insert the intersection points in ccw order
            // Each point is twice in the list because of the fact that we have a convex body
            // with convex polygons. All we have to do is order the edges (an even-odd pair)
            // in a ccw order. The plane normal shows us the direction.
            Polygon.Edge it = intersectionEdges[0];
            
            // check the cross product of the first two edges
            Vector3 vFirst  = it.first;
            Vector3 vSecond = it.second;
            
            // remove inserted edge
            intersectionEdges.removeFromArrayIdx( 0 );
            
            Vector3 vNext;
            
            // find mating edge
            if (findAndEraseEdgePair(vSecond, intersectionEdges, vNext))
            {
                // detect the orientation
                // the polygon must have the same normal direction as the plane and then n
                Vector3 vCross = ( vFirst - vSecond ).crossProduct( vNext - vSecond );
                bool frontside = pl.Normal.directionEquals( vCross, Radian(Degree( 1 )) );
                
                // first inserted vertex
                Vector3 firstVertex;
                // currently inserted vertex
                Vector3 currentVertex;
                // direction equals . front side (walk ccw)
                if ( frontside )
                {
                    // start with next as first vertex, then second, then first and continue with first to walk ccw
                    pClosing.insertVertex( vNext );
                    pClosing.insertVertex( vSecond );
                    pClosing.insertVertex( vFirst );
                    firstVertex     = vNext;
                    currentVertex   = vFirst;
                    
                    version(_DEBUG_INTERSECTION_LIST)
                    {
                        import std.stdio;
                        writeln("Plane: n=", pl.normal, ", d=", pl.d);
                        writeln("First inserted vertex: ", *next);
                        writeln("Second inserted vertex: ", *vSecond);
                        writeln("Third inserted vertex: ", *vFirst);
                    }
                }
                // direction does not equal . back side (walk cw)
                else
                {
                    // start with first as first vertex, then second, then next and continue with next to walk ccw
                    pClosing.insertVertex( vFirst );
                    pClosing.insertVertex( vSecond );
                    pClosing.insertVertex( vNext );
                    firstVertex     = vFirst;
                    currentVertex   = vNext;
                    
                    version(_DEBUG_INTERSECTION_LIST)
                    {
                        writeln("Plane: n=", pl.normal, ", d=", pl.d);
                        writeln("First inserted vertex: ", *vFirst);
                        writeln("Second inserted vertex: ", *vSecond);
                        writeln("Third inserted vertex: ", *next);
                    }
                }
                
                // search mating edges that have a point in common
                // continue this operation as long as edges are present
                while ( !intersectionEdges.empty() )
                {
                    
                    if (findAndEraseEdgePair(currentVertex, intersectionEdges, vNext))
                    {
                        // insert only if it's not the last (which equals the first) vertex
                        if ( !intersectionEdges.empty() )
                        {
                            currentVertex = vNext;
                            pClosing.insertVertex( vNext );
                        }
                    }
                    else
                    {
                        // degenerated...
                        break;
                    }
                    
                } // while intersectionEdges not empty
                
                // insert polygon (may be degenerated!)
                this.insertPolygon( pClosing );
                
            }
            // mating intersection edge NOT found!
            else
            {
                freePolygon(pClosing);
            }
            
        } // if intersectionEdges contains more than three elements
    }
    
    /** Extends the existing body to incorporate the passed in point as a
     convex hull.
     @remarks
     You must already have constructed a basic body using a 'construct' 
     method.
     */
    void extend(Vector3 pt)
    {
        // Erase all polygons facing towards the point. For all edges that
        // are not removed twice (once in AB and once BA direction) build a
        // convex polygon (triangle) with the point.
        Polygon.EdgeMap edgeMap;
        
        for ( size_t i = 0; i < getPolygonCount(); ++i )
        {
            Vector3 normal = getNormal( i );
            // direction of the point in regard to the polygon
            // the polygon is planar so we can take an arbitrary vertex
            Vector3 ptDir  = pt - getVertex( i, 0 );
            ptDir.normalise();
            
            // remove polygon if dot product is greater or equals null.
            if ( normal.dotProduct( ptDir ) >= 0 )
            {
                // store edges (copy them because if the polygon is deleted
                // its vertices are also deleted)
                storeEdgesOfPolygon( i, edgeMap );
                
                // remove polygon
                deletePolygon( i );
                
                // decrement iterator because of deleted polygon
                --i; 
            }
        }
        
        // point is already a part of the hull (point lies inside)
        if ( edgeMap.empty() )
            return;
        
        // remove the edges that are twice in the list (once from each side: AB,BA)
        
        size_t it;
        // iterate from first to the element before the last one
        for (size_t itStart = 0; itStart < edgeMap.length; )
        {
            // compare with iterator + 1 to end
            // don't need to skip last entry in itStart since omitted in inner loop
            it = itStart;
            ++it;
            
            bool erased = false;
            // iterate from itStart+1 to the element before the last one
            for ( ; it < edgeMap.length; ++it )
            {
                if (edgeMap[itStart].first.positionEquals(edgeMap[it].second) &&
                    edgeMap[itStart].second.positionEquals(edgeMap[it].first))
                {
                    edgeMap.removeFromArrayIdx(it);
                    // increment itStart before deletion (iterator invalidation)
                    //Polygon::EdgeMap::iterator delistart = itStart++;
                    //edgeMap.erase(delistart);
                    edgeMap.removeFromArrayIdx(itStart);
                    erased = true;
                    
                    break; // found and erased
                }
            }
            // increment itStart if we didn't do it when erasing
            if (!erased)
                ++itStart;
            
        }
        
        // use the remaining edges to build triangles with the point
        // the vertices of the edges are in ccw order (edgePtA-edgePtB-point
        // to form a ccw polygon)
        //while ( !edgeMap.empty() )
        foreach(edge; edgeMap)
        {
            //Polygon.Edge mapIt = edgeMap[0];
            
            // build polygon it.first, it.second, point
            Polygon p = allocatePolygon();
            
            p.insertVertex(edge.first);
            p.insertVertex(edge.second);
            
            p.insertVertex( pt );
            // attach polygon to body
            insertPolygon( p );
            
            // erase the vertices from the list
            // pointers are now held by the polygon
            //edgeMap.removeFromArrayIdx( 0 );
        }
        edgeMap.clear();
    }
    
    /** Resets the object.
     */
    void reset()
    {
        foreach (it; mPolygons)
        {
            freePolygon(it);
        }
        mPolygons.clear();
    }

    /** Returns the current number of polygons.
     */
    size_t getPolygonCount()// const;
    {
        return mPolygons.length;
    }
    
    /** Returns the number of vertices for a polygon
     */
    size_t getVertexCount( size_t poly )// const;
    {
        assert(poly < getPolygonCount(), "Search position out of range" );
        
        return mPolygons[ poly ].getVertexCount();
    }
    
    /** Returns a polygon.
     */
    Polygon getPolygon( size_t poly )// const;
    {
        assert(poly < getPolygonCount(), "Search position out of range");
        
        return mPolygons[poly];
    }
    
    /** Returns a specific vertex of a polygon.
     */
    Vector3 getVertex( size_t poly, size_t vertex ) //const;
    {
        assert( poly < getPolygonCount(), "Search position out of range" );
        
        return mPolygons[poly].getVertex(vertex);
    }
    
    /** Returns the normal of a specified polygon.
     */
    Vector3 getNormal( size_t poly )
    {
        assert( poly < getPolygonCount(), "Search position out of range" );
        
        return mPolygons[ poly ].getNormal();
    }
    
    /** Returns an AABB representation.
     */
    AxisAlignedBox getAABB()// const;
    {
        AxisAlignedBox aab;
        
        for ( size_t i = 0; i < getPolygonCount(); ++i )
        {
            for ( size_t j = 0; j < getVertexCount( i ); ++j )
            {
                aab.merge( getVertex( i, j ) );
            }
        }
        
        return aab;
    }

    /** Checks if the body has a closed hull.
     */
    bool hasClosedHull()// const;
    {
        // if this map is returned empty, the body is closed
        Polygon.EdgeMap edgeMap = getSingleEdges();
        
        return edgeMap.empty();
    }

    /** Merges all neighboring polygons into one single polygon if they are
     lay in the same plane.
     */
    void mergePolygons()
    {
        // Merge all polygons that lay in the same plane as one big polygon.
        // A convex body does not have two separate regions (separated by polygons
        // with different normals) where the same normal occurs, so we can simply
        // search all similar normals of a polygon. Two different options are 
        // possible when the normals fit:
        // - the two polygons are neighbors
        // - the two polygons aren't neighbors (but a third, fourth,.. polygon lays
        //   in between)
        
        // Signals if the body holds polygons which aren't neighbors but have the same
        // normal. That means another step has to be processed.
        bool bDirty = false;
        
        for ( size_t iPolyA = 0; iPolyA < getPolygonCount(); ++iPolyA )
        {
            
            for ( size_t iPolyB = iPolyA+1; iPolyB < getPolygonCount(); ++iPolyB )
            {
                Vector3 n1 = getNormal( iPolyA );
                Vector3 n2 = getNormal( iPolyB );
                
                // if the normals point into the same direction
                if ( n1.directionEquals( n2, Radian( Degree( 0.00001 ) ) )  )
                {
                    // indicates if a neighbor has been found and joined
                    bool bFound = false;
                    
                    // search the two fitting vertices (if there are any) for the common edge
                    const size_t numVerticesA = getVertexCount( iPolyA );
                    for ( size_t iVertexA = 0; iVertexA < numVerticesA; ++iVertexA )
                    {
                        const size_t numVerticesB = getVertexCount( iPolyB );
                        for ( size_t iVertexB = 0; iVertexB < numVerticesB; ++iVertexB )
                        {
                            Vector3 aCurrent = getVertex( iPolyA, iVertexA );
                            Vector3 aNext        = getVertex( iPolyA, (iVertexA + 1) % getVertexCount( iPolyA ) );
                            Vector3 bCurrent = getVertex( iPolyB, iVertexB );
                            Vector3 bNext        = getVertex( iPolyB, (iVertexB + 1) % getVertexCount( iPolyB ) );
                            
                            // if the edge is the same the current vertex of A has to be equal to the next of B and the other
                            // way round
                            if ( aCurrent.positionEquals(bNext) &&
                                bCurrent.positionEquals(aNext))
                            {
                                // polygons are neighbors, assemble new one
                                Polygon pNew = allocatePolygon();
                                
                                // insert all vertices of A up to the join (including the common vertex, ignoring
                                // whether the first vertex of A may be a shared vertex)
                                for ( size_t i = 0; i <= iVertexA; ++i )
                                {
                                    pNew.insertVertex( getVertex( iPolyA, i%numVerticesA ) );
                                }
                                
                                // insert all vertices of B _after_ the join to the end
                                for ( size_t i = iVertexB + 2; i < numVerticesB; ++i )
                                {
                                    pNew.insertVertex( getVertex( iPolyB, i ) );
                                }
                                
                                // insert all vertices of B from the beginning up to the join (including the common vertex
                                // and excluding the first vertex if the first is part of the shared edge)
                                for ( size_t i = 0; i <= iVertexB; ++i )
                                {
                                    pNew.insertVertex( getVertex( iPolyB, i%numVerticesB ) );
                                }
                                
                                // insert all vertices of A _after_ the join to the end
                                for ( size_t i = iVertexA + 2; i < numVerticesA; ++i )
                                {
                                    pNew.insertVertex( getVertex( iPolyA, i ) );
                                }
                                
                                // in case there are double vertices (in special cases), remove them
                                for ( size_t i = 0; i < pNew.getVertexCount(); ++i )
                                {
                                    Vector3 a = pNew.getVertex( i );
                                    Vector3 b = pNew.getVertex( (i + 1) % pNew.getVertexCount() );
                                    
                                    // if the two vertices are the same...
                                    if (a.positionEquals(b))
                                    {
                                        // remove a
                                        pNew.deleteVertex( i );
                                        
                                        // decrement counter
                                        --i;
                                    }
                                }
                                
                                // delete the two old ones
                                assert( iPolyA != iPolyB, "PolyA and polyB are the same!" );
                                
                                // polyB is always higher than polyA, so delete polyB first
                                deletePolygon( iPolyB );
                                deletePolygon( iPolyA );
                                
                                // continue with next (current is deleted, so don't jump to the next after the next)
                                --iPolyA;
                                --iPolyB;
                                
                                // insert new polygon
                                insertPolygon( pNew );
                                
                                bFound = true;
                                break;
                            }
                        }
                        
                        if ( bFound )
                        {
                            break;
                        }
                    }
                    
                    if ( bFound == false )
                    {
                        // there are two polygons available with the same normal direction, but they
                        // could not be merged into one single because of no shared edge
                        bDirty = true;
                        break;
                    }
                }
            }
        }
        
        // recursion to merge the previous non-neighbors
        if ( bDirty )
        {
            mergePolygons();
        }
    }
    
    /** Determines if the current object is equal to the compared one.
     */
    bool opEquals ( ConvexBody rhs )// const;
    {
        if ( getPolygonCount() != rhs.getPolygonCount() )
            return false;
        
        // Compare the polygons. They may not be in correct order.
        // A correct convex body does not have identical polygons in its body.
        bool[] bChecked;
        bChecked.length = getPolygonCount();
        //bChecked[] = false; //Automagically false
        
        for ( size_t i=0; i<getPolygonCount(); ++i )
        {
            bool bFound = false;
            
            for ( size_t j=0; j<getPolygonCount(); ++j )
            {
                Polygon pA = getPolygon( i );
                Polygon pB = rhs.getPolygon( j );
                
                if ( pA == pB )
                {
                    bFound = true;
                    bChecked[ i ] = true;
                    break;
                }
            }
            
            if ( bFound == false )
            {
                //OGRE_FREE(bChecked, MEMCATEGORY_SCENE_CONTROL);
                //bChecked = 0;
                return false;
            }
        }
        
        for ( size_t i=0; i<getPolygonCount(); ++i )
        {
            if ( bChecked[ i ] != true )
            {
                //OGRE_FREE(bChecked, MEMCATEGORY_SCENE_CONTROL);
                //bChecked = 0;
                return false;
            }
        }
        
        //OGRE_FREE(bChecked, MEMCATEGORY_SCENE_CONTROL);
        //bChecked = 0;
        return true;
    }

    
    /** Prints out the body with all its polygons.
     */
    override string toString()
    {
        string strm = std.conv.text("POLYGON INFO (", getPolygonCount(), ")\n");
        
        for ( size_t i = 0; i < getPolygonCount(); ++i )
        {
            strm ~= std.conv.text("POLYGON ", i, ", ", getPolygon( i ),"\n");
        }
        
        return strm;
    }
    
    /** Log details of this body */
    void logInfo()// const;
    {
        LogManager.getSingleton().logMessage(LML_NORMAL, toString());
    }
    
    /// Initialise the internal polygon pool used to minimise allocations
    static void _initialisePool()
    {
        synchronized(msFreePolygonsMutex)
        {
            if (msFreePolygons.empty())
            {
                size_t initialSize = 30;
                
                // Initialise polygon pool with 30 polys
                msFreePolygons.length = initialSize;
                for (size_t i = 0; i < initialSize; ++i)
                {
                    msFreePolygons[i] = new Polygon;
                }
            }
        }
    }

    /// Tear down the internal polygon pool used to minimise allocations
    static void _destroyPool()
    {
        synchronized(msFreePolygonsMutex)
        {
            foreach (i; msFreePolygons)
            {
                destroy(i);
            }
            msFreePolygons.clear();
        }
    }
    
    
protected:
    /** Get a new polygon from the pool.
     */
    static Polygon allocatePolygon()
    {
        synchronized(msFreePolygonsMutex)
        {
            if (msFreePolygons.empty())
            {
                // if we ran out of polys to use, create a new one
                // hopefully this one will return to the pool in due course
                return new Polygon;//OGRE_NEW_T(Polygon, MEMCATEGORY_SCENE_CONTROL)();
            }
            else
            {
                Polygon ret = msFreePolygons.back;
                ret.reset();
                
                msFreePolygons.popBack();
                
                return ret;
                
            }
        }
    }

    /** Release a polygon back tot he pool. */
    static void freePolygon(Polygon poly)
    {
        synchronized(msFreePolygonsMutex)
            msFreePolygons.insert(poly);
    }

    /** Inserts a polygon at a particular point in the body.
     @note
     After this method is called, the ConvexBody 'owns' this Polygon
     and will be responsible for deleting it.
     */
    void insertPolygon(Polygon pdata, size_t poly)
    {
        assert(poly <= getPolygonCount(), "Insert position out of range" );
        assert( pdata !is null, "Polygon is NULL" );

        mPolygons.insertBeforeIdx( poly, pdata );
        
    }

    /** Inserts a polygon at the end.
     @note
     After this method is called, the ConvexBody 'owns' this Polygon
     and will be responsible for deleting it.
     */
    void insertPolygon(Polygon pdata)
    {
        assert( pdata !is null, "Polygon is NULL" );
        
        mPolygons.insert( pdata );
    }
    
    /** Inserts a vertex for a polygon at a particular point.
     @note
     No checks are done whether the assembled polygon is (still) planar, 
     the caller must ensure that this is the case.
     */
    void insertVertex(size_t poly, Vector3 vdata, size_t vertex)
    {
        assert(poly < getPolygonCount(), "Search position (polygon) out of range" );
        
        mPolygons[poly].insertVertex(vdata, vertex);
    }

    /** Inserts a vertex for a polygon at the end.
     @note
     No checks are done whether the assembled polygon is (still) planar, 
     the caller must ensure that this is the case.
     */
    void insertVertex(size_t poly, Vector3 vdata)
    {
        assert(poly < getPolygonCount(), "Search position (polygon) out of range" );
        
        mPolygons[poly].insertVertex(vdata);
    }

    /** Deletes a specific polygon.
     */
    void deletePolygon(size_t poly)
    {
        assert(poly < getPolygonCount(), "Search position out of range" );
        
        Polygon it = mPolygons[poly];
        freePolygon(it);
        mPolygons.removeFromArrayIdx(poly);
    }
    
    /** Removes a specific polygon from the body without deleting it.
     @note
     The retrieved polygon needs to be deleted later by the caller.
     */
    Polygon unlinkPolygon(size_t poly)
    {
        assert( poly < getPolygonCount(), "Search position out of range" );
        
        Polygon it = mPolygons[poly];

        // safe address
        //Polygon pRet = *it;
        
        // delete entry
        mPolygons.removeFromArrayIdx(poly);    
        
        // return polygon pointer
        
        return it;//pRet;
    }
    
    /** Moves all polygons from the parameter body to this instance.
     @note Both the passed in object and this instance are modified
     */
    void moveDataFromBody(ConvexBody _body)
    {
        _body.mPolygons.swap(this.mPolygons);
    }
    
    /** Deletes a specific vertex of a specific polygon.
     */
    void deleteVertex(size_t poly, size_t vertex)
    {
        assert(poly < getPolygonCount(), "Search position out of range" );
        
        mPolygons[poly].deleteVertex(vertex);
    }
    
    /** Replace a polygon at a particular index.
     @note Again, the passed in polygon is owned by this object after this
     call returns, and this object is resonsible for deleting it.
     */
    void setPolygon(Polygon pdata, size_t poly )
    {
        assert(poly < getPolygonCount(), "Search position out of range" );
        assert(pdata !is null, "Polygon is NULL" );
        
        if (pdata != mPolygons[poly])
        {
            // delete old polygon
            freePolygon(mPolygons[ poly ]);
            
            // set new polygon
            mPolygons[poly] = pdata;
        }
    }
    
    /** Replace a specific vertex of a polygon.
     @note
     No checks are done whether the assembled polygon is (still) planar, 
     the caller must ensure that this is the case.
     */
    void setVertex( size_t poly, Vector3 vdata, size_t vertex )
    {
        assert(poly < getPolygonCount(), "Search position out of range");
        
        mPolygons[poly].setVertex(vdata, vertex);
    }
    
    /** Returns the single edges in an EdgeMap (= edges where one side is a vertex and the
     other is empty space (a hole in the body)).
     */
    Polygon.EdgeMap getSingleEdges()// const;
    {
        Polygon.EdgeMap edgeMap;
        
        // put all edges of all polygons into a list every edge has to be
        // walked in each direction once    
        for ( size_t i = 0; i < getPolygonCount(); ++i )
        {
            Polygon p = getPolygon( i );
            
            for ( size_t j = 0; j < p.getVertexCount(); ++j )
            {
                Vector3 a = p.getVertex( j );
                Vector3 b = p.getVertex( ( j + 1 ) % p.getVertexCount() );
                
                edgeMap.insert( Polygon.Edge( a, b ) );
            }
        }
        
        // search corresponding parts
        //Polygon::EdgeMap::iterator it;
        //Polygon::EdgeMap::iterator itStart;
        //Polygon::EdgeMap::const_iterator itEnd;
        while( !edgeMap.empty() )
        {
            size_t it = 1; //edgeMap.begin(); ++it; // start one element after itStart
            size_t itStart = 0; //edgeMap.begin();  // the element to be compared with the others
            size_t itEnd = edgeMap.length; //.end();      // beyond the last element
            
            bool bFound = false;
            
            for ( ; it < itEnd; ++it )
            {
                if (edgeMap[itStart].first.positionEquals(edgeMap[it].second) &&
                    edgeMap[itStart].second.positionEquals(edgeMap[it].first))
                {
                    // erase itStart and it
                    edgeMap.removeFromArrayIdx( it );
                    edgeMap.removeFromArrayIdx( itStart );
                    
                    bFound = true;
                    
                    break; // found
                }
            }
            
            if ( bFound == false )
            {
                break;  // not all edges could be matched
                // body is not closed
            }
        }
        
        return edgeMap;
    }
    
    /** Stores the edges of a specific polygon in a passed in structure.
     */
    void storeEdgesOfPolygon(size_t poly, ref Polygon.EdgeMap edgeMap)// const;
    {
        assert(poly <= getPolygonCount(), "Search position out of range" );
        assert( edgeMap !is null, "TEdgeMap ptr is NULL" );
        
        mPolygons[poly].storeEdges(edgeMap);
    }
    
    /** Allocates space for an specified amount of polygons with
        each of them having a specified number of vertices.
     @note
        Old data (if available) will be erased.
     */
    void allocateSpace(size_t numPolygons, size_t numVertices)
    {
        reset();
        
        // allocate numPolygons polygons with each numVertices vertices
        for ( size_t iPoly = 0; iPoly < numPolygons; ++iPoly )
        {
            Polygon poly = allocatePolygon();
            
            for ( size_t iVertex = 0; iVertex < numVertices; ++iVertex )
            {
                poly.insertVertex( Vector3.ZERO );
            }
            
            mPolygons.insert( poly );
        }
    }
    
    /** Searches for a pair (an edge) in the intersectionList with an entry
        that equals vec, and removes it from the passed in list.
         @param vec The vertex to search for in intersectionEdges
         @param intersectionEdges A list of edges, which is updated if a match is found
         @param vNext A reference to a vector which will be filled with the other
            vertex at the matching edge, if found.
         @return True if a match was found
     */
    bool findAndEraseEdgePair(Vector3 vec, 
                              ref Polygon.EdgeMap intersectionEdges, out Vector3 vNext )// const;
    {
        foreach (idx, it; intersectionEdges)
        {
            if (it.first.positionEquals(vec))
            {
                vNext = it.second;
                
                // erase found edge
                intersectionEdges.removeFromArrayIdx( idx );
                
                return true; // found!
            }
            else if (it.second.positionEquals(vec))
            {
                vNext = it.first;
                
                // erase found edge
                intersectionEdges.removeFromArrayIdx( idx );
                
                return true; // found!
            }
        }
        
        return false; // not found!
    }
    
}
/** @} */
/** @} */