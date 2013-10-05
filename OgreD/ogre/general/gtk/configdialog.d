module ogre.general.gtk.configdialog;
import ogre.config;

static if(OGRE_GTK)
{
    import std.conv : to;
    import ogre.bindings.mini_gtk;
    import ogre.backdrop;
    import ogre.compat;
    import ogre.general.root;
    import ogre.exception;
    import ogre.image.images;
    import ogre.resources.datastream;
    import ogre.rendersystem.rendersystem;
    import ogre.general.common;
    import ogre.image.pixelformat;
    import ogre.general.log;

    version(unittest)
        import std.stdio;

    enum gboolean FALSE = 0;
    enum gboolean TRUE = 1;

    /*
     * A GTK+2 dialog window, making it possible to configure OGRE
     * in a graphical way. It uses plain C gtk+ bindings since gtk-- is not
     * part of most standard distributions while gtk+ itself is present
     * in every Linux distribution I ever seen.
     */
    
    bool __gtk_init_once ()
    {
        static bool gtk_already_initialized = false;
        if (gtk_already_initialized)
            return true;
        
        gtk_already_initialized = true;
        
        // Initialize gtk+
        int argc = 0;
        char **argv = null;
        // Avoid gtk calling setlocale() otherwise
        // scanf("%f") won't work on some locales etc.
        // Leave this on application developer's responsibility.
        gtk_disable_setlocale ();
        return cast(bool)gtk_init_check (&argc, &argv);
    }

    //Can't pass reference to class to C callback. Wrap it up in struct.
    struct ConfigDialogPtr
    {
        ConfigDialog dlg;
    }

    /**
     Defines the behaviour of an automatic renderer configuration dialog.
     @remarks
     OGRE comes with it's own renderer configuration dialog, which
     applications can use to easily allow the user to configure the
     settings appropriate to their machine. This class defines the
     interface to this standard dialog. Because dialogs are inherently
     tied to a particular platform's windowing system, there will be a
     different subclass for each platform.
     @author
     Andrew Zabolotny <zap@homelink.ru>
     */
    class ConfigDialog
    {
    public:
        this() {}
        
        /**
         Displays the dialog.
         @remarks
         This method displays the dialog and from then on the dialog
         interacts with the user independently. The dialog will be
         calling the relevant OGRE rendering systems to query them for
         options and to set the options the user selects. The method
         returns when the user closes the dialog.
         @returns
         If the user accepted the dialog, <b>true</b> is returned.
         @par
         If the user cancelled the dialog (indicating the application
         should probably terminate), <b>false</b> is returned.
         @see
         RenderSystem
         */
        bool display ()
        {
            if (!__gtk_init_once ())
                return false;

            version(unittest)
            {
                //Nothing
            }
            else
            {
                /* Select previously selected rendersystem */
                mSelectedRenderSystem = Root.getSingleton ().getRenderSystem ();
            }

            /* Attempt to create the window */
            if (!createWindow ())
                throw new InternalError("Could not create configuration dialog",
                                        "ConfigDialog.display");
            
            // Modal loop
            gint result = gtk_dialog_run (GTK_DIALOG(mDialog));
            gtk_widget_destroy (mDialog);
            
            // Wait for all gtk events to be consumed ...
            while (gtk_events_pending ())
                gtk_main_iteration_do (FALSE);
            
            if (result != GtkResponseType.GTK_RESPONSE_OK)
                return false;

            version(unittest)
            {
                //nothing
            }
            else
                Root.getSingleton ().setRenderSystem (mSelectedRenderSystem);
            
            return true;
        }
        
    protected:
        /// The rendersystem selected by user
        RenderSystem mSelectedRenderSystem;
        /// The dialog window
        GtkWidget *mDialog;
        //GtkDialog *mDialog;
        /// The table with renderer parameters
        GtkWidget *mParamTable;
        /// The button used to accept the dialog
        GtkWidget *mOKButton;

        version(unittest)
        {
            ConfigOptionMap options;
        }

        /// Create the gtk+ dialog window
        bool createWindow ()
        {
            // Create the dialog window
            mDialog = gtk_dialog_new_with_buttons (
                CSTR("OGRE Engine Setup"), null, GtkDialogFlags.GTK_DIALOG_MODAL,
                CSTR("gtk-cancel"), GtkResponseType.GTK_RESPONSE_CANCEL,
                null);
            mOKButton = gtk_dialog_add_button (GTK_DIALOG (mDialog), CSTR("gtk-ok"), GtkResponseType.GTK_RESPONSE_OK);
            gtk_window_set_position (GTK_WINDOW (mDialog), GtkWindowPosition.GTK_WIN_POS_CENTER);
            gtk_window_set_resizable (GTK_WINDOW (mDialog), TRUE);

            //version(GTK2) gtk_widget_show ((GTK_DIALOG (mDialog).vbox));
            
            GtkWidget *vbox = gtk_vbox_new (FALSE, 5);
            gtk_widget_show (vbox);

            //version(GTK2)
            //    gtk_box_pack_start ( GTK_BOX (GTK_DIALOG(mDialog).vbox), vbox, TRUE, TRUE, 0);
            //else
            gtk_box_pack_start(GTK_BOX(gtk_bin_get_child(GTK_BIN(mDialog))), vbox, TRUE, TRUE, 0);

            // Unpack the image and create a GtkImage object from it
            try
            {
                static string imgType = "png";
                Image img = new Image;
                MemoryDataStream imgStream;

                ubyte[] buf = cast(ubyte[])GLX_backdrop_data;
                imgStream = new MemoryDataStream (buf, false);
                img.load (imgStream, imgType);
                PixelBox src = img.getPixelBox (0, 0);
                uint width = cast(uint)img.getWidth ();
                uint height = 85;//cast(uint)img.getHeight ();
                
                // Convert and copy image -- must be allocated with malloc
                //uint8 *data = (uint8 *)malloc (width * height * 4);
                ubyte[] data = new ubyte[width * height * 4];
                // Keep in mind that PixelBox does not free the data - this is ok
                // as gtk takes pixel data ownership in gdk_pixbuf_new_from_data
                PixelBox dst = new PixelBox (src, PixelFormat.PF_A8B8G8R8, data.ptr);
                
                PixelUtil.bulkPixelConversion (src, dst);
                
                GdkPixbuf *pixbuf = gdk_pixbuf_new_from_data (
                    cast(guchar *)dst.data, GDK_COLORSPACE_RGB,
                    true, 8, width, height, width * 4,
                    &backdrop_destructor, null);
                GtkWidget *ogre_logo = gtk_image_new_from_pixbuf (pixbuf);
                
                gdk_pixbuf_unref (pixbuf);
                
                gtk_widget_show (ogre_logo);
                gtk_box_pack_start (GTK_BOX (vbox), ogre_logo, FALSE, FALSE, 0);
            }
            catch (Exception e)
            {
                // Could not decode image; never mind
                version(unittest)
                {
                    writeln("WARNING: Failed to decode Ogre logo image.\n", e.msg);
                }
                else
                    LogManager.getSingleton().logMessage("WARNING: Failed to decode Ogre logo image");
            }
            
            GtkWidget *rs_hbox = gtk_hbox_new (FALSE, 0);
            gtk_box_pack_start (GTK_BOX (vbox), rs_hbox, FALSE, TRUE, 0);
            
            GtkWidget *rs_label = gtk_label_new (CSTR("Rendering subsystem:"));
            gtk_widget_show (rs_label);
            gtk_box_pack_start (GTK_BOX (rs_hbox), rs_label, TRUE, TRUE, 5);
            gtk_label_set_justify (GTK_LABEL (rs_label), GtkJustification.GTK_JUSTIFY_RIGHT);
            gtk_misc_set_alignment (GTK_MISC (rs_label), 1, 0.5);
            
            GtkWidget *rs_cb = gtk_combo_box_text_new ();
            gtk_widget_show (rs_cb);
            gtk_box_pack_start (GTK_BOX (rs_hbox), rs_cb, TRUE, TRUE, 5);

            auto dlgptr = new ConfigDialogPtr(this);
            g_signal_connect_data (cast(gpointer) (rs_cb), CSTR("changed"), cast(GCallback)&rendererChanged, 
                                   dlgptr, null,  cast(GConnectFlags)0);
            
            // Add all available renderers to the combo box
            version(unittest)
            {
                options["Test Entry"] = ConfigOption("Test Entry", "My name is Test", ["My name is Test", "Another option"], false);
                static class FakeClass
                {
                    string mName;
                public:
                    this(string name) { mName = name; }
                    string getName() { return mName; }
                }
                auto renderers = [new FakeClass("Entry 1"), new FakeClass("Entry 2"), new FakeClass("Entry 3")];
            }
            else
                RenderSystemList renderers = Root.getSingleton ().getAvailableRenderers ();
            uint idx = 0, sel_renderer_idx = 0;
            foreach (r; renderers)
            {
                //gtk_combo_box_append_text (GTK_COMBOBOX (rs_cb), CSTR(r.getName ()));
                gtk_combo_box_text_append_text (GTK_COMBOBOX_TEXT (rs_cb), CSTR(r.getName ()));
                version(unittest)
                {
                    //Nothing
                }
                else
                {
                    if (mSelectedRenderSystem == r)
                        sel_renderer_idx = idx;
                }
                idx++;
            }
            // Don't show the renderer choice combobox if there's just one renderer
            if (idx > 1)
                gtk_widget_show (rs_hbox);
            
            GtkWidget *ro_frame = gtk_frame_new (null);
            gtk_widget_show (ro_frame);
            gtk_box_pack_start (GTK_BOX (vbox), ro_frame, TRUE, TRUE, 0);
            
            GtkWidget *ro_label = gtk_label_new (CSTR("Renderer options:"));
            gtk_widget_show (ro_label);
            gtk_frame_set_label_widget (GTK_FRAME (ro_frame), ro_label);
            gtk_label_set_use_markup (GTK_LABEL (ro_label), TRUE);
            
            mParamTable = gtk_table_new (0, 0, FALSE);
            gtk_widget_show (mParamTable);
            gtk_container_add (GTK_CONTAINER (ro_frame), mParamTable);
            
            gtk_combo_box_set_active (GTK_COMBOBOX (rs_cb), sel_renderer_idx);
            return true;
        }

        extern (C) static void remove_all_callback (GtkWidget *widget, gpointer data)
        {
            GtkWidget *container = cast(GtkWidget *) (data);
            gtk_container_remove (GTK_CONTAINER (container), widget);
        }

        /// Get parameters from selected renderer and fill the dialog
        void setupRendererParams ()
        {
            // Remove all existing child widgets
            gtk_container_forall (GTK_CONTAINER (mParamTable),
                                  &remove_all_callback, mParamTable);
            version(unittest)
            {
                writeln("setupRendererParams");
                //nothing
            }
            else
                ConfigOptionMap options = mSelectedRenderSystem.getConfigOptions ();
            
            // Resize the table to hold as many options as we have
            gtk_table_resize (GTK_TABLE (mParamTable), cast(guint)options.lengthAA, 2);
            
            uint row = 0;
            foreach (k, v; options)
            {
                if (!v.possibleValues.length)
                {
                    continue;
                }
                
                GtkWidget *ro_label = gtk_label_new (CSTR(v.name));
                gtk_widget_show (ro_label);
                gtk_table_attach (GTK_TABLE (mParamTable), ro_label, 0, 1, row, row + 1,
                                  GtkAttachOptions.GTK_EXPAND | GtkAttachOptions.GTK_FILL,
                                  cast(GtkAttachOptions)0, 5, 0);
                gtk_label_set_justify (GTK_LABEL (ro_label), GtkJustification.GTK_JUSTIFY_RIGHT);
                gtk_misc_set_alignment (GTK_MISC (ro_label), 1, 0.5);
                
                GtkWidget *ro_cb = gtk_combo_box_text_new ();
                gtk_widget_show (ro_cb);
                gtk_table_attach (GTK_TABLE (mParamTable), ro_cb, 1, 2, row, row + 1,
                                  GtkAttachOptions.GTK_EXPAND | GtkAttachOptions.GTK_FILL,
                                  cast(GtkAttachOptions)0, 5, 0);
                
                // Set up a link from the combobox to the label
                g_object_set_data ( G_OBJECT(ro_cb), CSTR("renderer-option"), ro_label);

                uint idx = 0;
                foreach (opt_it; v.possibleValues)
                {
                    writeln(opt_it, ": ", v.currentValue);
                    gtk_combo_box_text_append_text(GTK_COMBOBOX_TEXT(ro_cb), CSTR(opt_it));
                    if (v.currentValue == opt_it)
                        gtk_combo_box_set_active (GTK_COMBOBOX(ro_cb), idx);
                    idx++;
                }

                auto dlgptr = new ConfigDialogPtr(this);
                g_signal_connect_data (cast(gpointer) (ro_cb), CSTR("changed"),
                                       cast(GCallback)&optionChanged, dlgptr, null, cast(GConnectFlags)0);
                row++;
            }
            
            gtk_widget_grab_focus (GTK_WIDGET(mOKButton));
        }

        /// Callback function for renderer select combobox
        extern (C) static void rendererChanged (GtkComboBoxText *widget, gpointer data)
        {
            ConfigDialog *This = cast(ConfigDialog *) data;

            //gchar *_renderer = widget //gtk_entry_get_text (GTK_ENTRY ( GTK_COMBO(widget).entry ));

            gchar *_renderer = gtk_combo_box_text_get_active_text(widget);
            string renderer = std.conv.to!string(_renderer);
            version(unittest)
            {
                import std.stdio;
                writeln("Selected: ", renderer);
                This.setupRendererParams ();
            }
            else
            {
                RenderSystemList renderers = Root.getSingleton ().getAvailableRenderers ();
                foreach (r; renderers)
                    if (renderer == r.getName ())
                {
                    This.mSelectedRenderSystem = r;
                    This.setupRendererParams ();
                }
            }
        }

        /// Callback function to change a renderer option
        extern (C) static void optionChanged (GtkComboBoxText *widget, gpointer data)
        {
            ConfigDialog This = (cast(ConfigDialogPtr *) (data)).dlg;
            GtkWidget *ro_label = cast(GtkWidget *) (g_object_get_data (G_OBJECT (widget), CSTR("renderer-option")));

            version(unittest)
            {
                This.options["Test Entry"].currentValue = .to!string(gtk_combo_box_text_get_active_text(widget));
            }
            else
            {
                This.mSelectedRenderSystem.setConfigOption (
                    .to!string(gtk_label_get_text (GTK_LABEL (ro_label))),
                    .to!string(gtk_combo_box_text_get_active_text (widget))
                    );
            }
            g_idle_add (&refreshParams, data);
        }

        /// Idle function to refresh renderer parameters
        extern (C) static gboolean refreshParams (gpointer data)
        {
            ConfigDialog This = (cast(ConfigDialogPtr*)data).dlg;
            //assert(This !is null);

            This.setupRendererParams ();
            return FALSE;
        }

        extern (C) static void backdrop_destructor (guchar *pixels, gpointer data)
        {
            //free (pixels);
        }
    }

    unittest
    {
        //For backdrop
        static if(OGRE_FREEIMAGE)
        {
            import ogre.image.freeimage;
            FreeImageCodec.startup();
        }

        import std.stdio;
        writeln(__FILE__,": ConfigDialog unittest");
        ConfigDialog dlg = new ConfigDialog;
        writeln("Dialog returned: ", dlg.display());
        static if(OGRE_FREEIMAGE)
            FreeImageCodec.shutdown();
    }
}