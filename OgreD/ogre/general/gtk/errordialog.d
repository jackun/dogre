module ogre.general.gtk.errordialog;
import ogre.config;

static if(OGRE_GTK)
{
    import ogre.bindings.mini_gtk;
    import ogre.general.gtk.configdialog: __gtk_init_once;

    /** Class for displaying the error dialog if Ogre fails badly. */
    class ErrorDialog
    {
    public:
        this() {}
        
        /**
         @remarks
             Displays the error dialog.
         @param
             errorMessage The error message which has caused the failure.
         @param
             logName Optional name of the log to display in the detail pane.
         */
        void display(string errorMessage, string logName = "")
        {
            if (!__gtk_init_once ())
            {
                import std.stdio;
                stderr.writeln("*** ERROR: ", errorMessage);
                return;
            }
            
            GtkWidget *dialog = gtk_message_dialog_new (
                null, GtkDialogFlags.GTK_DIALOG_MODAL, 
                GtkMessageType.GTK_MESSAGE_ERROR, 
                GtkButtonsType.GTK_BUTTONS_OK,
                cast(char*)errorMessage.ptr);

            gtk_window_set_position (GTK_WINDOW (dialog), GtkWindowPosition.GTK_WIN_POS_CENTER);
            gtk_dialog_run (GTK_DIALOG (dialog));
            gtk_widget_destroy (dialog);
            
            // Wait for all gtk events to be consumed ...
            while (gtk_events_pending ())
                gtk_main_iteration_do (0);
        }
    }

    unittest
    {
        import std.stdio;
        writeln(__FILE__, ": ErrorDialog unittest");
        ErrorDialog dlg = new ErrorDialog;
        dlg.display("Some random error.", "logname.log");
    }
}