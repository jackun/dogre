module ogregl.util;
import std.algorithm;
import std.conv;
import ogre.general.log;

//TODO Pretty simple dumb algo
void remove_duplicates(T)(ref T[] c)
{
    size_t s,e;
    sort(c);
    for(size_t i = 0; i < c.length; )
    {
        e = i;
        foreach(el; c[i+1..$])
        {
            if(el == c[i])
                e++;
            else
                break;
        }
        
        if(i < e)
            c = c[0..i] ~ c[e..$];
        else
            i++;
    }
}

C _conv(C, T)(T val, C def)
{
    try
    {
        return to!C(val);
    }catch(std.conv.ConvException e)
    {
        LogManager.getSingleton().logMessage("Error parsing '" ~ val ~ "' : " ~ e.msg);
        return def;
    }
}