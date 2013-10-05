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
enum IceAcceptStatus : int 
{
	IceAcceptSuccess = 0,
	IceAcceptFailure = 1,
	IceAcceptBadMalloc = 2
}
enum IceConnectStatus : int 
{
	IceConnectPending = 0,
	IceConnectAccepted = 1,
	IceConnectRejected = 2,
	IceConnectIOError = 3
}
enum IceProtocolSetupStatus : int 
{
	IceProtocolSetupSuccess = 0,
	IceProtocolSetupFailure = 1,
	IceProtocolSetupIOError = 2,
	IceProtocolAlreadyActive = 3
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
enum SmcCloseStatus : int 
{
	SmcClosedNow = 0,
	SmcClosedASAP = 1,
	SmcConnectionInUse = 2
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
enum XICCEncodingStyle : int 
{
	XStringStyle = 0,
	XCompoundTextStyle = 1,
	XTextStyle = 2,
	XStdICCTextStyle = 3,
	XUTF8StringStyle = 4
}
enum XrmBinding : int 
{
	XrmBindTightly = 0,
	XrmBindLoosely = 1
}
enum IcePaAuthStatus : int 
{
	IcePaAuthContinue = 0,
	IcePaAuthAccepted = 1,
	IcePaAuthRejected = 2,
	IcePaAuthFailed = 3
}
enum IceProcessMessagesStatus : int 
{
	IceProcessMessagesSuccess = 0,
	IceProcessMessagesIOError = 1,
	IceProcessMessagesConnectionClosed = 2
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
enum IceCloseStatus : int 
{
	IceClosedNow = 0,
	IceClosedASAP = 1,
	IceConnectionInUse = 2,
	IceStartedShutdownNegotiation = 3
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
enum IcePoAuthStatus : int 
{
	IcePoAuthHaveReply = 0,
	IcePoAuthRejected = 1,
	IcePoAuthFailed = 2,
	IcePoAuthDoneCleanup = 3
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
enum __codecvt_result : int 
{
	__codecvt_ok = 0,
	__codecvt_partial = 1,
	__codecvt_error = 2,
	__codecvt_noconv = 3
}

struct _ListClassRec
{
_CoreClassPart core_class;
SimpleClassPart simple_class;
ListClassPart list_class;
}


struct _SmeLineClassRec
{
_RectObjClassPart rect_class;
_SmeClassPart sme_class;
_SmeLineClassPart sme_line_class;
}


struct XawTextLineTable
{
int top;
int lines;
int base_line;
XawTextLineTableEntry * info;
}


struct timeval
{
int tv_sec;
int tv_usec;
}


struct SmPropValue
{
int length;
void * value;
}


struct _XawImPart
{
_XIM * xim;
XrmResource * resources;
uint num_resources;
char open_im;
char initialized;
ushort area_height;
char * input_method;
char * preedit_type;
}


struct _XawGripCallData
{
_XEvent * event;
char * * params;
uint num_params;
}


struct _ScrollbarRec
{
_CorePart core;
SimplePart simple;
ScrollbarPart scrollbar;
}


struct XIconSize
{
int min_width;
int min_height;
int max_width;
int max_height;
int width_inc;
int height_inc;
}


struct XVisualInfo
{
Visual * visual;
int visualid;
int screen;
int depth;
int _class;
int red_mask;
int green_mask;
int blue_mask;
int colormap_size;
int bits_per_rgb;
}


struct XNoExposeEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int drawable;
int major_code;
int minor_code;
}


struct _TextClassRec
{
_CoreClassPart core_class;
SimpleClassPart simple_class;
TextClassPart text_class;
}


struct XCirculateRequestEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int parent;
int window;
int place;
}


struct ScreenFormat
{
_XExtData * ext_data;
int depth;
int bits_per_pixel;
int scanline_pad;
}


struct _TranslationData
{
}


struct _XtActionsRec
{
char * string;
void function(_WidgetRec *, _XEvent *, char * *, uint *) * proc;
}


struct XDestroyWindowEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int event;
int window;
}


struct ViewportConstraintsPart
{
int reparented;
}


struct _LabelRec
{
_CorePart core;
SimplePart simple;
LabelPart label;
}


struct _BoxClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
BoxClassPart box_class;
}


struct _RectObjRec
{
_ObjectPart object;
_RectObjPart rectangle;
}


struct XawTextPaintList
{
_XmuArea * clip;
_XmuArea * hightabs;
_XawTextPaintStruct * paint;
_XawTextPaintStruct * bearings;
}


struct _FormConstraintsRec
{
_FormConstraintsPart form;
}


struct _TipClassRec
{
_CoreClassPart core_class;
TipClassPart tip_class;
}


struct _StripChartRec
{
_CorePart core;
SimplePart simple;
StripChartPart strip_chart;
}


struct _XExtData
{
int number;
_XExtData * next;
int function(_XExtData *) * free_private;
char * private_data;
}


struct _WidgetClassRec
{
_CoreClassPart core_class;
}


struct XButtonEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int window;
int root;
int subwindow;
int time;
int x;
int y;
int x_root;
int y_root;
uint state;
uint button;
int same_screen;
}


struct _SmeRec
{
_ObjectPart object;
_RectObjPart rectangle;
SmePart sme;
}


struct _XIMPreeditDrawCallbackStruct
{
int caret;
int chg_first;
int chg_length;
_XIMText * text;
}


struct _SmeLineRec
{
_ObjectPart object;
_RectObjPart rectangle;
SmePart sme;
SmeLinePart sme_line;
}


struct _CompositeClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
}


struct _OverrideShellClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
ShellClassPart shell_class;
OverrideShellClassPart override_shell_class;
}


struct AsciiClassPart
{
void * extension;
}


struct _PanedRec
{
_CorePart core;
_CompositePart composite;
_ConstraintPart constraint;
PanedPart paned;
}


struct _TopLevelShellClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
ShellClassPart shell_class;
WMShellClassPart wm_shell_class;
VendorShellClassPart vendor_shell_class;
TopLevelShellClassPart top_level_shell_class;
}


struct _TipRec
{
_CorePart core;
_TipPart tip;
}


struct XawTextSelection
{
int left;
int right;
XawTextSelectType type;
int * selections;
int atom_count;
int array_size;
}


struct __sigset_t
{
int [16] __val;
}


struct XClientMessageEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int window;
int message_type;
int format;
__HTD_gen_1 data;
}


struct XTextProperty
{
ubyte * value;
int encoding;
int format;
int nitems;
}


struct XCirculateEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int event;
int window;
int place;
}


struct _XtStateRec
{
}


struct _WMShellClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
ShellClassPart shell_class;
WMShellClassPart wm_shell_class;
}


struct _AsciiRec
{
_CorePart core;
SimplePart simple;
_TextPart text;
AsciiPart ascii;
}


struct _TemplateRec
{
_CorePart core;
TemplatePart _template;
}


struct XPoint
{
short x;
short y;
}


struct _XIMStringConversionCallbackStruct
{
ushort position;
XIMCaretDirection direction;
ushort operation;
ushort factor;
_XIMStringConversionText * text;
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


struct _SmsConn
{
}


struct XSetWindowAttributes
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
}


struct _XIMPreeditStateNotifyCallbackStruct
{
int state;
}


struct _G_fpos_t
{
int __pos;
__mbstate_t __state;
}


struct WMShellPart
{
char * title;
int wm_timeout;
char wait_for_wm;
char transient;
char urgency;
_WidgetRec * client_leader;
char * window_role;
_OldXSizeHints size_hints;
XWMHints wm_hints;
int base_width;
int base_height;
int win_gravity;
int title_encoding;
}


struct _XtCallbackRec
{
void function(_WidgetRec *, void *, void *) * callback;
void * closure;
}


struct _TreeConstraintsPart
{
_WidgetRec * parent;
_XGC * gc;
_WidgetRec * * children;
int n_children;
int max_children;
ushort bbsubwidth;
ushort bbsubheight;
ushort bbwidth;
ushort bbheight;
short x;
short y;
void * [2] pad;
}


struct BoxClassPart
{
void * extension;
}


struct XtCreateHookDataRec
{
char * type;
_WidgetRec * widget;
Arg * args;
uint num_args;
}


struct XwcTextItem
{
dchar * chars;
int nchars;
int delta;
_XOC * font_set;
}


struct _ToggleClass
{
void function(_WidgetRec *, _XEvent *, char * *, uint *) * Set;
void function(_WidgetRec *, _XEvent *, char * *, uint *) * Unset;
void * extension;
}


struct _AsciiTextClassRec
{
_CoreClassPart core_class;
SimpleClassPart simple_class;
TextClassPart text_class;
AsciiClassPart ascii_class;
}


struct XawVendorShellExtRec
{
_ObjectPart object;
XawVendorShellExtPart vendor_ext;
}


struct _XawTextAnchor
{
int position;
_XawTextEntity * entities;
_XawTextEntity * cache;
}


struct _XtTMRec
{
_TranslationData * translations;
void function(_WidgetRec *, _XEvent *, char * *, uint *) * * proc_table;
_XtStateRec * current_state;
int lastEventTime;
}


struct _CommandClassRec
{
_CoreClassPart core_class;
SimpleClassPart simple_class;
LabelClassPart label_class;
_CommandClass command_class;
}


struct _IO_FILE
{
int _flags;
char * _IO_read_ptr;
char * _IO_read_end;
char * _IO_read_base;
char * _IO_write_base;
char * _IO_write_ptr;
char * _IO_write_end;
char * _IO_buf_base;
char * _IO_buf_end;
char * _IO_save_base;
char * _IO_backup_base;
char * _IO_save_end;
_IO_marker * _markers;
_IO_FILE * _chain;
int _fileno;
int _flags2;
int _old_offset;
ushort _cur_column;
byte _vtable_offset;
char [1] _shortbuf;
void * _lock;
int _offset;
void * __pad1;
void * __pad2;
void * __pad3;
void * __pad4;
int __pad5;
int _mode;
char [20] _unused2;
}


struct XReparentEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int event;
int window;
int parent;
int x;
int y;
int override_redirect;
}


struct _SimpleMenuPart
{
char * label_string;
_SmeRec * label;
_WidgetClassRec * label_class;
ushort top_margin;
ushort bottom_margin;
ushort row_height;
int cursor;
_SmeRec * popup_entry;
char menu_on_screen;
int backing_store;
char recursive_set_values;
char menu_width;
char menu_height;
_SmeRec * entry_set;
ushort left_margin;
ushort right_margin;
_XawDL * display_list;
_WidgetRec * sub_menu;
ubyte state;
void * [4] pad;
}


struct SimpleClassPart
{
int function(_WidgetRec *) * change_sensitive;
void * extension;
}


struct XMotionEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int window;
int root;
int subwindow;
int time;
int x;
int y;
int x_root;
int y_root;
uint state;
char is_hint;
int same_screen;
}


struct BoxPart
{
ushort h_space;
ushort v_space;
XtOrientation orientation;
ushort preferred_width;
ushort preferred_height;
ushort last_query_width;
ushort last_query_height;
uint last_query_mode;
_XawDL * display_list;
void * [4] pad;
}


struct _XPrivate
{
}


struct TextClassPart
{
void * extension;
}


struct XOMFontInfo
{
int num_font;
XFontStruct * * font_struct_list;
char * * font_name_list;
}


struct _AsciiSrcClassPart
{
void * extension;
}


struct _contextErrDataRec
{
_WidgetRec * widget;
_XIM * xim;
}


struct XUnmapEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int event;
int window;
int from_configure;
}


struct _XrmHashBucketRec
{
}


struct _PaneStack
{
_PaneStack * next;
_PanedConstraintsPart * pane;
int start_size;
}


struct _SimpleClassRec
{
_CoreClassPart core_class;
SimpleClassPart simple_class;
}


struct XKeyEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int window;
int root;
int subwindow;
int time;
int x;
int y;
int x_root;
int y_root;
uint state;
uint keycode;
int same_screen;
}


struct ApplicationShellClassPart
{
void * extension;
}


struct _DialogPart
{
char * label;
char * value;
int icon;
_WidgetRec * iconW;
_WidgetRec * labelW;
_WidgetRec * valueW;
void * [4] pad;
}


struct _CommandRec
{
_CorePart core;
SimplePart simple;
LabelPart label;
CommandPart command;
}


struct XConfigureRequestEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int parent;
int window;
int x;
int y;
int width;
int height;
int border_width;
int above;
int detail;
int value_mask;
}


struct _XawTextMargin
{
short left;
short right;
short top;
short bottom;
}


struct OverrideShellClassPart
{
void * extension;
}


struct XMappingEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int window;
int request;
int first_keycode;
int count;
}


struct XAnyEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int window;
}


struct XGenericEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int extension;
int evtype;
}


struct _SmeClassPart
{
void function(_WidgetRec *) * highlight;
void function(_WidgetRec *) * unhighlight;
void function(_WidgetRec *) * notify;
void * extension;
}


struct _XawTextUndo
{
}


struct _MultiSrcClassPart
{
void * extension;
}


struct _PanedClassPart
{
void * extension;
}


struct _XRegion
{
}


struct _XIMHotKeyTriggers
{
int num_hot_key;
_XIMHotKeyTrigger * key;
}


struct SessionShellRec
{
_CorePart core;
_CompositePart composite;
ShellPart shell;
WMShellPart wm;
VendorShellPart vendor;
TopLevelShellPart topLevel;
ApplicationShellPart application;
SessionShellPart session;
}


struct _XmuArea
{
_XmuScanline * scanline;
}


struct XtChangeHookDataRec
{
char * type;
_WidgetRec * widget;
void * event_data;
uint num_event_data;
}


struct FormClassPart
{
char function(_FormRec *, uint, uint, int) * layout;
void * extension;
}


struct _CoreClassPart
{
_WidgetClassRec * superclass;
char * class_name;
uint widget_size;
void function() * class_initialize;
void function(_WidgetClassRec *) * class_part_initialize;
ubyte class_inited;
void function(_WidgetRec *, _WidgetRec *, Arg *, uint *) * initialize;
void function(_WidgetRec *, Arg *, uint *) * initialize_hook;
void function(_WidgetRec *, int *, XSetWindowAttributes *) * realize;
_XtActionsRec * actions;
uint num_actions;
_XtResource * resources;
uint num_resources;
int xrm_class;
char compress_motion;
ubyte compress_exposure;
char compress_enterleave;
char visible_interest;
void function(_WidgetRec *) * destroy;
void function(_WidgetRec *) * resize;
void function(_WidgetRec *, _XEvent *, _XRegion *) * expose;
char function(_WidgetRec *, _WidgetRec *, _WidgetRec *, Arg *, uint *) * set_values;
char function(_WidgetRec *, Arg *, uint *) * set_values_hook;
void function(_WidgetRec *, _WidgetRec *, XtWidgetGeometry *, XtWidgetGeometry *) * set_values_almost;
void function(_WidgetRec *, Arg *, uint *) * get_values_hook;
char function(_WidgetRec *, int *) * accept_focus;
int version_;
void * callback_private;
char * tm_table;
XtGeometryResult function(_WidgetRec *, XtWidgetGeometry *, XtWidgetGeometry *) * query_geometry;
void function(_WidgetRec *, char *) * display_accelerator;
void * extension;
}


struct ShellClassPart
{
void * extension;
}


struct _ToggleClassRec
{
_CoreClassPart core_class;
SimpleClassPart simple_class;
LabelClassPart label_class;
_CommandClass command_class;
_ToggleClass toggle_class;
}


struct Screen
{
_XExtData * ext_data;
_XDisplay * display;
int root;
int width;
int height;
int mwidth;
int mheight;
int ndepths;
Depth * depths;
int root_depth;
Visual * root_visual;
_XGC * default_gc;
int cmap;
int white_pixel;
int black_pixel;
int max_maps;
int min_maps;
int backing_store;
int save_unders;
int root_input_mask;
}


struct _DialogRec
{
_CorePart core;
_CompositePart composite;
_ConstraintPart constraint;
_FormPart form;
_DialogPart dialog;
}


struct ShellRec
{
_CorePart core;
_CompositePart composite;
ShellPart shell;
}


struct fd_set
{
int [16] __fds_bits;
}


struct ListClassPart
{
void * extension;
}


struct XPixmapFormatValues
{
int depth;
int bits_per_pixel;
int scanline_pad;
}


struct SessionShellClassPart
{
void * extension;
}


struct _WidgetRec
{
_CorePart core;
}


struct _XIMText
{
ushort length;
int * feedback;
int encoding_is_wchar;
__HTD_gen_2 string;
}


struct TemplatePart
{
char * resource;
char * _private;
}


struct __locale_struct
{
__locale_data * [13] __locales;
ushort * __ctype_b;
int * __ctype_tolower;
int * __ctype_toupper;
char * [13] __names;
}


struct XawVendorShellExtPart
{
_WidgetRec * parent;
_XawImPart im;
_XawIcPart ic;
void * [4] pad;
}


struct _MultiSinkRec
{
_ObjectPart object;
TextSinkPart text_sink;
MultiSinkPart multi_sink;
}


struct TextSinkExtRec
{
void * next_extension;
int record_type;
int version_;
uint record_size;
int function(_WidgetRec *) * BeginPaint;
void function(_WidgetRec *, int, int, int, int, int) * PreparePaint;
void function(_WidgetRec *) * DoPaint;
int function(_WidgetRec *) * EndPaint;
}


struct XtConvertArgRec
{
XtAddressMode address_mode;
void * address_id;
uint size;
}


struct XExtCodes
{
int extension;
int major_opcode;
int first_event;
int first_error;
}


struct _PanedConstraintsRec
{
_PanedConstraintsPart paned;
}


struct _XawTextPropertyList
{
int identifier;
Screen * screen;
int colormap;
int depth;
_XawTextProperty * * properties;
uint num_properties;
_XawTextPropertyList * next;
}


struct _ObjectPart
{
_WidgetRec * self;
_WidgetClassRec * widget_class;
_WidgetRec * parent;
int xrm_name;
char being_destroyed;
_XtCallbackRec * destroy_callbacks;
void * constraints;
}


struct _TreeRec
{
_CorePart core;
_CompositePart composite;
_ConstraintPart constraint;
TreePart tree;
}


struct _Piece
{
char * text;
int used;
_Piece * prev;
_Piece * next;
}


struct XTextItem16
{
XChar2b * chars;
int nchars;
int delta;
int font;
}


struct XGraphicsExposeEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int drawable;
int x;
int y;
int width;
int height;
int count;
int major_code;
int minor_code;
}


struct XmbTextItem
{
char * chars;
int nchars;
int delta;
_XOC * font_set;
}


struct XMapRequestEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int parent;
int window;
}


struct XtTypedArg
{
char * name;
char * type;
int value;
int size;
}


struct ObjectClassExtensionRec
{
void * next_extension;
int record_type;
int version_;
uint record_size;
void function(_WidgetClassRec *, uint *, uint *, Arg *, uint *, XtTypedArg *, uint *, _WidgetRec * *, void * *) * allocate;
void function(_WidgetRec *, void *) * deallocate;
}


struct _XawTextEntity
{
short type;
short flags;
_XawTextEntity * next;
void * data;
int offset;
uint length;
int property;
}


struct ListPart
{
int foreground;
ushort internal_width;
ushort internal_height;
ushort column_space;
ushort row_space;
int default_cols;
char force_cols;
char paste;
char vertical_cols;
int longest;
int nitems;
XFontStruct * font;
_XOC * fontset;
char * * list;
_XtCallbackRec * callback;
int is_highlighted;
int highlight;
int col_width;
int row_height;
int nrows;
int ncols;
_XGC * normgc;
_XGC * revgc;
_XGC * graygc;
int freedoms;
int selected;
char show_current;
char [11] pad1;
void * [2] pad2;
}


struct _TipPart
{
int foreground;
XFontStruct * font;
_XOC * fontset;
ushort top_margin;
ushort bottom_margin;
ushort left_margin;
ushort right_margin;
int backing_store;
int timeout;
_XawDL * display_list;
_XGC * gc;
int timer;
char * label;
char international;
ubyte encoding;
void * [4] pad;
}


struct MultiSinkPart
{
char echo;
char display_nonprinting;
_XGC * normgc;
_XGC * invgc;
_XGC * xorgc;
int cursor_position;
XawTextInsertState laststate;
short cursor_x;
short cursor_y;
_XOC * fontset;
void * [4] pad;
}


struct _RectObjClassPart
{
_WidgetClassRec * superclass;
char * class_name;
uint widget_size;
void function() * class_initialize;
void function(_WidgetClassRec *) * class_part_initialize;
ubyte class_inited;
void function(_WidgetRec *, _WidgetRec *, Arg *, uint *) * initialize;
void function(_WidgetRec *, Arg *, uint *) * initialize_hook;
void function() * rect1;
void * rect2;
uint rect3;
_XtResource * resources;
uint num_resources;
int xrm_class;
char rect4;
ubyte rect5;
char rect6;
char rect7;
void function(_WidgetRec *) * destroy;
void function(_WidgetRec *) * resize;
void function(_WidgetRec *, _XEvent *, _XRegion *) * expose;
char function(_WidgetRec *, _WidgetRec *, _WidgetRec *, Arg *, uint *) * set_values;
char function(_WidgetRec *, Arg *, uint *) * set_values_hook;
void function(_WidgetRec *, _WidgetRec *, XtWidgetGeometry *, XtWidgetGeometry *) * set_values_almost;
void function(_WidgetRec *, Arg *, uint *) * get_values_hook;
void function() * rect9;
int version_;
void * callback_private;
char * rect10;
XtGeometryResult function(_WidgetRec *, XtWidgetGeometry *, XtWidgetGeometry *) * query_geometry;
void function() * rect11;
void * extension;
}


struct _XOM
{
}


struct CompositeClassExtensionRec
{
void * next_extension;
int record_type;
int version_;
uint record_size;
char accepts_objects;
char allows_change_managed_set;
}


struct _TextSrcClassRec
{
_ObjectClassPart object_class;
_TextSrcClassPart textSrc_class;
}


struct PannerClassPart
{
void * extension;
}


struct PannerPart
{
_XtCallbackRec * report_callbacks;
char allow_off;
char resize_to_pref;
int foreground;
int shadow_color;
ushort shadow_thickness;
ushort default_scale;
ushort line_width;
ushort canvas_width;
ushort canvas_height;
short slider_x;
short slider_y;
ushort slider_width;
ushort slider_height;
ushort internal_border;
char * stipple_name;
_XGC * slider_gc;
_XGC * shadow_gc;
_XGC * xor_gc;
double haspect;
double vaspect;
char rubber_band;
__HTD_gen_3 tmp;
short knob_x;
short knob_y;
ushort knob_width;
ushort knob_height;
char shadow_valid;
XRectangle [2] shadow_rects;
short last_x;
short last_y;
void * [4] pad;
}


struct PortholeClassPart
{
void * extension;
}


struct XtDestroyHookDataRec
{
char * type;
_WidgetRec * widget;
}


struct _IceConn
{
}


struct _MultiSrcPart
{
_XIC * ic;
void * string;
XawAsciiType type;
int piece_size;
char data_compression;
char use_string_in_place;
int multi_length;
char is_tempfile;
char allocated_string;
int length;
_MultiPiece * first_piece;
void * [4] pad;
}


struct XSizeHints
{
int flags;
int x;
int y;
int width;
int height;
int min_width;
int min_height;
int max_width;
int max_height;
int width_inc;
int height_inc;
__HTD_gen_4 min_aspect;
__HTD_gen_4 max_aspect;
int base_width;
int base_height;
int win_gravity;
}


struct _RadioGroup
{
_RadioGroup * prev;
_RadioGroup * next;
_WidgetRec * widget;
}


struct _XtCheckpointTokenRec
{
int save_type;
int interact_style;
char shutdown;
char fast;
char cancel_shutdown;
int phase;
int interact_dialog_type;
char request_cancel;
char request_next_phase;
char save_success;
int type;
_WidgetRec * widget;
}


struct _XDisplay
{
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


struct _XawIcPart
{
int input_style;
char shared_ic;
_XawIcTablePart * shared_ic_table;
_XawIcTablePart * current_ic_table;
_XawIcTablePart * ic_table;
}


struct _AtomRec
{
}


struct _SmcConn
{
}


struct _SessionShellClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
ShellClassPart shell_class;
WMShellClassPart wm_shell_class;
VendorShellClassPart vendor_shell_class;
TopLevelShellClassPart top_level_shell_class;
ApplicationShellClassPart application_shell_class;
SessionShellClassPart session_shell_class;
}


