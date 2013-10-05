module ogre.strings;

private {
    import std.conv;
    import std.regex: split, regex, match;
    import std.path : extension, baseName, dirName;
    import std.array;
    import std.ascii;

    import ogre.compat;
    import ogre.math.quaternion;
    import ogre.math.angles;
    import ogre.math.vector;
    import ogre.math.matrix;
    import ogre.general.colourvalue;
    //import ogre.math.vector;
    //import ogre.general.colourvalue;
    import ogre.math.maths;
}


class StringUtil
{
    static bool isNumber(string str)
    {
        foreach(c; str)
            if(!(isDigit(c) || c == '.'))
                return false;
        return true;
    }
    
    static bool match(string str, string m, bool caseSensitive = true)
    {
        auto r = regex(m, "g" ~ (caseSensitive ? "" : "i"));
        return !.match(str, r).empty();
    }

    static void splitFilename(string fn, ref string basename, ref string path)
    {
        //ext = extension(fn);
        basename = baseName(fn);//XXX folder separator is platform specific
        path = dirName(fn);
        //compat with c++
        if(path == ".")
            path = "";
    }

    /** Returns a StringVector that contains all the substrings delimited
     by the characters in the passed <code>delims</code> argument.
     @param
     delims A list of delimiter characters to split by
     @param
     maxSplits The maximum number of splits to perform (-1 for unlimited (0xFFFFFFFF) splits). If this
     parameters is > 0, the splitting process will stop after this many splits, left to right.
     @param
     preserveDelims NOT USED. Flag to determine if delimiters should be saved as substrings
     */
    static string[] split(string str, string delim = " \t\n", uint maxSplit = -1, bool preserveDelims = false)
    {
        string[] splitted = str.split(regex("[" ~ delim ~"]+", "g")); //be careful of trailing whitespace
        
        if(splitted.length > maxSplit)
        {
            splitted[maxSplit] = splitted[maxSplit..$].join("" ~ delim[0]);
            splitted = splitted[0..maxSplit+1];
        }
        
        return splitted;
    }
}

class StringConverter
{
private:
    static string GenSplits(T, string type="Real")(size_t count)
    {
        string s;
        foreach(i; 0..count)
        {
            s ~= "to!" ~ type ~ "(split[" ~ to!string(i) ~ "])";
            if(i < count-1 )
                s ~= ", ";
        }
        return T.stringof ~ "(" ~ s ~ ")";//idunno, seems that ctors get confused if just passed as arguments
    }
public:
    static Radian parseAngle(string val, Radian defaultValue /*= Radian(0f)*/ /*struct size error bs*/) {
        Real angle = defaultValue.valueRadians();
        try
        {
            angle = to!Real(val);
        }
        catch(ConvException e) {}

        return Angle(angle).toRadian();
    }

    // [\t\n ]+ : mind the '+'
    //FIXME Trailing delims add empty string to array.
    static Vector2 parseVector2(string str, Vector2 def = Vector2.ZERO)
    {
        string[] split = str.split(regex("[\t\n ]+", "g")); //be caref ul of trailing whitespace
        if(split.length != 2)
            return def;
        return (mixin(GenSplits!Vector2(2)));
    }
    
    static Vector3 parseVector3(string str, Vector3 def = Vector3.ZERO)
    {
        string[] split = str.split(regex("[\t\n ]+", "g")); //be caref ul of trailing whitespace
        if(split.length != 3)
            return def;
        return (mixin(GenSplits!Vector3(3)));
    }
    
    static Vector4 parseVector4(string str, Vector4 def = Vector4.ZERO)
    {
        string[] split = str.split(regex("[\t\n ]+", "g")); //be caref ul of trailing whitespace
        if(split.length != 4)
            return def;
        return (mixin(GenSplits!Vector4(4)));
    }
    
    static Quaternion parseQuaternion(string str, Quaternion def = Quaternion.ZERO)
    {
        string[] split = str.split(regex("[\t\n ]+", "g")); //be caref ul of trailing whitespace
        if(split.length != 4)
            return def;
        return mixin(GenSplits!Quaternion(4));
    }
    
    static Matrix3 parseMatrix3(string str, Matrix3 def = Matrix3.IDENTITY)
    {
        string[] split = str.split(regex("[\t\n ]+", "g")); //be caref ul of trailing whitespace
        if(split.length != 9)
            return def;
        return (mixin(GenSplits!Matrix3(9)));
    }
    
    static Matrix4 parseMatrix4(string str, Matrix4 def = Matrix4.IDENTITY)
    {
        string[] split = str.split(regex("[\t\n ]+", "g")); //be caref ul of trailing whitespace
        if(split.length != 16)
            return def;
        return (mixin(GenSplits!Matrix4(16)));
    }
    
    static ColourValue parseColourValue(string str, ColourValue def = ColourValue.Black)
    {
        string[] split = str.split(regex("[\t\n ]+", "g")); //be caref ul of trailing whitespace
        if(split.length != 4)
            return def;
        return (mixin(GenSplits!ColourValue(4)));
    }
    
    static string[] parseString(string str)
    {
        return str.split(regex("[\t\n ]+", "g"));
    }
    
    static string[] parseStringVector(string str)
    {
        return str.split(regex("[\t\n ]+", "g"));
    }
    
    static T parse(T)(string str) if(is(T == short) || is(T == ushort) ||
                                     is(T == int) || is(T == uint) || 
                                     is(T == long) || is(T == ulong) || 
                                     is(T == bool) || is(T == size_t) )
    {
        return to!T(str);
    }

    unittest
    {
        //TODO Give me some unittest
    }
}
