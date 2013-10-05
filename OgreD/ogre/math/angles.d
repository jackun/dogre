module ogre.math.angles;
import ogre.compat;
import ogre.math.maths;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Math
 *  @{
 */
/** Wrapper class which indicates a given angle value is in Radians.
 @remarks
 Radian values are interchangeable with Degree values, and conversions
 will be done automatically between them.
 */
struct Radian
{
    Real mRad = 0;
    
    //Constructors give with dmd: ogre/strings.d(57): Error: cannot create a struct until its size is determined
    this (Real r ) { mRad = r; }
    
    // these functions could not be defined within the class definition of class
    // Radian because they required class Degree to be defined
    this ( Degree d ) { mRad = d.valueRadians(); }
    this ( Radian r ) { mRad = r.mRad; }
    
    //Radian (Degree d );
    Radian opAssign (Real f ) { mRad = f; return this; }
    Radian opAssign (Radian r ) { mRad = r.mRad; return this; }
    //Radian operator = (Degree d );
    
    //Real valueAngleUnits();
    Radian opUnary(string op)(){
        static if(op == "-")
            return Radian(-mRad); 
        else static if(op == "+")
            return this;
    }
    
    Radian opAdd (Radian r ){ return Radian ( mRad + r.mRad ); }
    Radian opAdd (Degree d ){ return Radian ( mRad + d.valueRadians() ); }
    Radian opAddAssign (Radian r ) { mRad += r.mRad; return this; }
    Radian opAddAssign (Degree d ) { mRad += d.valueRadians(); return this; }
    Radian opAssign (Degree d ) { mRad = d.valueRadians(); return this; }
    Radian opSub (Radian r ){ return Radian ( mRad - r.mRad ); }
    Radian opSub (Degree d ){ return Radian ( mRad - d.valueRadians() ); }
    Radian opSubAssign (Radian r ) { mRad -= r.mRad; return this; }
    Radian opSubAssign (Degree d ) { mRad -= d.valueRadians(); return this; }
    Radian opMul ( Real f ) { return Radian ( mRad * f ); }
    Radian opMul (const Real f ) const { return Radian ( mRad * f ); }
    Radian opMul (Radian f ) { return Radian ( mRad * f.mRad ); }
    Radian opMulAssign (Real f ) { mRad *= f; return this; }
    Radian opDiv ( Real f ) const { return Radian ( mRad / f ); }
    Radian opDivAssign ( Real f ) { mRad /= f; return this; }
    
    
    Real valueRadians() 
    {
        return mRad; 
    }
    
    Real valueDegrees()
    {
        return Math.RadiansToDegrees ( mRad );
    }
    
    Real valueAngleUnits()
    {
        return Math.RadiansToAngleUnits ( mRad );
    }
    
    Real opCmp(Radian r)
    {
        return mRad - r.mRad;
    }
    
    /*string toString()
     {
     return "Radian(" ~ std.conv.to!string(this.valueRadians()) ~ ")";
     }*/
}

/** Wrapper class which indicates a given angle value is in Degrees.
 @remarks
 Degree values are interchangeable with Radian values, and conversions
 will be done automatically between them.
 */
struct Degree
{
    Real mDeg = 0; // if you get an error here - make sure to define/typedef 'Real' first
    
public:
    this ( Real d ) { mDeg = d; }
    this (Radian r ) { mDeg = r.valueDegrees(); }
    Degree opAssign (Real f ) { mDeg = f; return this; }
    Degree opAssign (Degree d ) { mDeg = d.mDeg; return this; }
    Degree opAssign (Radian r ) { mDeg = r.valueDegrees(); return this; }
    
    Real valueDegrees() { return mDeg; }
    //Real valueRadians(); // see bottom of this file
    //Real valueAngleUnits();
    
    Degree opUnary (string op )()
    { 
        if (op == "+") return this;
        else if (op == "-")
            return Degree(-mDeg);
    }
    Degree opAdd (Degree d ) { return Degree ( mDeg + d.mDeg ); }
    Degree opAdd (Radian r ) { return Degree ( mDeg + r.valueDegrees() ); }
    Degree opAddAssign (Degree d ) { mDeg += d.mDeg; return this; }
    Degree opAddAssign (Radian r ) { mDeg += r.valueDegrees(); return this; }
    
    Degree opSub (Degree d ) { return Degree ( mDeg - d.mDeg ); }
    Degree opSub (Radian r ) { return Degree ( mDeg - r.valueDegrees() ); }
    Degree opSubAssign (Degree d ) { mDeg -= d.mDeg; return this; }
    Degree opSubAssign (Radian r ) { mDeg -= r.valueDegrees(); return this; }
    Degree opMul ( Real f ) { return Degree ( mDeg * f ); }
    Degree opMul (Degree f ) { return Degree ( mDeg * f.mDeg ); }
    Degree opMulAssign ( Real f ) { mDeg *= f; return this; }
    Degree opDiv ( Real f ) { return Degree ( mDeg / f ); }
    Degree opDivAssign ( Real f ) { mDeg /= f; return this; }
    
    Radian opMul ( Real a){
        return Radian ( a * this.valueRadians() );
    }
    
    Radian opDiv ( Real a){
        //return Radian ( a / this.valueRadians()  ); //TODO Really a/r ?
        return Radian ( this.valueRadians() / a );
    }
    
    /*Degree opMul( Real a)
    {
        return Degree ( a * this.valueDegrees() );
    }*/
    
    Degree opDiv_r ( Real a)
    {
        return Degree ( a / this.valueDegrees() );
    }
    
    /+const+/ Real valueRadians()
    {
        return Math.DegreesToRadians ( mDeg );
    }
    
    /+const+/ Real valueAngleUnits()
    {
        return Math.DegreesToAngleUnits ( mDeg );
    }
    
    Real opCmp(Degree d)
    {
        return this.mDeg - d.mDeg;
    }
    
    Real opCmp(Degree d) const
    {
        return this.mDeg - d.mDeg;
    }
    
    /*string toString()
     {
     return "Degree(" ~ std.conv.to!string(this.valueDegrees()) ~ ")";
     }*/
}

/** @} */
/** @} */