struct XFontProp
{
int name;
int card32;
}


struct _AsciiSinkClassPart
{
void * extension;
}


struct OverrideShellRec
{
_CorePart core;
_CompositePart composite;
ShellPart shell;
OverrideShellPart override_;
}


struct SmeLinePart
{
int foreground;
int stipple;
ushort line_width;
_XGC * gc;
void * [4] pad;
}


struct XChar2b
{
ubyte byte1;
ubyte byte2;
}


struct _SmeBSBClassPart
{
void * extension;
}


struct _ScrollbarClassRec
{
_CoreClassPart core_class;
SimpleClassPart simple_class;
ScrollbarClassPart scrollbar_class;
}


struct _ObjectClassPart
{
_WidgetClassRec * superclass;
char * class_name;
uint widget_size;
void function() * class_initialize;
void function(_WidgetClassRec *) * class_part_initialize;
ubyte class_inited;
void function(_WidgetRec *, _WidgetRec *, Arg *, uint *) * initialize;
void function(_WidgetRec *, Arg *, uint *) * initialize_hook;
void function() * obj1;
void * obj2;
uint obj3;
_XtResource * resources;
uint num_resources;
int xrm_class;
char obj4;
ubyte obj5;
char obj6;
char obj7;
void function(_WidgetRec *) * destroy;
void function() * obj8;
void function() * obj9;
char function(_WidgetRec *, _WidgetRec *, _WidgetRec *, Arg *, uint *) * set_values;
char function(_WidgetRec *, Arg *, uint *) * set_values_hook;
void function() * obj10;
void function(_WidgetRec *, Arg *, uint *) * get_values_hook;
void function() * obj11;
int version_;
void * callback_private;
char * obj12;
void function() * obj13;
void function() * obj14;
void * extension;
}


struct _StripChartClassRec
{
_CoreClassPart core_class;
SimpleClassPart simple_class;
StripChartClassPart strip_chart_class;
}


struct _SimpleMenuRec
{
_CorePart core;
_CompositePart composite;
ShellPart shell;
OverrideShellPart override_;
_SimpleMenuPart simple_menu;
}


struct _ApplicationShellClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
ShellClassPart shell_class;
WMShellClassPart wm_shell_class;
VendorShellClassPart vendor_shell_class;
TopLevelShellClassPart top_level_shell_class;
ApplicationShellClassPart application_shell_class;
}


struct TransientShellRec
{
_CorePart core;
_CompositePart composite;
ShellPart shell;
WMShellPart wm;
VendorShellPart vendor;
TransientShellPart transient;
}


struct _RepeaterClassRec
{
_CoreClassPart core_class;
SimpleClassPart simple_class;
LabelClassPart label_class;
_CommandClass command_class;
RepeaterClassPart repeater_class;
}


struct _GripClassRec
{
_CoreClassPart core_class;
SimpleClassPart simple_class;
GripClassPart grip_class;
}


struct _MultiSinkClassPart
{
void * extension;
}


struct _RectObjClassRec
{
_RectObjClassPart rect_class;
}


struct _FormConstraintsPart
{
XawEdgeType top;
XawEdgeType bottom;
XawEdgeType left;
XawEdgeType right;
int dx;
int dy;
_WidgetRec * horiz_base;
_WidgetRec * vert_base;
char allow_resize;
short virtual_width;
short virtual_height;
short new_x;
short new_y;
LayoutState layout_state;
char deferred_resize;
short virtual_x;
short virtual_y;
void * [2] pad;
}


struct IcePoVersionRec
{
int major_version;
int minor_version;
void function(_IceConn *, void *, int, int, int, IceReplyWaitInfo *, int *) * process_msg_proc;
}


struct _DialogConstraintsRec
{
_FormConstraintsPart form;
DialogConstraintsPart dialog;
}


struct _VendorShellExtClassRec
{
_ObjectClassPart object_class;
XawVendorShellExtClassPart vendor_shell_ext_class;
}


struct IcePaVersionRec
{
int major_version;
int minor_version;
void function(_IceConn *, void *, int, int, int) * process_msg_proc;
}


struct _TextSrcClassPart
{
int function(_WidgetRec *, int, XawTextBlock *, int) * Read;
int function(_WidgetRec *, int, int, XawTextBlock *) * Replace;
int function(_WidgetRec *, int, XawTextScanType, XawTextScanDirection, int, int) * Scan;
int function(_WidgetRec *, int, XawTextScanDirection, XawTextBlock *) * Search;
void function(_WidgetRec *, int, int, int) * SetSelection;
char function(_WidgetRec *, int *, int *, int *, void * *, int *, int *) * ConvertSelection;
void * extension;
}


struct RepeaterClassPart
{
void * extension;
}


struct __fsid_t
{
int [2] __val;
}


struct XStandardColormap
{
int colormap;
int red_max;
int red_mult;
int green_max;
int green_mult;
int blue_max;
int blue_mult;
int base_pixel;
int visualid;
int killid;
}


struct _MultiSinkClassRec
{
_ObjectClassPart object_class;
_TextSinkClassPart text_sink_class;
_MultiSinkClassPart multi_sink_class;
}


struct _XawDL
{
}


struct SimpleMenuClassPart
{
void * extension;
}


struct _PannerRec
{
_CorePart core;
SimplePart simple;
PannerPart panner;
}


struct _XIMPreeditCaretCallbackStruct
{
int position;
XIMCaretDirection direction;
XIMCaretStyle style;
}


struct StripChartPart
{
int fgpixel;
int hipixel;
_XGC * fgGC;
_XGC * hiGC;
int update;
int scale;
int min_scale;
int interval;
XPoint * points;
double max_value;
double [2048] valuedata;
int interval_id;
_XtCallbackRec * get_value;
int jump_val;
void * [4] pad;
}


struct ConstraintClassExtensionRec
{
void * next_extension;
int record_type;
int version_;
uint record_size;
void function(_WidgetRec *, Arg *, uint *) * get_values_hook;
}


struct _TemplateClassRec
{
_CoreClassPart core_class;
TemplateClassPart template_class;
}


struct IceReplyWaitInfo
{
int sequence_of_request;
int major_opcode_of_request;
int minor_opcode_of_request;
void * reply;
}


struct XtGeometryHookDataRec
{
char * type;
_WidgetRec * widget;
XtWidgetGeometry * request;
XtWidgetGeometry * reply;
XtGeometryResult result;
}


struct GripPart
{
_XtCallbackRec * grip_action;
void * [4] pad;
}


struct _PanedConstraintsPart
{
ushort min;
ushort max;
char allow_resize;
char show_grip;
char skip_adjust;
int position;
ushort preferred_size;
char resize_to_pref;
short delta;
short olddelta;
char paned_adjusted_me;
ushort wp_size;
int size;
_WidgetRec * grip;
}


struct XCrossingEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int window;
int root;
int subwindow;
int time;
int x;
int y;
int x_root;
int y_root;
int mode;
int detail;
int same_screen;
int focus;
uint state;
}


struct _XawTextProperty
{
int identifier;
int code;
int mask;
XFontStruct * font;
_XOC * fontset;
int foreground;
int background;
int foreground_pixmap;
int background_pixmap;
int xlfd;
int xlfd_mask;
int foundry;
int family;
int weight;
int slant;
int setwidth;
int addstyle;
int pixel_size;
int point_size;
int res_x;
int res_y;
int spacing;
int avgwidth;
int registry;
int encoding;
short underline_position;
short underline_thickness;
}


struct _FormClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
_ConstraintClassPart constraint_class;
FormClassPart form_class;
}


struct _TextPart
{
_WidgetRec * source;
_WidgetRec * sink;
int insertPos;
XawTextSelection s;
XawTextSelectType * sarray;
_XawTextSelectionSalt * salt;
int left_margin;
int dialog_horiz_offset;
int dialog_vert_offset;
char display_caret;
char auto_fill;
XawTextScrollMode scroll_vert;
XawTextScrollMode scroll_horiz;
XawTextWrapMode wrap;
XawTextResizeMode resize;
_XawTextMargin r_margin;
_XtCallbackRec * position_callbacks;
_XawTextMargin margin;
XawTextLineTable lt;
XawTextScanDirection extendDir;
XawTextSelection origSel;
int lasttime;
int time;
short ev_x;
short ev_y;
_WidgetRec * vbar;
_WidgetRec * hbar;
SearchAndReplace * search;
_WidgetRec * file_insert;
_XmuScanline * update;
int line_number;
short column_number;
ubyte kill_ring;
char selection_state;
int from_left;
int lastPos;
_XGC * gc;
char showposition;
char hasfocus;
char update_disabled;
char clear_to_eol;
int old_insert;
short mult;
_XawTextKillRing * kill_ring_ptr;
char redisplay_needed;
_XawTextSelectionSalt * salt2;
char numeric;
char source_changed;
char overwrite;
short left_column;
short right_column;
XawTextJustifyMode justify;
void * [4] pad;
}


struct XCharStruct
{
short lbearing;
short rbearing;
short width;
short ascent;
short descent;
ushort attributes;
}


struct _PortholeClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
PortholeClassPart porthole_class;
}


struct WMShellRec
{
_CorePart core;
_CompositePart composite;
ShellPart shell;
WMShellPart wm;
}


struct _SmeBSBRec
{
_ObjectPart object;
_RectObjPart rectangle;
SmePart sme;
SmeBSBPart sme_bsb;
}


struct XExposeEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int window;
int x;
int y;
int width;
int height;
int count;
}


struct TreePart
{
ushort hpad;
ushort vpad;
ushort line_width;
int foreground;
int gravity;
char auto_reconfigure;
_XGC * gc;
_WidgetRec * tree_root;
ushort * largest;
int n_largest;
ushort maxwidth;
ushort maxheight;
_XawDL * display_list;
void * [4] pad;
}


struct _AsciiSinkRec
{
_ObjectPart object;
TextSinkPart text_sink;
AsciiSinkPart ascii_sink;
}


struct _CompositeRec
{
_CorePart core;
_CompositePart composite;
}


struct _VendorShellClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
ShellClassPart shell_class;
WMShellClassPart wm_shell_class;
VendorShellClassPart vendor_shell_class;
}


struct _GripRec
{
_CorePart core;
SimplePart simple;
GripPart grip;
}


struct XIMValuesList
{
ushort count_values;
char * * supported_values;
}


struct XRectangle
{
short x;
short y;
ushort width;
ushort height;
}


struct XWMHints
{
int flags;
int input;
int initial_state;
int icon_pixmap;
int icon_window;
int icon_x;
int icon_y;
int icon_mask;
int window_group;
}


struct _ViewportClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
_ConstraintClassPart constraint_class;
FormClassPart form_class;
ViewportClassPart viewport_class;
}


struct _ConstraintPart
{
void * mumble;
}


struct _XawTextPaintStruct
{
_XawTextPaintStruct * next;
int x;
int y;
int width;
char * text;
uint length;
_XawTextProperty * property;
int max_ascent;
int max_descent;
_XmuArea * backtabs;
char highlight;
}


struct _SimpleMenuClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
ShellClassPart shell_class;
OverrideShellClassPart override_shell_class;
SimpleMenuClassPart simpleMenu_class;
}


struct _IO_marker
{
_IO_marker * _next;
_IO_FILE * _sbuf;
int _pos;
}


struct MenuButtonPart
{
char * menu_name;
void * [4] pad;
}


struct XClassHint
{
char * res_name;
char * res_class;
}


struct StripChartClassPart
{
void * extension;
}


struct _TextSinkClassRec
{
_ObjectClassPart object_class;
_TextSinkClassPart text_sink_class;
}


struct _contextDataRec
{
_WidgetRec * parent;
_WidgetRec * ve;
}


struct TipClassPart
{
void * extension;
}


struct _XComposeStatus
{
char * compose_ptr;
int chars_matched;
}


struct _SmeLineClassPart
{
void * extension;
}


struct XWindowChanges
{
int x;
int y;
int width;
int height;
int border_width;
int sibling;
int stack_mode;
}


struct _ViewportRec
{
_CorePart core;
_CompositePart composite;
_ConstraintPart constraint;
_FormPart form;
_ViewportPart viewport;
}


struct XIMCallback
{
char * client_data;
void function(_XIM *, char *, char *) * callback;
}


struct ShellClassExtensionRec
{
void * next_extension;
int record_type;
int version_;
uint record_size;
XtGeometryResult function(_WidgetRec *, XtWidgetGeometry *, XtWidgetGeometry *) * root_geometry_manager;
}


struct _IO_jump_t
{
}


struct XIMStyles
{
ushort count_styles;
int * supported_styles;
}


struct OverrideShellPart
{
int frabjous;
}


struct __pthread_internal_list
{
__pthread_internal_list * __prev;
__pthread_internal_list * __next;
}


struct _RectObjPart
{
short x;
short y;
ushort width;
ushort height;
ushort border_width;
char managed;
char sensitive;
char ancestor_sensitive;
}


struct _LabelClassRec
{
_CoreClassPart core_class;
SimpleClassPart simple_class;
LabelClassPart label_class;
}


struct __locale_data
{
}


struct TogglePart
{
_WidgetRec * widget;
void * radio_data;
_RadioGroup * radio_group;
void * [4] pad;
}


struct _ObjectRec
{
_ObjectPart object;
}


struct _TextSinkClassPart
{
void function(_WidgetRec *, int, int, int, int, int) * DisplayText;
void function(_WidgetRec *, int, int, XawTextInsertState) * InsertCursor;
void function(_WidgetRec *, int, int, uint, uint) * ClearToBackground;
void function(_WidgetRec *, int, int, int, int, int *, int *, int *) * FindPosition;
void function(_WidgetRec *, int, int, int, int *, int *, int *) * FindDistance;
void function(_WidgetRec *, int, int, int, int *) * Resolve;
int function(_WidgetRec *, uint) * MaxLines;
int function(_WidgetRec *, int) * MaxHeight;
void function(_WidgetRec *, int, short *) * SetTabs;
void function(_WidgetRec *, XRectangle *) * GetCursorBounds;
TextSinkExtRec * extension;
}


struct SmsCallbacks
{
__HTD_gen_5 register_client;
__HTD_gen_6 interact_request;
__HTD_gen_7 interact_done;
__HTD_gen_8 save_yourself_request;
__HTD_gen_9 save_yourself_phase2_request;
__HTD_gen_10 save_yourself_done;
__HTD_gen_11 close_connection;
__HTD_gen_12 set_properties;
__HTD_gen_13 delete_properties;
__HTD_gen_14 get_properties;
}


struct _XawListReturnStruct
{
char * string;
int list_index;
}


struct timespec
{
int tv_sec;
int tv_nsec;
}


struct _ViewportConstraintsRec
{
_FormConstraintsPart form;
ViewportConstraintsPart viewport;
}


struct XWindowAttributes
{
int x;
int y;
int width;
int height;
int border_width;
int depth;
Visual * visual;
int root;
int _class;
int bit_gravity;
int win_gravity;
int backing_store;
int backing_planes;
int backing_pixel;
int save_under;
int colormap;
int map_installed;
int map_state;
int all_event_masks;
int your_event_mask;
int do_not_propagate_mask;
int override_redirect;
Screen * screen;
}


struct XPropertyEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int window;
int atom;
int time;
int state;
}


struct _ConstraintRec
{
_CorePart core;
_CompositePart composite;
_ConstraintPart constraint;
}


struct _SmeClassRec
{
_RectObjClassPart rect_class;
_SmeClassPart sme_class;
}


struct _XIMStringConversionText
{
ushort length;
int * feedback;
int encoding_is_wchar;
__HTD_gen_15 string;
}


struct __mbstate_t
{
int __count;
__HTD_gen_16 __value;
}


struct _XIMStatusDrawCallbackStruct
{
XIMStatusDataType type;
__HTD_gen_17 data;
}


struct _RepeaterRec
{
_CorePart core;
SimplePart simple;
LabelPart label;
CommandPart command;
RepeaterPart repeater;
}


struct XFocusChangeEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int window;
int mode;
int detail;
}


struct XErrorEvent
{
int type;
_XDisplay * display;
int resourceid;
int serial;
ubyte error_code;
ubyte request_code;
ubyte minor_code;
}


struct XawTextPropertyInfo
{
int left;
int right;
XawTextBlock * block;
}


struct _ToggleRec
{
_CorePart core;
SimplePart simple;
LabelPart label;
CommandPart command;
TogglePart toggle;
}


struct ScrollbarPart
{
int foreground;
XtOrientation orientation;
_XtCallbackRec * scrollProc;
_XtCallbackRec * thumbProc;
_XtCallbackRec * jumpProc;
int thumb;
int upCursor;
int downCursor;
int leftCursor;
int rightCursor;
int verCursor;
int horCursor;
float top;
float shown;
ushort length;
ushort thickness;
ushort min_thumb;
int inactiveCursor;
char direction;
_XGC * gc;
short topLoc;
ushort shownLength;
void * [4] pad;
}


struct _ConstraintClassPart
{
_XtResource * resources;
uint num_resources;
uint constraint_size;
void function(_WidgetRec *, _WidgetRec *, Arg *, uint *) * initialize;
void function(_WidgetRec *) * destroy;
char function(_WidgetRec *, _WidgetRec *, _WidgetRec *, Arg *, uint *) * set_values;
void * extension;
}


struct PortholePart
{
_XtCallbackRec * report_callbacks;
void * [4] pad;
}


struct XSelectionEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int requestor;
int selection;
int target;
int property;
int time;
}


struct _TextSinkRec
{
_ObjectPart object;
TextSinkPart text_sink;
}


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


struct TopLevelShellPart
{
char * icon_name;
char iconic;
int icon_name_encoding;
}


struct XrmOptionDescRec
{
char * option;
char * specifier;
XrmOptionKind argKind;
char * value;
}


struct TopLevelShellRec
{
_CorePart core;
_CompositePart composite;
ShellPart shell;
WMShellPart wm;
VendorShellPart vendor;
TopLevelShellPart topLevel;
}


struct ApplicationShellPart
{
char * _class;
int xrm_class;
int argc;
char * * argv;
}


struct _ListRec
{
_CorePart core;
SimplePart simple;
ListPart list;
}


struct _FormRec
{
_CorePart core;
_CompositePart composite;
_ConstraintPart constraint;
_FormPart form;
}


struct RepeaterPart
{
int initial_delay;
int repeat_delay;
int minimum_delay;
int decay;
char flash;
_XtCallbackRec * start_callbacks;
_XtCallbackRec * stop_callbacks;
int next_delay;
int timer;
void * [4] pad;
}


struct _XawIcTablePart
{
_WidgetRec * widget;
_XIC * xic;
int input_style;
int flg;
int prev_flg;
char ic_focused;
_XOC * font_set;
int foreground;
int background;
int bg_pixmap;
int cursor_position;
int line_spacing;
char openic_error;
_XawIcTablePart * next;
}


struct TopLevelShellClassPart
{
void * extension;
}


struct CommandPart
{
ushort highlight_thickness;
_XtCallbackRec * callbacks;
int gray_pixmap;
_XGC * normal_GC;
_XGC * inverse_GC;
char set;
XtCommandHighlight highlighted;
int shape_style;
ushort corner_round;
void * [4] pad;
}


struct VendorShellPart
{
int vendor_specific;
}


struct XFontStruct
{
_XExtData * ext_data;
int fid;
uint direction;
uint min_char_or_byte2;
uint max_char_or_byte2;
uint min_byte1;
uint max_byte1;
int all_chars_exist;
uint default_char;
int n_properties;
XFontProp * properties;
XCharStruct min_bounds;
XCharStruct max_bounds;
XCharStruct * per_char;
int ascent;
int descent;
}


struct _ObjectClassRec
{
_ObjectClassPart object_class;
}


struct PanedPart
{
short grip_indent;
char refiguremode;
_TranslationData * grip_translations;
int internal_bp;
ushort internal_bw;
XtOrientation orientation;
int cursor;
int grip_cursor;
int v_grip_cursor;
int h_grip_cursor;
int adjust_this_cursor;
int v_adjust_this_cursor;
int h_adjust_this_cursor;
int adjust_upper_cursor;
int adjust_lower_cursor;
int adjust_left_cursor;
int adjust_right_cursor;
char recursively_called;
char resize_children_to_pref;
int start_loc;
_WidgetRec * whichadd;
_WidgetRec * whichsub;
_XGC * normgc;
_XGC * invgc;
_XGC * flipgc;
int num_panes;
_PaneStack * stack;
void * [4] pad;
}


struct _ViewportPart
{
char forcebars;
char allowhoriz;
char allowvert;
char usebottom;
char useright;
_XtCallbackRec * report_callbacks;
_WidgetRec * clip;
_WidgetRec * child;
_WidgetRec * horiz_bar;
_WidgetRec * vert_bar;
void * [4] pad;
}


struct _XawTextKillRing
{
_XawTextKillRing * next;
char * contents;
int length;
uint refcount;
int format;
}


struct _PanedClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
_ConstraintClassPart constraint_class;
_PanedClassPart paned_class;
}


struct _XGC
{
}


struct AsciiSinkPart
{
XFontStruct * font;
char echo;
char display_nonprinting;
_XGC * normgc;
_XGC * invgc;
_XGC * xorgc;
int cursor_position;
XawTextInsertState laststate;
short cursor_x;
short cursor_y;
void * [4] pad;
}


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


struct _TextSrcRec
{
_ObjectPart object;
TextSrcPart textSrc;
}


struct _XIC
{
}


struct _XIM
{
}


struct _XIMHotKeyTrigger
{
int keysym;
int modifier;
int modifier_mask;
}


struct VendorShellClassPart
{
void * extension;
}


struct XtPopdownIDRec
{
_WidgetRec * shell_widget;
_WidgetRec * enable_widget;
}


struct _MenuButtonClassRec
{
_CoreClassPart core_class;
SimpleClassPart simple_class;
LabelClassPart label_class;
_CommandClass command_class;
_MenuButtonClass menuButton_class;
}


struct XModifierKeymap
{
int max_keypermod;
ubyte * modifiermap;
}


struct XSelectionClearEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int window;
int selection;
int time;
}


struct _XawTextSelectionSalt
{
_XawTextSelectionSalt * next;
XawTextSelection s;
char * contents;
int length;
}


struct XawTextLineTableEntry
{
int position;
short y;
uint textWidth;
}


struct _XOC
{
}


struct _ConstraintClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
_ConstraintClassPart constraint_class;
}


struct _SmeBSBClassRec
{
_RectObjClassPart rect_class;
_SmeClassPart sme_class;
_SmeBSBClassPart sme_bsb_class;
}


struct XrmValue
{
uint size;
char * addr;
}


struct _CompositeClassPart
{
XtGeometryResult function(_WidgetRec *, XtWidgetGeometry *, XtWidgetGeometry *) * geometry_manager;
void function(_WidgetRec *) * change_managed;
void function(_WidgetRec *) * insert_child;
void function(_WidgetRec *) * delete_child;
void * extension;
}


struct XtChangeHookSetValuesDataRec
{
_WidgetRec * old;
_WidgetRec * req;
Arg * args;
uint num_args;
}


struct SessionShellPart
{
_SmcConn * connection;
char * session_id;
char * * restart_command;
char * * clone_command;
char * * discard_command;
char * * resign_command;
char * * shutdown_command;
char * * environment;
char * current_dir;
char * program_path;
ubyte restart_style;
ubyte checkpoint_state;
char join_session;
_XtCallbackRec * save_callbacks;
_XtCallbackRec * interact_callbacks;
_XtCallbackRec * cancel_callbacks;
_XtCallbackRec * save_complete_callbacks;
_XtCallbackRec * die_callbacks;
_XtCallbackRec * error_callbacks;
_XtSaveYourselfRec * save;
int input_id;
void * ses20;
void * ses19;
void * ses18;
void * ses17;
void * ses16;
void * ses15;
void * ses14;
void * ses13;
void * ses12;
void * ses11;
void * ses10;
void * ses9;
void * ses8;
void * ses7;
void * ses6;
void * ses5;
void * ses4;
void * ses3;
void * ses2;
void * ses1;
}


struct XSelectionRequestEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int owner;
int requestor;
int selection;
int target;
int property;
int time;
}


struct _IceListenObj
{
}


