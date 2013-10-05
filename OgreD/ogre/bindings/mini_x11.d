module ogre.bindings.mini_x11;

/// Mainly for ogre.rendersystem.glx.windoweventutilities

//http://www.dsource.org/projects/bindings/browser/trunk/X11

version(linux)
{
    pragma(lib, "X11");

    /* Resources */
    version(X86_64)
    {
        alias long c_long;
        alias ulong c_ulong;
    }
    else
    {
        alias int c_long;
        alias uint c_ulong;
    }
    
    alias c_ulong    XID;
    alias c_ulong Mask;
    alias c_ulong VisualID;
    alias c_ulong Time;
    alias XID Atom; //alias needed because of None invariant shared for Atom and XID
    alias XID Window;
    alias XID Drawable;
    alias XID Font;
    alias XID Pixmap;
    alias XID Cursor;
    alias XID Colormap;
    alias XID GContext;
    alias XID KeySym;
    alias uint KeyCode;

    alias int Bool;
    enum : Bool {False,True}; //xlib boolean is int type, D bool is only byte
    alias void* XPointer;
    alias int Status;

    /// Window attributes for CreateWindow and ChangeWindowAttributes
    enum 
    {
        CWBackPixmap        = (1<<0),
        CWBackPixel         = (1<<1),
        CWBorderPixmap      = (1<<2),
        CWBorderPixel       = (1<<3),
        CWBitGravity        = (1<<4),
        CWWinGravity        = (1<<5),
        CWBackingStore      = (1<<6),
        CWBackingPlanes     = (1<<7),
        CWBackingPixel      = (1<<8),
        CWOverrideRedirect  = (1<<9),
        CWSaveUnder         = (1<<10),
        CWEventMask         = (1<<11),
        CWDontPropagate     = (1<<12),
        CWColormap          = (1<<13),
        CWCursor            = (1<<14),
    }
    
    /** Input Event Masks. Used as event-mask window attribute and as arguments
     to Grab requests.  Not to be confused with event names.  */
    
    alias uint EventMask;
    enum : EventMask
    { 
        NoEventMask             =0,
        KeyPressMask            =1<<0,
        KeyReleaseMask          =1<<1, 
        ButtonPressMask         =1<<2,
        ButtonReleaseMask       =1<<3,
        EnterWindowMask         =1<<4,
        LeaveWindowMask         =1<<5,
        PointerMotionMask       =1<<6,
        PointerMotionHintMask   =1<<7,
        Button1MotionMask       =1<<8,
        Button2MotionMask       =1<<9,
        Button3MotionMask       =1<<10,
        Button4MotionMask       =1<<11,
        Button5MotionMask       =1<<12,
        ButtonMotionMask        =1<<13,
        KeymapStateMask         =1<<14,
        ExposureMask            =1<<15,
        VisibilityChangeMask    =1<<16,
        StructureNotifyMask     =1<<17,
        ResizeRedirectMask      =1<<18,
        SubstructureNotifyMask  =1<<19,
        SubstructureRedirectMask=1<<20,
        FocusChangeMask         =1<<21,
        PropertyChangeMask      =1<<22,
        ColormapChangeMask      =1<<23,
        OwnerGrabButtonMask     =1<<24
    }

    /* Event names.  Used in "type" field in XEvent structures.  Not to be
     confused with event masks above.  They start from 2 because 0 and 1
     are reserved in the protocol for errors and replies. */
    
    enum EventType:int
    {
        KeyPress            =2,
        KeyRelease          =3,
        ButtonPress         =4,
        ButtonRelease       =5,
        MotionNotify        =6,
        EnterNotify         =7,
        LeaveNotify         =8,
        FocusIn             =9,
        FocusOut            =10,
        KeymapNotify        =11,
        Expose              =12,
        GraphicsExpose      =13,
        NoExpose            =14,
        VisibilityNotify    =15,
        CreateNotify        =16,
        DestroyNotify       =17,
        UnmapNotify         =18,
        MapNotify           =19,
        MapRequest          =20,
        ReparentNotify      =21,
        ConfigureNotify     =22,
        ConfigureRequest    =23,
        GravityNotify       =24,
        ResizeRequest       =25,
        CirculateNotify     =26,
        CirculateRequest    =27,
        PropertyNotify      =28,
        SelectionClear      =29,
        SelectionRequest    =30,
        SelectionNotify     =31,
        ColormapNotify      =32,
        ClientMessage       =33,
        MappingNotify       =34,
        LASTEvent           =35 /* must be bigger than any event # */
    }
    
    enum int AllocNone = 0;

    enum ByteOrder:int
    {
        LSBFirst        =0,
        MSBFirst        =1
    }
    
    enum
    {
        InputOutput     = 1,
        InputOnly       = 2,
    }

    /* Visibility notify */
    
    enum VisibilityNotify:int
    {
        VisibilityUnobscured        =0,
        VisibilityPartiallyObscured =1,
        VisibilityFullyObscured     =2
    }

    /*
     * Extensions need a way to hang private data on some structures.
     */
    struct XExtData 
    {
        int number;     /* number returned by XRegisterExtension */
        XExtData *next;     /* next item on list of data for structure */
        int function(XExtData *extension) free_private; /* called to free private storage */
        XPointer private_data;  /* data private to this extension. */
    }

    struct _XPrivate{}      /* Forward declare before use for C++ */
    struct _XrmHashBucketRec{}
    //struct _XGC {}
    struct _XGC;
    alias _XGC *GC;

    /*
     * Format structure; describes ZFormat data the screen will understand.
     */
    struct ScreenFormat
    {
        XExtData *ext_data; /* hook for extension to hang data */
        int depth;          /* depth of this image format */
        int bits_per_pixel; /* bits/pixel at this depth */
        int scanline_pad;   /* scanline must padded to this multiple */
    }
    
    /*
     * Visual structure; contains information about colormapping possible.
     */
    struct Visual
    {
        XExtData *ext_data; /* hook for extension to hang data */
        VisualID visualid;  /* visual id of this visual */
        int class_;         /* class of screen (monochrome, etc.) */
        c_ulong red_mask, green_mask, blue_mask;  /* mask values */
        int bits_per_rgb;   /* log base 2 of distinct color values */
        int map_entries;    /* color map entries */
    }

    /*
     * Depth structure; contains information for each possible depth.
     */ 
    struct Depth
    {
        int depth;      /* this depth (Z) of the depth */
        int nvisuals;       /* number of Visual types at this depth */
        Visual *visuals;    /* list of visuals possible at this depth */
    }

    //TODO Seems to be a little off
    struct Screen{
        XExtData *ext_data;     /* hook for extension to hang data */
        XDisplay *display;      /* back pointer to display structure */
        Window root;            /* Root window id. */
        int width, height;      /* width and height of screen */
        int mwidth, mheight;    /* width and height of  in millimeters */
        int ndepths;            /* number of depths possible */
        Depth *depths;          /* list of allowable depths on the screen */
        int root_depth;         /* bits per pixel */
        Visual *root_visual;    /* root visual */
        GC default_gc;          /* GC for the root root visual */
        Colormap cmap;          /* default color map */
        c_ulong white_pixel;
        c_ulong black_pixel;      /* White and Black pixel values */
        int max_maps, min_maps; /* max and min color maps */
        int backing_store;      /* Never, WhenMapped, Always */
        Bool save_unders;   
        c_long root_input_mask;   /* initial root input mask */
    }

    //TODO Seems to be a little off
    struct _XDisplay
    {
        XExtData* ext_data;
        _XPrivate* private1;
        int fd;
        int private2;
        int proto_major_version;
        int proto_minor_version;
        char* vendor;
        XID resource_base;
        XID resource_mask;
        XID resource_id;
        int resource_shift;
        XID function(_XDisplay*) *resource_alloc;
        int byte_order;
        int bitmap_unit;
        int bitmap_pad;
        int bitmap_bit_order;
        int nformats;
        ScreenFormat* pixmap_format;
        int vnumber;
        int release;
        _XPrivate* head;
        _XPrivate* tail;
        int qlen;
        c_ulong last_request_read;
        c_ulong request;
        _XPrivate* last_req;
        _XPrivate* buffer;
        _XPrivate* bufptr;
        _XPrivate* bufmax;
        uint max_request_size;
        _XrmHashBucketRec* db;
        int function(_XDisplay*)* private15;
        char* display_name;
        int **default_screen;
        int nscreens;
        Screen* screens;
        c_ulong motion_buffer;
        c_ulong private16;
        int min_keycode;
        int max_keycode;
        XPointer private17;
        XPointer private18;
        int ext_number;
        char* xdefaults;
    }
    alias _XDisplay Display;
    alias _XDisplay XDisplay;

    struct XGCValues
    {
        int function_;
        int plane_mask;
        int foreground;
        int background;
        int line_width;
        int line_style;
        int cap_style;
        int join_style;
        int fill_style;
        int fill_rule;
        int arc_mode;
        int tile;
        int stipple;
        int ts_x_origin;
        int ts_y_origin;
        int font;
        int subwindow_mode;
        int graphics_exposures;
        int clip_x_origin;
        int clip_y_origin;
        int clip_mask;
        int dash_offset;
        char dashes;
    }

    struct XImage
    {
        int width;
        int height;
        int xoffset;
        int format;
        ubyte* data;
        int byte_order;
        int bitmap_unit;
        int bitmap_bit_order;
        int bitmap_pad;
        int depth;
        int chars_per_line;
        int bits_per_pixel;
        c_ulong red_mask;
        c_ulong green_mask;
        c_ulong blue_mask;
        XPointer obdata;//TODO
        //XPointer obdata1;
        //XPointer obdata2;
        struct F
        {
            XImage* function(XDisplay*, Visual*, uint, int, int, ubyte*, uint, uint, int, int) create_image;
            int function(XImage*) destroy_image;
            c_ulong function(XImage*, int, int) get_pixel;
            int function(XImage*, int, int, c_ulong) put_pixel;
            XImage function(XImage*, int, int, uint, uint) sub_image;
            int function(XImage*, c_long) add_pixel;
        }
        F f;
    }

    enum ImageFormat : int
    {
        XYBitmap = 0,
        XYPixmap = 1,
        ZPixmap = 2,
    }

    /*
     * this union is defined so Xlib can always use the same sized
     * event structure internally, to avoid memory fragmentation.
     * Cut unneeded stuff
     */
    union XEvent{
        int type;       /* must not be changed; first element */
        XVisibilityEvent xvisibility;
        XClientMessageEvent xclient;
        // bunch of stuff.....
        c_long[24] pad;
    }

    struct XVisibilityEvent{
        int type;
        c_ulong serial;   /* # of last request processed by server */
        Bool send_event;    /* true if this came from a SendEvent request */
        Display *display;   /* Display the event was read from */
        Window window;
        VisibilityNotify state;     /* Visibility state */
    }

    struct XClientMessageEvent
    {
        int type;
        c_ulong serial;   /* # of last request processed by server */
        Bool send_event;    /* true if this came from a SendEvent request */
        Display *display;   /* Display the event was read from */
        Window window;
        Atom message_type;
        int format;
        union data_t
        {
            byte[20] b;
            short[10] s;
            c_long[5] l;
        }
        data_t data;
    }
    
    struct XWindowAttributes
    {
        int x, y;           /* location of window */
        int width, height;      /* width and height of window */
        int border_width;       /* border width of window */
        int depth;              /* depth of window */
        Visual *visual;     /* the associated visual structure */
        Window root;            /* root of screen containing window */
        int c_class;        /* C++ InputOutput, InputOnly*/
        int bit_gravity;        /* one of bit gravity values */
        int win_gravity;        /* one of the window gravity values */
        int backing_store;      /* NotUseful, WhenMapped, Always */
        c_ulong backing_planes;/* planes to be preserved if possible */
        c_ulong backing_pixel;/* value to be used when restoring planes */
        Bool save_under;        /* boolean, should bits under be saved? */
        Colormap colormap;      /* color map to be associated with window */
        Bool map_installed;     /* boolean, is color map currently installed*/
        int map_state;      /* IsUnmapped, IsUnviewable, IsViewable */
        c_long all_event_masks;   /* set of events all people have interest in*/
        c_long your_event_mask;   /* my event mask */
        c_long do_not_propagate_mask; /* set of events that should not propagate */
        Bool override_redirect; /* boolean value for override-redirect */
        Screen *screen;     /* back pointer to correct screen */
    }
    
    struct XSetWindowAttributes {
        Pixmap background_pixmap;   /* background or None or ParentRelative */
        c_ulong background_pixel; /* background pixel */
        Pixmap border_pixmap;   /* border of the window */
        c_ulong border_pixel; /* border pixel value */
        int bit_gravity;        /* one of bit gravity values */
        int win_gravity;        /* one of the window gravity values */
        int backing_store;      /* NotUseful, WhenMapped, Always */
        c_ulong backing_planes;/* planes to be preseved if possible */
        c_ulong backing_pixel;/* value to use in restoring planes */
        Bool save_under;        /* should bits under be saved? (popups) */
        c_long event_mask;        /* set of events that should be saved */
        c_long do_not_propagate_mask; /* set of events that should not propagate */
        Bool override_redirect; /* boolean value for override-redirect */
        Colormap colormap;      /* color map to be associated with window */
        Cursor cursor;      /* cursor to be displayed (or None) */
    }
    
    
    struct XErrorEvent {
        int type;
        Display *display;   /* Display the event was read from */
        XID resourceid;     /* resource id */
        c_ulong serial;   /* serial number of failed request */
        ubyte error_code;   /* error code of failed request */
        ubyte request_code; /* Major op-code of failed request */
        ubyte minor_code;   /* Minor op-code of failed request */
    }

    //These fail, Display is not so valid :/
    Window      RootWindow     ( Display* dpy,int scr   )   { return ScreenOfDisplay( dpy,scr ).root;       }
    int         DefaultScreen  ( Display* dpy           )   { return **dpy.default_screen;                    }
    int         DisplayWidth   ( Display* dpy,int scr   )   { return ScreenOfDisplay( dpy,scr ).width;      }
    int         DisplayHeight  ( Display* dpy,int scr   )   { return ScreenOfDisplay( dpy,scr ).height;     }
    int         DefaultDepth   ( Display* dpy,int scr   )   { return ScreenOfDisplay( dpy,scr ).root_depth; }
    Screen*     ScreenOfDisplay( Display* dpy,int scr   )   { return &dpy.screens[scr];                     }

    extern(C)
    {

        Bool XCheckWindowEvent(
            Display*    /* display */,
            Window      /* w */,
            EventMask   /* event_mask */,
            XEvent*     /* event_return */
            );

        Bool XCheckTypedWindowEvent(
            Display*    /* display */,
            Window      /* w */,
            EventType   /* event_type */,
            XEvent*     /* event_return */
            );

        Bool XFreePixmap(Display*, Pixmap);
        Bool XCloseDisplay(void* disp);
        Screen* XScreenOfDisplay(Display *, int);
        XImage* XCreateImage(void*, Visual *, uint, ImageFormat, int, void *, uint, uint, int, int);
        Bool XPutImage(void*Disp, c_long, _XGC *, XImage *, int, int, int, int, uint, uint);
        Bool XDestroyImage(XImage* ximage);
        Pixmap XCreatePixmap(void*Disp, Drawable, uint, uint, uint);
        GC XCreateGC(void*Disp, Drawable, c_ulong, XGCValues*);
        Bool XFreeGC(void*Disp, GC);
        int XDefaultDepth(void*disp, int scr);
        Window XDefaultRootWindow(void* disp);
        Window XRootWindow(Display *, int);
        int XDefaultScreen(void* disp);
        int XDisplayWidth(void* disp, int);
        int XDisplayHeight(void* disp, int);
        int XDisplayPlanes(void*dsp,int);
        Display *XOpenDisplay(const(char)*);
        Atom XInternAtom(void*Display,char*,Bool);
        Pixmap XCreateBitmapFromData(void*Disp,Drawable,const(ubyte)*,uint,uint);
        int XImageByteOrder(void*Disp);
        Bool XQueryExtension(void* disp,const(char)*,int*,int*,int*);
        int XFree(void*);
        char* XDisplayString(void* disp);
        char* XDisplayName(const(char)* ds);
        Status XGetWindowAttributes(void*disp,Window,XWindowAttributes*);
        VisualID XVisualIDFromVisual(Visual*);
        Status XSetWMProtocols(void*,Window,Atom*,int);
        Status XGetWMProtocols(void*,Window,Atom**,int*);
        int XMapWindow(void*,Window);
        int XUnmapWindow(void*,Window);
        int XDestroyWindow(void*,Window);
        Colormap XCreateColormap(void*dsp,Window,void*Visual,int);
        void XFlush(void*dsp);
        Window XCreateWindow(void*,Window,int,int,uint,uint,uint,int,uint,void*Visual,c_ulong,XSetWindowAttributes*,);
        int XMoveWindow(void*dsp,Window,int,int);
        Status XQueryTree(void*dsp,Window,Window*,Window*,Window**,uint*);
        int XResizeWindow(void*dsp,Window,uint,uint);
        Status XSendEvent(void*dsp,Window,Bool,c_long,XEvent*);
        
        
        alias int function(void*, XErrorEvent*) XErrorHandler;//void* because Derelict3 conflict otherwise
        XErrorHandler XSetErrorHandler (XErrorHandler);
        
        //Randr
        struct _XRRScreenConfiguration;
        alias _XRRScreenConfiguration XRRScreenConfiguration;
        struct XRRScreenSize 
        {
            int width, height;
            int mwidth, mheight;
        }
        
        XRRScreenConfiguration *XRRGetScreenInfo (void* display, Window);
        int XRRConfigCurrentConfiguration (XRRScreenConfiguration *config, ushort *rotation);
        XRRScreenSize *XRRConfigSizes(XRRScreenConfiguration *config, int *nsizes);
        short XRRConfigCurrentRate (XRRScreenConfiguration *config);
        short *XRRConfigRates (XRRScreenConfiguration *config, int sizeID, int *nrates);
        void XRRFreeScreenConfigInfo (XRRScreenConfiguration *config);
        Status XRRSetScreenConfigAndRate (void*dpy,XRRScreenConfiguration*,Drawable,int,ushort,short,int Time);
        
        
        //Xutil
        /// definitions for initial window state
        enum
        {
            WithdrawnState  = 0,    /* for windows that are not mapped */
            NormalState     = 1,   /* most applications want to start this way */
            IconicState     = 3,   /* application wants to start as an icon */
        }
        
        /// definition for flags of XWMHints
        enum
        {
            InputHint           = (1 << 0),
            StateHint           = (1 << 1),
            IconPixmapHint      = (1 << 2),
            IconWindowHint      = (1 << 3),
            IconPositionHint    = (1 << 4),
            IconMaskHint        = (1 << 5),
            WindowGroupHint     = (1 << 6),
            AllHints  = (InputHint|StateHint|IconPixmapHint|IconWindowHint|IconPositionHint|IconMaskHint|WindowGroupHint),
            XUrgencyHint        = (1 << 8),
        }
        
        /// flags argument in size hints
        enum
        {
            USPosition  = (1 << 0), /* user specified x, y */
            USSize      = (1 << 1), /* user specified width, height */
                    
            PPosition   = (1 << 2), /* program specified position */
            PSize       = (1 << 3), /* program specified size */
            PMinSize    = (1 << 4), /* program specified minimum size */
            PMaxSize    = (1 << 5), /* program specified maximum size */
            PResizeInc  = (1 << 6), /* program specified resize increments */
            PAspect     = (1 << 7), /* program specified min and max aspect ratios */
            PBaseSize   = (1 << 8), /* program specified base for incrementing */
            PWinGravity = (1 << 9), /* program specified window gravity */
        }
        
        struct XWMHints{
            long flags; /* marks which fields in this structure are defined */
            Bool input; /* does this application rely on the window manager to
            get keyboard input? */
            int initial_state;  /* see below */
            Pixmap icon_pixmap; /* pixmap to be used as icon */
            Window icon_window;     /* window to be used as icon */
            int icon_x, icon_y;     /* initial position of icon */
            Pixmap icon_mask;   /* icon mask bitmap */
            XID window_group;   /* id of related window group */
            /* this structure may be extended in the future */
        }
        
        struct XSizeHints{
            c_long flags; /* marks which fields in this structure are defined */
            int x, y;       /* obsolete for new window mgrs, but clients */
            int width, height;  /* should set so old wm's don't mess up */
            int min_width, min_height;
            int max_width, max_height;
            int width_inc, height_inc;
            struct Aspect{
                int x;  /* numerator */
                int y;  /* denominator */
            } 
            Aspect min_aspect, max_aspect;
            int base_width, base_height;        /* added by ICCCM version 1 */
            int win_gravity;            /* added by ICCCM version 1 */
        }
        
        struct XTextProperty{
            ubyte *value;       /* same as Property routines */
            Atom encoding;          /* prop type */
            int format;             /* prop data format: 8, 16, or 32 */
            c_ulong nitems;       /* number of data items in value */
        }
        struct XClassHint{
            char *res_name;
            char *res_class;
        }
               
        XWMHints *XAllocWMHints ();
        XSizeHints *XAllocSizeHints ();
        void XSetWMProperties(void*,Window,XTextProperty*,XTextProperty*,char**,int,XSizeHints*,XWMHints*,XClassHint*);
        Status XStringListToTextProperty(char**,int,XTextProperty*);
        
    }
}