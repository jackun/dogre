/*
 *   Tedious work done by John Demme (me@teqdruid.com)
 *       h2d used as well.
 *
 *   LGPL License from original header files probably applies.
 *
 */
// Also http://svn.dsource.org/projects/bcd/trunk/bindings/bcd/gtk2/gtk.d but dmd1
// From minwin.gtk, minified.
module ogre.bindings.mini_gtk;
import ogre.config;

version(X86_64)
    version=CPU64BIT;
else version(PPC64)
    version=CPU64BIT;

static if(OGRE_GTK)
{
    // Included as part of MinWin since the LGPL says the use of header
    // files is unrestricted. The LGPL does not apply to any other part of
    // MinWin except for this file (and even there John isn't sure if it
    // applies since it is a port of header files). The original gtk.d is
    // available from www.dsource.org
    
    pragma(lib,OGRE_GTK_LIB);
    pragma(lib,"gobject-2.0");
    pragma(lib,"glib-2.0");
    pragma(lib,"gdk_pixbuf-2.0");
    
    extern (C) {

        //alias int ptrdiff_t;
        //alias uint size_t;
        //alias int wchar_t;

        alias byte gint8;
        alias ubyte guint8;
        alias short gint16;
        alias ushort guint16;

        alias int gint32;
        alias uint guint32;

        alias long gint64;
        alias ulong guint64;
        version(CPU64BIT) {
            alias long gssize;
            alias ulong gsize;
        } else {
            alias int gssize;
            alias uint gsize;
        }
        alias _GStaticMutex GStaticMutex;
        alias void _GMutex;

        struct _GStaticMutex {
            _GMutex *runtime_mutex;
            union static_mutex_union  {
                char pad[24];
                double dummy_double;
                void *dummy_pointer;
                int dummy_long;
            }
            static_mutex_union static_mutex;
        }
        alias _GSystemThread GSystemThread;

        union _GSystemThread {
            char data[4];
            double dummy_double;
            void *dummy_pointer;
            int dummy_long;
        }
        alias int GPid;

        alias char gchar;
        alias short gshort;

        version(CPU64BIT)
            alias long glong;
        else
            alias int glong;

        alias int gint;
        alias gint gboolean;

        alias ubyte guchar;
        alias ushort gushort;

        version(CPU64BIT)
            alias ulong gulong;
        else
            alias uint gulong;

        alias uint guint;

        alias guint32 gunichar;
        alias guint16 gunichar2;

        alias float gfloat;
        alias double gdouble;
        alias void* gpointer;
        alias void *gconstpointer;
        alias void GData;
        alias void GtkComboBoxPrivate;
        alias _GdkAtom *GdkAtom;
        alias void _GdkAtom;
        alias guint32 GdkNativeWindow;
        alias void GdkPixbuf;

        alias gulong GType;
        struct GValue {
            GType g_type;
            union data_union  {
                gint v_int;
                guint v_uint;
                glong v_long;
                gulong v_ulong;
                gint64 v_int64;
                guint64 v_uint64;
                gfloat v_float;
                gdouble v_double;
                gpointer v_pointer;
            }
            data_union[2] data;
        }

        struct GList {
            gpointer data;
            GList *next;
            GList *prev;
        }

        struct GTypeClass {
            GType g_type;
        }
        struct GTypeInstance {
            GTypeClass *g_class;
        }
        struct GTypeInterface {
            
            GType g_type;
            GType g_instance_type;
        }

        struct GObject {
            GTypeInstance g_type_instance;
            guint ref_count;
            GData *qdata;
        }

        struct GtkObject {
            GObject parent_instance;
            guint32 flags;
        }

        align(1)    struct GtkStyle {
            GObject parent_instance;
            GdkColor fg[5];
            GdkColor bg[5];
            GdkColor light[5];
            GdkColor dark[5];
            GdkColor mid[5];
            GdkColor text[5];
            GdkColor base[5];
            GdkColor text_aa[5];
            
            GdkColor black;
            GdkColor white;
            PangoFontDescription *font_desc;
            
            gint xthickness;
            gint ythickness;
            
            GdkGC *fg_gc[5];
            GdkGC *bg_gc[5];
            GdkGC *light_gc[5];
            GdkGC *dark_gc[5];
            GdkGC *mid_gc[5];
            GdkGC *text_gc[5];
            GdkGC *base_gc[5];
            GdkGC *text_aa_gc[5];
            GdkGC *black_gc;
            GdkGC *white_gc;
            
            GdkPixmap *bg_pixmap[5];
            gint attach_count;
            gint depth;
            GdkColormap *colormap;
            GdkFont *private_font;
            PangoFontDescription *private_font_desc;
            GtkRcStyle *rc_style;
            GSList *styles;
            GArray *property_cache;
            GSList *icon_factories;
        }

        struct GtkWidget 
        {
            GtkObject object;
            guint16 private_flags;
            guint8 state;
            guint8 saved_state;
            gchar *name;
            GtkStyle *style;
            GtkRequisition requisition;
            GtkAllocation allocation;
            GdkWindow *window;
            GtkWidget *parent;
        }

        alias GdkRectangle GtkAllocation;

        struct GtkRequisition {
            gint width;
            gint height;
        }

        struct GdkPoint {
            gint x;
            gint y;
        }
        
        struct GdkRectangle {
            gint x;
            gint y;
            gint width;
            gint height;
        }
        
        struct GdkSegment {
            gint x1;
            gint y1;
            gint x2;
            gint y2;
        }
        
        struct GdkSpan {
            gint x;
            gint y;
            gint width;
        }
        
        struct GdkColor {
            guint32 pixel;
            guint16 red;
            guint16 green;
            guint16 blue;
        }

        struct GdkGCValues {
            GdkColor foreground;
            GdkColor background;
            GdkFont *font;
            GdkFunction Function;
            GdkFill fill;
            GdkPixmap *tile;
            GdkPixmap *stipple;
            GdkPixmap *clip_mask;
            GdkSubwindowMode subwindow_mode;
            gint ts_x_origin;
            gint ts_y_origin;
            gint clip_x_origin;
            gint clip_y_origin;
            gint graphics_exposures;
            gint line_width;
            GdkLineStyle line_style;
            GdkCapStyle cap_style;
            GdkJoinStyle join_style;
        }
        struct GdkGC {
            GObject parent_instance;
            
            gint clip_x_origin;
            gint clip_y_origin;
            gint ts_x_origin;
            gint ts_y_origin;
            
            GdkColormap *colormap;
        }

        
        struct GdkDrawable {
            GObject parent_instance;
        }

        alias GdkDrawable GdkBitmap;
        alias GdkDrawable GdkPixmap;
        alias GdkDrawable GdkWindow;
        alias void PangoFontDescription;

        struct GdkColormap {
            GObject parent_instance;
            gint size;
            GdkColor *colors;
            GdkVisual *visual;
            gpointer windowing_data;
        }

        struct GdkVisual {
            GObject parent_instance;
            GdkVisualType type;
            gint depth;
            GdkByteOrder byte_order;
            gint colormap_size;
            gint bits_per_rgb;
            guint32 red_mask;
            gint red_shift;
            gint red_prec;
            guint32 green_mask;
            gint green_shift;
            gint green_prec;
            guint32 blue_mask;
            gint blue_shift;
            gint blue_prec;
        }

        enum GdkVisualType {
            GDK_VISUAL_STATIC_GRAY,
            GDK_VISUAL_GRAYSCALE,
            GDK_VISUAL_STATIC_COLOR,
            GDK_VISUAL_PSEUDO_COLOR,
            GDK_VISUAL_TRUE_COLOR,
            GDK_VISUAL_DIRECT_COLOR
        }

        enum GdkByteOrder {
            GDK_LSB_FIRST,
            GDK_MSB_FIRST
        }

        enum GtkRcFlags {
            GTK_RC_FG = 1 << 0,
            GTK_RC_BG = 1 << 1,
            GTK_RC_TEXT = 1 << 2,
            GTK_RC_BASE = 1 << 3
        }

        enum GdkEventType {
            GDK_NOTHING = -1,
            GDK_DELETE = 0,
            GDK_DESTROY = 1,
            GDK_EXPOSE = 2,
            GDK_MOTION_NOTIFY = 3,
            GDK_BUTTON_PRESS = 4,
            GDK_2BUTTON_PRESS = 5,
            GDK_3BUTTON_PRESS = 6,
            GDK_BUTTON_RELEASE = 7,
            GDK_KEY_PRESS = 8,
            GDK_KEY_RELEASE = 9,
            GDK_ENTER_NOTIFY = 10,
            GDK_LEAVE_NOTIFY = 11,
            GDK_FOCUS_CHANGE = 12,
            GDK_CONFIGURE = 13,
            GDK_MAP = 14,
            GDK_UNMAP = 15,
            GDK_PROPERTY_NOTIFY = 16,
            GDK_SELECTION_CLEAR = 17,
            GDK_SELECTION_REQUEST = 18,
            GDK_SELECTION_NOTIFY = 19,
            GDK_PROXIMITY_IN = 20,
            GDK_PROXIMITY_OUT = 21,
            GDK_DRAG_ENTER = 22,
            GDK_DRAG_LEAVE = 23,
            GDK_DRAG_MOTION = 24,
            GDK_DRAG_STATUS = 25,
            GDK_DROP_START = 26,
            GDK_DROP_FINISHED = 27,
            GDK_CLIENT_EVENT = 28,
            GDK_VISIBILITY_NOTIFY = 29,
            GDK_NO_EXPOSE = 30,
            GDK_SCROLL = 31,
            GDK_WINDOW_STATE = 32,
            GDK_SETTING = 33
        };
        
        
        
        
        
        enum GdkEventMask {
            GDK_EXPOSURE_MASK = 1 << 1,
            GDK_POINTER_MOTION_MASK = 1 << 2,
            GDK_POINTER_MOTION_HINT_MASK = 1 << 3,
            GDK_BUTTON_MOTION_MASK = 1 << 4,
            GDK_BUTTON1_MOTION_MASK = 1 << 5,
            GDK_BUTTON2_MOTION_MASK = 1 << 6,
            GDK_BUTTON3_MOTION_MASK = 1 << 7,
            GDK_BUTTON_PRESS_MASK = 1 << 8,
            GDK_BUTTON_RELEASE_MASK = 1 << 9,
            GDK_KEY_PRESS_MASK = 1 << 10,
            GDK_KEY_RELEASE_MASK = 1 << 11,
            GDK_ENTER_NOTIFY_MASK = 1 << 12,
            GDK_LEAVE_NOTIFY_MASK = 1 << 13,
            GDK_FOCUS_CHANGE_MASK = 1 << 14,
            GDK_STRUCTURE_MASK = 1 << 15,
            GDK_PROPERTY_CHANGE_MASK = 1 << 16,
            GDK_VISIBILITY_NOTIFY_MASK = 1 << 17,
            GDK_PROXIMITY_IN_MASK = 1 << 18,
            GDK_PROXIMITY_OUT_MASK = 1 << 19,
            GDK_SUBSTRUCTURE_MASK = 1 << 20,
            GDK_SCROLL_MASK = 1 << 21,
            GDK_ALL_EVENTS_MASK = 0x3FFFFE
        };
        

        enum GtkWindowPosition {
            GTK_WIN_POS_NONE,
            GTK_WIN_POS_CENTER,
            GTK_WIN_POS_MOUSE,
            GTK_WIN_POS_CENTER_ALWAYS,
            GTK_WIN_POS_CENTER_ON_PARENT
        };

        enum GdkVisibilityState {
            GDK_VISIBILITY_UNOBSCURED,
            GDK_VISIBILITY_PARTIAL,
            GDK_VISIBILITY_FULLY_OBSCURED
        };
        
        
        enum GdkScrollDirection {
            GDK_SCROLL_UP,
            GDK_SCROLL_DOWN,
            GDK_SCROLL_LEFT,
            GDK_SCROLL_RIGHT
        };
        
        enum GdkNotifyType {
            GDK_NOTIFY_ANCESTOR = 0,
            GDK_NOTIFY_VIRTUAL = 1,
            GDK_NOTIFY_INFERIOR = 2,
            GDK_NOTIFY_NONLINEAR = 3,
            GDK_NOTIFY_NONLINEAR_VIRTUAL = 4,
            GDK_NOTIFY_UNKNOWN = 5
        }

        enum GdkCrossingMode {
            GDK_CROSSING_NORMAL,
            GDK_CROSSING_GRAB,
            GDK_CROSSING_UNGRAB
        }

        enum GdkPropertyState {
            GDK_PROPERTY_NEW_VALUE,
            GDK_PROPERTY_DELETE
        }

        enum GdkWindowState {
            GDK_WINDOW_STATE_WITHDRAWN = 1 << 0,
            GDK_WINDOW_STATE_ICONIFIED = 1 << 1,
            GDK_WINDOW_STATE_MAXIMIZED = 1 << 2,
            GDK_WINDOW_STATE_STICKY = 1 << 3,
            GDK_WINDOW_STATE_FULLSCREEN = 1 << 4,
            GDK_WINDOW_STATE_ABOVE = 1 << 5,
            GDK_WINDOW_STATE_BELOW = 1 << 6
        }

        enum GdkSettingAction {
            GDK_SETTING_ACTION_NEW,
            GDK_SETTING_ACTION_CHANGED,
            GDK_SETTING_ACTION_DELETED
        }

        struct GtkRcStyle {
            GObject parent_instance;

            gchar *name;
            gchar *bg_pixmap_name[5];
            PangoFontDescription *font_desc;
            
            GtkRcFlags color_flags[5];
            GdkColor fg[5];
            GdkColor bg[5];
            GdkColor text[5];
            GdkColor base[5];
            gint xthickness;
            gint ythickness;
            GArray *rc_properties;
            GSList *rc_style_lists;
            GSList *icon_factories;
            guint engine_specified;
        }

        enum GtkTextDirection {
            GTK_TEXT_DIR_NONE,
            GTK_TEXT_DIR_LTR,
            GTK_TEXT_DIR_RTL
        }

        enum GtkJustification {
            GTK_JUSTIFY_LEFT,
            GTK_JUSTIFY_RIGHT,
            GTK_JUSTIFY_CENTER,
            GTK_JUSTIFY_FILL
        }

        enum GtkArrowType {
            GTK_ARROW_UP,
            GTK_ARROW_DOWN,
            GTK_ARROW_LEFT,
            GTK_ARROW_RIGHT
        }

        enum GtkAttachOptions {
            GTK_EXPAND = 1 << 0,
            GTK_SHRINK = 1 << 1,
            GTK_FILL = 1 << 2
        }

        enum GtkMessageType {
            GTK_MESSAGE_INFO,
            GTK_MESSAGE_WARNING,
            GTK_MESSAGE_QUESTION,
            GTK_MESSAGE_ERROR
        }
        
        
        enum GtkButtonsType {
            GTK_BUTTONS_NONE,
            GTK_BUTTONS_OK,
            GTK_BUTTONS_CLOSE,
            GTK_BUTTONS_CANCEL,
            GTK_BUTTONS_YES_NO,
            GTK_BUTTONS_OK_CANCEL
        }

        enum GtkButtonBoxStyle {
            GTK_BUTTONBOX_DEFAULT_STYLE,
            GTK_BUTTONBOX_SPREAD,
            GTK_BUTTONBOX_EDGE,
            GTK_BUTTONBOX_START,
            GTK_BUTTONBOX_END
        }

        enum GtkCurveType {
            GTK_CURVE_TYPE_LINEAR,
            GTK_CURVE_TYPE_SPLINE,
            GTK_CURVE_TYPE_FREE
        }

        struct GArray {
            gchar *data;
            guint len;
        }
        
        struct GByteArray {
            guint8 *data;
            guint len;
        }
        
        struct GPtrArray {
            gpointer *pdata;
            guint len;
        }

        struct GSList {
            gpointer data;
            GSList *next;
        }

        enum GdkFontType {
            GDK_FONT_FONT,
            GDK_FONT_FONTSET
        }
        
        
        struct GdkFont {
            GdkFontType type;
            gint ascent;
            gint descent;
        }

        enum GdkCapStyle {
            GDK_CAP_NOT_LAST,
            GDK_CAP_BUTT,
            GDK_CAP_ROUND,
            GDK_CAP_PROJECTING
        }

        enum GdkFill {
            GDK_SOLID,
            GDK_TILED,
            GDK_STIPPLED,
            GDK_OPAQUE_STIPPLED
        }
        
        enum GdkFunction {
            GDK_COPY,
            GDK_INVERT,
            GDK_XOR,
            GDK_CLEAR,
            GDK_AND,
            GDK_AND_REVERSE,
            GDK_AND_INVERT,
            GDK_NOOP,
            GDK_OR,
            GDK_EQUIV,
            GDK_OR_REVERSE,
            GDK_COPY_INVERT,
            GDK_OR_INVERT,
            GDK_NAND,
            GDK_NOR,
            GDK_SET
        }

        enum GdkJoinStyle {
            GDK_JOIN_MITER,
            GDK_JOIN_ROUND,
            GDK_JOIN_BEVEL
        }

        enum GdkLineStyle {
            GDK_LINE_SOLID,
            GDK_LINE_ON_OFF_DASH,
            GDK_LINE_DOUBLE_DASH
        }
        
        enum GdkSubwindowMode {
            GDK_CLIP_BY_CHILDREN = 0,
            GDK_INCLUDE_INFERIORS = 1
        }
        
        
        enum GdkGCValuesMask {
            GDK_GC_FOREGROUND = 1 << 0,
            GDK_GC_BACKGROUND = 1 << 1,
            GDK_GC_FONT = 1 << 2,
            GDK_GC_FUNCTION = 1 << 3,
            GDK_GC_FILL = 1 << 4,
            GDK_GC_TILE = 1 << 5,
            GDK_GC_STIPPLE = 1 << 6,
            GDK_GC_CLIP_MASK = 1 << 7,
            GDK_GC_SUBWINDOW = 1 << 8,
            GDK_GC_TS_X_ORIGIN = 1 << 9,
            GDK_GC_TS_Y_ORIGIN = 1 << 10,
            GDK_GC_CLIP_X_ORIGIN = 1 << 11,
            GDK_GC_CLIP_Y_ORIGIN = 1 << 12,
            GDK_GC_EXPOSURES = 1 << 13,
            GDK_GC_LINE_WIDTH = 1 << 14,
            GDK_GC_LINE_STYLE = 1 << 15,
            GDK_GC_CAP_STYLE = 1 << 16,
            GDK_GC_JOIN_STYLE = 1 << 17
        }

        enum GtkDialogFlags {
            GTK_DIALOG_MODAL = 1 << 0,
            GTK_DIALOG_DESTROY_WITH_PARENT = 1 << 1,
            GTK_DIALOG_NO_SEPARATOR = 1 << 2
        }
        
        enum GtkResponseType {
            GTK_RESPONSE_NONE = -1,
            GTK_RESPONSE_REJECT = -2,
            GTK_RESPONSE_ACCEPT = -3,
            GTK_RESPONSE_DELETE_EVENT = -4,
            GTK_RESPONSE_OK = -5,
            GTK_RESPONSE_CANCEL = -6,
            GTK_RESPONSE_CLOSE = -7,
            GTK_RESPONSE_YES = -8,
            GTK_RESPONSE_NO = -9,
            GTK_RESPONSE_APPLY = -10,
            GTK_RESPONSE_HELP = -11
        }

        enum GdkModifierType {
            GDK_SHIFT_MASK = 1 << 0,
            GDK_LOCK_MASK = 1 << 1,
            GDK_CONTROL_MASK = 1 << 2,
            GDK_MOD1_MASK = 1 << 3,
            GDK_MOD2_MASK = 1 << 4,
            GDK_MOD3_MASK = 1 << 5,
            GDK_MOD4_MASK = 1 << 6,
            GDK_MOD5_MASK = 1 << 7,
            GDK_BUTTON1_MASK = 1 << 8,
            GDK_BUTTON2_MASK = 1 << 9,
            GDK_BUTTON3_MASK = 1 << 10,
            GDK_BUTTON4_MASK = 1 << 11,
            GDK_BUTTON5_MASK = 1 << 12,
            GDK_RELEASE_MASK = 1 << 30,
            GDK_MODIFIER_MASK = GDK_RELEASE_MASK | 0x1fff
        }
        
        enum GdkInputCondition {
            GDK_INPUT_READ = 1 << 0,
            GDK_INPUT_WRITE = 1 << 1,
            GDK_INPUT_EXCEPTION = 1 << 2
        }

        enum GdkStatus {
            GDK_OK = 0,
            GDK_ERROR = -1,
            GDK_ERROR_PARAM = -2,
            GDK_ERROR_FILE = -3,
            GDK_ERROR_MEM = -4
        }

        enum GdkGrabStatus {
            GDK_GRAB_SUCCESS = 0,
            GDK_GRAB_ALREADY_GRABBED = 1,
            GDK_GRAB_INVALID_TIME = 2,
            GDK_GRAB_NOT_VIEWABLE = 3,
            GDK_GRAB_FROZEN = 4
        }

        
        struct GdkEventAny {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
        }

        alias void GdkRegion;

        struct GdkEventExpose {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
            GdkRectangle area;
            GdkRegion *region;
            gint count;
        }
        
        struct GdkEventNoExpose {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
        }
        
        struct GdkEventVisibility {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
            GdkVisibilityState state;
        }

        
        enum GdkExtensionMode {
            GDK_EXTENSION_EVENTS_NONE,
            GDK_EXTENSION_EVENTS_ALL,
            GDK_EXTENSION_EVENTS_CURSOR
        };
        
        
        enum GdkInputSource {
            GDK_SOURCE_MOUSE,
            GDK_SOURCE_PEN,
            GDK_SOURCE_ERASER,
            GDK_SOURCE_CURSOR
        };
        
        
        enum GdkInputMode {
            GDK_MODE_DISABLED,
            GDK_MODE_SCREEN,
            GDK_MODE_WINDOW
        };
        
        
        enum GdkAxisUse {
            GDK_AXIS_IGNORE,
            GDK_AXIS_X,
            GDK_AXIS_Y,
            GDK_AXIS_PRESSURE,
            GDK_AXIS_XTILT,
            GDK_AXIS_YTILT,
            GDK_AXIS_WHEEL,
            GDK_AXIS_LAST
        };

        struct GdkDeviceKey {
            guint keyval;
            GdkModifierType modifiers;
        }

        struct GdkDeviceAxis {
            GdkAxisUse use;
            gdouble min;
            gdouble max;
        }

        struct GdkDevice {
            GObject parent_instance;
            gchar *name;
            GdkInputSource source;
            GdkInputMode mode;
            gboolean has_cursor;
            
            gint num_axes;
            GdkDeviceAxis *axes;
            
            gint num_keys;
            GdkDeviceKey *keys;
        }

        struct GdkEventMotion {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
            guint32 time;
            gdouble x;
            gdouble y;
            gdouble *axes;
            guint state;
            gint16 is_hint;
            GdkDevice *device;
            gdouble x_root, y_root;
        }
        
        struct GdkEventButton {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
            guint32 time;
            gdouble x;
            gdouble y;
            gdouble *axes;
            guint state;
            guint button;
            GdkDevice *device;
            gdouble x_root, y_root;
        }
        
        struct GdkEventScroll {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
            guint32 time;
            gdouble x;
            gdouble y;
            guint state;
            GdkScrollDirection direction;
            GdkDevice *device;
            gdouble x_root, y_root;
        }
        
        struct GdkEventKey {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
            guint32 time;
            guint state;
            guint keyval;
            gint length;
            gchar *string;
            guint16 hardware_keycode;
            guint8 group;
        }
        
        struct GdkEventCrossing {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
            GdkWindow *subwindow;
            guint32 time;
            gdouble x;
            gdouble y;
            gdouble x_root;
            gdouble y_root;
            GdkCrossingMode mode;
            GdkNotifyType detail;
            gboolean focus;
            guint state;
        }
        
        struct GdkEventFocus {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
            gint16 In;
        }
        
        struct GdkEventConfigure {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
            gint x, y;
            gint width;
            gint height;
        }
        
        struct GdkEventProperty {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
            GdkAtom atom;
            guint32 time;
            guint state;
        }
        
        struct GdkEventSelection {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
            GdkAtom selection;
            GdkAtom target;
            GdkAtom property;
            guint32 time;
            GdkNativeWindow requestor;
        }

        struct GdkEventProximity {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
            guint32 time;
            GdkDevice *device;
        }
        
        struct GdkEventClient {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
            GdkAtom message_type;
            gushort data_format;
            union data_union  {
                char b[20];
                short s[10];
                int l[5];
            }
            data_union data;
        }
        
        struct GdkEventSetting {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
            GdkSettingAction action;
            char *name;
        }
        
        struct GdkEventWindowState {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
            GdkWindowState changed_mask;
            GdkWindowState new_window_state;
        }
        
        enum GdkDragAction {
            GDK_ACTION_DEFAULT = 1 << 0,
            GDK_ACTION_COPY = 1 << 1,
            GDK_ACTION_MOVE = 1 << 2,
            GDK_ACTION_LINK = 1 << 3,
            GDK_ACTION_PRIVATE = 1 << 4,
            GDK_ACTION_ASK = 1 << 5
        }
        
        enum GdkDragProtocol {
            GDK_DRAG_PROTO_MOTIF,
            GDK_DRAG_PROTO_XDND,
            GDK_DRAG_PROTO_ROOTWIN,
            
            GDK_DRAG_PROTO_NONE,
            GDK_DRAG_PROTO_WIN32_DROPFILES,
            GDK_DRAG_PROTO_OLE2,
            GDK_DRAG_PROTO_LOCAL
        }

        struct GdkDragContext {
            GObject parent_instance;
            GdkDragProtocol protocol;
            
            gboolean is_source;
            
            GdkWindow *source_window;
            GdkWindow *dest_window;
            
            GList *targets;
            GdkDragAction actions;
            GdkDragAction suggested_action;
            GdkDragAction action;
            
            guint32 start_time;
            gpointer windowing_data;
        }
        
        struct GdkEventDND {
            GdkEventType type;
            GdkWindow *window;
            gint8 send_event;
            GdkDragContext *context;
            
            guint32 time;
            gshort x_root, y_root;
        }
        
        union GdkEvent {
            GdkEventType type;
            GdkEventAny any;
            GdkEventExpose expose;
            GdkEventNoExpose no_expose;
            GdkEventVisibility visibility;
            GdkEventMotion motion;
            GdkEventButton button;
            GdkEventScroll scroll;
            GdkEventKey key;
            GdkEventCrossing crossing;
            GdkEventFocus focus_change;
            GdkEventConfigure configure;
            GdkEventProperty property;
            GdkEventSelection selection;
            GdkEventProximity proximity;
            GdkEventClient client;
            GdkEventDND dnd;
            GdkEventWindowState window_state;
            GdkEventSetting setting;
        }

        struct GtkContainer {
            GtkWidget widget;
            GtkWidget *focus_child;
            
            guint border_width;
            /* needs alignment work BVH
             guint need_resize;
             guint resize_mode;
             guint reallocate_redraws;
             guint has_focus_chain;
             */
        }

        struct GtkCombo {
            GtkHBox hbox;
            GtkWidget *entry;
            GtkWidget *button;
            GtkWidget *popup;
            GtkWidget *popwin;

            GtkWidget *list;

            guint entry_change_id;
            guint list_change_id;
            
            guint value_in_list;
            guint ok_if_empty;
            guint case_sensitive;
            guint use_arrows;
            guint use_arrows_always;
            
            guint16 current_button;
            guint activate_id;
        }

        struct GtkComboBox {
            GtkBin parent_instance;
            GtkComboBoxPrivate *priv;
        }

        struct GtkBin {
            GtkContainer container;
            GtkWidget *child;
        }

        struct GtkDialog {
            GtkWindow window;
            GtkWidget *vbox;
            GtkWidget *action_area;
            GtkWidget *separator;
        }

        struct GtkWindowGroup {
            GObject parent_instance;
            GSList *grabs;
        }

        alias void GtkWindowGeometryInfo;

        struct GtkWindow {
            GtkBin bin;
            
            gchar *title;
            gchar *wmclass_name;
            gchar *wmclass_class;
            gchar *wm_role;
            
            GtkWidget *focus_widget;
            GtkWidget *default_widget;
            GtkWindow *transient_parent;
            GtkWindowGeometryInfo *geometry_info;
            GdkWindow *frame;
            GtkWindowGroup *group;
            
            guint16 configure_request_count;
            guint allow_shrink;
            guint allow_grow;
            guint configure_notify_received;

            guint need_default_position;
            guint need_default_size;
            guint position;
            guint type;
            guint has_user_ref_count;
            guint has_focus;
            
            guint modal;
            guint destroy_with_parent;
            
            guint has_frame;
            
            
            guint iconify_initially;
            guint stick_initially;
            guint maximize_initially;
            guint decorated;
            
            guint type_hint;
            guint gravity;
            
            guint is_active;
            guint has_toplevel_focus;
            
            guint frame_left;
            guint frame_top;
            guint frame_right;
            guint frame_bottom;
            
            guint keys_changed_handler;
            
            GdkModifierType mnemonic_modifier;
            GdkScreen *screen;
        }

        struct GdkScreen {
            GObject parent_instance;
            guint closed;
            GdkGC *normal_gcs[32];
            GdkGC *exposure_gcs[32];
        }

        struct GtkHBox {
            GtkBox box;
        }

        struct GtkVBox {
            GtkBox box;
        }

        struct GtkBox {
            GtkContainer container;
            GList *children;
            gint16 spacing;
            guint homogeneous;
        }

        struct GtkMisc {
            GtkWidget widget;
            
            gfloat xalign;
            gfloat yalign;
            
            guint16 xpad;
            guint16 ypad;
        }

        alias void PangoAttrList;
        alias void PangoAttrIterator;
        alias void PangoLayout;
        alias void GtkLabelSelectionInfo;

        struct GtkLabel {
            GtkMisc misc;
            gchar *label;
            guint jtype;
            guint wrap;
            guint use_underline;
            guint use_markup;
            
            guint mnemonic_keyval;
            
            gchar *text;
            PangoAttrList *attrs;
            PangoAttrList *effective_attrs;
            
            PangoLayout *layout;
            
            GtkWidget *mnemonic_widget;
            GtkWindow *mnemonic_window;
            
            GtkLabelSelectionInfo *select_info;
        }

        struct GtkFrame {
            GtkBin bin;
            
            GtkWidget *label_widget;
            gint16 shadow_type;
            gfloat label_xalign;
            gfloat label_yalign;
            
            GtkAllocation child_allocation;
        }

        struct GtkTableRowCol {
            guint16 requisition;
            guint16 allocation;
            guint16 spacing;
            guint need_expand;
            guint need_shrink;
            guint expand;
            guint shrink;
            guint empty;
        }

        struct GtkTable {
            GtkContainer container;
            
            GList *children;
            GtkTableRowCol *rows;
            GtkTableRowCol *cols;
            guint16 nrows;
            guint16 ncols;
            guint16 column_spacing;
            guint16 row_spacing;
            guint homogeneous;
        }

        //GTK 3
        alias void GtkComboBoxTextPrivate;
        struct GtkComboBoxText
        {
            GtkComboBox parent_instance;
            
            GtkComboBoxTextPrivate *priv;
        }

        
        //Minimumish set of functions
        void gtk_disable_setlocale ();
        gboolean gtk_parse_args (int *argc, char ***argv);
        void gtk_init (int *argc, char ***argv);
        gboolean gtk_init_check (int *argc, char ***argv);
        void gtk_exit (gint error_code);
        GtkWidget* gtk_widget_new (GType type,
                                   gchar *first_property_name,
                                   ...);
        GtkWidget* gtk_widget_ref (GtkWidget *widget);
        void gtk_widget_unref (GtkWidget *widget);
        void gtk_widget_destroy (GtkWidget *widget);
        gboolean gtk_events_pending ();
        void gtk_main_do_event (GdkEvent *event);
        
        void gtk_main ();
        guint gtk_main_level ();
        void gtk_main_quit ();
        gboolean gtk_main_iteration ();
        gboolean gtk_main_iteration_do (gboolean blocking);

        GtkWidget* gtk_dialog_new ();
        GtkWidget* gtk_message_dialog_new (GtkWindow *parent,
                                           GtkDialogFlags flags,
                                           GtkMessageType type,
                                           GtkButtonsType buttons,
                                           gchar *message_format,
                                           ...) ;
        GtkWidget* gtk_dialog_new_with_buttons ( gchar *title, GtkWindow *parent, GtkDialogFlags flags,
                                                gchar *first_button_text, ...);
        void gtk_dialog_add_action_widget (GtkDialog *dialog, GtkWidget *child, gint response_id);
        GtkWidget* gtk_dialog_add_button (GtkDialog *dialog, gchar *button_text, gint response_id);
        void gtk_dialog_add_buttons (GtkDialog *dialog, gchar *first_button_text, ...);
        void gtk_dialog_set_response_sensitive (GtkDialog *dialog, gint response_id, gboolean setting);
        void gtk_dialog_set_default_response (GtkDialog *dialog, gint response_id);
        void gtk_dialog_set_has_separator (GtkDialog *dialog, gboolean setting);
        gboolean gtk_dialog_get_has_separator (GtkDialog *dialog);
        void gtk_dialog_response (GtkDialog *dialog, gint response_id);
        gint gtk_dialog_run (GtkDialog *dialog);
        void _gtk_dialog_set_ignore_separator (GtkDialog *dialog, gboolean ignore_separator);
        gint _gtk_dialog_get_response_for_widget (GtkDialog *dialog, GtkWidget *widget);
        void gtk_container_forall (GtkContainer *container,
                                   GtkCallback callback,
                                   gpointer callback_data);
        
        void gtk_window_set_position (GtkWindow *window, GtkWindowPosition position);
        void gtk_window_set_resizable (GtkWindow *window, gboolean resizable);
        gboolean gtk_window_get_resizable (GtkWindow *window);

        void gtk_widget_grab_focus (GtkWidget *widget);
        void gtk_widget_show (GtkWidget *widget);
        void gtk_widget_show_now (GtkWidget *widget);
        void gtk_widget_hide (GtkWidget *widget);
        void gtk_widget_show_all (GtkWidget *widget);
        void gtk_widget_hide_all (GtkWidget *widget);
        void gtk_frame_set_label (GtkFrame *frame, gchar *label);
        void gtk_label_set_use_markup (GtkLabel *label, gboolean setting);
        gchar *gtk_frame_get_label (GtkFrame *frame);
        void gtk_frame_set_label_widget (GtkFrame *frame, GtkWidget *label_widget);
        gchar* gtk_label_get_text (GtkLabel *label);
        void gtk_label_set_text (GtkLabel *label, gchar *str);
        GtkWidget* gtk_frame_new ( gchar *label);
        GtkWidget* gtk_table_new (guint rows, guint columns, gboolean homogeneous);
        void gtk_table_resize (GtkTable *table, guint rows, guint columns);
        void gtk_table_attach (GtkTable *table,
                               GtkWidget *child,
                               guint left_attach,
                               guint right_attach,
                               guint top_attach,
                               guint bottom_attach,
                               GtkAttachOptions xoptions,
                               GtkAttachOptions yoptions,
                               guint xpadding,
                               guint ypadding);
        void gtk_table_attach_defaults (GtkTable *table,
                                        GtkWidget *widget,
                                        guint left_attach,
                                        guint right_attach,
                                        guint top_attach,
                                        guint bottom_attach);

        GtkWidget* gtk_vbox_new (gboolean homogeneous, gint spacing);

        void gtk_box_pack_start (GtkBox *box,
                                 GtkWidget *child,
                                 gboolean expand,
                                 gboolean fill,
                                 guint padding);
        void gtk_box_pack_end (GtkBox *box,
                               GtkWidget *child,
                               gboolean expand,
                               gboolean fill,
                               guint padding);
        void gtk_box_pack_start_defaults (GtkBox *box, GtkWidget *widget);
        void gtk_box_pack_end_defaults (GtkBox *box, GtkWidget *widget);
        void gtk_box_set_homogeneous (GtkBox *box, gboolean homogeneous);
        gboolean gtk_box_get_homogeneous (GtkBox *box);
        void gtk_box_set_spacing (GtkBox *box, gint spacing);
        gint gtk_box_get_spacing (GtkBox *box);
        void gtk_box_reorder_child (GtkBox *box, GtkWidget *child, gint position);
        GtkWidget* gtk_hbox_new (gboolean homogeneous, gint spacing);
        GtkWidget* gtk_label_new ( char *str);
        void gtk_label_set_justify (GtkLabel *label, GtkJustification jtype);
        void gtk_misc_set_alignment (GtkMisc *misc, gfloat xalign, gfloat yalign);
        void gtk_misc_get_alignment (GtkMisc *misc, gfloat *xalign, gfloat *yalign);
        void gtk_misc_set_padding (GtkMisc *misc, gint xpad, gint ypad);
        void gtk_misc_get_padding (GtkMisc *misc, gint *xpad, gint *ypad);
        GtkWidget *gtk_bin_get_child (GtkBin *bin);

        //version(GTK2)
        //    GtkWidget *gtk_combo_box_new_text ();
        //else
        //{
            GtkWidget *gtk_combo_box_text_new ();
        //    alias gtk_combo_box_text_new gtk_combo_box_new_text;
        //}

        //deprecated
        //gchar *gtk_combo_box_get_active_text(GtkComboBox *combo_box);
        gchar *gtk_combo_box_text_get_active_text(GtkComboBoxText *combo_box);

        alias void GtkEntryCompletionPrivate;
        struct GtkEntryCompletion {
            GObject parent_instance;
            GtkEntryCompletionPrivate *priv;
        }

        struct GtkIMContext {
            GObject parent_instance;
        }

        struct GtkEntry {
            GtkWidget widget;
            
            gchar *text;
            
            guint editable;
            guint visible;
            guint overwrite_mode;
            guint in_drag;
            
            guint16 text_length;
            guint16 text_max_length;
            
            
            GdkWindow *text_area;
            GtkIMContext *im_context;
            GtkWidget *popup_menu;
            
            gint current_pos;
            gint selection_bound;
            
            PangoLayout *cached_layout;
            guint cache_includes_preedit;
            
            guint need_im_reset;
            
            guint has_frame;
            
            guint activates_default;
            
            guint cursor_visible;
            
            guint in_click;
            
            guint is_cell_renderer;
            guint editing_canceled;
            
            guint mouse_cursor_obscured;
            
            guint select_words;
            guint select_lines;
            guint resolved_dir;
            guint button;
            guint blink_timeout;
            guint recompute_idle;
            gint scroll_offset;
            gint ascent;
            gint descent;
            
            guint16 text_size;
            guint16 n_bytes;
            
            guint16 preedit_length;
            guint16 preedit_cursor;
            
            gint dnd_position;
            
            gint drag_start_x;
            gint drag_start_y;
            
            gunichar invisible_char;
            
            gint width_chars;
        }
        void gtk_entry_set_text (GtkEntry *entry, gchar *text);
        gchar* gtk_entry_get_text (GtkEntry *entry);

        //version(GTK2)
        //    void gtk_combo_box_append_text (GtkComboBox *combo_box, gchar *text);
        //else // Needs atleast gtk 2.24?
        //{
            void gtk_combo_box_text_append_text (GtkComboBoxText *combo_box, gchar *text);
            void gtk_combo_box_append_text (GtkComboBox *combo_box, gchar *text)
            {
                gtk_combo_box_text_append_text(GTK_COMBOBOX_TEXT(combo_box), text);
            }
        //}

        void gtk_combo_box_insert_text (GtkComboBox *combo_box, gint position, gchar *text);
        void gtk_combo_box_prepend_text (GtkComboBox *combo_box, gchar *text);
        void gtk_combo_box_remove_text (GtkComboBox *combo_box, gint position);
        void gtk_combo_box_popup (GtkComboBox *combo_box);
        void gtk_combo_box_popdown (GtkComboBox *combo_box);
        void gtk_container_add (GtkContainer *container, GtkWidget *widget);
        void gtk_container_remove (GtkContainer *container, GtkWidget *widget);
        gint gtk_combo_box_get_active (GtkComboBox *combo_box);
        void gtk_combo_box_set_active (GtkComboBox *combo_box, gint index_);

        alias uint GdkColorspace ;
        enum : GdkColorspace
        {
            GDK_COLORSPACE_RGB
        }
        alias void function (guchar *pixels, gpointer data) GdkPixbufDestroyNotify;

        GdkPixbuf *gdk_pixbuf_new_from_data ( guchar *data,
                                             GdkColorspace colorspace,
                                             gboolean has_alpha,
                                             int bits_per_sample,
                                             int width, int height,
                                             int rowstride,
                                             GdkPixbufDestroyNotify destroy_fn,
                                             gpointer destroy_fn_data);
        GtkWidget* gtk_image_new_from_pixbuf (GdkPixbuf *pixbuf);
        GdkPixbuf *gdk_pixbuf_ref (GdkPixbuf *pixbuf);
        void gdk_pixbuf_unref (GdkPixbuf *pixbuf);

        alias void GMainContext;
        alias void function () GSourceDummyMarshal;
        alias gboolean function (gpointer data) GSourceFunc;

        struct GSourceCallbackFuncs {
            void function (gpointer cb_data) _ref;
            void function (gpointer cb_data) unref;
            void function (gpointer cb_data,
                           GSource *source,
                           GSourceFunc *func,
                           gpointer *data) get;
        }

        struct GSource {
            
            gpointer callback_data;
            GSourceCallbackFuncs *callback_funcs;
            
            GSourceFuncs *source_funcs;
            guint ref_count;
            
            GMainContext *context;
            
            gint priority;
            guint flags;
            guint source_id;
            
            GSList *poll_fds;
            
            GSource *prev;
            GSource *next;
            
            gpointer reserved1;
            gpointer reserved2;
        }

        struct GSourceFuncs {
            gboolean function (GSource *source, gint *timeout_) prepare;
            gboolean function (GSource *source) check;
            gboolean function (GSource *source,
                               GSourceFunc callback,
                               gpointer user_data) dispatch;
            void function (GSource *source) finalize;
            
            
            GSourceFunc closure_callback;
            GSourceDummyMarshal closure_marshal;
        }

        guint g_idle_add (GSourceFunc Function, gpointer data);

        enum GSignalFlags {
            G_SIGNAL_RUN_FIRST = 1 << 0,
            G_SIGNAL_RUN_LAST = 1 << 1,
            G_SIGNAL_RUN_CLEANUP = 1 << 2,
            G_SIGNAL_NO_RECURSE = 1 << 3,
            G_SIGNAL_DETAILED = 1 << 4,
            G_SIGNAL_ACTION = 1 << 5,
            G_SIGNAL_NO_HOOKS = 1 << 6
        }

        enum GConnectFlags {
            G_CONNECT_AFTER = 1 << 0,
            G_CONNECT_SWAPPED = 1 << 1
        }
        
        enum GSignalMatchType {
            G_SIGNAL_MATCH_ID = 1 << 0,
            G_SIGNAL_MATCH_DETAIL = 1 << 1,
            G_SIGNAL_MATCH_CLOSURE = 1 << 2,
            G_SIGNAL_MATCH_FUNC = 1 << 3,
            G_SIGNAL_MATCH_DATA = 1 << 4,
            G_SIGNAL_MATCH_UNBLOCKED = 1 << 5
        }

        gpointer g_object_get_data (GObject *object, gchar *key);
        void g_object_set_data (GObject *object, gchar *key, gpointer data);
        gulong g_signal_connect_data (gpointer instanc,
                                      gchar *detailed_signal,
                                      GCallback c_handler,
                                      gpointer data,
                                      GClosureNotify destroy_data,
                                      GConnectFlags connect_flags);

        alias void function () GCallback;
        alias void function (gpointer data, GClosure *closure) GClosureNotify;
        alias void function (GtkWidget *widget, gpointer data) GtkCallback;

        struct GClosureNotifyData {
            gpointer data;
            GClosureNotify notify;
        }

        struct GClosure {
            guint ref_count;
            guint meta_marshal;
            guint n_guards;
            guint n_fnotifiers;
            guint n_inotifiers;
            guint in_inotify;
            guint floating;
            guint derivative_flag;
            guint in_marshal;
            guint is_invalid;
            
            void function (GClosure *closure,
                           GValue *return_value,
                           guint n_param_values,
                           GValue *param_values,
                           gpointer invocation_hint,
                           gpointer marshal_data) marshal;
            gpointer data; 
            
            GClosureNotifyData *notifiers;
        }
        
        
        struct GCClosure {
            GClosure closure;
            gpointer callback;
        }

        gboolean g_type_check_instance(GTypeInstance *instance);
        GTypeInstance* g_type_check_instance_cast(GTypeInstance *instance, GType iface_type);
        gboolean g_type_check_instance_is_a(GTypeInstance *instance, GType iface_type);
        GTypeClass* g_type_check_class_cast(GTypeClass *g_class, GType  is_a_type);
        gboolean g_type_check_class_is_a(GTypeClass *g_class, GType is_a_type);
        gboolean g_type_check_is_value_type(GType type);
        gboolean g_type_check_value(GValue  *value);
        gboolean g_type_check_value_holds(GValue *value, GType type);
        gboolean g_type_test_flags(GType type, guint flags);

        GType g_type_fundamental(GType type_id);

        GType gtk_widget_get_type () ;
        GType gtk_table_get_type () ;
        GType gtk_box_get_type () ;
        GType gtk_vbox_get_type () ;
        GType gtk_hbox_get_type () ;
        GType gtk_combo_box_get_type ();
        GType gtk_combo_get_type ();
        GType gtk_label_get_type () ;
        GType gtk_misc_get_type () ;
        GType gtk_dialog_get_type () ;
        GType gtk_window_get_type () ;
        GType gtk_frame_get_type () ;
        GType gtk_container_get_type () ;
        GType gtk_entry_get_type () ;
        GType gtk_bin_get_type () ;

        version(GTK2)
        {
            //nothing
        }
        else
        {
            GType gtk_combo_box_text_get_type();
        }
    }

    // `macros`
    enum G_TYPE_FUNDAMENTAL_SHIFT = 2;
    GType G_TYPE_MAKE_FUNDAMENTAL(T)(T x){ return (cast(GType) ((x) << G_TYPE_FUNDAMENTAL_SHIFT)); }
    @property GType G_TYPE_FUNDAMENTAL(GType type){ return g_type_fundamental (type); }
    @property GType G_TYPE_INVALID(){ return G_TYPE_MAKE_FUNDAMENTAL (0); }
    @property GType G_TYPE_NONE(){ return G_TYPE_MAKE_FUNDAMENTAL (1); }
    @property GType G_TYPE_INTERFACE(){ return G_TYPE_MAKE_FUNDAMENTAL (2); }
    @property GType G_TYPE_CHAR(){ return G_TYPE_MAKE_FUNDAMENTAL (3); }
    @property GType G_TYPE_UCHAR(){ return G_TYPE_MAKE_FUNDAMENTAL (4); }
    @property GType G_TYPE_BOOLEAN(){ return G_TYPE_MAKE_FUNDAMENTAL (5); }
    @property GType G_TYPE_INT(){ return G_TYPE_MAKE_FUNDAMENTAL (6); }
    @property GType G_TYPE_UINT(){ return G_TYPE_MAKE_FUNDAMENTAL (7); }
    @property GType G_TYPE_LONG(){ return G_TYPE_MAKE_FUNDAMENTAL (8); }
    @property GType G_TYPE_ULONG(){ return G_TYPE_MAKE_FUNDAMENTAL (9); }
    @property GType G_TYPE_INT64(){ return G_TYPE_MAKE_FUNDAMENTAL (10); }
    @property GType G_TYPE_UINT64(){ return G_TYPE_MAKE_FUNDAMENTAL (11); }
    @property GType G_TYPE_ENUM(){ return G_TYPE_MAKE_FUNDAMENTAL (12); }
    @property GType G_TYPE_FLAGS(){ return G_TYPE_MAKE_FUNDAMENTAL (13); }
    @property GType G_TYPE_FLOAT(){ return G_TYPE_MAKE_FUNDAMENTAL (14); }
    @property GType G_TYPE_DOUBLE(){ return G_TYPE_MAKE_FUNDAMENTAL (15); }
    @property GType G_TYPE_STRING(){ return G_TYPE_MAKE_FUNDAMENTAL (16); }
    @property GType G_TYPE_POINTER(){ return G_TYPE_MAKE_FUNDAMENTAL (17); }
    @property GType G_TYPE_BOXED(){ return G_TYPE_MAKE_FUNDAMENTAL (18); }
    @property GType G_TYPE_PARAM(){ return G_TYPE_MAKE_FUNDAMENTAL (19); }
    @property GType G_TYPE_OBJECT(){ return G_TYPE_MAKE_FUNDAMENTAL (20); }
    @property GType G_TYPE_RESERVED_GLIB_FIRST(){ return (22); }
    @property GType G_TYPE_RESERVED_GLIB_LAST(){ return (31); }
    @property GType G_TYPE_RESERVED_BSE_FIRST(){ return (32); }
    @property GType G_TYPE_RESERVED_BSE_LAST(){ return (48); }
    @property GType G_TYPE_RESERVED_USER_FIRST(){ return (49); }

    GTypeInstance* G_TYPE_CHECK_INSTANCE_CAST(T)(T *instance, GType type)
    {
        return g_type_check_instance_cast(cast(GTypeInstance*)instance, type);
    }
    
    GObject* G_OBJECT(T)(T* instance)
    {
        return cast(GObject*)G_TYPE_CHECK_INSTANCE_CAST(instance, G_TYPE_OBJECT);
    }
    
    GtkTable* GTK_TABLE(T)(T* instance)
    {
        return cast(GtkTable*)G_TYPE_CHECK_INSTANCE_CAST(instance, gtk_table_get_type());
    }

    GtkBin* GTK_BIN(T)(T* instance)
    {
        return cast(GtkBin*)G_TYPE_CHECK_INSTANCE_CAST(instance, gtk_bin_get_type());
    }

    GtkEntry* GTK_ENTRY(T)(T* instance)
    {
        return cast(GtkEntry*)G_TYPE_CHECK_INSTANCE_CAST(instance, gtk_entry_get_type());
    }

    GtkComboBox* GTK_COMBOBOX(T)(T* instance)
    {
        return cast(GtkComboBox*)G_TYPE_CHECK_INSTANCE_CAST(instance, gtk_combo_box_get_type());
    }

    GtkCombo* GTK_COMBO(T)(T* instance)
    {
        return cast(GtkCombo*)G_TYPE_CHECK_INSTANCE_CAST(instance, gtk_combo_get_type());
    }

    GtkWidget* GTK_WIDGET(T)(T* instance)
    {
        return cast(GtkWidget*)G_TYPE_CHECK_INSTANCE_CAST(instance, gtk_widget_get_type());
    }

    GtkLabel* GTK_LABEL(T)(T* instance)
    {
        return cast(GtkLabel*)G_TYPE_CHECK_INSTANCE_CAST(instance, gtk_label_get_type());
    }

    GtkMisc* GTK_MISC(T)(T* instance)
    {
        return cast(GtkMisc*)G_TYPE_CHECK_INSTANCE_CAST(instance, gtk_misc_get_type());
    }

    GtkBox* GTK_BOX(T)(T* instance)
    {
        return cast(GtkBox*)G_TYPE_CHECK_INSTANCE_CAST(instance, gtk_box_get_type());
    }

    GtkDialog* GTK_DIALOG(T)(T* instance)
    {
        return cast(GtkDialog*)G_TYPE_CHECK_INSTANCE_CAST(instance, gtk_dialog_get_type());
    }

    GtkWindow* GTK_WINDOW(T)(T* instance)
    {
        return cast(GtkWindow*)G_TYPE_CHECK_INSTANCE_CAST(instance, gtk_window_get_type());
    }

    GtkFrame* GTK_FRAME(T)(T* instance)
    {
        return cast(GtkFrame*)G_TYPE_CHECK_INSTANCE_CAST(instance, gtk_frame_get_type());
    }

    GtkContainer* GTK_CONTAINER(T)(T* instance)
    {
        return cast(GtkContainer*)G_TYPE_CHECK_INSTANCE_CAST(instance, gtk_container_get_type());
    }

    version(GTK2)
    {
        //nothing
    }
    else
    {
        GtkComboBoxText* GTK_COMBOBOX_TEXT(T)(T* instance)
        {
            return cast(GtkComboBoxText*)G_TYPE_CHECK_INSTANCE_CAST(instance, gtk_combo_box_get_type());
        }
    }
}