struct XawPannerReport
{
uint changed;
short slider_x;
short slider_y;
ushort slider_width;
ushort slider_height;
ushort canvas_width;
ushort canvas_height;
}


struct _PortholeRec
{
_CorePart core;
_CompositePart composite;
PortholePart porthole;
}


struct DialogClassPart
{
void * extension;
}


struct XKeymapEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int window;
char [32] key_vector;
}


struct _SimpleRec
{
_CorePart core;
SimplePart simple;
}


struct SmcCallbacks
{
__HTD_gen_18 save_yourself;
__HTD_gen_19 die;
__HTD_gen_20 save_complete;
__HTD_gen_21 shutdown_cancelled;
}


struct _MenuButtonClass
{
void * extension;
}


struct SmProp
{
char * name;
char * type;
int num_vals;
SmPropValue * vals;
}


struct _XmuScanline
{
int y;
_XmuSegment * segment;
_XmuScanline * next;
}


struct _XtSaveYourselfRec
{
}


struct XrmResource
{
int xrm_name;
int xrm_class;
int xrm_type;
uint xrm_size;
int xrm_offset;
int xrm_default_type;
void * xrm_default_addr;
}


struct SmePart
{
_XtCallbackRec * callbacks;
char international;
void * [4] pad;
}


struct _AsciiSrcClassRec
{
_ObjectClassPart object_class;
_TextSrcClassPart text_src_class;
_AsciiSrcClassPart ascii_src_class;
}


struct XKeyboardState
{
int key_click_percent;
int bell_percent;
uint bell_pitch;
uint bell_duration;
int led_mask;
int global_auto_repeat;
char [32] auto_repeats;
}


struct _TextRec
{
_CorePart core;
SimplePart simple;
_TextPart text;
}


struct _XImage
{
int width;
int height;
int xoffset;
int format;
char * data;
int byte_order;
int bitmap_unit;
int bitmap_bit_order;
int bitmap_pad;
int depth;
int bytes_per_line;
int bits_per_pixel;
int red_mask;
int green_mask;
int blue_mask;
char * obdata;
funcs f;
}


struct _CompositePart
{
_WidgetRec * * children;
uint num_children;
uint num_slots;
uint function(_WidgetRec *) * insert_position;
}


struct XServerInterpretedAddress
{
int typelength;
int valuelength;
char * type;
char * value;
}


struct _AsciiSinkClassRec
{
_ObjectClassPart object_class;
_TextSinkClassPart text_sink_class;
_AsciiSinkClassPart ascii_sink_class;
}


struct TextSrcPart
{
XawTextEditType edit_mode;
int text_format;
_XtCallbackRec * callback;
char changed;
char enable_undo;
char undo_state;
_XawTextUndo * undo;
_WidgetRec * * text;
uint num_text;
_XtCallbackRec * property_callback;
_XawTextAnchor * * anchors;
int num_anchors;
void * [1] pad;
}


struct Arg
{
char * name;
int value;
}


struct SubstitutionRec
{
char match;
char * substitution;
}


struct XtConfigureHookDataRec
{
char * type;
_WidgetRec * widget;
uint changeMask;
XWindowChanges changes;
}


struct XResizeRequestEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int window;
int width;
int height;
}


struct _XmuWidgetNode
{
char * label;
_WidgetClassRec * * widget_class_ptr;
_XmuWidgetNode * superclass;
_XmuWidgetNode * children;
_XmuWidgetNode * siblings;
char * lowered_label;
char * lowered_classname;
int have_resources;
_XtResource * resources;
_XmuWidgetNode * * resourcewn;
uint nresources;
_XtResource * constraints;
_XmuWidgetNode * * constraintwn;
uint nconstraints;
void * data;
}


struct _BoxRec
{
_CorePart core;
_CompositePart composite;
BoxPart box;
}


struct ShellPart
{
char * geometry;
void function(_WidgetRec *) * create_popup_child_proc;
XtGrabKind grab_kind;
char spring_loaded;
char popped_up;
char allow_shell_resize;
char client_specified;
char save_under;
char override_redirect;
_XtCallbackRec * popup_callback;
_XtCallbackRec * popdown_callback;
Visual * visual;
}


struct XawTextPositionInfo
{
int line_number;
int column_number;
int insert_position;
int last_position;
char overwrite_mode;
}


struct _TreeClassPart
{
void * extension;
}


struct WMShellClassPart
{
void * extension;
}


struct VendorShellRec
{
_CorePart core;
_CompositePart composite;
ShellPart shell;
WMShellPart wm;
VendorShellPart vendor;
}


struct _MenuButtonRec
{
_CorePart core;
SimplePart simple;
LabelPart label;
CommandPart command;
MenuButtonPart menu_button;
}


struct TransientShellClassPart
{
void * extension;
}


struct TransientShellPart
{
_WidgetRec * transient_for;
}


struct ApplicationShellRec
{
_CorePart core;
_CompositePart composite;
ShellPart shell;
WMShellPart wm;
VendorShellPart vendor;
TopLevelShellPart topLevel;
ApplicationShellPart application;
}


struct GripClassPart
{
void * extension;
}


struct AsciiPart
{
int resource;
void * [4] pad;
}


struct XawTextBlock
{
int firstPos;
int length;
char * ptr;
int format;
}


struct _AsciiSrcRec
{
_ObjectPart object;
TextSrcPart text_src;
_AsciiSrcPart ascii_src;
}


struct XOMOrientation
{
int num_orientation;
XOrientation * orientation;
}


struct Visual
{
_XExtData * ext_data;
int visualid;
int _class;
int red_mask;
int green_mask;
int blue_mask;
int bits_per_rgb;
int map_entries;
}


struct XSegment
{
short x1;
short y1;
short x2;
short y2;
}


struct SmeBSBPart
{
char * label;
int vert_space;
int left_bitmap;
int right_bitmap;
ushort left_margin;
ushort right_margin;
int foreground;
XFontStruct * font;
_XOC * fontset;
XtJustify justify;
char set_values_area_cleared;
_XGC * norm_gc;
_XGC * rev_gc;
_XGC * norm_gray_gc;
_XGC * invert_gc;
ushort left_bitmap_width;
ushort left_bitmap_height;
ushort right_bitmap_width;
ushort right_bitmap_height;
char * menu_name;
void * [4] pad;
}


struct ScrollbarClassPart
{
void * extension;
}


struct _DialogClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
_ConstraintClassPart constraint_class;
FormClassPart form_class;
DialogClassPart dialog_class;
}


struct XawVendorShellExtClassPart
{
void * extension;
}


struct Depth
{
int depth;
int nvisuals;
Visual * visuals;
}


struct SearchAndReplace
{
char selection_changed;
_WidgetRec * search_popup;
_WidgetRec * label1;
_WidgetRec * label2;
_WidgetRec * left_toggle;
_WidgetRec * right_toggle;
_WidgetRec * rep_label;
_WidgetRec * rep_text;
_WidgetRec * search_text;
_WidgetRec * rep_one;
_WidgetRec * rep_all;
_WidgetRec * case_sensitive;
}


struct XFontSetExtents
{
XRectangle max_ink_extent;
XRectangle max_logical_extent;
}


struct XMapEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int event;
int window;
int override_redirect;
}


struct _TransientShellClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
ShellClassPart shell_class;
WMShellClassPart wm_shell_class;
VendorShellClassPart vendor_shell_class;
TransientShellClassPart transient_shell_class;
}


struct DialogConstraintsPart
{
void * extension;
}


struct _G_fpos64_t
{
int __pos;
__mbstate_t __state;
}


struct XCreateWindowEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int parent;
int window;
int x;
int y;
int width;
int height;
int border_width;
int override_redirect;
}


struct TextSinkPart
{
int foreground;
int background;
short * tabs;
short * char_tabs;
int tab_count;
int cursor_color;
_XawTextPropertyList * properties;
XawTextPaintList * paint;
void * [2] pad;
}


struct XColormapEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int window;
int colormap;
int _new;
int state;
}


struct XTextItem
{
char * chars;
int nchars;
int delta;
int font;
}


struct _ShellClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
ShellClassPart shell_class;
}


struct _MultiPiece
{
dchar * text;
int used;
_MultiPiece * prev;
_MultiPiece * next;
}


struct _XtAppStruct
{
}


struct _XtEventRec
{
}


struct _MultiSrcClassRec
{
_ObjectClassPart object_class;
_TextSrcClassPart text_src_class;
_MultiSrcClassPart multi_src_class;
}


struct XHostAddress
{
int family;
int length;
char * address;
}


struct _TreeConstraintsRec
{
_TreeConstraintsPart tree;
}


struct XVisibilityEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int window;
int state;
}


struct XConfigureEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int event;
int window;
int x;
int y;
int width;
int height;
int border_width;
int above;
int override_redirect;
}


struct XColor
{
int pixel;
ushort red;
ushort green;
ushort blue;
char flags;
char pad;
}


struct _TreeClassRec
{
_CoreClassPart core_class;
_CompositeClassPart composite_class;
_ConstraintClassPart constraint_class;
_TreeClassPart tree_class;
}


struct _XmuSegment
{
int x1;
int x2;
_XmuSegment * next;
}


struct _CommandClass
{
void * extension;
}


struct XArc
{
short x;
short y;
ushort width;
ushort height;
short angle1;
short angle2;
}


struct SimplePart
{
int cursor;
int insensitive_border;
char * cursor_name;
int pointer_fg;
int pointer_bg;
char international;
_XawDL * display_list;
char * tip;
void * [3] pad;
}


struct _MultiSrcRec
{
_ObjectPart object;
TextSrcPart text_src;
_MultiSrcPart multi_src;
}


struct XKeyboardControl
{
int key_click_percent;
int bell_percent;
int bell_pitch;
int bell_duration;
int led;
int led_mode;
int key;
int auto_repeat_mode;
}


struct XTimeCoord
{
int time;
short x;
short y;
}


struct 
{
_XExtData * ext_data;
_XPrivate * private1;
int fd;
int private2;
int proto_major_version;
int proto_minor_version;
char * vendor;
int private3;
int private4;
int private5;
int private6;
int function(_XDisplay *) * resource_alloc;
int byte_order;
int bitmap_unit;
int bitmap_pad;
int bitmap_bit_order;
int nformats;
ScreenFormat * pixmap_format;
int private8;
int release;
_XPrivate * private9;
_XPrivate * private10;
int qlen;
int last_request_read;
int request;
char * private11;
char * private12;
char * private13;
char * private14;
uint max_request_size;
_XrmHashBucketRec * db;
int function(_XDisplay *) * private15;
char * display_name;
int default_screen;
int nscreens;
Screen * screens;
int motion_buffer;
int private16;
int min_keycode;
int max_keycode;
char * private17;
char * private18;
int private19;
char * xdefaults;
}


struct _PannerClassRec
{
_CoreClassPart core_class;
SimpleClassPart simple_class;
PannerClassPart panner_class;
}


struct _FormPart
{
int default_spacing;
ushort old_width;
ushort old_height;
int no_refigure;
char needs_relayout;
char resize_in_layout;
ushort preferred_width;
ushort preferred_height;
char resize_is_no_op;
_XawDL * display_list;
void * [4] pad;
}


struct XGravityEvent
{
int type;
int serial;
int send_event;
_XDisplay * display;
int event;
int window;
int x;
int y;
}


struct LabelClassPart
{
void * extension;
}


struct XGenericEventCookie
{
int type;
int serial;
int send_event;
_XDisplay * display;
int extension;
int evtype;
uint cookie;
void * data;
}


struct XOMCharSetList
{
int charset_count;
char * * charset_list;
}


struct XICCallback
{
char * client_data;
int function(_XIC *, char *, char *) * callback;
}


struct _IO_FILE_plus
{
}


struct _AsciiSrcPart
{
char * string;
XawAsciiType type;
int piece_size;
char data_compression;
char use_string_in_place;
int ascii_length;
char is_tempfile;
char allocated_string;
int length;
_Piece * first_piece;
void * [4] pad;
}


struct TemplateClassPart
{
void * extension;
}


struct LabelPart
{
int foreground;
XFontStruct * font;
_XOC * fontset;
char * label;
XtJustify justify;
ushort internal_width;
ushort internal_height;
int pixmap;
char resize;
ubyte encoding;
int left_bitmap;
_XGC * normal_GC;
_XGC * gray_GC;
int stipple;
short label_x;
short label_y;
ushort label_width;
ushort label_height;
ushort label_len;
int lbm_y;
uint lbm_width;
uint lbm_height;
void * [4] pad;
}


struct ViewportClassPart
{
void * extension;
}


struct 
{
int __lock;
uint __nr_readers;
uint __readers_wakeup;
uint __writer_wakeup;
uint __nr_readers_queued;
uint __nr_writers_queued;
int __writer;
int __shared;
int __pad1;
int __pad2;
uint __flags;
}


struct _OldXSizeHints
{
int flags;
int x;
int y;
int width;
int height;
int min_width;
int min_height;
int max_width;
int max_height;
int width_inc;
int height_inc;
__HTD_gen_26 min_aspect;
__HTD_gen_26 max_aspect;
}


struct __HTD_gen_3
{
char doing;
char showing;
short startx;
short starty;
short dx;
short dy;
short x;
short y;
}


struct __HTD_gen_4
{
int x;
int y;
}


struct 
{
int __lock;
uint __futex;
ulong __total_seq;
ulong __wakeup_seq;
ulong __woken_seq;
void * __mutex;
uint __nwaiters;
uint __broadcast_seq;
}


struct __HTD_gen_5
{
int function(_SmsConn *, void *, char *) * callback;
void * manager_data;
}


struct __HTD_gen_6
{
void function(_SmsConn *, void *, int) * callback;
void * manager_data;
}


struct __HTD_gen_7
{
void function(_SmsConn *, void *, int) * callback;
void * manager_data;
}


struct __HTD_gen_8
{
void function(_SmsConn *, void *, int, int, int, int, int) * callback;
void * manager_data;
}


struct __HTD_gen_9
{
void function(_SmsConn *, void *) * callback;
void * manager_data;
}


struct __HTD_gen_10
{
void function(_SmsConn *, void *, int) * callback;
void * manager_data;
}


struct __HTD_gen_11
{
void function(_SmsConn *, void *, int, char * *) * callback;
void * manager_data;
}


struct __HTD_gen_12
{
void function(_SmsConn *, void *, int, SmProp * *) * callback;
void * manager_data;
}


struct __HTD_gen_13
{
void function(_SmsConn *, void *, int, char * *) * callback;
void * manager_data;
}


struct __HTD_gen_14
{
void function(_SmsConn *, void *) * callback;
void * manager_data;
}


struct __HTD_gen_18
{
void function(_SmcConn *, void *, int, int, int, int) * callback;
void * client_data;
}


struct __HTD_gen_19
{
void function(_SmcConn *, void *) * callback;
void * client_data;
}


struct __HTD_gen_20
{
void function(_SmcConn *, void *) * callback;
void * client_data;
}


struct __HTD_gen_21
{
void function(_SmcConn *, void *) * callback;
void * client_data;
}


struct funcs
{
_XImage * function(_XDisplay *, Visual *, uint, int, int, char *, uint, uint, int, int) * create_image;
int function(_XImage *) * destroy_image;
int function(_XImage *, int, int) * get_pixel;
int function(_XImage *, int, int, int) * put_pixel;
_XImage * function(_XImage *, int, int, uint, uint) * sub_image;
int function(_XImage *, int) * add_pixel;
}


struct __pthread_mutex_s
{
int __lock;
uint __count;
int __owner;
uint __nusers;
int __kind;
int __spins;
__pthread_internal_list __list;
}


struct __HTD_gen_26
{
int x;
int y;
}


union pthread_condattr_t
{
char [4] __size;
int __align;
}


union pthread_rwlock_t
{
__HTD_gen_63 __data;
char [56] __size;
int __align;
}


union XEDataObject
{
_XDisplay * display;
_XGC * gc;
Visual * visual;
Screen * screen;
ScreenFormat * pixmap_format;
XFontStruct * font;
}


union pthread_mutexattr_t
{
char [4] __size;
int __align;
}


union pthread_cond_t
{
__HTD_gen_64 __data;
char [48] __size;
long __align;
}


union pthread_barrier_t
{
char [32] __size;
int __align;
}


union _XEvent
{
int type;
XAnyEvent xany;
XKeyEvent xkey;
XButtonEvent xbutton;
XMotionEvent xmotion;
XCrossingEvent xcrossing;
XFocusChangeEvent xfocus;
XExposeEvent xexpose;
XGraphicsExposeEvent xgraphicsexpose;
XNoExposeEvent xnoexpose;
XVisibilityEvent xvisibility;
XCreateWindowEvent xcreatewindow;
XDestroyWindowEvent xdestroywindow;
XUnmapEvent xunmap;
XMapEvent xmap;
XMapRequestEvent xmaprequest;
XReparentEvent xreparent;
XConfigureEvent xconfigure;
XGravityEvent xgravity;
XResizeRequestEvent xresizerequest;
XConfigureRequestEvent xconfigurerequest;
XCirculateEvent xcirculate;
XCirculateRequestEvent xcirculaterequest;
XPropertyEvent xproperty;
XSelectionClearEvent xselectionclear;
XSelectionRequestEvent xselectionrequest;
XSelectionEvent xselection;
XColormapEvent xcolormap;
XClientMessageEvent xclient;
XMappingEvent xmapping;
XErrorEvent xerror;
XKeymapEvent xkeymap;
XGenericEvent xgeneric;
XGenericEventCookie xcookie;
int [24] pad;
}


union pthread_barrierattr_t
{
char [4] __size;
int __align;
}


union pthread_rwlockattr_t
{
char [8] __size;
int __align;
}


union pthread_attr_t
{
char [56] __size;
int __align;
}


union pthread_mutex_t
{
__pthread_mutex_s __data;
char [40] __size;
int __align;
}


union __HTD_gen_1
{
char [20] b;
short [10] s;
int [5] l;
}


union __HTD_gen_2
{
char * multi_byte;
dchar * wide_char;
}


union __HTD_gen_15
{
char * mbs;
dchar * wcs;
}


union __HTD_gen_16
{
uint __wch;
char [4] __wchb;
}


union __HTD_gen_17
{
_XIMText * text;
int bitmap;
}


