module ogre.general.errordialog;
import ogre.config;

/*version(Windows)
{
    import ogre.general.windows.errordialog;
    alias ogre.general.windows.errordialog.ErrorDialog ErrorDialog;
}
else*/ 
version(Posix)
{
    static if(OGRE_GTK)
    {
        import ogre.general.gtk.errordialog;
        alias ogre.general.gtk.errordialog.ErrorDialog ErrorDialog;
    }
    else
    {
        import ogre.general.glx.errordialog;
        alias ogre.general.glx.errordialog.ErrorDialog ErrorDialog;
    }
}
else
{
    import std.stdio;
    class ErrorDialog
    {
        this()
        {
            // Constructor code
        }

        void display(string errorMessage, string logName = "")
        {
            stderr.writeln("*** ERROR: ", errorMessage);
        }
    }
}