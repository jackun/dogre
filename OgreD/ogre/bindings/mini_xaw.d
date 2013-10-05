module ogre.bindings.mini_xaw;

import ogre.config;
static if(!OGRE_GTK && OgrePosix)
{
    import ogre.bindings.mini_x11;
    pragma(lib, "Xaw");
    pragma(lib, "Xt");

    alias uint _XtAppStruct;
    alias _XtAppStruct * XtAppContext;
    alias XID _XRegion;
    alias XID _XtEventRec;
    alias XID _XtStateRec;
    alias XID _TranslationData;
    alias void * XtActionHookId;
    alias void * XtCacheRef;
    alias void * XtPointer;
    alias void * XtRequestId;
    alias void * XtVarArgsList;
    //enum int False = 0;
    //enum int True = 1;

    enum XIMStatusDataType : int 
    {
        XIMTextType = 0,
        XIMBitmapType = 1
    }
    enum XtListPosition : int 
    {
        XtListHead = 0,
        XtListTail = 1
    }
    enum XtCommandHighlight : int 
    {
        HighlightNone = 0,
        HighlightWhenUnset = 1,
        HighlightAlways = 2
    }
    enum XawEdgeType : int 
    {
        XawChainTop = 0,
        XawChainBottom = 1,
        XawChainLeft = 2,
        XawChainRight = 3,
        XawRubber = 4
    }
    enum XtGrabKind : int 
    {
        XtGrabNone = 0,
        XtGrabNonexclusive = 1,
        XtGrabExclusive = 2
    }
    enum XtCallbackStatus : int 
    {
        XtCallbackNoList = 0,
        XtCallbackHasNone = 1,
        XtCallbackHasSome = 2
    }
    enum XtGeometryResult : int 
    {
        XtGeometryYes = 0,
        XtGeometryNo = 1,
        XtGeometryAlmost = 2,
        XtGeometryDone = 3
    }
    enum XawTextJustifyMode : int 
    {
        XawjustifyLeft = 0,
        XawjustifyRight = 1,
        XawjustifyCenter = 2,
        XawjustifyFull = 3
    }
    enum LayoutState : int 
    {
        LayoutPending = 0,
        LayoutInProgress = 1,
        LayoutDone = 2
    }

    enum XawTextSelectionMode : int 
    {
        XawsmTextSelect = 0,
        XawsmTextExtend = 1
    }
    enum XawTextSelectType : int 
    {
        XawselectNull = 0,
        XawselectPosition = 1,
        XawselectChar = 2,
        XawselectWord = 3,
        XawselectLine = 4,
        XawselectParagraph = 5,
        XawselectAll = 6,
        XawselectAlphaNumeric = 7
    }

    enum XawTextScanType : int 
    {
        XawstPositions = 0,
        XawstWhiteSpace = 1,
        XawstEOL = 2,
        XawstParagraph = 3,
        XawstAll = 4,
        XawstAlphaNumeric = 5
    }
    enum XOrientation : int 
    {
        XOMOrientation_LTR_TTB = 0,
        XOMOrientation_RTL_TTB = 1,
        XOMOrientation_TTB_LTR = 2,
        XOMOrientation_TTB_RTL = 3,
        XOMOrientation_Context = 4
    }
    enum XtAddressMode : int 
    {
        XtAddress = 0,
        XtBaseOffset = 1,
        XtImmediate = 2,
        XtResourceString = 3,
        XtResourceQuark = 4,
        XtWidgetBaseOffset = 5,
        XtProcedureArg = 6
    }

    enum XrmBinding : int 
    {
        XrmBindTightly = 0,
        XrmBindLoosely = 1
    }

    enum XawTextScrollMode : int 
    {
        XawtextScrollNever = 0,
        XawtextScrollWhenNeeded = 1,
        XawtextScrollAlways = 2
    }
    enum XawTextWrapMode : int 
    {
        XawtextWrapNever = 0,
        XawtextWrapLine = 1,
        XawtextWrapWord = 2
    }

    enum XawTextResizeMode : int 
    {
        XawtextResizeNever = 0,
        XawtextResizeWidth = 1,
        XawtextResizeHeight = 2,
        XawtextResizeBoth = 3
    }
    enum XrmOptionKind : int 
    {
        XrmoptionNoArg = 0,
        XrmoptionIsArg = 1,
        XrmoptionStickyArg = 2,
        XrmoptionSepArg = 3,
        XrmoptionResArg = 4,
        XrmoptionSkipArg = 5,
        XrmoptionSkipLine = 6,
        XrmoptionSkipNArgs = 7
    }
    enum XawTextSelectionAction : int 
    {
        XawactionStart = 0,
        XawactionAdjust = 1,
        XawactionEnd = 2
    }
    enum XIMCaretStyle : int 
    {
        XIMIsInvisible = 0,
        XIMIsPrimary = 1,
        XIMIsSecondary = 2
    }
    enum XtJustify : int 
    {
        XtJustifyLeft = 0,
        XtJustifyCenter = 1,
        XtJustifyRight = 2
    }

    enum XawTextInsertState : int 
    {
        XawisOn = 0,
        XawisOff = 1
    }
    enum XtOrientation : int 
    {
        XtorientHorizontal = 0,
        XtorientVertical = 1
    }
    enum XawTextScanDirection : int 
    {
        XawsdLeft = 0,
        XawsdRight = 1
    }
    enum XawTextEditType : int 
    {
        XawtextRead = 0,
        XawtextAppend = 1,
        XawtextEdit = 2
    }
    enum highlightType : int 
    {
        Normal = 0,
        Selected = 1
    }
    enum XawAsciiType : int 
    {
        XawAsciiFile = 0,
        XawAsciiString = 1
    }
    enum XIMCaretDirection : int 
    {
        XIMForwardChar = 0,
        XIMBackwardChar = 1,
        XIMForwardWord = 2,
        XIMBackwardWord = 3,
        XIMCaretUp = 4,
        XIMCaretDown = 5,
        XIMNextLine = 6,
        XIMPreviousLine = 7,
        XIMLineStart = 8,
        XIMLineEnd = 9,
        XIMAbsolutePosition = 10,
        XIMDontChange = 11
    }

    struct _XtActionsRec
    {
        char* str;
        void function(_WidgetRec *, XEvent *, char * *, uint *) * proc;
    }

    struct Arg
    {
        char * name;
        int value;
    }

    struct _CoreClassPart
    {
        _WidgetClassRec * superclass;
        char * class_name;
        uint widget_size;
        void function() class_initialize;
        void function(_WidgetClassRec *) class_part_initialize;
        ubyte class_inited;
        void function(_WidgetRec *, _WidgetRec *, Arg *, uint *) initialize;
        void function(_WidgetRec *, Arg *, uint *) initialize_hook;
        void function(_WidgetRec *, int *, XSetWindowAttributes *) realize;
        _XtActionsRec * actions;
        uint num_actions;
        _XtResource * resources;
        uint num_resources;
        int xrm_class;
        char compress_motion;
        ubyte compress_exposure;
        char compress_enterleave;
        char visible_interest;
        void function(_WidgetRec *) destroy;
        void function(_WidgetRec *) resize;
        void function(_WidgetRec *, XEvent *, _XRegion *) expose;
        char function(_WidgetRec *, _WidgetRec *, _WidgetRec *, Arg *, uint *) set_values;
        char function(_WidgetRec *, Arg *, uint *) set_values_hook;
        void function(_WidgetRec *, _WidgetRec *, XtWidgetGeometry *, XtWidgetGeometry *) set_values_almost;
        void function(_WidgetRec *, Arg *, uint *) get_values_hook;
        char function(_WidgetRec *, int *) accept_focus;
        int version_;
        void * callback_private;
        char * tm_table;
        XtGeometryResult function(_WidgetRec *, XtWidgetGeometry *, XtWidgetGeometry *) query_geometry;
        void function(_WidgetRec *, char *) display_accelerator;
        void * extension;
    }

    struct _WidgetClassRec
    {
        _CoreClassPart core_class;
    }

    struct _CorePart
    {
        _WidgetRec * self;
        _WidgetClassRec * widget_class;
        _WidgetRec * parent;
        int xrm_name;
        char being_destroyed;
        _XtCallbackRec * destroy_callbacks;
        void * constraints;
        short x;
        short y;
        ushort width;
        ushort height;
        ushort border_width;
        char managed;
        char sensitive;
        char ancestor_sensitive;
        _XtEventRec * event_table;
        _XtTMRec tm;
        _TranslationData * accelerators;
        int border_pixel;
        int border_pixmap;
        _WidgetRec * * popup_list;
        uint num_popups;
        char * name;
        Screen * screen;
        int colormap;
        int window;
        uint depth;
        int background_pixel;
        int background_pixmap;
        char visible;
        char mapped_when_managed;
    }

    struct _WidgetRec
    {
        _CorePart core;
    }

    alias _WidgetRec* Widget;

    /*struct XSetWindowAttributes
    {
        int background_pixmap;
        int background_pixel;
        int border_pixmap;
        int border_pixel;
        int bit_gravity;
        int win_gravity;
        int backing_store;
        int backing_planes;
        int backing_pixel;
        int save_under;
        int event_mask;
        int do_not_propagate_mask;
        int override_redirect;
        int colormap;
        int cursor;
    }*/

    struct _XtResource
    {
        char * resource_name;
        char * resource_class;
        char * resource_type;
        uint resource_size;
        uint resource_offset;
        char * default_type;
        void * default_addr;
    }

    struct XtWidgetGeometry
    {
        uint request_mode;
        short x;
        short y;
        ushort width;
        ushort height;
        ushort border_width;
        _WidgetRec * sibling;
        int stack_mode;
    }

    struct _XtCallbackRec
    {
        void function(_WidgetRec *, void *, void *) callback;
        void * closure;
    }

    struct XrmOptionDescRec
    {
        char * option;
        char * specifier;
        XrmOptionKind argKind;
        char * value;
    }

    struct _XtTMRec
    {
        _TranslationData * translations;
        void function(_WidgetRec *, XEvent *, char * *, uint *) * proc_table;
        _XtStateRec * current_state;
        int lastEventTime;
    }

    extern (C)
    {
        alias void function(_WidgetRec *, void *, void *) XtCallbackProc;
        //Note the two 'extern'. Access global data.
        extern __gshared _WidgetClassRec * sessionShellWidgetClass;
        extern __gshared _WidgetClassRec * formWidgetClass;
        extern __gshared _WidgetClassRec * menuButtonWidgetClass;
        extern __gshared _WidgetClassRec * labelWidgetClass;
        extern __gshared _WidgetClassRec * simpleMenuWidgetClass;
        extern __gshared _WidgetClassRec * smeBSBObjectClass;
        extern __gshared _WidgetClassRec * commandWidgetClass;

        void XtUnrealizeWidget(Widget);
        void XtDestroyWidget(Widget);
        Widget XtVaOpenApplication(_XtAppStruct * *, char *, XrmOptionDescRec *, uint, int *, char * *, char * *, _WidgetClassRec *, ...);
        Display* XtDisplay(Widget);
        void XtVaSetValues(Widget, ...);
        Widget XtVaCreateManagedWidget(char *, _WidgetClassRec *, _WidgetRec *, ...);
        Widget XtVaCreatePopupShell(char *, _WidgetClassRec *, _WidgetRec *, ...);
        void XtAddCallbacks(_WidgetRec *, char *, _XtCallbackRec *, ...);
        void XtAddCallback(_WidgetRec *, char *, void function(_WidgetRec *, void *, void *) cb, void *);
        void XtRealizeWidget(Widget);
        void XtAppMainLoop(_XtAppStruct *);
        void XtAppNextEvent(_XtAppStruct *, XEvent *);
        void XtAppProcessEvent(_XtAppStruct *, int);
        void XtAppSetExitFlag(_XtAppStruct *);
    }
}