alias _ApplicationShellClassRec ApplicationShellClassRec;
alias _ApplicationShellClassRec * ApplicationShellWidgetClass;
alias ApplicationShellRec * ApplicationShellWidget;
alias Arg * ArgList;
alias _AsciiRec AsciiRec;
alias _AsciiRec * AsciiWidget;
alias _AsciiSinkClassPart AsciiSinkClassPart;
alias _AsciiSinkClassRec AsciiSinkClassRec;
alias _AsciiSinkClassRec * AsciiSinkObjectClass;
alias _AsciiSinkRec * AsciiSinkObject;
alias _AsciiSinkRec AsciiSinkRec;
alias _AsciiSrcClassPart AsciiSrcClassPart;
alias _AsciiSrcClassRec AsciiSrcClassRec;
alias _AsciiSrcClassRec * AsciiSrcObjectClass;
alias _AsciiSrcPart AsciiSrcPart;
alias _AsciiSrcRec * AsciiSrcObject;
alias _AsciiSrcRec AsciiSrcRec;
alias _AsciiTextClassRec AsciiTextClassRec;
alias _AsciiTextClassRec * AsciiTextWidgetClass;
alias _AtomRec * AtomPtr;
alias _BoxClassRec BoxClassRec;
alias _BoxClassRec * BoxWidgetClass;
alias _BoxRec BoxRec;
alias _BoxRec * BoxWidget;
alias char Boolean;
alias char function(char *) * XtFilePredicate;
alias char function(_WidgetRec *, Arg *, uint *) * XtArgsFunc;
alias char function(_WidgetRec *, int *, int *, int *, void * *, int *, int *, int *, void *, void * *) * XtConvertSelectionIncrProc;
alias char function(_WidgetRec *, int *, int *, int *, void * *, int *, int *) * _XawSrcConvertSelectionProc;
alias char function(_WidgetRec *, int *, int *, int *, void * *, int *, int *) * XtConvertSelectionProc;
alias char function(_WidgetRec *, int *) * XtAcceptFocusProc;
alias char function(_WidgetRec *, _WidgetRec *, _WidgetRec *, Arg *, uint *) * XtSetValuesFunc;
alias char function(void *) * XtWorkProc;
alias char * function(_XDisplay *, char *, void *) * XtLanguageProc;
alias char function(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *) * XtTypeConverter;
alias char function(_XEvent *) * XtEventDispatchProc;
alias char * String;
alias char * XPointer;
alias char * XrmString;
alias _CommandClass CommandClassPart;
alias _CommandClassRec CommandClassRec;
alias _CommandClassRec * CommandWidgetClass;
alias _CommandRec CommandRec;
alias _CommandRec * CommandWidget;
alias CompositeClassExtensionRec * CompositeClassExtension;
alias _CompositeClassPart CompositeClassPart;
alias _CompositeClassPart * CompositePartPtr;
alias _CompositeClassRec CompositeClassRec;
alias _CompositeClassRec * CompositeWidgetClass;
alias _CompositePart CompositePart;
alias _CompositePart * CompositePtr;
alias _CompositeRec CompositeRec;
alias _CompositeRec * CompositeWidget;
alias ConstraintClassExtensionRec * ConstraintClassExtension;
alias _ConstraintClassPart ConstraintClassPart;
alias _ConstraintClassRec ConstraintClassRec;
alias _ConstraintClassRec * ConstraintWidgetClass;
alias _ConstraintPart ConstraintPart;
alias _ConstraintRec ConstraintRec;
alias _ConstraintRec * ConstraintWidget;
alias _contextDataRec contextDataRec;
alias _contextErrDataRec contextErrDataRec;
alias _CoreClassPart CoreClassPart;
alias _CorePart CorePart;
alias _DialogClassRec DialogClassRec;
alias _DialogClassRec * DialogWidgetClass;
alias _DialogConstraintsRec * DialogConstraints;
alias _DialogConstraintsRec DialogConstraintsRec;
alias _DialogPart DialogPart;
alias _DialogRec DialogRec;
alias _DialogRec * DialogWidget;
alias _FormClassRec FormClassRec;
alias _FormClassRec * FormWidgetClass;
alias _FormConstraintsPart FormConstraintsPart;
alias _FormConstraintsRec * FormConstraints;
alias _FormConstraintsRec FormConstraintsRec;
alias _FormPart FormPart;
alias _FormRec FormRec;
alias _FormRec * FormWidget;
alias _GripClassRec GripClassRec;
alias _GripClassRec * GripWidgetClass;
alias _GripRec GripRec;
alias _GripRec * GripWidget;
alias _IceConn * IceConn;
alias _IceListenObj * IceListenObj;
alias IcePaAuthStatus function(_IceConn *, void * *, int, int, void *, int *, void * *, char * *) * IcePaAuthProc;
alias IcePoAuthStatus function(_IceConn *, void * *, int, int, int, void *, int *, void * *, char * *) * IcePoAuthProc;
alias int Atom;
alias int Colormap;
alias int Cursor;
alias int Drawable;
alias int EventMask;
alias int Font;
alias int function(char *) * IceHostBasedAuthProc;
alias int function(_IceConn *, int, int, char *, char *, void * *, char * *) * IceProtocolSetupProc;
alias int function(_SmsConn *, void *, char *) * SmsRegisterClientProc;
alias int function(_SmsConn *, void *, int *, SmsCallbacks *, char * *) * SmsNewClientProc;
alias int function(_WidgetRec *, int, int, XawTextBlock *) * _XawSrcReplaceProc;
alias int function(_WidgetRec *, int) * _XawSinkMaxHeightProc;
alias int function(_WidgetRec *, int, XawTextBlock *, int) * _XawSrcReadProc;
alias int function(_WidgetRec *, int, XawTextScanDirection, XawTextBlock *) * _XawSrcSearchProc;
alias int function(_WidgetRec *, int, XawTextScanType, XawTextScanDirection, int, int) * _XawSrcScanProc;
alias int function(_WidgetRec *, uint) * _XawSinkMaxLinesProc;
alias int function(void *, char *, int) __io_read_fn;
alias int function(void *, char *, int) __io_write_fn;
alias int function(void *, int *, int) __io_seek_fn;
alias int function(void *) __io_close_fn;
alias int function(_XDisplay *, XErrorEvent *) * XErrorHandler;
alias int function(_XDisplay *) * XIOErrorHandler;
alias int function(_XIC *, char *, char *) * XICProc;
alias int GContext;
alias int KeySym;
alias int Mask;
alias int Pixel;
alias int Pixmap;
alias int Time;
alias int Window;
alias int VisualID;
alias int XawTextPosition;
alias int XContext;
alias int XID;
alias int XIMFeedback;
alias int XIMHotKeyState;
alias int XIMPreeditState;
alias int XIMResetState;
alias int XIMStringConversionFeedback;
alias int XIMStyle;
alias int XrmClass;
alias int * XrmClassList;
alias int XrmName;
alias int * XrmNameList;
alias int XrmQuark;
alias int * XrmQuarkList;
alias int XrmRepresentation;
alias int XtArgVal;
alias int XtBlockHookId;
alias int XtCacheType;
alias int XtGCMask;
alias int XtGravity;
alias int XtInputId;
alias int XtInputMask;
alias int XtIntervalId;
alias int XtSignalId;
alias int XtValueMask;
alias int XtVersionType;
alias int XtWorkProcId;
alias _LabelClassRec LabelClassRec;
alias _LabelClassRec * LabelWidgetClass;
alias _LabelRec LabelRec;
alias _LabelRec * LabelWidget;
alias _ListClassRec ListClassRec;
alias _ListClassRec * ListWidgetClass;
alias _ListRec ListRec;
alias _ListRec * ListWidget;
alias _MenuButtonClass MenuButtonClassPart;
alias _MenuButtonClassRec MenuButtonClassRec;
alias _MenuButtonClassRec * MenuButtonWidgetClass;
alias _MenuButtonRec MenuButtonRec;
alias _MenuButtonRec * MenuButtonWidget;
alias _MultiPiece MultiPiece;
alias _MultiSinkClassPart MultiSinkClassPart;
alias _MultiSinkClassRec MultiSinkClassRec;
alias _MultiSinkClassRec * MultiSinkObjectClass;
alias _MultiSinkRec * MultiSinkObject;
alias _MultiSinkRec MultiSinkRec;
alias _MultiSrcClassPart MultiSrcClassPart;
alias _MultiSrcClassRec MultiSrcClassRec;
alias _MultiSrcClassRec * MultiSrcObjectClass;
alias _MultiSrcPart MultiSrcPart;
alias _MultiSrcRec * MultiSrcObject;
alias _MultiSrcRec MultiSrcRec;
alias ObjectClassExtensionRec * ObjectClassExtension;
alias _ObjectClassPart ObjectClassPart;
alias _ObjectClassRec * ObjectClass;
alias _ObjectClassRec ObjectClassRec;
alias _ObjectPart ObjectPart;
alias _ObjectRec * Object;
alias _ObjectRec ObjectRec;
alias _OverrideShellClassRec OverrideShellClassRec;
alias _OverrideShellClassRec * OverrideShellWidgetClass;
alias OverrideShellRec * OverrideShellWidget;
alias _PanedClassPart PanedClassPart;
alias _PanedClassRec PanedClassRec;
alias _PanedClassRec * PanedWidgetClass;
alias _PanedConstraintsPart * Pane;
alias _PanedConstraintsPart PanedConstraintsPart;
alias _PanedConstraintsRec * PanedConstraints;
alias _PanedConstraintsRec PanedConstraintsRec;
alias _PanedRec PanedRec;
alias _PanedRec * PanedWidget;
alias _PaneStack PaneStack;
alias _PannerClassRec PannerClassRec;
alias _PannerClassRec * PannerWidgetClass;
alias _PannerRec PannerRec;
alias _PannerRec * PannerWidget;
alias _Piece Piece;
alias _PortholeClassRec PortholeClassRec;
alias _PortholeClassRec * PortholeWidgetClass;
alias _PortholeRec PortholeRec;
alias _PortholeRec * PortholeWidget;
alias _RadioGroup RadioGroup;
alias _RectObjClassPart RectObjClassPart;
alias _RectObjClassRec * RectObjClass;
alias _RectObjClassRec RectObjClassRec;
alias _RectObjPart RectObjPart;
alias _RectObjRec * RectObj;
alias _RectObjRec RectObjRec;
alias _RepeaterClassRec RepeaterClassRec;
alias _RepeaterClassRec * RepeaterWidgetClass;
alias _RepeaterRec RepeaterRec;
alias _RepeaterRec * RepeaterWidget;
alias _ScrollbarClassRec ScrollbarClassRec;
alias _ScrollbarClassRec * ScrollbarWidgetClass;
alias _ScrollbarRec ScrollbarRec;
alias _ScrollbarRec * ScrollbarWidget;
alias _SessionShellClassRec SessionShellClassRec;
alias _SessionShellClassRec * SessionShellWidgetClass;
alias SessionShellRec * SessionShellWidget;
alias ShellClassExtensionRec * ShellClassExtension;
alias _ShellClassRec ShellClassRec;
alias _ShellClassRec * ShellWidgetClass;
alias ShellRec * ShellWidget;
alias short Position;
alias _SimpleClassRec SimpleClassRec;
alias _SimpleClassRec * SimpleWidgetClass;
alias _SimpleMenuClassRec SimpleMenuClassRec;
alias _SimpleMenuClassRec * SimpleMenuWidgetClass;
alias _SimpleMenuPart SimpleMenuPart;
alias _SimpleMenuRec SimpleMenuRec;
alias _SimpleMenuRec * SimpleMenuWidget;
alias _SimpleRec SimpleRec;
alias _SimpleRec * SimpleWidget;
alias _SmcConn * SmcConn;
alias _SmeBSBClassPart SmeBSBClassPart;
alias _SmeBSBClassRec SmeBSBClassRec;
alias _SmeBSBClassRec * SmeBSBObjectClass;
alias _SmeBSBRec * SmeBSBObject;
alias _SmeBSBRec SmeBSBRec;
alias _SmeClassPart SmeClassPart;
alias _SmeClassRec SmeClassRec;
alias _SmeClassRec * SmeObjectClass;
alias _SmeLineClassPart SmeLineClassPart;
alias _SmeLineClassRec SmeLineClassRec;
alias _SmeLineClassRec * SmeLineObjectClass;
alias _SmeLineRec * SmeLineObject;
alias _SmeLineRec SmeLineRec;
alias _SmeRec * SmeObject;
alias _SmeRec SmeRec;
alias _SmsConn * SmsConn;
alias _StripChartClassRec StripChartClassRec;
alias _StripChartClassRec * StripChartWidgetClass;
alias _StripChartRec StripChartRec;
alias _StripChartRec * StripChartWidget;
alias SubstitutionRec * Substitution;
alias _TemplateClassRec TemplateClassRec;
alias _TemplateClassRec * TemplateWidgetClass;
alias _TemplateRec TemplateRec;
alias _TemplateRec * TemplateWidget;
alias _TextClassRec TextClassRec;
alias _TextClassRec * TextWidgetClass;
alias _TextPart TextPart;
alias _TextRec TextRec;
alias _TextRec * TextWidget;
alias _TextSinkClassPart TextSinkClassPart;
alias _TextSinkClassRec TextSinkClassRec;
alias _TextSinkClassRec * TextSinkObjectClass;
alias TextSinkExtRec * TextSinkExt;
alias _TextSinkRec * TextSinkObject;
alias _TextSinkRec TextSinkRec;
alias _TextSrcClassPart TextSrcClassPart;
alias _TextSrcClassRec TextSrcClassRec;
alias _TextSrcClassRec * TextSrcObjectClass;
alias _TextSrcRec * TextSrcObject;
alias _TextSrcRec TextSrcRec;
alias _TipClassRec TipClassRec;
alias _TipClassRec * TipWidgetClass;
alias _TipPart TipPart;
alias _TipRec TipRec;
alias _TipRec * TipWidget;
alias _ToggleClassRec ToggleClassRec;
alias _ToggleClassRec * ToggleWidgetClass;
alias _ToggleClass ToggleClassPart;
alias _ToggleRec ToggleRec;
alias _ToggleRec * ToggleWidget;
alias _TopLevelShellClassRec TopLevelShellClassRec;
alias _TopLevelShellClassRec * TopLevelShellWidgetClass;
alias TopLevelShellRec * TopLevelShellWidget;
alias _TransientShellClassRec TransientShellClassRec;
alias _TransientShellClassRec * TransientShellWidgetClass;
alias TransientShellRec * TransientShellWidget;
alias _TranslationData * XtAccelerators;
alias _TranslationData * XtTranslations;
alias _TreeClassPart TreeClassPart;
alias _TreeClassRec TreeClassRec;
alias _TreeClassRec * TreeWidgetClass;
alias _TreeConstraintsPart TreeConstraintsPart;
alias _TreeConstraintsRec * TreeConstraints;
alias _TreeConstraintsRec TreeConstraintsRec;
alias _TreeRec TreeRec;
alias _TreeRec * TreeWidget;
alias ubyte KeyCode;
alias ubyte XtEnum;
alias uint Cardinal;
alias uint function(_WidgetRec *) * XtOrderProc;
alias uint Modifiers;
alias uint XtGeometryMask;
alias ushort Dimension;
alias ushort XIMStringConversionOperation;
alias ushort XIMStringConversionPosition;
alias ushort XIMStringConversionType;
alias _VendorShellClassRec VendorShellClassRec;
alias _VendorShellClassRec * VendorShellWidgetClass;
alias _VendorShellExtClassRec XawVendorShellExtClassRec;
alias VendorShellRec * VendorShellWidget;
alias _WidgetClassRec CoreClassRec;
alias _WidgetClassRec * CoreWidgetClass;
alias _WidgetClassRec * WidgetClass;
alias _WidgetClassRec WidgetClassRec;
alias _WidgetRec CoreRec;
alias _WidgetRec * CoreWidget;
alias _WidgetRec * Widget;
alias _WidgetRec * * WidgetList;
alias _WidgetRec WidgetRec;
alias _ViewportClassRec ViewportClassRec;
alias _ViewportClassRec * ViewportWidgetClass;
alias _ViewportConstraintsRec * ViewportConstraints;
alias _ViewportConstraintsRec ViewportConstraintsRec;
alias _ViewportPart ViewportPart;
alias _ViewportRec ViewportRec;
alias _ViewportRec * ViewportWidget;
alias _WMShellClassRec WMShellClassRec;
alias _WMShellClassRec * WMShellWidgetClass;
alias WMShellRec * WMShellWidget;
alias void function(char *, char *, char *, char *, char * *, uint *) * XtErrorMsgHandler;
alias void function(char *) * XtErrorHandler;
alias void function(_IceConn *) * IceIOErrorHandler;
alias void function(_IceConn *) * IceIOErrorProc;
alias void function(_IceConn *, int, int, int, int, int, void *) * IceErrorHandler;
alias void function(_IceConn *, void *) * IcePingReplyProc;
alias void function(_IceConn *, void *) * IceProtocolActivateProc;
alias void function(_IceConn *, void *, int, int, int) * IcePaProcessMsgProc;
alias void function(_IceConn *, void *, int, int, int, IceReplyWaitInfo *, int *) * IcePoProcessMsgProc;
alias void function(_IceConn *, void *, int, void * *) * IceWatchProc;
alias void function(_SmcConn *, int, int, int, int, int, void *) * SmcErrorHandler;
alias void function(_SmcConn *, void *, int, int, int, int) * SmcSaveYourselfProc;
alias void function(_SmcConn *, void *, int, SmProp * *) * SmcPropReplyProc;
alias void function(_SmcConn *, void *) * SmcDieProc;
alias void function(_SmcConn *, void *) * SmcInteractProc;
alias void function(_SmcConn *, void *) * SmcSaveCompleteProc;
alias void function(_SmcConn *, void *) * SmcSaveYourselfPhase2Proc;
alias void function(_SmcConn *, void *) * SmcShutdownCancelledProc;
alias void function(_SmsConn *, int, int, int, int, int, void *) * SmsErrorHandler;
alias void function(_SmsConn *, void *, int, char * *) * SmsCloseConnectionProc;
alias void function(_SmsConn *, void *, int, char * *) * SmsDeletePropertiesProc;
alias void function(_SmsConn *, void *, int, int, int, int, int) * SmsSaveYourselfRequestProc;
alias void function(_SmsConn *, void *, int, SmProp * *) * SmsSetPropertiesProc;
alias void function(_SmsConn *, void *, int) * SmsInteractDoneProc;
alias void function(_SmsConn *, void *, int) * SmsInteractRequestProc;
alias void function(_SmsConn *, void *, int) * SmsSaveYourselfDoneProc;
alias void function(_SmsConn *, void *) * SmsGetPropertiesProc;
alias void function(_SmsConn *, void *) * SmsSaveYourselfPhase2RequestProc;
alias void function(_WidgetClassRec *, uint *, uint *, Arg *, uint *, XtTypedArg *, uint *, _WidgetRec * *, void * *) * XtAllocateProc;
alias void function(_WidgetClassRec *) * XtWidgetClassProc;
alias void function(_WidgetRec *, Arg *, uint *) * XtArgsProc;
alias void function(_WidgetRec *, char *) * XtStringProc;
alias void function(_WidgetRec *, int, int, int, int, int *, int *, int *) * _XawSinkFindPositionProc;
alias void function(_WidgetRec *, int, int, int, int *, int *, int *) * _XawSinkFindDistanceProc;
alias void function(_WidgetRec *, int, int, int, int, int) * _XawSinkDisplayTextProc;
alias void function(_WidgetRec *, int, int, int, int *) * _XawSinkResolveProc;
alias void function(_WidgetRec *, int, int, int) * _XawSrcSetSelectionProc;
alias void function(_WidgetRec *, int, int, uint, uint) * _XawSinkClearToBackgroundProc;
alias void function(_WidgetRec *, int *, int *, void * *, void *) * XtCancelConvertSelectionProc;
alias void function(_WidgetRec *, int *, int *, void * *, void *) * XtSelectionDoneIncrProc;
alias void function(_WidgetRec *, int, int, XawTextInsertState) * _XawSinkInsertCursorProc;
alias void function(_WidgetRec *, int *, int *) * XtSelectionDoneProc;
alias void function(_WidgetRec *, int, short *) * _XawSinkSetTabsProc;
alias void function(_WidgetRec *, int *, void * *, int, void *) * XtExtensionSelectProc;
alias void function(_WidgetRec *, int *, void *) * XtLoseSelectionIncrProc;
alias void function(_WidgetRec *, int, XrmValue *) * XtResourceDefaultProc;
alias void function(_WidgetRec *, int *, XSetWindowAttributes *) * XtRealizeProc;
alias void function(_WidgetRec *, int *) * XtLoseSelectionProc;
alias void function(_WidgetRec *, uint *, XrmValue *) * XtConvertArgProc;
alias void function(_WidgetRec *, _WidgetRec *, Arg *, uint *) * XtInitProc;
alias void function(_WidgetRec *, _WidgetRec * *, uint *, _WidgetRec * *, uint *, void *) * XtDoChangeProc;
alias void function(_WidgetRec *, _WidgetRec *, XtWidgetGeometry *, XtWidgetGeometry *) * XtAlmostProc;
alias void function(_WidgetRec *, void *, char *, _XEvent *, char * *, uint *) * XtActionHookProc;
alias void function(_WidgetRec *, void *, int *, int *, void *, int *, int *) * XtSelectionCallbackProc;
alias void function(_WidgetRec *, void *, void *) * XtCallbackProc;
alias void function(_WidgetRec *, void *, _XEvent *, char *) * XtEventHandler;
alias void function(_WidgetRec *, void *) * XtDeallocateProc;
alias void function(_WidgetRec *, _XEvent *, char * *, uint *) * XtActionProc;
alias void function(_WidgetRec *, _XEvent *, char * *, uint *) * * XtBoundActions;
alias void function(_WidgetRec *, _XEvent *, _XRegion *) * XtExposeProc;
alias void function(_WidgetRec *, XRectangle *) * _XawSinkGetCursorBoundsProc;
alias void function(_WidgetRec *) * XtCreatePopupChildProc;
alias void function(_WidgetRec *) * XtWidgetProc;
alias void function(void *, int *, int *) * XtInputCallbackProc;
alias void function(void *, int *) * XtSignalCallbackProc;
alias void function(void *, int *) * XtTimerCallbackProc;
alias void function(void *) * XtBlockHookProc;
alias void function(_XDisplay *, char *, char *) * XIDProc;
alias void function(_XDisplay *, char *, int, int, char * *) * XConnectionWatchProc;
alias void function(_XDisplay *, int, int *, int *) * XtCaseProc;
alias void function(_XDisplay *, ubyte, uint, uint *, int *) * XtKeyProc;
alias void function(_XIM *, char *, char *) * XIMProc;
alias void function(XrmValue *, uint *, XrmValue *, XrmValue *) * XtConverter;
alias void function(_XtAppStruct *, XrmValue *, void *, XrmValue *, uint *) * XtDestructor;
alias void function() * XtProc;
alias void * IcePointer;
alias void * Opaque;
alias void * SmPointer;
alias void * XtActionHookId;
alias void * XtCacheRef;
alias void * XtPointer;
alias void * XtRequestId;
alias void * XtVarArgsList;
alias void * XVaNestedList;
alias _XawDL XawDisplayList;
alias _XawGripCallData * GripCallData;
alias _XawGripCallData GripCallDataRec;
alias _XawGripCallData * XawGripCallData;
alias _XawGripCallData XawGripCallDataRec;
alias _XawIcPart XawIcPart;
alias _XawIcTablePart * XawIcTableList;
alias _XawIcTablePart XawIcTablePart;
alias _XawImPart XawImPart;
alias _XawListReturnStruct XawListReturnStruct;
alias _XawTextAnchor XawTextAnchor;
alias XawTextBlock * XawTextBlockPtr;
alias _XawTextEntity XawTextEntity;
alias _XawTextKillRing XawTextKillRing;
alias XawTextLineTableEntry * XawTextLineTableEntryPtr;
alias XawTextLineTable * XawTextLineTablePtr;
alias _XawTextMargin XawTextMargin;
alias _XawTextPaintStruct XawTextPaintStruct;
alias _XawTextPropertyList XawTextPropertyList;
alias _XawTextProperty XawTextProperty;
alias _XawTextSelectionSalt XawTextSelectionSalt;
alias _XawTextUndo XawTextUndo;
alias XawVendorShellExtRec XawVendorShellExtRec;
alias XawVendorShellExtRec * XawVendorShellExtWidget;
alias XButtonEvent XButtonPressedEvent;
alias XButtonEvent XButtonReleasedEvent;
alias _XComposeStatus XComposeStatus;
alias XCrossingEvent XEnterWindowEvent;
alias XCrossingEvent XLeaveWindowEvent;
alias _XDisplay Display;
alias _XEvent XEvent;
alias _XExtData XExtData;
alias XFocusChangeEvent XFocusInEvent;
alias XFocusChangeEvent XFocusOutEvent;
alias _XGC * GC;
alias _XIC * XIC;
alias _XImage XImage;
alias _XIMHotKeyTriggers XIMHotKeyTriggers;
alias _XIMHotKeyTrigger XIMHotKeyTrigger;
alias _XIMPreeditCaretCallbackStruct XIMPreeditCaretCallbackStruct;
alias _XIMPreeditDrawCallbackStruct XIMPreeditDrawCallbackStruct;
alias _XIMPreeditStateNotifyCallbackStruct XIMPreeditStateNotifyCallbackStruct;
alias _XIMStatusDrawCallbackStruct XIMStatusDrawCallbackStruct;
alias _XIMStringConversionCallbackStruct XIMStringConversionCallbackStruct;
alias _XIMStringConversionText XIMStringConversionText;
alias _XIMText XIMText;
alias _XIM * XIM;
alias XKeyEvent XKeyPressedEvent;
alias XKeyEvent XKeyReleasedEvent;
alias XMotionEvent XPointerMovedEvent;
alias _XmuArea XmuArea;
alias _XmuScanline XmuScanline;
alias _XmuScanline XmuTextUpdate;
alias _XmuSegment XmuSegment;
alias _XmuWidgetNode XmuWidgetNode;
alias _XOC * XFontSet;
alias _XOC * XOC;
alias _XOM * XOM;
alias  * _XPrivDisplay;
alias _XRegion * Region;
alias XrmBinding * XrmBindingList;
alias _XrmHashBucketRec * * [1] XrmSearchList;
alias _XrmHashBucketRec * XrmDatabase;
alias _XrmHashBucketRec * XrmHashBucket;
alias _XrmHashBucketRec * * XrmHashTable;
alias XrmOptionDescRec * XrmOptionDescList;
alias XrmResource * XrmResourceList;
alias XrmValue * XrmValuePtr;
alias _XtActionsRec * XtActionList;
alias _XtActionsRec XtActionsRec;
alias _XtAppStruct * XtAppContext;
alias _XtCallbackRec * XtCallbackList;
alias _XtCallbackRec XtCallbackRec;
alias XtChangeHookDataRec * XtChangeHookData;
alias XtChangeHookSetValuesDataRec * XtChangeHookSetValuesData;
alias _XtCheckpointTokenRec * XtCheckpointToken;
alias _XtCheckpointTokenRec XtCheckpointTokenRec;
alias XtConfigureHookDataRec * XtConfigureHookData;
alias XtConvertArgRec * XtConvertArgList;
alias XtCreateHookDataRec * XtCreateHookData;
alias XtDestroyHookDataRec * XtDestroyHookData;
alias _XtEventRec * XtEventTable;
alias XtGeometryHookDataRec * XtGeometryHookData;
alias XtGeometryResult function(_WidgetRec *, XtWidgetGeometry *, XtWidgetGeometry *) * XtGeometryHandler;
alias XtPopdownIDRec * XtPopdownID;
alias _XtResource XtResource;
alias _XtResource * XtResourceList;
alias _XtSaveYourselfRec * XtSaveYourself;
alias _XtTMRec * XtTM;
alias _XtTMRec XtTMRec;
alias XtTypedArg * XtTypedArgList;

