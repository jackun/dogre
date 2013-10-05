module ogre.general.glx.errordialog;
import std.stdio;

class ErrorDialog
{
public:
    this() {}
    void display(string errorMessage, string logName = "")
    {
        stderr.writeln("*** ERROR: ", errorMessage);
    }
}