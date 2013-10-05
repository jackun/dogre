module ogre.general.configdialog;
import ogre.config;

version(Windows)
{
    import ogre.general.windows.configdialog;
    alias ogre.general.windows.configdialog.ConfigDialog ConfigDialog;
}
else version(Posix)
{
    static if(OGRE_GTK)
    {
        import ogre.general.gtk.configdialog;
        alias ogre.general.gtk.configdialog.ConfigDialog ConfigDialog;
    }
    else
    {
        import ogre.general.glx.configdialog;
        alias ogre.general.glx.configdialog.ConfigDialog ConfigDialog;
    }
}
else
{
    ConfigDialog dlg;
    class ConfigDialog
    {
        this()
        {
            // Constructor code
        }

        void initialise() {}
        void run() {}
        void cancel() {}
        bool display()
        {
            return true;
        }
    }
}