extern(System) extern _ApplicationShellClassRec applicationShellClassRec;
extern(System) extern _AsciiSinkClassRec asciiSinkClassRec;
extern(System) extern _AsciiSrcClassRec asciiSrcClassRec;
extern(System) extern _AsciiTextClassRec asciiTextClassRec;
extern(System) extern _AtomRec * _XA_ATOM_PAIR;
extern(System) extern _AtomRec * _XA_CHARACTER_POSITION;
extern(System) extern _AtomRec * _XA_CLASS;
extern(System) extern _AtomRec * _XA_CLIENT_WINDOW;
extern(System) extern _AtomRec * _XA_CLIPBOARD;
extern(System) extern _AtomRec * _XA_COMPOUND_TEXT;
extern(System) extern _AtomRec * _XA_DECNET_ADDRESS;
extern(System) extern _AtomRec * _XA_DELETE;
extern(System) extern _AtomRec * _XA_FILENAME;
extern(System) extern _AtomRec * _XA_HOSTNAME;
extern(System) extern _AtomRec * _XA_IP_ADDRESS;
extern(System) extern _AtomRec * _XA_LENGTH;
extern(System) extern _AtomRec * _XA_LIST_LENGTH;
extern(System) extern _AtomRec * _XA_NAME;
extern(System) extern _AtomRec * _XA_NET_ADDRESS;
extern(System) extern _AtomRec * _XA_NULL;
extern(System) extern _AtomRec * _XA_OWNER_OS;
extern(System) extern _AtomRec * _XA_SPAN;
extern(System) extern _AtomRec * _XA_TARGETS;
extern(System) extern _AtomRec * _XA_TEXT;
extern(System) extern _AtomRec * _XA_TIMESTAMP;
extern(System) extern _AtomRec * _XA_USER;
extern(System) extern _AtomRec * _XA_UTF8_STRING;
extern(System) extern _BoxClassRec boxClassRec;
extern(System) extern char [1] _XawDefaultTextTranslations;
extern(System) extern _CommandClassRec commandClassRec;
extern(System) extern const char [1] XtShellStrings;
extern(System) extern _DialogClassRec dialogClassRec;
extern(System) extern _FormClassRec formClassRec;
extern(System) extern _GripClassRec gripClassRec;
extern(System) extern int FMT8BIT;
extern(System) extern int XawFmt8Bit;
extern(System) extern int XawFmtWide;
extern(System) extern int XawWidgetCount;
extern(System) extern int _Xdebug;
extern(System) extern _LabelClassRec labelClassRec;
extern(System) extern _ListClassRec listClassRec;
extern(System) extern _MenuButtonClassRec menuButtonClassRec;
extern(System) extern _MultiSinkClassRec multiSinkClassRec;
extern(System) extern _MultiSrcClassRec multiSrcClassRec;
extern(System) extern _ObjectClassRec objectClassRec;
extern(System) extern _OverrideShellClassRec overrideShellClassRec;
extern(System) extern _PanedClassRec panedClassRec;
extern(System) extern _PannerClassRec pannerClassRec;
extern(System) extern _PortholeClassRec portholeClassRec;
extern(System) extern _RectObjClassRec rectObjClassRec;
extern(System) extern _RepeaterClassRec repeaterClassRec;
extern(System) extern _ScrollbarClassRec scrollbarClassRec;
extern(System) extern _SessionShellClassRec sessionShellClassRec;
extern(System) extern _ShellClassRec shellClassRec;
extern(System) extern _SimpleClassRec simpleClassRec;
extern(System) extern _SimpleMenuClassRec simpleMenuClassRec;
extern(System) extern _SmeBSBClassRec smeBSBClassRec;
extern(System) extern _SmeClassRec smeClassRec;
extern(System) extern _SmeLineClassRec smeLineClassRec;
extern(System) extern _StripChartClassRec stripChartClassRec;
extern(System) extern _TemplateClassRec templateClassRec;
extern(System) extern _TextClassRec textClassRec;
extern(System) extern _TextSinkClassRec textSinkClassRec;
extern(System) extern _TextSrcClassRec textSrcClassRec;
extern(System) extern _TipClassRec tipClassRec;
extern(System) extern _ToggleClassRec toggleClassRec;
extern(System) extern _TopLevelShellClassRec topLevelShellClassRec;
extern(System) extern _TransientShellClassRec transientShellClassRec;
extern(System) extern _TreeClassRec treeClassRec;
extern(System) extern uint _XawTextActionsTableCount;
extern(System) extern _VendorShellClassRec vendorShellClassRec;
extern(System) extern _WidgetClassRec * applicationShellWidgetClass;
extern(System) extern _WidgetClassRec * asciiSinkObjectClass;
extern(System) extern _WidgetClassRec * asciiSrcObjectClass;
extern(System) extern _WidgetClassRec * asciiTextWidgetClass;
extern(System) extern _WidgetClassRec * boxWidgetClass;
extern(System) extern _WidgetClassRec * commandWidgetClass;
extern(System) extern _WidgetClassRec * dialogWidgetClass;
extern(System) extern _WidgetClassRec * formWidgetClass;
extern(System) extern _WidgetClassRec * gripWidgetClass;
extern(System) extern _WidgetClassRec * labelWidgetClass;
extern(System) extern _WidgetClassRec * listWidgetClass;
extern(System) extern _WidgetClassRec * menuButtonWidgetClass;
extern(System) extern _WidgetClassRec * multiSinkObjectClass;
extern(System) extern _WidgetClassRec * multiSrcObjectClass;
extern(System) extern _WidgetClassRec * objectClass;
extern(System) extern _WidgetClassRec * overrideShellWidgetClass;
extern(System) extern _WidgetClassRec * panedWidgetClass;
extern(System) extern _WidgetClassRec * pannerWidgetClass;
extern(System) extern _WidgetClassRec * portholeWidgetClass;
extern(System) extern _WidgetClassRec * rectObjClass;
extern(System) extern _WidgetClassRec * repeaterWidgetClass;
extern(System) extern _WidgetClassRec * scrollbarWidgetClass;
extern(System) extern _WidgetClassRec * sessionShellWidgetClass;
extern(System) extern _WidgetClassRec * shellWidgetClass;
extern(System) extern _WidgetClassRec * simpleMenuWidgetClass;
extern(System) extern _WidgetClassRec * simpleWidgetClass;
extern(System) extern _WidgetClassRec * smeBSBObjectClass;
extern(System) extern _WidgetClassRec * smeLineObjectClass;
extern(System) extern _WidgetClassRec * smeObjectClass;
extern(System) extern _WidgetClassRec * stripChartWidgetClass;
extern(System) extern _WidgetClassRec * templateWidgetClass;
extern(System) extern _WidgetClassRec * textSinkObjectClass;
extern(System) extern _WidgetClassRec * textSrcObjectClass;
extern(System) extern _WidgetClassRec * textWidgetClass;
extern(System) extern _WidgetClassRec * tipWidgetClass;
extern(System) extern _WidgetClassRec * toggleWidgetClass;
extern(System) extern _WidgetClassRec * topLevelShellWidgetClass;
extern(System) extern _WidgetClassRec * transientShellWidgetClass;
extern(System) extern _WidgetClassRec * treeWidgetClass;
extern(System) extern _WidgetClassRec * vendorShellWidgetClass;
extern(System) extern _WidgetClassRec * viewportWidgetClass;
extern(System) extern _WidgetClassRec * wmShellWidgetClass;
extern(System) extern _ViewportClassRec viewportClassRec;
extern(System) extern _WMShellClassRec wmShellClassRec;
extern(System) extern _XawTextKillRing * xaw_text_kill_ring;
extern(System) extern _XmuWidgetNode [1] XawWidgetArray;
extern(System) extern _XtActionsRec [1] _XawTextActionsTable;
extern(System) extern XtConvertArgRec [1] colorConvertArgs;
extern(System) extern XtConvertArgRec [1] screenConvertArg;


extern(System) Arg * XtMergeArgLists(Arg *, uint, Arg *, uint);
extern(System) _AtomRec * XmuMakeAtom(char * name);
extern(System) char * function(_XDisplay *, char *, void *) * XtSetLanguageProc(_XtAppStruct *, char * function(_XDisplay *, char *, void *) *, void *);
extern(System) char function(_XEvent *) * XtSetEventDispatcher(_XDisplay *, int, char function(_XEvent *) *);
extern(System) char * IceAllocScratch(_IceConn *, int);
extern(System) char * IceComposeNetworkIdList(int, _IceListenObj * *);
extern(System) char * IceConnectionString(_IceConn *);
extern(System) char * IceGetListenConnectionString(_IceListenObj *);
extern(System) char * IceGetPeerName(_IceConn *);
extern(System) char * IceRelease(_IceConn *);
extern(System) char * IceVendor(_IceConn *);
extern(System) char * SmcClientID(_SmcConn *);
extern(System) char * SmcRelease(_SmcConn *);
extern(System) char * SmcVendor(_SmcConn *);
extern(System) char * SmsClientHostName(_SmsConn *);
extern(System) char * SmsClientID(_SmsConn *);
extern(System) char * SmsGenerateClientID(_SmsConn *);
extern(System) char * XawDialogGetValueString(_WidgetRec * w);
extern(System) char * _XawTextGetSTRING(_TextRec * ctx, int left, int right);
extern(System) char XawTextSourceConvertSelection(_WidgetRec * w, int * selection, int * target, int * type, void * * value_return, int * length_return, int * format_return);
extern(System) char * _XawTextWCToMB(_XDisplay * display, dchar * wstr, int * len_in_out);
extern(System) char * XBaseFontNameListOfFontSet(_XOC *);
extern(System) char * XDefaultString();
extern(System) char * XDisplayName(char *);
extern(System) char * XDisplayString(_XDisplay *);
extern(System) char * XFetchBuffer(_XDisplay *, int *, int);
extern(System) char * XFetchBytes(_XDisplay *, int *);
extern(System) char * XGetAtomName(_XDisplay *, int);
extern(System) char * XGetDefault(_XDisplay *, char *, char *);
extern(System) char * * XGetFontPath(_XDisplay *, int *);
extern(System) char * XGetICValues(_XIC *);
extern(System) char * XGetIMValues(_XIM *);
extern(System) char * XGetOCValues(_XOC *);
extern(System) char * XGetOMValues(_XOM *);
extern(System) char * XKeysymToString(int);
extern(System) char * * XListExtensions(_XDisplay *, int *);
extern(System) char * * XListFontsWithInfo(_XDisplay *, char *, int, int *, XFontStruct * *);
extern(System) char * * XListFonts(_XDisplay *, char *, int, int *);
extern(System) char * XLocaleOfFontSet(_XOC *);
extern(System) char * XLocaleOfIM(_XIM *);
extern(System) char * XLocaleOfOM(_XOM *);
extern(System) char * XmbResetIC(_XIC *);
extern(System) char XmuConvertStandardSelection(_WidgetRec * w, int timev, int * selection, int * target, int * type_return, char * * value_return, int * length_return, int * format_return);
extern(System) char XmuCvtBackingStoreToString(_XDisplay * dpy, XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal, void * * converter_data);
extern(System) char XmuCvtGravityToString(_XDisplay * dpy, XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal, void * * converter_data);
extern(System) char XmuCvtJustifyToString(_XDisplay * dpy, XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal, void * * converter_data);
extern(System) char XmuCvtLongToString(_XDisplay * dpy, XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal, void * * converter_data);
extern(System) char XmuCvtOrientationToString(_XDisplay * dpy, XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal, void * * converter_data);
extern(System) char XmuCvtShapeStyleToString(_XDisplay * dpy, XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal, void * * converter_data);
extern(System) char XmuCvtStringToColorCursor(_XDisplay * dpy, XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal, void * * converter_data);
extern(System) char XmuCvtStringToShapeStyle(_XDisplay * dpy, XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal, void * * converter_data);
extern(System) char XmuCvtWidgetToString(_XDisplay * dpy, XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal, void * * converter_data);
extern(System) char * XmuGetAtomName(_XDisplay * dpy, int atom);
extern(System) char * XmuNameOfAtom(_AtomRec * atom_ptr);
extern(System) char XmuNewCvtStringToWidget(_XDisplay * display, XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal, void * * converter_data);
extern(System) char XmuReshapeWidget(_WidgetRec * w, int shape_style, int corner_width, int corner_height);
extern(System) char * Xpermalloc(uint);
extern(System) char * XResourceManagerString(_XDisplay *);
extern(System) char * XrmLocaleOfDatabase(_XrmHashBucketRec *);
extern(System) char * XrmQuarkToString(int);
extern(System) char * XScreenResourceString(Screen *);
extern(System) char * XServerVendor(_XDisplay *);
extern(System) char * XSetICValues(_XIC *);
extern(System) char * XSetIMValues(_XIM *);
extern(System) char * XSetLocaleModifiers(char *);
extern(System) char * XSetOCValues(_XOC *);
extern(System) char * XSetOMValues(_XOM *);
extern(System) char XtAppGetExitFlag(_XtAppStruct *);
extern(System) char XtAppPeekEvent(_XtAppStruct *, _XEvent *);
extern(System) char XtCallAcceptFocus(_WidgetRec *, int *);
extern(System) char XtCallConverter(_XDisplay *, char function(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *) *, XrmValue *, uint, XrmValue *, XrmValue *, void * *);
extern(System) char * XtCalloc(uint, uint);
extern(System) char _XtCheckSubclassFlag(_WidgetRec *, ubyte);
extern(System) char XtConvertAndStore(_WidgetRec *, char *, XrmValue *, char *, XrmValue *);
extern(System) char XtCvtColorToPixel(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtIntToBoolean(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtIntToBool(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtIntToColor(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtIntToFloat(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtIntToFont(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtIntToPixel(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtIntToPixmap(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtIntToShort(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtIntToUnsignedChar(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToAcceleratorTable(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToAtom(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToBoolean(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToBool(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToCommandArgArray(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToCursor(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToDimension(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToDirectoryString(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToDisplay(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToFile(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToFloat(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToFontSet(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToFontStruct(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToFont(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToGravity(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToInitialState(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToInt(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToPixel(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToRestartStyle(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToShort(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToTranslationTable(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToUnsignedChar(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtCvtStringToVisual(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *);
extern(System) char XtDispatchEventToWidget(_WidgetRec *, _XEvent *);
extern(System) char XtDispatchEvent(_XEvent *);
extern(System) char * XtFindFile(char *, SubstitutionRec *, uint, char function(char *) *);
extern(System) char XtIsApplicationShell(_WidgetRec *);
extern(System) char XtIsComposite(_WidgetRec *);
extern(System) char XtIsConstraint(_WidgetRec *);
extern(System) char XtIsManaged(_WidgetRec *);
extern(System) char XtIsObject(_WidgetRec *);
extern(System) char XtIsOverrideShell(_WidgetRec *);
extern(System) char XtIsRealized(_WidgetRec *);
extern(System) char XtIsRectObj(_WidgetRec *);
extern(System) char XtIsSensitive(_WidgetRec *);
extern(System) char XtIsSessionShell(_WidgetRec *);
extern(System) char XtIsShell(_WidgetRec *);
extern(System) char _XtIsSubclassOf(_WidgetRec *, _WidgetClassRec *, _WidgetClassRec *, ubyte);
extern(System) char XtIsSubclass(_WidgetRec *, _WidgetClassRec *);
extern(System) char XtIsTopLevelShell(_WidgetRec *);
extern(System) char XtIsTransientShell(_WidgetRec *);
extern(System) char XtIsVendorShell(_WidgetRec *);
extern(System) char XtIsWidget(_WidgetRec *);
extern(System) char XtIsWMShell(_WidgetRec *);
extern(System) char * XtMalloc(uint);
extern(System) char * XtName(_WidgetRec *);
extern(System) char * XtNewString(char *);
extern(System) char XtOwnSelectionIncremental(_WidgetRec *, int, int, char function(_WidgetRec *, int *, int *, int *, void * *, int *, int *, int *, void *, void * *) *, void function(_WidgetRec *, int *, void *) *, void function(_WidgetRec *, int *, int *, void * *, void *) *, void function(_WidgetRec *, int *, int *, void * *, void *) *, void *);
extern(System) char XtOwnSelection(_WidgetRec *, int, int, char function(_WidgetRec *, int *, int *, int *, void * *, int *, int *) *, void function(_WidgetRec *, int *) *, void function(_WidgetRec *, int *, int *) *);
extern(System) char XtPeekEvent(_XEvent *);
extern(System) char XtPending();
extern(System) char * XtRealloc(char *, uint);
extern(System) char * XtResolvePathname(_XDisplay *, char *, char *, char *, char *, SubstitutionRec *, uint, char function(char *) *);
extern(System) char XtToolkitThreadInitialize();
extern(System) char * Xutf8ResetIC(_XIC *);
extern(System) dchar * _XawTextMBToWC(_XDisplay * display, char * str, int * len_in_out);
extern(System) dchar * XwcResetIC(_XIC *);
extern(System) IceCloseStatus IceCloseConnection(_IceConn *);
extern(System) IceConnectStatus IceConnectionStatus(_IceConn *);
extern(System) _IceConn * IceAcceptConnection(_IceListenObj *, IceAcceptStatus *);
extern(System) _IceConn * IceOpenConnection(char *, void *, int, int, int, char *);
extern(System) _IceConn * SmcGetIceConnection(_SmcConn *);
extern(System) _IceConn * SmsGetIceConnection(_SmsConn *);
extern(System) IceProcessMessagesStatus IceProcessMessages(_IceConn *, IceReplyWaitInfo *, int *);
extern(System) IceProtocolSetupStatus IceProtocolSetup(_IceConn *, int, void *, int, int *, int *, char * *, char * *, int, char *);
extern(System) int function(_XDisplay *, XErrorEvent *) * XSetErrorHandler(int function(_XDisplay *, XErrorEvent *) *);
extern(System) int function(_XDisplay *) * XSetAfterFunction(_XDisplay *, int function(_XDisplay *) *);
extern(System) int function(_XDisplay *) * XSetIOErrorHandler(int function(_XDisplay *) *);
extern(System) int function(_XDisplay *) * XSynchronize(_XDisplay *, int);
extern(System) int IceAddConnectionWatch(void function(_IceConn *, void *, int, void * *) *, void *);
extern(System) int IceCheckShutdownNegotiation(_IceConn *);
extern(System) int IceConnectionNumber(_IceConn *);
extern(System) int IceFlush(_IceConn *);
extern(System) int IceGetInBufSize(_IceConn *);
extern(System) int IceGetListenConnectionNumber(_IceListenObj *);
extern(System) int IceGetOutBufSize(_IceConn *);
extern(System) int IceInitThreads();
extern(System) int IceLastReceivedSequenceNumber(_IceConn *);
extern(System) int IceLastSentSequenceNumber(_IceConn *);
extern(System) int IceListenForConnections(int *, _IceListenObj * * *, int, char *);
extern(System) int IceListenForWellKnownConnections(char *, int *, _IceListenObj * * *, int, char *);
extern(System) int IcePing(_IceConn *, void function(_IceConn *, void *) *, void *);
extern(System) int IceProtocolRevision(_IceConn *);
extern(System) int IceProtocolShutdown(_IceConn *, int);
extern(System) int IceProtocolVersion(_IceConn *);
extern(System) int IceRegisterForProtocolReply(char *, char *, char *, int, IcePaVersionRec *, int, char * *, IcePaAuthStatus function(_IceConn *, void * *, int, int, void *, int *, void * *, char * *) * *, int function(char *) *, int function(_IceConn *, int, int, char *, char *, void * *, char * *) *, void function(_IceConn *, void *) *, void function(_IceConn *) *);
extern(System) int IceRegisterForProtocolSetup(char *, char *, char *, int, IcePoVersionRec *, int, char * *, IcePoAuthStatus function(_IceConn *, void * *, int, int, int, void *, int *, void * *, char * *) * *, void function(_IceConn *) *);
extern(System) int IceSwapping(_IceConn *);
extern(System) int SmcGetProperties(_SmcConn *, void function(_SmcConn *, void *, int, SmProp * *) *, void *);
extern(System) int SmcInteractRequest(_SmcConn *, int, void function(_SmcConn *, void *) *, void *);
extern(System) int SmcProtocolRevision(_SmcConn *);
extern(System) int SmcProtocolVersion(_SmcConn *);
extern(System) int SmcRequestSaveYourselfPhase2(_SmcConn *, void function(_SmcConn *, void *) *, void *);
extern(System) int SmsInitialize(char *, char *, int function(_SmsConn *, void *, int *, SmsCallbacks *, char * *) *, void *, int function(char *) *, int, char *);
extern(System) int SmsProtocolRevision(_SmsConn *);
extern(System) int SmsProtocolVersion(_SmsConn *);
extern(System) int SmsRegisterClientReply(_SmsConn *, char *);
extern(System) int XActivateScreenSaver(_XDisplay *);
extern(System) int XAddConnectionWatch(_XDisplay *, void function(_XDisplay *, char *, int, int, char * *) *, char *);
extern(System) int XAddHosts(_XDisplay *, XHostAddress *, int);
extern(System) int XAddHost(_XDisplay *, XHostAddress *);
extern(System) int XAddToExtensionList(_XExtData * *, _XExtData *);
extern(System) int XAddToSaveSet(_XDisplay *, int);
extern(System) int XAllocColorCells(_XDisplay *, int, int, int *, uint, int *, uint);
extern(System) int XAllocColorPlanes(_XDisplay *, int, int, int *, int, int, int, int, int *, int *, int *);
extern(System) int XAllocColor(_XDisplay *, int, XColor *);
extern(System) int XAllocNamedColor(_XDisplay *, int, char *, XColor *, XColor *);
extern(System) int XAllowEvents(_XDisplay *, int, int);
extern(System) int XAllPlanes();
extern(System) int XAutoRepeatOff(_XDisplay *);
extern(System) int XAutoRepeatOn(_XDisplay *);
extern(System) int XawAsciiSaveAsFile(_WidgetRec * w, char * name);
extern(System) int XawAsciiSave(_WidgetRec * w);
extern(System) int XawAsciiSourceChanged(_WidgetRec * w);
extern(System) int _XawImGetImAreaHeight(_WidgetRec * w);
extern(System) int _XawImWcLookupString(_WidgetRec * w, XKeyEvent * event, dchar * buffer_return, int bytes_buffer, int * keysym_return);
extern(System) int _XawLookupString(_WidgetRec * w, XKeyEvent * event, char * buffer_return, int buffer_size, int * keysym_return);
extern(System) int _XawMultiSaveAsFile(_WidgetRec * w, char * name);
extern(System) int _XawMultiSave(_WidgetRec * w);
extern(System) int XawPanedGetNumSub(_WidgetRec * w);
extern(System) int _XawTextFormat(_TextRec * tw);
extern(System) int XawTextGetInsertionPoint(_WidgetRec * w);
extern(System) int XawTextLastPosition(_WidgetRec * w);
extern(System) int XawTextReplace(_WidgetRec * w, int start, int end, XawTextBlock * text);
extern(System) int XawTextSearch(_WidgetRec * w, XawTextScanDirection dir, XawTextBlock * text);
extern(System) int XawTextSinkBeginPaint(_WidgetRec * w);
extern(System) int XawTextSinkEndPaint(_WidgetRec * w);
extern(System) int XawTextSinkMaxHeight(_WidgetRec * w, int lines);
extern(System) int XawTextSinkMaxLines(_WidgetRec * w, ushort height);
extern(System) int XawTextSourceAnchorAndEntity(_WidgetRec * w, int position, _XawTextAnchor * * anchor_return, _XawTextEntity * * entity_return);
extern(System) int XawTextSourceRead(_WidgetRec * w, int pos, XawTextBlock * text_return, int length);
extern(System) int XawTextSourceReplace(_WidgetRec * w, int start, int end, XawTextBlock * text);
extern(System) int XawTextSourceScan(_WidgetRec * w, int position, XawTextScanType type, XawTextScanDirection dir, int count, char include);
extern(System) int XawTextSourceSearch(_WidgetRec * w, int position, XawTextScanDirection dir, XawTextBlock * text);
extern(System) int XawTextTopPosition(_WidgetRec * w);
extern(System) int XBell(_XDisplay *, int);
extern(System) int XBitmapBitOrder(_XDisplay *);
extern(System) int XBitmapPad(_XDisplay *);
extern(System) int XBitmapUnit(_XDisplay *);
extern(System) int XBlackPixelOfScreen(Screen *);
extern(System) int XBlackPixel(_XDisplay *, int);
extern(System) int XCellsOfScreen(Screen *);
extern(System) int XChangeActivePointerGrab(_XDisplay *, uint, int, int);
extern(System) int XChangeGC(_XDisplay *, _XGC *, int, XGCValues *);
extern(System) int XChangeKeyboardControl(_XDisplay *, int, XKeyboardControl *);
extern(System) int XChangeKeyboardMapping(_XDisplay *, int, int, int *, int);
extern(System) int XChangePointerControl(_XDisplay *, int, int, int, int, int);
extern(System) int XChangeProperty(_XDisplay *, int, int, int, int, int, ubyte *, int);
extern(System) int XChangeSaveSet(_XDisplay *, int, int);
extern(System) int XChangeWindowAttributes(_XDisplay *, int, int, XSetWindowAttributes *);
extern(System) int XCheckIfEvent(_XDisplay *, _XEvent *, int function(_XDisplay *, _XEvent *, char *) *, char *);
extern(System) int XCheckMaskEvent(_XDisplay *, int, _XEvent *);
extern(System) int XCheckTypedEvent(_XDisplay *, int, _XEvent *);
extern(System) int XCheckTypedWindowEvent(_XDisplay *, int, int, _XEvent *);
extern(System) int XCheckWindowEvent(_XDisplay *, int, int, _XEvent *);
extern(System) int XCirculateSubwindowsDown(_XDisplay *, int);
extern(System) int XCirculateSubwindowsUp(_XDisplay *, int);
extern(System) int XCirculateSubwindows(_XDisplay *, int, int);
extern(System) int XClearArea(_XDisplay *, int, int, int, uint, uint, int);
extern(System) int XClearWindow(_XDisplay *, int);
extern(System) int XClipBox(_XRegion *, XRectangle *);
extern(System) int XCloseDisplay(_XDisplay *);
extern(System) int XCloseIM(_XIM *);
extern(System) int XCloseOM(_XOM *);
extern(System) int XConfigureWindow(_XDisplay *, int, uint, XWindowChanges *);
extern(System) int XConnectionNumber(_XDisplay *);
extern(System) int XContextDependentDrawing(_XOC *);
extern(System) int XContextualDrawing(_XOC *);
extern(System) int XConvertSelection(_XDisplay *, int, int, int, int, int);
extern(System) int XCopyArea(_XDisplay *, int, int, _XGC *, int, int, uint, uint, int, int);
extern(System) int XCopyColormapAndFree(_XDisplay *, int);
extern(System) int XCopyGC(_XDisplay *, _XGC *, int, _XGC *);
extern(System) int XCopyPlane(_XDisplay *, int, int, _XGC *, int, int, uint, uint, int, int, int);
extern(System) int XCreateBitmapFromData(_XDisplay *, int, char *, uint, uint);
extern(System) int XCreateColormap(_XDisplay *, int, Visual *, int);
extern(System) int XCreateFontCursor(_XDisplay *, uint);
extern(System) int XCreateGlyphCursor(_XDisplay *, int, int, uint, uint, XColor *, XColor *);
extern(System) int XCreatePixmapCursor(_XDisplay *, int, int, XColor *, XColor *, uint, uint);
extern(System) int XCreatePixmapFromBitmapData(_XDisplay *, int, char *, uint, uint, int, int, uint);
extern(System) int XCreatePixmap(_XDisplay *, int, uint, uint, uint);
extern(System) int XCreateSimpleWindow(_XDisplay *, int, int, int, uint, uint, uint, int, int);
extern(System) int XCreateWindow(_XDisplay *, int, int, int, uint, uint, uint, int, uint, Visual *, int, XSetWindowAttributes *);
extern(System) int XDefaultColormapOfScreen(Screen *);
extern(System) int XDefaultColormap(_XDisplay *, int);
extern(System) int XDefaultDepthOfScreen(Screen *);
extern(System) int XDefaultDepth(_XDisplay *, int);
extern(System) int XDefaultRootWindow(_XDisplay *);
extern(System) int XDefaultScreen(_XDisplay *);
extern(System) int XDefineCursor(_XDisplay *, int, int);
extern(System) int XDeleteContext(_XDisplay *, int, int);
extern(System) int XDeleteProperty(_XDisplay *, int, int);
extern(System) int XDestroyRegion(_XRegion *);
extern(System) int XDestroySubwindows(_XDisplay *, int);
extern(System) int XDestroyWindow(_XDisplay *, int);
extern(System) int XDirectionalDependentDrawing(_XOC *);
extern(System) int XDisableAccessControl(_XDisplay *);
extern(System) int XDisplayCells(_XDisplay *, int);
extern(System) int XDisplayHeightMM(_XDisplay *, int);
extern(System) int XDisplayHeight(_XDisplay *, int);
extern(System) int XDisplayKeycodes(_XDisplay *, int *, int *);
extern(System) int XDisplayMotionBufferSize(_XDisplay *);
extern(System) int XDisplayPlanes(_XDisplay *, int);
extern(System) int XDisplayWidthMM(_XDisplay *, int);
extern(System) int XDisplayWidth(_XDisplay *, int);
extern(System) int XDoesBackingStore(Screen *);
extern(System) int XDoesSaveUnders(Screen *);
extern(System) int XDrawArcs(_XDisplay *, int, _XGC *, XArc *, int);
extern(System) int XDrawArc(_XDisplay *, int, _XGC *, int, int, uint, uint, int, int);
extern(System) int XDrawImageString16(_XDisplay *, int, _XGC *, int, int, XChar2b *, int);
extern(System) int XDrawImageString(_XDisplay *, int, _XGC *, int, int, char *, int);
extern(System) int XDrawLines(_XDisplay *, int, _XGC *, XPoint *, int, int);
extern(System) int XDrawLine(_XDisplay *, int, _XGC *, int, int, int, int);
extern(System) int XDrawPoints(_XDisplay *, int, _XGC *, XPoint *, int, int);
extern(System) int XDrawPoint(_XDisplay *, int, _XGC *, int, int);
extern(System) int XDrawRectangles(_XDisplay *, int, _XGC *, XRectangle *, int);
extern(System) int XDrawRectangle(_XDisplay *, int, _XGC *, int, int, uint, uint);
extern(System) int XDrawSegments(_XDisplay *, int, _XGC *, XSegment *, int);
extern(System) int XDrawString16(_XDisplay *, int, _XGC *, int, int, XChar2b *, int);
extern(System) int XDrawString(_XDisplay *, int, _XGC *, int, int, char *, int);
extern(System) int XDrawText16(_XDisplay *, int, _XGC *, int, int, XTextItem16 *, int);
extern(System) int XDrawText(_XDisplay *, int, _XGC *, int, int, XTextItem *, int);
extern(System) int XEmptyRegion(_XRegion *);
extern(System) int XEnableAccessControl(_XDisplay *);
extern(System) int XEqualRegion(_XRegion *, _XRegion *);
extern(System) int XEventMaskOfScreen(Screen *);
extern(System) int XEventsQueued(_XDisplay *, int);
extern(System) int XExtendedMaxRequestSize(_XDisplay *);
extern(System) int XFetchName(_XDisplay *, int, char * *);
extern(System) int XFillArcs(_XDisplay *, int, _XGC *, XArc *, int);
extern(System) int XFillArc(_XDisplay *, int, _XGC *, int, int, uint, uint, int, int);
extern(System) int XFillPolygon(_XDisplay *, int, _XGC *, XPoint *, int, int, int);
extern(System) int XFillRectangles(_XDisplay *, int, _XGC *, XRectangle *, int);
extern(System) int XFillRectangle(_XDisplay *, int, _XGC *, int, int, uint, uint);
extern(System) int XFilterEvent(_XEvent *, int);
extern(System) int XFindContext(_XDisplay *, int, int, char * *);
extern(System) int XFlush(_XDisplay *);
extern(System) int XFontsOfFontSet(_XOC *, XFontStruct * * *, char * * *);
extern(System) int XForceScreenSaver(_XDisplay *, int);
extern(System) int XFreeColormap(_XDisplay *, int);
extern(System) int XFreeColors(_XDisplay *, int, int *, int, int);
extern(System) int XFreeCursor(_XDisplay *, int);
extern(System) int XFreeExtensionList(char * *);
extern(System) int XFreeFontInfo(char * *, XFontStruct *, int);
extern(System) int XFreeFontNames(char * *);
extern(System) int XFreeFontPath(char * *);
extern(System) int XFreeFont(_XDisplay *, XFontStruct *);
extern(System) int XFreeGC(_XDisplay *, _XGC *);
extern(System) int XFreeModifiermap(XModifierKeymap *);
extern(System) int XFreePixmap(_XDisplay *, int);
extern(System) int XFree(void *);
extern(System) int XGContextFromGC(_XGC *);
extern(System) int XGeometry(_XDisplay *, int, char *, char *, uint, uint, uint, int, int, int *, int *, int *, int *);
extern(System) int XGetAtomNames(_XDisplay *, int *, int, char * *);
extern(System) int XGetClassHint(_XDisplay *, int, XClassHint *);
extern(System) int XGetCommand(_XDisplay *, int, char * * *, int *);
extern(System) int XGetErrorDatabaseText(_XDisplay *, char *, char *, char *, char *, int);
extern(System) int XGetErrorText(_XDisplay *, int, char *, int);
extern(System) int XGetEventData(_XDisplay *, XGenericEventCookie *);
extern(System) int XGetFontProperty(XFontStruct *, int, int *);
extern(System) int XGetGCValues(_XDisplay *, _XGC *, int, XGCValues *);
extern(System) int XGetGeometry(_XDisplay *, int, int *, int *, int *, uint *, uint *, uint *, uint *);
extern(System) int XGetIconName(_XDisplay *, int, char * *);
extern(System) int XGetIconSizes(_XDisplay *, int, XIconSize * *, int *);
extern(System) int XGetInputFocus(_XDisplay *, int *, int *);
extern(System) int XGetKeyboardControl(_XDisplay *, XKeyboardState *);
extern(System) int * XGetKeyboardMapping(_XDisplay *, ubyte, int, int *);
extern(System) int XGetNormalHints(_XDisplay *, int, XSizeHints *);
extern(System) int XGetPointerControl(_XDisplay *, int *, int *, int *);
extern(System) int XGetPointerMapping(_XDisplay *, ubyte *, int);
extern(System) int XGetRGBColormaps(_XDisplay *, int, XStandardColormap * *, int *, int);
extern(System) int XGetScreenSaver(_XDisplay *, int *, int *, int *, int *);
extern(System) int XGetSelectionOwner(_XDisplay *, int);
extern(System) int XGetSizeHints(_XDisplay *, int, XSizeHints *, int);
extern(System) int XGetStandardColormap(_XDisplay *, int, XStandardColormap *, int);
extern(System) int XGetZoomHints(_XDisplay *, int, XSizeHints *);
extern(System) int XGetTextProperty(_XDisplay *, int, XTextProperty *, int);
extern(System) int XGetTransientForHint(_XDisplay *, int, int *);
extern(System) int XGetWindowAttributes(_XDisplay *, int, XWindowAttributes *);
extern(System) int XGetWindowProperty(_XDisplay *, int, int, int, int, int, int, int *, int *, int *, int *, ubyte * *);
extern(System) int XGetWMClientMachine(_XDisplay *, int, XTextProperty *);
extern(System) int XGetWMColormapWindows(_XDisplay *, int, int * *, int *);
extern(System) int XGetWMIconName(_XDisplay *, int, XTextProperty *);
extern(System) int XGetWMName(_XDisplay *, int, XTextProperty *);
extern(System) int XGetWMNormalHints(_XDisplay *, int, XSizeHints *, int *);
extern(System) int XGetWMProtocols(_XDisplay *, int, int * *, int *);
extern(System) int XGetWMSizeHints(_XDisplay *, int, XSizeHints *, int *, int);
extern(System) int XGrabButton(_XDisplay *, uint, uint, int, int, uint, int, int, int, int);
extern(System) int XGrabKeyboard(_XDisplay *, int, int, int, int, int);
extern(System) int XGrabKey(_XDisplay *, int, uint, int, int, int, int);
extern(System) int XGrabPointer(_XDisplay *, int, int, uint, int, int, int, int, int);
extern(System) int XGrabServer(_XDisplay *);
extern(System) int XHeightMMOfScreen(Screen *);
extern(System) int XHeightOfScreen(Screen *);
extern(System) int XIconifyWindow(_XDisplay *, int, int);
extern(System) int XIfEvent(_XDisplay *, _XEvent *, int function(_XDisplay *, _XEvent *, char *) *, char *);
extern(System) int XImageByteOrder(_XDisplay *);
extern(System) int XInitImage(_XImage *);
extern(System) int XInitThreads();
extern(System) int XInstallColormap(_XDisplay *, int);
extern(System) int XInternalConnectionNumbers(_XDisplay *, int * *, int *);
extern(System) int XInternAtoms(_XDisplay *, char * *, int, int, int *);
extern(System) int XInternAtom(_XDisplay *, char *, int);
extern(System) int XIntersectRegion(_XRegion *, _XRegion *, _XRegion *);
extern(System) int XKeycodeToKeysym(_XDisplay *, ubyte, int);
extern(System) int XKillClient(_XDisplay *, int);
extern(System) int XLastKnownRequestProcessed(_XDisplay *);
extern(System) int * XListDepths(_XDisplay *, int, int *);
extern(System) int * XListInstalledColormaps(_XDisplay *, int, int *);
extern(System) int * XListProperties(_XDisplay *, int, int *);
extern(System) int XLoadFont(_XDisplay *, char *);
extern(System) int XLookupColor(_XDisplay *, int, char *, XColor *, XColor *);
extern(System) int XLookupKeysym(XKeyEvent *, int);
extern(System) int XLookupString(XKeyEvent *, char *, int, int *, _XComposeStatus *);
extern(System) int XLowerWindow(_XDisplay *, int);
extern(System) int XMapRaised(_XDisplay *, int);
extern(System) int XMapSubwindows(_XDisplay *, int);
extern(System) int XMapWindow(_XDisplay *, int);
extern(System) int XMaskEvent(_XDisplay *, int, _XEvent *);
extern(System) int XMatchVisualInfo(_XDisplay *, int, int, int, XVisualInfo *);
extern(System) int XMaxCmapsOfScreen(Screen *);
extern(System) int XMaxRequestSize(_XDisplay *);
extern(System) int _Xmblen(char * str, int len);
extern(System) int XmbLookupString(_XIC *, XKeyEvent *, char *, int, int *, int *);
extern(System) int XmbTextEscapement(_XOC *, char *, int);
extern(System) int XmbTextExtents(_XOC *, char *, int, XRectangle *, XRectangle *);
extern(System) int XmbTextListToTextProperty(_XDisplay * display, char * * list, int count, XICCEncodingStyle style, XTextProperty * text_prop_return);
extern(System) int XmbTextPerCharExtents(_XOC *, char *, int, XRectangle *, XRectangle *, int, int *, XRectangle *, XRectangle *);
extern(System) int XmbTextPropertyToTextList(_XDisplay * display, XTextProperty * text_prop, char * * * list_return, int * count_return);
extern(System) int _Xmbtowc(dchar *, char *, int);
extern(System) int XMinCmapsOfScreen(Screen *);
extern(System) int XMoveResizeWindow(_XDisplay *, int, int, int, uint, uint);
extern(System) int XMoveWindow(_XDisplay *, int, int, int);
extern(System) int XmuAppendSegment(_XmuSegment *, _XmuSegment *);
extern(System) int XmuCompareISOLatin1(char * first, char * second);
extern(System) int XmuCreatePixmapFromBitmap(_XDisplay * dpy, int d, int bitmap, uint width, uint height, uint depth, int fore, int back);
extern(System) int XmuCreateStippledPixmap(Screen * screen, int fore, int back, uint depth);
extern(System) int XmuInternAtom(_XDisplay * dpy, _AtomRec * atom_ptr);
extern(System) int XmuLocateBitmapFile(Screen * screen, char * name, char * srcname_return, int srcnamelen, int * width_return, int * height_return, int * xhot_return, int * yhot_return);
extern(System) int XmuLocatePixmapFile(Screen * screen, char * name, int fore, int back, uint depth, char * srcname_return, int srcnamelen, int * width_return, int * height_return, int * xhot_return, int * yhot_return);
extern(System) int XmuPrintDefaultErrorMessage(_XDisplay * dpy, XErrorEvent * event, _IO_FILE * fp);
extern(System) int XmuReadBitmapDataFromFile(char * filename, uint * width_return, uint * height_return, ubyte * * datap_return, int * xhot_return, int * yhot_return);
extern(System) int XmuReadBitmapData(_IO_FILE * fstream, uint * width_return, uint * height_return, ubyte * * datap_return, int * xhot_return, int * yhot_return);
extern(System) int XmuScanlineEqu(_XmuScanline *, _XmuScanline *);
extern(System) int XmuSimpleErrorHandler(_XDisplay * dpy, XErrorEvent * errorp);
extern(System) int XmuSnprintf(char * str, int size, char * fmt);
extern(System) int XmuValidArea(_XmuArea *);
extern(System) int XmuValidScanline(_XmuScanline *);
extern(System) int XmuWnCountOwnedResources(_XmuWidgetNode * node, _XmuWidgetNode * ownernode, int constraints);
extern(System) int XNextEvent(_XDisplay *, _XEvent *);
extern(System) int XNextRequest(_XDisplay *);
extern(System) int XNoOp(_XDisplay *);
extern(System) int XOffsetRegion(_XRegion *, int, int);
extern(System) int XParseColor(_XDisplay *, int, char *, XColor *);
extern(System) int XParseGeometry(char *, int *, int *, uint *, uint *);
extern(System) int XPeekEvent(_XDisplay *, _XEvent *);
extern(System) int XPeekIfEvent(_XDisplay *, _XEvent *, int function(_XDisplay *, _XEvent *, char *) *, char *);
extern(System) int XPending(_XDisplay *);
extern(System) int XPlanesOfScreen(Screen *);
extern(System) int XPointInRegion(_XRegion *, int, int);
extern(System) int XProtocolRevision(_XDisplay *);
extern(System) int XProtocolVersion(_XDisplay *);
extern(System) int XPutBackEvent(_XDisplay *, _XEvent *);
extern(System) int XPutImage(_XDisplay *, int, _XGC *, _XImage *, int, int, int, int, uint, uint);
extern(System) int XQLength(_XDisplay *);
extern(System) int XQueryBestCursor(_XDisplay *, int, uint, uint, uint *, uint *);
extern(System) int XQueryBestSize(_XDisplay *, int, int, uint, uint, uint *, uint *);
extern(System) int XQueryBestStipple(_XDisplay *, int, uint, uint, uint *, uint *);
extern(System) int XQueryBestTile(_XDisplay *, int, uint, uint, uint *, uint *);
extern(System) int XQueryColors(_XDisplay *, int, XColor *, int);
extern(System) int XQueryColor(_XDisplay *, int, XColor *);
extern(System) int XQueryExtension(_XDisplay *, char *, int *, int *, int *);
extern(System) int XQueryKeymap(_XDisplay *, char *);
extern(System) int XQueryPointer(_XDisplay *, int, int *, int *, int *, int *, int *, int *, uint *);
extern(System) int XQueryTextExtents16(_XDisplay *, int, XChar2b *, int, int *, int *, int *, XCharStruct *);
extern(System) int XQueryTextExtents(_XDisplay *, int, char *, int, int *, int *, int *, XCharStruct *);
extern(System) int XQueryTree(_XDisplay *, int, int *, int *, int * *, uint *);
extern(System) int XRaiseWindow(_XDisplay *, int);
extern(System) int XReadBitmapFileData(char *, uint *, uint *, ubyte * *, int *, int *);
extern(System) int XReadBitmapFile(_XDisplay *, int, char *, uint *, uint *, int *, int *, int *);
extern(System) int XRebindKeysym(_XDisplay *, int, int *, int, ubyte *, int);
extern(System) int XRecolorCursor(_XDisplay *, int, XColor *, XColor *);
extern(System) int XReconfigureWMWindow(_XDisplay *, int, int, uint, XWindowChanges *);
extern(System) int XRectInRegion(_XRegion *, int, int, uint, uint);
extern(System) int XRefreshKeyboardMapping(XMappingEvent *);
extern(System) int XRegisterIMInstantiateCallback(_XDisplay *, _XrmHashBucketRec *, char *, char *, void function(_XDisplay *, char *, char *) *, char *);
extern(System) int XRemoveFromSaveSet(_XDisplay *, int);
extern(System) int XRemoveHosts(_XDisplay *, XHostAddress *, int);
extern(System) int XRemoveHost(_XDisplay *, XHostAddress *);
extern(System) int XReparentWindow(_XDisplay *, int, int, int, int);
extern(System) int XResetScreenSaver(_XDisplay *);
extern(System) int XResizeWindow(_XDisplay *, int, uint, uint);
extern(System) int XRestackWindows(_XDisplay *, int *, int);
extern(System) int XrmCombineFileDatabase(char *, _XrmHashBucketRec * *, int);
extern(System) int XrmEnumerateDatabase(_XrmHashBucketRec *, int *, int *, int, int function(_XrmHashBucketRec * *, XrmBinding *, int *, int *, XrmValue *, char *) *, char *);
extern(System) int XrmGetResource(_XrmHashBucketRec *, char *, char *, char * *, XrmValue *);
extern(System) int XrmPermStringToQuark(char *);
extern(System) int XrmQGetResource(_XrmHashBucketRec *, int *, int *, int *, XrmValue *);
extern(System) int XrmQGetSearchList(_XrmHashBucketRec *, int *, int *, _XrmHashBucketRec * * *, int);
extern(System) int XrmQGetSearchResource(_XrmHashBucketRec * * *, int, int, int *, XrmValue *);
extern(System) int XrmStringToQuark(char *);
extern(System) int XrmUniqueQuark();
extern(System) int XRootWindowOfScreen(Screen *);
extern(System) int XRootWindow(_XDisplay *, int);
extern(System) int XRotateBuffers(_XDisplay *, int);
extern(System) int XRotateWindowProperties(_XDisplay *, int, int *, int, int);
extern(System) int XSaveContext(_XDisplay *, int, int, char *);
extern(System) int XScreenCount(_XDisplay *);
extern(System) int XScreenNumberOfScreen(Screen *);
extern(System) int XSelectInput(_XDisplay *, int, int);
extern(System) int XSendEvent(_XDisplay *, int, int, int, _XEvent *);
extern(System) int XSetAccessControl(_XDisplay *, int);
extern(System) int XSetArcMode(_XDisplay *, _XGC *, int);
extern(System) int XSetBackground(_XDisplay *, _XGC *, int);
extern(System) int XSetClassHint(_XDisplay *, int, XClassHint *);
extern(System) int XSetClipMask(_XDisplay *, _XGC *, int);
extern(System) int XSetClipOrigin(_XDisplay *, _XGC *, int, int);
extern(System) int XSetClipRectangles(_XDisplay *, _XGC *, int, int, XRectangle *, int, int);
extern(System) int XSetCloseDownMode(_XDisplay *, int);
extern(System) int XSetCommand(_XDisplay *, int, char * *, int);
extern(System) int XSetDashes(_XDisplay *, _XGC *, int, char *, int);
extern(System) int XSetFillRule(_XDisplay *, _XGC *, int);
extern(System) int XSetFillStyle(_XDisplay *, _XGC *, int);
extern(System) int XSetFontPath(_XDisplay *, char * *, int);
extern(System) int XSetFont(_XDisplay *, _XGC *, int);
extern(System) int XSetForeground(_XDisplay *, _XGC *, int);
extern(System) int XSetFunction(_XDisplay *, _XGC *, int);
extern(System) int XSetGraphicsExposures(_XDisplay *, _XGC *, int);
extern(System) int XSetIconName(_XDisplay *, int, char *);
extern(System) int XSetIconSizes(_XDisplay *, int, XIconSize *, int);
extern(System) int XSetInputFocus(_XDisplay *, int, int, int);
extern(System) int XSetLineAttributes(_XDisplay *, _XGC *, uint, int, int, int);
extern(System) int XSetModifierMapping(_XDisplay *, XModifierKeymap *);
extern(System) int XSetNormalHints(_XDisplay *, int, XSizeHints *);
extern(System) int XSetPlaneMask(_XDisplay *, _XGC *, int);
extern(System) int XSetPointerMapping(_XDisplay *, ubyte *, int);
extern(System) int XSetRegion(_XDisplay *, _XGC *, _XRegion *);
extern(System) int XSetScreenSaver(_XDisplay *, int, int, int, int);
extern(System) int XSetSelectionOwner(_XDisplay *, int, int, int);
extern(System) int XSetSizeHints(_XDisplay *, int, XSizeHints *, int);
extern(System) int XSetStandardProperties(_XDisplay *, int, char *, char *, int, char * *, int, XSizeHints *);
extern(System) int XSetState(_XDisplay *, _XGC *, int, int, int, int);
extern(System) int XSetStipple(_XDisplay *, _XGC *, int);
extern(System) int XSetSubwindowMode(_XDisplay *, _XGC *, int);
extern(System) int XSetZoomHints(_XDisplay *, int, XSizeHints *);
extern(System) int XSetTile(_XDisplay *, _XGC *, int);
extern(System) int XSetTransientForHint(_XDisplay *, int, int);
extern(System) int XSetTSOrigin(_XDisplay *, _XGC *, int, int);
extern(System) int XSetWindowBackgroundPixmap(_XDisplay *, int, int);
extern(System) int XSetWindowBackground(_XDisplay *, int, int);
extern(System) int XSetWindowBorderPixmap(_XDisplay *, int, int);
extern(System) int XSetWindowBorderWidth(_XDisplay *, int, uint);
extern(System) int XSetWindowBorder(_XDisplay *, int, int);
extern(System) int XSetWindowColormap(_XDisplay *, int, int);
extern(System) int XSetWMColormapWindows(_XDisplay *, int, int *, int);
extern(System) int XSetWMHints(_XDisplay *, int, XWMHints *);
extern(System) int XSetWMProtocols(_XDisplay *, int, int *, int);
extern(System) int XShrinkRegion(_XRegion *, int, int);
extern(System) int XStoreBuffer(_XDisplay *, char *, int, int);
extern(System) int XStoreBytes(_XDisplay *, char *, int);
extern(System) int XStoreColors(_XDisplay *, int, XColor *, int);
extern(System) int XStoreColor(_XDisplay *, int, XColor *);
extern(System) int XStoreNamedColor(_XDisplay *, int, char *, int, int);
extern(System) int XStoreName(_XDisplay *, int, char *);
extern(System) int XStringListToTextProperty(char * *, int, XTextProperty *);
extern(System) int XStringToKeysym(char *);
extern(System) int XSubtractRegion(_XRegion *, _XRegion *, _XRegion *);
extern(System) int XSupportsLocale();
extern(System) int XSync(_XDisplay *, int);
extern(System) int XtAddInput(int, void *, void function(void *, int *, int *) *, void *);
extern(System) int XtAddSignal(void function(void *, int *) *, void *);
extern(System) int XtAddTimeOut(int, void function(void *, int *) *, void *);
extern(System) int XtAddWorkProc(char function(void *) *, void *);
extern(System) int XtAppAddBlockHook(_XtAppStruct *, void function(void *) *, void *);
extern(System) int XtAppAddInput(_XtAppStruct *, int, void *, void function(void *, int *, int *) *, void *);
extern(System) int XtAppAddSignal(_XtAppStruct *, void function(void *, int *) *, void *);
extern(System) int XtAppAddTimeOut(_XtAppStruct *, int, void function(void *, int *) *, void *);
extern(System) int XtAppAddWorkProc(_XtAppStruct *, char function(void *) *, void *);
extern(System) int XtAppGetSelectionTimeout(_XtAppStruct *);
extern(System) int XtAppPending(_XtAppStruct *);
extern(System) int XtBuildEventMask(_WidgetRec *);
extern(System) int XTextExtents16(XFontStruct *, XChar2b *, int, int *, int *, int *, XCharStruct *);
extern(System) int XTextExtents(XFontStruct *, char *, int, int *, int *, int *, XCharStruct *);
extern(System) int XTextPropertyToStringList(XTextProperty *, char * * *, int *);
extern(System) int XTextWidth16(XFontStruct *, XChar2b *, int);
extern(System) int XTextWidth(XFontStruct *, char *, int);
extern(System) int XtGetActionKeysym(_XEvent *, uint *);
extern(System) int * XtGetKeysymTable(_XDisplay *, ubyte *, int *);
extern(System) int XtGetMultiClickTime(_XDisplay *);
extern(System) int XtGetSelectionTimeout();
extern(System) int XtGrabKeyboard(_WidgetRec *, char, int, int, int);
extern(System) int XtGrabPointer(_WidgetRec *, char, uint, int, int, int, int, int);
extern(System) int XtLastTimestampProcessed(_XDisplay *);
extern(System) int XTranslateCoordinates(_XDisplay *, int, int, int, int, int *, int *, int *);
extern(System) int XtReservePropertyAtom(_WidgetRec *);
extern(System) int XtWindowOfObject(_WidgetRec *);
extern(System) int XtWindow(_WidgetRec *);
extern(System) int XUndefineCursor(_XDisplay *, int);
extern(System) int XUngrabButton(_XDisplay *, uint, uint, int);
extern(System) int XUngrabKeyboard(_XDisplay *, int);
extern(System) int XUngrabKey(_XDisplay *, int, uint, int);
extern(System) int XUngrabPointer(_XDisplay *, int);
extern(System) int XUngrabServer(_XDisplay *);
extern(System) int XUninstallColormap(_XDisplay *, int);
extern(System) int XUnionRectWithRegion(XRectangle *, _XRegion *, _XRegion *);
extern(System) int XUnionRegion(_XRegion *, _XRegion *, _XRegion *);
extern(System) int XUnloadFont(_XDisplay *, int);
extern(System) int XUnmapSubwindows(_XDisplay *, int);
extern(System) int XUnmapWindow(_XDisplay *, int);
extern(System) int XUnregisterIMInstantiateCallback(_XDisplay *, _XrmHashBucketRec *, char *, char *, void function(_XDisplay *, char *, char *) *, char *);
extern(System) int Xutf8LookupString(_XIC *, XKeyEvent *, char *, int, int *, int *);
extern(System) int Xutf8TextEscapement(_XOC *, char *, int);
extern(System) int Xutf8TextExtents(_XOC *, char *, int, XRectangle *, XRectangle *);
extern(System) int Xutf8TextListToTextProperty(_XDisplay * display, char * * list, int count, XICCEncodingStyle style, XTextProperty * text_prop_return);
extern(System) int Xutf8TextPerCharExtents(_XOC *, char *, int, XRectangle *, XRectangle *, int, int *, XRectangle *, XRectangle *);
extern(System) int Xutf8TextPropertyToTextList(_XDisplay * display, XTextProperty * text_prop, char * * * list_return, int * count_return);
extern(System) int XWarpPointer(_XDisplay *, int, int, int, int, uint, uint, int, int);
extern(System) int XwcLookupString(_XIC *, XKeyEvent *, dchar *, int, int *, int *);
extern(System) int XwcTextEscapement(_XOC *, dchar *, int);
extern(System) int XwcTextExtents(_XOC *, dchar *, int, XRectangle *, XRectangle *);
extern(System) int XwcTextListToTextProperty(_XDisplay * display, dchar * * list, int count, XICCEncodingStyle style, XTextProperty * text_prop_return);
extern(System) int XwcTextPerCharExtents(_XOC *, dchar *, int, XRectangle *, XRectangle *, int, int *, XRectangle *, XRectangle *);
extern(System) int XwcTextPropertyToTextList(_XDisplay * display, XTextProperty * text_prop, dchar * * * list_return, int * count_return);
extern(System) int _Xwctomb(char *, dchar);
extern(System) int XVendorRelease(_XDisplay *);
extern(System) int XWhitePixelOfScreen(Screen *);
extern(System) int XWhitePixel(_XDisplay *, int);
extern(System) int XWidthMMOfScreen(Screen *);
extern(System) int XWidthOfScreen(Screen *);
extern(System) int XWindowEvent(_XDisplay *, int, int, _XEvent *);
extern(System) int XVisualIDFromVisual(Visual *);
extern(System) int XWithdrawWindow(_XDisplay *, int, int);
extern(System) int XWMGeometry(_XDisplay *, int, char *, char *, uint, XSizeHints *, int *, int *, int *, int *, int *);
extern(System) int XWriteBitmapFile(_XDisplay *, char *, int, uint, uint, int, int);
extern(System) int XXorRegion(_XRegion *, _XRegion *, _XRegion *);
extern(System) Screen * XDefaultScreenOfDisplay(_XDisplay *);
extern(System) Screen * XScreenOfDisplay(_XDisplay *, int);
extern(System) Screen * XtScreenOfObject(_WidgetRec *);
extern(System) Screen * XtScreen(_WidgetRec *);
extern(System) SmcCloseStatus SmcCloseConnection(_SmcConn *, int, char * *);
extern(System) _SmcConn * SmcOpenConnection(char *, void *, int, int, int, SmcCallbacks *, char *, char * *, int, char *);
extern(System) _TranslationData * XtParseAcceleratorTable(char *);
extern(System) _TranslationData * XtParseTranslationTable(char *);
extern(System) ubyte XKeysymToKeycode(_XDisplay *, int);
extern(System) uint XtAsprintf(char * * new_string, char * format);
extern(System) ushort _XawImGetShellHeight(_WidgetRec * w);
extern(System) _WidgetClassRec * XtClass(_WidgetRec *);
extern(System) _WidgetClassRec * XtSuperclass(_WidgetRec *);
extern(System) _WidgetRec * XawOpenApplication(_XtAppStruct * * app_context_return, _XDisplay * dpy, Screen * screen, char * application_name, char * application_class, _WidgetClassRec * widget_class, int * argc, char * * argv);
extern(System) _WidgetRec * XawSimpleMenuGetActiveEntry(_WidgetRec * w);
extern(System) _WidgetRec * XawTextGetSink(_WidgetRec * w);
extern(System) _WidgetRec * XawTextGetSource(_WidgetRec * w);
extern(System) _WidgetRec * XtAppCreateShell(char *, char *, _WidgetClassRec *, _XDisplay *, Arg *, uint);
extern(System) _WidgetRec * XtAppInitialize(_XtAppStruct * *, char *, XrmOptionDescRec *, uint, int *, char * *, char * *, Arg *, uint);
extern(System) _WidgetRec * XtCreateApplicationShell(char *, _WidgetClassRec *, Arg *, uint);
extern(System) _WidgetRec * XtCreateManagedWidget(char *, _WidgetClassRec *, _WidgetRec *, Arg *, uint);
extern(System) _WidgetRec * XtCreatePopupShell(char *, _WidgetClassRec *, _WidgetRec *, Arg *, uint);
extern(System) _WidgetRec * XtCreateWidget(char *, _WidgetClassRec *, _WidgetRec *, Arg *, uint);
extern(System) _WidgetRec * XtGetKeyboardFocusWidget(_WidgetRec *);
extern(System) _WidgetRec * XtHooksOfDisplay(_XDisplay *);
extern(System) _WidgetRec * XtInitialize(char *, char *, XrmOptionDescRec *, uint, int *, char * *);
extern(System) _WidgetRec * XtNameToWidget(_WidgetRec *, char *);
extern(System) _WidgetRec * XtOpenApplication(_XtAppStruct * *, char *, XrmOptionDescRec *, uint, int *, char * *, char * *, _WidgetClassRec *, Arg *, uint);
extern(System) _WidgetRec * XtParent(_WidgetRec *);
extern(System) _WidgetRec * XtVaAppCreateShell(char *, char *, _WidgetClassRec *, _XDisplay *);
extern(System) _WidgetRec * XtVaAppInitialize(_XtAppStruct * *, char *, XrmOptionDescRec *, uint, int *, char * *, char * *);
extern(System) _WidgetRec * XtVaCreateManagedWidget(char *, _WidgetClassRec *, _WidgetRec *);
extern(System) _WidgetRec * XtVaCreatePopupShell(char *, _WidgetClassRec *, _WidgetRec *);
extern(System) _WidgetRec * XtVaCreateWidget(char *, _WidgetClassRec *, _WidgetRec *);
extern(System) _WidgetRec * XtVaOpenApplication(_XtAppStruct * *, char *, XrmOptionDescRec *, uint, int *, char * *, char * *, _WidgetClassRec *);
extern(System) _WidgetRec * _XtWindowedAncestor(_WidgetRec *);
extern(System) _WidgetRec * XtWindowToWidget(_XDisplay *, int);
extern(System) Visual * XDefaultVisualOfScreen(Screen *);
extern(System) Visual * XDefaultVisual(_XDisplay *, int);
extern(System) void function(char *, char *, char *, char *, char * *, uint *) * XtAppSetErrorMsgHandler(_XtAppStruct *, void function(char *, char *, char *, char *, char * *, uint *) *);
extern(System) void function(char *, char *, char *, char *, char * *, uint *) * XtAppSetWarningMsgHandler(_XtAppStruct *, void function(char *, char *, char *, char *, char * *, uint *) *);
extern(System) void function(char *) * XtAppSetErrorHandler(_XtAppStruct *, void function(char *) *);
extern(System) void function(char *) * XtAppSetWarningHandler(_XtAppStruct *, void function(char *) *);
extern(System) void function(_IceConn *) * IceSetIOErrorHandler(void function(_IceConn *) *);
extern(System) void function(_IceConn *, int, int, int, int, int, void *) * IceSetErrorHandler(void function(_IceConn *, int, int, int, int, int, void *) *);
extern(System) void function(_SmcConn *, int, int, int, int, int, void *) * SmcSetErrorHandler(void function(_SmcConn *, int, int, int, int, int, void *) *);
extern(System) void function(_SmsConn *, int, int, int, int, int, void *) * SmsSetErrorHandler(void function(_SmsConn *, int, int, int, int, int, void *) *);
extern(System) void IceAppLockConn(_IceConn *);
extern(System) void IceAppUnlockConn(_IceConn *);
extern(System) void IceFreeListenObjs(int, _IceListenObj * *);
extern(System) void * IceGetConnectionContext(_IceConn *);
extern(System) void IceRemoveConnectionWatch(void function(_IceConn *, void *, int, void * *) *, void *);
extern(System) void IceSetHostBasedAuthProc(_IceListenObj *, int function(char *) *);
extern(System) void IceSetShutdownNegotiation(_IceConn *, int);
extern(System) void SmcDeleteProperties(_SmcConn *, int, char * *);
extern(System) void SmcInteractDone(_SmcConn *, int);
extern(System) void SmcModifyCallbacks(_SmcConn *, int, SmcCallbacks *);
extern(System) void SmcRequestSaveYourself(_SmcConn *, int, int, int, int, int);
extern(System) void SmcSaveYourselfDone(_SmcConn *, int);
extern(System) void SmcSetProperties(_SmcConn *, int, SmProp * *);
extern(System) void SmFreeProperty(SmProp *);
extern(System) void SmFreeReasons(int, char * *);
extern(System) void SmsCleanUp(_SmsConn *);
extern(System) void SmsDie(_SmsConn *);
extern(System) void SmsInteract(_SmsConn *);
extern(System) void SmsReturnProperties(_SmsConn *, int, SmProp * *);
extern(System) void SmsSaveComplete(_SmsConn *);
extern(System) void SmsSaveYourselfPhase2(_SmsConn *);
extern(System) void SmsSaveYourself(_SmsConn *, int, int, int, int);
extern(System) void SmsShutdownCancelled(_SmsConn *);
extern(System) void XawAsciiSourceFreeString(_WidgetRec * w);
extern(System) void XawDialogAddButton(_WidgetRec * dialog, char * name, void function(_WidgetRec *, void *, void *) * function_, void * client_data);
extern(System) void XawFormDoLayout(_WidgetRec * w, char do_layout);
extern(System) void _XawImCallVendorShellExtResize(_WidgetRec * w);
extern(System) void _XawImDestroy(_WidgetRec * w, _WidgetRec * ext);
extern(System) void _XawImInitialize(_WidgetRec * w, _WidgetRec * ext);
extern(System) void _XawImRealize(_WidgetRec * w);
extern(System) void _XawImReconnect(_WidgetRec * w);
extern(System) void _XawImRegister(_WidgetRec * w);
extern(System) void _XawImResizeVendorShell(_WidgetRec * w);
extern(System) void _XawImSetFocusValues(_WidgetRec * w, Arg * args, uint num_args);
extern(System) void _XawImSetValues(_WidgetRec * w, Arg * args, uint num_args);
extern(System) void _XawImUnregister(_WidgetRec * w);
extern(System) void _XawImUnsetFocus(_WidgetRec * w);
extern(System) void XawInitializeDefaultConverters();
extern(System) void XawInitializeWidgetSet();
extern(System) void XawListChange(_WidgetRec * w, char * * list, int nitems, int longest, char resize);
extern(System) void XawListHighlight(_WidgetRec * w, int item);
extern(System) void XawListUnhighlight(_WidgetRec * w);
extern(System) void _XawMultiSinkPosToXY(_WidgetRec * w, int pos, short * x, short * y);
extern(System) void _XawMultiSourceFreeString(_WidgetRec * w);
extern(System) void XawMultiSourceFreeString(_WidgetRec * w);
extern(System) void XawPanedAllowResize(_WidgetRec * w, char allow_resize);
extern(System) void XawPanedGetMinMax(_WidgetRec * w, int * min_return, int * max_return);
extern(System) void XawPanedSetMinMax(_WidgetRec * w, int min, int max);
extern(System) void XawPanedSetRefigureMode(_WidgetRec * w, char mode);
extern(System) void XawScrollbarSetThumb(_WidgetRec * scrollbar, float top, float shown);
extern(System) void XawSimpleMenuAddGlobalActions(_XtAppStruct * app_con);
extern(System) void XawSimpleMenuClearActiveEntry(_WidgetRec * w);
extern(System) void _XawTextBuildLineTable(_TextRec * ctx, int top_pos, char force_rebuild);
extern(System) void XawTextDisableRedisplay(_WidgetRec * w);
extern(System) void XawTextDisplayCaret(_WidgetRec * w, char visible);
extern(System) void XawTextDisplay(_WidgetRec * w);
extern(System) void XawTextEnableRedisplay(_WidgetRec * w);
extern(System) void XawTextGetSelectionPos(_WidgetRec * w, int * begin_return, int * end_return);
extern(System) void XawTextInvalidate(_WidgetRec * w, int from, int to);
extern(System) void _XawTextNeedsUpdating(_TextRec * ctx, int left, int right);
extern(System) void _XawTextPosToXY(_WidgetRec * w, int pos, short * x, short * y);
extern(System) void _XawTextSaltAwaySelection(_TextRec * ctx, int * selections, int num_atoms);
extern(System) void XawTextSetInsertionPoint(_WidgetRec * w, int position);
extern(System) void XawTextSetSelectionArray(_WidgetRec * w, XawTextSelectType * sarray);
extern(System) void XawTextSetSelection(_WidgetRec * w, int left, int right);
extern(System) void XawTextSetSource(_WidgetRec * w, _WidgetRec * source, int top);
extern(System) void XawTextSinkClearToBackground(_WidgetRec * w, short x, short y, ushort width, ushort height);
extern(System) void XawTextSinkDisplayText(_WidgetRec * w, short x, short y, int pos1, int pos2, char highlight);
extern(System) void XawTextSinkDoPaint(_WidgetRec * w);
extern(System) void XawTextSinkFindDistance(_WidgetRec * w, int fromPos, int fromX, int toPos, int * width_return, int * pos_return, int * height_return);
extern(System) void XawTextSinkFindPosition(_WidgetRec * w, int fromPos, int fromX, int width, char stopAtWordBreak, int * pos_return, int * width_return, int * height_return);
extern(System) void XawTextSinkGetCursorBounds(_WidgetRec * w, XRectangle * rect_return);
extern(System) void XawTextSinkInsertCursor(_WidgetRec * w, short x, short y, XawTextInsertState state);
extern(System) void XawTextSinkPreparePaint(_WidgetRec * w, int y, int line, int from, int to, int highlight);
extern(System) void XawTextSinkResolve(_WidgetRec * w, int fromPos, int fromX, int width, int * pos_return);
extern(System) void XawTextSinkSetTabs(_WidgetRec * w, int tab_count, int * tabs);
extern(System) void XawTextSourceClearEntities(_WidgetRec * w, int left, int right);
extern(System) void XawTextSourceSetSelection(_WidgetRec * w, int start, int end, int selection);
extern(System) void XawTextUnsetSelection(_WidgetRec * w);
extern(System) void XawTipDisable(_WidgetRec * w);
extern(System) void XawTipEnable(_WidgetRec * w);
extern(System) void XawToggleChangeRadioGroup(_WidgetRec * w, _WidgetRec * radio_group);
extern(System) void * XawToggleGetCurrent(_WidgetRec * radio_group);
extern(System) void XawToggleSetCurrent(_WidgetRec * radio_group, void * radio_data);
extern(System) void XawToggleUnsetCurrent(_WidgetRec * radio_group);
extern(System) void XawTreeForceLayout(_WidgetRec * tree);
extern(System) void XawViewportSetCoordinates(_WidgetRec * gw, short x, short y);
extern(System) void XawViewportSetLocation(_WidgetRec * gw, float xoff, float yoff);
extern(System) void XConvertCase(int, int *, int *);
extern(System) void XDestroyIC(_XIC *);
extern(System) void XDestroyOC(_XOC *);
extern(System) void XFlushGC(_XDisplay *, _XGC *);
extern(System) void XFreeEventData(_XDisplay *, XGenericEventCookie *);
extern(System) void XFreeFontSet(_XDisplay *, _XOC *);
extern(System) void XFreeStringList(char * *);
extern(System) void XLockDisplay(_XDisplay *);
extern(System) void XmbDrawImageString(_XDisplay *, int, _XOC *, _XGC *, int, int, char *, int);
extern(System) void XmbDrawString(_XDisplay *, int, _XOC *, _XGC *, int, int, char *, int);
extern(System) void XmbDrawText(_XDisplay *, int, _XGC *, int, int, XmbTextItem *, int);
extern(System) void XmbSetWMProperties(_XDisplay *, int, char *, char *, char * *, int, XSizeHints *, XWMHints *, XClassHint *);
extern(System) void XmuCopyISOLatin1Lowered(char * dst_return, char * src);
extern(System) void XmuCopyISOLatin1Uppered(char * dst_return, char * src);
extern(System) void XmuCvtFunctionToCallback(XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal);
extern(System) void XmuCvtStringToBackingStore(XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal);
extern(System) void XmuCvtStringToBitmap(XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal);
extern(System) void XmuCvtStringToCursor(XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal);
extern(System) void XmuCvtStringToGravity(XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal);
extern(System) void XmuCvtStringToJustify(XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal);
extern(System) void XmuCvtStringToLong(XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal);
extern(System) void XmuCvtStringToOrientation(XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal);
extern(System) void XmuCvtStringToWidget(XrmValue * args, uint * num_args, XrmValue * fromVal, XrmValue * toVal);
extern(System) void XmuDestroyScanlineList(_XmuScanline *);
extern(System) void XmuDestroySegmentList(_XmuSegment *);
extern(System) void XmuDrawLogo(_XDisplay * dpy, int drawable, _XGC * gcFore, _XGC * gcBack, int x, int y, uint width, uint height);
extern(System) void XmuDrawRoundedRectangle(_XDisplay * dpy, int draw, _XGC * gc, int x, int y, int w, int h, int ew, int eh);
extern(System) void XmuFillRoundedRectangle(_XDisplay * dpy, int draw, _XGC * gc, int x, int y, int w, int h, int ew, int eh);
extern(System) void XmuInternStrings(_XDisplay * dpy, char * * names, uint count, int * atoms_return);
extern(System) void XmuNCopyISOLatin1Lowered(char * dst_return, char * src, int size);
extern(System) void XmuNCopyISOLatin1Uppered(char * dst_return, char * src, int size);
extern(System) void XmuReleaseStippledPixmap(Screen * screen, int pixmap);
extern(System) void XmuWnFetchResources(_XmuWidgetNode * node, _WidgetRec * toplevel, _XmuWidgetNode * topnode);
extern(System) void XmuWnInitializeNodes(_XmuWidgetNode * nodearray, int nnodes);
extern(System) void XProcessInternalConnection(_XDisplay *, int);
extern(System) void XRemoveConnectionWatch(_XDisplay *, void function(_XDisplay *, char *, int, int, char * *) *, char *);
extern(System) void XrmCombineDatabase(_XrmHashBucketRec *, _XrmHashBucketRec * *, int);
extern(System) void XrmDestroyDatabase(_XrmHashBucketRec *);
extern(System) void XrmInitialize();
extern(System) void XrmMergeDatabases(_XrmHashBucketRec *, _XrmHashBucketRec * *);
extern(System) void XrmParseCommand(_XrmHashBucketRec * *, XrmOptionDescRec *, int, char *, int *, char * *);
extern(System) void XrmPutFileDatabase(_XrmHashBucketRec *, char *);
extern(System) void XrmPutLineResource(_XrmHashBucketRec * *, char *);
extern(System) void XrmPutResource(_XrmHashBucketRec * *, char *, char *, XrmValue *);
extern(System) void XrmPutStringResource(_XrmHashBucketRec * *, char *, char *);
extern(System) void XrmQPutResource(_XrmHashBucketRec * *, XrmBinding *, int *, int, XrmValue *);
extern(System) void XrmQPutStringResource(_XrmHashBucketRec * *, XrmBinding *, int *, char *);
extern(System) void XrmSetDatabase(_XDisplay *, _XrmHashBucketRec *);
extern(System) void XrmStringToBindingQuarkList(char *, XrmBinding *, int *);
extern(System) void XrmStringToQuarkList(char *, int *);
extern(System) void XSetAuthorization(char *, int, char *, int);
extern(System) void XSetICFocus(_XIC *);
extern(System) void XSetRGBColormaps(_XDisplay *, int, XStandardColormap *, int, int);
extern(System) void XSetStandardColormap(_XDisplay *, int, XStandardColormap *, int);
extern(System) void XSetTextProperty(_XDisplay *, int, XTextProperty *, int);
extern(System) void XSetWMClientMachine(_XDisplay *, int, XTextProperty *);
extern(System) void XSetWMIconName(_XDisplay *, int, XTextProperty *);
extern(System) void XSetWMName(_XDisplay *, int, XTextProperty *);
extern(System) void XSetWMNormalHints(_XDisplay *, int, XSizeHints *);
extern(System) void XSetWMProperties(_XDisplay *, int, XTextProperty *, XTextProperty *, char * *, int, XSizeHints *, XWMHints *, XClassHint *);
extern(System) void XSetWMSizeHints(_XDisplay *, int, XSizeHints *, int);
extern(System) void XtAddActions(_XtActionsRec *, uint);
extern(System) void XtAddCallbacks(_WidgetRec *, char *, _XtCallbackRec *);
extern(System) void XtAddCallback(_WidgetRec *, char *, void function(_WidgetRec *, void *, void *) *, void *);
extern(System) void XtAddConverter(char *, char *, void function(XrmValue *, uint *, XrmValue *, XrmValue *) *, XtConvertArgRec *, uint);
extern(System) void XtAddEventHandler(_WidgetRec *, int, char, void function(_WidgetRec *, void *, _XEvent *, char *) *, void *);
extern(System) void XtAddExposureToRegion(_XEvent *, _XRegion *);
extern(System) void XtAddGrab(_WidgetRec *, char, char);
extern(System) void XtAddRawEventHandler(_WidgetRec *, int, char, void function(_WidgetRec *, void *, _XEvent *, char *) *, void *);
extern(System) void * XtAppAddActionHook(_XtAppStruct *, void function(_WidgetRec *, void *, char *, _XEvent *, char * *, uint *) *, void *);
extern(System) void XtAppAddActions(_XtAppStruct *, _XtActionsRec *, uint);
extern(System) void XtAppAddConverter(_XtAppStruct *, char *, char *, void function(XrmValue *, uint *, XrmValue *, XrmValue *) *, XtConvertArgRec *, uint);
extern(System) void XtAppErrorMsg(_XtAppStruct *, char *, char *, char *, char *, char * *, uint *);
extern(System) void XtAppError(_XtAppStruct *, char *);
extern(System) void XtAppGetErrorDatabaseText(_XtAppStruct *, char *, char *, char *, char *, char *, int, _XrmHashBucketRec *);
extern(System) void XtAppLock(_XtAppStruct *);
extern(System) void XtAppMainLoop(_XtAppStruct *);
extern(System) void XtAppNextEvent(_XtAppStruct *, _XEvent *);
extern(System) void XtAppProcessEvent(_XtAppStruct *, int);
extern(System) void XtAppReleaseCacheRefs(_XtAppStruct *, void * *);
extern(System) void XtAppSetExitFlag(_XtAppStruct *);
extern(System) void XtAppSetFallbackResources(_XtAppStruct *, char * *);
extern(System) void XtAppSetSelectionTimeout(_XtAppStruct *, int);
extern(System) void XtAppSetTypeConverter(_XtAppStruct *, char *, char *, char function(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *) *, XtConvertArgRec *, uint, int, void function(_XtAppStruct *, XrmValue *, void *, XrmValue *, uint *) *);
extern(System) void XtAppUnlock(_XtAppStruct *);
extern(System) void XtAppWarningMsg(_XtAppStruct *, char *, char *, char *, char *, char * *, uint *);
extern(System) void XtAppWarning(_XtAppStruct *, char *);
extern(System) void XtAugmentTranslations(_WidgetRec *, _TranslationData *);
extern(System) void XtCallActionProc(_WidgetRec *, char *, _XEvent *, char * *, uint);
extern(System) void XtCallbackExclusive(_WidgetRec *, void *, void *);
extern(System) void XtCallbackNone(_WidgetRec *, void *, void *);
extern(System) void XtCallbackNonexclusive(_WidgetRec *, void *, void *);
extern(System) void XtCallbackPopdown(_WidgetRec *, void *, void *);
extern(System) void XtCallbackReleaseCacheRefList(_WidgetRec *, void *, void *);
extern(System) void XtCallbackReleaseCacheRef(_WidgetRec *, void *, void *);
extern(System) void XtCallCallbackList(_WidgetRec *, _XtCallbackRec *, void *);
extern(System) void XtCallCallbacks(_WidgetRec *, char *, void *);
extern(System) void XtCancelSelectionRequest(_WidgetRec *, int);
extern(System) void XtChangeManagedSet(_WidgetRec * *, uint, void function(_WidgetRec *, _WidgetRec * *, uint *, _WidgetRec * *, uint *, void *) *, void *, _WidgetRec * *, uint);
extern(System) void XtCloseDisplay(_XDisplay *);
extern(System) void XtConfigureWidget(_WidgetRec *, short, short, ushort, ushort, ushort);
extern(System) void XtConvertCase(_XDisplay *, int, int *, int *);
extern(System) void XtConvert(_WidgetRec *, char *, XrmValue *, char *, XrmValue *);
extern(System) void XtCreateSelectionRequest(_WidgetRec *, int);
extern(System) void XtCreateWindow(_WidgetRec *, uint, Visual *, int, XSetWindowAttributes *);
extern(System) void XtDestroyApplicationContext(_XtAppStruct *);
extern(System) void XtDestroyGC(_XGC *);
extern(System) void XtDestroyWidget(_WidgetRec *);
extern(System) void XtDirectConvert(void function(XrmValue *, uint *, XrmValue *, XrmValue *) *, XrmValue *, uint, XrmValue *, XrmValue *);
extern(System) void XtDisownSelection(_WidgetRec *, int, int);
extern(System) void XtDisplayInitialize(_XtAppStruct *, _XDisplay *, char *, char *, XrmOptionDescRec *, uint, int *, char * *);
extern(System) void XtDisplayStringConversionWarning(_XDisplay *, char *, char *);
extern(System) void XtError(char *);
extern(System) void XtErrorMsg(char *, char *, char *, char *, char * *, uint *);
extern(System) void XtFree(char *);
extern(System) void XtGetActionList(_WidgetClassRec *, _XtActionsRec * *, uint *);
extern(System) void XtGetApplicationNameAndClass(_XDisplay *, char * *, char * *);
extern(System) void XtGetApplicationResources(_WidgetRec *, void *, _XtResource *, uint, Arg *, uint);
extern(System) void * XtGetClassExtension(_WidgetClassRec *, uint, int, int, uint);
extern(System) void XtGetConstraintResourceList(_WidgetClassRec *, _XtResource * *, uint *);
extern(System) void XtGetDisplays(_XtAppStruct *, _XDisplay * * *, uint *);
extern(System) void XtGetErrorDatabaseText(char *, char *, char *, char *, char *, int);
extern(System) void XtGetResourceList(_WidgetClassRec *, _XtResource * *, uint *);
extern(System) void XtGetSelectionParameters(_WidgetRec *, int, void *, int *, void * *, int *, int *);
extern(System) void XtGetSelectionValueIncremental(_WidgetRec *, int, int, void function(_WidgetRec *, void *, int *, int *, void *, int *, int *) *, void *, int);
extern(System) void XtGetSelectionValuesIncremental(_WidgetRec *, int, int *, int, void function(_WidgetRec *, void *, int *, int *, void *, int *, int *) *, void * *, int);
extern(System) void XtGetSelectionValues(_WidgetRec *, int, int *, int, void function(_WidgetRec *, void *, int *, int *, void *, int *, int *) *, void * *, int);
extern(System) void XtGetSelectionValue(_WidgetRec *, int, int, void function(_WidgetRec *, void *, int *, int *, void *, int *, int *) *, void *, int);
extern(System) void XtGetSubresources(_WidgetRec *, void *, char *, char *, _XtResource *, uint, Arg *, uint);
extern(System) void XtGetSubvalues(void *, _XtResource *, uint, Arg *, uint);
extern(System) void XtGetValues(_WidgetRec *, Arg *, uint);
extern(System) void XtGrabButton(_WidgetRec *, int, uint, char, uint, int, int, int, int);
extern(System) void XtGrabKey(_WidgetRec *, ubyte, uint, char, int, int);
extern(System) void _XtHandleFocus(_WidgetRec *, void *, _XEvent *, char *);
extern(System) void _XtInherit();
extern(System) void XtInitializeWidgetClass(_WidgetClassRec *);
extern(System) void XtInsertEventHandler(_WidgetRec *, int, char, void function(_WidgetRec *, void *, _XEvent *, char *) *, void *, XtListPosition);
extern(System) void XtInsertEventTypeHandler(_WidgetRec *, int, void *, void function(_WidgetRec *, void *, _XEvent *, char *) *, void *, XtListPosition);
extern(System) void XtInsertRawEventHandler(_WidgetRec *, int, char, void function(_WidgetRec *, void *, _XEvent *, char *) *, void *, XtListPosition);
extern(System) void XtInstallAccelerators(_WidgetRec *, _WidgetRec *);
extern(System) void XtInstallAllAccelerators(_WidgetRec *, _WidgetRec *);
extern(System) void XtKeysymToKeycodeList(_XDisplay *, int, ubyte * *, uint *);
extern(System) void XtMainLoop();
extern(System) void XtManageChildren(_WidgetRec * *, uint);
extern(System) void XtManageChild(_WidgetRec *);
extern(System) void XtMapWidget(_WidgetRec *);
extern(System) void XtMenuPopupAction(_WidgetRec *, _XEvent *, char * *, uint *);
extern(System) void XtMoveWidget(_WidgetRec *, short, short);
extern(System) void XtNextEvent(_XEvent *);
extern(System) void XtNoticeSignal(int);
extern(System) void XtOverrideTranslations(_WidgetRec *, _TranslationData *);
extern(System) void XtPopdown(_WidgetRec *);
extern(System) void XtPopupSpringLoaded(_WidgetRec *);
extern(System) void XtPopup(_WidgetRec *, XtGrabKind);
extern(System) void XtProcessEvent(int);
extern(System) void XtProcessLock();
extern(System) void XtProcessUnlock();
extern(System) void XtRealizeWidget(_WidgetRec *);
extern(System) void XtRegisterCaseConverter(_XDisplay *, void function(_XDisplay *, int, int *, int *) *, int, int);
extern(System) void XtRegisterDrawable(_XDisplay *, int, _WidgetRec *);
extern(System) void XtRegisterExtensionSelector(_XDisplay *, int, int, void function(_WidgetRec *, int *, void * *, int, void *) *, void *);
extern(System) void XtRegisterGrabAction(void function(_WidgetRec *, _XEvent *, char * *, uint *) *, char, uint, int, int);
extern(System) void XtReleaseGC(_WidgetRec *, _XGC *);
extern(System) void XtReleasePropertyAtom(_WidgetRec *, int);
extern(System) void XtRemoveActionHook(void *);
extern(System) void XtRemoveAllCallbacks(_WidgetRec *, char *);
extern(System) void XtRemoveBlockHook(int);
extern(System) void XtRemoveCallbacks(_WidgetRec *, char *, _XtCallbackRec *);
extern(System) void XtRemoveCallback(_WidgetRec *, char *, void function(_WidgetRec *, void *, void *) *, void *);
extern(System) void XtRemoveEventHandler(_WidgetRec *, int, char, void function(_WidgetRec *, void *, _XEvent *, char *) *, void *);
extern(System) void XtRemoveEventTypeHandler(_WidgetRec *, int, void *, void function(_WidgetRec *, void *, _XEvent *, char *) *, void *);
extern(System) void XtRemoveGrab(_WidgetRec *);
extern(System) void XtRemoveInput(int);
extern(System) void XtRemoveRawEventHandler(_WidgetRec *, int, char, void function(_WidgetRec *, void *, _XEvent *, char *) *, void *);
extern(System) void XtRemoveSignal(int);
extern(System) void XtRemoveTimeOut(int);
extern(System) void XtRemoveWorkProc(int);
extern(System) void XtResizeWidget(_WidgetRec *, ushort, ushort, ushort);
extern(System) void XtResizeWindow(_WidgetRec *);
extern(System) void _XtResourceConfigurationEH(_WidgetRec *, void *, _XEvent *);
extern(System) void XtSendSelectionRequest(_WidgetRec *, int, int);
extern(System) void XtSessionReturnToken(_XtCheckpointTokenRec *);
extern(System) void XtSetErrorHandler(void function(char *) *);
extern(System) void XtSetErrorMsgHandler(void function(char *, char *, char *, char *, char * *, uint *) *);
extern(System) void XtSetKeyboardFocus(_WidgetRec *, _WidgetRec *);
extern(System) void XtSetKeyTranslator(_XDisplay *, void function(_XDisplay *, ubyte, uint, uint *, int *) *);
extern(System) void XtSetMappedWhenManaged(_WidgetRec *, char);
extern(System) void XtSetMultiClickTime(_XDisplay *, int);
extern(System) void XtSetSelectionParameters(_WidgetRec *, int, int, void *, int, int);
extern(System) void XtSetSelectionTimeout(int);
extern(System) void XtSetSensitive(_WidgetRec *, char);
extern(System) void XtSetSubvalues(void *, _XtResource *, uint, Arg *, uint);
extern(System) void XtSetTypeConverter(char *, char *, char function(_XDisplay *, XrmValue *, uint *, XrmValue *, XrmValue *, void * *) *, XtConvertArgRec *, uint, int, void function(_XtAppStruct *, XrmValue *, void *, XrmValue *, uint *) *);
extern(System) void XtSetValues(_WidgetRec *, Arg *, uint);
extern(System) void XtSetWarningHandler(void function(char *) *);
extern(System) void XtSetWarningMsgHandler(void function(char *, char *, char *, char *, char * *, uint *) *);
extern(System) void XtSetWMColormapWindows(_WidgetRec *, _WidgetRec * *, uint);
extern(System) void XtStringConversionWarning(char *, char *);
extern(System) void XtToolkitInitialize();
extern(System) void XtTranslateCoords(_WidgetRec *, short, short, short *, short *);
extern(System) void XtTranslateKeycode(_XDisplay *, ubyte, uint, uint *, int *);
extern(System) void XtTranslateKey(_XDisplay *, ubyte, uint, uint *, int *);
extern(System) void XtUngrabButton(_WidgetRec *, uint, uint);
extern(System) void XtUngrabKeyboard(_WidgetRec *, int);
extern(System) void XtUngrabKey(_WidgetRec *, ubyte, uint);
extern(System) void XtUngrabPointer(_WidgetRec *, int);
extern(System) void XtUninstallTranslations(_WidgetRec *);
extern(System) void XtUnmanageChildren(_WidgetRec * *, uint);
extern(System) void XtUnmanageChild(_WidgetRec *);
extern(System) void XtUnmapWidget(_WidgetRec *);
extern(System) void XtUnrealizeWidget(_WidgetRec *);
extern(System) void XtUnregisterDrawable(_XDisplay *, int);
extern(System) void * XtVaCreateArgsList(void *);
extern(System) void XtVaGetApplicationResources(_WidgetRec *, void *, _XtResource *, uint);
extern(System) void XtVaGetSubresources(_WidgetRec *, void *, char *, char *, _XtResource *, uint);
extern(System) void XtVaGetSubvalues(void *, _XtResource *, uint);
extern(System) void XtVaGetValues(_WidgetRec *);
extern(System) void XtWarning(char *);
extern(System) void XtWarningMsg(char *, char *, char *, char *, char * *, uint *);
extern(System) void XtVaSetSubvalues(void *, _XtResource *, uint);
extern(System) void XtVaSetValues(_WidgetRec *);
extern(System) void XUnlockDisplay(_XDisplay *);
extern(System) void XUnsetICFocus(_XIC *);
extern(System) void Xutf8DrawImageString(_XDisplay *, int, _XOC *, _XGC *, int, int, char *, int);
extern(System) void Xutf8DrawString(_XDisplay *, int, _XOC *, _XGC *, int, int, char *, int);
extern(System) void Xutf8DrawText(_XDisplay *, int, _XGC *, int, int, XmbTextItem *, int);
extern(System) void Xutf8SetWMProperties(_XDisplay *, int, char *, char *, char * *, int, XSizeHints *, XWMHints *, XClassHint *);
extern(System) void * XVaCreateNestedList(int);
extern(System) void XwcDrawImageString(_XDisplay *, int, _XOC *, _XGC *, int, int, dchar *, int);
extern(System) void XwcDrawString(_XDisplay *, int, _XOC *, _XGC *, int, int, dchar *, int);
extern(System) void XwcDrawText(_XDisplay *, int, _XGC *, int, int, XwcTextItem *, int);
extern(System) void XwcFreeStringList(dchar * * list);
extern(System) _XawListReturnStruct * XawListShowCurrent(_WidgetRec * w);
extern(System) _XawTextAnchor * XawTextSourceAddAnchor(_WidgetRec * source, int position);
extern(System) _XawTextAnchor * XawTextSourceFindAnchor(_WidgetRec * source, int position);
extern(System) _XawTextAnchor * XawTextSourceNextAnchor(_WidgetRec * source, _XawTextAnchor * anchor);
extern(System) _XawTextAnchor * XawTextSourcePrevAnchor(_WidgetRec * source, _XawTextAnchor * anchor);
extern(System) _XawTextAnchor * XawTextSourceRemoveAnchor(_WidgetRec * source, _XawTextAnchor * anchor);
extern(System) _XawTextEntity * XawTextSourceAddEntity(_WidgetRec * source, int type, int flags, void * data, int position, uint length, int property);
extern(System) _XawTextPropertyList * XawTextSinkConvertPropertyList(char * name, char * spec, Screen * screen, int Colormap, int depth);
extern(System) _XawTextProperty * XawTextSinkAddProperty(_WidgetRec * w, _XawTextProperty * property);
extern(System) _XawTextProperty * XawTextSinkCombineProperty(_WidgetRec * w, _XawTextProperty * result_in_out, _XawTextProperty * property, int override_);
extern(System) _XawTextProperty * XawTextSinkCopyProperty(_WidgetRec * w, int property);
extern(System) _XawTextProperty * XawTextSinkGetProperty(_WidgetRec * w, int property);
extern(System) XClassHint * XAllocClassHint();
extern(System) _XDisplay * XDisplayOfIM(_XIM *);
extern(System) _XDisplay * XDisplayOfOM(_XOM *);
extern(System) _XDisplay * XDisplayOfScreen(Screen *);
extern(System) _XDisplay * XOpenDisplay(char *);
extern(System) _XDisplay * XtDisplayOfObject(_WidgetRec *);
extern(System) _XDisplay * XtDisplay(_WidgetRec *);
extern(System) _XDisplay * XtOpenDisplay(_XtAppStruct *, char *, char *, char *, XrmOptionDescRec *, uint, int *, char * *);
extern(System) _XEvent * XtLastEventProcessed(_XDisplay *);
extern(System) XExtCodes * XAddExtension(_XDisplay *);
extern(System) XExtCodes * XInitExtension(_XDisplay *, char *);
extern(System) _XExtData * * XEHeadOfExtensionList(XEDataObject);
extern(System) _XExtData * XFindOnExtensionList(_XExtData * *, int);
extern(System) XFontSetExtents * XExtentsOfFontSet(_XOC *);
extern(System) XFontStruct * XLoadQueryFont(_XDisplay *, char *);
extern(System) XFontStruct * XQueryFont(_XDisplay *, int);
extern(System) _XGC * XCreateGC(_XDisplay *, int, int, XGCValues *);
extern(System) _XGC * XDefaultGCOfScreen(Screen *);
extern(System) _XGC * XDefaultGC(_XDisplay *, int);
extern(System) _XGC * XtAllocateGC(_WidgetRec *, uint, int, XGCValues *, int, int);
extern(System) _XGC * XtGetGC(_WidgetRec *, int, XGCValues *);
extern(System) XHostAddress * XListHosts(_XDisplay *, int *, int *);
extern(System) XIconSize * XAllocIconSize();
extern(System) _XIC * XCreateIC(_XIM *);
extern(System) _XImage * XCreateImage(_XDisplay *, Visual *, uint, int, int, char *, uint, uint, int, int);
extern(System) _XImage * XGetImage(_XDisplay *, int, int, int, uint, uint, int, int);
extern(System) _XImage * XGetSubImage(_XDisplay *, int, int, int, uint, uint, int, int, _XImage *, int, int);
extern(System) _XIM * XIMOfIC(_XIC *);
extern(System) _XIM * XOpenIM(_XDisplay *, _XrmHashBucketRec *, char *, char *);
extern(System) XModifierKeymap * XDeleteModifiermapEntry(XModifierKeymap *, ubyte, int);
extern(System) XModifierKeymap * XGetModifierMapping(_XDisplay *);
extern(System) XModifierKeymap * XInsertModifiermapEntry(XModifierKeymap *, ubyte, int);
extern(System) XModifierKeymap * XNewModifiermap(int);
extern(System) _XmuArea * XmuAreaAnd(_XmuArea *, _XmuArea *);
extern(System) _XmuArea * XmuAreaCopy(_XmuArea *, _XmuArea *);
extern(System) _XmuArea * XmuAreaDup(_XmuArea *);
extern(System) _XmuArea * XmuAreaNot(_XmuArea *, int, int, int, int);
extern(System) _XmuArea * XmuAreaOrXor(_XmuArea *, _XmuArea *, int);
extern(System) _XmuArea * XmuNewArea(int, int, int, int);
extern(System) _XmuArea * XmuOptimizeArea(_XmuArea * area);
extern(System) _XmuScanline * XmuNewScanline(int, int, int);
extern(System) _XmuScanline * XmuOptimizeScanline(_XmuScanline *);
extern(System) _XmuScanline * XmuScanlineAndSegment(_XmuScanline *, _XmuSegment *);
extern(System) _XmuScanline * XmuScanlineAnd(_XmuScanline *, _XmuScanline *);
extern(System) _XmuScanline * XmuScanlineCopy(_XmuScanline *, _XmuScanline *);
extern(System) _XmuScanline * XmuScanlineNot(_XmuScanline * scanline, int, int);
extern(System) _XmuScanline * XmuScanlineOrSegment(_XmuScanline *, _XmuSegment *);
extern(System) _XmuScanline * XmuScanlineOr(_XmuScanline *, _XmuScanline *);
extern(System) _XmuScanline * XmuScanlineXorSegment(_XmuScanline *, _XmuSegment *);
extern(System) _XmuScanline * XmuScanlineXor(_XmuScanline *, _XmuScanline *);
extern(System) _XmuSegment * XmuNewSegment(int, int);
extern(System) _XmuWidgetNode * XmuWnNameToNode(_XmuWidgetNode * nodelist, int nnodes, char * name);
extern(System) _XOC * XCreateFontSet(_XDisplay *, char *, char * * *, int *, char * *);
extern(System) _XOC * XCreateOC(_XOM *);
extern(System) _XOM * XOMOfOC(_XOC *);
extern(System) _XOM * XOpenOM(_XDisplay *, _XrmHashBucketRec *, char *, char *);
extern(System) XPixmapFormatValues * XListPixmapFormats(_XDisplay *, int *);
extern(System) _XRegion * XCreateRegion();
extern(System) _XRegion * XPolygonRegion(XPoint *, int, int);
extern(System) _XrmHashBucketRec * XrmGetDatabase(_XDisplay *);
extern(System) _XrmHashBucketRec * XrmGetFileDatabase(char *);
extern(System) _XrmHashBucketRec * XrmGetStringDatabase(char *);
extern(System) _XrmHashBucketRec * * XtAppGetErrorDatabase(_XtAppStruct *);
extern(System) _XrmHashBucketRec * XtDatabase(_XDisplay *);
extern(System) _XrmHashBucketRec * * XtGetErrorDatabase();
extern(System) _XrmHashBucketRec * XtScreenDatabase(Screen *);
extern(System) XSelectionRequestEvent * XtGetSelectionRequest(_WidgetRec *, int, void *);
extern(System) XSizeHints * XAllocSizeHints();
extern(System) XStandardColormap * XAllocStandardColormap();
extern(System) _XtAppStruct * XtCreateApplicationContext();
extern(System) _XtAppStruct * XtDisplayToApplicationContext(_XDisplay *);
extern(System) _XtAppStruct * XtWidgetToApplicationContext(_WidgetRec *);
extern(System) XtCallbackStatus XtHasCallbacks(_WidgetRec *, char *);
extern(System) _XtCheckpointTokenRec * XtSessionGetToken(_WidgetRec *);
extern(System) XtGeometryResult XtMakeGeometryRequest(_WidgetRec *, XtWidgetGeometry *, XtWidgetGeometry *);
extern(System) XtGeometryResult XtMakeResizeRequest(_WidgetRec *, ushort, ushort, ushort *, ushort *);
extern(System) XtGeometryResult XtQueryGeometry(_WidgetRec *, XtWidgetGeometry *, XtWidgetGeometry *);
extern(System) XTimeCoord * XGetMotionEvents(_XDisplay *, int, int, int, int *);
extern(System) XVisualInfo * XGetVisualInfo(_XDisplay *, int, XVisualInfo *, int *);
extern(System) XWMHints * XAllocWMHints();
extern(System) XWMHints * XGetWMHints(_XDisplay *, int);
